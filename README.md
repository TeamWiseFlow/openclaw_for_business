# OpenClaw for Business

企业级 OpenClaw 扩展项目，基于上游 [openclaw/openclaw](https://github.com/openclaw/openclaw) 构建。

## ✨ 特性

- 🏢 **企业级配置** - 预配置开箱即用，增加多种“一键”命令（一键启动、一键安装、一键部署……）
- 📦 **开箱即用** - 所有配置和数据在项目内，无需污染用户目录
- 🇨🇳 **国内优化** - 特别针对国内使用环境优化（去除用不上的渠道、增加国内常用渠道、插件等），
- 📚 **知识库能力** - 增加知识库能力
- 🔧 **补丁管理** - 基于 patch 的上游代码修改，易于维护和升级
- 🔌 **插件扩展** - 业务插件独立开发，不修改上游代码

## 项目结构

```
openclaw_for_business/
├── openclaw/              # 上游仓库（git clone）
├── workspace/             # 运行时工作区（不提交）
│   ├── config/           # 配置文件
│   ├── data/             # 状态数据
│   └── agents/           # Agent 工作区
├── config-templates/      # 配置模板（开箱即用）
├── patches/               # 业务补丁
├── extensions/            # 业务扩展插件
├── scripts/              # 工具脚本
└── docs/                 # 文档
```

## 快速开始

### WSL2 环境（Windows 用户推荐）

```bash
# 1. 克隆项目
git clone https://github.com/TeamWiseFlow/openclaw_for_business.git
cd openclaw_for_business
git clone https://github.com/openclaw/openclaw.git

# 2. 一键配置 WSL2 环境
./scripts/setup-wsl2.sh

# 3. 安装依赖
cd openclaw
pnpm install

# 4. 启动开发环境
cd ..
./scripts/dev.sh gateway

# 5. 在 Windows 浏览器中访问显示的 URL（通常是 http://172.x.x.x:18789）
```

**WSL2 特别说明**：
- ✅ 自动检测并显示正确的访问地址
- ✅ 自动处理行尾符问题
- ✅ 需要在 Windows 浏览器中访问（不是 WSL2 内部）
- ⚠️ 确保 Windows 防火墙允许端口 18789

### 开发环境

**适合**：日常开发、调试、修改代码

```bash
# 1. 克隆项目
git clone https://github.com/TeamWiseFlow/openclaw_for_business.git
cd openclaw_for_business
git clone https://github.com/openclaw/openclaw.git

# 2. 安装依赖
cd openclaw
pnpm install

# 3. 启动开发环境（前台运行，实时编译）
cd ..
./scripts/dev.sh gateway

# 4. 浏览器启动后，访问 http://127.0.0.1:18789 即可使用(如果你未指定端口)

此时如果配置了飞书等渠道，应该也能够直接对话了（启动后程序后台运行，可以关掉命令行窗口）
```

**特点**：
- ✅ 无需预先构建
- ✅ 代码修改后重启即可
- ✅ 前台运行，Ctrl+C 停止
- ⚠️ 首次启动较慢（需编译）

### 生产环境

**适合**：生产部署、后台持续运行

```bash
# 1. 构建项目
cd openclaw
pnpm build
cd ..

# 2. 安装后台服务（自动启动 + 开机自启 + 崩溃重启）
./scripts/reinstall-daemon.sh

服务启动后访问 http://127.0.0.1:18789 即可使用(如果你未指定端口)

此时如果配置了飞书等渠道，应该也能够直接对话了，此时服务运行在后台，可以关掉命令行窗口
```

**停止服务(需要在 openclaw 目录下执行)**：
```bash
# 查看状态
pnpm openclaw daemon status

# 停止服务
pnpm openclaw daemon stop

# 卸载服务
pnpm openclaw daemon uninstall
```

**特点**：
- ✅ 后台持续运行
- ✅ 开机自动启动
- ✅ 崩溃自动重启
- ✅ 性能更好（预编译）

所有配置和数据都在 `workspace/` 目录，不会影响 `~/.openclaw`。

### 常用命令

```bash
# 开发模式启动（前台）
./scripts/dev.sh gateway

# 启动时指定参数
./scripts/dev.sh gateway --port 18789

# 更新配置
./scripts/dev.sh cli config

# 验证路径设置
./scripts/verify-paths.sh

# 更新上游代码
./scripts/update-upstream.sh

# 生产环境：每次更新后
./scripts/reinstall-daemon.sh
```

## 对比原版修改点

### 1. 项目内配置

通过环境变量将 OpenClaw 的所有路径指向项目内：

```bash
OPENCLAW_STATE_DIR=./workspace/data
OPENCLAW_CONFIG_PATH=./workspace/config/openclaw.json
```

**好处：**
- ✅ 开发环境隔离，不污染 `~/.openclaw`
- ✅ 配置可版本控制（通过模板）
- ✅ 多项目并行开发
- ✅ 客户部署开箱即用

### 2. 补丁管理

修改上游代码时生成 patch 文件（无需提交到上游仓库）：

```bash
# 修改代码
cd openclaw
vim src/memory/manager.ts

# 生成补丁
cd ..
./scripts/generate-patch.sh "memory-docx-support"
# 生成: patches/001-memory-docx-support.patch
```

**好处：**
- ✅ 清晰追踪对上游的修改
- ✅ 易于升级上游版本
- ✅ 可选择性应用补丁

### 3. 插件扩展

业务逻辑通过插件实现，不修改上游：

```
patches/
├── enterprise-workflow/      # 企业工作流
└── custom-skills/            # 自定义技能
```

## 开发工作流

### 更新上游代码

```bash
./scripts/update-upstream.sh  # 拉取最新 + 重新构建 + 应用补丁
```

### 修改上游代码

```bash
cd openclaw
# 修改代码...
cd ..
./scripts/generate-patch.sh "描述"
```

### 更新上游

```bash
./scripts/update-upstream.sh  # 拉取最新 + 安装依赖 + 重新构建 + 应用补丁
```

**说明**：OpenClaw 在频繁更新中，建议定期运行此命令同步最新代码。

## 文档

- [OpenClaw 分析](docs/openclaw-analysis.md) - 详细分析上游代码，理解其架构和实现

## 许可证

MIT License
