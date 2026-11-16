# Hashed-frame spike: closeout (2026-11-16)

**Outcome: green.** The prerequisite holds, and the pulse loop is faster by
much more than the kill condition's 0.02 on every comparison shape (README,
kill condition).

## What ran

- `probe.R`: the fork loads. The frame is hashed and holds 136 names. The
  envelope body and all eight stage and publish functions are byte-compiled.
  Fills, equity and trades are identical on 10x7200 (`evidence/probe.csv`).
- `check.R`: 54 gate workloads (the 37 slice-3 workloads plus 17 slice-1/2
  and witness workloads) were run in a fork worktree at 6e90a881 against the
  freeze. Debug off and on each gave 872 tables, 0 different, 54 of 54 frozen
  paths matched (`evidence/gate_debug0.csv`, `gate_debug1.csv`). A gutted
  fork whose frame cannot see the call's arguments fails the gate, as it
  must. Package scope is clean. The rerun in diff mode reproduces both
  files.
- `run.R`: the current lean loop ("plain") against the fork ("hashed") on the
  four comparison shapes, 7 alternating rounds plus a warm-up, both arms
  compiled with `cmpfun`. High performance plan, P-core affinity, Balanced
  restored afterwards (2026-11-16 02:13-02:29). There were two passes. The
  stage pass times P1-P5 with clocks. The loop pass has no stage clocks and
  is the decision number, because the clocks add lookups of their own.
  Fill counts are equal between arms in every pass and shape.

## Result (loop pass, median per pulse, `evidence/summary.csv`)

| shape | pulse loop plain -> hashed (us) | saved | rounds faster | whole run saved |
| --- | --- | --- | --- | --- |
| 10x7200 | 282 -> 232 | 47 us, 16.7% | 7 of 7 | 8.8% |
| 20x23400 | 325 -> 285 | 41 us, 12.5% | 7 of 7 | 7.6% |
| 500x1260 | 571 -> 540 | 40 us, 6.9% | 7 of 7 | 1.5% |
| slice2_10x7200 | 556 -> 510 | 46 us, 8.2% | 7 of 7 | 3.3% |

The saving is about 40-47 us per pulse whatever the width, so its share is
largest on long, narrow runs. The stage pass shows it spread over every stage.
P1 (the smallest stage) drops by 30-44%, and P2, P3, P4 and P5 each drop by
roughly 5-25 us. Publish is unchanged: it runs once, not per pulse.

## What was learned about the package

- R function frames are searched name by name, and a hashed environment is
  not. At about 140 bindings, this lookup cost was roughly 15% of the narrow
  pulse loop.
- Evaluating a compiled body in `new.env(hash = TRUE, parent = environment())`
  keeps the semantics on every gate workload tried, `on.exit()` included, with
  `loop.R` unchanged. The fork is 9 lines of code.
- To compile with `compiler::compile()` inside `sys.source()`, the
  `topLevelEnvironment` option has to be cleared for the call.

## What the spec may consume

- The measured saving (40-47 us per pulse, 7-17% of the pulse loop on these
  shapes) and the fact that it needs no change to `loop.R`.
- Frame size stops being a per-pulse cost under this pattern. Cut 19's
  one-environment `s3` stays correct but is no longer needed for speed.

## Tooling that reads the envelope

The routing asked for this; it was added after the first closeout. Because
`loop.R` is unchanged, variant anchors (text edits to `loop.R`) and line
counts are unaffected. The fork itself adds 9 lines. Tools that read the
envelope's body, environment or identity need small edits:
`parity/loop_shortcuts.R` (line 176, body and environment of
`lean_fold_envelope`), `parity/loop_workloads.R` (line 274, the installed
check by identity) and the Cut 19 frame census `ebind.R`. The variant driver
was not run on the fork.

## Debugging

`debug_probe.R` (`evidence/debug_probe.txt`) uses a toy envelope whose stage
errors. The call stack under the hashed pattern is the plain one plus two
`eval()` lines, the stage names stay visible, and the envelope's state can be
read from a frame on the stack, as `recover()` would. What is lost is
stepping through the envelope's top-level setup with `debug()` or
`debugonce()`. `browser()` was not tested because the probe ran
non-interactively.

## Decision (maintainer, 2026-11-16)

Production keeps this form: the wrapper defined in `loop.R` itself, with
inline documentation. With the lean debug flag on, the envelope runs as the
plain function, so `debug()` steps through it, and every parity run
exercises both forms. It is routed as a hashed-frame cut after the
optimization manual update and before slice 4, and the manual gets an entry
for the pattern (macro plan WS16).

## Open
- The checks covered 54 of 111 gate workloads. Not run on the fork: the full
  gate, batch one, inert hooks, the variant driver, dispatch, FIFO, planner
  and the witness suites. A production cut runs the full set once on its
  final code.
- The four shapes are the comparison shapes, not a matched peer suite. No
  public performance claim follows from this spike.
