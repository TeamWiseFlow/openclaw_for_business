# HRBP Agent — Tools

## Available Tools
- File read/write: For generating and editing workspace files
- `./skills/hrbp-recruit/scripts/add-agent.sh`: Register new agent in openclaw.json
- `./skills/hrbp-modify/scripts/modify-agent.sh`: Update agent bindings in openclaw.json
- `./skills/hrbp-remove/scripts/remove-agent.sh`: Unregister agent and archive workspace
- `./skills/hrbp-list/scripts/list-agents.sh`: View current agent roster
- `./skills/hrbp-usage/scripts/agent-usage.sh`: Query agent model usage and cost data

## Tool Usage Rules
- Always read existing files before modifying
- Use role-templates as starting points for new agents
- Never modify the `main` or `hrbp` entries directly
- All openclaw.json modifications are L3 (require user confirmation)
