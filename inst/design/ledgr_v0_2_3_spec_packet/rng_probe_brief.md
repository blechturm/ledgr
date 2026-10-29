# RNG probe brief: measure before the RNG and pulse-seed cut

**Brief drafted by Claude, 2026-10-29; the maintainer authorized running it
the same day.** Measurement step for the next cut, macro WS2 (RNG
reproducibility, inventory X1 absorbing H8) plus C4 (cheap, versioned
pulse-seed derivation), under `inst/design/spike_protocol.md`. No product
change.

## 1. Why

The next cut will pin the RNG kind wherever ledgr seeds, restore the caller's
RNG with `seed = NULL`, widen preflight RNG detection, and replace the
per-pulse seed derivation (canonical JSON plus SHA-256, `R/rng.R:21-57`,
called every pulse at `R/fold-engine.R:766`) with a cheap versioned rule.
It deliberately changes seeded stochastic results once. Before writing it we
need: what the current derivation costs, which runs pay it, and a frozen
record of today's stochastic behaviour, including the known 1-versus-2-worker
mismatch (`dev/spikes/nmof-probe/probe_findings.md`).

## 2. Questions

1. **Cost.** Per call, and as a share of end-to-end time, what does
   `ledgr_derive_pulse_seed()` cost on a seeded committed run and a seeded
   sweep? Use the WS1 timing fixtures (`dev/bench/v0_2_3_ws1_timing/`, for
   example `dense_scale_50x1260` and `timing_scale`) with a seed, measuring
   the derivation by microbenchmark and its share by `Rprof` sampling.
   Descriptive only; this is not a gate.
2. **Who pays.** A census of every seeding path: `ledgr_run`, `ledgr_sweep`
   (candidate seeds at `R/sweep.R:1294`), walk-forward
   (`R/walk-forward-identity.R:97`), promotion, run and sweep windows. For
   each: the default `seed`, whether an execution seed is derived when the
   user passes none, whether `pulse_seed` is then computed every pulse, and
   where `set.seed()` is called and with which kind.
3. **Current behaviour, frozen.** A small deterministic record of today's
   stochastic results that the cut will intentionally change:
   - a seeded strategy that draws from `ctx$pulse_seed` (the contract's
     recipe, for example via `withr::with_seed`) through `ledgr_run`, and
     through `ledgr_sweep` with `workers = 1` and `workers = 2`: record fills
     and whether 1 and 2 workers agree (the known bug says they do not);
   - the caller's `.Random.seed` and `RNGkind()` before and after `ledgr_run`
     and `ledgr_sweep` with `seed = NULL` and with a seed, for 1 and 2
     workers;
   - the current `pulse_seed` values for the first pulses of one seed, so the
     cut can show which values change.
4. **Detection gap.** Which RNG calls current preflight misses
   (`R/strategy-preflight.R:678` lists only `runif`, `rnorm`, `sample`):
   show at least `sample.int`, one other `r*` distribution function and an
   RNG call inside a package function used by a strategy, and whether a
   runtime `.Random.seed` comparison around a strategy call would catch each.
5. **Inventory.** Every `set.seed`, `RNGkind`, `.Random.seed` and RNG-using
   call in `R/`, with file:line and purpose.

## 3. Where and how

- Worktree `C:/Users/maxth/ledgr-wt/rng-probe`, branch `claude/rng-probe`
  (from `release/v0.2.3` at `c836d291`). Deliverables under
  `dev/bench/v0_2_3_rng_baseline/`: `probe.R` (runner), `records/` (canonical
  CSVs plus a SHA-256 manifest; reuse the A0 canonical writer in
  `dev/bench/v0_2_3_output_freeze/lib.R` where it fits), `check.R`
  (reruns and diffs byte for byte), `gut.R` (one corruption per record table
  must fail `check.R`), `inventory.md`, and a one-page `findings.md`
  answering questions 1 to 5.
- The record must be deterministic: two `probe.R` runs give identical
  manifests. If a value is legitimately non-deterministic, name it.
- **No product change:** do not edit `R/`, `src/`, `tests/`, `man/`,
  `vignettes/`, `DESCRIPTION` or `NAMESPACE`. Ignore line-ending churn in
  `R/cpp11.R` and `src/cpp11.cpp`; never commit it.
- Another session may be running R work in parallel; timing here is
  descriptive, so note host load but do not wait for a quiet machine.

## 4. Budgets and stop conditions

Stop and report if: the harness passes 800 R lines; the records exceed 2 MB;
a question cannot be answered without changing product code; or the record
is non-deterministic for a reason you cannot isolate.

## 5. Rules

- Commit only your own paths on `claude/rng-probe` with
  `git -C C:/Users/maxth/ledgr-wt/rng-probe commit --only <paths>`. Do not
  merge or push.
- Shell: one simple command per call, absolute paths, `git -C` instead of
  `cd`, plain `Rscript`, script files for probes, no `rm -rf`, no sleep or
  polling loops.
- UTF-8 or ASCII only.
- Report: commit SHA; per-call and share costs; the seeding-path census
  table; the 1-versus-2-worker result; the caller-RNG table; the
  detection-gap table; record size and determinism; gut results; and open
  points for the cut (in particular, candidate pulse-seed rules and RNG kind
  choices the data favours or rules out).
