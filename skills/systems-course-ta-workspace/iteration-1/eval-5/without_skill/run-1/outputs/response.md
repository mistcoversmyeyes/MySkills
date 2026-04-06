你这个现象很常见：live range 很长、又出现在热路径里，如果简单按 degree 去选 spill 候选，就很容易 spill 得越多越慢。

比纯 degree 更靠谱的方向通常有：

- 用 spill cost 而不是只看邻居数
- 把循环深度或 block frequency 纳入权重
- 对长 live range 做 splitting
- 对可重算的值做 rematerialization
- 避免过度 coalescing 把图弄得更密

如果你现在实现还比较基础，我会先建议：

1. 改 spill heuristic，让热路径上的 use/def 更贵
2. 不要太早决定 spill，尽量晚一点再判断
3. 加一些 baseline measurement，比如运行时间、动态 load/store、move 数

如果你把当前 spill cost 的公式和一组 baseline numbers 给我，我可以继续帮你判断是 cost model 太粗，还是需要做 splitting。
