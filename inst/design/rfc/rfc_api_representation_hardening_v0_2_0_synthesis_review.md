# Synthesis Review: API And Representation-Boundary Hardening

**Role:** Claude, final reviewer. Codex wrote Seed v1 and the response review, Claude
wrote the response, ChatGPT Astra wrote the synthesis. **Date:** 2026-09-09.
**Under review:** `rfc_api_representation_hardening_v0_2_0_synthesis.md` at `87ef0d8` on
`origin/rfc/api-hardening-synthesis-v0.2.0` (578 lines, ASCII, no long lines), baseline
`27a95f2`. Line numbers below without a file are lines of the synthesis.
**Status:** Verification complete. Four patches were required, one High; all four are
applied and verified on branch commit `68195be`. No design is reopened; maintainer
decisions 1-4 stand. The synthesis is ready for maintainer acceptance.

## What ran

- Probe rerun, `Rscript dev/spikes/api-representation-hardening/probe.R` on R 4.5.2:
  output identical to the recorded run; all twelve observations hold.
- Gut of the load-bearing claim in Section 6, recorded as
  `dev/spikes/api-representation-hardening/review_gut_fold_rollback.R`: three committed runs
  on the probe fixture with `checkpoint_every = 2`, then the store inspected through a fresh
  read-only connection.

| Scenario | Status | `ledger_events` | `strategy_state` | `equity_curve` |
| --- | --- | --- | --- | --- |
| A: strategy error at pulse 4, after the periodic flush at pulse 2 | FAILED | 0 | 0 | 0 |
| B: partial run, `max_pulses = 3` | RUNNING | 3 | 0 | 0 |
| C: clean run | DONE | 7 | 0 | 8 |

- Source census: every cited line range in Sections 2 and 5; every cited test file and
  `tools/check-readme-example.R` exist; `ledgr_backtest_run()` and
  `ledgr_backtest_run_internal()` are internal (not in `NAMESPACE`) with callers at
  `R/backtest.R:303` and twelve acceptance-test sites; `ledgr_run_open()` opens only `DONE`
  runs (`R/run-store.R:981`); the availability synthesis Section 14.1 has 24 gates; naming
  synthesis 7.6 is the streaming gate; the horizon entry follows the `rfc_cycle.md` pattern.

## Findings by severity

### High

**H-1: Section 6 and gate G12 rest on a checkpoint that does not exist.** The synthesis
defines "checkpoint K" as the durable state after the first nonempty periodic flush and
injects the fault on the second flush (lines 291-298, G12 at line 432). But
`ledgr_execute_fold()` runs the whole pulse loop inside `output_handler$run_transaction()`
(`R/fold-engine.R:595`, which is `DBI::dbWithTransaction` at `R/backtest-runner.R:291-293`).
Periodic `flush_pending()` calls (`R/fold-engine.R:571-575`; handler at
`R/backtest-runner.R:504-534`) drain buffers inside that one transaction. Executed, scenario
A: an error at pulse 4 after a flush at pulse 2 leaves zero ledger, state, and equity rows
and a FAILED status. Nothing a periodic flush writes is durable until the fold returns, so
assertion 2 is vacuous and assertion 3 is a rerun from scratch. Verification: executed.

Section 11.2 calls the cadence "not established"; it is established. `checkpoint_every` is
config `engine$checkpoint_every` (`R/backtest-runner.R:605-611`), exposed by
`ledgr_backtest()` (`R/backtest.R:101`) and not by `ledgr_run()` or `ledgr_experiment()`,
and it is buffer-drain cadence, not durability. The baseline has three real seams:

1. the fold transaction, now shown atomic by scenario A;
2. the partial-run commit (`full_run = FALSE`, status RUNNING,
   `R/backtest-runner.R:1296-1303`), scenario B, already pinned by `test-runner.R:110` and
   AT8 (`test-acceptance-v0.1.0.R:291`);
3. finalization (`R/backtest-runner.R:1306-1497`): the features `DELETE` plus append run
   in one transaction (1458-1476) and the equity-curve `DELETE`, append, and DONE write in
   a second (1479-1485); neither is inside the fold transaction, and the coordinator
   `tryCatch` covers only the fold call (1275-1290). A failure between the two leaves a
   committed full fold and features, no equity finalization, status RUNNING, and no error
   message. Verification: source. Corrected after the synthesis patch: the first version
   of this review called these writes autocommit; the resume tail cleanup at 955-964 is a
   transaction as well.

Seam 3 is the interrupted-persistence scenario worth the new test. *Patch:* rewrite the
Section 6 fixture around seam 3 (full fold; inject between the two finalization
transactions; spec-cut names the hook), with assertions (1) fold rows
committed and unchanged, (2) status and error fields as decided in a new Section 11
question (record FAILED on finalization failure, or keep RUNNING as resumable), (3) resume
yields the clean run's outputs; keep seam 2 as the existing net; delete "checkpoint K" and
the two-decision cadence (lines 288-298); rewrite G12 and 11.2 to match. The response's
stage-4 sentence ("fails the handler's flush on the nth call ... no rows past the last
checkpoint") carried the same misconception; the response is accepted and historical, and
this finding is its correction.

### Medium

**M-1: the review-lineage snippet does not run.** Line 144 calls
`ledgr_promote(exp, candidate)`; `run_id` has no default (`R/sweep.R:568-572`). *Patch:*
`bt <- ledgr_promote(exp, candidate, run_id = "promoted_from_review")`. Verification: source.

### Low

**L-1:** lines 149-151 say the promotion completeness of `top` "is not established by P6".
Source establishes it: `ledgr_sweep_review_top_cols()` (`R/sweep-review.R:120-126`) omits
`provenance`, which `ledgr_candidate()` requires (`R/sweep.R:391`), so `top` cannot be a
candidate input today. *Patch:* cite that instead of "not established".

**L-2:** line 218 attributes "use the base pipe" to the styleguide; `vignette_styleguide.md`
has no pipe rule. *Patch:* drop the clause, or mark it *source* citing vignette practice.

## Verified without finding

Decisions 1-4 propagate consistently through Sections 1, 2, 3, 5, 7, 9, 10, 13; the phase
map matches the patched response and the code; twelve gates; the "v1" disclaimer; open
questions separated from future obligations; `ledgr_run_fills(bt)` with no `...` rejects
removed arguments by matching; `-final_equity` is a valid `rank_by`
(`R/sweep-review.R:82-88`); the wrapper deletion in stage 1 removes no export.

## Decision

Patches required before acceptance: H-1, M-1, L-1, L-2. Verified on `68195be`: the
fixture, G12, and Section 11.2 now target the gap between the two finalization
transactions with an explicit status and error decision; the promotion snippet carries
`run_id`; the `top` sentence cites the missing `provenance` column; the pipe clause is
gone; no "checkpoint K" or periodic-flush language remains; twelve gates; 624 lines, ASCII,
no long lines. Accept the synthesis and append its Section 14 horizon entry.

## Revision History

- **2026-09-09** -- Initial review at `173603b`.
- **2026-09-09** -- After branch patch `68195be`: seam 3 corrected to the two finalization
  transactions (the synthesis author caught the autocommit error), the four patches
  verified against the code, decision updated to ready for acceptance.
