单纯按 degree 决定 spill 候选，确实很容易把“长但很热”的 live range 扔进内存，结果越 spill 越慢。

我会先把问题拆成三个量：

- spill cost
- loop depth / block frequency
- 这个 live range 能不能切分

比单纯 degree 更靠谱的方向通常是：

1. 用 spill cost 选候选，而不是先看谁邻居多  
2. 把热循环里的 use/def 权重放大  
3. spill 之后重算，而不是整段一刀切  
4. 对可 rematerialize 的值降低 spill 代价  
5. 保守做 coalescing，别把图越并越密

如果你现在实现还比较简单，我会建议最小升级顺序：

- 先把 spill heuristic 改成 block-frequency aware
- 再做 optimistic coloring
- 然后只在 loop boundary 或稀疏 use 区加 live-range splitting

别先上大换血算法。先拿数据说话：

- spill 前后运行时间
- 动态 load/store 数
- move 数
- 编译时间
- 哪些值在热循环里被反复 reload

下一步只要给我：

- 你的 spill 代价公式
- 一段失败的 interference graph 或 live interval 信息
- 一组 baseline numbers

我可以先帮你判断问题是 cost model 太粗，还是根本缺少 splitting / rematerialization。
