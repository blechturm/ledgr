# Cut 10 real-data continuity oracle (LDG-2972)

Maintained public-path oracle for the three EXP-0003 stoppers that Cut 10
closes. Fixtures are vendor-neutral and derived from the ledgr-research
reproducer `scripts/sharadar/reproduce_exp0003_ledgr_findings.R`.

```sh
Rscript dev/bench/v0_2_2_real_data_continuity/run_record.R <repo> <out_dir> [--allow-dirty]
Rscript dev/bench/v0_2_2_real_data_continuity/check_record.R <out_dir>/record.csv --expect pre|post
```

The runner refuses a dirty tracked tree, records every arm's condition
instead of stopping, and writes `record.csv` with the commit and command.

## Groups

| Group | Ticket | Claim |
| --- | --- | --- |
| `lfb017` | LDG-2973 | An eligible member without a current close is skipped, not fatal; priced members keep their fully priced size unless held skipped exposure would push the total above allocatable equity; every skip is a `sizing_unavailable` decision row even when the strategy flattens the target |
| `lfb023` | LDG-2974 | A fold without a selectable candidate reuses the latest training selection (`previous`) or runs no test window (`none`); `no_selection = "fail"` keeps the refusal |
| `lfb018` | LDG-2975 | An early exit by error or interrupt after registration leaves the run `FAILED` with a message, and the condition still reaches the caller |
| `invariance` | all | The close-filter workaround, a gap-free run, dense warn-and-zero sizing, an all-select walk-forward, the `ledgr.interrupt` soft stop (RUNNING) and resume stay unchanged |

## Fixture arithmetic

Two members, five sessions (2020-01-06 to 2020-01-10), open equals close,
AAA at 10 and BBB at 20, cash 1000, zero costs.

- **Default:** equal weight, `equity_fraction = 0.9`. AAA is
  `floor(0.5 * 0.9 * 1000 / 10) = 45` on every pulse. BBB has no bar on day 1
  (unheld, skipped at 0) and day 4 (held 22; E = 440, V = 450, V + E <= 1000,
  so AAA stays 45). Otherwise BBB is `floor(450 / 20) = 22`. Fills: AAA 45
  on day 2, BBB 22 on day 3, nothing else.
- **Cap:** weights 0.1/0.9 at fraction 1 on days 2 and 3 buy AAA 10 and
  BBB 45. Day 4 asks for 0.5/0.5 with BBB unpriced and held: E = 900,
  V = 500, s = (1000 - 900) / 500 = 0.2, AAA = `floor(0.2 * 500 / 10) = 10`.
- **Walk-forward:** weekdays of 2020, two random-walk members, rolling
  two-month train and one-month test windows stepped monthly. Candidates that
  trade until the end of May leave every training window starting in June or
  later with constant equity and no finite Sharpe ratio.

## Evidence

`evidence/pre_cut` is recorded from the clean LDG-2972 commit, product-identical
to `0c1fe2b`, and passes `--expect pre`.
