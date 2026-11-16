# Hashed-frame spike (macro plan WS16, maintainer 2026-11-15)

Question: does evaluating `lean_fold_envelope`'s body in a hashed
environment remove a material share of the lean loop's per-pulse cost, with
identical results?

Prerequisite question (probe.R): does the fork load, keep every stage
function byte-compiled, run in a hashed frame, and return the pin's tables
on one workload?

Kill condition: the prerequisite fails (a stage runs uncompiled or a result
differs) and no change confined to `hashed.R` fixes it; or the pulse loop is
not faster by at least 0.02 of the loop on any comparison shape.

The fork (`hashed.R`, sourced after `loop.R` into the lean environment) keeps
`loop.R` unchanged: it compiles the envelope's body once and evaluates it in
`new.env(hash = TRUE)` whose parent is the call frame (so `execution` and
`output_handler` resolve as before).

| file | role |
| --- | --- |
| `hashed.R` | the fork: the only new execution code |
| `probe.R` | prerequisite: compiled stages, hashed frame, one workload |
| `run.R` | runner: per-stage and pulse-loop time per pulse, current lean against the fork, alternating, the four comparison shapes; writes `evidence/stages.csv`, `evidence/summary.csv` |
| `debug_probe.R` | what the call stack and `recover()` see under the fork (closeout, Debugging) |
| `cut_prep.R` | cut preparation (Cut 20): early `return()` and `on.exit()`, base-name shadowing, compile time; writes `evidence/cut_prep.txt` |
| `check.R` | checker: the gate subset in a fork worktree with debug off and on against the freeze, a gutted fork that must fail, and the package-scope guard |

Fork worktree: `git worktree add --detach C:/Users/maxth/ledgr-wt/hashed-frame <commit>`;
`run.R` and `check.R` copy `hashed.R` into its `dev/lean_core/` as `zz_hashed.R`.
