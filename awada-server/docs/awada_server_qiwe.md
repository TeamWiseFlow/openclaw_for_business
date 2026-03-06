# chatbot-new

基于 qiweapi 的微信智能机器人项目。

## 技术栈

- Node.js + TypeScript
- Koa2
- qiweapi (https://doc.qiweapi.com/)

## 项目结构

```
chatbot-new/
├── src/
│   ├── index.ts          # 入口文件
│   ├── app.ts            # Koa应用配置
│   └── routes/
│       ├── webhook.ts    # qiweapi消息回调
│       └── api.ts        # 对外API接口
├── config/
│   ├── index.ts          # 配置入口
│   ├── config.json       # 业务配置
│   └── qiweapi.ts        # qiweapi配置
├── services/
│   ├── qiweapi/          # qiweapi API封装
│   │   ├── client.ts     # HTTP客户端
│   │   ├── types.ts      # 类型定义
│   │   ├── instance.ts   # 实例管理
│   │   └── login.ts      # 登录管理
│   ├── bot/              # 业务逻辑
│   └── algorithm/        # AI接口
├── utils/                # 工具函数
└── database/             # 数据存储
```

## 安装

```bash
# 安装依赖
npm install
# 或
pnpm install
```

## 配置

1. 复制 `.env.example` 为 `.env`
2. 填写 qiweapi 的配置信息：

```env
QIWEAPI_BASE_URL=https://api.qiweapi.com
QIWEAPI_APP_KEY=your_app_key
QIWEAPI_APP_SECRET=your_app_secret
CALLBACK_URL=http://your-server.com/webhook
```

## 运行

```bash
# 开发模式
npm run dev

# 生产模式
npm run build
npm start

# 使用PM2
pm2 start pm2.config.js
```

## API接口

### Webhook回调

- `POST /webhook` - 通用回调入口
- `POST /webhook/message` - 消息回调
- `POST /webhook/friendship` - 好友请求回调
- `POST /webhook/room-change` - 群成员变动回调
- `GET /webhook/health` - 健康检查

### 对外API

- `GET /api/userinfo` - 获取当前用户信息
- `GET /api/qrcode` - 获取登录二维码
- `GET /api/login/status` - 获取登录状态
- `POST /api/sendtxtmsg` - 发送文本消息
- `POST /api/sendimgmsg` - 发送图片消息
- `POST /api/sendfilemsg` - 发送文件消息
- `GET /api/health` - 健康检查

## 从 wechaty_old 迁移

本项目是从 wechaty_old 迁移而来，主要变化：

1. **消息接收方式**：从 wechaty SDK 事件监听改为 HTTP Webhook 回调
2. **消息发送方式**：从 `msg.say()` 改为调用 qiweapi HTTP API
3. **登录方式**：从扫码事件改为 API 获取二维码 + 轮询状态

## License

ISC

