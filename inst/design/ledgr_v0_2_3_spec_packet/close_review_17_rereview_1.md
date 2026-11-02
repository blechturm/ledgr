# Focused Re-Review 1: Workstream 17 (Cut 7)

- Mode: Type 1, focused independent re-review, Claude Opus, 2026-11-02
- Range: `b7a45312..01fc8fe9` on `codex/cut7-ws5`
- Against: `close_review_17.md` findings F1-F6 and its non-blocking notes
- Tickets: LDG-3185, LDG-3186
- Verdict: **CHANGES_REQUIRED** (one new finding, R1; F1-F6 closed)

No Type 2 concern. The correction stays inside D5 and the accepted
cursor/checkpoint decision. It adds no schema change, no migration or
compatibility reader, and no WS18 sizing scope. The stored payload bytes are
unchanged, because `canonical_json()` is the cached wrapper of
`ledgr_canonical_json_encode()`, so `ledgr_strategy_state_rule_version`
correctly stays at 1.

## Per-Finding Status

| Finding | Status | Evidence |
| --- | --- | --- |
| F1 merge-to-replacement | **Closed** | LTB-0533 now gives `regime` a non-default value (`"risk_off"`) through a raw replacement and then omits it in a helper patch. `D5_merge_to_replacement` and `D5_metadata_to_state` are registered in `mutations.R` and `ownership_matrix.csv`, and both are detected here. The metadata mutation is detected through the undeclared-field refusal. The new `expect_false("intent_reason" %in% names(...))` line is vacuous, because the decoder returns only declared fields; this is record-only. |
| F2 narrowed-axis resume | **Closed** | `ledgr_strategy_state_restore()` returns the payload's own decoded axis, and P1 performs the single alignment. That is exact, because every axis change forces a payload. Reviewer probe: 3-ID to 2-ID membership, state changed on pulse 1, 15 pulses, resumed one pulse at a time (16 invocations). The `state_json` rows are identical to the uninterrupted run (payload pattern `100100000000000` in both), and every `ctx$state` read is identical per pulse. LTB-0534 now carries a byte-parity witness. A reviewer mutation that restores the old align-to-`resume_axis` code is detected by LTB-0534. |
| F3 detectors | **Closed** | LTB-0536 changes value only on pulse 1 and asserts the exact payload/marker vector, so `D5_axis_checkpoint` is detected. LTB-0534 now interrupts twice, so the resume follows a marker; `D5_marker_resume` is detected. LTB-0537 alternates parity-driven targets and compares retained trades between same-declaration candidates; `D5_candidate_leak` is detected through the trades oracle, not by an incidental error (`candidate_id` is in scope at `R/sweep.R:1640`). LTB-0532 loops over all six literal reserved names; a reviewer mutation dropping `intent_reason`/`reset_state` is detected. LCL-0528 is narrowed to test runs. |
| F4 classed/attributed values | **Closed** | `validate_value` refuses `is.object()` and any non-`names` attribute. The decoder refuses a cast that produces `NA` at a non-missing position. Probes refuse POSIXct, Date, 1x1 matrix, factor, difftime, a `comment` attribute, a custom class and a named portfolio scalar. Plain `ctx$close`, `ctx$hold()` and `ctx$flat()` carry only `names`, so storing them still works (probe ran). Reviewer mutations that remove each refusal are detected by LTB-0532. |
| F5 hot path | **Closed, with note N1** | Traced over 20 pulses at 500 IDs x 4 fields: declaration validation is 7 calls and `canonical_json` 51 calls per run, constant across the unchanged, raw-identical, reset, patch and NA-reset cases. No per-pulse validation or cached encode remains. The JSON-cache delta is 3 per run (setup only). `encode` is called once per changed pulse through the uncached encoder, with no re-validation (`ledgr_canonical_json_encode` = 3 + 20). The NA reset uses the prepared scalar. The wide 500-ID/4-field cells reproduce: 100/0 payloads, 2,568,900 bytes. The closeout's account of the cache owners is accurate. |
| F6 census | **Closed, with note N3** | `ledgr_strategy_state_rule_version` is in `fingerprint_names`. Check mode gives `LEDGR_CODEBASE_CENSUS_OK ... helpers=2002 conditions=2479`, which matches the committed summary. |

Non-blocking notes from the original review: the typed-`NA` wording is in
`contracts.md` and `ledgr_strategy_result.Rd`. The view copy and the
availability-state migration are both noted in the closeout and the
benchmark README; N4 corrects the view-copy rationale.

## Registered D5 Mutations

All seven apply once and are detected. The result matches the committed
`evidence/current/mutations.csv` row for row:

| Mutation | Detected by |
| --- | --- |
| D5_state_declaration | LTB-0532, 0533, 0534, 0538 |
| D5_state_checkpoint | LTB-0534, 0536 |
| D5_merge_to_replacement | LTB-0533 |
| D5_metadata_to_state | LTB-0533 |
| D5_axis_checkpoint | LTB-0536 |
| D5_marker_resume | LTB-0534 |
| D5_candidate_leak | LTB-0537 |

## Finding

### R1 (medium): ID alignment of a reordered asset update has no detector, and the correction made it a conditional branch

The F5.2 correction changed `ledgr_strategy_state_validate_value()`
(`R/strategy-state.R:255-264`) from an unconditional `value <- value[axis]`
to `if (!identical(value_names, axis)) value <- value[index]`. Reviewer
mutation `RR_identity_skip_reorder` replaces that line with `value <- value`.
A strategy that returns a fully named asset vector in a different order from
the decision axis then keeps positional values, so values land on the wrong
IDs, silently.

- With filter `strategy-state-ws17`, the mutation **survives every block**.
- With the broad filter `state|strategy|availability|corporate|pulse|sweep|walk`,
  it **survives** (`review2.csv`: applied TRUE, detected FALSE). The three
  blocks that failed in that run (`direct persisted rows match the reviewed
  baseline`, `materialized sessions run in a fresh process without loading
  qlcal`, `[LTB-0036] public run posts one gross dividend`) also fail on the
  unmutated tree under the same `test_local(load_package = 'none')` call. They
  do not use permuted state updates. They are not detections, and this review
  did not investigate their cause further.

The gap is older than the correction, but the correction widened it.
Previously, only LTB-0533's run path passed a permuted vector
(`peak = c(BBB = 3, AAA = 4)` against the sorted universe `AAA, BBB`), and
the result was never asserted. The correction removed even that exercise.
Every remaining `apply_values` assertion uses names already in axis order
(`test-strategy-state-ws17.R:274-279`). The closeout and LCL-0523 still
claim "broadcast/alignment" coverage, which does not hold for this path.

Smallest fix (test plus registration; no product change):

1. In LTB-0533, assert one reordered update, for example
   `ledgr:::ledgr_strategy_state_apply_values(previous, list(peak = c(AAA = 1, BBB = 2)), declaration, c("BBB", "AAA"), patch = TRUE)$peak`
   is identical to `c(BBB = 2, AAA = 1)`.
2. Register the reviewer edit as `D5_update_alignment` in
   `dev/bench/v0_2_3_ws5/mutations.R` and `ownership_matrix.csv` (old
   `if (!identical(value_names, axis)) value <- value[index]`, new
   `value <- value`). Add it to `check.R`'s expected families, then rerun and
   update `evidence/current/mutations.csv`.

## Notes (record-only)

- N1, residual F5.2 cost. The identity path still runs `match()`,
  `anyDuplicated()`, `anyNA()` and `nzchar()` before testing `identical()`.
  At 500 IDs it costs about 18.5 us per field per pulse, against about 1.5 us
  for an identity-first sketch (20,000 iterations; permuted path about
  20 us). This satisfies "one-match alignment". Once lengths are equal and
  every axis ID matches, the three name checks are implied, so the identity
  test could come first at no semantic cost. Owner's choice.
- N2, evidence provenance. The committed `evidence/current/meta.csv` says
  `source_state = "WS17 close-review correction working tree"`, but
  `run_record.R` still writes `"WS17 candidate working tree before
  implementation commit"` and `source_base = "d566de6e"`. The committed file
  was not produced by the committed script. The record counts reproduce
  exactly; wall times differ under concurrent load and are descriptive.
- N3, census line references. Check mode rewrites `helpers.csv` and
  `test_only_seams.csv` with `test-execution-spec.R` call-site line numbers
  shifted by one, because the census was regenerated before that file gained
  `strategy_state_default_scalars`. It also rewrites the `metadata.csv`
  `source_commit` label. Counts and findings are unchanged. Regenerate it
  alongside R1.
- N4, view-copy rationale. The closeout and README say the copy keeps the
  view "frozen against later fold mutation". R's copy-on-modify already
  guarantees that; the copy defends only against by-reference writes into
  `ctx$state`. The copy is fine; the reason given for it is not.

## Gates Run

- Focused tests `strategy-state-ws17|execution-spec|availability-state`: all
  pass.
- `dev/bench/v0_2_3_ws5/check.R`: `WS5_INVENTORY_OK`.
- `tools/check-codebase-contracts.R --mode=check`: `LEDGR_CODEBASE_CENSUS_OK`
  (the rewritten files were reverted; see N3).
- `run_record.R`: all six rows' counts and bytes reproduce.
- The full suite and R CMD check were not re-run. The closeout's build/check
  claim is recorded, not reproduced.

## Commands

```
Rscript dev/bench/v0_2_2_indicator_history/scripts/mutate.R dev/bench/v0_2_3_ws5/mutations.R D5_state_declaration,D5_state_checkpoint,D5_merge_to_replacement,D5_metadata_to_state,D5_axis_checkpoint,D5_marker_resume,D5_candidate_leak <out> .
Rscript dev/bench/v0_2_2_indicator_history/scripts/mutate.R <tmp>/review_mutations.R all <out> .    # F2 revert, F4 x2, reserved, reorder skip
Rscript dev/bench/v0_2_2_indicator_history/scripts/mutate.R <tmp>/review_mutations2.R all <out> .   # reorder skip, broad filter
Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_local('.', filter='strategy-state-ws17|execution-spec|availability-state', reporter='summary', load_package='none')"
Rscript dev/bench/v0_2_3_ws5/check.R
Rscript tools/check-codebase-contracts.R --mode=check
Rscript dev/bench/v0_2_3_strategy_state/run_record.R <tmp>/record
Rscript <tmp>/probe_rr1.R   # call counts, cache delta, micro costs
Rscript <tmp>/probe_rr2.R   # narrowed-axis resume parity, adversarial values
Rscript <tmp>/probe_rr3.R   # validate_value identity vs permuted cost
Rscript <tmp>/probe_rr4.R   # attributes of ctx vectors stored as state
```

`load_all` rewrites `R/cpp11.R`/`src/cpp11.cpp`, and check mode rewrites the
census. Both were reverted, so the tree differs from `01fc8fe9` only by this
file.
