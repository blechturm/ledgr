# WS45 / LDG-3073 close review (Type 1), `4b33f377..021aaa7f`

## Verdict: CHANGES_REQUIRED

One identity change is undeclared and needs the maintainer's disposition (F1).
One integrity gap remains (F2): a tampered sessions family can still be
re-signed into a resolved family. Three record and disclosure corrections
complete the list (F3-F5). The core rewrite is sound. Lineage, conflict
counting, civil resolution, integrity, mixed-clock validation, decision (27)
and decision (28) behave as the closeout says on every fixture I added, apart
from F1 and F2.

What holds:

- Full suite on a `git archive` copy of `021aaa7f`: 1,168 blocks, 20,459
  expectations, 0 failed, 0 errors, 1 skip (`quantmod`). This matches the
  closeout.
- Checks on the same copy:
  - census check: `LEDGR_CODEBASE_CENSUS_OK`, with 158 branch and 55 flow
    sites, unchanged from BASE (so no new execution-mode branch);
  - mode-branch self-test: OK;
  - fold-phase checker: `LEDGR_FOLD_PHASE_CONTRACT_OK`;
  - `tickets.yml` and `tests/claims.yml` parse.
- Lineage and conflicts:
  - the implementer's `diff_lineage.R` (5,000 forests) reproduces 0
    mismatches against BASE;
  - my `diff_deep.R` (3,000 sets: chains up to 60 rows deep, wider forests,
    mixed scopes; 1,967 refusals and 1,033 accepts) gives 0 lineage and 0
    conflict mismatches against BASE's functions.
- Identity probe. My own probe ran on fixtures the runner did not cover:
  - accepted and refused Date correction chains;
  - Date and POSIXct mixes in status, lifetime and corporate actions;
  - two venues, including an ambiguous date;
  - a DST boundary (US 2021-03-14);
  - audit-only and incomplete actions;
  - rebundles;
  - a sealed DST snapshot with a run.

  Every case is identical to BASE except:
  - F1;
  - one row of the declared "supplied POSIXct knowledge beside a Date event"
    shape (decision 27, item 5);
  - the decision (28) refusal;
  - refusals now raised at `ledgr_facts()` rather than in the constructor
    (item 4; N3).
- Decisions (27) and (28), checked by probe:
  - a Date event without knowledge is stored with knowledge at session open
    (14:30 UTC) and effective at close (21:00 UTC);
  - effective-only acquisitions and spin-offs refuse with
    `ledgr_corporate_action_entitlement_missing`, carrying fact, instrument,
    subtype and both clocks. This holds in a single run, in a sweep (as a
    FAILED candidate), in a two-fold chain and in a three-fold chain where
    the effective clock falls in window 1 and the knowledge clock in window 3.
    The chain refuses on the same fact and pulse as the single run;
  - a row whose clocks fall after the run's last pulse completes;
  - decision (23) code is untouched.
- Integrity: an edited exact family is refused by `ledgr_facts_assert()` with
  the same message with and without civil evidence (BASE accepted the second
  case). Edited pending families, edited metadata, edited resolved families
  and a resolved family stripped back to look pending are all refused. BASE
  accepted every one of these.
- Contract Point-In-Time Facts and the condition reference state decisions
  (27) and (28) in present tense. The macro plan records the settlement-state
  outcome.

What does not hold:

- F1 (blocking, LDG-3073 acceptance 1; brief "STOP if a hash must change for
  any other reason"). The membership-snapshot header order changes for
  inputs BASE accepted. The family hash and the bundle hash change with it.
  Neither decision (27) nor decision (28) covers this, and the closeout says
  no other hash changed.
- F2 (should fix, acceptance 2; review question 5). Resolution reads session
  families whose own hash it never checks. An edited sessions family is
  re-signed into the resolved family's new hash. That family then passes
  `ledgr_facts_assert()` in another bundle and seals.
- F3 (non-blocking, brief "Antipattern avoidance"). The related-pair chain
  walk does work proportional to the sum of all chain depths, which is
  quadratic in one chain's depth. The lineage level list grows by appending.
  The closeout calls both per-level and linear.
- F4 (non-blocking, contract present tense). `contracts.md` and a code
  comment still say a missing knowledge time "is decided with LDG-3073".
- F5 (non-blocking, record). The closeout says `git diff --check 4b33f377`
  is clean. It is not.

Review ratio: 5 findings over 6 LDG-3073 acceptance items = 0.833. Counted
per completed ticket (one, LDG-3073), it is 5/1.

## Method

- I read:
  - AGENTS.md and the approved brief, including its antipattern section;
  - LDG-3073 and Cut 16 decisions (11), (12), (23), (27) and (28);
  - `contracts.md` Point-In-Time Facts and Provider, Knowledge And Timing;
  - `cut16_antipattern_review.md` findings 11-15;
  - the seven shapes in `optimization_coding_style.qmd`;
  - the closeout, the whole product diff, the new test file, the claims and
    the bench scripts.
- I made `git archive` copies of BASE `4b33f377` and of `021aaa7f` under
  `scratchpad/ws45_review/{base,cand}`, compiled once, and a third copy
  (`mut/`) for mutations. Every R process ran sequentially.
- My scripts are in `scratchpad/ws45_review/scripts/`:
  - `identity_probe.R` and `compare.R`: 29 fact cases, 6 constructor cases
    and 2 sealed snapshots with runs, compared BASE against the candidate;
  - `probe_integrity.R`: edit and tamper cases A-D;
  - `probe_d28.R`: decision (27)/(28) single runs, three-fold chains, a
    sweep, unheld and out-of-universe parents, late clocks;
  - `diff_deep.R`: a deep-chain differential of lineage and conflicts
    against BASE's functions;
  - `mutate.py` with `run_tests.R`: the mutations;
  - `scale_probe.R` with `run_scale.ps1`: disclosure-only timing under the
    High performance plan with affinity `0xFFFF`;
  - `fixprobe_f2.py`: the F2 fix, checked.

## Findings

### F1 (blocking, identity): snapshot header order changes hashes BASE accepted

Verified facts (`identity_probe.R`, cases `snap_date_knowledge_assume` and
`snap_mixed_assume`; both trees accept both inputs):

- Input A is `ledgr_facts_membership_snapshots(..., knowledge =
  "assume_effective")` with:
  - a POSIXct `effective_from` of 2021-01-05 10:00 UTC for two sets;
  - set `set_x` with no knowledge time, so it assumes 10:00;
  - set `set_y` with a Date knowledge of 2021-01-05, a placeholder of 00:00
    that resolves to 14:30.

  BASE orders the headers `set_y, set_x` (placeholder 00:00 before 10:00).
  The candidate orders them `set_x, set_y` (10:00 before 14:30). The family
  hash changes from `d1d982f8...` to `854780c7...`, and the bundle hash from
  `510cdabe...` to `c7c80979...`.
- Input B is a Date `effective_from` with a POSIXct `knowledge_time`
  supplied per set (23:00 for `set_a`, 12:00 for `set_z`), under
  `assume_effective`. The retained civil-label rule (the closeout's routed
  question) moves both knowledge times to the 14:30 session open, so the
  headers tie and fall back to `set_id`. The family hash changes from
  `bef3eda6...` to `e7a76f17...`.
- The ordering comes from `ledgr_fact_family_settle()`
  (`R/availability-facts.R:1293-1299`). After resolution it orders headers by
  `knowledge_time`. A knowledge column filled by an assumption, or relabelled
  by the assume-effective civil label, mixes instant sources even when the
  input column has one type.
- The closeout says otherwise:
  - lines 125-128: "Ordering on resolved instants equals BASE's placeholder
    order whenever each sort column holds one type ... the identity
    comparison below confirms it on every fixture";
  - line 212: "No other hash changed";
  - LDG-3073 evidence: "exactly seven intended differences".

  The runner has no snapshot-shaped family with two sets sharing an
  effective time.

Inference: the candidate order is the one item 4 asks for (resolved
instants). The hash change is therefore a consequence of the ticket's own
scope rather than a coding slip. But acceptance item 1 allows hash changes
only "where a recorded decision changes them", and the brief says to stop and
report. That makes it a maintainer disposition, not a reviewer one.

Smallest fix:

- put input A (and B, or B under the routed question) in `compare_runner.R`
  as a declared intended difference;
- correct closeout lines 125-128 and 212 and the LDG-3073 evidence;
- obtain and record the maintainer's disposition. Either accept item 4
  ordering as a recorded hash change, or keep placeholder order for headers,
  which would contradict item 4;
- register a header-order witness (input A) in the reserved range. Mutations
  O8 and O8b show that no registered block detects dropped header ordering.

### F2 (should fix, integrity): resolution re-signs instants from an unchecked sessions family

Verified facts (`probe_integrity.R` case D, candidate):

- Shifting a sessions family's `session_open` by one hour after
  construction, then calling `ledgr_facts(edited_sessions, date_membership)`,
  is accepted.
  - `ledgr_fact_resolve_civil_families()` checks the hash only of pending
    families (`R/availability-facts.R:1114`). It then reads every session
    family (`:1120`) and rehashes the resolved family.
  - The bundle itself is refused later by `ledgr_facts_assert()`, because the
    sessions family is edited.
- The resolved membership family carries the tampered instant
  (`effective_from` 13:30 instead of 14:30 UTC), and
  `ledgr_fact_family_intact()` is TRUE for it.
- Taken out and rebundled with the untouched sessions family,
  `ledgr_facts(sessions(), laundered)` passes `ledgr_facts_assert()`, and
  `ledgr_snapshot_from_df()` seals it.
- BASE is worse here: it re-signs the edited sessions family as well.
- With the one-line fix below applied to a copy (`fixprobe_f2.py`), case D
  is refused at `ledgr_facts()` and every other case is unchanged.
  `test-fact-pipeline-followups.R` and `test-availability-facts.R` (19
  blocks) pass.

Inference: whether an edit to one family can be laundered still depends on
bundle composition (a pending family beside it). That is the property item 3
and review question 5 ask to remove. It requires deliberate edits of
internals, so it is not blocking.

Smallest fix: check the recorded hash of every family resolution reads,
pending families and session families alike. For example, check
`pending | family == "sessions"` before `ledgr_fact_civil_sessions()`. Add
case D to LTB-0354.

### F3 (non-blocking, antipattern disclosure): the chain walk is quadratic in chain depth

Verified facts:

- In `ledgr_fact_status_unrelated_overlap()` (`R/availability-facts.R:2511-2521`),
  each iteration moves every remaining descendant one link up its chain. The
  loop runs for the deepest chain's length. Its total vector work is the sum
  over rows of their depths, which is D(D-1)/2 for one chain of D
  corrections.
- `ledgr_status_lineage()` grows `levels` by appending (`:2274`). The style
  manual's rule is "Never grow a vector or list by appending."
- Scale (disclosure only; `run_scale.ps1`; one fresh process per point;
  candidate unless BASE is named). The validator is the whole
  `ledgr_fact_validate_status_rows()`, on one instrument with a single
  correction chain of D rows:

  | D | lineage | validator |
  | ---: | ---: | ---: |
  | 2,000 | 0.03 s (BASE 0.04) | 0.11 s (BASE 1.33) |
  | 8,000 | 0.12 s (BASE 0.44) | 1.11 s |
  | 32,000 | 0.45 s | 14.02 s |

  Lineage is linear in depth. The validator grows 10 to 12.6 times per 4
  times the depth.
- The closeout's seven-shape row (line 265) says the walk "runs once per
  depth level and visits each ancestor pair once". Line 239 says validation
  "grow[s] linearly with fact rows". Both statements hold only for a bounded
  depth; the scale fixture uses depth 2.

Inference: real correction chains are short, and BASE paired every
correction row with its whole scope, so this is no regression. The brief
still requires every remaining loop's cost to be stated and no pairwise
validator to remain.

Smallest fix:

- state the O(sum of depths) bound in the code comment and the closeout,
  with a deep-chain scale point;
- preallocate `levels` (at most `count` entries) instead of appending.

Counting related pairs in O(n log n) is possible (preorder intervals plus an
offline sweep), but a stated bound is enough for this ticket.

### F4 (non-blocking, contract present tense): a forward reference to LDG-3073 remains

Verified facts:

- `contracts.md:932-937` (Provider, Knowledge And Timing) says "what a
  missing knowledge time should mean is decided with LDG-3073".
- `R/availability-provider.R:279-282` says the same.
- LDG-3073 is complete. Decision (27) states that decision (23)'s refusal
  "is unchanged".

Smallest fix: replace both with the present-tense rule, for example: "Cut 16
decision (27) keeps this refusal; corporate actions follow the
known-when-effective rule in Point-In-Time Facts."

### F5 (non-blocking, record): `git diff --check` is not clean

Verified fact: `git diff --check 4b33f377 021aaa7f` reports trailing
whitespace on 21 lines of
`dev/bench/v0_2_2_fact_pipeline_followups/evidence/compare_result.txt`
(lines 1-18 and 25-27). The closeout (lines 377-378) says the check is
clean.

Smallest fix: write `compare_check.R` output without padding, or strip the
evidence file, and rerun the check.

### Notes (no change required)

- N1. Decision (28) also changes dense runs. An effective-only stock
  acquisition completed silently at BASE and now refuses (LTB-0357's dense
  case). This follows decision (11)'s reasoning (no mode branch), and the
  contract says "in every execution mode". Decision (28) itself does not
  mention dense, so the maintainer may want to confirm it at acceptance.
- N2. The decision (28) refusal does not depend on holdings or universe. A
  parent with zero position, or one outside the experiment's universe, still
  refuses the run (`probe_d28.R` case 4). This matches the pre-existing
  `ledgr_corporate_action_clock_missing` rule and the unconditional decision
  text. A snapshot-wide data defect therefore blocks every run spanning its
  pulse.
- N3. Constructors no longer refuse Date-input defects such as intervals,
  conflicts, supersession and clock order. `ledgr_facts()` refuses them with
  the same class and message (all bundled refusal cases are identical to
  BASE). Two side effects:
  - a Date row with both an invalid interval and an identity conflict now
    reports the identity conflict first;
  - vectorised supersession checks report the first failing category across
    all links, not the first failing link.

  Both follow from item 4. The closeout discloses the interval case.
- N4. The ticket scope says to implement known-when-effective once "after
  resolution". The rule runs once, in the constructor, and its Date instants
  come from the resolver. The closeout's reason (fact IDs hash the assumed
  knowledge) is sound, and acceptance item 4 is met.
- N5. The Point-In-Time Facts sentence "Availability-aware Date boundaries
  resolve to session open for starts and session close for ends"
  (`contracts.md:667-668`) reads as if exclusive fact ends resolve to the
  close. The code, the H2 register (PIT-S2-011: exclusive ends resolve to the
  open) and the new LTB-0355 witness use the open. The wording predates this
  workstream, but WS45 edited that paragraph and could make it say "window
  ends".
- N6. `NEWS.md` has no entry for the new refusal class, the decision (27)
  timing or the mixed-clock acceptance and refusal changes.
- N7. The per-row constructor helpers (`ledgr_fact_ids()` with one-row
  frames, `ledgr_fact_provenance()`, the set-id `vapply`) are routed in the
  closeout to LDG-3080/F05. They carry no in-code reason comment, because the
  functions themselves did not change.
- N8. Inference only: two venues with disjoint calendars could map civil
  dates to instants out of date order, for example Honolulu and Auckland on
  adjacent dates, and so reorder a family on resolution. My two-venue
  fixture stayed identical, and I did not build an inverting one.
- N9. Under `assume_effective`, the closeout routes the civil-label copy that
  replaces supplied POSIXct knowledge. F1's input B shows that the same copy
  also drives a hash change once ordering runs on resolved instants.

## Acceptance items

| Item | Result |
| --- | --- |
| 1 linear scaling at 100,000 rows, before/after, identity except recorded decisions | scaling met for the stated fixtures (reproduced); identity not met (F1); depth bound undisclosed (F3) |
| 2 edited family refused identically with or without civil evidence | met for edited families; sessions-derived laundering remains (F2) |
| 3 mixed Date/POSIXct on resolved instants, registered witnesses | met (LTB-0355; V1 and O5 detect) |
| 4 one known-when-effective rule following decision (27) | met (LTB-0356; K1, O3 detect; N4) |
| 5 effective-only rows follow decision (28) in a single run and the carried chain | met (LTB-0357; D3, O4 detect; three-fold chain probed) |
| 6 focused and full suites pass, detectors mutation-checked | met (full suite reproduced; mutations below) |

## Mutations (on `scratchpad/ws45_review/mut`, restored after each)

The copy has CRLF line endings from `git archive`. Multi-line anchors were
re-run with CRLF-aware matching after a first pass found no anchor.

| ID | Mutation | Files run | Result |
| --- | --- | --- | --- |
| L1 | implementer's: siblings numbered out of preorder | followups | LTB-0351 fails |
| C3 | implementer's: touching half-open intervals overlap | followups | LTB-0352 fails |
| R1 | implementer's: resolved instants formatted per row | followups | LTB-0353 fails |
| I1 | implementer's: every bundle family rehashed | followups | LTB-0354 fails |
| V1 | implementer's: clock order checked before resolution | followups | LTB-0355 fails |
| K1 | implementer's: supplied knowledge replaced (label mask) | followups | LTB-0356, LTB-0357 fail |
| D3 | implementer's: unentitled row not carried | followups | LTB-0357 fails |
| O1 | integrity check on non-pending families instead of pending | followups | LTB-0354 fails |
| O2 | ancestor walk stops after one link | followups | LTB-0351, LTB-0352 fail |
| O3 | assumed knowledge keeps no civil label (UTC midnight) | followups | LTB-0356 fails |
| O4 | decision (28) refusal at the effective pulse, ignoring knowledge | followups | LTB-0357 fails |
| O5 | exact-interval check when either bound is exact | followups | LTB-0355 fails |
| O6 | ambiguous supplied link ids rewritten to the first match | followups, availability-facts, validator-sweeps | passes; equivalent: a repeated (supplied id, source) yields one canonical `fact_id`, so either target rewrites identically |
| O7 | post-resolution settle dropped (no validation or order for Date families) | followups, availability-facts, equity-corporate-action-facts | LTB-0351, LTB-0355 fail |
| O8 / O8b | snapshot headers not ordered | followups, availability-facts, snapshot-hash-rule4; fact-integrity oracles and persistence, sim-pit-inputs, availability-workflow | passes all; header order has no registered witness (F1 fix) |
| O9 | decision (28) subtypes without `spin_off` | followups | LTB-0357 fails |
| O10 | carried row dropped once its effective clock is the window's first pulse | followups; also my three-fold probe | passes both; no behaviour change observed, so likely equivalent for these fixtures |

## Verification record

Windows 11, R 4.6.1, sequential:

- Full suite on `cand` (`pkgload::load_all` then `testthat::test_local(...,
  stop_on_failure = FALSE, load_package = "none")`): 1,168 blocks, 20,459
  expectations, 0 failed, 0 errors, 1 skip, 11.9 min.
- `tools/check-codebase-contracts.R --mode=check`:
  `LEDGR_CODEBASE_CENSUS_OK` (findings 72; 158 branch and 55 flow sites).
  `--self-test-mode-branches`: OK.
- `tools/check-fold-phase-contract.R .`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.
- `tickets.yml` and `tests/claims.yml` parse.
- `git diff --check 4b33f377 021aaa7f`: 21 trailing-whitespace lines (F5).
- The new test file run against the BASE copy: LTB-0351, 0353, 0354, 0355,
  0356 and 0357 fail and LTB-0352 passes, as the closeout states.
- Scale at the brief's sizes (disclosure only; same method; fixtures from
  `scale_fixtures.R`):

  | Stage | 100,000 | 400,000 | Ratio |
  | --- | ---: | ---: | ---: |
  | lineage | under 0.01 s | 0.03 s | |
  | status validation, chain depth 2 | 0.11 s | 0.64 s | 5.8 |
  | status validation, chain depth 5 | 0.22 s | 0.83 s | 3.8 |
  | civil resolution (Date membership) | 1.56 s | 5.71 s | 3.7 |
  | family hash (POSIXct membership) | 0.23 s | 1.02 s | 4.4 |

  These reproduce the closeout's linear shape and magnitudes; the
  closeout's scale table uses the resolved Date family for hashing. The
  power plan and affinity are in `ws45_review/scale.csv.conditions.txt`.
- Lineage differential `diff_lineage.R` (5,000 sets): 0 lineage and 0
  conflict mismatches.
- Test changes: none to registered tests, fixtures or oracles. LTB-0351..0357
  are new, with claims LCL-0341..0347, inside the reserved ranges
  (LCL-0341..0360, LTB-0351..0370).
- R CMD check was not re-run. The closeout records Status OK on a copy of
  `1793d1f3`, whose code equals `021aaa7f`.
