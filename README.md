# openclaw-for-business

打造能帮用户挣钱的"小龙虾"。

```text
"我一直认为，普遍用户的核心需求，不是生产力，而是赚钱（还有个普遍的核心需求是情感）。"
———— PENG Bo（rwkv.com rwkv.cn 创始人）https://www.zhihu.com/people/bopengbopeng
```

小龙虾很强，能够帮你收发邮件、写报告……但是讲真，这真是你需要的吗？或者说这是你可能付费的吗？

但是它既然都能做这么多事情了，为什么不能用它来帮我们"搞钱"？

本项目的目的就是打造一个能够帮用户 24 小时搞钱的 AI 助手，并且无需复杂的部署和二次开发，非技术用户也可以快速上手。

我们会不断更新代码，如果你有具体思路或想法也欢迎进群讨论，可以先添加作者微信：bigbrother666sh

## 本项目做什么？

**openclaw-for-business 是 [OpenClaw](https://github.com/openclaw/openclaw) 的一套"最佳实践"预配置**，让你开箱即用，无需折腾配置。

它**不修改上游代码**，而是通过以下方式扩展能力：

- **配置模板** — 预设国内可用的模型、渠道、技能等配置
- **Addon 机制** — 通过标准化的 addon 加载器，按需安装第三方能力增强包
- **工具脚本** — 一键启动、一键部署、一键更新

### Addon 生态

能力增强通过独立的 addon 仓库提供，各团队可独立维护：

| Addon | 说明 | 仓库 |
|-------|------|------|
| [wiseflow](https://github.com/TeamWiseFlow/wiseflow) | 浏览器反检测 + 互联网能力增强 | `addon/` 目录 |

> 欢迎贡献更多 addon！参见下方 [Addon 开发](#addon-开发) 章节。

## 项目结构

```
openclaw_for_business/
├── openclaw/              # 上游仓库（git clone，禁止直接修改）
├── addons/                # addon 安装目录（运行时由 apply-addons.sh 扫描）
├── config-templates/      # 配置模板（开箱即用的最佳��践）
│   └── openclaw.json     # 默认配置模板
├── scripts/              # 工具脚本
│   ├── dev.sh            # 开发模式启动
│   ├── apply-addons.sh   # 通用 addon 加载器
│   ├── update-upstream.sh # 更新上游代码
│   ├── reinstall-daemon.sh # 生产模式安装后台服务
│   ├── generate-patch.sh  # 生成补丁（给 addon 开发者用）
│   └── setup-wsl2.sh     # WSL2 环境配置
└── docs/                 # 项目文档
```

运行时数据使用上游默认位置 `~/.openclaw/`。

## 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/TeamWiseFlow/openclaw_for_business.git
cd openclaw_for_business
git clone https://github.com/openclaw/openclaw.git
```

### 2. 安装 addon（可选）

将 addon 发布文件放到 `addons/` 目录：

```bash
# 例：安装 wiseflow addon（浏览器反检测 + 互联网能力增强）
从 https://github.com/TeamWiseFlow/wiseflow/releases 下载最新的发布
解压缩后放入 addons/
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
2. 自动扫描 `addons/` 并应用所有 addon（overrides + patches + skills）

### WSL2 用户

```bash
# 一键配置 WSL2 环境
./scripts/setup-wsl2.sh

# 启动后在 Windows 浏览器中访问显示的 URL（通常是 http://172.x.x.x:18789）
```

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
```

## Addon 开发

Addon 是一个包含 `addon.json` 的目录，结构如下：

```
addons/<name>/
├── addon.json          # 元数据（必须）
├── overrides.sh        # 可选：pnpm overrides / 依赖替换
├── patches/*.patch     # 可选：git patch 代码改动
└── skills/*/SKILL.md   # 可选：自定义技能
```

三层加载机制按稳定性递减排列：
1. **overrides** — 依赖替换，不依赖源码行号，��稳健
2. **patches** — git patch，精确代码改动，上游更新时可能需要调整
3. **skills** — 自定义技能文件，独立于源码

详见 `scripts/apply-addons.sh` 源码。

## 文档

- [OpenClaw 分析](docs/introduce_to_clawd_by_claude.md) - 上游代码架构分析

## 许可证

MIT License
