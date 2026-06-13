# RFC: API Naming Consistency And Surface Tightening

**Status:** Seed v1 - request for response-stage review. No implementation
started. Nothing in this document is binding until a synthesis is accepted.
**Date:** 2026-06-11
**Author:** Claude (seed v1; per `../rfc_cycle.md` role rotation the response
stage should be authored by a different model, synthesis by whoever did not
write seed v2).
**Window:** v0.1.9.5 (documentation, teaching, contracts, entropy management).
**Input:** Maintainer request following the v0.1.9.4-close deep code review
(`../audits/v0_1_9_4_deep_code_review_audit.md`) and an API-naming discussion
that started from dissatisfaction with `ledgr_walk_forward_extract_candidate()`.
**Context files:**
- `tests/testthat/test-api-exports.R` - the locked export surface (the
  inventory below is drawn from this lock)
- `inst/design/ledgr_ux_decisions.md` - tidyverse-adjacent north star, the
  three interaction patterns, return-value contract
- `inst/design/rfc_cycle.md` - cycle discipline, pre-CRAN framing rules
- `R/sweep.R` - `ledgr_candidate()` (sweep candidate extraction)
- `R/walk-forward-inspection.R` - `ledgr_walk_forward_extract_candidate()`,
  `ledgr_walk_forward_results()`
- `R/backtest.R` - `ledgr_extract_fills()` (line 1168),
  `ledgr_compute_equity_curve()` (line 1707)
- `R/public-api.R` - `ledgr_db_init()` (line 58), `ledgr_state_reconstruct()`
  (line 112)
- `R/snapshots-list.R` - `ledgr_snapshot_load()` (line 175)
- `R/strategy-extract.R` - `ledgr_extract_strategy()` (line 169)
- `R/strategy-types.R` - `ledgr_selection()` and the strategy DSL family
- `R/backtest-runner.R` - `ledgr_backtest_run()` (documented as low-level
  internal, lines 12-15)
- `inst/design/manual/identity_contract.qmd`, `inst/design/contracts.md`

---

## 1. Problem Statement

The exported API surface (~130 `ledgr_*` functions plus six unprefixed
exports, locked in `test-api-exports.R`) grew across eleven v0.1.7-v0.1.9
releases. Each family is internally sensible, but the surface as a whole has
accumulated four kinds of drift:

1. **Verb-position inconsistency.** The package's best families are
   noun-first (`ledgr_run_tag`, `ledgr_snapshot_seal`, `ledgr_sweep_save`),
   which makes autocomplete the de facto module browser: `ledgr_run_<TAB>`
   shows the whole run family. A minority of exports are verb-first
   (`ledgr_compare_runs`, `ledgr_clear_feature_cache`,
   `ledgr_extract_strategy`, `ledgr_register_indicator`) and fall outside
   their family's TAB group.
2. **Duplicate vocabularies for one concept.** Two reopen verbs
   (`ledgr_snapshot_load` vs `ledgr_run_open` / `ledgr_sweep_open`); two
   candidate-extraction surfaces (`ledgr_candidate()` for sweeps vs
   `ledgr_walk_forward_extract_candidate()` for walk-forward); three naming
   schemes inside the indicator domain (`ledgr_indicator*`, `ledgr_ind_*`,
   `*_indicator(s)`).
3. **Weak verbs that hide semantics.** `extract` appears three times
   (`ledgr_extract_strategy`, `ledgr_extract_fills`,
   `ledgr_walk_forward_extract_candidate`) and never tells the reader
   anything the noun would not.
4. **Surface that should not be public.** `ledgr_backtest_run()` documents
   itself as a low-level internal runner whose direct use "is not
   recommended"; `ledgr_backtest_bench()` is a benchmarking harness;
   `ledgr_create_schema()` / `ledgr_db_init()` are store plumbing partially
   superseded by the snapshot-first flow. Every unnecessary export widens the
   wall a first-contact user faces.

This is not a runtime or architecture problem. It is the API-shape analog of
the entropy v0.1.9.5 exists to manage: the cost of fixing it is near its
all-time minimum (pre-CRAN, zero external users, vignettes and doc-contract
tests will mechanically catch every rename) and rises with every release that
teaches the current names.

The maintainer's north star for this cycle: **tidyverse-grade internal
consistency - readable, predictable, composable.** Note the precise sense:
tidyverse style says function names should be verbs, but the tidyverse's own
family packages (stringr, forcats) put the domain noun first and the verb
last (`str_replace`, `fct_reorder`). ledgr's `ledgr_run_tag` pattern is
exactly that shape. The goal is to make that shape the rule rather than the
majority case.

---

## 2. Current State Inventory

Drawn from the export lock in `tests/testthat/test-api-exports.R`. Families
listed with their internal consistency assessment.

### 2.1 Consistent families (hold as the standard; do not touch)

- **Run lifecycle and metadata:** `ledgr_run_archive`, `ledgr_run_info`,
  `ledgr_run_label`, `ledgr_run_list`, `ledgr_run_open`, `ledgr_run_tag`,
  `ledgr_run_tags`, `ledgr_run_untag`. The reference family.
- **Sweep artifacts:** `ledgr_sweep_info`, `ledgr_sweep_list`,
  `ledgr_sweep_open`, `ledgr_sweep_retention`, `ledgr_sweep_returns`,
  `ledgr_sweep_returns_wide`, `ledgr_sweep_save`.
- **Cost constructors:** `ledgr_cost_chain`, `ledgr_cost_describe`,
  `ledgr_cost_fixed_fee`, `ledgr_cost_notional_bps_fee`,
  `ledgr_cost_spread_bps`, `ledgr_cost_steps`, `ledgr_cost_zero`.
- **Risk constructors:** `ledgr_risk_chain`, `ledgr_risk_long_only`,
  `ledgr_risk_max_weight`, `ledgr_risk_none`, `ledgr_risk_free_rate`.
- **Folds and selection:** `ledgr_fold`, `ledgr_folds_anchored`,
  `ledgr_folds_rolling`, `ledgr_select_argmax`, `ledgr_select_argmin`.
- **Snapshot constructors and lifecycle:** `ledgr_snapshot_close`,
  `ledgr_snapshot_create`, `ledgr_snapshot_from_csv`,
  `ledgr_snapshot_from_df`, `ledgr_snapshot_from_yahoo`,
  `ledgr_snapshot_import_bars_csv`, `ledgr_snapshot_import_instruments_csv`,
  `ledgr_snapshot_info`, `ledgr_snapshot_list`, `ledgr_snapshot_seal`.
  (One stray: `ledgr_snapshot_load`, Section 2.3.)
- **Grids:** `ledgr_param_grid`, `ledgr_feature_grid`, `ledgr_strategy_grid`
  ("grids of X") vs `ledgr_grid_cross`, `ledgr_grid_named`,
  `ledgr_grid_add_baseline` (combinators over grids). Two-level scheme,
  defensible; hold.

### 2.2 Verb-first strays with clean noun-first homes

| Current | File | Proposed | Note |
| --- | --- | --- | --- |
| `ledgr_compare_runs` | `R/backtest.R` | `ledgr_run_compare` | joins run family TAB group |
| `ledgr_clear_feature_cache` | `R/feature-cache.R` | `ledgr_feature_cache_clear` | joins `ledgr_feature_*` |
| `ledgr_extract_strategy` | `R/strategy-extract.R:169` | `ledgr_run_strategy` | run-evidence accessor; signature `(snapshot, run_id, trust)` already run-scoped |
| `ledgr_extract_fills` | `R/backtest.R:1168` | `ledgr_run_fills` or fold into `ledgr_results()` | see open question Q3; signature `(bt, lazy, stream_threshold)` has streaming capability `ledgr_results()` may not |
| `ledgr_register_indicator` | `R/indicator.R` | `ledgr_indicator_register` | registry family, Section 2.4 |
| `ledgr_deregister_indicator` | `R/indicator.R` | `ledgr_indicator_remove` | or `_deregister`; pick at spec cut |
| `ledgr_get_indicator` | `R/indicator.R` | `ledgr_indicator_get` | |
| `ledgr_list_indicators` | `R/indicator.R` | `ledgr_indicator_list` | matches `run_list` / `sweep_list` / `snapshot_list` |

Deliberately NOT renamed: `ledgr_compute_metrics`, `ledgr_precompute_features`
(genuine operations, not artifact methods; the verb earns its place), and the
strategy-preflight / promotion-context names.

### 2.3 Duplicate vocabularies

**Reopen verb.** `ledgr_snapshot_load(db_path, snapshot_id, verify)`
(`R/snapshots-list.R:175`) vs `ledgr_run_open` / `ledgr_sweep_open`. Same
concept - reattach to a persisted artifact - two verbs. Proposal: `open`
wins; `ledgr_snapshot_load` becomes `ledgr_snapshot_open`. The same rule then
names the walk-forward reopen helper: `ledgr_walk_forward_results(snapshot,
session_id)` performs a verified reopen but is named like an accessor.
Proposal: `ledgr_walk_forward_open()`. (Open question Q2 records the
counter-argument.)

**Candidate extraction.** The sweep path is container-in, candidate-out:

```r
results <- ledgr_sweep(exp, grid, ...)
candidate <- ledgr_candidate(results, which = "trade")
promoted <- ledgr_promote(exp, candidate, run_id = ...)
```

Walk-forward broke the pattern with a parallel function and a different
signature: `ledgr_walk_forward_extract_candidate(snapshot, session_id,
fold_seq, selection_rationale)`. Proposal (Section 4): make
`ledgr_candidate()` an S3 generic over evidence containers and delete the
long name outright.

**Replay vocabulary.** `ledgr_compute_equity_curve(bt)` (`R/backtest.R:1707`,
verb-first) and `ledgr_state_reconstruct(run_id, con)` (`R/public-api.R:112`,
noun-first) are both replay-from-events operations with flipped word orders.
`ledgr_state_reconstruct` self-documents as "a low-level DBI recovery helper"
in its own error text. Proposal: pair them under one shape at spec cut -
either both `ledgr_<noun>_<verb>` (`ledgr_equity_recompute` /
`ledgr_state_reconstruct`) or fold the low-level pair into an unexported
recovery surface (Section 2.5).

### 2.4 The indicator domain has three naming schemes

- `ledgr_indicator()`, `ledgr_indicator_dev()` - constructor and dev helper;
- `ledgr_ind_sma`, `ledgr_ind_ema`, `ledgr_ind_rsi`, `ledgr_ind_returns`,
  `ledgr_ind_ttr`, `ledgr_ind_ttr_outputs` - built-ins under a contracted
  prefix;
- `ledgr_register_indicator`, `ledgr_deregister_indicator`,
  `ledgr_get_indicator`, `ledgr_list_indicators` - registry, verb-first;
- plus `ledgr_ttr_warmup_rules` (TTR domain without the `ind_` token) and
  `ledgr_indicator_bundle` machinery (S3, via the multi-output synthesis).

Proposal: registry functions move under `ledgr_indicator_*` (Section 2.2).
The `ind_` contraction for built-ins is a separate binary decision (D2): it
is short, heavily typed in strategy code, and the maintainer may keep it as a
deliberate contraction - but it should be bound as a decision, not drift.
`ledgr_ttr_warmup_rules` follows whatever D2 decides.

### 2.5 Unexport candidates (cheapest tightening: deletion from the surface)

| Export | Evidence | Disposition proposal |
| --- | --- | --- |
| `ledgr_backtest_run` | own docs: "low-level internal runner... not recommended" (`R/backtest-runner.R:12-15`) | unexport; `ledgr_backtest()` and `ledgr_run()` are the supported doors |
| `ledgr_backtest_bench` | benchmarking harness | unexport; dev tooling lives in `dev/bench/` |
| `ledgr_create_schema` | store plumbing; snapshot-first flow creates schema internally | unexport; keep `ledgr_validate_schema` as the public diagnostic |
| `ledgr_db_init` | raw DBI connection opener; used in `ledgr_state_reconstruct` examples | decide with the recovery-surface question (Q4) |
| `ledgr_metric_context_resolve` | internal resolution machinery; public callers use `ledgr_metric_context()` | unexport unless a documented workflow needs it (verify at response stage) |

Pre-CRAN framing check (per `../rfc_cycle.md`): the cost of each unexport is
internal only - roxygen `@export` tags, the api-exports lock, any vignette or
manual page that demonstrates them. No external-user cost exists.

### 2.6 The unprefixed six

`iso_utc`, `passed_warmup`, `select_top_n`, `signal_return`,
`target_rebalance`, `weight_equal`.

Five of these are the strategy-authoring DSL: they are designed to read
fluently inside strategy pipelines alongside the prefixed type constructors
(`ledgr_selection`, `ledgr_signal`, `ledgr_target`, `ledgr_weights` in
`R/strategy-types.R`):

```r
ctx |> ledgr_signal(...) |> select_top_n(5) |> weight_equal() |> target_rebalance()
```

The tension is real: half-prefixed pipelines are neither fully branded nor
fully fluent, `select_top_n` is one tidyverse-adjacent package away from a
masking conflict, and CRAN review notices unprefixed exports. `iso_utc` is
not DSL at all - it is a utility with a prefixed sibling (`ledgr_utc`).

Proposal: `iso_utc` gains the prefix unconditionally. The DSL five are a
maintainer decision (D1): either prefix them too (consistency wins; pipelines
read `ledgr_select_top_n(5)`) or bind the unprefixed DSL exception in
`contracts.md` with a collision policy (fluency wins; the exception is
governed). The seed author leans prefix-everything - the fluency gain is
small against the cost of two namespace classes - but this is a product
choice, not a technical one.

### 2.7 The front-door trio

`ledgr_backtest` (one-shot convenience), `ledgr_run` (experiment runner),
`ledgr_backtest_run` (internal). Unexporting the third (Section 2.5) reduces
the trio to a two-door story that the docs already tell well. No rename
proposed for the first two.

---

## 3. Design Constraints

1. **Tidyverse-adjacent, stringr-shaped.** `ledgr_<family>_<verb>` where the
   family is the artifact noun. Verb-first names are reserved for genuine
   cross-artifact operations (`compute_metrics`, `precompute_features`).
2. **The three interaction patterns are load-bearing.**
   `ledgr_ux_decisions.md` binds Execution / Mutation / Read patterns and a
   return-value contract. Renames must preserve each function's pattern and
   update that document - per `../rfc_cycle.md`, accepted docs create
   maintainer-facing mental models that change deliberately, not silently.
3. **No backward compatibility shims.** Pre-CRAN, zero external users
   (`feedback_no_backcompat_prerelease`). Renames are hard renames: no
   aliases, no deprecation warnings, no transition exports. The old names
   are deleted in the same commit that creates the new ones.
4. **Identity surfaces are out of scope.** `cost_model_hash`,
   `risk_chain_hash`, `candidate_key`, `session_id`, condition-class names,
   and persisted schema column names do not change. This RFC renames R-level
   functions only; nothing that participates in hashing, persistence, or the
   condition reference moves.
5. **The drift-catching gates do the verification.** Executing vignettes,
   `test-api-exports.R`, and `test-documentation-contracts.R` are the
   mechanism that proves a rename pass is complete. A rename that does not
   trip a gate was either already consistent or is not covered by a gate -
   the second case is a gate gap worth recording.
6. **Functions, not R6** (`project_dependency_and_strategy_stances`). The
   flat namespace stays; naming is the only module system. This raises the
   value of family-prefix consistency rather than lowering it.

---

## 4. Candidate Extraction As An S3 Generic

The single deepest change proposed. Current state:

- `ledgr_candidate(view, which)` extracts from `ledgr_sweep_results`
  (`R/sweep.R`); the results object already carries `snapshot_hash`,
  `snapshot_id`, and identity attributes that promotion trusts.
- `ledgr_walk_forward_extract_candidate(snapshot, session_id, fold_seq,
  selection_rationale)` extracts from a persisted walk-forward session
  (`R/walk-forward-inspection.R`), re-reading and re-verifying through the
  experiment store.

Proposal: one generic, two methods.

```r
ledgr_candidate(x, ...)

# method: ledgr_sweep_results (unchanged semantics)
ledgr_candidate(sweep_results, which = "trade")

# method: ledgr_walk_forward_results (live or reopened)
wf <- ledgr_walk_forward(exp, grid, folds, selection_rule, seed = 42L)
# ... or wf <- ledgr_walk_forward_open(snapshot, session_id)
candidate <- ledgr_candidate(wf, fold_seq = "latest",
                             selection_rationale = "Manual review accepted latest fold.")
```

Design consequences to bind or refute at response stage:

- **The results object carries its locator.** The walk-forward results
  object (live and reopened) gains the snapshot handle (or db_path +
  snapshot_hash) as an attribute so the method can read run configs and
  re-verify identity. This matches the existing sweep precedent - 
  `ledgr_sweep_results` already carries snapshot identity attributes that
  `ledgr_candidate()` trusts - so it is consistency, not loosening of the
  explicit-locator posture.
- **Closed-snapshot lifecycle.** If the carried snapshot handle was closed
  between reopen and extraction, the method fails with a classed error
  naming the fix. Fail-closed, no silent fallback to a stale path.
- **Audit explicitness carries over unchanged.** Required `fold_seq`, the
  `"latest"` sentinel, `ledgr_walk_forward_latest_without_rationale`, and
  identity re-verification at extraction time are method behavior, not
  casualties of the dispatch change.
- **Spec supersession.** The v0.1.9.4 spec Section 4 binds the public name
  `ledgr_walk_forward_extract_candidate`. v0.1.9.4 has closed; this RFC's
  synthesis, if accepted, supersedes that binding for v0.1.9.5 with an
  explicit note in the v0.1.9.5 packet. No maintainer override is needed at
  seed stage; the supersession is what the synthesis is for.

---

## 5. Proposed Naming Rules (for the synthesis to bind)

- **R1 - family-first.** Artifact-scoped operations are named
  `ledgr_<family>_<action>`. Families: `snapshot`, `run`, `sweep`,
  `walk_forward`, `candidate`, `cost`, `risk`, `fold(s)`, `feature`,
  `indicator`, `metric`, `grid`/`param`. Verb-first names are reserved for
  cross-artifact operations.
- **R2 - one reopen verb.** `open` reattaches to persisted artifacts:
  `ledgr_snapshot_open`, `ledgr_run_open`, `ledgr_sweep_open`,
  `ledgr_walk_forward_open`.
- **R3 - accessors are nouns.** No `extract_`, `get_`, or `fetch_` on
  evidence accessors. `ledgr_results(bt, what)` is the model.
- **R4 - one candidate verb.** `ledgr_candidate()` is a generic over
  evidence containers; per-container extraction functions are forbidden.
- **R5 - every export is prefixed** unless contracts.md binds a named DSL
  exception with a collision policy (maintainer decision D1).
- **R6 - internal functions are internal.** A function whose own
  documentation steers users elsewhere is unexported, not documented around.
- **R7 - one prefix scheme per domain.** The indicator domain consolidates
  per D2; future domains pick one scheme at their first export.

---

## 6. Internal Cost Surfaces (pre-CRAN framing, named explicitly)

Per `../rfc_cycle.md`, pre-CRAN status removes external-user cost only. The
internal surfaces a rename pass touches:

- `NAMESPACE` via roxygen `@export` / function renames;
- `tests/testthat/test-api-exports.R` - the lock updates once, in the same
  commit as the renames;
- ~107 test files referencing current names (mechanical, grep-driven);
- executing vignettes (`vignettes/*.qmd`) - these are the drift gate, they
  fail loudly until updated;
- `_pkgdown.yml` reference groups;
- `README.md`, `inst/design/ledgr_ux_decisions.md` (return-value contract
  table cites `ledgr_compare_runs` and `ledgr_extract_strategy` by name),
  `inst/design/manual/*.qmd` where names appear;
- `NEWS.md` - one consolidated "API naming consistency" entry naming every
  rename and unexport;
- `man/` regenerates from roxygen.

**contracts.md is a first-class rework item, not a grep casualty.**
`inst/design/contracts.md` cites `ledgr_*` function names ~85 times across
714 lines, including direct rename targets (`ledgr_snapshot_load` 3x,
`ledgr_compare_runs` 2x, `ledgr_state_reconstruct`,
`ledgr_ttr_warmup_rules`). Because contracts.md is a binding authority
document (per `rfc/README.md`: "contracts... remain authoritative"), renaming
a surface it binds requires a deliberate contracts rework pass: each affected
contract clause is re-read, the named surface updated, and the clause
re-verified to still say what it bound - not a mechanical find-replace. The
rework pass is also where this RFC's own bindings land: the R1-R7 naming
rules become a contracts.md section, and the D1 DSL exception (if the
maintainer keeps unprefixed DSL exports) is bound there with its collision
policy. contracts.md is therefore both a consumer of the renames and the
durable home for the naming rules; the synthesis must scope it as its own
ticket, not a line item in the mechanical rename batch.

Not touched: persisted schemas, identity hashes, condition classes, DuckDB
artifacts, the C++ kernel, `dev/bench` harnesses (update opportunistically).

---

## 7. Non-Goals

- No semantic changes to any renamed function. Rename means rename:
  signature, behavior, and return contract are byte-identical except where
  Section 4 explicitly adds the results-object locator attribute.
- No argument-name consistency audit in this cycle (recorded as a future
  obligation, Section 9).
- No `ledgr_wf_*` or other contraction scheme. Full words win at current
  family sizes; the contraction trigger is recorded as a future obligation.
- No print-method changes (governed by `ledgr_ux_decisions.md`).
- No new exports beyond the `ledgr_candidate()` methods.
- No pipe-API redesign; the three interaction patterns stand.

---

## 8. Acceptance Criteria If Implemented

- Every export matches R1-R7 or carries a bound exception in contracts.md.
- `ledgr_walk_forward_extract_candidate` does not exist;
  `ledgr_candidate()` dispatches on sweep and walk-forward containers with
  all v0.1.9.4 Amendment 2 extraction discipline intact (required
  `fold_seq`, rationale-gated `"latest"`, classed failures).
- One reopen verb across snapshot / run / sweep / walk-forward.
- Zero verb-first artifact methods remain (the cross-artifact allowlist is
  written down in the synthesis).
- The unexport list is applied; `test-api-exports.R` reflects the final
  surface in a single lock update.
- All vignettes execute against the new names; doc-contract tests pass; no
  stale name appears in README, pkgdown groups, ux_decisions, or manual
  pages (rg sweep named in the ticket).
- `contracts.md` rework pass is complete: every contract clause citing a
  renamed surface is re-read and re-verified (not find-replaced), the R1-R7
  naming rules are bound as a contracts.md section, and the D1 disposition
  (prefix or governed DSL exception) is recorded there.
- `NEWS.md` carries the consolidated rename table.

---

## 9. Open Questions vs Future Obligations

Per `../rfc_cycle.md`, separated by lifetime.

**Open questions (for spec-cut within v0.1.9.5):**

- **Q1.** `ledgr_deregister_indicator` -> `ledgr_indicator_remove` or
  `ledgr_indicator_deregister`? (Shorter vs symmetric with `_register`.)
- **Q2.** Does `ledgr_walk_forward_results` become `ledgr_walk_forward_open`
  (reopen semantics, R2) or stay `_results` (it returns the same class the
  live orchestrator returns, and "open" may overpromise a live handle)? The
  seed leans `_open` for R2 consistency; the response should pressure-test
  whether the live/reopened symmetry argues the other way.
- **Q3.** `ledgr_extract_fills` -> `ledgr_run_fills`, or fold into
  `ledgr_results(bt, what = "fills", lazy =, stream_threshold =)`? Requires
  verifying the current overlap between the two surfaces (the extract
  variant has lazy/streaming options; `ledgr_results` may already cover the
  eager case).
- **Q4.** Recovery surface: do `ledgr_db_init` + `ledgr_state_reconstruct`
  stay public as a documented low-level recovery pair (renamed per R1), or
  move internal with a recovery vignette teaching `ledgr:::` access?
- **Q5.** Exact disposition of `ledgr_metric_context_resolve` (verify
  whether any documented workflow calls it).

**Maintainer decisions (stage 6 candidates - product-level binary choices):**

- **D1.** Strategy DSL prefix: prefix all six unprefixed exports, or bind
  the unprefixed-DSL exception in contracts.md. (Seed leans prefix.)
- **D2.** Keep `ledgr_ind_*` as the bound built-in contraction, or expand to
  `ledgr_indicator_*` built-ins. (Seed leans keep `ind_` - heavily typed in
  strategy code - but bind it.)
- **D3.** Approve the unexport list (Section 2.5) as cut.

**Future obligations (separate RFC cycles, recorded for horizon at
synthesis):**

- Argument-name and argument-order consistency audit (e.g. `which` vs
  `fold_seq` vs `run_id` selector naming; locator-first ordering) - same
  spirit, different blast radius, own cycle.
- Contraction trigger: if any single family exceeds ~15 exports, a
  deliberate contraction RFC (e.g. `ledgr_wf_*`) may earn its keep; revisit
  then, not before.
- S3 generic consolidation beyond `ledgr_candidate()` (e.g. `ledgr_open()`
  dispatching on artifact type) - deliberately not this cycle; one generic
  proves the pattern first.

---

## 10. Recommended Sequencing

1. Response stage (different model) verifies: the Q3 overlap claim against
   `R/backtest.R` and `R/result-table.R`; the Section 2.5 unexport evidence;
   whether any rename collides with an existing internal name; and
   pressure-tests Q2 and the Section 4 locator-attribute design.
2. Seed v2 absorbs findings if warranted; maintainer resolves D1-D3 (stage 6
   artifact only if the decisions need escalation beyond in-line v2
   resolution).
3. Synthesis binds R1-R7, the final rename table, the unexport list, and the
   `ledgr_candidate()` method contracts.
4. Final review verifies the rename table against the actual export surface
   and the v0.1.9.4 spec supersession note.
5. Ticket-cut inside the v0.1.9.5 packet: the rename batch lands BEFORE the
   v0.1.9.5 teaching-documentation batches, so every new vignette teaches
   the final vocabulary exactly once. The contracts.md rework (Section 6) is
   its own ticket sequenced with the rename batch: contracts are re-bound in
   the same release that renames the surfaces they cite, never across a
   release boundary.

One process note for the synthesis author: this cycle's blast radius is wide
but shallow (hundreds of mechanical call-site edits, zero semantic changes
outside Section 4). The walk-forward cycle's Section 17 gate-matrix pattern
is heavier than this needs; a single packet-open gate ("rg sweep for every
old name returns zero hits outside NEWS and design history") plus the
existing executing-vignette and api-lock gates should suffice. Flag at
synthesis if the response stage disagrees.
