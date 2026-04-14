---
name: auto-cs-lab
description: 自动化完成 CS 课程实验报告全流程——从代码编写、运行验证、截图记录到报告生成。适用所有 CS 课程实验。
disable-model-invocation: true
allow-tools: Read,
---

# auto-cs-lab: CS 实验报告自动化

## 概述

本 Skill 提供 CS 课程实验报告的端到端自动化工作流。Agent 自主探索当前项目环境，发现实验指导手册和报告模板，按步骤完成实验并生成报告。

**核心设计原则**：
- 实验内容和模板是外部输入，不在 Skill 中硬编码
- Agent 自主决定何时截图、截什么内容
- 工作流可适配任何 CS 课程实验

---

## 前置检查与工具安装

### 第一步：环境检查

运行环境检查脚本，了解当前工具状态：

```bash
bash scripts/mcp/check-env.sh
```

### 第二步：按需安装 MCP

根据实验需要，安装缺失的工具：

| MCP 服务器 | 用途 | 安装脚本 |
|-----------|------|---------|
| `office-docs` | Word 文档读写 | `bash scripts/mcp/install-office-docs.sh` |
| `excel-mcp-server` | Excel 表格读写 | `bash scripts/mcp/install-excel.sh` |
| `powerpoint-mcp-server` | PPT 读写 | `bash scripts/mcp/install-powerpoint.sh` |
| `playwright-user/isolated` | 浏览器截图 | `bash scripts/mcp/install-playwright.sh` |

**安装策略**：
- 不是所有实验都需要所有 MCP。例如纯代码实验不需要 Playwright
- 根据实验类型选择需要的 MCP
- 安装后需 **重启 Claude Code** 使配置生效

### 第三步：确认截图能力

测试桌面截图是否正常：

```bash
bash scripts/screenshot.sh --output /tmp/test-screenshot.png
```

如果截图失败或全黑，检查：
1. WSL 是否能调用 `powershell.exe`
2. Windows 是否锁屏
3. 输出目录是否有写权限

---

## 工作流

### 1. 获取实验信息

扫描当前项目目录，发现并读取实验相关文件：

**优先搜索**：
1. `README.md` — 课程说明或实验指引
2. `.docx` / `.pdf` — 实验指导手册或报告模板
3. `.md` — 实验说明文件
4. 代码文件 — 已有的实验代码

**读取策略**：
- 使用 `mcp__office-docs__read_docx` 读取 Word 文档
- 使用 `Read` 工具读取 Markdown/文本文件
- 使用 PDF 读取能力读取 PDF 文档

**提取信息**：
- 实验目标
- 实验步骤
- 预期结果
- 评分标准（如有）
- 报告模板结构

### 2. 理解实验要求

从指导手册中提取关键信息：
- 需要编写什么代码/配置
- 需要什么运行结果
- 需要截图什么内容
- 报告格式要求

### 3. 执行实验

按步骤编写代码/配置，运行并验证：

1. **编写代码** — 根据实验要求编写
2. **运行验证** — 执行代码确认结果正确
3. **记录过程** — 在关键步骤截图

### 4. 关键步骤截图

**截图时机**：Agent 根据实验内容自主判断何时截图。典型场景：
- 代码编写完成后的 IDE 截图
- 运行结果截图（终端输出、测试通过等）
- 配置过程截图（数据库 GUI、Web 界面等）
- 错误排查截图（如有）

**截图工具选择规则**：

| 场景 | 工具 | 命令 |
|------|------|------|
| 桌面应用/IDE/终端 | `scripts/screenshot.sh` | `bash scripts/screenshot.sh [--window \| --find <keyword> \| --region x,y,w,h] [--delay N] [--output <path>]` |
| 浏览器页面 | `mcp__playwright-user__browser_take_screenshot` | 直接调用 Playwright MCP |

**截图前窗口查询**：

截图前可用 `win-info.sh` 了解当前桌面窗口状态：

```bash
# 列出所有可见窗口
bash scripts/win-info.sh --list

# 搜索特定窗口
bash scripts/win-info.sh --find "IDEA"

# 查看当前活动窗口
bash scripts/win-info.sh --active

# 需要物理像素坐标时，显式提供 DPI 缩放
bash scripts/win-info.sh --scale 175 --find "IDEA"
```

**截图存储规范**：
- 目录: `screenshots/<experiment-name>/`
- 命名: `<step-number>_<description>.png`
- 例如: `screenshots/lab1/01_ide_code.png`, `screenshots/lab1/02_test_result.png`

**截图脚本用法**：

```bash
# 全屏截图（默认）
bash scripts/screenshot.sh --output screenshots/lab1/01_overview.png

# 活动窗口截图
bash scripts/screenshot.sh --window --output screenshots/lab1/02_ide.png

# 按窗口标题关键词查找并截图
bash scripts/screenshot.sh --find "IDEA" --output screenshots/lab1/02_ide.png

# 区域截图 (x,y,宽,高)
bash scripts/screenshot.sh --region 0,0,1920,1080 --output screenshots/lab1/03_region.png

# 延迟截图（截图前等待）
bash scripts/screenshot.sh --delay 3 --output screenshots/lab1/04_delayed.png
```

**`--find` 模式工作流程**：
1. 搜索标题包含关键词的窗口（EnumWindows + GetWindowText）
2. 选择最匹配的可见窗口
3. 尝试恢复并激活该窗口
4. 读取该窗口最终矩形并截取对应区域

### 5. 生成报告

使用 `mcp__office-docs__write_docx` 或 `mcp__office-docs__edit_docx_paragraph` 生成 .docx 报告。

**报告结构**（如无模板则使用以下通用结构）：

```
实验报告
├── 实验名称
├── 实验目的
├── 实验环境
├── 实验内容
│   ├── 步骤1: 描述
│   │   ├── 操作说明
│   │   └── 截图引用: [图片]
│   ├── 步骤2: 描述
│   │   └── ...
│   └── 步骤N: 描述
├── 实验结果
└── 实验总结/心得
```

**如果有模板**：严格按照模板结构生成，在对应位置填入内容。

---

## 注意事项

1. **截图是关键**：确保每个重要步骤都有截图作为证据
2. **自主判断**：Agent 应根据实验内容自主决定截图时机，不依赖固定规则
3. **黑屏检测**：截图脚本会自动检测锁屏状态，避免生成无效截图
4. **文件引用**：报告中引用的截图路径必须是相对路径（相对于报告文件位置）
5. **幂等安装**：所有 MCP 安装脚本都是幂等的，重复运行不会出错
6. **中文写作**：实验报告使用中文撰写，代码注释用英文
