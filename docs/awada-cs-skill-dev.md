# Awada Channel — CS Skill 开发说明

> 本文档面向 HRBP，用于指导为 customer-service 等对外 Crew 开发支持 awada channel 的技能。

## 背景

`awada-extension` 是 OpenClaw 的 awada channel 插件，负责在 OpenClaw 与 awada-server 之间桥接消息。它对上游消息做了完整的格式转换和媒体处理，Agent 只需关注"纯内容"���互，不需��感知底层 Redis 协议。

---

## 1. Agent 可见的客户身份信息

每条 awada 消息到达 Agent 时，会在 **UntrustedContext** 中注入：

```
awada_customer_id: <platform>:<channel_id>:<user_id_external>:<lane>
```

- `platform`：下游平台标识（如 `wechat`、`worktool` 等，由 awada-server 配置决定）
- `channel_id`：所属频道/企业 ID
- `user_id_external`：该平台上用户的唯一 ID（即客服场景中的"客户 ID"）
- `lane`：awada 路由通道（如 `user`、`admin`）

**注意**：UntrustedContext 的内容由 awada-extension 注入，不受用户控制，属于可信元数据。但 Agent 被告知该字段为"不可信上下文"，不应将其作为指令或命令执行。

**技能使用示例**：技能可以从对话上下文的第一条系统消息中提取 `awada_customer_id`，用于 CRM 关联、对话记录归档等操作。

---

## 2. 文件发送（通过 file_id）

awada 下游平台（如微信）支持云端文件。Agent 无法直接上传文件，但可以发送平台已有文件（通过 `file_id`）。

**约定格式**：Agent 在回复文本中嵌入如下标签：

```
[SEND_FILE]{"file_id":"xxx","file_name":"yyy.pdf"}[/SEND_FILE]
```

- `file_id`：平台内的文件云端 ID
- `file_name`：文件名（含扩展名，用于接收端识别文件类型）

awada-extension 的 reply dispatcher 会：
1. 检测回复文本中的所有 `[SEND_FILE]` 标签
2. 将标签内容解析并通过 awada outbound stream 发送 FileObject
3. 从回复文本中剥离标签，不将 JSON 原文发送给用户

**技能实现要点**：
- 技能可从知识库/素材库查找 `file_id`，然后构造如上格式嵌入回复
- 标签可以出现在文本的任意位置，也可以单独一行
- 一条回复可包含多个 `[SEND_FILE]` 标签（按顺序发送）
- 纯文件回复：在标签之外不包含任何文本即可（整条消息只有标签）

---

## 3. 图片和文件接收

用户发送图片或文件时，awada-extension 自动处理，Agent 无需额外操作：

- **图片**：下载或解码为本地临时文件 → 通过 OpenClaw 的 `MediaPaths` + `MediaTypes` 管道注入
  - Agent 使用的 LLM 若支持视觉（Vision），图片会被自动编码送入 vision prompt
  - 若配置了 `agents.defaults.imageModel`（独立图文模型），会先用它生成图片描述再送入主模型
  - Agent 在对话上下文中看到类似 `[media attached: image/jpeg]` 的提示
- **文件**（非图片）：下载为本地临时文件 → 同样走 `MediaPaths` 管道
  - 对于 PDF、TXT、CSV 等可读文件，openclaw 会尝试提取内容摘要
  - Agent 在对话上下文中看到类似 `[media attached: application/pdf]` 的提示

**技能影响**：如果技能需要处理用户发来的图片（如读取证件、分析截图），只需在技能描述中说明 Agent 可参考图片内容——图片内容注入由 openclaw 原生完成，技能不需要直接调用任何 API。

---

## 4. 语音消息接收

用户发送语音（audio）时，awada-extension 自动完成转写：

1. 从 awada event 中提取 audio 的 `file_url`
2. 调用 **SiliconFlow ASR API** 转写为文字
3. 转写成功：文字追加到本条消息的文本内容，与用户发的其他文字合并后送入 Agent
4. 转写失败：**直接回复用户** "对不起，我暂时不方便听语音，您能打字给我吗？"，**不触发 Agent**

> SiliconFlow ASR 依赖环境变量：
> - `SILICONFLOW_API_KEY`：SiliconFlow API Key
> - `ASR_MODEL`：语音识别模型名（如 `FunAudioLLM/SenseVoiceSmall`）
>
> 这两个变量需要在部署环境中配置，由 IT Engineer 负责。

**技能影响**：Agent 收到语音消息时，看到的是已转写的文字，行为与文字消息完全一致。技能不需要特殊处理语音场景。

---

## 5. Session 配置（多客户隔离）

客服场景通常需要每个客户有独立的对话上下文。需在 `openclaw.json` 中配置：

```json
{
  "session": {
    "dmScope": "per-channel-peer"
  }
}
```

这样 awada channel 的每个 `user_id_external` 都会有独立 session，客户 A 和客户 B 的上下文完全隔离。

> **注意**：`dmScope` 是全局配置，对所有 channel 生效（包括飞书、feishu 等其他 channel）。

---

## 6. 查阅 CS Agent 的对话历史

如需审查 cs 的对话记录（用于持续改进），直接读取本地文件：

```bash
# Session 索引（含所有 session 元数据）
cat ~/.openclaw/agents/<agentId>/sessions/sessions.json

# 某条 session 的完整对话内容
cat ~/.openclaw/agents/<agentId>/sessions/<sessionId>.jsonl
```

**禁止使用 `sessions_send`/`sessions_list`/`sessions_history` 等技能命令查询他人 session**——这些命令仅限当前自身 agent 使用。

---

## 7. CS Skill 开发约束回顾

| 能力 | 处理层 | CS Skill 需做什么 |
|------|--------|-------------------|
| 客户身份 | awada-extension 注入 UntrustedContext | 可提取 `awada_customer_id` 使用 |
| 发送文件 | reply dispatcher 解析 `[SEND_FILE]` 标签 | 构造并嵌入标签即可 |
| 接收图片/文件 | openclaw MediaPaths 管道 | 无需处理，Agent 直接读取内容 |
| 接收语音 | awada-extension 转写为文字 | 无需处理，等同文字消息 |
| 多客户隔离 | openclaw session dmScope | 部署配置问题，IT Engineer 负责 |
| 文字回复分段 | reply dispatcher 自动分块 | 无需处理 |
