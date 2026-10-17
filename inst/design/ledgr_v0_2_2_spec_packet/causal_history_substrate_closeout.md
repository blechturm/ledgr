# Cut 16 Workstream 41 closeout: shared causal history substrate

Implementation commits: `7dcd9968`, `7d8e595f`, correction `9c1e352e` and
correction `1db8b675` (second and third rounds)

Status: the close review and focused re-reviews 1 and 2 returned
`CHANGES_REQUIRED`. Re-review 2 found no product defect; its detector and
branch findings were corrected in a third round that the maintainer directed
("iterate until green"), and the reviewer's confirmation returned `PASS`.
Maintainer acceptance remains open, together with the fast-profile timing gate
(see the verification record).

## Necessity and scope

Historical-projection synthesis v12 requires one causal preparation before
the package can expose public history frames or teach recursive indicators.
The pre-cut tree prepared bars, availability facts and feature inputs through
separate run, sweep and walk-forward shapes. Reusing those shapes for public
history would have created another reader and made cutoff answers depend on
the caller.

This workstream installs only the shared internal substrate, treatment
vocabulary and local-worker transport. It does not expose
`ledgr_history_frame()`, change dense execution, hydrate features before their
current scoring boundary, or claim the H6 private-memory gates.

## LDG-3059: one causal substrate

`ledgr_history_substrate` owns the canonical instrument order, common venue
axis, bar matrices, separate effective and knowledge clocks, resolved fact
segments, expected-session masks and an optional feature projection. It is
prepared once for an availability experiment and reused by a run, sweep,
window or walk-forward operation. Queries use consumer-local positions; the
stored object has no monotone mutable cursor, so reordered cutoffs return the
same values.

The prepared membership cursor applies each newly eligible complete or
incomplete header once and caches the header-derived planes until another
header arrives or the cursor rewinds. At the reviewed Sharadar shape (580
complete sets, 1,200 instruments and 6,961 pulses) the full decision pass takes
0.26 seconds, and a 300-set incomplete pass 0.14 seconds, against 0.23 and
0.12 seconds on the pre-cut tree. LTB-0291 counts one header advance per
eligible header. Run, sweep, window and walk-forward substrate creation all
build observation planes from one unsplit fetched bars frame, never aligned
placeholder rows or a split-and-rebound copy. LTB-0291 names one missing
expected bar and one inactive no-print session, and fails if sweep preparation
calls the split-bars helper.

Segments for trading status, lifetime, terminal state and interval-only
membership compile per instrument over that instrument's own knowledge epochs
and observation breaks, through the shared resolvers. One corrected instrument
no longer forces every instrument through a family-wide cross-product: three
status facts per instrument at 150 instruments by 750 sessions fall from 91.4
to 0.1 seconds, and lagged membership intervals at 200 by 1,000 from 215 to
1.0 seconds. LTB-0291 checks the lagged interval-only family against the
canonical resolver at every observation and knowledge pair. Complete set
headers keep their linear complete-set compiler and same-clock sets the
prepared cursor. Incomplete set headers whose knowledge lags their effective
time still use the family-wide compiler: 0.8, 3.9 and 23.9 seconds at 20, 40
and 80 sets by 300 instruments. That residual is measured rather than hidden
and is routed below.

The existing availability resolver remains the precedence oracle. Segment
rows preserve the resolved state, winning fact and reason. Active, inactive,
unknown and conflicting membership states remain distinct, as do family
declaration and family completeness. The guard defaults to
`max(4 * fact_rows, 16)` and reports the instrument, family and counts through
a classed refusal. A declared override is already part of history-policy
identity from Workstream 40.

A supplied substrate is validated against the history identity stored in the
run's config. `ledgr_history_policy_normalize()` refuses `NULL` instead of
defaulting, which had made a non-default-policy walk-forward refuse and let a
strict experiment run on a carry-5 substrate. LTB-0287's internal-NULL
assertion changed from default equality to refusal for that reason; a run
that omits `history_policy` now witnesses public default equality directly.

P1 is the only fold stage that reads the substrate. P2 receives values adapted
by P1; P3 through P5 receive neither a substrate nor a history frame. The
source detector also checks run, sweep and walk-forward ownership and the
accepted WS38 service census. Dense execution retains its pre-cut preparation.

## LDG-3060: treatment and evidence

Treatment keeps separate planes for structural expectedness, observation,
raw missingness, input carry, calculation validity, output carry, readiness
and estimator admission. Carry is forward-only, field-local and bounded by
expected sessions. It retains the original source time and age, cannot cross
lifetime or terminal barriers, cannot invent a leading value and never fills
volume. A declared input carry may make an instrument complete enough for the
post-treatment admission primitive. The primitive exposes raw and carried
planes; LDG-3066 owns return and volatility consumers, while LDG-3062 and
LDG-3063 own public selection and its target-plane proof.

The shared vocabulary records `expected`, `observed`, `is_missing`,
`input_carried`, `calculated`, `output_carried`, `source_ts_utc`,
`carry_age_sessions`, `ready`, `calculation_valid`, `missing_reason`,
`barrier_reason`, `requested`, `included`, `exclusion_reason`,
`required_input_count`, `carried_input_count` and `carried_input_share`.
Evidence is represented by bounded planes and segment summaries, not a trace
that grows once per pulse.

Treatment always begins at the causal prefix and then slices a requested
window, and it omits observations after the cutoff. Output carry clears source
and age when no carry occurred and distinguishes expiry from ineligibility.
Estimator admission distinguishes structural barriers, expired carry and
other missing required input. LTB-0292 pins those boundaries together with
the five-versus-six carry edge, terminal knowledge, non-default policy, volume
guard and original chained source time.

Terminal handling follows the maintainer decision of 2026-10-17. The terminal
state comes from the shared lifetime resolver, so a relisting clears it, but
the carry barrier is sticky from the first knowable terminal column onward,
as v12 Section 5 requires. An intermediate uncommitted correction had
released the barrier after relisting and rewritten LTB-0292's `terminal`
oracle to `lifetime_restart`; that oracle is restored and the state and
barrier are now pinned separately.

Feature calculation is bounded by the window's scoring start and end, parsed
as exact instants whether they arrive as ISO strings or POSIXct. An ISO end
truncated to its calendar date had dropped the last scored pulse's feature
value, which six registered blocks detected; LTB-0292 now pins the ISO and
POSIXct bounds to the same result.

The remaining civil-time decision is bound literally. A Date-valued
corporate-action entitlement, effective or payment date resolves to the
declared venue session close; a Date-valued knowledge time resolves to that
session's open. LTB-0292 pins the distinct instants and the resulting cash
posting.

## LDG-3061: persistent local-worker staging

Availability sweeps stage one immutable invariant per mirai daemon. Candidate
messages contain only an owner-scoped substrate descriptor and
candidate-varying inputs; each worker reconstructs pulse strings, the
availability provider and local cursors from the staged object. Missing,
stale or altered descriptor identity refuses before candidate work. This is a
daemon-local contamination guard, not a content hash.

One and two workers are the measured support claim. Larger local counts still
run and are labelled unmeasured. Public sweep and walk-forward witnesses pin
ordering, results, research hashes and caller RNG across one, two and three
workers. Backend cleanup is counted after a successful public dispatch and an
injected worker failure; the existing interrupt witness owns discard-all
interrupt cleanup.

The transport record measures serialized task shape, not RSS. For six
candidates the unstaged tasks serialize to 125,898 bytes. Each of two workers
receives one 19,375-byte invariant and the compact tasks serialize to 11,244
bytes: 49,994 bytes in total, or 0.397 of the unstaged payload, with exact
candidate-result parity. Object-size diagnostics are separately labelled.
LDG-3069 still owns parent, daemon and process-tree private-commit gates, fold
restaging, unseeded worker-start RNG and the mori trigger.

## Detecting evidence

| Claim | Block | Boundary |
|---|---|---|
| LCL-0288 | LTB-0291, LTB-0293 | two clocks, masks, linear complete-set replay, segments and sole-reader ownership |
| LCL-0289 | LTB-0292 | causal-prefix treatment, evidence, admission and Date event edge |
| LCL-0290 | LTB-0294, LTB-0295 | exact compact fields, descriptor key and backend cleanup |
| LCL-0291 | LTB-0295, LTB-0296 | public worker parity, fold staging, RNG and fresh scoring-start features |

The implementation also moved two older structural oracles to the new native
boundary. LTB-0155 observes release at the history-feature call rather than
the retired inline strict call. LTB-0276 now pins runner to history helper to
strict engine. Neither claim was weakened.

## Compatibility and fixture ladder

The registered 800-instrument, 1,260-session, 300-member fixture lane compares
the pre-cut `e3f822a5` tree with the candidate tree that became `7dcd9968`.
All 50 gated families and the identity family are exact. The independent
recorder self-test detects all 51 mutated families.

That lane exposed two integration errors before closeout. First, computing
features from the substrate start changed the still-current scoring-boundary
rule owned by later tickets. `ledgr_history_compute_feature_series()` now
uses the shared bars but masks the prefix before the declared calculation
start. Second, a window-local pulse index was applied to the full substrate
projection; the fold now passes the projection column. LTB-0296 now pins
literal fresh-warmup run and sweep equity, walk-forward training equity and
test-fill time. Removing the calculation-start mask fails five assertions;
restoring the local index also fails the block.

The measured phase totals were 139.611 seconds before the cut and 147.359
seconds on the candidate. This is a disclosure, not an H6 resource gate; the
lane's purpose here is exact semantics and identity. LDG-3069 owns paired
end-to-end time and private-commit adjudication.

## Aggregate segment census

The checked-in WS39 aggregates contain 1,166 instruments, 7,213 sessions,
5,481,906 bars, 290,811 membership rows, 580 complete membership sets and
829 lifetime rows. Membership prepares 967,091 facts and 677,446 segments;
its aggregate ratio is 0.7005 and its per-instrument upper bound is
581 / 580. Trading status has no source rows and one default segment per
instrument. Both pass the default guard by construction.

Those aggregates do not disclose lifetime-row distribution, clocks or
terminal labels. The record therefore says `needs_full_census` for lifetime
and terminal families instead of inventing a pass. LDG-3070 owns the private
current-format census before Cut 16 closes.

## Seven-shape walk

The changed preparation, fold and transport functions were checked against
the seven shapes in `optimization_coding_style.qmd`.

1. Segments and payload rows are accumulated in bounded lists and bound once;
   no data frame grows a row at a time, and bars are fetched as one frame
   rather than split per instrument and rebound.
2. Bars and facts are indexed during preparation. Multi-fact segment families
   compile per instrument over that instrument's own facts, and the pulse loop
   does not repeatedly subset a full table by instrument. Incomplete lagged set
   headers remain the measured exception noted above.
3. Matrix and `collapse::na_locf()` operations handle column work; timestamp
   and fact normalization are not repeated per cell.
4. No row-wise JSON or hashing was added. Feature preparation constructs one
   frame per instrument and reuses it across definitions.
5. Candidate-invariant preparation and worker staging occur once per owning
   operation or daemon, not once per candidate or pulse. Each membership
   header is applied once, and its derived planes are cached between header
   changes rather than rebuilt every pulse. Features are calculated only
   inside their window. Walk-forward's deliberate per-fold restaging remains
   an LDG-3069 measurement input.
6. No new pulse operation scans the complete historical axis. P1 queries the
   prepared packet and P2 adapts it.
7. Availability owns one bars/facts/feature substrate. Dense keeps its old
   representation, and public history results remain owned by Workstream 42.

## Routed, not fixed here

The Cut 16 antipattern review also found shape problems that this correction
does not attempt. Each is recorded with its proposed owner, pending maintainer
confirmation; none changes a WS41 result.

- Incomplete membership set headers with lagged knowledge still use the
  family-wide compiler (measured above): LDG-3069 for the bound, with
  LDG-3070's private census establishing whether the Sharadar lake has that
  shape.
- About 41 percent of the lake-scale substrate is dead or duplicated: facts
  held as both segments and provider plan, four packet planes nobody reads,
  and `gap_type`/`is_synthetic` restating `observed`. LDG-3069 owns staged
  memory; WS42 decides which planes its public reads consume.
- Availability P2 materializes the full `ctx$feature_table` every pulse where
  the pre-cut path used the schema-only frame the contract allows; and the
  cut adds execution-mode branches in fold, runner, sweep and walk-forward, a
  few provably redundant. WS42 owns the strategy-context surface.
- `ledgr_history_substrate_treated_field()` rematerializes and re-treats the
  whole prefix per call, which WS42 must not call per pulse.
- WS40-area costs (correction-chain lineage recomputation, civil JSON
  formatting and size, tamper detection that depends on bundle composition,
  the duplicated known-when-effective rule, and constructors validating on
  UTC-midnight placeholders) belong to a WS40 follow-up ticket; the
  known-when-effective timing for Date input needs a maintainer decision.
- Output carry can leak the input-carried flag without failing LTB-0292
  (record-only; the primitive has no product consumer yet).

## Verification record

The original implementation record predates the close-review corrections:

- Fast profile: 565/565 blocks in each of three runs, median 110.22 seconds
  against the unchanged 112-second bound, pass.
- Review profile: 357/357 blocks in 306.82 seconds, zero failures and one
  pre-existing optional Yahoo missing-package-path skip.
- Heavy protocol: 192/192 blocks in 207.19 seconds, zero failures or skips.
- Fixture ladder: 50/50 gated families plus identity exact; self-test 51/51.
- Package build and check: code, installed tests, examples, Rd and vignette
  source execution pass; only the two expected `--no-build-vignettes`
  warnings remain.

The correction evidence is separate:

- The focused history suite and eleven adjacent availability, feature,
  sweep and walk-forward suites pass. Codebase-contract, documentation and
  control-plane suites also pass.
- Mutations that restore prefix replay, aligned placeholder observations or
  the scoring-start regression fail LTB-0291 or LTB-0296. Dropping an owner
  descriptor field fails LTB-0294, and changing the exact compact task shape
  fails LTB-0295.
- The corrected worker transport record has exact parity and records 49,994
  serialized bytes against 125,898 bytes without staging, ratio 0.397.
- The first correction fast record executes all 565 blocks in each run but
  misses the timing gate: 112.82, 111.11 and 113.29 seconds give a
  112.82-second median against 112 seconds. The miss is retained rather than
  relabelled as a pass.
- Its one complete retry also executes 565/565 without failures at 122.44,
  127.21 and 142.59 seconds. The increasing times on the unchanged tree are
  recorded as host variability; the retry median of 127.21 seconds remains a
  miss and is not substituted for the first record.
- Codebase census, fold-phase checker, YAML and `git diff --check`: pass.

The second-correction evidence is separate again:

- Full test suite: 1,114 blocks, no failures, one optional-package skip.
- Source-copy mutations each fail their registered block: restoring the
  split-and-rebind bars, the internal-NULL policy default, the re-bundle
  overwrite, ISO date truncation, a released terminal barrier or the
  family-wide interval compiler, and the four re-review treatment survivors.
  Output carry leaking the input-carried flag is the one record-only survivor.
- The randomized resolver differential (121 membership, 65 status and 48
  lifetime fact sets at every observation and knowledge pair) still shows no
  mismatch.
- Fixture ladder rerun on this tree: 50/50 gated families and identity exact,
  51/51 self-test; phase totals 144.613 and 148.273 seconds are disclosure.
- Profiles were measured on a host the maintainer reported as busy, so their
  timings are not gate evidence (see
  `ws41_second_correction_fast/README.md`). Review 357/357 and heavy 192/192
  pass. The three fast runs execute 565/565 but each records two warning
  blocks (LTB-0154 and LTB-0182, source-scan blocks unrelated to the change);
  a captured diagnostic fast pass is 565/565 clean. The fast-profile gate needs
  a rerun on a quiet host.

Re-review 2 (`close_review_41_rereview_2.md`) found no product defect. Its
third-round corrections:

- LTB-0296 parses every recorded calculation end exactly and requires it to
  be a fold window end, with every training end present.
- LTB-0291 adds a lagged mixed membership family queried forward, backward
  and forward again on one cursor, and counts header advances exactly.
- The runner's stored-policy check is unconditional instead of a new
  `availability_active` branch.

Mutations calculating a training window to the snapshot end, removing the
complete-header guard or re-advancing every header each fail LTB-0296 or
LTB-0291. N5 (defensive mixed civil-frame refusal) and N6 (about 6 ms per
instrument for interval-only membership, linear) are record-only.

Durable evidence is under
`dev/bench/v0_2_2_history_substrate/evidence/`. Scratch fixture stores and
private paths are not evidence and are removed at handoff.
