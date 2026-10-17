# Cut 16 Workstream 41 closeout: shared causal history substrate

Implementation commits: `7dcd9968`, `7d8e595f` and correction `9c1e352e`

Status: close review returned `CHANGES_REQUIRED`; product and detector
corrections are complete and await focused Type 1 confirmation.

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

Complete membership snapshots restart resolution from the latest eligible
complete header rather than replaying its whole prefix. A correction probe at
the reviewed Sharadar shape (580 complete sets, 1,200 instruments and 6,961
pulses) takes 0.37 seconds for the full query pass. Restoring prefix replay
makes LTB-0291 count 820 header applications for 40 successive sets against
the linear bound of 80. Run, sweep, window and walk-forward substrate creation
now all build observation planes from fetched rows, never aligned placeholder
rows. LTB-0291 names one missing expected bar and one inactive no-print
session; restoring placeholder alignment fails three literal planes.

The existing availability resolver remains the precedence oracle. Segment
rows preserve the resolved state, winning fact and reason. Active, inactive,
unknown and conflicting membership states remain distinct, as do family
declaration and family completeness. The guard defaults to
`max(4 * fact_rows, 16)` and reports the instrument, family and counts through
a classed refusal. A declared override is already part of history-policy
identity from Workstream 40.

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
   no data frame grows a row at a time.
2. Bars and facts are indexed during preparation. Complete membership sets
   replay from the latest eligible complete header, and the pulse loop does
   not repeatedly subset a full table by instrument.
3. Matrix and `collapse::na_locf()` operations handle column work; timestamp
   and fact normalization are not repeated per cell.
4. No row-wise JSON or hashing was added. Feature preparation constructs one
   frame per instrument and reuses it across definitions.
5. Candidate-invariant preparation and worker staging occur once per owning
   operation or daemon, not once per candidate or pulse; walk-forward's
   deliberate per-fold restaging remains an LDG-3069 measurement input.
6. No new pulse operation scans the complete historical axis. P1 queries the
   prepared packet and P2 adapts it.
7. Availability owns one bars/facts/feature substrate. Dense keeps its old
   representation, and public history results remain owned by Workstream 42.

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

Durable evidence is under
`dev/bench/v0_2_2_history_substrate/evidence/`. Scratch fixture stores and
private paths are not evidence and are removed at handoff.
