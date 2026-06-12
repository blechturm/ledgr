# RFC Synthesis: API Naming Consistency And Surface Tightening

**Status:** Accepted 2026-06-12. Final review passed 2026-06-12
(APPROVED WITH PATCHES; see
`rfc_api_naming_consistency_v0_1_9_5_final_review.md`). Binding for the
v0.1.9.5 spec packet.
**Revision note (2026-06-12, final-review patches F1-F4, in-place per
rfc_cycle.md):** (F1) `ledgr_promote` added to the R1 closed verb-first
allowlist -- it was kept in Section 2.2 but missing from the list;
execution entry points clarified as family roots, not allowlist cases.
(F2) NEWS.md restored to the Section 6 cost surfaces and a 7.7
criterion added: NEWS carries the consolidated rename/unexport table
(inherited from seed v1/v2 acceptance criteria). (F3) the
missing/moved-db fail-closed path in Section 3.3 now binds reuse of
`LEDGR_SNAPSHOT_DB_NOT_FOUND` (`R/snapshots-list.R:183`). (F4) the
Recovery docs landing surface allows for the vignette-screening
audit's Split D successor article.
**Date:** 2026-06-12
**Author:** Codex (synthesis author; Claude wrote seed v1/v2; Codex wrote
the response and v2 verification review; Claude reviews this synthesis).
**Window:** v0.1.9.5, before the teaching-documentation batches.
**Primary input:** `rfc_api_naming_consistency_v0_1_9_5_seed_v2.md`.
**Cycle trail:** seed v1 -> Codex response -> seed v2 -> Codex v2
verification review -> in-place v2 patches -> maintainer decisions D1-D5
resolved in seed v2 -> this synthesis -> Claude final review.

This synthesis consolidates and binds the resolved naming-RFC decisions. It
does not reopen D1-D5, does not propose implementation code, and does not edit
prior artifacts. Tickets cite this synthesis and its final review.

This RFC uses "v1" as shorthand for the first implementation of this naming
cleanup; ledgr's roadmap does not have a naming-RFC v1 milestone. Post-v1 work
lives in named follow-up RFCs at their own roadmap windows.

---

## 1. Bound Naming Rules

The v0.1.9.5 rename batch binds these public naming rules into
`inst/design/contracts.md` in the same release as the renames.

- **R1 - family first.** Artifact-scoped exports use
  `ledgr_<family>_<action>`. Verb-first exports are forbidden except for this
  closed allowlist:
  `ledgr_compute_metrics`, `ledgr_precompute_features`,
  `ledgr_validate_schema`, `ledgr_backtest_bench`, and `ledgr_promote`
  (cross-container operation with no artifact-noun reading; added at
  final review, F1). Execution entry points (`ledgr_run`,
  `ledgr_sweep`, `ledgr_walk_forward`) are not allowlist cases: they
  read as artifact-family roots, not verb-first names.
- **R2 - one reopen verb.** Reopening durable evidence uses `open`.
- **R3 - accessors are nouns or family actions.** No public
  `extract_`, `get_`, or `fetch_` evidence accessors remain after the batch.
- **R4 - one candidate verb.** `ledgr_candidate()` is the candidate generic
  across evidence containers. Per-container extraction functions are removed.
- **R5 - every export is prefixed.** No unprefixed public helper exceptions
  remain. The six current unprefixed exports all gain `ledgr_` prefixes.
- **R6 - internal functions stay internal.** DB/schema plumbing, duplicate
  accessors, and internal runners are unexported.
- **R7 - one prefix scheme per domain.** In the indicator domain,
  `ledgr_ind_*` names are indicator constructors and constructor-family support
  helpers; `ledgr_indicator_*` names are indicator infrastructure.

The D2 semantic rule is binding:

- `ledgr_ind_*` = indicator constructors, bundles, and constructor-family
  metadata helpers. In v1 this includes `ledgr_ind_ttr_warmup_rules()` because
  the helper supplies TTR-constructor warmup metadata.
- `ledgr_indicator_*` = registry, lookup, dev, and infrastructure surfaces.

Future verb-first exports or unprefixed exports require a new accepted RFC or
contracts amendment.

---

## 2. Final Rename And Disposition Table

No aliases are shipped. ledgr is pre-CRAN with no external user compatibility
surface to preserve, and the purpose of this batch is to stop teaching names
that will immediately churn.

### 2.1 Changed, Removed, Or Internally Renamed Names

| Current name | Final name or disposition | Binding rationale |
| --- | --- | --- |
| `iso_utc` | `ledgr_iso_utc` | D1 resolved to prefix all six unprefixed exports; utility, not DSL. |
| `passed_warmup` | `ledgr_passed_warmup` | D1 resolved to prefix all six. |
| `select_top_n` | `ledgr_select_top_n` | D1 resolved to prefix all six. |
| `signal_return` | `ledgr_signal_return` | D1 resolved to prefix all six. |
| `target_rebalance` | `ledgr_target_rebalance` | D1 resolved to prefix all six. |
| `weight_equal` | `ledgr_weight_equal` | D1 resolved to prefix all six. |
| `ledgr_backtest_run` | unexport | Bucket A removal. Low-level runner; examples and manual traces can cite internal machinery. |
| `ledgr_clear_feature_cache` | `ledgr_feature_cache_clear` | Feature-cache family first. |
| `ledgr_compare_runs` | `ledgr_run_compare` | Run-family read surface; preserves read-pattern UX. |
| `ledgr_compute_equity_curve` | unexport | Bucket A removal. Duplicate door to `ledgr_results(bt, "equity")` through the same implementation; not a replay helper. |
| `ledgr_create_schema` | unexport | Bucket A removal. DBI schema plumbing, not ordinary workflow. |
| `ledgr_deregister_indicator` | `ledgr_indicator_remove` | Q1 resolved here. Infrastructure action under `ledgr_indicator_*`; `remove` is shorter and user-facing. |
| `ledgr_extract_strategy` | `ledgr_run_strategy` | Run-family read surface; preserves read-pattern UX. |
| `ledgr_extract_fills` | `ledgr_run_fills` | Run-family read surface. Keeps current lazy / `stream_threshold` / `ledgr_fills_cursor` contract unchanged. |
| `ledgr_get_indicator` | `ledgr_indicator_get` | Indicator infrastructure lookup. |
| `ledgr_list_indicators` | `ledgr_indicator_list` | Indicator infrastructure listing. |
| `ledgr_metric_context_resolve` | unexport | Bucket A removal. Public callers use metric-context constructors or shortcut arguments. |
| `ledgr_register_indicator` | `ledgr_indicator_register` | Indicator infrastructure registration. |
| `ledgr_snapshot_load` | `ledgr_snapshot_open` | Reopen vocabulary rule. |
| internal `ledgr_snapshot_open` | internal `ledgr_snapshot_connection` | Same-commit collision fix required before the public `ledgr_snapshot_open` export lands. No roxygen export. |
| `ledgr_ttr_warmup_rules` | `ledgr_ind_ttr_warmup_rules` | D2 placement: TTR constructor-family warmup metadata. |
| `ledgr_walk_forward_extract_candidate` | deleted / unexported; use `ledgr_candidate()` | R4. v0.1.9.4 spec Section 4 is superseded by this synthesis for the public extraction name. |
| `ledgr_walk_forward_results` | `ledgr_walk_forward_open` | Opens compact verified walk-forward evidence, not a live session handle. The help page must say this explicitly. |

### 2.2 Export-Lock Reconciliation For Unchanged Names

Every current export in `tests/testthat/test-api-exports.R` is covered either
by Section 2.1 or by this table. "Unchanged" still requires documentation,
pkgdown, tests, and contracts references to be rechecked during the rename
batch.

| Current and final name | Reason unchanged |
| --- | --- |
| `ledgr_adapter_csv` | Snapshot adapter family already family-first. |
| `ledgr_adapter_r` | Snapshot adapter family already family-first. |
| `ledgr_backtest` | Existing public backtest entry point; not part of this naming drift. |
| `ledgr_backtest_bench` | D5 resolved keep-public; closed verb-first diagnostic allowlist. |
| `ledgr_calendar` | Calendar family root. |
| `ledgr_calendar_crypto` | Calendar family template. |
| `ledgr_calendar_us_equity` | Calendar family template. |
| `ledgr_candidate` | R4 generic. |
| `ledgr_candidate_reproduction_key` | Candidate family accessor. |
| `ledgr_compute_metrics` | Closed verb-first allowlist. |
| `ledgr_cost_chain` | Cost family constructor. |
| `ledgr_cost_describe` | Cost family inspection helper. |
| `ledgr_cost_fixed_fee` | Cost family constructor. |
| `ledgr_cost_notional_bps_fee` | Cost family constructor. |
| `ledgr_cost_spread_bps` | Cost family constructor. |
| `ledgr_cost_steps` | Cost family accessor. |
| `ledgr_cost_zero` | Cost family constructor. |
| `ledgr_db_init` | D4 resolved keep-public as part of the recovery pair; docs required. |
| `ledgr_demo_sma_crossover_strategy` | Demo family; acceptable descriptive name. |
| `ledgr_experiment` | Experiment family root. |
| `ledgr_feature_contract_check` | Feature family contract helper. |
| `ledgr_feature_contracts` | Feature family contract accessor. |
| `ledgr_feature_grid` | Feature-grid constructor. |
| `ledgr_feature_id` | Feature identity helper. |
| `ledgr_feature_map` | Feature-map constructor. |
| `ledgr_fold` | Fold family root. |
| `ledgr_folds_anchored` | Fold-list constructor. |
| `ledgr_folds_rolling` | Fold-list constructor. |
| `ledgr_grid_add_baseline` | Grid family action; not verb-first. |
| `ledgr_grid_cross` | Grid family constructor. |
| `ledgr_grid_named` | Grid family constructor. |
| `ledgr_ind_ema` | D2 indicator-constructor namespace. |
| `ledgr_ind_returns` | D2 indicator-constructor namespace. |
| `ledgr_ind_rsi` | D2 indicator-constructor namespace. |
| `ledgr_ind_sma` | D2 indicator-constructor namespace. |
| `ledgr_ind_ttr` | D2 indicator-constructor namespace. |
| `ledgr_ind_ttr_outputs` | D2 TTR constructor-family helper. |
| `ledgr_indicator` | Indicator infrastructure root/custom constructor. |
| `ledgr_indicator_dev` | Indicator infrastructure/dev helper. |
| `ledgr_metric_context` | Metric-context family constructor. |
| `ledgr_metric_context_hash` | Metric-context family identity helper. |
| `ledgr_metric_crypto` | Metric-context template. |
| `ledgr_metric_us_equity` | Metric-context template. |
| `ledgr_opening` | Opening-state family root. |
| `ledgr_opening_from_broker` | Opening-state helper; broker adapter remains future-scoped. |
| `ledgr_param` | Parameter marker root. |
| `ledgr_param_grid` | Parameter-grid constructor. |
| `ledgr_parameters` | Parameter helper. |
| `ledgr_precompute_features` | Closed verb-first allowlist. |
| `ledgr_promote` | Cross-container promotion verb retained by existing workflow. |
| `ledgr_promotion_context` | Promotion-context accessor. |
| `ledgr_pulse_features` | Pulse inspection helper. |
| `ledgr_pulse_snapshot` | Pulse inspection helper. |
| `ledgr_pulse_wide` | Pulse inspection helper. |
| `ledgr_results` | Existing generic result table accessor. |
| `ledgr_risk_chain` | Risk family constructor. |
| `ledgr_risk_free_rate` | Metric/risk-free-rate value helper; established public surface. |
| `ledgr_risk_long_only` | Risk family constructor. |
| `ledgr_risk_max_weight` | Risk family constructor. |
| `ledgr_risk_none` | Risk family constructor. |
| `ledgr_run` | Run family execution entry point. |
| `ledgr_sweep` | Sweep family execution entry point. |
| `ledgr_run_archive` | Run family mutation. |
| `ledgr_run_info` | Run family read surface. |
| `ledgr_run_label` | Run family mutation. |
| `ledgr_run_list` | Run family read surface. |
| `ledgr_run_open` | Run family reopen surface. |
| `ledgr_run_promotion_context` | Run family promotion-context accessor. |
| `ledgr_run_tag` | Run family mutation. |
| `ledgr_run_tags` | Run family read surface. |
| `ledgr_run_untag` | Run family mutation. |
| `ledgr_select_argmax` | Selection-rule constructor; family-first under `select`. |
| `ledgr_select_argmin` | Selection-rule constructor; family-first under `select`. |
| `ledgr_selection` | Selection family root. |
| `ledgr_signal` | Signal helper root. |
| `ledgr_signal_strategy` | Signal-strategy wrapper. |
| `ledgr_sim_bars` | Simulation-data helper; family-first under `sim`. |
| `ledgr_snapshot_close` | Snapshot lifecycle action. |
| `ledgr_snapshot_create` | Snapshot lifecycle action. |
| `ledgr_snapshot_from_csv` | Snapshot constructor. |
| `ledgr_snapshot_from_df` | Snapshot constructor. |
| `ledgr_snapshot_from_yahoo` | Snapshot constructor. |
| `ledgr_snapshot_import_bars_csv` | Snapshot import helper. |
| `ledgr_snapshot_import_instruments_csv` | Snapshot import helper. |
| `ledgr_snapshot_info` | Snapshot read surface. |
| `ledgr_snapshot_list` | Snapshot read surface. |
| `ledgr_snapshot_seal` | Snapshot lifecycle action. |
| `ledgr_state_reconstruct` | D4 resolved keep-public as part of the recovery pair; docs required. |
| `ledgr_strategy_preflight` | Strategy family diagnostic. |
| `ledgr_strategy_grid` | Strategy-grid constructor. |
| `ledgr_sweep_retention` | Sweep-retention constructor. |
| `ledgr_sweep_info` | Sweep family read surface. |
| `ledgr_sweep_list` | Sweep family read surface. |
| `ledgr_sweep_open` | Sweep family reopen surface. |
| `ledgr_sweep_returns` | Sweep family retained-return accessor. |
| `ledgr_sweep_returns_wide` | Sweep family retained-return projection. |
| `ledgr_sweep_save` | Sweep family persistence action. |
| `ledgr_target` | Target helper root. |
| `ledgr_timing_next_open` | Timing family constructor. |
| `ledgr_utc` | UTC timestamp helper already prefixed. |
| `ledgr_validate_schema` | Closed verb-first diagnostic allowlist. |
| `ledgr_walk_forward` | Walk-forward execution entry point. |
| `ledgr_walk_forward_folds` | Walk-forward fold accessor. |
| `ledgr_walk_forward_scores` | Walk-forward score accessor. |
| `ledgr_weights` | Weight helper root. |

---

## 3. Candidate Generic Contract

`ledgr_candidate()` becomes the sole public candidate extraction verb. The
walk-forward method is a small semantic addition, not just a symbol rename, so
the following contract is binding.

### 3.1 Locator Attributes

Both live and reopened `ledgr_walk_forward_results` objects carry durable
string locator attributes:

- `db_path`;
- `snapshot_id`;
- `snapshot_hash`.

They must not capture a live connection, snapshot environment, or DB handle.

### 3.2 Resolve At Call

`ledgr_candidate.ledgr_walk_forward_results()` resolves the locator when the
candidate is requested. It opens store access from the locator, re-verifies the
stored session snapshot hash against `snapshot_hash`, runs the existing
linked-run identity verification, extracts the candidate, and closes resources.

Fail-closed paths are required for:

- missing or moved db file;
- session snapshot-hash mismatch;
- unverifiable linked session;
- explicit override mismatch.

### 3.3 Override Semantics

`ledgr_candidate(wf, ..., snapshot = NULL)` accepts an explicit snapshot
override for moved stores. If supplied:

- override `snapshot_id` must match the locator `snapshot_id`;
- override `snapshot_hash` must match the locator `snapshot_hash`;
- override `db_path` may differ.

The mismatch condition class is
`ledgr_walk_forward_snapshot_override_mismatch`.

Other classed paths reuse existing classes where applicable:
`ledgr_walk_forward_snapshot_hash_mismatch`,
`ledgr_walk_forward_invalid_session`,
`ledgr_walk_forward_latest_without_rationale`, and -- for the
missing/moved-db-file path -- `LEDGR_SNAPSHOT_DB_NOT_FOUND`
(`R/snapshots-list.R:183`; final-review patch F3).

### 3.4 Amendment 2 Extraction Discipline

The v0.1.9.4 walk-forward Amendment 2 discipline carries over:

- `fold_seq` remains required;
- `"latest"` remains rationale-gated;
- candidate-not-found failures remain classed;
- promotion-ready candidate identity remains verified before returning.

### 3.5 Supersession Note

The v0.1.9.5 spec must explicitly state that this synthesis supersedes the
v0.1.9.4 spec Section 4 public name
`ledgr_walk_forward_extract_candidate()`. It does not weaken the v0.1.9.4
identity, rationale, or fail-closed extraction rules.

---

## 4. Unexport Dispositions

The four Bucket A removals are final:

- `ledgr_backtest_run`;
- `ledgr_create_schema`;
- `ledgr_metric_context_resolve`;
- `ledgr_compute_equity_curve`.

The recovery pair stays public:

- `ledgr_db_init`;
- `ledgr_state_reconstruct`.

The recovery decision has a binding documentation requirement. The landing
surface is a new **Recovery** section in `vignettes/experiment-store.qmd` --
or, if the vignette-screening audit's Split D has landed in the same
release, its refocused Experiment Store successor article (final-review
patch F4) -- with generated vignette outputs refreshed if maintained in
the release. The section must teach:

- what `ledgr_db_init()` opens and why ordinary users usually do not need it;
- what `ledgr_state_reconstruct()` reconstructs;
- when the pair is appropriate for low-level recovery or restart inspection;
- what it does not do, including broker reconciliation, live restart safety,
  schema migration, or sealed-snapshot repair.

`ledgr_backtest_bench()` stays public as the session-scoped detailed telemetry
surface and is part of the R1 allowlist.

---

## 5. Contracts.md Rework Ticket

`inst/design/contracts.md` gets its own same-release ticket. It is not a
mechanical search-and-replace-only task.

Acceptance for that ticket:

- re-read and verify each clause that cites a renamed, unexported, or unchanged
  API name;
- bind R1-R7 into the contracts document;
- bind the D2 `ledgr_ind_*` / `ledgr_indicator_*` semantic rule;
- preserve the existing `ledgr_backtest_bench()` telemetry clause unless the
  final review finds it stale for reasons unrelated to naming;
- update any contract examples to the new names;
- leave historical RFC/spec references alone unless they are active normative
  text rather than history;
- land in the same v0.1.9.5 release as the rename batch.

The rename batch cannot pass release gate if `contracts.md` still teaches old
public names outside explicit historical references.

---

## 6. Cost Surfaces, Ticket Shape, And Sequencing

The v0.1.9.5 spec packet should cut at least these implementation tickets.
The known cost surfaces are `R/` symbol definitions and call sites,
`NAMESPACE`, roxygen/man pages, `tests/testthat/test-api-exports.R`,
documentation-contract tests, `_pkgdown.yml`, README, executing vignettes,
the pkgdown-only positioning articles (`vignettes/articles/`),
`inst/design/contracts.md`, `inst/design/ledgr_ux_decisions.md`, and
`NEWS.md` (final-review patch F2).

1. **M-8 correctness prerequisite.**
   Fix the `ledgr_results(bt, "fills")` dead-cursor path before or in the
   same batch as the fills rename. The preferred contract is that borrowed
   connections are never captured into returned cursors; `ledgr_results()` is
   eager.
2. **Rename and unexport batch.**
   Apply Section 2.1, update `NAMESPACE`, roxygen, man pages, export lock,
   pkgdown reference groups, documentation-contract tests, and all first-contact
   docs. No aliases.
3. **Candidate generic and walk-forward locator batch.**
   Replace the walk-forward extraction export with `ledgr_candidate()`, add the
   locator attributes, implement resolve-at-call verification, add the override
   mismatch class, and preserve Amendment 2 discipline.
4. **Contracts pass.**
   Complete Section 5.
5. **Recovery and teaching docs.**
   Add the `vignettes/experiment-store.qmd` Recovery section, update UX decision
   references, and refresh generated docs as required by the repo's release
   rules.

The spec may split these further for reviewability, but it must not sequence
the contracts pass or recovery docs into a later release.

---

## 7. Mechanical Acceptance Criteria And Gates

All criteria below must be mechanically checkable.

### 7.1 Export Lock

- `tests/testthat/test-api-exports.R` is updated to remove every old name in
  Section 2.1, add every new public name in Section 2.1, keep every unchanged
  name in Section 2.2, and assert the internal helper
  `ledgr_snapshot_connection` exists while `ledgr_snapshot_open` is exported
  only as the public snapshot reopen surface.
- `pkgload::load_all()` plus the export-lock test passes.

### 7.2 Old-Name Sweep

At packet release gate, an `rg` sweep for all old names in Section 2.1 returns
zero hits outside `NEWS.md` and design-history records (`inst/design/rfc/`,
completed spec packets, audits, release closeouts, and this synthesis). Active
runtime, tests, vignettes, README, man pages, pkgdown config, and
`contracts.md` must not retain old names.

### 7.3 Internal Definition Collision Gate

Before a new public name lands, grep internal definitions for exact collisions,
not just exports. At minimum, the ticket must check each new public symbol with
an anchored definition search over `R/`, and the release gate must confirm:

- the old internal `ledgr_snapshot_open` helper no longer exists;
- `ledgr_snapshot_connection` is internal-only;
- no new public name shadows an existing internal function.

### 7.4 M-8 Gate

M-8 is fixed before or with the rename batch. A regression test must force the
above-threshold borrowed-connection path and assert that
`ledgr_results(bt, "fills")` returns an eager result table, not a
`ledgr_fills_cursor` backed by a connection scheduled for close.

### 7.5 Candidate Generic Gate

Tests cover:

- live walk-forward results carry `db_path`, `snapshot_id`, and `snapshot_hash`
  locator attributes;
- reopened walk-forward results carry the same locator attributes;
- `ledgr_candidate(wf, fold_seq = ...)` resolves from the locator at call time;
- explicit snapshot override succeeds when `snapshot_id` and `snapshot_hash`
  match, even if `db_path` differs;
- explicit override mismatch fails with
  `ledgr_walk_forward_snapshot_override_mismatch`;
- session hash mismatch fails closed with the existing classed path;
- `"latest"` without rationale still fails with
  `ledgr_walk_forward_latest_without_rationale`.

### 7.6 Streaming Contract Gate

`ledgr_run_fills()` preserves the current `lazy`, `stream_threshold`, cursor
class, and cursor cleanup behavior from `ledgr_extract_fills()`. The rename
must not fold streaming into `ledgr_results()`.

### 7.7 Contracts And Docs Gate

- `contracts.md` passes the clause-by-clause rework in Section 5.
- `vignettes/experiment-store.qmd` contains the Recovery section bound in
  Section 4.
- `README.md`, `_pkgdown.yml`, `ledgr_ux_decisions.md`, executing vignettes,
  man pages, and documentation-contract tests no longer teach old names.
- `ledgr_walk_forward_open()` docs state that the function opens compact
  verified evidence, not a live session handle.
- `NEWS.md` carries the consolidated rename/unexport table for the batch
  (final-review patch F2).

---

## 8. Future Obligations Recorded

These are not v0.1.9.5 implementation scope unless a later spec explicitly
promotes them.

- **`ledgr_results()` streaming extension.** Folding fills streaming into
  `ledgr_results()` requires new public lazy arguments and cursor lifecycle
  semantics. It is semantic work, not a rename.
- **Argument-name and argument-order audit.** This RFC binds exported function
  names, not argument naming consistency.
- **Family-contraction trigger.** If a family grows large enough that
  `ledgr_<family>_<action>` becomes noisy, open a separate contraction RFC
  rather than changing ad hoc.
- **Broader `ledgr_open()` generic.** Reopen generic consolidation can be
  reconsidered after `ledgr_candidate()` proves the generic pattern and after
  current family-specific `*_open()` semantics are stable.

---

## 9. Open Questions Promoted To Spec-Cut

None. Q1 is resolved here as `ledgr_indicator_remove()`.

The spec writer may choose ticket granularity and review batch order, but not
different public names, aliases, or delayed contracts/docs sequencing without a
maintainer amendment to this synthesis.
