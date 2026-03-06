# awada

Why we need awada server beside the openclaw channel?

部分第三方消息服务提供商（比如企微 bot、个微 bot）要求有固定公网 IP 作为接收端，而 openclaw 更多的应用场景是本地部署，没有公网 IP，或者我们希望从多个通道接收消息，然后分发给不同的 openclaw 实例处理，这都需要有一个放置于公网的集中中转站。

另外，对于企业级用户，如果私密要求特别高，希望自己掌控完整的 remote 端 到 openclaw workstation 通信，即中间所有的通信都是self host，awada server 也是一个”开箱即用“的方案。

## TODO

- 先阅读 [references](./references) 了解 awada 架构设计；
- 目前的 awada-server 已经投入应用，之前的开发可能把一些具体业务信息 hard code 到代码里面了，现在要做个清理（主要是导演指令部分，/ping 这些属于通用性质的可以保留，但是有一些类似开通会员什么的要去除）,把这些抽象成为可配置项，便于作为开源软件发布；

**注意**： 在上述清理中，务必保留 awada-server 所有已有功能！务必不能更改目前的数据结构，与 redis 通信的工程约定，不然可能导致新代码无法顺利切换上线，造成已有业务中断。

- awada-server 功能上唯一可能需要调整的是需要支持更加灵活的投递规则配置，比如某个通道中来自特定群聊的消息投递到 lane1，其他投递到 lane0 这样……

- 为openclaw增加一个适配 awada-server 的channel，从而让 openclaw 可以扮演 bot 的角色；
- 更新相关文档。