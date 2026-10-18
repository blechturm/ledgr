# Cut 16 Workstream 43 closeout: indicator history semantics

Implementation commits: `0602a93d` (LDG-3065), `73eec63e` (LDG-3066),
`6bed3dff` (decisions 13-15), merge `806897fc`, renumbering `22324f3f` and
the LDG-3067 commit that records this section.

Role: record; Workstream 43 implementation evidence.
Authority: non-binding. `tickets.yml` owns status and `contracts.md` owns
behavior.
Status: under review. LDG-3065 and LDG-3066 are complete. LDG-3067 is
implemented, evidenced and green on the full suite and is `review_pending`
on one open question (NEEDS_TYPE_2, below): a durable `ledgr_run()` refuses
a look-ahead definition only after it has registered the run. Workstream 43
is `review_pending` for its independent Type 1 close review.

## Necessity and scope

Historical-projection synthesis v12 Sections 5 and 6 require every indicator
to be bounded or history-dependent, to declare the fields it needs and to be
calculated over the shared treated substrate from Workstream 41. Before this
work the availability path accepted only a narrow strict-window set, refused
EMA, RSI and every other TTR form, calculated windows of `stable_after` rows
on raw bars and ignored the history policy. LDG-3065 and LDG-3066 add the
declarations, their identity and the calculation; LDG-3067 adds the sampled
causality checks, deletes the test-only sweep helper and updates indicator
teaching. Dense behavior is unchanged.

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

## LDG-3067: sampled causality and production-precompute fixtures

`ledgr_history_compute_feature_series()` ends with
`ledgr_history_feature_causality()`, so every availability preparation (run,
sweep, explicit precompute and experiment-derived pulse inspection) checks
before it returns. For each concrete definition, built-ins and catalogue rows
included, the probe is the instrument with the most calculated cells (counted
during the main pass, no extra scan). Its calculated cells that have later
history in their knowledge range are the candidates; the sample is their
first, last and two interior thirds (`ceiling(n/3)`, `ceiling(2n/3)`), so at
most four positions. At each position the definition is recomputed from the
probe's treated inputs truncated at that session (same cutoff, so only the
definition's own dependence is tested) and must equal the prepared value
exactly; otherwise `ledgr_feature_lookahead_detected` names the definition,
instrument and session and carries both values. The reference is the
prepared value, not a second full computation, so a definition that carries
state between calls is caught as well as one that reads later rows.

For a custom bounded definition with both `fn` and `series_fn` the same
positions refute the pair: `fn` on its exact `requires_bars` window must
equal the prepared `series_fn` value, exactly unless a fingerprinted nonzero
tolerance is declared, or `ledgr_indicator_gap_parity` names the definition,
instrument and session. History-dependent pairs and built-in or catalogue
rows are not refuted. This replaces LDG-3066's interim every-window loop in
`ledgr_history_feature_segment()`. The checker's cost is one recomputation of
the probe for structure plus at most four truncated recomputations per
definition; catalogue TTR rows reuse the probe's segment cache, so a
truncated prefix whose last segment is unchanged costs no TTR call.

`ledgr_sweep_compute_feature_matrix()` is deleted from `R/sweep.R` and from
the census seam list. The three direct-fold fixtures in `test-sweep.R`
(prebuilt pulse views; mutation isolation across pulses; across candidate
folds) now take their runtime projection from `ledgr_precompute_features()`
on a sealed snapshot of the same bars, asserting that the payload's feature
union carries the fixtures' fingerprints; every prebuilt-view and isolation
assertion is unchanged, and the cross-candidate block additionally checks
the observed values against the fixture closes. The fixtures are dense folds
(prebuilt views are the dense fast context), so they use the dense branch of
the production precompute, which after the merge sits beside WS42's
availability branch in the same function. The dev peer benchmark now builds
its projection with the production `ledgr_precompute_payload()`. The
historical sweep-profiling spike under `dev/spikes/` still names the deleted
helper and is left as dated evidence.

Contracts: Feature Path And Intent Constructors and Indicator Teaching are
present tense and lose their pending links; Availability-Aware Strict
Features points to Feature Path for the refutation. Teaching: `indicators`
states first-valid versus convergence with the conformance spike's measured
one-gap recovery ranges (with their TTR arguments) and the sampled check;
`custom-indicators` describes both checks and their limits; `leakage` adds
the check to its enforcement table; `?ledgr_indicator`, the condition
reference and NEWS state the same rules.

Registered blocks changed, each for the stated reason that the sampled
causality check adds a fixed, history-independent number of calls:

- LTB-0276 (LCL-0274): TTR call counts become per segment plus the probe's
  calls (dense `2 + 5`, gapped `3 + 5`, MACD bundle `3 + 2 + 3`, each
  derived in the test comment); the per-window claim is unchanged.
- LTB-0143 (LCL-0143): segment calls become `7 * (1 + 1 + 4)`: one
  preparation segment, one probe segment and four sampled prefixes per
  definition.
- LTB-0153 (LCL-0153): preparation segment work stays pinned exactly
  (80 and 160 rows, two calls, ratio 2); the checker's work is counted
  apart and bounded: exactly ten segment calls (two definitions times probe
  plus four prefixes) and at most five passes of the history.
- LTB-0144 and LTB-0276: the availability feature-engine literal changes
  because the hashed `compute`, `calculate` and `segment` helpers changed;
  dense literals are unchanged. The checker helpers are not hashed: they
  refuse but never change a value.

NEEDS_TYPE_2 (open): the acceptance says a future-looking definition
"refuses before run, sweep or precompute side effects". Sweep and precompute
refuse with nothing written. A durable `ledgr_run()` registers its run and
provenance rows before it verifies the snapshot and prepares features, so the
refusal leaves the run recorded `FAILED` (one `runs` row, one
`run_provenance` row) with no strategy call, ledger event or equity row;
this matches every other data-dependent run refusal (missing bars, snapshot
checks). Removing that row means preparing the substrate and features before
registration, which reorders the run prelude; adding a pre-registration
availability check instead would be a new execution-mode branch in run code,
which AGENTS.md forbids. The maintainer chooses: (a) accept the recorded
`FAILED` run as the run-path boundary (the contract currently states this);
(b) reorder the run prelude; or (c) another rule. LTB-0315 asserts the
strategy, ledger and equity boundary and deliberately does not assert the
runs row either way.

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
| LCL-0307 | LTB-0315 | sampled prefix invariance for `series_fn` and fn-only definitions, exact fn windows, refusal before run, sweep and precompute side effects (LDG-3067) |
| LCL-0308 | LTB-0316 | fixed four-position sample, history-length independent, catalogue rows probed (LDG-3067) |
| LCL-0309 | LTB-0317 | custom bounded pair refutation, tolerance, no history-dependent or catalogue refutation (LDG-3067) |

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

All 14 LDG-3065, 22 LDG-3066 and 10 LDG-3067 mutations fail their named
registered blocks (`dev/bench/v0_2_2_indicator_history/evidence/`
`mutations_ldg3065.csv`, `mutations_ldg3066.csv` and `mutations_ldg3067.csv`
list every block that failed; `scripts/mutate.R` runs a specification).

| Mutation (LDG-3067) | Detector (other blocks that also failed) |
|---|---|
| Causality call removed from preparation | LTB-0315, LTB-0316, LTB-0317 |
| Check moved to the per-instrument evidence reader (after artifacts) | LTB-0315 (LTB-0316, LTB-0317) |
| Prefix comparison weakened to missingness only | LTB-0315 |
| Every candidate position recomputed (all prefixes) | LTB-0316 (LTB-0315) |
| Custom pair refutation removed | LTB-0317, LTB-0310, LTB-0312 |
| History-dependent pairs refuted | LTB-0317 (LTB-0315, LTB-0316) |
| Built-in and catalogue rows refuted at runtime | LTB-0317 (LTB-0316) |
| Declared tolerance ignored | LTB-0317 |
| fn-only window one row wider than `requires_bars` | LTB-0315 |
| fn handed the next (future) row | LTB-0315 (LTB-0316) |

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

### LDG-3067 checker growth

`scripts/checker_scale.R` times `ledgr_history_feature_causality()` inside
one preparation of the `realistic` panel and fourteen definitions
(`evidence/checker_scale.csv`; single runs on a shared host, so timings are
disclosure only).

| Instruments x sessions | Preparation seconds | Checker seconds | Checker share | Prefix recomputations |
|---|---:|---:|---:|---:|
| 1 x 252 | 0.70 | 0.08 | 11.4% | 56 |
| 1 x 1,008 | 0.72 | 0.11 | 15.3% | 56 |
| 1 x 4,032 | 0.91 | 0.24 | 26.4% | 56 |
| 1 x 16,128 | 1.65 | 0.75 | 45.5% | 56 |
| 1,166 x 252 | 9.39 | 0.04 | 0.4% | 56 |
| 1,166 x 1,803 | 39.94 | 0.11 | 0.3% | 56 |
| 1,166 x 7,213 | 152.58 | 0.34 | 0.2% | 56 |

The number of recomputations is fixed at four per definition (56 for
fourteen) on every shape, so the checker never grows with the number of
prefixes. Its time grows with history length only through the length of
each recomputed prefix: from 4,032 to 16,128 sessions on one instrument it
rises 3.1 times for four times the history (linear, with fixed overhead at
small sizes), and it does not grow with the instrument count because one
probe instrument is used per definition. On one instrument the checker is a
large share of a small preparation (its recomputations are about three
prefix-weighted passes of that instrument); at the realistic 1,166-instrument
shapes it is 0.2 to 0.4 percent. The 1,166 x 7,213 preparation (152.58
seconds) is within the phase-1 measurement (157.85 seconds) for the same
shape, and every one of the fourteen definitions, TTR multi-output rows
included, passed the exact check on every shape.

## Seven-shape walk

1. Values are written by index into preallocated instrument-by-axis matrices;
   no table grows by row. The sweep payload splits each matrix once and
   releases it.
2. Each instrument's inputs and lifetime masks are prepared once per
   knowledge range and serve every definition; certification runs once per
   definition per preparation (LTB-0157), not per instrument or pulse.
3. Carry, admission and run detection are vector operations. The remaining
   per-element loops are stated: built-in SMA keeps one `mean()` per window
   for bit parity (pre-existing), and a custom `fn` is called once per ready
   window because it is user code. LDG-3067 replaced the interim per-window
   custom-pair loop with at most four `fn` calls per definition; the
   checker's own loops run over definitions and at most four positions, and
   the probe count is accumulated during the main pass rather than by a
   second scan of the result matrices.
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

- LDG-3067 run-path boundary: NEEDS_TYPE_2 above (a refused durable run
  stays recorded `FAILED`).
- WS42's public frame feature evidence (`ledgr_history_frame()` on a
  feature source) still reports the placeholder planes it had before this
  workstream: it does not read `ledgr_history_feature_planes()`, so its
  input-carry and output-carry evidence for a feature is not the evidence
  this calculation produces (values are the prepared ones). Routed to
  WS46 / LDG-3069 as an integration decision (eager evidence at preparation
  versus lazy recomputation on read); not changed here because WS42 owns the
  reader.
- Dense execution is frozen: it runs neither causality check, and the
  test-only all-prefix `ledgr_check_no_lookahead()` (LTB-0003) remains a
  dense oracle seam only. Retiring it with the dense path is left to the
  execution-core consolidation.
- Merge note (resolved): explicit `ledgr_precompute_features()` now prepares
  availability experiments through the causal substrate (WS42), and the
  store-format binding met WS42's schema 122 as recorded above.
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
- Merged, renumbered tree (`22324f3f`): full suite 1,132 blocks, no
  failures, the same skip.
- LDG-3067: full suite 1,135 blocks, no failures, the same skip (source
  copy, 702 seconds on a shared host). The first run failed only LTB-0153,
  whose segment-work oracle did not separate the new check's work; the
  block now counts it apart (stated above) and the rerun is the green one.
  The census was regenerated (`source_commit` label `ws43-ldg-3067`), the
  fold-phase checker reports `LEDGR_FOLD_PHASE_CONTRACT_OK`, `claims.yml`
  and `tickets.yml` parse, and `git diff --check` is clean.
- Mutations (LDG-3067): 10 of 10 fail their named blocks on source copies.
- Not run here, by instruction: the timed fast, review and heavy profiles.
  The new blocks are review-profile; LTB-0142 to LTB-0144 stay fast and are
  in-memory, so their fast cost should be comparable, but the fast bound has
  not been measured on this tree.

Durable evidence is under `dev/bench/v0_2_2_indicator_history/`. Scratch
copies and fixture stores are not evidence and were left outside the
repository.
