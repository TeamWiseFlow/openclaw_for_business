# HRBP Agent System

## 概述

HRBP Agent System 是一套多 Agent 管理系统，采用**混合路由模式**：

- **模式 A（统一入口）**：用户通过飞书 Bot 与 Main Agent 对话，Main Agent 通过 `sessions_spawn` 分发给子 Agent
- **模式 B（渠道直连）**：子 Agent 通过 OpenClaw 原生 `bindings` 直接绑定到特定渠道（如微信）

同一个子 Agent 可以同时被两种方式使用。

## 架构

```
模式 A: 飞书用户 → Bridge → Gateway → Main Agent → spawn 子 Agent
模式 B: 微信用户 → OpenClaw channel → Gateway bindings → 子 Agent（直接响应）
```

**进程模型**：Gateway 单进程，所有 Agent 在内部运行（逻辑隔离）。

## 核心组件

### Main Agent（路由器/调度员）
- 接收用户消息，判断意图
- 通过 `sessions_spawn` 分发给对应子 Agent
- 汇报子 Agent 结果
- 不确定时询问用户

### HRBP Agent（预制子 Agent）
- 管理 Agent 完整生命周期：招聘（创建）、调岗（修改）、解雇（删除）
- 受保护，不可删除
- 三个 Skill：`hrbp-recruit`、`hrbp-modify`、`hrbp-remove`

### Bridge（飞书连接器）
- 单飞书 Bot → 单 Main Agent
- 入站：解析 `@alias` 路由提示
- 出站：添加 `[AgentName]` 前缀标识

## Workspace 结构

每个 Agent 的 workspace 包含 8 个文件：

| 文件 | 用途 |
|------|------|
| SOUL.md | 角色定位、身份边界 |
| AGENTS.md | 工作流和流程 |
| MEMORY.md | 长期记忆和上下文 |
| USER.md | 用户偏好 |
| IDENTITY.md | 名称、个性、声音 |
| TOOLS.md | 可用工具和使用规则 |
| TASKS.md | 活跃项目追踪 |
| HEARTBEAT.md | 健康状态 |

## 共享协议

- **RULES.md** — Autonomy Ladder (L1/L2/L3)、QAPS 任务分类、Closeout 规范
- **TEMPLATES.md** — Closeout 和 Checkpoint 模板

## 脚本

| 脚本 | 用途 |
|------|------|
| `setup-hrbp.sh` | 首次安装（部署 workspace、模板、配置） |
| `add-agent.sh` | 注册新 Agent |
| `modify-agent.sh` | 修改 Agent 渠道绑定 |
| `remove-agent.sh` | 移除 Agent（workspace 归档） |
| `list-agents.sh` | 列出所有 Agent 及状态 |

## 配置

Agent 配置在 `~/.openclaw/openclaw.json` 中：

- `agents.list[]` — Agent 列表（id、name、workspace、subagents）
- `bindings[]` — 渠道绑定（模式 B 直连）

## 路由模式

| 模式 | 说明 | 配置 |
|------|------|------|
| spawn | 通过 Main Agent 路由 | `allowAgents` 列表 |
| binding | 渠道直连 | `bindings[]` 条目 |
| both | 两种方式共存 | 同时配置 |
