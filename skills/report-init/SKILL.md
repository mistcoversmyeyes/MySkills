---
name: report-init
description: 初始化日报或周报草稿。仅通过 /report-init 手动调用。
disable-model-invocation: true
arguments: [TYPE, MODE]
argument-hint: "[daily|weekly] [full|quick]"
---

# Report Init

初始化一份报告草稿（日报或周报），根据参数路由到对应的 subagent 执行。

## 根据参数路由到对应子 agent 生成报告草稿
根据解析结果，读取并执行对应的 agent 文件：

- $TYPE == daily, $MODE == full → 读取并执行 [agents/daily-report-maker-full.md](agents/daily-report-maker-full.md)
- $TYPE == daily, $MODE == quick → 读取并执行 [agents/daily-report-maker-quick.md](agents/daily-report-maker-quick.md)
- $TYPE == weekly, $MODE == full → 读取并执行 [agents/weekly-report-maker-full.md](agents/weekly-report-maker-full.md)
- $TYPE == weekly, $MODE == quick → 读取并执行 [agents/weekly-report-maker-quick.md](agents/weekly-report-maker-quick.md)

读取对应的 agent 文件后，严格按照其中的工作流指令执行。

## 根据用户要求，交互式修改报告草稿

子 agent 生成草稿后，将草稿内容展示给用户审阅。进入确认循环：

1. 展示完整草稿内容
2. 询问用户是否满意，或有哪些需要修改的地方
3. 如果用户提出修改意见 → 按要求调整草稿 → 回到步骤 1
4. 如果用户确认通过 → 将最终草稿写入目标文件

在用户明确确认之前，不要写入文件。


## 注意事项

- 报告文件输出到项目的 `report/` 目录
- 日报路径格式：`report/第X周/M.DD 日报.md`（X 为中文数字，如"第一周"、"第二周"）
- 周报路径格式：`report/第X周/第X周 周报.md`
- 周数从项目入职第一周开始计算（第一周起始日期参见 report/ 目录下最早的文件）
- 使用 `scripts/init-report.py` 获取正确的目标路径，避免手动计算周数
