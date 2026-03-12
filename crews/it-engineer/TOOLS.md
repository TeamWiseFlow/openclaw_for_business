# IT Engineer Agent — Tools

## 可用工具

### 通用工具
- 文件读写：读取日志、配置文件，修改 workspace 文件
- Shell 执行：运行系统命令、检查状态、查看日志

### OFB 内置脚本（需先 cd 到 OFB 项目目录再执行）

> OFB 项目路径见同目录的 `OFB_ENV.md`（每次 `setup-crew.sh` 自动更新，里面有完整命令）。

```bash
# 开发模式前台启动（含日志输出）
cd <OFB_PROJECT_ROOT> && ./scripts/dev.sh gateway

# 生产模式重新安装后台服务
cd <OFB_PROJECT_ROOT> && ./scripts/reinstall-daemon.sh

# 重新同步 crew 配置（幂等，安全执行）
cd <OFB_PROJECT_ROOT> && ./scripts/setup-crew.sh

# 重新应用 addons
cd <OFB_PROJECT_ROOT> && ./scripts/apply-addons.sh

# 升级 OFB 系统（执行前必须确认系统空闲）
cd <OFB_PROJECT_ROOT> && ./scripts/upgrade.sh
```

> ⚠️ **禁止直接运行 `openclaw` 命令**（`openclaw` 不在系统 PATH 中）。
> 如需直接调用上游 CLI，必须在 `openclaw/` 子目录内通过 `pnpm openclaw` 执行：
> ```bash
> cd <OFB_PROJECT_ROOT>/openclaw && pnpm openclaw <subcommand>
> ```

### 检查系统运行状态

```bash
# 检查 openclaw 进程是否存活
ps aux | grep openclaw.mjs | grep -v grep

# 查看 pm2 管理的进程（生产模式）
pm2 list
pm2 logs openclaw --lines 50

# 检查配置文件完整性
node -e "require('fs').readFileSync(process.env.HOME + '/.openclaw/openclaw.json', 'utf8'); console.log('✅ Config OK')"
```

### GitHub / 代码相关（需已启用 github、gh-issues、coding-agent 技能）
- `github`：读取 OFB 和 OpenClaw 仓库的最新信息（commits、releases、README）
- `gh-issues`：查看 OFB 和 OpenClaw 的 issue，了解已知问题和修复状态
- `coding-agent`：用于分析代码问题、生成配置文件、解读报错信息

## 工具使用规则

1. **先读后改**：修改任何配置前，先读取当前内容，理解后再操作
2. **备份重要文件**：修改 `~/.openclaw/openclaw.json` 前，先备份
3. **脚本优先**：优先使用 OFB 内置脚本，不要直接操作 `openclaw/` 目录下的代码
4. **日志是第一线索**：遇到问题先查日志，再猜原因
5. **验证结果**：每次操作后确认效果（如重启后检查服务是否正常运行）
