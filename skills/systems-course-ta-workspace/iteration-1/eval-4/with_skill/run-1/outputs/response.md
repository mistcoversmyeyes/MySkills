如果线上 seq 看着对，但你本地 reassembly buffer 里的数据已经乱了，我第一怀疑不是 seq 比较本身，而是 overlap trim 之后，payload 偏移没有一起更新。

先把数据模型收紧成半开区间：

- 每段表示成 `[start, end)`
- `len = end - start`
- payload 的第 0 个字节必须对应 `start`

然后守住这几个不变量：

- buffer 中的区间按 `start` 递增
- 最终区间互不重叠
- `next_expected_seq` 之前的数据会被裁掉
- 区间变化时，payload slice 也同步变化

最容易错的 case 是：

- 已有 `[100,120)`
- 新来一段被裁成 `[108,120)`

如果你只把 `start` 改到 108，却没有把 payload 的读取起点前移 8 字节，区间看起来对，字节内容会错位。

下一步别拿大流量硬撞，先手工跑 3 个最小 case：

- 简单乱序：`[110,120)`, `[100,110)`
- 前缀 overlap：已有 `[100,120)`, 新来 `[90,110)`
- 后缀 overlap：已有 `[100,120)`, 新来 `[110,130)`

把每一步打印成：

- 插入前 buffer
- 新 segment 的区间和 payload offset
- 裁剪/合并后的区间
- 交付前的 buffer

如果你贴一个具体 packet trace 和你当前的 trim/merge 代码，我可以先帮你检查 sequence-space 推理有没有和 payload 管理脱节。
