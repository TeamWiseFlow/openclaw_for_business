# 多 Agent 系统 — 快速上手

## 前提条件

- Node.js >= 18
- pnpm
- OpenClaw 上游代码已克隆到 `openclaw/` 目录

## 一键启动

```bash
# 1. 安装依赖
cd openclaw && pnpm install && cd ..

# 2. 启动（自动安装 Agent 系统 + 应用 addon）
./scripts/dev.sh gateway

# 3. 编辑配置（填入 API Key、飞书 App 信息等）
vim ~/.openclaw/openclaw.json
```

首次运行 `dev.sh` 时会自动：
- 从 `config-templates/` 创建默认配置
- 安装 Main Agent 和 HRBP Agent 的 workspace（含 HRBP 专属技能）
- 安装角色参考模板
- 安装全局共享技能 + 应用 addon

## 验证

```bash
# 查看已注册的 Agent（main + hrbp）
node -e "const c=require(process.env.HOME+'/.openclaw/openclaw.json'); console.log((c.agents?.list||[]).map(a=>a.id).join(', '))"
```

应该看到两个 Agent：`main`（路由器）和 `hrbp`（HR 管理）。

## 使用

### 通过飞书对话

每个 Agent 绑定一个独立的飞书 Bot（上游 feishu extension 多账户机制）：

1. 在飞书开放平台为每个 Agent 创建一个机器人应用
2. 在 `~/.openclaw/openclaw.json` 的 `channels.feishu.accounts` 中填入每个应用的 `appId` 和 `appSecret`
3. 在 `bindings[]` 中配置飞书账户到 Agent 的映射关系
4. 启动 Gateway 后，各 Bot 自动通过 WebSocket 长连接接收消息

```json
{
  "channels": {
    "feishu": {
      "accounts": {
        "main-bot": { "appId": "cli_xxx", "appSecret": "..." },
        "hrbp-bot": { "appId": "cli_yyy", "appSecret": "..." }
      }
    }
  },
  "bindings": [
    { "agentId": "main", "match": { "channel": "feishu", "accountId": "main-bot" } },
    { "agentId": "hrbp", "match": { "channel": "feishu", "accountId": "hrbp-bot" } }
  ]
}
```

发消息给 main-bot，由 Main Agent 回复；发消息给 hrbp-bot，由 HRBP Agent 回复。各 Agent 并行运行、互不干扰。

## Agent 管理（推荐）

```bash
# 手动安装/重装 Agent 系统
./scripts/setup-crew.sh
./scripts/setup-crew.sh --force  # 覆盖已有 workspace
./scripts/setup-crew.sh --builtin-skills hrbp:browser-guide  # 覆盖指定 agent 的内置 skill
```

建议通过 HRBP 对话执行 Agent 生命周期操作（新增/调岗/移除），由 HRBP skill 内部脚本处理注册与绑定。

如需手动执行（调试场景）：

```bash
# 新增 Agent（workspace 已存在）
bash ~/.openclaw/workspace-hrbp/skills/hrbp-recruit/scripts/add-agent.sh <agent-id>
bash ~/.openclaw/workspace-hrbp/skills/hrbp-recruit/scripts/add-agent.sh <agent-id> --builtin-skills browser-guide,summarize

# 修改绑定
bash ~/.openclaw/workspace-hrbp/skills/hrbp-modify/scripts/modify-agent.sh <agent-id> --bind wechat:wx_xxx
bash ~/.openclaw/workspace-hrbp/skills/hrbp-modify/scripts/modify-agent.sh <agent-id> --unbind wechat

# 移除 Agent（workspace 归档不删除）
bash ~/.openclaw/workspace-hrbp/skills/hrbp-remove/scripts/remove-agent.sh <agent-id>

# 用量统计
bash ~/.openclaw/workspace-hrbp/skills/hrbp-usage/scripts/agent-usage.sh --period daily --days 14

# 花名册/路由状态
bash ~/.openclaw/workspace-hrbp/skills/hrbp-list/scripts/list-agents.sh
```

## 通过 Addon 增加 Agent

第三方 addon 可以通过 `crew/` 目录贡献预制 Agent：

```
addons/my-addon/
├── addon.json
├── skills/             # 可选：全局技能（所有 Agent 可见）
│   └── my-skill/SKILL.md
└── crew/               # 可选：预制 Agent
    └── my-agent/       # workspace 模板
        ├── SOUL.md
        ├── IDENTITY.md
        ├── AGENTS.md
        ├── MEMORY.md
        ├── USER.md
        ├── TOOLS.md
        ├── TASKS.md
        ├── HEARTBEAT.md
        └── skills/     # 可选：Agent 专属技能
            └── my-agent-skill/SKILL.md
```

运行 `dev.sh` 或 `reinstall-daemon.sh` 时，addon 中的 Agent 会被自动安装并注册。
全局 skills 安装到 `openclaw/skills/`（所有 Agent 可见），Agent 专属 skills 安装到对应 workspace。
每个 Agent 最终可见 skill 为：`workspace skills + agents.list[].skills 中允许的内置 skill`。
这些 Agent 由 HRBP 统一管理，可以通过 HRBP 进行修改和移除。

## 目录结构

安装后 `~/.openclaw/` 中的新增内容：

```
~/.openclaw/
├── openclaw.json          # 已添加 agents.list 和 bindings
├── workspace-main/        # Main Agent workspace（8 个 .md 文件）
├── workspace-hrbp/        # HRBP Agent workspace
└── hrbp-templates/        # 角色模板（供 HRBP 招聘时参考）
    ├── _template/         # 空白模板（8 个占位文件 + BUILTIN_SKILLS）
    ├── developer.md       # 开发工程师参考
    ├── market-analyst.md  # 市场分析师参考
    ├── content-writer.md  # 内容创作者参考
    ├── customer-service.md # 客服参考
    └── operations.md      # 运营参考
```
