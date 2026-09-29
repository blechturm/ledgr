# Strategy Helper Axis Closeout

**Status:** Accepted by the maintainer on 2026-09-29, after the close-review
correction at `ac28924`.
**Date:** 2026-09-29
**Cut:** 22
**Workstream:** 30
**Implementation range:** `63c453b..ac28924`, the baseline acceptance `6497c00`,
and this closeout record.

## Decision

Every strategy helper works on one decision axis, `ctx$universe`, and one
eligibility plane, `ctx$vec$admissible`, in dense and ragged universes alike.
The accepted rules are in `inst/design/contracts.md`, "Decision Axis And
Eligibility" (LDG-2906, accepted by the maintainer on 2026-09-29 as it stood
at `6f104fa`, rebased as `d8fd7be`). Cut 22 decisions 1 to 4 in `tickets.yml`
record the choices behind them. Decisions 3 (sell departed holdings by default,
declared on the universe) and 4 (the intent-layer model) do not ship in this
cut: ledgr keeps today's literal-target behaviour, now stated in the contract
and help, and the design homework is recorded in `horizon.md` on 2026-09-29.

## Shipped Claims And Detectors

| Ticket | Claim | Detector | Commit |
| --- | --- | --- | --- |
| LDG-2905 | The audit and its probe record every helper on every context shape. | `dev/spikes/strategy-helper-axis/` probe, 1,635 observations | `63c453b`, `813c112`, `9796913`, `d8fd7be` |
| LDG-2906 | One axis, one eligibility plane, a domain table with types and the A1 to A6 mapping. | contract section; model and manifest | `9796913`, `a924c69`, `d8fd7be`, `4a2fdcd` |
| LDG-2907 | Dense contexts expose `ctx$members` and the four planes, all eligible, built once per run. | LTB-0119 / LCL-0119 | `a3166c6` |
| LDG-2908 | Context signals return raw values over the axis with an `eligible` attribute. | LTB-0120 / LCL-0120 | `7450692` |
| LDG-2912 | Selections, rankings and target helpers apply eligibility and keep ineligible holdings. | LTB-0121 / LCL-0121 | `7450692` |
| LDG-2909 | `ledgr_signal_strategy()` maps eligible instruments, holds the rest and accepts an empty axis. | LTB-0122 / LCL-0122 | `2fd53a2` |
| LDG-2910 | `ledgr_passed_warmup(ctx, values)` checks eligible instruments only. | LTB-0123 / LCL-0123 | `266cf5c`, correction |
| close review | A missing or malformed eligibility plane fails closed in every context helper. | LTB-0124 / LCL-0124 | correction |

The claim records carry the fixtures, condition classes and smallest failing
changes; each ticket's evidence in `tickets.yml` carries its mutation counts.
Blocks that pinned the old member projection and NA masking (LTB-0085, 0087,
0088, 0090, 0095, 0096, 0098) were updated to the decided behaviour, and
their claims restate the contract.

## Probe Check Against The Frozen Baseline

`observations.csv` is the frozen Cut 22 baseline (1,635 observations) and
`expected_delta.csv` the manifest derived from the LDG-2906 model: 460 rows,
LDG-2907 30, LDG-2908 171, LDG-2912 120, LDG-2909 34, LDG-2910 105. Each
ticket passed `check.R --through <ticket>`, with its rows and every earlier
ticket's realized, later tickets' rows at their baseline, and nothing outside
the manifest changed. At `266cf5c`, and again after the close-review
correction:

```text
Rscript dev/spikes/strategy-helper-axis/check.R
ok through all: 1635 observations, 460 expected change(s) realized, 0 pending at their baseline value
```

`check.R --accept` ran after the close review had rerun this check and the
maintainer had accepted the workstream, in its own commit `6497c00`: the 460
manifest rows became the baseline, the manifest is empty, and the check passes
against the new baseline with no expected changes.

## Costs

All clocks are warm, interleaved, one process per arm, with bytes from
`Rprofmem()`; each ticket's evidence has the full table and harness.

| Ticket | Measure | Before | After |
| --- | --- | --- | --- |
| LDG-2907 | context refresh, axis 500 | 225 us, 314,632 B | 200 us, 314,640 B |
| LDG-2907 | dense run 100 x 250, per pulse | 1.68 ms, 9,772 B | 1.72 ms, 9,772 B |
| LDG-2907 | availability run 50 x 120, per pulse | 3.58 ms, 20,353 B | 3.50 ms, 20,353 B |
| LDG-2908/2912 | dense helpers, axis 500 | baseline | bytes within +5%/-4%, time within 7.4% (`ledgr_selection(ctx)` +6% at 20,000 calls) |
| LDG-2908/2912 | ragged helpers, axis 500 | members only | +11% to +74% bytes, because outputs cover the whole axis; per element no more than dense |
| LDG-2908/2912 | dense and availability pipeline runs, per pulse | 1.84 ms, 10,504 B; 3.83 ms, 22,032 B | unchanged |
| LDG-2909 | wrapper call, axis 500, dense | 395 us, 177,760 B | 400 us, 177,760 B |
| LDG-2909 | wrapper call, axis 500, ragged | 385 us, 177,760 B | 405 us, 204,552 B (keeping ineligible holdings) |
| LDG-2909 | wrapper runs, per pulse | baseline | +2% dense and availability, paired within a machine level shift |
| LDG-2910 | one-argument warmup | 1.43 us, 0 B | 1.15 us, 0 B (after the correction) |
| LDG-2910 | context warmup, axis 10 and 500 | not available | 22 us and 55 us, 67,448 B at 500 |
| correction | context warmup on a signal, axis 500 | 125 us, 163,576 B | 40 us, 43,016 B |
| correction | every helper and wrapper call, axis 500; pipeline and wrapper runs | `252c1cc` | within +2.5%/-5%, identical bytes |

Three regressions were found by measurement and fixed before their tickets
landed: dense `ledgr_selection(where =)` +26% and `ids =` +10% bytes, and a
double projection in `ledgr_signal(ctx, values)` (LDG-2912); the wrapper's
+44% dense allocation (LDG-2909); and the one-argument warmup's +11% from the
new dispatch (LDG-2910). No change adds a loop over instruments, pulses or
rows; the per-instrument warning loop in `ledgr_target_rebalance()` became one
aggregated warning.

## Close-Review Corrections

The close review (invocation 4) confirmed invocation 3's four fixes, every
registered mutation, the real folds, the seven-shape walk and the costs, and
found three defects, all fixed:

- The one-argument warmup form's `!anyNA(x)` body, introduced to pay for the
  new dispatch, differs from `all(!is.na(x))` for a classed vector whose
  `is.na()` and `anyNA()` methods disagree. The fast path now applies to plain
  vectors only. The LDG-2910 record's claim that the two are identical for
  numeric input was wrong and is corrected there.
- `ledgr_strategy_eligible()` rebuilt eligibility from `ctx$members` when an
  availability context lacked a well-formed plane, so a restricted member could
  be selected. It now fails closed with the caller's condition class; a dense
  context without the plane stays all eligible. LTB-0124 covers four broken
  planes across eight helper calls. One hand-built availability test fixture
  lacked the plane and now carries it.
- The context warmup form sent a signal through the full entrance a second
  time. A signal on the context's axis is now read directly, with eligibility
  from `ctx`; other payloads, including a signal with an infinite score, still
  take the entrance.

Eleven mutations each fail the owning block; the counts are in LCL-0123,
LCL-0124 and LDG-2911's evidence.

## Fast Gate

After the correction the ordinary fast profile passed 490 of 490 blocks in
74.72 seconds against the 112-second bound, on duckdb 1.5.6.9000 (107.5
seconds on duckdb 1.5.5 at `2fd53a2`; see Cut 23). A one-process full-suite
run fails the same nine tests before and after the correction, plus LTB-0123,
whose entrance counter reads 0 there as LTB-0095's and LTB-0119's do;
LDG-2914 owns that and LDG-2913 the stale witness baseline.

## Open Points For The Maintainer

- The context warmup form's conditions carry `ledgr_invalid_warmup_input`
  only, as the frozen manifest and the model state; the one-argument form's
  also carry `ledgr_invalid_args`.
- The articles still teach the pre-Cut 22 helpers in places; WS29 (LDG-2898
  to LDG-2901) re-renders them.

## Governance

Cut review invocation 1 (Codex, CHANGES_REQUIRED, seven findings patched),
invocation 2 (Type 2 review of LDG-2906, NEEDS_TYPE_2), invocation 3 (Type 2
re-review, CHANGES_REQUIRED, four findings fixed without a further review by
the maintainer's choice) and invocation 4 (the Workstream 30 close review,
CHANGES_REQUIRED, three findings fixed without a further review by the
maintainer's choice): 4 over 8 tickets, `0.500`, at the gate.
