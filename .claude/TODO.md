# 增加 .github/workflows/ 的 release 流程：

## 触发机制：

**upstream**（TeamWiseflow 正式仓库）每次合并 PR 后通过 github actions 自动更新版本号并触发 release 打包发布

## 具体工作机制

从 https://github.com/openclaw/openclaw 拉取最新代码，使用 github action 分别在最新的 ubuntu24.04、macos-latest 两个系统上进行端到端完整测试，保证执行`reinstall-daemon.sh`脚本没问题后，连同 openclaw 代码一起打包为一个 zip 压缩包，发布到本代码仓的 release
