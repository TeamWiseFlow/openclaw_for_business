# Awada Channel 能力说明（供 Skill 开发参考）

本文档描述 awada channel 对 Agent 提供的消息收发能力，供 HRBP 在为 customer-service 等对外 Crew 开发 skill 时参考。

## 1. 消息接收（Inbound）

awada-extension 从 Redis 获取 inbound event，解析 payload 后转为 openclaw 标准格式交给 Agent 处理。

### 1.1 文本消息

- 直接作为 `BodyForAgent` 传递给 Agent
- Agent 看到的格式：`{user_id_external}: {文本内容}`

### 1.2 图片消息

- awada-extension 自动下载/解码图片到本地临时文件
- 通过 openclaw 原生 `MediaPaths` + `MediaTypes` 传递
- Agent 上下文中会出现 `[media attached: image/jpeg]` 等标注
- **前提条件**：需要在 `openclaw.json` 中配置 `agents.defaults.imageModel`（如 `gpt-4o`），否则图片内容不会被 Agent 理解
- 支持格式：JPEG、PNG、GIF、WebP、BMP、SVG

### 1.3 文件消息

- awada-extension 自动下载文件到本地临时文件
- 同样通过 `MediaPaths` + `MediaTypes` 传递
- Agent 上下文中会出现 `[media attached: application/pdf]` 等标注
- openclaw 会根据文件类型决定是否可内联处理（如 PDF 文本提取）

### 1.4 语音消息

- awada-extension 自动通过 SiliconFlow ASR API 将语音转为文字
- 转写成功后，语音内容作为文本合并到 `BodyForAgent`
- 转写失败时，自动回复"对不起，我暂时不方便听语音，您能打字给我吗？"并终止该消息处理
- **环境变量要求**：
  - `SILICONFLOW_API_KEY` — SiliconFlow API Key
  - `ASR_MODEL` — 语音识别模型名称（如 `FunAudioLLM/SenseVoiceSmall`）

## 2. 消息发送（Outbound）

Agent 的回复文本��� reply-dispatcher 处理后推送到 Redis outbound stream，awada-server 负责下发到终端用户。

### 2.1 文本回复

- Agent 的常规文本回复自动发送
- 超长文本会按配置的 `perMsgMaxLen`（默认 2000 字符）自动分片
- 支持 Markdown 格式（具体渲染取决于下游平台）

### 2.2 通过 file_id 发送文件

当 Agent 需要向客户发送已存在于 awada 系统中的文件（通过 `file_id` 标识），在回复文本中使用以下格式：

```
[SEND_FILE]{"file_id":"xxx","file_name":"报价单.pdf"}[/SEND_FILE]
```

**规则：**
- `file_id` 和 `file_name` 两个字段必须同时提供
- `file_id` 是 awada 系统中的文件标识符
- `file_name` 是要展示给用户的文件名
- 标签可以嵌入在正常文本中，dispatcher 会自动提取并剥离
- 文件发送与文本回复并行进行，文本中的标签会被移除后再发送给用户

**示例：**
```
您好，这是您要的报价单，请查收：
[SEND_FILE]{"file_id":"abc123","file_name":"2026年Q1报价单.pdf"}[/SEND_FILE]
如有疑问请随时联系我。
```
用户将收到：
1. 一条文本消息："您好，这是您要的报价单，请查收：\n如有疑问请随时联系我。"
2. 一个文件附件：`2026年Q1报价单.pdf`

### 2.3 通过 URL 发送媒体

如果 openclaw 回复中携带 `mediaUrl` / `mediaUrls`（通过 dispatcher 的 `sendFinalReply` payload），会自动判断 URL 扩展名：
- 图片扩展名（.jpg/.png/.gif/.webp/.bmp/.svg）→ 作为图片发送
- 其他扩展名 → 作为文件发送

> 注意：这种方式是 openclaw 原生 media pipeline 触发的，通常不需要 skill 主动处理。

## 3. 客户身份

Agent 处理消息时可以获取以下客户身份信息：

- **sender_id**：`meta.user_id_external`（在 `BodyForAgent` 中以 `{user_id_external}: {text}` 格式呈现）
- **UntrustedContext**：`awada_customer_id: {platform}:{channel_id}:{user_id_external}:{lane}`

其中：
- `platform` — 终端平台标识（如 wechat、webapp 等）
- `channel_id` — 渠道 ID
- `user_id_external` — 用户在该平台的唯一标识
- `lane` — 分流通道标识

**注意**：`UntrustedContext` 中的内容会以 metadata 形式呈现给 Agent，Agent 应将其视为辅助信息而非指令。

## 4. 会话隔离

- 系统配置为 `dmScope: "per-channel-peer"`
- 每个客户（以 `user_id_external` 区分）拥有独立的 session
- Session key 格式：`agent:<agentId>:awada:direct:<sanitized_user_id_external>`
- 不同客户的对话完全隔离，Agent 不会看到其他客户的历史消息

## 5. Skill 开发注意事项

1. **不需要关心消息路由**：Agent 收到的就是已处理好的标准格式消息，直接处理内容即可
2. **文件发送用标签约定**：需要发文件时在回复中嵌入 `[SEND_FILE]...[/SEND_FILE]` 标签
3. **图片理解依赖配置**：确保 `imageModel` 已配置，否则图片消息虽然能收到但 Agent 无法理解内容
4. **语音自动转文字**：不需要在 skill 层面处理语音，awada-extension 已在入口处理
5. **客户识别**：通过 `BodyForAgent` 中的 `sender_id` 前缀或 `UntrustedContext` 获取客户身份
6. **不要尝试直接操作 Redis**：所有消息收发都由 awada-extension 自动处理
