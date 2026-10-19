# History representation map

Role: living; Workstream 46 design map of the causal-history system (LDG-3074).
Status: finalized against the accepted Workstream 43 tree (`b9d098c8`) for LDG-3074; Section 7 records what Workstream 46 then changed.
Authority: non-binding. `tickets.yml` owns status and sequencing, `contracts.md`
owns behaviour, and `../manual/optimization_coding_style.qmd` owns the
fast-path rule this map applies.

## Purpose and reading guide

Cut 16 decision (17) ("simplify before proving") asks for one map of every
history representation, every resolution path and every execution-mode
branch before Workstream 46 removes duplicates and Workstream 44 proves the
result. This map is that inventory. It is the input to LDG-3075 (hold each
fact once, drop unread planes), LDG-3076 (one membership compiler) and the
execution-core consolidation in the macro plan.

- Source tree: `b9d098c8`, the integration merge of the accepted Workstream
  43 (Workstreams 40 to 43 accepted), merged into `ws46/history-simplification`
  at `804e9be2` with no product change. The map was drafted on `9b0b304d`
  before Workstream 43 merged; every entry Workstream 43 changed was re-read
  on `b9d098c8` (Section 5). Function names are the stable anchors; line
  numbers are omitted because they churn.
- "Canonical" names the path whose answer defines the rule. "Fast path"
  names a second path that answers the same question for some inputs, faster
  or in a different shape. Each fast path lists its differential oracle (a
  registered test block that compares it with the canonical path, or "none")
  and a proposed removal or merge condition, as the fast-path rule in the
  optimization coding style requires.
- "Production consumer" means a call reached from `ledgr_run()`,
  `ledgr_sweep()`, window, walk-forward, precompute, inspection or result
  readers. A consumer that only tests reach is listed as a test consumer.

## Measurement at the H1 shape

Sizes come from `dev/bench/v0_2_2_history_simplification/representation_sizes.R`
run on `b9d098c8` against the vendor-neutral public-history fixture
(`dev/bench/v0_2_2_public_history/fixture.R`: 1,166 instruments by 7,213
weekday sessions, 580 rotating complete membership sets of 600 members, 20
labelled delistings, 40 late-known ten-session inactive intervals, about 0.5
percent missing member bars, five cash dividends). The recorded output is
`dev/bench/v0_2_2_history_simplification/evidence/representation_sizes_h1_b9d098c8.csv`
with its console log beside it (the draft's `9b0b304d` record,
`representation_sizes_h1.csv`, is kept; the bar, plane, segment and plan
rows are unchanged by Workstream 43 and only the feature, precompute and
staged rows moved, by 1 to 2 percent). "Object" is `object.size()`; "serialized" is
`length(serialize(x, NULL))`, which is what a worker transport or `saveRDS()`
carries. One process ran alone; sizes do not depend on host load. Dense
representations are measured on a synthetic complete matrix of the same
shape because the fixture's ragged bars are an availability input.

Headline numbers (MB, object / serialized):

| Representation | Size |
| --- | --- |
| Substrate, no features bound | 720.6 / 737.4 |
| Substrate, one feature bound | 786.8 / 802.2 |
| Bar value planes (open, high, low, close, volume) | 5 x 64.2 |
| `gap_type` / `is_synthetic` / `observed` | 64.2 (98.4 serialized) / 32.1 / 32.1 |
| `expected`, `halted`, `missing_expected_bar`, `inactive_print` | 4 x 32.1 |
| Membership segments (677,446 segments) | 81.7 / 48.2 |
| Status, lifetime, terminal segments | 0.1 each |
| `provider_plan` (membership `set_index` 58.5) | 59.5 / 75.5 |
| Unread plus restating planes (six) | 224.6 / 258.9 |
| Facts held twice (segments plus provider plan) | 141.5 / 123.9 |
| One feature: payload / runtime projection (each with sparse evidence planes) | 65.7 / 67.8 |
| `ledgr_precompute_features()`, two features: total / projection / payload | 265.8 / 134.3 / 131.3 |
| History memo after one `close` read: base masks / base `close` positions / 80 overlays | 32.1 / 64.2 / 3.4 |
| One read result, `close`, lookback 252 / `Inf` (wide) | 20.5 / 554.0 |
| Staged invariant, fresh sweep (two features) | 855.2 / 869.9 |
| Staged invariant, sweep with a precomputed payload | 1,121.0 / 1,133.6 |
| Provider built from the substrate (closures) | 0.8 object, 1,701.3 serialized |
| Dense `bars_mat` / `static_bars_views` / `bars_by_id` (synthetic) | 417.1 / 1,011.1 / 548.1 |

The substrate builds in about 10 seconds at this shape on `b9d098c8`
(disclosure only; the host was not quiet). The provider's
serialized size is an artefact of its closures capturing the substrate (see
R14); the provider is never serialized in production, it is rebuilt in each
daemon.

## 1. Representations

Each row names the object, its owning function and file, its production
consumers, its size at H1 and a disposition note. Rows marked "flag" feed
Section 3.

### 1.1 Bars

| ID | Representation | Owner | Production consumers | H1 size | Note |
| --- | --- | --- | --- | --- | --- |
| R1 | Fetched bar frame, one unsplit frame per preparation (transient) | `ledgr_precompute_fetch_bars_frame()` (`R/precompute-features.R`); runner SQL in `ledgr_run_fold_impl()` (`R/backtest-runner.R`) when no substrate is supplied | `ledgr_history_substrate()` only; dropped after construction | not retained | Two fetch sites for one frame: the runner selects OHLCV plus constant `gap_type = 'NONE'` and `is_synthetic = FALSE`, the precompute fetch selects OHLCV only. |
| R2 | Substrate bar value planes `bars$open/high/low/close/volume` (instrument x session doubles) | `ledgr_history_substrate_bar_matrices()` (`R/history-substrate.R`) | P1 bar packet; valuation marks (`close`); history reads (`ledgr_history_bar_evidence()`); memo carry positions (`is.finite()` of the field); feature calculation, which reads each instrument's prefix of every field directly (`ledgr_history_feature_inputs()`, `R/history-features.R`); walk-forward frozen-at-end and terminal recovery | 5 x 64.2 MB | Canonical bar store on the availability path. |
| R3 | `bars$observed` (logical) | same | precompute warm-up counts (`ledgr_precompute_available_counts()`), feature-read evidence `observed` and `is_missing` (`ledgr_history_feature_evidence()`), P1 packet field (copied, unread on `b9d098c8`), test assertions | 32.1 MB | Marks the cells a fetched bar row filled; history bar reads test `is.finite(raw)` per field instead. |
| R4 | `bars$gap_type` (character) - flag | same | P1 bar packet -> `ctx$bars$gap_type` via `ledgr_history_bar_packet_frame()`; instrument frame column (not read by the feature engine) | 64.2 MB (98.4 serialized) | Restating: every fetch path supplies `'NONE'` or omits the column, so the plane is exactly `ifelse(observed, "NONE", "MISSING_EXPECTED_SESSION")`. |
| R5 | `bars$is_synthetic` (logical) - flag | same | P1 bar packet -> `ctx$bars$is_synthetic`; instrument frame column | 32.1 MB | Restating: constant `FALSE` on every fetch path. |
| R6 | P1 bar packet (`current` and `next_bar`, one column of every plane per pulse, 14 vectors each) | `ledgr_history_substrate_bar_packet()` via `ledgr_history_substrate_fold_reader()$bars` | P1 marks (`current$close`), P2 `ctx$bars` (`ledgr_history_bar_packet_frame()`), P3/P4 next-open fills (`next_bar` OHLCV) | 2 x 14 x 1,166 per pulse | Five packet fields (`observed`, `expected`, `halted`, `missing_expected_bar`, `inactive_print`) are copied every pulse and never read. |
| R7 | Instrument frame (one data frame per instrument over the whole axis) | `ledgr_history_substrate_instrument_frame()` | none in production: its only caller is `ledgr_history_substrate_history_reader()`, the provider's `history` member (R14), which no product code reads | transient, about 0.5 MB per instrument | Workstream 43 moved feature preparation to the planes (R2), leaving this frame unread. |
| R8 | `ledgr_history_substrate_bar_frame()` | `R/history-substrate.R` | none | n/a | Uncalled private helper; the codebase census reports it as the one `uncalled_private` finding. |
| R9 | DB-backed bar readers | `ledgr_availability_provider()` history closure (`R/availability-provider.R`); `ledgr_derived_state_availability_marks()` (`R/derived-state.R`) | provider closure: none in production (the unregistered marks oracle in `test-workstream8-exact-parity.R` reads it); marks: `ledgr_rebuild_derived_state()` for results and reconstruction | query-time | The marks query re-derives last-observed closes from `snapshot_bars` with one `cummax()`; see path V-2. |
| R10 | Window pulse validation bars (`bars_by_id`, aligned) | `ledgr_experiment_window_validate_pulses()` (`R/walk-forward-folds.R`) with `ledgr_availability_provider_portable()` (a third provider history closure over these bars) and `ledgr_sweep_align_availability_bars()` | window construction only, to count pulses and check coverage | per window | A third bar shape and a full facts provider (membership plan included) built only to count calendar pulses and check coverage; the session calendar alone answers both. |
| R11 | Dense `bars_by_id`, `bars_mat`, `static_bars_views` (frozen) | runner, `ledgr_sweep_impl()`, `ledgr_bars_pulse_views()` (`R/pulse-context.R`) | dense fold only | 548.1 / 417.1 / 1,011.1 MB synthetic | Frozen by Cut 16 decision (1); removed by execution-core consolidation, not by Workstream 46. |

### 1.2 Substrate planes derived from facts

All four are built at the end of `ledgr_history_substrate()` from the
segments' diagonal (`ledgr_history_segments_diagonal_state()`: the state
knowable at each observation's own session).

| ID | Plane | Production consumers | Test consumers | H1 size | Note |
| --- | --- | --- | --- | --- | --- |
| R12a | `expected` - flag | P1 bar packet field only (never read downstream) | LTB-0291 | 32.1 MB | Unread. History reads build their own mask at knowledge `Inf` in the memo (R20) and per late epoch; for instruments without late facts that mask equals this plane. |
| R12b | `halted` - flag | P1 bar packet field only | LTB-0291 | 32.1 MB | Unread. Execution restrictions come from the provider status cursor (path S-3). |
| R12c | `missing_expected_bar` - flag | P1 bar packet field only | LTB-0291 | 32.1 MB | Unread. Reads derive `is_missing` per cell at their cutoff. |
| R12d | `inactive_print` - flag | P1 bar packet field only | LTB-0291 | 32.1 MB | Unread. Reads derive inactive prints as `!expected & observed` at their cutoff (`ledgr_history_bar_evidence()`). |

Removing R12a-d changes LTB-0291's literal assertions on these planes; that
test change needs its own stated reason in LDG-3075's evidence (the planes
have no product consumer), per the registered-test rule in `AGENTS.md`.

### 1.3 Facts

| ID | Representation | Owner | Production consumers | H1 size | Note |
| --- | --- | --- | --- | --- | --- |
| R13 | Canonical sparse fact tables (`families`, `membership_sets`, `membership`, `status`, `lifetime`, `sessions`) | `ledgr_availability_provider_data()` (`R/availability-provider.R`) | substrate construction; DB providers (R15); `ledgr_walk_forward_pulse_calendar()` and window validation (R10) read every fact table and use only `sessions` | transient | Durable input; never retained whole. |
| R14 | `provider_plan`: membership plan (ordered headers, eligibility times, `set_index` with every set row, interval vectors), status and lifetime diagonal segments (CSR bounds and codes), sessions | `ledgr_availability_provider_prepare()` (`R/availability-provider-prepared.R`), stored in the substrate | every availability fold's decision and execution views through `ledgr_availability_provider_from_plan()`; worker staging rebuilds the provider from it | 59.5 MB (58.5 in `set_index`) | Second form of the facts (diagonal: knowledge cutoff equals observation). Its `sessions` copy duplicates `substrate$sessions`. The provider's `history` member wraps R7 and captures the substrate, but no production code reads `provider$history` (tests in `test-availability-causality.R` and `test-workstream8-exact-parity.R` do). |
| R15 | Store-built provider (facts re-read from the snapshot) | `ledgr_availability_provider()` | `ledgr_rebuild_derived_state()` (built twice per call), `ledgr_backtest_availability()` results, `ledgr_run_open()` for INCOMPLETE runs | rebuilt per call | Derived state and run open read only `sessions` for a calendar, yet compile the full membership plan; the results reader also replays decision views. |
| R16 | Two-clock segments, four families (`membership`, `trading_status`, `lifetime`, `lifetime_terminal`): CSR offsets and counts, observation range, `knowledge_from`, dictionary-coded state, winner and reason, segment-guard counts | `ledgr_history_substrate()` through the compilers in Section 2 | lifetime and terminal: history-read masks (R20), `ledgr_history_substrate_treated_field()`; membership and trading status: none in production (`ledgr_history_substrate_query_facts()` in tests, the census and the build-time segment guard) | membership 81.7 MB (677,446 segments for 1,023,787 counted facts); the others 0.1 MB each | First form of the facts. Membership and status segments are compiled, guarded and staged but never read by a production path on this tree. |
| R17 | Small substrate fields: `families` (declared list, membership completeness table), `universe_rule`, `valuation_policy`, `sessions`, `instrument_index`, `pulse_index`, `axis`, clocks and identity | `ledgr_history_substrate()` | `sessions`: calendars in sweep, inspection, walk-forward continuation and owner validation; identity fields: staging identity and owner validation | 1.5 MB together | `families`, `universe_rule` and `valuation_policy` have no production reader on the substrate (tests read `families`). |
| R18 | Corporate-action rows and settlement plan | `ledgr_corporate_action_rows()`, `ledgr_corporate_action_plan()` | fold P1 postings; carried walk-forward chain rebuilds the predecessor plan from its ledger | small | Not a history representation; listed because the deferred "settlement state as data" item (macro plan, Deferred history simplification) owns it. |

### 1.4 Treatment and history reads

| ID | Representation | Owner | Consumers | H1 size | Note |
| --- | --- | --- | --- | --- | --- |
| R19 | History policy (`price_carry`, `output_carry`, `segment_limit`) and its identity | `ledgr_history_policy_normalize()`, `ledgr_history_policy_identity()` (`R/history-policy.R`) | substrate, owner validation, precompute identity, staging identity | bytes | Single representation. |
| R20 | History memo (`substrate$history_memo`, an environment): `late_epochs`, `base_masks` (expected mask and terminal-first column at knowledge `Inf`), `base_<field>` carry positions (source and last-barrier integer planes), `overlay_<instrument>_<epoch>[_<field>]` per late-known instrument and epoch | `ledgr_history_memo_value()` and callers in `R/history-frame.R` | every `ledgr_history_frame()` read | 99.7 MB after one `close` read (32.1 masks, 64.2 positions, 3.4 for 80 overlays); each further field adds 64.2 MB | Cache, never staged (staging resets it); derived only from the substrate. Base masks duplicate R12a for instruments without late facts. |
| R21 | Read service and cutoff view | `ledgr_history_read_service()`, `ledgr_history_view()`, `ledgr_history_substrate_fold_reader()$view` | P2 attaches the view as `ctx$.history`; `ledgr_history_frame()` | bytes plus references | The view references the whole substrate, which is the LDG-3072 preflight gap. |
| R22 | Read result: values plus twelve aligned evidence planes and a selection table | `ledgr_history_read()`, `ledgr_history_wide()`, `ledgr_history_long()` | strategies, `ledgr_history_matrix()`, `ledgr_history_sufficient()` | 20.5 MB at lookback 252; 554.0 MB at `Inf` | Eager evidence; the lazy-evidence decision belongs to the maintainer with LDG-3069 measurements (macro plan, Deferred history simplification). |
| R23 | Valuation marks state (last observed close, its pulse, frozen set) | `ledgr_availability_valuation_state()` (`R/availability-economics.R`) | fold P1 decision views, `ledgr_availability_frozen_at()`, terminal recovery | 2 vectors of length 1,166 | A running cursor over R2 `close`; see marks paths V-1 and V-2. |

### 1.5 Features

Feature values are calculated once per experiment preparation by
`ledgr_history_compute_feature_series()` (`R/history-features.R`), per
instrument and per pulse range whose knowable lifetime state is constant
(L-8), over treated inputs (C-4).

| ID | Representation | Owner | Consumers | H1 size | Note |
| --- | --- | --- | --- | --- | --- |
| R24 | Feature payload: per fingerprint, per instrument value vectors on the substrate axis, plus the sparse evidence records of R29 | `ledgr_history_precompute_payload()` (`R/history-substrate.R`); dense `ledgr_precompute_payload()` | `ledgr_projection_from_payload()` | 65.7 MB per feature | Values are computed as matrices first and split into this shape, releasing each matrix as it is split. |
| R25 | Runtime projection: one instrument x session matrix per feature plus index maps and `feature_planes` (the sparse evidence records aligned to the projection) | `ledgr_runtime_projection()`, `ledgr_projection_from_payload()`, `ledgr_projection_from_feature_matrix()` (`R/runtime-projection.R`) | bound into the substrate as `feature_projection`; P2 accessors and `features_wide`; history feature reads | 67.8 MB per feature | Canonical feature store at run time. |
| R26 | `substrate$feature_projection` | `ledgr_history_substrate_bind_features()` | fold (as `runtime_projection`), history feature reads, staging identity (`feature_ids`) | same object as R25 | Not a copy in memory; serialized with the substrate. |
| R27 | Precomputed object: `projection` (R25) and `payload` (R24) together, plus `history_axis`, warm-up table and identity | `ledgr_precompute_features()` (`R/precompute-features.R`) | `ledgr_sweep()` slices `projection`; dense sweeps may rebuild from `payload` | 265.8 MB for two features (134.3 projection, 131.3 payload) - flag | Features held twice inside one public object. Not in LDG-3075's amended scope; routed in Section 7. |
| R28 | Availability feature name and lookup states; dense fast context and static feature views (frozen) | `ledgr_projection_feature_name_state()`, `ledgr_projection_feature_lookup_state()`, `ledgr_fast_context_state()`, `ledgr_projection_pulse_views()` | fold P2 | index maps; dense views per pulse | Dense views are removed with dense mode. |
| R29 | Feature evidence for history reads: preparation retains only sparse records (admitted-run spans with their first ready column, reason runs, input-carried and output-carried cells with source time and age; `ledgr_feature_plane_records()`), and each read derives the aligned planes at its cutoff | `ledgr_feature_plane_records()` (`R/history-features.R`), `ledgr_history_feature_evidence()` (`R/history-frame.R`) | `ledgr_history_frame(feature = )` | sparse; per read | Canonical read-time evidence. |
| R29b | Dense per-instrument evidence frame | `ledgr_history_feature_planes()` (`R/history-features.R`) | none in production; test oracle in `test-indicator-evidence.R` and `test-indicator-history-calculation.R` | per call | A second, dense implementation of R29's column meanings kept as a test oracle; its differential is those tests. |
| R34 | Indicator history catalogue (48 rows: source, family, output, variant, history class, required fields, input-carry family, width) | `ledgr_indicator_history_catalogue()` (`R/indicator-history.R`), a hashed feature-engine helper | every built-in and registered TTR constructor through `ledgr_indicator_catalogue_row()`; certification (`ledgr_feature_catalogue_candidates()`) | small, but rebuilt row by row for every constructed indicator | LDG-3077: build once per session and look rows up by index; the function body stays as hashed so the engine digest does not move. |

### 1.6 Precompute payloads and staged worker invariants

| ID | Representation | Owner | Consumers | H1 size | Note |
| --- | --- | --- | --- | --- | --- |
| R30 | Sweep in-memory payload and projection (no explicit precompute) | `ledgr_sweep_impl()` | bound into the sweep's substrate | as R24/R25 | Transient; the payload is dropped after the projection is built. |
| R31 | Inspection payload and substrate | `ledgr_pulse_inspection()` (`R/pulse-snapshot.R`) | one inspected pulse | one substrate to the snapshot end plus features | One-off external call; not on a run path. |
| R32 | Staged invariant: `exp` payload, `history_substrate` (memo reset), `pulses_posix`, `metric_kernel`, `retain`, `precomputed_features`, `snapshot_hash`, `strategy_hash`, `master_seed`, `compiled_accounting_model`, `availability_config`, `execution_opportunities_posix`, `corporate_action_rows`, plus empty `bars_by_id`, `bars_mat`, `static_bars_views` and `runtime_projection` slots | `ledgr_sweep_history_invariant_fields()`, `ledgr_sweep_stage_history_tasks()` (`R/sweep.R`); daemon side `ledgr_history_worker_stage()` stores it in `.ledgr_history_worker_stage` | each daemon's candidate tasks through `ledgr_history_worker_take()` | 855.2 MB fresh; 1,121.0 MB with a precomputed payload; one compact task 0.1 MB | Worker-reconstructed, not staged: `pulses_iso`, the availability provider (from R14) and the memo (R20). |
| R33 | `precomputed_features` inside the staged invariant - flag | same | none: `ledgr_sweep_candidate_execution()` and `ledgr_sweep_run_candidate()` receive and pass the argument but never read it, and pulse inspection passes `NULL` | 265.8 MB (two features) | The features it carries are already in `history_substrate$feature_projection`, so a precomputed sweep stages its features three times: the substrate's sliced projection, the payload's projection and the payload's per-instrument vectors. |

## 2. Resolution paths

Fact state is resolved at an observation session and a knowledge cutoff.
The fold asks only diagonal questions (knowledge equals observation); history
reads ask two-clock questions (observation at or before a later cutoff).

### 2.1 Membership

The canonical resolver is `ledgr_membership_resolve_prepared()`
(`R/availability-provider.R`; `ledgr_membership_resolve_at()` is its public
inspection wrapper). Production fold decisions use the prepared cursor;
history reads do not consult membership segments (selection uses the
context's decision planes from the cursor).

| ID | Path | Status | Selected when | Differential oracle | Proposed removal or merge condition |
| --- | --- | --- | --- | --- | --- |
| M-1 | `ledgr_membership_resolve_prepared()` | canonical | interval-only and family-wide compilers call it per instrument or per break | n/a | Stays; LDG-3076 makes it the only resolver behind compilation. |
| M-2 | Prepared cursor: `ledgr_availability_prepared_membership_plan()` / `_from_plan()`, advancing headers once and caching header planes (`R/availability-provider-prepared.R`) | fast path, diagonal only | every availability fold pulse (`decision_view`, `execution_view`); same-clock segment compiler | LTB-0291 (lagged mixed complete-plus-partial family forward, backward and forward; 40 incomplete sets; header-advance counts), plus the unregistered `test-availability-provider-witnesses.R` blocks against the retained v0.2.0.0 reference | Merge into the segment form if LDG-3075 keeps only two-clock segments: a diagonal read of the segments must match the cursor on the same differential and on the H1 fold timing. Otherwise keep as the single diagonal form and drop membership segments. |
| M-3 | Complete-set compiler `ledgr_history_membership_complete_segments()` | fast path | every header complete and no interval rows | LTB-0291 (three complete sets with two clocks, two instruments, every observation and knowledge pair: state, winner and reason) | LDG-3076: keep only if a randomized differential against M-1 and an H1 measurement justify it over the per-instrument compiler. |
| M-4 | Same-clock compiler `ledgr_history_membership_diagonal_segments()` (through M-2) | fast path | headers present or mixed with intervals, every knowledge time equal to its effective time | none | LDG-3076: removed into the per-instrument compiler; same-clock facts have one epoch per fact. |
| M-5 | Interval-only per-instrument compiler: `ledgr_history_fact_segments_by_instrument()` with M-1 on that instrument's rows | canonical compiler shape | no set headers, interval rows present | LTB-0291 (lagged intervals, every observation and knowledge pair); a mock refuses the family-wide compiler | Becomes the single compiler (LDG-3076), extended to headers. |
| M-6 | Family-wide epoch compiler `ledgr_history_segments_build()` | fallback, superlinear | any other mix (incomplete or mixed headers with lagged knowledge): 0.8, 3.9 and 23.9 s at 20, 40 and 80 sets by 300 instruments (WS41 closeout) | none (the WS41 randomized differential was not registered) | Removed by LDG-3076 with a detector that fails if it returns. |
| M-7 | Point query `ledgr_history_segments_query()` and plane materializer `ledgr_history_segments_materialize()` over segments | readers of compiled segments | `query_facts` (tests); materializer for lifetime and terminal planes | the segment differentials above | Stay with whichever segment form survives. |

### 2.2 Trading status

The canonical rule is the applicable-set resolver
`ledgr_history_status_resolve_applicable()` (supersession lineage, then
precedence, then conflict) over rows with `effective_from <= observation <
effective_to` and `knowledge_time <= cutoff`. Both compiled forms call it.

| ID | Path | Status | Selected when | Differential oracle | Proposed removal or merge condition |
| --- | --- | --- | --- | --- | --- |
| S-1 | `ledgr_history_status_resolve_applicable()` | canonical rule | n/a | n/a (literal witnesses: LTB-0285 correction chains through the provider) | Stays. |
| S-2 | Per-instrument segment compiler (`ledgr_history_status_segments()` -> `ledgr_history_fact_segments_by_instrument()`) | canonical compiler shape | an instrument has more than one status fact | none against S-1 directly; LTB-0291 compares S-2/S-4 with S-3 on the diagonal at three pulses of one fixture | Production reads no status segments on this tree (R16), so the family can be dropped from the substrate unless a Workstream 42 or 43 consumer appears; if kept, add a two-clock differential. |
| S-3 | Provider diagonal segments and cursor (`ledgr_availability_prepared_segments()`, `ledgr_availability_prepared_cursor()`) | fast path, diagonal only | every availability fold pulse (execution restrictions) | LTB-0291 (diagonal agreement with S-2 at three pulses); unregistered provider witness blocks against the v0.2.0.0 reference | Keep as the single diagonal form if status segments are dropped; otherwise derive it from the segments' diagonal (LDG-3075). |
| S-4 | Sparse compiler `ledgr_history_sparse_fact_segments()` | fast path | every instrument has at most one status fact | none (LTB-0291 checks only segment counts and that the epoch compiler is not entered) | Merge into S-2: with one fact the per-instrument compiler produces the same segments; keep only with a differential and a measurement. |
| S-5 | Diagonal materialization into `substrate$halted` (`ledgr_history_segments_diagonal_state()`) | derived plane | none in production (R12b) | LTB-0291 literal | Removed with R12b. |

### 2.3 Lifetime

Canonical rule: `ledgr_history_lifetime_resolve_applicable()` (the
applicable fact with the latest effective time, then knowledge time, then
row order).

| ID | Path | Status | Selected when | Differential oracle | Proposed removal or merge condition |
| --- | --- | --- | --- | --- | --- |
| L-1 | `ledgr_history_lifetime_resolve_applicable()` | canonical rule | n/a | n/a (literal witnesses: LTB-0285 revival and conflict through the provider) | Stays. |
| L-2 | Per-instrument segment compiler (`ledgr_history_lifetime_segments()`) | canonical compiler shape | an instrument has more than one lifetime fact | LTB-0298 indirectly (reads equal the whole-prefix primitive built on these segments); LTB-0292 literals | Stays as the two-clock lifetime form. |
| L-3 | Sparse compiler (`ledgr_history_sparse_fact_segments()`) | fast path | at most one lifetime fact per instrument | none (LTB-0291 segment counts only) | Merge into L-2 as S-4. |
| L-4 | Provider diagonal lifetime segments (three planes: state, terminal label, winner) and cursor | fast path, diagonal only | every availability fold pulse (restrictions, held inactive positions, terminal disposition labels) | LTB-0291 (diagonal agreement at three pulses); provider witness blocks | Derive from the two-clock lifetime and terminal segments' diagonal, or keep as the one diagonal form (LDG-3075). |
| L-5 | Whole-prefix mask `ledgr_history_substrate_expected_at()` (materializes lifetime segments at a cutoff) | canonical two-clock mask | history-read memo (base and overlays); `ledgr_history_substrate_treated_field()` (tests only); feature inputs (`ledgr_history_feature_inputs()`, per instrument and per pulse range at the range end's cutoff) | LTB-0298 is built on it; LTB-0310 and LTB-0313 read feature values through it | Stays. |
| L-6 | Memo masks: base at knowledge `Inf`, one overlay per late-known instrument and epoch (`ledgr_history_cutoff_planes()`) | fast path | every history read | LTB-0298 (every cutoff of a hostile substrate, forward and shuffled, equals the whole-prefix primitive cell for cell) | Stays while reads are eager. Overlays should be grouped by epoch if LDG-3070 finds a material late-known count; revisit if the lazy-evidence decision changes the read. |
| L-7 | Diagonal lifetime plane `substrate$expected` and derived `missing_expected_bar`, `inactive_print` | derived planes | none in production (R12) | LTB-0291 literals | Removed with R12a, R12c and R12d. |
| L-8 | Late-epoch detection: `ledgr_history_late_epochs()` (history reads; per instrument, the knowledge instants of lifetime or terminal segments learned after the column they describe) and `ledgr_history_feature_ranges()` (feature calculation; the same instants as pulse positions inside the calculation bounds, used to split ranges) | two implementations of one question | reads; feature calculation | none directly; LTB-0298 (reads) and LTB-0313 (features) each pin their own consumer on late-known lifetime facts | Merge into one helper only with a stated identity change: `ledgr_history_feature_ranges()` is a hashed feature-engine helper (`ledgr_feature_engine_version()`), so changing its body moves the engine digest and every availability feature fingerprint, which a byte-identical Workstream 46 change may not do. Routed (Section 7). |

### 2.4 Terminal state and the sticky barrier

The terminal state follows the lifetime resolver (a relisting clears it);
the carry barrier it implies is sticky from the first knowable terminal
column (maintainer decision 2026-10-17, v12 Section 5). These are deliberately
different questions.

| ID | Path | Status | Selected when | Differential oracle | Proposed removal or merge condition |
| --- | --- | --- | --- | --- | --- |
| T-1 | Terminal segments (`ledgr_history_terminal_segments()`, always per instrument; no sparse path) | canonical two-clock terminal state | barrier and memo | LTB-0292 (state and barrier pinned separately; released barrier mutation fails) | Stays. Holds the same facts as lifetime segments under a second key; LDG-3075 may derive it from lifetime segments if their winners carry the terminal label. |
| T-2 | Sticky barrier `ledgr_history_substrate_terminal_planes()` (per-column assertion plus the first asserted column over the whole prefix, then `<=`; `ledgr_history_substrate_terminal_at()` returns the sticky plane) | canonical barrier | memo base and overlays (`terminal_first`), treated field, feature inputs (sticky barrier for carry, asserted columns to restart runs under Cut 16 decision 20) | LTB-0292 literal, LTB-0298 cutoffs, LTB-0310 restart literals | Stays. |
| T-3 | Memo `terminal_first` per instrument (base and overlay) | fast path of T-2 | every history read | LTB-0298 | As L-6. |
| T-4 | Provider terminal label (L-4 plane 2) | diagonal, non-sticky by design | fold terminal disposition of held inactive instruments (`ledgr_terminal_resolve()`) | terminal-outcome blocks for the fold; no differential with T-1 | Derive from T-1's diagonal or keep with L-4; the non-sticky execution semantics are bound and do not change. |

### 2.5 Carry and marks

| ID | Path | Status | Differential oracle | Proposed removal or merge condition |
| --- | --- | --- | --- | --- |
| C-1 | `ledgr_history_input_carry()` (vector, one instrument) | canonical carry rule | LTB-0292 literals | Stays, or becomes a one-row call of C-2. |
| C-2 | `ledgr_history_input_carry_matrix()` = `ledgr_history_carry_positions()` + `ledgr_history_carry_evidence()` | second implementation, matrix shape | LTB-0292 (one matrix row equals C-1 field by field) | Merge: express C-1 through C-2 (or the reverse) so one implementation remains. |
| C-3 | Memo positions plus `ledgr_history_bar_evidence()` | fast path of C-2 at a cutoff | LTB-0298 | As L-6. |
| C-4 | Feature-input carry: `ledgr_history_feature_inputs()` calls C-1 once per price field per instrument range (volume is never carried) | consumer of C-1, not a separate implementation | LTB-0292 (C-1 literals), LTB-0310 and LTB-0311 (feature values and carry planes under default, no and output-only carry) | Stays with C-1; no C-1 versus C-3 differential exists, so the read and feature paths agree only through their shared primitive and each one's literal tests. |
| V-1 | Fold marks `ledgr_availability_valuation_state()` | canonical marks | LTB-0303, LTB-0304 | Stays. |
| V-2 | Result and reconstruction marks `ledgr_derived_state_availability_marks()` (SQL plus `cummax()`) | second implementation | LTB-0303, LTB-0304 (results and reconstruction equal the fold) | Keep while readers have no substrate; merge if result readers ever hold one. |

## 3. Flags for LDG-3075

Consumers below are the actual ones on this tree, found by reading the
callers, not by name search alone.

- **Facts held twice.** Membership, status and lifetime facts are compiled
  into two forms: two-clock segments (R16) and the diagonal provider plan
  (R14). At H1 the two forms hold 141.5 MB (81.7 segments, 59.5 plan). The
  fold reads only the plan; history reads read only lifetime and terminal
  segments. Membership segments (677,446 at H1) and trading-status segments
  have no production consumer on this tree; they are compiled, guarded,
  staged and read only by `ledgr_history_substrate_query_facts()` in tests
  and the census. The plan answers a diagonal read of the segments, so it can
  be derived from them; the reverse needs the fact rows, which the plan keeps
  only for membership (`set_index`) and folds into `pmax(effective,
  knowledge)` boundaries for status and lifetime.
- **Unread planes.** `expected`, `halted`, `missing_expected_bar` and
  `inactive_print` (R12, 128.4 MB) are copied into every P1 bar packet and
  read by nothing downstream; only LTB-0291 asserts them.
- **Restating planes.** `gap_type` (64.2 MB, 98.4 serialized) is
  `ifelse(observed, "NONE", "MISSING_EXPECTED_SESSION")` and `is_synthetic`
  (32.1 MB) is constant `FALSE` on every fetch path. Their one product
  consumer is the `ctx$bars` frame built by `ledgr_history_bar_packet_frame()`,
  which can derive both columns from `observed` per pulse. `observed` (32.1
  MB) stays: precompute warm-up counts and feature evidence read it.
- **Share of the substrate.** Unread plus restating planes plus the provider
  plan are 284.1 MB, 39 percent of the 720.6 MB substrate at H1 (the WS41
  closeout estimated 41 percent at lake scale). Holding membership once
  removes a further 59.5 or 81.7 MB depending on the form kept.
- **Also unread on this tree.** `precomputed_features` in the staged
  invariant (R33, 265.8 MB at two features); `provider$history` (R14), which
  captures the substrate through R7; `ledgr_history_substrate_bar_frame()`
  (R8); the substrate's `families`, `universe_rule` and `valuation_policy`
  fields (R17); the duplicate `provider_plan$sessions`; the instrument frame
  (R7) behind `provider$history`; the diagonal-state helper behind R12. Each
  is safe to remove for byte-identical results; LTB-0291 and the two
  provider-history tests are the only readers of the test-read items.
- **Full plan for a calendar.** Derived-state rebuild (twice per call),
  `ledgr_run_open()` for INCOMPLETE runs and window pulse validation (R10)
  compile a full provider, membership plan included, to read only the session
  calendar; `ledgr_walk_forward_pulse_calendar()` reads every fact table for
  the same calendar.
- **Per-pulse waste.** P1 copies five unread packet fields for the current
  and next session every pulse (R6).

## 4. Execution-mode branches

The codebase census (`tools/check-codebase-contracts.R`) now records every
execution-mode switch site in `R/` per file and function:
`dev/bench/v0_2_2_pre_cran_removal/census/mode_branches.csv` (one row per
site, keyed by file, function, kind, switch and context, without line
numbers) and `mode_branch_counts.csv` (per-file totals). Check mode fails
when the source has a site the committed record lacks, or the record keeps a
site the source no longer has, so adding or removing a branch changes the
record visibly. LTB-0331 runs the same comparison in the fast profile.

On `b9d098c8` the census finds 213 sites in 55 functions across 29 files: 158
`branch` sites (an `if` or `ifelse` on a switch) and 55 `flow` sites (a switch
passed on or assigned). The switch forms are `availability_active` (and the
`$availability_active` field), `availability$active`,
`ledgr_availability_config_active()`, `ledgr_backtest_availability_active()`,
`is.null(history_substrate)` and `is.null(availability_provider)`, and
function-local aliases such as `use_fast_context`, `dispositions_active`,
`allow_empty` and `use_fold_equity`.

| File | Functions | Branch sites | Flow sites |
| --- | --- | --- | --- |
| `R/fold-engine.R` | 5 | 42 | 5 |
| `R/backtest-runner.R` | 2 | 26 | 12 |
| `R/sweep.R` | 4 | 24 | 4 |
| `R/strategy-helpers.R` | 3 | 11 | 8 |
| `R/walk-forward.R` | 4 | 6 | 0 |
| `R/availability-policy.R` | 3 | 4 | 5 |
| `R/experiment.R` | 2 | 4 | 0 |
| `R/precompute-features.R` | 4 | 4 | 3 |
| `R/run-finalize.R` | 1 | 4 | 2 |
| `R/derived-state.R` | 1 | 3 | 2 |
| `R/strategy-types.R` | 2 | 3 | 2 |
| `R/walk-forward-folds.R` | 3 | 3 | 0 |
| `R/availability-results.R` | 2 | 2 | 1 |
| 16 further files | 19 | 22 | 11 |

The one semantic branch bound by Cut 16 decision (16) is the walk-forward
`is.null(history_substrate)` split (`ledgr_walk_forward_continue_windows()`
and `ledgr_walk_forward_eval_fold()`). Every other site selects the dense or
availability arm of a representation, validation or rule that dense mode
keeps frozen. Removal belongs to
the execution-core consolidation (macro plan), which should start from this
record and Section 1's dense rows (R11, R28). Workstream 43 removed four
sites (one in `ledgr_config()`, one in `ledgr_run_fold_impl()`, two in
`ledgr_precompute_payload()`) and added none; the merge `804e9be2`
regenerated the record in report mode with that stated reason, and check
mode then passed.

## 5. Finalization against the accepted Workstream 43 tree

Every entry the draft marked for Workstream 43 was re-read on `b9d098c8`:

- R2 and R7: feature preparation reads each instrument's prefix of the bar
  planes directly; R7's only remaining caller is the unread provider history
  reader, so R7 joins the Section 3 unread list.
- R24, R25 and R29: payload and projection carry sparse evidence records;
  reads derive aligned evidence planes at their cutoff; a dense per-instrument
  implementation of the same columns (R29b) survives as a test oracle.
- R27, R32 and R33: sizes re-measured (one to two percent larger with the
  evidence records).
- R34: the indicator catalogue Workstream 43 added is rebuilt per
  constructor (LDG-3077).
- L-5, L-8, T-2 and C-4: feature inputs call the whole-prefix mask, the
  terminal planes and the carry rule per instrument range; late-epoch
  detection exists twice and the feature-side copy is a hashed engine helper.
- Section 4: 213 sites (four fewer than the draft) after the merge.

## 6. Implications for the next tickets

- LDG-3075 can remove R12a-d, derive R4-R5 at the `ctx$bars` boundary, drop
  R33 from the staged invariant, and keep one form of each fact family (the
  diagonal is a read of the two-clock segments, or segments are dropped for
  families no read uses), with LTB-0291's plane assertions changed under a
  stated reason. The structural detector it owes should fail if a second
  fact form or a removed plane returns.
- LDG-3076 replaces M-3, M-4 and M-6 with the per-instrument compiler M-5
  generalized to headers, keeping M-3 only under the fast-path rule. The
  same rule asks S-4 and L-3 to justify themselves or merge.
- Execution-core consolidation removes R11, R28's dense views and the 213
  census sites' dense arms.

## 7. Workstream 46 changes

Recorded per ticket in `history_simplification_closeout.md`; this section
keeps the map's rows current.

Removed by LDG-3075 (results byte-identical to `b9d098c8`):

- R4 and R5 (`gap_type`, `is_synthetic` planes): `ctx$bars` derives both
  from `observed` in `ledgr_history_bar_packet_frame()`.
- R6: the packet carries `ts_utc`, `instrument_id`, OHLCV and `observed`.
- R7, R8 and the provider `history` member on all three provider builders
  (R9's closure, R14's substrate reader and R10's portable closure).
- R12a-d with S-5 and L-7 (`ledgr_history_segments_diagonal_state()`).
- R17's `families`, `universe_rule` and `valuation_policy` fields; the
  substrate's family declaration and membership completeness are the
  provider plan's `families` and `membership$header_complete`.
- The duplicate `provider_plan$sessions`; the provider takes the
  substrate's `sessions`.
- R33 and the `precomputed_features` argument of the candidate task,
  candidate execution and candidate run functions.
- Sessions-only readers (derived state, `ledgr_run_open()` for INCOMPLETE
  runs, window pulse validation R10, `ledgr_walk_forward_pulse_calendar()`)
  read the session table through `ledgr_availability_session_source()` and
  compile no provider; R10's provider is gone (its bar fetch and alignment
  stay, unchanged).

At H1 the substrate falls from 720.6 MB object / 737.4 MB serialized to
495.3 / 477.1 and the staged invariant from 855.2 / 869.9 (fresh) and
1,121.0 / 1,133.6 (precomputed) to 629.8 / 609.7 for both
(`dev/bench/v0_2_2_history_simplification/evidence/representation_sizes_h1_ldg3075.csv`).

Cut 16 decision (22) (2026-10-19, on the LDG-3075 NEEDS_TYPE_2): membership
and trading-status segments are counted, not stored. LDG-3075 then removed
the stored membership and trading-status segments (R16's first two
families; 81.8 MB object / 48.3 MB serialized at H1) and the compilers that
only built them: M-3, M-4 and M-6 (with the header applier M-3 used), the
membership dispatcher and the status wrapper. The substrate keeps
`segment_counts` (per instrument: fact count, segment count, ratio, limit)
for the guard and the census. Membership counts come from the facts the
provider plan holds: the complete-set, interval-only and lagged cases by
counting, for each fact, the contiguous axis blocks it wins when it becomes
known (`ledgr_history_membership_fact_counts()`), the same-clock case from
the plan's prepared resolver at each break
(`ledgr_history_membership_diagonal_counts()`). Status counts run the shared
one-fact and per-instrument compilers (S-4, S-2, also used by L-3 and L-2)
without keeping their output. LTB-0335 compares every count and refusal with
frozen copies of the BASE compilers. With them the substrate is 413.5 /
428.8 MB at H1 and the staged invariant 548.0 / 561.4 MB
(`representation_sizes_h1_decision22.csv`).

LDG-3076: M-1 (canonical resolver), M-2 (cursor), S-1 to S-4 and the
lifetime and terminal compilers remain; LTB-0334 and LTB-0335 are their
differentials. Incomplete lagged counting at 20, 40 and 80 sets by 300
instruments takes 0.01 to 0.09 s against 0.78, 3.82 and 22.2 s for M-6 on
BASE.

LDG-3077 builds R34 once per session (`ledgr_indicator_catalogue_index()`)
and looks rows up by key; the catalogue function body, and therefore the
feature-engine digest, is unchanged.

Routed, not changed by Workstream 46: R27 (features held twice inside the
public precomputed object; a public-object change); L-8's merge (it moves
the feature-engine digest); C-1/C-2's merge; R29b (a test oracle).
