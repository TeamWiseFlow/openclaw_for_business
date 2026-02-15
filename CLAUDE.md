# OpenClaw for Business - Claude Code 项目规则

## 项目概述

企业级 OpenClaw 扩展项目，基于上游 openclaw/openclaw 构建。通过环境变量、补丁和插件机制在不修改上游代码的前提下实现企业定制。

## 项目结构

```
openclaw_for_business/
├── openclaw/              # 上游仓库（git submodule，禁止直接修改）
├── .openclaw-data/        # 运行时数据（不提交到 git）
│   ├── config/           # 配置文件（从 config-templates 生成）
│   ├── workspace/        # Agent 工作区（OpenClaw 自动创建）
│   └── ...               # 其他运行时数据（OpenClaw 自动创建）
├── config-templates/      # 配置模板（版本控制）
│   └── openclaw.json     # 默认配置模板
├── patches/               # 对上游的业务补丁（.patch 文件）
├── extensions/            # 业务扩展插件
├── scripts/              # 工具脚本
│   ├── dev.sh            # 开发模式启动（前台运行）
│   ├── reinstall-daemon.sh  # 生产模式安装后台服务
│   ├── generate-patch.sh    # 生成补丁
│   ├── apply-patches.sh     # 应用补丁
│   ├── update-upstream.sh   # 更新上游代码
│   └── setup-wsl2.sh       # WSL2 环境配置
└── docs/                 # 项目文档
```

## 核心规则

### 1. 代码优先验证（最重要）

用户对 npm/node/pnpm 等技术栈不熟悉，可能提出不合理的要求。

- 执行任何修改前，必须先读取并理解相关代码
- 如果用户理解有误，先纠正并解释，再讨论方案
- 确认无误后才执行修改

### 2. 禁止操作

- **禁止直接修改 `openclaw/` 目录** - 对上游的修改必须通过 `scripts/generate-patch.sh` 生成补丁到 `patches/`
- **禁止提交 `.openclaw-data/` 到 git** - 这是运行时数据
- **禁止在不理解的情况下删除代码**

### 3. 修改上游代码的正确流程

```bash
cd openclaw
# 修改代码...
cd ..
./scripts/generate-patch.sh "补丁描述"
# 补丁生成到 patches/ 目录
```

### 4. 环境变量体系

所有路径通过环境变量配置，核心变量：
- `OPENCLAW_STATE_DIR` → `.openclaw-data`
- `OPENCLAW_CONFIG_PATH` → `.openclaw-data/config/openclaw.json`
- `OPENCLAW_OAUTH_DIR` → `.openclaw-data/credentials`

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

# 补丁管理
./scripts/generate-patch.sh "描述"
./scripts/apply-patches.sh

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
