# HRBP Agent — Memory

## Template Library
Browse templates at: `~/.openclaw/hrbp-templates/index.md`

## Active Directory
- Current active crew directory: `~/.openclaw/TEAM_DIRECTORY.md`
- A local copy is synced to this workspace as `TEAM_DIRECTORY.md`
- Recruit/modify/remove operations must keep this directory synchronized

### Built-in Templates (managed by setup-crew.sh, not HRBP)
- `main` — Team dispatcher and router
- `hrbp` — Agent lifecycle management (this agent)
- `it-engineer` — OFB system deployment, maintenance, upgrade

### Official Templates
- `customer-service` — Customer support, issue resolution, escalation
- `developer` — Software development, debugging, code review
- `content-writer` — Content creation, social media, marketing copy
- `market-analyst` — Market research, competitive analysis, trend insights
- `operations` — Workflow optimization, task tracking, resource coordination

### User-created Templates
(Updated when new templates are created)

Scaffold template for new roles: `~/.openclaw/hrbp-templates/_template/`

## Protected Agents
These agents cannot be deleted or multi-instantiated:
- `main` — Team dispatcher
- `hrbp` — This agent (self)
- `it-engineer` — System IT engineer

## Instance Registry
(Updated after each recruit/modify/dismiss operation)

| Instance ID | Template | 创建日期 | 备注 |
|-------------|----------|----------|------|

## Operation History
(Updated after each recruit/modify/dismiss operation)
