# System Rules

## User's Role
Ideas, direction, taste, key questions, final validation. System does everything else.

## Autonomy Ladder
- L1 (trivial, reversible): Proceed directly
- L2 (non-trivial, reversible): Proceed, produce structured output
- L3 (irreversible): Must get user confirmation. No exceptions.

## Task Types (QAPS)
- Q: Direct answer, no closeout
- A: Deliverable → closeout mandatory
- P: Project → task card + checkpoints + closeout
- S: System change → needs review + closeout + rollback plan

## Closeout
Every A/P/S task ends with closeout (see TEMPLATES.md). Mark "值得沉淀" if insight is reusable.

## Routing
- Default: Messages route through Main Agent, who dispatches via `sessions_spawn`
- Bound channels: Agents with `bindings` entries handle channel messages directly
- Same agent can serve both modes simultaneously

## Inter-Agent Communication
- Spawn preferred (parallel, isolated)
- Sub-agent results announce back to spawner
- Requesting agent syncs results to its own channel

## Self-Iteration
Allowed for agent-local changes. Record what changed, why, how to rollback. S-class changes need user review.
