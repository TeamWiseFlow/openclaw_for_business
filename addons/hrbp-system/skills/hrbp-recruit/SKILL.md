# HRBP Skill — Recruit (招聘)

## Trigger
User requests a new agent/role/assistant, or Main Agent spawns HRBP for recruitment.

## Procedure

### Step 1: Understand Requirements (L1)
- Ask the user about the new agent's purpose, specialty, and responsibilities
- Ask if the new agent needs a direct channel binding (Mode B) or just spawn access (Mode A)
- Clarify the agent's name and ID (lowercase, hyphenated, e.g., `content-writer`)

### Step 2: Design the Role (L1)
- Review available role templates in `~/.openclaw/hrbp-templates/`
- If a matching template exists, use it as a starting point
- If not, use `~/.openclaw/hrbp-templates/_template/` as the base
- Present a role proposal to the user:
  - Agent ID and name
  - Core responsibilities (for SOUL.md)
  - Autonomy levels (L1/L2/L3 boundaries)
  - Tools and skills needed
  - Route mode: spawn / binding / both
  - If binding: which channel and account

### Step 3: Generate Workspace (L2)
After user confirms the proposal:

1. Create workspace directory: `~/.openclaw/workspace-<agent-id>/`
2. Generate 8 workspace files based on the template:
   - `SOUL.md` — Role definition, identity, boundaries
   - `AGENTS.md` — Workflow and procedures
   - `MEMORY.md` — Long-term notes (initially empty)
   - `USER.md` — User preferences
   - `IDENTITY.md` — Name, personality, voice
   - `TOOLS.md` — Available tools and usage rules
   - `TASKS.md` — Active projects tracker
   - `HEARTBEAT.md` — Health status
3. Copy shared protocols (`RULES.md`, `TEMPLATES.md`) into the workspace

### Step 4: Register Agent (L3 — requires user confirmation)
1. Run: `./scripts/add-agent.sh <agent-id>` (add `--bind <channel>:<accountId>` if needed)
2. This will:
   - Add agent to `agents.list` in openclaw.json
   - Update Main Agent's `subagents.allowAgents`
   - Add binding if specified
   - Update Main Agent's MEMORY.md roster

### Step 5: Closeout
Report to the user:
- Agent ID and name
- Workspace location
- Route mode (spawn / binding / both)
- Remind: restart Gateway to activate (`./scripts/dev.sh gateway`)

## Notes
- Always present the role proposal before generating files
- Use existing role templates when possible
- Agent IDs must be unique, lowercase, hyphenated
- The workspace directory must exist before running add-agent.sh
