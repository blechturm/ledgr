# WS46 / LDG-3074..3077 close review (Type 1), `b9d098c8..303ded9c`

## Verdict: CHANGES_REQUIRED

Most of the simplification holds. The substrate drops the four diagonal
planes, the two restating bar planes, the unread fields, the provider
`history` closure, the duplicate session calendar and the staged
`precomputed_features`. Membership and trading-status segments are counted,
not stored. The indicator catalogue is built once per session.

On every fixture both runners built, results are byte-identical to BASE
`b9d098c8`:

- The implementer's runner, re-run on my own copies: 84 of 84 families.
- My own probe: 63 families, with scenarios the runner lacks.

Membership and status counts and segment-guard refusals equal BASE's on 828
adversarial families (4,116 evaluations, 1,632 refusals, no mismatch). The
census, the fold-phase checker and the full suite pass. Each re-run detector
mutation fails its block.

Three findings block acceptance:

- F1: byte identity does not hold for a legal input class. A snapshot whose
  trading-status or lifetime fact has no knowledge time behaves differently
  from BASE.
- F2: `contracts.md` still binds the provider `history` operation, which
  LDG-3075 removed.
- F3: the surviving same-clock membership counter does not agree with the
  canonical two-clock count. Its only registered differential compares it
  with its own frozen predecessor, so the gap is not recorded. Changing the
  counter would change refusals, which decision (22) forbids, so F3 needs a
  maintainer disposition.

The other findings are claim corrections, detector gaps and record text.

The verdict is not NEEDS_TYPE_2. Decision (22) settles that refusals stay
as they were. F3 only asks the maintainer to keep or align a divergence that
the map and closeout must first record.

Method:

- Read the inputs:
  - AGENTS.md, the Cut 16 decisions (1)-(22) and the 2026-10-17 sticky
    barrier route;
  - WS46 and LDG-3074..3077 with their acceptance items;
  - `history_representation_map.md` and
    `history_simplification_closeout.md`;
  - the Provider, Knowledge And Timing contract and the style manual's
    fast-path rule;
  - the whole product and test diff, including the earlier commit
    `d4d13c55`.
- Built source copies of the candidate (`git ls-files`) and of BASE
  (`git archive b9d098c8`), compiling each once, sequentially, before any
  two-worker run.
- Re-ran the implementer's runner on these copies after reading it for
  blind spots: 84 of 84 identical, no retries, no error families. Blind
  spots:
  - No family has facts without a knowledge time (F1).
  - The only corporate action sits inside a training window, so no carried
    walk-forward boundary crosses one.
  - No fixed character-vector universe on an availability snapshot.
  - Refusals are recorded only for run, sweep and inspection, not for
    precompute, walk-forward or window.
- My probe `e2e.R` (scratchpad `ws46_review/probes/`) adds:
  - two relisting cycles on one instrument under decision (20), and a
    lifetime fact learned after the data end;
  - status supersession and precedence conflicts, and a decoy universe;
  - `price_carry = 3` with `output_carry = 2`;
  - a carried walk-forward whose dividend entitlement falls in fold 1's test
    window and its payment in fold 2's;
  - explicit precompute and precomputed sweeps, sequential and two-worker,
    and a two-worker walk-forward;
  - an INCOMPLETE run, reopened and reconstructed;
  - seven inspected pulses;
  - the substrate census, provider facts at every pulse, and expected and
    terminal planes at five cutoffs;
  - a fixed-universe run and an interval-only universe;
  - segment-limit refusals 1 to 7 for run, sweep, precompute, walk-forward,
    window and inspection, which refuse on membership, trading status and
    lifetime.
- Result: 63 of 63 families identical. Four strategy-error messages differ
  only in the source-copy path that rlang prints, `base/R` against `cand/R`.
- Counts: `count_gen.R`, `count_eval.R` and `count_cmp.R` evaluate 828
  families on both trees, comparing every count, ratio and limit and every
  refusal's class, message and fields at the default limit and at limits 1
  to max + 1. The families cover:
  - complete, incomplete, interval-only, same-clock, lagged-mixed and
    leading-knowledge membership;
  - same-clock ties between headers whose `set_id`s differ in case;
  - two universes, and instruments outside the universe or with no facts;
  - knowledge after the axis end, and up to 120 sets;
  - multi-fact status with supersession.
- 17 mutations on a source copy, each restored byte for byte (table
  below).
- Full suite once on the candidate copy. Census `--mode=check` and
  `--self-test-mode-branches`, and `tools/check-fold-phase-contract.R`.
  `tools/codebase-structure.R`'s scanner run on both trees.
- Timings and sizes are disclosure only. Settings: High performance plan,
  PowerShell affinity `0xFFFF`, `Rscript.exe` by full path. The scaling
  runs were not alternated with BASE; BASE has no counter.

## Findings

### F1 (blocking, byte identity): facts without a knowledge time no longer behave as on BASE

The fact constructors accept trading-status and lifetime rows with no
`knowledge_time`. With the default `knowledge = "evidenced"` they store
`NA` (`R/availability-facts.R:1543-1549`). Such rows seal into a snapshot,
and ingest audits them as `knowledge_time_missing`
(`R/availability-ingest.R:373`).

On BASE, availability preparation of such a snapshot stops in
`ledgr_history_segments_diagonal_state()`. The error is an unclassed
`simpleError`, "missing value where TRUE/FALSE needed", at
`if (from <= to)` (BASE `R/history-substrate.R:1767`). LDG-3075 removed that
function, so the candidate behaves differently.

Evidence:

| Probe | BASE `b9d098c8` | Candidate `303ded9c` |
| --- | --- | --- |
| `na_status.R`: one status fact with no knowledge time, no features | `simpleError` at preparation | the run completes (25 equity rows, 75 availability rows; status resolves `unknown` at every pulse, so the fact is never applied) |
| `na_nofeat.R`: also one lifetime fact with no knowledge time, no features | `simpleError` at preparation | `ledgr_strategy_error` wrapping `subscriptOutOfBoundsError` at the strategy's first history read |
| `na_knowledge.R`: the same with one SMA feature | `simpleError` at preparation | `subscriptOutOfBoundsError` during feature preparation |

The candidate failure is in `ledgr_history_segments_materialize()`
(`R/history-substrate.R:1351`), reached through
`ledgr_history_substrate_expected_at()` and
`ledgr_history_substrate_fact_plane()`. The lifetime segment carries
`knowledge_from = NA` (`na_where.R`). This defect is pre-existing in both
trees; BASE never reached it because it failed earlier.

Counts are unaffected: `na_counts.R` shows identical counts on both trees
for membership, interval and status families with `NA` knowledge times.

The closeout states byte identity for run, sweep, window, walk-forward,
inspection and history reads. Neither runner has such a fact. LDG-3075
requires byte identity, and this input class is not byte-identical.

Smallest fix:

- Record the difference in the closeout.
- Get a maintainer disposition. On BASE the input failed with an internal
  error, so no behavior-preserving option exists.
- The probable intent is that an unknown knowledge time means the fact is
  never known. The provider plan already treats it that way: the
  status-only run completes with the fact never applied. If that is the
  intent, make lifetime segments with `NA` knowledge mean "never known" in
  `ledgr_history_segments_materialize()` (and its late-epoch readers), or
  refuse such facts at preparation with a classed condition.
- Add one such fixture to the identity runner and a registered block.

### F2 (blocking, contract): the provider is still bound to a `history` operation

`inst/design/contracts.md:872-873` (Provider, Knowledge And Timing, present
tense) says: "Availability-aware execution uses one internal provider with
`facts`, `decision_view`, `execution_view`, `history`, and `identity`
operations."

LDG-3075 removed `history` from all three provider builders, and LTB-0332
asserts it is absent. The workstream edited the next-but-five bullet of the
same section but left this one, so the binding contract now disagrees with
the code.

Smallest fix: drop "`history`," from that bullet.

### F3 (blocking pending maintainer disposition): the same-clock membership counter is not the canonical two-clock count, and its only differential is against itself

LDG-3076's amended scope names the same-clock membership compiler as a
surviving fast path that needs a registered differential against its
canonical resolver. Its acceptance item 2 is "every remaining compiler path
has a registered randomized differential against its canonical resolver
named in the map, with no mismatch".

After decision (22), the same-clock path is
`ledgr_history_membership_diagonal_counts()` (`R/history-substrate.R:1039`),
selected at `:1123`. Its only differential is LTB-0335 against the frozen
BASE same-clock compiler (M-4), that is, against its own predecessor.

Evidence: `diag_canon.R` takes the frozen BASE dispatcher with the diagonal
branch disabled, so same-clock families go through BASE's canonical,
resolver-based compiler (M-6). It runs on 325 header-only same-clock
families, which the public API can store:

- the production counter differs from M-6 on 111 families;
- `ledgr_history_membership_fact_counts()` differs on none.

`diag_vs_fact.R` adds two facts:

- The disagreement is one-sided. In 349 instrument counts the production
  count is lower and in none is it higher.
- It needs two or more headers whose effective times fall between the same
  two sessions. All 31 families whose effective times sit on session closes
  agree.

Example: complete sets `v` at 20:00 and `x` at 21:00 on one day, with the
21:00 session close. At knowledge cutoffs between 20:00 and 21:00, `v` is
the two-clock answer for that column. The diagonal never sees it, so the
counter omits that segment.

The counter therefore undercounts against the canonical rule. A declared
`segment_limit` can admit a same-clock family whose canonical segment count
exceeds it, which is fail-open. AGENTS.md says that "divergence fails closed
pending an RFC".

The behavior is inherited: BASE's M-4 did the same, and the map recorded
"Differential oracle: none". Decision (22) ("refuses exactly as before")
forbids changing it here. But the closeout and map present the counter as
"BASE's per-break rule" and never record that it differs from the canonical
count.

Smallest fix:

- Record the divergence in the map (an M-4 successor row with canonical
  status, differential and removal condition) and in the closeout.
- Add the canonical comparison to LTB-0335 as a disclosed known difference,
  or as a test that fails once aligned.
- Route the choice to the maintainer:
  - keep the divergent same-clock count as an owned exception; or
  - delete `ledgr_history_membership_diagonal_counts()` and count every
    shape with `ledgr_history_membership_fact_counts()`. That is canonical,
    one path, and fail-closed, but refusals change for these families.

### F4 (non-blocking, claim): the counter is not linear in incomplete sets

The closeout (LDG-3076 section) and the ticket evidence say:

- the counter grows "in proportion to sets times instruments";
- "doubling either sets or instruments about doubles the time".

The shape-walk says the counter is linear. In
`ledgr_history_membership_fact_counts()`, each instrument loops over its own
incomplete headers (`:1004`), and each step is a vector operation over
complete plus own headers. The cost is O(N x S_own x (C + S_own)), quadratic
in sets per instrument. The recorded grid stops at 320 sets, where the
per-iteration R overhead hides the quadratic term.

My `scale.R` at 300 instruments, one run each:

| Shape | 320 sets | 640 sets | 1,280 sets | 2,560 sets |
| --- | ---: | ---: | ---: | ---: |
| Incomplete, half listed | 0.34 s | 0.77 s | 2.17 s | 8.47 s |
| Complete | not run | 0.02 s | 0.10 s | 0.11 s |

From 1,280 to 2,560 sets the time rises 3.9 times. Set rows rise 2 times
(192,000 to 384,000). On the incomplete shape, the counter's cost therefore
grows superlinearly in fact rows.

This is still far below BASE's M-6 (22 s at 80 sets). The complete-set path
is fine, and H1 uses complete sets. The `for (y in complete)` loop is
O(C x H), which is harmless at H1's 580 sets.

Smallest fix: correct the claim to the measured range and the stated
complexity. If the maintainer wants the incomplete lagged shape linear,
route an O(S log S) next-blocking-header computation.

### F5 (non-blocking, detector independence): LTB-0335's status half cannot see a change in the shared status compilers

LCL-0325 claims: "Expected counts and refusals come from verbatim copies of
the removed BASE compilers ... the package's counting code is not consulted
for the oracle."

The frozen copies are verbatim, which I checked with `frozen_cmp.R`: six of
six functions identical after normalization. But
`history_reference_status_segments()` calls the live package compilers
`ledgr_history_sparse_fact_segments()` and
`ledgr_history_fact_segments_by_instrument()`. The candidate's status
counter calls the same two functions. For status, oracle and product
therefore share their counting code.

Mutation X16 changes the sparse compiler's default floor from 16 to 15
(`R/history-substrate.R:684`). That changes every one-fact status limit and
default refusal. It survives LTB-0335, LTB-0291 and LTB-0334.

The status code is unchanged from BASE, so this is a detector gap, not a
current defect.

Smallest fix:

- Correct LCL-0325's `oracle_independence` for status.
- Add a literal status-limit witness (default `max(4 * facts, 16)` on a
  one-fact and a multi-fact instrument).
- Optionally, route the three copies of the guard formatter to one
  function, `ledgr_history_segment_limit_check()`. The copies are in the
  sparse compiler, the per-instrument compiler and `:859`.

### F6 (non-blocking, record): the map's path tables are stale and the new paths have no rows

`history_representation_map.md` Sections 1 and 2 still present M-3, M-4,
M-6, S-2 and S-4, R12a-d and R16's membership and status families as
current. Section 7 corrects this in prose only.

The style manual's new rule says that "a change that adds a history fast
path or representation adds its row there". Three items have no row:

- the counted `segment_counts` representation;
- the membership fact counter;
- the same-clock counter (see F3).

None of them has a canonical or fast-path status, a differential or a
removal condition.

Smallest fix: update the rows, or mark Sections 1-2 as the BASE inventory,
and add rows for the three new items.

### F7 (note): parameters and conditions with no observable effect

- `header_method` in `ledgr_history_membership_fact_counts()` (`:1117`)
  only orders tied headers. A tie gives the lower-ranked header an empty
  region, so the count cannot depend on it. Mutation X14 (radix to auto)
  survives LTB-0335. On my 828 families, including 117 with tied header
  clocks and case-differing `set_id`s, all-radix and all-auto both match
  BASE exactly.
- `previous_keep &` in the same-clock counter (`:1079`) is redundant
  (mutation X3 survives). If the answer is equal to the previous one, the
  current cell has the same keep status. The implementer's Q3 (the
  knowledge comparison) is likewise equivalent.
- These can be dropped or kept. The closeout's "path selection is BASE's,
  including radix header order" describes code with no effect on the
  count.

### F8 (note): the test name and the "mixed" shapes

- `test-availability-provider-production.R:184` is still named
  "INCOMPLETE reopen builds one prepared provider plan" but now asserts
  zero.
- Inference, not exhaustively verified: `ledgr_facts()` refuses a second
  membership family for one universe ("Fact family scopes must be unique").
  The public API therefore cannot store set headers and interval rows in
  the same universe. If so:
  - the interval cover on header regions in the fact counter only serves
    internally built data (`ledgr_history_uncovered_pieces()` for headers,
    mutation Q2);
  - so do the "mixed" shapes of LTB-0334 and LTB-0335.
- The historical spike probes `dev/spikes/historical-projection/probe.R` and
  `dev/spikes/two-clock-history/probe.R` call the removed
  `ledgr_availability_provider_portable()`. They are not part of any gate.

## Acceptance items

| Item | Result |
| --- | --- |
| 3074-1 map lists every representation and path, linked from README | Met for BASE; see F6 for the post-change rows |
| 3074-2 census records per-file mode branches; self-test fails on an added branch | Met. Check mode OK. My scan of BASE and candidate gives the same 213 keys (158 branch, 55 flow). R-LTB0331 (an added `availability_active` branch) fails LTB-0331. |
| 3074-3 fast-path rule in the style manual, referenced by briefs | Met |
| 3075-1 byte identity; ladder exact; full suite passes | Not met for facts without a knowledge time (F1). Met on every other probed family. Suite passes. Ladder not re-run. |
| 3075-2 detector fails if a second fact form or removed plane returns | Met. R-M6 and R-M9 fail LTB-0332. |
| 3075-3 sizes before/after | Met. Reduced shape (200 x 1,000, `sizes.R`): substrate 16.7 to 10.0 MB object, 17.1 to 10.0 MB serialized (-40% / -42%), in line with the H1 -43% / -42% |
| 3075-4 seven shapes walked | Walked. F4 corrects the linearity statement. |
| 3075-5 removed items absent and guarded; test changes with reasons | Met (see Test changes) |
| 3076-1 remaining compilers with production callers | Met |
| 3076-2 randomized differential against the canonical resolver, no mismatch | Not met for the same-clock counter (F3). Met for L-2, L-3, T-1, L-4, S-3 and M-2 (R-P5 fails LTB-0334), and for the fact counter against the canonical compiler (`diag_canon.R`: 0 of 325) |
| 3076-3 M-6 absent or replaced, with a detector | Met. M-6 is absent and LTB-0332 lists it. |
| 3076-4 ladder exact, full suite passes | Suite passes. Ladder not re-run. |
| 3077-1 built once per session, content identical | Met. `catalogue.R`: catalogue, 48 rows, 3 misses, 9 constructed indicators and their fingerprints serialize identically on both trees. |
| 3077-2 constructors, fingerprints and digests unchanged | Met |
| 3077-3 detector fails if a constructor rebuilds | Met. R-N2 fails LTB-0333 (3). |
| 3077-4 fast profile LTB-0142/0143 timing | See Timing |

## Mutations (source copy, restored byte for byte)

| ID | Mutation | Block | Result |
| --- | --- | --- | --- |
| M0 | none | LTB-0291, 0331, 0332, 0333, 0334, 0335 | 447, 11, 40, 6, 91, 510 expectations; none failed |
| R-M6 | provider gains a `history` member | LTB-0332 | fails (1) |
| R-M9 | derived-state marks calendar builds a provider again | LTB-0332 | fails (1) |
| R-N2 | catalogue index never stored | LTB-0333 | fails (3) |
| R-P5 | prepared cursor treats every header as complete | LTB-0334 | fails (24) |
| R-Q2 | header regions ignore interval cover | LTB-0335 | fails (15) |
| R-LTB0331 | unrecorded `if (!availability_active)` in `R/sweep.R` | LTB-0331 | fails (census error) |
| X1 | interval cover ignores knowledge order | LTB-0335 | fails (2) |
| X3 | drop `previous_keep &` in the same-clock counter | LTB-0335 | survives: equivalent (F7) |
| X7 | a complete header blocked at its own break still counts | LTB-0335 | fails (25) |
| X9 | disable the same-clock branch | LTB-0335 | fails (23) |
| X10 | interval-only instruments use the shared count | LTB-0335 | fails (68) |
| X12 | refuse on the last exceeding instrument | LTB-0335 | fails (75) |
| X13 | count status before membership in the substrate | LTB-0335 | fails (2) |
| X14 | `header_method` radix to auto | LTB-0335 | survives: equivalent (F7) |
| X15 | knowledge level uses `left.open` | LTB-0335 | fails (4) |
| X16 | sparse-compiler default floor 16 to 15 | LTB-0335, 0291, 0334 | survives all three (F5) |
| X17 | per-instrument-compiler default floor 16 to 15 | LTB-0335 | fails (24) |

## Test changes

- LTB-0291 reads its two-clock membership and status literals from the
  frozen BASE compilers. `frozen_cmp.R` shows those are verbatim BASE after
  normalization. Every literal is unchanged, and the block also asserts
  that the substrate's counts equal the reference counts. Production has no
  two-clock membership or status reader left, so the moved literals now
  certify the oracle, not the product. That is sound for byte identity and
  hides nothing current, apart from F5's shared status code. The diagonal
  `halted`, missing-bar and inactive-print literals now read the provider's
  diagonal and the two-clock lifetime primitive, with the same values.
  Valid.
- LTB-0285 and LTB-0288, the witness helper and the query-order block lose
  only the removed fourth argument. Valid.
- LTB-0332's expected names follow decision (22). Valid.
- Unregistered tests:
  - Causality: the expected provider names drop `history`, and the
    closure's row count goes with it. Valid.
  - The ws8 marks oracle runs the same SQL in a test helper, with the same
    parameters, so its input is unchanged. Valid.
  - INCOMPLETE reopen expects 0 builds instead of 1, which is stricter.
    Valid apart from the stale name (F8).

## Removals: consumers on BASE

Each removed plane, field and function was searched in BASE's `R/`,
`tests/`, `vignettes/`, `dev/` and `tools/`, and every hit was read.

- The four diagonal planes, `gap_type`/`is_synthetic` planes,
  `ledgr_history_substrate_bar_frame()`, `_instrument_frame()`,
  `_history_reader()`, the substrate `families`/`universe_rule`/
  `valuation_policy` fields and the five compilers had only tests or their
  own file as readers. `inactive_print` in `R/history-frame.R:241` is a
  local variable.
- `provider$history` was read only by two tests.
- `ledgr_availability_provider_portable()` was called by window validation
  and two historical spike probes (F8).
- `precomputed_features` in the task and invariant was passed through three
  signatures and never read (BASE `R/sweep.R:1576-1760`). The worker stage
  restores tasks from the invariant by field list, which no longer has it.
- Production segment readers (`R/history-features.R:413`,
  `R/history-frame.R:34,69`, the materializer) read only `lifetime` and
  `lifetime_terminal`.
- The session-only readers' providers were used only for `$sessions`:
  `ledgr_availability_calendar()`, `_run_calendar()`, `_require_coverage()`
  and `ledgr_derived_state_availability_pulses()`. `plan$sessions` was
  `data$sessions`, the same query as `ledgr_availability_session_source()`.
- The `ctx$bars` `gap_type`/`is_synthetic` derivation matches every
  substrate bar source. The runner selects constant `'NONE'`/`FALSE`, and
  the precompute fetch selects neither.

## Clean

- Mode branches: none added or removed. The census check passes, and the
  candidate scanner gives identical keys on BASE and the candidate.
- LDG-3077 cache: `.ledgr_indicator_catalogue_cache` lives in the
  namespace. `load_all()` and package load create a fresh environment. The
  catalogue is a pure function of package code with no options, user
  registrations or optional packages. Each mirai daemon builds its own.
  Rows and digests are identical (`catalogue.R`). The hashed body of
  `ledgr_indicator_history_catalogue()` is unchanged.
- Seven shapes on the changed preparation code:
  - The removed planes eliminate a per-instrument, per-segment R loop (shape
    5) and twice-per-pulse packet copies.
  - The counters loop over complete headers, touched instruments, own
    headers and per-instrument interval rows, with no session or
    instrument x session loop. F4 covers the per-instrument quadratic term.
  - Shape 5 remains for status, as disclosed: segments are built and
    dropped.
  - The interpretation of decision (22)'s "from the provider execution
    plan" as "from the facts the plan holds" is acceptable. The counts come
    from the same `availability_data` rows the plan is prepared from. The
    plan's diagonal status segments cannot yield two-clock counts.
    Decision (22)'s operative clauses hold: counted, not stored; refusals
    unchanged, except F3, which is inherited; and the stored segments and
    the membership compilers are gone. The shape-5 status residual is
    acceptable because status facts are few, and it costs what BASE did.
- Docs: the contract's "counted as such segments" wording is accurate
  except for F2. Claims LCL-0321..0325 and LTB-0331..0335 fall within the
  reserved ranges, with no duplicate or orphan; each LCL maps to one block.

## Verification record

- Full suite on the candidate copy (`load_all()` then `test_local(...,
  stop_on_failure = FALSE, load_package = 'none')`): 1,145 blocks, 18,352
  expectations, 0 failures, 0 errors, one optional skip (the Yahoo
  missing-package path), 660 s of block time. This matches the closeout.
- Census `--mode=check`: `LEDGR_CODEBASE_CENSUS_OK` (findings 72),
  `LEDGR_MODE_BRANCH_CENSUS files=29 functions=55 branch_sites=158
  flow_sites=55`. `--self-test-mode-branches`:
  `LEDGR_MODE_BRANCH_SELF_TEST_OK`. Fold-phase:
  `LEDGR_FOLD_PHASE_CONTRACT_OK`.
- Identity: the implementer's runner gives 84 of 84 on my copies. My e2e
  probe gives 63 of 63, apart from the probe-path artifact. Counts: 828
  families, 0 mismatches.
- Not run: the fixture ladder, the fast, review and heavy profiles, and
  `R CMD check`.

## Timing

LDG-3077, using the implementer's `time_blocks.R` (whole
`test-strict-feature-acceleration.R`, testthat per-block elapsed). High
performance plan, affinity `0xFFFF`, BASE and candidate alternating, three
runs each:

| Block | BASE | Candidate |
| --- | --- | --- |
| LTB-0142 | 2.66, 2.69, 2.57 s | 0.93, 0.89, 0.91 s |
| LTB-0143 | 0.75, 0.77, 0.75 s | 0.15, 0.16, 0.16 s |

This agrees with the closeout (2.76 to 0.97 s and 0.80 to 0.17 s). The
counter scaling is in F4.

## Review ratio

Eight findings (F1-F8) over sixteen acceptance items: 8/16 = 0.500. Three
are blocking (F1, F2, F3), and F3 needs a maintainer disposition.
