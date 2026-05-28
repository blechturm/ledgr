# RFC Final Review: Feature Projection Shape, Materialization Policy, And Lookback Access

**Status:** Final review (verification, not design). Reviews the synthesis against
v2, the response, and current source.
**Date:** 2026-05-28
**Reviewer:** Claude (seed v1 + seed v2 author; did not write the synthesis)
**Reviewed artifact:**
`inst/design/rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`

---

## Verdict

**ACCEPT — no blocking issues.** The synthesis faithfully binds seed v2: the
direction positions (§3), sequencing (§4), and gates (§5) match v2; the
open-questions-vs-future-obligations split (§6/§7) matches v2 §6 exactly; the
horizon draft (§8) follows the `rfc_cycle.md` pattern; and **all eight code
anchors in §2 verify against current source.** It is safe to accept and apply
the horizon entry.

Two optional citation-range tightenings and four informational notes are below.
None block acceptance. Per `rfc_cycle.md`, I have not patched the synthesis; the
items are for Codex or Max to apply.

---

## Blocking Issues

None.

---

## Patch Requests

Both are optional precision tightenings, not corrections — the cited facts are
accurate; the ranges are slightly broad/narrow at the edges.

1. **`R/ledger-writer.R` range.** §2 cites `:67-83` for "computes `cash_delta`
   and `position_delta`, places them in `meta_json`." `position_delta`
   (`signed_qty`) is computed at line 66 (just before 67) and the `meta_json`
   list closes at line 86 (just after 83). Optional: cite `66-86`. The INSERT
   citation `:104-128` is within the `dbExecute` block (`101-131`); optional:
   `101-131`.

2. **`R/derived-state.R` range.** §2 cites `:12-31` (positions) and `:56-73`
   (cash) for "parse `meta_json`." The actual `jsonlite::fromJSON` calls are at
   lines 29 and 70 (both inside the cited ranges, so not wrong). Optional: tighten
   to the parse loops (`25-37` and `69-76`) for pinpoint accuracy.

---

## Informational Notes

1. **Carried-forward parity gate (acceptable).** §5 adds "fingerprint-stability
   pins and LDG-2403 accounting parity remain green after each result-affecting
   change." This was in v1 §8 but not restated in v2 §5. It is a standard
   regression gate consistent with prior syntheses, not a new obligation — fine
   to keep.

2. **Added 5.3 / 5.4 gates (acceptable).** §3 attaches explicit gates to 5.3
   (public long-schema parity + no full-panel materialization) and 5.4
   (no-lookahead + warmup/NA fixtures) that v2 stated only as direction text.
   Binding gates is the synthesis's job; both are consistent with v1/v2 intent
   and do not reopen design.

3. **Horizon tag is novel.** §8 uses `### 2026-05-28 [feature-projection] ...`.
   Existing horizon tags are `[optimization]`, `[infrastructure]`, `[api]`,
   `[architecture]`. Non-blocking, but consider an existing tag (e.g.
   `[architecture]` or `[optimization]`) for grep consistency.

4. **Horizon entry is fenced — strip the fence on apply.** §8 presents the entry
   inside a ```` ```markdown ```` block. When it is added to `inst/design/horizon.md`
   after acceptance, paste the inner content only (drop the fence), or it becomes
   a literal code block rather than a live entry. This is an application note,
   not a synthesis defect.

---

## Verification Notes

All §2 code anchors verified against current source (`v0.1.8.5` branch):

| Synthesis claim | Citation | Result |
| --- | --- | --- |
| `ledgr_run_fold()` calls `ledgr_feature_cache_key()` in the per-(instrument,feature) loop | `R/backtest-runner.R:1214` | PASS — `cache_key <- ledgr_feature_cache_key(` at 1214 |
| Cache key recomputes **both** def fingerprint and engine version | `R/feature-cache.R:94-95` | PASS — `indicator_fingerprint = ledgr_feature_def_fingerprint(feature_def)` (94), `feature_engine_version = ledgr_feature_engine_version()` (95) |
| `ledgr_projection_pulse_views()` allocates both views | `R/runtime-projection.R:233-234` | PASS — `feature_table`/`features_wide` list allocs |
| ...and builds/splits the full long table for all pulses | `R/runtime-projection.R:276-287` | PASS — `feature_table_all` + `ledgr_split_pulse_data_frame` |
| Fold tolerates absent `feature_table` via schema-shaped empty frame | `R/fold-core.R:99-108` | PASS — `feature_table_views` fallback + `empty_feature_table` (feature_ids=character()) |
| Non-fast helper rebuilds long when `features` empty + projection present | `R/pulse-context.R:233-235` | PASS — `features <- ledgr_projection_feature_table(projection, pulse_idx, ...)` |
| Buffered handler column-primitive at the R boundary | `R/backtest-runner.R:362-485` | PASS — preallocated column vectors; `data.frame` only at `flush_pending` |
| `ledger_events` has `meta_json`, no typed delta columns | `R/db-schema-create.R:194-208` | PASS — DDL confirms |
| Direct writer computes deltas, stores in `meta_json`, inserts schema cols | `R/ledger-writer.R:67-83, 104-128` | PASS (range slightly broad — see Patch 1) |
| Persistent replay parses `meta_json` | `R/derived-state.R:12-31, 56-73` | PASS (parse at 29/70 — see Patch 2) |
| Immediate run read-back also parses `meta_json` per event | `R/backtest-runner.R:1335-1391` | PASS — `for(i...) jsonlite::fromJSON(events_df$meta_json[[i]])` extracting `cash_delta`/`position_delta` |
| In-memory sweep path is LDG-2410-style typed: delta columns + typed attrs | `R/sweep.R:710-723, 812-814` | PASS — `cash_delta`/`position_delta` columns (710-723); `attr(out,"ledgr_event_cash_delta")` etc. (812-814) |

Additional checklist results:

- **v2 ↔ synthesis consistency:** consistent across all directions, gates, and sequencing.
- **Binds v2 §2/§4/§5 without reopening design:** confirmed; no new directions or obligations introduced.
- **Open-questions vs future-obligations split:** matches v2 §6 exactly (spec-cut: `ctx$window()` column naming, full-long opt-in surface; future obligations: multi-feature/tensor windows, export/training APIs, PIT interchange, broader typed metadata).
- **Sequencing:** correct (v0.1.8.6 = 5.0 → 5.1 + separate remeasure + instrument×feature sweep before width/benchmark claims; 5.6 conditional on accepted storage work; 5.4 → v0.1.9 only if target-risk/portfolio-risk needs covariance windows).
- **Horizon draft:** follows the cycle pattern (5 themes within the 4–7 band, "Promoted roadmap hooks", "Immediate cross-cycle obligations", closing non-authorization disclaimer).
- **No implementation code** beyond design-level bindings; 5.6's column/migration steps are design decisions already present in v2, not generated code.
- **Cycle stage note (§9)** is accurate: maintainer-decision stage correctly skipped (no escalated product-binary choice); final review (this note) was the pending stage.

One substantive verification worth surfacing: the immediate run read-back
(`R/backtest-runner.R:1387-1391`) parses `meta_json` **per event row**, exactly
like the resume/reopen replay. This strengthens the 5.6 rationale — typed
persistent columns would simplify the *immediate* read-back too, not only
resume/reopen — and is consistent with how the synthesis frames it.
