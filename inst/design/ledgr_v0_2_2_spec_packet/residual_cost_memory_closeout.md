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

The product tree stayed at accepted Workstream 52 commit `0ffaaa0f`. The
record scripts and this document are later commits with no change under
`R/`, `src/`, `DESCRIPTION` or `NAMESPACE`. Every current-run output was
`DONE` over 7,213 pulses with 8,798 fills and 4,870 closed trades. The
profile and telemetry arms have identical normalized fills, equity and trade
hashes.

### Current public-path profile

The R-profile run took 60.39 seconds. Native phase clocks account for 58.96
seconds (`t_pre` 9.69, `t_loop` 49.21, `t_post` 0.06), leaving 1.43 seconds,
or 2.4 percent, outside those phases. Windows `Rprof()` accumulated only
19.36 seconds while R was sampleable; time inside or waiting on native code
is therefore not assigned a fictional R function. The phase clocks, not the
sample total, are the wall-time reconciliation.

The every-pulse diagnostic is a separate 62.22-second arm. Its component
clocks overlap where `t_exec` summarizes lower-level fields, so they are not
summed. They locate the remaining costs:

| Cost owner | Current evidence | Share of run wall | Disposition |
| --- | ---: | ---: | --- |
| causal feature work | `t_feats` 15.07 s | 24.2% | No bounded WS53 candidate. WS4 owns recursive/strict history work; generic custom-function slicing stays a growth-shape input because H1 uses the built-in return definition. |
| availability context and accessor refresh | `t_ctx` 9.00 s | 14.5% | Routed to the already parked next-version context-surface retirement; changing the callback boundary here would be architecture, not a local optimization. |
| state preparation/persistence | `t_state` 5.00 s | 8.0% | No exact bounded candidate identified. The current per-pulse state is durability evidence and stays unchanged. |
| target normalization and planning | `t_target` 5.12 s | 8.2% | Routed with the typed execution / unified fold work; 4.96 s occurs on held pulses and is also scheduler evidence. |
| fill timing and resolution | `t_fill` 1.42 s | 2.3% | Below the five-percent share gate; rejected for this cut. |
| event/accounting application | `t_event` 1.03 s | 1.7% | Below the gate; the broader `t_exec` field overlaps target, fill, event and state and is not counted as an independent candidate. |
| canonical JSON | `canonical_json` 1.65 s in the R sample | 2.7% of wall | Below the five-percent share gate; unchanged as required. |
| DuckDB append boundary | `DBI::dbAppendTable` 3.55 s in the R sample | 5.9% of wall | The writer is already set-wise and buffered. No concrete duplicate representation or bounded exact candidate was found; retain and re-profile after execution-core unification. |
| fill-event payload | `ledgr_fill_event_payload` 0.23 s | 0.4% | Below the gate; rejected. |

The public post-run clocks are also below the gate individually: run info
0.81 seconds, fills 0.73, equity 0.03, trades 0.79, summary 1.09, printed
summary 1.78 and cold `ledgr_run_open()` 0.03. Recovery replay is not reached
by a completed H1 run and receives no invented clock; Workstream 54 retains
the registered interruption/resume case. The two-worker sweep medians below
cover the sweep phase. The accepted Cut 17 26-fold record remains the
walk-forward phase input; no new product candidate is inferred across those
different boundaries.

### Scheduler result and telemetry decision

Of 7,213 pulses, 6,868 are held pulses and 345 are monthly decision pulses.
On held pulses alone, context, strategy and target work totals 14.27 seconds,
22.9 percent of wall. This is deliberately a lower bound: it does not claim
that fills, settlement, valuation, state, diagnostics or commit can be
skipped. It clears the five-percent trigger, so the staged scheduler seed
advances to a Type 2 response. No scheduling semantics enter Cut 18.

Detailed telemetry remains unchanged. Source inspection finds one
session-local registry feeding the public `ledgr_backtest_bench()` table and
the registered benchmark/diagnostic runners, plus the compact durable
`run_telemetry` row consumed by run listings and continuity checks. The
detailed vectors are not a persisted public evidence format, while the
compact row is part of recovery and inspection. Removing or changing either
would mix two different roles and would require a contract decision. WS53
therefore retains both and records redesign only after the execution and
context unification changes their shape.

### One- and two-worker attribution

The medians below come from three fresh processes per arm. `base_la` in the
two-worker rows is the no-dividend snapshot with the installed package; the
historical label is kept only because the accepted runner reserves that arm.

| Snapshot / load mode | Workers | Elapsed | Parent private peak | Parent + daemons private peak |
| --- | ---: | ---: | ---: | ---: |
| v003, `load_all()` | 1 | 61.97 s | 1,864.5 MiB | 1,864.5 MiB |
| v003, installed | 1 | 56.66 s | 2,145.4 MiB | 2,145.4 MiB |
| v004 dividends, `load_all()` | 1 | 73.34 s | 1,904.7 MiB | 1,904.7 MiB |
| v004 dividends, installed | 1 | 68.53 s | 2,602.8 MiB | 2,602.8 MiB |
| v003, `load_all()` | 2 | 60.55 s | 2,305.4 MiB | 4,071.6 MiB |
| v003, installed | 2 | 57.80 s | 2,211.7 MiB | 3,982.9 MiB |
| v004 dividends, `load_all()` | 2 | 66.81 s | 2,538.6 MiB | 4,469.1 MiB |
| v004 dividends, installed | 2 | 61.85 s | 2,547.2 MiB | 4,223.0 MiB |

The dividend increment is in the engine phase, not initial setup: under
`load_all()` the one-worker engine peak rises only 40.2 MiB, while installed
mode rises 457.5 MiB; the two-worker tree median rises 397.5 MiB under
`load_all()` and 240.1 MiB installed. The opposite load-mode memory ordering
between shapes is reproducible but does not identify a removable package
representation, so no product change is authorized from it.

The public staged-payload census gives the narrower explanation. Both builds
stage the same 476,122,240-byte causal-history substrate. Corporate-action
rows grow from 5,488 bytes in v003 to 18,177,064 bytes in v004; the complete
staged invariant grows from 476,486,520 to 494,658,440 bytes. The remaining
whole-process increment arises after staging while each process builds and
uses its own execution plan. That is intentional process isolation, not a
second in-process copy that WS53 can safely delete. Shared representation is
therefore a later backend/design question.

### Four- and eight-worker trigger arms

These are single diagnostic arms, not medians and not support claims. The
corrected sampler interval is 0.203 seconds in both:

| Workers | Outer elapsed | Parent private peak | Parent + daemons private peak |
| ---: | ---: | ---: | ---: |
| 4 | 67.08 s | 2,734.3 MiB | 6,085.4 MiB |
| 8 | 71.01 s | 2,978.6 MiB | 8,948.7 MiB |

The eight-worker peak is 8.74 GiB, below the accepted 12 GiB trigger.
Shared-memory transport stays deferred and eight workers remain unadvertised.
More workers do not improve this two-candidate workload. Supported guidance
remains one worker for memory efficiency and at most two when the user has
measured enough independent candidate work to justify the extra memory.

### Reproduction and data boundary

`profile_h1_current.R`, `worker_scaling_h1.R` and their runners reproduce the
records. `summarize_ws53.R` derives the compact medians and phase peaks;
`check_ws53.R` checks the complete arm set, process exits, sampler intervals,
native-output equality, phase reconciliation, canonical-JSON gate, scheduler
trigger, worker equality, the 12 GiB trigger and absence of local paths from
the text evidence. It prints `WS53_CHECK_OK`.

The committed record contains 94 aggregate or compressed process-sample
files totalling about 0.4 MB. No vendor row, instrument identifier or private
path enters it. After the aggregates were checked, 12.49 GiB of disposable
run-store copies were deleted; source snapshots were untouched.
