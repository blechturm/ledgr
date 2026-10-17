# WS41 / LDG-3059..3061 close review (Type 1), `e3f822a5..d1e9f04d`

## Verdict: CHANGES_REQUIRED

The shared substrate is in place for availability runs, sweeps, windows and
walk-forward. Fact answers match the existing resolvers, the fold ownership
split holds, the Date corporate-action edge is correct and the staged worker
path gives the same results as sequential execution. Two product defects
block acceptance:

- the rewritten prepared-membership cursor is quadratic in membership
  headers (F1);
- the substrate built for sweep, window and walk-forward has wrong
  observation planes (F2).

The other findings concern detectors and the written record. None requires
redesigning v12 or the WS38 phase split, so this is not NEEDS_TYPE_2.

Method:
- Read the diff, the closeout, the claims and the tests.
- Ran 33 focused suites: all pass, 0 failures. These were history-substrate,
  history-foundation, fold-phase-contract, execution-spec, 15 availability
  suites, risk-fold, sweep-parity, sweep-parallel, parallel-workers, sweep,
  walk-forward (orchestrator, folds, identity), precompute-features,
  corporate-action-policy, pit-consistency, codebase-contracts,
  documentation-contracts and dense-timestamp-validation.
- Ran the codebase census and fold-phase checker, a randomized resolver
  differential, cross-path substrate probes, base-versus-candidate timing and
  in-memory or source-copy mutations.
- Two read-only helper reviews covered treatment (LDG-3060) and transport
  (LDG-3061). Their probe and mutation logs sit in reviewer scratch. Every
  finding below that rests on them was spot-checked against the source or
  the logs.

## Findings

### F1 (high): the prepared membership cursor is quadratic in membership headers

`R/availability-provider-prepared.R:169`. When the eligible-header count
changes, `ledgr_availability_prepared_membership_from_plan()` now replays
every eligible header through `ledgr_membership_apply_prepared_header()`.
Each call copies five vectors the length of the instrument key. The pre-cut
cursor replayed only from the last eligible complete header. The quadratic
loop affects:

- every availability run and sweep candidate, through the provider's
  `members_at`;
- the substrate's diagonal-membership compiler (`R/history-substrate.R:987-1011`).

Measured on one full decision pass (6,961 pulses, 580 complete sets of 500
members, 1,200 instruments, about the WS39 membership shape):

| Tree | Time |
| --- | --- |
| `e3f822a5` (pre-cut) | 0.23 s |
| `d1e9f04d` (candidate) | 39.97 s |
| candidate, replay from the last eligible complete header | 0.48 s |

Within one daemon, each candidate re-crosses those header changes, so on a
lake shaped like WS39 every run or candidate pays about 40 s. The fast,
review and heavy profiles and the 300-member fixture ladder do not reach this
shape.

Fix:
- Restore the replay start at the last eligible complete header (one line;
  history-substrate, provider-production, pit-consistency and parity suites
  still pass with it).
- Add a scaling witness: many complete sets, with a call-count or ratio
  bound on `ledgr_membership_apply_prepared_header`.

### F2 (high): sweep, window and walk-forward substrates mark every session observed

`R/history-substrate.R:196-202, 329-373`; `R/sweep.R:2645-2673`.

The cause:
- `ledgr_history_substrate_for_experiment()` pads every missing session with
  `ledgr_sweep_align_availability_bars()`, a full-axis placeholder frame per
  instrument with NA prices.
- `ledgr_history_substrate_bar_matrices_from_list()` then sets `observed`
  TRUE for every row, at line 372.
- The run path builds from the real bar frame
  (`ledgr_history_substrate_bar_matrices()`) and is correct.

Probe: AAA misses expected session 3, and BBB becomes known-inactive at
session 5 with no prints from session 6.

| Plane | Run-built substrate | Substrate from `for_experiment()` |
| --- | --- | --- |
| `bars$observed` | FALSE at AAA:3 and BBB:6-8 | TRUE everywhere |
| `missing_expected_bar` | TRUE at AAA:3 | FALSE everywhere |
| `inactive_print` | TRUE only at BBB:5 | TRUE at BBB:5-8 |

`close` and `gap_type` are identical on both paths.

Impact:
- No economic consumer reads these planes today. Treatment derives
  `observed` from finite field values.
- But they ride in every P1 packet, they are the planes LDG-3059 acceptance 2
  promises, and they are what WS42 public history will consume.
- One substrate currently gives different evidence depending on the entry
  point.
- LTB-0291 builds its fixture only through the direct data-frame
  constructor, so it cannot see this.

Fix:
- Build the sweep and walk-forward substrate from the fetched bar frame with
  `ledgr_history_substrate_bar_matrices()`, and delete the align/from-list
  path.
- Add a registered witness that the planes from the run path and from
  `for_experiment()` are identical when an expected bar is missing and when
  inactive sessions have no prints.

### F3 (medium): LDG-3060 evidence and contract text claim behaviour no product path has

`tickets.yml:2081` (LDG-3060 evidence, lines 3-5); `contracts.md:764-771`.

The state of the code:
- `ledgr_history_substrate_treated_field()`, `ledgr_history_output_carry()`
  and `ledgr_history_estimator_admission()` have no caller in `R/`; the census
  registers them as test-only seams.
- Features are computed on raw bars.
- `price_carry` changes config identity and nothing else.

What the evidence lines claim:
- Line 4 says LTB-0292 keeps return and volatility values missing and leaves
  the membership, trading, valuation and execution planes unchanged. LTB-0292
  has no return or volatility feature and no plane comparison, and no code
  identifies a return or volatility family.
- Line 5 says `drop_instruments` is evaluated after treatment. No
  `drop_instruments` or `na_action` exists yet; only the admission primitive
  is tested.
- Line 3 says the default five-session carry is pinned. The 5-versus-6 edge
  is never asserted.

The two contract sentences on the default carry and on return and
volatility families are written as shipped behaviour, but they are only
vacuously true.

Fix:
- Narrow evidence lines 3-5 to the primitive and the admission primitive.
- Route the return/volatility half to LDG-3066, and the `drop_instruments`
  and no-plane-change half to LDG-3062/3063.
- Either restore a pending link on those two contract sentences or phrase
  them as rules of the treatment primitive until a public consumer exists.

### F4 (medium): LTB-0292 misses six treatment mutations on the substrate's matrix path

The unmutated baseline passes 67/67. Each mutant below still passes 67/67;
the helper's `verify.out` confirms each changes values.

| Mutant | Change |
| --- | --- |
| M3b | Off-by-one age bound in the matrix path (`R/history-treatment.R:200-201`); a 6th cell carries at `max = 5` |
| M4a | Matrix carry ignores the terminal barrier; the fixture's terminal row coincides with `known_inactive`, which masks it |
| M5 | `price_carry` hard-coded to `5L` at `:299` (the wiring itself is correct today) |
| M8b | `ledgr_history_substrate_terminal_at()` ignores the cutoff |
| M2b/M2c | Volume guard removed from `treated_field` |
| M6 | Chained `source_ts_utc` refreshed |

M11 (output-carry age unbounded) also survives.

Fix: add literal substrate-level assertions for each:
- the 5-versus-6 edge;
- a terminal row that is not `known_inactive`;
- a substrate with non-default `price_carry`;
- terminal state before and after its knowledge time;
- volume through `treated_field`;
- a literal source time on a chained carry;
- output carry past its bound.

### F5 (medium): the first integration correction has no registered detector

`R/history-substrate.R:221-224`. Removing the calculation-start mask, so
features start at the substrate data start, fails nothing in:

- history-substrate
- availability-features
- availability-parity
- precompute-features
- walk-forward-orchestrator
- sweep-parity

Only the unregistered fixture ladder caught the original error. (The second
correction, local pulse to projection column, is pinned: restoring the local
index fails LTB-0296, and restoring local fold-reader columns fails LTB-0296
and the availability-parity carry-chain block.)

Fix: add a registered witness with a scoring or window start after the data
start and a warm-up-dependent feature. Expect its first values to equal a
fresh calculation from the scoring start in run, sweep and walk-forward.

### F6 (medium): stage identity is a descriptor, not "exact", and four of its components are unpinned

`R/history-substrate.R:13-31`; LCL-0290 (`tests/claims.yml:3303`).

What the identity covers:
- It hashes owner, snapshot hash, policy, version, starts, instruments, axis
  names and feature ids.
- It does not cover bar, feature or segment content, `provider_plan`, or the
  non-substrate invariant fields (`exp`, `strategy_hash`, `master_seed`,
  `availability_config`, corporate-action rows).

What the source-copy mutations show:
- Dropping `owner_id`, `axis`, `instruments` or `feature_ids` passes every
  block.
- Only dropping `snapshot_hash` fails LTB-0294.

Exposure today is nil, because daemons live for one sweep and the owner is
that sweep's id. But the claim's `smallest_failing_change` and the contract's
"exact staged identity" overstate it.

Fix: alter each component in LTB-0294 and expect `ledgr_history_worker_stage()`
to refuse. Reword the claim and contract as an owner-scoped descriptor key, or
hash the staged content.

### F7 (medium): the transport record understates the two-worker payload and mislabels its unit

`dev/bench/v0_2_2_history_substrate/worker_transport.R:50-89`;
`evidence/ws41_worker_transport/transport.csv`; closeout LDG-3061.

- **Copy count.** `mirai::everywhere()` delivers the invariant to each daemon,
  but `staged_total_bytes` counts one copy at `worker_count = 2`. The real
  two-worker figure is 2 × 82,024 + 53,280 = 217,328 bytes, a ratio of 0.400,
  not 0.249.
- **Unit.** All sizes are `utils::object.size`, not serialized length.
  Serialized, the figures are 120,982 / 18,524 / 11,244, a ratio of 0.399
  with two copies.
- **Provenance.** `package_head` records `e3f822a5`, the base commit, so the
  record measured uncommitted candidate code. Likewise the fixture-ladder
  candidate is `precommit_worktree`.
- Nothing claims RSS; the LDG-3069 handoff is intact.

Fix:
- Add a `workers × invariant` column and base the ratio on it.
- Label the unit or switch to `length(serialize())`.
- Re-record both evidence sets against `7dcd9968`, or state the tree hash
  they used.

### F8 (low): the transport census and walk-forward worker wiring are partly undetected

- The invariant classification (`R/sweep.R:1219`) is an allow-list that fails
  open: removing `exp` from it sends `exp` in every task, and every block
  still passes.
- Forcing `workers = 1L` inside `ledgr_walk_forward_eval_fold()` passes
  LTB-0296.
- The ticket evidence attributes the real task census to LTB-0294, which
  uses synthetic tasks.

Fix:
- Assert the exact compact-task field set in LTB-0295.
- Count stage calls per fold in LTB-0296.
- Correct the attribution.

### F9 (low): treatment primitive defects to fix before WS42 consumes it

These are latent, because the primitive has no caller yet.

- **Window-local treatment.** `treated_field` with `observation_idx = 2:4`
  drops a source that is one or two sessions old. That breaks v12 S5 "latest
  admissible earlier observation" and S8 "never window-local".
- **Columns after the cutoff.** The default `observation_idx` includes
  columns after the cutoff, and carries into them.
- **Output-carry evidence.** Cells that are not carried report an age and a
  source time; an expired output carry is labelled
  `output_not_carry_eligible`.
- **Admission reasons.** Admission names every exclusion
  `missing_required_input`.

Fix: treat from column 1 through the cutoff and then subset. Clear age and
source on cells that are not carried, and name expiry and structural
exclusion separately.

### F10 (low): repeated frame construction in feature preparation

`R/backtest-runner.R:1143-1156` and `R/history-substrate.R:219,242-249`.

For every definition and instrument, the run builds the full-axis instrument
data frame twice: once for a row-count check, and once inside
`ledgr_history_compute_feature_series()`. The sweep and precompute payload
rebuild it once per definition. Pre-cut code reused one frame per instrument.

Fix: build each instrument frame once per preparation and pass it to all
definitions.

## Record-only

- **Shared provider per daemon.** The staged invariant holds one
  availability provider per daemon, shared across candidates. That is safe
  (the cursors recompute on a backward seek), but `contracts.md:137` says
  cursors "remain local to one consumer". Say "one daemon".
- **Re-staging per fold.** Walk-forward restarts daemons and re-stages the
  invariant for every fold: once per daemon per sweep, but folds × workers
  times per walk-forward. This is for LDG-3069.
- **Daemon global environment.** `everywhere()` also leaves the invariant in
  each daemon's `.GlobalEnv`. Cleanup depends on `daemons(0)`, and stage
  errors on the daemon are dropped.
- **Unmeasured label.** "Unmeasured" exists only as an unprinted sweep
  attribute plus a walk-forward field. It is correctly not identity-bearing.
- **Caller RNG.** `ledgr_sweep(seed = NULL, workers >= 2)` advances caller RNG
  through mirai start and stop. This is identical before the cut. Acceptance
  4 has no seed qualifier, so route it.
- **R-level loops for WS42.** Several loops become seven-shape items once
  WS42 calls them per request: `ledgr_history_segments_query/materialize`
  loop per instrument and segment in R, and the general status/lifetime
  compilers loop over instruments at each epoch and break. The sparse paths
  cover today's data.
- **Terminal plane rank.** The terminal plane ranks among terminal rows only,
  so a later non-terminal correction does not lift it. This is consistent
  with v12's permanent barrier, but should be stated.

## Acceptance assessment

| Ticket item | Result |
| --- | --- |
| 3059.1 no parallel availability bars representation | PASS (spec validator plus LTB-0293); the transient padded list feeds F2 |
| 3059.2 axis and masks distinguish inactive, halt, missing, inactive print | **FAIL** on sweep, window and walk-forward (F2); PASS on run |
| 3059.3 P1 sole reader, P2 adapter, P3-P5 substrate-free, WS38 census | PASS |
| 3059.4 segments equal the existing resolver; winner, reason, four states, declaration | PASS (randomized differential: 121 membership, 65 status, 48 lifetime fact sets, 0 mismatches) |
| 3059.5 segment guard and aggregate census | PASS; aggregate census reproduces; lifetime `needs_full_census` is honest |
| 3059.6 override identity, reordered and immutable reads | PASS |
| 3059.7 dense byte-identical, ladder, seven shapes | Dense PASS; ladder PASS (F7 provenance); **seven shapes FAIL** (F1, F10) |
| 3060.1-2 hostile fixtures, independent planes | Primitive PASS; detection gaps (F4) |
| 3060.3 default five-session carry, NULL strict, identity | Primitive PASS; edge unpinned (F4), no product consumer (F3) |
| 3060.4 return/volatility and planes unchanged | **Not evidenced** (F3) |
| 3060.5 `drop_instruments` after treatment | **Not evidenced**; primitive only (F3) |
| 3060.6 late-known lifetime | PASS |
| 3060.7 Date corporate-action edge | PASS; reverting to open fails LTB-0292 and LTB-0286 |
| 3060.8 bounded evidence | PASS |
| 3061.1 payload census, staged once per daemon | PASS in product; record F7, census detector F8 |
| 3061.2 identity refusal before work, cleanup | Refusal and cleanup PASS; identity scope F6 |
| 3061.3 sequential, current and staged parity | PASS; results are `identical()`, though the test uses `expect_equal` |
| 3061.4 1/2/3 workers, order, RNG, unmeasured label | PASS with a seed; walk-forward wiring undetected (F8); no-seed RNG is pre-existing |
| 3061.5 no repeated split or serialization; staged bytes recorded | Path clean; byte record F7 |

## Checked and found clean

- **Ownership and spec validation.** Availability execution refuses
  `bars_by_id`, `bars_mat`, static views and a separate runtime projection.
  Dense keeps the old preparation and its `bars_mat` check. Dense dispatch is
  unchanged.
- **Fold stages.**
  - P1 alone calls `history_reader$bars()`.
  - P2 builds bars from the P1 packet and reads the stateless feature
    projection by mapped column.
  - P4 receives only the next-bar packet value.
  - The phase checker forbids history formals and substrate references.
  - The fold reader is declared in the WS38 census.
- **Resolver parity.** Status and lifetime precedence are factored into one
  shared function used by both provider and substrate. Membership segments
  agree with `ledgr_membership_resolve_prepared()`, the existing resolver
  given a separate knowledge cutoff, at every observation and knowledge pair
  in the randomized differential.
- **Corrections and edges.** The window-local projection correction is pinned
  by LTB-0296. The Date corporate-action edge is pinned: event dates go to
  close and knowledge to open.
- **Treatment semantics (primitive).** Carry is causal, field-local and
  bounded by expected sessions; the original source age is retained; volume
  is never carried; there is no leading or backward fill; lifetime and
  terminal barriers stop it; a print after a nonterminal barrier reseeds.
  Matrix and vector paths agree on 3,000 randomized cases. Policy is wired
  from the experiment.
- **Transport.**
  - Compact tasks carry 11 identity or candidate-varying fields.
  - Refusal comes before strategy invocation.
  - The `on.exit` daemon stop runs on success, failure and interrupt.
  - Candidate order and seeded caller RNG are preserved.
  - Worker count is absent from identity, provenance and session id.
  - Reruns reproduce `transport.csv` arithmetic exactly.
- **Evidence records.**
  - Fast: three runs 565/565, median 110.22 against the 112 s bound.
  - Review: 357/357, one quantmod skip.
  - Heavy: 192/192.
  - Ladder summary: 50/50 gated families, identity exact, 51/51 self-test.
  - The 139.611 to 147.359 s change is disclosure only.
  - The aggregate census reproduces byte-identically from an exported
    `d1e9f04d` tree; lifetime and terminal correctly say `needs_full_census`
    and leave the census to LDG-3070.
- **Mechanics.** Codebase census check: all ten files identical. Fold-phase
  checker OK. YAML loads. `git diff --check` is clean. No pending
  historical-projection link remains in a WS41-owned contract group.

## Review accounting

Findings: 2 high, 5 medium, 3 low. Product fixes F1 and F2 need a focused
re-review of the cursor scaling witness and the cross-path plane witness.
F3-F10 are detector, record or latent-primitive patches.
