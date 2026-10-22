# WS44 phase C / LDG-3071 decision reconciliation and Cut 16 close record (Type 1), `5efe10cc..9ebe0544`

## Verdict: PASS_AFTER_PATCHES (two low record patches; no product, contract or oracle defect)

What holds:

- The reconciliation table (`cut16_decision_reconciliation.md`) has one row
  for each of decisions (1)-(35):
  - all 22 contract anchors it cites resolve;
  - all 70 function references it names are defined: 69 in the file the
    row names, and one ("reached from" in row (23)) in its own file;
  - every cited block is registered and defined once.

  I read 15 rows against code and tests: (18), (22)-(27), (31)-(35), the
  2026-10-17 sticky-barrier decision, and (4) and (9) for their anchors. In
  each, the contract group states the decision, the code owner implements it
  and the cited block exercises it. Six product mutations fail their row's
  block (table below).
- Every routed gap has a real owner and anchor:
  - (17) and (7): `macro_plan.md#deferred-history-simplification` names
    execution-core consolidation and the two maintainer questions;
  - (25) F05: v12 Section 11 "Revision optimization" is the reopening
    trigger;
  - (30): the 2026-10-21 horizon entry exists;
  - (9): `check_h6.R` in ledgr-research, by design.
- `contracts.md` changes are wording only, and each new sentence matches the
  code:
  - Event Staging: `R/sweep.R` `ledgr_sweep_impl()` releases the payload with
    `rm(payload)` and runs `gc()` only when `workers > 1L`;
    `ledgr_pulse_inspection()` releases and does not collect.
  - Fold Core: the substrate stores only lifetime and terminal segments, and
    `provider_plan` holds the facts (`ledgr_history_substrate()`).
  - Provider: `ledgr_history_membership_segment_counts()` counts every
    membership shape through `ledgr_history_membership_fact_counts()`.
  - The `max_sessions = 0` sentence moved, unchanged, to Activation, next
    to the `max_sessions = 5` default.
  - The stale "no default `max_sessions`" clause is deleted, as the
    maintainer decided (a). `R/availability-policy.R` defaults to 5.

  `max_sessions` now appears four times in the file with no contradiction.
  No changed sentence disagrees with the code, so nothing returns
  NEEDS_TYPE_2.
- The v12 appendix is append-only. The 41,092 bytes of `5efe10cc` are a
  byte-identical prefix of the new file, and all 14 anchors in the appendix
  resolve. Its section-to-decision map matches the table's "v12 section
  changed" column, row by row.
- LTB-0416 is source-derived:
  - it takes decision numbers from the `tickets.yml` decisions text,
    anchors from `contracts.md`, blocks from `claims.yml` and the test
    sources, and owners from the evidence-owners map;
  - LCL-0406 is registered with the review profile, and the control-plane
    claims reader accepts all 340 claims.

  I re-ran 5 checker mutations on rows different from the implementer's; each
  fails for its intended reason. The implementer's record at
  `scratchpad/ws44c/mutations_ltb0416.txt` shows K1-K12 detected and the
  unmutated K0 passing.
- The registered-test changes stay within the decisions:
  - LTB-0408 drops only its `expect_identical(status, "open")` for pending
    owners; a reverted LDG-3071 now passes LTB-0408 and fails LTB-0416;
  - LTB-0411 changes only the reader. `jsonlite` is in neither
    `DESCRIPTION` nor `NAMESPACE`. `ledgr_json_read_nested()` is the
    yyjsonr reader that LTB-0356 and LTB-0358 already use. The
    `expect_identical` oracle (10, 0.5, 5) is unchanged, and the block passes.
- The close record:
  - M1 recomputes to 23 verdicts over 25 completed tickets: 2 cut-review,
    and 1, 4, 2, 4, 4, 2, 3 and 1 close or focused verdicts for Workstreams
    40-47;
  - the record splits these into 19 CHANGES_REQUIRED, one
    PASS_AFTER_PATCHES, one PASS with findings and two confirmation PASS;
  - the per-workstream ticket counts (2, 3, 3, 3, 7, 1, 4, 2) match
    `tickets.yml`;
  - the condition diff against `0b2dd644` matches by a second method (see
    Method);
  - LDG-3071 is `complete`, Workstream 44 is `review_pending`, and Cut 16
    stays `open`.
- Governance:
  - no new ledger;
  - no `file:line` citation in any added record text;
  - `decisions.md` and `rfc/README.md` are unchanged, and LTB-0415 passes;
  - AGENTS.md has 149 lines, and the entry-point row is replaced, not
    appended;
  - `tickets.yml` and `tests/claims.yml` parse;
  - every changed file is UTF-8 without CR, and `git diff --check` is clean.

What does not hold:

- F1 (low, test text, LTB-0408). The comment that introduces the expected map
  still says pending owners "must still be open", and the now-unused
  `status <- ticket(spec$owner)$status` remains.
- F2 (low, record, Cut 16 closeout). "Maintainer review-disposition turns:
  eleven" counts grouped dispositions, while the list it gives holds 17
  separate turns. `rfc_cycle.md` names the counter "maintainer decision
  turns".

Review ratio: 2 findings over 3 in-scope acceptance items (LDG-3071 items 5,
6 and 7) = 0.667. Counted as `rfc_cycle.md` defines it, this is one more
independent verdict on Workstream 44, which becomes 5 over 7 completed
tickets (0.714), and Cut 16 becomes 24 over 25 (0.96).

## Method

- I read:
  - AGENTS.md and the approved brief, including its governance section;
  - `rfc_cycle.md`'s "Review measurement and escalation";
  - the Cut 16 entry (decisions, evidence owners, receivers, closeout);
  - LDG-3071, and every Cut 16 review file's verdict and finding headings;
  - the whole diff `5efe10cc..9ebe0544`;
  - the code and test blocks named in the rows I spot-checked.
- I made a source copy with `git archive 9ebe0544` (reusing the worktree's
  compiled objects) and one copy per mutation, all under
  `scratchpad/ws44c_review/copies/`. Every R process ran sequentially. I
  edited and ran nothing in the worktree.
- Scripts are in `scratchpad/ws44c_review/`:
  - `check_owners.R` checks every table row's named functions against their
    files, its anchors and its blocks;
  - `run_blocks.R` runs named blocks through the control-plane reader, after
    validating `claims.yml`;
  - `make_copies.py` and `run_mutations.R` apply and run the mutations;
  - `cond_diff.py` diffs the condition-reference aliases. As a second,
    independent method, it scans the `class =` literals in `R/` at both
    commits. That scan finds the 23 directly written public classes plus the
    private `ledgr_internal_pulse_inspection_capture`. The other two public
    classes are built conditionally in `R/indicator-history.R`. The three
    removed classes no longer appear in code. The six other new literals
    (`ledgr_history`, `ledgr_history_info`, `ledgr_history_policy`,
    `ledgr_history_read_service`, `ledgr_history_substrate`,
    `ledgr_history_view`) are S3 object classes, not conditions;
  - `static_checks.py` checks the v12 prefix, anchors, encoding, AGENTS.md
    length and wording residue;
  - `maint_grep.R` collects every "maintainer" sentence in the Cut 16
    tickets and workstreams, to check the list of decisions outside an RFC.

## Findings

### F1 (low, test text; LTB-0408): a stale rule comment and a dead variable after the approved assertion drop

Verified facts:

- `tests/testthat/test-history-integrated-proof.R`, LTB-0408, the comment
  before `expected <- list(`: "Items whose owner has not closed are
  pending: their owner must still be open." The block no longer checks this.
  LTB-0416 now checks the opposite, that every owner is complete.
- In the loop, `status <- ticket(spec$owner)$status` is assigned and never
  read.
- Maintainer decision (b) allows dropping the assertion only, and the
  oracle is otherwise unchanged. I confirmed this: reverting LDG-3071 to
  `open` passes LTB-0408 (185 expectations) and fails LTB-0416.

Inference: a reader of LTB-0408 is told a lifecycle rule exists that nothing
enforces there.

Smallest fix: reword the comment (for example, "Pending items are routed;
LTB-0416 checks that their owner closed") and delete the dead assignment. No
expectation changes.

### F2 (low, record; Cut 16 closeout): the disposition-turn count does not say what it counts

Verified facts:

- The closeout says "Maintainer review-disposition turns: eleven (...)".
  The list has eleven entries. Five of them join separate turns: "third-round
  authorization and acceptance", "correction authorization, decision 26
  amendment and acceptance", and so on. Counted one by one, there are 17.
- `rfc_cycle.md` ("Review measurement and escalation") asks for "maintainer
  decision turns". The record lists decisions (10)-(35) separately, without
  a count.

Inference: a later M1 reassessment cannot compare this figure with other
cuts unless the unit is stated.

Smallest fix: state the unit, for example "eleven review dispositions (17
maintainer turns)". Optionally add the number of decision occasions behind
(10)-(35).

### Notes (no change required)

- N1. LTB-0393's `gc` tracer cannot count. `quote(collections$n <- ...)` is
  evaluated in `gc()`'s frame, where `collections` is not visible.
  Unguarding the collection (my P1) therefore fails the block with "object
  'collections' not found", not through `expect_identical(collections$n,
  0L)`. Detection holds. This is pre-existing WS47 code and outside this
  range. If it is ever touched, `bquote(.(collections)$n <- ...)` would make
  the count real.
- N2. Config Policies still shows the signature as
  `ledgr_valuation_stale(max_sessions, exhausted = "freeze")`, that is, with
  `exhausted`'s default and not `max_sessions`'s. After decision (a) no
  sentence contradicts the code. Whether to show `max_sessions = 5` there is
  the maintainer's call; I did not treat unchanged text as NEEDS_TYPE_2.
- N3. LTB-0416 checks anchors, routes and blocks but not the table's
  code-owner column. `check_owners.R` found all 70 function references
  defined. Row (23) says `ledgr_history_substrate()` "reaches"
  `ledgr_fact_knowledge_refuse()`. It does, through
  `ledgr_availability_data_require_fact_knowledge()`, and lives in
  `R/history-substrate.R`.
- N4. `contracts.md` keeps "(Cut 16 LDG-30xx)" provenance labels (History
  start, Continuous carry, Point-In-Time Facts, history policy disclosure,
  preflight, `ledgr_history_weights`), as earlier cuts do. None uses a
  ticket as the subject of a behavior rule. The two that did ("LDG-3066 owns
  the feature-family rule", "LDG-3064 removed ...") are gone.
- N5. The implementer's mutation file ends "12 of 13 detected" because it
  counts the K0 control. The LDG-3071 evidence correctly says 12 of 12.
- N6. The worktree has uncommitted `R/cpp11.R` and `src/cpp11.cpp`
  modifications and an untracked
  `dev/bench/v0_2_2_history_proof/evidence/ws44c_quiet_fast/`. None is in
  the reviewed commits; they are probably from the timing run. Keep them out
  of any commit (`git commit --only`).

## Acceptance items

| Item | Result |
| --- | --- |
| 3071-5 source-derived owner/receiver check, no rule-3 or schema-120/121 statement | met (LTB-0416; K1, K3, K6, K8, K13 and the implementer's K1-K12 fail it) |
| 3071-6 Cut 16 close records M1, artifacts, exceptions, condition classes | met (M1 and the condition diff recomputed independently); F2 on the turn unit |
| 3071-7 reconciliation table, gaps fixed or routed, v12 appendix | met (15 rows read against code; 6 product mutations fail their blocks; appendix append-only) |
| Contract consistency (brief item 2) | met; wording only, no code disagreement in changed text |
| Maintainer decision (a) | carried out exactly: clause deleted, recorded as outside an RFC in the table and the closeout |
| Maintainer decision (b) | carried out: only the assertion dropped, with its reason in the evidence (F1 on the leftover comment) |
| jsonlite fix | reason in the LDG-3071 evidence; oracle unchanged; block passes |

## Mutations (on source copies of `9ebe0544`)

| ID | Row | Mutation | Block | Result |
| --- | --- | --- | --- | --- |
| P1 | (26) | `gc()` runs on every fresh sweep (guard removed) | LTB-0393 | fails (error from the tracer, N1) |
| P2 | (32) | `assume_effective` overwrites a supplied knowledge time | LTB-0358 | fails (4 failures, 1 error) |
| P3 | (33) | `ordinary_cash_dividend` removed from the entitled subtypes | LTB-0359 / LTB-0357 | LTB-0359 fails; LTB-0357 passes (specific) |
| P4 | sticky barrier | `sticky` plane replaced by the per-column assertion | LTB-0292 / LTB-0320 | both fail |
| P5 | (31) | a supplied corporate-action knowledge time is replaced | LTB-0356 | fails (2) |
| P6 | (23) | `ledgr_fact_knowledge_refuse()` never refuses | LTB-0336 | fails |
| K1 | checker | LDG-3071 reverted to `open` | LTB-0416 / LTB-0408 | LTB-0416 fails (`status(owner)` "open"); LTB-0408 passes |
| K3 | checker | row 24 deleted | LTB-0416 | fails (row numbers) |
| K6 | checker | row 27 anchor misspelled | LTB-0416 | fails (unresolved anchor) |
| K8 | checker | row 26 cites unregistered LTB-0499 | LTB-0416 | fails (2: unregistered, not defined once) |
| K13 | checker | routed row 17 relabelled `stated` with no contract anchor | LTB-0416 | fails (no anchor) |

The unmutated copy passes all 21 blocks I ran: LTB-0416, 0408, 0411, 0415,
0315, 0332, 0335, 0336, 0337, 0391, 0392, 0393, 0356-0360, 0292, 0320, 0409
and 0413.

## Verification record

Windows 11, R 4.6.1, sequential, on the `git archive 9ebe0544` copy:

- `run_blocks.R` reports that the claims registry is valid (340 claims) and
  that all 21 blocks pass. LTB-0416 has 282 expectations, LTB-0408 185,
  LTB-0411 10 and LTB-0415 39.
- `tools/check-codebase-contracts.R --mode=check`:
  `LEDGR_CODEBASE_CENSUS_OK ... findings=72` and
  `LEDGR_MODE_BRANCH_CENSUS ... branch_sites=158 flow_sites=55`.
- `tools/check-fold-phase-contract.R <copy>`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.
- `git diff --check 5efe10cc..9ebe0544` is clean.
- Not re-run, per the brief: R CMD check and the full suite. The
  coordinator holds that evidence: R CMD check reported Status OK, and the
  full suite ran 1,172 blocks with no failure.
- Optimization shapes: the only code changes are in tests (LTB-0416 and two
  edits to existing blocks). They are not on an ingest, seal, fold,
  hydration, finalisation or reader path. LTB-0416 loops over the 35 table
  rows and the 19 evidence items, both fixed design-record sizes. No product
  file changed.
