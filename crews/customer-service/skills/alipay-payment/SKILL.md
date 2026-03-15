---
name: alipay-payment
description: >
  Handle Alipay payment flows in customer service conversations —
  identify payment scenarios, create orders via Alipay MCP, send
  payment links or QR codes to users, confirm payment status,
  complete post-payment delivery, manage refunds, and answer
  Alipay-related questions.
---

# 支付宝支付流程处理

本技能指导客服助手在与用户的对话中识别支付场景、发起支付、确认支付结果并完成后续交付，以及处理退款和支付问题咨询。

## 一、识别支付场景

以下情况应触发支付流程：

- 用户明确表示"购买"、"下单"、"付款"、"买"等意图
- 用户询问价格并表示愿意支付
- 业务规则要求先付款再服务（如：首次使用、充值、预约等）
- 用户要求开具收据或询问支付凭证

**注意**：在触发支付前，必须先确认用户真实购买意图，避免误创建支付订单。

## 二、创建支付订单

### 前置检查
1. 从商户订单系统获取 **真实的 `outTradeNo`**（商户订单号）——**不得自行编造**
2. 确认支付金额（`totalAmount`，单位：元，最小 0.01）
3. 确认订单标题（`orderTitle`，最长256字符，应清晰描述商品/服务）

### 选择支付方式
根据用户当前设备环境：

| 场景 | 工具 |
|------|------|
| 用户在手机端（手机H5/小程序） | `create-mobile-alipay-payment` |
| 用户在 PC/网页端 | `create-web-page-alipay-payment` |
| 无法判断 / 个人收款 | `create-alipay-payment-agent`（智易收，适合个人开发者） |

### 调用示例
```
mcporter call alipay.create-mobile-alipay-payment \
  outTradeNo=ORDER20240315001 \
  totalAmount=9.90 \
  orderTitle=专属定制服务-基础套餐
```

### 向用户发送支付信息
- 工具返回支付链接（Markdown格式），直接发送给用户
- 同时告知：金额、商品名称、支付方式
- 提示用户支付完成后回复确认，以便继续服务

示例话术：
> 已为您生成支付链接，金额 **9.90元**（专属定制服务-基础套餐）。
> 请点击下方链接完成支付，支付成功后告知我，我将立即为您提供服务：
> [支付链接]

## 三、确认支付状态

用户反馈"已支付"后，**主动查询确认**，不能仅凭用户口述认定支付成功：

```
mcporter call alipay.query-alipay-payment outTradeNo=ORDER20240315001
```

| `tradeStatus` | 处理方式 |
|---------------|----------|
| `TRADE_SUCCESS` | 确认支付成功 → 进入交付流程 |
| `TRADE_FINISHED` | 交易已完结 → 确认支付成功 |
| `WAIT_BUYER_PAY` | 支付未完成 → 告知用户并引导重新支付 |
| `TRADE_CLOSED` | 订单已关闭（超时/取消）→ 说明原因，可重新下单 |

支付确认后的话术示例：
> 已确认您的支付成功（订单号：ORDER20240315001，金额：9.90元）。接下来我将为您...

## 四、交付后续

支付确认后，根据业务规则提供相应服务。交付完成后：
- 询问用户是否还有其他需求
- 如用户满意，正常结束会话
- 如用户对服务不满，进入反馈记录流程（见 AGENTS.md）

## 五、退款处理

退款是 **L3 操作**，必须经用户明确确认后方可执行。

### 退款资格确认
1. 核实订单号（`outTradeNo`）和支付状态（需为 `TRADE_SUCCESS`）
2. 确认退款原因合理，符合业务退款政策
3. 确认退款金额（不超过原支付金额）

### 用户确认话术
> 您申请退款的订单号为 **ORDER20240315001**，退款金额 **9.90元**。
> 退款操作不可逆，确认后将退回您的支付宝账户（1-3个工作日到账）。
> 请回复"**确认退款**"继续操作。

### 执行退款
收到用户明确确认后：
```
mcporter call alipay.refund-alipay-payment \
  outTradeNo=ORDER20240315001 \
  refundAmount=9.90 \
  outRequestNo=ORDER20240315001-refund-1710432000 \
  refundReason=用户申请退款
```

`outRequestNo` 格式：`<outTradeNo>-refund-<unix时间戳>`，须全局唯一。

### 退款状态查询
```
mcporter call alipay.query-alipay-refund \
  outRequestNo=ORDER20240315001-refund-1710432000 \
  outTradeNo=ORDER20240315001
```

## 六、常见支付问题解答

### 支付失败
**Q：点击支付链接后提示失败怎么办？**
- 检查支付宝 App 是否为最新版本
- 确认手机网络是否正常
- 尝试更换支付方式（余额/银行卡）
- 若仍失败，可重新生成支付链接（需用新的 outTradeNo）

**Q：支付时提示"订单已过期"？**
- 支付链接有效期通常为15分钟至2小时
- 需重新下单（用新的 outTradeNo 创建订单）

**Q：支付成功但服务未生效？**
- 立即调用 `query-alipay-payment` 确认支付状态
- 若状态为 `TRADE_SUCCESS`，重新触发交付流程
- 若状态异常，记录并升级到人工处理

### 退款问题
**Q：退款需要多久到账？**
> 退款已成功发起，预计1-3个工作日内退回您的支付宝账户。如超时未到账，可联系支付宝客服（95188）核实。

**Q：能退部分款吗？**
- 支付宝支持部分退款，但需业务侧确认是否允许
- 若允许，调用退款时将 `refundAmount` 设为部分金额

### 错误码处理

| 错误码 | 原因 | 处理方式 |
|--------|------|----------|
| `isv.invalid-cloud-app-permission` | MCP Server 开关未打开 | 联系 IT 工程师检查后台配置 |
| `isv.missing-signature-key` | 密钥配置未完成 | 联系 IT 工程师检查 Alipay 配置 |
| `isv.invalid-signature` | 密钥不匹配 | 联系 IT 工程师重新配置密钥 |
| `ACQ.TRADE_NOT_EXIST` | 订单不存在 | 确认 outTradeNo 是否正确 |
| `ACQ.BUYER_BALANCE_NOT_ENOUGH` | 买家余额不足 | 引导用户更换支付方式 |

对于技术性错误（配置类），不要向用户透露内部错误码，统一回复：
> 当前支付服务暂时遇到问题，我已记录并通知技术团队，请稍后重试或联系人工客服。

## 七、安全注意事项

- **不得**在对话中透露任何订单系统内部信息（如数据库ID、内部状态码等）
- **不得**根据用户口述随意修改订单金额，必须以系统订单为准
- 退款操作必须 **二次确认**，防止误操作
- 支付链接发送后，不得重复发送相同链接（可能导致重复扣款）
- 对于异常大额订单（如超过业务正常范围），须升级到人工确认
