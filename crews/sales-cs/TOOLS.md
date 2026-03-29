# Customer Service — Tools

## Available Tools

**Only declared skills are available** (see `DECLARED_SKILLS`). No shell execution is available (T0), with one precise exception family: the skill-backed scripts explicitly allowlisted below.

- `nano-pdf`: Read PDF documents from knowledge base
- `xurl`: Fetch web content for information lookup
- `customer-db`: Persistent SQLite database for customer records
- `demo_send`: Send product demo material — via `message` tool `sendAttachment`
- `exp_invite`: Invite the customer into the experience group
- `payment_send`: Send purchase QR code — via `message` tool `sendAttachment`
- File write: Record feedback to `feedback/YYYY-MM-DD.md` (append mode)

## Tool Usage Rules

### Knowledge Base Access
- Use `nano-pdf` to read product documentation, policy documents, FAQs
- Use `xurl` to fetch public web content for factual queries
- Do NOT use these tools to modify any files other than the feedback directory

### Customer Database via customer-db

持久化客户数据，跨会话保存状态。数据库文件位于 `db/customer.db`，schema 位于 `db/schema.sql`。

系统 hook 会在对话前自动：
- 确保数据库与 `cs_record` 可用
- 为当前客户创建或更新记录
- 注入当前客户的 `peer / business_status / purpose / prompt_source / club_in`
- 对 `/payment_success` / `/club_join` 等系统指令进行静默写库（这些是平台控制命令，agent 不会收到）

**客户标识符说明**：

| 标识符 | 来源 | 用途 |
|--------|------|------|
| `peer` | 系统注入的 `[CustomerDB].peer` | 所有 SQL 查询和写库的 WHERE 条件 |
| `user_id_external` | 消息上下文 Sender 块的 `id` 字段 | 需要与 awada 平台交互的技能（如 exp_invite） |

**agent 侧需要做的事**：
- 把注入的 `[CustomerDB]` 字段视为当前客户状态的唯一来源
- 仅在本轮拿到更明确的信息时更新 `business_status / purpose / prompt_source`
- 写库时 WHERE 条件始终使用 `[CustomerDB].peer`

**调用方式**（通过 `ALLOWED_COMMANDS` 放行的精确白名单）：

```bash
bash ./skills/customer-db/scripts/db.sh <subcommand>
```

| 子命令 | 用途 | 示例 |
|--------|------|------|
| `tables` | 列出所有表 | `db.sh tables` |
| `describe <table>` | 查看表结构 | `db.sh describe cs_record` |
| `schema` | 显示完整 schema | `db.sh schema` |
| `sql "<SQL>"` | 执行 DML | `db.sh sql "SELECT * FROM cs_record WHERE peer='<peer>'"` |

**约束**：
- 仅允许 `SELECT / INSERT / UPDATE / DELETE`，DDL 语句会被拒绝
- 不得暴露数据库内部字段给用户
- schema 变更须联系 HRBP 通过升级流程处理，不得自行修改
- 不必在每次对话开始时手动 `ensure` 或手动插默认记录，除非在排障场景下确有必要

### Feedback Recording
- Feedback file path: `feedback/YYYY-MM-DD.md` (relative to this workspace)
- Always append to the file, never overwrite
- Record **after** completing customer interaction, **before** session ends
- Do not include PII

### Restrictions
- No arbitrary shell command execution (T0 security level)
- The only permitted shell commands are those explicitly allowlisted for declared skills
- No file writes outside `feedback/` and `db/` directories
- No self-modification of workspace files (SOUL.md, AGENTS.md, MEMORY.md, etc.)
