从症状看，我先把优先级放成：

1. latch 协议实现错了，导致结构在并发修改下不一致  
2. unlatch/unpin 之后还在用旧 page/node 指针  
3. 死锁

因为“crash 或错误结果”更像结构损坏；纯死锁通常更像卡住或超时。

先把并发 B+ tree 里该守住的不变量写清楚：

- parent 的 separator 必须和 child 的边界一致
- split/merge 时，parent-child 可见性不能只更新一半
- leaf sibling 链不能断
- 线程释放 latch 之后，不能继续依赖旧节点内容
- 锁获取顺序必须一致

如果你用了 latch crabbing，先检查 `safe` 的定义是不是按操作区分了：

- search
- insert
- delete

很多实现的问题不是“没加锁”，而是 child 一 safe 就把祖先锁全放了，但后面又要做需要结构稳定性的修改。

下一步我只要这些最小 artifact：

- 从 root 到 leaf 的 latch 获取/释放逻辑
- split 或 merge 的路径
- page guard / unpin 生命周期代码
- 一段失败 interleaving 或锁日志

日志建议至少打：

- thread id
- page id
- latch mode
- acquire/release
- 当前操作类型
- 判断 child safe 的结果

如果你能给一条最小 interleaving，我会先帮你判断它更像 lock ordering、stale pointer，还是 split/merge 的原子性破坏。
