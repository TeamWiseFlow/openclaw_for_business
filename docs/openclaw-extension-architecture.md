# OpenClaw 扩展体系架构

本文档整理了 OpenClaw 的完整扩展体系，包括 Tool、Skill、Plugin、Hook 等核心概念及其相互关系。

## 架构总览

```
OpenClaw 扩展体系
│
├── Plugin（代码模块，全能扩展点）
│   ├── registerTool → 创建 Tool
│   ├── registerHook → 注册生命周期钩子（代码级）
│   ├── registerChannel → 注册消息通道
│   ├── registerProvider → 注册 LLM 提供商
│   ├── registerService → 注册后台服务
│   ├── registerCommand → 注册用户命令
│   ├── registerCli → 注册 CLI 子命令
│   └── registerHttpRoute / registerGatewayMethod → 注册 HTTP/Gateway 端点
│
├── Tool（内置 + 插件注册的可执行函数，共 ~20 个核心 tool）
│
├── Skill（SKILL.md 指导文档，内置 52 个）
│
├── Hook（HOOK.md + handler.ts，事件驱动模块，内置 4 个）
│
├── ACP（Agent Client Protocol 标准协议接口）
│
└── MCP → 目前不支持（传入会被忽略）
```

## 核心概念关系

| 概念 | 本质 | 面向谁 | 类比 |
|------|------|--------|------|
| **Tool** | 可执行的函数 | LLM agent 调用 | 手（动作能力） |
| **Skill** | Markdown 指导文档 | LLM agent 阅读 | 知识（使用手册） |
| **Plugin** | 可运行的代码模块 | OpenClaw 系统本身 | 器官（系统扩展） |
| **Hook** | 事件驱动的处理器 | OpenClaw 事件系统 | 神经反射（自动响应） |

---

## 1. Tool（工具）

Tool 是 agent 直接可以调用的**函数**。每个 tool 有明确的参数 schema 和 execute 方法。

### 核心 Tool 列表

定义在 `openclaw/src/agents/tools/` 下：

| Tool 名称 | 功能 |
|-----------|------|
| `browser` | 浏览器控制（最复杂的 tool） |
| `web_fetch` | 抓取网页内容 |
| `web_search` | 网页搜索 |
| `memory_search` | 记忆搜索（由 plugin 注册） |
| `memory_get` | 记忆读取（由 plugin 注册） |
| `message` | 发送消息 |
| `image` | 图像处理 |
| `nodes` | 远程节点控制 |
| `canvas` | HTML 内容展示 |
| `cron` | 定时任务 |
| `tts` | 文字转语音 |
| `gateway` | 网关操作 |
| `agents_list` | 列出 agent |
| `session_status` | 会话状态 |
| `sessions_list` | 会话列表 |
| `sessions_history` | 会话历史 |
| `sessions_send` | 发送到会话 |
| `sessions_spawn` | 创建子会话 |
| `subagents` | 子 agent 管理 |

### Browser Tool 详解

`browser` 是最复杂的单一 tool，通过 `action` 参数区分 16 种操作：

**Tool Actions（16 个）：**

| Action | 功能 |
|--------|------|
| `status` | 查询浏览器控制服务状态 |
| `start` | 启动托管浏览器 |
| `stop` | 停止托管浏览器 |
| `profiles` | 列出所有浏览器 profile |
| `tabs` | 列出当前打开的标签页 |
| `open` | 打开新标签页并导航到指定 URL |
| `focus` | 聚焦指定标签页 |
| `close` | 关闭标签页 |
| `snapshot` | 获取页面 accessibility 快照 |
| `screenshot` | 截取页面截图 |
| `navigate` | 在当前标签页导航到新 URL |
| `console` | 获取浏览器控制台消息 |
| `pdf` | 导出页面为 PDF |
| `upload` | 文件上传 |
| `dialog` | 处理浏览器原生对话框 |
| `act` | 执行页面交互操作 |

**Act 子操作（12 种 kind）：**

| Kind | 功能 |
|------|------|
| `click` | 点击元素（双击、右键、修饰键） |
| `type` | 在元素中输入文本 |
| `press` | 按下键盘按键 |
| `hover` | 悬停在元素上 |
| `drag` | 拖拽元素 |
| `select` | 选择下拉框选项 |
| `fill` | 批量填写表单字段 |
| `resize` | 调整视口大小 |
| `wait` | 等待条件 |
| `evaluate` | 在浏览器中执行 JavaScript |
| `close` | 关闭页面 |
| `scrollIntoView` | 滚动到元素可见位置 |

**额外的浏览器 HTTP API 路由（Storage 组）：**

- Cookies: get / set / clear
- Storage: localStorage/sessionStorage 的 get / set / clear
- Set Offline / Headers / Credentials / Geolocation / Media / Timezone / Locale / Device
- Response Body / Download / Highlight

**底层实现：** 所有浏览器操作通过 `src/browser/` 中的 browser server 实现，使用 Playwright（在我们的补丁中被替换为 Patchright）通过 CDP 协议与浏览器交互。

---

## 2. Skill（技能）

Skill **不是**可执行代码，而是一个 `SKILL.md` Markdown 文件，本质上是给 LLM 看的指导文档。

### 工作流程

1. **启动时**：从多个来源加载所有 skill 的名称和简短描述，注入到 system prompt
2. **用户发消息时**：LLM 扫描 `<available_skills>` 列表
3. **匹配到 skill 时**：LLM 用 `read` tool 读取 `SKILL.md` 完整内容
4. **遵循指导**：按照 SKILL.md 中的说明调用相应的 tool

### Skill 来源（优先级从低到高）

| 优先级 | 来源 | 路径 |
|--------|------|------|
| 1 (最低) | extra | 配置中的 `skills.load.extraDirs` + 插件 skill |
| 2 | bundled | `openclaw/skills/` 目录（内置 52 个） |
| 3 | managed | `~/.openclaw/skills/` |
| 4 | personal agents | `~/.agents/skills/` |
| 5 | project agents | `<workspace>/.agents/skills/` |
| 6 (最高) | workspace | `<workspace>/skills/` |

同名 skill 高优先级覆盖低优先级。

### 条件加载

- **OS 检查**：某些 skill 只在特定操作系统上可用
- **二进制依赖**：`requires.bins` 检查所需命令行工具
- **环境变量**：`requires.env` 检查 API key 等
- **配置检查**：`requires.config` 检查 OpenClaw 配置项
- **手动控制**：`skills.entries.<name>.enabled: false` 或 `skills.allowBundled` allowlist

### 内置 Skill（52 个）

| 分类 | Skills |
|------|--------|
| 社交/消息 | discord, slack, imsg, bluebubbles, wacli, voice-call |
| Twitter/X | xurl |
| 笔记/效率 | apple-notes, apple-reminders, bear-notes, notion, obsidian, things-mac, trello |
| AI/编程 | coding-agent, gemini, skill-creator, oracle |
| 媒体 | camsnap, gifgrep, peekaboo, songsee, video-frames, openai-image-gen, openai-whisper, openai-whisper-api, sherpa-onnx-tts |
| GitHub | github, gh-issues |
| 邮件 | himalaya |
| 智能家居 | openhue, sonoscli |
| 音乐 | spotify-player |
| 系统/终端 | tmux, session-logs, healthcheck |
| 模型管理 | model-usage |
| 工具 | blucli, eightctl, gog, goplaces, mcporter, nano-banana-pro, nano-pdf, ordercli, sag, summarize, weather |
| 展示 | canvas |
| 其他 | clawhub, blogwatcher |

### Command Dispatch

Skill 可以在 frontmatter 中声明 `command-dispatch: tool` 和 `command-tool: <toolName>`，当用户通过 `/skill_name` 命令触发时，直接调用指定 tool 而不经过 LLM 判断。

---

## 3. Plugin（插件）

Plugin 是最底层的扩展机制，是一个 TypeScript/JavaScript 模块，通过 `openclaw.plugin.json` 声明元数据。

### Plugin 能力

通过 `OpenClawPluginApi` 注册：

| 注册方法 | 说明 |
|----------|------|
| `registerTool` | 注册新的 agent tool |
| `registerHook` | 注册生命周期钩子 |
| `registerChannel` | 注册消息通道 |
| `registerProvider` | 注册 LLM 提供商 |
| `registerService` | 注册后台服务 |
| `registerCommand` | 注册直接命令（绕过 LLM） |
| `registerCli` | 注册 CLI 子命令 |
| `registerHttpHandler` / `registerHttpRoute` | 注册 HTTP 端点 |
| `registerGatewayMethod` | 注册 gateway RPC 方法 |

### 生命周期钩子（24 种事件）

```
before_model_resolve, before_prompt_build, before_agent_start,
llm_input, llm_output, agent_end,
before_compaction, after_compaction, before_reset,
message_received, message_sending, message_sent,
before_tool_call, after_tool_call, tool_result_persist, before_message_write,
session_start, session_end,
subagent_spawning, subagent_delivery_target, subagent_spawned, subagent_ended,
gateway_start, gateway_stop
```

### Plugin Manifest（`openclaw.plugin.json`）

```json
{
  "id": "memory-core",
  "kind": "memory",
  "skills": ["./skills"],
  "channels": ["telegram"],
  "providers": ["gemini"],
  "configSchema": { ... }
}
```

### 内置 Plugin（extensions 目录，39 个）

| 分类 | Plugins |
|------|---------|
| 消息通道 | telegram, discord, slack, whatsapp, signal, imessage, line, matrix, irc, msteams, googlechat, nostr, twitch, feishu, zalo, zalouser, synology-chat, nextcloud-talk, tlon, bluebubbles, mattermost |
| 记忆 | memory-core, memory-lancedb |
| 认证 | google-antigravity-auth, google-gemini-cli-auth, copilot-proxy, minimax-portal-auth, qwen-portal-auth |
| 其他 | voice-call, talk-voice, phone-control, device-pair, diagnostics-otel, llm-task, lobster, open-prose, thread-ownership |

### 示例：memory-core 插件

```typescript
const memoryCorePlugin = {
  id: "memory-core",
  kind: "memory",
  register(api: OpenClawPluginApi) {
    // 注册 memory_search 和 memory_get 两个 tool
    api.registerTool((ctx) => {
      return [memorySearchTool, memoryGetTool];
    }, { names: ["memory_search", "memory_get"] });

    // 注册 CLI 命令
    api.registerCli(({ program }) => {
      api.runtime.tools.registerMemoryCli(program);
    }, { commands: ["memory"] });
  },
};
```

---

## 4. Hook（钩子）

Hook 是独立于 Plugin 的事件驱动扩展机制。每个 Hook 由 `HOOK.md`（元数据和文档）+ `handler.ts`（处理逻辑）组成。

与 Plugin 的 `registerHook` 不同：Plugin Hook 是代码级的，运行在 Plugin 的 JS 运行时中；这里的 Hook 是独立的文件系统级模块。

### 内置 Hook（4 个）

| Hook 名称 | 事件 | 功能 |
|-----------|------|------|
| session-memory | `command:new`, `command:reset` | 会话重置时自动把对话保存到记忆文件 |
| command-logger | 命令事件 | 记录命令日志 |
| boot-md | 启动事件 | 启动时加载上下文 |
| bootstrap-extra-files | 启动事件 | 启动时注入额外文件 |

---

## 5. 其他架构概念

### ACP（Agent Client Protocol）

OpenClaw 实现了 Agent Client Protocol 标准协议（使用 `@agentclientprotocol/sdk`），作为标准化的 agent server 被外部客户端接入。

### Node（远程节点）

通过 `nodes` tool 管理远程配对设备（Mac App、iOS、Android 等），支持拍照、截屏、运行命令、推送通知、获取位置等。

### MCP（Model Context Protocol）

**目前不支持。** ACP translator 中对传入的 MCP servers 直接忽略：

```typescript
if (params.mcpServers.length > 0) {
  this.log(`ignoring ${params.mcpServers.length} MCP servers`);
}
```

---

## 关键源码路径

| 概念 | 路径 |
|------|------|
| Tool 定义 | `openclaw/src/agents/tools/` |
| Browser Tool | `openclaw/src/agents/tools/browser-tool.ts` |
| Browser Server | `openclaw/src/browser/` |
| Browser Routes | `openclaw/src/browser/routes/` |
| Playwright 操作 | `openclaw/src/browser/pw-tools-core.*.ts` |
| Skill 加载 | `openclaw/src/agents/skills/` |
| Skill 文件 | `openclaw/skills/` |
| Plugin 系统 | `openclaw/src/plugins/` |
| Plugin 扩展 | `openclaw/extensions/` |
| Hook 系统 | `openclaw/src/hooks/` |
| Hook 内置 | `openclaw/src/hooks/bundled/` |
| ACP 协议 | `openclaw/src/acp/` |
| System Prompt | `openclaw/src/agents/system-prompt.ts` |
| 配置类型 | `openclaw/src/config/` |

---

## 我们的定制

### Patchright 补丁

`patches/001-switch-playwright-to-patchright-core.patch` 将底层的 `playwright-core` 替换为 `patchright-core`。由于所有浏览器操作都通过 `pw-session.ts` → `pw-tools-core.*.ts` 这一层调用 Playwright API，补丁影响范围覆盖所有浏览器操作。
