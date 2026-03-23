# openclaw-for-business

打造能帮用户挣钱的"小龙虾"。

```text
"我一直认为，普遍用户的核心需求，不是生产力，而是赚钱（还有个普遍的核心需求是情感）。"
———— PENG Bo（rwkv.com rwkv.cn 创始人）https://www.zhihu.com/people/bopengbopeng
```

openclaw很强，能够帮你收发邮件、写报告……但是讲真，这真是你需要的吗？或者说这是你可能付费的吗？

它既然都能做这么多事情了，为什么不能用它来帮我们"搞钱"？

**本项目的目的不是为你增加一个“个人助理”，而是为你打造一直“云上牛马”团队，可以 7*24 小时给你在线搞钱的那种！**

我们会不断更新代码，如果你有具体思路或想法也欢迎进群讨论，可以先添加作者微信：bigbrother666sh

## 为此我们做了什么？

相较于原版 [OpenClaw](https://github.com/openclaw/openclaw)，我们提供如下增强：

### 多 crew 机制 

说实话，市面上有很多基于 openclaw 的二开项目都支持多 crew（Agent），甚至还支持让这些 crew（Agent） 自主协同，或者带个办公室界面，你能看到他们在一起“过家家”……

我认为这些都太华而不实了! 如果不能搞钱，一个 Agent Team 跟一个 chatbot 一样，只是玩具而已！

实际上你只需要两类 Agent，一类是对内支撑系统正常运转的（我们称之为 内部 crew），一类是能够对外服务，替你挣钱的（我们称之为外部 crew）。

OFB 项目设置了一套简洁明了的机制：

- 对内 crew 默认只有三个（这三个是全局内置性质）：
  - 一个是 Main Agent，负责管理所有对内 crew 的生命周期，你也可以把它当成唯一对话入口，通过它喊其他 Crew 干活；
  - 一个是 IT Engineer，负责帮你搞定 openclaw 繁琐的配置，日常运维（升级、定时心跳检查状态）等，**对，你没看错，只要你完成第一次部署，后面它就可以帮你去做系统配置和运维**
  - 一个是 HRBP，负责帮你招募、管理对外服务 crew，还能帮你周期性质的扫描对外服务 crew 的 feedback，不断升级他们……

  以上三个内置 crew 我们都已经提供了现成的最佳配置（角色定义文件、SKills、权限等）

- 对外 crew，我们会不断推出官方模板，并且后面会引入 marketplace（addon 市场）机制，要启用哪个，你直接让你的 hrbp 去操作，当然你也可以让它帮你创建

内置 crew 模板：
- sales customer service （销售导向客服）
- …… 不断增加中

### Crew 之间的自主协作
  
  我们巧妙的利用了 OpenClaw 的 Spawn Subagent 机制实现了 crew 之间的自主互助能力：

  目前已经默认启用： 所有对内 Crew（internal）都配置了 subagents.allowAgents: ["it-engineer"]，这意味着：

  当任何对内 Agent 遇到技术问题时：
  ```text
  1. ❌ 不会停止工作
  2. ❌ 不会喊用户帮忙 （这很傻，不是吗？）
  3. ✅ 自主调用 IT Engineer 排查
  4. ✅ 问题解决后继续原任务
  ```

  工作流程：

  假设新媒体运营 Agent（media-operator）正在处理内容发布任务，突然遇到 API 调用失败：
  ```text
  [media-operator] 正在发布文章到微信公众号...
  [media-operator] 发现错误：access_token expired
  [media-operator] 判断：这是技术问题，调用 IT Engineer
    └── [it-engineer] 收到协助请求：access_token 过期
    └── [it-engineer] 分析原因：token 刷新机制异常
    └── [it-engineer] 执行修复：重新配置 token 刷新
    └── [it-engineer] 返回结果：问题已解决
  [media-operator] 收到解决方案，继续发布文章
  [media-operator] 任务完成
  ```
  用户视角：整个过程用户无感知，Agent 自主完成了问题排查和修复。

### 精简 + 增益内置skill

原版 openclaw 的 Skill 机制过于臃肿，且不符合国内实情，OFB 做了如下优化：

OFB 不再采用“空 `agents.list[].skills` = 继承全量内置技能”的方式，而是**始终写入每个 Agent 的 skills allowlist**。

- 全局基线技能（默认所有对内 crew 都会继承）：
  - 上游内置：`1password`、`healthcheck`、`model-usage`、`nano-pdf`、`skill-creator`、`ordercli`、`session-logs`、`tmux`、`weather`、`xurl`、`video-frames`
  - OFB 额外新增：`self-improving`
- `it-engineer` 默认追加：`github`、`gh-issues`、`coding-agent`。
- 对外 crew 技能全部在模板中采用声明机制。我们为什么要让一个对外搞钱的 crew 具有查天气的技能呢？如果它对外提供的服务跟天气毫无关系？

记住，本项目的唯一理念：一切为了搞钱！

### 安全

我们采用三重命令执行机制，**权限由 `exec-approvals.json` + `tools.exec` 自动强制执行**，不单单是角色定义中告知。

#### 层级概览

| Tier | 名称 | 执行策略 | 适用 Crew |
|------|------|----------|-----------|
| T0 | read-only | `security: deny` — 默认禁止所有 shell 命令 | external crews（默认） |
| T1 | basic-shell | `security: allowlist` — 仅允许只读命令 | low-risk internal crews |
| T2 | dev-tools | `security: allowlist` — 开发工具链 + 只读命令 | main |
| T3 | admin | `security: full` — 完整系统操作 | it-engineer, hrbp |

### 【todo】为了搞钱目的新增的基础能力

- 微信客服能力
- 支付宝/微信支付 打通能力
- 有可能需要第三个内置全局 crew：财务……以财务数据指导整个系统自动进化，目标只有一个： **收入 ＞ token 消耗 + 固定成本（电脑、宽带、电费……）**

这一趴我们计划三月内完成并开源。

### 易用性脚本

- **配置模板** — 预设国内可用的模型、渠道、技能等配置
- **工具脚本** — 一键启动、一键部署、一键更新…… 

搞钱的路上不要那么烦，能够一键解决的争取都提供

## 我们不做什么

直接改上游（openclaw）代码，一切本质上都是脚本实现的最适合搞钱的配置 + patch。

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
│   └── _template/         # 空白脚手架（创建新 Crew 模板的起点）
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

> **从自己的 fork 同步**（而非官方仓库）：如果你 fork 了本项目并做了定制，希望 `upgrade.sh` 从自己的 fork 拉取，只需确保 `origin` 指向你的 fork，运行时在提示处输入 `y` 即可：
> ```bash
> git remote set-url origin https://github.com/YOUR_ORG/openclaw_for_business.git
> ./scripts/upgrade.sh   # 提示 "Remote is not the official OFB repo" 时输入 y
> ```

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
