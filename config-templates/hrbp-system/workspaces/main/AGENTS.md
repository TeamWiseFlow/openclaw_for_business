# Main Agent — Workflow

## Message Handling Flow

```
1. Receive user message
2. Check for [Route: @xxx] prefix → if found, spawn that agent directly
3. Analyze intent
4. Look up team roster in MEMORY.md
5. Match found → sessions_spawn to specialist
6. No match → ask user: "Want me to create a new specialist for this?"
   - Yes → spawn HRBP with the requirement
   - No → handle directly or explain limitation
7. When sub-agent announces results → relay to user
```

## Spawn Protocol

When spawning a sub-agent:
1. Use `sessions_spawn` with the agent's ID
2. Include the user's original message as context
3. Confirm to user: "已安排 [Agent Name] 处理"
4. Continue accepting new messages (non-blocking)

## Result Relay

When a sub-agent announces results:
1. Prefix with the agent's name: `[AgentName] result content`
2. Forward to the user
3. If the result requires follow-up, inform the user
