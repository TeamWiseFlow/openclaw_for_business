# 多 Agent 系统架构

## 概述

多 Agent 系统是 openclaw-for-business 的核心组件，定义在项目根目录的 `crew/` 中。

核心理念：通过预制一系列具有不同专业角色定义、Rules 定义和技能配比的 Agent，实现：
1. **任务专业性** — 每个 Agent 聚焦特定领域
2. **并行处理** — 利用 OpenClaw 的 `sessions_spawn` 把任务拆到子进程完成

采用**混合路由模式**：
- **模式 A（统一入口）**：用户通过飞书 Bot 与 Main Agent 对话，Main Agent 通过 `sessions_spawn` 分发给子 Agent
- **模式 B（渠道直连）**：子 Agent 通过 OpenClaw 原生 `bindings` 直接绑定到特定渠道（如微信）

同一个子 Agent 可以同时被两种方式使用。

## 架构

```
模式 A: 飞书用户 → Bridge → Gateway → Main Agent → spawn 子 Agent
模式 B: 微信用户 → OpenClaw channel → Gateway bindings → 子 Agent（直接响应）
```

**进程类型**：Gateway 单进程，所有 Agent 在内部以子进程模式运行（逻辑隔离）。

## 源码结构（crew/）

```
crew/
├── shared/            # 共享协议（所有 Agent 共用）
│   ├── RULES.md       # Autonomy Ladder (L1/L2/L3)、QAPS 任务分类
│   └── TEMPLATES.md   # Closeout 和 Checkpoint 模板
├── workspaces/        # 内置 Agent 的 workspace 模板
│   ├── main/          # Main Agent（路由调度器）
│   └── hrbp/          # HRBP Agent（默认预制的第一个 Agent）
│       └── skills/    # HRBP 专属技能
│           ├── hrbp-recruit/  # 招聘新 Agent
│           ├── hrbp-modify/   # 修改已有 Agent
│           ├── hrbp-remove/   # 移除 Agent
│           ├── hrbp-list/     # 花名册/路由状态查询
│           └── hrbp-usage/    # 用量与成本统计
└── role-templates/    # 角色参考模板（供 HRBP 招聘时使用）
    ├── _template/     # 空白模板（8 个 .md + BUILTIN_SKILLS）
    ├── developer.md
    ├── customer-service.md
    ├── market-analyst.md
    ├── content-writer.md
    └── operations.md

skills/                # 全局共享技能（项目根目录，所有 Agent 可见）
```

### 技能两级体系

与 OpenClaw 原生 skill 加载机制对齐：

| 级别 | 位置 | 安装到 | 可见范围 |
|------|------|--------|----------|
| 全局共享 | `skills/`（项目根目录） | `openclaw/skills/` | 所有 Agent |
| Agent 专属 | `crew/workspaces/<agent>/skills/` | `~/.openclaw/workspace-<agent>/skills/` | 仅该 Agent |

最终每个 Agent 可见的技能集合为：
- `workspace skills` + `agents.list[].skills` 中允许的内置 skills
- 非 main agent 默认仅启用 workspace skills
- main 默认启用全部内置 skills

## 核心组件

### Main Agent（路由器/调度员）
- 接收用户消息，判断意图
- 优先通过 `sessions_spawn` 分发给对应子 Agent
- 汇报子 Agent 结果
- 没有匹配 crew 时才自己处理
- 不确定时询问用户

### HRBP Agent（默认预制的第一个 Agent）
- 管理 Agent 完整生命周期：招聘（创建）、调岗（修改）、解雇（删除）
- 受保护，不可删除
- 五个 Skill：`hrbp-recruit`、`hrbp-modify`、`hrbp-remove`、`hrbp-list`、`hrbp-usage`

## Agent 来源

Agent 有三种创建方式：

1. **内置预制**：`crew/workspaces/` 中定义的 Agent（main、hrbp），随 `dev.sh` / `reinstall-daemon.sh` 自动安装
2. **HRBP 创建**：用户通过与 HRBP Agent 对话，根据需求创建定制化 Agent（默认方式）
3. **Addon 预制**：第三方 addon 通过 `crew/` 目录贡献预制 Agent，由 `apply-addons.sh` 自动安装并注册，由 HRBP 统一管理

## Workspace 结构

每个 Agent 的 workspace 包含 8 个核心文件（可选 `BUILTIN_SKILLS`）：

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
| BUILTIN_SKILLS（可选） | 启用的内置 skill（每行一个，不填=仅 workspace skills） |

## 共享协议

- **RULES.md** — Autonomy Ladder (L1/L2/L3)、QAPS 任务分类、Closeout 规范
- **TEMPLATES.md** — Closeout 和 Checkpoint 模板

## 脚本

| 脚本 | 用途 |
|------|------|
| `setup-crew.sh` | 安装多 Agent 系统（部署 workspace、模板、配置，幂等） |
| `crew/workspaces/hrbp/skills/hrbp-recruit/scripts/add-agent.sh` | HRBP 内部：注册新 Agent |
| `crew/workspaces/hrbp/skills/hrbp-modify/scripts/modify-agent.sh` | HRBP 内部：修改 Agent 渠道绑定 |
| `crew/workspaces/hrbp/skills/hrbp-remove/scripts/remove-agent.sh` | HRBP 内部：移除 Agent（workspace 归档） |
| `crew/workspaces/hrbp/skills/hrbp-list/scripts/list-agents.sh` | HRBP 内部：列出所有 Agent 及状态 |
| `crew/workspaces/hrbp/skills/hrbp-usage/scripts/agent-usage.sh` | HRBP 内部：统计 Agent 用量与成本 |

## 配置

Agent 配置在 `~/.openclaw/openclaw.json` 中：

- `agents.list[]` — Agent 列表（id、name、workspace、subagents）
- `agents.list[].skills` — Agent skill 白名单（workspace skills + 指定内置 skills）
- `bindings[]` — 渠道绑定（模式 B 直连）

## 路由模式

| 模式 | 说明 | 配置 |
|------|------|------|
| spawn | 通过 Main Agent 路由 | `allowAgents` 列表 |
| binding | 渠道直连 | `bindings[]` 条目 |
| both | 两种方式共存 | 同时配置 |
