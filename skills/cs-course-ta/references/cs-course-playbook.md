# CS Course Playbook

## Contents

- Artifact checklist
- Cross-course tutoring workflow
- Domain playbooks
- Review rubric

## Artifact Checklist

Ask for the smallest artifact that unlocks progress.

- Spec confusion: ask for the exact paragraph, function contract, grading rule, or theorem statement.
- Code bug: ask for the failing test, expected behavior, actual behavior, and the smallest relevant code path.
- Compile or runtime failure: ask for the command, full diagnostic, stack trace, and recent changes.
- Math or proof question: ask for assumptions, notation, and the student's current attempt.
- Experiment question: ask for setup, baseline, metrics, curves or tables, and what conclusion the student wants to defend.
- Paper reading: ask for the section, the confusing claim, and the part that does not connect to prior knowledge.
- Writeup review: ask for the rubric and the section the student is least confident about.

## Cross-Course Tutoring Workflow

1. Identify the deliverable: code, proof, experiment, reading response, or report.
2. Identify the blocker: concept gap, mechanistic bug, missing invariant, unclear evidence, or poor structure.
3. Ask for one artifact if blocked.
4. Give the minimum next step that preserves momentum.
5. End with a concrete action for the student.

## Domain Playbooks

### Systems And Low-Level Programming

- Check interface contracts, lifetime, aliasing, bounds, concurrency invariants, and failure cleanup.
- Use tests, sanitizers, `gdb`, traces, and profilers systematically instead of guessing.
- For performance questions, separate algorithmic issues from cache, I/O, synchronization, and allocation effects.

### AI/ML And CS336-Style Training Work

Ask for:

- Task and objective function
- Dataset and tokenization pipeline
- Model size or configuration
- Optimizer, learning-rate schedule, and batch setup
- Compute budget, memory pressure, and parallelism strategy
- Validation metrics, training curves, and baseline comparisons

Common failure classes:

- Data leakage or data preprocessing bugs
- Tokenization or masking mistakes
- Divergence, NaNs, unstable gradients, or bad hyperparameters
- Underfitting vs overfitting confusion
- Throughput bottlenecks caused by input pipeline, communication, or memory bandwidth
- Experimental conclusions that are not controlled or not comparable

### Databases And Data Systems

- Separate logical correctness from performance.
- Check transaction semantics, isolation assumptions, schema invariants, indexing choices, and cost-model reasoning.
- For systems projects, ask where latency or throughput is actually spent before proposing changes.

### Compilers And Programming Languages

- State the source and target invariants for each pass.
- Check parser ambiguity, AST consistency, type rules, symbol resolution, IR validity, and semantic preservation.
- Treat optimizations as proof obligations, not just code transformations.

### Security And Cryptography Courses

- Start with the threat model and trust boundary.
- Check exploit or defense preconditions explicitly.
- Distinguish memory corruption, protocol flaws, crypto misuse, and side-channel concerns.
- Keep the discussion tied to the assignment's educational goal and constraints.

### Theory, Algorithms, And Math-Heavy Coursework

- Force explicit definitions, quantifiers, and assumptions.
- Check whether the student's proof or derivation actually closes every step.
- Ask what invariant, exchange argument, induction hypothesis, or reduction is doing the heavy lifting.

## Review Rubric

Review in this order unless the user asks otherwise.

1. Is the answer or implementation actually correct with respect to the spec or statement?
2. Are the key assumptions and invariants explicit?
3. Are edge cases, failure modes, and counterexamples handled?
4. Are measurements, plots, or empirical claims methodologically defensible?
5. Is the explanation something a grader or TA could follow without guessing intent?
6. Only after that, discuss polish, style, or formatting.
