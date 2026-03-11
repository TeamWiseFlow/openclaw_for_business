# IT Engineer Agent — Memory

## 关于 OFB 项目

## Crew 通讯录
- 当前启用 crew 通讯录：`~/.openclaw/TEAM_DIRECTORY.md`
- 本 workspace 会同步一份：`TEAM_DIRECTORY.md`
- 任何 crew 增删改后，优先以该通讯录为准确认当前启用实例和路由方式

### 项目基本信息
- **OFB 项目名称**：openclaw-for-business
- **OFB 仓库地址**：https://github.com/TeamWiseFlow/openclaw_for_business
- **上游 OpenClaw 仓库**：https://github.com/openclaw/openclaw
- **OpenClaw 官方教程**：https://docs.openclaw.ai/

### OFB 是什么
openclaw-for-business（OFB）是 [OpenClaw](https://github.com/openclaw/openclaw) 的预制最佳实践版本，具备：
- 预设国内可用的模型、渠道、技能配置
- 一键启动、一键部署、一键更新的工具脚本
- 内置多 crew 机制（Main Agent + HRBP，可自定义扩展）
- Addon 生态（通过标准化 addon 加载器按需安装第三方能力）

### OFB 与 OpenClaw 的关系
- OFB 是**封装增强层**，上游代码位于项目目录下的 `openclaw/` 子目录
- `openclaw/` 子目录是 git clone 下来的上游仓库，**禁止直接修改**
- OFB 通过补丁（`apply-addons.sh`）和配置模板与上游集成
- 更新时先拉取上游代码，再重新应用 OFB 的增强层

### 我正在维护的是 OFB
用户部署和运行的系统是 OFB，不是原版 OpenClaw。虽然底层是 OpenClaw，但用户的操作入口是 OFB 的脚本，配置位于 `~/.openclaw/openclaw.json`。

---

## 项目目录结构

```
openclaw_for_business/
├── openclaw/              # 上游仓库（git clone，禁止直接修改）
├── crew/                  # 多 Agent 系统
│   ├── shared/            # 共享协议（RULES.md、TEMPLATES.md）
│   ├── workspaces/        # Agent workspace 模板
│   └── role-templates/    # 角色参考模板
├── skills/                # 全局共享技能
├── addons/                # 第三方 addon
├── config-templates/      # 配置模板
│   └── openclaw.json      # 默认配置模板
├── scripts/               # 工具脚本（核心操作入口）
│   ├── dev.sh             # 开发模式启动
│   ├── setup-crew.sh      # 多 crew 系统安装
│   ├── apply-addons.sh    # 全局 skills + addon 加载器
│   ├── update-upstream.sh # 更新上游代码（升级入口）
│   ├── reinstall-daemon.sh # 生产模式安装后台服务
│   └── setup-wsl2.sh      # WSL2 环境配置
└── docs/                  # 项目文档
```

运行时数据位于 `~/.openclaw/`：
- `~/.openclaw/openclaw.json`：实际运行配置（勿手动大幅修改）
- `~/.openclaw/workspace-*/`：各 Agent 的工作区
- `~/.openclaw/agents/*/sessions/`：会话记录（用于用量统计）

---

## 如何更新 OFB 系统

### 升级命令
```bash
cd ~/path/to/openclaw_for_business
./scripts/update-upstream.sh
```

`update-upstream.sh` 会依次：
1. 恢复上游代码到干净状态（`git reset --hard`）
2. 拉取上游最新代码（`git pull origin main`）
3. 安装 / 更新依赖（`pnpm install`）
4. 重新构建（`pnpm build`）
5. 重新同步 crew 配置（`setup-crew.sh`）
6. 重新应用 addons（`apply-addons.sh`）

升级完成后通常需要重启服务。

### ⚠️ 升级前必须检查：系统是否空闲？

**绝对不能在系统繁忙时升级！** 升级可能中断正在运行的 agent 会话。

检查方法：
```bash
# 查看是否有活跃的 agent 会话
ls ~/.openclaw/agents/*/sessions/ 2>/dev/null | head -20
# 或直接问用户：最近有没有其他同事正在使用 AI 助手处理任务？
```

如果有任务在运行：
- **不执行升级**
- 告知用户当前情况
- 建议在所有人都不用的时候（如下班后、凌晨）再操作

---

## 常见故障与解决方案

（在排查故障后将解决方案记录在此，方便复用）

---

## 部署记录

（首次部署和重要变更记录）
