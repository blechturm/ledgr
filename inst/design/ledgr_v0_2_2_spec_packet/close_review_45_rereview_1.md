# WS45 / LDG-3073 focused re-review 1 (Type 1), `95df3edb..8fc570b0`

## Verdict: PASS

Correction 1 closes F1 to F5 of `close_review_45.md`, and Cut 16 decisions
(31) to (35) are implemented as written. I found no blocking or should-fix
defect. Two low findings remain, both on the record and the registered
detectors, not on product behaviour:

- R1 (low, record): the ticket evidence and the closeout say "14 declared
  differences"; the runner, its checker and the closeout table hold 13. The
  closeout also calls the runner's two-fold walk-forward a "three-window
  fixture".
- R2 (low, detector): LTB-0360 cannot tell header order by resolved
  knowledge time from header order by `set_id`, because its expected order is
  also alphabetical. Dropping the knowledge-time key from the header order
  (mutation M4) passes it.

Neither changes behaviour, so neither needs a correction round before
acceptance. Both are one-line edits the maintainer may take at acceptance or
leave to the next touch.

What holds:

- F1 (snapshot header order). Decision (34) accepts ordering on resolved
  instants. The runner declares the reviewer's input A
  (`diff34_snapshot_header_order`), LTB-0360 registers it, and mutation O8
  (headers not ordered) now fails LTB-0360. O8b still passes the other
  suites, which is expected: LTB-0360 is the registered witness.
- F2 (sessions laundering). `ledgr_fact_resolve_civil_families()` now checks
  the recorded hash of every pending family and every sessions family before
  it resolves (`R/availability-facts.R:1111-1118`). The first review's case D
  is refused at `ledgr_facts()`. Cases A to C are unchanged. My mutation M1
  (check pending families only) fails LTB-0354.
- F3 (chain-walk bound). The O(sum of chain depths) bound is stated in the
  code (`R/availability-facts.R:2520-2527`) and the closeout. The lineage
  level list is preallocated. Re-measured on the corrected tree: lineage
  0.03, 0.11 and 0.45 s and validation 0.11, 1.07 and 13.8 s for a single
  chain of D = 2,000, 8,000 and 32,000 corrections. This matches the stated
  numbers. Lineage at 120,000 and 480,000 rows takes under 0.01 s and
  0.03 s.
- F4 (present tense). `contracts.md` Provider, Knowledge And Timing and
  `R/availability-provider.R:279-283` state the settled rule. No
  "decided with LDG-3073" remains outside decision (23)'s own historical
  text.
- F5. `git diff --check 4b33f377 8fc570b0` is clean. Every file the
  correction touches is ASCII with LF line ends, apart from two em dashes in
  `tickets.yml` line 239, which BASE already has.
- Decision (32), probed for each family (below). A supplied knowledge time is
  kept under `assume_effective`, and only a missing one is filled. At run
  time no membership, snapshot-membership, trading-status or lifetime fact is
  visible before its supplied knowledge time. BASE showed each of them early.
- Decisions (33) and (35), probed (below). An effective-only cash dividend
  refuses with `ledgr_corporate_action_entitlement_missing` in a single run,
  a sweep (FAILED candidate), the carried three-fold chain and a dense run.
  The carried chain refuses on the same fact as the single run.
- Identity. The implementer's runner, re-run here on BASE and the corrected
  copy, gives `WS45_IDENTITY_OK`. My copy of the first reviewer's identity
  probe shows that every difference from BASE falls under a recorded
  decision. Against the first-round candidate, only decision (32) cases and
  one refusal message change, so nothing the first review passed has
  regressed.
- Full suite, census check and fold-phase checker pass (Verification).

Review ratio: 2 findings over 7 re-reviewed items (F1 to F5, decision (32),
decisions (33) and (35)) = 0.286. This is correction round 1's re-review.

## Method

- I read:
  - AGENTS.md, the approved brief (including Antipattern avoidance);
  - `close_review_45.md`, Cut 16 decisions (31) to (35) and LDG-3073;
  - the Correction 1 section of `fact_pipeline_followups_closeout.md`;
  - the whole of `git diff 95df3edb 8fc570b0`: product, tests, claims,
    contract, NEWS, condition reference, Rd, runner and census.
- Source copies from `git archive 8fc570b0` under the scratchpad
  `ws45_rereview/`: `cand` and `mut` (mutations, restored after each; a
  final `diff -rq` of `R/` shows no difference). BASE is the first
  reviewer's `ws45_review/base` copy of `4b33f377`. Every R process ran
  sequentially.
- Probes (`ws45_rereview/scripts/`, plus the first reviewer's scripts):
  - `probe_integrity.R` (first review): cases A to D;
  - `probe_d32.R`: stored knowledge per family and input shape, and a run
    for membership intervals and trading status; `probe_d32b.R`: a run for
    membership snapshots and lifetime; both on BASE and the candidate;
  - `probe_d33.R`: the dividend in a single run, a sweep, three-fold chains,
    a training-window placement and a dense run;
  - `identity_probe.R` and `compare.R` (first review): BASE against the
    candidate, and the first-round candidate against the candidate;
  - the implementer's `compare_runner.R` and `compare_check.R`;
  - `scale_probe.R` (first review) through `run_depth.ps1`: chain-depth
    points, High performance plan, affinity `0xFFFF`, disclosure only;
  - `mutate.py`: the first review's O8 and O8b and my M1 to M4.

## Findings

### R1 (low, record): the declared-difference count is 13, not 14

Verified facts:

- `tickets.yml:2238` (LDG-3073 evidence) says "14 declared differences".
  `fact_pipeline_followups_closeout.md:466` says "14 declared differences,
  each listed in the table above".
- The table above it (`:213-227`) has 13 rows. The `intended` vector in
  `compare_check.R` has 13 entries. The runner output I reproduced lists 13
  `DIFFERS` cases (11 fact cases and 2 snapshot cases).
- `fact_pipeline_followups_closeout.md:436` calls the runner's walk-forward
  "three-window". `compare_runner.R:312-315` defines two folds.

Smallest fix: say 13 in both places, and "two-fold" at line 436.

### R2 (low, detector): LTB-0360 does not detect a header order without the knowledge-time key

Verified facts:

- LCL-0350 (`tests/claims.yml:3787-3798`) claims that headers are "ordered
  by resolved effective and knowledge times after civil resolution". LTB-0360
  (`tests/testthat/test-fact-pipeline-followups.R:749-774`) gives both sets
  the same effective time. It expects `set_x` (assumed 10:00) before `set_y`
  (Date knowledge, 14:30), which is also alphabetical order.
- Mutation M4 removes `headers$knowledge_time` from the header order key
  (`R/availability-facts.R:1292-1298`). The whole of
  `test-fact-pipeline-followups.R` passes.
- The claim's listed smallest failing changes (no ordering, or ordering on
  placeholders) are both detected: O8 and the implementer's H1 fail
  LTB-0360.

Inference: the runner case `diff32_snapshots_assume` (sets `set_a` at 23:00
before `set_z` at 12:00) would show M4 as an unexpected difference, but the
runner is not a registered test.

Smallest fix: rename the sets in LTB-0360 so that `set_id` order contradicts
the expected order. For example, name the assumed-knowledge set `set_y` and
the Date-knowledge set `set_x`, and expect `c("set_y", "set_x")`.

## Notes (no change required)

- N1, the walk-forward with a refusal inside every training window (question
  3 of the brief). `probe_d33.R` case 4 puts the effective-only dividend at
  session 2, inside all three training windows. Verified:
  - the single run refuses with `ledgr_corporate_action_entitlement_missing`;
  - every training candidate is `FAILED`, and each train score row keeps
    `error_class = ledgr_corporate_action_entitlement_missing` and the
    message;
  - each fold has `selection_source = "none"`, the session status is `DONE`
    and there are no test runs;
  - `print()` reports "3 train evaluations attempted: 0 done, 0 incomplete,
    3 failed", "3 fold(s) had no candidate before any training selection"
    and "no fold selected a candidate; this session has no test evidence";
  - with `no_selection = "fail"` the session stops with
    `ledgr_walk_forward_no_selection`.

  This is the documented No selection rule (`contracts.md` Walk-Forward Fold
  Lifecycle, Cut 10 LDG-2974): a training sweep records a refusing candidate
  as `FAILED`, and before any selection the fold runs no test window and is
  `DONE`. Any data-dependent refusal in a training window behaves this way,
  including the decision (28) rows and `ledgr_corporate_action_clock_missing`.
  So it is not specific to WS45. It is not silent: the result counts the
  failed evaluations, warns that there is no test evidence, and keeps the
  refusal class in the score rows. It is not misleading under the contract
  either, because the decision (28) sentence ("A carried walk-forward chain
  refuses on the same pulse as one run") concerns the carried test chain,
  and in the test-window placement the chain does refuse (`probe_d33.R`
  cases 1 and 2). I classify it as acceptable. Two optional improvements:
  `print()` could name the failure classes of failed train evaluations, and
  the decision (28) contract bullet could say that inside a training window
  the refusal is a `FAILED` candidate under No selection.
- N2: the integrity bullet in `contracts.md:681-685` still says
  `ledgr_facts()` "checks that family's recorded hash first" and does not
  mention the sessions families it reads. Its conclusion (an edited family is
  refused whatever else the bundle holds) is now true. The closeout's
  seven-shape row for `ledgr_fact_resolve_civil_families()` (`:298`) is
  similarly unchanged. NEWS states the sessions case.
- N3: a complete `ordinary_cash_dividend` with unvalidated cash terms
  (`gross_cash_validated = FALSE`, as in LTB-0359's fixture) refuses when it
  has no entitlement clock. With an entitlement clock the same row does not
  post (`cash_eligible`, `R/corporate-action-settlement.R:220-229`). This
  follows decision (33)'s unconditional text and decision (28)'s pattern,
  which does not require validated terms either. The maintainer may want to
  confirm it.
- N4: the sessions predicate `identical(family$family, "sessions")` appears
  both in the integrity check (`R/availability-facts.R:1112`) and in
  `ledgr_fact_civil_sessions()` (`:1149`). The two must stay aligned if
  resolution ever reads another family.
- N5: the worktree holds uncommitted line-ending-only changes to `R/cpp11.R`
  and `src/cpp11.cpp`. They are not part of the reviewed commits and should
  not be committed.

## Item results

| Item | Result |
| --- | --- |
| F1 header order | Closed under decision (34): declared in the runner, LTB-0360 registered, O8 fails LTB-0360; detector gap R2 |
| F2 sessions laundering | Closed: case D refused at `ledgr_facts()`; A to C unchanged; M1 and the implementer's S1 fail LTB-0354 |
| F3 chain-walk bound | Closed: bound stated in code and closeout, levels preallocated, numbers reproduced |
| F4 present tense | Closed (contract, provider comment, NEWS); N2 on the integrity bullet |
| F5 `git diff --check` | Closed: clean |
| Decision (32) | Met: stored instants match for 4 families x 5 shapes; no lookahead at run time for all four families |
| Decisions (33), (35) | Met: refusal in a single run, a sweep, the carried chain, a Date-effective run and a dense run; training-window placement is acceptable (N1) |
| Identity | Met: runner `WS45_IDENTITY_OK`; every difference in my probe is under a recorded decision; count R1 |
| Antipatterns | No new per-row work or second rule (below) |
| IDs and docs | LCL-0348..0350 and LTB-0358..0360 are inside LCL-0341..0360 and LTB-0351..0370; contract, NEWS, condition reference and Rd agree and are in present tense |

## Decision (32) probes

`probe_d32.R`, New York sessions (open 14:30 UTC, close 21:00 UTC), one row
per family and shape, `knowledge = "assume_effective"`, effective date
2021-01-05. Stored knowledge time on the candidate:

| Shape | Expected | Intervals | Snapshots (row and header) | Status | Lifetime |
| --- | --- | --- | --- | --- | --- |
| Date effective, POSIXct knowledge 01-06 18:00 | kept | 01-06 18:00 | 01-06 18:00 | 01-06 18:00 | 01-06 18:00 |
| Date effective, POSIXct knowledge 01-05 12:00 | kept | 01-05 12:00 | 01-05 12:00 | 01-05 12:00 | 01-05 12:00 |
| POSIXct effective 10:00, Date knowledge | session open | 01-05 14:30 | 01-05 14:30 | 01-05 14:30 | 01-05 14:30 |
| Date effective, knowledge missing | effective session open | 01-05 14:30 | 01-05 14:30 | 01-05 14:30 | 01-05 14:30 |
| POSIXct effective 10:00, knowledge missing | effective instant | 01-05 10:00 | 01-05 10:00 | 01-05 10:00 | 01-05 10:00 |

BASE stores 01-05 14:30 for both supplied POSIXct rows in every family. The
other three shapes are the same in both trees.

Run-time visibility (pulses at the 21:00 UTC close):

| Fact | Supplied knowledge | Candidate visible from | BASE visible from |
| --- | --- | --- | --- |
| BBB membership interval from 01-05 | 01-07 22:00 | 01-08 | 01-05 |
| CCC membership interval from 01-05 | missing | 01-05 | 01-05 |
| AAA halt from 01-11 | 01-12 15:00 | 01-12 | 01-11 |
| CCC halt from 01-11 | missing | 01-11 | 01-11 |
| BBB in snapshot set from 01-05 | 01-07 22:00 | 01-08 | 01-05 |
| CCC `known_inactive` (delisted) from 01-11 | 01-12 15:00 | 01-12 | 01-11 |
| AAA `known_inactive` from 01-13 | missing | 01-13 | 01-13 |

No fact is visible before its supplied knowledge time on the candidate.

## Decisions (33) and (35) probes

`probe_d33.R` uses 12 sessions and three explicit folds (train from session
1; tests 3-5, 6-8 and 9-12). The dividend is on BBB (held), with validated
gross cash of 1.

| Case | Result |
| --- | --- |
| control: entitlement 4, effective 5 | completes, `CASHFLOW` posted |
| effective 4 (test window 1), known 10 (window 3): single window 3..12 | refuses at effective 01-07 21:00, knowledge 01-15 14:30 |
| same, carried chain | refuses on the same fact and clocks |
| Date effective (session 7), no knowledge | stored knowledge 14:30 and effective 21:00 on 01-12 (decision 27); single run and chain refuse |
| sweep | one `FAILED` candidate, with `error_class` set to the refusal class |
| effective inside every training window | see N1 |
| dense run (no sessions) | refuses, subtype `ordinary_cash_dividend` |

## Identity

- Runner (`compare_runner.R` on BASE and on the corrected copy, then
  `compare_check.R`): `WS45_IDENTITY_OK`. There are 21 identical cases and 13
  declared differences (R1), with the same output as the committed
  `evidence/compare_result.txt`.
- First reviewer's `identity_probe.R` (29 fact cases, 6 constructor cases,
  2 sealed snapshots with runs), BASE against the candidate. Every difference
  is under a recorded decision:
  - `snap_date_knowledge_assume` (F1 input A): header order `set_x, set_y`;
    decision (34);
  - `snap_mixed_assume` and `snap_mixed_assume_gen`: supplied POSIXct
    knowledge kept and headers in resolved order; decisions (32) and (34);
  - `ca_assorted` and `rebundle_mixed`: supplied POSIXct knowledge beside a
    Date event kept; decision (31);
  - six constructor cases: Date-dependent refusals move to `ledgr_facts()`
    (item 4; first review N3);
  - `dst_d28_date`: decision (28) refusal.
- The same probe, first-round candidate (`021aaa7f`) against the corrected
  copy: only `snap_mixed_assume` and `snap_mixed_assume_gen` (decision 32)
  and the refusal message of `dst_d28_date` ("cash, disposition or quantity
  effect") change. Everything else the first review passed is identical.

## Antipattern walk (changed code)

| Function | Change | Walk |
| --- | --- | --- |
| `ledgr_fact_knowledge_time()` | the one assume-effective rule for instants and labels | Two vectorised masks; no loop. `ledgr_fact_civil_json()` is removed, so no second copy of the rule remains. The corporate-action rule (`ledgr_corporate_action_assumed_knowledge()`) is a different decision (27) and is unchanged. |
| constructors (intervals, snapshots, status, lifetime, sessions) | call the rule above | No new work. The snapshot set-id `vapply`, `ledgr_fact_ids()` and `ledgr_fact_provenance()` now carry their route comments (first review N7). |
| `ledgr_fact_resolve_civil_families()` | sessions families checked | One more `vapply` over the bundle's families (bounded by family count, commented); one family hash per sessions family. |
| `ledgr_status_lineage()` | levels preallocated | Removes the append. The loop is still once per depth level. |
| `ledgr_fact_status_unrelated_overlap()` | comment only | The bound is stated and measured (F3). |
| `ledgr_corporate_action_entitled_subtypes()`, `ledgr_corporate_action_plan()` | dividend added; comments | Constant vector; no new loop. |

The census check reports 158 branch and 55 flow sites, unchanged from BASE,
so no execution-mode branch was added. Decision (35) needs none.

## Mutations (`ws45_rereview/mut`, restored after each)

| ID | Mutation | Files run | Result |
| --- | --- | --- | --- |
| O8 | snapshot headers not ordered (first review) | followups, availability-facts, snapshot-hash-rule4 | LTB-0360 fails |
| O8b | the same | fact-integrity oracles and persistence, sim-pit-inputs, availability-workflow | passes (LTB-0360 is the registered witness) |
| M1 | integrity check on pending families only (case D) | followups | LTB-0354 fails |
| M2 | `assume_effective` replaces every knowledge time | followups | LTB-0358 and LTB-0360 fail |
| M3 | dividend refusal only where dispositions act (not dense) | followups | LTB-0359 fails |
| M3b | unentitled dividend not carried into the successor window | followups | LTB-0359 fails |
| M4 | header order without the knowledge-time key | followups | passes (R2) |

The implementer's P1, P2, Q1, S1 and H1 are recorded in
`evidence/mutations.csv`. I did not re-run them, because M1 to M3b cover the
same blocks with different edits.

## Verification

Windows 11, R 4.6.1, sequential, on the `cand` copy of `8fc570b0`:

- Full suite (`pkgload::load_all()`, then `testthat::test_local(...,
  reporter = 'summary', stop_on_failure = FALSE, load_package = 'none')`):
  1,171 blocks, 20,473 expectations, 0 failed, 0 errors, 1 skip
  (`quantmod`), 11.6 min. This matches the closeout.
- `tools/check-codebase-contracts.R --mode=check`:
  `LEDGR_CODEBASE_CENSUS_OK` (helpers 1,840, findings 72) and
  `LEDGR_MODE_BRANCH_CENSUS ... branch_sites=158 flow_sites=55`.
  `--self-test-mode-branches`: `LEDGR_MODE_BRANCH_SELF_TEST_OK`.
- `tools/check-fold-phase-contract.R .`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.
- `tickets.yml` and `tests/claims.yml` parse.
- `git diff --check 4b33f377 8fc570b0`: clean.
- Not run: the fast, review and heavy profiles, and `R CMD check`. The
  closeout records Status OK on `6a3f8472`, whose code equals `8fc570b0`.
  The private Sharadar data was not touched.

## Review ratio

Two findings (R1, R2) over seven re-reviewed items (F1, F2, F3, F4, F5,
decision (32), decisions (33) and (35)): 2/7 = 0.286. Both are low and
need no correction round.
