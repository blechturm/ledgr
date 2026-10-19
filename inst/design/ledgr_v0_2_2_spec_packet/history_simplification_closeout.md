# Cut 16 Workstream 46 closeout: history representation simplification

Commits on `ws46/history-simplification`: `d4d13c55` (LDG-3074 draft),
merge `804e9be2` (accepted Workstream 43), `69543182` and `72f496e7`
(LDG-3074 finalization), `5ee67009` (LDG-3075 without the segment item,
and the LDG-3076 differential), `4a9b93cf` (LDG-3077) and the evidence
commit that adds this record.

Role: record; Workstream 46 implementation evidence.
Authority: non-binding. `tickets.yml` owns status and `contracts.md` owns
behavior; `history_representation_map.md` is the work list.
Status: blocked on one maintainer question (NEEDS_TYPE_2 below). LDG-3074
and LDG-3077 are complete. LDG-3075 is implemented except the deletion of
the membership and trading-status history segments, and LDG-3076 depends on
that decision; both stay open. Workstream 46 is not yet ready for its close
review.

BASE for every byte-identity claim is `b9d098c8`, the integration merge of
the accepted Workstream 43. Product code on this branch equals BASE up to
`804e9be2`.

## Necessity and scope

Cut 16 decision (17) asks Workstream 46 to map every history representation,
hold each fact once, drop unread substrate planes and leave one membership
compiler before Workstream 44 measures and proves the system. The map
(`history_representation_map.md`, LDG-3074) found that on BASE the fold reads
facts only through the provider plan, that six of eight bar and diagonal
planes have no product reader or restate another plane, that several helpers
and fields are unread, and that precomputed sweeps stage their features
three times. LDG-3075 removes those items without semantic change; LDG-3077
removes the per-constructor catalogue rebuild routed at the Workstream 43
acceptance.

## LDG-3074: map, census and fast-path rule

| Acceptance item | Record | Result |
| --- | --- | --- |
| The map lists every representation and resolution path on the accepted Workstream 43 tree, with owner, consumers and status, linked from the packet README | `history_representation_map.md` Sections 1, 2 and 5; README Start here row | 38 representations and 30 paths re-read on BASE; every draft `[WS43]` entry resolved (Section 5); sizes re-measured on a `git archive` copy of BASE (`representation_sizes_h1_b9d098c8.csv`) |
| The census records per-file execution-mode branch counts and its self-test fails when a branch is added | `tools/check-codebase-contracts.R`, `mode_branches.csv`, `mode_branch_counts.csv`, LTB-0331 | 213 sites (158 branch, 55 flow) in 55 functions across 29 files after the Workstream 43 merge; `--mode=check` and `--self-test-mode-branches` pass; the five census-README mutations each fail LTB-0331 (draft evidence, unchanged) |
| The style manual states the fast-path rule and the Cut 16 briefs reference it | `optimization_coding_style.qmd` Rules, Maintainer Checklist, Source Links; macro plan H5 amendment; LDG-3076 scope; the Workstream 46 brief | Present |

## LDG-3075: hold each fact once and drop unread planes

Every item was checked against the map on BASE by reading its callers, not
by name search alone, and removed only when no product path reads it:

| Item (map row) | Product readers on BASE | Change |
| --- | --- | --- |
| `expected`, `halted`, `missing_expected_bar`, `inactive_print` (R12a-d, S-5, L-7) | copied into every P1 packet, read by nothing | removed with `ledgr_history_segments_diagonal_state()`; the packet no longer carries them |
| `gap_type`, `is_synthetic` bar planes (R4, R5) | only the `ctx$bars` frame | removed; `ledgr_history_bar_packet_frame()` derives `gap_type` as `"NONE"` where `observed` and `"MISSING_EXPECTED_SESSION"` elsewhere, and `is_synthetic` as `FALSE`, which is exactly what every substrate bar source wrote (the runner selects constant `'NONE'`/`FALSE`; the precompute fetch selects neither) |
| Packet `observed` (R6) | none before; now the `ctx$bars` derivation | kept |
| `ledgr_history_substrate_bar_frame()` (R8) | none (the census's one `uncalled_private` finding) | removed |
| Provider `history` member (R14 via R7; R9's DB closure; R10's portable closure) | none | removed from `ledgr_availability_provider_from_plan()`, `ledgr_availability_provider()`, `ledgr_availability_provider_build[_prepared]()`; `ledgr_history_substrate_instrument_frame()`, `ledgr_history_substrate_history_reader()` and `ledgr_availability_provider_portable()` removed |
| Substrate `families`, `universe_rule`, `valuation_policy` (R17) | none (tests read `families`) | removed; family declaration and membership completeness remain on the substrate as `provider_plan$families` and `provider_plan$membership$header_complete`, which v12 Section 7's "family declaration and completeness apart from individual fact rows" continues to describe |
| `provider_plan$sessions` (R14) | the provider's `sessions` | dropped from the stored plan; `ledgr_availability_provider_from_substrate()` passes `substrate$sessions` |
| `precomputed_features` in tasks and the staged invariant (R33) | none: passed through `ledgr_sweep_eval_candidate_task()`, `ledgr_sweep_run_candidate()` and `ledgr_sweep_candidate_execution()` and never read | removed from the task, the invariant field list and the three signatures; pulse inspection no longer passes `NULL` |
| Full plan compiled for a calendar (R15, R10, R13) | derived-state rebuild (twice), `ledgr_run_open()` for INCOMPLETE runs, window pulse validation, `ledgr_walk_forward_pulse_calendar()` | each reads the session table through the new `ledgr_availability_session_source()`; `ledgr_run_open()` keeps its eager `ledgr_snapshot_ensure_verified()` call. Window validation's `ledgr_precompute_snapshot_meta()` argument was a lazy promise the provider only forced inside `identity()`, which validation never calls, so it is dropped without removing a check that ran |
| Membership and trading-status segments (R16, M-3 to M-7, S-2, S-4) | none in production, but see NEEDS_TYPE_2 | **not removed**: blocked |

No execution-mode branch site was added or removed: census check mode passes
with 158 branch and 55 flow sites; only the helper, condition, connection,
version and test-only-seam tables move with the removed helpers (findings 73
to 72: the `uncalled_private` bar-frame finding is gone).

### Acceptance status

| Acceptance item | Record | Result |
| --- | --- | --- |
| Run, sweep, window, walk-forward, inspection and history-read results byte-identical to BASE; fixture ladder exact; full suite passes | Byte-identity runner and fixture ladder below; verification record | 62 of 62 families identical; ladder 50 of 50 plus identity; full suite: see Verification record |
| A structural detector fails if a second fact representation or a removed plane returns | LCL-0322/LTB-0332 | Fails on every restored plane, field, packet field, provider history member, staged `precomputed_features`, removed helper and session-only reader that builds a provider (mutations M1-M10). The "second fact representation" half is open with the segment decision |
| Substrate and staged-invariant size at H1 before and after | Sizes below | Substrate 720.6 to 495.3 MB object (737.4 to 477.1 serialized); staged invariant 855.2 to 629.8 (fresh) and 1,121.0 to 629.8 (precomputed) |
| Seven shapes walked on changed preparation code | Seven-shape walk below | Walked |
| Each removed item absent from package code and guarded; changed tests with reasons | LTB-0332; Test changes below | Done for every removed item; the segment item is open |

## LDG-3076: compilers that remain

On BASE and on this branch, every fact compiler is reached from production
through `ledgr_history_substrate()` (runner, `ledgr_history_substrate_for_experiment()`
for sweeps, walk-forward, explicit precompute and pulse inspection) or
through `ledgr_availability_provider_prepare()` (the substrate and the
store-built provider of the availability results reader):

| Family | Two-clock compilers (substrate segments) | Diagonal compiler (provider plan, read by the fold) |
| --- | --- | --- |
| Membership | M-3 complete-set, M-4 same-clock, M-5 interval-only, M-6 family-wide epoch (superlinear) | M-2 prepared cursor |
| Trading status | S-2 per-instrument, S-4 sparse | S-3 |
| Lifetime | L-2 per-instrument, L-3 sparse | L-4 |
| Terminal | T-1 per-instrument | L-4 plane 2 |

Whether M-3 to M-6, S-2 and S-4 remain depends on the NEEDS_TYPE_2 decision:
deleted with their segments under option A, or M-6 replaced by one
per-instrument compiler with measurements under option B. Until then the
ticket stays open. Its decision-independent part is done: LCL-0324/LTB-0334
is a registered randomized differential of the compilers that survive every
option against their canonical resolvers: L-2 and L-3 two-clock lifetime
(state, winner and reason) and T-1 terminal segments against
`ledgr_history_lifetime_resolve_applicable()` at every observation and at
cutoffs on, between and after sessions; the diagonal plan's lifetime state,
terminal label and winner (L-4) and status (S-3) against the canonical
lifetime and status rules (S-1); and the prepared membership cursor (M-2)
against `ledgr_membership_resolve_prepared()` for random complete,
incomplete and lagged headers mixed with interval rows, read forward,
backward and shuffled. Thirty random families; no mismatch.

## LDG-3077: indicator catalogue built once

`ledgr_indicator_catalogue_row()` reads `ledgr_indicator_catalogue_index()`,
which builds the catalogue once per R session into
`.ledgr_indicator_catalogue_cache` (the catalogue and a key-to-row index) and
looks rows up by `source`, `family`, `output` and `variant`; a key held by
more than one row resolves to no row, as the logical match always did. The
body of `ledgr_indicator_history_catalogue()` is unchanged, so the hashed
feature-engine helper and the engine digest
(`4b2bb8e6989d77ef7fdd4fd2c0738340e97786724826951af1ddb47cb2a005a9` for
availability) are unchanged.

| Acceptance item | Record | Result |
| --- | --- | --- |
| Built at most once per session; content byte-identical to the Workstream 43 catalogue | LTB-0333; catalogue check below | Catalogue, every row lookup (all 48 keys plus three misses) and nine constructed indicators serialize identically on BASE and candidate |
| Constructors, declarations, fingerprints and rule-4 identity unchanged; engine digest unchanged or changed only with reason | catalogue check | Active fingerprints of the nine indicators and both engine digests identical; no digest literal changed |
| A detector fails if a constructor rebuilds the catalogue | LCL-0323/LTB-0333 | Mutations N1 and N2 fail it |
| Fast profile measured under the recorded timing method with before/after block times for LTB-0142 and LTB-0143 | Timing below | LTB-0142 2.76 s to 0.97 s and LTB-0143 0.80 s to 0.17 s (medians of five alternating runs); the profile itself is the coordinator's quiet-host run |

## Byte-identity runner

The runner is scratch-only (not committed): `run_identity.R`,
`fixtures.R` and `check_identity.R` in the session scratchpad. It loads one
tree with `pkgload::load_all()`, builds four vendor-neutral snapshots
through the public fact constructors and records 62 families:

- Fixture A (ten instruments, 45 sessions): incomplete set headers with
  lagged knowledge (the family-wide epoch compiler), multi-fact trading
  status, a late-known delisting followed by a relisting, a late-known
  inactive interval, a bankruptcy terminal, missing bars and a dividend.
  Fixture B: complete sets only, one status and one lifetime fact per
  instrument (complete-set and sparse compilers). Fixture C: lagged interval
  rows only (interval compiler). Fixture D: same-clock incomplete headers
  (diagonal compiler).
- Seven features: SMA, EMA, RSI and returns built-ins, TTR SMA, TTR BBands
  `up` and a custom range indicator.
- Per fixture: `ledgr_run()` (every result table, metrics, run info with
  database paths scrubbed, `ledgr_state_reconstruct()` and a reopened run),
  `ledgr_sweep()` with promotion, explicit precompute plus a precomputed
  sweep, `ledgr_run_window()`, `ledgr_sweep_window()`, carried and flat
  walk-forward, four inspected pulses and direct two-clock mask and terminal
  reads at five out-of-order cutoffs. Fixture A also runs two-worker sweeps
  (fresh and precomputed) and a two-worker walk-forward, and a second policy
  (`price_carry = NULL`, `output_carry = 2`).
- Two INCOMPLETE runs (fixtures A and B under `ledgr_valuation_stale(0,
  exhausted = "refuse")`) reach `ledgr_run_open()`'s INCOMPLETE path and the
  derived-state rebuild of a stopped run.
- The strategy records, at every pulse of every in-process run, the context
  data fields (including `ctx$bars` with `gap_type` and `is_synthetic`),
  wide, long, drop-instrument and admissible bar frames, seven feature
  frames, a long feature frame, `ledgr_history_matrix()` and two
  `ledgr_history_sufficient()` answers.

`check_identity.R` compares each family by the bytes of `serialize()`; its
self-test perturbs each family alone and detects 62 of 62. Before any
product change, a run of the unchanged branch head agreed with a BASE run on
every family (58 families then; the two INCOMPLETE scenarios were added
later and BASE was re-recorded), after volatile columns (timings, creation
and promotion times, database paths) were dropped. Result on the final
candidate (the committed LDG-3075 and LDG-3077 tree): 62 of 62 families
identical, no family retried; checker self-test 62 of 62. A product
mutation that makes `ctx$bars$gap_type` `"NONE"` everywhere makes the runner
report 11 in-strategy and inspection families as different (Mutation table).

The registered fixture ladder (`dev/bench/v0_2_2_real_data_scale`, 800
instruments, 1,260 sessions, 300 members, ten phases) ran on the BASE copy
and on the candidate with `--allow-dirty`, twice (the first LDG-3075 tree
and the final tree): each time 50 of 50 gated families identical and the
identity family identical; the recorder self-test detects 51 of 51.

## Sizes (H1 shape)

`representation_sizes.R` on the same H1 snapshot (1,166 instruments by
7,213 sessions, 580 complete sets), BASE copy against candidate; MB, object /
serialized:

| Representation | BASE `b9d098c8` | Candidate |
| --- | --- | --- |
| Substrate, no features | 720.6 / 737.4 | 495.3 / 477.1 |
| Substrate, one feature bound | 788.4 / 803.8 | 563.1 / 543.5 |
| Bar planes | 8 planes, 449.4 / 483.6 | 6 planes, 353.1 / 353.1 |
| Diagonal planes (R12a-d) | 128.4 / 128.4 | absent |
| Provider plan | 59.5 / 75.5 | 58.8 / 74.1 |
| Staged invariant, fresh sweep | 855.2 / 869.9 | 629.8 / 609.7 |
| Staged invariant, precomputed sweep | 1,121.0 / 1,133.6 | 629.8 / 609.7 |
| Membership plus status segments (pending) | 81.8 / 48.3 | 81.8 / 48.3 |

The substrate shrinks by 31 percent (object) and 35 percent (serialized);
the staged invariant by 26 and 30 percent for a fresh sweep and 44 and 46
percent for a precomputed one. Deleting the membership and status segments
would remove a further 81.8 / 48.3 MB. Records:
`dev/bench/v0_2_2_history_simplification/evidence/representation_sizes_h1_b9d098c8.csv`
and `representation_sizes_h1_ldg3075.csv`, with logs.

## Timing (LDG-3077)

Method: High performance power plan; the PowerShell process pinned to the
performance cores (`ProcessorAffinity = 0xFFFF`) before calling
`Rscript.exe` by full path; BASE copy and candidate alternating, five runs
each, no other R process at the start; each run loads its tree and runs
`test-strict-feature-acceleration.R`, and the block times are testthat's
per-block elapsed times. Medians (ranges): LTB-0142 BASE 2.76 s
(2.74-2.81), candidate 0.97 s (0.94-1.00); LTB-0143 BASE 0.80 s
(0.78-0.82), candidate 0.17 s (0.16-0.18). The fast, review and heavy
profiles were not run here.

## Seven-shape walk

Changed preparation code: `ledgr_history_substrate()`,
`ledgr_history_substrate_bar_matrices()`, `ledgr_history_substrate_bar_packet()`,
`ledgr_history_bar_packet_frame()`, the provider builders,
`ledgr_availability_session_source()`, the sweep task builders and
`ledgr_indicator_catalogue_row()` / `ledgr_indicator_catalogue_index()`.

1. One-row frame per element: none added. The catalogue rebuild was a
   one-row `data.frame()` per catalogue row bound with `rbind` on every
   constructor call; it now runs once per session.
2. Full-table subset inside a loop over ids: the catalogue lookup was a
   logical subset of the whole catalogue per constructor; it is now one
   indexed read through a named index built once.
3. Per-element parsing or formatting: none added.
4. Per-row JSON: none.
5. Work computed and discarded: removed in four places (the diagonal planes
   and their per-instrument, per-segment R loop in
   `ledgr_history_segments_diagonal_state()`; five unread packet fields
   copied twice per pulse; the restating planes; the full provider plan
   compiled to read a calendar). The `ctx$bars` derivation is one vector index
   per pulse over the context's instruments.
6. Quadratic validators: none.
7. Scalar writes into an environment-held vector: none; the catalogue cache
   is assigned once.

## Test changes and reasons

No behavioral oracle changed. Each change below follows a removed structure:

- LTB-0291 (`test-history-substrate.R`): the assertions on
  `substrate$halted`, `missing_expected_bar`, `inactive_print`, `expected`
  and `families` read structures LDG-3075 removes. The same literal cells are
  now read from the forms production uses (the provider diagonal for halted
  at AAA session 4; the two-clock lifetime mask with `observed` for the
  missing and inactive-print cells and for the path fixture's
  `c(TRUE, TRUE, TRUE, FALSE)` / `c(FALSE, TRUE, FALSE, FALSE)` literals; the
  plan's `families` and `header_complete`), and a structural check fails if
  any removed field returns. The literal expected values are unchanged.
- LTB-0285 and LTB-0288 (`test-history-foundation.R`), the provider witness
  helper and the query-order block (`helper-availability-v0-2-0-1-witnesses.R`,
  `test-availability-provider-witnesses.R`): the stub fourth argument
  (`function(...) NULL` or a refusing stub) for the removed `history`
  parameter is dropped. Oracles unchanged.
- `provider resolves facts only after effective and knowledge time`
  (`test-availability-causality.R`, unregistered): the expected provider
  names drop `history`, which now acts as the detector, and the row count of
  the removed closure is no longer asserted.
- `availability marks use one query and preserve the prefix oracle`
  (`test-workstream8-exact-parity.R`, unregistered): the oracle read closes
  through `provider$history`; it now runs the same SQL in a test helper
  (`workstream8_bar_history()`), so the oracle's input is unchanged.
- `INCOMPLETE reopen builds one prepared provider plan`
  (`test-availability-provider-production.R`, unregistered): it counted
  provider-plan compilations and expected exactly one when an INCOMPLETE run
  is reopened. LDG-3075's scope removes that compilation (the reopen needs
  only the session calendar), so the expected count becomes zero; the run
  half of the block (one plan per run) is unchanged. This is the only
  failure the first complete full-suite run on the candidate reported
(1,143 blocks; the run before it stopped at the stale shared library noted
under Routed).
- New: LCL-0322/LTB-0332 (fast), LCL-0323/LTB-0333 (fast), LCL-0324/LTB-0334
  (review).

## Mutation table

Each mutation was applied to one file of a source copy made with
`git ls-files -z | tar --null -T - -cf - | tar -xf - -C <copy>`, the named
block run in a fresh R process, and the file restored byte for byte.

"Failed" counts failing expectations in the block (testthat `failed`); no
mutation made the block error.

| ID | Mutation | File | Block | Result |
| --- | --- | --- | --- | --- |
| M0 | none (unmutated copy) | - | LTB-0332, LTB-0333, LTB-0334 | 30, 6 and 91 expectations, none failed |
| M1 | restore a diagonal plane field (`halted`) on the substrate | `R/history-substrate.R` | LTB-0332 | fails (1) |
| M2 | restore the `gap_type` bar plane | `R/history-substrate.R` | LTB-0332 | fails (1) |
| M3 | keep the provider plan's duplicate session calendar | `R/history-substrate.R` | LTB-0332 | fails (1) |
| M4 | copy the unread `expected` plane into the per-pulse packet again | `R/history-substrate.R` | LTB-0332 | fails (1) |
| M5 | derive `ctx$bars` `gap_type` as `"NONE"` for every cell | `R/history-substrate.R` | LTB-0332 | fails (1) |
| M6 | restore a provider `history` member | `R/availability-provider-prepared.R` | LTB-0332 | fails (1) |
| M7 | restore `ledgr_history_substrate_bar_frame()` | `R/history-substrate.R` | LTB-0332 | fails (1) |
| M8 | stage `precomputed_features` in the invariant again | `R/sweep.R` | LTB-0332 | fails (1) |
| M9 | rebuild a full provider for the derived-state calendar | `R/derived-state.R` | LTB-0332 | fails (1) |
| M10 | read every fact table for the walk-forward pulse calendar | `R/walk-forward-folds.R` | LTB-0332 | fails (2) |
| N1 | look catalogue rows up in a freshly built catalogue | `R/indicator-history.R` | LTB-0333 | fails (3) |
| N2 | never store the built catalogue | `R/indicator-history.R` | LTB-0333 | fails (3) |
| P1 | sparse compiler writes the wrong reason (L-3) | `R/history-substrate.R` | LTB-0334 | fails (13) |
| P2 | per-instrument compiler applies only the first knowledge epoch (L-2) | `R/history-substrate.R` | LTB-0334 | fails (14) |
| P3 | terminal segments never report an asserted terminal (T-1) | `R/history-substrate.R` | LTB-0334 | fails (22) |
| P4 | diagonal plan ranks lifetime facts by row order only (L-4) | `R/availability-provider-prepared.R` | LTB-0334 | fails (5) |
| P4b | diagonal plan lets the earliest lifetime fact win (L-4) | `R/availability-provider-prepared.R` | LTB-0334 | fails (7) |
| P5 | prepared membership cursor treats every header as complete (M-2) | `R/availability-provider-prepared.R` | LTB-0334 | fails (24) |
| P6 | diagonal status plan ignores precedence (S-3) | `R/availability-provider-prepared.R` | LTB-0334 | fails (7) |

P4 first survived: the lifetime constructor sorts rows by effective time, so
row order equalled rank. LTB-0334 now shuffles the lifetime rows (row order
is the resolver's last tie-break) and P4 fails; P4b was added as the plain
reversal.

The byte-identity runner was also mutation-checked at product level: with M5
applied to the copy and the two-worker scenarios skipped (`--no-parallel`),
11 of the 59 recorded families differ: the in-strategy reads of all seven
scenarios and the inspected pulses of four (fixture C's inspected families
are unchanged, presumably because its four inspected pulses have no missing
bar).

## NEEDS_TYPE_2: membership and trading-status segments

The amended LDG-3075 scope says to delete the membership and trading-status
history segments because no production path reads them. On BASE that holds
for reads, but the segments are also:

1. the stored form `contracts.md` binds in present tense ("Prepared
   membership, trading-status and lifetime state is stored as flat
   bitemporal segments over separate observation and knowledge clocks",
   Availability Provider, Knowledge And Timing) and v12 Section 7 requires
   ("flat bitemporal segment vectors per instrument and fact-state family;
   active, inactive, unknown and conflicting membership states"), and Cut 16
   decision (17) says Workstream 46 "compiles membership segments on one
   per-instrument path"; and
2. the only input of the segment guard for those two families ("Preparation
   counts segments for every instrument and family ... raises
   `ledgr_history_segment_limit_exceeded`"; v12 Section 7; LDG-3070 and H6
   report the guard by family). Deleting them changes behavior: an
   experiment whose membership or status segments exceed a declared
   `ledgr_history_policy(segment_limit = k)` (or the default
   `max(4 * facts, 16)`) is refused on BASE and would run after deletion. That
   is not byte-identical, so it conflicts with LDG-3075's "No semantic
   change".

Options for the maintainer:

- **A. Delete as amended.** The guard covers lifetime and terminal only; the
  contract clause, the condition reference, v12 Section 7's receiver and the
  LDG-3070/H6 census wording change, and the refusal change is recorded as a
  decision. LDG-3076 then has no membership or two-clock status compiler on
  a production path and closes with LTB-0334 plus a removal detector.
- **B. Keep both segment families.** Facts stay held twice for membership
  and status (81.8 / 48.3 MB at H1); LDG-3076's original scope applies (M-6
  is on the production path and is replaced by one per-instrument compiler
  with before/after measurements and a return detector; M-3, M-4, S-4 justify
  themselves under the fast-path rule or merge).
- **C. Count without storing.** Keep the guard by counting each instrument's
  segments during preparation and drop the stored vectors; the contract
  changes from "stored" to "counted". The count needs the same compilation,
  so it depends on LDG-3076's per-instrument compiler to be linear.

## Routed, not changed here

- R27: `ledgr_precompute_features()` holds each feature twice (projection
  and payload). A public-object change; not in the amended LDG-3075 list.
- L-8: one late-epoch helper for reads and features. Merging moves the
  feature-engine digest because `ledgr_history_feature_ranges()` is hashed;
  it needs a stated identity change.
- C-1/C-2: two implementations of the carry rule (vector and matrix).
- R29b: the dense feature-evidence frame survives only as a test oracle.
- Observation (pre-existing, not a Workstream 46 change): parallel mirai
  daemons each call `pkgload::load_all()` with the default `compile = NA` on
  the source tree. When the shared library is stale, two daemons compiled
  into the same `src/` at once here: the first two-worker scenario failed
  with "there is no package called 'ledgr'" and the resulting `ledgr.dll`
  later crashed R in `compiled spot FIFO validates scalar state argument
  types` until it was rebuilt cleanly. This affects only source-tree
  development runs; the runner retried such a failure once and disclosed it.
- The store-built and substrate-built providers keep an unforced promise
  (`history_substrate_version`) that references the substrate; a serialized
  provider is still 702 MB at H1 (1,701 MB on BASE). Providers are never
  serialized in production.

## Verification record

On the product tree committed as `4a9b93cf`, Windows 11, R 4.6.1, run
sequentially unless noted:

- Full suite (`pkgload::load_all('.'); testthat::test_local('.', reporter =
  'summary', stop_on_failure = FALSE, load_package = 'none')`): 1,144 blocks,
  17,824 expectations, no failure or error, one optional skip
  (`ledgr_snapshot_from_yahoo requires quantmod`, quantmod is installed);
  650 s of block time.
- Byte-identity runner against BASE: 62 of 62; self-test 62 of 62.
- Fixture ladder against BASE: 50 of 50 plus identity; self-test 51 of 51.
- `tools/check-codebase-contracts.R --mode=check`: OK, 158 branch and 55
  flow sites in 55 functions across 29 files, findings 72;
  `--self-test-mode-branches`: OK.
- `tools/check-fold-phase-contract.R .`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.
- `tickets.yml` and `tests/claims.yml` parse with `yaml::read_yaml()`;
  `git diff --check b9d098c8` is clean (69543182 added a size log with
  trailing spaces; 72f496e7 strips them).
- Not run here: the fast, review and heavy timed profiles (the
  coordinator's quiet-host runs) and `R CMD check`.
- Disclosure: the BASE size measurement overlapped another of this
  session's R processes; sizes do not depend on load. The first full-suite
  attempt stopped inside `test-execution-spec.R` on a stale shared library
  (Routed); after a clean `pkgbuild` rebuild of `src/` the runs above
  passed. `R/cpp11.R` and `src/cpp11.cpp` show line-ending churn only and
  are not committed.
