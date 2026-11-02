# Close Review: Workstream 17 (Cut 7)

- Mode: Type 1, independent clean-context Claude Opus, 2026-11-02
- Range: `d566de6e..b7a45312` on `codex/cut7-ws5`
- Tickets: LDG-3185, LDG-3186
- Verdict: **CHANGES_REQUIRED**

No Type 2 concern. The accepted D5 design and the cursor/checkpoint
decision can be implemented as written. Every finding below is a product,
detector or evidence correction that stays inside the accepted decisions.

## Necessity And Direction

The workstream is necessary: it replaces the untyped `state_prev` and
every-pulse JSON with D5's declared typed state, as Section 4 item 4 and the
cut's D5 row require. It adds no manifest, registry or second execution path.
The state codec, view and checkpoint helpers live in one file
(`R/strategy-state.R`) and are called from the existing fold stages. The
direction is right. The problems are in the detectors and in a few hot-path
details.

## What Was Checked (Clean)

- Declaration grammar (`R/strategy-state.R:14-84`). The four atomic types and
  typed `NA` defaults keep their type. Every one of these is refused with
  `ledgr_invalid_strategy_state`: NaN/Inf, NULL, Date, nested list, unnamed
  list, duplicates across scopes, and the reserved names `targets`,
  `state_update` and `reset_state`. A named scalar default normalizes to the
  same identity as an unnamed one. Equal declarations give equal config
  hashes, and a changed default or type changes the hash (LTB-0532 runs).
- Codec fidelity. The encoder and decoder round-trip these values exactly:
  `0.1 + 0.2`, `1/3`, `5e-324`, `.Machine$integer.max`, the strings
  `"NA"`/`"null"`/`""` as both values and asset IDs, an empty axis, and a
  non-alphabetical axis. A stored config with whole-number double defaults
  (`2.0`) reopens through `validate_ledgr_config()`.
- Decoder refusals. A duplicated field, an omitted field, a duplicate axis
  ID, a wrong-length asset mask, an old `rule_version` and the marker itself
  are all refused with the state class.
- Identity and format. `ledgr_strategy_state_rule_version` enters the
  store-format fingerprint automatically and with no condition
  (`R/store-gate.R:3`). Config validation refuses a missing `strategy_state`.
  The table schema is unchanged, nothing consumes schema 125, there is no
  migration or alias, and no WS18 sizing scope is touched. No `state_prev`
  reference remains in `R/`, `man/` or the vignettes except the explicit
  refusal in pulse inspection (`R/pulse-snapshot.R:126-133`).
- Unchanged pulses write the marker without encoding. The memory sink never
  encodes. Interrupting on the final pulse and then resuming replays nothing
  (2 rows, final `n = 2`). Walk-forward test runs restart from the defaults.
- The registered D5 mutations reproduce here: `D5_state_declaration` fails
  LTB-0532/0533/0534/0538 and `D5_state_checkpoint` fails LTB-0534. Both apply
  once and are detected.
- The 4x500 record reproduces: 500 cursors per case, 0/0/0/500 payloads and
  51,892 payload bytes.
- Gates run here: the focused `strategy-state-ws17` file (7 blocks, 0
  failures), `dev/bench/v0_2_3_ws5/check.R` (`WS5_INVENTORY_OK`) and
  `tools/check-codebase-contracts.R --mode=check`
  (`LEDGR_CODEBASE_CENSUS_OK`, helpers 2001, conditions 2479; see F6 for the
  stale committed census). The full suite
  and R CMD check were not re-run (out of brief scope); the closeout's
  build/check claim is recorded, not reproduced.

## Reviewer Mutations

These mutations were run through the existing isolated-copy driver
(`dev/bench/v0_2_2_indicator_history/scripts/mutate.R`, filter
`strategy-state-ws17`). They are not registered.

| Id | Edit | Claimed detector | Result |
| --- | --- | --- | --- |
| R1 merge-to-replacement | `R/fold-engine.R:1489` `context_ids, patch = TRUE` -> `patch = FALSE` | LTB-0533 (LCL-0523 "replace a helper patch") | **survives every block** |
| R2 reserved metadata names | drop `"intent_reason", "reset_state"` from `ledgr_strategy_state_reserved_names()` | LTB-0532 | **survives** |
| R3 axis change writes marker | `R/fold-engine.R:1499` `changed <- isTRUE(fold_state$state_axis_changed) \|\|` -> `changed <- FALSE \|\|` | LTB-0536 (LCL-0526 "write a marker on an axis change") | **survives** |
| R4 marker not excluded | `R/strategy-state.R:403` marker parameter -> `"not-the-marker"` | LTB-0534 (LCL-0524 "restore state only from the latest row"; LDG-3186 "marker-equals-payload mutation fails") | **survives** |
| R5b same-declaration candidate leak | sweep candidate seeds from the previous candidate's final state when its declaration matches | LTB-0537 (LCL-0527 "reuse one candidate's complete strategy state") | **survives** |
| R5 any-declaration leak | as R5b, unguarded | LTB-0537 | fails, but only incidentally: the state leaked from an earlier test's declaration raises an error; the equity oracle does not detect it |
| R6 replacement-to-merge | raw branch `patch = FALSE` -> `TRUE` | LTB-0533 | detected |

## Findings

### F1 (high): Section 4 item 4's required merge-to-replacement mutation survives every block and is not registered

Synthesis Section 4 item 4 says "A merge-to-replacement or
metadata-to-state mutation must fail". LDG-3186's first acceptance item says
the operations "fail under their opposite mutations". R1 turns the helper
patch into a complete replacement, and every WS17 block still passes. The
cause is in LTB-0533 (`tests/testthat/test-strategy-state-ws17.R:183-248`).
Its only patch pulse sets `count` and `peak`. The one field it omits is
`regime`, and the retained value of `regime` equals its default
(`"risk_on"`). A patch and a replacement therefore give the same checkpoint.
The ownership matrix registers only the declaration-type and
checkpoint-encode mutations.

Fix:

1. In LTB-0533, first give an omitted field a non-default value, for example
   a raw replacement on pulse 1 with `count = 1L, regime = "risk_off"`. Then
   make a helper patch that omits `regime` and assert that `"risk_off"` is
   retained. Keep the existing raw-replacement-resets-`peak` assertion. It is
   the detector that already catches R6.
2. Register `D5_merge_to_replacement` (the R1 edit) and a metadata-to-state
   mutation in `dev/bench/v0_2_3_ws5/mutations.R` and `ownership_matrix.csv`.
   For the metadata-to-state edit, `ledgr_strategy_result()` would place
   `intent_reason` inside the patch. Rerun and update
   `evidence/current/mutations.csv`.

### F2 (high): resume on a narrowed decision axis writes payloads where the uninterrupted run writes markers

`ledgr_strategy_state_restore()` (`R/strategy-state.R:390-412`) aligns the
restored payload to `resume_axis`, which is the full `instrument_ids`. It
returns that as the carried axis. On the first resumed pulse,
`observe_settle` (`R/fold-engine.R:549-557`) sees
`context_ids != state_axis`, sets `state_axis_changed` and forces a full
checkpoint, even though the state and the decision axis equal the previous
completed pulse's. Probe: run `scale_test_events_snapshot(second_members =
c("AAA","BBB"))` with a state that changes on three early pulses and then
stays unchanged. The uninterrupted run gives 15 rows ending in markers. The
same run, resumed one pulse at a time with `ledgr.interrupt`, gives 15 rows of
which pulses 5-15 are payloads, not markers. The final payload is identical,
so the values are exact but the cursor rows are not.

This violates LDG-3186: "A pulse is unchanged when its complete typed state
and decision-axis ID vector are identical to the previous completed
pulse's". It also breaks LCL-0524's claim that resumed unchanged tails encode
no payload. LTB-0534 misses it because its fixture's axis is constant and
equal to the instrument axis.

Fix: return the payload's own axis and its decoded values
(`list(values = restored$values, axis = restored$axis)`), and let the next
pulse's observe stage align by ID. This is exact because every axis change
forces a checkpoint, so the latest payload's axis is the axis at the cursor.
When no payload precedes the cursor, keep the defaults on `instrument_ids`.
By the same rule, that has been the axis on every pulse so far. Add a
detector that resumes after an unchanged pulse on a narrowed membership axis
and requires `state_json` rows identical to the uninterrupted run.

### F3 (medium): four named smallest-failing changes are not detected

- LCL-0526 / LTB-0536: R3 survives because `visits` changes on every pulse,
  so the axis-change rows are payloads anyway. Fix: make the state change
  only on some pulses (for example, return bare targets on most pulses) so an
  axis change is the only reason for a checkpoint. Assert payloads exactly
  on axis changes or value changes and markers everywhere else.
- LCL-0524 / LTB-0534: R4 survives because the interrupt fires after pulse 1,
  so the resume cursor is the only payload. Fix: interrupt after at least
  one unchanged pulse that follows the payload. Calling `ledgr_run()` three
  times with `ledgr.interrupt = TRUE` is enough. Then assert the restored
  `count` and the encoder count. This also covers "N unchanged pulses resume
  at N + 1".
- LCL-0527 / LTB-0537: R5b survives. The fixture has constant prices and zero
  cost, so `final_equity` is 1000 whatever the targets. A probe with targets
  offset by 4 gives 1000 vs 1000. The claim text says candidate fills are
  compared, but the test compares only final equity. Fix: compare per-candidate
  fills or positions, or decode each candidate's state, over a price path
  where targets change equity. Register R5b. LCL-0528 also says "every
  walk-forward training and test run", but LTB-0538 checks only test runs.
  Either narrow the scope or add a training-candidate witness.
- LTB-0532: R2 survives. Only `targets` is tested as a reserved name. Fix:
  loop over `ledgr:::ledgr_strategy_state_reserved_names()`, with the literal
  expected vector pinned in the test.

### F4 (medium): classed or attributed update values pass validation and are silently lost at checkpoint

`ledgr_strategy_state_validate_value()` (`R/strategy-state.R:228-259`)
checks only the base type. Declaration normalization refuses `is.object()`,
but update validation does not. Probes:

- A POSIXct into a numeric portfolio field is accepted. The live state is
  POSIXct, `canonical_json()` writes it as a string, and decode gives `NA`
  with `missing = FALSE`.
- A Date into a numeric asset field: same result.
- A 1x1 matrix into an integer field is accepted. Its `dim` stays in the live
  state and is lost on decode.

In each case the strategy reads a different value after resume than in the
uninterrupted run. That breaks "all returned values match declared
type/shape" and exact resume. The decoder accepts the `NA` that a cast
produced (`R/strategy-state.R:371-378`).

Fix:

1. In `validate_value`, refuse `is.object(value)` and any attribute other than
   `names`.
2. In the decoder, refuse when the cast leaves `NA` at a non-missing
   position.
3. Add the three cases to LTB-0533 or LTB-0532.

### F5 (medium): repeated normalization, per-pulse name matching and the cached encoder remain on the pulse path

Brief and manual checks: repeated invariant preparation, name matching inside
the loop, re-validation, and serialization/hashing. The README's seven-shape
record says declarations are "normalized once per candidate" and "runtime
validation does not encode". On these paths both claims are false:

1. `ledgr_strategy_state_defaults()` calls
   `ledgr_strategy_state_declaration_validate()` (`:170`). That call
   re-normalizes the declaration and makes two `canonical_json()` calls, each
   a SHA-256 of the serialized declaration (`:118-122`). It then rebuilds
   every full-axis default vector. It runs on every raw-replacement pulse
   (`:295`), on every reset pulse (`R/fold-engine.R:1481-1484`), once more for
   each field that contains `NA` (`:301`), and on every axis change through
   `align`. Probe over 20 pulses: raw-identical and reset runs make 28
   declaration validations and 93 `canonical_json` calls; the
   declared-unchanged run makes 8 and 53. That is one validation and two
   encodes per pulse. One `defaults()` call costs about 335 us at 500 IDs and
   4 fields.

   The `NA` default case is the canonical `peak = NA_real_` example, so a
   trailing-stop strategy that returns `NA` for unheld IDs pays this cost
   once per field on every pulse.

   Fix: validate once at fold setup (`ledgr_validate_execution_spec` already
   does this). Prepare each field's typed default scalar once, use an
   unvalidated internal builder for axis defaults on axis change, and reset
   `NA` by `value[reset] <- field_default`.
2. `validate_value` runs `setequal(names(value), axis)` and then
   `value[axis]` on every asset update (`:235-242`), with no identity fast
   path. The common return already carries the axis names in order. Cost:
   about 85 us per field per pulse at 500 IDs, against about 10 us for the
   identity check alone (the latter includes loop overhead).

   Fix: test `identical(names(value), axis)` first. Otherwise make one
   `match(axis, names(value))` and refuse when
   `length(value) != length(axis) || anyNA(idx)`.
3. `ledgr_strategy_state_encode()` validates the fold-owned values again
   (`:313`), although they were validated when they were applied. It also
   encodes through the cached `canonical_json()` (`:324`). On every changed
   pulse that hashes the whole state and inserts the payload into the
   process-global `.ledgr_json_cache`, a cache that never hits.
   `R/config-canonical-json.R:116-118` says non-repeating values must call
   `ledgr_canonical_json_encode()`. Probe: about 400 us cached against about
   150 us uncached, and about 650 us for the whole encode per changed pulse at
   500 IDs and 4 fields. After the probe the cache held 281 entries.

   This is also the JSON cache's last-hot-caller duty that LDG-3186 owns. The
   closeout's "retired untyped JSON cache ... absent" overstates it: state
   payloads still pass through the cache.

   Fix: encode through the uncached encoder, skip re-validation (keep at most
   a constant-cost shape assertion), and have the closeout name the cache's
   remaining owners.
4. The 4x500 record has one instrument and portfolio scalars only, so it
   cannot show any of these per-ID costs. Add one descriptive wide asset-state
   cell (for example 500 IDs, 4 fields, changed and unchanged) so the record
   can support the seven-shape claims. This stays descriptive, not a gate.

### F6 (low): the committed census is stale and its tool misses the new fingerprint binding

Running `tools/check-codebase-contracts.R --mode=check` here rewrote the
committed census under `dev/bench/v0_2_2_pre_cran_removal/census/`. Helpers
went from 1982 to 2001 and versions from 172 to 175. Version findings went
from 11 to 12. The new finding is `ledgr_strategy_state_rule_version`, marked
`outside_fingerprint = TRUE`. That mark is wrong: the product fingerprint
selects bindings by pattern (`R/store-gate.R:3-12`) and includes this one, as
LTB-0532 asserts. The tool, however, keeps a hardcoded list
(`tools/check-codebase-contracts.R:657`) that this workstream did not update.

Fix: add the binding to `fingerprint_names`, regenerate the census and commit
it with the correction. I reverted my regenerated files, along with the
`R/cpp11.R`/`src/cpp11.cpp` rewrite from `load_all`, so the tree is unchanged.

## Non-Blocking Notes

- `ledgr_strategy_result(t, peak = NA)` with a plain logical `NA` on a
  numeric field is refused as a type error. The contract text says
  "`NA` restores the field's declared default". Say "a typed `NA`" in
  help/contracts, or coerce a length-matching logical-NA vector to the
  declared type.
- `ledgr_strategy_state_view()` copies every atomic field on every pulse
  (`x[]` duplicates; checked with `tracemem`). R value semantics already
  freeze the view, so this copy defends only against by-reference writes into
  `ctx$state`. That is a defensible owner choice; keep it deliberate.
- A run whose first decision axis differs from `instrument_ids` writes a
  payload on pulse 1, even with no state declared. This matches the ticket's
  rule ("to the prepared defaults on the first pulse").
- The `test-availability-state.R` "dynamic membership" migration dropped its
  `members` and `plane_names` expectations. Both are covered elsewhere
  (`test-flat-lazy-context.R`, `test-availability-workflow.R`), so this is
  not oracle weakening, but the migration note should say so.

## Per-Ticket Acceptance

- LDG-3185: clean on types, codec, refusals, identity, the format binding and
  inspection, except F4 (attributed values) and the reserved-name detector in
  F3, plus F6's stale census.
- LDG-3186: not accepted. F1 (patch/replacement mutation), F2 (resume marker
  exactness), F3 (axis-checkpoint, marker-query and candidate-isolation
  detectors) and F5 (repeated normalization and cached encode) remain.

## Commands

```
Rscript <tmp>/probe1.R   # codec fidelity, config reopen, per-pulse call counts, view copy
Rscript <tmp>/probe2.R   # narrowed-axis resume rows, LTB-0537 sensitivity, micro costs
Rscript <tmp>/probe3.R; Rscript <tmp>/probe4.R   # adversarial declarations/payloads, final-pulse resume
LEDGR_MUTATION_SCRATCH=<tmp> Rscript dev/bench/v0_2_2_indicator_history/scripts/mutate.R <tmp>/review_mutations.R all <out> .
Rscript dev/bench/v0_2_2_indicator_history/scripts/mutate.R dev/bench/v0_2_3_ws5/mutations.R D5_state_declaration,D5_state_checkpoint <out> .
Rscript -e "pkgload::load_all('.'); testthat::test_local('.', filter='strategy-state-ws17')"
Rscript dev/bench/v0_2_3_ws5/check.R
Rscript tools/check-codebase-contracts.R --mode=check
Rscript dev/bench/v0_2_3_strategy_state/run_record.R <tmp>/record
```
