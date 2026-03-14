# Systems Course Playbook

## Contents

- Artifact checklist
- Debugging playbooks
- Assignment-family heuristics
- Review rubric

## Artifact Checklist

Ask for the smallest artifact that unlocks progress.

- Spec confusion: ask for the exact paragraph, function contract, or grading rule.
- Compile/link failure: ask for the command, full diagnostic, and relevant function signature.
- Wrong answer: ask for one failing input, expected output, actual output, and the smallest code path involved.
- Crash or memory corruption: ask for the stack trace, sanitizer output, reproduction steps, and ownership assumptions.
- Concurrency bug: ask for shared state, lock structure, wakeup logic, and a failing interleaving.
- Performance issue: ask for timing numbers, workload size, machine assumptions, and where time is spent.
- Writeup review: ask for the rubric plus the section the student is least confident about.

## Debugging Playbooks

### Compile Or Link Errors

- Check function declarations, type mismatches, missing includes, and build flags first.
- Watch for C vs C++ linkage, incomplete types, and multiple-definition errors.
- If templates or macros are involved, reduce to the smallest reproducer.

### Wrong Answer

- Make the student state the intended invariant before touching code.
- Compare expected and actual behavior on the first failing case, not the tenth.
- Trace one execution path end to end.
- Look for off-by-one logic, stale state, missing initialization, signedness mistakes, and misunderstood spec details.

### Crash, UB, Or Memory Bugs

- Prefer `-g` plus `-fsanitize=address,undefined` when course rules allow it.
- Check lifetime, ownership, nullability, bounds, alignment, double free, use-after-free, and stack-vs-heap assumptions.
- If sanitizers are unavailable, use `gdb`, assertions, logging around allocations, and minimal repro cases.

### Concurrency Bugs

- Write down shared variables and the invariant each lock protects.
- Check lock ordering, missed wakeups, condition-variable predicates, and termination conditions.
- Separate data races from logical deadlocks and from starvation.
- If behavior is flaky, ask what schedule sensitivity implies about the bug class.

### Performance Regressions

- Measure before optimizing.
- Separate algorithmic complexity from cache behavior, synchronization overhead, system-call cost, and allocation churn.
- Ask whether the hot path is CPU-bound, memory-bound, I/O-bound, or lock-bound.
- Prefer one or two justified optimizations over broad rewrites.

## Assignment-Family Heuristics

### Bit Manipulation Or Data Representation

- Track exact bit widths and signedness.
- State whether shifts are logical or arithmetic.
- Check overflow assumptions explicitly.

### Architecture, Assembly, Or Bomb-Style Reverse Engineering

- Reconstruct control flow before discussing individual instructions.
- Track registers, stack layout, and memory aliases on paper.
- Translate basic blocks into intent, then validate with test inputs.

### Shell, Proxy, Or Network Server Labs

- Separate parsing, process/socket management, and protocol correctness.
- Check resource cleanup on all failure paths.
- Be explicit about blocking behavior, partial reads/writes, and signal handling.

### Memory Allocator Or Cache Labs

- Define invariants for metadata layout and free-list structure.
- Validate coalescing/splitting logic with tiny traces before benchmarking.
- For cache tasks, separate correctness from hit-rate optimization.

### Thread Pool, MapReduce, Or Scheduler Assignments

- Define work ownership and lifecycle first.
- Clarify when tasks become visible, when workers sleep, and how shutdown works.
- Ask how correctness is preserved under contention before tuning throughput.

## Review Rubric

Review in this order unless the user asks otherwise.

1. Does the code satisfy the spec on visible behavior?
2. Are the invariants stated or at least inferable from the implementation?
3. Are edge cases, cleanup paths, and failure modes handled?
4. Does the design remain correct under hidden tests or adversarial schedules?
5. Are performance claims measured and explained?
6. Is the writeup technically defensible?
