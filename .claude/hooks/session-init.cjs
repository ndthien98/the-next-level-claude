#!/usr/bin/env node
/**
 * SessionStart Hook — Inject project context at session start
 *
 * Fires:   once per Claude Code session (startup, resume, clear, compact)
 * Purpose: surface CWD, git branch, project type, package manager, runtime
 *          versions so the lead can orient itself without running 4 Bash
 *          commands.
 * Exit:    0 always (non-blocking, fail-open)
 *
 * Configure in `.claude/settings.json`:
 *   "SessionStart": [{ "hooks": [{ "type": "command",
 *     "command": "${FLEET_ROOT}/.claude/hooks/session-init.cjs",
 *     "timeout": 10 }] }]
 */

try {
  const fs = require('fs');
  const path = require('path');
  const os = require('os');
  const { execSync } = require('child_process');

  function execSafe(cmd) {
    try {
      return execSync(cmd, {
        encoding: 'utf-8',
        stdio: ['pipe', 'pipe', 'ignore'],
        timeout: 3000,
      }).trim();
    } catch {
      return null;
    }
  }

  function detectProjectType() {
    const cwd = process.cwd();
    if (fs.existsSync(path.join(cwd, 'package.json'))) return 'node';
    if (
      fs.existsSync(path.join(cwd, 'requirements.txt')) ||
      fs.existsSync(path.join(cwd, 'pyproject.toml'))
    )
      return 'python';
    if (fs.existsSync(path.join(cwd, 'go.mod'))) return 'go';
    if (fs.existsSync(path.join(cwd, 'Cargo.toml'))) return 'rust';
    if (
      fs.existsSync(path.join(cwd, 'pom.xml')) ||
      fs.existsSync(path.join(cwd, 'build.gradle'))
    )
      return 'java';
    return 'unknown';
  }

  function detectPackageManager() {
    const cwd = process.cwd();
    if (fs.existsSync(path.join(cwd, 'yarn.lock'))) return 'yarn';
    if (fs.existsSync(path.join(cwd, 'pnpm-lock.yaml'))) return 'pnpm';
    if (fs.existsSync(path.join(cwd, 'package-lock.json'))) return 'npm';
    if (fs.existsSync(path.join(cwd, 'bun.lockb'))) return 'bun';
    return null;
  }

  const stdin = fs.readFileSync(0, 'utf-8').trim();
  const data = stdin ? JSON.parse(stdin) : {};
  const source = data.source || 'unknown';

  const gitBranch = execSafe('git rev-parse --abbrev-ref HEAD');
  const nodeVersion = process.version;
  const pythonVersion =
    execSafe('python3 --version')?.replace('Python ', '') || null;
  const projectType = detectProjectType();
  const pm = detectPackageManager();

  const parts = [`Session ${source}.`];
  parts.push(`Dir: ${process.cwd()}`);
  if (gitBranch) parts.push(`Branch: ${gitBranch}`);
  if (projectType !== 'unknown') {
    parts.push(`Project: ${projectType}${pm ? ` (${pm})` : ''}`);
  }
  parts.push(`Node: ${nodeVersion}`);
  if (pythonVersion) parts.push(`Python: ${pythonVersion}`);
  parts.push(`OS: ${os.platform()}`);

  // Warn on context compact so the lead re-confirms any pending approvals.
  if (source === 'compact') {
    console.log(
      '\n[compact] Context compacted. If you were waiting on owner approval (e.g. via Telegram), re-confirm before proceeding.'
    );
  }

  console.log(parts.join(' | '));
  process.exit(0);
} catch {
  process.exit(0); // fail-open — never block the session
}
