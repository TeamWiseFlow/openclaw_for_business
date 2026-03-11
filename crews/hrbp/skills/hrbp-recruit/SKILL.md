# HRBP Skill — Recruit (招聘 / 实例化)

## Trigger
User requests a new agent/role/assistant, or Main Agent spawns HRBP for recruitment.

## Procedure

### Step 1: Understand Requirements (L1)
- Ask the user about the new agent's purpose, specialty, and responsibilities
- Ask if the new agent needs a direct channel binding (Mode B) or just spawn access (Mode A)
- Clarify the instance's name and desired ID (lowercase, hyphenated, e.g., `cs-product-a`)

### Step 2: Match Template (L1)
- Browse template library: `~/.openclaw/hrbp-templates/index.md`
- If a matching template exists → use it as the base, proceed to Step 3
- If no match → create a new template first:
  1. Use `~/.openclaw/hrbp-templates/_template/` as scaffold (or closest existing template)
  2. Generate 8 workspace files for the new template
  3. Write to `~/.openclaw/hrbp-templates/<template-id>/`
  4. Update `~/.openclaw/hrbp-templates/index.md`
  5. Then proceed to Step 3

### Step 3: Configure Instance (L1)
Present an instantiation proposal to the user:
- **Instance ID**: unique, lowercase, hyphenated (e.g., `cs-product-a`)
- **Instance Name**: human-readable (e.g., "产品A客服")
- **Source Template**: which template this instance is based on
- **Channel Binding**: optional — which channel and account
- **Skill Customization**: optional — additional or denied skills
- **Role Tuning**: optional — SOUL.md adjustments for this specific instance

### Step 4: Generate Workspace (L2)
After user confirms the proposal:

1. Create workspace directory: `~/.openclaw/workspace-<instance-id>/`
2. Copy template files as starting point
3. Apply instance-specific customizations (name, role tuning, etc.)
4. Create optional skill config file:
   - `BUILTIN_SKILLS` — one bundled skill per line (leave empty = no bundled skills)
5. Copy shared protocols (`RULES.md`, `TEMPLATES.md`) into the workspace

### Step 5: Register Instance (L3 — requires user confirmation)
1. Run:
   - `bash ./skills/hrbp-recruit/scripts/add-agent.sh <instance-id>`
   - Optional bind: `--bind <channel>:<accountId>`
   - Optional bundled skills override: `--builtin-skills <skill1,skill2>`
2. This will:
   - Add instance to `agents.list` in openclaw.json
   - Update Main Agent's `subagents.allowAgents`
   - Add binding if specified
   - Default: inherit all enabled global skills + workspace skills (no `skills` field)
   - If workspace has `DENIED_SKILLS`: write filtered `skills` allowlist = enabled global minus denied + workspace skills
   - If `--builtin-skills` is provided: write explicit whitelist (workspace skills + selected bundled skills)
   - Update Main Agent's MEMORY.md roster

### Step 6: Update HRBP Memory
- Add entry to Instance Registry in MEMORY.md:
  - Instance ID, source template, creation date, notes

### Step 7: Closeout
Report to the user:
- Instance ID and name
- Source template
- Workspace location
- Route mode (spawn / binding / both)
- Remind: restart Gateway to activate (`./scripts/dev.sh gateway`)

## Notes
- Always present the proposal before generating files
- Use existing templates when possible — avoid creating unnecessary new templates
- Instance IDs must be unique, lowercase, hyphenated
- The workspace directory must exist before running add-agent.sh
- Same template can be instantiated multiple times with different IDs
