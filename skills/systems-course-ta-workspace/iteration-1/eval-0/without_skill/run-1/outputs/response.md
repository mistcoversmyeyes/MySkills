`free()` 崩溃通常说明问题不一定在 `free` 本身，而是更早之前堆结构已经被破坏了。常见原因有：

- double free
- header/footer 被写坏
- free list 指针损坏
- coalesce 或 split 之后继续使用旧指针

我建议你先检查这些地方：

1. `free(bp)` 入口时，这个块的 alloc bit 是不是已经是 0  
2. `GET_SIZE(HDRP(bp))` 算出来的大小是否合理、是否对齐  
3. `coalesce()` 合并前后，前后块状态和返回指针是否正确  
4. 如果你有显式 free list，`insert/remove` 是否维护好了 `prev/next`

如果条件允许，优先上 AddressSanitizer 或 Valgrind，看是不是能更快定位到第一次写坏堆元数据的位置。

另外最好加一个 heap checker，检查：

- header/footer 一致
- free block 没有重复出现在 free list
- 相邻空闲块是否正确合并

如果你把相关代码贴出来，我建议至少包括：

- `malloc`
- `free`
- `coalesce`
- `place`
- free list 相关操作

这样比较容易判断到底是重复释放，还是元数据在更早的时候已经坏掉了。
