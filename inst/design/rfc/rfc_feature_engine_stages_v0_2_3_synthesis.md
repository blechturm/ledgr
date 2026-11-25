# Feature Engine Stages 2-3: Synthesis

- Author: Codex, 2026-11-25. Mode: Decision synthesis; RFC cycle stage
  "synthesis". Claude drafted the brief; the maintainer approved its decisions
  on 2026-11-25. Codex wrote the response, not seed v2.
- Status: proposed binding design for the stages 2-3 cut; **binds nothing until
  accepted**. Acceptance authorizes pending scope, not a claim of implementation.
- Inputs, all read in full from the supplied `a04ab730` snapshot:
  [seed v1](rfc_feature_engine_stages_v0_2_3_seed.md),
  [Type 2 response](rfc_feature_engine_stages_v0_2_3_response.md),
  [response review](rfc_feature_engine_stages_v0_2_3_response_review.md),
  [seed v2](rfc_feature_engine_stages_v0_2_3_seed_v2.md), and the accepted
  [parent](rfc_feature_engine_v0_2_3_seed_v2.md), especially Stages 2-3 and
  Sections 4, 6 and 7. Recorded provenance: v1 reviewed at `b3454fc7`;
  review/v2 code baseline `ff8e9a63`; parent acceptance corrections `c01e7445`;
  measured R/ `68b505b9`; permanent oracle pin `d5b3a151`. These commit
  attributions and file-introduction commits are independently **unverified**:
  Git refused ownership checks, including process-scoped safe-directory attempts.
- Maintainer decisions, 2026-11-25: one private R/ debug flag, restoring prior
  state, explicitly set in parity/timing workers and on for the suite, reused by
  the lean core after its switch; one cut with stage 2 then stage 3, separately
  close-reviewed, stage 3 starting only after stage 2's close review; a small
  fixed `ledgr` adapter beside `TTR` only if it removes the parallel built-in
  branch; lazy in-order construction only for measured stage-2 savings, with
  the maximum-width SMA refusal as the sole new oracle exception, otherwise
  eager construction and that question lapses. The real-data count remains
  deferred under the 2026-11-18 decision; the looser gate is outside this cut.

Paths and line numbers below refer to this worktree; RFC short names refer to
the linked inputs above. Contract citations use stable rule-group addresses.

## Evidence boundary

The measuring step justifies trying stage 3, not shipping an assumed speedup.
Its six dense rows compare 13,408 TTR SMA cells with no recorded value/segment
differences (`dev/spikes/feature_stage23_probe/results/direct.csv:2`). Its
49-59% wide-cell figures subtract separately timed components, including an
empty record assembly; they are neither integrated savings nor an upper bound
(`direct.R:63`, `common.R:115` in that probe). Public coverage is 197/200 on
the simulated PIT panel and 4/6 on each corpus panel for the two SMA definitions
(`results/gate_count.csv:38,62`); these are not all-row or real-data coverage.
Four additional relaxed cells have reason records (`results/gate_count_differing.csv:2`).

Earlier response probes are read evidence:
`C:/Users/maxth/ledgr-wt/fe-stages-probes/stages_response_probe.txt:4`,
`stages_response_source_probe.txt:1`, and
`stages_response_gate/gate_probe.txt:1`. The 192 whole-slice comparisons support
arithmetic reuse; they prove neither refusal ordering nor raw sharing. Historical
CHECK PASS and the full 14-cell gut total remain **unverified by rerun** here;
the saved response output reports ten corpus-only gut differences.

This synthesis ran only small synthetic probes, using the supplied installed
build. `C:/Users/maxth/ledgr-wt/fe-stages-synthesis-out/synthesis_probe.R:1`
and `synthesis_probe.out` record the full engine digest beginning
`bc6a3ea254d0a37b`, matching bodies/formals for all 215 top-level functions in
the eleven inspected source files, the certification counterexamples below,
and both `runSD(1)` refusals. Locale/coercion/backend warnings occurred. No
timing run, permanent-oracle run, full suite, package check or private-data
access occurred. Implementation parity, speed and memory therefore remain
**unverified**, to be proved by the cut.

## Stage 2 rules

1. **Move adapter knowledge once.** `ledgr_feature_adapters()` returns fixed,
   ordered package-owned descriptions: `ledgr`, then `TTR`. The built-in entry
   replaces the separate built-in certification/dispatch bookkeeping; it must
   not wrap and retain a parallel branch. Describing adapters neither constructs
   indicators nor loads TTR merely to inspect a built-in. No discovery, mutable
   hooks, runtime registration or public schema. Catalogue rows keep their
   layout and order (`R/indicator-history.R:203`). Certification, calculator
   dispatch, source validation/inspection, parameter constructors and dependency
   provenance read these descriptions (`R/history-features.R:19,297`,
   `R/indicator.R:137`, `R/feature-inspection.R:295`,
   `R/feature-parameters.R:290`, `R/strategy-provenance.R:104`). Source values
   and refusals remain exactly `ledgr`, `TTR`, `custom`; inspection's unknown
   source still resolves to custom. This is the parent's Stage 2, not a second
   session indicator registry. [Indicator identity](../contracts.md#contract-context-indicator-computation).

2. **Descriptions contain the complete adapter contract.** Keep deterministic
   adapter/backend identity, package/version and applicable algorithm settings;
   exact input mapping and separately forwarded arguments; dependency-width,
   readiness and history-class rules; catalogue variants and allowed/neutral
   arguments; ordered canonical candidates; raw-call keys, invocation, output
   discovery, selection/derivation and numeric normalization. Data or named
   callbacks may carry these responsibilities; a selected-vector callback
   alone is insufficient. TTR's mappings, separate MFI/CMF volume argument and
   MACD histogram derivation stay (`R/indicator-ttr.R:317,718,806,855,888,969`).
   The `ledgr` entry retains existing kernels, including exact scalar-mean SMA
   semantics (`R/history-features.R:303`, `R/features-engine.R:273`). Keep the
   existing dependency-version JSON fields and missing-package behavior;
   diagnostic provenance does not become calculation identity.
   [TTR Adapter](../contracts.md#contract-context-ttr-adapter).

3. **Preserve certification, not just catalogue metadata.** Keep width
   discovery from params then ID, width order, SMA/EMA/RSI/returns order within
   each width, then TTR; ID substitution; canonical base/active identities;
   claimed/content contradiction checks; canonical function replacement; and
   the existing custom outcome. Content identity participates in contradiction
   detection; it does not newly authorize recognition without the current
   claimed-identity match (`R/history-features.R:23,41,59,96`). Each attempted
   TTR candidate still uses `ledgr_ind_ttr()` with its synthetic validation,
   catches construction errors and omits non-catalogue candidates
   (`R/history-features.R:123`, `R/indicator-ttr.R:250,868`). Neither metadata
   selection nor copying TTR's general validator is authorized. ROC3 with
   invalid `type` and MACD(100,3,2) built in a validation-suppressed local
   constructor remain hostile custom-certification witnesses, not valid
   public constructions. [Indicator identity](../contracts.md#contract-context-indicator-computation),
   [Strict Features](../contracts.md#contract-context-strict-features).

4. **Lazy construction is conditional and bounded.** First measure candidate
   construction, synthetic TTR validation, definition building and fingerprints
   separately, then the integrated certification call. Adopt in-order lazy
   construction only if the shared timing protocol resolves a saving; otherwise
   retain eager construction and no new exception. If adopted, record precisely
   the approved `ledgr_ind_sma(.Machine$integer.max)` difference: construction
   already succeeds; certification no longer refuses during unrelated EMA
   construction and may prepare an all-warmup result on a short history
   (`R/indicator-builtins.R:14,75`, `R/history-features.R:114`). This is not
   permission to suppress every later-candidate refusal. Retain eager
   construction outside the proven equivalent domain, including extra ID-width
   cases described below. Any further semantic difference fails the workstream;
   keep eager behavior there, or retain eager construction throughout. The
   exception changes neither constructor fingerprints nor short-slice guards.

## Stage 3 rules

5. **One preparer chooses per cell.** Add the deterministic calculator choice
   only inside `ledgr_history_compute_feature_series()`
   (`R/history-features.R:467`). Run, sweep and explicit precompute reach it;
   the single-definition evidence entry and the causality probe keep general
   calculation (`R/backtest-runner.R:668`, `R/history-substrate.R:376`,
   `R/history-features.R:670,793`).
   Authorize the shortcut by the accepted parent's Stage 3 and equivalent
   semantics, not its filename. Keep certification before bounds/early return;
   empty bounds or no definitions return before gate construction
   (`R/history-features.R:471`). A custom-only preparation allocates no gate
   planes. No user option or clock-specific execution fork.
   [Feature Path](../contracts.md#contract-context-feature-path).

6. **Use the conservative gate only.** For each certified definition and
   instrument, at the actual bounds, cutoff and history policy, require a
   supported built-in/catalogue row, exactly one unchanged knowledge range,
   every calculation column expected at that range-end cutoff, every required
   raw field finite there, and no asserted terminal anywhere in prefix
   `1..calc_to`. Custom and unregistered forms fall through. Empty slices
   never enter. Expected/finite coverage proves identical required raw/treated
   input, one run and no carry/reason exceptions. Whole-prefix terminal
   exclusion implies no sticky barrier; do not scan sticky separately or demand
   an impossible sticky-only near miss (`R/history-substrate.R:1395,1426`).
   Keep the deliberate over-rejection of harmless second ranges/early terminals.
   Compute ranges once for preparation and reuse them for fallback. Reduce
   transient mask/finiteness work to instrument flags per distinct field set;
   retain no field-set-by-instrument-by-axis collection. Gate decisions are
   prepared once, with cheap rejection. [Strict Features](../contracts.md#contract-context-strict-features).

7. **Reuse arithmetic and preserve records/order.** Preserve certification,
   instrument, knowledge-range, definition, then causality order, interleaving
   direct and fallback cells (`R/history-features.R:475,495,521`). Do not batch
   all direct cells first. On an admitted cell call the same adapter segment
   calculation on the whole slice, with prefix-relative indices and canonical
   required-field order. Keep raw-call sharing over compatible outputs with
   exactly today's key: params excluding selected output, required fields,
   input-carry family, history class and segment endpoints; cache lifetime is
   one instrument/knowledge range (`R/history-features.R:62,307`). BBands'
   distinct carry families stay distinct even on equal finite inputs.

   Write the same typed axis-aligned values and bounds, warmup NAs, one segment
   start/end and its `stable_after`-th ready position, or `NA_integer_` if never
   ready. Short slices make no adapter call. Retain calculated counts from
   `ready & is.finite(value)`, not from admission alone. Empty carry/reason sets
   are justified only by rule 6 (`R/history-features.R:349,561,608`). In
   production treat inputs only for an instrument/range needing fallback;
   debug may also build oracle inputs. Fallback retains today's field union
   and complete custom callback frame, including non-required OHLCV columns
   and raw/treated choice (`R/history-features.R:173,249,362`). No new per-bar
   loop, row-frame accumulator or repeated per-cell plane scan. The retained
   instrument/range/definition order has a stated reason: canonical refusal
   precedence and adapter calls. Use typed indexed writes and boundary assembly
   under `inst/design/manual/optimization_coding_style.qmd:94,167,343`.

8. **Production checks stay; debug compares outcomes.** Keep substrate/input
   entry guards, feature-output validation and the sampled causality refutation
   in production. Preserve calculated-count tie-breaking, chosen instrument,
   definitions and sampled positions/order, including skipping definitions with
   no calculated cells (`R/history-features.R:670,699`). The refutation is not a
   proof. With debug on, every admitted cell also runs general calculation,
   using an independent preparation-local raw cache. Compare exact values,
   counts, bounds and all plane records on success; compare condition classes,
   message and all identifying payload fields on refusal. Exclude only call,
   trace and other diagnostic machinery, as the permanent runner does
   (`dev/feature_parity/runner.R:223`). Agreed refusal re-raises the product
   condition; success/refusal disagreement or any mismatch raises an internal
   classed error. Never silently fall back on disagreement. Test mismatches
   differing only in a condition field. One unexported flag defaults off,
   restores prior state on every exit, runs suite-on and parity-on/off, and is
   explicitly set in parity/timing workers. Debug changes assertions only and
   enters no identity. Reuse that flag at the lean switch; this cut does not
   extend lean-only assertion removal to current R/ (pulse-plumbing synthesis
   `rfc_lean_core_pulse_plumbing_v0_2_3_synthesis.md:84`).

9. **The shortcut must earn its cost and have an exit.** Measure incremental
   stage 3 against close-reviewed stage 2 through `dev/bench/timing/`, one cut
   protocol: 10 x 7,200 and both wide shapes, run and sweep, integrated records
   included; zero/low admission using hostile public fixtures and custom-only
   work; mixed admission using the public PIT panel; wide-cell peak R heap.
   Workers explicitly select debug off for production timings; debug-on cost
   is separately labelled. The cut fixes noise/size dispositions before results.
   Zero-admission feature time must remain within the stage-2 label-exchange
   range; otherwise simplify or drop the gate. Report low/mixed costs and
   memory, not just successful-cell savings. No retained shortcut without
   resolved net benefit and an explicit size disposition at close review.
   Remove or merge it when general-path simplification makes the predicate
   unnecessary, or measured saving falls inside that range on recorded target
   workloads. Add its oracle, predicate, registered differential and exit to
   `inst/design/ledgr_v0_2_2_spec_packet/history_representation_map.md:144`.

## Proof and oracle obligations

10. **Keep independent semantic oracles.** The stage-1-cleaned canonical R
    general path is normative; direct/general debug alone cannot detect a
    shared adapter defect. Run the permanent installed-pin differential against
    `d5b3a151`, both clocks and both debug settings, and direct-backend TTR
    parity including derived outputs. Retain exact values/NA placement, types,
    dimensions, names, planes, projections, history reads/reasons, canonical
    certification, callback frames, refusal classes/messages/identifying fields
    and first-refusal order, caller RNG and causality selection/order
    (`dev/feature_parity/README.md:51`, `runner.R:223,275`). Only the existing
    declared identity/representation exclusions and rule 4's conditional,
    explicitly keyed refusal exception may differ. Any separately authorized
    post-warmup-NA change keeps its own ledger entry if it lands first; this
    cut neither implements nor absorbs it (parent:216).

11. **Change mechanism observations narrowly.** Existing route and preparation
    hand-off counts assert work these stages may remove
    (`dev/feature_parity/runner.R:133,155`, `check.R:109,141`). The cut records
    that distinct test-change reason. Keep pin observations/semantic expected
    answers; replace only obsolete candidate mechanism expectations with
    independently observed actual gate choices, adapter/backend invocations,
    raw-cache hits and fallback treatment, against reviewed committed
    expectations. Observe execution seams, not a product-reported success flag;
    no production counters solely for tests. Keep causality/read-entry phase
    observations and field coverage where those paths remain unchanged. TTR
    synthetic validation is still required on attempted TTR candidates; stage
    2 is not a blanket call-count waiver. Account separately for debug shadow
    work. Retain missing-arm/case/component refusals, pin-self parity and all
    applicable fault controls; add controls for wrong admission, missing
    treatment/raw sharing and same-class wrong-payload refusal. Missing traces
    on refusing cases must still fail. Do not regenerate semantic expectations
    from the candidate to clear a failure. [Feature Path](../contracts.md#contract-context-feature-path),
    [Execution identity](../contracts.md#contract-execution-identity).

12. **Register witnesses at both workstream closes.** Stage 2 covers every
    catalogue row and hostile wrong widths, edited IDs, copied/forged functions,
    SMA carrying RSI's claim, carry contradictions, unregistered args/outputs,
    invalid ROC and MACD domains, maximum-width SMA and the extra-ID-width
    counterexample. Stage 3 covers each gate rejection, terminal/sticky
    implication, empty/short/never-ready histories, later calculation starts,
    both carry families, all built-ins, every registered input/output/variant
    and `stable_after > requires_bars`. Include MACD histogram sharing, BBands
    sharing/separation, MFI/CMF volume, mixed admitted/fallback cells and
    admitted `runSD(n=1)` refusal. Competing errors in both definition orders
    and across instruments/ranges must preserve the first refusal. `ohlc`
    remains an unregistered fallback mapping witness, not a new catalogue row
    (`R/indicator-history.R:203`, `dev/feature_parity/corpus.R:196`). Cover run,
    implicit sweep, explicit precompute/reuse and both clocks/settings. Verify
    preparation refusal before candidates/fold; durable run FAILED with no
    strategy/events/equity, sweep/precompute writing nothing
    ([Feature Path](../contracts.md#contract-context-feature-path)). Gut the
    full-coverage clause and retain complete output showing debug refuses;
    independently challenge gate decisions as well as comparing shared calls.
    Record production/debug/witness sizes separately and each rejected
    approach's consequential reason (`inst/design/rfc_cycle.md:297,304`).

## Proposed contract replacement

At implementation replace only the bullet at `inst/design/contracts.md:2752`
in [Feature Path And Intent Constructors](../contracts.md#contract-context-feature-path)
with this exact text; its other bullets remain binding:

> - Feature computation uses one common preparer for both execution clocks.
>   Within preparation, a deterministic predicate may select an equivalent
>   internal calculator for a certified definition/instrument cell. The general
>   R calculator remains the normative executable oracle. Registered
>   differential tests cover selection, exact values, all evidence records and
>   refusal outcomes/order; internal debug compares every admitted cell and
>   fails closed on disagreement. Production output validation and sampled
>   causality checks remain mandatory. There is no user-selectable calculation
>   mode or implicit reuse of calculated features across preparations. Raw-call
>   sharing is confined to compatible outputs within one instrument and
>   knowledge range of a preparation. Explicit `ledgr_precomputed_features`
>   payloads retain their ownership, causal-axis and current feature/engine
>   identity validation before reuse; a mismatch refuses before candidate
>   execution.

## Identity effects

13. **Keep logical identity; move the engine version in each stage.** Before
    refactoring pin emitted built-in/TTR function bodies, formals, captures,
    params (including `ttr_version`), IDs and declarations for concrete,
    parameterized and bundled forms (`R/indicator-ttr.R:288`,
    `R/indicator.R:278`, `R/features-engine.R:97`). Prove unchanged base and
    declared-session fingerprints, stored declarations, feature set/union,
    config, alias and feature-parameter hashes, and matching walk-forward
    candidate/experiment/session identities. Extend the helper census and
    replacement proofs to registry data/callbacks, gate, calculator and debug
    comparison helpers; bind every ledgr-owned semantic dependency or name its
    separate binding (`R/features-engine.R:1`, parent:430). Do not replace the
    census with recursive environment/session hashing. Debug state is excluded.

    Use the existing changed-engine identity check at each stage
    (`dev/feature_parity/identity_check.R:36`). Old explicit
    precompute refuses `ledgr_precomputed_engine_mismatch` before candidates;
    regenerate, without a compatibility reader (`R/precompute-features.R:154`).
    Ownership, axis, grid,
    fingerprint and alias checks remain. Durable sweeps keep the engine version
    they recorded. No store-schema change, logical-key change or refusal to read
    older stored results follows solely from this engine change. If closure
    identity cannot be preserved, stop with the concrete diff for maintainer
    disposition; no old hash is hard-coded. [Indicator identity](../contracts.md#contract-context-indicator-computation),
    [Strict Features](../contracts.md#contract-context-strict-features),
    [Execution identity](../contracts.md#contract-execution-identity).

## Corrections to seed v2

- **F1, lazy scope (v2:147).** It says lazy construction keeps every outcome
  except post-match construction refusals, but does not contain those refusals
  to the one approved exception. Executed counterexample: `ledgr_ind_sma(3L)`
  renamed to `sma_2147483647` refuses under eager construction, yet its first
  candidate certifies. Params and ID discover two widths
  (`R/history-features.R:99,104,114`); the later width overflows. Rule 4 requires
  eager preservation there and outside proven equivalence. The maximum-width
  exception promises certification/ordinary preparation, not a finite value
  before readiness; v2:337's "computes" is qualified accordingly.
- **F3, condition equality (v2:234).** Class and message alone omit identifying
  fields required by the accepted response:33 and parent:300. Rule 8 compares
  those fields too and rule 12 keeps complete range/order witnesses. Production
  treatment skipping in v2:223 does not apply to debug oracle work.
- **Parent Stage 2 completeness (v2:121).** Its short descriptor list leaves
  input/width/variant rules and output discovery implicit. Rule 2 makes those
  parent:331 responsibilities explicit without creating a larger registry API.
- **F6, checker scope (v2:283).** Do not retire whole mixed-purpose observations
  indiscriminately: keep unchanged causality/read phases and required TTR
  validation observations. Rule 11 changes only affected mechanisms, with
  independent observation and fault controls, preserving the semantic pin.
- **F7, family scope (v2:293).** There is no registered `ohlc` row among today's
  48 rows; rule 12 exercises that mapping through custom fallback. It does not
  imply admission or authorize a new row. Probe counts and historical CHECK
  PASS/gut claims retain the verification limits stated above.

All eight response findings remain accepted (response review:14). No accepted
direction is rejected. Metadata-only certification, removing synthetic TTR
validation, success-only debug and the relaxed gate remain rejected for their
documented recognition/refusal/evidence failures; no broader framework is needed.

## Open Questions Promoted To Spec-Cut

The four maintainer choices are resolved. The cut assigns concrete internal
callback/flag names and worker wiring, witness/observer locations, and pins its
timing noise and size dispositions before measurement. Stage 2's conditional
lazy/eager result is resolved by rule 4's measurement at that workstream's close,
not reopened as a product choice. Stage 3's measured retain/simplify/drop result
belongs to its own close under rule 9. No clean-machine rerun is required here;
the cut records its actual host, and an inconclusive record cannot establish a
saving. `tickets.yml` alone owns those tickets and sequencing
(`inst/design/rfc_cycle.md:167,284`).

## Future Obligations Recorded

The lean-core switch reuses this private debug mechanism with module-property
tests, suite-on and worker-explicit parity-on/off under pulse-plumbing R1.
The shortcut's removal/merge trigger in rule 9 remains an upkeep obligation.
Route accepted obligations to the RFC pipeline/decision bridge until tickets own
them (`inst/design/rfc_cycle.md:187`); this synthesis edits neither index.

The real-data count remains deferred, requiring the authorized private-data
executor and maintainer release of that deferral. It informs only possible later
looser-gate work; neither the count nor a looser gate gates this cut. TA-Lib,
matrix calls and public adapters remain possibilities, not new implementation
or RFC promises. Reconsideration requires its own authorized work.

## Explicitly not authorized

No second fold/runner engine, new execution-mode branch, public debug/performance
switch, compiled code, matrix entry point, adapter/backend addition, indicator
or catalogue expansion, cross-backend equivalence, relaxed gate or reconstructed
missing-edge reasons. No custom callback narrowing, changed carry/history/output
validation policy, post-warmup-NA implementation, sweep reuse/architecture change,
cross-preparation memo, precompute representation redesign, migration, old-format
reader or identity fallback. Snapshot creation/sealing/hash verification and
no-lookahead execution remain mandatory; interactive tools remain read-only.
The parent Section 4, AGENTS.md and the cited contract groups retain authority.
This document implements nothing, edits no prior artifact and substitutes for
neither independent final review nor either workstream close review.
