# LDG-3169 final-candidate record

Round 1 (below, through "Diagnostics") ran on `0ec90fee`. The final
candidate is `28ad2542`, after the maintainer-authorized test repairs; see
"Round 2".

Tested commit `0ec90fee` on `claude/ws4a-carrier` (contracts.md and NEWS.md
of LDG-3169 on top of `e365db21`). Its product is identical to the overflow
product `9b05538f`: the git object ids of `R`, `src`, `tests`, `man`,
`vignettes`, `DESCRIPTION` and `NAMESPACE` are equal on both commits, and
their sha256 product digest is
`f4357f927bbba6aa601e7518f6794879b8668f6bdb3cb12667309f6dc1b60da6` on both.
The evidence commit that adds this folder changes no product file. No timing,
memory or real-data workload was run here (cut 5 `amendment_performance`).

All commands ran from the worktree `C:/Users/maxth/ledgr-wt/ws4a-impl` with
R 4.6.1, one at a time, scratch output under
`C:/Users/maxth/AppData/Local/Temp/ws13-3169/` (`<s>` below).
`R/cpp11.R` and `src/cpp11.cpp` were restored after each step.
`sequence.log` holds the exit codes in run order.

## Commands and outcomes

| Gate | Command | Exit | Outcome |
| --- | --- | --- | --- |
| Build | `R CMD build <worktree>` from `<s>/build` (`<s>/build.R`) | 1, then 0 | the first attempt had no Quarto on PATH and failed at vignettes; the rerun with `QUARTO_PATH` and `RSTUDIO_PANDOC` set to RStudio's bundle, as `dev/build-site.R` does, built `ledgr_0.2.2.tar.gz` |
| Check | `R CMD check --no-manual --no-build-vignettes -o <s>/build ledgr_0.2.2.tar.gz` | 1 | 1 ERROR, 1 NOTE; see "Package check" |
| Coverage | `Rscript tools/check-coverage.R` | 1 | no coverage figure; the same ERROR |
| Cases | `Rscript dev/bench/v0_2_3_ws4a/check.R --base=HEAD --out=<s>/gates/check` | 0 | 23 cases identical |
| Guts and mutations | `Rscript dev/bench/v0_2_3_ws4a/guts.R --base=HEAD --out=<s>/gates/guts --guts=<the 36 registered guts>` | 0 | 36 of 36 FAIL (expected), M1-M12 included; invalid-base control REFUSED (`guts.log`) |
| Dense | `Rscript dev/bench/peer_benchmark/dense/check.R --pkg=<worktree> --out=<s>/gates/dense` | 0 | PASS: nine native arms identical, A0 pointers resolve, scope unchanged |
| A0 record | `Rscript dev/bench/v0_2_3_cut3_successors/a0/record.R --pkg=<worktree> --out=<s>/gates/a0` | 0 | 290 files |
| A0 compare | `Rscript dev/bench/v0_2_3_cut3_successors/a0/compare.R --pkg=<worktree> --successor=<s>/gates/a0 --result=<s>/gates/a0-compare.csv` | 0 | 295 of 295 PASS (`a0-compare.csv`) |
| D20 | `Rscript dev/bench/v0_2_3_ws4a/records/ldg3169/d20.R --out=<s>/gates/d20` | 0 | R8.02-R8.14 identical to `953338df`; R8.01 differs as designed (`ledgr_carrier_provider_view(view, valuation)` added at LDG-3165, absent on the base); witness cases C1, C3, C5b, C6, C8a, C9, C10, C11, C13a, C15, C16 and C18 identical; an injected P5 state encode changes exactly R8.04 and gut C1_drop_notional fails (`d20.log`, `d20-routes.csv`) |
| Identity | `Rscript dev/bench/v0_2_3_ws4a/records/ldg3169/identity.R --base=953338df --candidate=HEAD --work=<s>/gates/identity --result=<s>/gates/identity.csv` | 0 | 16 of 16 PASS (`identity.csv`) |
| Suite | `Rscript <s>/suite.R` (`pkgload::load_all(<worktree>)`, then `testthat::test_local(<worktree>, reporter = "summary", stop_on_failure = TRUE)`) | 0 | no failure; one existing skip (quantmod missing-package path) |
| Real data | maintainer, on the installed product `9b05538f` (library `E:/ledgr-data/r-lib/ledgr-ws4a-9b05538f`): `v0_2_2-reference/compare.R` for the six workloads against `E:/ledgr-data/reference/v0.2.3-base-953338df` | 0 (every step, `realdata/sequence.log`) | all six COMPARE_IDENTICAL (`realdata/realdata.txt`, comparison names and outcomes only) |

The failure-boundary injections are in these gates: C13a, C13b's runtime
witness and C13c (cases, their four swallow guts, and `[WS4a C13b]`,
`[WS4a 3167 precedence]` and LTB-0280 in the suite). The structural
detectors D1-D13, D15-D19 and D21-D25, W1, the validators V-* and U-* and
F4.49 run as their `[WS4a ...]` production blocks in the suite.
`detectors.R` certifies base outcomes and binds deleted functions, so it is
not run on the candidate; `d20.R` evaluates its unchanged route definitions.

## Package check

The tests step fails before running any test. The test control plane
(`tests/test-control-plane.R`, `ledgr_test_scan_file()`) refuses
`tests/testthat/test-accounting-core-consolidation.R`: "Orphan block profile
declaration". Its line 30, `# ledgr-test-profile: review`, belonged to the
LTB-0019 block on the base; LDG-3164 (`fcd05ba2`) inserted the helper
`ledgr_test_book_lots()` between that line and the block (now line 39). A scan
of all 222 test files with the control plane's own scanner
(`profile_scan.R` here, run as `Rscript profile_scan.R <worktree>`) refuses only this file. `testthat::test_local()` does
not run that preflight, so every earlier full-suite record passed. Coverage
runs the same `tests/testthat.R` and stops at the same refusal. Not patched
here: it is a registered test file outside this ticket's edits.

The NOTE is the pre-existing `head` in `ledgr_history_bar_mask_view` without
a `utils` import (recorded in `ws1_disposition.md` and `ws11_disposition.md`).
Every other check step is OK, including running the vignette code.

`check-00check.log` is the check's log.

## Diagnostics (scratch copies only, no tracked change)

These runs edit scratch copies to find what else blocks the check and
coverage. They are not gate results.

| Run | Scratch edit | Exit | Outcome |
| --- | --- | --- | --- |
| Check 1 (`<s>/diag_check.R`, the extracted tarball) | the LTB-0019 declaration moved directly above its block | 1 | the preflight then refuses "Duplicate stable block ID(s): LTB-0514": `test-governance-report.R:1076` and `:1152` share the ID. Pre-existing: both are on the cut base `953338df` and on `release/v0.2.3` (added by `26ea8fb4`, cut 2) |
| Check 2 | also the second LTB-0514 renamed LTB-9514 | 0 | tests OK; 2 WARNINGs only from the object files that check 1 left in the extracted directory, 1 NOTE (`head`) |
| Coverage 1 (`<s>/diag_coverage.R`, a `git archive` of HEAD) | both edits above | 1 | one failing block under covr: LTB-0188, `test-ledger-writer.R:321` (migrated in LDG-3167, `042cf097`) matches `ledgr_event_buffer_setv(cols, name, index, block[[name]])` in the deparsed handler body, which covr's instrumentation wraps across lines |
| Coverage 2 (`<s>/diag_coverage2.R`, covr install kept) | the same | 1 | the same single failure, read from `testthat.Rout.fail` |
| Coverage 3 | also LTB-0188's predicate on whitespace-collapsed source | 1 | one failing block: LTB-0022 (`test-accounting-core-consolidation.R:219`, migrated in LDG-3164), the rescan mutant's depth slope 0.261 is not above the 0.30 allowance under covr (one observation) |

No coverage figure was obtained. The diagnostics stopped there.

## Harness lines

`d20.R` (42), `identity.R` (50) and `profile_scan.R` (13) are new
maintained R: 2,299 to 2,404 lines, under the 2,500-line budget (cut 5
`amendment_budget`).

## Round 2: final candidate 28ad2542

`28ad2542` applies the maintainer's disposition of the package-check and
coverage blockers (2026-10-31). It changes test infrastructure only, and no
test setup, fixture, oracle or bound:

- (d1) `test-accounting-core-consolidation.R`: the helper moves above the
  `# ledgr-test-profile: review` line, which again precedes LTB-0019. LDG-3164
  had orphaned the declaration.
- (d2) `test-governance-report.R:1152`, the later-added LTB-0514 (26ea8fb4,
  claim LCL-0512), becomes LTB-0522, the next free stable ID on every branch;
  `tests/claims.yml` LCL-0512 follows. The two blocks test different claims
  (LCL-0505, LCL-0512). The control plane refuses a duplicate stable ID.
- (e1) LTB-0188 (`test-ledger-writer.R`): its exact-source match runs under
  `if (!ledgr_test_in_coverage())`, the repository's convention, because covr
  rewrites function bodies. It stays fully active outside covr.
- (e2) LTB-0022: `skip_on_covr()`. Investigated first with `<s>/ltb0022_probe.R`,
  which runs the block's own measurement outside covr three times: production
  slope 0.038, 0.023, 0.010 and mutant slope 0.355, 0.403, 0.378 against the
  0.30 allowance, so it passes. Under covr the mutant gave 0.261: the counters
  add depth-independent cost to the instrumented kernel calls, while the
  mutant's extra scan runs in uninstrumented test code. The margin outside
  covr is thin (at least 0.055).

Product code is unchanged: the git object ids of `R`, `src`, `man`,
`vignettes`, `DESCRIPTION` and `NAMESPACE` equal `9b05538f`'s (sha256
`a4a0d4b0ddd8f4c61227a9ce3f86d4ba7625412ddda419ead60161cdf343e1fe` on both).
The control plane's scanner now refuses no file and the preflight passes.
Scratch `<s>/gates2/`; `round2/sequence.log` holds the exit codes.

| Gate | Command | Exit | Outcome |
| --- | --- | --- | --- |
| Build | `<s>/build2.R` (R CMD build into `<s>/build2`, Quarto set) | 0 | `ledgr_0.2.2.tar.gz` |
| Check | `<s>/check2.R` (R CMD check --no-manual --no-build-vignettes) | 0 | 0 ERRORs, 0 WARNINGs, 1 NOTE: the pre-existing `head` without a `utils` import in `ledgr_history_bar_mask_view` (`round2/check-00check.log`) |
| Coverage | `Rscript tools/check-coverage.R` | 1 | not obtained; see below (`round2/coverage-attempt1.log`) |
| Coverage, second attempt | the same | 1 | the same error (`round2/coverage-attempt2.log`) |
| Cases | `check.R --base=HEAD --out=<s>/gates2/check` | 0 | 23 cases identical |
| Guts and mutations | `guts.R --base=HEAD --guts=<the 36>` | 0 | 36 of 36 FAIL (expected); invalid-base control REFUSED (`round2/guts.log`) |
| Dense | `dense/check.R --pkg=<worktree>` | 0 | PASS, nine native arms identical |
| A0 | `a0/record.R`, then `a0/compare.R` | 0, 0 | 295 of 295 PASS (`round2/a0-compare.csv`) |
| Suite | `Rscript <s>/suite.R` | 0 | no failure; one existing skip (quantmod) |
| Real data | as in round 1 (maintainer, product `9b05538f`) | 0 | six COMPARE_IDENTICAL |

D20 and identity read only `R/` and `src/` (and the product's runtime) and
are not repeated: their round-1 results on `0ec90fee` hold for the
unchanged product.

### Coverage: not obtained

Status: not obtained. covr's child-result collection fails on this Windows
host (tooling, maintainer 2026-10-31); routed to `inst/design/horizon.md`
(2026-10-31, coverage collection fails on the Windows host). Both attempts
ran the whole test run and then failed in the collector:

```
Error in readRDS(f) : error reading from connection
Calls: ledgr_check_coverage_main ... ledgr_with_ordinary_coverage_env -> force -> ledgr_collect_coverage
Execution halted
```

What is known: a diagnostic collection with covr's install kept
(`<s>/diag_traces.R`, exit 1) left 22 `covr_trace_*` files, of which 20 do
not `readRDS()`. Those 20 are about 1.2 MB each, written in pairs about a
second apart between 20:26 and 20:39, which matches two-worker daemons. Two
traces are readable, the main process's 13 MB trace among them. Several
worker-backed blocks start daemons with no coverage skip (found by
`<s>/worker_blocks.R`): `test-rng-isolation.R` :249, :448 and :521,
`test-pulse-seed-v2.R`:399, `test-sweep-parallel.R`:344 and possibly
`test-history-substrate.R`:1194. What is unknown: that those daemons write
the truncated traces, and whether coverage passes once they are skipped. A
scratch run with them skipped was stopped unfinished on the maintainer's
instruction. No coverage figure exists for this candidate.
