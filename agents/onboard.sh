#!/usr/bin/env bash
# Interactive first-time setup for the claudistant fleet.
# Idempotent — safe to re-run; existing values are kept as defaults.
#
# What it does:
#   1. Greets the operator
#   2. Resolves FLEET_ROOT (this script's parent dir)
#   3. Prompts for Telegram bot token (validates via getMe)
#   4. Prompts for Telegram owner user id
#   5. Prompts for allowed chat id (defaults to owner id)
#   6. Prompts for owner display name + email (identity for artifacts)
#   7. Prompts for fleet name (default: claudistant)
#   8. Writes .env from .env.example, filling in answers
#   9. Writes .state/identities.json with the default identity
#  10. Initializes empty .state/projects.json and .state/active-project.txt
#  11. Substitutes FLEET_ROOT in .claude/settings.json so hooks fire
#  12. Sends a "Welcome to your fleet" test message to the bot
#  13. Prints next steps
#
# Re-run scenarios:
#   - If you move the fleet folder, re-run to rewrite settings.json paths.
#   - If you swap bot token, re-run; existing .env values are shown as
#     defaults, just press Enter to keep them, or type new values.

set -uo pipefail

FLEET_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$FLEET_ROOT"

# ── Colors (no emojis in script per code rules; use unicode arrows) ─────
RESET=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
CYAN=$'\033[36m'

say()  { printf '%s%s%s\n' "$CYAN" "$*" "$RESET"; }
ok()   { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail() { printf '%s✗%s %s\n' "$RED" "$RESET" "$*" >&2; }
note() { printf '%s  %s%s\n' "$DIM" "$*" "$RESET"; }

# ── Preflight: required commands ────────────────────────────────────────
need_cmds=(curl jq python3 sed grep)
miss=0
for c in "${need_cmds[@]}"; do
  if ! command -v "$c" >/dev/null 2>&1; then
    fail "missing dependency: $c"
    miss=1
  fi
done
if [ "$miss" -eq 1 ]; then
  echo
  fail "install missing dependencies and re-run."
  exit 2
fi

# ── Read existing values (so re-runs preserve them) ─────────────────────
existing() {
  local key="$1"
  [ -f "$FLEET_ROOT/.env" ] || { echo ""; return; }
  # shellcheck disable=SC2002
  cat "$FLEET_ROOT/.env" | awk -F'=' -v k="$key" '
    /^#/ {next}
    $1==k { sub(/^[^=]*=/,""); gsub(/^"|"$/,""); gsub(/^'\''|'\''$/,""); print; exit }
  '
}

prefill_token="$(existing TG_BOT_TOKEN)"
prefill_owner="$(existing TG_OWNER_ID)"
prefill_chat="$(existing TG_ALLOWED_CHAT)"
prefill_botuser="$(existing BOT_USERNAME)"
prefill_name="$(existing CLAUDISTANT_OWNER_NAME)"
prefill_email="$(existing CLAUDISTANT_OWNER_EMAIL)"
prefill_fleet="$(existing FLEET_NAME)"
[ -z "$prefill_fleet" ] && prefill_fleet="claudistant"

# ── Banner ──────────────────────────────────────────────────────────────
echo
say "═══════════════════════════════════════════════════════════════════"
say "  claudistant — first-time setup"
say "═══════════════════════════════════════════════════════════════════"
echo
note "Fleet root: $FLEET_ROOT"
note "This is idempotent. Press Enter to keep existing values."
echo

# ── Helper: prompt with default ─────────────────────────────────────────
ask() {
  local var="$1" label="$2" default="$3" secret="${4:-no}" value
  local hint=""
  [ -n "$default" ] && hint=" ${DIM}[current: $default]${RESET}"
  if [ "$secret" = "yes" ] && [ -n "$default" ]; then
    hint=" ${DIM}[current: ${default:0:6}…${default: -4}]${RESET}"
  fi
  while :; do
    printf '%s%s%s%b ' "$BOLD" "$label" "$RESET" "$hint"
    if ! IFS= read -r value; then
      # stdin closed (EOF). If we have a default, accept it; else bail
      # rather than spin forever (the historical infinite-loop bug).
      if [ -n "$default" ]; then
        value="$default"
        printf '\n'
        printf -v "$var" '%s' "$value"
        break
      fi
      printf '\n'
      fail "stdin closed before a value was provided for '$label'."
      fail "re-run onboard.sh interactively, or pipe in all required answers."
      exit 1
    fi
    if [ -z "$value" ]; then
      value="$default"
    fi
    if [ -z "$value" ]; then
      warn "value required."
      continue
    fi
    printf -v "$var" '%s' "$value"
    break
  done
}

# ── Step 1: bot token ───────────────────────────────────────────────────
say "Step 1/6 — Telegram bot token"
note "Get one from @BotFather: /newbot, then copy the token."
note "Format: <numeric_id>:<alphanumeric_secret>"
TG_BOT_TOKEN=""
while :; do
  ask TG_BOT_TOKEN "  Bot token" "$prefill_token" "yes"
  say "  → validating via Telegram getMe..."
  resp="$(curl -s --max-time 8 "https://api.telegram.org/bot${TG_BOT_TOKEN}/getMe" || echo '{}')"
  bot_ok="$(echo "$resp" | jq -r '.ok // false' 2>/dev/null || echo false)"
  if [ "$bot_ok" = "true" ]; then
    bot_username="$(echo "$resp" | jq -r '.result.username // empty')"
    bot_id="$(echo "$resp" | jq -r '.result.id // empty')"
    ok "bot @${bot_username} (id=${bot_id})"
    break
  else
    fail "getMe failed. Response: $(echo "$resp" | jq -c . 2>/dev/null || echo "$resp")"
    warn "double-check the token and try again."
  fi
done
echo

# ── Step 2: owner user id ───────────────────────────────────────────────
say "Step 2/6 — Owner Telegram user id"
note "Open https://t.me/userinfobot in Telegram, send any message, copy"
note "the 'Id' it shows back. Numeric, e.g. 1234567890."
TG_OWNER_ID=""
while :; do
  ask TG_OWNER_ID "  Owner user id" "$prefill_owner"
  if [[ "$TG_OWNER_ID" =~ ^[0-9]+$ ]]; then
    ok "owner id: $TG_OWNER_ID"
    break
  fi
  fail "must be numeric."
done
echo

# ── Step 3: allowed chat id ─────────────────────────────────────────────
say "Step 3/6 — Allowed chat id"
note "For 1:1 DM with the bot, this equals the owner id (positive int)."
note "For a group, use the negative integer (e.g. -1009876543210)."
TG_ALLOWED_CHAT=""
default_chat="${prefill_chat:-$TG_OWNER_ID}"
while :; do
  ask TG_ALLOWED_CHAT "  Chat id" "$default_chat"
  if [[ "$TG_ALLOWED_CHAT" =~ ^-?[0-9]+$ ]]; then
    ok "chat id: $TG_ALLOWED_CHAT"
    break
  fi
  fail "must be a (possibly negative) integer."
done
echo

# ── Step 4: owner identity ──────────────────────────────────────────────
say "Step 4/6 — Owner identity for artifacts"
note "Used to attribute files, commits, docs the fleet produces."
note "No AI / persona / agent-id names will appear in artifacts."
CLAUDISTANT_OWNER_NAME=""
CLAUDISTANT_OWNER_EMAIL=""
ask CLAUDISTANT_OWNER_NAME  "  Your display name" "$prefill_name"
while :; do
  ask CLAUDISTANT_OWNER_EMAIL "  Your email"       "$prefill_email"
  if [[ "$CLAUDISTANT_OWNER_EMAIL" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
    break
  fi
  fail "must look like an email address."
done
ok "identity: $CLAUDISTANT_OWNER_NAME <$CLAUDISTANT_OWNER_EMAIL>"
echo

# ── Step 5: fleet name ──────────────────────────────────────────────────
say "Step 5/6 — Fleet display name"
note "Used in greetings, slash-command labels, Agent Team name."
FLEET_NAME=""
while :; do
  ask FLEET_NAME "  Fleet name" "$prefill_fleet"
  if [[ "$FLEET_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    ok "fleet name: $FLEET_NAME"
    break
  fi
  fail "use letters, digits, _, - only."
done
echo

# ── Step 6: bot username (auto from getMe) ──────────────────────────────
BOT_USERNAME="$bot_username"

# ── Write .env ──────────────────────────────────────────────────────────
say "Step 6/6 — Writing config"
ENV_PATH="$FLEET_ROOT/.env"
if [ -f "$ENV_PATH" ]; then
  cp "$ENV_PATH" "$ENV_PATH.bak.$(date +%s)"
  note "backed up existing .env"
fi

# Start from .env.example, then inject answers via sed
cp "$FLEET_ROOT/.env.example" "$ENV_PATH"
set_kv() {
  local k="$1" v="$2"
  # Single-quote-wrap the value so spaces / shell metacharacters are
  # preserved when sourced with `set -a; . .env; set +a` (the standard
  # pattern in setup-fleet.sh and friends). Escape any embedded single
  # quotes via the '\'' close+escape+reopen idiom.
  local quoted; quoted="'${v//\'/\'\\\'\'}'"
  # Quote the result again so sed's replacement doesn't choke on the
  # value (still escape & | and \ for the sed s|||).
  local esc; esc="$(printf '%s' "$quoted" | sed -e 's/[\\&|]/\\&/g')"
  if grep -qE "^${k}=" "$ENV_PATH"; then
    sed -i "s|^${k}=.*|${k}=${esc}|" "$ENV_PATH"
  else
    printf '\n%s=%s\n' "$k" "$quoted" >> "$ENV_PATH"
  fi
}
set_kv TG_BOT_TOKEN              "$TG_BOT_TOKEN"
set_kv TG_OWNER_ID               "$TG_OWNER_ID"
set_kv TG_ALLOWED_CHAT           "$TG_ALLOWED_CHAT"
set_kv BOT_USERNAME              "$BOT_USERNAME"
set_kv CLAUDISTANT_OWNER_NAME    "$CLAUDISTANT_OWNER_NAME"
set_kv CLAUDISTANT_OWNER_EMAIL   "$CLAUDISTANT_OWNER_EMAIL"
set_kv FLEET_NAME                "$FLEET_NAME"
chmod 600 "$ENV_PATH"
ok "wrote $ENV_PATH"

# ── Seed state files ────────────────────────────────────────────────────
mkdir -p "$FLEET_ROOT/.state" "$FLEET_ROOT/.claude/tg-state" \
         "$FLEET_ROOT/.claude/logs" "$FLEET_ROOT/.claude/daily-audit" \
         "$FLEET_ROOT/uploads" "$FLEET_ROOT/outputs" \
         "$FLEET_ROOT/projects"
for d in .state .claude/tg-state .claude/logs .claude/daily-audit \
         uploads outputs projects; do
  touch "$FLEET_ROOT/$d/.gitkeep"
done

# projects.json — preserve if already populated
if [ ! -s "$FLEET_ROOT/.state/projects.json" ]; then
  echo '{"projects":[]}' > "$FLEET_ROOT/.state/projects.json"
fi

# active-project.txt — leave empty if no projects yet
touch "$FLEET_ROOT/.state/active-project.txt"

# identities.json — write default, preserve per-project overrides if any
IDENT_PATH="$FLEET_ROOT/.state/identities.json"
if [ -s "$IDENT_PATH" ]; then
  tmp="$(mktemp)"
  jq --arg n "$CLAUDISTANT_OWNER_NAME" --arg e "$CLAUDISTANT_OWNER_EMAIL" \
     '.default = {name: $n, email: $e}' "$IDENT_PATH" > "$tmp" && mv "$tmp" "$IDENT_PATH"
else
  jq -n --arg n "$CLAUDISTANT_OWNER_NAME" --arg e "$CLAUDISTANT_OWNER_EMAIL" '
    {
      _doc: "Per-project author identity. Lead/specialists MUST use these when writing artifacts (files, commits when approved, doc attributions). NO AI/persona tags allowed anywhere in artifacts.",
      projects: {},
      default: {name: $n, email: $e}
    }
  ' > "$IDENT_PATH"
fi
ok "seeded .state/projects.json, .state/identities.json, .state/active-project.txt"

# ── Rewrite settings.json with absolute hook paths ──────────────────────
SETTINGS="$FLEET_ROOT/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
  sed -i "s|\${FLEET_ROOT}|$FLEET_ROOT|g" "$SETTINGS"
  ok "rewrote hook paths in $SETTINGS"
else
  warn "$SETTINGS missing — hooks will not fire"
fi

# ── Register slash commands via setMyCommands ───────────────────────────
say "Registering Telegram slash commands..."
CMDS_TMP="$(mktemp)"
cat > "$CMDS_TMP" <<'JSON'
{
  "commands": [
    {"command": "onboard",         "description": "Run interactive fleet setup (one-time)"},
    {"command": "project_list",    "description": "List all projects"},
    {"command": "project_current", "description": "Show the active project"},
    {"command": "project_switch",  "description": "Switch active project: /project_switch <name>"},
    {"command": "project_create",  "description": "Bootstrap a new project: /project_create <name>"},
    {"command": "stats",           "description": "Fleet stats (cost, queues, contexts)"},
    {"command": "compact",         "description": "Compact every project lead"},
    {"command": "help",            "description": "Show available commands"}
  ]
}
JSON
SET=$(curl -s --max-time 8 -X POST \
  "https://api.telegram.org/bot${TG_BOT_TOKEN}/setMyCommands" \
  -H 'Content-Type: application/json' --data @"$CMDS_TMP")
rm -f "$CMDS_TMP"
set_ok="$(echo "$SET" | jq -r '.ok // false')"
if [ "$set_ok" = "true" ]; then
  ok "8 slash commands registered with @${BOT_USERNAME}"
else
  warn "setMyCommands returned: $(echo "$SET" | jq -c . 2>/dev/null || echo "$SET")"
fi

# ── Send welcome message ────────────────────────────────────────────────
say "Sending welcome test message..."
WELCOME="$(cat <<EOF
${FLEET_NAME} is online.

Owner identity: ${CLAUDISTANT_OWNER_NAME} <${CLAUDISTANT_OWNER_EMAIL}>
Bot: @${BOT_USERNAME}
Chat: ${TG_ALLOWED_CHAT}

Next: open Claude Code in this directory and run /skill fleet-first-time-setup.

Type /help here to see all slash commands.
EOF
)"
if bash "$FLEET_ROOT/agents/send-telegram.sh" "$WELCOME" >/dev/null 2>&1; then
  ok "welcome message sent to chat $TG_ALLOWED_CHAT"
else
  warn "could not send welcome message — check $FLEET_ROOT/.state/tg-send-errors.log"
fi

# ── Done ────────────────────────────────────────────────────────────────
echo
say "═══════════════════════════════════════════════════════════════════"
say "  Onboarding complete"
say "═══════════════════════════════════════════════════════════════════"
echo
cat <<EOF
Next steps:

  1. Open Claude Code in this directory:
       cd $FLEET_ROOT && claude

  2. Inside Claude Code, run the first-time bootstrap skill:
       /skill fleet-first-time-setup

     That creates the Agent Team, scaffolds your first project, spawns
     a lead, starts the Telegram poller, and arms the watchdogs.

  3. Send a Telegram message to @${BOT_USERNAME} from chat ${TG_ALLOWED_CHAT}
     to test routing.

Files written:
  .env                                 (chmod 600)
  .state/projects.json
  .state/identities.json
  .state/active-project.txt
  .claude/settings.json                (hook paths set to $FLEET_ROOT)

Re-run this script any time to re-validate or change values.

EOF
