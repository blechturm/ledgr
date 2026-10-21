# Cut 16 Workstream 44 phase B closeout: history resource proof, real-data proof and teaching

Role: record; Workstream 44 phase B evidence (LDG-3069, LDG-3070 and the
teaching part of LDG-3071).
Authority: non-binding. `tickets.yml` owns status and `contracts.md` owns
behaviour.
Status: in progress. LDG-3069 is complete (this section). LDG-3070 and the
LDG-3071 teaching sections follow as their evidence is committed.

BASE is the integration head `67f98d6b` (`integrate/cut15-v0.2.2`, phase A
accepted and merged). Branch `ws44/history-proof`. Real-data work is in
`ledgr-research` branch `claude/history-proof-v0.2.2` (from
`claude/history-fact-census-v0.2.2`), `experiments/history-wave-h6/`
(LDG-3069) and `experiments/history-wave-full-proof/` (LDG-3070).

## What was proven, in plain terms

Written when phase B is complete.

## LDG-3069: history resource and worker bounds

The registered H1 workload (one full-history run and one two-candidate,
two-worker sweep on the 1998-2026 Sharadar projection) was measured on a
fresh baseline arm built from `99a3b067` and on the integration head
`67f98d6b`, three alternating repeats each, every worker process and daemon
sampled every 0.203 to 0.204 seconds. Both arms built their own snapshot
from the same canonical build; the baseline hash equals the H1/WS39 hash and
the candidate hash equals the LDG-3080 hash. Record and checker:
`ledgr-research` `experiments/history-wave-h6/` (README, `check_h6.R`).

| gate (median of three) | baseline MiB | candidate MiB | ratio | bound | result |
| --- | ---: | ---: | ---: | ---: | --- |
| single-run parent working set | 2,918.0 | 1,745.8 | 0.598 | 1.10 | pass |
| single-run parent private commit | 2,942.2 | 1,866.4 | 0.634 | 1.10 | pass |
| two-worker parent working set | 9,859.3 | 1,966.6 | 0.199 | 1.10 | pass |
| two-worker parent private commit | 9,976.8 | 2,292.1 | 0.230 | 1.10 | pass |
| two-worker parent-plus-daemon private commit | 14,872.6 | 3,731.0 | 0.251 | 1.10 | pass |
| summed working set (lower bound, disclosed) | 14,364.7 | 3,624.6 | 0.252 | - | - |

Both arms produce the same economic results on this workload: identical
fills and equity on the run (8,798 fills, final equity 14,153,680.996) and
identical final equity, trade count and execution seed for both sweep
candidates. Their snapshot, config and feature identities differ as rule 4
requires.

Other measurements the ticket names (all in the research README):

- **Preparation and fold peaks.** The candidate's single-run peak is in
  preparation (1,746 MiB median working set) and its fold peak is lower
  (1,567); the baseline peaks in the fold (2,918). In the baseline sweep the
  parent holds about 9.9 GB while serializing full candidate tasks and each
  daemon about 4.2 GB; in the candidate each daemon holds one staged copy and
  peaks at about 1.1 GB, the staged invariant included.
- **Live substrate and counts.** 387.7 MiB (`object.size`), 379.9 MiB
  serialized, 2.5 s to build; 2 workers, 1,166 instruments, 7,213 pulses,
  5,481,906 bars; facts and segments equal the LDG-3080 census (lifetime 829
  facts in 1,995 segments, membership 967,091 guard facts in 677,446
  segments, no trading-status facts, every guard under its limit, highest
  share 0.25).
- **Transport parity.** Sequential, current-dispatch and staged-dispatch
  arms agree exactly on candidate ID, status, final equity, trades,
  execution seed and the reproduction-key, snapshot, strategy and
  feature-union hashes. This is LTB-0295 (LDG-3061's transport oracle,
  reused) on the real workload; `check_h6.R` fails on any difference.
- **Shared-memory trigger.** `(2 - 1) * 476,486,520 B / 3,731.0 MiB =
  0.1218`. This is **at or above the 10 percent threshold**, so shared
  memory reopens as a question under v12 Section 7 (E6). It is routed to the
  maintainer, not implemented (see Routed).
- **Decision trace reads.** 3,636,401 trace rows. `ledgr_results(bt,
  "diagnostics")` takes 1.1 s at a 697 MiB R heap peak; `ledgr_run_explain()`
  of one instrument takes 9.3 s at a 2.6 GB R heap peak because it reads the
  whole diagnostics and availability tables and filters them in R. Both are
  unchanged from the baseline. The explain cost is routed to WS8; the trace
  is not weakened.
- **Caller RNG.** `ledgr_sweep(seed = NULL, workers = 2)` advances the
  caller's RNG on both arms; starting and stopping `mirai` daemons alone does
  the same, a seeded sweep restores it and one worker leaves it untouched. It
  is a pre-existing worker start and stop effect, not history staging;
  whether ledgr should restore the caller's RNG is routed.
- **Walk-forward restaging.** Three rolling folds with two workers start six
  daemons and stage about 444 MiB on each daemon per fold; staging takes
  0.8 s of parent time per fold and the synchronous restart about 0.4 s.
  Results equal the one-worker run; two workers took 74.5 s against 71.9 s,
  so at this fold size they do not pay for themselves. The baseline has no
  walk-forward workers, so there is no paired baseline.
- **Eager history evidence.** A full-lookback wide read at the last session
  (503 instruments by 7,213 sessions) is 243.4 MiB for 27.7 MiB of values,
  8.79 times, in about 1 s; at lookback 252 it is 9.2 MiB and 0.02 s. This
  is the input for the lazy-evidence decision; nothing is implemented.
- **Vintage feature evidence (close review 44a N1).** On the real data,
  which has no late-known fact, `ledgr_history_vintage_planes()` takes about
  5 percent of a full-lookback feature read; its per-instrument epoch loop
  never runs, so the +14 percent the review measured with 100 late-fact
  instruments does not arise at this density.
- **Timing (disclosed, not gated).** The candidate single run is slower:
  native elapsed 52.3 s against 42.4 s (preparation 10.0 against 6.2 s, fold
  41.2 against 35.1 s). The two-worker sweep is faster: 50.8 against
  69.8 s. Routed to WS8.

### Seven-shape walk

LDG-3069 changes no product code. The walk covers the functions Cut 16
changed on preparation, fold, transport and reader paths, and asks whether
the H1 benchmark hides a scale-growing collection. The census
(`dev/bench/v0_2_2_history_proof/scripts/loop_census.R`, output
`evidence/ldg3069/loop_census.csv`) parses the eighteen history, provider,
runner, fold, sweep, walk-forward, precompute and projection files and
lists every R-level iteration inside a function whose lines changed between
`99a3b067` and `67f98d6b`: 191 iterations in 79 functions, 122 of them on
changed lines. Most iterate a fixed small set (the five bar fields, fact
families, feature definitions, catalogue rows, instrument blocks of 64 or 128
rows). The ones that grow with the data, against the seven shapes and the
H1 profile (`prof_cand__prof_total.csv`):

| iteration | grows with | H1 exercises it | assessment |
| --- | --- | --- | --- |
| feature series, `ledgr_history_compute_feature_series()` | instruments x lagged knowledge ranges x definitions | yes: 1,166 x 1 x 1; 4.9 s of 32.6 s profiled | per-instrument loop with vectorised axis work and index reads (no shape); the lagged-range factor is the WS43 F5 cost, zero at real density (LDG-3080, LDG-3070) |
| scalar `fn` features, `ledgr_history_feature_segment()` | ready cells (instruments x pulses) | no (built-ins use `series_fn`) | the `fn(window)` contract calls the function once per window, as before the cut; `series_fn` is the vectorised path. Not a hidden regression |
| generic fact compiler, `ledgr_history_fact_segments_by_instrument()` | instruments with facts x knowledge epochs x breaks | partly: 78 two-row lifetime instruments; no trading-status facts | per instrument from its own boundaries; bounded by the segment guard; 0.43 s at H1 (LDG-3080, F05 not material). Status families are hidden by the data |
| membership counter, `ledgr_history_membership_fact_counts()` | headers x touched instruments | yes: 580 headers; 0.04 s | linear advancement (WS41); no shape |
| status lineage and runtime conflicts (`availability-facts.R`) | status facts and boundaries | no | hidden by the data; WS45 (LDG-3073) owns their 100,000-row linearity |
| late-epoch overlays in reads (`ledgr_history_cutoff_planes()`, `ledgr_history_vintage_planes()`) | late-fact instruments x epochs | no (no late facts) | memoised overlays, no recomputation per read; the close review measured +14 percent at 100 late-fact instruments |
| segment materialise and query | requested instruments x their segments | yes, per feature input and mask block | vectorised along the axis; segments bounded by the guard |
| fold pulse loop and per-pulse bar frame (`ledgr_history_bar_packet_frame()`) | pulses (one frame of all instruments per pulse) | yes: 1.9 s | one frame per pulse is the `ctx$bars` contract, not shape 1 (no per-element frames) |
| sweep task compaction, `ledgr_sweep_stage_history_tasks()` | candidates | yes: 2 | per-candidate field removal only; the invariant is built once (LTB-0294) |
| walk-forward folds | folds x workers | yes: 3 x 2 | daemons restart and the invariant is restaged per fold (measured above) |
| dense runner and precompute loops (`backtest-runner.R`, `precompute-features.R`) | instruments x definitions | no (availability run) | frozen dense path, unchanged in shape; leaves with execution-core consolidation |

No new instance of the seven shapes is on the measured path. The
collections the H1 benchmark hides are late-known facts, trading-status
facts, scalar-`fn` features, more than two workers and many folds; each has
the owner or note above. The candidate single run is 23 percent slower than
the baseline (preparation and per-pulse decision work, from the profile);
that is a timing observation routed to WS8, not a shape.

Contracts: Release Gates and Store And Codebase Gates are rewritten in the
present tense and their v12 pending links removed (LDG-3069 is their
receiver owner).

## LDG-3070: full-history real-data proof

Follows.

## LDG-3071: teaching (ticket stays open)

Follows.
