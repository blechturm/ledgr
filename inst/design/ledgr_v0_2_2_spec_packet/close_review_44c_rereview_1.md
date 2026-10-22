# WS44 / LDG-3071 ledgr_align_weights rename (Type 1, focused), `601fc3be..9fd7f7dc`

## Verdict: PASS_AFTER_PATCHES (two test-adequacy findings, one exact test patch; no product, contract or record defect)

What holds:

- The rename is pure:
  - I took the old `ledgr_history_weights()` body at `601fc3be` and
    substituted the class, the origin, the signature, `x` -> `history` and
    `weights` -> `solution`. The result is identical, line for line (44
    lines), to `ledgr_align_weights()` at `9fd7f7dc`.
  - The first statement still validates the history
    (`ledgr_history_require_consistent(history)`).
  - No alias, shim or fallback exists.
- The old name is absent from every current surface:
  - `grep -r` over the whole tree, ignored files included, finds
    `ledgr_history_weights` in 7 files only.
  - Five are historical records: `close_review_44a.md`,
    `close_review_44a_rereview_1.md`, `close_review_44c.md` and the phase A
    and phase B closeouts.
  - In `tickets.yml`, the hits are historical (the LDG-3070 evidence, the
    phase A/B evidence of LDG-3071, the Workstream 44 `scope_change` and the
    rename evidence's "is now" sentence) or current and correct (LDG-3071's
    scope and acceptance item 9 name the old name only to require its
    removal).
  - `macro_plan.md` WS7 names it once, to forbid restoring it.
  - The name does not appear in R/, NAMESPACE, man/, vignettes (`.qmd` and
    `.md`), `_pkgdown.yml`, NEWS.md, contracts.md, the tests or the census
    CSVs. `man/ledgr_history_weights.Rd` is gone.
- The historical records are unchanged:
  - `git diff --quiet` across the range is clean for
    `close_review_44a*.md`, `close_review_44c.md` and both closeouts;
  - the nine earlier LDG-3071 evidence items are byte-identical, and the
    scope and acceptance are unchanged.
- The tests follow the test-change rule:
  - in LTB-0407, LTB-0414, LTB-0371 and the export test, only call names,
    argument order and the renamed origin and class literals change;
  - every expected value and fixture is unchanged;
  - the reason is stated in the LDG-3071 rename evidence.

  LTB-0417 and LTB-0418 are registered with LCL-0407 and LCL-0408 (review
  profile), and the claims reader accepts all 342 claims. LTB-0418's scan
  reads what it claims. My R7 and R8 put the old name only in the generated
  `vignettes/causal-history.md` and only in `man/ledgr_history_info.Rd`;
  each fails it. R6, a load-time alias with no literal old name in R/, fails
  its namespace check.
- The docs agree with the code:
  - `tools/render-vignettes-gfm.R --check vignettes/causal-history.qmd` on
    an archive copy re-executes all 45 chunks, including `portfolio` with
    `w |> ledgr_align_weights(returns) |> ledgr_target_rebalance(...)`, and
    matches the committed `.md`;
  - the article prose, `?ledgr_align_weights`, the condition reference,
    NEWS and contracts.md agree;
  - each contracts.md sentence in the two changed groups (Pulse Data And
    Axis-Aligned Accessors, Strategy Context Teaching) is true of the code.
- The Cut 16 closeout:
  - names `ledgr_weight_alignment_mismatch` and not the old class;
  - its list is still 25 public classes, sorted;
  - it differs from `601fc3be` only by that swap.
- Records:
  - LDG-3071 is `complete`, Workstream 44 is `review_pending` and Cut 16 is
    `open`;
  - no file was added to the packet;
  - `tickets.yml`, `tests/claims.yml` and `_pkgdown.yml` parse;
  - every changed file is UTF-8 without CR. The only non-ASCII is
    pre-existing in `tickets.yml` and pandoc's apostrophe in the rendered
    `.md`; the diff adds none to `tickets.yml`;
  - `git diff --check 601fc3be 9fd7f7dc` is clean.

What does not hold:

- F1 (medium, test adequacy, acceptance item 8): the registered blocks do
  not detect a regression of the unsupported-shape refusal.
- F2 (low, test adequacy, contracts.md and LCL-0397 statements): the blocks
  do not detect a regression of the non-numeric refusal or of the
  history-first validation order.

One patch, verified on source copies, fixes both.

Review ratio: 2 findings over the 2 in-scope acceptance items (LDG-3071
items 8 and 9) = 1.00. Counted as `rfc_cycle.md` defines it, this is one
more independent verdict on Workstream 44, which becomes 6 over 7 completed
tickets (0.857), and Cut 16 becomes 25 over 25 (1.00).

## Method

- I read:
  - AGENTS.md and the approved brief;
  - the Workstream 44 `scope_change` and LDG-3071's scope, acceptance and
    evidence;
  - the whole diff `601fc3be..9fd7f7dc`, commit by commit (d0f2e832,
    904d2d8c, 9fd7f7dc);
  - the implementer's `scratchpad/ws44d/mutations.csv` and `specs.json`.
- I made a source copy with `git archive 9fd7f7dc`, reusing the worktree's
  compiled objects, and one copy per mutation, under
  `scratchpad/ws44d_review/copies/`. Every R process ran sequentially. I
  edited and ran nothing in the worktree.
- Scripts are in `scratchpad/ws44d_review/`:
  - `static_checks.R`: rename identity, historical-file diffs, records,
    closeout list, claims, encoding;
  - `evidence_diff.R`: item-by-item evidence comparison;
  - `make_copies.py` and `run_blocks.R`: mutations and named blocks;
  - `probe_gaps.R`: shows what the surviving mutations let through;
  - `apply_test_patch.py`: applies the proposed patch to the copies only;
  - `render_check.R`: the article freshness check.

## Findings

### F1 (medium, test adequacy; LTB-0417 / LTB-0407, acceptance item 8): the shape refusal has no discriminating detector

Verified facts:

- Acceptance item 8 requires refusal of "unsupported-shape mismatches
  through ledgr_weight_alignment_mismatch". The rename evidence says LTB-0407
  and the new blocks "cover every acceptance clause (... and shape
  refusals ...)".
- The only shape case is `matrix(1, 2L, 2L)` in LTB-0407. It has 4 values
  against 2 included instruments, so the length check refuses it with the
  same class even without the shape check.
- Mutation R2 deletes the shape check (`length(dim(solution)) != 2L ||
  min(dim(solution)) > 1L ...`). LTB-0407 (66), LTB-0417 (19) and LTB-0418
  (9) all pass.
- On the R2 copy, `ledgr_align_weights(array(c(0.25, 0.75), c(1L, 1L, 2L)),
  fast)` returns `AAA=0.25 BBB=0.75`. On the unmutated copy it refuses with
  `ledgr_weight_alignment_mismatch`.

Inference: a regression could silently read any array or wider matrix whose
length equals the included count. Examples are a 3-d array, or a 2x2 matrix
against four instruments. The evidence's coverage claim is not true for this
clause.

Fix: see Patch P1. It adds a length-2 three-dimensional array, so only the
shape check can refuse it.

### F2 (low, test adequacy; contracts.md Pulse Data And Axis-Aligned Accessors, LCL-0397, rename evidence): the non-numeric refusal and the history-first order are stated but not pinned

Verified facts:

- contracts.md now states that "a non-numeric value ... refuse[s] with
  `ledgr_weight_alignment_mismatch`", and LCL-0397's scope claims it. The
  only case is `"0.5"` in LTB-0407. It has length 1, so the length check
  refuses it anyway.
  - Mutation R3 (`if (!is.numeric(solution))` becomes `if (FALSE)`) passes
    all three blocks.
  - On the R3 copy, `ledgr_align_weights(c("0.25", "0.75"), fast)` returns
    `AAA=0.25 BBB=0.75`, a silent coercion. The unmutated copy refuses it.
- The rename evidence says "history is checked first", and the brief
  requires it. No block gives a bad solution together with a stale history.
  - Mutation R1 validates a non-numeric or wider solution before the
    history. It passes all three blocks.
  - On the R1 copy, `ledgr_align_weights("0.5", data.frame(x = 1))` refuses
    with `ledgr_weight_alignment_mismatch`. The unmutated copy refuses with
    `ledgr_invalid_history_result`.

Both gaps existed before this range: the `"0.5"` case dates from phase A.
The range rewrote the contract and claim text that states them, and the
brief asks that validation semantics be preserved and covered.

Fix: Patch P1. Its character vector of matching length and its stale-history
call close both gaps.

## Patches

P1 (verified). In `tests/testthat/test-history-api-bridge.R`, LTB-0417,
insert immediately before the comment line `  # A missing or non-finite
weight in an aligned solution refuses through`:

```r
  # A three-dimensional array or a character vector whose length matches the
  # included instruments reaches only the shape and type refusals.
  for (bad in list(array(c(0.25, 0.75), c(1L, 1L, 2L)), c("0.25", "0.75"))) {
    cnd <- tryCatch(ledgr_align_weights(bad, fast), error = function(e) e)
    testthat::expect_s3_class(cnd, "ledgr_weight_alignment_mismatch")
  }
  # The history is validated before the solution.
  testthat::expect_error(ledgr_align_weights("0.5", data.frame(x = 1)),
    class = "ledgr_invalid_history_result")

```

On the copies, LTB-0417 passes on the unmutated copy (22 expectations) and
fails on R1 (error: alignment class instead of
`ledgr_invalid_history_result`), R2 (array accepted) and R3 (character
accepted). It is a one-block addition to a block new in this range. No
existing oracle changes.

P2. In `tests/claims.yml`, LCL-0407:

- append to `scope`: "; a three-dimensional array and a character vector
  whose length matches the included instruments refuse with
  ledgr_weight_alignment_mismatch, and a non-numeric solution with a stale
  history refuses with ledgr_invalid_history_result because the history is
  validated first";
- append to `smallest_failing_change`: "; or remove the shape or numeric
  refusal, or validate the solution before the history (re-review mutations
  R1-R3)".

P3. In the LDG-3071 rename evidence item, add one sentence. It records
close_review_44c_rereview_1.md F1-F2, the P1 addition, that R1-R3 now fail
LTB-0417, and the new LTB-0417 count (22).

## Notes (no change required)

- N1. The help page says that "a wider matrix" refuses. A three-dimensional
  array also refuses, with the same class and the message "must be a vector
  or a one-column or one-row matrix". The wording is not false. "any other
  shape" would be exact, but that is optional.
- N2. `anyDuplicated(labels)` in the name check cannot fire alone: when the
  length matches, a duplicated name always leaves an included instrument
  unmatched, so `setequal()` also refuses. The duplicate-name clause holds
  behaviorally (`c(AAA = 0.5, AAA = 0.5)` refuses with the alignment class
  in LTB-0407). This is unchanged phase A code; removing it is out of scope
  for a pure rename.
- N3. The worktree still has the uncommitted CRLF-only changes to
  `R/cpp11.R` and `src/cpp11.cpp` and the untracked `ws44c_quiet_fast/`.
  None is in the range.

## Acceptance items

| Item | Result |
| --- | --- |
| 3071-8 ledgr_align_weights converts unnamed, named, one-row, one-column; origin; refusal classes; non-finite stays ledgr_invalid_strategy_type | met by the code (pure rename, checked by identity); detection holds for unnamed, reorder, one-row, one-column, origin, length, name, duplicate-name, missing-name and non-finite (R4, R5, R9 and the implementer's M2-M8 fail); F1 on shape |
| 3071-9 old export, help, class and docs absent without alias; history unchanged; executed example and WS7 use the new name | met (tree grep; LTB-0418 with R6-R8; historical diffs empty; article re-executed; macro_plan WS7 uses the final pipe) |
| Test-change rule | met; identifiers and argument order only; reason in the evidence |
| Records | met; LDG-3071 complete, WS44 review_pending, Cut 16 open, no new ledger, YAML parses |

## Mutations (on source copies of `9fd7f7dc`)

| ID | Mutation | Blocks | Result |
| --- | --- | --- | --- |
| R1 | a non-numeric or wider solution is refused before the history is validated | 0407, 0417, 0418 | survives (F2); fails patched 0417 |
| R2 | shape refusal removed | 0407, 0417, 0418 | survives (F1); fails patched 0417 |
| R3 | non-numeric refusal removed | 0407, 0417, 0418 | survives (F2); fails patched 0417 |
| R4 | length refusal removed | 0407, 0417, 0418 | 0407 fails (error: ledgr_invalid_strategy_type from ledgr_weights) |
| R5 | matrix labels read from the shorter dimension | 0407, 0417, 0418 | 0417 fails (2) |
| R6 | alias assigned at load time from a pasted name | 0407, 0417, 0418 | 0418 fails (namespace exists) |
| R7 | old name in the generated `vignettes/causal-history.md` only | 0418, 0414 | 0418 fails; 0414 passes |
| R8 | old name in `man/ledgr_history_info.Rd` seealso | 0418, 0414 | 0418 fails; 0414 passes |
| R9 | non-finite weights silently set to zero | 0407, 0417, 0418 | 0407 and 0417 fail (5) |

None of R1-R9 is in the implementer's list. Their M1-M8, N1-N7 and T1
cover different edits: M1 is a literal alias, N6 edits the `.qmd`, N7 edits
the new help page, and M5 routes non-finite values to the alignment class.

## Verification record

Windows 11, R 4.6.1, sequential, on the `git archive 9fd7f7dc` copy:

- `run_blocks.R` reports that the claims registry is valid (342 claims).
  LTB-0407 (66 expectations), LTB-0414 (104), LTB-0417 (19), LTB-0418 (9),
  LTB-0416 (282) and LTB-0371 (266) pass. `test-api-exports.R` passes (21
  expectations).
- `tools/check-codebase-contracts.R --mode=check`:
  `LEDGR_CODEBASE_CENSUS_OK ... findings=72` and
  `LEDGR_MODE_BRANCH_CENSUS ... branch_sites=158 flow_sites=55`. The
  regenerated census directory is identical to the committed one.
- `tools/render-vignettes-gfm.R --check vignettes/causal-history.qmd`:
  "Verified vignette Markdown", with 45 chunks executed.
- Not run, per the brief: the full suite, R CMD check and timing.
- Optimization shapes: the product diff only renames identifiers, strings
  and roxygen in one function and adds no iteration, so none of the seven
  shapes occurs. `match()` is still used once for the reorder. The new test
  code loops over 3-4 literal inputs (LTB-0417) and `vapply`s over the
  source files of the scanned surfaces (LTB-0418, test-only). Neither is on
  an ingest, seal, fold, hydration, finalisation or reader path.
