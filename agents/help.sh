#!/usr/bin/env bash
# Print available slash commands to Telegram.
cat <<'EOF'
🤖 Fleet commands (owner-only)

Project mgmt:
• /project_list           — list all projects
• /project_current        — show active project
• /project_switch <name>  — set active project
• /project_create <name>  — bootstrap new project

Routing:
• @<name> <msg>           — force route to project <name>
• <plain msg>             — routed to active project

Diagnostics:
• /stats                  — fleet stats (cost, queues, contexts)
• /queue                  — queue state per project
• /skipped                — last 10 skipped inbounds (debug)

Maintenance:
• /compact                — compact every project lead
• /restart_poller         — kill + restart Telegram poller
• /broadcast <msg>        — send <msg> to every project lead

• /help                   — this list
EOF
