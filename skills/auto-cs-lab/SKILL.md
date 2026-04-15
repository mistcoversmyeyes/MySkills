---
name: auto-cs-lab
description: 自动化完成 CS 课程实验报告全流程，从读取实验要求、补全代码、运行验证、采集截图到生成报告。适用于用户希望把课程实验和实验报告一起完成的场景。
disable-model-invocation: true
allow-tools: Read, Write, Edit, Bash, Glob, Grep, MultiEdit, LS 
---

# auto-cs-lab

自动完成 CS 课程实验并撰写实验报告。

如果当前 harness 支持 sub-agent，把它们当成“高阶工具”使用，只委派输入清楚、目标清楚、输出可验、共享状态弱的步骤。当前 skill 自带这些子代理：

- `agents/planner.md`：把材料整理成阶段计划
- `agents/requirements-analyst.md`：提炼实验要求和模板要求
- `agents/repo-auditor.md`：审计项目现状和可能的运行入口
- `agents/report-drafter.md`：基于真实证据起草报告

不要把强依赖当前桌面状态或共享运行状态的步骤委派出去，例如桌面截图、窗口切换、最终实际运行验证和最后一轮整合提交。

## 检查工具和环境

先检查当前环境是否具备完成任务所需的能力：

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/mcp/check-env.sh
```

- 该脚本只检查常见安装方式；如果用户使用了自定义 MCP 配置，只要能力等价也可以继续。
- 不要默认安装所有 MCP，只安装当前实验真正需要的能力。

按需安装缺失工具：

| MCP 服务器 | 用途 | 安装脚本 |
|-----------|------|---------|
| `office-docs` | Word 文档读写 | `bash ${CLAUDE_SKILL_DIR}/scripts/mcp/install-office-docs.sh` |
| `excel-mcp-server` | Excel 表格读写 | `bash ${CLAUDE_SKILL_DIR}/scripts/mcp/install-excel.sh` |
| `powerpoint-mcp-server` | PPT 读写 | `bash ${CLAUDE_SKILL_DIR}/scripts/mcp/install-powerpoint.sh` |
| `playwright-user/isolated` | 浏览器截图 | `bash ${CLAUDE_SKILL_DIR}/scripts/mcp/install-playwright.sh` |

- 如果安装后需要重启当前 Agent 工具才能生效，要明确告诉用户。
- 在能继续推进的情况下，不要因为某个可选 MCP 暂时不可用就停住整个任务。

检查截图链路是否可用：

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/screenshot.sh --output /tmp/test-screenshot.png
```

如果截图失败或全黑，优先检查：

1. `powershell.exe` 是否可调用
2. Windows 是否锁屏
3. 输出目录是否可写

## 获取实验信息

扫描当前项目目录，优先寻找：

1. `README.md`
2. `*.docx` / `*.pdf`
3. `*.md`
4. 代码、测试、构建脚本、数据文件

读取时优先使用：

- `mcp__office-docs__read_docx` 读取 Word 文档
- `Read` 读取 Markdown 和文本文件
- PDF 读取能力读取 PDF

从材料里提取这些信息：

- 实验目标
- 实验步骤
- 预期结果
- 评分标准
- 报告模板结构

如果同时存在实验指导书和报告模板，先区分它们各自的用途，不要混用。

如果材料很多、要求复杂、模板和指导书并存，优先委派 `agents/requirements-analyst.md`，让它先输出结构化要求摘要，再继续主流程。

## 理解任务并拆分步骤

在真正修改代码前，先明确：

- 要补什么代码或配置
- 要跑什么命令或测试
- 哪些结果必须展示
- 哪些步骤需要截图
- 报告最终要交什么文件

把任务拆成若干阶段再执行，通常至少包括：

1. 环境准备
2. 实现或修改
3. 运行验证
4. 截图留证
5. 报告生成

如果实验跨度较大、目录复杂或用户一次性给了很多上下文，委派 `agents/planner.md` 先给出阶段计划。主 agent 根据计划决定是否继续委派其他子代理。

## 执行实验并验证结果

按照实验要求编写或修改代码，然后运行并验证。

- 优先使用实验文档里给出的命令、样例、测试方式。
- 没有明确命令时，再根据项目结构自行判断。
- 运行后要保留证据，例如终端输出、测试结果、生成文件。

如果当前仓库结构复杂、语言栈不清楚、运行入口不明显，可以先委派 `agents/repo-auditor.md` 做只读审计，再由主 agent 自己决定怎么改代码和怎么运行。

如果出现错误：

- 先自行排查并重试
- 修复后重新验证
- 如果仍然无法完成，保留错误信息和已尝试步骤，不要假装成功

## 采集关键截图

这一阶段默认由主 agent 自己完成，不要委派给子代理。原因是截图、窗口激活、桌面前台状态都强依赖共享环境，多个 agent 并行操作很容易互相干扰。

截图要服务于报告和证据链，不要机械乱截。优先保留这些内容：

- 代码或配置完成后的编辑器界面
- 编译成功、测试通过、程序运行结果
- GUI、数据库工具、仿真器、浏览器页面中的关键状态
- 有价值的报错和修复前后对比

截图前可先查看窗口状态：

```bash
# 列出所有可见窗口
bash ${CLAUDE_SKILL_DIR}/scripts/win-info.sh --list

# 搜索特定窗口
bash ${CLAUDE_SKILL_DIR}/scripts/win-info.sh --find "IDEA"

# 查看当前活动窗口
bash ${CLAUDE_SKILL_DIR}/scripts/win-info.sh --active

# 需要物理像素坐标时，显式提供 DPI 缩放
bash ${CLAUDE_SKILL_DIR}/scripts/win-info.sh --scale 175 --find "IDEA"
```

如需确认屏幕尺寸和 DPI：

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/screen-info.sh
```

常用截图方式：

```bash
# 全屏截图（默认）
bash ${CLAUDE_SKILL_DIR}/scripts/screenshot.sh --output screenshots/lab1/01_overview.png

# 活动窗口截图
bash ${CLAUDE_SKILL_DIR}/scripts/screenshot.sh --window --output screenshots/lab1/02_ide.png

# 按窗口标题关键词查找并截图
bash ${CLAUDE_SKILL_DIR}/scripts/screenshot.sh --find "IDEA" --output screenshots/lab1/03_idea.png

# 区域截图
bash ${CLAUDE_SKILL_DIR}/scripts/screenshot.sh --region 0,0,1920,1080 --output screenshots/lab1/04_region.png

# 延迟截图
bash ${CLAUDE_SKILL_DIR}/scripts/screenshot.sh --delay 3 --output screenshots/lab1/05_delayed.png
```

`--find` 模式会：

1. 搜索标题包含关键词的窗口
2. 选择最匹配的可见窗口
3. 尝试恢复并激活该窗口
4. 读取最终窗口矩形并截取该区域

截图建议统一保存到：

```text
screenshots/<experiment-name>/
```

命名建议：

```text
<step-number>_<description>.png
```

例如：

```text
screenshots/lab1/01_ide_code.png
screenshots/lab1/02_test_result.png
```

## 生成报告

优先按用户提供的模板生成报告；没有模板时，再使用通用实验报告结构。

当实现和验证证据已经稳定、截图文件名也已经基本确定后，可以委派 `agents/report-drafter.md` 先起草报告正文，再由主 agent 负责最终写入文档和补齐缺口。

可使用：

- `mcp__office-docs__write_docx`
- `mcp__office-docs__edit_docx_paragraph`

通用结构：

```text
实验报告
├── 实验名称
├── 实验目的
├── 实验环境
├── 实验内容
├── 实验结果
└── 实验总结/心得
```

写报告时保持和真实执行过程一致：

- 步骤描述要对应实际操作
- 结果分析要基于真实输出
- 截图说明要对应图片内容
- 没做完的部分要明确标注，不要编造结果

默认用中文撰写报告；如果课程或模板另有要求，以课程要求为准。

## 交付结果

完成任务时，尽量同时交付：

- 修改后的实验代码或配置
- 运行验证结果
- `screenshots/<experiment-name>/` 下的截图
- 报告文件，或可直接继续完善的报告草稿

如果环境限制导致无法完全交付，也要明确告诉用户：

- 已完成哪些部分
- 缺了哪些部分
- 阻塞原因是什么
- 下一步最合理的补救方式是什么

最终交付前，主 agent 要自己复核一遍所有产物之间是否一致：代码、运行结果、截图、报告不能互相矛盾。

## 保持真实

- 不要伪造运行结果、截图或测试通过记录
- 不要把推测写成已验证结论
- 不要忽略模板、评分标准和命名规范
- 不要只给建议而不落地执行，除非环境确实阻止执行
