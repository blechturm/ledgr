# Inventory row review, re-review 2: correction round 2 (LDG-3280)

- Mode: Type 1 re-review of correction round 2, which answers
  `inventory_row_review_rereview_1.md` (N1-N7).
- Reviewed tree: detached worktree `C:/Users/maxth/ledgr-wt/row-rereview` at
  `c01eb3a0` (release/v0.2.3). I read the diff against `867a93ac`. The
  worktree was not edited.
- Pin: `C:/Users/maxth/ledgr-wt/pin-src-7f65733f` (source) and
  `C:/Users/maxth/ledgr-wt/pin-lib-7f65733f` (library).
- Reviewer: the same independent session as re-review 1, which wrote none of
  the work.
- Date: 2026-11-28.

## Verdict

**PASS_AFTER_PATCHES.**

The round answers N1 and N3-N7 correctly, and the scripts reproduce:
- `review_corrections.R` applied to the `15e9b785` inventory reproduces the
  committed `inventory.csv`, and running it again on that output changes
  nothing.
- `registry_rewrites.R` rerun on a copy reproduces both committed CSVs byte
  for byte: 65 rewrites in 18 entries, 75 fields kept with a reason, and 8
  entries that survive whole.
- R028, its second witness and R166 rerun to their committed `result.csv`.
  Each witness fails on an expectation, not an error.

Two registry rewrites, though, would make the test control plane refuse
`tests/claims.yml` once Cut 28 applies them (M1, M2). The fixes are small
and exact, so they are patches, not a third correction round. No design
change is needed.

## N1-N7

| Finding | Status | Evidence |
| --- | --- | --- |
| N1 LR-29 false for the switched fold | Resolved | LR-29, R028, `remaps/R028/row.csv` and the README now say: no production check; today only `lean_stage_plan` checks, in debug; Cut 28 adds the interface's debug-only call to `lean_p3_plan`; the plan-carrier check alone admits `c(1L, 2L)`. This matches plan.R:354-357, loop.R:801-846 and R/fold-carrier.R:366-378. The skip plan is cited at R/fold-engine.R:712. See M3 for one input the new obligation depends on. |
| N2 registry fields stale | Not resolved (M1, M2) | Every field of each rewritten entry is now listed, and the script stops if one is missing. I checked: no listed field is phantom, no field is double-listed except LCL-0506's two scope fragments, and every `old` fragment is present. The new texts I checked against the code and the cited rows are true, with two exceptions: LCL-0054's new detecting blocks mix profiles (M1), and LCL-0506 keeps a retiring block (M2). |
| N3 spot_fifo half narrowed | Resolved | `after_1.R` adds a direct table: `ledgr_require_compiled_spot_fifo_event_kinds("FILL")` is TRUE, and adding CASHFLOW, DISPOSITION or SYNTHETIC_UNKNOWN to FILL errors with `ledgr_compiled_spot_fifo_unavailable`. The function returns `invisible(TRUE)` (R/compiled-spot-fifo.R:85-101). The block passes on the candidate with 13 expectations. |
| N4 stale texts | Resolved | The README says 135 rows (134 before R197) and "R013, then b,c; c since". R073's justification is fixed. The design item says "the 30 rows with handling `a`" and "a `b,c` row". R087's row and gate.md say three name lists. |
| N5 R135 misstated | Resolved | The row and README state that D25 already holds `lean_p4_apply` and `lean_lot_first_failure` and bans `lean_lot_*` calls in loops, that D3 checks indexing only, and they give the two options with fifo.R's loop lines. |
| N6 structural witness edges | Resolved | The block now checks three more things: every `return()` in `lean_plan_pulse` returns `lean_plan_result(...)` and the last expression is that call; `lean_plan_result`'s source contains `economic_event_kinds = kinds`; and `none <- integer()` is a top-level statement. These are text checks, and their failure conditions can be read directly. A kind changed later inside `lean_plan_result` would still pass, which is acceptable for an optional finding. |
| N7 R166 dead mock | Resolved | Patch 2 removes `counted()` and `appended` and calls `ws4a_public_ovf(...)` directly, keeping the DONE/1000 oracle. The row's added reason is true: the mock attached an `append_compiled_spot_batch` function to every handler, and `ledgr_require_compiled_spot_fifo_dispatch` tests `is.function(output_handler$append_compiled_spot_batch)` (R/compiled-spot-fifo.R:70). The rerun passes on the candidate, and the witness fails on `lean_lot_first_failure(...)$row` (2, not 1). |

## New findings

### M1 (patch): LCL-0054's new detecting blocks fail the control plane's profile check

- **Rows:** R028; `registry_rewrites.csv` LCL-0054 `detecting_blocks` and
  `cheapest_adequate_lane`.
- **What.**
  - The rewrite sets LCL-0054's detecting blocks to `LTB-0026 LTB-0036`,
    and LCL-0054 promises the `fast` profile.
  - LTB-0036 is a `review` block: `# ledgr-test-profile: review` sits at
    test-corporate-action-cash.R:258, and LCL-0031, its own claim, promises
    `review`. LTB-0026 sits in the fast part of test-execution-spec.R (the
    review marker there is at line 935).
  - `tests/test-control-plane.R:462-468` aborts with
    `ledgr_test_claims_profile_mismatch` when a claim's detecting blocks do
    not share its promised profile.
  - The new lane text, "A direct table call and one short public sweep;
    fast", is also wrong about the sweep, which runs in the review profile.
- **Why it matters.** Applied as written at Cut 28, the registry fails its
  own check.
- **Fix.** One of:
  - keep LCL-0054 fast with detecting block LTB-0026 only (the direct table
    now witnesses every kind), and name LTB-0036 in `overlapping_evidence`
    as the review-profile public witness of the fold-entry call;
  - or split the fold-entry call into a review claim.

  Either way, correct the lane text.

### M2 (patch): LCL-0506 keeps LTB-0516, which retires

- **Rows:** R064, R065; `registry_rewrites.csv` LCL-0506 `detecting_blocks`.
- **What.**
  - The file marks `detecting_blocks` ("LTB-0515 LTB-0516") as
    "field survives". Its reason is: "LTB-0516 retires with the writer
    (R065)".
  - R065's target retires LTB-0516 with the writer.
  - `tests/test-control-plane.R:455-460` aborts with
    `ledgr_test_claims_unresolved_block` when a claim names a block that
    does not exist.
- **Why it matters.** At Cut 28 the registry would name a deleted block,
  and the claims check would fail.
- **Fix.** Make it a rewrite: `LTB-0515 LTB-0516` -> `LTB-0515`.
  - The new scope names LTB-0280 and LTB-0137 as the transaction witnesses.
    Both are `review` blocks (test-risk-fold.R:311 and :407), and LCL-0506
    promises `fast`. So they belong in `overlapping_evidence`, not in the
    detecting blocks.
  - The scope sentence can stay as it is.

### M3 (patch): the new Cut 28 debug call depends on a function in an old-fold file

- **Rows:** R028; LR-29.
- **What.**
  - LR-29 now commits Cut 28 to call `ledgr_fold_plan_event_kinds()` in
    `lean_p3_plan`.
  - That function is defined in R/fold-engine.R:172.
  - The holistic review (`holistic_review_claude.md`, around lines 369-380)
    lists it among the package functions that lean reaches only from debug
    sites and that have no other R/ caller outside the old fold files.
  - R028's `depends_on` calls it "(kept)", but no switch obligation says it
    moves out of fold-engine.R or survives the old-fold deletion.
- **Why it matters.** If Cut 28 deletes the old fold files without moving
  the function, the debug call that LR-29 relies on has nothing to call, or
  is dropped without being noticed.
- **Fix.** Add one sentence to LR-29 or R028: Cut 28 keeps
  `ledgr_fold_plan_event_kinds()` (moved out of fold-engine.R) or writes the
  equivalent check in lean P3.

## Commands run

All R runs used "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe", one
command per call and one at a time. Scratch files are under
`C:/Users/maxth/ledgr-wt/row-rereview-out/scratch2/`.

- **`git -C ... diff 867a93ac c01eb3a0`**, over every changed file.
- **Corrections from the base.** `scratch2/rc_old/review_corrections.R`,
  with `inventory.csv` taken from `git show 15e9b785:...`. Its output is
  byte-identical to the committed `inventory.csv` (letters a 30, b 87, c 85,
  d 1, e 1, g 4).
- **Idempotence.** `scratch2/rr/.../census/review_corrections.R`, run on a
  copy of the committed census, leaves it unchanged.
- **Registry rewrites.** `scratch2/rr/.../census/registry_rewrites.R`, run
  with `tests/claims.yml` copied at the same relative depth. Both CSVs are
  byte-identical to the committed ones.
- **`scratch2/rw_check.R`**: phantom fields, double-listed fields, `old`
  fragments, and the LCL-0054 and LCL-0506 detecting-block rows.
- **`scratch2/deleted_blocks.R`**: c rows whose block is deleted, crossed
  with the claims' detecting blocks. LTB-0516 is the only registered one.
- **Remap demos.**
  - Common arguments: `remap_demo.R
    --pin=C:/Users/maxth/ledgr-wt/pin-src-7f65733f --row=<copy>
    --out=.../scratch2/runs
    --lean=C:/Users/maxth/ledgr-wt/row-rereview/dev/lean_core`.
  - R028: DEMONSTRATED. The candidate passes with 13 expectations. The
    witness fails on the kinds set.
  - R028_p4 (`witness_p4`): DEMONSTRATED. The witness fails on the per-fill
    loop check.
  - R166: DEMONSTRATED, with `result.csv` and `remap.patch` identical to the
    committed ones.
- **Greps and reads.** I grepped and read tests/test-control-plane.R
  (claims validation), the test profile markers, `tests/claims.yml`,
  R/compiled-spot-fifo.R, plan.R and loop.R.
