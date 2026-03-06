# HRBP Skill — Agent Roster (花名册查询)

## Trigger
User asks to list team members, check current agents, inspect bindings or route modes. Examples:
- "现在有哪些 agent？"
- "列一下当前 crew"
- "谁是直连绑定，谁是 spawn？"
- "看下团队花名册"

## Procedure

### Step 1: Clarify Scope (L1)
Confirm what user wants:
- Full roster (default)
- Specific agent details
- Focus on route mode / bindings / workspace status

If unclear, default to full roster.

### Step 2: Query Roster (L1)
Run:

```bash
# List all registered agents with route/binding/workspace status
bash ./skills/hrbp-list/scripts/list-agents.sh
```

### Step 3: Summarize for User (L1)
Present concise takeaways:
1. Total agent count
2. Which agents are spawn / binding / both
3. Missing workspace or abnormal status (if any)

## Notes
- This skill is read-only (L1) — no system modifications
- Data source: `~/.openclaw/openclaw.json` + workspace path checks
- If config is missing, guide user to run `./scripts/dev.sh gateway` once
