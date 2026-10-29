# WS1 timing protocol (v0.2.3 cut 1, LDG-3127)

Status: frozen before any handler change. Protocol version `ws1-timing-1`.
Authority: `inst/design/ledgr_v0_2_3_spec_packet/tickets.yml`, LDG-3127 and
LDG-3132. The executable statement is `matrix.R`, `measure.R`, `runner.R` and
`check.R` in this directory; this page explains them. If the two disagree, the
code binds and this page is wrong.

## What is measured

Every workload runs through both public paths:

- `run`: `ledgr_run()` once per sweep candidate, each handle closed (the
  persistent handler in `audit_log` mode);
- `sweep`: one `ledgr_sweep()` over the same grid with one worker (the memory
  handler), retaining completed returns and closed trades.

| Workload | Source | Bars | Candidates | Expected status |
| --- | --- | --- | --- | --- |
| dense_cost | A0 `fixtures.R` | 2 x 8 | 3 | DONE |
| dense_risk_features | A0 `fixtures.R` | 2 x 8 | 2 | DONE |
| dense_dividend_state | A0 `fixtures.R` | 1 x 4 | 2 | DONE |
| avail_terminal_resume | A0 `fixtures.R` | gapped, 6 sessions | 1 | DONE |
| avail_acquisition | A0 `fixtures.R` | 2 x 3 | 2 | DONE |
| avail_incomplete | A0 `fixtures.R` | 1 x 3 of 4 sessions | 2 | INCOMPLETE |
| walk_forward | A0 `fixtures.R` | gapped, 10 sessions | 2 | DONE |
| timing_scale | A0 `timing.R` | 20 x 252 | 2 | DONE |
| dense_scale_50x1260 | `matrix.R` | 50 x 1260 | 2 | DONE |

The first eight rows are A0's timing workloads (A0's `failures` workload
ends runs by design and was never timed). The fixtures are A0's code: the
runner sources A0 `fixtures.R` and extracts `a0_fx_timing_scale` from A0
`timing.R` and `a0_retain` from A0 `lib.R` without running those scripts.

**Larger workload.** `dense_scale_50x1260` has 50 instruments x 1,260
sessions (63,000 bars, deterministic prices, no RNG), SMA(20), a 5 bps
spread, opening cash 1e7 and a vectorised SMA strategy with two candidates
(quantity 10 and 20). It produces about 6,200 fills per candidate, so event,
fill and equity output dominate rather than strategy code or fixed per-call
cost. It was chosen over larger shapes because one measurement process stays
near 20 seconds, so eight pairs of the whole matrix finish in about half an
hour (a runner smoke run measured 4 to 5 seconds per path on the base tree). The 20 x 252 workload remains the A0 comparison point for H6.

Seeds are each fixture's `seed` (2591, 77, 11, 169, 54, 31, 24, 7, 7);
each committed run uses the candidate's `execution_seed` from the sweep. The
expected status is per candidate, in grid row order, for both paths.

## One measurement

One measurement is one fresh `Rscript --no-init-file measure.R` process for
one arm, one workload and one path. In that process, in this order:

1. host probe: the active power-plan GUID and the process's own affinity;
2. `library(ledgr, lib.loc = <arm library>)`, refusing any other copy;
3. untimed preparation, identical for both arms and both paths: the fixture's
   snapshot in a fresh DuckDB file, one sweep (which also supplies each
   candidate's params and execution seed), one committed run per candidate,
   then `gc()`;
4. the timed execution of the requested path, once;
5. untimed: the timed runs' statuses and trade counts (`ledgr_run_list()`),
   or the timed sweep's `status` and `n_trades`.

**Clock endpoints.** `as.numeric(Sys.time())` immediately before the first
`ledgr_run()` (run path) or the `ledgr_sweep()` call (sweep path), and
immediately after the last `close()` or the `ledgr_sweep()` return. On
Windows `Sys.time()` resolves well below a millisecond, while
`proc.time()[["elapsed"]]` ticks in 10 ms steps (A0's clock), which is 5% of
the smallest cells; the runner smoke run showed the 10 ms steps.
Conditions are muffled with `suppressWarnings()` inside both, as in A0.

**Clock adjustments.** `Sys.time()` is the adjustable civil clock, not a
monotonic timer, and its resolution does not make 3% repeatable. A time-sync
step backwards inside a timed section yields non-positive seconds, which the
checker rejects as an invalid row; a step that leaves a positive value is
indistinguishable from scheduler noise and falls under the dispositions in
Records. Neither case is retried: the record is kept, and the affected row is
named in the disposition.

**Retained result surface.** Run path: each candidate's persisted run in the
snapshot's DuckDB store as `ledgr_run()` writes it; no reader is called. Sweep
path: the returned in-memory sweep object with completed returns and closed
trades; it is not saved.

**Warm-snapshot policy.** The timed execution starts from a snapshot that
the preparation step has already opened and executed against, in both arms.

## Pairs, arms and host

- Each arm is installed from a git commit: `git archive` of the commit,
  then `R CMD INSTALL --no-docs --no-html` into the arm's own library. The
  record names both commits, their tree hashes and their product digest (the
  tree hashes of `R/`, `src/`, `DESCRIPTION` and `NAMESPACE`).
- Exactly eight pairs. The cut's minimum is five; an even count lets each
  arm run first in exactly half of the pairs (a one-pair smoke run on one
  tree showed the second process of a cell about 5% slower on the run path),
  and more pairs make each median less sensitive to one disturbed process.
  In pair k every cell runs once per arm: base first
  when k is odd, candidate first when k is even. Cells run in matrix order,
  so the two arms of a cell are adjacent in time.
- The runner refuses to start unless the power plan is High performance
  (`8c5e7fda-...`) and its own affinity is `0xFFFF`. Launch it from a
  PowerShell whose affinity was pinned first, so every child inherits it.
  Every measurement records its own plan and affinity.
- Close background applications first; no other R session.
- No automatic retries. A failed process is a recorded row that fails the
  checker; a new record needs a new label (records are never overwritten).

## The statistic and the checker

For each workload and path cell: median candidate seconds divided by median
base seconds, over the raw full-precision seconds. `check.R` passes only if
every cell's ratio is at most 1.03, or that cell has an explicit linked
maintainer exception (`--exceptions=<csv>` with `workload,path,link`). Before
any ratio counts, it rejects:

- a missing, duplicate or unexpected row (pair x cell x arm), including an
  empty record;
- non-finite or non-positive seconds;
- a failed, skipped or crashed execution;
- a status or candidate count other than declared;
- a row or runner not on the registered host settings;
- a missing, non-finite or negative trade count, or different trade counts
  within a cell (the arms did different work);
- a smoke record, an unfinished record, a pair count other than eight, or a changed
  protocol file (line-ending-insensitive SHA-256 of `matrix.R`, `measure.R`,
  `runner.R`, `check.R`, A0 `fixtures.R`, A0 `timing.R`, and the `a0_retain`
  definition);
- malformed arm identities (commit and tree hashes, product digest,
  library), missing host or toolchain fields, a row whose ledgr came from
  the other arm's library, or arms that did not alternate as declared.

A checker PASS establishes the record's internal consistency against the
frozen matrix; it does not authenticate that `runner.R` produced the record.
Provenance is the committed record together with its meta.csv.

`check_demo.R` shows the checker failing for each of these on a synthetic
record, including the two the cut requires (a missing row, a ratio of 1.031),
and passing the clean record and an excepted cell.

H6 is reported per workload and arm as committed-run median over sweep
median.

## Records

- **Base record (LDG-3127).** An A/A run: base and candidate are the same
  base commit, installed twice, eight pairs. It gives the base H6 gap per
  workload and an observed repeatability check on this host before any
  handler change; it is not a statistical bound on future noise. Run it
  only on the maintainer's go-ahead.
- **Gate record (LDG-3132).** The same runner and checker, unchanged, with
  base = the base commit and candidate = the final candidate commit.

**If the A/A base record has an otherwise valid cell above 1.03**
(fixed before the first measurement):

1. Keep the record and the checker failure. Do not retry until green,
   select pairs, add pairs, round, or change the threshold.
2. Keep record validity separate from the ratio gate. An A/A miss shows
   variability, not a product regression; LDG-3127 needs a valid base record
   and H6, not an A/A ratio pass. Keep both arms' H6 and all raw rows.
3. Record the affected cells and obtain the maintainer's disposition before
   any product edit. The final paired gate stays unchanged: every over-bound
   final candidate cell still needs its own linked exception, and a baseline
   disposition never silently exempts a cell later.
4. If noise needs a different protocol, the change needs the maintainer's
   disposition before product edits, a new protocol version (frozen and
   committed), and a new baseline under it. The first attempt is preserved.

A record that fails for a validity reason (missing row, failed process,
unpinned host) is also kept and named in the disposition; a new record
needs a new label, never an overwrite.

Records live in `records/<label>/` (`meta.csv`, `raw.csv`, and `logs/` for
failed processes only) and are committed as cut release evidence (cut
decision 7).

Command:

```powershell
[System.Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity = [IntPtr]0xFFFF
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/v0_2_3_ws1_timing/runner.R --base=<commit> --candidate=<commit> --label=<label>
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/v0_2_3_ws1_timing/check.R --record=dev/bench/v0_2_3_ws1_timing/records/<label>
```
