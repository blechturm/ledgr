# Real-data continuity oracle (Cut 10 LDG-2972, Cut 11 LDG-2977)

Maintained public-path oracle for the real-data stoppers that Cuts 10 and 11
close. Fixtures are vendor-neutral and derived from the ledgr-research
reproducer `scripts/sharadar/reproduce_exp0003_ledgr_findings.R` and the
1998-2026 Sharadar run (`dev/bench/v0_2_2_sharadar_run/`).

```sh
Rscript dev/bench/v0_2_2_real_data_continuity/run_record.R <repo> <out_dir> [--allow-dirty]
Rscript dev/bench/v0_2_2_real_data_continuity/check_record.R <out_dir>/record.csv \
  --expect pre|post10|pre11|post [--against <earlier record.csv>]
```

The runner refuses a dirty tracked tree, records every arm's condition
instead of stopping, and writes `record.csv` with the commit and command.

## Groups

| Group | Ticket | Claim |
| --- | --- | --- |
| `lfb017` | LDG-2973 | An eligible member without a current close is skipped, not fatal; priced members keep their fully priced size unless held skipped exposure would push the total above allocatable equity; every skip is a `sizing_unavailable` decision row even when the strategy flattens the target |
| `lfb023` | LDG-2974 | A fold without a selectable candidate reuses the latest training selection (`previous`) or runs no test window (`none`); `no_selection = "fail"` keeps the refusal |
| `lfb018` | LDG-2975 | An early exit by error or interrupt after registration leaves the run `FAILED` with a message, and the condition still reaches the caller |
| `invariance` | Cut 10 | The close-filter workaround, a gap-free run, dense warn-and-zero sizing, an all-select walk-forward, the `ledgr.interrupt` soft stop (RUNNING) and resume stay unchanged |
| `lfb019` | LDG-2978 | `ledgr_state_reconstruct()` rebuilds a completed availability run with missing bars, a skipped member, a stale mark and a frozen mark, matching its stored equity at every pulse |
| `wfgap` | LDG-2979 | `carry_test_state` over test windows with pulses between them refuses before any store write, naming the first gap and both remedies |
| `wfresume` | LDG-2980 | Rerunning a session interrupted during a test run completes with the uninterrupted session's folds, selections and test equity |
| `bounds` | LDG-2991 | Folds starting on the first sealed date run; a boundary on a date outside the sealed range refuses and names the range |
| `invariance11` | Cut 11 | `flat_test_state` over gapped folds completes; rerunning a finished session reopens its test runs without executing them (unchanged `run_telemetry` stamps); folds inside the range run |
| `reason11` | Cut 11 | Each Cut 11 group fails before the cut for its source-table reason: `ledgr_missing_bars`, a PARTIAL session with an INCOMPLETE test run, `ledgr_run_not_complete`, and the old range refusal |

## Modes

- `pre`: the Cut 10 groups fail and `invariance` passes (Cut 10 pre-cut record).
- `post10`: the Cut 10 groups and `invariance` pass (Cut 10 post record).
- `pre11`: the Cut 10 groups, `invariance`, `invariance11` and `reason11` pass;
  every Cut 11 group fails.
- `post`: every group except `reason11` passes.

`--against` compares every observable of the `inv_*` and `lfb017_*` arms with
an earlier record, except telemetry stamps and session IDs; a session ID
hashes the snapshot's generated `snapshot_id`, so it differs between records
(routed to the post-Cut-11 maintenance cut, macro plan 2026-10-08).

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
- **Reconstruction, gap (stale 2):** BBB at 20, 21 and 23 on days 2, 3 and 5.
  AAA 45 fills day 2 (cash 550), BBB 22 fills day 3 at 21 (cash 88). Day 4
  values BBB at its stale mark 21: 450 + 462 = 912. Day 5: 450 + 506 = 956.
- **Reconstruction, freeze (stale 1):** AAA 10 to 14, BBB's last bar is day 2
  at 22. From day 4 the held 22 BBB are frozen at 22: day 4 is
  39 * 13 + 484 = 991, day 5 is 41 * 14 + 484 = 1058.
- **Walk-forward:** weekdays of 2020 (first session Wednesday 2020-01-01),
  random-walk members, rolling two-month train and one-month test windows
  stepped monthly. Candidates that trade until the end of May leave every
  training window starting in June or later with constant equity and no
  finite Sharpe ratio.
- **Gapped carry:** the same windows stepped every two months, so the test
  windows 2020-03-02..04-01 and 2020-05-02..06-01 leave the 22 weekdays from
  2020-04-02 to 2020-05-01 unobserved. CCC delists on 2020-04-15, inside that
  gap.
- **Resume:** the strategy interrupts on 2020-05-12, inside fold 3's test
  window, when an option is set; the reference session runs on its own copy
  of the same data.

## Evidence

`evidence/pre_cut` is recorded from the clean LDG-2972 commit, product-identical
to `0c1fe2b`, and passes `--expect pre`. `evidence/after_ws20` passes
`--expect post10`. `evidence/pre_cut11` is recorded from the clean LDG-2977
commit and passes `--expect pre11 --against evidence/after_ws20/record.csv`.
`evidence/after_ws21` (commit `4fcbc3e`) passes `--expect post --against
evidence/pre_cut11/record.csv`. The Workstream 21 close review added the
`lfb019_stopped` arm, so the current pair is `evidence/pre_cut11_r2`
(recorded with the new runner against the pre-fix commit `8be6222`, passes
`--expect pre11 --against evidence/after_ws20/record.csv`) and
`evidence/after_ws21_r2` (commit `6567b73`, passes `--expect post --against
evidence/pre_cut11_r2/record.csv`).
