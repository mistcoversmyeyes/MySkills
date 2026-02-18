---
name: codex-caller
description: "Standardized Codex invocation for encoding tasks. Use when: (1) User explicitly mentions ''codex'' or ''编写代码'', (2) User invokes ''/codex'' slash command, (3) Any complex encoding task that requires Codex''s advanced capabilities. Provides default parameter configuration with override support for cwd, approval-policy, sandbox, model, and profile settings."
---

# Codex Caller

## Overview

Standardizes invocation of Codex for complex encoding tasks. Eliminates repetitive manual prompting by providing sensible defaults while allowing full parameter override.

**Core principle**: "Good taste" - simple, predictable, zero-surprise interface to Codex.

## Quick Start

### Default invocation (recommended for most cases)

```yaml
cwd: {auto-detect} # Detects current project root
approval-policy: on-failure
sandbox: workspace-write
```

**Usage pattern**: When user says "编写代码" or "codex", invoke Codex with defaults:
```
User: "请用 codex 为我编写用户登录接口"
→ Automatically invoke Codex with cwd=project_root, approval-policy=on-failure
```

## Usage Scenarios

### When to trigger Codex

**Trigger immediately** when user says:

1. **Explicit keywords**:
   - "codex"
   - "编写代码"
   - "用 codex 编码"
   - Example: "请用 codex 实现用户登录"

2. **Slash command**:
   - `/codex [task description]`
   - Example: "/codex 添加会话超时回收功能"

3. **Implicit but clear encoding intent**:
   - "实现 xx 功能" (when clearly requiring new code)
   - "重构 xx 模块" (refactoring task)
   - Example: "为后端添加 WebSocket 支持"

### When NOT to trigger

**Do NOT trigger** for:

1. **Self-invocation prevention** (CRITICAL):
   - **If current agent is already Codex, reject codex-caller invocation**
   - "若当前 Agent 为 Codex，请拒绝使用 Codex-caller 调用自身"
   - Rationale: Prevents infinite recursion. You're already Codex - just do the work.
   - Example: Codex agent receives "use codex for X" → Reject, handle directly

2. **Wrong task types**:
   - Pure documentation tasks
   - Configuration changes
   - Simple file edits (use Edit tool directly)
   - Analysis/explanation requests
   - Example: "查看这个文件的内容" → Use Read, not Codex

## Parameter Reference

### cwd (Working Directory)

**Default**: Not specified (auto-detect from current working directory)

**Detection logic**:
1. Use current working directory if in a valid project
2. Detect git root if available
3. Fallback to current directory

**Override**: User specifies different location

**Example override**:
```
User: "在 /tmp/test-项目 中用 codex 编写测试"
→ Use cwd: /tmp/test-项目
```

### approval-policy

**Default**: `on-failure`

**Options**:
- `untrusted` - Require approval for all shell commands
- `on-failure` - Require approval only when commands fail (RECOMMENDED)
- `on-request` - Ask before executing any command
- `never` - Never ask for approval

**Guideline**: Use `on-failure` for balance between safety and efficiency. Use `untrusted` for sensitive operations (database migrations, production deployments).

### sandbox

**Default**: `workspace-write`

**Options**:
- `read-only` - Cannot modify any files
- `workspace-write` - Can modify workspace files (RECOMMENDED)
- `danger-full-access` - Unrestricted access

**Guideline**: Use `workspace-write` for development tasks. Use `read-only` for analysis/refactoring review.

### model

**Default**: Not specified (uses Codex default model)

**Override**: User specifies model explicitly

**Example**:
```
User: "用 gpt-5.2-codex 模型处理"
→ Add model: "gpt-5.2-codex"
```

### profile

**Default**: Not specified (uses default profile)

**Override**: User specifies profile from config.toml

**Example**:
```
User: "使用 fast-iterate profile"
→ Add profile: "fast-iterate"
```

### base-instructions

**Default**: Not specified (uses Codex default instructions)

**Override**: User provides custom base instructions

**Use case**: Project-specific coding standards, architecture constraints

**Example**:
```
User: "使用项目编码规范：Go 1.21+, 遵循 SOLID 原则"
→ Add base-instructions: "Use Go 1.21+, follow SOLID principles"
```

### developer-instructions

**Default**: Not specified

**Override**: User provides developer role instructions

**Use case**: Specific role requirements (e.g., "act as senior Go engineer")

## Invocation Examples

### Example 1: Basic encoding task

**User input**:
```
"用 codex 编写用户登录接口，支持 JWT 认证"
```

**Invocation**:
```yaml
prompt: "编写用户登录接口，支持 JWT 认证"
cwd: {auto-detect}
approval-policy: on-failure
sandbox: workspace-write
```

### Example 2: With parameter overrides

**User input**:
```
"在 /tmp/experiment-项目 中用 codex 编写测试代码，用 untrusted 模式"
```

**Invocation**:
```yaml
prompt: "编写测试代码"
cwd: /tmp/experiment-项目
approval-policy: untrusted
sandbox: workspace-write
```

### Example 3: With custom instructions

**User input**:
```
"用 codex 为这个项目添加 WebSocket 支持，遵循项目现有的异步架构模版"
```

**Invocation**:
```yaml
prompt: "添加 WebSocket 支持，遵循项目现有的异步架构模版"
cwd: {auto-detect}
approval-policy: on-failure
sandbox: workspace-write
base-instructions: "遵循项目现有的异步架构模版，所有 WebSocket 处理必须使用 context 管理生命周期"
```

## Best Practices

### 1. Always confirm before invocation

When triggering Codex based on implicit intent (not explicit keywords):

```
"检测到编码任务，将使用 Codex 处理。继续？[Y/n]"
```

### 2. Preserve user's original request

Never paraphrase or summarize the user's prompt. Pass it exactly as-is to Codex.

### 3. Inform user of parameter overrides

When overriding defaults, tell user:

```
"使用 cwd=/tmp/test-项目 (用户指定)
"使用 approval-policy=untrusted (用户指定)
```

### 4. Handle multi-turn conversations

For extended tasks, use `codex-reply` to continue the conversation:

```yaml
First invocation: codex(prompt="实现用户登录")
→ Codex returns code and asks about testing

Second invocation: codex-reply(threadId="xxx", prompt="运行单元测试")
```

## Error Handling

### Codex connection failure

**Symptom**: Invocation fails with connection error

**Action**:
```
1. Check if Codex MCP server is running
2. Verify MCP server configuration
3. Inform user: "Codex 服务不可用，请检查 MCP server 配置"
```

### Invalid parameters

**Symptom**: Validation error on parameters

**Action**:
```
1. Review parameter values against allowed options
2. Inform user of validation error
3. Suggest correct parameter values
```

