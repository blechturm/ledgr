# Cut 16 Workstream 44 phase B closeout: history resource proof, real-data proof and teaching

Role: record; Workstream 44 phase B evidence (LDG-3069, LDG-3070 and the
teaching part of LDG-3071).
Authority: non-binding. `tickets.yml` owns status and `contracts.md` owns
behaviour.
Status: LDG-3069 and LDG-3070 are complete. LDG-3071 stays `open`: its
teaching part is done here, and its decision-reconciliation table and v12
as-implemented appendix wait for Workstream 45 and close with the cut.
Workstream 44 stays open.

BASE is the integration head `67f98d6b` (`integrate/cut15-v0.2.2`, phase A
accepted and merged). Branch `ws44/history-proof`: LDG-3069 `d1b7ede7`,
LDG-3070 `18d915b5`, LDG-3071 teaching `ea971d2e` and `59feeb0e`, this
record's final state after them. Real-data work is in `ledgr-research`
branch `claude/history-proof-v0.2.2` (from
`claude/history-fact-census-v0.2.2`, not pushed):
`experiments/history-wave-h6/` (LDG-3069; `67d56afd`, `ccbf76a8`, README
correction `65c379d`) and `experiments/history-wave-full-proof/` (LDG-3070;
`b37d2044`, `a6e63b7f`). The measured source copies are detached
worktrees of `99a3b067` and `67f98d6b`, each compiled once before any
measured run.

## What was proven, in plain terms

Proven, by measurement on the real Sharadar data (1,166 instruments, 7,213
sessions, 1998-2026):

- **Memory.** The history-enabled ledgr uses much less memory than the
  pre-history baseline on the registered workload, not more: about 60
  percent for a single run and 20 to 25 percent for a two-worker sweep. All
  three exact 1.10 gates pass with wide margins. Both versions produce the
  same trades and the same final equity on this workload.
- **Parallel transport.** Running the sweep sequentially, with the old
  full-payload dispatch or with the new staged dispatch gives identical
  results on real data.
- **Full history runs.** A strategy that reads causal history every month
  runs over the full 1998-2026 span on both the changing S&P membership and
  the full instrument set without any history-related stop; the default
  segment guard accepts the reference build; every count and identity
  reconciles to the earlier H1, WS39 and LDG-3080 records; a fresh rerun
  reproduces every counted result.
- **Teaching.** One executed article now teaches history from a
  hello-world run through a full history-to-weights-to-targets estimate,
  and the contract carries no pending history link.

Not proven, or found:

- **Shared memory comes back as a question.** The staged copy of the history
  data on each worker is large enough (12.2 percent of the sweep's summed
  parent-plus-daemon private commit, against a 10 percent trigger) that the
  accepted design says to reconsider shared memory. Nothing was built; it is routed to the maintainer.
- **The single run is slower.** The history-enabled run takes 23 percent
  longer than the baseline (52 against 42 seconds); the two-worker sweep is
  27 percent faster. Time was not gated; routed to WS8.
- **Explaining one instrument is expensive** (9 seconds, 2.6 GB), unchanged
  by the history work; routed to WS8.
- **Late-known and trading-status facts are absent from the real data**
  (adapter v003 sets knowledge equal to effective time and emits no status
  facts), so their cost on real data could not be measured; it was measured
  only on synthetic fixtures earlier. Two workers do not pay for themselves
  on small walk-forward folds.
- Not run here, by instruction: the fast, review and heavy profiles and the
  independent close review. LDG-3071 stays open for the decision
  reconciliation after Workstream 45.

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

**Extended census (Correction 1, close review 44b F2).** The first census
read eighteen hand-picked files, so it did not cover every changed function.
The script now takes its file list from `git diff --name-only 99a3b067
67f98d6b -- R/` (all 56 changed R files): 281 iterations in 114 changed
functions across the 35 files that have one, 139 on changed lines
(`evidence/ldg3069/loop_census.csv`, replaced). The files the first census
missed add 17 iterations on changed lines; none is a seven-shape instance:

| file:line | function | iterates | assessment |
| --- | --- | --- | --- |
| `availability-economics.R:100` | `ledgr_availability_valuation_state()` | session columns advanced since the last pulse (one per pulse in a run) | each step reads one close column and writes the instruments' last close by mask; linear in sessions x instruments, the read itself. Not per-element writes (shape 7); the changed lines are its data-start comment |
| `availability-policy.R:276` | `ledgr_availability_validate_features()` | feature definitions | fixed small set |
| `fold-event-buffer.R:134` | `ledgr_opening_position_event_rows()` | opening positions, once per run or carried window | bounded by instruments, once per window, not per pulse |
| `indicator-ttr.R:314` | `ledgr_ttr_declaration_args()` | declaration arguments | fixed small set |
| `indicator-ttr.R:372, 378, 381` | `ledgr_ttr_catalogue_variant()` | catalogue neutral arguments and variants | fixed catalogue |
| `indicator.R:333` | `ledgr_feature_indicator_index()` | feature definitions | fixed small set |
| `lot-accounting.R:183` | `ledgr_lot_state_from_opening()` | opening lots, once per carried window | bounded by open lots, once per window |
| `strategy-preflight.R:518, 571, 598, 631` | `ledgr_strategy_private_context_access()`, `ledgr_strategy_named_symbols()` | nodes of the strategy's source | grows with the strategy's code, not with data; once per preflight |
| `walk-forward-folds.R:429` | `ledgr_walk_forward_offset()` | the step's period terms | fixed small set |
| `walk-forward-folds.R:828, 833, 837` | `ledgr_walk_forward_refuse_noncontiguous_carry()` | folds | one pass over the fold list |

The thirteen the review listed are the ones above outside
`strategy-preflight.R`; the four preflight iterations are added because the
census now reads every changed file.

Contracts: Release Gates and Store And Codebase Gates are rewritten in the
present tense and their v12 pending links removed (LDG-3069 is their
receiver owner).

## LDG-3070: full-history real-data proof

Record and checker: `ledgr-research` `experiments/history-wave-full-proof/`
(README, `check_full.R`). Both 1998-2026 workloads ran on the integration
head `67f98d6b` against the snapshot built for LDG-3069 (hash `1f53c098`,
equal to the LDG-3080 build), each reading causal history every month
(`ledgr_history_frame(feature = "return_1", lookback = 63L, na_action =
"drop_instruments")`, sufficiency, an inverse-volatility estimate,
`ledgr_history_weights()` and `ledgr_target_rebalance()`).

| measure | changing membership | full membership |
| --- | ---: | ---: |
| status, pulses | DONE, 7,213 | DONE, 7,213 |
| fills; decision-trace rows | 10,703; 3,653,273 | 10,550; 8,428,204 |
| preparation, fold, native total s | 9.69, 43.70, 54.32 | 9.63, 64.53, 75.11 |
| parent peak working set / private MiB: preparation | 1,681 / 1,704 | 1,652 / 1,698 |
| fold | 1,638 / 1,685 | 1,806 / 1,844 |
| reading fills, equity and the whole trace | 3,273 / 3,660 | 5,951 / 6,599 |

- **Segment guard.** The default guard passes on both shapes: lifetime and
  terminal 829 facts in 1,995 segments (max 3 per instrument, share 0.19),
  membership 967,091 guard facts in 677,446 segments (max 581, share 0.25),
  trading status none (share 0.06); no instrument over its limit. The
  full-membership shape has no membership family.
- **Reconciliation.** Bars 5,481,906, instruments 1,166, open sessions
  7,213, membership 290,811 rows in 580 sets, lifetime 829 rows (527
  terminal), no trading-status or corporate-action rows, first and last bar
  1998-01-02 and 2026-09-04: all equal H1/WS39 and LDG-3080. The intended
  differences are Cut 16's snapshot hash rule 4, schema 122 and identity rule
  4.
- **Routed real-data counts.** No late-known lifetime fact; 78 instruments
  with more than one lifetime row; no trading-status row; zero lagged
  knowledge ranges on every instrument in both shapes, so the WS43 F5
  prefix-replay cost is a factor of 1 on this data. As LDG-3080 notes,
  adapter v003 sets knowledge equal to effective time; an adapter that maps
  vendor knowledge times must be re-censused.
- **Checker.** `check_full.R` fails on a changed identity or count, a
  late-known or missing-knowledge fact, a segment-guard breach, a lagged
  range, a run that is not `DONE` over 7,213 pulses or a failed stage, and,
  given a rerun directory, on any counted difference. Seven data mutations
  (F1-F7 below) each make it fail. A fresh rerun into a new private work
  directory reproduced every counted file exactly, including the fills,
  equity and config hashes of both runs, and `check_full.R data <rerun>`
  passes; F8 makes that comparison fail.
- **Plausibility.** The runs are mechanical evidence, not a strategy claim.
  The equity paths have no implausible jump: the largest one-day gain is
  11 percent (changing) and 23 percent (full membership); no day gains more
  than 50 percent.
- The stage peaks come from reading the whole decision trace back after the
  run (8.4 million rows for full membership), not from history preparation
  or the fold. This joins the WS8 trace-read route above.

## LDG-3071: teaching (ticket stays open)

Phase B implements the teaching part of LDG-3071; the decision
reconciliation table and the v12 as-implemented appendix wait for Workstream
45 (decisions 27 and 28) and close with the cut, so the ticket stays `open`.

- **Article.** New `vignettes/causal-history.qmd` ("Reading Causal
  History"), first in the Point-In-Time Evidence group: walk-forward hands
  off to it and it hands off to point-in-time-inputs. Interpretation of
  "before the point-in-time ingestion material": the article opens with a
  hello-world path (open an existing sealed snapshot, declare an experiment,
  run it) before any ingestion, and point-in-time ingestion is the next
  article in the reading flow. The snapshot it opens is built in a hidden
  setup chunk from `ledgr_sim_pit_inputs()`; every shown chunk executes and
  the rendered `causal-history.md` holds its output. It teaches, with
  executed output: the default read and its four defaults; the matrix
  adapter; `ledgr_history_info()`; `instruments = "decision_axis"` and
  `na_action = "drop_instruments"` with the selection table; the long layout
  and its evidence; structural sufficiency (stated not to be warm-up);
  bounded and history-dependent indicator classes (printed); feature cell
  evidence; carry evidence including `carried_input_share`; return features
  against differenced carried closes; one portfolio estimate from a history
  read through a plain solver, `ledgr_history_weights()` and
  `ledgr_target_rebalance(keep = )` with estimation exclusion and execution
  intent explained separately, then run; the vintage feature view against
  restated bar history on a late-known lifetime fact; one continuous history
  across walk-forward windows; finite-lookback advice with sizes; and the
  preflight boundary (decision 30) with an executed Tier 3 refusal.
- **Rendering.** `causal-history.md` is rendered with
  `tools/render-vignettes-gfm.R`. `walk-forward.md` is re-rendered for its
  new Where Next hand-off; its fold hash, session ID, execution seed,
  snapshot hash and feature-set hash lines change because the committed
  render predates identity rule 4 and snapshot hash rule 4 (stale rendered
  output, not a behaviour change). While writing the article, preflight
  refused the first portfolio strategy because its solver was a function in
  the calling session; the article now defines the solver inside the
  strategy and says why. That is preflight working as documented.
- **Contract.** Strategy Context Teaching is present tense, its v12 pending
  link removed, with two new bullets for the article and the portfolio
  example. With Release Gates and Store And Codebase Gates (LDG-3069), no
  v12 pending link remains in `contracts.md`; LTB-0415 checks that, that
  every v12 receiver anchor resolves, that no contracts.md sentence states
  rule 3 or schema 120/121 as current, and that the decisions bridge rows and
  the three RFC redirect anchors remain. No WS45-owned pending link exists
  in `contracts.md` (decisions 27 and 28 were made after the v12 receiver
  map and add none).
- **WS7.** The macro plan's WS7 entry now owns the carried-input-share
  consumer proof (v12 Section 10 item 18b): a registered workload whose
  estimator acts on the share, with a block showing the weights change at
  its threshold; field existence alone does not pass. Cut 16 shows only that
  the field is reachable (LTB-0297 and the article).
- **Help.** `?ledgr_history_frame`, `?ledgr_history_matrix`,
  `?ledgr_history_info`, `?ledgr_history_weights`,
  `?ledgr_history_sufficient` and `?ledgr_history_policy` link the article
  with a browser-free path. NEWS names the article.
- **Detector.** LTB-0414 (LCL-0404) checks the article's structure, calls,
  forbidden manual reconstruction in the portfolio chunk, the rendered output
  and the help links.

## Mutation table

Real-data checkers. Each mutation edits a copy of the committed `data/`
directory (`dev/bench/v0_2_2_history_proof/scripts/mutate_h6_data.py` and
`mutate_full_data.py`; samples are scaled in the gzip files) and runs the
checker on the copy.

| ID | Mutation | Checker | Result |
| --- | --- | --- | --- |
| H1 | candidate single-run parent samples x1.9 in two repeats | `check_h6.R` | fails: single-run gates 1.1006 and 1.1441 |
| H2 | candidate sweep daemon samples x8 in two repeats | `check_h6.R` | fails: parent-plus-daemon gate 1.1704 |
| H2a | the same at x5 (first attempt) | `check_h6.R` | passes, correctly: the ratio stays 0.87, below the bound |
| H3 | candidate sweep parent samples x6 in two repeats | `check_h6.R` | fails: two-worker parent gates 1.1133 and 1.1156 |
| H4 | current-dispatch final equity differs | `check_h6.R` | fails: transport parity |
| H5 | sequential execution seed differs | `check_h6.R` | fails: transport parity |
| H6 | a candidate run repeat has one fill fewer | `check_h6.R` | fails: run repeats differ |
| H7 | a gated step exited non-zero | `check_h6.R` | fails |
| H8 | a gated repeat missing | `check_h6.R` | fails (stops on the missing samples) |
| F1 | bar count changed | `check_full.R` | fails |
| F2 | snapshot hash changed | `check_full.R` | fails |
| F3 | a segment-guard breach | `check_full.R` | fails |
| F4 | full-membership run stopped | `check_full.R` | fails |
| F5 | pulse count changed | `check_full.R` | fails |
| F6 | a late-known lifetime fact | `check_full.R` | fails |
| F7 | a failed stage | `check_full.R` | fails |
| F8 | one more fill in a copy of the rerun data (by hand) | `check_full.R` with a rerun | fails: rerun differs |

Registered blocks. Each mutation is applied to one file of a source copy
(`git archive` of the teaching commit), the named block runs in a fresh R
process (`scripts/block_runner.R`) and the file is restored byte for byte
(`scripts/mutate.py`, specs from `scripts/make_specs_phase_b.py`). The
unmutated copy passes all three blocks. T6 first named "Used before
window:", which occurs twice in the rendered article and so could not be
applied; it was respecified to a unique executed line. "error" means the
block stopped.

| ID | Mutation | File | Result |
| --- | --- | --- | --- |
| T1 | hello world no longer the first shown chunk (label changed) | `vignettes/causal-history.qmd` | LTB-0414 fails (2 failed, error) |
| T2 | portfolio example drops `keep` | `vignettes/causal-history.qmd` | LTB-0414 fails (1 failed) |
| T3 | portfolio example rebuilds names with `colnames()` | `vignettes/causal-history.qmd` | LTB-0414 fails (2 failed) |
| T4 | a teaching chunk declares `eval: false` | `vignettes/causal-history.qmd` | LTB-0414 fails (1 failed) |
| T5 | the default-read chunk lost (renamed), so defaults are not taught first | `vignettes/causal-history.qmd` | LTB-0414 fails (1 failed, error) |
| T6 | an executed indicator print missing from the rendered article | `vignettes/causal-history.md` | LTB-0414 fails (1 failed) |
| T7 | a help page no longer links the article | `man/ledgr_history_info.Rd` | LTB-0414 fails (1 failed) |
| R1 | a v12 pending link restored on Release Gates | `inst/design/contracts.md` | LTB-0415 fails (1 failed) |
| R2 | a current-tense rule-3 snapshot-hash sentence | `inst/design/contracts.md` | LTB-0415 fails (1 failed) |
| R3 | a receiver anchor renamed | `inst/design/contracts.md` | LTB-0415 fails (1 failed) |
| R4 | a decisions bridge row anchor renamed | `inst/design/decisions.md` | LTB-0415 fails (1 failed) |
| O6 | LDG-3069 evidence no longer cites LTB-0295 | `tickets.yml` | LTB-0408 fails (1 failed) |
| O7 | LDG-3070 evidence no longer cites LTB-0291 | `tickets.yml` | LTB-0408 fails (1 failed) |

## Test changes and reasons

- New: LTB-0414 and LTB-0415 (`test-history-teaching.R`, review profile),
  registered as LCL-0404 and LCL-0405.
- LTB-0408 (`test-history-integrated-proof.R`): items 17 and 14 leave their
  pending state as LDG-3069 and LDG-3070 close, and the map names the
  registered blocks their evidence cites (LTB-0295, LDG-3061's transport
  oracle that LDG-3069 reran on real data; LTB-0291, the segment-guard
  refusal that LDG-3070's real-data guard pass relies on). This is the
  lifecycle the block's own comment requires ("when it closes, this map must
  name its detecting blocks"), not an oracle change to make a failure pass.
- No other registered test, fixture or oracle changed.

## Routed, not changed here

- **Shared memory (maintainer).** The post-substrate trigger is 0.1218 on the
  H1 workload, at or above the 10 percent threshold of v12 Section 7 (E6), so
  shared memory reopens as a question. Nothing is implemented. Inputs: the
  staged invariant is 454 MiB (`object.size`) and each daemon peaks at about
  1.1 GB with it. If reopened, E6 says to share the bar substrate rather than
  rebuild it and to rebuild only the pulse strings.
- **WS8: `ledgr_run_explain()` read cost.** Explaining one instrument reads
  the whole diagnostics and availability tables (9.3 s and a 2.6 GB R heap
  peak at H1), unchanged by the cut. The trace is not weakened.
- **WS8: single-run timing.** The history-enabled single run is 23 percent
  slower than the baseline on H1 (52.3 against 42.4 s native elapsed;
  preparation 10.0 against 6.2 s, fold 41.2 against 35.1 s; the profile names
  feature preparation and per-pulse decision work). Not gated by LDG-3069.
- **Maintainer: caller RNG with `seed = NULL`.** Unseeded parallel sweeps
  advance the caller's RNG through `mirai` daemon start and stop, before and
  after the cut. Whether ledgr should restore it is a behaviour choice.
- **Lazy history evidence (maintainer, Cut 16 decision 17).** Measured input:
  a full-lookback wide read is 8.79 times its value bytes on real data.
- **Walk-forward with two workers.** At the measured fold size, restarting
  daemons and restaging per fold makes two workers slower than one (74.5
  against 71.9 s); a reuse of daemons across folds would be a transport
  change for the macro plan, not this ticket.

## Correction 1 (close review 44b, 2026-10-21)

The close review (`close_review_44b.md`) returned CHANGES_REQUIRED with five
non-blocking findings. It verified the memory and real-data proofs
independently; nothing was re-measured, and the H6 plans and the Sharadar
workloads were not re-run.

- **F1, routes recorded where they are owned.** `macro_plan.md` WS8
  "Routed inputs" now lists the `ledgr_run_explain()` read cost (9.3 s, a
  2.6 GB R heap peak, the same as the baseline) and the history-enabled
  single-run time (52.3 against 42.4 s; preparation and per-pulse decision
  work from the profile, marked as inference). The deferred history
  simplification list updates the lazy-evidence entry to the measured 8.79
  times (243.4 MiB for 27.7 MiB of values) and adds the shared-memory trigger
  0.1218 and the `seed = NULL` caller-RNG advancement as open maintainer
  questions, and walk-forward daemon reuse across folds as a routed item
  owned by execution-core consolidation with the transport.
- **F2, census covers every changed function.** `loop_census.R` now takes
  its file list from the Cut 16 diff of `R/`; see "Extended census" in the
  seven-shape walk above. No shape instance was found among the 17 added
  iterations.
- **F3, the article exercises what it teaches.** The walk-forward example
  now reads history from the strategy's own context inside the test runs:
  a strategy holds as many shares as its history read has sessions, each
  window starts flat, and the first fills show 130 sessions at 1 July and 196
  at 1 October, both from the data start. The portfolio example runs once
  with `keep` and once without on a three-session window: both buy 357
  `DEMO_04` on 8 January; after its missing 9 January close the estimate
  leaves it out; with `keep` the position stays until 16 January, without
  `keep` all 357 shares are sold on 10 January. A `params$keep` switch exists
  only for this comparison. Re-rendered;
  `tools/render-vignettes-gfm.R --check vignettes/causal-history.qmd
  vignettes/walk-forward.qmd` verifies both.
- **F4, decision axis described as the help describes it.** The article now
  says `instruments = "decision_axis"` adds held nonmembers and members the
  strategy may not trade now, names `DEMO_01` (a member delisted on
  14 January) and explains `structural_exclusion` in one sentence.
- **F5, LTB-0414 checks effects.** The forbidden-name scan runs on
  whitespace-stripped code and refuses any `names(` or `dimnames(` use in the
  portfolio chunk. The late-fact chunk must read both restated bars and
  vintage features at the seventh session, and the rendered output must show
  inactive-interval prints for the bars and the at-pulse values 52.5 and 58.0
  for the features. The walk-forward chunk must read history inside the test
  runs, and the rendered first fills must exceed a window's length, the later
  window more. The rendered keep comparison must show no 10 January sale with
  `keep` and the 10 January sale without it. LCL-0404's scope and smallest
  failing change state these checks. The review's surviving U2-U4 now fail
  the block (table below).
- **Notes.** N2: `check_full.R` pins both runs' config, fills and equity
  hashes, fill and trace-row counts and final equity on the committed data
  alone (ledgr-research `3e9ea29`); F9 and F10 make it fail. N3: the summary
  now names the shared-memory denominator (the sweep's summed
  parent-plus-daemon private commit), not "total memory". N5: the article
  explains where `pit` and `snapshot_path` come from, what "Used before
  window: yes" means, shows the readiness flip from `not_ready` to valid, and
  compares the feature with simple (not log) differences, so the observed
  day matches exactly. N6: the Release Gates bullet no longer names a
  workstream. N1, N4 and N7-N9 need no change.

Test changes in Correction 1: LTB-0414 (whitespace-stripped forbidden scan,
`names(`/`dimnames(` refusal, late-fact and walk-forward reads and their
rendered effects, keep effect); the reason is close review 44b F5, which
showed the block passed mutations it claimed to detect. No accepted oracle
changed; the new literals (52.5, 58.0, the 10 January sale) are the
article's executed output, not product oracles.

MUT_C1

## Verification record

Windows 11, R 4.6.1, DuckDB 1.5.6, every R process run sequentially.

- Full suite, first run (source copy of `ea971d2e`): 1,161 blocks, 19,377
  expectations, one failure, one optional skip (quantmod). The failure was
  LTB-0302: its scan of documented strategy bodies reads from
  `function(ctx` to the next brace, and the article's brace-less
  `function(ctx, params) ctx$hold()` ran on into a helper that calls
  `ledgr_pulse_snapshot()`. The article was changed (the strategy has
  braces, `59feeb0e`); the block is unchanged and passes.
- Full suite on `59feeb0e` (source copy; `pkgload::load_all('.')` then
  `testthat::test_local('.', reporter = 'summary', stop_on_failure = FALSE,
  load_package = 'none')`): 1,161 blocks, 19,377 expectations, no failure
  or error, one optional skip (quantmod); 684 s of block time.
- `tools/check-codebase-contracts.R --mode=check`: OK, 158 branch and 55
  flow sites (unchanged), findings 72; `--self-test-mode-branches`: OK;
  `tools/check-fold-phase-contract.R .`: `LEDGR_FOLD_PHASE_CONTRACT_OK`;
  `tickets.yml` and `tests/claims.yml` parse; `git diff --check 67f98d6b` is
  clean. The census check rewrites its line-number CSVs under
  `dev/bench/v0_2_2_pre_cran_removal/census/` because roxygen lines moved
  code down; those regenerated files are not committed, as in phase A.
- `R CMD build` (with `QUARTO_PATH` naming RStudio's bundled Quarto, which
  rebuilds every vignette including the new article) and `R CMD check
  --no-manual --no-build-vignettes ledgr_0.2.1.0.tar.gz` on a source copy of
  `ab02a214`: Status OK, no warning or note. The check's test step runs the
  fast profile's membership as `tests/testthat.R` defines it; that is the
  package check, not the coordinator's timed fast-profile gate. "Running R
  code from vignettes" passes for all 25 package vignettes.
- Not run here, by instruction: the fast, review and heavy profiles and the
  independent close review. `R/cpp11.R` and `src/cpp11.cpp` line-ending churn
  from compilation is not committed.
