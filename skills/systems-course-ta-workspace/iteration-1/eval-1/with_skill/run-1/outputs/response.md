这类 “Election 有时过有时不过” 最像状态机边界没收紧，不是单纯 timeout 参数问题。  
我会先怀疑三件事：

- 旧的 `RequestVote` reply 还在给当前轮次加票
- 看到更高 term 时没有立刻降级成 follower
- `currentTerm/state/votedFor/voteCount` 不是在同一个锁保护下更新

先按 Raft 不变量缩：

- 一轮 election 只能对应一个 `electionTerm`
- 只有当前仍是 `Candidate` 时，reply 才能参与计票
- 同一 peer 在同一轮里最多算一票
- 任何更高 term 都必须立刻触发降级

最值得先看的不是整个项目，而是 3 段：

- 发起 election 的代码
- 处理 `RequestVote` reply 的代码
- `RequestVote` handler 本身

我建议先打最小日志，而不是盲改：

- 发起 election 时：`term/state/votedFor/voteCount`
- 发 RPC 时：发给谁、携带的 `term/lastLogIndex/lastLogTerm`
- 收 reply 时：`reply.Term`, `VoteGranted`, 当前 `term`, 当前 `state`, 这条 reply 属于哪轮 election

你真正想证明的是：有没有旧 reply 在你已经降级、或者 term 已变之后，仍然把票数加进来了。

下一步把这三段代码和一段失败日志贴出来就够了。我会先帮你查状态转换是否违反了 term/state/votedFor 的不变量，再看具体行级修正。
