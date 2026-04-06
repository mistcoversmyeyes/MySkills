看描述，这更像是 election 状态和投票回复处理没有绑紧，而不只是“超时时间不对”。

先看 4 个最容易出问题的点：

1. 发起选举时的原子性：`currentTerm += 1`、`state = Candidate`、`votedFor = me`、`voteCount = 1` 是否一致更新。
2. RequestVote reply 回来时，是否先确认 reply 还属于当前这轮 election。
3. 更高 term 的 reply 是否会立刻触发降级成 follower。
4. RequestVote handler 的判票条件有没有把日志新旧、`votedFor` 和 term 处理错。

我建议先打最小日志：

- 发起 election 时的 `term/state/voteCount`
- 发 RPC 时带的 `term`
- 收 reply 时的 `reply.Term`、`VoteGranted`、当前 `term/state`

你真正想回答的问题是：是不是有旧 term 的 reply 还在给当前轮次加票。

如果你把 `startElection`、reply handling 和 RequestVote handler 贴出来，我可以继续往下缩到更具体的状态转换问题。
