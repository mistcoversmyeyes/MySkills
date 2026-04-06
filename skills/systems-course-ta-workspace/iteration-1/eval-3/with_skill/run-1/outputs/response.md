这更像 lazy allocation 语义没有在整条 VM 路径里统一，而不是“锁还没加够”。

核心前提是：`sbrk` 之后，`0..p->sz` 里可以存在“合法但尚未映射”的页。  
如果只有 `usertrap()` 接受这个状态，而 `uvmunmap/uvmcopy/copyin/copyout` 还默认“合法地址就必须已映射”，panic 就会是随机的。

我会先查这几条路径：

- `usertrap()` 的 page-fault 分支是否只对 `< p->sz` 的地址做懒分配
- `uvmunmap()` 遇到未映射但合法的页时是否还会 panic
- `uvmcopy()` 在 `fork()` 时如何处理还没 fault 过的页
- `walkaddr/copyin/copyout` 对缺失 PTE 的语义是不是一致

先别贴整个内核。下一步最有用的是：

- 具体 `panic` / `scause` / `stval`
- 一个稳定复现方式
- `usertrap`
- `uvmunmap`
- `uvmcopy`

最小复现我会优先试：

1. `sbrk(PGSIZE)` 后直接 `fork()`  
2. `sbrk(PGSIZE)` 后让内核通过 syscall 访问这页  
3. `sbrk(PGSIZE)` 后退出，看 `uvmunmap()` 会不会炸

如果你把 exact panic 文本和其中一条复现路径给我，我可以很快判断是 page-fault 入口错了，还是某个 VM helper 还保留了旧语义。
