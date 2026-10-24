# Residual cost and memory decisions

Workstream 53, Cut 18. This is an internal release record, not a public speed
claim. It uses the accepted H1 changing-membership workload and native ledgr
results. Private snapshot paths, identifiers and rows remain outside the
package; committed evidence contains aggregate counts, timings, hashes and
process-memory samples only.

## Measurement plan fixed before the current-run profile

The ticket already preregistered the semantic and materiality gates. This
section fixes the concrete current-tree measurement before the profile and
worker-count arms run.

- Product commit: `0ffaaa0f` (accepted Workstream 52). Later record-only or
  test-only commits may be used only when their product tree is identical.
- Workload: the accepted H1 monthly momentum strategy, 1,166 instruments,
  7,213 expected sessions and the changing point-in-time S&P 500 membership
  universe. The current dividend and no-dividend snapshots retain their
  native rule-4 hashes outside this document.
- Public entry points: `ledgr_run()` for the current run and
  `ledgr_sweep()` for worker measurements. Profiling instrumentation changes
  only the telemetry stride or activates `Rprof`; it does not replace either
  entry point.
- Clock boundary: fresh `Rscript` process launch through final native result
  reads for process-tree records; `ledgr_run()` call only for the R profile.
  Setup, preparation, fold, result reads and outer wall reconcile separately.
- Repetitions: three fresh-process repeats for each one-worker
  load-mode-by-dividend arm and each two-worker arm. The statistic is the
  median. Four- and eight-worker dividend arms run once each because their
  purpose is the accepted 12 GiB architectural trigger, not a stable median.
- Sampler: parent and descendant working set and private commit at a target
  interval of 0.2 seconds. The R profile uses a 5 ms interval. Detailed
  telemetry uses every pulse and is a separate diagnostic run so its timing
  overhead does not enter the ordinary wall clock.
- Host: Windows 11, R 4.6.1, High performance power plan, affinity `0xFFFF`.
  A run with material foreign R-process CPU is retried; otherwise host load is
  disclosed rather than silently discarded.
- Retry rule: infrastructure or input failure may be corrected and rerun;
  a successful timing arm is not retried merely for being slow. The
  profile-to-phase totals must reconcile within ten percent of the measured
  run call. Any larger residual is named.
- Equality oracle: status, pulse count, fill/trade counts, final equity and
  stable fills/equity/trades hashes for runs; candidate status, final equity
  and execution seed for sweeps. No research-side replay is an oracle.

## Gates and dispositions

A cost must be at least five percent of current public-path elapsed time and a
bounded candidate must improve that path by at least five percent before a
product change is eligible. Every candidate also needs exact native-output
parity, failure atomicity, a failure-sensitive detector and the seven-shape
walk. Profiling alone changes no product code.

The held-pulse record reports the measured context, strategy and target work
on non-decision pulses. That is a lower bound on potential scheduler value,
not authority to remove decision trace, valuation, settlement or commit work.
At or above five percent the result returns to the scheduler RFC as Type 2;
no scheduler semantics land here.

Telemetry is inventoried from the source. A public or semantic telemetry
change likewise returns to Type 2. Canonical JSON remains unchanged unless
its current public-path share clears five percent; the prior 3.4 percent is
input only.

The memory record first seeks one concrete duplicate representation. If none
is shown, no speculative storage mechanism is added. An eight-worker
parent-plus-daemon private peak above 12 GiB routes shared memory to later
design; at or below it shared memory stays deferred. Eight workers are not
advertised as supported in either case.

## Results

Pending measurement.
