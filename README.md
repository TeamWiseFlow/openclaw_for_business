# openclaw-for-business

打造能帮用户挣钱的"小龙虾"。

```text
"我一直认为，普遍用户的核心需求，不是生产力，而是赚钱（还有个普遍的核心需求是情感）。"
———— PENG Bo（rwkv.com rwkv.cn 创始人）https://www.zhihu.com/people/bopengbopeng
```

小龙虾很强，能够帮你收发邮件、写报告……但是讲真，这真是你需要的吗？或者说这是你可能付费的吗？

它既然都能做这么多事情了，为什么不能用它来帮我们"搞钱"？

本项目的目的就是打造一个能够帮用户 24 小时搞钱的 AI 助手，并且无需复杂的部署和二次开发，非技术用户也可以快速上手。

我们会不断更新代码，如果你有具体思路或想法也欢迎进群讨论，可以先添加作者微信：bigbrother666sh

## 本项目是什么？

**openclaw-for-business 是 [OpenClaw](https://github.com/openclaw/openclaw) 的一套预制了"最佳实践"的改良版本**，具有开箱即用、专为 business（能够实践搞钱）场景配置、充分适配国内生态环境的特点。

相对于原版的具体**增强点**：

- **配置模板** — 预设国内可用的模型、渠道、技能等配置
- **工具脚本** — 一键启动、一键部署、一键更新
- **多 crew 机制** — 参考 [opencrew](https://github.com/AlexAnys/opencrew) 引入多 crew 机制，你拥有的不再是一个“私人助理”，而是一个”团队“。但我们并未向 opencrew 一样，内置了多个 crew，因为每个人根据自己的需求不同，对团队的配置也是不同的。我们只默认配置了一个 Crew —— HRBP，通过它你可以自定义你需要的其他 crew（比如财务、自媒体运营、情报官等……），HRBP 还会帮你进行 Crew 的管理（统计消耗、更新乃至“解雇”）
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
├── crew/                  # 多 Agent 系统（内置核心）
│   ├── shared/            # 共享协议（RULES.md、TEMPLATES.md）
│   ├── workspaces/        # Agent workspace 模板（main + hrbp）
│   │   └── hrbp/skills/   # HRBP 专属技能（recruit/modify/remove/list/usage）
│   └── role-templates/    # 角色参考模板（供 HRBP 招聘时使用）
├── skills/                # 全局共享技能（所有 Agent 可见）
├── addons/                # 第三方 addon 安装目录（不跟踪子目录）
├── config-templates/      # 配置模板（开箱即用的最佳实践）
│   └── openclaw.json      # 默认配置模板
├── scripts/               # 工具脚本
│   ├── dev.sh             # 开发模式启动（自动安装 crew 系统 + addon）
│   ├── setup-crew.sh      # 多 crew 系统安装（幂等）
│   ├── apply-addons.sh    # 全局 skills + addon 加载器
│   ├── update-upstream.sh # 更新上游代码
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
git clone https://github.com/openclaw/openclaw.git
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
2. 自动安装多 crew 系统（Main Agent + HRBP Agent）
3. 自动安装 crew 内置技能 + 扫描并应用所有 addon

### WSL2 用户

```bash
# 一键配置 WSL2 环境
./scripts/setup-wsl2.sh

# 启动后在 Windows 浏览器中访问显示的 URL（通常是 http://172.x.x.x:18789）
```

**注：dev.sh 和 reinstall-daemon.sh 已经集成该脚本，无需单独使用**

### 生产部署

```bash
# 构建 + 安装后台服务（自动启动 + 开机自启 + 崩溃重启）
cd openclaw && pnpm build && cd ..
./scripts/reinstall-daemon.sh
```

## 常用命令

```bash
./scripts/dev.sh gateway              # 开发模式启动
./scripts/dev.sh gateway --port 18789 # 指定端口
./scripts/dev.sh cli config           # CLI 操作
./scripts/update-upstream.sh          # 更新上游 + 重新应用 addon
./scripts/reinstall-daemon.sh         # 生产部署

# Agent 管理
./scripts/setup-crew.sh               # 手动安装/重装 Agent 系统
./scripts/setup-crew.sh --force       # 覆盖已有 workspace
./scripts/setup-crew.sh --builtin-skills hrbp:browser-guide
```

Agent 生命周期（新增/调岗/移除/消耗统计）由 HRBP skill 执行，内部脚本位于 `crew/workspaces/hrbp/skills/*/scripts/`，不作为人类用户主入口。

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

## 许可证

MIT License
