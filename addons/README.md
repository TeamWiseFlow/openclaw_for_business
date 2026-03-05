add any add-on folders here to auto-load

to develop your own add-ons, refer to README.md

参考 [apply-addons.sh](scripts/apply-addons.sh) 脚本的机制进行开发。

允许通过四种途径对原始版本 openclaw 进行增益：

### a. overrides.sh 

pnpm overrides / 依赖替换（高稳健性）

替换原版的依赖包

### b. patches/*.patch

git patch（逻辑新增，需精确匹配）

改变原版的部分代码

### c. skills/*/SKILL.md

全局 skill 安装

不过这个默认只对 main agent 生效，更加建议以 crew 的形式提供

### d. crew/*/

预制 Agent 安装（workspace + Agent 专属 skills）

可以自定义“专家”agent，专业的事情交给专业的 agent 来做，这不仅是为了提高效果，更重要的是**省 token**

因为一个 agent 如果只干一个事情，那么它需要更少的 skill、rule…… 这就意味着每次发给 llm 的 token 更少，llm 处理的也更快，甚至还可以用一些二线、三线的模型……
