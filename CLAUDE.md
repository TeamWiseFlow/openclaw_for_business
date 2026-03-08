# OpenClaw for Business - Claude Code 项目规则

## 项目概述

本项目旨在为上游 [openclaw/openclaw](https://github.com/openclaw/openclaw) 提供一套优雅的“强化机制”。包括：
- Crew 机制：利用 openclaw 自有的 spawn session 机制，创建多 crew，每个 crew 都是一个配备了不同 rules、skills 的 agent。这样的目的是任务执行更专业、更省 token、更快！（因为不需要每个 session 都带全部的规则和 skills）；
- Addon 机制：可以加载 addon 包，每个 addon 包均可以提供对于 openclaw 原版的依赖修改、源代码修改，增加extension/plugin、全局 skill 或者 crew。
- 最佳实践的配置模板和一系列“一键”脚本

注意：
- 本代码仓不直接修改上游 openclaw 的源码，所有增强均需通过上述两个机制实现。
- 本代码仓会内置多个 crew（目前只有 hrbp，后面会逐步增加）。
- 本代码仓本身不包含任何 addon，仅仅提供应用 addon 的能力。未来基于这种能力，我们将打造一套开放的“addon”共享社区。

## 项目结构

为了便于开发理解，你应该在代码仓根目录clone 一份上游 openclaw的代码，但不要修改它，也不要把它加入 git 的 track。

```
openclaw_for_business/
├── openclaw/              # 上游仓库（git clone，禁止直接修改）
├── crew/                  # 多 Agent 系统（内置核心，非 addon）
│   ├── shared/            # 共享协议（RULES.md、TEMPLATES.md）
│   ├── workspaces/        # Agent workspace 模板
│   │   ├── main/          # Main Agent（路由调度器）
│   │   └── hrbp/          # HRBP Agent（默认预制的第一个 Agent）
│   │       └── skills/    # HRBP 专属技能（recruit/modify/remove/list/usage）
│   └── role-templates/    # 角色参考模板（供 HRBP 招聘时使用）
├── skills/                # 全局共享技能（所有 Agent 可见）
├── addons/                # 第三方 addon 安装目录（.gitignore 不跟踪子目录）
├── config-templates/      # 配置模板（版本控制）
│   └── openclaw.json      # 默认配置模板
├── scripts/               # 工具脚本（这里面的脚本是给人类用户用的，务必少而精。具体 agent 使用的脚本放入对应的 skill 中，基础通用类的放在这下面的 lib/）
│   ├── lib/               # 通用基础类脚本
│   ├── dev.sh             # 开发模式启动（自动安装 Agent 系统）
│   ├── setup-crew.sh      # 多 Agent 系统安装（幂等）
│   ├── apply-addons.sh    # 全局 skills + 通用 addon 加载器
│   ├── update-upstream.sh # 更新上游代码 + 重新应用 addon
│   ├── reinstall-daemon.sh  # 生产模式安装后台服务
│   └── setup-wsl2.sh       # WSL2 环境配置
└── docs/                  # 项目文档
```

运行时数据使用上游默认位置 `~/.openclaw/`。

## 核心规则

### 1. config-templates 是最佳实践基准

`config-templates/openclaw.json` 是本项目的核心产出之一，目标是让其他用户能开箱即用。

- 每当实际运行配置（`~/.openclaw/openclaw.json`）经过验证可正常工作后，**必须将结构和最佳实践同步回 config-templates**
- 敏感信息（apiKey、appSecret、auth token 等）在模板中留空，但字段结构必须保留

### 2. 多 Agent 系统（crew/）

`crew/` 是项目的核心组件，定义了内置的多 Agent 系统：

- **不是 addon** — 它是项目的默认预设，dev.sh 和 reinstall-daemon.sh 会自动安装
- **HRBP 是第一个预制 Agent** — 负责 Agent 的生命周期管理（招聘/调岗/解雇）
- **Main Agent 是路由调度器** — 负责消息路由和子 Agent 调度，并作为托底任务执行者
- 每个 Agent workspace 包含 8 个 .md 文件（SOUL/AGENTS/MEMORY/USER/IDENTITY/TOOLS/TASKS/HEARTBEAT）和可选 `DENIED_SKILLS`
- **技能两级体系**（与 OpenClaw 原生机制对齐）：
  - 全局共享：`skills/`（项目根目录）→ 安装到 `openclaw/skills/`，所有 Agent 可见
  - Agent 专属：`crew/workspaces/<agent>/skills/` → 安装到 `~/.openclaw/workspace-<agent>/skills/`，仅该 Agent 可见
  - **默认开放策略**：全部已启用内置 skill 对所有 Agent 开放，无需白名单配置
    - `agents.list[].skills` 字段默认不设置（openclaw 原生行为：所有已启用 skill 可见）
    - 如需屏蔽特定 skill，在 workspace 中放置 `DENIED_SKILLS` 文件（每行一个 skill 名称）
    - 有屏蔽列表时，`setup-crew.sh` 自动计算 allowlist = 全部内置 - 屏蔽列表，写入 `agents.list[].skills`
  - **精简内置 skill 集**：`config-templates/openclaw.json` 中通过 `skills.entries` 禁用平台无关 skill
    - 禁用的是个人工具类（苹果生态、智能家居、社交软件等），保留通用工具
    - `apply-addons.sh` 每次运行时将禁用列表同���到 `~/.openclaw/openclaw.json`，确保升级后一致

飞书渠道直连架构：
- 每个 Agent 绑定一个独立的飞书 Bot（通过 `channels.feishu.accounts` 多账户配置）
- 通过 `bindings[]` 将飞书账户（accountId）路由到指定 Agent
- 上游 feishu extension 原生支持多账户并行 WebSocket 监听、流式卡片回复、文档/云盘/知识库操作

关键概念：
- `agents.list[]` — Agent 注册表（id、name、workspace、subagents）
- `bindings[]` — 渠道绑定配置（模式 B 直连）
- `main` 和 `hrbp` 是受保护的系统 Agent，不可删除
- HRBP 内部运维脚本放在 `crew/workspaces/hrbp/skills/*/scripts/`，`scripts/` 目录仅保留人类用户主入口脚本

详见 `docs/crew-system.md`。

### 4. Addon 机制

能力扩展通过 addon 实现，addon 是独立仓库(本项目本身不含任何具体 addon 的开发），安装到 `addons/` 目录。
**`addons/` 子目录被 .gitignore 忽略**，避免把第三方 addon 同步到代码仓。

addon 四层加载机制（按稳定性递减）：
1. **overrides.sh** — pnpm overrides / 依赖替换（最稳健，不依赖行号）
2. **patches/*.patch** — git patch 精确代码改动（上游更新时可能需调整）
3. **skills/*/SKILL.md** — 全局技能安装（默认仅 main Agent 可见）
4. **crew/<agent-id>/** — 预制 Agent（workspace + Agent 专属 skills），由 HRBP 管理

addon 中的技能分两级：根目录 `skills/` 为全局技能；`crew/<agent>/skills/` 为 Agent 专属技能。
预制 Agent 会被自动安装并注册到系统中，由 HRBP Agent 统一管理。

详见 `scripts/apply-addons.sh`。

### 5. 数据存储

运行时数据使用上游默认位置 `~/.openclaw/`，不做路径覆盖：
- 配置文件：`~/.openclaw/openclaw.json`
- 凭证：`~/.openclaw/credentials/`
- 工作区：`~/.openclaw/workspace/`

Agent 系统安装后额外目录：
- Agent workspace：`~/.openclaw/workspace-<agent-id>/`（每个 Agent 独立 workspace）
- 角色模板：`~/.openclaw/hrbp-templates/`（供 HRBP 招聘时参考）
- 归档目录：`~/.openclaw/archived/`（已移除 Agent 的 workspace 归档）

## 常用命令

```bash
# 开发模式（前台，自动安装 Agent 系统 + 应用 addon）
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

# Agent 管理
./scripts/setup-crew.sh              # 手动安装/重装 Agent 系统
./scripts/setup-crew.sh --force      # 覆盖已有 workspace
./scripts/setup-crew.sh --denied-skills hrbp:slack,github  # 为指定 agent 屏蔽特定内置 skill
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
4. **upstream**（TeamWiseflow 正式仓库）每次合并 PR 后自动更新版本号并触发 release 打包发布

注：有时我会通过在 .claude/ 中留下 TODO.md 的方式下发开发任务，这些任务你完成后需要把 TODO.md 改名为 {date}_done.md

## Permissions

Claude Code 被授权在本仓库中执行任何 git 命令（包括 push、branch、tag 等），无需逐次确认。

### 版本管理

版本号存储在 `version` 文件中，格式为 `vMAJOR.MINOR.PATCH`。当 PR 合并到 upstream 的 master 时，GitHub Action 自动递增版本号并创建 Release。通过 PR 标签控制递增类型：
- `major` 标签 → 大版本升级
- `minor` 标签 → 功能版本升级
- 无标签或 `patch` 标签 → 补丁版本升级（默认）

**不要手动修改 `version` 文件**，由 CI 自动维护。
