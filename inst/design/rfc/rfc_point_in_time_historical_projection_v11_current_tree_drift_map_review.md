# V11 Current-Tree Drift Map Type 1 Review

Role: record; Type 1 review of the history-wave H0 audit reconciliation.
Status: working; initial and focused `PASS_AFTER_PATCHES` findings are
incorporated in the H0 record, pending maintainer handling.
Authority: non-binding review record. It corrects audit facts and routing only;
it does not decide history semantics or amend the history-wave register.

## Review target and outcome

The review examined H0 commit `fa764a9cf50cc27458e139d4fa2e28d8a175a625`
against the post-Cut 15 tree, accepted v11, the current macro plan, RFC
pipeline, migration reconciliation, UX brief, contracts, and implementation.
Outcome: `PASS_AFTER_PATCHES`. The required patches below are record-only;
none authorizes v12 behavior.

## Findings and incorporated patches

| ID | Finding | Incorporated correction |
| --- | --- | --- |
| R1 | The H0 metadata used non-governance Role/Status values. | The map and this review use the valid `record` role and `working` status. |
| R2 | Row 4.2 incorrectly said narrowing had no live owner. | It now cites the `instrument-specific-session-axis` RFC-pipeline obligation, WS3's narrowing bullet, and the horizon migration reconciliation. Q2 requires v12 to reject, defer, or bind narrowing and reconcile both live owners. |
| R3 | Row 3.3 combined a retained shared-axis rule with superseded start/padding rules. | Rows 3.3a/b now retain columns on a shared prepared/session axis rather than per-asset last-N observations, while Sessions A/B supersede leading padding and the no-pre-range boundary. |
| R4 | Row 3.4 incorrectly superseded the one-series call shape and omitted held-nonmember/past-membership clauses. | Rows 3.4a-c retain one numeric bar field or feature per call, rewrite only the classed container/evidence shape, and route the default row set plus included/excluded representation to H2/stage 3. The UX brief's proposed `instruments = "admissible"` is not treated as accepted. |
| R5 | The shared-fold statement incorrectly included pulse inspection. | Row 6.3 and the anchor table now distinguish the run/sweep/walk-forward fold from `ledgr_pulse_snapshot()`, a separate dense one-pulse SQL helper without availability-aware normalization. Inspection parity is explicit H2 Type 2 work. |
| R6 | The identity row assumed rule 3 would remain the history rule and omitted temporary hydration seams. | Rule 3 is stated only as current while D3-F5 owns any history identity advance. The map inventories `hydration_start_utc`, `walk_forward_folds.hydration_start_utc`, `ledgr_unsupported_hydration_start`, `ledgr_precomputed_hydration_mismatch`, and `warmup_range$start` for retirement or replacement under Sessions A/B. |
| R7 | Q1 lacked the controlling assumed-basis amendment. | Q1 cites Cut 12's 2026-10-11 amendment and LDG-3013: an omitted basis remains `NULL` in identity but always reaches assumed `split_adjusted` economics/disclosure on the availability path. The carry-barrier answer stays open. |
| R8 | Q3 described condition vocabulary without the current missing-clock behavior. | Q3 now records that ingest accepts both event clocks absent, execution maps them to `NA` and never posts the row, and `ledgr_invalid_corporate_action_event` covers a non-finite entitlement recount delta. The product answer stays open. |
| R9 | Row 2.6 conflated ledgr liquidity ownership with the adapter transformation. | The ledgr-side zero-volume/liquidity claim is retained; the adapter's independent LFB-027 removal of vendor-carried zero-volume rows is recorded separately. |
| R10 | Type 2 and drafting ownership was incomplete. | Q1-Q3 and availability-aware pulse inspection are explicit H2 Type 2 work. Shared-axis and row-set/held-nonmember representation go to H2/stage 3; identity stays with D3-F5. |
| R11 | Register item D3-F5 cites deleted `R/feature-cache.R:82-94`. | The map flags the stale anchor and identifies current `ledgr_active_feature_fingerprint()` and `ledgr_feature_def_fingerprint()` definitions in `R/features-engine.R`. The register is intentionally unchanged. |

## Focused re-review disposition

The focused Opus/high re-review confirmed R1-R11 and returned
`PASS_AFTER_PATCHES` for four remaining record omissions. This final pass
incorporates them without changing the decision register or selecting
semantics.

| ID | Focused finding | Incorporated correction |
| --- | --- | --- |
| N1 | Row 8.3 over-superseded causal, empty-shape, scalar-parity, and empty-inspection requirements; row 3.8 dropped scalar reads. | Rows 8.3a/b now retain reads-within-axis, empty shape, scalar/frame/matrix parity, and empty-long-table inspection while superseding only early padding and `ctx$window()`-specific parity. Row 3.8 keeps scalar reads in the equal-cutoff agreement. |
| N2 | Row 3.3b omitted the no-second-warm-up, `0 x lookback`, and declared-hydration carry-seed clauses. | Row 3.3b explicitly disposes of each old mechanism under Sessions A/B/0 and routes the shorter-lookback first-column carry-seed question to H2/stage 3. |
| N3 | The narrowing route omitted observations inside inactive intervals. | Row 4.2 and Q2 require any bind option to define cutoff resolution, common-axis alignment, and inactive-interval observation treatment; no request window may choose silently. |
| N4 | `hydration_start_utc fold field/formal` was ambiguous. | The seam is named precisely as the walk-forward fold-window field and constructor formal. |

## Necessity judgment

Only the drift map and this concise review record are needed. No schema,
validator, manifest, register edit, or implementation change is justified by
these factual corrections. The unresolved questions remain for H2 and stage 3.
