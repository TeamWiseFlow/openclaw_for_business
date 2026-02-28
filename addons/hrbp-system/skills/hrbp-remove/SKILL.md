# HRBP Skill — Remove (解雇)

## Trigger
User requests to delete/remove an existing agent, or Main Agent spawns HRBP for removal.

## Important
**This entire procedure is L3 — every step that modifies the system requires explicit user confirmation.**

## Procedure

### Step 1: Identify Target Agent (L1)
- Check the team roster in Main Agent's `MEMORY.md`
- Confirm which agent the user wants to remove
- If ambiguous, list available agents and ask for clarification

### Step 2: Safety Check (L1)
- **Protected agents** (`main`, `hrbp`) **cannot be deleted** — inform the user and abort
- Check if the agent has active channel bindings
- Review the agent's current workspace and configuration

### Step 3: Present Removal Plan (L3 — requires confirmation)
Show the user:
- Agent ID, name, and current responsibilities
- Current channel bindings (if any) that will be removed
- Workspace location that will be archived
- **Explicitly state**: workspace will be archived (not permanently deleted) and can be recovered
- Ask for explicit confirmation to proceed

### Step 4: Execute Removal (L3)
After user confirms:

1. Run: `./scripts/remove-agent.sh <agent-id>`
2. This will:
   - Remove agent from `agents.list` in openclaw.json
   - Remove from Main Agent's `subagents.allowAgents`
   - Remove all related `bindings` entries
   - Archive workspace to `~/.openclaw/archived/workspace-<agent-id>-<timestamp>/`
   - Update Main Agent's `MEMORY.md` roster

### Step 5: Closeout
Report to the user:
- Agent removed successfully
- Workspace archived location (for recovery if needed)
- Bindings removed (if any)
- Remind: restart Gateway to apply changes (`./scripts/dev.sh gateway`)

## Notes
- **Never delete `main` or `hrbp`** — these are protected system agents
- Workspace is archived, not permanently deleted — user can recover it
- All steps that modify the system require explicit user confirmation
- If the user asks to "undo" a removal, the workspace can be restored from the archive
