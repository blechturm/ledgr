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

The first descriptive record at `c8401ecc` did not satisfy that ordering: most
arms predated the committed acquisition program, the repeated arms retained
only a partial native oracle, and the checker trusted derived summaries. It is
rejected and overwritten, not used below. The final acquisition programs and
raw-to-summary checker were frozen through `1cab9637` before the definitive
rerun. All 24 repeated arms, both single-run diagnostics and the 2-, 4- and
8-worker arms were then rerun. The repeated files name `1cab9637` as their one
acquisition commit and `0ffaaa0f` as the unchanged product commit.

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
`DONE` over 7,213 pulses with 8,798 fills. The dividend build has 4,870
closed trades and the no-dividend build has 4,882. Within each build, load
mode and repetition have identical status, counts, final equity and normalized
fills, equity and trades hashes. The profile and telemetry arms also have
identical normalized output hashes.

### Current public-path profile

The R-profile run took 60.99 seconds. Native phase clocks account for 59.62
seconds (`t_pre` 9.66, `t_loop` 49.91, `t_post` 0.05), leaving 1.37 seconds,
or 2.2 percent, outside those phases. Windows `Rprof()` accumulated only
19.53 seconds while R was sampleable; time inside or waiting on native code
is therefore not assigned a fictional R function. The phase clocks, not the
sample total, are the wall-time reconciliation.

The every-pulse diagnostic is a separate 62.65-second arm. Its component
clocks overlap where `t_exec` summarizes lower-level fields, so they are not
summed. They locate the remaining costs:

| Cost owner | Current evidence | Share of run wall | Disposition |
| --- | ---: | ---: | --- |
| causal feature work | `t_feats` 14.95 s | 23.9% | No bounded WS53 candidate. WS4 owns recursive/strict history work; generic custom-function slicing stays a growth-shape input because H1 uses the built-in return definition. |
| availability context and accessor refresh | `t_ctx` 9.16 s | 14.6% | Routed to the already parked next-version context-surface retirement; changing the callback boundary here would be architecture, not a local optimization. |
| state preparation/persistence | `t_state` 5.08 s | 8.1% | No exact bounded candidate identified. The current per-pulse state is durability evidence and stays unchanged. |
| target normalization and planning | `t_target` 4.97 s | 7.9% | Routed with the typed execution / unified fold work; 4.64 s occurs on held pulses and is also scheduler evidence. |
| fill timing and resolution | `t_fill` 1.53 s | 2.4% | Below the five-percent share gate; rejected for this cut. |
| event/accounting application | `t_event` 0.73 s | 1.2% | Below the gate; the broader `t_exec` field overlaps target, fill, event and state and is not counted as an independent candidate. |
| canonical JSON | `canonical_json` 1.64 s in the R sample | 2.7% of wall | Below the five-percent share gate; unchanged as required. |
| DuckDB append boundary | `DBI::dbAppendTable` 3.58 s in the R sample | 5.9% of wall | The writer is already set-wise and buffered. No concrete duplicate representation or bounded exact candidate was found; retain and re-profile after execution-core unification. |
| fill-event payload | `ledgr_fill_event_payload` 0.22 s | 0.4% | Below the gate; rejected. |

The public post-run clocks are also below the gate individually: run info
0.84 seconds, fills 0.71, equity 0.07, trades 0.84, summary 0.94, printed
summary 1.76 and cold `ledgr_run_open()` 0.03. Recovery replay is not reached
by a completed H1 run and receives no invented clock; Workstream 54 retains
the registered interruption/resume case. The two-worker sweep medians below
cover the sweep phase. The accepted Cut 17 26-fold record remains the
walk-forward phase input; no new product candidate is inferred across those
different boundaries.

### Scheduler result and telemetry decision

Of 7,213 pulses, 6,868 are held pulses and 345 are monthly decision pulses.
On held pulses alone, context, strategy and target work totals 14.17 seconds,
22.6 percent of wall. This is deliberately a lower bound: it does not claim
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
| v003, `load_all()` | 1 | 63.99 s | 1,729.9 MiB | 1,729.9 MiB |
| v003, installed | 1 | 58.42 s | 1,766.6 MiB | 1,766.6 MiB |
| v004 dividends, `load_all()` | 1 | 75.36 s | 1,938.5 MiB | 1,938.5 MiB |
| v004 dividends, installed | 1 | 69.65 s | 1,810.3 MiB | 1,810.3 MiB |
| v003, `load_all()` | 2 | 59.70 s | 2,280.1 MiB | 3,648.9 MiB |
| v003, installed | 2 | 58.53 s | 2,223.0 MiB | 3,991.9 MiB |
| v004 dividends, `load_all()` | 2 | 67.05 s | 2,534.3 MiB | 4,457.8 MiB |
| v004 dividends, installed | 2 | 64.04 s | 2,454.3 MiB | 4,384.5 MiB |

The dividend increment is in the engine phase, not initial setup: under
`load_all()` the one-worker engine peak rises 208.6 MiB, while installed mode
rises 43.7 MiB; the two-worker tree median rises 809.0 MiB under `load_all()`
and 392.7 MiB installed. The opposite load-mode memory ordering
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
| 4 | 67.42 s | 2,986.1 MiB | 6,083.2 MiB |
| 8 | 71.30 s | 2,985.0 MiB | 8,916.7 MiB |

The eight-worker peak is 8.71 GiB, below the accepted 12 GiB trigger.
Shared-memory transport stays deferred and eight workers remain unadvertised.
More workers do not improve this two-candidate workload. Supported guidance
remains one worker for memory efficiency and at most two when the user has
measured enough independent candidate work to justify the extra memory.

### Reproduction and data boundary

`profile_h1_current.R`, `attribution_h1.R`, `worker_scaling_h1.R` and their
runners reproduce the records. `summarize_ws53.R` derives the compact medians
and phase peaks; `check_ws53.R` checks the complete arm set, process exits,
sampler intervals, native-output equality, raw-to-summary derivation, phase
reconciliation, canonical-JSON gate, scheduler trigger, worker equality, the
12 GiB trigger and absence of local paths from the text evidence. Its
`--self-test` corrupts a raw sample, an arm summary and a phase summary and
requires all three to fail. It prints `WS53_CHECK_OK`.

The committed record contains 100 aggregate or compressed process-sample
files totalling 425,355 bytes (0.406 MiB). No vendor row, instrument
identifier or private path enters it. After the aggregates were checked,
16.27 GiB of disposable correction run-store copies were deleted; source
snapshots were untouched.
