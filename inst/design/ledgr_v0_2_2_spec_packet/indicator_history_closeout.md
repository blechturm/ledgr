# Cut 16 Workstream 43 closeout: indicator history semantics

Implementation commits: `0602a93d` (LDG-3065) and `73eec63e` (LDG-3066).

Status: phase 1 of the workstream. LDG-3065 and LDG-3066 are implemented,
evidenced and green on the full suite. LDG-3067 stays open: it depends on
Workstream 42's LDG-3063 (both touch production precompute) and resumes after
the coordinator merges the reviewed Workstream 42 branch. The independent
Type 1 close review covers the whole workstream after LDG-3067.

## Necessity and scope

Historical-projection synthesis v12 Sections 5 and 6 require every indicator
to be bounded or history-dependent, to declare the fields it needs and to be
calculated over the shared treated substrate from Workstream 41. Before this
work the availability path accepted only a narrow strict-window set, refused
EMA, RSI and every other TTR form, calculated windows of `stable_after` rows
on raw bars and ignored the history policy. This phase adds the declarations,
their identity and the calculation. It does not add sampled causality checks,
delete the test-only sweep helper or rewrite indicator teaching (LDG-3067),
and it changes no dense behavior.

## LDG-3065: declarations, catalogue and identity

`ledgr_indicator()` gains `history_class`, `required_fields` and `tolerance`.
`gap_contract = "strict_window"` declares bounded; with
`history_class = "history_dependent"` it refuses with
`ledgr_indicator_history_contradiction`. A definition without either is
disclosed as history-dependent (`print()` names the default). Invalid classes,
field sets and tolerances refuse with `ledgr_invalid_indicator_declaration`; a
nonzero tolerance is accepted only on a bounded definition with `series_fn`.
`stable_after >= requires_bars` is unchanged. No convergence field exists.

One package catalogue (`ledgr_indicator_history_catalogue()`, 48 rows: 4
built-in and 44 TTR, 12 of them history-dependent) holds the built-in and
registered TTR rows keyed by function, output and
algorithm-changing argument (`maType`, `wilder`), with history class,
required fields, input-carry family and width formula. Built-ins and
`ledgr_ind_ttr()` apply their row; any other argument combination or a
`requires_bars` that differs from the row width follows the custom rules, and
`ledgr_ind_ttr()` accepts `history_class`/`tolerance` for those unregistered
forms only. Classes follow the reviewed H2 conformance census; the spike's
Aroon width witness corrects TTR `aroon` to `n + 1` rows (it returns a
partial-window value at row `n`). LTB-0308 certifies every row on smooth and
1e6-to-1 level-shift fixtures: exact prefix invariance, bounded rows equal
their `requires_bars` window within 1e-4 scaled, history-dependent rows show
retained state above 1e-3. The recorded drift
(`dev/bench/v0_2_2_indicator_history/evidence/catalogue_certification.csv`,
TTR 0.24.4) is at most 2.47e-08 scaled for bounded rows (SMA-variant MACD on
the hostile fixture) and at least 0.99998 for every history-dependent row, so
the classes are separated by more than seven orders of magnitude. The drift
is evidence, not a product tolerance. Six rows extend the spike census by
logic and are certified by the same block: ATR `tr`, `trueHigh` and `trueLow`
with `maType = "SMA"`, and BBands `dn`, `up` and `pctB` with
`maType = "EMA"`.

Rule-4 availability feature identity (`ledgr_active_feature_v2`) binds the
dense fingerprint (which already carries functions, `id`, `requires_bars`,
`stable_after`, params, TTR version and algorithm arguments) plus history
class, gap behavior, required fields, input-carry family, tolerance and a new
feature-history rule version. Declaration provenance and labels are
display-only. The stored availability config definition carries the same
declarations. Dense fingerprints are unchanged except TTR aroon, whose
width change decision (14) accepts (the LTB-0144 literals still hold).
LTB-0309 pins the final rule-4 feature and config golden
fixtures. Because `ledgr_feature_history_rule_version` is a `*_rule_version`
binding, it joins the store-format fingerprint, so stores written before this
commit refuse at open rather than resuming under changed feature semantics;
LTB-0259 records the new binding (27 bindings).

The required-field admission primitive
(`ledgr_history_required_field_admission()`) tests only declared fields and
names every blocking field.

## LDG-3066: calculation over treated segments

`ledgr_history_compute_feature_series(substrate, definitions, start, end)` is
the one availability feature calculation, used by runs and by the sweep
payload (walk-forward reaches it through both). Per instrument it treats the
four price fields once with the Workstream 41 carry primitive (volume never
carried), then calculates every definition:

- Admission tests the declared fields on treated input, or on raw input for
  return- and volatility-family rows, which therefore never consume a carried
  price.
- Bounded rows use segments over the instrument's expected sessions, so a
  window counts expected sessions on the lifetime mask; `fn` receives exactly
  `requires_bars` rows. History-dependent rows use segments on the common
  axis, so a missing input beyond carry or an inactive interval restarts them.
  `stable_after` is the first-valid position after each start or restart.
- Built-ins and catalogue rows are computed with the package constructor's
  functions; certification trusts only the claimed fingerprint, so a
  definition claiming a catalogue identity cannot run replaced code. Built-in
  SMA keeps the bit-exact `mean(window)` series; catalogue TTR rows call TTR
  once per segment, and the outputs of one multi-output call share that call.
- A custom bounded `fn`/`series_fn` pair takes values from `series_fn` and
  refuses with `ledgr_indicator_gap_parity` (feature, instrument, session)
  where `fn` disagrees beyond its tolerance; history-dependent pairs are not
  refuted. Until LDG-3067 samples it, this check runs at every ready window,
  the same order of work as the pre-cut scalar path.
- Lifetime and terminal masks come from facts knowable at each pulse: a fact
  learned after the column it changes splits the calculation range at its
  knowledge pulse, and earlier pulses keep their earlier answer (LTB-0313).
- Optional output carry fills only a session whose own required input is
  unavailable, from the latest earlier valid output within the policy age.

`ledgr_history_feature_planes()` returns the aligned planes for one
instrument and definition from the same calculation: expected, observed,
missing, input carried, blocking field, calculated, ready, calculation valid,
output carried with source and age, missing and barrier reasons, and the
carried-input count and share of bounded windows. Preparation stores values
only.

Recorded behavior changes (v12 Sections 4-6; decisions 13-15):

- Default carry changes eligible built-in outputs across gaps of five expected
  sessions or fewer; `ledgr_history_policy(price_carry = NULL)` reproduces the
  previous strict values exactly, also at the full scale shape below.
- A custom definition whose `stable_after` exceeds `requires_bars` now
  receives `requires_bars` rows; its first-valid boundary is unchanged.
- Only declared fields gate a calculation: an open, high or low gap no longer
  blanks SMA or returns.
- Prints inside a known-inactive interval enter no calculation, and a bounded
  window after the interval spans it (LCL-0093 rewritten).
- `ledgr_indicator_gap_unsupported` is retired; every indicator runs.

The execution-path review's `return_n` finding is confirmed and fixed. A run
rebuilds `return_1` from its config through the legacy id dispatch
(`ledgr_feature_return_1()`, `params = list()`), so the pre-cut kind resolver
returned `NULL` and the run took the per-window scalar path while sweeps used
the vector path. Certification now recognises the stored built-in
fingerprint and computes the canonical constructor's functions. Measured below under Scale.

## Maintainer decisions (Cut 16 decisions 13 to 15)

The phase-1 handoff raised four readings as NEEDS_TYPE_2. The maintainer
decided them on 2026-10-18; they are recorded in the Cut 16 `decisions`
field of `tickets.yml`.

- Decision (13): the return and volatility membership rule is accepted as
  implemented. A catalogue row whose value depends on session-to-session
  price changes or price dispersion has `input_carry = "excluded"`: built-in
  returns and RSI; TTR RSI, ROC, momentum, ATR (all outputs), CCI, BBands
  `dn`, `up` and `pctB`, MFI, runSD, runVar and runMAD. Level rows (SMA, EMA,
  WMA, MACD, BBands `mavg`, aroon, DonchianChannel, CMF, runMean) are
  eligible. The decision added a custom declaration: `ledgr_indicator()`,
  and `ledgr_ind_ttr()` for unregistered forms, accept
  `input_carry = "excluded"`. Undeclared definitions consume the
  policy-treated input and `print()` discloses that default. The declaration
  is already part of the rule-4 feature fingerprint and stored config
  definition; a registered TTR row refuses a declaration, and a copy of a
  built-in or catalogue row that declares another family refuses at
  experiment validation and at calculation with
  `ledgr_indicator_history_contradiction` (LTB-0314).
- Decision (14): the TTR aroon width of `n + 1` applies in dense and
  availability modes. The dense aroon output (one more warm-up row) and
  fingerprint change is an accepted catalogue bug fix, not a dense
  regression; a mode-specific width would need a forbidden mode branch.
- Decision (15): a bounded window counts the instrument's expected sessions
  and so spans a lifetime-inactive interval, while history-dependent rows
  restart; this is the stated reason for the LTB-0093 oracle reversal.
  Readiness restarts per segment when `stable_after` exceeds
  `requires_bars`, and output carry is eligible only where the session's own
  required input is missing.

Decision (13) is implemented in the commit that records these decisions.
LCL-0306/LTB-0314 is the
registered detector; its mutation results are in
`dev/bench/v0_2_2_indicator_history/evidence/mutations_decision13.csv`.

## Merge with Workstream 42 and renumbering

`806897fc` merges `integrate/cut15-v0.2.2` (accepted Workstream 42) into this
branch. Conflicts kept both sides: the runner and precompute now calculate
from WS42's single data-start rule (`ledgr_history_calculation_start()`)
through this workstream's `ledgr_history_compute_feature_series()`; this
workstream's evidence reader is renamed `ledgr_history_feature_planes()`
because WS42 owns `ledgr_history_feature_evidence()`; the Cut 16 decisions
read (1) to (17) in order; the census was regenerated, not hand-merged.

Store format: the integrated experiment-store schema is 122, and
`ledgr_feature_history_rule_version` joins the store-format fingerprint
beside WS42's bindings. There is one current format; a store written before
either change refuses at open with the classed store-format condition, and no
compatibility code is added. LTB-0259 lists the bindings (27); its oracle
changed only by naming the new binding, for that reason.

The renumbering commit moves this workstream's claims to LCL-0301..0306 and
blocks to LTB-0307..0314 (relative order kept; LCL-0307..0320 and
LTB-0315..0330 stay reserved for it). Three WS42 registered blocks changed
their literals for the accepted v12 Section 5 reason (a bounded SMA consumes
policy-carried closes), not to hide a product failure:

- LTB-0297: `fast5$BBB` is `c(22, 23.5)` and `vec_fast` is
  `c(14.5, 23.5, 34.5)` (BBB's carried session-3/4 close enters the SMA).
- LTB-0299: the estimator-exclusion fixture now uses `ledgr_ind_returns(1)`,
  which never consumes a carried price (v12 Section 5), so BBB stays excluded
  from the estimator sample as the block intends; an SMA would now be
  calculated from the carried close.
- LTB-0300: `run6$fast` has AAA, BBB and CCC columns (BBB `c(23.5, 25.5)`,
  CCC `c(34.5, 35)`), no exclusion reasons, and `bbb_fast$BBB` reads
  session 4 before the two-session window (`used_before_window` TRUE).

The full suite on the merged, renumbered tree passes 1,132 blocks with no
failures and the one optional-package skip.

## Detecting evidence

| Claim | Block | Boundary |
|---|---|---|
| LCL-0301 | LTB-0307, LTB-0308 | declarations, contradictions, admission primitive, catalogue certification |
| LCL-0302 | LTB-0309 | rule-4 feature and config identity, golden fixtures |
| LCL-0303 | LTB-0310, LTB-0313 | bounded and history-dependent calculation, gaps, carry, restart, readiness, families, inactive prints, late-known masks |
| LCL-0304 | LTB-0311 | separate evidence planes, output carry |
| LCL-0305 | LTB-0312 | run, sweep and two-worker byte parity and refusal class |
| LCL-0306 | LTB-0314 | custom `input_carry` declaration, identity and catalogue refusal (decision 13) |

Registered blocks changed, each for the stated v12 reason (Sections 4-6
unless noted):

- LTB-0142 (LCL-0142): exact SMA and returns are now checked on required-field
  admission under explicit no-carry and default carry, including the
  1,200-row bit-parity witness.
- LTB-0143 and LTB-0144 (LCL-0143, LCL-0144): dispatch is certification by
  claimed identity; the availability engine digest lists the new helpers and
  its literal changes; dense literals are unchanged.
- LTB-0276 (LCL-0274): the TTR SMA scalar special case is replaced by
  per-segment catalogue computation; hostile claimed identities now prove the
  replaced code never runs.
- LTB-0073 (LCL-0073): the routes run under an explicit no-carry policy so the
  strict literal and calendar table are retained, and the default-carry
  literal is added on the direct and sweep routes.
- LTB-0074 (LCL-0074): the support matrix now records each form's history
  class; history-dependent TTR forms and bundles run instead of refusing.
- LTB-0093 (LCL-0093): Sections 4 and 6 and decision (15) replace the oracle.
- LTB-0153 and LTB-0157: only the observed internal boundary moves (segment
  calculation, certification); expected counts are unchanged.
- LTB-0292: only the call shape of the feature boundary changes.
- LTB-0259: the new rule-version binding (LDG-3065).
- Two unregistered blocks: the omission refusal becomes "undeclared indicators
  run as history-dependent"; the strict scalar contract block uses the
  substrate.
- The TTR parity cases record aroon's first callable row (20) separately from
  its declared width (21).

## Mutation results

Every claimed detector was mutation-checked on a source copy (tracked plus
new files, so worker daemons load the mutated source).

All 14 LDG-3065 and 22 LDG-3066 mutations fail their named registered
blocks (`dev/bench/v0_2_2_indicator_history/evidence/mutations_ldg3065.csv`
and `mutations_ldg3066.csv` list every block that failed).

| Mutation (LDG-3065) | Detector |
|---|---|
| Undeclared definitions default to bounded | LTB-0307 |
| Strict-window/history-dependent contradiction accepted | LTB-0307 |
| Admission tests all price fields | LTB-0307 |
| Unregistered TTR argument resolves to the default row | LTB-0307 |
| Tolerance accepted without a bounded `series_fn` pair | LTB-0307 |
| Aroon width back to `n` | LTB-0308 |
| TTR EMA catalogued bounded | LTB-0308 |
| TTR SMA catalogued history-dependent | LTB-0308 |
| Required fields, tolerance, input carry or class dropped from the active fingerprint (four mutations) | LTB-0309 |
| Declaration provenance added to the active fingerprint | LTB-0309 |
| A declaration dropped from the stored config definition | LTB-0309 |

| Mutation (LDG-3066) | Detector |
|---|---|
| History-dependent rows use expected-session windows | LTB-0310 |
| Bounded windows count inactive sessions | LTB-0310, LTB-0093 |
| fn-only windows of `stable_after` rows | LTB-0310 |
| Returns consume carried prices | LTB-0310, LTB-0142 |
| Admission on all price fields | LTB-0310, LTB-0142 |
| Segments joined across gaps | LTB-0310 |
| Custom bounded parity check removed | LTB-0310, LTB-0312 |
| Declared tolerance ignored | LTB-0310 |
| History-dependent pair refuted | LTB-0310 |
| Lifetime masks resolved at the final cutoff | LTB-0313 |
| Lifetime mask ignored (inactive prints used) | LTB-0310, LTB-0093 |
| Output carry eligible on not-ready sessions | LTB-0311 |
| Only the first blocking field named | LTB-0311 |
| Sweep payload entry paired with the wrong definition | LTB-0312 |
| SMA via `rowMeans(embed())` | LTB-0142 |
| Certification without identity match | LTB-0143 |
| TTR called once per output | LTB-0276 |
| Certified definition runs its own functions | LTB-0143, LTB-0276 |
| History policy ignored | LTB-0310, LTB-0073 |
| Certification per instrument | LTB-0157 |
| Duplicate segment pass | LTB-0153 |
| History-dependent form refused at validation | LTB-0074 |

LTB-0144's availability-engine literal also fails under every mutation of a
hashed helper, as designed. Two first-round mutations showed weaker
detectors than claimed: admitting on all price fields escaped LTB-0310
(default carry masked the high gap) and a certified built-in SMA running its
own functions escaped LTB-0143 (the exact SMA series never calls them).
LTB-0310 gained a no-carry SMA check and LTB-0143 a tampered returns
definition; both mutations then fail. A multi-field blocking mutation fails
LTB-0311 only, so LCL-0301 does not claim it.

## Scale

Feature preparation for one substrate, measured with
`dev/bench/v0_2_2_indicator_history/scripts/scale.R` on synthetic gappy bars
(30 percent late listings; missing runs of one to eight sessions starting at
0.5 percent of sessions) against the pre-cut tree `a915ba66`. `parity` uses
`price_carry = NULL` and the four definitions the pre-cut tree admits
(SMA 20 and 50, returns 1 and 20); `realistic` adds lifetime intervals (one
in six learned ten sessions late), the default policy and fourteen
definitions (adds built-in EMA and RSI, TTR EMA and RSI, MACD with three
outputs, BBands `dn`/`up` and ATR `atr`).

| Tree | Config | Instruments x sessions | Definitions | Seconds | Microseconds per cell-definition | R heap peak MB |
|---|---|---|---:|---:|---:|---:|
| a915ba66 | parity | 1,166 x 7,213 | 4 | 103.53 | 3.08 | 1,085 |
| ws43 | parity | 1,166 x 7,213 | 4 | 67.58 | 2.01 | 1,448 |
| ws43 | realistic | 1,166 x 7,213 | 14 | 157.85 | 1.34 | 2,813 |
| a915ba66 | parity | 583 x 7,213 | 4 | 51.87 | 3.08 | 666 |
| ws43 | parity | 583 x 7,213 | 4 | 35.11 | 2.09 | 859 |
| ws43 | realistic | 583 x 7,213 | 14 | 81.96 | 1.39 | 1,484 |
| a915ba66 | parity | 292 x 7,213 | 4 | 26.08 | 3.10 | 458 |
| ws43 | parity | 292 x 7,213 | 4 | 17.13 | 2.03 | 526 |
| ws43 | realistic | 292 x 7,213 | 14 | 39.14 | 1.33 | 879 |
| a915ba66 | parity | 1,166 x 3,606 | 4 | 53.91 | 3.21 | 655 |
| ws43 | parity | 1,166 x 3,606 | 4 | 34.67 | 2.06 | 820 |
| ws43 | realistic | 1,166 x 3,606 | 14 | 80.71 | 1.37 | 1,475 |
| a915ba66 | parity | 1,166 x 1,803 | 4 | 27.74 | 3.30 | 441 |
| ws43 | parity | 1,166 x 1,803 | 4 | 17.75 | 2.11 | 519 |
| ws43 | realistic | 1,166 x 1,803 | 14 | 41.00 | 1.39 | 875 |
| a915ba66 | TTR SMA(20) | 50 x 7,213 | 1 | 56.28 | 156.05 | 241 |
| ws43 | TTR SMA(20) | 50 x 7,213 | 1 | 0.64 | 1.78 | 285 |
| a915ba66 | TTR SMA(20) | 100 x 7,213 | 1 | 110.52 | 153.22 | 269 |
| ws43 | TTR SMA(20) | 100 x 7,213 | 1 | 1.08 | 1.50 | 388 |

Cost per instrument-session-definition is flat across a fourfold change in
instruments and sessions on both trees, so preparation is linear in
instruments x sessions x definitions with no per-prefix work. At the full
shape the parity preparation is 35 percent faster than the pre-cut tree and
the values of all four definitions are identical at every shape. Catalogue
TTR rows are about 90 times faster because TTR runs once per segment instead
of once per window.

The R heap peak (`gc()` maximum, which includes garbage not yet collected)
is 363 MB higher than the pre-cut tree at the full parity shape. Releasing
each result matrix as the sweep payload is split did not lower it: the
final tree measures 67.28 seconds and 1,469 MB for parity and 157.70
seconds and 2,813 MB for the realistic set, with parity values again
identical to `a915ba66`. The difference is recorded, not explained or
gated here; LDG-3069 owns the process-level private-commit gates.

The runner path for `return_1` (`evidence/return1_run.csv`, one instrument):
the pre-cut tree called the scalar `fn` once per window (749 and 1,499 calls
for 750 and 1,500 sessions); this tree calls it zero times. Elapsed run time
is unchanged within noise (2.97 versus 3.16 and 4.96 versus 5.01 seconds,
measured while other test processes ran), because one instrument's scalar
calls are a small share of a public run.

## Seven-shape walk

1. Values are written by index into preallocated instrument-by-axis matrices;
   no table grows by row. The sweep payload splits each matrix once and
   releases it.
2. Each instrument's inputs and lifetime masks are prepared once per
   knowledge range and serve every definition; certification runs once per
   definition per preparation (LTB-0157), not per instrument or pulse.
3. Carry, admission and run detection are vector operations. The remaining
   per-element loops are stated: built-in SMA keeps one `mean()` per window
   for bit parity (pre-existing), a custom `fn` is called once per ready
   window because it is user code, and the interim custom-pair check calls
   `fn` per ready window until LDG-3067 samples it.
4. No row-wise JSON or hashing: one TTR cache key per segment.
5. Candidate-invariant work happens once: features are prepared once per
   sweep for the unique definitions, and multi-output TTR rows share one raw
   call per segment.
6. No pulse operation scans history; pulses read the prepared projection.
7. One representation: values live in the existing runtime projection; no
   feature store, cache or second reader was added. Evidence is recomputed
   on demand by the same calculation.

The new loops over instruments and segments are linear and are the stated
reasons above; scaling is measured in the previous section.

## Routed, not fixed here

- LDG-3067: sampled prefix invariance and window-versus-prefix refutation
  replace the interim every-window custom-pair check; the Feature Path
  contract still says the fn-only fallback uses "bounded stable windows"
  (it now hands `requires_bars` rows); full indicator teaching. This phase
  made only minimal factual edits to the indicators, custom-indicators,
  ttr-indicators and missing-data articles so no text describes removed
  behavior.
- WS42 / LDG-3063 / LDG-3068: public history results may consume
  `ledgr_history_feature_planes()`; experiment-derived pulse parity for
  these features and the "supplies no mark" half of the inactive-print
  acceptance are valuation-plane and integration evidence not touched here.
  Explicit `ledgr_precompute_features()` still prepares availability
  experiments through the dense helper (LDG-3063's file).
- Merge note: the new store-format binding and LTB-0259 list will meet
  LDG-3064's store-format change; the codebase census records one more
  version finding of the same kind as the Workstream 40 history bindings
  (the census tool's member list predates them).
- Dense execution still rebuilds `return_1` through the legacy id dispatch,
  whose `c / p - 1` differs in the last bit from the sweep's `(c - p) / p`.
  Dense is frozen, so this pre-existing difference is recorded only.
- During this work the agent ended every running `Rscript.exe` process on the
  host once (to stop its own mutation run); any concurrent session's R
  process would also have stopped.

## Verification record

- Pre-cut baseline: the full suite on `a915ba66` passes 1,114 blocks with no
  failures and one optional-package skip.
- `0602a93d` (LDG-3065 alone): full suite 1,117 blocks, no failures, the
  same skip.
- `73eec63e` (LDG-3066): full suite 1,121 blocks, no failures, the same
  skip (`pkgload::load_all()` then `testthat::test_local()` on a source copy,
  672 seconds on a shared host). The final edits after that run changed only
  claim text (`tests/claims.yml`), which the control-plane, claims,
  codebase-contract and governance suites rechecked: 16 blocks, no failures.
- Mutations: 14 of 14 (LDG-3065) and 22 of 22 (LDG-3066) fail their named
  blocks on source copies.
- `tools/check-codebase-contracts.R --mode=report` regenerated the census
  (`source_commit` labels `ws43-ldg-3065` and `ws43-ldg-3066`);
  `tools/check-fold-phase-contract.R .` reports
  `LEDGR_FOLD_PHASE_CONTRACT_OK`; `tests/claims.yml` and `tickets.yml` parse;
  `git diff --check` is clean.
- Not run here, by instruction: the timed fast, review and heavy profiles.
  The new blocks are review-profile; LTB-0142 to LTB-0144 stay fast and are
  in-memory, so their fast cost should be comparable, but the fast bound has
  not been measured on this tree.

Durable evidence is under `dev/bench/v0_2_2_indicator_history/`. Scratch
copies and fixture stores are not evidence and were left outside the
repository.
