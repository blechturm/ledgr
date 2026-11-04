# Close review 25, re-review 2: WS25 correction (e6c90f0d, a497bfb5)

Mode: final narrow clean-context Type 1 confirmer. Scope: `e6c90f0d` and
`a497bfb5` against `close_review_25_rereview_1.md` (N1-N7). Concurrent
RFC/horizon commits and the untracked observable-data seed v2 were ignored.
E:, private data, the LDG-3209 private rebuild, the rule-16 milestone and the
paired H1 gate were not touched.

## Verdict: CHANGES_REQUIRED

N1, N2, N6 and N7 are resolved. N3, N4 and N5 are partly resolved. The N5
correction adds a new High defect: the decision-order validator now costs
seconds on every durable run's finalisation and on every bounded read.

## N1-N7

| Finding | Status | Evidence |
| --- | --- | --- |
| N1 dividend/state oracle | Resolved | `fixtures.R:91-104` declares `portfolio_state = list(observed_cash = 0)` and makes the day-two buy depend on `ctx$state$observed_cash == 1000`. Both run records are DONE with no condition rows (`records/dense_dividend_state/run/runs.csv`). Both candidates post `corporate_action_cash`, and `add` fills 3 AAA (`run/ledger_events.csv`, `sweep_w1/memory_events.csv`). `lib.R:484-487,509-529` stops on a FAILED non-`failures` workload and on a missing dividend posting or fill. The closeout gut table (`closeout.md:121-140`) matches `gut_results.csv` row for row. |
| N2 empty-evidence witness | Resolved | LTB-0557 now creates its rows only through `ledgr_run_registration()` and `ledgr_run_restart_nonterminal()`. In-memory mutation: replacing the initializer at `R/run-registration.R:88` makes LTB-0557 error with "Run diagnostic summary evidence is missing or dup[licated]". Replacing the one at `R/run-resume.R:44` gives the same error. Both orphans list and `ledgr_run_info()` reads them when unmutated. |
| N3 test-change record | Partly resolved | LTB-0190 (7 to 9, still equal to the one-run count), LTB-0281 and the ambient-RNG normalization (only `run_id`, `event_id` and row names) are recorded with reasons (`per_pulse_restart_decoder_closeout.md:123-142`). The dead `preserve_diagnostic_seq` branch is deleted. LTB-0138 is not failure-sensitive as claimed (R2). |
| N4 stale wording/residue | Mostly resolved | All listed conditions, comments and dead helpers are gone, and LTB-0555 now detects them. Two comments remain (R4). |
| N5 decision order | Swap class resolved; new defect | Swapping stored `(decision_seq, decision_order)` pairs refuses, and the legitimate multi-fill pulse decodes (LTB-0558 green). The context half is still self-authored (R3), and the validator's cost is R1. |
| N6 run naming | Resolved | The association, sequence and decision-order errors name the offending run. LTB-0558 checks this for the second run of a two-run decode. |
| N7 detector attribution | Resolved | LTB-0559/LCL-0546 is registered, carries its `review` profile marker, and pins exact, missing and ambiguous association plus the no-scan shape. `per_pulse_restart_decoder_closeout.md:62-64` attributes it correctly. |

Store identity is unchanged otherwise. The schema stays 125, and
`decision_order` becomes BIGINT with the golden column digest updated in the
same commit. There is no migration, fallback or compatibility reader. The
private rebuild, rule-16 milestone and H1 gate stay explicitly OPEN
(`tickets.yml` LDG-3209 evidence, `per_pulse_restart_decoder_closeout.md:168-179`).

## New findings

### R1. High: the decision-order validator adds seconds to every durable run

`R/diagnostic-decoder.R:171-262` pulls every implicit row of the requested
runs into R. It then builds one formatted string key per row
(`format(ts, "%OS6")` plus `paste`, line 223) and radix-sorts the keys.

- **It ignores the filters.** The query has no `instrument_id` or
  `explain_ts_utc` predicate, unlike the association query just above it.
- **It runs on the run path.** `ledgr_diagnostic_require_coverage()` is called
  by `ledgr_diagnostic_summary_from_store()` (`R/diagnostic-codec.R:153`). That
  function is reached from `sink$write_diagnostic_summary`
  (`R/output-handler.R:143-144`) at every durable finalisation, and from
  `ledgr_run_open()`, `ledgr_explain`, terminal evidence and results reads.

Measured with plain `Rscript` and `load_all()`. This is a rough diagnostic,
not a protocol timing gate. The workload is a 500 x 1,260 hold run, which has
630,000 implicit rows:

| Measurement | Candidate | New block disabled in memory |
| --- | --- | --- |
| `require_coverage`, full | 3.44 s | 0.06 s |
| `require_coverage`, one instrument and one timestamp | 3.32 s | (not measured) |
| `ledgr_run()`, alternating arms | 9.08 s, 7.75 s | 5.54 s, 4.38 s |

That is about +3.4 s, or roughly 1.7x, on the run that the published peer
benchmark uses. The rule-16 milestone would inherit this regression. It
contradicts LDG-3207's "filtered reads do not expand the full run first". It
also breaks the optimization style's reader-path rules: manifest data frames
only at boundaries, and no per-row string keys.

**Fix.** Keep the same exact check, but run it in DuckDB as the execution-order
check already does:

1. Decompose `decision_order` with integer arithmetic.
2. Join the axis position from the stored universe, either through
   `json_extract`/list position on `runs.config_json` or through a registered
   (not written) axis relation.
3. Use the existing `LAG` window over `(run_id, ts_utc)` ordered by the context
   component.
4. Return at most one offending `run_id`.
5. On an `explain_ts_utc` read, restrict the check to that pulse.

A proportionate witness is a query-shape or rows-transferred assertion, not a
timing test.

### R2. Medium: LTB-0138 does not detect two of its claimed mutations

LCL-0138 (`tests/claims.yml`) claims the block fails if the handler "reuse[s]
the rolled-back in-memory counter" or "omit[s] the refresh". The test builds a
fresh handler and calls `write_exception_diagnostic()` with no prior staged
block. `next_diagnostic_seq()` therefore seeds from the store whether or not
`refresh` is set (`R/output-handler.R:612-617,644-645`).

In-memory mutation: `refresh <- FALSE` at `R/output-handler.R:644` leaves
LTB-0138 green.

**Fix.** Before the exception, stage a block through
`handler$write_run_diagnostics()` that advances the in-memory counter past 8,
and do not commit it, as a failed pulse would not. Then assert that the
exception row takes sequence 8. Alternatively, narrow `smallest_failing_change`
to the inline-MAX guard. Record the change in the closeout.

### R3. Low (maintainer choice): the context half of `decision_order` is still self-anchored

The axis component is checked against the stored universe. The context
ordinal is not. Probe on the LTB-0558 fixture: keep each row's own axis
component, exchange only the context components, and swap `decision_seq` to
match. The run decodes silently, and the first pulse's decision rows change
order from AAA, BBB to BBB, AAA.

Three records claim more than this:

- LCL-0545's `smallest_failing_change` ("coordinate a decision-sequence and
  self-authored ordinal rewrite");
- `per_pulse_restart_decoder_closeout.md:87-88`;
- the LDG-3208 evidence line.

**Fix.** Narrow these to "swaps of stored decision-order tokens", and record
that a forged context ordinal is out of scope. The other option is to anchor
the context ordinal as well.

### R4. Low: two stale continuation comments

- `R/run-registration.R:124` ("a resume call that supplies a conflicting
  context");
- `R/lot-accounting.R:5` ("opening and resume").

The internal `is_resume` field (`R/run-registration.R:52,141-143`;
`R/backtest-runner.R:372-547`) now means "existing run". Renaming it is
optional.

### R5. Low: malformed manifest hash in the A0 closeout

`dev/bench/v0_2_3_output_freeze/closeout.md:108` records a 61-character
"SHA-256" with `0bf` dropped. The committed `records/manifest.csv` hashes to
`5f1a698744a28d81a4acbcdebd746d240ef0bf34dbe7ff7c55e9ec1714509c31`.

## Commands

Executed: in-memory namespace mutations of `ledgr_run_registration`,
`ledgr_run_restart_nonterminal` and `ledgr_output_handler`, each with LTB-0557
or LTB-0138 run through `testthat::test_file(desc = ...)`; baselines for
LTB-0557, LTB-0138 and LTB-0558 (green); the R3 probe; the R1 timings above;
and `sha256sum` of the manifest. No repository file other than this record was
written.

Not run here: the full suite, R CMD build/check, A0 `check.R`/`gut.R`, the
typed-accounting checker and the codebase census. Their claimed figures (1,347
blocks; 300 files/634,264 bytes, 204 checks, 2 differences; 86/30/22/300;
2,006/2,487/89; Status OK) were not independently reproduced.

## LDG-3209 readiness

Not ready. R1 must be fixed first, because it would otherwise surface as a
rule-16 regression and inflate the private Sharadar rebuild. R2 and the R3
record are small. After that, re-record the A0 freeze only if the fix changes
stored output (it should not), re-run the full suite and R CMD check, and the
public candidate is ready for the maintainer's private rebuild, the rule-16
milestone and the paired H1 gate.
