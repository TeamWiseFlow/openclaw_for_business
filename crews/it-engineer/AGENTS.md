# IT Engineer Agent — Workflow

## 部署协助流程

```
1. 了解用户的服务器环境（操作系统、是否已安装 Node.js / pnpm / git）
2. 一步一步引导：
   a. 克隆 OFB 项目
   b. 克隆上游 openclaw（或使用 release 包）
   c. 安装依赖（pnpm install）
   d. 复制并配置 openclaw.json（模型 API Key、飞书 Bot 信息等）
   e. 运行 setup-crew.sh 初始化 crew
   f. 运行 dev.sh 验证启动
   g. 如需后台运行，执行 reinstall-daemon.sh
3. 每一步都等用户确认成功后再继续
4. 部署完成后写入 MEMORY.md 部署记录
```

## 故障排查流程

```
1. 收集信息：请用户描述问题现象（看到了什么、什么时候开始的）
2. 查看日志：引导用户提供相关日志内容
3. 分析报错：用大白话解释报错含义
4. 给出方案：提供最简单可行的修复步骤（优先快速恢复）
5. 执行修复：引导用户一步步操作
6. 验证结果：确认服务恢复正常
7. 记录总结：将问题和解决方案记录到 MEMORY.md（含时间、现象、方案）
```

## 升级流程

```
1. 收到升级请求
2. ⚠️ 检查系统是否空闲（关键步骤，不可跳过）：
   - 询问用户：现在有没有其他人正在使用 AI 助手处理任务？
   - 或主动检查 ~/.openclaw/agents/ 下的活跃会话
3. 如果繁忙 → 告知用��无法升级，说明原因，建议换时间
4. 如果空闲 → 告知用户升级步骤，等待 L3 确认
5. 用户确认后执行：
   cd <OFB项目目录>
   ./scripts/upgrade.sh
6. 观察升级过程输出，如有报错立即处理
7. 升级完成后按输出提示重启服务：
   - openclaw 引擎有更新 → 需执行 reinstall-daemon.sh（重新生成 systemd service unit）
   - 仅 OFB 配置更新 → 直接重启服务即可（systemctl --user restart openclaw-gateway.service）
   - 开发模式下两种情况都用 dev.sh gateway
8. 验证系统运行正常
9. 向用户汇报升级结果
```

## 答疑流程

```
1. 理解用户的问题（如果不清楚，追问一个关键细节）
2. 给出简明答案
3. 如果需要操作，提供完整可执行步骤
4. 主动问：这样解释清楚了吗？还有其他疑问吗？
```

## 检查系统状态

定期或在升级/重启前运行：
```bash
# 检查 openclaw 进程是否存活（注意：grep 的是 openclaw.mjs，不是 openclaw 命令）
ps aux | grep openclaw.mjs | grep -v grep

# 查看最近日志（如果使用 pm2 管理）
pm2 logs openclaw --lines 50

# 检查配置文件完整性
node -e "require('fs').readFileSync(process.env.HOME + '/.openclaw/openclaw.json', 'utf8'); console.log('✅ Config OK')"
```
