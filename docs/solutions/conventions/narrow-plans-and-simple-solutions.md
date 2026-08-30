---
title: "Use Narrow Plans and the Simplest Complete Solution"
date: 2026-08-30
category: conventions
module: repository-wide
problem_type: convention
component: development_workflow
severity: medium
applies_when:
  - "planning or implementing any repository task"
  - "deciding whether to add abstractions, dependencies, configuration, or infrastructure"
  - "considering cleanup, refactoring, or future-proofing beyond the current requirement"
tags:
  - "agent-workflow"
  - "planning"
  - "scope-control"
  - "simplicity"
  - "over-engineering"
---

# Use Narrow Plans and the Simplest Complete Solution

## Context

Implementation work can expand beyond the requested outcome when a plan does not name its boundaries or when hypothetical future needs are treated as current requirements. The repository convention is to keep both planning and implementation as narrow as safety and the present task allow.

## Guidance

For non-trivial work, create the narrowest safe plan before editing. Identify the files to inspect, files likely to change, checks to run, pass/fail criteria, and important non-goals. Keep the plan in the working conversation unless a durable planning document is useful or explicitly requested.

Implement the simplest solution that fully meets the current requirement, fits the existing architecture, handles real and likely edge cases, and remains understandable and maintainable. Reuse existing patterns before introducing new abstractions.

Avoid new dependencies, folder restructuring, speculative infrastructure or configuration, unrelated features, broad cleanup or refactors, duplicate systems, extra layers, and future-proofing for hypothetical requirements unless the task itself clearly requires them. This simplicity principle is the default for every task. Depart from it only when the user explicitly requests an over-engineered or hyper-engineered solution.

## Why This Matters

Narrow plans expose the intended evidence and stopping condition before implementation begins. Simple, architecture-aligned changes reduce review surface, regression risk, and maintenance cost while keeping unrelated work and user-owned changes outside the task boundary.

## When to Apply

- Apply by default to every repository task.
- Write out the planning checklist for non-trivial work.
- Scale verification to the risk and scope of the change.
- Treat explicit user direction to over-engineer or hyper-engineer a solution as the only override to the simplicity default.

## Examples

- A small behavior change should inspect the owning feature, modify the minimum relevant files, and run the narrowest checks that prove the behavior and its failure cases.
- A required dependency or structural change is acceptable when the current requirement genuinely needs it; document that need instead of expanding into adjacent modernization.
- A request to deliberately hyper-engineer a solution may add the requested redundancy or extensibility, but unrelated cleanup and features remain outside scope unless separately requested.

## Related

- `AGENTS.md` contains the concise, always-on repository instructions for this convention.
