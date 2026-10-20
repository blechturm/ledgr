# WS47 / LDG-3078..3079 close review (Type 1), `2ef0f2da..40d6139b`

## Verdict: CHANGES_REQUIRED (a test line, record corrections and one maintainer choice; no product defect)

The four trims hold on every input I could build through the public API.

- F01: a fresh sweep and pulse inspection drop the feature payload once the
  projection exists.
- F02: feature inputs call one carry calculation, the old C-1 body's first
  half verbatim; output carry still takes the full manifestation.
- F03: the membership plan keeps only the columns its cursor and attached
  resolver read.
- F04: one last-barrier plane per mask; field entries hold only sources.

Results are byte-identical to BASE `2ef0f2da` apart from the availability
feature-engine digest:

- My own end-to-end probe: 70 of 70 families after digest normalization
  (67 raw; the three explicit-precompute families differ only in the two
  digest strings per tree).
- Every feature input a definition consumes, for every instrument, prefix
  end and cutoff under four policies, plus the output-carry evidence planes:
  6,912 of 6,912 records identical raw.
- Direct history reads in four cutoff and field orders are identical across
  trees and order-invariant within each tree.

The suite, the census and the fold-phase checker pass. Each re-run detector
mutation fails its block.

Three findings, none in the product's results:

- F1: the decision (26) collection runs on every fresh sweep, including
  sequential and dense sweeps and each walk-forward fold. It costs about
  60 ms per sweep in a fresh process (+43% on a small dense sweep) and
  about 0.18 s in the test suite: 320 collections, 58.9 s, 8% of the full
  suite (1.8 s in the fast profile, 8-10% of the review and heavy
  profiles). The closeout does not record this cost. The code follows the
  decision as worded; whether it should apply only where workers are staged
  is a maintainer choice.
- F2: the new helper name makes LTB-0144's provenance check for
  `ledgr_history_input_carry` pass vacuously (substring match).
- F3: the recorded decision (26) peak reduction (parent -1,145 MiB, tree
  -1,170 MiB) uses a round in which every BASE run peaked in BASE's high
  mode. Against the low mode the parent falls about 530 MiB, and the tree
  change ranges from about nothing to about 1,000 MiB.

Six notes need no change. The closeout's catalogue-mix explanation (-1.6%)
is supported by my attribution runs.

## Method

- Read AGENTS.md; Cut 16 decisions (23)-(26); Workstream 47, LDG-3078 and
  LDG-3079 with their acceptance items; `cut16_architecture_audit.md`
  F01-F04; `proof_baseline_trims_closeout.md`; `history_representation_map.md`
  (R14, R20, R30, C-1 to C-4, Section 8); the style manual's seven shapes and
  fast-path rule; the whole product, test, claims and record diff of
  `2ef0f2da..40d6139b`, including the decision (26) commit.
- Built source copies of the candidate (`git ls-files`) and BASE
  (`git archive 2ef0f2da`) and a third candidate copy for mutations, compiling
  each once, sequentially, before any two-worker run.
- Read the implementer's runner (`ws47/runner/`) for blind spots before
  relying on any of its numbers. Blind spots:
  - two-worker sweeps and walk-forward run only for fixture A under the
    default policy, never under a carry or output-carry policy;
  - in-strategy reads never touch `low`, and the strategy reads fields in one
    order only;
  - the membership family exercises the cursor and resolver, not the
    provider's `decision_view()` and `execution_view()` that production
    calls;
  - no universe has an empty complete set, and no snapshot holds a decoy
    universe beside the run's;
  - refusals are recorded for run, sweep and inspection only, at segment
    limits.
- My probe `e2e47.R` (scratchpad `ws47_review/probes/`) covers those gaps on
  one hostile fixture: two relisting cycles on R02 (decisions 20 and 21), a
  lifetime fact learned after the data end (R03), a late-known merger
  terminal (R07), leading missingness (R08), status supersession and
  precedence, lagged complete and incomplete sets (`u`), intervals (`w`), a
  decoy universe (`v`), a universe whose first complete set is empty (`e`)
  and two dividends. Families:
  - runs reading all five fields in forward and reverse order inside the
    strategy, plus five features in several layouts;
  - fresh, explicit-precompute and precomputed sweeps, sequential and
    two-worker, under three policies (`price_carry = 3, output_carry = 2`,
    default, `price_carry = NULL, output_carry = 1`);
  - `run_window`, `sweep_window`, carried walk-forward over three folds
    (sequential under two policies, and two-worker), an INCOMPLETE run;
  - pulse inspection at seven cutoffs per policy, all five fields read in
    two orders on two inspected contexts, seven features;
  - direct `ledgr_history_read()` on fresh bound substrates: five fields and
    five features at every cutoff forward, backward and shuffled
    (lookback 5), and at ten cutoffs with the late ones first, with memo key
    sets and build counters;
  - the provider's `decision_view()`, `execution_view()`, `members_at()` and
    the attached resolver at every session close, 12 hours before and one
    second after, forward, backward and shuffled, for `u`, `w` and `e`, plus a
    run and inspection per universe;
  - segment-limit refusals 1 to 5 for run, sweep, precompute, walk-forward,
    window and inspection; an off-axis inspection cutoff; a precomputed
    payload reused under another policy; a dense fresh sweep.
- `inputs47.R` records `ledgr_history_feature_inputs()` for every instrument,
  prefix end and cutoff (own and axis end) under four policies and two
  universes, and `ledgr_history_feature_planes()` (the output-carry consumer
  of the manifestation) for nine definitions per instrument. Definitions
  consume only these inputs, and no calculation code after them changed, so
  this covers the whole catalogue, not only the definitions a runner names.
- 17 mutations and an unmutated control on the mutation copy, each
  restored byte for byte (the copy was diffed against the candidate copy
  afterwards).
- Full suite once on the candidate copy, and once more with `base::gc`
  traced for F1; census `--mode=check` and
  `--self-test-mode-branches`; `tools/check-fold-phase-contract.R`.
- Timing and memory are disclosure. Settings: High performance plan,
  PowerShell affinity `0xFFFF` set on the launching process, `Rscript.exe` by
  full path, BASE and candidate alternating, no foreign R process.

## Findings

F01-F04 are the audit's findings; F1-F3 are this review's.

### F1 (non-blocking, disclosure; maintainer choice): the decision (26) collection runs, and costs, on every fresh sweep

`R/sweep.R:331` collects once per fresh sweep. The decision's reason is
worker staging: the released payload would otherwise stay resident while
the invariant is serialized. But the statement also runs where nothing is
staged or the heap is small:

- sequential sweeps (`workers = 1`);
- dense fresh sweeps (the closeout notes this);
- every walk-forward training fold, since `ledgr_walk_forward()` runs a fresh
  `ledgr_sweep_window()` per fold.

Evidence (`gc_small.R`, a traced `base::gc`, fresh processes, eight
instruments by 50 sessions, 10 sweeps per row; BASE once, then the
candidate twice):

| Path | BASE sweep s | Candidate sweep s | Collections | Seconds per collection |
| --- | ---: | ---: | ---: | ---: |
| Availability fresh, `workers = 1` | 0.522 | 0.550, 0.553 | 1 per sweep | 0.063, 0.064 |
| Availability precomputed | 0.490 | 0.502, 0.511 | 0 | - |
| Dense fresh | 0.143 | 0.200, 0.204 | 1 per sweep | 0.062, 0.061 |
| Walk-forward, 3 folds | 2.71 | 2.87, 2.88 | 3 per call | 0.068, 0.068 |

Inside a test session the heap is larger and each collection costs more
(`gc_suite.R`, whole files, candidate):

| File | Elapsed s | Collections | Collection s | Share |
| --- | ---: | ---: | ---: | ---: |
| `test-sweep.R` | 16.0 | 26 | 2.77 | 17% |
| `test-walk-forward-orchestrator.R` | 18.3 | 25 | 3.00 | 16% |
| `test-sweep-retention.R` | 6.0 | 15 | 1.84 | 31% |
| `test-sweep-parity.R` | 9.8 | 5 | 0.59 | 6% |

Across the whole suite (`gc_fullsuite.R`: the full suite once more with
`base::gc` traced, each call attributed to its enclosing block and the
block's registered profile; calls from the six test files that call `gc()`
themselves excluded), the decision (26) collections are:

| Profile | Collections | Collection s | Profile block s | Share |
| --- | ---: | ---: | ---: | ---: |
| fast | 9 | 1.8 | 102.8 | 1.8% |
| review | 188 | 32.3 | 397.4 | 8.1% |
| heavy_protocol | 123 | 24.8 | 236.4 | 10.5% |
| all | 320 | 58.9 | 736.6 | 8.0% |

The fast profile carries little of it: about 1.8 s against the 112-second
bound and the recent 104.7-108.0 s medians. The review and heavy profiles
and the full suite pay about 8-10%.

The closeout's own (unpaired) records show the full-suite block time rising
from 665 s (`f367ed80`) to 709 s with the collection (+6.6%), with no
attribution; the traced 58.9 s is of the same order as that rise.

The implementation follows the decision as worded, so this is not a defect
against it. But the closeout measures only the H1 two-worker effect, and the
decision was taken without this cost.

Smallest fix:

- record the per-sweep and suite cost in the closeout (and the fast-lane
  margin at cut close, as the macro plan asks);
- put the choice to the maintainer: keep one collection per fresh sweep,
  or limit it to sweeps that stage workers (`workers > 1`). The second option
  would amend decision (26). X5 shows LTB-0393's structural check would then
  need its expected text changed.

### F2 (non-blocking, detector): LTB-0144 no longer checks that the manifestation is hashed

LTB-0144 checks each helper name with `expect_match(source, helper, fixed =
TRUE)`. The new name `ledgr_history_input_carry_calculation` contains
`ledgr_history_input_carry`, so the check for the manifestation now passes
whether or not `input_carry = helper(ledgr_history_input_carry, ...)` is in
the payload.

Evidence: X8 removes the manifestation from the hashed payload. LTB-0144
fails once, on the digest literal only. R-D4, which removes the calculation,
fails twice (literal and name). Under covr the digest literals are skipped
(`test-strict-feature-acceleration.R:200`), so X8 passes there.

This gap is new in this workstream. Before it, removing the manifestation
failed the name check.

Smallest fix: match on a word boundary, for example
`expect_match(source, paste0(helper, "\\b"))` (an underscore is a word
character, so `_calculation` no longer matches), or match the payload entry
text `"helper(ledgr_history_input_carry,"`.

### F3 (non-blocking, claim): the decision (26) peak reduction is stated against BASE's high mode only

The LDG-3078 evidence, the closeout's acceptance row and the decision (26)
commit message give the effect as "parent 3,873.5 to 2,728.5 MiB, tree
5,676.7 to 4,507.2 MiB". Those BASE medians come from the second round, where
all six BASE runs peaked high. BASE's staging peak is bimodal:

- the implementer's twelve BASE runs: five at 3,111-3,275 MiB parent (tree
  4,722-5,337) and seven at 3,861-3,938 (tree 5,340-5,982);
- my two pairs (Timing): BASE 3,267 / 4,752 and 3,852 / 5,970, the
  candidate 2,738 / 4,742 and 2,725 / 4,727 (parent / tree MiB), so one
  pair landed in each BASE mode.

The candidate sits at about 2,730 MiB parent in every run I or the
implementer recorded with the collection, except one 2,311. Against BASE's
low mode the parent reduction is about 530 MiB, not 1,145, and the tree
reduction ranges from nothing (my pair 1: 4,752 to 4,742) to about
1,000 MiB. The closeout says peaks "vary between rounds" and decision (26)
itself quotes the low-mode BASE (3,251 MiB), so nothing is hidden. But the headline numbers
that Workstream 44 will read overstate the reduction.

Smallest fix: state the effect against both BASE modes (parent about
-530 to -1,150 MiB; tree from about 0 to -1,170 MiB, the high-mode
medians) in the LDG-3078 evidence and the closeout's acceptance row, and
record the bimodal staging peak as a property of BASE. Workstream 44's
memory gate is a paired H6 comparison (macro plan, H2 Session E), so the mode
a baseline run lands in matters there; proof baselines should quote the
candidate's absolute peaks, not the delta.

### Notes (no change required)

- N1, comment. `R/history-treatment.R:11-14` says "public reads and output
  carry take the full manifestation". Public reads use C-3 (memo sources and
  barriers plus `ledgr_history_carry_evidence()`) and never called C-1; only
  output carry calls `ledgr_history_input_carry()`. The map's C-1 row says it
  correctly. LDG-3079's scope sentence has the same slip ("public history
  reads keep the full one").
- N2, shape 5 residue. `ledgr_history_input_carry()` validates its inputs
  (`R/history-treatment.R:86`), then the calculation validates the same
  vectors again (`:24`). The cost is a few vector scans per output-carry
  call; checking once would remove it.
- N3, detector scope. LTB-0393 matches a payload by shape at the top level of
  the caller's frame. X4 keeps the payload inside another list
  (`held <- list(p = payload)`) and survives. LCL-0383 claims "under any
  name", which is accurate; nested retention is outside it.
- N4, record. The closeout's seven-shape walk shortens four of the manual's
  names ("One-row frame per element", "Per-element parsing or formatting",
  "Per-row JSON", "Work computed and discarded"). `review_obligations` asks
  for them verbatim. The Workstream 46 closeout did the same and was accepted.
- N5, equivalent mutant (inherited). X6 drops `!terminal_barrier` from the
  calculation's admissible observations and survives every related block.
  It is equivalent: an observation at a barrier column is always removed by
  `crossed_barrier`, because its own column is the latest barrier. By the
  same argument the `expected` term is redundant (not mutated). Both terms
  are BASE C-1's.
- N6, record. The engine digest also changes the `feature_engine_version`
  attribute of every availability sweep result and the persisted sweep row
  (`R/sweep-persistence-schema.R:72`). My probe does not record it (no
  digest hit in any sweep family), and the implementer's runner uses the same
  column-subset canonicalization, which drops the attribute. The closeout's
  "five differing families" describes what its runner records, not every
  carrier of the digest. That is consistent with
  decision (25); a sentence in the closeout would make the record complete.

## Acceptance items

| Item | Result |
| --- | --- |
| 3078-1 run, sweep (sequential, two-worker), window, walk-forward, inspection, history-read and refusal results byte-identical, including reordered reads and late overlays | Met. `e2e47.R` 70 of 70 after digest normalization, covering the runner's blind spots (two-worker under three policies, all five fields in two in-strategy orders, provider views on four membership shapes, refusals at every entry point). Direct reads order-invariant on both trees. |
| 3078-2 structural detector for a retained payload, a removed membership column or a per-field barrier copy | Met. R-A1 and R-A2 (payload), R-B1, X1 and X7 (plan columns), Y3 (per-field barrier copy) and X2 (barrier not kept per mask) fail LTB-0393 or LTB-0391. Nested retention is outside LTB-0393 (N3). |
| 3078-3 retained sizes before and after at H1; peak private commit of a two-worker sweep | Met. Sizes not re-measured (they reproduce the audit's figures). Peak measured; my two pairs agree with the candidate's level (2,725-2,738 MiB parent) but the recorded reduction is stated against BASE's high mode only (F3). |
| 3078-4 seven shapes walked | Met (names shortened, N4). |
| 3079-1 feature values and every retained evidence plane byte-identical across the catalogue, TTR multi-output, custom fn/series_fn, gaps, relistings and late facts | Met. Every input a definition can consume is identical (6,912 records). The diff changes no calculation code after the inputs, so this holds for the whole catalogue, not only the 15 definitions the runner names (inference from the diff plus the records). Feature frames and planes in `e2e47.R` and `inputs47.R` are identical. |
| 3079-2 engine identity change recorded with its reason; digest literals change only for it | Met. The record is complete apart from N6 (sweep attributes). F2 is a detector side effect of the new name. |
| 3079-3 detector if feature inputs build the discarded evidence again; detector if carry disclosure is lost | Met. R-D1 and Y1 fail LTB-0392. |
| 3079-4 H1 feature preparation time before and after, audit mix and a broader catalogue mix | Met. My attribution runs support the closeout's figures and its inference about the small catalogue-mix gain (Timing). |

## Mutations (mutation copy, restored byte for byte)

`R-` re-runs one of the implementer's mutations per claimed detector on the
decision (26) tree; `X`/`Y` are mine.

| ID | Mutation | Block | Result |
| --- | --- | --- | --- |
| M0 | none | LTB-0391, 0392, 0393, 0144 | 21, 9, 8, 23 expectations; none failed |
| R-A1 | fresh sweep keeps the payload (no `rm`) | LTB-0393 | fails (3) |
| R-A2 | pulse inspection keeps the payload | LTB-0393 | fails (1) |
| R-B1 | plan keeps every set-row column | LTB-0391 | fails (1) |
| R-D1 | feature inputs call the full manifestation | LTB-0392 | fails (1) |
| R-D4 | the calculation leaves the engine payload | LTB-0144 | fails (2) |
| R-E1 | decision (26) collection dropped | LTB-0393 | fails (1) |
| X1 | set rows also keep `universe_id` | LTB-0391 | fails (1) |
| X2 | mask barrier never written back to the memo (rebuilt per read) | LTB-0391; LTB-0298 | fails (4); survives (values unchanged) |
| X3 | feature inputs carry across the terminal barrier | LTB-0391-0393 and every block in four history/indicator files | only LTB-0320 fails (4) |
| X4 | fresh sweep keeps the payload nested in a list | LTB-0393 | survives (N3) |
| X5 | collection only when `workers > 1` | LTB-0393 | fails (1) |
| X6 | calculation drops `!terminal_barrier` from admissible observations | as X3 | survives everywhere: equivalent (N5) |
| X7 | intervals keep `instrument_id` instead of `fact_id` | LTB-0391 | fails (2) |
| X8 | the manifestation leaves the engine payload, calculation kept | LTB-0144 | fails (1), on the digest literal only (F2) |
| Y1 | feature inputs drop the input-carried flag, values kept (the implementer's D3 shape) | LTB-0392 | fails (2) |
| Y2 | a late overlay row reads the base mask's barrier (the implementer's C2) | LTB-0391; LTB-0298 | fails (3); survives |
| Y3 | field entries store their own barrier copy again (the implementer's C1) | LTB-0391 | fails (6) |

## F03: readers of the membership plan on BASE

Each reader was read on BASE `2ef0f2da`, not only located by search.

- `ledgr_availability_prepared_membership_plan()` is called by
  `ledgr_availability_provider_prepare()` (`R/availability-provider-prepared.R:356`)
  and the test seam `ledgr_availability_prepared_membership()`.
- The stored plan (`provider_plan$membership`) is read only by
  `ledgr_availability_provider_from_plan()` (`:465-468`), which hands it to
  `ledgr_availability_prepared_membership_from_plan()`. That function and
  `ledgr_membership_advance_prepared_header()` read `set_index$rows$instrument_id`,
  `set_index$rows$fact_id`, `set_index$by_header`, `headers$set_id` (resolver
  winners) and `interval$fact_id` (resolver winners), plus the compiled
  vectors. `advance_prepared_header()` receives `headers` and never reads it.
- Every production consumer reaches the plan through that one function:
  - the fold's decision and execution views (run, sweep, window,
    walk-forward), through `ledgr_availability_provider_from_substrate()`;
  - workers, which rebuild the provider from the staged substrate's plan;
  - pulse inspection, through the same substrate provider;
  - the results reader and INCOMPLETE reopen (R15), through
    `ledgr_availability_provider()`, which prepares a plan and calls
    `from_plan()`.
- The decision (24) membership counter reads `data$membership`
  (`R/history-substrate.R:977`), not the plan. The canonical resolver and
  public fact inspection build their own set index from the fact rows.
- Tests read `header_complete` (a vector, kept) and the dev size script
  measures the plan's size.

No removed column had a reader. My provider family exercises the trimmed
plan on complete, incomplete, interval, empty-set and decoy shapes in three
query orders; all identical.

## F04: barrier sharing

- `ledgr_history_carry_last_barrier()` is the old second half of
  `ledgr_history_carry_positions()`, verbatim; it takes only the masks.
  `ledgr_history_mask_barrier()` builds it once per memo key (`base_masks`,
  `overlay_<i>_<e>`) from that key's own masks and writes it back to the same
  key. A late overlay row therefore reads its own epoch's barrier, as BASE's
  overlay positions did.
- The memo entry is replaced, not mutated, so a mask read before the
  barrier existed is recomputed at most once more (no wrong answer). Build
  counters are unchanged because the barrier does not go through
  `ledgr_history_memo_value()`.
- Order: my direct-read families on both trees give the same 500 reads
  forward and backward and the same 100 reads late-first, and the memo key
  sets agree. Overlays `2_0`, `2_1`, `3_0` and `7_0` are built (two epochs on
  the relisted instrument).

## F02: one calculation, two projections

- `ledgr_history_input_carry_calculation()` is BASE C-1's body up to
  `treated[!expected] <- NA_real_`, verbatim except that it does not take or
  check `axis`. `ledgr_history_input_carry()` keeps the full validation,
  calls the calculation and runs BASE C-1's remaining lines verbatim. No
  third formula: C-2/C-3 (`ledgr_history_carry_source()`,
  `ledgr_history_carry_last_barrier()`) were already the second
  implementation and are only split.
- Callers: feature inputs call the calculation (`R/history-features.R:197`);
  output carry calls the manifestation (`R/history-treatment.R:467`); public
  reads use C-3 and never called C-1.
- Disclosure: feature evidence reads `inputs$carried`, which the
  calculation returns unchanged, so `input_carried` and
  `carried_input_excluded` are unchanged (LTB-0392 literals; `inputs47.R`
  planes; e2e feature frames).
- Identity: the availability payload of `ledgr_feature_engine_version()`
  now hashes the calculation as well as the changed inputs and
  manifestation bodies; the digest moves to `0072232f...d508`, the dense
  digest is unchanged. In my records the digest appears only in
  precomputed objects and their projections; run and walk-forward records
  carry no engine string. Sweep results carry it as an attribute (N6).

## Decision (26)

- Placement: `invisible(gc(verbose = FALSE))` follows `rm(payload)` in the
  fresh-preparation block of `ledgr_sweep_impl()` (`R/sweep.R:330-331`),
  before `ledgr_sweep_candidate_tasks()` and staging. It matches the
  decision's wording ("a fresh sweep ... immediately after it releases the
  feature payload, before staging workers").
- Where it runs: every fresh sweep, so also sequential sweeps (nothing is
  staged), dense fresh sweeps and every walk-forward training fold
  (`ledgr_walk_forward()` calls `ledgr_sweep_window()` per fold without a
  precomputed payload). It does not run for precomputed sweeps or pulse
  inspection.
- Structural test: LTB-0393 finds the one top-level statement of
  `ledgr_sweep_impl()` that contains `rm(payload)` and requires the
  collection to follow it. R-E1 and X5 fail it. It is a source-text check;
  reformatting the block would need the expected text updated, which is
  acceptable for a check whose subject has no observable result.
- Cost: at H1 the one collection takes 0.08-0.11 s of a 110 s two-worker
  sweep (traced in my memory runs), so it is negligible there. On small
  sweeps and in the test suite it is not (F1).

## Test changes

- LTB-0144 and LTB-0276: only the availability digest literal changes, for
  the stated F02 reason; LTB-0144 also lists the calculation. Valid. See F2
  for a substring effect of the new name.
- LTB-0391 (new) gained literal barrier reasons after C2 first survived.
  That strengthens a new block. Valid.
- LCL-0383/LTB-0393 grew the decision (26) structural check. Valid; it is a
  source-text check by necessity, since the collection changes no result.
- No existing oracle, fixture or setup changed.

## Clean

- Seven shapes (names as in the manual) on the changed functions:
  - One-row frame per element, bound at the end: none.
  - Full-table subset inside a loop over ids: none; the plan trim is three
    column subsets once per plan.
  - Per-element parsing or formatting where a vectorised call exists: none;
    `ledgr_history_overlay_key()` formats once per overlay entry, as before.
  - Per-row JSON on repetitive strings: none.
  - Work computed and discarded, or recomputed on every call: removed in
    F02, F03 and F04. One small residue: `ledgr_history_input_carry()`
    validates its inputs and the calculation validates them again (note N2).
    The test-only C-2 path now builds the column matrix twice; production
    reads build it once per field and once per mask.
  - Quadratic validators: none.
  - Scalar writes into an environment-held vector: none; one `assign()` per
    mask.
- Mode branches: census unchanged, 158 branch and 55 flow sites. The
  decision (26) statement sits in the shared fresh-preparation block and adds
  no branch.
- Claims: LCL-0381..0383 and LTB-0391..0393 lie in the reserved ranges, each
  LCL maps to one block, profiles match the block headers.
- Encoding: every added line is ASCII; `git diff --check` is clean.

## Verification record

- Full suite on the candidate copy (`load_all()` then `test_local(...,
  stop_on_failure = FALSE, load_package = 'none')`): 1,150 blocks, 18,504
  expectations, 0 failures, 0 errors, one optional skip (the Yahoo
  missing-package path), 713 s of block time. This matches the closeout's
  decision (26) record.
- Census `--mode=check`: `LEDGR_CODEBASE_CENSUS_OK` (helpers 1,809,
  conditions 2,396, findings 72), `LEDGR_MODE_BRANCH_CENSUS files=29
  functions=55 branch_sites=158 flow_sites=55`. `--self-test-mode-branches`:
  `LEDGR_MODE_BRANCH_SELF_TEST_OK`. Fold-phase: `LEDGR_FOLD_PHASE_CONTRACT_OK`.
- Identity: `e2e47.R` 70 of 70 families after digest normalization (67 raw);
  BASE run twice, 69 of 69 shared families identical (my first run had a
  probe error in the dense family); `inputs47.R` 6,912 of 6,912 raw;
  direct reads order-invariant on both trees.
- `git diff --check 2ef0f2da..40d6139b` is clean; every added line is ASCII.
- Not run: the implementer's runner (its records were read, not re-run), the
  H1 audit parity checker, the fast, review and heavy profiles, and
  `R CMD check`.

## Timing and memory (disclosure)

Settings for every H1 row: the reused H1 snapshot (`ws47/h1/h1.duckdb`,
1,166 instruments by 7,213 sessions), High performance plan, affinity
`0xFFFF` set on the launching PowerShell process, `Rscript.exe` by full path,
BASE then candidate, no R process I did not start. One run per arm per
order; these are attribution runs, not a ranking.

Feature preparation (`h1_feat.R`): `ledgr_history_compute_feature_series()`
wall time, the time spent inside `ledgr_history_feature_inputs()` (a timing
wrapper, the same on both trees) and `gc.time()` during the call. Digests
equal the implementer's on both trees.

| Order and mix | BASE total / inputs / GC s | Candidate total / inputs / GC s | Total change |
| --- | --- | --- | ---: |
| Audit mix first in process | 14.52 / 7.25 / 1.30 | 10.00 / 3.96 / 0.81 | -4.52 s (-31.1%) |
| Catalogue mix second in process (closeout's order) | 97.61 / 4.41 / 11.21 | 95.47 / 2.56 / 11.47 | -2.14 s (-2.2%) |
| Catalogue mix alone, first in process | 97.76 / 4.86 / 11.61 | 96.48 / 2.56 / 11.20 | -1.28 s (-1.3%) |

The closeout's catalogue-mix figure (-1.6%) holds for a fresh process too,
and its inference is supported. The same 1,209-1,210 input preparations
cost 7.25 s on BASE in the light audit run but 4.4-4.9 s in the heavy
catalogue run, and F02 saves 3.3 s of input preparation in the first against
1.9-2.3 s in the second. In the audit run a further 1.2 s of the saving
falls outside input preparation. Collection time in the catalogue run is
11.2-11.6 s on both trees, so it is set by the indicator calculations, not
by the discarded evidence. Inference: the extra cost in the light run is
memory management (collection and heap growth) that the discarded evidence
triggers when little else allocates.

Two-worker fresh sweep with features (`h1_sweep.R`, the implementer's
sweep-mode workload: returns 20 and 60, two candidates, seed 41; private
commit sampled every 250 ms by the implementer's driver, retargeted to my
copies as `mem_pairs.ps1`; `base::gc` traced):

| Pair | BASE parent / tree MiB | Candidate parent / tree MiB | BASE / candidate sweep s | Collection s |
| --- | --- | --- | --- | ---: |
| 1 | 3,267.0 / 4,751.8 | 2,738.2 / 4,741.8 | 115.3 / 110.1 | 0.08 |
| 2 | 3,852.2 / 5,970.2 | 2,725.3 / 4,727.1 | 114.0 / 110.0 | 0.11 |

All four result tables are serialization-identical. In every run the parent
and tree peaks fall at the same sample, about 14-18 s into the sweep. On the
candidate that is shortly after the traced collection (13.5 s), where the
implementer's time series puts worker staging. BASE pair 1 is in BASE's low
mode, pair 2 in its high mode (F3).

Small-sweep and test-file costs of the decision (26) collection are in F1.

## Review ratio

Three findings (F1-F3) over eight acceptance items (four each for LDG-3078
and LDG-3079): 3/8 = 0.375. None is blocking for product behavior. F1 needs a
maintainer choice on the scope of decision (26). N1-N6 are notes, not counted.
