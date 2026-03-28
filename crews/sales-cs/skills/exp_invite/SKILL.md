---
name: exp_invite
description: >
  Invite a qualified customer into the experience group when they want to
  understand the product form further after seeing demo materials. The invite
  is sent as an awada control message, and the customer status is updated to
  exp_invited to prevent duplicate invitations.
---

# exp_invite

## 用途
当客户希望进一步了解产品形态、看完 demo 后仍有较大疑问，且明确同意加入体验群时，发送体验群邀请。

## 调用方式

```bash
bash ./skills/exp_invite/scripts/invite.sh --user-id-external "<meta.user_id_external>"
```

## 客户标识提取规则
这里一定要原样使用 `meta.user_id_external` 

## 行为规则
- 邀请消息不是发给用户看的自然语言，而是 awada 控制消息：

```text
/invite//<user_external_id>//风暴眼（wiseflow情报小站）
```

- awada-channel 会将其转为拉群动作
- 发送前先查询数据库：
  - 若当前 `business_status` 已是 `exp_invited`，则**不要重复邀请**
  - 此时应回到主流程 3.7，继续主动引导
- 若尚未邀请，则：
  1. 更新数据库中的 `business_status = exp_invited`
  2. 输出 invite 控制消息

## 返回约定
- 成功：标准输出 invite 控制消息
- 已邀请过：输出 `ALREADY_INVITED`，并以非 0 状态退出

## 当前体验群名称
- `风暴眼（wiseflow情报小站）`
