最像的故障类是两种：块被重复释放，或者你更早把 header/footer 或 free-list 指针写坏了，等到 `free()` 才炸。

先别改代码，先查不变量：

- `GET_SIZE(HDRP(bp))` 是否对齐、是否至少是最小块大小
- `GET_ALLOC(HDRP(bp))` 进入 `free(bp)` 时是不是已经是 0
- header/footer 是否一致
- free list 里同一个块是否出现两次
- coalesce 之后你是否还在用旧 `bp`

我会先在这几处打最小日志或断言：

- `free(bp)` 入口：`bp`, `size`, `alloc`
- `coalesce(bp)` 前后：前块/后块是否空闲，返回的是哪个块
- `insert/remove free list`：插入或删除的块地址，以及它的 `prev/next`

如果一进 `free()` 就看到 alloc bit 已经是 0，那基本就是重复释放，或者这个块的元数据之前就被写坏了。  
如果 `size` 是离谱值，优先回查 `place/split` 有没有把相邻块边界写坏。

下一步别发整个项目，先给最小一组东西：

- `free`
- `coalesce`
- free-list 的 `insert/remove`
- 一次最小复现序列
- 崩溃前那次 `free()` 打出来的四个值

如果你已经有 `mm_checkheap()`，把它插到每次 `malloc/free/coalesce` 后面，目标不是“最后检查”，而是找到“第一次堆结构坏掉”的那一步。
