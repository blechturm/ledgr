# Cut 6 Review: One Execution Path (macro WS4b)

Role: finding-bearing cut review; evidence, not authority.
Reviewer: Claude (fresh context), 2026-11-01.
Mode: combined Type 1 verification and Type 2 challenge.
Inputs: uncommitted Cut 6 draft in `tickets.yml` (cut 6, workstream 14,
LDG-3170..LDG-3178), `macro_plan.md` revision 7 and the packet `README.md`
diff, all on `codex/cut6-ws4b` over base `b5622f09`.

## Verdict: NEEDS_TYPE_2

## Executive summary

The draft records the four maintainer choices faithfully, its ticket chain is
linear and acyclic, and its close-review brief is strong. One maintainer
choice is missing, and several claims are false or incomplete.

1. **Missing choice (Type 2).** The two current producers differ in more than
   the four settled points. On a fixed basket, the availability core would
   also change feature history start, walk-forward carry, affordability,
   short admission, persisted evidence, corporate-action refusal, the feature
   engine and strategy-helper semantics. The draft is contradictory here. Its
   `out_of_scope` forbids economic change, which implies keeping every dense
   rule. Decision (6) and LDG-3173 forbid any mode selector, which implies
   adopting the availability rules. The draft does not say which applies, so
   implementation would have to decide product behavior.
2. **The identity claim is false.** `ledgr_identity_rule_version` is a
   store-format binding, so rule 5 changes the store fingerprint (verified
   below). Older stores refuse at open, before the per-record checks that
   LDG-3174 acceptance 3 tries to exercise.
3. **Maintained harnesses depend on the surfaces this cut deletes.** These
   are the A0 `db_live` arm, the RNG baseline, the peer driver's internal
   oracle and WS4a detector D13. The cut gives none of them migration
   authority.
4. **The timing protocol cannot work as written.** The shared harness
   requires a bound for every cell, and macro rule 16 measures against v0.2.2.
   The draft has no bounds and uses b5622f09 as the only before arm.
5. **LDG-3177 would weaken accepted evidence.** Removing the success-path
   reconciliation JSON removes Cut 5's `amendment_valuation` refusal point.
   Removing the padding breaks the strategy-visible `asset_state` contract
   unless the ticket says otherwise.
6. **Macro rule 11 was not applied.** The difference table is to be frozen
   after acceptance in LDG-3170, but rule 11 requires base oracles to run
   and surprises to be settled before acceptance. This review's own small
   probe surfaced three unsettled differences.

Items 2 to 6 are mechanical and listed as required patches. Item 1 needs the
maintainer.

## The missing maintainer choice

**Question.** A fixed basket on the bar-native clock now enters the one
availability-core path. Where the current producers differ beyond decisions
(1) to (4), does it take the availability rule (option B), or does the
substrate carry today's dense rule as a named prepared value (option A)?

These differences were verified at b5622f09. Every item is non-vacuous on a
complete rectangular basket.

| # | Behavior | Dense today | Availability today | Evidence |
| --- | --- | --- | --- | --- |
| a | Feature history start | scoring start (restart) | data start | `contracts.md` contract-execution-window-start; `tests/claims.yml` LCL-0300 ("Giving dense the availability data-start rule is an unaccepted dense change") |
| b | `carry_test_state` walk-forward | per-window; a non-final window's last target does not fill | continuous carry; it fills at the next window's first pulse | `contracts.md:419-443` ("Dense sessions keep their per-window behavior") |
| c | Affordability | none; probe: cash 1000, target 50 x 100 ends at cash -4000, DONE | active scan; `insufficient_cash` rejection plus a per-pulse reconciliation row | `R/fold-engine.R:1249-1275`, `:1516-1565`; contract-availability-affordability |
| d | New or enlarged short | admitted; probe and `test-fill-model.R:264`, `test-fifo-opening-positions.R:240-270` | refused, `ledgr_short_exposure_unsupported` | `R/fold-engine.R:1094-1096`; contract-availability-targets |
| e | Persisted evidence | no decision trace and no completion row; state written only when returned | one `decision_recorded` row per axis ID per pulse, `affordability_reconciled` per pulse, completion row, padded state written every pulse | `R/fold-engine.R:1001-1040`, `:1574-1597`, `:1939-1954`; contract-persistence-fold-evidence |
| f | Corporate-action refusal | aborts | typed INCOMPLETE stop | `R/fold-engine.R:433-445` |
| g | Feature engine | `ledgr_compute_feature_series` | history segments; different `feature_engine_version` (persisted; gates payload reuse) | `R/features-engine.R:1-60`, `R/backtest-runner.R:802-842`, `R/precompute-features.R:86-111` |
| h | Strategy-visible ctx and helpers | `ctx$availability_active` absent; empty targets refused | `TRUE`; empty targets allowed; eligible-only sizing; held-nonmember handling | `R/fold-engine.R:876-882`, `:986`; `R/strategy-helpers.R:6,355-438,540-560`; `R/signal-strategy.R:63-158`; `R/strategy-types.R:82-120`; `R/pulse-context.R:1197` |
| i | Equity source at finalisation | event replay | fold record; partial-prefix commit | `R/run-finalize.R:460`, `R/backtest-runner.R:1065-1089`; contract-execution-fold-core |
| j | Non-finite valuation | completes with non-finite equity | refuses at reconciliation (`ledgr_config_non_finite`) | `contracts.md:735-742` (Cut 5 `amendment_valuation`) |

**Option A: preserve dense results.** Each row becomes a prepared policy value
on the substrate (for example, affordability "none", shorts "admitted",
history "scoring start", carry "per window", corporate-action refusal
"abort"). Dense outputs stay identical apart from decision (4) and the rule-5
identities. The cost is that P2, P3, P5 and finalisation still branch on these
values. That is the dense mode under new names. It contradicts decision (6),
LDG-3173 acceptance 1 and the `AGENTS.md` rule against "`availability_active`
or equivalent".

**Option B: availability semantics.** A fixed basket is a full-membership,
never-stale availability run on the bar-native clock. Every row changes for
dense users. The concrete consequences are:

- Overspending strategies get rejected fills.
- New shorts refuse. This is consistent with contract-strategy-supported-surface,
  which already calls negative targets unsupported. Six or more registered
  tests flip.
- Dated, windowed and walk-forward features change, and LCL-0300 flips.
- Carried walk-forward windows fill across their boundaries.
- Durable runs persist about N x T extra decision rows (630,000 for the
  500 x 1,260 peer shape). This is a storage and time cost for the milestone
  record.
- Corporate-action refusals stop as INCOMPLETE.
- `feature_engine_version` changes.
- The compiled spot-FIFO admission predicate must be restated as "no
  declared sessions", because contract-availability-targets currently says
  "availability-aware execution is canonical R only".

**Recommendation: B.** The roadmap and the v0.2.2 consolidation entry
("removes the dense engine, not the dense use case ... a special case of the
one engine ... with full membership") describe B. A recreates the frozen
second semantics. Whichever option is chosen, the answer must also update the
cut's `out_of_scope`, `identity_and_release_impact`, the expected-difference
table (RP6) and test-migration authority (RP10). It must also say whether
the probe's strict TTR preparation cost is in WS4b's floor list. That cost
was 137x `t_pre` on a pre-Cut-16 base and needs remeasurement (S11).

## Required patches

These apply under either Type 2 outcome. Text in quotes is paste-ready.

| ID | Location | Defect | Replacement |
| --- | --- | --- | --- |
| RP1 | cut 6 `decisions` (5), from "The diagnostic change is execution evidence" to the end of (5) | The fingerprint claim is false. `ledgr_store_format_bindings()` matches `^ledgr_[a-z_]+_(schema|rule)_version$` (`R/store-gate.R:3-12`), so `ledgr_identity_rule_version` is binding 15 of 28. Old stores refuse at the store gate before any record check. Cut 4 recorded the same mechanism for `ledgr_pulse_seed_rule_version`. | "(5) The diagnostic change is execution evidence, so ledgr_identity_rule_version becomes 5L before it can ship. New configs, run IDs, sweep IDs and walk-forward identities use rule 5. ledgr_identity_rule_version is a store-format binding, so the store-format fingerprint changes by that one constant, as cut 4's pulse-seed rule did. A store written before rule 5 refuses when opened with ledgr_store_rebuild_required (cause fingerprint_mismatch, differing constant ledgr_identity_rule_version); its runs, saved sweeps and walk-forward sessions are neither reopened nor reused. Inside a current store, a record carrying rule 4 refuses at its existing check: ledgr_invalid_config at run registration and resume, ledgr_invalid_run when reopened, ledgr_sweep_schema_incompatible for a saved sweep and ledgr_walk_forward_invalid_session for a session. No migration, fallback or compatibility reader is added. Snapshot content identity and the store schema version do not change. Development uses fresh stores, and the private lake is rebuilt only at the final freeze (macro rule 5)." |
| RP1 | cut 6 `identity_and_release_impact`, sentence "Store schema and format fingerprint: unchanged." | Same as above. | "Store schema version: unchanged. Store-format fingerprint: changes by the one binding ledgr_identity_rule_version (4 to 5); older stores refuse with ledgr_store_rebuild_required." Also append to "Persisted evidence": "; strategy_state rows of declared-session runs lose the empty per-instrument asset_state entries (LDG-3177); further evidence changes are those the Type 2 answer accepts." |
| RP1 | LDG-3174 `scope`, last sentence | Same as above. | "Rule-4 execution records are not migrated or normalized to rule 5: older stores refuse at the store-format gate, and rule-4 records inside a current store refuse at their existing checks." |
| RP1 | LDG-3174 `acceptance` items 3 and 4 | Item 3 is unreachable as worded, and it names a single class where three exist. Item 4 asserts the false fingerprint claim. | Item 3: "new config-derived identities use rule 5 consistently; a store written on b5622f09 refuses when opened with ledgr_store_rebuild_required (fingerprint_mismatch naming ledgr_identity_rule_version) before any run, sweep or session read; inside a current store, rule-4 run, saved-sweep and walk-forward-session records refuse with ledgr_invalid_config (registration/resume) or ledgr_invalid_run (reopen), ledgr_sweep_schema_incompatible and ledgr_walk_forward_invalid_session". Item 4: "snapshot hashes and the store schema version remain exact, ledgr_store_format_bindings() differs from b5622f09 only in ledgr_identity_rule_version, and no rule-4 fallback, migration or reader branch is added". |
| RP2 | LDG-3170 `scope`, from "Register ws4b-timing-1" to "no pass/fail clock." | The shared protocol loader refuses a cell without a positive bound (`dev/bench/timing/protocol.R:58-88`), and `check.R:257-276` emits PASS or FAIL verdicts. Macro rule 16 checks performance against v0.2.2, but the draft names only b5622f09. | "Register ws4b-timing-1 in dev/bench/timing/protocols/ with no-fill, sparse-rebalance and wide-all-fill shapes on the fixed-basket and declared-session producers, run and sweep paths, phase attribution and three alternating pairs. Its arms are b5622f09 (attribution) and the v0.2.2 tag (macro rule 16 reference) for every workload that runs unchanged there; a workload that cannot run on v0.2.2 records why. Because the shared checker requires a positive bound per cell, thresholds.csv carries a disposition trigger (proposed 1.10) and protocol.md states that a FAIL verdict or non-zero checker exit obliges an attributed disposition line in the milestone record; it is not a ticket or workstream failure. The shared harness is not edited, so no A/A run is needed (macro rule 12)." |
| RP2 | LDG-3170 `acceptance` item 4; LDG-3178 `scope`, "Run ws4b-timing-1 against b5622f09 on the registered host" | Same as above. | Acceptance 4: "ws4b-timing-1 uses the shared harness by reference with no harness edit, records timer boundaries, economic controls and both arms, and records its checker verdicts as disposition triggers, not acceptance". LDG-3178: "Run ws4b-timing-1 against b5622f09 and the v0.2.2 reference arm on the registered host (High performance plan, P-core affinity, alternating pairs)". |
| RP3 | LDG-3170 `scope`, append after "registered claims." | Maintained consumers call deleted surfaces. `dev/bench/v0_2_3_output_freeze/fixtures.R:52-54` (A0 `run_db_live` through `ledgr_backtest(execution_mode = "db_live")`); `dev/bench/v0_2_3_rng_baseline/probe.R:373`; `dev/bench/peer_benchmark/peer_benchmark.R:634-690` (the internal-oracle lane builds `ledgr_bars_pulse_views`, `ledgr_sweep_bars_matrix`, `ledgr_precompute_payload`); `dev/bench/v0_2_3_ws4a/detectors.R:162-178` (D13 hashes the dense builders as frozen). The cut gives no authority to migrate them, and A0 cannot pass LDG-3176 or LDG-3178 without that authority. | "The census includes the maintained harness consumers of removed surfaces: the A0 run_db_live arm (dev/bench/v0_2_3_output_freeze/fixtures.R), the RNG baseline probe (dev/bench/v0_2_3_rng_baseline/probe.R), the peer driver's internal-oracle lane (peer_run_ledgr_internal_oracle in dev/bench/peer_benchmark/peer_benchmark.R) and WS4a detector D13. Each migrates only its attachment point, in the ticket that removes its target: the db_live arm to ledgr_experiment(execution_mode = \"db_live\") plus ledgr_run(); the internal-oracle lane to the prepared-substrate constructor, or retirement once its replacement coverage is accepted; D13 is retired with the dense builders and superseded by the LDG-3176 absence census. Original A0 and RNG-baseline records stay unchanged as history. The candidate records separately named successors, compared field by field under the change predicates frozen here (the cut 4 decision (8) pattern), with every other field required identical." |
| RP4 | LDG-3172 `scope`, first sentence; `acceptance` item 1 | Missing entry points. The exported `ledgr_precompute_features()` and the sweep's precomputed-payload reuse have their own dense/availability branches (`R/precompute-features.R:86-111`, `R/sweep.R:316-354`). Resume and terminal recovery also branch (`R/backtest-runner.R:884-923`, `:1013-1039`). Experiment-derived `ledgr_pulse_snapshot()` refuses dense experiments (`R/pulse-snapshot.R:127-134`). The fold has three direct consumers: `R/backtest-runner.R:1046`, `R/sweep.R:1913` and `R/pulse-snapshot.R:546`. Spec-building tests also call it directly (`tests/testthat/test-execution-spec.R`). | Scope: "Make ledgr_run(), ledgr_sweep() with and without a precomputed payload, ledgr_precompute_features(), run and sweep windows, walk-forward training/test runs, promotion/reproduction, resume and terminal recovery, and ledgr_pulse_snapshot() obtain bars, features, pulse axis, execution opportunities and provider services from the same prepared substrate. The three direct ledgr_execute_fold() consumers (backtest-runner, the sweep candidate executor, pulse-snapshot) and the spec-building tests use the same constructor. Experiment-derived ledgr_pulse_snapshot() admits an implied-clock fixed basket and ledgr_pulse_snapshot_availability_required is removed (recommended; confirm at acceptance). A precomputed payload records its substrate clock kind and a mismatch refuses with the existing ledgr_precomputed_* classes." Acceptance 1: add "explicit precompute and payload reuse, resume and terminal recovery" to the route matrix. |
| RP5 | cut 6 `source_table`, sentence "availability_active occurs 45 times ... three times in R/run-snapshot.R."; LDG-3176 `acceptance` item 1 | The census starting point names only 3 of 14 files. The other 11 hold the strategy-helper, reader, finalisation and feature-engine branches. The criterion for a "justified" predicate is open-ended. | Source table: "availability_active occurs 140 times in 14 R files at b5622f09: fold-engine 45, backtest-runner 30, sweep 18, strategy-helpers 12, availability-results 7, availability-policy 5, signal-strategy 5, derived-state 4, strategy-types 4, precompute-features 3, run-snapshot 3, features-engine 2, pulse-context 1, run-finalize 1." LDG-3176 acceptance 1: "every row of the literal census over all 14 files has one owner: deleted here; a preparation-only predicate that refuses before the fold or selects a prepared value recorded in config identity; a result-reader branch routed to WS7/WS8 with its key stated; or a public ctx/helper semantic retained by contract per the Type 2 answer. Zero rows are unowned, and no surviving predicate selects code in E, P1-P5 or finalisation's equity source." |
| RP6 | cut 6, new field `base_run` after `source_table`; LDG-3170 `acceptance` item 1 | Macro rule 11 requires running the base oracles and settling surprises before acceptance. The draft defers the difference table to LDG-3170. This review's probe found three unsettled rows: overspend, new short, and final-pulse warning count. | New field: "base_run: >- Before acceptance, on b5622f09 (macro rule 11): A0 check, dense-oracle check, WS4a check and guts, and the one-execution-mode witnesses rerun on this tree, each with command, exit code and date; plus the expected-difference table with one row per accepted change (decision (4) warnings to diagnostics, rule-5 identities, the store fingerprint, and each Type 2 row) and its cause." LDG-3170 acceptance 1: "the unchanged base reproduces the dense oracle, A0 and every WS4b semantic witness, and every candidate difference matches a row of the expected-difference table frozen in base_run". |
| RP7 | cut 6 `decisions` (1), append | Macro WS4b says "settle the disclosed implied calendar", and the v0.2.2 consolidation entry requires the implied calendar to be disclosed "on the same surfaces as the price basis". The draft is silent, so it drops disclosure without saying so. | "The bar-native clock is disclosed as a default wherever the price basis is labeled (ledgr_experiment_plan(), and print() and summary() of an experiment and a result), as \"Pulse clock: bar timestamps (no declared sessions; default)\"." (Recommended. If the maintainer prefers no label, the cut states that instead.) |
| RP8 | LDG-3177 `scope`, sentence "Replace reconciliation success-path detail JSON ... retained failure row."; `acceptance` item 2 | (1) Durable runs must persist reconciliation evidence (contract-persistence-fold-evidence). (2) The success-path encode is the accepted `ledgr_config_non_finite` refusal point (`contracts.md:735-742`, Cut 5 `amendment_valuation`). Removing it silently changes an accepted refusal. | Scope: "Carry reconciliation values as typed primitives and encode detail_json only for a row the active sink retains. Durable runs keep every reconciliation row and its exact detail bytes; a sweep candidate skips the encode for rows its retention filter drops. The non-finite valuation refusal that the reconciliation encode raises today (ledgr_config_non_finite, cut 5 amendment_valuation) moves to an explicit typed finiteness check at the same point, with the same class, message and precedence." Acceptance 2: "pulses whose reconciliation row the sink does not retain perform no detail JSON encode; retained rows keep their exact detail bytes; every failure keeps its exact class, reason, values and retained diagnostic, including amendment_valuation's ledgr_config_non_finite". |
| RP9 | LDG-3177 `scope`, first two sentences after "evidence."; `acceptance` item 1 | The contract says "newly visible and re-entering IDs receive `list()`" (contract-availability-context-and-state). Removing the padding without saying so changes what the strategy sees, and the persisted state bytes change undeclared. | Scope: "Stop padding absent asset state across the full instrument axis in the stored and carried representation. The strategy-visible ctx$state_prev$asset_state keeps its contract: newly visible and re-entering IDs read list() and exited IDs are removed. Canonicalize each actual state update once and keep the required P5 resume cursor write. The persisted strategy_state bytes of declared-session runs change by the removed empty entries, which the cut's evidence impact and the A0 successor predicates record." Acceptance 1, append: "and a strategy reading the asset_state of a newly visible ID still receives list()". |
| RP10 | cut 6 `decisions` (8), whole item | Removing the constructor touches about 120 `ledgr_backtest(` calls in 42 test files. Most are setup for unrelated claims (FIFO, metrics, plotting), so the "unique to that removed surface" wording does not cover them. There are 12 or more `LEDGR_LAST_BAR_NO_FILL` expectations, and LCL-0300 plus the claims rows at `tests/claims.yml` 2146, 2585 and 2806 cite the constructor. | "(8) Test migration. (a) Constructor migration from ledgr_backtest() to ledgr_experiment() plus ledgr_run() changes only the constructor invocation and its arguments; fixtures, fault locations, expected conditions and numeric oracles do not change. (b) Assertions naming deleted dense internals move to the unified owner only when the same fixture, semantic oracle, fault boundary and failure sensitivity remain. (c) An oracle changes only for a row of the frozen expected-difference table, named with its cause in the ticket evidence. (d) Tests unique to the removed constructor (argument checks, raw-data and universe inference, ledgr_backtest_availability_unsupported) are deleted only after the claim map shows their execution and result claims on ledgr_run(). The claims.yml rows that cite the constructor or the frozen dense rule are edited in the same ticket with stated reasons." |

## Should-fix

- **S1 (LDG-3174 teaching ownership).** Deleting the warning also requires
  edits to these places, which are not listed in LDG-3174's scope:
  - the help topic (`R/condition-reference.R:1287-1306`,
    `man/LEDGR_LAST_BAR_NO_FILL.Rd`, alias `ledgr_last_bar_no_fill`);
  - `R/sweep.R:61` roxygen;
  - the `test-documentation-contracts.R:642,1458-1483` assertions;
  - six vignettes (`execution-semantics`, `indicators`, `reproducibility`,
    `risk-and-cost`, `strategy-authoring-tools`, `strategy-development`).

  Name them in LDG-3174 so the ticket stays green under macro rule 7, rather
  than leaving them to LDG-3178.
- **S2 (frozen refusals on the implied clock).** State in LDG-3171 that a
  bars-only snapshot whose experiment declares a `valuation_policy` still
  refuses (`ledgr_availability_sessions_required`; activation contract
  `contracts.md:1055-1058`). Also state that a fewer-than-two-pulse scoring
  range still refuses `ledgr_run_window_too_short`. Today that check is
  partly a dense-only guard branch (`R/run-snapshot.R:82`).
- **S3 (fixtures).** Add three fixtures to LDG-3170 and LDG-3171:
  - a snapshot with an unrequested instrument that has extra timestamps,
    proving the clock is drawn over the requested instruments only, as the
    guard's SQL is today;
  - a Date-typed opening and window boundary on a date with two pulses;
  - both midnight-UTC and 21:00-UTC daily bars.

  Also name the retained UTC-date boundary rule for implied clocks as a
  justified preparation predicate. The WS40 Date branches are on the
  consolidation list.
- **S4 (non-positive resolved price).** The dense planner rejects a
  non-positive resolved price with reason code 2 (`execution_bar_missing`,
  `R/fold-engine.R:172`, `R/fold-carrier.R:178`). That reason feeds no
  diagnostic today. Say whether the unified P5 writes a diagnostic for it. If
  it does, add it to the difference table.
- **S5 (macro rule 14 routing).** LDG-3177 should list each remaining
  per-pulse `canonical_json()` call and its route:
  - intent detail, `R/fold-engine.R:998`;
  - the risk segment, `:1074`;
  - affordability failure, `:1259`;
  - the state encode, `:1587`, routed to WS5 typed state.

  Rule 14 requires every cut touching these paths to remove or route them.
- **S6 (stale-mark predicate).** `R/fold-engine.R:1108-1110` calls
  `all.equal()` per stale instrument with the default 1.5e-8 tolerance. The
  vectorized replacement must reproduce `all.equal.numeric`'s scalar rule
  (relative to `|target|` above the tolerance, otherwise absolute). Add a
  boundary witness on each side. The macro citation `:1002-1007` is stale.
- **S7 (peer milestone scope).** Macro WS3 says "all lanes are timed again
  after WS4b". The draft reruns only "the affected ledgr cells". Either rerun
  all lanes, or state why unchanged peer engines are not re-timed and how
  host drift is controlled for the ratios.
- **S8 (walk-forward build count).** LDG-3171 acceptance 5 counts "one shared
  build per sweep/window input". Give the expected count for a walk-forward
  session (per fold, as today). Route session-level sharing to H9/WS9b so the
  counter has a definite oracle.
- **S9 (compiled envelope wording).** LDG-3172 keeps the compiled admission
  unchanged. Contract-availability-targets ties the refusal to
  "availability-aware execution". Restate the admission predicate as "no
  declared sessions or runtime fact families", and add a witness that a
  compiled request on a declared-session experiment still refuses
  `ledgr_compiled_availability_unsupported`.
- **S10 (`ledgr_backtest_bench`).** LDG-3175 should name the exported
  `ledgr_backtest_bench(bt)` (`R/backtest-results.R:322`) as a retained
  result-handle function. Its redesign belongs to H7.
- **S11 (stale probe clock).** The one-execution-mode probe ran on
  `93d801a8`, before Cut 16. Its TTR strict-path figure (137x `t_pre`) is
  older than the indicator-history catalogue work. LDG-3170 should remeasure
  the feature-preparation split once rather than cite it (macro rule 10
  permits a new measurement when the old one is stale).
- **S12 (macro text).** The WS4b 2026-10-30 amendment still reads "with
  bounds set at the cut". A one-line note that rule 16 supersedes it would
  stop RP2 being re-litigated. This is a maintainer edit; this review does
  not edit the macro plan.

## Nits

- **N1.** LDG-3174 claims two things: the final-pulse rule and the identity
  bump. Decision (5) couples them, so the grain is acceptable. Its title
  could say "and bump identity rule 5" for search.
- **N2.** The README status reads well. The macro header "Accepted by the
  maintainer on 2026-10-28 (revision 7 ..." could date revision 7 itself.
- **N3.** LDG-3175 depends on LDG-3174 only by preference. The real
  technical prerequisite is RP3's A0 migration.

## Per-ticket ownership and acceptance

| Ticket | Owner | One claim | Dependency | Acceptance can fail | Findings |
| --- | --- | --- | --- | --- | --- |
| LDG-3170 | ledgr dev harness | yes | none (after acceptance) | yes for the census row; decisions not yet built can only have successor witnesses | RP2, RP3, RP6, S3, S11 |
| LDG-3171 | ledgr preparation | yes | 3170 | yes | Type 2 (a, f, g), RP7, S2, S3, S8 |
| LDG-3172 | ledgr entry routing | yes | 3171 | yes | RP4, S9, Type 2 (b) |
| LDG-3173 | ledgr fold P1/P2 | yes | 3172 | yes | Type 2 (d, h), RP5 |
| LDG-3174 | ledgr P3-P5 and identity | coupled pair | 3173 | items 3 and 4 fail as written (fingerprint) | RP1, S1, S4 |
| LDG-3175 | ledgr public API | yes | 3174 (preference) | yes | RP3, RP10, S10, N3 |
| LDG-3176 | ledgr deletion | yes | 3175 | yes | RP5 |
| LDG-3177 | ledgr hot path | yes ("remove the floor, keep the evidence") | 3176 | yes | RP8, RP9, S5, S6 |
| LDG-3178 | ledgr verification and milestone | yes | 3177 | yes | RP2, S7 |

No ticket overreaches into WS5 (flat ctx, typed declared state), WS6 (frame
retirement), WS7/WS8 (readers, schema 125) or worker batching, apart from the
padding contract (RP9). Two tickets silently decide product questions:
LDG-3172 by its phrase "one feature hydration and history-start rule"
(Type 2 row a), and LDG-3177 by changing the reconciliation refusal (RP8).

## Checked and found clean

- Decisions (1) to (4) and the macro revision 7 amendment state the four
  maintainer choices accurately. No public policy knob is introduced.
- The final-pulse cardinality matches the carrier. The carrier has one
  rejection row per actionable ordinal, the epoch is NA exactly for
  `final_pulse_no_execution` (`contracts.md:284`, `R/fold-carrier.R:178,333`),
  and the token is already in the closed reason vocabulary
  (`contracts.md:1424`), so no schema token is added. The dense warning fires
  once per actionable target (`R/fold-engine.R:151-158`), which the probe
  confirms: one target change produced one warning.
- The strict coverage rule sits at the right boundary. The guard refuses
  before the fold with `LEDGR_SNAPSHOT_COVERAGE_ERROR`; its per-instrument
  count compares against the distinct pulses of the requested instruments in
  the requested range (`R/run-snapshot.R:62-124`). LDG-3171's "requested
  instruments and executable range" wording matches.
- Corporate-action-only snapshots can use the bar-native clock: the plan
  already resolves clocks against `pulses_posix` with dispositions off
  (`R/backtest-runner.R:959-968`). Only the refusal outcome is undecided
  (Type 2 row f).
- `ledgr_run_config()` and `ledgr_config()` are shared with `ledgr_run()`
  (`R/backtest.R:543,578`), so removing the constructor leaves no orphaned
  config builder. The result-class S3 methods and `ledgr_run_open()` are
  independent of `ledgr_backtest()`.
- The sweep shares the same fold through `R/sweep.R:1913`. No second fold
  entry exists beyond the three named in RP4.
- The `canonical_json()` cache rule in LDG-3177 matches the macro JSON-audit
  amendment.
- The workstream 14 close-review brief covers the seven shapes, a cold read,
  mutation of the deletion and identity witnesses, a test-migration audit and
  a zero-unowned census.
- The dependency chain is linear. No product deletion precedes its
  replacement; the harness consumers are the exception (RP3).
- The README diff is accurate: cuts 1, 2, 4 and 5 closed, Cut 5 merged at
  `b5622f09`, Cut 6 not authorized.

## Evidence

- `grep -c availability_active R/*.R` at b5622f09 gives 140 occurrences in
  14 files (counts in RP5).
- Store bindings: `ledgr:::ledgr_store_format_bindings()` lists 28 names,
  including `ledgr_identity_rule_version` (value 4). The current fingerprint
  JSON contains `"ledgr_identity_rule_version":4`.
- Dense economics probe: a throwaway script, not committed, with two
  instruments, five daily bars, zero cost, cash 1000 and `ledgr_run()` on
  b5622f09:
  - `overspend`: DONE, min cash -4000, 1 fill, 0 warnings.
  - `new_short`: DONE, 1 fill.
  - `final_change`: DONE, 1 fill, 1 `LEDGR_LAST_BAR_NO_FILL` warning.
  - Identity rule 4.
- No oracle, A0, timing or real-data run was performed by this review.
