单线程没问题、高并发会 crash 或返回错结果，这更像并发结构修改出了问题，而不只是死锁。死锁更常见的表现通常是卡住或超时。

我会先怀疑这些方向：

- latch 获取/释放顺序不一致
- child safe 的判断不对，导致祖先锁放早了
- split/merge 时 parent-child 关系只更新了一半
- unlatch/unpin 之后还在继续用旧节点指针

可以先检查：

1. search/insert/delete 三类操作对 safe node 的定义是不是一致且正确
2. root 到 leaf 的 latch protocol 是否统一
3. page 生命周期是否被 guard 或 RAII 正确管理
4. split/merge 期间 parent 和 sibling 的锁是否真的都在

最有帮助的是一段锁日志或失败 interleaving，至少包括 thread id、page id、锁模式和 acquire/release 顺序。

如果你把 traversal、split/merge 代码和一条失败场景贴出来，会比较容易判断是锁协议问题还是指针生命周期问题。
