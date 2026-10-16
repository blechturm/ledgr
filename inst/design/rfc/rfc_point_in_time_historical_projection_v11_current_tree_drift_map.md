# V11 Current-Tree Drift Map

Role: record; history-wave H0 audit reconciliation.
Status: working; Type 1 review returned `PASS_AFTER_PATCHES` on the H0 record.
Authority: non-designing reconciliation input to history-wave stage 2 and the
later v12 synthesis. This record changes no semantics, contract, ticket, or
implementation.

## 1. Scope and reading rule

This map reconciles every load-bearing clause in the accepted
[historical-projection v11](rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md)
with the post-Cut 15 tree. It is not v12 and does not apply the working
[history-wave decision register](rfc_history_wave_v0_2_2_decisions.md) early.
The register's accepted maintainer decisions are nevertheless later inputs
that can supersede v11 for the purpose of drafting v12.

Each numbered row below has exactly one of the four H0 dispositions:

- `retain`: carry the semantic claim forward without changing its meaning;
- `rewrite for current architecture`: preserve the applicable meaning, but
  restate it against current ownership, vocabulary, identity, storage, or
  evidence;
- `supersede by an accepted history-wave decision`: do not carry the v11
  clause; use the named accepted register decision instead; or
- `retire because its mechanism was deleted`: omit the clause because Cut 15
  removed the mechanism and deliberately provided no compatibility surface.

Rows split compound v11 paragraphs where their parts have different
dispositions. Historical evidence remains readable even where its operative
claim is rewritten or retired.

## 2. Current-tree reference frame

These are the controlling facts used throughout the map.

- The history surface is not implemented. There is no exported
  `ledgr_history_frame()`, `ledgr_history_matrix()`, or `ctx$window()` in the
  current tree. The accepted Session 0 direction is the classed
  `ledgr_history_frame()` result plus `ledgr_history_matrix()` adapter and
  retained exclusions. The adapter is not a second reader. See
  [Session 0](rfc_history_wave_v0_2_2_decisions.md#session-0-public-history-api)
  and the adopted
  [research strategy UX brief](../ledgr_v0_2_2_spec_packet/research_strategy_ux_brief.md#2-ux-principles).
- The accepted history implementation target is the availability path only.
  Dense execution still exists but is frozen and receives no history feature
  or branch. A fixed
  basket or all-snapshot-instruments request with availability facts is the
  full-membership shape on that path; it is not a second dense history mode.
  See the register's **Resume here** mode decision, the macro plan's
  [execution-core consolidation](../ledgr_v0_2_2_spec_packet/macro_plan.md#execution-core-consolidation),
  and the accepted
  [WS39 record](../../../dev/bench/v0_2_2_sharadar_run/evidence/ws39_schema120/README.md).
- The fold is one envelope, `ledgr_fold_envelope()`, and five stages:
  `ledgr_fold_stage_observe_settle()` (P1),
  `ledgr_fold_stage_decide()` (P2), `ledgr_fold_stage_plan()` (P3),
  `ledgr_fold_stage_apply()` (P4), and `ledgr_fold_stage_commit()` (P5).
  P1 is the sole reader of history-derived values and P2 the sole adapter to
  public context. Public `ctx` and all data-frame frames are P2 locals; no
  data frame may be a stage argument or fold-carrier slot. See the accepted
  [fold architecture](rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md#4-bound-architecture),
  [mode/history seam](rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md#6-mode-history-and-compiled-seams),
  and `R/fold-engine.R` by the function names above.
- Runtime feature values are ephemeral. Cut 15 LDG-3049 and LDG-3050 deleted
  the process-local feature cache, its public clear function, hit/miss
  telemetry, `persist_features`, feature-row buffers and writes, and the
  `features` table. There is one uncached production feature path; explicit
  `ledgr_precomputed_features` is a caller-supplied validated payload, not a
  cache. See the [Feature Path contract](../contracts.md#contract-context-feature-path),
  [Persistence contract](../contracts.md#contract-persistence-connections),
  and `tests/testthat/test-feature-retention-removal.R`.
- Experiment-store schema 120 is the sole current store format, config
  identity rule 3 is exact `3L`, and snapshot content hash rule 3 is the sole
  executable hash rule. Older, newer, missing-marker, invalid, or
  fingerprint-mismatched stores refuse with
  `ledgr_store_rebuild_required`; a non-3 sealed snapshot marker refuses with
  `ledgr_snapshot_hash_rule_unsupported`. There is no migration, legacy
  reader, inference, or fallback. See
  [Execution identity](../contracts.md#contract-execution-identity),
  [Snapshot identity and verification](../contracts.md#contract-snapshot-identity-and-verification),
  and [Current Store Format](../contracts.md#contract-persistence-current-format).
- The current shipped hydration rule is still the temporary Cut 9 rule:
  feature state starts at scoring start. Accepted history-wave Session A and
  B decisions replace it only when implemented: history and every indicator
  start at the beginning of the data; decisions remain limited to scoring
  pulses. See [Scoring And Feature Start](../contracts.md#contract-execution-window-start),
  [Session A](rfc_history_wave_v0_2_2_decisions.md#session-a-what-history-a-strategy-sees),
  and [Session B](rfc_history_wave_v0_2_2_decisions.md#session-b-one-hydration-rule).
- Implementing Sessions A/B must retire or replace the current scoring-start
  hydration seams: the walk-forward fold-window `hydration_start_utc` field
  and constructor formal, the stored
  `walk_forward_folds.hydration_start_utc` column,
  `ledgr_unsupported_hydration_start`,
  `ledgr_precomputed_hydration_mismatch`, and
  `ledgr_precomputed_features$warmup_range$start`. This is an inventory of
  current seams, not a choice of their replacement representation.
- Availability has no public mode flag. Declared availability fact families or
  a valuation policy activate it; a complete session calendar is mandatory;
  and omitted valuation policy defaults to
  `ledgr_valuation_stale(max_sessions = 5, exhausted = "freeze")`. Existing
  boundary classes include `ledgr_availability_inactive`,
  `ledgr_availability_sessions_required`, `ledgr_sessions_incomplete`,
  `ledgr_invalid_valuation_policy`, `ledgr_indicator_gap_unsupported`, and
  `ledgr_indicator_gap_parity`. History design must not silently give those
  current names new meanings or invent an unrecorded fallback. See
  [Activation And Session Calendar](../contracts.md#contract-availability-activation-and-calendar)
  and [Availability-Aware Strict Features](../contracts.md#contract-context-strict-features).

## 3. Clause-level dispositions

### V11 header and Section 1: decision and scope

| ID | V11 load-bearing claim | Disposition | Current-tree reconciliation |
| --- | --- | --- | --- |
| H-1 | V11 is the operative accepted synthesis, read against its 2026-09-28 implementation baseline; it authorizes no implementation except through its Section 7 cut. | rewrite for current architecture | V11 remains the accepted derivation record until v12 is accepted, but its baseline and Section 7 sequence are historical. The current route is H0-H6 in the [history-wave execution plan](../ledgr_v0_2_2_spec_packet/macro_plan.md#history-wave-execution-plan), with the register still in stage 2. |
| 1.1 | Ship causal histories of prices and indicators for statistical and ML consumers, with declared carry and aligned missingness evidence. | retain | This is still the wave's product objective. The public container and execution ownership change in later rows, not the causal/missingness obligation. |
| 1.2 | Prepare values and evidence before execution and expose bounded indexed reads through one fold. | rewrite for current architecture | Preparation remains outside strategy callbacks, but the bound ownership is now E plus P1-P5: E prepares run inputs/services, P1 reads history-derived typed values, and P2 creates the requested public frame locally. |
| 1.3 | Prefer an ordinary prepared series and permit whole-series recalculation; do not require per-knowledge-segment storage, an invalidation graph, or partial updates. | retain | No accepted later decision mandates those optimizations. Session E still owns the representation and resource budget. |
| 1.4 | Deferring optimization does not weaken causality, declared carry, missingness disclosure, or correctness; fitted imputers and general model lifecycle are separate. | retain | The history wave still excludes fitted-model lifecycle and keeps detecting correctness fixtures. |
| 1.5 | V11 replaces v10 and earlier superseded architecture or sequencing does not add obligations. | retain | V10 and earlier artifacts remain derivation evidence only. V12 will replace v11 rather than layering another narrow amendment over it. |

### V11 Section 2: evidence and supported inference

| ID | V11 load-bearing claim | Disposition | Current-tree reconciliation |
| --- | --- | --- | --- |
| 2.1 | The semantic spike demonstrates a revision seam and finite-window propagation, while recursive and panel-dependent cases prevent generalizing that bound; it does not prove production cost or segmented storage need. | retain | This remains valid design evidence and is consistent with open Session D indicator-history classification. |
| 2.2 | The 2019-2021 exposure investigation and its reported counts are the workload evidence for deferring extra revision machinery. | rewrite for current architecture | Keep those figures as historical evidence, not the current workload baseline. Current real-data input is the accepted WS39 schema-120/rule-3 build: 1998-2026, 5,481,906 bars, 1,166 instruments, 7,213 sessions, 290,811 membership rows, and 829 lifetime rows. H1 must add post-adapter gap, refusal, delisting, correction-chain, runtime, and memory evidence; those data do not yet exist in the accepted record. |
| 2.2a | Multiset source comparison and civil-date fill joins are the correct interpretation of the old exposure CSVs because event keys were non-unique and opens/closes used different timestamps. | rewrite for current architecture | Preserve those methods with the historical report. They do not prescribe H1's current evidence schema or authorize joining current point-in-time facts by civil date; PIT-S2-011 already leaves venue civil-date semantics open. |
| 2.3 | The exposure report, scripts, CSVs, and provenance must be preserved before integration. | rewrite for current architecture | The preservation obligation is discharged at v11 commit `412f600`; it is provenance, not an open gate. The current H1 evidence extends WS39 rather than rerunning or replacing that historical investigation. |
| 2.4 | Zero affected requests does not prove zero late arrival; `assume_effective` is an assumption and a capture interval is not first market knowledge. | retain | Accepted Session C makes the pragmatic rule explicit: facts without a knowledge clock are known when effective and disclosed; real knowledge clocks remain representable. |
| 2.5 | Zero volume is a separate execution-policy question; admission, execution permission, and valuation are distinct authorities, and repeated prices alone do not prove vendor carry. | retain | Those ownership distinctions remain valid and history treatment must not create an execution or valuation permission. |
| 2.6 | The existing liquidity/capacity route is sufficient and zero-volume handling needs no history-wave action. | retain | The ledgr-side ownership claim stands: history does not redesign liquidity or capacity policy. Independently, the research adapter drops vendor-carried zero-volume rows under LFB-027 so ledgr receives missing observations, and H1 measures gaps after that adapter transformation. |

### V11 Section 3: information, shape, and ownership

| ID | V11 load-bearing claim | Disposition | Current-tree reconciliation |
| --- | --- | --- | --- |
| 3.1 | For a request at decision pulse `t`, every historical column `s <= t` uses evidence knowable at `t` and applicable at `s`; seal and wall time never substitute, future-known facts are excluded, and the existing family resolver remains authoritative. | retain | This is the still-valid two-clock causality rule. Session A separately forbids `s > t`, and Session C states how absent knowledge clocks are disclosed. |
| 3.2 | `ctx$window()` is the public one-feature reader returning an instruments-by-lookback numeric matrix in `ctx$universe` order. | supersede by an accepted history-wave decision | Session 0 adopts `ctx |> ledgr_history_frame(...)` as the history reader and `ledgr_history_matrix()` as an identity-preserving adapter over that result. Neither function exists yet; `ctx$window()` must not be reintroduced as the operative surface. |
| 3.3a | Columns use one shared prepared/session-axis unit, not each asset's last `N` non-missing observations. | retain | A common time axis remains necessary for aligned history. Its exact unit, including the relationship to instrument narrowing, is routed to H2 and stage-3 drafting rather than selected here. |
| 3.3b | Early requests have leading `NA`; an empty axis is `0 x lookback`; no second warm-up rule or hidden pre-range history is introduced; declared hydration may supply a carry seed without expanding the public axis. | supersede by an accepted history-wave decision | Session A replaces leading padding and the no-pre-range boundary with data-start history. Session B replaces declaration-specific hydration and the old no-second-warm-up/start mechanism with one data-start rule for every indicator and entry point. Session 0 replaces the exact `ctx$window()` `0 x lookback` container shape, while the generic empty-shape obligation remains in row 8.3a. H2/stage 3 must decide what a shorter lookback's first column may use as a causal carry seed without reviving a separate public axis or hydration rule. |
| 3.4a | One call returns one numeric feature/series, not a list or multi-feature tensor. | retain | The adopted UX brief agrees: one call reads exactly one sealed bar field or one resolved feature. The new classed result changes the container, not this call cardinality. |
| 3.4b | Raw prices and companion evidence share the same aligned history semantics. | rewrite for current architecture | The classed history result carries axis, cutoff, missingness treatment, included IDs, exclusions, and aligned evidence; `ledgr_history_matrix()` only projects that already-constructed result. Exact evidence columns remain stage-3 drafting work. |
| 3.4c | The current decision axis includes held nonmembers, and membership at a past column does not by itself exclude an otherwise admissible observation. | rewrite for current architecture | The held-nonmember and past-membership semantics remain inputs. The default requested row set, the included/excluded representation, and how a held nonmember appears in an estimation request are not settled by the UX brief's proposed `instruments = "admissible"`; H2 and stage 3 must bind them without converting estimation exclusion into an execution target. |
| 3.5 | The engine may keep complete prepared backing, but supported reads enforce cutoff/axis and returned windows do not expose mutable engine state; a maximum lookback is not itself a causality boundary and reflection is outside the guarantee. | rewrite for current architecture | Complete backing may be run-local and ephemeral only. It is not a feature cache or durable feature table. E owns preparation, P1 reads typed history-derived values, P2 materializes a fresh public frame, and `ctx` must not reference the fold carrier. |
| 3.6 | The projection is the sole numerical owner; no lower projector or automatic full-panel long materialization is introduced, and the context surface owns supported access. | rewrite for current architecture | P1 is the sole history-derived reader and P2 the sole public adapter. The classed frame is constructed only on request; wide/long/matrix forms are not retained together. The history wave must amend the fold service census if it adds an incremental service. |
| 3.7 | History is for estimation, not replay of historical `held`, `priced`, `mark_age`, or trading state; explain owns retained run evidence. | retain | No public portfolio replay mode is authorized. The pending PIT-G-015/PIT-S2-007 need for pre-window mark and entitlement inputs is fold-continuity substrate, not permission to add those planes to the public estimator frame. |
| 3.8 | Equal-cutoff, equal-policy reads agree; later-cutoff views may differ without rewriting an earlier decision. | retain | Restate parity across scalar feature reads, the classed history frame, and its matrix adapter. Session 0 removes `ctx$window()`, not scalar feature reads. Durable decision evidence remains immutable. |

### V11 Section 4: session axis and release work

| ID | V11 load-bearing claim | Disposition | Current-tree reconciliation |
| --- | --- | --- | --- |
| 4.1 | Current feature hydration uses venue open sessions, with LDG-2866/2867 and old availability gate 21 as the current repair route. | rewrite for current architecture | The stable current rule is in [Availability-Aware Strict Features](../contracts.md#contract-context-strict-features): strict windows count venue open sessions on the shared pulse axis, `known_inactive` does not remove sessions, and real observations inside inactive intervals remain inputs. LDG-2866/2867 and gate 21 are historical anchors; the temporary feature-start rule is in the Execution contract. |
| 4.2 | Instrument-narrowed expected sessions remain separately scheduled; if shipped, narrowing is cutoff-resolved and aligned back to the common column axis. | rewrite for current architecture | The route is still live: the RFC pipeline's [instrument-specific session-axis row](README.md#instrument-specific-session-axis) is `Obligations open`, WS3 says to [narrow expected sessions where evidence requires it](../ledgr_v0_2_2_spec_packet/macro_plan.md#ws3-point-in-time-history-and-feature-map-addressing), and the [horizon migration reconciliation](../ledgr_v0_2_2_spec_packet/horizon_migration_reconciliation.md) routes v11 Section 4 to that pipeline row. The shared venue-session contract, its current treatment of real observations inside inactive intervals, and Sessions A/B do not silently dispose of these owners. H2 must require v12 to reject, defer, or bind narrowing; a bind must define cutoff resolution, common-axis alignment, and treatment of observations inside inactive intervals, then reconcile both the WS3 and pipeline obligations. |
| 4.3 | Strict values are cutoff-invariant only for fixed observations, axis, and treatment; numerical correctness is required, but segmentation/partial storage is not. | retain | The qualification and detecting obligation still apply, including any later accepted axis choice. |

### V11 Section 5: missing-data policy, barriers, and disclosure

| ID | V11 load-bearing claim | Disposition | Current-tree reconciliation |
| --- | --- | --- | --- |
| 5.1 | Missing-data preparation is explicit, outside indicator callbacks and the fold, and never creates observed bars, membership, trading permission, valuation marks, or execution prices. | rewrite for current architecture | Preserve the non-fabrication rule. In the current fold architecture E prepares services/inputs, P1 reads history-derived values, and P2 adapts a public frame. No history data frame or treatment step may cross stage boundaries or mutate execution/valuation planes. |
| 5.2 | Price-input carry defaults on, is independently switchable, has a required maximum age defaulting to five venue sessions, carries each OHLC field from its own source, and never carries volume. | retain | This remains an accepted but unimplemented history-treatment rule. It is not the current valuation policy. PIT-G-013 already leaves return/volatility-family treatment open, so H0 does not infer zero returns from carried prices or choose bridging. |
| 5.3 | Indicator-output carry defaults off, may be enabled independently with a declared age, follows input treatment/calculation, and cannot be enabled by disabling input carry. | retain | No accepted later decision removes this option; its implementation and disclosure remain WS3/WS4 work. |
| 5.4 | Carry age uses venue sessions from the original source, never refreshes, never fills backward, invents no leading value, and inserts no closed-day columns. | retain | These remain semantic invariants for either carry stage. |
| 5.5 | Required-field admission, readiness on treated inputs, calculation validity, and output carry eligibility are separate stages; the engine imposes no carried-share threshold. | retain | Session D must still classify bounded versus history-dependent indicators, readiness, gaps, and tolerance. H0 must not collapse those open choices into the current `strict_window` implementation. |
| 5.6 | Only a gap caused by unavailable required input after readiness and with an admissible earlier output is fillable; warm-up, failed readiness, errors, and unsupported computation are not. | retain | The reason taxonomy is still required even though exact public labels and the recursive gap rule remain open. |
| 5.7 | The five-session history-carry default bounds age, not error or completeness; expiry is `NA`, and fitted imputation is consumer-owned. | rewrite for current architecture | Keep this statement explicitly about history input carry. The current public `ledgr_valuation_stale(max_sessions = 5, exhausted = "freeze")` is a different policy for held-position marks; `freeze` or `refuse`, `valuation_frozen`, and `valuation_horizon_exhausted` must not be reused as history-missingness meanings. The valuation default was selected from later gap evidence, unlike v11's history-carry default. |
| 5.8 | `known_inactive` is a source-to-destination carry barrier resolved with facts knowable at the request cutoff. | retain | Current lifetime vocabulary is `known_active`, `known_inactive`, and `unknown`; the public target restriction reason is `lifetime_inactive`. Those execution labels do not replace aligned history barrier evidence. |
| 5.9 | Under an undeclared basis, knowable corporate actions create barriers at each supplied entitlement/effective clock; payment and knowledge time do not locate a barrier; declared `split_adjusted` removes that barrier; `distribution_adjusted` execution is refused. | rewrite for current architecture | Current execution distinguishes stored identity from effective disclosure: an availability-aware snapshot with `price_basis = NULL` keeps identity `NULL` but runs and reports `split_adjusted` as an assumed default. Declared `split_adjusted` is reported as declared; `distribution_adjusted` refuses with `ledgr_distribution_adjusted_bars_unsupported`; invalid constructor vocabulary uses `ledgr_invalid_price_basis`. The barrier behavior of assumed-default split-adjusted data is unresolved and routed in Section 6. |
| 5.10 | A knowable terminal assertion permanently blocks carry after its terminal boundary; a later observation never restarts it. | retain | Terminal event labels and current settlement policy remain distinct from the history barrier, but the permanent boundary rule remains applicable. |
| 5.11 | A knowable corporate action lacking both event clocks fails only when basis is undeclared and carry is enabled; strict policy or a declared basis does not trigger it. | rewrite for current architecture | Session C now distinguishes absent knowledge clocks (`assume_effective`, disclosed) from absent event clocks. Current public conditions include `ledgr_corporate_action_clock_mismatch` for supplied off-axis clocks and `ledgr_invalid_corporate_action_event` for invalid execution events, but no accepted condition specifically names this history-preparation case. The class and parent are routed in Section 6 rather than invented here. |
| 5.12 | After a nonterminal barrier, a new real observation may seed later carry; later boundaries remain, and actual admitted observations are never quarantined merely because carry is blocked. | retain | This continues to separate source observations from treatment. |
| 5.13 | History discloses aligned original/remaining missingness, carry/calculation provenance, source time/age, warm-up/later gaps, reasons, and carried-input counts/shares without a universal usability flag. | retain | The exact classed-frame columns remain stage-3 vocabulary, but the evidence distinctions are still required. |
| 5.14 | Source, transformation, and consumption are separate; treatment, policy, implementation version, cutoff, and axis enter identity; strict and padded requests cannot share identity and later views cannot mutate earlier results. | rewrite for current architecture | Config identity rule 3 and snapshot hash rule 3 are current as v12 drafting begins; H0 does not presume rule 3 remains the final history identity rule. The register's existing D3-F5 history-identity work decides whether accepted history-class or policy inputs require an identity advance. Runtime history results are immutable values, not durable feature rows, and no cache key or persisted feature artifact exists. |
| 5.15 | Existing cache machinery owns treatment identity and prevents wrong reuse. | retire because its mechanism was deleted | The process-local cache, clear API, cache keys, hit/miss telemetry, `persist_features`, feature-row persistence, resume handling, and `features` table were deleted by LDG-3049/3050. Do not recreate them for history. Explicit precompute validation is the only existing reusable-payload seam. |
| 5.16 | Future fitted transforms may consume original missingness under training-only scope, but no DAG, registry, or fitted-model store is required. | retain | Model lifecycle remains a later RFC and does not expand WS3. |

### V11 Section 6: preparation and representation

| ID | V11 load-bearing claim | Disposition | Current-tree reconciliation |
| --- | --- | --- | --- |
| 6.1 | Use one ordinary prepared numerical series where correct; resolve evidence at `(s, t)` with both clocks because the diagonal `pmax(effective, knowledge)` representation alone cannot answer history. | retain | The current prepared provider still uses diagonal segments for decision/execution views. It is evidence of why the history representation needs both clocks, not the historical answer itself. |
| 6.2 | When supported policies make history cutoff-dependent, compute correct answers by the simplest adequate method; whole-series recalculation is allowed and fact arrival need not create a numerical copy. | retain | Session E decides production representation and size guard after H1; no segmentation or incremental algorithm is preselected. |
| 6.3 | Preparation precedes the fold; retrieval cannot perform callback SQL, rebuild fact segments, or recompute a whole panel per pulse; run and sweep share one fold. | rewrite for current architecture | E prepares the run-scoped substrate, P1 is its sole history reader, and P2 builds a requested frame. The current private `provider$history()` raw-bar closure performs per-call SQL and cannot become the P2 reader unchanged. Run and sweep share `ledgr_fold_envelope()`, and walk-forward invokes that same run path. `ledgr_pulse_snapshot()` is a separate dense one-pulse helper with its own snapshot SQL and feature computation; it makes every requested instrument a member and does not simulate availability-aware state. Inspection parity is therefore an H2 question, not a current shared-fold fact. |
| 6.4 | Prepared data are reusable while cursors are consumer-local, may re-seek backward, and returned windows remain immutable; sweeps, inspection, and reopened runs have independent consumers. | rewrite for current architecture | Any cursor-bearing history service must be run/candidate-local, declared in the fold synthesis Section 5.2 census by amendment, called by P1 only, and absent from the carrier/public context. P2 returns a new classed object. |
| 6.5 | Numerical segmentation, trigger tables, exact invalidation bands, and partial updates are deferred; finite-window locality does not certify recursive, cross-sectional, fitted, or narrowed-axis dependencies. | retain | This is still the correct boundary for open Session D/E work. |
| 6.6 | Existing prepared fact segments remain; measure ordinary preparation, delivered evidence, storage, and worker copies, then optimize only an observed bottleneck. | rewrite for current architecture | Prepared provider segments remain for current fact views, but they are not a selected history representation. H1 extends the WS39 baseline; Session E sets the one-run and representative-worker memory budget and size guard. The old `2.11x` arithmetic remains non-runtime history. |

### V11 Section 7: checkpoint and ticket-cut boundary

| ID | V11 load-bearing claim | Disposition | Current-tree reconciliation |
| --- | --- | --- | --- |
| 7.1 | Checkpoint (a): effective column and knowledge cutoff resolve through existing precedence, completeness, and supersession authority. | retain | Session C adds pragmatic missing-clock rules but keeps one resolver authority. Session F still owns correction-chain validity. |
| 7.2 | Checkpoint (b): raw clocks must support `(s, t)` retrieval without callback SQL, a second resolver, or portfolio replay; a diagonal-only lookup must fail a detecting case. | retain | The two-clock spike and current diagonal provider make this still necessary. Representation and resource choices remain Session E work. |
| 7.3 | Checkpoint (c): both carry stages, required-field admission, aligned provenance, and measured preparation/delivery cost are implementation and release obligations. | retain | H3-H6 carry these obligations; current valuation carry does not discharge either history carry stage. |
| 7.4 | Checkpoint (d): every supported configuration must produce cutoff-correct values/evidence and preserve earlier outputs; output carry is tested independently. | retain | Accepted Session C explicitly keeps v11 Section 8 detecting fixtures, and WS3 owns numerical correctness at the history boundary. |
| 7.5 | The spike proves only one seam; detecting synthetic fixtures remain necessary even if the real workload has zero affected requests. | retain | WS39 supplies current aggregate evidence, not a replacement for failure-sensitive causal fixtures. |
| 7.6 | Resolve representation questions before interfaces, permit only a bounded probe for remaining executable uncertainty, and do not commission a comparative segmentation project. | rewrite for current architecture | The current sequence is H1 evidence, Sessions D-F, consolidated v12, Type 1 review, then WS3/WS4 tickets. Session E may choose a representation and budget; no new spike is authorized by H0. |
| 7.7 | At ticket cut map the contract amendment, required-field declarations, companion representation, context surface, provenance preservation, and narrowing to owners; return infeasible representation/cost to the maintainer. | rewrite for current architecture | Exposure preservation is discharged. H3/H5 own the new requirement-to-owner mapping; H1/H2 supply real-data and budget evidence. The old narrowing route is the unresolved item in Section 6, and any budget breach follows H6's explicit maintainer-exception route. |

### V11 Section 8: contract changes and detecting requirements

| ID | V11 load-bearing claim | Disposition | Current-tree reconciliation |
| --- | --- | --- | --- |
| 8.1 | The next packet amends strict-window-only wording for external input/output treatment while keeping hidden internal imputation prohibited, and makes admission, readiness, barriers, disclosure, cutoff identity, result immutability, and selected axis semantics explicit. | rewrite for current architecture | Current contracts already bind shipped `strict_window` behavior and point to pending history and recursive-indicator decisions. V12 must amend the stable Context, Execution, Availability, Snapshot, Persistence, and Result rule groups; it must not treat the old packet wording as current authority. |
| 8.2 | Detect seal/wall-clock substitution, future-known leakage, or omission of knowable facts with a fixture whose clocks differ. | retain | This remains the primary causal oracle. Reopen stability alone remains insufficient. |
| 8.3a | Detect a read beyond its pulse/axis, an empty-shape error, disagreement among scalar, frame, and matrix reads, and inspection failure with an empty long table. | rewrite for current architecture | These remain detecting requirements. Exercise causal bounds and empty results through the classed frame, preserve scalar-versus-frame-versus-matrix parity at equal cutoff and policy, and require inspection to handle an empty long representation without failure. |
| 8.3b | Detect early-padding errors and `ctx$window()`-specific scalar/window parity. | supersede by an accepted history-wave decision | Session A replaces the leading-padding contract with data-start history, and Session 0 replaces `ctx$window()` with the classed frame and matrix adapter. Only those surface-specific oracle parts are superseded; row 8.3a retains the underlying causal, empty-shape, scalar-parity, and inspection obligations. |
| 8.4 | Detect backward or refreshed-age carry, cross-field/volume carry, barrier crossing, lost multiple boundaries, terminal restart, and basis-related over-blocking. | rewrite for current architecture | All carry defects remain detecting requirements, but the price-basis cases must include declared versus assumed-default split-adjusted identity and use current condition vocabulary. The assumed-default barrier choice remains open in Section 6. |
| 8.5 | Detect conflation of admission, warm-up, readiness, calculation validity, and output eligibility, including missing aligned provenance. | retain | Session D supplies the final indicator classes and tolerances; the separations themselves stand. |
| 8.6 | Detect wrong values/evidence after a late-known change and preserve earlier-cutoff outputs; implementation agreement is not an oracle. | retain | Session C explicitly retains this obligation even though Sharadar does not exercise numerical revision in this release. |
| 8.7 | Detect wrong cache reuse across policy/axis/cutoff, retained-result mutation, query-order dependence, or unsupported companion distinctions returning plausible values. | rewrite for current architecture | Remove cache-specific probes. Detect instead wrong explicit-precompute reuse under rule-3 config/feature identity, mutable returned history objects, consumer/cursor query-order dependence, and an unsupported frame/matrix distinction failing to refuse. |
| 8.8 | The locality detector is corroboration only; no arbitrary timing, memory, or member-count threshold is created by v11. | rewrite for current architecture | Locality remains corroborative, but Session E must now set an explicit size guard and one-run/worker memory budget from H1 evidence. That later accepted budget, not v11, becomes the threshold. |

### V11 Sections 9 and 10: deferral, reopening, and integration

| ID | V11 load-bearing claim | Disposition | Current-tree reconciliation |
| --- | --- | --- | --- |
| 9.1 | Reopen revision optimization only when supported point-in-time behavior changes an intended request and simple correct preparation has a material cost/maintenance problem; record affected instruments/cells/requests, the consequence of a named shortcut, and correction cost; synthetic cases prove correctness and real requests prove need. | retain | This remains the complexity gate. H1/H6 provide the real workload evidence. |
| 9.2 | A new source with real knowledge clocks triggers exposure assessment, not automatic segmentation; causal approximation requires an explicit decision. | retain | Session C preserves slots for real knowledge clocks and does not authorize approximation. |
| 9.3 | Fitted imputers, liquidity, corporate-action clock vocabulary, and model lifecycle are separate routes and are not prerequisites. | rewrite for current architecture | Fitted/model lifecycle stays later; adapter-carried zero-volume bars are already handled by LFB-027; current corporate-action/session clock rules are in the Availability contract and Session C; dividend-fact mapping stays with the later adapter/WS7 rebuild. None expands WS3 automatically. |
| 10.1 | The listed 2026-09 code-line anchors are the implementation reading baseline. | rewrite for current architecture | Replace line-only anchors with current functions and contracts: `ledgr_availability_provider()` and `ledgr_availability_provider_build_prepared()` for the current provider; `ledgr_run_prepare_config()` plus the feature hydration in the current runner; `ledgr_compute_feature_series_strict()` and `ledgr_compute_feature_series()` for indicator paths; `ledgr_precompute_features()` for explicit payloads; and `ledgr_fold_envelope()` plus P1-P5 for run, sweep, and walk-forward execution. Treat `ledgr_pulse_snapshot()` as the separate dense inspection helper it currently is, not as a shared-fold anchor. `ledgr_sweep_compute_feature_matrix()` remains test-only and is not a production history anchor. |
| 10.2 | The original projection probe requires complete runtime backing in both dense and availability modes. | supersede by an accepted history-wave decision | History is availability-only. Full membership is expressed on the availability path; dense receives no history branch and leaves in the later execution-core consolidation. |
| 10.3 | Section 7 is the next ticket-cut route; the exposure files are the current integration input and no fresh RFC cycle is needed. | rewrite for current architecture | The current route is H0 drift map, H1 evidence, completion of register Sessions D-F, consolidated v12, Type 1 review, then WS3/WS4 cut. Existing Type 2 work is reused; H0 does not restart the cycle or draft v12. |

## 4. Mechanical drift versus unresolved semantics

### Mechanical drift resolved by current authority

The following changes require no new product choice in v12:

1. Replace `ctx$window()` with the accepted frame plus matrix-adapter direction.
2. Describe full membership as an availability-path shape, not a dense history
   mode.
3. Bind history ownership to E/P1/P2 and keep every public frame P2-local and
   outside the carrier.
4. Remove every operative dependency on the deleted cache,
   `persist_features`, durable feature rows, feature telemetry, and the
   `features` table.
5. State schema 120, identity rule 3, snapshot hash rule 3, and refusal of all
   non-current stored formats as current-tree facts. Do not add a compatibility
   argument, old-format reader, inference, migration, or fallback. Whether
   history inputs advance the identity rule remains with the existing
   history-identity item.
6. Replace old line and ticket anchors with the stable contract headings,
   accepted RFC sections, and current function names listed above.
7. Treat the v11 exposure figures as historical provenance and WS39 plus H1 as
   the current real-data evidence chain.

### Already-open semantics; H0 does not decide them

The register already owns indicator classes and labels, readiness,
convergence, gap transitions, tolerance, history identity, representation,
size guard, single-run and worker memory, decision-trace volume, correction
chains, civil-date boundaries, return-family carry, fold continuity, and
mark/entitlement start. These remain Sessions D-F or existing consider rows.
They are not current-tree drift to repair mechanically.

## 5. Obsolete anchors and current replacements

| V11 anchor or statement | Disposition | Current replacement or limit |
| --- | --- | --- |
| `R/availability-provider.R:28-47,211-246` raw clocks/construction | rewrite for current architecture | Use current `ledgr_availability_provider()`, `ledgr_availability_provider_build_prepared()`, and the Availability Provider/Knowledge contract. The private raw-bar `history` closure is not the public history surface. |
| `R/availability-provider-prepared.R:47-55,102-160` diagonal segments/backward seek | rewrite for current architecture | Current `ledgr_availability_prepared_segments()` and `ledgr_availability_prepared_cursor()` still support point views; v11's diagonal-insufficiency claim remains, and Session E owns the historical representation. |
| `R/backtest-runner.R:873-907` venue alignment | rewrite for current architecture | Use current runner preparation plus the Scoring/Feature Start and Availability-Aware Strict Features contract groups. The old LDG-2866/2867 route is historical. |
| `R/features-engine.R:235-246,286-328` strict calculation/all-OHLC gate | rewrite for current architecture | Use `ledgr_compute_feature_series_strict()`, `ledgr_compute_feature_series()`, `ledgr_strict_complete_window_mask()`, and current required-field/gap-contract rules. Session D still decides the future class system. |
| `R/sweep.R:1068,1276-1292,1413` projection/worker/restart anchors | rewrite for current architecture | Production sweep uses the shared runner/fold and explicit `ledgr_precompute_features()` payloads; `ledgr_sweep_compute_feature_matrix()` is test-only. History work must not add a second sweep path. |
| `R/pulse-snapshot.R:35-41` arbitrary inspection cutoff | rewrite for current architecture | Current `ledgr_pulse_snapshot()` is a separate dense one-pulse helper: it issues its own snapshot SQL, computes features from bars through the cutoff, treats all requested instruments as members, and explicitly does not simulate availability-aware state normalization. H2 must decide whether this helper becomes availability-aware or inspection parity is owned by another route. |
| Session B scoring-start hydration seams | rewrite for current architecture | Retire or replace `hydration_start_utc`, the stored `walk_forward_folds.hydration_start_utc` column, `ledgr_unsupported_hydration_start`, `ledgr_precomputed_hydration_mismatch`, and `ledgr_precomputed_features$warmup_range$start` when the accepted data-start rule is implemented. |
| Register D3-F5 citation to deleted `R/feature-cache.R:82-94` | rewrite for current architecture | The identity question remains pending, but its implementation anchor is stale after Cut 15. H2 should cite the current `ledgr_active_feature_fingerprint()` and `ledgr_feature_def_fingerprint()` definitions in `R/features-engine.R`; H0 does not edit the register. |
| Cut 13 context-surface ticket and v0.2.0.0 LDG-2866/2867/gate-21 status references | rewrite for current architecture | Use current Contracts headings and accepted history decisions. Prior packets remain evidence, not current implementation authority. |
| V11's cache and retained-feature-artifact language | retire because its mechanism was deleted | LDG-3049/3050 and schema 120 removed the complete mechanism; the structural deletion detector is `tests/testthat/test-feature-retention-removal.R`, and the schema catalogue proves no `features` table. |
| V11's two-mode projection-probe conclusion | supersede by an accepted history-wave decision | The release-line mode decision is availability-only history with full membership represented on that path. |
| V11's current exposure measurements | rewrite for current architecture | Keep them as historical evidence. Use the WS39 aggregate record as the current input and H1/H6 for history-specific runtime and memory. |

## 6. Newly exposed semantic questions to route before v12

These questions arise from reconciling v11 with current contracts. This audit
does not answer them. H2 must carry them as explicit Type 2 work before stage
3; H0 neither answers them nor edits the decision register.

1. **Assumed-default price basis and carry barriers.** V11 gives an
   undeclared basis the conservative corporate-action barrier rule. Current
   availability execution keeps `data.price_basis = NULL` for identity but
   economically runs and discloses `split_adjusted` as an assumed default.
   The [Cut 12 decision 8 amendment and LDG-3013](../ledgr_v0_2_2_spec_packet/tickets.yml)
   record that exact split: the basis remains `NULL` in identity while the
   availability path always applies the assumed `split_adjusted` model.
   Should history carry follow the effective assumed split-adjusted model or
   the conservative undeclared-identity rule? The answer must also state what
   enters rule-3 config/history identity and the detecting fixture.
2. **Instrument-narrowed expected sessions.** V11 preserves a separately
   scheduled narrowing route, and current WS3 plus the RFC pipeline still own
   it. V12 must explicitly reject narrowing, defer it with a trigger and owner,
   or bind its cutoff resolution, alignment to the common public time axis,
   and treatment of observations inside inactive intervals. No request window
   may choose that treatment silently. V12 must then dispose both live owners
   coherently; silence would leave the WS3 bullet and
   `instrument-specific-session-axis` obligation operative.
3. **Unlocatable corporate-action condition.** V11 promises a carry-specific
   classed refusal when a knowable action has neither entitlement nor effective
   clock. Current ingest permits both event clocks to be absent. Execution maps
   each absent clock to `NA`, so the row silently receives no posting pulse;
   `ledgr_invalid_corporate_action_event` covers a non-finite entitlement
   recount delta, not missing event clocks. The register must decide whether
   the v11 case remains supported and, if so, its class, parent, fields,
   timing, and relationship to Session C's `assume_effective` rule.
4. **Availability-aware pulse inspection parity.** Run, sweep, and
   walk-forward share the fold, but `ledgr_pulse_snapshot()` is a separate
   dense helper with its own SQL and non-availability state. H2 must decide
   whether to make that helper availability-aware for causal history or route
   inspection parity to another owner/surface.

H2 and stage 3 must also bind the shared history-axis unit, what a shorter
lookback's first column may use as a causal carry seed, and the default row set,
including held nonmembers, past-membership observations, and the representation
of included/excluded instruments. The UX brief's proposed
`instruments = "admissible"` is input, not an accepted default. The register's
existing D3-F5 item, after its deleted-file anchor is corrected, owns the
history-identity question; H0 creates no duplicate decision.

## 7. H0 exit check

- Every load-bearing v11 clause has one disposition in Section 3; Section 5
  separately maps every obsolete implementation, measurement, and ticket
  anchor.
- No deleted feature-retention mechanism remains an operative dependency.
- No history semantic is selected here. The four explicit Type 2 questions and
  the stage-3 row-set/axis drafting work are routed above; identity remains
  with D3-F5, and all previously open choices remain in Sessions D-F and the
  register's consider rows.
- The map uses current contract headings, accepted RFC sections, and current
  function names in preference to line-only anchors.
