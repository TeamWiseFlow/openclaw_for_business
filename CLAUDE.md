# OpenClaw for Business - Claude Code 项目规则

## 项目概述

OpenClaw 的"最佳实践"预配置项目，基于上游 [openclaw/openclaw](https://github.com/openclaw/openclaw) 构建。通过配置模板和 addon 机制在不修改上游代码的前提下实现能力扩展。

## 项目结构

```
openclaw_for_business/
├── openclaw/              # 上游仓库（git clone，禁止直接修改）
���── addons/                # addon 安装目录（运行时由 apply-addons.sh 扫描）
├── config-templates/      # 配置模板（版本控制）
│   └── openclaw.json     # 默认配置模板
├── scripts/              # 工具脚本
│   ├── dev.sh            # 开发模式启动（前台运行）
│   ├── apply-addons.sh   # 通用 addon 加载器
│   ├── update-upstream.sh # 更新上游代码 + 重新应用 addon
│   ├── reinstall-daemon.sh  # 生产模式安装后台服务
│   ├── generate-patch.sh    # 生成补丁（给 addon 开发者用）
│   └── setup-wsl2.sh       # WSL2 环境配置
└── docs/                 # 项目文档
```

运行时数据使用上游默认位置 `~/.openclaw/`。

## 核心规则

### 1. config-templates 是最佳实践基准

`config-templates/openclaw.json` 是本项目的核心产出之一，目标是让其他用户能开箱即用。

- 每当实际运行配置（`~/.openclaw/openclaw.json`）经过验证可正常工作后，**必须将结构和最佳实践同步回 config-templates**
- 敏感信息（apiKey、appSecret、auth token 等）在模板中留空，但字段结构必须保留
- 模板应始终反映当前已验证的最佳配置结构，不得落后于实际运行配置

### 3. 禁止操作

- **禁止直接修改 `openclaw/` 目录** - 所有对上游的修改必须通过 addon 的 patches 或 overrides 机制
- **禁止在不理解的情况下删除代码**

### 4. Addon 机制

能力扩展通过 addon 实现，addon 是独立仓库，安装到 `addons/` 目录。

addon 三层加载机制（按稳定性递减）：
1. **overrides.sh** — pnpm overrides / 依赖替换（最稳健，不依赖行号）
2. **patches/*.patch** — git patch 精确代码改动（上游更新时可能需调整）
3. **skills/*/SKILL.md** — 自定义技能安装（独立于源码）

详见 `scripts/apply-addons.sh`。

### 5. 数据存储

运行时数据使用上游默认位置 `~/.openclaw/`，不做路径覆盖：
- 配置文件：`~/.openclaw/openclaw.json`
- 凭证：`~/.openclaw/credentials/`
- 工作区：`~/.openclaw/workspace/`

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
```

## 技术栈

- 运行时：Node.js + pnpm
- 上游项目：TypeScript
- 脚本：Bash
- 默认端口：18789
- 支持平台：macOS (LaunchAgent)、Linux (systemd)、WSL2

## 沟通语言

用户使用中文沟通，回复请使用中文。
