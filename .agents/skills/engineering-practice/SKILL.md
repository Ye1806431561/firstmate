---
name: engineering-practice
description: >-
  Agent-only engineering procedure loaded by generated ship and scout instructions.
  Owns proportional minimal-change, impact and history investigation, and completion evidence inside an already-authorized task.
user-invocable: false
metadata:
  internal: true
---

# engineering-practice

Load this skill when a generated ship or scout instruction points here, before planning or editing.
This skill owns engineering depth and evidence inside the assigned task.
The brief still owns scope and authority, Firstmate still owns routing and landing, and the selected delivery path still owns review and validation.

## Choose the proportional path

Use the **narrow path** only when the area is familiar, the behavior change is local, no shared boundary or state transition changes, and an existing check can exercise the result.
Use the **expanded path** when any of these is true:

- The code or subsystem is unfamiliar.
- The change crosses a process, API, storage, serialization, permission, third-party, concurrency, timing, or cleanup boundary.
- The task diagnoses a failure or changes behavior whose current shape is surprising.
- A small diff could invalidate a safety, compatibility, recovery, or data-integrity assumption.

A narrow task stays narrow.
Record one sentence in the completion receipt explaining why expanded how or why investigation was unnecessary.
For a reported bug, `diagnostic-reasoning` remains the owner of diagnosis; use this skill for the resulting change and evidence.

## Make the smallest coherent change

State the authorized behavior change before choosing an implementation.
Inspect the existing execution path, test seam, and documentation owner that already carry that behavior.
Prefer subtraction before addition: remove an obsolete branch, duplicate rule, or unnecessary layer before creating a parallel path.
Extend an existing seam when it remains coherent rather than introducing a new abstraction, helper, framework, or control plane.
Keep unrelated cleanup out of the task.
When the current structure makes the authorized change unsafe, perform only the local refactor needed to expose a stable seam and preserve behavior with an executable check.

## Analyze impact and how

On the expanded path, follow the changed input through control flow and state to the user-visible or operator-visible outcome.
Name the one or two assumptions that make the change safe.
Inspect only the boundaries that can falsify those assumptions, including applicable callers and callees, persisted or serialized shapes, retries and ordering, concurrent ownership, third-party behavior, failure handling, and cleanup.
A grep result or a small diff is not proof that an unseen boundary is unaffected.
Prefer an executable observation through the public interface over an implementation claim.

## Investigate why when history is load-bearing

Inspect history only when present code and authoritative docs do not explain a surprising constraint, divergent path, migration, compatibility branch, or prior regression.
Use the narrowest useful source, such as blame around the invariant, the introducing commit, an ADR, a migration, or the linked issue.
Stop when the rationale is established or when the available history clearly cannot answer the question, and record that limit.
Skip history for a familiar local edit whose behavior and owner are already clear, and say so in the completion receipt.

## Produce completion evidence

Before reporting implementation or investigation complete, inspect the actual deliverable and run the narrowest executable check that exercises the changed behavior through a public or user-relevant interface.
Behavior tests must execute behavior and must not infer correctness by matching implementation-source bytes.
Use broader worker-run checks only when the impact analysis makes them relevant.
This proportional preflight does not narrow any test or CI that the selected delivery path already requires.
If a safe or available executable check does not exist, state exactly what was not run, why, and what remains uncertain.

Leave a concise completion receipt in the task's existing delivery surface:

- Record the behavior or finding that changed and the actual artifact inspected.
- Name the critical assumption when the expanded path was triggered and the observation that supports it.
- List the exact commands run, their observed results, and the durable evidence location when one exists.
- List every relevant check or environment that was not run or observed.
- Explain why how or history investigation was expanded or skipped.

Use the scout report, selected delivery path's PR or validation evidence, commit, and final status record rather than creating another ledger or approval step.
A command name without its observed result is not evidence.
A passing unrelated suite does not prove the changed behavior.

## Preserve role and delivery boundaries

A scout produces knowledge and explicit uncertainty, not an implementation or PR.
A ship changes only the authorized behavior and follows its selected delivery path.
No-mistakes remains the sole owner of its review, fixes, tests, push, PR, and CI flow; once its run is active, respond through that flow rather than editing around it.
Direct-PR and local-only work do not gain an extra reviewer or validation framework from this skill.
This skill does not authorize merging, destructive action, research-to-implementation promotion, recovery shortcuts, or disposal of unlanded work.
It does not add a router, model configuration, worker registry, pager, or pstack installation.

## Sources and adaptation boundary

This is a Firstmate-specific adaptation of engineering-discipline ideas described in [the first integration post](https://x.com/ssbrouhard/status/2092809593411785196), [the follow-up operating-model post](https://x.com/ssbrouhard/status/2098041919779541487), and the official [pstack source at the studied commit](https://github.com/cursor/plugins/tree/c1c0a32802223f4be824112dd83d33ad29a8b26c/pstack).
The wording and procedure here are local, and no upstream playbook, model setting, orchestrator, or private factory component is copied or installed.
