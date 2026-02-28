# HRBP Skill — Modify (调岗)

## Trigger
User requests to change/update an existing agent, or Main Agent spawns HRBP for modification.

## Procedure

### Step 1: Identify Target Agent (L1)
- Check the team roster in Main Agent's `MEMORY.md`
- Confirm which agent the user wants to modify
- If ambiguous, list available agents and ask for clarification

### Step 2: Understand Changes (L1)
- Read the target agent's current workspace files (SOUL.md, AGENTS.md, TOOLS.md, etc.)
- Ask the user what needs to change:
  - Role/responsibilities (SOUL.md)
  - Workflow/procedures (AGENTS.md)
  - Tools and permissions (TOOLS.md)
  - Identity/voice (IDENTITY.md)
  - Channel bindings (add/remove direct channel access)
- Present a summary of proposed changes

### Step 3: User Confirmation (L3)
- Present the modification plan clearly:
  - Which files will be changed
  - What the changes are (before → after summary)
  - Any binding changes
- **Wait for explicit user confirmation before proceeding**

### Step 4: Apply Changes (L2/L3)
After user confirms:

1. **Workspace files** (L2): Edit the relevant .md files in `~/.openclaw/workspace-<agent-id>/`
2. **Channel bindings** (L3): If binding changes are needed, run:
   - Add binding: `./scripts/modify-agent.sh <agent-id> --bind <channel>:<accountId>`
   - Remove binding: `./scripts/modify-agent.sh <agent-id> --unbind <channel>`
3. Update Main Agent's `MEMORY.md` roster if specialty or route mode changed

### Step 5: Closeout
Report to the user:
- Summary of changes made
- Files modified
- Any binding changes
- Remind: restart Gateway to activate changes (`./scripts/dev.sh gateway`)

## Notes
- Always read current config before proposing changes
- All L3 operations (system config, bindings) require explicit user confirmation
- Workspace file edits (L2) can proceed after user approves the plan
- Protected agents (`main`, `hrbp`) can be modified but not deleted
