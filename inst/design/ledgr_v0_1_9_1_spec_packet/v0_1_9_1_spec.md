# ledgr v0.1.9.1 Spec

**Status:** Planning packet; v0.1.9.1 spec drafted 2026-06-05. Codex review passed after spec patches. Tickets cut 2026-06-05; Batch 0 / LDG-2547 completed.
**Target Branch:** `v0.1.9.1`.
**Scope:** First packet in the v0.1.9.x four-tick arc (v0.1.9.1 cost-API; v0.1.9.2 sweep artifact persistence; v0.1.9.3 target-risk; v0.1.9.4 walk-forward). Ship the public transaction-cost API per the accepted synthesis, bind cost identity into run config and promotion provenance, and fix the v0.1.8.11 auditr cycle's high-severity identity-contract findings (THEME-004) plus the installed disclaimer link.
**Ticket state:** Tickets are cut in `v0_1_9_1_tickets.md` and `tickets.yml`. Batch 0 / LDG-2547 packet alignment is complete; all implementation tickets remain planned.
**Non-scope for this pass:** Target-risk implementation (v0.1.9.3), walk-forward implementation (v0.1.9.4), sweep artifact persistence (v0.1.9.2), OMS / paper / live work, broker / liquidity templates, compiled-core promotion or default execution, non-spot accounting models, default `compiled_accounting_model = "spot_fifo"` flip, target-helper Pass 2 extensions, crypto-readiness spike, and any auditr finding not explicitly listed in Section 4.

---

## 0. Source Inputs

Authoritative inputs:

- `inst/design/contracts.md`
- `inst/design/README.md`
- `inst/design/ledgr_roadmap.md` (v0.1.9.x Line Sequencing preamble, 2026-06-05)
- `inst/design/horizon.md` (2026-06-05 sequencing + cost-API spec-cut decisions + walk-forward Section 17 gate-row obligations entries)
- `inst/design/rfc_cycle.md`
- `inst/design/vignette_styleguide.md`
- `inst/design/release_ci_playbook.md`

Completed packet inputs:

- `inst/design/ledgr_v0_1_8_5_spec_packet/`
- `inst/design/ledgr_v0_1_8_7_spec_packet/`
- `inst/design/ledgr_v0_1_8_8_spec_packet/`
- `inst/design/ledgr_v0_1_8_9_spec_packet/`
- `inst/design/ledgr_v0_1_8_10_spec_packet/`
- `inst/design/ledgr_v0_1_8_11_spec_packet/`

Accepted RFC inputs:

- `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md` (binding for v0.1.9.1 surface; accepted, no amendments)
- `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_maintainer_decisions.md`
- `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_seed_v2.md`
- `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_response.md`
- `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` (cross-reference for cost-identity forward obligation to v0.1.9.4)
- `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_final_review.md`
- `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md` (cross-reference; v0.1.9.3 prereq context)
- `inst/design/rfc/rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md`
- `inst/design/rfc/rfc_strategy_authoring_helpers_v0_1_8_x_synthesis.md`

Auditr cycle inputs (v0.1.8.11 episodes):

- `inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml`
- `inst/design/ledgr_v0_1_9_1_spec_packet/cycle_retrospective.md`
- `inst/design/ledgr_v0_1_9_1_spec_packet/ledgr_triage_report.md`

Horizon entries promoted into this packet:

- `2026-06-05 [planning] v0.1.9.x line sequencing -- four-tick arc culminating in walk-forward`
- `2026-06-05 [planning] v0.1.9.1 cost-API spec-cut decisions on synthesis Section 13 open questions`
- `2026-06-05 [planning] v0.1.9.4 walk-forward Section 17 gate-row obligations from the v0.1.9.x arc`
- `2026-06-05 [research] v0.1.9.2 sweep artifact persistence RFC cycle scheduled`
- `2026-06-05 [optimization] Post-LDG-2522 ephemeral wall picture and Architecture A status`
- `2026-06-05 [execution] Spot-FIFO as default for ephemeral spot workloads (v0.1.9.x candidate)`

---

## 1. Thesis

v0.1.8.11 closed the entropy-management cycle and shipped the documentation /
discoverability surface that should have existed during the v0.1.8.x
optimization arc. The auditr v0.1.8.11 cycle then ran 46 episodes against
the cleaned-up package and surfaced one HIGH-severity theme (THEME-004:
Hashes And Reproducibility Identity, 5 high-evidence items) and five
MEDIUM-severity documentation themes.

The v0.1.8.x arc never bound a coherent identity contract for users. Hash
fields existed (`feature_set_hash`, `alias_map_hash`, `config_hash`,
`feature_params_hash`, `alias_map_json`, `alias_map_order`) but the
auditr cycle found three identity bugs (config_hash contains run-specific
state; alias declaration order contaminates config_hash; alias_map_hash
contains concrete feature parameters) and a missing API surface
(`feature_set_hash` not exposed on documented run surfaces). The
identity surface is also barely documented.

v0.1.9.1 is the first packet in the v0.1.9.x four-tick arc. The arc
culminates in walk-forward (v0.1.9.4), which depends on a stable,
documented identity contract to compose `candidate_key` and `session_id`
recipes. Walk-forward cannot be built on top of a broken identity
surface; v0.1.9.1 fixes it before walk-forward consumes it.

v0.1.9.1 ships:

1. The public transaction-cost API per the accepted RFC synthesis,
   binding two new identity fields (`cost_model_hash`, `cost_plan_json`)
   on run config and promotion provenance.
2. The THEME-004 hash identity contract fixes plus the missing
   `feature_set_hash` exposure on documented run surfaces.
3. A documented identity-contract reference covering all hash fields.
4. The remaining HIGH-severity auditr item: install-path fix for the
   formal disclaimer link broken in v0.1.8.11.
5. Bounded follow-on documentation refresh for the five MEDIUM-severity
   auditr themes (THEME-002, 003, 005, 006, 010), scoped to surfaces
   that touch the cost API or are cheap-to-fix.

The release succeeds when (a) users can construct, identify, persist,
and inspect cost models through the documented public surface; (b) the
five high-evidence identity findings are closed by code or by an
explicit binding decision; (c) the installed disclaimer link resolves;
and (d) the five medium-severity documentation themes scoped in Goal 8 are addressed
where they touch v0.1.9.1 work.

---

## 2. Release Goals

v0.1.9.1 has nine planning goals.

### Cost-API workstream

1. Ship the public cost-API surface per synthesis Section 4: four
   primitives (`ledgr_cost_spread_bps()`, `ledgr_cost_fixed_fee()`,
   `ledgr_cost_notional_bps_fee()`, `ledgr_cost_zero()`), composition
   (`ledgr_cost_chain()`) with construction-time order validation,
   timing constructor (`ledgr_timing_next_open()`), and inspection
   helpers (`ledgr_cost_steps()`, `ledgr_cost_describe()`).

2. Bind cost identity per synthesis Section 6: `cost_model_hash`
   (deterministic content hash, derivation recipe in Section 6.2) and
   `cost_plan_json` (canonical worker-safe plan) appear on run config,
   promotion provenance, and any reopen surface.

3. Wire cost into the existing fold-core proposal / resolver seam per
   synthesis Section 3.2: no fold-core control-flow changes; the only
   semantic edit is the `commission_fixed` to `fee` field rename at the
   cash-delta site. The `fill_model` to `timing_model` argument rename
   propagates across the public and internal surfaces named in
   synthesis Section 9.

### Identity hardening workstream (THEME-004)

4. Fix the three identity bugs surfaced by auditr episode 037:
   - `config_hash` must not contain run-specific state (currently
     contaminated by `run_id` or store-path differences).
   - `config_hash` must be invariant under alias declaration-order
     changes (currently contaminated).
   - `alias_map_hash` must not contain concrete feature parameter
     values (currently contaminated).

5. Expose `feature_set_hash` on documented run surfaces per auditr
   episode 037 FB-001: at minimum on `bt$config$features` (or
   equivalent accessor), `ledgr_run_info()`, and `ledgr_run_list()`,
   with help-page documentation explaining the difference between
   `feature_set_hash`, `feature_params_hash`, alias hash fields, and
   `config_hash`.

6. Add a documented identity contract reference covering
   `feature_set_hash`, `alias_map_hash`, `alias_map_json`,
   `alias_map_order`, `feature_params_hash`, `config_hash`, plus the
   new `cost_model_hash` and `cost_plan_json`. Reference lives where
   the cost-API synthesis Section 6.1 expects (run-config and
   promotion-provenance documentation), plus a top-level identity
   reference article under `inst/design/manual/` or as a help topic.

### Auditr remainder workstream

7. Fix the v0.1.8.11 installed-disclaimer link breakage per auditr
   episode 046 FB-001: include `DISCLAIMER.md` at the path the
   research-workflow vignette currently links to, or change the link
   to an installed help topic / article that carries the formal
   disclaimer text.

8. Address the medium-severity auditr themes (THEME-002, 003, 005,
   006, 010) where they touch v0.1.9.1 work or are cheap-to-fix doc
   updates. Scope is bounded: this is not a v0.1.8.11-style entropy
   pass. Specifically:

   - THEME-005 (Errors / Warnings / Diagnostics): document condition
     classes for the new cost-API errors
     (`ledgr_legacy_fill_model_shape`, `ledgr_legacy_config_shape`,
     `ledgr_cost_model_unspecified`,
     `ledgr_invalid_cost_chain_order`); add a help topic for
     `LEDGR_LAST_BAR_NO_FILL` (auditr episode 025); ensure all new
     v0.1.9.1 conditions have `?class` topics.
   - THEME-006 (Metrics And Accounting): rewrite the
     `metrics-and-accounting` vignette to teach the quoted-spread
     convention (synthesis Section 9:514) and the new cost-API
     surfaces; document `compiled_accounting_model` fail-closed
     behavior (auditr episode 040).
   - THEME-003 (Sweep And Candidate Workflows): document that the
     cost-API does not participate in sweep grid composition in v1
     (synthesis Section 10.2); record the future
     `ledgr_cost_grid()` direction in the sweep vignette's
     "Future Work" surface.
   - THEME-002 (Strategy Context And Indicators): no direct
     v0.1.9.1 scope unless cost-API teaching touches strategy
     context (strategies do not receive cost; synthesis Section
     3.1). Defer to a future docs pass.
   - THEME-010 (Runnable Examples And Reference Completeness): add
     runnable examples for cost-API constructors, chain
     composition, and identity inspection on the
     `?ledgr_cost_chain` and related help pages.

### Cross-cycle handoffs

9. Record the cost-identity forward obligation for v0.1.9.4
   walk-forward ticket-cut per the 2026-06-05 horizon entry. No new
   work in v0.1.9.1; the obligation is captured in horizon and the
   cost-API synthesis Section 14:560.

The release succeeds when the nine goals are met and v0.1.9.2 sweep
artifact persistence RFC cycle can begin authoring its seed v1
against a stable cost-identity surface.

---

## 3. Binding Boundaries

### 3.1 Cost-API Binding Decisions Are Final

The five spec-cut decisions recorded in the 2026-06-05 horizon entry
"v0.1.9.1 cost-API spec-cut decisions on synthesis Section 13 open
questions" are bound for this packet:

1. Legacy `fill_model = list(...)` shape: reject with
   `ledgr_legacy_fill_model_shape`. No auto-translation. Error message
   names the quoted-spread halving so users do not silently break.
2. Cost-plan execution shape: implementer's choice subject to identity
   stability tests, `cost_plan_json` reconstruction parity, and no
   per-pulse DB writes.
3. Cost component diagnostic retention: `meta_json` only in v1.
4. Reopen-path compatibility: `ledgr_run_open()` raises
   `ledgr_legacy_config_shape` on stored `fill_model` configs. No
   translation.
5. `cost_model = NULL` default: `ledgr_experiment()` without explicit
   `cost_model` raises `ledgr_cost_model_unspecified`. Users who want
   zero-cost pass `ledgr_cost_zero()` explicitly.

Any deviation requires a maintainer override note in the spec packet
log per cost-API synthesis Section 15 binding-decision-change
discipline.

### 3.2 Identity Hardening Scope

The three THEME-004 hash bugs are real defects to fix in v0.1.9.1. The
fixes are constrained:

- `config_hash` canonicalization: remove storage-location fields
  (`db_path`, `snapshot_db_path`) from the canonical payload. This is
  the PROVEN contaminant per auditr episode 043 FB-002. Also remove
  alias-declaration-order sensitivity from the canonical payload (the
  defect surfaced as `alias_map_order` differences in episode 037
  FB-003). The auto-generated fallback `run_id` is not in the hash
  today (`R/backtest-runner.R` computes the hash before deriving the
  fallback id), so no fix is required there. An explicitly supplied
  `run_id` does land in the hashed config (`R/backtest.R:930`); the
  packet's posture is to drop it from the canonical payload as a
  precautionary cleanup, with the rationale recorded in the identity
  contract. Any field intentionally retained as identity state must
  have its rationale recorded explicitly.
- `alias_map_hash`: remove concrete feature parameter values from the
  canonical payload. Concrete-feature identity lives in
  `feature_set_hash`, not in alias identity. If alias_map_hash is
  intentionally parameter-sensitive, the packet must record the
  rationale.
- All fixes must include identity-stability regression tests covering
  the cases the auditr cycle surfaced.

The fixes may change hash values for existing stored runs. Pre-CRAN
posture (horizon 2026-05-25 entry) makes this acceptable: stored
artifacts may break across cycles. The release notes name this
explicitly.

### 3.3 No Target-Risk, No Walk-Forward, No Sweep Persistence

v0.1.9.1 does not implement target-risk, walk-forward, or sweep
artifact persistence. References to those packets in the cost-API
identity-contract documentation are forward-looking only. The
v0.1.9.4 walk-forward Section 17 gate-row obligation for
`cost_model_hash` is recorded in horizon and is not addressed here.

### 3.4 No Default `spot_fifo`

v0.1.9.1 does not flip the default `compiled_accounting_model` from
`NULL` to `"spot_fifo"`. The spot-FIFO-default candidate (2026-06-05
horizon entry) remains a separate scoping decision with its own
prerequisites. The closed-enum scope guard from the 2026-06-02
horizon entry remains in force.

### 3.5 Documentation Scope Guard

The auditr remainder workstream is bounded. It is not a v0.1.8.11-
style entropy pass. Doc work is in scope only when:

- the topic touches the cost-API surface (THEME-006 metrics /
  accounting vignette rewrite, THEME-005 new condition class docs,
  THEME-010 cost-API runnable examples);
- the doc gap is a cheap fix tightly coupled to v0.1.9.1 work
  (identity contract reference, fail-closed-example for cost-API
  conditions);
- the gap is HIGH severity and load-bearing for the release
  (DISCLAIMER.md install path).

THEME-002 (ctx / indicators), THEME-003 (sweep workflows beyond the
cost-non-participation note), and other medium-severity items
unrelated to v0.1.9.1 surfaces defer to a future docs pass.

Two existing condition classes surfaced by auditr --
`ledgr_run_not_found` (signaled by `R/run-store.R`,
`R/metric-context.R`, `R/strategy-extract.R`; auditr episode
2026-06-04_030, severity LOW) and `ledgr_unresolved_feature_id`
(signaled by `R/feature-parameters.R` via
`ledgr_abort_unresolved_feature_id()`; auditr episode
2026-06-04_033/FB-005, severity LOW) -- lack Errors / Failure
sections on their host help topics (`?ledgr_run_info`,
`?ledgr_feature_id`). These defer to a future docs pass: they are
not cost-API surfaces and the scope guard limits v0.1.9.1 doc work
to cost-API, HIGH severity, or cheap-and-tightly-coupled items.

### 3.6 Pre-CRAN Posture Confirmed

The v0.1.9.1 packet enforces the pre-CRAN posture documented in the
2026-05-25 horizon entry. Stored artifacts (run configs, stored
hashes) may break. There is no transitional accommodation,
deprecation cycle, or auto-translation for the legacy `fill_model`
shape or the `commission_fixed` field name. Users re-author
experiments after upgrading.

### 3.7 RFC Synthesis Authority

The cost-API synthesis (`rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`)
remains authoritative for cost-API contract decisions. This spec
packet does not rewrite synthesis text; it implements the synthesis
plus the five spec-cut decisions from the 2026-06-05 horizon entry.
Any conflict between this spec and the synthesis must be resolved by
maintainer override note before implementation.

---

## 4. Planned Workstreams

Tickets will be cut in `v0_1_9_1_tickets.md` and `tickets.yml` after
Codex review of this spec. The planned workstreams are:

### Workstream A -- Cost-API Public Surface

1. **Cost primitive constructors.** Implement
   `ledgr_cost_spread_bps(bps)`, `ledgr_cost_fixed_fee(amount)`,
   `ledgr_cost_notional_bps_fee(bps)`, and `ledgr_cost_zero()` per
   synthesis Section 4. Quoted-spread semantics for
   `ledgr_cost_spread_bps()` per synthesis Section 7 (BUY:
   `open * (1 + spread_bps / 20000)`; SELL:
   `open * (1 - spread_bps / 20000)`).

2. **Composition and validation.** Implement `ledgr_cost_chain(...)`
   with construction-time chain-order validation. Raise
   `ledgr_invalid_cost_chain_order` when fee adders precede price
   transforms.

3. **Timing constructor.** Implement `ledgr_timing_next_open()` and
   add `timing_model` argument to `ledgr_experiment()` per synthesis
   Section 4.3. Legacy `fill_model = list(...)` shape raises
   `ledgr_legacy_fill_model_shape` at construction (Section 3.1
   decision 1).

4. **Cost identity surface.** Implement `cost_model_hash` derivation
   per synthesis Section 6.2 (canonical-JSON hash from
   `cost_schema_version`, top-level type_id, named fixed arguments,
   ordered child steps with type_ids and versions; must not depend
   on function memory addresses, R environment serialization, object
   print output, or package load order). Implement `cost_plan_json`
   as canonical worker-safe plan reconstruction. Persist both on run
   config and promotion provenance per synthesis Section 6.1.

5. **Inspection helpers.** Implement `ledgr_cost_steps(cost_model)`
   and `ledgr_cost_describe(cost_model)` per synthesis Section 4.8.

6. **Cost-resolver wiring.** Compile cost models into worker-safe
   plans consumed at the existing `ledgr_resolve_fill_proposal()`
   seam. No fold-core control-flow changes per synthesis Section
   3.2. Cost resolution may not mutate quantity, side, instrument,
   or execution timestamp (synthesis Section 4 mutation guards).

### Workstream B -- Internal Migration

7. **`commission_fixed` to `fee` rename.** Rename the field at the
   cash-delta computation site in `ledgr_fill_event_payload()`
   (`R/backtest-runner.R`, ~lines 167-202 -- reads `commission_fixed`
   from the fill intent, computes `cash_delta`, writes `fee` into the
   FILL row, and serializes `commission_fixed` into `meta_json`), the
   fill-model machinery (`R/fill-model.R`), other backtest-runner
   output handlers, and lot-accounting. Update tests. Ledger schema
   already exposes `fee` (synthesis Section 4.6:259); no schema
   migration needed. No fold-engine / fold-reconstruction
   control-flow changes per synthesis Section 12, item 14 (cost
   integrates through the existing proposal/resolver seam).

8. **`fill_model` to `timing_model` argument rename.** Propagate
   across `R/experiment.R`, `R/config-validate.R`, `R/backtest.R`
   (exported `ledgr_backtest()` arg and
   `ledgr_fill_model_instant()` helper), `R/backtest-runner.R`
   (config read), `R/run-store.R` (required-config-fields list and
   reopen path), internal helpers, roxygen, architecture notes, and
   tests.

9. **Reopen-path migration.** `ledgr_run_open()` raises
   `ledgr_legacy_config_shape` on stored `config_json` containing
   `fill_model` (Section 3.1 decision 4). Error message points at
   recreating the experiment.

9b. **Exported `ledgr_backtest()` public surface (R/backtest.R).**
    The exported `ledgr_backtest()` retains its role as a symmetric
    public entry point and is migrated to the same argument contract
    as `ledgr_experiment()`:
    - replace the `fill_model = NULL` parameter with two new
      arguments: `timing_model` (defaults to
      `ledgr_timing_next_open()`, matching the synthesis Section 4.3
      `ledgr_experiment()` signature) and `cost_model` (no default,
      per Section 3.1 decision 5);
    - remove `ledgr_fill_model_instant()` from the exported surface;
      replace its single internal call site with the explicit
      `ledgr_timing_next_open()` constructor;
    - if a caller passes the legacy `fill_model = ...` argument,
      raise `ledgr_legacy_fill_model_shape` (the same classed
      condition bound by Section 3.1 decision 1 for
      `ledgr_experiment()`) with a migration message pointing to
      `ledgr_timing_next_open()` and the `ledgr_cost_*`
      constructors; do not auto-translate, do not warn-and-continue;
    - if a caller omits `cost_model`, raise
      `ledgr_cost_model_unspecified` (the same classed condition
      bound by Section 3.1 decision 5 for `ledgr_experiment()`); no
      implicit `cost_model = ledgr_cost_zero()` default;
    - update R/backtest.R roxygen `@param` block, `@details` v0.1.7
      paragraph (lines 33-47 today), and the print method
      `print.ledgr_config()` to read `cfg$timing_model` /
      `cfg$cost_model` instead of `cfg$fill_model`;
    - extend `test-backtest-wrapper.R` to cover: (i) the symmetric
      `timing_model + cost_model` happy path with the default
      `timing_model`, (ii) classed rejection of
      `fill_model = list(...)` via `ledgr_legacy_fill_model_shape`,
      (iii) classed rejection of missing `cost_model` via
      `ledgr_cost_model_unspecified`, (iv) identity parity with the
      equivalent `ledgr_experiment() + ledgr_run()` invocation
      (same `cost_model_hash`, same `cost_plan_json`).

    Rationale: resolves the synthesis Section 4.3 / Implementation
    Constraints line 419 spec-cut decision under the pre-CRAN
    no-back-compat posture. Pre-CRAN, ledgr has no external
    strategy/API consumers, so a symmetric public surface is cheaper
    than maintaining a legacy-wrapper deprecation cycle. This also
    resolves the synthesis Section 13 Remaining Open question 1
    (legacy scalar handling) in the rejection direction for
    `ledgr_backtest()` and Section 13 question 5
    (`cost_model = NULL` default) in the explicit-required direction,
    keeping the two public entry points uniform.

10. **`cost_model` argument on `ledgr_experiment()`.** Required (no
    NULL default per Section 3.1 decision 5). Missing argument
    raises `ledgr_cost_model_unspecified` at construction. Error
    message hints at `ledgr_cost_zero()` for explicit zero-cost
    users.

### Workstream C -- Identity Hardening (THEME-004)

11. **`config_hash` store-path independence.** Remove
    storage-location fields from the `config_hash` canonical
    payload. The proven contaminant is the DuckDB path: auditr
    episode 043 FB-002 shows that holding snapshot_id, bars, aliased
    features, parameter grid, run_id, and seed constant while
    changing only the DuckDB path produces a different `config_hash`
    (all other inspected hashes match). Sources of the contamination
    in the current config tree: `config$db_path` (`R/backtest.R:875`)
    and `config$data$snapshot_db_path` (`R/backtest.R:926`); both
    flow into the canonical payload via `canonical_json()` and
    through reopen via `R/run-store.R:962-963`. Fix: omit `db_path`
    and `snapshot_db_path` from the canonical payload
    (canonical-payload allow-list, or explicit drop in a pre-hash
    projection). Note: the auto-generated fallback `run_id` does NOT
    contribute to `config_hash` (`R/backtest-runner.R:648-659`
    computes `cfg_hash` before deriving a fallback `run_id` from it);
    an explicitly supplied `run_id` is inserted into config at
    `R/backtest.R:930` and is a candidate for exclusion as well, but
    the auditr evidence does not yet prove it as a contaminant in
    isolation. Treat the explicit-`run_id` removal as a precautionary
    scope item rather than a proven-defect fix, and document the
    rationale in the identity contract reference (Workstream D,
    ticket 14). Add identity-stability regression tests covering
    auditr episode 043 FB-002 (store-path delta) explicitly.

12. **`config_hash` alias declaration-order independence.** Ensure
    `config_hash` is invariant under alias-declaration-order
    permutations. Add regression test covering the auditr episode
    037 FB-003 evidence.

13. **`alias_map_hash` parameter independence.** Remove concrete
    feature parameter values from `alias_map_hash` canonical
    payload. Concrete-feature identity lives in `feature_set_hash`.
    Add regression test covering the auditr episode 037 FB-004
    evidence.

### Workstream D -- Identity Surface Exposure And Documentation

14. **Expose `feature_set_hash` on documented run surfaces.** Add
    `feature_set_hash` to `bt$config$features` (or equivalent
    accessor), `ledgr_run_info()`, and `ledgr_run_list()`. Add
    help-page documentation explaining differences between
    `feature_set_hash`, `feature_params_hash`, alias hash fields,
    and `config_hash`.

15. **Identity contract reference.** Author a documented identity
    contract covering all hash fields:
    - `feature_set_hash`
    - `feature_params_hash`
    - `alias_map_hash`
    - `alias_map_json`
    - `alias_map_order`
    - `config_hash`
    - `cost_model_hash`
    - `cost_plan_json`

    Each field gets: purpose, canonical-payload composition recipe
    summary, derivation source (which surface it lives on), and
    cross-references to related fields. Lives as a help topic
    (`?ledgr_identity_contract` or similar) and as a section in the
    appropriate `inst/design/manual/` article. Cross-referenced from
    `?ledgr_run`, `?ledgr_run_info`, `?ledgr_sweep`,
    `?ledgr_promote`, and the relevant vignettes. Include a bounded
    `inst/design/contracts.md` update for the new public cost-API
    contract and identity fields; this is not a broad contracts.md
    restructuring pass.

### Workstream E -- Auditr Remainder

16. **DISCLAIMER.md install path fix (auditr episode 046).** Either
    include `DISCLAIMER.md` at the installed path the
    research-workflow vignette currently links to (typically
    `system.file(package = "ledgr")` root), or change the vignette
    link to an installed help topic that carries the formal
    disclaimer text. Verify by re-running the failed auditr episode
    workflow. FB-002 through FB-004 are optional follow-ups unless
    the chosen install-path fix naturally exposes a stable
    help/article URL; the release blocker is FB-001.

17. **Condition class documentation (THEME-005).** Add `?class`
    help topics for every new v0.1.9.1 condition class:
    `ledgr_legacy_fill_model_shape`, `ledgr_legacy_config_shape`,
    `ledgr_cost_model_unspecified`, `ledgr_invalid_cost_chain_order`,
    `ledgr_invalid_cost_model` (input-shape validation introduced by
    Batch 1 LDG-2548), and `ledgr_invalid_timing_model` (timing-model
    validation introduced by Batch 1 LDG-2550).
    Each topic includes a minimal fail-closed example and an
    actionable message contract.

18. **`LEDGR_LAST_BAR_NO_FILL` help topic (auditr episode 025).**
    Add a help topic for the existing warning code; cross-reference
    from execution-semantics vignette.

19. **Metrics-and-accounting vignette rewrite (THEME-006).** Rewrite
    `vignettes/metrics-and-accounting.qmd` to teach the
    quoted-spread convention (synthesis Section 9:514) and the new
    cost-API surfaces (`ledgr_cost_spread_bps()`,
    `ledgr_cost_fixed_fee()`, `ledgr_cost_chain()`,
    `ledgr_timing_next_open()`). The article must include
    timing-vs-cost separation, price-transform-vs-fee separation,
    and explicit non-scope bullets for liquidity, financing, TCA,
    taxes, OMS, and broker reconciliation. Add a worked round-trip
    example confirming approximately `spread_bps` total round-trip
    cost. Document `compiled_accounting_model` fail-closed behavior
    per auditr episode 040 evidence and name the stable top-level
    condition classes users should assert on.

20. **Cost-API runnable examples (THEME-010).** Add runnable
    examples on `?ledgr_cost_chain`, `?ledgr_cost_spread_bps`,
    `?ledgr_cost_fixed_fee`, `?ledgr_cost_notional_bps_fee`,
    `?ledgr_cost_zero`, `?ledgr_timing_next_open`,
    `?ledgr_cost_steps`, and `?ledgr_cost_describe`. Examples cover
    construction, chain composition, identity inspection
    (`cost_model_hash` extraction), and the
    `ledgr_cost_model_unspecified` error path.

21. **Sweep vignette non-participation note (THEME-003).** Add a
    paragraph to the sweep vignette explaining that cost-API
    parameters do not participate in sweep grid composition in v1
    (synthesis Section 10.2). Reference the future
    `ledgr_cost_grid()` direction (synthesis Section 14:565) as
    deferred work.

### Workstream F -- Release Surfaces

22. **NEWS entry.** Document the v0.1.9.1 release: the cost-API
    headline; the three THEME-004 hash fixes (breaking change for
    stored runs); the breaking changes (`fill_model` to
    `timing_model`, `commission_fixed` to `fee`, required
    `cost_model` argument); the auditr remainder fixes.

23. **Roadmap update.** Move v0.1.9.1 to "active" status. Annotate
    completion of the cost-API spec-cut.

24. **Horizon housekeeping.** Move the 2026-06-05 cost-API
    spec-cut decisions entry to `## Resolved` when v0.1.9.1 ships.
    Keep the sequencing entry, the walk-forward Section 17 gate-row
    obligations entry, and the sweep RFC schedule entry in `## Open`
    (they remain forward-looking).

25. **Design index update.** Reflect v0.1.9.1 ship state. Add the
    identity contract reference to the design index. Update the
    RFC index `inst/design/rfc/README.md` to mark the cost-API
    synthesis as implemented in v0.1.9.1.

---

## 5. Non-Goals

- No target-risk implementation (v0.1.9.3).
- No walk-forward implementation (v0.1.9.4).
- No sweep artifact persistence (v0.1.9.2 RFC cycle).
- No `ledgr_cost_grid()` or sweep-grid cost-parameter composition.
- No user-supplied cost functions (only classed ledgr cost objects).
- No per-instrument, per-asset-class, or per-venue cost models.
- No stateful rolling-volume fee tiers, maker / taker classification,
  rebates, or negative-fee handling.
- No broker / exchange templates in the core package.
- No liquidity / capacity policy (v0.2.x).
- No financing, margin interest, borrow, or carry.
- No multi-currency fee accounting.
- No TCA / implementation-shortfall reporting.
- No paper / live fee reconciliation.
- No spot-FIFO default flip.
- No durable-path compiled spot-FIFO integration.
- No non-spot accounting models.
- No target-helper Pass 2 extensions.
- No crypto-readiness spike work in this packet.
- No selection-integrity diagnostics (v0.1.9.5+).
- No broad refactor outside the named workstreams.
- No new auditr-driven doc work beyond Section 4 Workstream E.
- No follow-on v0.1.9.1.x release. Any unfinished work routes to
  v0.1.9.2 or later.

---

## 6. Review Questions

1. Is v0.1.9.1 the right version number for this packet, given the
   v0.1.9.x four-tick arc decided in the 2026-06-05 horizon
   sequencing entry?

2. Is the scope envelope correct, given the user directive to
   "tackle all important auditr findings in the current version
   too"? Specifically: is bundling THEME-004 hash hardening and the
   five medium-severity doc themes (002, 003, 005, 006, 010) too
   broad, too narrow, or correct?

3. Are the three THEME-004 hash bug fixes (Workstream C tickets 11,
   12, 13) all genuine bugs, or do any of them reflect intentional
   identity semantics that the spec should record instead of
   change? Specifically:
   - `config_hash` containing `run_id` or store-path: bug or
     intentional run-specific identity?
   - `config_hash` sensitive to alias declaration order: bug or
     intentional order-preserving identity?
   - `alias_map_hash` containing concrete feature parameter values:
     bug or intentional parameter-sensitive alias identity?
   For any case where the answer is "intentional," the packet must
   document the rationale and the auditr finding shifts from
   ledgr_bug to docs_gap.

4. Is the identity contract reference (Workstream D ticket 15) at
   the right level? Help topic plus manual article plus help-page
   cross-references is the proposed shape; alternative is a single
   vignette plus help topic cross-references.

5. Is the cost-API maintainer-decisions binding from the 2026-06-05
   horizon entry complete and final, or should any of the five
   decisions be revisited at this packet review? Specifically:
   decision 5 (`cost_model = NULL` raises rather than defaults to
   `ledgr_cost_zero()`) is the most aggressive of the five and
   worth explicit confirmation.

6. Is the `commission_fixed` to `fee` rename safe to ship without a
   transitional accommodation? Pre-CRAN posture says yes; this
   question confirms before commit.

7. Should DISCLAIMER.md install be done by including the file at
   the package-installed path, or by updating the research-workflow
   vignette link to point at an installed help topic? Either
   resolves the auditr finding; the choice affects the docs surface
   shape.

8. Is the v0.1.9.4 walk-forward Section 17 gate-row obligation
   correctly recorded in horizon, or should it also appear in this
   packet's review questions as a future-spec-cut binding to
   propagate to the walk-forward packet?

9. Is the cost-API spec packet expected to include a `batch_plan.md`
   like v0.1.8.11 did, or are tickets cut directly in
   `v0_1_9_1_tickets.md` without batched sequencing because the
   workstreams (A-F) are smaller than v0.1.8.11's 15 batches?

   **Review Resolution:** Include a compact `batch_plan.md`. v0.1.9.1
   has fewer batches than v0.1.8.11, but the work still crosses
   public API, internals, identity, documentation, and release surfaces.
   A batch plan keeps review units clear without changing ticket scope.

10. Should the v0.1.9.1 packet include a contracts.md update for the
    cost-API surface, or does that wait for a follow-on bounded
    documentation pass? Contracts.md currently does not name the
    public cost-API surface because it is shipping in this packet.

    **Review Resolution:** Include a bounded contracts.md update in
    LDG-2563. The packet adds public cost constructors, required
    `cost_model`, `timing_model`, and new identity fields, so the
    authoritative contract surface must not lag the implementation.
    This does not authorize a broad contracts.md structure pass.

---

**End of v0.1.9.1 spec.** Tickets are cut after Codex review of this
document. Codex review prompt at
`inst/design/ledgr_v0_1_9_1_spec_packet/codex_review_prompt.md`.
