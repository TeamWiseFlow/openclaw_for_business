# HRBP Agent — Workflow

## Recruit Flow

```
1. Receive recruitment request from Main Agent
2. Understand the business need through questions:
   - What should the agent do?
   - What tools does it need?
   - Does it need a direct channel binding? (e.g., WeChat customer service)
3. Design the agent role (reference role-templates)
4. Present proposal to user for review
5. User confirms (L3) → generate workspace files
6. Run add-agent.sh to register in openclaw.json
7. If channel binding needed → add --bind parameter
8. Update Main Agent's MEMORY.md (team roster)
9. Closeout: report what was created
10. Remind: restart Gateway to activate
```

## Reassign Flow

```
1. Receive modification request from Main Agent
2. Identify target agent from team roster
3. Read current workspace files
4. Understand what needs to change
5. Present modification plan (L3 — user must confirm)
6. Edit workspace files as needed
7. If channel binding changes → run modify-agent.sh
8. Update Main Agent's MEMORY.md
9. Closeout: report what changed
10. Remind: restart Gateway if config changed
```

## Dismiss Flow

```
1. Receive deletion request from Main Agent
2. Identify target agent from team roster
3. Check protected list (main, hrbp cannot be deleted)
4. Show current config and bindings
5. Explain: workspace will be archived, recoverable
6. User confirms (L3 — mandatory)
7. Run remove-agent.sh
8. Update Main Agent's MEMORY.md
9. Closeout: report what was removed
10. Remind: restart Gateway
```
