# WS43 / LDG-3065..3067 close review (Type 1), `42df9de9..6680bdb7`

## Verdict: CHANGES_REQUIRED

The indicator history system is in place and mostly well detected:
declarations and the 48-row catalogue, rule-4 identity and the store
binding, one calculation over the WS41 treated substrate, decision (13)
input-carry exclusion, the sampled causality and pair checks inside
preparation, the decision (18) FAILED run row, the deleted sweep helper and
the retained carry planes on history frames. The comparable four-definition
preparation is about 30 percent faster than the accepted base, and the
14-definition cost scales linearly.

One contract sentence written by this workstream contradicts the bound
data-start rule (F1). The public frame still reports feature reasons with
the WS42 placeholder vocabulary, although the WS42 route is marked closed
(F2). A dispatch change that alters dense and availability feature values is
undisclosed and has no detector (F3). The sticky terminal barrier on feature
input carry has no semantic detector (F4). The remaining findings are cost
disclosure, detector gaps and record text. None asks to reopen v12 or Cut 16
decisions (13) to (18), so this is not NEEDS_TYPE_2. One maintainer note is
recorded at the end.

Method:
- Read the diff, `indicator_history_closeout.md`, the Cut 16 decisions
  (1)-(18), WS43 and LDG-3065..3067, v12 Sections 5, 6, 9, 10 and 12, the
  WS43 contract receivers, LCL-0301..0310, the four WS43 test files and every
  changed registered block.
- Full suite once on a source copy after `load_all()`: 1,136 blocks, 0
  failures, 0 errors, one optional skip (Yahoo missing-package path), 705 s.
  No `_problems` artifacts.
- `tools/check-fold-phase-contract.R`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.
  `tools/check-codebase-contracts.R --mode=check`:
  `LEDGR_CODEBASE_CENSUS_OK`. `git diff --check 42df9de9..6680bdb7` is clean,
  and the changed files are ASCII.
- `tests/claims.yml` parses: 304 claims, no duplicate IDs. LCL-0301..0310 map
  to LTB-0307..0318, one test block each, with no orphan and no reuse.
- 12 mutations on a source copy, each restored (table below), plus seven
  probes: shadowed built-in IDs, terminal relisting, late-known ranges, frame
  evidence with a two-worker sweep, a base-tree store opened on this tree,
  the aroon dense fingerprint, and reduced-shape preparation timing on the
  base `42df9de9` and this tree.
- Timings are single runs on a shared host and are disclosure only. The
  conclusions rest on ratios, counts and values.

## Findings

### F1 (blocking, contract): features are said to start at the scoring start

`inst/design/contracts.md:1965-1966` (Availability-Aware Strict Features,
LDG-3066 receiver) says: "Features are calculated only inside each window's
scoring start and end." This sentence is new in this diff. It contradicts the
History start rule at `contracts.md:155-160`, which says history has one
start, the data start, and the scoring start bounds decisions only. It also
contradicts the code: the runner (`R/backtest-runner.R:1168-1173`), the sweep
payload (`R/sweep.R:312-316`) and explicit precompute
(`R/precompute-features.R:85-91`) all calculate from
`ledgr_history_calculation_start()`, which is the data start. LTB-0196 pins
that rule.

Fix: "Features are calculated from the data start through each window's
scoring end (see Scoring And Feature Start)."

### F2 (medium; correct the record, the product change may be routed): frame feature reasons are still placeholders

`R/history-frame.R:291-311`. The follow-up replaced the input-carry and
output-carry placeholders. The reasons, readiness and validity are still
derived from one test. `missing_reason` is `not_calculated` for every
expected cell that is neither calculated nor output-carried. Warm-up,
re-warming after a restart, a required input missing beyond the carry
horizon, a carried input excluded for a return-family row, an expired output
carry and a cell outside the calculation range therefore all read the same.
`calculation_valid` is `calculated` by construction, and `ready` is
`calculated | output_carried`.

The internal seam `ledgr_history_feature_planes()` computes all of these
distinctions. Its columns share names with the frame's columns but carry
different meanings: in the seam, `calculated` means admitted and `ready`
means `stable_after` was reached.

v12 Section 5 requires aligned evidence that distinguishes "warm-up,
structural absence and later gaps" and the applicable exclusion reason.
Section 6 and Cut 16 decision (4) keep admission, readiness and calculation
validity as separate evidence. The WS42 route ("readiness, output carry and
calculation validity replace the placeholders") is marked "Closed ... by
Workstream 43" at `public_causal_history_closeout.md:407-410`, but only
carry was replaced.

Evidence (`evidence_probe.R`, the LTB-0318 fixture with `output_carry = 2`,
cutoff session 8). BBB `ret` at session 1 is warm-up, and at session 5 the
return window needs the missing session-4 raw close. The frame reports
`not_calculated` and `calculated = FALSE` for both sessions. The seam reports
`not_ready`, with `calculated = TRUE` (admitted) for both. At sessions 3-4
the frame says `ready = TRUE` and the seam says `ready = FALSE`. By reading
`R/history-frame.R:295`, an SMA cell missing beyond carry and a warm-up cell
are also both `not_calculated`.

Smallest fix: retain, beside the carried exceptions, the admitted-but-not-
ready cells and the not-admitted cells with their reason (required input
missing, carried input excluded, outside calculation, output carry expired).
Both sets are bounded by warm-up times segments and by missing cells, the
same order as the carried exceptions. Derive the frame reasons from them, and
align or rename the seam's `calculated` and `ready` columns. If the
maintainer prefers to route the product change, reword the route to "open",
state the reduced feature reason vocabulary in the Inspection contract, and
record a disposition against v12 Section 5.

### F3 (medium): undisclosed, undetected change to feature dispatch in both modes

`R/backtest-runner.R:1590-1640` (`registered()` and `shadowed()` in
`ledgr_feature_defs_from_config()`, added in 0602a93d). A user indicator
whose ID matches a built-in pattern (`sma_<n>`, `return_1`) and whose stored
fingerprint differs from the built-in now computes its own functions. Before
this change it silently computed the built-in.

Probe (`shadow_probe.R`, `shadow_avail.R`):
`ledgr_indicator("sma_3", function(window) 42, requires_bars = 3L,
gap_contract = "strict_window")` in a public run.

| Tree | dense values seen | availability values seen |
| --- | --- | --- |
| base `42df9de9` | NA, NA, 11, 12, ..., 16 | NA, NA, 102, ..., 105 |
| `6680bdb7` | NA, NA, 42, ..., 42 | NA, NA, 42, ..., 42 |

The new behavior is correct, and it was needed for availability
certification by claimed identity. But it changes dense economics while dense
is frozen, and decision (14) is the only accepted dense change. It is absent
from the closeout, NEWS and `tickets.yml`. Mutation R12 (`shadowed()` always
FALSE) leaves 181 related blocks green (filter
`indicator|strict|availability-features|feature|acceptance|backtest|runner`).

Fix: register a run-path block for both modes that pins own-function
computation and the fingerprint-mismatch refusal for a shadowing ID. Record
the dense change in the closeout and NEWS, and ask the maintainer to accept
it as a decision (14)-style bug fix.

### F4 (medium, detector gap): the sticky terminal barrier on feature input carry is unprotected

`R/history-features.R:189-196` passes `terminal_barrier = terminal` to the
WS41 carry primitive. Mutation R6 (`rep(FALSE, prefix_end)`) fails only the
LTB-0144 and LTB-0276 engine-digest literals. Those are tripwires for any
edit to a hashed helper, not semantic detectors.

Probe (`terminal_probe.R`, one instrument): a delisting makes sessions 4-6
inactive, a relisting print arrives at 7 and session 8 is missing.

| | SMA(2), sessions 7-10 | TTR EMA(2), sessions 7-10 |
| --- | --- | --- |
| tree | 14.5, NA, NA, 19.5 | NA, NA, NA, 19.5 |
| R6 mutation | 14.5, 17, 18, 19.5 | NA, 17, 18.33, 19.44 |

Fix: add this relisting case to LTB-0310 or LTB-0313, with values and the
`input_carried` plane.

### F5 (low, record and route): each lagged knowledge range recomputes the whole prefix

`R/history-features.R:438-466`. For every lifetime or terminal fact learned
after the column it changes, the instrument's inputs are re-treated from
session 1, and every definition is recomputed from the calculation start to
that range's end. The cost per instrument is therefore proportional to
(lagged facts + 1) times the prefix length.

Probe (`late_ranges.R`, 20 x 2,000, three definitions, K lagged inactive
intervals on one instrument):

| K | ranges | seconds |
| ---: | ---: | ---: |
| 0 | 1 | 0.64 |
| 5 | 6 | 0.67 |
| 20 | 21 | 0.88 |
| 50 | 51 | 1.41 |

Each extra range costs about 0.015 s, roughly half that instrument's full
cost. At K = 50 the instrument costs about 25 times an unlagged one. Growth
is bounded by the lagged-fact count, not by history length squared. The
closeout's seven-shape item 2 says "once per knowledge range" without this
factor, and its scale panel has at most one lagged fact per instrument.

Fix: state the factor in the closeout. Ask LDG-3070 to report lagged
lifetime and terminal facts per instrument. If material, let WS46 start each
later range at the start of the segment that holds the earliest changed
column.

### F6 (low, detector gaps)

- One probe per definition, on the instrument with the most calculated cells
  (LCL-0308 scope, Feature Path contract). R11 (probe every instrument) and
  R4 (probe the first instrument) pass every block. Every counting fixture
  has one instrument: LTB-0153's `availability_runtime_fixture()` holds only
  AAA, and LTB-0143 and LTB-0316 use one-instrument substrates. The claim
  "does not grow with the instrument count" rests on `checker_scale.csv`
  only. Fix: add a two-instrument count to LTB-0316. Give one instrument more
  calculated cells, and assert four recomputations and that instrument as
  the probe, for example through a refusal's `instrument_id`.
- R10: taking input-carry exceptions from all price fields instead of the
  required fields passes LTB-0318, because the fixture's OHLC gap is joint.
  Fix: add a single-field gap (for example, `high` missing only) for a
  close-only definition.
- R9: a slice that does not re-index the planes passes. In the product, the
  availability slice is the identity after exact axis validation
  (`R/sweep.R:331-343`), so the path is unreachable today. Reading confirms
  that `ledgr_projection_slice_planes()` is correct. Test it directly or
  leave it as a note.

### F7 (record-only)

- `NEWS.md:42-44` ("dense fingerprints are unchanged") and
  `contracts.md:1978-1980` ("Dense indicator fingerprints ... remain
  unchanged") are both false for TTR aroon. Verified: `requires_bars` 20 ->
  21, and the dense fingerprint changes from `099da788...` to `c9ebda94...`.
  NEWS also omits the extra dense aroon warm-up row that decision (14)
  accepted. SMA and EMA dense fingerprints and the dense engine digest are
  unchanged.
- `contracts.md:1958-1959` says that return- and volatility-family output
  "is `NA_real_` wherever a required input is missing or carried". With
  output carry enabled, LTB-0318 pins a return value carried as output over
  BBB's missing sessions 3-4. Qualify the sentence ("their calculated
  output ...; optional output carry may still fill it, disclosed as
  `output_carried`"), or get the maintainer's reading of the v12 Section 5
  sentence.
- The closeout is stale after the follow-up. Lines 115-116 say "Preparation
  stores values only", and seven-shape item 7 (lines 586-587) says "Evidence
  is recomputed on demand by the same calculation".
- `tickets.yml` LDG-3067 evidence says "Implementation in the LDG-3067
  commit". Name `603966ec` and `6680bdb7`.

## Acceptance table

LDG-3065

| Acceptance item | Result |
| --- | --- |
| exact catalogue declarations incl. multi-output and variants | pass (LTB-0307 literal catalogue, LTB-0308 per-row certification; read) |
| contradiction, `stable_after >= requires_bars`, unregistered TTR follows custom rules | pass (LTB-0307) |
| undeclared custom is disclosed history-dependent; bounded needs valid width | pass (LTB-0307; LTB-0310 undeclared width probe) |
| each calculation-affecting declaration changes rule-4 identity; display-only does not; golden fixtures | pass (LTB-0309); base-tree store refused at open with `ledgr_store_rebuild_required` (fingerprint), no compatibility code |
| admission ignores unrelated fields and names every blocking field | pass (LTB-0311 `high,close`; R5 fails LTB-0311) |
| constructors usable, classed invalid combinations, no convergence | pass |

LDG-3066

| Acceptance item | Result |
| --- | --- |
| registered rows over all families, gaps, expiry, restart, readiness | pass (LTB-0310, LTB-0313; R8 detected) |
| bounded equals window oracle; history-dependent per segment without all-prefix work | pass; lagged-range recomputation cost F5 |
| default carry changes eligible outputs; no-carry keeps old values; LCL-0142/0274 reason | pass (R5 fails LTB-0142 and LTB-0310) |
| planes independently detectable; return/volatility never consume carry; inactive prints | pass on the internal seam (LTB-0311, LTB-0314; R5 detected); public frame reasons lossy, F2 |
| custom pairs agree within tolerance; history-dependent pair not refuted; fn-only exact window | pass (LTB-0310, LTB-0317) |
| bytes, parity and failure class across one and two workers | pass (LTB-0312 in the suite; frame evidence identical across sequential and two-worker sweeps in `evidence_probe.R`) |

LDG-3067

| Acceptance item | Result |
| --- | --- |
| removing, moving or weakening the prefix check fails; refusal precedes strategy, ledger, equity and sweep/precompute artifacts; FAILED run under (18) | pass (R1, R2, R3 detected; LTB-0315 asserts zero rows and one FAILED row) |
| pair refutation with tolerance, not for history-dependent, no catalogue re-derivation | pass (LTB-0317; R1 detected) |
| fixed bounded sample; growth measured | pass for history length; instrument dimension unregistered (F6) |
| helper absent; three fixtures via production precompute without losing assertions | pass (only dated spike, audit and RFC text names it; `test-sweep.R` keeps every assertion and adds a close-value check) |
| valid native, TTR and custom pass; fn-only on exact windows | pass (LTB-0315 window trace) |
| focused suites pass | pass (full suite) |

Contract receivers. Indicator Computation And Identity, TTR Adapter, Feature
Path And Intent Constructors and Indicator Teaching are present tense, and
their pending links are removed. Availability-Aware Strict Features is
present tense with its pending link removed, but it carries F1 and two F7
sentences.

## Mutations (source copy, each restored)

| ID | Mutation | Result |
| --- | --- | --- |
| R1 | causality call removed from preparation | LTB-0315, LTB-0316, LTB-0317 fail |
| R2 | prefix comparison on missingness only | LTB-0315 fails |
| R3 | probe recomputed on the full, untruncated history | LTB-0315, LTB-0316 fail |
| R4 | probe the first instrument, not the most calculated | no block fails (F6) |
| R5 | return family consumes treated (carried) input | LTB-0310, LTB-0311, LTB-0314, LTB-0142 fail (and the LTB-0144 digest) |
| R6 | feature input carry ignores the terminal barrier | only the LTB-0144/LTB-0276 digests fail (F4) |
| R7 | frame ignores retained output-carry planes | LTB-0318 fails |
| R8 | history-dependent rows span inactive intervals | LTB-0310, LTB-0313 fail |
| R9 | sliced planes not re-indexed | no block fails (unreachable today, F6) |
| R10 | input-carry exceptions from all price fields | no block fails (F6) |
| R11 | probe every instrument with calculated cells | no block fails (F6) |
| R12 | shadowed built-in ID dispatch disabled | no block fails among 181 related blocks (F3) |

## Registered oracle changes

- LTB-0259: names `ledgr_feature_history_rule_version` (27 bindings). The
  reason is valid. A store created on `42df9de9` refuses at open on this
  tree, and no migration code exists.
- LTB-0297 and LTB-0300: the new literals follow from the fixture closes
  under five-session carry. BBB: (22 + 22) / 2 = 22, (22 + 25) / 2 = 23.5,
  (25 + 26) / 2 = 25.5. CCC: (35 + 35) / 2 = 35 at session 6, because CCC's
  inactivity is known only at session 7. `used_before_window` TRUE is
  correct, because the session-5 value reads session 4. This is the v12
  Section 5 reason, not a bent oracle.
- LTB-0299: the move to `ledgr_ind_returns(1)` keeps the block's subject
  (estimator exclusion is not execution intent). The carried SMA values it no
  longer shows are pinned by LTB-0297 and LTB-0300. Valid.
- LTB-0143 (`7 * (1 + 1 + 4)`) and LTB-0276 (`2 + 5`, `3 + 5`, `3 + 2 + 3`):
  each count follows from one probe segment plus four sampled prefixes, with
  catalogue cache reuse where the last segment is unchanged. The per-window
  claims still hold, and LTB-0143 gained tampered-definition cases. Valid.
- LTB-0144 and LTB-0276 digests: the availability literal changes because
  hashed helpers changed. The dense literal `80d1ae6d...` is unchanged.
  Valid.
- LTB-0153: the preparation oracle is unchanged (80 and 160 rows, two calls,
  ratio 2). The checker's segment work is counted apart: exactly 10 calls and
  at most five passes. A per-prefix checker or a second full preparation
  inside the check would fail it, so the split did not weaken the
  preparation claim. Its one-instrument fixture cannot see the instrument
  dimension (F6).
- LTB-0315: strengthened with the decision (18) assertions.
- LTB-0142, LTB-0073, LTB-0074, LTB-0093, LTB-0157 and LTB-0292 changed for
  the stated v12 Sections 4-6 and decision (13)-(15) reasons. Each is
  consistent on reading, and R5 and R8 confirm that LTB-0142 and LTB-0093
  still detect.

## Clean

- One treatment rule: feature inputs use WS41's `ledgr_history_input_carry()`
  and `ledgr_history_output_carry()`. Admission is LDG-3065's own primitive.
  No second carry, barrier or estimator-admission rule was added.
- Decision (13): catalogue membership and the custom
  `input_carry = "excluded"` declaration route through raw inputs
  (`fields <- inputs$raw`), and a re-declared catalogue row refuses (R5
  detected by four blocks). Decision (14): verified on the dense
  fingerprint. Decision (15): bounded windows count expected sessions and
  history-dependent rows restart (R8 detected). Decision (16): every
  availability entry point calculates from the data start. Decision (18):
  pinned by LTB-0315.
- Dense frozen: the diff adds no `availability_active` branch. The runner
  branch is restructured, the `ledgr_config()` and stored-fingerprint
  branches predate this work, and the dense precompute payload lost its
  availability argument. The exceptions are aroon (decision 14) and F3.
- Causality runs inside `ledgr_history_compute_feature_series()`, so it
  precedes run artifacts (other than the FAILED row), sweep candidates and
  precompute payloads on every availability route. Those routes are the
  runner, the sweep payload, explicit precompute and pulse inspection
  (`R/pulse-snapshot.R:455`).
- Frame evidence: no per-read recomputation, only `findInterval` over the
  retained sorted indices. A projection without planes refuses. The run,
  sweep, explicit-precompute and pulse-inspection routes all carry planes,
  and the two-worker sweep reads identical evidence. No public path still
  returns the WS42 carry placeholders.
- Preparation cost (own probe, `scale.R` on a reduced shape):

  | Tree | Config | Shape | Seconds | Heap MB |
  | --- | --- | --- | ---: | ---: |
  | base `42df9de9` | parity, 4 defs | 300 x 1,803 | 6.86, 6.87 | 289 |
  | `6680bdb7` | parity, 4 defs | 300 x 1,803 | 4.81, 4.78 | 326 |
  | `6680bdb7` | parity, 4 defs | 600 x 1,803 | 9.08 | 383 |
  | `6680bdb7` | parity, 4 defs | 300 x 3,606 | 8.99 | 409 |
  | `6680bdb7` | realistic, 14 defs | 300 x 1,803 | 10.86 | 381 |

  Doubling instruments or sessions costs 1.9 times. The realistic set runs at
  1.43 microseconds per cell-definition, in line with the closeout's 1.33 to
  1.39. The reported 152.6 s at 1,166 x 7,213 x 14 is therefore the linear
  cost of 14 definitions, not a regression: the comparable four-definition
  work is about 30 percent faster than the base. The other ten definitions
  have no base comparator, because the base refused them. The heap is 13
  percent higher at this shape, consistent with the routed LDG-3069 note.
- Seven shapes on preparation, projection and the frame reader:
  - The per-instrument and per-segment loops have stated reasons. The
    per-window `mean()` for SMA predates this work, and the per-window custom
    `fn` call runs user code.
  - The checker loops over definitions and at most four positions.
  - Planes use `rep`/`unlist` and binary search, with no row-wise JSON or
    hashing.
  - The exception is F5.
- Teaching: `stable_after` is taught as first-valid, the measured recovery
  ranges are cited as evidence, and both checks are described as samples.
  The `missing-data-and-sessions` default-carry numbers (12 and 13) are
  correct.

## Maintainer note (not a finding)

Decision (15) applied to a terminal interval lets a bounded window mix
pre-delisting and post-relisting prints. In `terminal_probe.R`, SMA(2) at the
relisting session is mean(12, 17) = 14.5, while carry across the same
boundary stays permanently barred. The decisions, read literally, permit
this. Whether a terminal interval should also end bounded windows is the
maintainer's call.

## Review ratio

Seven findings (F1-F7) over eighteen acceptance items: 7/18 = 0.389. One
finding is blocking (F1). F2 and F3 need a record correction and a
maintainer disposition or fix.
