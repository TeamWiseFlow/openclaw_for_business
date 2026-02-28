# HRBP Agent — Tools

## Available Tools
- File read/write: For generating and editing workspace files
- `add-agent.sh`: Register new agent in openclaw.json
- `modify-agent.sh`: Update agent bindings in openclaw.json
- `remove-agent.sh`: Unregister agent and archive workspace
- `list-agents.sh`: View current agent roster

## Tool Usage Rules
- Always read existing files before modifying
- Use role-templates as starting points for new agents
- Never modify the `main` or `hrbp` entries directly
- All openclaw.json modifications are L3 (require user confirmation)
