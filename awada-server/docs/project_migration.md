# 微信机器人项目迁移方案：wechaty → qiweapi

> 迁移目标：将 `wechaty_old` 项目迁移至新技术方案 `qiweapi`，保持业务逻辑不变

---

## 一、项目现状分析

### 1.1 wechaty_old 核心架构

**技术栈**：
- 基于 `@juzi/wechaty`（句子互动的wechaty服务）
- Node.js + TypeScript + Koa
- 事件驱动模型（SDK方式）

**核心事件监听**：
| 事件 | 说明 |
|------|------|
| `scan` | 扫码登录 |
| `login` | 登录成功 |
| `logout` | 退出登录 |
| `message` | 消息接收 |
| `friendship` | 好友请求 |
| `room-join` / `room-leave` | 群成员变动 |

**业务功能**：
- ✅ 权限管理（directors管理员、权限群、权限用户）
- ✅ 群管理（start/stop/talking/update 命令）
- ✅ AI问答（调用后端 `callAgent` 接口）
- ✅ 文档校对（调用 `wordCorrect` 接口）
- ✅ 敏感词过滤
- ✅ 好友请求自动通过
- ✅ 多消息类型处理（文本、语音、文件、图片）

### 1.2 qiweapi 核心特点

**架构差异**：
- HTTP API + Webhook 回调模式（非SDK）
- 需要主动创建设备实例
- 消息通过回调地址推送接收

**核心模块**：
- 实例管理（创建/恢复/停止设备）
- 登录模块（二维码获取/检测/登录状态）
- 消息模块（发送各类消息）
- 联系人模块
- 群模块
- 云存储CDN模块

**文档地址**：https://doc.qiweapi.com/

---

## 二、架构设计

### 2.1 核心架构变化

```
┌─────────────────────────────────────────────────────────────────┐
│                        旧架构（wechaty）                          │
├─────────────────────────────────────────────────────────────────┤
│  wechaty SDK ──事件监听──> onMessage回调 ──> 业务处理 ──> msg.say()  │
└─────────────────────────────────────────────────────────────────┘
                              ↓ 迁移
┌─────────────────────────────────────────────────────────────────┐
│                        新架构（qiweapi）                          │
├─────────────────────────────────────────────────────────────────┤
│  qiweapi回调 ──Webhook接口──> 消息处理 ──> 业务处理 ──> 发送消息API   │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 新项目目录结构

```
chatbot-new/
├── src/
│   ├── index.ts                    # 入口文件
│   ├── app.ts                      # Koa应用配置
│   └── routes/
│       ├── webhook.ts              # qiweapi消息回调路由（核心新增）
│       └── api.ts                  # 对外API接口（保持原有）
│
├── config/
│   ├── index.ts                    # 配置入口
│   ├── config.json                 # 业务配置（保持）
│   └── qiweapi.ts                  # qiweapi配置（新增）
│
├── services/
│   ├── qiweapi/                    # qiweapi API封装（核心新增）
│   │   ├── index.ts
│   │   ├── client.ts               # HTTP客户端封装
│   │   ├── types.ts                # 类型定义
│   │   ├── message.ts              # 消息发送API
│   │   ├── contact.ts              # 联系人API
│   │   ├── group.ts                # 群管理API
│   │   ├── login.ts                # 登录管理API
│   │   ├── cdn.ts                  # 文件上传下载API
│   │   └── instance.ts             # 实例管理API
│   │
│   ├── bot/                        # 业务逻辑（改造）
│   │   ├── message/                # 消息处理（改造）
│   │   │   ├── index.ts            # 消息处理入口
│   │   │   ├── filter.ts           # 消息过滤
│   │   │   ├── msg.ts              # 消息解析
│   │   │   ├── person/             # 私聊消息处理
│   │   │   └── plan/               # 问答处理
│   │   ├── friendship.ts           # 好友请求处理
│   │   └── room.ts                 # 群事件处理
│   │
│   └── algorithm/                  # AI接口（直接复用）
│       ├── index.ts
│       ├── plan.ts
│       ├── response.ts
│       ├── type.ts
│       └── word.ts
│
├── utils/                          # 工具函数（改造）
│   ├── index.ts
│   ├── permission.ts               # 权限管理（改造自wechaty-ui.ts）
│   ├── message.ts                  # 消息工具
│   ├── file.ts                     # 文件工具
│   ├── format.ts                   # 格式化（复用）
│   ├── sensitive.ts                # 敏感词（复用）
│   └── type.ts                     # 类型定义
│
├── database/                       # 数据存储（保持）
│   ├── cache/
│   ├── files/
│   └── wechatyui/
│
├── sensitive/                      # 敏感词库（保持）
│
├── package.json
├── tsconfig.json
└── README.md
```

---

## 三、功能映射表

| 原wechaty功能 | qiweapi对应方案 | 说明 |
|--------------|----------------|------|
| `WechatyBuilder.build()` | 创建设备API + 恢复实例API | 初始化机器人实例 |
| `bot.on('scan')` | 二维码获取API + 轮询检测 | 登录二维码流程 |
| `bot.on('login')` | 用户登录API + 用户状态API | 登录状态管理 |
| `bot.on('logout')` | 注销API | 退出登录 |
| `bot.on('message')` | **设置回调地址 + Webhook接口** | 核心消息接收 |
| `bot.on('friendship')` | 消息回调（好友申请类型） + 同意申请API | 好友请求处理 |
| `bot.on('room-join')` | 消息回调（群成员变动） | 群成员加入 |
| `bot.on('room-leave')` | 消息回调（群成员变动） | 群成员离开 |
| `msg.say(text)` | 发送纯文本消息API | 发送文本 |
| `room.say(text, @users)` | 发送混合文本消息API | 群消息+@功能 |
| `msg.toFileBox()` | 企微/个微文件下载API | 接收文件 |
| `FileBox.fromFile()` | 文件上传API | 发送文件 |
| `Contact.find()` | 联系人详情-批量API | 查询联系人 |
| `Room.find()` | 群详情-批量API | 查询群信息 |
| `msg.mentionSelf()` | 消息回调内容解析 | 检测是否被@ |
| `msg.mentionList()` | 消息回调内容解析 | 获取@列表 |

---

## 四、实施计划

### 第一阶段：基础架构搭建（2-3天） ✅ 已完成

| 任务 | 优先级 | 状态 |
|------|--------|------|
| 初始化项目结构（package.json, tsconfig.json） | 高 | ✅ |
| 搭建Koa服务框架 | 高 | ✅ |
| 实现qiweapi客户端基础类（client.ts） | 高 | ✅ |
| 实现实例管理（创建/恢复/停止） | 高 | ✅ |
| 实现登录模块（二维码流程） | 高 | ✅ |
| 配置回调Webhook接口 | 高 | ✅ |

### 第二阶段：消息处理核心（3-4天）

| 任务 | 优先级 | 状态 |
|------|--------|------|
| 实现消息回调接收和解析 | 高 | ⬜ |
| 适配消息类型映射 | 高 | ⬜ |
| 迁移消息过滤逻辑（filter.ts） | 高 | ⬜ |
| 迁移消息解析逻辑（msg.ts） | 高 | ⬜ |
| 实现消息发送封装（文本/图片/文件/语音） | 高 | ⬜ |
| 实现@功能适配 | 高 | ⬜ |

### 第三阶段：业务逻辑迁移（2-3天）

| 任务 | 优先级 | 状态 |
|------|--------|------|
| 迁移群消息处理逻辑（导演命令） | 高 | ⬜ |
| 迁移私聊消息处理逻辑 | 高 | ⬜ |
| 迁移AI问答功能（algorithm模块直接复用） | 高 | ⬜ |
| 迁移文档校对功能 | 高 | ⬜ |

### 第四阶段：辅助功能迁移（2天）

| 任务 | 优先级 | 状态 |
|------|--------|------|
| 迁移好友请求处理 | 中 | ⬜ |
| 迁移群成员变动处理 | 中 | ⬜ |
| 迁移权限管理逻辑 | 中 | ⬜ |
| 迁移敏感词过滤 | 中 | ⬜ |
| 迁移配置文件监听 | 中 | ⬜ |

### 第五阶段：对外API接口（1天）

| 任务 | 优先级 | 状态 |
|------|--------|------|
| 迁移 `/api/sendtxtmsg` | 中 | ⬜ |
| 迁移 `/api/sendimgmsg` | 中 | ⬜ |
| 迁移 `/api/sendfilemsg` | 中 | ⬜ |
| 迁移 `/api/userinfo` | 中 | ⬜ |

### 第六阶段：测试和优化（3-4天）

| 任务 | 优先级 | 状态 |
|------|--------|------|
| 单元测试 | 高 | ⬜ |
| 集成测试 | 高 | ⬜ |
| 并行运行对比测试 | 高 | ⬜ |
| 性能优化 | 中 | ⬜ |
| 文档编写 | 中 | ⬜ |

**预估总工期**：约 2-3 周

---

## 五、代码复用情况

### 可直接复用（约60%）

| 模块 | 文件 | 说明 |
|------|------|------|
| AI接口 | `algorithm/*` | 完全复用，无需修改 |
| 敏感词过滤 | `sensitive.ts` | 完全复用 |
| 文本格式化 | `format.ts` | 完全复用 |
| 业务配置 | `config.json` | 完全复用 |
| 数据存储 | `database/` | 目录结构保持 |
| 敏感词库 | `sensitive/` | 完全复用 |

### 需要改造（约30%）

| 模块 | 改造内容 |
|------|----------|
| `message.ts` | 移除FileBox依赖，改用qiweapi CDN API |
| `wechaty-ui.ts` → `permission.ts` | 移除wechaty依赖，纯数据操作 |
| `bot/message/*` | 适配新的消息对象结构 |
| `file.ts` | 适配qiweapi文件上传下载 |

### 需要新增（约10%）

| 模块 | 说明 |
|------|------|
| `services/qiweapi/*` | qiweapi API封装层 |
| `routes/webhook.ts` | 消息回调接收路由 |
| 登录流程代码 | API方式的扫码登录 |
| 类型定义 | qiweapi相关类型 |

---

## 六、风险点与应对

| 风险 | 影响 | 应对措施 |
|------|------|----------|
| 消息回调格式差异 | 中 | 建立消息适配层，统一内部消息格式 |
| @功能实现差异 | 中 | 详细阅读qiweapi文档，测试验证 |
| 文件处理流程变化 | 中 | 封装统一的文件服务类 |
| 登录状态维护 | 高 | 实现状态检测和自动重连机制 |
| qiweapi服务稳定性 | 中 | 添加错误重试和日志监控 |
| 消息类型不完全对应 | 低 | 枚举所有类型，逐个适配 |

---

## 七、技术栈

### 保持不变
- Node.js + TypeScript
- Koa + koa-router + koa-bodyparser
- dayjs（时间处理）
- JSON5（配置解析）
- PM2（进程管理）

### 新增/替换
- axios / node-fetch（HTTP请求，替代 request 库）
- qiweapi 相关类型定义

### 移除
- @juzi/wechaty
- @juzi/wechaty-puppet
- @juzi/wechaty-puppet-service
- file-box
- qrcode-terminal

---

## 八、迁移建议

1. **保持业务逻辑不变**
   - 将底层通信封装好，业务层代码改动最小化
   - 使用适配器模式屏蔽底层差异

2. **建立适配层**
   - 创建统一的消息对象结构（MSGType）
   - 封装统一的发送消息方法
   - 屏蔽底层API差异

3. **渐进式迁移**
   - 可以让两个项目并行运行
   - 逐步验证功能正确性
   - 确认无误后再切换

4. **完善日志**
   - 增加关键节点日志
   - 便于问题排查
   - 记录API调用情况

5. **错误处理**
   - 实现统一的错误处理机制
   - 添加重试逻辑
   - 通知管理员机制

---

## 九、qiweapi 关键API参考

### 实例管理
- `POST /device/create` - 创建设备
- `POST /device/recover` - 恢复实例
- `POST /device/stop` - 停止实例
- `POST /device/callback` - 设置回调地址

### 登录模块
- `POST /qrcode/get` - 获取二维码
- `POST /qrcode/check` - 检测二维码状态
- `POST /user/login` - 用户登录
- `POST /user/status` - 用户状态

### 消息模块
- `POST /message/send` - 发送消息（通用）
- `POST /message/text` - 发送纯文本
- `POST /message/image` - 发送图片
- `POST /message/file` - 发送文件
- `POST /message/voice` - 发送语音

### CDN模块
- `POST /cdn/upload` - 文件上传
- `POST /cdn/download` - 文件下载

---

## 十、附录

### 原项目关键文件清单

```
wechaty_old/
├── src/index.ts                           # 入口，bot初始化和HTTP服务
├── config/
│   ├── index.ts                           # 配置入口
│   └── config.json                        # 业务配置
├── service/
│   ├── bot/
│   │   ├── scan.ts                        # 扫码登录
│   │   ├── login.ts                       # 登录成功
│   │   ├── logout.ts                      # 退出
│   │   ├── friendship.ts                  # 好友请求
│   │   ├── room-join.ts                   # 群成员加入
│   │   ├── room-leave.ts                  # 群成员离开
│   │   ├── error.ts                       # 错误处理
│   │   └── message/
│   │       ├── index.ts                   # 消息处理入口
│   │       ├── filter.ts                  # 消息过滤
│   │       ├── msg.ts                     # 消息解析
│   │       ├── log.ts                     # 消息日志
│   │       ├── person/                    # 私聊处理
│   │       │   ├── index.ts
│   │       │   ├── conversation.ts
│   │       │   ├── const.ts
│   │       │   └── message-func.ts
│   │       └── plan/
│   │           └── index.ts               # 问答处理
│   └── algorithm/
│       ├── index.ts
│       ├── plan.ts                        # AI问答请求
│       ├── response.ts                    # 响应处理
│       ├── type.ts                        # 类型定义
│       └── word.ts                        # 文档校对
├── utils/
│   ├── index.ts
│   ├── wechaty-ui.ts                      # 权限管理
│   ├── message.ts                         # 消息工具
│   ├── file.ts                            # 文件工具
│   ├── format.ts                          # 格式化
│   ├── sensitive.ts                       # 敏感词
│   ├── type.ts                            # 类型定义
│   ├── bot.ts                             # Bot工具
│   ├── normalchat.ts                      # 普通聊天
│   └── service.ts                         # 服务工具
└── database/
    ├── cache/
    ├── files/
    └── wechatyui/
        ├── room_users.json
        └── users_alias.json
```

---

**文档版本**：v1.0  
**创建日期**：2024-12-12  
**最后更新**：2024-12-12

