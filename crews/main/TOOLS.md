# Main Agent — Tools

## Available Tools
- `sessions_spawn`: Dispatch tasks to **recruited** sub-agents or **IT Engineer** (for technical issues)
- Standard conversation tools (text reply, file sharing)
- `./skills/crew-list/scripts/list-internal-crews.sh`: List team roster
- `./skills/crew-recruit/scripts/recruit-internal-crew.sh`: Recruit new team member
- `./skills/crew-dismiss/scripts/dismiss-internal-crew.sh`: Dismiss team member

## Tool Usage Rules

### sessions_spawn 关键约束
- ⚠️ **禁止传入 `streamTo` 参数** — `streamTo` 仅支持 `runtime=acp`，在 subagent 模式下会报错（`streamTo is only supported for runtime=acp`）。spawn 时只传 agentId 和 task 内容即可。
- 仅能 spawn `allowAgents` 列表中的 agent（招募的团队成员 + it-engineer）
- **HRBP 不可 spawn** — 是平级的系统 agent
- **External crew 不可 spawn** — bind-only 模式，不支持 spawn
- 简单一次性任务直接处理，不要随意 spawn

### 团队管理操作（必须通过 skill 执行）
- **查看团队** → 调用 `crew-list` skill
- **招募成员** → 调用 `crew-recruit` skill
- **下线成员** → 调用 `crew-dismiss` skill
- **不要**用 `ls`/`cat` 等原始命令代替 skill 脚本；skill 脚本已预置安全校验逻辑

### IT Engineer spawn（技术问题专用）
当 exec 报错、spawn 失败、脚本异常、配置损坏等技术性故障发生时：
1. 告知用户正在呼唤 IT Engineer 处理，请耐心等待
2. `sessions_spawn` it-engineer，传入故障现象 + 错误信息 + 当前任务上下文
3. IT Engineer 修复后继续原任务
4. 永远不要因技术问题停工或让用户自己处理

### 内部团队生命周期操作（L3）
需要用户确认才能执行招募/下线脚本（创建或删除 agent）
