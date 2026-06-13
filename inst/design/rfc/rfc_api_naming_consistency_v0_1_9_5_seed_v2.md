# RFC: API Naming Consistency And Surface Tightening (Seed v2)

**Status:** Seed v2 - supersedes seed v1 after response-stage findings.
Standalone: read this file, not v1, as the current proposal. Nothing is
binding until a synthesis is accepted.
**Date:** 2026-06-12
**Author:** Claude (seed v1 + v2 per role rotation; response by Codex
2026-06-12; synthesis falls to Codex; final review to Claude).
**Window:** v0.1.9.5, rename batch before the teaching-documentation
batches.
**Inputs:** `rfc_api_naming_consistency_v0_1_9_5_seed.md` (v1,
historical), `rfc_api_naming_consistency_v0_1_9_5_response.md` (Codex),
plus the v1 context-file list (unchanged).

**Revision note (v1 -> v2).** All five response findings absorbed; one
response count corrected against source. Specifics: (1) the
`ledgr_snapshot_open` collision is resolved by renaming the internal
connection helper in the same commit (Section 3.3); (2) Q3 is bound to
`ledgr_run_fills()`, with `ledgr_results()` folding recorded as a future
obligation -- and the response's evidence chain surfaced a real latent
bug now logged as audit finding M-8 (dead cursor above the streaming
threshold), which independently settles the disposition; (3) Section 5
replaces the v1 locator hand-wave with a concrete durable-string locator
contract and corrects v1's overstated sweep-precedent claim; (4) the
unexport list is split into three buckets with `ledgr_backtest_bench`
elevated to a maintainer decision because contracts.md binds
session-scoped telemetry through it; (5) blast-radius numbers are stated
exactly (Section 7); (6) D1 carries the response's both-sides fluency
evidence; (7) `ledgr_compute_equity_curve` and `ledgr_ttr_warmup_rules`
get explicit dispositions instead of implicit coverage.

**Revision note (in-place patches, 2026-06-12, per
`rfc_api_naming_consistency_v0_1_9_5_seed_v2_review.md`).** Four
verification-stage patches, no design reopened: (a) contracts.md count
settled with the counting method named -- 714 physical lines, 99
`ledgr_*` tokens across 84 matching lines under `ledgr_[a-z_]*`
(the earlier 100/85 figure used a digit-inclusive pattern that counted
packet-path references; the response's 691-line figure used a wrong
line-count method); (b) the Section 3.1 equity-helper row no longer
claims replay-from-events semantics -- `ledgr_compute_equity_curve()`
reads the persisted `equity_curve` table via the same impl that backs
`ledgr_results(bt, "equity")`, so its disposition is reframed
(duplicate-accessor question, decoupled from D4); (c) Section 5
override semantics tightened: explicit override snapshots must match
locator `snapshot_id` AND `snapshot_hash`; `db_path` may differ (moved
stores are the override's reason to exist); (d) the override-mismatch
failure path is bound to a new condition class,
`ledgr_walk_forward_snapshot_override_mismatch`.

> This RFC uses "v1"/"v2" for seed revisions of this cycle; ledgr's
> roadmap has no naming-RFC version milestone.

---

## 1. Problem Statement (unchanged from v1, abbreviated)

The exported surface (~130 `ledgr_*` exports plus six unprefixed, locked
in `tests/testthat/test-api-exports.R`) has four kinds of drift:
verb-position inconsistency against the dominant noun-first family
pattern; duplicate vocabularies (two reopen verbs, two candidate
extractors, three indicator naming schemes); weak `extract` verbs; and
internal-grade functions in the public surface. Pre-CRAN with zero
users, the fix cost is at its minimum and rises with every release that
teaches current names. North star: tidyverse-grade consistency in the
stringr shape -- `ledgr_<family>_<action>`, family first.

The response stage confirmed the inventory buckets are complete
(response Section 1, "Inventory completeness") and confirmed the
problem statement, the pre-CRAN no-alias framing, the
rename-before-teaching sequencing, and the identity-surface exclusion
as-is.

---

## 2. Naming Rules (R1-R7, for the synthesis to bind; unchanged)

- **R1 - family-first.** `ledgr_<family>_<action>` for artifact-scoped
  operations. Verb-first reserved for genuine cross-artifact operations
  (`compute_metrics`, `precompute_features`; the response adds
  `validate_schema` as a legitimate diagnostic carveout -- the synthesis
  writes the explicit allowlist).
- **R2 - one reopen verb:** `open`.
- **R3 - accessors are nouns.** No `extract_`/`get_`/`fetch_` on
  evidence accessors.
- **R4 - one candidate verb.** `ledgr_candidate()` generic over evidence
  containers; per-container extraction functions forbidden.
- **R5 - every export prefixed** unless contracts.md binds a named DSL
  exception with a collision policy (D1).
- **R6 - internal functions are internal.**
- **R7 - one prefix scheme per domain.**

---

## 3. Rename Table (revised)

### 3.1 Verb-first strays -> noun-first homes

| Current | New | v2 notes |
| --- | --- | --- |
| `ledgr_compare_runs` | `ledgr_run_compare` | collision-checked clean (response) |
| `ledgr_clear_feature_cache` | `ledgr_feature_cache_clear` | clean |
| `ledgr_extract_strategy` | `ledgr_run_strategy` | clean; README.md:135-144 teaches the old name -- named cost surface |
| `ledgr_extract_fills` | `ledgr_run_fills` | **bound** (was Q3). Keeps the public `lazy` / `stream_threshold` contract and the `ledgr_fills_cursor` lifecycle exactly as-is. Folding into `ledgr_results()` is a recorded future obligation (Section 9): it is semantic work (cursor lifecycle on an eager surface), not a rename -- see audit finding M-8 for the latent bug at the current internal seam, which must be fixed independently of this RFC |
| `ledgr_register_indicator` | `ledgr_indicator_register` | clean |
| `ledgr_deregister_indicator` | `ledgr_indicator_remove` or `_deregister` | Q1 unchanged |
| `ledgr_get_indicator` | `ledgr_indicator_get` | clean |
| `ledgr_list_indicators` | `ledgr_indicator_list` | clean |
| `ledgr_compute_equity_curve` | duplicate-accessor disposition (Q2) | PATCHED per v2 review: this is NOT a replay function. It reads the persisted `equity_curve` table through `ledgr_compute_equity_curve_impl()`, which is the same impl backing `ledgr_results(bt, "equity")` -- the export duplicates an existing canonical door. Disposition options at Q2: unexport as a duplicate (preferred under R6 / one-door-per-question), or rename to an accessor-shaped name. A `*_reconstruct` name is rejected unless replay semantics are deliberately scoped, which this cycle does not do. Decoupled from D4 |

### 3.2 Reopen vocabulary

| Current | New | v2 notes |
| --- | --- | --- |
| `ledgr_snapshot_load` | `ledgr_snapshot_open` | requires Section 3.3 internal rename first |
| `ledgr_walk_forward_results` | `ledgr_walk_forward_open` | **bound** (was Q2). Response recommends `_open` with a doc caveat: it opens compact verified evidence, not a live session handle; reopened `test_runs` remain linked run-id strings. The help page carries that caveat verbatim |

### 3.3 Collision resolution (new in v2; response finding 1)

The internal lazy-connection helper `ledgr_snapshot_open(snapshot)` at
`R/snapshot.R:61-78` (consumed by `get_connection()` at
`R/snapshot.R:80-83`) collides with the proposed public reopen name.
Resolution, in the same commit as the public rename: rename the internal
helper to `ledgr_snapshot_connection()` (internal-only, no roxygen
export, zero public impact); `get_connection()` call site updates with
it. The synthesis's collision-check acceptance criterion (Section 8)
covers this and any future collision: every proposed public name must
grep clean against internal definitions, not only against exports.

### 3.4 ledgr_ttr_warmup_rules placement (new in v2)

Export-locked, pkgdown-grouped, contracts-cited, and taught in the
indicators vignette. Disposition rides D2: if `ind_` is kept as the
bound built-in contraction, this helper moves to the same domain scheme
(`ledgr_ind_ttr_warmup_rules`) or is explicitly allowlisted under its
current name with one sentence in contracts.md; if D2 expands built-ins
to `indicator_`, it follows. No silent skip.

---

## 4. Unexport List (restructured; response finding 4)

**Bucket A - confirmed removals (D3 RESOLVED 2026-06-12: approved as a
set, expanded to four):**

| Export | Evidence |
| --- | --- |
| `ledgr_backtest_run` | self-documented internal runner; example gated `if (FALSE)`; manual traces can cite `ledgr_backtest_run_internal()` |
| `ledgr_create_schema` | DBI plumbing; manual mentions are implementation-detail context, not workflow; internal tests keep using it unexported |
| `ledgr_metric_context_resolve` | response settled Q5: no README, vignette, manual, or doc-contract call site; public callers use `ledgr_metric_context()` |
| `ledgr_compute_equity_curve` | added at D3 resolution: duplicate of `ledgr_results(bt, "equity")` (same impl, `ledgr_compute_equity_curve_impl()`); maintainer prefers the single door |

**Bucket B - recovery-surface decision (D4):** `ledgr_db_init` +
`ledgr_state_reconstruct` (+ the renamed equity-replay helper from
Section 3.1). These form the documented low-level recovery pair
(`ledgr_db_init` opens the raw DBI connection the reconstruct example
requires, and `ledgr_snapshot_load` uses it internally). Options: keep
public as a renamed, documented recovery surface
(`ledgr_state_reconstruct` already self-describes as a low-level DBI
recovery helper), or move internal with a recovery vignette teaching
`ledgr:::` access. Decide as one unit, not per-function.

**Bucket C - telemetry decision (D5):** `ledgr_backtest_bench`. NOT
plain dev tooling, contra v1: `inst/design/contracts.md:259-262` binds
"detailed per-component telemetry remains session-scoped through
`ledgr_backtest_bench()`", it has a runnable example, and it is the only
public door to per-component telemetry. Unexporting requires either a
contracts amendment naming the replacement surface or a deliberate
decision that session-scoped detailed telemetry becomes maintainer-only.

---

## 5. Candidate Extraction As An S3 Generic (revised; response finding 3)

The generic shape stands; the v1 premise is corrected. v1 claimed the
sweep path provides a locator precedent -- it does not.
`ledgr_sweep_results` carries identity attributes (`snapshot_id`,
`snapshot_hash`, sweep/cost/risk identity), not a durable locator, and
neither walk-forward results object (live `R/walk-forward.R:151-168`,
reopened `R/walk-forward-inspection.R:15-40`) carries a snapshot handle,
db path, or even snapshot hash today. The locator is NEW contract,
bound here:

- **Durable-string locator attributes**, not a live handle:
  `ledgr_walk_forward_results` (live and reopened) gains `db_path`,
  `snapshot_id`, and `snapshot_hash` attributes. Live path populates
  from `exp$snapshot`; reopen path from the `snapshot` argument. No R
  connection or environment is captured, so closed-snapshot lifecycle
  hazards do not arise from the attribute itself.
- **Resolve-at-call:** `ledgr_candidate.ledgr_walk_forward_results()`
  opens its own store access from the locator (same machinery the
  inspection helpers already use), re-verifies the stored session
  snapshot hash against the locator's `snapshot_hash`, runs the existing
  linked-run identity verification, extracts, and closes. Fail-closed
  classed errors for: missing/moved db_path, snapshot-hash mismatch,
  unverifiable session.
- **Optional explicit override:** `ledgr_candidate(wf, ...,
  snapshot = NULL)` accepts an explicit snapshot handle for moved
  stores. When supplied, the override must match the locator's
  `snapshot_id` AND `snapshot_hash`; `db_path` may differ -- moved
  stores are the reason the override exists, and linked-run config
  lookup is scoped by snapshot id. A mismatch fails closed with the new
  class `ledgr_walk_forward_snapshot_override_mismatch`. The other
  fail-closed paths reuse existing classes: missing/moved db file
  reuses the snapshot-load failure class, session hash mismatch reuses
  `ledgr_walk_forward_snapshot_hash_mismatch`, unverifiable linked
  sessions reuse `ledgr_walk_forward_invalid_session`. The
  explicit-locator posture is therefore preserved: the default path
  resolves a recorded locator and re-verifies; the override path is
  explicit and verified.
- **Amendment 2 discipline carries over as method arguments,**
  confirmed present in current code by the response: required
  `fold_seq`, rationale-gated `"latest"` with
  `ledgr_walk_forward_latest_without_rationale`, classed
  candidate-not-found failures. No weakening.
- The sweep method (`ledgr_candidate.ledgr_sweep_results`) is unchanged
  in semantics; the generic split is mechanical there.
- `ledgr_walk_forward_extract_candidate` is deleted; the v0.1.9.4 spec
  Section 4 name binding is superseded by this synthesis with an
  explicit note in the v0.1.9.5 packet.

---

## 6. The Unprefixed Six (D1 evidence sharpened; response finding incorporated)

`iso_utc` gains the prefix unconditionally (utility, not DSL; prefixed
sibling exists). For the DSL five (`passed_warmup`, `select_top_n`,
`signal_return`, `target_rebalance`, `weight_equal`) the response
documents that the tradeoff is real, not cosmetic:

- *For prefixing:* namespace hygiene; `select_top_n` is one
  tidyverse-adjacent package from a masking conflict; CRAN review
  notices unprefixed exports; one naming class instead of two.
- *Against prefixing:* the four-stage helper pipeline is shipped
  front-facing teaching material -- strategy-development teaches it as
  the economic-logic surface, and both positioning articles
  (`why-r.qmd`, `who-ledgr-is-for.qmd`) use the unprefixed fluent chain
  as a readability selling point. Prefixing reaches ledgr's
  shop-window code, not just its plumbing.

D1 is a genuine product decision: brand fluency vs namespace hygiene.
v2 takes no lean (v1's prefix-everything lean is withdrawn as
underweighted); the maintainer decides with the shop-window evidence in
view. If the exception is kept, contracts.md binds it with a collision
policy (R5).

---

## 7. Blast-Radius And Cost Surfaces (corrected numbers)

Settled 2026-06-12 (v2-review patch): contracts.md is 714 physical
lines with 99 `ledgr_*` tokens across 84 matching lines, counted with
`ledgr_[a-z_]*` (packet-path references with digits excluded; the
counting method is part of the claim). Direct contracts rename targets and the doc-contract test
locks named in the response (Section 1, "Blast-radius accuracy") are
confirmed and become the rg-sweep checklist in the rename ticket:
contracts.md (first-class rework pass per v1 Section 6, unchanged),
`test-documentation-contracts.R` locks for `ledgr_snapshot_load`,
`ledgr_compare_runs`, `ledgr_extract_strategy`; `_pkgdown.yml` reference
groups; `README.md:135-144`; `ledgr_ux_decisions.md` return-value table;
executing vignettes as the drift gate. The naming rules R1-R7 are bound
INTO contracts.md during the rework pass, which is its own ticket
sequenced with the rename batch (unchanged from v1).

---

## 8. Acceptance Criteria (delta from v1)

v1 criteria stand, plus:

- every proposed public name greps clean against internal definitions
  as well as exports (the `ledgr_snapshot_open` lesson);
- the internal connection-helper rename lands in the same commit as the
  public `ledgr_snapshot_open`;
- `ledgr_run_fills()` preserves the lazy/streaming contract
  byte-for-byte (same args, same cursor class, same lifecycle);
- the walk-forward results locator attributes are present on both live
  and reopened objects, and `ledgr_candidate.ledgr_walk_forward_results`
  fail-closed paths (moved store, hash mismatch, closed override
  mismatch) have classed tests;
- audit finding M-8 (dead cursor at the `ledgr_results`/fills seam) is
  fixed in or before the rename batch -- it is a correctness bug
  independent of naming, but the rename ticket touches the same seam
  and must not ship the bug under a new name;
- bucket A unexports applied (four, per D3); buckets B and C resolved
  keep-public per D4/D5, contracts.md untouched on D5;
- the D4 recovery documentation requirement is met: a "Recovery"
  section teaching `ledgr_db_init` + `ledgr_state_reconstruct` (what
  they do, when to reach for them, what they do not do) lands in the
  experiment-store vignette or the appropriate v0.1.9.5 docs article;
- the six D1 prefix renames land with the rename batch; both
  positioning articles and the strategy-development vignette are
  updated to the prefixed pipeline in the same release.

---

## 9. Decisions And Obligations (renumbered)

**Maintainer decisions -- ALL RESOLVED 2026-06-12 (in-line per
rfc_cycle.md, since this file escalated them; cost-API v2 precedent):**

- **D1 -- RESOLVED: prefix all six.** All five DSL helpers gain the
  `ledgr_` prefix (`ledgr_passed_warmup`, `ledgr_select_top_n`,
  `ledgr_signal_return`, `ledgr_target_rebalance`,
  `ledgr_weight_equal`), plus `ledgr_iso_utc`. Maintainer rationale:
  the visual clutter is accepted as the price of coexisting with other
  attached packages without masking -- "nothing is more annoying than
  having to choose which filter() should actually be used." No
  unprefixed exports remain; R5 needs no exception clause.
- **D2 -- RESOLVED: keep `ind_`, bound with the semantic rule.**
  `ledgr_ind_*` = indicator constructors (return indicator/bundle
  objects for feature maps); `ledgr_indicator_*` = indicator
  infrastructure (custom constructor, registry, dev tools).
  `ledgr_ttr_warmup_rules` -> `ledgr_ind_ttr_warmup_rules`. The rule is
  bound into contracts.md during the rework pass.
- **D3 -- RESOLVED: bucket A approved, expanded to four.**
  `ledgr_backtest_run`, `ledgr_create_schema`,
  `ledgr_metric_context_resolve`, and `ledgr_compute_equity_curve`
  (duplicate of `ledgr_results(bt, "equity")` -- same impl; maintainer:
  "ledgr_results(bt, 'equity') is cleaner"). Q2-new is thereby
  resolved: unexport, no rename.
- **D4 -- RESOLVED: keep the recovery pair public, with a binding
  documentation requirement.** `ledgr_db_init` +
  `ledgr_state_reconstruct` stay exported. Maintainer note: "we need to
  document what it does clearly and cleanly -- I kinda forgot that it
  existed at all." That forgetability is itself the finding: the pair
  is load-bearing in the research-to-production narrative (edge-device
  restart recovery) but has no teaching home. Binding consequence: a
  "Recovery" documentation section (in the experiment-store vignette or
  the v0.1.9.5 docs cycle's appropriate article) teaching what the pair
  does, when to reach for it, and what it does not do. Added to
  acceptance criteria.
- **D5 -- RESOLVED: keep `ledgr_backtest_bench` public.** The bound
  session-telemetry door stays; contracts.md untouched on this point.
  Spec-cut may place it on the verb-first diagnostic allowlist next to
  `ledgr_validate_schema`; no rename required.

**Open questions (spec-cut):**

- **Q1.** `_remove` vs `_deregister` (unchanged).
- **Q2-old resolved:** `_open` bound (Section 3.2). **Q3-old resolved:**
  `ledgr_run_fills` bound (Section 3.1). **Q5-old resolved:** unexport
  confirmed (Section 4 bucket A).
- **Q2 (new, reframed per v2 review).** `ledgr_compute_equity_curve`
  disposition: unexport as a duplicate of `ledgr_results(bt, "equity")`
  (same impl; preferred under R6), or rename to an accessor-shaped
  name. No `*_reconstruct` spelling without scoped replay semantics.

**Future obligations (unchanged from v1, plus):**

- `ledgr_results()` streaming extension (lazy args + public cursor
  lifecycle) as a separate semantic ticket, explicitly NOT this cycle;
- argument-name/order audit; family-contraction trigger at ~15 exports;
  broader `ledgr_open()` generic consolidation only after
  `ledgr_candidate()` proves the pattern.

---

## 10. Cycle State And Next Step

Stages complete: research-equivalent (audit + inventory), seed v1,
response (Codex, 2026-06-12), seed v2, v2 verification review (Codex,
2026-06-12), in-place v2 patches, and maintainer decisions D1-D5
(resolved in-line 2026-06-12; Section 9). Next: synthesis by Codex
binding R1-R7, the final rename table (including the six newly
prefixed DSL exports per D1 and the four bucket-A unexports per D3),
the locator contract with the override semantics and condition classes
as patched, the D2 constructor/infrastructure rule, and the D4 recovery
documentation requirement; final review by Claude verifies the rename
table against the export lock and the collision criterion against
internal definitions. The packet-open gate from v1 stands: an rg sweep
for every old name returns zero hits outside NEWS and design history.
