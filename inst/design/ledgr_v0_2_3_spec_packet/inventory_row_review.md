# Inventory row review: the switch's test inventory (LDG-3280)

- Brief: `inst/design/ledgr_v0_2_3_spec_packet/inventory_row_review_brief.md`
  (approved 2026-11-27), mode Type 1.
- Reviewed tree: detached worktree `C:/Users/maxth/ledgr-wt/row-review` at
  `ac354d33` (release/v0.2.3). The worktree was not edited.
- Pin: source archive `C:/Users/maxth/ledgr-wt/pin-src-7f65733f`
  (LEDGR_SOURCE_COMMIT 7f65733f).
- Reviewer: an independent session that wrote none of the inventory, the
  census, the remaps or the design item.
- Date: 2026-11-27.

## Verdict

**CHANGES_REQUIRED.** One row, R028, returns **NEEDS_TYPE_2** (F6): its
disposition rests on a production refusal that the lean core does not have,
and two accepted texts disagree about whether it should.

The census method is sound. The suite reconciliation reproduces exactly, and
every failing block has a row. All 14 sampled remaps reproduce their recorded
outcome. Ten of the eleven witnessed samples fail on an expectation; R189's
fails on a crash (F12). The 12 gates are real. The g rows match decision 10.

The blocking findings are gaps, not a broken method:
- LR-27 was approved after the rows were written, and its retirement of
  `telemetry_stride` never reached four affected blocks (F1);
- the claims registry follows only three of the c dispositions (F2);
- two of the four remap findings are still open: R013's owner half and
  R147's skip seam (F3, F4);
- two b rows are neither demonstrated nor named Cut 28 gates (F5);
- R028's remap rests on a refusal the lean core lacks (F6);
- R060's remap reduces its oracle to a tautology (F7);
- R189's witness is a fixture crash that the mutated candidate's own smoke
  guard refuses (F12).

## Findings

Each finding names its rows, what is wrong, why it matters, and the fix.

### F1 (blocking): LR-27 is not carried into the rows it affects

Rows: R026, R182, R186, R101, and one block with no row:
test-api-exports.R "exported API surface is locked".

- **What.** LR-27 (approved 2026-11-27) retires "the `telemetry_stride`
  control, its validation (`ledgr_run_prepare_telemetry_stride()`) and the
  execution-spec field". The rows were written before LR-27 and were not
  updated:
  - R026 (test-execution-spec.R "execution spec constructor exposes only the
    canonical substrate payload"). Its frozen field list
    (test-execution-spec.R:416) contains `"telemetry_stride"`. The row's
    target drops only `checkpoint_every` and `event_mode`.
  - R182 (the test-execution-spec.R spec helpers, lines 118, 216 and 345)
    and R186 (`ledgr_risk_fold_test_execution`, test-risk-fold.R:95). Both
    pass `telemetry_stride = 0L` to `ledgr_execution_spec()`. Both rows say
    to drop only the `checkpoint_every` and `event_mode` arguments.
  - test-api-exports.R:220 lists `"ledgr_run_prepare_telemetry_stride"` in
    `internal_boundaries` and asserts that each entry exists. R101's own
    target says this "becomes a b row", and census.md's exclusion of
    test-api-exports.R carries the same condition. No row was added.
- **Why it matters.** Once Cut 28 removes the spec field and the validator,
  all four blocks fail. Cut 28 applies only approved mappings, and none
  covers these edits. The ticket says unresolved affected rows block the
  switch.
- **Fix.**
  - Add `telemetry_stride` to the removed fields in R026, R182 and R186,
    citing LR-27.
  - Add a b row for test-api-exports.R "exported API surface is locked"
    (drop the entry, citing LR-27, as a Cut 28 gate).
  - Rerun `suite_reconcile.R` and record the new row count.

### F2 (blocking): the claims registry follows only three of the c dispositions

Rows: R195; it should also cover LCL-0006, LCL-0014, LCL-0136, LCL-0276,
LCL-0277, LCL-0279, LCL-0288, LCL-0489 and LCL-0507.

- **What.** R195 rewrites only the three registry entries that pulse-plumbing
  Section 7 names: LCL-0506, LCL-0508 and LCL-0539. Section 7 adds that
  "these examples are not a blanket waiver". Other registry entries say
  something their detecting block will no longer show after its c
  disposition. Examples:
  - LCL-0006: "Canonical-R and compiled spot-FIFO differential parity" (R029,
    R030, R122). Under LR-25 both arms run fifo.R.
  - LCL-0014: "compiled parity through persistence" (R121).
  - LCL-0136: "the fold calls the pulse-event flush once per pulse" (R088,
    retired by LR-20).
  - LCL-0277 / LCL-0279 / LCL-0288: the old stage structure. Their blocks are
    rebuilt or partly retired by decisions (4) to (6).
  - LCL-0507: LTB-0517's buffered-mode precondition is dropped (R031).

  `census/claims_registry_affected.csv` is also stale: it still lists
  LTB-0279, LTB-0281, LTB-0293 and LTB-0498 as handling `f`.
- **Why it matters.** The registry records what each block witnesses (scope,
  `oracle_class`, `smallest_failing_change`). After the switch, LCL-0006 and
  LCL-0014 would still claim a compiled-parity witness that no block
  exercises. This is a vacuous pass at the registry level.
- **Fix.**
  - Extend R195, or add one c row per entry, with each entry's rewrite:
    - the compiled claims: "suspended until WS14 (LR-25)";
    - LCL-0136: logical per-pulse commitment (LR-20);
    - the stage-structure claims: the rebuilt detectors.
  - Regenerate `claims_registry_affected.csv` from the final inventory.

### F3 (blocking): R013's owner half is still a remap that cannot be written

Rows: R013 (finding remaps/R013/finding.md).

- **What.** Decision (3) keeps "an owner test of the service". The remap
  finding shows that the pin block has no owner half: its only oracles are
  `DONE` and `expect_gt(calls, 0L)`. A direct test needs a new fixture and
  new expected values. The finding offers two resolutions:
  - cite the existing direct test test-ws4a-carrier.R "[WS4a F4.19] the
    provider adapter keeps unpriced provenance field by field" as the owner
    witness;
  - or write a new test with its own stated reason.

  The inventory row still reads "b, a remap that drops the fold run". The
  README lists R013 under Findings but records no choice.
- **Why it matters.**
  - Without a choice, Cut 28 has no approved mapping for this row.
  - If the c half is applied alone, the block keeps only the `DONE` status
    of a public run. That is close to vacuous (census finding 2).
- **Fix.** The maintainer picks one of the two resolutions, and R013's row
  records it:
  - if F4.19: change the row's handling to c only, cite F4.19 as the owner
    witness, and delete the block or merge it into another;
  - if a new test: record it as a new test with its own reason in the ticket
    evidence, not as a b row.

### F4 (blocking): the Cut 28 design item omits two rows that need a stage seam

Rows: R147 (b), R088 (c); cut28_design_item.md.

- **What.** The design item lists exactly the 29 a rows. Two other rows also
  need an observation or injection inside a stage closure:
  - **R147** ([WS4a F4.27 empty plan]). Its remap finding says the skip half
    "moves to the Cut 28 seam item": the reconciliation
    `expected <- if (is.null(batch)) cash else ...` runs inside
    `lean_p5_commit`. The row is still b, and the design item does not list
    it.
  - **R088** ([LTB-0136]). The c disposition replaces the flush count with
    "the per-pulse logical commitment witness (committed fill count after
    each P5, loop.R:965 n_committed)". `n_committed` is a closure variable of
    `lean_p5_commit`. No package function exposes it per pulse.
- **Why it matters.**
  - The design item is where Cut 28 decides every seam (amendment (10)).
  - A row missing from it can reach Cut 28 with no seam and no approved
    weaker substitute. R147's skip half would then become a source-text
    anchor, which its finding calls a weakening.
- **Fix.**
  - Add R147 (skip half) and R088 to cut28_design_item.md with their needs:
    - R147: "observe that a skipped pulse reconciles against the fold cash,
      with the +1 mutant injected through the seam";
    - R088: "observe the committed fill count after each P5".
  - Split R147's row into its b half (through R194) and its a half.

### F5 (blocking): two b rows are neither demonstrated nor named gates

Rows: R087 (its b part), R091.

- **What.**
  - **R087.** The b part (the plan-batch, fill and rejection field sets,
    remapped to `lean_plan_pulse`'s batch) has no remap directory and no
    gate.
  - **R091** ("long-only risk step leaves compliant targets unchanged")
    calls `ledgr_apply_risk_step_long_only`, which deletion-readiness 4.3
    merges. Its siblings R092 to R094 are named Cut 28 gates. R091 is in
    neither `summary.csv` nor `batch_A.csv`/`batch_B.csv`.

  The README's 54 rows equal the 56 b rows without a gate phrase, minus
  these two.
- **Why it matters.** The ticket requires every mechanical remap row to be
  either demonstrated on scratch code or kept as an individually named Cut 28
  gate.
- **Fix.**
  - Demonstrate R087's b part now. `lean_plan_pulse` is callable on the
    candidate, as R189 and R194 show. Its witness can be a planner mutation
    that adds or renames a batch field.
  - Name R091 a Cut 28 gate on the 4.3 merge, as R092 is.

### F6 (blocking, NEEDS_TYPE_2): R028's remap rests on a refusal the lean core does not have

Rows: R028 ([LTB-0026] "accounting refuses every unhandled pulse event
kind").

- **What.** The row says to inject the event kind at `lean_plan_pulse`'s
  return, and that "the unsupported-kind refusal is the kept
  `ledgr_fold_plan_event_kinds()` on the lean path".
  - The switched fold never calls `ledgr_fold_plan_event_kinds`.
    `lean_p3_plan` (loop.R:801-846) passes the batch straight to P4.
  - The only call is in the harness adapter `lean_stage_plan` (plan.R:354),
    and only under `.lean_debug`.
  - The lean planner can only emit FILL or no kind (plan.R:163, :236). So
    in production, an injected CASHFLOW, DISPOSITION or unknown kind is
    ignored, not refused.
  - The spot_fifo half of the block expects the selector's event-kind
    refusal (`ledgr_require_compiled_spot_fifo_event_kinds`). Lean runs that
    check only on the corporate-action plan's kinds at E (loop.R:243).

  Two accepted texts disagree:
  - pulse-plumbing Section 4, "Plan/fill/rejection" row: keep the
    "unsupported-kind ... refusals under R3";
  - lean_core_interface.md P3 validation placement: "Event kinds |
    debug-only | P4".
- **Why it matters.**
  - The row's a classification assumes that a seam restores the witness. No
    seam can: there is no production refusal to witness.
  - Under the suite's debug-on run, a remapped block could pass only through
    a debug check. That is the same vacuity census finding 2 records for
    LTB-0282.
- **Fix.** This needs a design disposition before the row can be approved.
  Either:
  - lean P3 keeps the unsupported-kind refusal in production, as R3 and
    Section 4 say. That is a lean product change, as LDG-3276 was for the
    overflow refusal. R028 then stays a with a seam at the planner's return.
  - Or the refusal becomes debug-only or retired, with a rules-ledger entry
    reconciling Section 4 and the interface, on the decision-(1) pattern (no
    public input reaches it, because the planner emits only FILL). R028 then
    becomes c, citing that entry; the spot_fifo half is dropped or re-pointed
    at E's check.

### F7 (blocking for R060; optional for R073, R074, R077): b rows that weaken or lose their oracle

Rows: R060, R073, R074, R077.

A b row must preserve its fixture, oracle and witness strength.

- **R060** ("event_seq increments across multiple writes").
  - **What.** The pin block chains the second write from the first write's
    returned `next_event_seq` and asserts `r2$event_seq == 2L`. The row's
    target says "the remap passes 1 then 2 and reads the stored rows". That
    passes the expected values in, so the assertion can no longer fail
    (a tautology).
  - **Fix.** Chain through the handler path's returned `next_event_seq`. The
    payload builder returns `next_event_seq = seq[[n]] + 1L`
    (R/backtest-runner.R:138), and handler blocks carry it
    (R/output-handler.R:523-526). Keep the `2L` oracle. Otherwise reclassify
    the row c under LR-12, with the fold's event_seq advance as the
    replacement witness.
- **R073 / R074** ("services prepare once"; "preparation counters increment
  at one site per run and candidate").
  - **What.** The `service` count is mapped to `ledgr_fold_envelope`
    entries, which are one per run (or per candidate) by construction. That
    third of the oracle cannot detect a per-pulse service preparation.
  - **What still works.** The `feature_resolver` and `fill_axis_map` counts
    keep their strength: the witness run failed with `feature_resolver` 9
    against 1.
  - **Fix.** Count the preparer that lean E calls for the context service
    (the row names `ledgr_strategy_schedule_query` as the alternative), or
    mark the `service` third retired with the maintainer's approval as c.
- **R077** ("the pulse-seed path computes one vector per fold with no
  hashing").
  - **What.** The runtime `reads` count (one indexed read per pulse) is
    dropped for a static anchor. The row calls this "the approval point". A
    dropped runtime witness is a semantic change, not a b remap.
  - **Fix.** Relabel b,c and cite the maintainer's 2026-11-27 approval in the
    row. The vectors, derive and JSON witnesses are kept, and the witness
    run fails as recorded.

The maintainer approved R073, R074 and R077's representation choices by name.
For those three, the fix is a correct label and an explicit citation. R060's
weakening was never named, so it is blocking.

### F8 (patch): approved corrections exist only in the README, not in the rows

Rows: R131, R133, R135, R144, R150, R157, R158, R159, R173, R180, R185, R189,
R194.

- **What.** The README says "The inventory rows stay as written; these
  corrections go to the maintainer's row approval". Cut 28 "applies only the
  approved mappings". The row text now contradicts the approved corrections:
  - **R158 and R159.** The rows say to drop `flush_pulse_events`, "deleted
    under LR-20". The demonstrations keep it in the scan, because the lean
    terminal transfer still calls `handler$flush_pulse_events` (facts.R:334
    and R052's own justification).
  - **R180 and R185 (and R189 and R194, through `cost_steps`).** The
    demonstrated helpers reach `ledgr_plan_resolve` through
    `lean_plan_pulse`'s `cost_steps = NULL` branch, which deletion-readiness
    4.4 deletes. So the demonstrations hold only until the cost merge. R180's
    closure resolver may become a fixture finding.
  - **R135.** D25's kernel scan stays on the R/ kernel. After the switch the
    fold's kernel is fifo.R, which only R131's D3 scan covers. The README
    says "This should be a deliberate decision", but no decision is
    recorded. "Accepted all" approves the observation, not a choice.
  - **R157 and R173.** These are covered by R189's patch. The findings
    recommend reclassifying them; the rows are unchanged.
  - **R131, R133, R144, R150, R158 and R159.** Their census allowances live
    only in the row.csv notes of the remap directories.
- **Why it matters.** Cut 28 is told to apply the rows. An implementer
  reading R158 would delete a method the lean transfer still calls, or would
  remap R180 against a branch that is gone.
- **Fix.**
  - Write each correction into its row's `target_or_authority`.
  - Make R180 and R185 named Cut 28 gates on the 4.4 merge.
  - Record the maintainer's explicit choice for R135: either D25 also scans
    fifo.R's `lean_lot_*` kernel for per-instrument loops, or D25 stays on
    the R/ kernel and R131's D3 scan is recorded as fifo.R's only
    vectorization witness.

### F9 (patch): handling letters and texts not updated after the decisions

Rows: R165, R166, R169, R023, R049, R059 to R062; census.md.

- **R165 (`e`).** The block still errors on the final candidate (suite
  reconcile: "Error in utils::modifyList(p$x, list(...)): is.list(x) is not
  TRUE"). Its packet half needs LR-13's disposition, as R138 does. Change it
  to `e,c` and give the packet half's exact after-block: drop the
  `ws4a_v201_groups` capture and the `.ledgr_carrier_field_parts` sweep
  control.
- **R166 (`c`).** Its direct `ledgr_run_compiled_spot_fifo_batch`
  assertions (test-ws4a-carrier.R:2935-2950) are "subject to the [WS4a
  compiled boundary] question". Decision (9) settled that question: the
  wrappers stay until WS14. Those assertions should be `g`, and the
  `ledgr_fold_fill_candidate` line (deleted) should remap to
  `lean_lot_first_failure`, as R163 does.
- **R169.** The row still says LR-28 is "drafted for the maintainer's
  approval". It is approved.
- **R023, R049, R059 to R062.** Each is conditional: "applies only if Cut 28
  deletes `ledgr_write_fill_events`". Pulse-plumbing Section 7 says "Delete
  live dispatch/writer paths rather than preserve an ignored mode". State
  the deletion as given.
- **census.md.** Its Result table (a 27, b 83, c 72, f 12) predates the
  decisions. The inventory now has a 29, b 86, c 81, d 1, e 1, g 3 and f 0
  (letters counted per row).

### F10 (optional): the design item does not say which a rows need no production seam

Rows: R020, R024, R025 (direct half), R041, R042, R089, R132.

- **What.** These rows inject or observe through functions that are top
  level in the lean modules. After the switch these become package
  functions, so `local_mocked_bindings()` reaches them with no new seam:
  - `lean_facts_accept` (facts.R:80);
  - `lean_marks_clean` (marks.R:191);
  - `lean_plan_pulse` (plan.R:149);
  - `lean_lot_fill` (fifo.R:109);
  - `lean_lot_opening` (fifo.R:105).

  Examples:
  - R132's property ("openings take no Kahan step and keep a nonzero
    compensation") can be tested by calling `lean_lot_opening` directly,
    with its mutants built through `body<-`, as the pin's D7 block does for
    `ledgr_lot_opening`.
  - R041 and R042 can wrap `lean_plan_pulse` to capture its arguments and
    result.

  R028 would be in this group if F6 resolved it as a production refusal.
- **Why it matters.** Pulse plumbing R3/R4 keeps the hot path free of
  test-only branches. Listing these rows as needing a "seam" invites seams
  where a mock of a package function is enough.
- **Fix.** Split the design item's table into:
  - "mockable package function after the switch" (shape 3, no production
    change);
  - "needs an observation inside a stage closure" (R009, R010, R040, R046,
    R086, R087, R090, R107 to R109, R113, R140, R141, R143, R151, R152,
    R162, R168, R171, R172, R191, plus R088 and R147 from F4).

  Function names are the reference; the cited `loop.R:N` lines are about 8
  lines off on ac354d33 (for example `lean_p4_apply` is at loop.R:858, not
  850).

### F11 (optional): demonstration evidence and the form Cut 28 applies

Rows: R192, R067, R125, every row whose patch uses
`ledgr_test_candidate_source()` or the patched `ws4a_sources()`.

- **The Cut 28 form is not stated.**
  - `remaps/helper-candidate.R` defaults to
    `getOption("ledgr.candidate_lean")`, and R192's `ws4a_sources()` patch
    lists the candidate directory. After the switch neither exists.
  - The README says the helper's directory "then becomes the package's R/".
    Under `R CMD check` that has to go through `ledgr_test_source_root()`
    (tests/test-control-plane.R:12). It also has to keep the nested-closure
    walk over R/, which `ledgr_fold_phase_function_sources()` does not do.
  - So the patches demonstrated here are not the exact patches Cut 28 will
    apply. Write down the post-switch form of both helpers; the R/ version
    must still error on a missing or doubly defined name.
- **R192's patch can replace pin functions.** It overwrites any pin function
  that has a lean namesake (today `ledgr_history_substrate_bar_matrices`,
  from prepare.R) and drops names that are defined twice (`bind`, `fail`).
  No scan reads those names today. A one-line identity probe (pin entries
  unchanged for names without a lean namesake) would make R192 like the other
  no-witness rows.
- **The R067 / R125 probe.** It rebuilds the fixtures by hand rather than
  evaluating the patched text, as R004's probe does. It also writes its CSV
  to `C:/Users/maxth/ledgr-wt/cut27-scratch/...`, not into the row
  directory. It is sound for what it checks (the `ledgr_carrier_new`
  equity carrier is `identical()` to record + append + prefix). It is
  weaker than an execution of the patched block text.
- **`result.csv` does not tell a failure from an error.** It records "fail"
  for both. The README states that no mutation merely crashes. I checked
  that in my reruns (see Samples), but the committed evidence cannot show
  it. Adding `failed`, `error` and the first problem to `result.csv` would
  close this.
- **The candidate checksums depend on line endings.** The md5s in
  `suite/identity.csv` are of raw bytes. On this worktree's CRLF checkout,
  loop.R, facts.R and marks.R hash differently from the record (910fcfcc...,
  f224cb29..., 9c74cbaf...). They equal the cut27-dev files under
  `diff --strip-trailing-cr`, and no commit touches them after de04efa2. A
  line-ending-normalized digest would make the record portable.

### F12 (blocking): R189's witness is a crash, and the README says none is

Rows: R189; R157 and R173 rest on it.

- **What.** R189's mutation stops `lean_plan_pulse` from recycling `exec_ts`
  over the fill rows. The fold then crashes:
  - the committed `remaps/R189/result.csv` records the witness run's smoke as
    "WITNESS RUN, guard would refuse: the smoke run fails on the candidate:
    ledgr_invalid_pulse_plan: Invalid internal plan: fill: `exec_ts` does
    not have its axis length";
  - in my rerun the witness block errors with that condition (0
    expectations passed), and 18 other blocks in the file fail with it.

  The README says "None just crashes the fold, and in every demonstrated run
  both the candidate and the mutated candidate passed the driver's smoke
  guard". For R189 that is not true. It is the only such row among the 32
  `result.csv` files (grep for "guard would refuse"). The R173 finding itself
  calls this kind of failure "a crash of the fixture, not a witness of the
  claim".
- **Why it matters.**
  - R189 is a fixture-builder row. Its claim is that the remapped helper
    hands the blocks the same four-row plan.
  - A malformed plan that the debug validator refuses shows that the lean
    producer is called. It does not show that the fixture is preserved.
  - R157's and R173's coverage rests entirely on R189.
- **Fix.** Replace R189's witness with an identity probe, as R004 has: the
  remapped `ws4a_3166_plan()` output is `identical()` to the pin's
  `ledgr_fold_build_availability_pulse_plan()` output for the fixture
  inputs. Or use a value mutation that the validator accepts but the plan's
  expected rows reject. Then correct the README sentence.

## What checks out

1. **Completeness.**
   - The census method is sound:
     - it parses every block with `getParseData()` (1,366 blocks, all matched
       to the probe);
     - it closes over helper calls transitively;
     - it extracts mocked names;
     - it reads every candidate.
   - My greps for retired controls (`execution_mode`, `db_live`,
     `audit_log`, `checkpoint_every`, `event_mode`, `telemetry_stride`), for
     old-fold names (`ledgr_fold_envelope`, `ledgr_fold_stage_*`) and for
     fold file names (`fold-engine.R`, `fold-carrier.R`, `run-resume`) found
     only files that have rows or stated exclusions. The exceptions are
     F1's `telemetry_stride` hits.
   - The fixtures that name retired fields
     (`availability-v0-2-0-1/identity.csv`,
     `schema-current-golden-rows.csv`) have rows (R011, R103).
   - `suite_reconcile.R` rerun on `suite/tests.csv` gives the recorded
     output byte for byte (39 failing blocks, all rowed; 134 passing rows).
   - I spot-checked these exclusions and found their reasons correct:
     - test-schema.R:470 and :509 (message-specific refusals);
     - test-sweep.R "private two-boundary interface" (formals unchanged);
     - test-codebase-contracts.R LTB-0270 (tests reference the kept compiled
       wrappers, so none is orphaned) and LTB-0271 (no public condition
       class is unique to fold-engine.R except
       `ledgr_affordability_reconciliation_failed`, which lean keeps);
     - the rng-isolation tracer (conditional on the envelope binding name);
     - test-backtest-s3.R's `ledgr_backtest_bench` shape check (passes on
       the lean core today);
     - LTB-0269's schema-literal census (no listed file is on the fold
       path).
2. **Handling.**
   - The c rows cite existing authorities (LR-12/13/16/17/18/20/25/27/28,
     pulse-plumbing Sections 4, 5 and 7, D3-A/B/C, and the amendment
     decisions).
   - The g rows R021, R136 and R137 match decision 10 (see F9 for R166).
   - The twelve decision rows carry decisions (1) to (9) as written, except
     the two gaps above: R013's premise (F3) and R101's unpropagated
     consequence (F1).
3. **The 12 gates are real.**
   - Each needs a Cut 28 artifact that does not exist yet:
     - the 4.1, 4.3 and 4.5 merges: R092-R094, R104, R106, R111, R117 and
       R118;
     - the 4.4 cost merge: R149, R153 and R175;
     - the rebuilt phase checker: R154.
   - A remap today would name functions Cut 28 replaces (`lean_cost_resolve`,
     `lean_targets`, `lean_risk_apply`).
4. **The four remap findings.** R157 and R173 are adequately covered by R189
   (bookkeeping in F8). R013 and R147 are open (F3, F4).
5. **The six no-witness rows.**
   - R004 to R006: the probe executes the old and the patched helper over
     every fixture call in the file. The call set is complete (lines 54, 69,
     127, 129 and 132), and the probe is sound.
   - R067 and R125: sound but weaker (F11).
   - R192 has no probe (F11).
6. **Vacuous passes beyond census finding 2:**
   - R060's remap (F7);
   - the `service` third of R073 and R074 (F7);
   - R013 if its c half is applied alone (F3);
   - LCL-0006 and LCL-0014 at the registry level (F2);
   - R028 under the debug-on suite (F6).

   I also listed the ledgr functions that the lean modules call only under
   `.lean_debug` and crossed them with every block's mocked names (script
   below). The only blocks that mock such a function are R164 and the
   excluded [WS4a V-applied-row]. Both mock `ledgr_lot_applied`, which
   fifo.R:579-580 calls only in debug. Both apply the mock to the kept
   package kernel (`ledgr_lot_fill` / `ledgr_lot_apply`), which calls it in
   production, and R164's patch leaves those kernel cases on the package
   kernel (decision 7). So neither block passes only through a debug call.

## Samples and reruns

I copied 14 row directories and `helper-candidate.R` to
`C:/Users/maxth/ledgr-wt/row-review-out/rows/`. I ran `remap_demo.R` on each,
one at a time, into `C:/Users/maxth/ledgr-wt/row-review-out/runs/`. Each test
file with demonstrated rows has at least one sampled row.

Each rerun reproduced its recorded verdict, with the same candidate and
witness text as the committed `result.csv`. The table gives the witness
block's result on the mutated candidate.

| Row | File | Verdict (rerun = recorded) | Witness block on the mutated candidate | Guard on the mutated candidate |
| --- | --- | --- | --- | --- |
| R004 | test-availability-diagnostic-production.R | DEMONSTRATED (no witness run) | n/a; candidate 3/3 blocks pass | n/a |
| R007 | test-availability-economics.R | DEMONSTRATED | 4 expectation failures (accepted rows `SELL` instead of `BUY_EXACT, SELL`), no error | PASS |
| R017 | test-context-frame-retirement.R | DEMONSTRATED | expectation failure (`before` 11, not 1) | PASS |
| R021 | test-cross-asset-corrections.R | DEMONSTRATED | expectation failure on the `lean_p4_apply` position-write anchor | PASS |
| R035 | test-feature-accessor-scaling.R | DEMONSTRATED | expectation failure on the E preparation anchor | PASS |
| R067 | test-ledger-writer.R | DEMONSTRATED (no witness run) | n/a; candidate 23/23 blocks pass | n/a |
| R069 | test-one-execution-path.R | DEMONSTRATED | expectation failure (detail formatting found in `lean_p5_commit`) | PASS |
| R073 | test-position-facts-context.R | DEMONSTRATED | expectation failure (`feature_resolver` 9, not 1) | PASS |
| R077 | test-pulse-seed-v2.R | DEMONSTRATED | 3 expectation failures (loop walk, vectors count) | PASS |
| R112 | test-strategy-schedule.R | DEMONSTRATED | 2 expectation failures (stage scan) | PASS |
| R115 | test-strategy-sizing-evidence.R | DEMONSTRATED | 2 expectation failures (sizing anchor, JSON check) | PASS |
| R125 | test-sweep.R | DEMONSTRATED (no witness run) | n/a; candidate 26/26 blocks pass | n/a |
| R185 | test-fill-model.R | DEMONSTRATED | 2 expectation failures (prices `101, 99`, not `99, 101`) | PASS |
| R189 | test-ws4a-carrier.R | DEMONSTRATED | **error, 0 expectations passed**: `ledgr_invalid_pulse_plan` ("fill: `exec_ts` does not have its axis length"); 18 other blocks fail | **guard would refuse** (see F12) |

The candidate runs also reproduce the other failures in each file. Those
blocks belong to other rows and fail today: R010, R036, R040-R042, R074 and
R113, and in test-ws4a-carrier.R the 15 a and c rows listed in the suite
reconcile.

## Commands run

All R runs used "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe", one command
per call. The scripts are under `C:/Users/maxth/ledgr-wt/row-review-out/scratch/`.

- `suite_reconcile.R
  --tests=C:/Users/maxth/ledgr-wt/row-review/dev/lean_core/parity/evidence/ldg3280/suite/tests.csv
  --out=C:/Users/maxth/ledgr-wt/row-review-out/scratch/reconcile_rerun.csv`.
  Exit status 0; the output is identical to `suite/reconcile.csv`.
- `scratch/run_sample.R R069 R007 R017 R021 R035 R073 R077 R112 R115 R185
  R004 R067 R189 R125`. This is a sequential driver. For each row it calls
  `dev/lean_core/parity/remap_demo.R
  --pin=C:/Users/maxth/ledgr-wt/pin-src-7f65733f
  --row=C:/Users/maxth/ledgr-wt/row-review-out/rows/<row>
  --out=C:/Users/maxth/ledgr-wt/row-review-out/runs`. The candidate is the
  default, the worktree's dev/lean_core. The log is in
  `runs/sample_log.txt`.
- `scratch/check_runs.R`: compares each rerun with the recorded
  `result.csv`, and reads the witness run's `tests.csv` to tell a failure
  from an error.
- `scratch/inv_summary.R`, `inv_dump.R`, `b_coverage.R`, `seam_rows.R`:
  handling counts, b-row demonstration coverage, and design-item coverage.
- `scratch/lean_dups.R`: duplicate lean function names (only `bind` and
  `fail`), and the lean names that are also pin R/ names.
- `scratch/classes.R`: condition classes unique to fold-engine.R (for
  LTB-0271).
- `scratch/debug_only_mocks.R`: functions called only under debug, crossed
  with the blocks' mocked names.
- `diff -q --strip-trailing-cr` of loop.R, facts.R, marks.R and checks.R
  between this worktree and cut27-dev (identical apart from line endings).
- Greps over the pin's tests/, R/, tools/ and claims.yml, and over the design
  documents, as cited in the findings.

`git -C C:/Users/maxth/ledgr-wt/row-review status` was clean at the start
and was still clean after the last run (23:38).
