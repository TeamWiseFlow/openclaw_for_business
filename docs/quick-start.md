# HRBP Agent System — 快速上手

## 前提条件

- Node.js >= 18
- pnpm
- OpenClaw 上游代码已克隆到 `openclaw/` 目录

## 一键安装

```bash
# 1. 安装 HRBP Agent System（部署 workspace、模板、配置）
./scripts/setup-hrbp.sh

# 2. 编辑配置（填入 API Key、飞书 App 信息等）
vim ~/.openclaw/openclaw.json

# 3. 启动 Gateway
./scripts/dev.sh gateway

# 4. 启动 Bridge（飞书 Bot 连接）
cd bridge && node bridge.mjs
```

## 验证

```bash
# 查看已注册的 Agent
./scripts/list-agents.sh
```

应该看到两个 Agent：`main`（路由器）和 `hrbp`（HR 管理）。

## 使用

### 通过飞书对话（模式 A）

1. 发送任意消息给飞书 Bot → Main Agent 回复
2. 说"我需要一个开发助手" → Main Agent 自动 spawn HRBP → HRBP 设计方案
3. HRBP 创建新 Agent 后 → 说"帮我写代码" → Main Agent spawn Developer Agent

### 直接 @指定 Agent

```
@hrbp 我要招一个运营
@developer 帮我修复登录 bug
```

## Agent 管理脚本

```bash
# 添加新 Agent（workspace 必须已存在）
./scripts/add-agent.sh <agent-id>

# 添加并绑定渠道（模式 B 直连）
./scripts/add-agent.sh customer-service --bind wechat:wx_xxx

# 修改渠道绑定
./scripts/modify-agent.sh <agent-id> --bind wechat:wx_xxx
./scripts/modify-agent.sh <agent-id> --unbind wechat

# 移除 Agent（workspace 归档不删除）
./scripts/remove-agent.sh <agent-id>

# 列出所有 Agent
./scripts/list-agents.sh
```

## 目录结构

安装后 `~/.openclaw/` 中的新增内容：

```
~/.openclaw/
├── openclaw.json          # 已添加 agents.list 和 bindings
├── workspace-main/        # Main Agent workspace（8 个 .md 文件）
├── workspace-hrbp/        # HRBP Agent workspace
└── hrbp-templates/        # 角色模板（供 HRBP 招聘时参考）
    ├── _template/         # 空白模板（8 个占位文件）
    ├── developer.md       # 开发工程师参考
    ├── market-analyst.md  # 市场分析师参考
    ├── content-writer.md  # 内容创作者参考
    ├── customer-service.md # 客服参考
    └── operations.md      # 运营参考
```
