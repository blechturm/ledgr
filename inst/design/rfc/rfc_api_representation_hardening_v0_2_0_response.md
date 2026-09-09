# RFC Response: Public API And Representation-Boundary Hardening

**Status:** Response v1 to Seed v1, accepted by the maintainer on 2026-09-09
with the four decisions in Section 10. Not a synthesis; nothing is implemented.
**Date:** 2026-09-09
**Seed:** `rfc_api_representation_hardening_v0_2_0_seed.md` (Codex, 2026-09-09)
**Response author:** Claude
**Baseline:** `v0.1.9.8` at `c78ab4fc69c32163a4ea96170771ccb3a9ee4cdc`, package `0.1.9.7`
**Evidence:** `dev/spikes/api-representation-hardening/probe.R` and its
`probe_findings.md`, executed 2026-09-09 on R 4.5.2 against the baseline via
`pkgload::load_all()`. Statements are marked *executed* (the probe ran it),
*contract* (`contracts.md` or an accepted synthesis), *source* (read, not run),
or *proposal*.

---

## 1. Overall Assessment And Version Direction

The seed's readiness condition is met and its question is answered: the
documented public workflow already provides the access needed for safe
selection and promotion. Every supported row operation, the saved-sweep
round trip, and promotion from a reopened subset carried a nondefault risk
chain through to a committed run whose final equity equals the sweep row to
the last printed digit (*executed*, findings 1-4). No new public export or
entry point is needed; the proposed `ledgr_target_values()` is rejected.

The seed is right about direction and wrong about center of gravity. Its
workflow, tiers, no-registry stance, and moves-before-extraction order are
accepted. But the probe found four defects next to the path that the seed
treats as background, none of them in `ledgr_run_fold()`: the research-workflow
vignette's own selection step drops sweep lineage, the fills reader validates
after it returns, the fills return type depends on data rather than arguments,
and reversal rows double the fee. The recommended packet is the seed's
Alternative B reordered: the four evidenced corrections first, then the
coordinator extraction in four risk-ordered stages, each behind a named test.

**Version direction (confirmed):** the next release jumps from `0.1.9.7` to
`v0.2.0`. Historical RFC filenames keep their windows; `DESCRIPTION`, schema
versions, and hash-rule versions are not bumped by this cycle. Version
strings change in the spec packet, not here.

## 2. Evidence Summary

| Seed claim or lead | Executed result | Disposition |
| --- | --- | --- |
| Risk provenance lost on subsetting (audit T-3, horizon 2026-09-04) | `filter()`, `arrange()`, `slice_head()`, base `[`, and save/reopen all kept the attribute and a promotable identity; even an attribute-stripped data frame promoted | Latent, not observed; two-line restore fix plus one assertion |
| Target extraction needs a reader | `c(target)` is a plain named numeric; `target[["AAA"]]` works on the classed object; `unclass()` keeps `origin` | Reject the accessor; fix the example |
| Threshold validation after empty shortcut | Bad thresholds return an empty tibble on a no-fill run; `Inf` raises an untyped base error; `-1`, `0`, `1.5` accepted | Confirmed; validate first, typed error |
| Threshold-driven return-type change | `stream_threshold = 0` with `lazy = FALSE` returns a cursor; `lazy = TRUE` on a no-fill run returns a tibble | Confirmed; return type must follow arguments |
| Cursor ownership undocumented | No S3 methods, no exported consumer, no vignette; tests call `DBI::dbFetch(cursor$res)` | Confirmed; cursor removed (decided 2026-09-09) |
| Reversal fee duplication (T-1) | 7 events, 13 rows, derived fee 13.045 vs source 6.775; six events carry the full fee twice | Confirmed; pro rata allocation (decided 2026-09-09) |
| Teach handle ownership and reopening | `close(bt)` then `ledgr_run_fills()` and `summary()` reopen by path and succeed | Contract: handle is a locator (decided 2026-09-09) |
| `ledgr_results()` delegates to `as_tibble()` | Same table wrapped in `ledgr_result_fills` plus a `ledgr_result_type` attribute | Contract satisfied |
| Not in the seed: review helper drops lineage | `ledgr_sweep_review()$ranked` is a plain tibble; its candidate has zero `sweep_meta` fields and promotes with `source_sweep$sweep_id = NULL` | New; highest-value teaching fix |
| Not in the seed: run risk identity reader | `ledgr_run_info()` has no risk field; identity sits in `config_json` and `bt$config$risk_chain` | Amend the inspection tier |

Still *source* only, deferring to the audit on severity: T-2 no-lookahead, RNG
temporary names, wide-projection collisions, interrupted persistence, T-4 cleanup.

## 3. Dispositions By Seed Section

| Seed section | Disposition | Reason |
| --- | --- | --- |
| 1-2 Problem, inputs, scope | Accept, amend | Add `spike_protocol.md` size budgets as binding on the packet |
| 3 API shape: workflow, tiers, retain table | Accept | Tiers are documentation placement; no runtime mode |
| 3 `ledgr_run_fills` row | Amend | Validate before the count query; cursor and the `lazy` and `stream_threshold` arguments removed (Section 7) |
| 3 `ledgr_target_values(x)` | Reject | Base R suffices; fix the vignette example (Section 4) |
| 3 promotion readers | Accept, amend | Name where a committed run's risk identity is read (Section 4) |
| 4 Usability contract | Accept, amend | Add the review-helper lineage fix; state the close contract once decided |
| 5 Ownership table | Amend | Split `R/backtest.R`; extract `ledgr_run_fold()` in four risk-ordered stages (Section 5) |
| 6 Invariant obligations | Accept, with executed evidence for T-1, T-3, thresholds | Section 6 |
| 7 Compatibility | Amend | Pre-release cost model (Section 7) |
| 7 Availability boundary | Accept | Section 8 |
| 8 Alternative B recommended | Accept, reordered | Corrections first, staged extraction after (Section 9) |
| 9 Readiness condition | Satisfied by this probe | Section 2 |

## 4. API And Teaching (Seed Question 1)

**Does the first path reduce user decisions?** Yes, and it already exists.
The quickstart and research-workflow sequence (snapshot, experiment, run,
sweep, review, candidate, promote, reopen) needed no field access beyond
documented columns (*executed*). What the seed should remove is a trap, not an
accessor: `ledgr_sweep_review()` builds `ranked` from `tibble::as_tibble(sweep)`
(`R/sweep-review.R:34`, *source*), so the vignette's `ledgr_candidate(ranked, 1)`
warns that sweep metadata is unavailable and the promoted run records no
source sweep (*executed*, finding 6). The helper meant to keep the ranking
rule visible discards the lineage it should protect.

*Proposal:* `ledgr_sweep_review()` returns `ranked` and `top` as
`ledgr_sweep_results` views restored from the input, exactly as `filter()`
already does, and the promotion-context test asserts `source_sweep$sweep_id`
for a candidate taken from `review$ranked`. This is a correctness fix in an
existing helper, not new surface; the vignette code stays as it is.

**Is the target reader needed?** No. On a `ledgr_target` built by the vignette
pipeline, `c(target)` returns a plain named numeric with no other attributes,
`target[["DEMO_01"]]` works on the classed object, `unclass()` keeps the
`origin` attribute, and `as.numeric()` drops names (*executed*, finding 8).
The teaching lead in `strategy-authoring-tools.qmd` uses `unclass(target)[[id]]`
where `target[[id]]` already works. *Proposal:* replace that line, name
`c(target)` as the plain-vector idiom there and on the `ledgr_target()` help
page. A getter for what `c()` already does fails the naming bar for exports.

**Where is a committed run's risk identity read?** `ledgr_run_info()` returns
38 fields and none of them is risk-related; the identity sits in `config_json`
and `bt$config$risk_chain$risk_chain_hash`, and for promoted runs in
`ledgr_promotion_context()` (*executed*, findings 4-5). *Proposal:* add
`risk_chain_hash` beside `config_hash` in the `ledgr_run_info()` row, a "change".

**Errors and print output.** Accept, with one executed counterexample:
`stream_threshold = Inf` fails with the base message "missing value where
TRUE/FALSE needed" after a coercion warning, naming no argument or remedy.

## 5. Module Boundaries (Seed Question 2)

**Do the module owners remove concrete coupling?** Not the coupling the
evidence found. The four executed defects live in `R/sweep-review.R`,
`R/backtest.R` (fills reader and fill projection), and the restore list in
`R/sweep-retention.R`; none touches `ledgr_run_fold()` or
`ledgr_execute_fold()` (`R/fold-engine.R:159`). The coordinator is therefore
sequenced on its own evidence, read from the function (*source*):

| Block of `ledgr_run_fold()` (`R/backtest-runner.R`) | Lines | Side effects |
| --- | --- | --- |
| Config and control normalization | 574-625 | clock read (598), `set.seed()` (623) |
| Store open, schema, `on.exit` checkpoint and disconnect | 626-640 | connection lifetime |
| Registration, resume detection, DONE shortcut, handler | 641-773 | writes `runs` |
| Sealed-snapshot guard, TEMP VIEWs, run-row snapshot update | 774-876 | session views, writes `runs` (875) |
| Calendar, resume tail cleanup, opening-position events | 877-982 | deletes tail rows, writes ledger (973) |
| Preparation: control, `RUNNING` status (994), state, bars cache, feature matrix, projection, risk plan, execution spec | 983-1274 | status write, feature cache (1193) |
| Fold call with failure recording and partial-run return | 1275-1305 | status writes |
| Finalization: event replay, second lot pass, equity curve, DONE, telemetry | 1306-1497 | writes tables |

The body has 113 top-level locals; 50 cross a block boundary and 22 assigned
before the fold call are read in finalization. Three hazards fix the order:
the `on.exit` at line 629 is function-scoped, so a helper that opens the store
must return a closer; the resume block calls the handler's `abort_run`, so
handler construction precedes it; finalization replays events through a second
lot pass (line 1396), and its owner inherits that reconciliation unchanged.
No block is pure. Stage numbers below are extraction and commit order only;
runtime call order, status writes, and `set.seed()` placement do not move.

Tests already pin resume (`test-runner.R:110`, `146`, `168`), clean-versus-
resumed output equality (`test-acceptance-v0.1.0.R:291`), and the FAILED
status write; none injects a failure through the coordinator's write sequence.
*Accepted 2026-09-09:* four stages, one commit each under the 500-line budget.

1. **Lowest-effect blocks, existing suite as the net:** the preparation block
   with the `RUNNING` write left in the coordinator, and the config and
   control normalization with `set.seed()` left in place; delete the trivial
   wrappers `ledgr_backtest_run()` and `ledgr_backtest_run_internal()`.
2. **Snapshot guard,** already delimited and covered by the snapshot tests;
   it returns the stored hash and the calendar.
3. **Finalization,** with clean-versus-resumed equality as the net.
4. **Registration, resume, and tail cleanup,** only after one new test that
   fails the handler's flush on the nth call, asserts FAILED status and no
   rows past the last checkpoint, then resumes and asserts equality with a
   clean run.

**Mechanical moves accepted:** split `R/backtest.R` (2,466 lines: result
contract, fills reader, fill projection, config construction, handle
lifecycle) along the seed's results / fills / handle lines. `R/sweep.R` can
wait; `R/fold-engine.R` stays untouched. Helpers take explicit inputs and
return records; no shared mutable environment, agreeing with the seed.

## 6. Correctness And Test Protection (Seed Question 3)

**Can independent checks catch fee, causality, or identity defects that parity
would preserve?** Yes for fees and identity; the probe did so with three
assertions and no framework. Packet rule: each correction ships with the one
assertion that fails on the baseline, written before the fix; mechanical moves
are checked by the existing suite, never by equality of the number under repair.

- **Reversal fees (T-1).** Reproduced (*executed*, finding 12): for each
  reversal event both the `CLOSE` and `OPEN` rows carry the whole event fee,
  so the fills table sums to 13.045 against a ledger total of 6.775. The
  projection at `R/backtest.R:1413-1426` (*source*) passes `fee` to both row
  buffers. Owner: fill projection. Conservation assertion: for each
  `event_seq`, derived fees sum to the event fee. Allocation is pro rata by
  quantity (decided, Section 10): direction-neutral, and it leaves
  `realized_pnl`, lot cost basis, and trade metrics untouched, as the seed
  requires.
- **Row-operation identity (T-3).** Not a defect under any supported
  operation (*executed*, findings 2-3): dplyr and vctrs copy the attributes
  that `ledgr_sweep_results_restore()` omits (`R/sweep-retention.R:1245-1268`,
  *source*), and `ledgr_candidate_risk_identity()` (`R/sweep.R:815`) rebuilds
  the chain from row provenance regardless. Add `risk_chain_hash` and
  `risk_plan_json` to the restore list and assert them after base `[`.
- **Threshold validation.** Confirmed (*executed*, finding 9). Owner: fills
  reader. Assertions: a bad threshold errors with `ledgr_invalid_args` on an
  empty run; `Inf` errors with that class; `-1` and `1.5` are rejected; `0`
  streams any positive count as the seed proposes.
- **No-lookahead (T-2), RNG names, wide collisions, cleanup (T-4), doc locks
  (T-5).** Accept the seed's obligations as written; the probe did not run
  them. The wide-projection fix alone touches saved-artifact shape; it goes last.

## 7. Compatibility, Streaming, And Saved Artifacts (Seed Question 4)

**Are compatibility costs understandable from public examples?** The seed
prices compatibility as if consumers existed; ledgr is pre-release with none.
*Proposal:* the packet's retain/add/change/remove table is the only
compatibility record, a change needs a before/after example rather than a
migration guarantee, and the additive saved-sweep migration is the precedent.

**Streaming fills.** Three executed facts decide this (findings 9-11): the
cursor has no exported consumer and no methods, the return type of
`ledgr_run_fills()` depends on data size and on whether the run has fills, and
validation runs after the empty shortcut. The naming synthesis retained the
cursor contract without a consumer. Two forms were offered: keep the cursor
with `close()` and `print()` methods, a documented consumer, and a threshold
that errors instead of switching type; or remove the cursor and
`lazy` and `stream_threshold` arguments and keep the eager tibble. *Decided
2026-09-09:* remove; `ledgr_run_fills(bt)` keeps only `bt`.
Empty results stay full-schema tibbles; `nrow()` distinguishes them.

**Handle ownership.** `close(bt)` releases a connection; every later read
reopens a temporary one by path (*executed*, finding 11; `R/backtest.R:627-660`,
*source*). *Decided 2026-09-09:* that is the contract. A run handle is a
durable locator, `close()` only releases a held connection, and the vignette's
`close()` then `ledgr_run_open()` sequence teaches a new session rather than
a closed handle. The removed cursor was the only reader that needed the handle.

**Saved artifacts.** Save, reopen, subset, candidate, promote, and reopen kept
identity intact (*executed*, findings 2-4); teach the round trip, do not harden it.

## 8. Availability Integration And Sequencing (Seed Question 5)

**Can availability land without undoing these boundaries?** Yes, provided the
boundaries stay where the accepted synthesis put them. Its members-union-held
axis, two session envelopes, valuation clock, and `ctx$vec` planes enter
through `ledgr_execution_spec()`, the pulse context, `ledgr_execute_fold()`,
and the result views (synthesis Sections 5-7, 9); its identity changes enter
`snapshot_hash` and `experiment_hash` by presence (Section 9.1). None of that
is a coordinator phase, so the Section 5 staging is sequenced on its own
tests. The seed's sentence that storage representation and imputation are not
prerequisites for these moves is accepted.

Two corrections from Section 6 touch what availability will touch and must
land first: the fee-allocation rule (availability's fill diagnostics reuse the
fill projection) and the fills-reader return-type rule (the `availability`
result view will be read the same way). The restore-list fix must land before
availability adds fields to sweep identity, or the new fields inherit the same
omission. Accepted from the seed unchanged: no dense-assumption wrapper or
validator, legacy requirements qualified by activation, no future identifiers
or execution evidence in strategy context through a new accessor.

## 9. Bounded Scope And Dependency Order

*Proposal.* One packet, five ordered slices, each under the spike protocol's
500-line correction budget.

1. **Corrections with their failing assertions:** review-helper lineage; fills
   reader validation order and cursor removal; pro rata reversal fee
   allocation; restore-list risk fields. One commit each, assertion first.
2. **Teaching:** `ledgr_target()` example and idiom; run-info risk field; the
   handle-as-locator sentence; the horizon's stale-example repairs checked
   against the current API; tier placement in `_pkgdown.yml`.
3. **Mechanical moves:** split `R/backtest.R`; coordinator stages 1 and 2.
4. **Tests carried to the packet:** the failure-injection test from Section 5;
   T-2 negative witness; RNG temporary names; wide-projection escaping; cleanup
   and warning classes; selective doc-lock replacement.
5. **Coordinator stages 3 and 4,** after slice 4's failure-injection test.

Availability implementation follows slice 5. Out of scope, agreeing with the
seed: new engine, broad renaming, package split, availability policy redesign,
storage-shape selection, imputation or ML, OMS, financing, corporate actions,
CI redesign, export-count targets, registries, generic test framework, coverage cuts.

## 10. Decisions And Remaining Items

Maintainer decisions recorded 2026-09-09 after a walkthrough of the four
judgment questions:

1. **Reversal fee allocation:** pro rata by quantity across the split rows.
2. **Fills cursor:** remove it with the `lazy` and `stream_threshold`
   arguments; `ledgr_run_fills(bt)` returns the eager tibble only.
3. **Reads after `close(bt)`:** contract. A run handle is a durable locator;
   `close()` only releases a held connection. Teach it; drop the reopen
   ceremony from the vignette.
4. **`ledgr_run_fold()`:** the four-stage extraction in Section 5, replacing
   the response's first-draft deferral.

Resolvable in synthesis: whether `top` gets its class back as well as
`ranked`; the `ledgr_run_info()` risk field name and whether `risk_plan_json`
joins it; one commit or two for the review-helper and restore-list fixes.

Routed elsewhere: the engine accepted negative targets in the reversal run
while the shorting and leverage contract is still a gate without seed
(*executed*, finding 12); a horizon observation for that seed, not this packet.

## Revision History

- **2026-09-09** -- Response v1 by Claude after executing the ten-case probe
  required by the seed's Section 9 and `spike_protocol.md` Section 1.
- **2026-09-09** -- Maintainer walkthrough: decisions 1-3 accepted as
  recommended; question 4's deferral replaced by the four-stage coordinator
  extraction after a block and test census of `ledgr_run_fold()` (1, 5, 9, 10).
- **2026-09-09** -- Response review (Codex) patched in place: effect-aware
  phase map, no block called pure, stages are extraction order only (M-1);
  `lazy` removed with the cursor (L-1); "no new export or entry point" (L-2).
