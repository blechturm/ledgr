# Cut 16 Workstream 46 closeout: history representation simplification

Commits on `ws46/history-simplification`: `d4d13c55` (LDG-3074 draft),
merge `804e9be2` (accepted Workstream 43), `69543182` and `72f496e7`
(LDG-3074 finalization), `5ee67009` (LDG-3075 without the segment item,
and the LDG-3076 differential), `4a9b93cf` (LDG-3077), `7b09f095` (first
evidence record with the NEEDS_TYPE_2), then the Cut 16 decision (22)
implementation and evidence commits named in `tickets.yml`.

Role: record; Workstream 46 implementation evidence.
Authority: non-binding. `tickets.yml` owns status and `contracts.md` owns
behavior; `history_representation_map.md` is the work list.
Status: LDG-3074 to LDG-3077 are complete. The LDG-3075 NEEDS_TYPE_2 was
decided by the maintainer on 2026-10-19 as Cut 16 decision (22): membership
and trading-status segments are counted, not stored. The close review
(`close_review_46.md`) returned CHANGES_REQUIRED; Correction 1 at the end of
this record answers it, implementing Cut 16 decisions (23) and (24).
Focused re-review 1 (`close_review_46_rereview_1.md`) returned
CHANGES_REQUIRED with no product defect; Correction 2 answers it.
Workstream 46 is `review_pending`.

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
| Membership and trading-status segments (R16) and the compilers that only built them: `ledgr_history_segments_build()` (M-6), `ledgr_history_membership_complete_segments()` (M-3) with `ledgr_membership_apply_prepared_header()`, `ledgr_history_membership_diagonal_segments()` (M-4), `ledgr_history_membership_segments()` and `ledgr_history_status_segments()` | none in production; the segment guard and `ledgr_history_substrate_census()` read their counts | removed under Cut 16 decision (22); the substrate keeps `segment_counts` (per instrument fact count, segment count, ratio and limit for each family) and the guard refuses exactly as before (Decision 22 below) |

No execution-mode branch site was added or removed: census check mode passes
with 158 branch and 55 flow sites; only the helper, condition, connection,
version and test-only-seam tables move with the removed and added helpers
(findings 73 to 72: the `uncalled_private` bar-frame finding is gone).

### Acceptance status

| Acceptance item | Record | Result |
| --- | --- | --- |
| Run, sweep, window, walk-forward, inspection and history-read results byte-identical to BASE; fixture ladder exact; full suite passes | Byte-identity runner and fixture ladder below; verification record | 84 of 84 families identical, including run, sweep and inspection refusals at declared segment limits; ladder 50 of 50 plus identity; full suite passes |
| A structural detector fails if a second fact representation or a removed plane returns | LCL-0322/LTB-0332 | Fails on every restored plane, field, packet field, provider history member, staged `precomputed_features`, removed helper, session-only reader that builds a provider, stored membership or status segment family and removed compiler (mutations M1-M13) |
| Substrate and staged-invariant size at H1 before and after | Sizes below | Substrate 720.6 to 413.5 MB object (737.4 to 428.8 serialized); staged invariant 855.2 to 548.0 (fresh) and 1,121.0 to 548.0 (precomputed) |
| Seven shapes walked on changed preparation code | Seven-shape walk below | Walked |
| Each removed item absent from package code and guarded; changed tests with reasons | LTB-0332; Test changes below | Done |

## LDG-3076: compilers that remain

On BASE every fact compiler was reached from production through
`ledgr_history_substrate()` (runner, `ledgr_history_substrate_for_experiment()`
for sweeps, walk-forward, explicit precompute and pulse inspection) or
through `ledgr_availability_provider_prepare()` (the substrate and the
store-built provider of the availability results reader):

| Family | Two-clock compilers (substrate segments) | Diagonal compiler (provider plan, read by the fold) |
| --- | --- | --- |
| Membership | M-3 complete-set, M-4 same-clock, M-5 interval-only, M-6 family-wide epoch (superlinear) | M-2 prepared cursor |
| Trading status | S-2 per-instrument, S-4 sparse | S-3 |
| Lifetime | L-2 per-instrument, L-3 sparse | L-4 |
| Terminal | T-1 per-instrument | L-4 plane 2 |

After Cut 16 decision (22) the membership compilers M-3, M-4 and M-6 are
gone (M-5 was a membership use of the shared per-instrument compiler, which
stays for lifetime, terminal and status counts). What remains, with its
production caller and differential:

| Path | Production caller | Differential |
| --- | --- | --- |
| M-1 canonical resolver | public `ledgr_facts_resolve()` for membership (through `ledgr_membership_resolve_at()`); the rule M-2 and the counter implement | the canonical side of LTB-0334 and of the frozen compilers in LTB-0335 |
| M-2 prepared cursor | every availability fold pulse (the same-clock membership counter, its second caller, was removed in Correction 1) | LTB-0334 |
| Membership counter (`ledgr_history_membership_fact_counts()`; the same-clock `ledgr_history_membership_diagonal_counts()` was removed by Cut 16 decision 24, Correction 1) | `ledgr_history_substrate()` through `ledgr_history_membership_segment_counts()` | LTB-0335 against the frozen BASE compilers |
| S-1 rule, S-2 per-instrument and S-4 one-fact compilers (counts only) | `ledgr_history_substrate()` through `ledgr_history_status_segment_counts()` | LTB-0335 (counts and refusals), LTB-0334 (S-3 against S-1) |
| S-3 diagonal status plan | every availability fold pulse | LTB-0334 |
| L-1 rule, L-2 and L-3 lifetime compilers, T-1 terminal compiler (stored) | `ledgr_history_substrate()` | LTB-0334 |
| L-4 diagonal lifetime plan | every availability fold pulse | LTB-0334 |

The family-wide epoch compiler (M-6) is absent from the package and LTB-0332
fails if it returns (mutation M12). Incomplete lagged set compilation
(`dev/bench/v0_2_2_history_simplification/membership_lagged_counts.R`, 500
sessions, sets known five sessions after they take effect, each listing a
random half of the instruments; timing method under Timing below, three
alternating runs per arm):

| Sets x instruments | BASE M-6 (s) | Counter (s) | Segments (both arms) |
| --- | --- | --- | --- |
| 20 x 300 | 0.78, 0.77, 0.78 | 0.01, 0.02, 0.01 | 3,300 |
| 40 x 300 | 3.82, 3.80, 3.82 | 0.09, 0.07, 0.08 | 6,300 |
| 80 x 300 | 22.11, 22.22, 22.24 | 0.06, 0.06, 0.06 | 12,300 |

The per-instrument counts are identical in both arms (equal digests). On
the counter alone, 20 to 320 sets by 300, 600 and 1,200 instruments take
0.03 to 1.33 s (`evidence/membership_lagged_counts.csv`). Corrected in
Correction 1 (close review F4): the cost is O(instruments x own incomplete
sets x (complete + own sets)), linear in instruments but quadratic in sets
per instrument for incomplete shapes; 2,560 sets take about 8.5 s.

LCL-0324/LTB-0334 is the randomized differential of the compilers that
survive under every option against their canonical resolvers: L-2 and L-3 two-clock lifetime
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

After Cut 16 decision (22) the runner gained 22 refusal families: a run, a
sweep and a pulse inspection under `ledgr_history_policy(segment_limit = k)`
for k = 1 to 6 on fixture A, 1 to 3 on B and C, 1 to 4 on D, and 1 to 6 on a
fifth fixture E (one complete set, four lagged status facts on one
instrument), recording each refusal's class, message and condition fields.
On BASE these refuse with the membership family (A, B, C, D) and with the
trading-status family (E at k = 2 to 4); the larger limits run. BASE was
re-recorded with 84 families.

`check_identity.R` compares each family by the bytes of `serialize()`; its
self-test perturbs each family alone and detects 62 of 62 (84 of 84 on the
re-recorded BASE). Before any
product change, a run of the unchanged branch head agreed with a BASE run on
every family (58 families then; the two INCOMPLETE scenarios were added
later and BASE was re-recorded), after volatile columns (timings, creation
and promotion times, database paths) were dropped. Result on the final
candidate (the committed LDG-3075 and LDG-3077 tree): 62 of 62 families
identical, no family retried; checker self-test 62 of 62. On the decision
(22) tree: 84 of 84 identical against the re-recorded BASE, no family
retried. A product
mutation that makes `ctx$bars$gap_type` `"NONE"` everywhere makes the runner
report 11 in-strategy and inspection families as different (Mutation table).

The registered fixture ladder (`dev/bench/v0_2_2_real_data_scale`, 800
instruments, 1,260 sessions, 300 members, ten phases) ran on the BASE copy
and on the candidate with `--allow-dirty`, on the first LDG-3075 tree, the
LDG-3077 tree and the decision (22) tree: each time 50 of 50 gated families
identical and the identity family identical; the recorder self-test detects
51 of 51.

## Sizes (H1 shape)

`representation_sizes.R` on the same H1 snapshot (1,166 instruments by
7,213 sessions, 580 complete sets), BASE copy against candidate; MB, object /
serialized:

| Representation | BASE `b9d098c8` | After LDG-3075 part 1 | After decision (22) |
| --- | --- | --- | --- |
| Substrate, no features | 720.6 / 737.4 | 495.3 / 477.1 | 413.5 / 428.8 |
| Substrate, one feature bound | 788.4 / 803.8 | 563.1 / 543.5 | 481.3 / 495.3 |
| Bar planes | 8 planes, 449.4 / 483.6 | 6 planes, 353.1 / 353.1 | 6 planes, 353.1 / 353.1 |
| Diagonal planes (R12a-d) | 128.4 / 128.4 | absent | absent |
| Membership plus status segments | 81.8 / 48.3 | 81.8 / 48.3 | counts only, 0.05 / 0.05 |
| Provider plan | 59.5 / 75.5 | 58.8 / 74.1 | 58.8 / 74.1 |
| Staged invariant, fresh sweep | 855.2 / 869.9 | 629.8 / 609.7 | 548.0 / 561.4 |
| Staged invariant, precomputed sweep | 1,121.0 / 1,133.6 | 629.8 / 609.7 | 548.0 / 561.4 |

Against BASE the substrate shrinks by 43 percent (object) and 42 percent
(serialized); the staged invariant by 36 and 35 percent for a fresh sweep and
51 and 50 percent for a precomputed one. The H1 substrate built in about 2.3
s on the decision (22) tree against about 10 s on BASE (disclosure only, one
run each; the complete-set compiler built 677,446 segments there). Records:
`dev/bench/v0_2_2_history_simplification/evidence/representation_sizes_h1_b9d098c8.csv`,
`representation_sizes_h1_ldg3075.csv` and
`representation_sizes_h1_decision22.csv`, with logs.

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
`ledgr_availability_session_source()`, the sweep task builders,
`ledgr_indicator_catalogue_row()` / `ledgr_indicator_catalogue_index()`, and
for decision (22) `ledgr_history_segment_limit_check()`,
`ledgr_history_membership_segment_counts()`,
`ledgr_history_membership_fact_counts()`,
`ledgr_history_uncovered_pieces()`,
`ledgr_history_membership_diagonal_counts()` and
`ledgr_history_status_segment_counts()`.

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

Decision (22) counting, shape by shape. No loop runs over sessions or
instruments times sessions. `ledgr_history_membership_fact_counts()` loops
once over complete headers (each step one vector operation over headers:
O(headers x complete headers), 0.34 million comparisons at H1's 580 sets),
then over instruments that appear in an incomplete header or an interval
row (shape 2 avoided: their facts are grouped once with `split()` and read
by index; each instrument's work is one operation per own incomplete header
over its relevant headers, and interval cover is grouped by knowledge level).
Instruments with neither share one count. `ledgr_history_uncovered_pieces()`
merges cover intervals with `cummax()` and counts gaps with one `outer()`.
The same-clock counter this paragraph first described was removed by Cut 16
decision (24) (Correction 1). The fact counter is quadratic in incomplete
sets per instrument (close review F4), not linear. The status counter runs the
shared per-instrument compiler, which loops over instruments with status
facts and their own epochs and breaks (shape 5 is the accepted residual: the
segments are built and dropped, as BASE built and stored them).

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
- Decision (22), LTB-0291: its two-clock membership and trading-status reads
  (`before`, `learned`, `ignored`, `status_late`, `status_early`, the status
  side of the provider diagonal loop, the lagged interval-only family and the
  two-clock complete family) read stored segments that decision (22)
  removes. They now read the same answers from frozen copies of the BASE
  compilers (`helper-history-segment-reference.R`), with every literal and
  canonical-resolver oracle unchanged, and LTB-0291 additionally asserts that
  the substrate's counts equal the reference compilers' counts. The two
  sparse-lifetime blocks drop their mock of `ledgr_history_segments_build()`,
  which no longer exists; LTB-0332 detects its return.
- Decision (22), LTB-0332: the expected substrate names add `segment_counts`,
  the expected segment families are `lifetime` and `lifetime_terminal`, and
  the removed-function list adds the five compilers and the header applier.
- New: LCL-0322/LTB-0332 (fast), LCL-0323/LTB-0333 (fast), LCL-0324/LTB-0334
  (review), LCL-0325/LTB-0335 (review). The frozen reference helper is test
  code only; the census lists no new test-only seam.

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
| M11 | store the membership counts as a segment family again | `R/history-substrate.R` | LTB-0332 | fails (1) |
| M12 | restore the family-wide epoch compiler | `R/history-substrate.R` | LTB-0332 | fails (1) |
| M13 | restore the complete-set header applier | `R/availability-provider-prepared.R` | LTB-0332 | fails (1) |
| Q1 | count an instrument's header region from its break to the axis end | `R/history-substrate.R` | LTB-0335 | fails (16) |
| Q2 | ignore interval cover on header regions | `R/history-substrate.R` | LTB-0335 | fails (15) |
| Q3 | merge same-clock runs across different knowledge times | `R/history-substrate.R` | LTB-0335 | survives: equivalent mutant (a run's winner fixes its knowledge time, so equal answers imply equal knowledge) |
| Q3b | count every kept same-clock break as its own segment | `R/history-substrate.R` | LTB-0335 | fails (43) |
| Q4 | let a later complete header block before it is known | `R/history-substrate.R` | LTB-0335 | fails (31) |
| Q5 | change the guard message's ratio precision | `R/history-substrate.R` | LTB-0335 | fails (122) |
| Q6 | change the default limit floor in the shared guard | `R/history-substrate.R` | LTB-0335 | fails (62) |

M0 to P6 were re-run on the decision (22) tree with the same results
(LTB-0332 then has 40 expectations); the unmutated copy passes LTB-0335
(510 expectations).

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

## Decision (22): membership and trading-status segments counted, not stored

The NEEDS_TYPE_2 below was decided by the maintainer on 2026-10-19 as option
C, recorded as Cut 16 decision (22). Implementation:

- `ledgr_history_substrate()` calls `ledgr_history_membership_segment_counts()`
  and `ledgr_history_status_segment_counts()` in BASE's order (membership,
  status, then the stored lifetime and terminal compilers), so the first
  refusing family and instrument are BASE's. Both feed
  `ledgr_history_segment_limit_check()`, which builds BASE's message, class
  and fields from the counts.
- Membership: the counts come from the facts the provider plan holds. For
  the complete-set, interval-only and lagged cases an instrument's answer is
  decided by one fact (the last applicable interval, else the last eligible
  relevant header, else none) and distinct facts give distinct answers, so a
  BASE segment count is one initial segment plus, for every fact, the number
  of contiguous axis blocks it wins when it becomes known.
  `ledgr_history_membership_fact_counts()` computes that from header ranks,
  breaks and knowledge times and interval spans. The same-clock case first
  kept BASE's per-break rule through the plan's prepared resolver
  (`ledgr_history_membership_diagonal_counts()`), with BASE's path
  selection; Correction 1 removed both under Cut 16 decision (24), so every
  shape is counted by the fact counter.
- Status: the plan's diagonal status segments do not carry enough to count
  two-clock segments (no end times or statuses), so the status counter runs
  the shared one-fact and per-instrument compilers on the status rows the
  plan is prepared from and keeps only their counts. This reads decision
  (22)'s "derives each family's segment count from the provider execution
  plan" as "from the facts the plan holds"; the operative clauses (counted,
  not stored; refusals unchanged; status-only compiler wrapper removed) hold.
- v12 Section 7's "flat bitemporal segment vectors per instrument and
  fact-state family" and its per-family guard are met by counting for
  membership and trading status, as decision (22) records, and by stored
  segments for lifetime and terminal state. `contracts.md` (Provider,
  Knowledge And Timing) now says membership and trading-status state is
  counted, not stored, citing decision (22).
- Verification: LTB-0335 compares counts and refusals with frozen BASE
  compilers over 24 random rounds (five membership shapes, two status
  shapes, about 170 limit breaches) and four declared limits on a whole
  substrate; a scratch probe found no count mismatch on 1,800 further random
  membership families; the identity runner's refusal families are equal on
  BASE and the candidate.

### The NEEDS_TYPE_2 as raised

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
- M-8 fact counter cost (added by Corrections 1 and 2): quadratic in
  incomplete sets per instrument (close review F4: 8.5 s at 2,560 lagged
  sets by 300 instruments). Since decision (24) it also counts same-clock
  incomplete sets, the shape `knowledge = "assume_effective"` produces:
  about 2.1 s at 1,280 sets by 300 instruments against 0.4 s before
  Correction 1 and about 2.0 s on BASE (re-review 1), so it should be
  slower than BASE above that size. The exit is an O(S log S)
  next-blocking-header pass.
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

On the decision (22) product tree (`a86f8573`),
Windows 11, R 4.6.1, run sequentially:

- Full suite: 1,145 blocks, 18,352 expectations, no failure or error, one optional skip (quantmod installed); 653 s of block time.
- Byte-identity runner against BASE: 84 of 84; self-test 84 of 84.
- Fixture ladder against BASE: 50 of 50 plus identity; self-test 51 of 51.
- Census check mode and `--self-test-mode-branches`, the fold-phase checker
  and the YAML parse pass; `git diff --check b9d098c8` is clean.

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

## Correction 1 (close review 46, 2026-10-19)

`close_review_46.md` returned CHANGES_REQUIRED with eight findings. The
maintainer decided F1 and F3 on 2026-10-19 as Cut 16 decisions (23) and
(24), recorded in `tickets.yml`. Each finding and its answer:

| Finding | Answer | Evidence |
| --- | --- | --- |
| F1: facts with no knowledge time behave differently from BASE | Decision (23): such facts are refused with `ledgr_fact_knowledge_missing`. The check runs on the durable run's own store connection before the run is registered (`ledgr_run_fold_impl()`), and on the in-memory fact tables at the start of `ledgr_history_substrate()`, which sweeps, precompute, walk-forward and inspection reach before any side effect. Membership facts can carry a missing knowledge time too: `ledgr_facts_membership_intervals()` and `_snapshots()` share `ledgr_fact_knowledge_time()`, which stores `NA` under the default `knowledge = "evidenced"`; they are refused the same way. Contract (Provider, Knowledge And Timing) and condition reference (roxygen and `man/ledgr_condition_classes.Rd`) name the class | LCL-0326/LTB-0336: status, lifetime and membership snapshots each refused by `ledgr_run()`, `ledgr_sweep()`, `ledgr_precompute_features()`, `ledgr_walk_forward()` and `ledgr_pulse_snapshot()`, with the `runs`, `ledger_events`, `sweeps` and `walk_forward_sessions` row counts unchanged; mutations K1-K3 fail it |
| F2: the contract still lists a provider `history` operation | Removed; the bullet now says history is read only from the shared substrate | `contracts.md` Provider, Knowledge And Timing |
| F3: the same-clock counter undercounts against the canonical count | Decision (24): `ledgr_history_membership_diagonal_counts()` and its selection are removed; every shape is counted by `ledgr_history_membership_fact_counts()`. `ledgr_history_membership_is_diagonal()` and `ledgr_history_membership_state()` had no other product caller and move, verbatim, into the frozen reference helper | LCL-0327/LTB-0337: a literal family (counts 4 and 3; the removed counter counted 3 and 2) refused at limit 3 with a literal message, and a randomized differential of 48 same-clock and lagged header and interval families against a brute-force count from `ledgr_membership_resolve_prepared()` at every axis column and knowledge epoch (no mismatch; on these header-only and interval-only families, the shapes the public API can store, the removed counter undercounts on some and never overcounts; Correction 2 records that it also overcounted internally built mixed families); mutations D1-D3 fail it. LTB-0335 drops its same-clock shape for this reason. LTB-0332 fails if the counter returns (M14) |
| F4: the counter is not linear in incomplete sets | Claim corrected. The cost is O(instruments x own incomplete sets x (complete + own sets)): quadratic in sets per instrument for incomplete shapes, linear for complete sets. Measured under the recorded timing method (two runs, 300 instruments, half listed per set): 0.36-0.38, 0.75-0.76, 2.12-2.20 and 8.53-8.80 s at 320, 640, 1,280 and 2,560 sets, against 22.2 s for BASE's M-6 at 80 sets. Not optimized; an O(S log S) next-blocking-header pass is the routed exit | `evidence/membership_lagged_counts_scaling.csv`; `membership_lagged_counts.R` now lengthens the axis when there are more than 450 sets so each set has its own session (shapes up to 450 sets are unchanged) |
| F5: LTB-0335's status half shares the live compilers | LCL-0325's `oracle_independence` now says so. LTB-0335 adds literal status witnesses: one-fact counts `2, 1` with limits `16, 16`, multi-fact counts `2, 6` with limits `16, 20`, and one literal refusal message. The guard's message formatting has one copy: the one-fact and per-instrument compilers call `ledgr_history_segment_limit_check()` | Mutations X16 (the one-fact compiler hands the guard a wrong fact count) and Q6 (default floor) fail LTB-0335 |
| F6: the map's path tables are stale | Sections 1-2 keep describing `b9d098c8`, and each row Workstream 46 changed now ends with **Now:**; new rows R35 (`segment_counts`) and M-8 (fact counter) carry status, differential and exit | `history_representation_map.md` |
| F7: dead parameter and redundant condition | `header_method` removed (ties order only which header wins a shared break; the loser's region is empty either way; radix order is used). `previous_keep &` went with the same-clock counter | Code |
| F8: stale test name; mixed shapes; spike probes | The test is renamed "an INCOMPLETE run builds one prepared provider plan and its reopen builds none". The reviewer's inference holds: `ledgr_facts()` accepts one membership family per universe, so public data cannot mix set headers and interval rows in one universe; the counter's interval cover on header regions and the mixed shapes in LTB-0334/0335 serve internally built data only, and are kept because the canonical resolver defines that case. The historical spike probes `dev/spikes/historical-projection/probe.R` and `dev/spikes/two-clock-history/probe.R` call the removed `ledgr_availability_provider_portable()`; they are not part of any gate and are left as historical records | Test file; this note |

### Identity after Correction 1

The runner gained fixture G (an incomplete set and two complete sets taking
effect at 20:00 and at the 21:00 close of the same day, all same-clock) with
declared limits 1 to 5; BASE was re-recorded with 89 families. Result: 86
of 89 identical. The three differences are the families decision (24)
allows, all in fixture G, the family the removed counter undercounted:

| Family | BASE | Correction 1 |
| --- | --- | --- |
| `G/limit_1` (run, sweep, inspection) | refused: membership, G01, 3 segments for 5 facts | refused: membership, G01, 4 segments for 5 facts |
| `G/limit_2` (run, sweep, inspection) | refused: membership, G01, 3 segments for 5 facts | refused: membership, G01, 4 segments for 5 facts |
| `G/limit_3` (run, sweep, inspection) | runs | refused: membership, G01, 4 segments for 5 facts, limit 3 |

`G/limit_4` and `G/limit_5` run on both trees. No other family differs.
The fixture ladder is 50 of 50 plus identity again.

### Correction 1 mutation table

All earlier mutations (M1-M13, N1-N2, P1-P6, P4b) were re-run on the
Correction 1 copy and each fails its block as before; M14 (restore the
same-clock counter) fails LTB-0332 (1).

| ID | Mutation | Block | Result |
| --- | --- | --- | --- |
| K1 | drop the knowledge check before run registration | LTB-0336 | fails (15) |
| K2 | make the knowledge refusal a no-op | LTB-0336 | fails (45) |
| K3 | stop counting lifetime facts in the stored-fact check | LTB-0336 | fails (5) |
| D1 | an incomplete header blocks another before it is known | LTB-0337 | fails (1) |
| D2 | count a header region from its break to the axis end | LTB-0337 | fails (2) |
| D3 | drop an instrument's incomplete headers | LTB-0337 | fails (43) |
| Q1 | header region to the axis end | LTB-0335 | fails (5) |
| Q2 | ignore interval cover on header regions | LTB-0335 | fails (19) |
| Q4 | a later complete header blocks before it is known | LTB-0335 | fails (12) |
| Q5 | change the guard message's ratio precision | LTB-0335 | fails (72) |
| Q6 | default floor 16 to 15 in the shared guard | LTB-0335 | fails (33) |
| X16 | one-fact compiler hands the guard a fact count of at least 1 | LTB-0335 | fails (1) |

### Test changes in Correction 1

- LTB-0291: the membership-state oracle mapping now calls the frozen
  `history_reference_membership_state()` (verbatim BASE), because the
  package function had no product caller left after decision (24). Oracle
  unchanged.
- LTB-0332: the removed-function list adds the same-clock counter,
  `ledgr_history_membership_is_diagonal()` and
  `ledgr_history_membership_state()`.
- LTB-0335: the same-clock shape moves to LTB-0337 (decision 24 changes
  same-clock counts away from the frozen BASE compiler); literal status
  witnesses added (F5).
- New LCL-0326/LTB-0336 and LCL-0327/LTB-0337.
- `ledgr_availability_prepared_membership()` is now called only by tests;
  the census records it as a test-only seam with a stated contract.
- The unregistered provider-production test is renamed (F8).

### Correction 1 verification

On `260d3eaf`, Windows 11, R 4.6.1, sequentially: full suite 1,147 blocks,
18,438 expectations, no failure or error, one optional skip (quantmod
installed), 658 s of block time; identity runner 86 of 89 against the
re-recorded BASE with only the three decision (24) differences above,
self-test 89 of 89; fixture ladder 50 of 50 plus identity, self-test 51 of
51; census `--mode=check` (158 branch, 55 flow sites; findings 72) and
`--self-test-mode-branches`, `tools/check-fold-phase-contract.R` and the
YAML parse pass; `git diff --check` is clean. The first full-suite run of
Correction 1 had placed the run check before the run store opened, through
a second snapshot connection; LTB-0131 (one store open per run) failed, so
the check moved onto the run's own connection. LTB-0271 then required the
census to list the new condition class.

## Correction 2 (focused re-review 1, 2026-10-20)

`close_review_46_rereview_1.md` returned CHANGES_REQUIRED with three
findings and no product defect. Commits `b936675d` and `adcc9de8` answer
them; this record is the evidence.

| Finding | Answer | Evidence |
| --- | --- | --- |
| R1: user documentation still calls a fact with no knowledge time audit-only and run-neutral | Reworded in `?ledgr_facts` (`R/availability-facts.R`), `?ledgr_sim_pit_inputs` (`R/sim-pit-inputs.R`) and the four passages of `vignettes/point-in-time-inputs.qmd`: a membership, trading-status or lifetime row without a knowledge time is accepted and sealed, then every run, sweep, feature precompute, walk-forward session or pulse inspection that prepares availability refuses with `ledgr_fact_knowledge_missing` until the row has one. The only statement about `assume_effective` is what `ledgr_fact_knowledge_time()` does today: it uses the effective time. The user text names no decision number, following LDG-2901 (no maintainer language in user articles); decision (23) is cited here and in the ticket evidence. Both Rd files were regenerated with roxygen (seven other Rd files that roxygen touched only by a trailing blank line were restored). NEWS gains one bullet for the refusal. The rendered sibling `vignettes/point-in-time-inputs.md` was regenerated with `tools/render-vignettes-gfm.R`, which executes every chunk; its `--check` freshness run passes, and the Markdown diff is prose only | LTB-0079 (registered): see test changes |
| R2: the `<=` to `<` tie mutation at `R/history-substrate.R:940` survives | LTB-0337 adds the reviewer's tie family as a literal case: a complete set `x` (I1) and an incomplete set `z` (I1-I5) with identical effective and knowledge times, 2021-03-04 20:00 UTC, between two 21:00 sessions. Fact counts `4, 3, 3, 3, 3`, segment counts 2 for every instrument (hand-derived in the block comment and equal to the brute-force canonical count); at limit 2 it runs. The mutant counts 3 for every instrument and refuses at limit 2 | Mutation D5 fails LTB-0337 (2); probe `tie_probe.R` showed live 2, canonical 2, frozen BASE 2, mutant 3 for the five instruments |
| R3a: "never overcounts" is unscoped | Scoped to the shapes the public API can store. `ledgr_facts()` refuses a second membership family per universe, so public data is header-only or interval-only per universe; there the removed same-clock counter only undercounted. On internally built same-clock families that mix set headers and interval rows it also overcounted: on the reviewer's 828 families, the 36 that differ from BASE are all such mixed families; BASE overcounted 22 and undercounted 15 (one family both); at the declared limits 22 evaluations BASE refused now run and 7 it ran now refuse. The candidate equals the canonical count on every one. Decision (24)'s "only intended difference" holds for public data | Correction 1 F3 row (scoped in place); LCL-0327 `protected_contract_or_defect` |
| R3b: closeout line 101 lists the same-clock counter as an M-2 caller | Fixed: the M-2 row now says the same-clock counter, its second caller, was removed in Correction 1 | `## LDG-3076: compilers that remain` |
| R3c: LCL-0325 says "five membership shapes" | Fixed: four membership shapes (complete, interval-only, incomplete, lagged mixed) and two status shapes, with the breach rule stated (a declared limit one below the largest count in each family whose largest count exceeds 1; the block asserts more than 100). The "five membership shapes" sentence in the decision (22) section stays: it records the verification at `a86f8573`, before Correction 1 dropped the same-clock shape | `tests/claims.yml` |
| R3d: the removed `length(axis) == 0L` branch is unrecorded | Recorded. Correction 1 removed it from `ledgr_history_membership_segment_counts()` together with the same-clock selection; on an empty axis a family that is not complete-only, interval-only or same-clock now counts 1 per instrument instead of 0 (the reviewer's `empty_axis.R`: 270 of 711 families). No public path reaches an empty axis, read from every builder: the durable run builds its axis with `ledgr_availability_calendar()` (`R/backtest-runner.R`, the `history_axis` block) or takes a substrate already built; sweep, precompute, walk-forward and pulse inspection call `ledgr_history_substrate_for_experiment()`, which also uses `ledgr_availability_calendar()`. That function refuses fewer than two open-session pulses with `ledgr_run_window_too_short`. A count of 1 also cannot exceed a limit, which is at least 1. BASE's result is therefore not restored | Code reading; this note |

Timing disclosure (re-review 1, "Cost and shape"): same-clock incomplete
sets, the shape `knowledge = "assume_effective"` produces, now go through
the fact counter and inherit F4's quadratic term. Under the recorded timing
method (the reviewer's measurement), 300 instruments by 1,400 sessions,
each set listing half the instruments: 1,280 sets take about 2.1 s on the
candidate against 0.4 s before Correction 1 (`303ded9c`) and about 2.0 s
on BASE; 80 and 320 sets
take 0.08-0.09 and 0.32-0.34 s (0.03 and 0.15-0.16 s before, 0.14 and
0.47-0.48 s on BASE). Above about 1,280 sets the candidate should be slower
than BASE. This is recorded under the routed O(S log S) next-blocking-header
pass in "Routed, not changed here", which now also names
`assume_effective` users.

### Correction 2 mutation table

On a source copy synchronized to `b936675d`, each mutation restored byte for
byte; the unmutated copy passes LTB-0332 (43), LTB-0333 (6), LTB-0334 (91),
LTB-0335 (441), LTB-0336 (48) and LTB-0337 (108 expectations).

| ID | Mutation | Block | Result |
| --- | --- | --- | --- |
| D5 | an own header with an equal knowledge time does not block (`<=` to `<`) | LTB-0337 | fails (2) |
| D1 | an incomplete header blocks another before it is known | LTB-0337 | fails (1) |
| D2 | count a header region from its break to the axis end | LTB-0337 | fails (4) |
| D3 | drop an instrument's incomplete headers | LTB-0337 | fails (43) |
| W1 | the detector pattern applied to the previous article (`git show 967794af:vignettes/point-in-time-inputs.qmd`), not through the runner | LTB-0079 detector | all four old passages are caught (status, lifetime and the dictionary by the audit-only pattern, membership by the "kept for audit" pattern); the current article matches neither |

### Test changes in Correction 2

- LTB-0079 (registered, documentation): one pinned rule string asserted
  the old wording "for membership, status and lifetime, missing evidenced
  knowledge remains audit-only". Decision (23) made that rule false and the
  coordinator's R1 brief ordered the text changed, so the pin now asserts
  the new rule ("... is sealed, but availability preparation refuses it
  with `ledgr_fact_knowledge_missing`"), and a new detector fails if either
  the article or its rendered sibling again says that missing knowledge is
  audit-only or "kept for audit but cannot affect" resolution. No
  behavioral test changed.
- LTB-0337: the literal tie family is added (R2). The limit-2 assertion
  catches the refusal condition, so a mutant fails the expectation rather
  than aborting the block before its randomized differential.
- LCL-0325 and LCL-0327 text as above.
- No fixture changed. The first full-suite run on `b936675d` failed
  LTB-0269 (inline schema-version literal census): the longer
  `?ledgr_sim_pit_inputs` wording had moved the literal in
  `R/sim-pit-inputs.R` from line 288 to 290. `adcc9de8` rewrites that note
  in its original three lines instead of moving the census location.

### Correction 2 verification

On `adcc9de8`, Windows 11, R 4.6.1, sequentially: full suite 1,147 blocks,
18,446 expectations, no failure or error, one optional skip (quantmod), 676 s
of block time; targeted files test-history-substrate.R (11 blocks, 1,380
expectations), test-pit-input-documentation.R, test-schema-version-literals.R,
test-test-control-plane.R and test-documentation-contracts.R pass; census
`--mode=check` (`LEDGR_CODEBASE_CENSUS_OK`, findings 72; 158 branch and 55
flow sites) and `--self-test-mode-branches` pass;
`tools/check-fold-phase-contract.R .` passes; the article renders and its
`--check` freshness run passes; the YAML parses and `git diff --check` is
clean. Correction 2 changes no product code path, so the identity runner and
fixture ladder were not re-run; their Correction 1 results stand.
The census run regenerated its CSVs under
`dev/bench/v0_2_2_pre_cran_removal/census/`: the only changes are line
numbers in `R/availability-facts.R` (the four added roxygen lines) and the
two new test references to `ledgr_facts_membership_snapshots()` and
`ledgr_history_membership_segment_counts()` from the LTB-0337 tie family.
