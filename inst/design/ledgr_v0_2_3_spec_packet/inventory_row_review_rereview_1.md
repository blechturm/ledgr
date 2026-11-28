# Inventory row review, re-review 1: the correction round (LDG-3280)

- Mode: Type 1 re-review of the correction round that answers
  `inst/design/ledgr_v0_2_3_spec_packet/inventory_row_review.md` (round 1,
  CHANGES_REQUIRED, F1-F12).
- Reviewed tree: detached worktree `C:/Users/maxth/ledgr-wt/row-rereview` at
  `867a93ac` (release/v0.2.3). I read the correction commit's diff against
  `15e9b785`. The worktree was not edited, and `git status` was clean at the
  end.
- Pin: source archive `C:/Users/maxth/ledgr-wt/pin-src-7f65733f`, library
  `C:/Users/maxth/ledgr-wt/pin-lib-7f65733f`.
- Reviewer: an independent session that wrote none of the work.
- Out of scope: `rfc_lean_core_deletion_readiness_v0_2_3_addendum.md`.
- Date: 2026-11-28.

## Verdict

**CHANGES_REQUIRED.** No finding needs a design change, so there is no
NEEDS_TYPE_2.

The correction round is mechanically sound:
- `review_corrections.R` applied to the pre-correction inventory (`15e9b785`)
  reproduces the committed `inventory.csv` byte for byte, and it is idempotent;
- `registry_rewrites.R` rerun on a copy reproduces both committed CSVs byte
  for byte;
- every rerun demonstration reproduces its committed `result.csv`, and each
  witness fails on an expectation, not on an error, with the smoke guard
  passing on the mutated candidate;
- the suite reconciliation reproduces;
- the design item lists exactly the 30 rows that carry `a`.

Three blocking gaps remain:
- LR-29's central sentence is false for the switched fold (N1);
- the registry rewrites leave other fields of the same entries stating the
  retired witnesses, and LCL-0054 keeps a detecting block that no longer
  detects it (N2);
- R028's spot_fifo half drops two of its three refused kinds without saying
  so (N3).

Each has a small, stated fix.

## F1-F12

| Finding | Status | Evidence |
| --- | --- | --- |
| F1 LR-27 not carried | Resolved | R026, R182 and R186 name `telemetry_stride` (LR-27). New row R197 drops the entry at test-api-exports.R:220; "the other nine boundaries" is correct, since the list has 10 entries. The pin's tests have no other `telemetry_stride` use without a row (test-run-telemetry.R:52 is R101). |
| F2 claims registry | Not resolved (N2) | All 27 `old` fragments occur in their fields, and every entry with a c detecting row is rewritten or listed as surviving; none is missed. But only scope, oracle_class and smallest_failing_change were rewritten. Other fields of the same entries still describe the retired witnesses, and LCL-0054's detecting block no longer detects it. |
| F3 R013 owner half | Resolved | R013 is c and cites [WS4a F4.19] (test-ws4a-carrier.R:1239). That block calls `ledgr_availability_valuation_state` with no fold, asserts reference 20 and age 4 and the three mark sources, and passes in the suite run (14 expectations). |
| F4 seams missing from the design item | Resolved | R147 is a,b and R088 is a,c; both are in the design item. Precision note: `n_committed` is an envelope variable that P5 writes (loop.R:351, :974), not a local of `lean_p5_commit`. |
| F5 b rows neither shown nor gated | Resolved | R087 and R091 have `gate.md`. All 30 b rows without a remap directory carry a "Cut 28 gate" phrase. R087's reason for not demonstrating now is valid: `local_mocked_bindings()` does not reach the candidate's `lean_plan_pulse`. |
| F6 R028 (NEEDS_TYPE_2) | Not resolved (N1, N3) | The probe's structural argument holds (below). But LR-29 says the refusal "is checked only in debug", and the switched fold never checks it, even in debug (N1). The spot_fifo half keeps a public witness only for CASHFLOW (N3). |
| F7 weakened oracles | Resolved | R060 chains through the handler's returned `next_event_seq` (R/backtest-runner.R:138; R/output-handler.R:523-526) and keeps `2L`. R073 and R074 count `ledgr_strategy_schedule_query`, the call that the pin's "service" increment follows (R/fold-engine.R:1842-1847); the rerun witness fails with service 9 against 1. R077 is b,c and cites the approval. One stale sentence remains (N4). |
| F8 corrections only in the README | Resolved | All listed corrections are now in `target_or_authority`. R180 and R185 are cost-merge gates (`gate.md`). R135 is open by agreement, but its options are misstated (N5). |
| F9 stale letters and texts | Resolved | R165 is e,c. R166 is b,c,g and demonstrated (rerun reproduced). R169 says approved. R023, R049 and R059-R061 state the deletion, and R062 points to them. census.md's new table matches the inventory (blocks a 29, b 75, c 75, d 1, e 1, g 4; all rows 30/87/85/1/1/4). |
| F10 seam split | Resolved | The design item has the two tables. `lean_facts_accept`, `lean_marks_clean`, `lean_plan_pulse`, `lean_lot_fill` and `lean_lot_opening` are all top level (facts.R:80, marks.R:191, plan.R:149, fifo.R:109, fifo.R:105). |
| F11 (optional) | Resolved as far as taken | The post-switch helper form is written in the README. The rest is left, which is acceptable for an optional finding. |
| F12 R189's crash witness | Resolved | My rerun of `identity_probe.R` reproduces its CSV: identical, debug on and off. A negative control (fee 0.5 changed to 0.6 in `after_1.R`) makes every row FALSE, so the probe can fail. All four `ws4a_3166_plan()` calls in the file use the default cash (lines 1671, 2225, 2228, 3543). The README sentence is corrected. |

**F6, the parts that check out.**
- The pin's `ledgr_fold_build_availability_pulse_plan()` (R/availability-economics.R:384-461) and `lean_plan_pulse()` (plan.R:149-246) pass only `none` or `if (length(fills) > 0L) 1L else none` as kinds.
- The pin's skip plan uses `none` (R/fold-engine.R:712). The probe's `structure.csv` does not list the skip plan, although LR-29 names it.
- A grep of R/ and dev/lean_core finds no other producer of `economic_event_kinds`. The only writes are availability-economics.R:386, fold-engine.R:712 and plan.R:145.
- The corpus log ends with 235 workloads, 37,835 plans, kinds {1}, 0 mismatches and 0 refusals.
- The replacement witness is not vacuous. My reruns of R028 (CASHFLOW beside FILL) and R028_p4 (a per-fill loop in P4) fail on their intended expectations, with the guard passing.
- The corporate-action refusal's public witness is real. I removed the kind check at loop.R:243 in a probe copy, and [LTB-0036] then fails on its expectation ("Expected `ledgr_sweep(...)` to throw ... ledgr_compiled_spot_fifo_unavailable"), with the guard passing. That witness covers CASHFLOW only (N3).

## New findings

### N1 (blocking): LR-29 says the refusal is debug-only; the switched fold has no check at all

Rows: R028; LR-29 (draft); the interface P3 placement table.

- **What.**
  - LR-29 says the pulse plan's unsupported-kind refusal "is checked only in debug". R028 says it "is debug-only on the lean path".
  - The only lean call of `ledgr_fold_plan_event_kinds()` and `ledgr_require_compiled_spot_fifo_event_kinds(kinds)` is in `lean_stage_plan` (plan.R:354-357). That is the harness adapter `lean_plan_install()` binds over the pin's `ledgr_fold_stage_plan` (plan.R:3-5, :529-541). It is not part of `lean_fold_envelope_plain`.
  - The switched P3, `lean_p3_plan` (loop.R:801-846), calls `lean_plan_pulse` and never checks kinds, even in debug.
  - The debug carrier check in `lean_plan_result` (`ledgr_carrier_plan`, R/fold-carrier.R:366-378) covers only these: kinds inside the dictionary, no duplicates, no kinds on an empty plan, and FILL declared exactly when there are fills. A plan that declares `c(1L, 2L)` or `c(1L, 3L)` passes it. The R028 mutation run shows this: with debug on, the run completes and the smoke guard passes.
- **Why it matters.**
  - The maintainer is asked to approve text whose main claim is false for the code that Cut 28 installs.
  - lean_core_interface.md:755 ("Event kinds | debug-only | P4") is not implemented in the switched fold either.
- **Fix.** Pick one before approving LR-29:
  - Make it true. Call `ledgr_fold_plan_event_kinds(batch, canonical_event_kinds = 1:2)` in `lean_p3_plan` under `.lean_debug`, and the spot_fifo FILL-only check when the selector is spot_fifo. This matches the interface placement and costs nothing in production.
  - Or reword LR-29 and R028: the refusal is retired from the fold; the debug carrier check keeps only the dictionary and FILL-declaration checks. Then also amend the interface row at :755.

  Optionally, add the skip plan to the probe's `structure.csv`, or cite fold-engine.R:712, since LR-29 names it.

### N2 (blocking): the registry rewrites leave the other fields of the same entries stale

Rows: R195; `census/registry_rewrites.csv`; tests/claims.yml entries LCL-0006, LCL-0022, LCL-0054, LCL-0136, LCL-0276, LCL-0277, LCL-0279, LCL-0489, LCL-0506, LCL-0507 and LCL-0508.

- **What.** The rewrites touch scope, oracle_class and smallest_failing_change. Each entry also has protected_contract_or_defect, oracle_independence, cheapest_adequate_lane and overlapping_evidence. Several of those still state the witness that the rewrite retires:
  - **LCL-0136.** protected_contract_or_defect: "A three-pulse fold invokes `flush_pulse_events()` exactly three times" (claims.yml:1462). oracle_independence: "The expected flush count ...". This is the per-pulse physical flush that LR-20 retires.
  - **LCL-0022.** oracle_independence: "The test injects three event kinds into the completed plan". cheapest_adequate_lane: "Two tiny in-memory folds per table row exercise both real dispatch boundaries". oracle_class: "negative witness". All three describe the retired mocked-planner runs.
  - **LCL-0054.**
    - The rewritten scope is "refuses every declared non-FILL corporate-action accounting event at fold entry". Its detecting block is still only LTB-0026, and after R028's remap that block exercises no spot_fifo refusal. The refusal's witness is [LTB-0036] in test-corporate-action-cash.R, which I confirmed by mutation.
    - Its oracle_class ("table-driven two-arm fail-closed witness"), oracle_independence and smallest_failing_change ("omit DISPOSITION or accept unknown kinds in the compiled event-envelope guard") are all unchanged. As things stand, no block detects them (see N3).
  - **LCL-0006.** oracle_independence: "LTB-0014 additionally reconstructs each retained compiled candidate". overlapping_evidence: "the full eight-pulse ... compiled matrix".
  - **LCL-0279.** oracle_class: "Runtime wrappers around the five production stages". oracle_independence: "compares returned packets with literal accepted field lists". The packets retire.
  - **LCL-0276.** protected_contract_or_defect, oracle_independence and smallest_failing_change all describe the locked carrier, which the new scope retires.
  - **LCL-0277.** overlapping_evidence: "LCL-0276 owns runtime carrier and stop shapes". oracle_independence: "omit or reorder a stage call".
  - **LCL-0489.** oracle_class: "public compiled-sweep parity". overlapping_evidence: "LTB-0006 owns broad compiled parity".
  - **LCL-0506.** cheapest_adequate_lane: "three handlers". overlapping_evidence: "the writer's surrounding behavior". Both refer to the db_live writer.
  - **LCL-0507.** overlapping_evidence: "keeps ... the live-mode refusal; this claim owns the buffered DuckDB refusal".
  - **LCL-0508.** oracle_independence: "(20, 25, 18 shared)".
  - **LCL-0014.** oracle_class "cross-path parity" is unchanged, while LCL-0006's identical class was rewritten.
- **Why it matters.**
  - F2 was about the registry still claiming witnesses that no block exercises. These fields are part of the same claim record.
  - LCL-0054 would remain a registry entry whose only detecting block cannot detect its scope: the vacuous pass F2 named.
- **Fix.**
  - For each rewritten entry, list every field in `registry_rewrites.csv`, either as a rewrite or as "survives" with a reason.
  - Re-point LCL-0054's `detecting_blocks` to include LTB-0036, or fold LCL-0054 into LCL-0022.
  - Optional: LCL-0135 (a b row, R052) still says "Buffered persistent ... handlers" (claims.yml:1450). LR-12 leaves one mode.

### N3 (blocking, small): R028's spot_fifo half loses DISPOSITION and unknown kinds

Rows: R028; LCL-0054.

- **What.**
  - The pin block asserts that a spot_fifo run refuses CASHFLOW, DISPOSITION and an unknown kind with `ledgr_compiled_spot_fifo_unavailable`.
  - The remap drops that half and cites [LTB-0036]. That block refuses only a dividend (CASHFLOW) corporate action. No test in the pin calls `ledgr_require_compiled_spot_fifo_event_kinds` directly, and no spot_fifo test covers a DISPOSITION corporate action.
  - The function stays in production at E (loop.R:241-244). An edit that let DISPOSITION through would therefore fail no block.
  - The row says the refusal "keeps its public witness", which is true only for CASHFLOW.
- **Why it matters.** A production refusal loses most of its witness without the row saying so. The original F6 fix allowed dropping this half, but only as a stated choice.
- **Fix.** Keep a direct, mock-free table in the remapped LTB-0026 block: `ledgr_require_compiled_spot_fifo_event_kinds(c("FILL", k))` errors with `ledgr_compiled_spot_fifo_unavailable` for each of `CASHFLOW`, `DISPOSITION` and `SYNTHETIC_UNKNOWN`, and returns for `"FILL"`. That is a b remap of a kept package function. Alternatively, state the narrowing in R028 and LCL-0054.

### N4 (patch): stale text left by the round

- **README.** "134 inventory rows' blocks pass today". My rerun of `suite_reconcile.R` reports 135, because R197 was added, and the F1 fix asked for the new count. The same paragraph still calls R013 "b,c"; it is now c.
- **R073 justification.** It still says "mapping it to one envelope entry is the representation choice the maintainer approves". The target now counts `ledgr_strategy_schedule_query`.
- **cut28_design_item.md.**
  - "the 28 rows with handling `a`, and two rows with other letters (R088, R147)": 30 rows carry `a`, R088 and R147 among them.
  - "so it is a `c` row": R028 is b,c.
- **R087 row and `remaps/R087/gate.md`.** Both say "the four frozen name lists". The block has three (`names(batch)`, `names(batch$fill)`, `names(batch$rejection)`, test-risk-fold.R), and gate.md itself lists three.

### N5 (patch; needed before the maintainer decides R135): R135's open choice is misstated

Rows: R135, R131.

- **What.** Option (b) reads "D25 stays on the R/ kernel and R131's D3 scan is recorded as fifo.R's only vectorization witness". Two parts are wrong:
  - **D25 already scans part of fifo.R.** Its remapped kernel set (remaps/R135/after_2.R) is the R/ kernel plus `ledgr_lot_apply_blocks`, `lean_p4_apply` and `lean_lot_first_failure`, the last of which is in fifo.R. Its `ops` list already bans `lean_lot_*` calls inside loops.
  - **D3 is not a vectorization scan.** [WS4a D3] (test-ws4a-carrier.R:379) checks name-keyed indexing ("index by position outside the census"), not loops. Under (b), fifo.R's other kernel functions (`lean_lot_apply`, `lean_lot_general`, `lean_lot_simple`, `lean_lot_apply_blocks`, with loops at fifo.R:266, :339, :422, :606 and :618) would have no loop scan at all.

  The original review's F8 wording carried the same error, and the round copied it.
- **Fix.** Restate the choice:
  - (a) add fifo.R's remaining `lean_lot_*` kernel functions to D25's kernel set, with their existing loops listed as approved exceptions;
  - (b) keep D25's set as written, and record that those fifo.R functions have no vectorization scan, D3 covering only their indexing.

### N6 (optional): the R028 structural witness has edges

- It walks only `lean_plan_pulse` and reads the second positional argument of `lean_plan_result`.
- It does not catch a kind added inside `lean_plan_result`'s body (`economic_event_kinds = kinds`), a return that bypasses `lean_plan_result`, or a change to what `none` holds.
- A cheap extension: assert that `lean_plan_result` passes `kinds` through unchanged, and that `lean_plan_pulse` returns only through `lean_plan_result`.

### N7 (optional): R166 leaves dead test code

After patch 2, the `counted()` handler mock and the `appended` counter in [WS4a compiled overflow] no longer feed an assertion. Drop the wrapper with the count, and keep the DONE/1000 sweep call.

## Commands run

All R runs used "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe", one command per call and one at a time. Scratch files are under `C:/Users/maxth/ledgr-wt/row-rereview-out/scratch/`.

- **Suite reconciliation.** `suite_reconcile.R --tests=.../ldg3280/suite/tests.csv --out=.../scratch/reconcile_rerun.csv`: identical to `suite/reconcile.csv`, with 39 failing blocks, all rowed, and 135 passing rows.
- **Registry rewrites.** I copied `census/` and `tests/claims.yml` into `scratch/rr/` at the same relative depth, because the script locates the root six levels up, then ran `scratch/rr/.../census/registry_rewrites.R`. Its output, "27 fields in 17 entries; 8 survive; affected entries 53", gives `registry_rewrites.csv` and `claims_registry_affected.csv` byte-identical to the committed files.
- **Row corrections.** `scratch/rr/.../census/review_corrections.R` on the committed inventory left it unchanged (idempotent). `scratch/rc_old/review_corrections.R` on the inventory at `15e9b785` reproduced the committed `inventory.csv` byte for byte.
- **Helper scripts.**
  - `scratch/f2_check.R`: checks that the old fragments are present, finds entries with a c detecting row, and prints the full entries.
  - `scratch/design_item_check.R`: checks the a rows against the design item and the b-row coverage.
  - `scratch/counts.R`: handling counts, summary and batch files.
  - `scratch/dump_rows.R`: dumps rows.
- **Remap demos.** `remap_demo.R --pin=C:/Users/maxth/ledgr-wt/pin-src-7f65733f --row=<copy> --out=.../scratch/runs --lean=C:/Users/maxth/ledgr-wt/row-rereview/dev/lean_core` for R028, R028_p4 (R028's before/after with `witness_p4/`), R166, R073 and R073_service (R073's before/after with `witness_service/`). Each was DEMONSTRATED, and each `result.csv` is identical to the committed one. The witness runs' `tests.csv` show expectation failures:
  - R028: kinds set mismatch;
  - R028_p4: per-fill loop found;
  - R166: first failure row 2, not 1;
  - R073: feature_resolver 9, not 1;
  - R073_service: service 9, not 1.
- **LTB-0036 probe.** `remap_demo.R` on probe row `scratch/rows/CA0036`: a no-op patch, with a mutation that replaces loop.R:243's kind check with `NULL`. The block passes on the candidate and fails on the expected refusal on the mutated candidate, with the guard passing.
- **R189 identity probe.** `scratch/R189/identity_probe.R --lib=C:/Users/maxth/ledgr-wt/pin-lib-7f65733f --pin=C:/Users/maxth/ledgr-wt/pin-src-7f65733f --lean=C:/Users/maxth/ledgr-wt/row-rereview/dev/lean_core`: CSV identical to the committed one. The negative control `scratch/R189_neg/identity_probe.R` (fee 0.6) gives all rows FALSE and stops.
- **Greps and reads** over the pin's R/, tests/ and tools/, dev/lean_core and tests/claims.yml, as cited above. Before each claim about code, I read the enclosing function.
