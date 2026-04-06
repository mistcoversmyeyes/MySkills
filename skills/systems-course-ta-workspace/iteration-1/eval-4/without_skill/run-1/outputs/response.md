从描述看，overlapping segments 的处理确实很可疑，尤其是你说 Wireshark 里序列号看起来没问题，但你自己的 buffer 数据已经乱了。

我会先检查这几个方向：

- segment 插入位置是否算对
- overlap 时是保留旧数据还是新数据，策略有没有统一
- merge 之后长度和边界是否更新正确
- 有没有在乱序到达时把数据复制到了错误偏移

这种问题通常不能只看 seq number 对不对，还要看你的 reassembly buffer 在每一步之后长什么样。因为 seq 对，不代表最后拷贝进去的 payload 对。

可以重点检查：

1. 新 segment 完全被已有数据覆盖时怎么处理  
2. 新 segment 和已有 segment 部分重叠时怎么裁剪  
3. merge 多个相邻或重叠 segment 时，边界和数据有没有一起更新  
4. `next expected seq` 推进之后，旧数据有没有被正确丢掉

如果你方便的话，最好给一个具体例子，比如几段 packet 的到达顺序、每段的 seq 范围、以及你的 buffer 在每一步的状态。那样比只看代码更容易定位问题。
