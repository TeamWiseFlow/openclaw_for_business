# openclaw-for-business

打造能帮用户挣钱的"小龙虾"。

```text
"我一直认为，普遍用户的核心需求，不是生产力，而是赚钱（还有个普遍的核心需求是情感）。"
———— PENG Bo（rwkv.com rwkv.cn 创始人）https://www.zhihu.com/people/bopengbopeng
```

小龙虾很强，能够帮你收发邮件、写报告……但是讲真，这真是你需要的吗？或者说这是你可能付费的吗？

它既然都能做这么多事情了，为什么不能用它来帮我们"搞钱"？

**本项目的目的不是为你增加一个“个人助理”，而是为你打造一直“云上牛马”团队，可以 7*24 小时给你在线搞钱的那种！**

我们会不断更新代码，如果你有具体思路或想法也欢迎进群讨论，可以先添加作者微信：bigbrother666sh

## 为此我们做了什么？

相较于原版 [OpenClaw](https://github.com/openclaw/openclaw)，我们提供如下增强：

- **配置模板** — 预设国内可用的模型、渠道、技能等配置
- **工具脚本** — 一键启动、一键部署、一键更新
- **多 crew 机制** — 采用 `Template → Instance` 模型，你拥有的不再是一个“私人助理”，而是一个“团队”。系统内置三个全局 Crew：`main`（路由调度）、`hrbp`（生命周期管理）、`it-engineer`（系统运维）。你可以通过 HRBP 按模板持续招聘/调整/停用更多业务 Crew（如财务、自媒体运营、情报官等）
- **Addon 机制** — 通过标准化的 addon 加载器，按需安装第三方能力增强包，可以通过 marketplace 安装社区开源的 Skill、Crew 等

### 🌇 Addon 生态（marketplace）

能力增强通过独立的 addon 仓库提供，各团队可独立维护：

| Addon | 说明 | 仓库 |
|-------|------|------|
| [wiseflow](https://github.com/TeamWiseFlow/wiseflow) | 浏览器反检测 + 互联网能力增强 | `addons/` 目录 |

> 欢迎贡献更多 addon！参见下方 [Addon 开发](#addon-开发) 章节。

我们已经规划了 Add-on Marketplace, 预计将于 2026.4 月上线，不同于 openclaw clawhub，这是一个专门提供搞钱技能和能帮你搞钱的 crew 的市场，敬请期待！

## 项目结构

```
openclaw_for_business/
├── openclaw/              # 上游仓库（git clone，禁止直接修改）
├── crews/                 # Crew 模板库 + 内置 Crew（Template → Instance 模型）
│   ├── shared/            # 共享协议（RULES.md、TEMPLATES.md）
│   ├── _template/         # 空白脚手架（创建新模板的起点）
│   ├── index.md           # 模板注册表（HRBP 维护）
│   ├── main/              # [built-in] Main Agent（路由调度器）
│   ├── hrbp/              # [built-in] HRBP（Crew 生命周期管理）
│   │   └── skills/        # HRBP 专属技能（recruit/modify/remove/list/usage）
│   ├── it-engineer/       # [built-in] IT Engineer（系统运维）
│   ├── customer-service/  # [official] 客服模板
│   ├── developer/         # [official] 开发者模板
│   └── ...                # 更多官方模板
├── skills/                # 全局共享技能（所有 Agent 可见）
├── addons/                # 第三方 addon 安装目录（不跟踪子目录）
├── config-templates/      # 配置模板（开箱即用的最佳实践）
│   └── openclaw.json      # 默认配置模板
├── scripts/               # 工具脚本
│   ├── dev.sh             # 开发模式启动（自动安装 crew 系统 + addon）
│   ├── setup-crew.sh      # 多 crew 系统安装（幂等）
│   ├── apply-addons.sh    # 全局 skills + addon 加载器
│   ├── upgrade.sh         # 升级 OFB + openclaw 引擎（推荐入口）
│   ├── update-upstream.sh # [已废弃] 等价于 upgrade.sh
│   ├── reinstall-daemon.sh # 生产模式安装后台服务
│   ├── generate-patch.sh  # 生成补丁（给 addon 开发者用）
│   └── setup-wsl2.sh      # WSL2 环境配置
└── docs/                  # 项目文档
```

运行时数据使用上游默认位置 `~/.openclaw/`。

## 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/TeamWiseFlow/openclaw_for_business.git
cd openclaw_for_business
source ./openclaw.version
git clone https://github.com/openclaw/openclaw.git openclaw
git -C openclaw checkout "$OPENCLAW_COMMIT"
```

或者直接在 release 页面下载打包（已经整合了上游 openclaw）

### 2. 安装 addon（可选）

将 addon 发布文件放到 `addons/` 目录：

```bash
# 例：安装 wiseflow addon（浏览器反检测 + 互联网能力增强）
git clone https://github.com/TeamWiseFlow/wiseflow/
拷贝 wiseflow 代码仓下的 wiseflow/ 文件夹 放入 addons/
```

### 3. 安装依赖

```bash
cd openclaw
pnpm install
cd ..
```

### 4. 启动

```bash
# 开发模式（前台运行）
./scripts/dev.sh gateway

# 浏览器访问 http://127.0.0.1:18789
```

首次启动时，`dev.sh` 会：
1. 自动从 `config-templates/` 创建默认配置到 `~/.openclaw/openclaw.json`
2. 自动安装多 crew 系统和三个全局默认 crew（Main Agent + HRBP + IT Engineer）
3. 自动安装 crew 内置技能 + 扫描并应用所有 addon

## 部署后怎么用（推荐流程）

### 1) 最小可用：只配置 Main Agent 一个 channel

最小配置可以只接入 `main`（例如只配置一个飞书机器人），先让所有请求都进 Main，再由 Main 分发给其他 Crew。

你可以在消息里直接用 **强制路由前缀** 指定处理人：

```text
@it-engineer 帮我检查 gateway 日志
@hrbp 帮我招聘一个客服 crew
```

也支持完整写法：

```text
[Route: @it-engineer] 帮我检查 gateway 日志
```

### 2) 先让 IT Engineer 帮你完成系统配置

部署后建议先找 `it-engineer` 做基础配置和巡检，例如：
- 模型/API 配置检查
- channel 连接状态检查
- 日志排查与升级建议
- 日常维护操作（重启、更新、故障恢复）

### 3) 通过 HRBP 招募新 Crew

`hrbp` 是唯一的生命周期管理入口（招聘、调岗、停用）。推荐直接描述你的业务目标，例如：

```text
@hrbp 我需要一个“短视频运营”crew，先不绑定独立 channel，走 Main 分发
```

HRBP 会完成模板匹配/实例化/注册，并把结果同步到团队通讯录。

### 4) 常用 Crew 建议单独绑定 channel（推荐）

最小模式（只配 Main）适合起步；当某些 Crew 进入高频使用后，建议给它们单独绑定 channel：
- 好处：沟通更直接、上下文更稳定、减少 Main 的中转噪音
- 同时保留 Main 分发能力（`spawn` + `binding` 可共存）

### 5) 查看团队通讯录

部署后系统会自动维护 `~/.openclaw/TEAM_DIRECTORY.md`，记录当前启用 Crew 的：
- ID
- 名称
- 职责（从 IDENTITY.md 提取）
- 路由方式（spawn/binding/both）
- 绑定渠道

### 6) 3 分钟上手示例对话（可直接照抄）

如下都是你发给 main agent 的：

```text
你：@it-engineer 帮我检查当前配置是否可用，重点看模型和飞书连接

你：@hrbp 我需要一个“短视频运营”crew，先不绑定独立 channel，走 Main 分发

你：@main 把今天要发的短视频选题交给短视频运营 crew

你：@hrbp 给 short-video-ops 绑定一个单独的飞书账号 short-video-bot

你：@short-video-ops 以后你直接负责我的短视频选题、脚本和发布时间建议

你：@it-engineer 帮我确认 TEAM_DIRECTORY.md 里 short-video-ops 的路由状态和绑定是否正确
```

说明：
- 第 1 句先让 IT Engineer 做基础体检
- 第 2 句由 HRBP 招聘新 crew（生命周期变更只走 HRBP）
- 第 3 句在 Main 模式下调度新 crew
- 第 4 句由 HRBP 给新 crew 绑定独立 channel，升级为”直连”模式
- 第 5 句仍然发到 Main channel 中，由 Main 路由到 short-video-ops（如需跳过 Main 中转，请使用绑定后的独立 channel 直接对话）
- 第 6 句用 IT Engineer 做最终核验

### 生产部署

```bash
# 构建 + 安装后台服务（自动启动 + 开机自启 + 崩溃重启）
cd openclaw && pnpm build && cd ..
./scripts/reinstall-daemon.sh
```

日后升级只需要执行：

```bash
./scripts/upgrade.sh
```

## 常用命令

```bash
./scripts/dev.sh gateway              # 开发模式启动
./scripts/dev.sh gateway --port 18789 # 指定端口
./scripts/dev.sh cli config           # CLI 操作
./scripts/upgrade.sh                  # 升级 OFB + openclaw 引擎
./scripts/reinstall-daemon.sh         # 生产部署

# Agent 管理
./scripts/setup-crew.sh               # 手动安装/重装 Agent 系统
./scripts/setup-crew.sh --force       # 覆盖已有 workspace
./scripts/setup-crew.sh --denied-skills hrbp:slack,github
```

## 原版 openclaw 的 Skill 机制过于臃肿，且不符合国内实情，OFB 做了如下优化：

OFB 不再采用“空 `agents.list[].skills` = 继承全量内置技能”的方式，而是**始终写入每个 Agent 的 skills allowlist**。

- 全局基线技能（默认所有 Agent 都有，含 HRBP 新招实例）：
  - 上游内置：`1password`、`healthcheck`、`model-usage`、`nano-pdf`、`skill-creator`、`ordercli`、`session-logs`、`tmux`、`weather`、`xurl`、`video-frames`
  - OFB 额外新增：`self-improving`
- 非基线上游技能默认从“全员默认配备”中剔除，仅可通过 `BUILTIN_SKILLS` / `--builtin-skills` 按 Agent 追加。
- addon 若提供 `skills/`（全局 skills），默认对所有 agent 可见；addon 若提供 `crew/<template>/skills/`，仅该 crew 实例可见。
- `DENIED_SKILLS` 始终作为最终裁剪层（从“基线 + 追加”里减掉指定 skill）。
- `it-engineer` 与 `developer` 模板默认追加：`github`、`gh-issues`、`coding-agent`。

当前从上游默认全员集合中剔除的内置 skill（如需可按 Agent 追加）：

```text
apple-notes
apple-reminders
bear-notes
blogwatcher
blucli
bluebubbles
browser-guide
camsnap
canvas
clawhub
coding-agent
discord
eightctl
gemini
gh-issues
gifgrep
github
gog
goplaces
himalaya
imsg
mcporter
nano-banana-pro
notion
obsidian
openai-image-gen
openai-whisper
openai-whisper-api
openhue
oracle
peekaboo
sag
sherpa-onnx-tts
slack
songsee
sonoscli
spotify-player
summarize
things-mac
trello
voice-call
wacli
```

Agent 生命周期（新增/调岗/移除/消耗统计）由 HRBP skill 执行，内部脚本位于 `crews/hrbp/skills/*/scripts/`，不作为人类用户主入口。

## Addon 开发

详见 **[addon_development.md](./addon_development.md)**（英文），涵盖：

- OpenClaw 版本锁定机制（`openclaw.version` 文件的读取方式）
- Addon 目录结构和 `addon.json` 规范
- 四层加载机制（overrides → patches → skills → crew）
- 本地开发与测试流程
- 发布与上架方式

## 文档

- [多 crew 系统架构](docs/crew-system.md) - 架构设计和组件说明
- [快速上手](docs/quick-start.md) - 安装和使用指南
- [OpenClaw 分析](docs/introduce_to_clawd_by_claude.md) - 上游代码架构分析
- [Crews v2 设计文档](crews/DESIGN.md) - Template → Instance 机制与完整设计细节

## 许可证

MIT License
