# OpenClaw for Business - Claude Code 项目规则

## 项目概述

OpenClaw 的"最佳实践"预配置项目，基于上游 [openclaw/openclaw](https://github.com/openclaw/openclaw) 构建。通过配置模板和 addon 机制在不修改上游代码的前提下实现能力扩展。

## 项目结构

```
openclaw_for_business/
├── openclaw/              # 上游仓库（git clone，禁止直接修改）
├── addons/                # addon 安装目录（运行时由 apply-addons.sh 扫描）
│   └── hrbp-system/      # 多 Agent 管理系统 addon（skills）
├── config-templates/      # 配置模板（版本控制）
│   ├── openclaw.json     # 默认配置模板
│   └── hrbp-system/      # HRBP 系统模板
│       ├── shared/        # 共享规则（RULES.md、TEMPLATES.md）
│       ├── workspaces/    # Main 和 HRBP 的 workspace 模板
│       └── role-templates/ # 角色参考模板（供 HRBP 招聘时使用）
├── bridge/               # 飞书 Bridge（飞书 Bot <-> Gateway 连接器）
├── scripts/              # 工具脚本
│   ├── dev.sh            # 开发模式启动（前台运行）
│   ├── apply-addons.sh   # 通用 addon 加载器
│   ├── setup-hrbp.sh     # HRBP 系统首次安装
│   ├── add-agent.sh      # 注册新 Agent
│   ├── modify-agent.sh   # 修改 Agent 渠道绑定
│   ├── remove-agent.sh   # 移除 Agent（workspace 归档）
│   ├── list-agents.sh    # 列出所有 Agent 及状态
│   ├── update-upstream.sh # 更新上游代码 + 重新应用 addon
│   ├── reinstall-daemon.sh  # 生产模式��装后台服务
│   ├── generate-patch.sh    # 生成补丁（给 addon 开发者用）
│   ���── setup-wsl2.sh       # WSL2 环境配置
└── docs/                 # 项目文档
```

运行时数据使用上游默认位置 `~/.openclaw/`。

## 核心规则

### 1. config-templates 是最佳实践基准

`config-templates/openclaw.json` 是本项目的核心产出之一，目标是让其他用户能开箱即用。

- 每当实际运行配置（`~/.openclaw/openclaw.json`）经过验证可正常工作后，**必须将结构和最佳实践同步回 config-templates**
- 敏感信息（apiKey、appSecret、auth token 等）在模板中留空，但字段结构必须保留
- 模板应始终反映当前已验证的最佳配置结构，不得落后于实际运行配置

### 2. 禁止操作

- **禁止直接修改 `openclaw/` 目录** - 所有对上游的修改必须通过 addon 的 patches 或 overrides 机制
- **禁止在不理解的情况下删除代码**

### 3. Addon 机制

能力扩展通过 addon 实现，addon 是独立仓库，安装到 `addons/` 目录。

addon 三层加载机制（按稳定性递减）：
1. **overrides.sh** — pnpm overrides / 依赖替换（最稳健，不依赖行号）
2. **patches/*.patch** — git patch 精确代码改动（上游更新时可能需调整）
3. **skills/*/SKILL.md** — 自定义技能安装（独立于源码）

详见 `scripts/apply-addons.sh`。

### 4. 数据存储

运行时数据使用上游默认位置 `~/.openclaw/`，不做路径覆盖：
- 配置文件：`~/.openclaw/openclaw.json`
- 凭证：`~/.openclaw/credentials/`
- 工作区：`~/.openclaw/workspace/`

HRBP 系统安装后额外目录：
- Agent workspace：`~/.openclaw/workspace-<agent-id>/`（每个 Agent 独立 workspace）
- 角色模板：`~/.openclaw/hrbp-templates/`（供 HRBP 招聘时参考）
- 归档目录：`~/.openclaw/archived/`（已移除 Agent 的 workspace 归档）

### 5. HRBP 多 Agent 系统

混合路由架构，两种路由方式共存：
- **模式 A（统一入口）**：飞书 Bot -> Bridge -> Gateway -> Main Agent -> spawn 子 Agent
- **模式 B（渠道直连）**：OpenClaw bindings 将渠道消息直接路由到指定 Agent

关键概念：
- `agents.list[]` — Agent 注册表（id、name、workspace、subagents）
- `bindings[]` — 渠道绑定配置（模式 B 直连）
- `main` 和 `hrbp` 是受保护的系统 Agent，不可删除
- 每个 Agent workspace 包含 8 个 .md 文件（SOUL/AGENTS/MEMORY/USER/IDENTITY/TOOLS/TASKS/HEARTBEAT）

详见 `docs/hrbp-system.md`。

## 常用命令

```bash
# 开发模式（前台，实时编译）
./scripts/dev.sh gateway

# 开发模式指定端口
./scripts/dev.sh gateway --port 18789

# CLI 操作
./scripts/dev.sh cli config

# 生产部署（后台服务）
cd openclaw && pnpm build && cd ..
./scripts/reinstall-daemon.sh

# 更新上游
./scripts/update-upstream.sh

# HRBP 多 Agent 管理
./scripts/setup-hrbp.sh              # 首次安装 HRBP 系统
./scripts/list-agents.sh             # 列出所有 Agent
./scripts/add-agent.sh <id>          # 注册新 Agent
./scripts/modify-agent.sh <id> --bind wechat:wx_xxx  # 添加渠道绑定
./scripts/remove-agent.sh <id>       # 移除 Agent（workspace 归档）
```

## 技术栈

- 运行时：Node.js + pnpm
- 上游项目：TypeScript
- 脚本：Bash
- 默认端口：18789
- 支持平台：macOS (LaunchAgent)、Linux (systemd)、WSL2

## Development Workflow

### 远程仓库

- **origin** → `git@github.com:bigbrother666sh/openclaw_for_business.git`（个人开发仓库）
- **upstream** → `git@github.com:TeamWiseFlow/openclaw_for_business.git`（TeamWiseflow 正式发布仓库）

### 开发流程

1. 默认在 `main` 分支上开发，按需创建功能分支
2. 开发完成后推送到 **origin**（个人仓库）
3. 阶段性成果通过 GitHub PR 从 origin 合并到 **upstream**（TeamWiseflow 正式仓库）

## Permissions

Claude Code 被授权在本仓库中执行任何 git 命令（包括 push、branch、tag 等），无需逐次确认。

## 沟通语言

用户使用中文沟通，回复请使用中文。
