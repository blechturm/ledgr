# Terminal outcomes: current-behavior probe

**2026-10-04 / Claude, for the maintainer.** Stage-1 probe before the
terminal-outcome RFC seed. Binds no design.
**Question:** What does ledgr do today when a held instrument becomes
untradable, and how do the result, comparison, sweep and walk-forward surfaces
treat the resulting run?
**Tree:** `a5443f3` (an exported copy, so uncommitted work is excluded), R 4.6.1.

`probe.R` uses the public API on sealed snapshots. AAA rises from 100 to 130
over three sessions and then becomes untradable on session 4. BBB rises
steadily over ten sessions and is never affected. The strategy buys 10 of
each on the first pulse, then holds. The valuation policy is
`ledgr_valuation_stale(2)`. All 84 observations are in `observations.csv`.

## Runs

| Case | What happens to AAA | Outcome | Achieved end | Equity rows |
| --- | --- | --- | --- | ---: |
| R1 | Delisted (lifetime terminal), no settlement evidence | `INCOMPLETE`, `terminal_settlement_unsupported` | session 3 | 3 of 10 |
| R2 research | Acquired, with an unvalidated `cash_acquisition` fact, research preset | `DONE`; one `DISPOSITION` at the last close (proceeds 1,300 = 10 x 130; model P&L +150) | session 10 | 10 |
| R2 strict | The same as R2, strict preset | `INCOMPLETE`, `terminal_settlement_unsupported` | session 3 | 3 |
| R3 | Known halt from session 4, no further bars | `INCOMPLETE`, `valuation_horizon_exhausted` | session 5 | 5 |
| R4 | Halt as in R3; the strategy targets AAA = 0 | Exit recorded as `execution:no_fill:trading_halted`, not queued; then `valuation_horizon_exhausted` | session 5 | 5 |
| R5 | Bars simply end; no fact explains why | `INCOMPLETE`, `valuation_horizon_exhausted` | session 5 | 5 |
| C1 | The same R1 snapshot, but the strategy never holds AAA | `DONE` | session 10 | 10 |

- **The whole portfolio stops, not just AAA.** BBB's path after the stop is
  lost in R1, R2 strict and R3–R5.
- **Prints label the result honestly** as "Total Return (achieved prefix)".
- **A known halt (R3) ends exactly like an unexplained data gap (R5).** Both
  stop at the same session for the same reason.
- **The research preset already applies an assumption-like outcome.** With an
  acquisition fact but no validated cash, it disposes the holding at its last
  close and finishes `DONE` (R2). Only the delisting with no fact at all (R1)
  has no modeled path.

## Comparison and selection

| Surface | Observed |
| --- | --- |
| `ledgr_run_compare(snapshot)` | Its default table shows only `C1_without_aaa`; R1 is left out without notice. Naming R1 explicitly fails with `ledgr_run_not_complete`. |
| `print(sweep)` | Shows the `INCOMPLETE` row with its prefix metrics in the same columns as the `DONE` row (total return +1.6% against +0.8%; Sharpe 11.2 against 42.3). The footer says "2 combinations: 1 done, 0 failed", so the incomplete candidate is counted nowhere. |
| `ledgr_sweep_review(rank_by = "sharpe_ratio")` | Ranks only the `DONE` candidate. The incomplete one appears under "Issue rows" with `error_class` and `error_msg` both `NA`; no stop reason is shown. |
| `ledgr_sweep_filter()` | Evaluates completed candidates only ("candidates: 1"). |
| `ledgr_effective_trials()` | Fails with `ledgr_validation_cluster_too_few_candidates`. `returns = "completed"` is the only available retention mode, so an incomplete candidate never enters return panels, effective-trial counts or DSR. |
| `ledgr_walk_forward()` (training window contains the delisting) | The session is `DONE` and selects `without_aaa`. The scores keep nine `INCOMPLETE` training rows for `with_aaa`, but the print shows only a short-window health warning and nothing about the excluded candidate. |

Together these are strategy-level survivorship. A variant that meets the
terminal event drops out of comparison, ranking, filtering, trial counting and
walk-forward selection, with no recorded reason at any of those surfaces.

## Side observation

Once a trading-status family is declared, an instrument with no status row is
treated as restricted. The first R3 attempt, which had no BBB row, failed on
pulse 1 with `ledgr_restricted_target` for BBB. The fixture now declares BBB
active. Whether this is intended is outside this probe.

## Not executed

The probe did not exercise:
- dense runs without availability facts;
- short positions;
- `ledgr_pbo()`, and `ledgr_dsr()` beyond its effective-trial prerequisite;
- sweeps with more than two candidates;
- promotion;
- long histories;
- an instrument that keeps trading OTC after delisting. The snapshot cannot
  represent that case today, so it is a design input rather than an executed
  observation.

From the repository root (the probe loads the tree with `compile = FALSE`,
so that tree needs a built `src/ledgr.dll`):

```sh
git archive a5443f3 | tar -x -C <tree>   # then copy src/ledgr.dll into <tree>/src/
Rscript dev/spikes/terminal-outcomes/probe.R <tree> <output-dir>
```
