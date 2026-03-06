# Main Agent — Tools

## Available Tools
- `sessions_spawn`: Dispatch tasks to sub-agents (non-blocking)
- Standard conversation tools (text reply, file sharing)

## Tool Usage Rules
- Always use `sessions_spawn` for specialist tasks; do not attempt to handle them directly
- For simple Q-type questions, answer directly without spawning
