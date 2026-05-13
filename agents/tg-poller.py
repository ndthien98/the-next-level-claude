#!/usr/bin/env python3
"""Telegram long-poll for claudistant. Emits one JSON line per inbound
event. Reads config from `.env` in the workspace root.

Why python: shell+jq pipelines choke on multi-line text / control chars.
Python's json module handles it correctly.

Env vars consumed:
  TG_BOT_TOKEN      bot token from @BotFather
  TG_ALLOWED_CHAT   chat id this poller listens to
  WORKDIR           (auto-detected) workspace root
"""
import json
import os
import socket
import sys
import time
import urllib.request
from pathlib import Path

# Force IPv4 — prevents "Network unreachable" on hosts without IPv6 routing
_orig_getaddrinfo = socket.getaddrinfo
def _ipv4_getaddrinfo(host, port, family=0, *args, **kwargs):
    return _orig_getaddrinfo(host, port, socket.AF_INET, *args, **kwargs)
socket.getaddrinfo = _ipv4_getaddrinfo


def _load_env(workdir: Path) -> dict[str, str]:
    env_path = workdir / ".env"
    out: dict[str, str] = {}
    if not env_path.is_file():
        return out
    for raw in env_path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


WORKDIR = Path(os.environ.get("WORKDIR") or Path(__file__).resolve().parents[1])
ENV = {**_load_env(WORKDIR), **os.environ}

TOKEN = ENV.get("TG_BOT_TOKEN", "")
ALLOWED_CHAT = int(ENV.get("TG_ALLOWED_CHAT", "0"))
API = f"https://api.telegram.org/bot{TOKEN}"
FILE_API = f"https://api.telegram.org/file/bot{TOKEN}"
UPLOADS = WORKDIR / "uploads"
OFFSET_FILE = WORKDIR / ".claude/tg-state/offset"
SKIP_LOG = WORKDIR / ".claude/logs/inbound-skipped.log"

UPLOADS.mkdir(parents=True, exist_ok=True)
OFFSET_FILE.parent.mkdir(parents=True, exist_ok=True)
SKIP_LOG.parent.mkdir(parents=True, exist_ok=True)

if not TOKEN or not ALLOWED_CHAT:
    sys.exit("[poller] missing TG_BOT_TOKEN or TG_ALLOWED_CHAT in .env")


def get_offset() -> int:
    try:
        return int(OFFSET_FILE.read_text().strip())
    except Exception:
        return 0


def save_offset(o: int) -> None:
    OFFSET_FILE.write_text(str(o))


def http_get(url: str, timeout: int = 40) -> bytes | None:
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return r.read()
    except Exception as e:
        _stderr(f"[poller] http err: {e}")
        return None


def download_file(file_id: str, prefix: str) -> str | None:
    meta = http_get(f"{API}/getFile?file_id={file_id}", timeout=15)
    if not meta:
        _stderr(f"[poller] download_file: getFile returned nothing for {file_id}")
        return None
    try:
        m = json.loads(meta)
    except Exception as e:
        _stderr(f"[poller] download_file: bad JSON from getFile: {e}")
        return None
    rp = m.get("result", {}).get("file_path")
    if not rp:
        _stderr(f"[poller] download_file: no file_path in response: {meta[:200]!r}")
        return None
    ext = "." + rp.rsplit(".", 1)[-1] if "." in rp else ""
    local = f"{prefix}{ext}"
    data = http_get(f"{FILE_API}/{rp}", timeout=60)
    if not data:
        _stderr(f"[poller] download_file: download failed for {rp}")
        return None
    try:
        (UPLOADS / local).write_bytes(data)
    except Exception as e:
        _stderr(f"[poller] save err: {e}")
        return None
    return local


_last_err: str = ""
_last_err_count: int = 0


def _stderr(msg: str) -> None:
    """Print msg to stderr, collapsing consecutive identical lines into a count."""
    global _last_err, _last_err_count
    if msg == _last_err:
        _last_err_count += 1
    else:
        if _last_err_count > 0:
            print(f"{_last_err} (... x{_last_err_count} more)", file=sys.stderr, flush=True)
        _last_err = msg
        _last_err_count = 0
        print(msg, file=sys.stderr, flush=True)


def _flush_err_collapse() -> None:
    """Flush any pending repeat-collapse summary (call on successful poll)."""
    global _last_err, _last_err_count
    if _last_err_count > 0:
        print(f"{_last_err} (... x{_last_err_count} more)", file=sys.stderr, flush=True)
    _last_err = ""
    _last_err_count = 0


def emit(event: dict) -> None:
    print(json.dumps(event, ensure_ascii=False, separators=(",", ":")), flush=True)


def log_skip(reason: str, chat, fobj, text: str) -> None:
    try:
        with SKIP_LOG.open("a") as lf:
            lf.write(
                f"{time.strftime('%Y-%m-%d %H:%M:%S')} | {reason} | "
                f"chat={chat} | from={fobj.get('id')}(@{fobj.get('username','?')}) | "
                f"text={text[:60]!r}\n"
            )
    except Exception:
        pass


def main() -> None:
    offset = get_offset()
    _stderr(f"[poller] up. offset={offset} chat={ALLOWED_CHAT}")
    while True:
        try:
            body = http_get(f"{API}/getUpdates?timeout=30&offset={offset}", timeout=50)
            if not body:
                time.sleep(3)
                continue
            data = json.loads(body)
            if not data.get("ok"):
                _stderr(f"[poller] not ok: {data.get('description')}")
                time.sleep(3)
                continue
            _flush_err_collapse()
            for upd in data.get("result", []):
                updid = upd.get("update_id")
                if updid is not None:
                    offset = updid + 1
                    save_offset(offset)
                msg = upd.get("message") or upd.get("edited_message") or {}
                chat = msg.get("chat", {}).get("id")
                fobj = msg.get("from", {}) or {}
                text_preview = (msg.get("text") or msg.get("caption") or "")
                if chat != ALLOWED_CHAT:
                    log_skip("chat-filter", chat, fobj, text_preview)
                    continue
                text = msg.get("text") or msg.get("caption") or ""
                ts_file = time.strftime("%Y%m%d-%H%M%S")
                safe_user = fobj.get("username") or str(fobj.get("id") or "anon")
                files_arr: list = []

                photos = msg.get("photo") or []
                if photos:
                    p = max(photos, key=lambda x: x.get("file_size", 0))
                    local = download_file(p["file_id"], f"{ts_file}_{safe_user}_photo")
                    if local:
                        files_arr.append({
                            "kind": "photo",
                            "path": str(UPLOADS / local),
                            "mime": "image/jpeg",
                            "original_name": "",
                        })

                doc = msg.get("document")
                if doc:
                    orig = doc.get("file_name") or ""
                    safe_name = (orig.replace(" ", "_").replace("/", "_")) or "doc"
                    mime = doc.get("mime_type") or ""
                    local = download_file(doc["file_id"], f"{ts_file}_{safe_user}_{safe_name}")
                    if local:
                        files_arr.append({
                            "kind": "document",
                            "path": str(UPLOADS / local),
                            "mime": mime,
                            "original_name": orig,
                        })

                for kind, default_mime in (
                    ("voice", "audio/ogg"),
                    ("audio", "audio/mpeg"),
                    ("video", "video/mp4"),
                ):
                    obj = msg.get(kind)
                    if obj:
                        mime = obj.get("mime_type") or default_mime
                        local = download_file(obj["file_id"], f"{ts_file}_{safe_user}_{kind}")
                        if local:
                            files_arr.append({
                                "kind": kind,
                                "path": str(UPLOADS / local),
                                "mime": mime,
                                "original_name": "",
                            })

                if not text and not files_arr:
                    log_skip("empty", chat, fobj, text_preview)
                    continue

                emit({
                    "src": "tg-inbound",
                    "chat_id": chat,
                    "from_id": fobj.get("id"),
                    "from_username": fobj.get("username") or "",
                    "from_name": fobj.get("first_name") or "",
                    "ts": time.strftime("%Y-%m-%d %H:%M:%S"),
                    "text": text,
                    "files": files_arr,
                })
        except Exception as e:
            _stderr(f"[poller] loop err: {e}")
            time.sleep(3)


if __name__ == "__main__":
    main()
