# Cut 16 Workstream 43 closeout: indicator history semantics

Implementation commits: `0602a93d` (LDG-3065), `73eec63e` (LDG-3066),
`6bed3dff` (decisions 13-15), merge `806897fc`, renumbering `22324f3f`,
LDG-3067 `603966ec`, merge `9b5b17c4`, follow-up `6680bdb7` (decision 18,
frame carry planes), `bfffb0f7` (Correction 1, close review 43) and the
Correction 2 commit (re-review 1).

Role: record; Workstream 43 implementation evidence.
Authority: non-binding. `tickets.yml` owns status and `contracts.md` owns
behavior.
Status: under review. LDG-3065, LDG-3066 and LDG-3067 are complete; the
LDG-3067 run-path question was decided as Cut 16 decision (18). The close
review (`close_review_43.md`) returned CHANGES_REQUIRED; Correction 1 below
answers each finding and implements decisions (19) and (20); focused
re-review 1 (`close_review_43_rereview_1.md`) returned CHANGES_REQUIRED and
Correction 2 answers it and implements decision (21). Workstream 43 is
`review_pending` for the next focused re-review.

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
carried-input count and share of bounded windows. (As first written,
preparation stored values only; since `6680bdb7` and Correction 1 it also
retains the sparse evidence planes described under LDG-3067.)

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
  refuse but never change a value. The follow-up changes the literal once
  more (`50b8f783...`) because `compute` now also retains the evidence
  exceptions; values are unchanged.
- LTB-0315 (this workstream's block) gained the decision (18) assertions:
  zero store rows after the refused sweep and precompute, then one `FAILED`
  run row with no ledger or equity row.

Run-path boundary, Cut 16 decision (18) (maintainer, 2026-10-18): a
durable `ledgr_run()` registers its run and provenance rows before it
verifies the snapshot and prepares features, so a refused definition leaves
that run recorded `FAILED` with no strategy call, ledger event or equity row,
like other data-dependent run refusals; sweep and precompute refusals write
nothing. The ticket's first acceptance item was reworded to match, the
Feature Path contract cites the decision, and LTB-0315 now pins it: no store
row after the refused sweep and precompute, then exactly one `runs` row,
status `FAILED`, with no ledger or equity row. A mutation that leaves the
refused run unmarked fails LTB-0315.

### Feature evidence on history frames

On the maintainer's instruction (2026-10-18) this workstream also fixed
`ledgr_history_feature_evidence()`, WS42's frame reader, which had reported
placeholder planes (input and output carry always false, `calculated` meaning
any finite value, so output-carried values counted as calculated). Feature
preparation already computes every plane; it now retains the exceptions
sparsely. For each definition `ledgr_history_compute_feature_series()`
records, per instrument slot, the columns whose own required input was
policy-carried (never for an `input_carry = "excluded"` family) and the
columns whose value was output-carried, with that value's source time and
age (`ledgr_feature_plane_exceptions()`, `ledgr_feature_plane_records()`).
The sweep payload carries the record per definition; the runtime projection
indexes it once into sorted linear cell indices
(`ledgr_projection_index_planes()`), and a pulse-column slice re-indexes it.
A frame read locates its cells by binary search (`findInterval`) and
derives: `calculated` = finite and not output-carried, `calculation_valid` =
`calculated`, `ready` = calculated or output-carried, `source_ts_utc` and
`carry_age_sessions` from the record for carried cells, and reason
`output_carried`. Nothing is recomputed per read. A projection without
retained planes refuses the read (`ledgr_invalid_history_substrate`) rather
than reporting placeholders. The eager-versus-lazy representation question
stays with LDG-3069.

LTB-0318 (LCL-0310) pins literal planes for an SMA over BBB's carried
two-session gap and a return carried as output for two sessions
(`output_carry = 2`), identical across run, sweep and explicit-precompute
routes. No WS42 registered oracle changed: its blocks read bar evidence or
feature values only.

Retention cost (`evidence/planes_scale.csv`, `scripts/planes_scale.R`,
realistic panel, fourteen definitions, single runs on a shared host):

| Shape and policy | Preparation s | Input-carried cells | Output-carried cells | Planes MB | Values MB | Indexing s |
|---|---:|---:|---:|---:|---:|---:|
| 1,166 x 1,803 default | 40.36 | 247,877 | 0 | 0.96 | 227.67 | 0.17 |
| 1,166 x 1,803 output carry 5 | 48.25 | 247,877 | 278,556 | 5.21 | 227.67 | 0.18 |
| 1,166 x 7,213 default | 154.76 | 1,001,273 | 0 | 3.83 | 907.80 | 0.65 |
| 1,166 x 7,213 output carry 5 | 185.14 | 1,001,273 | 1,131,879 | 21.10 | 907.80 | 0.72 |

The retained planes are 0.4 percent of the value matrices under the
default policy and 2.3 percent with five sessions of output carry. The
default-policy preparation (154.76 s) is within noise of the LDG-3067
measurement at the same shape (152.58 s); the output-carry rows have no
earlier baseline and include output carry's own cost. One full-window
evidence read of all fourteen definitions over every instrument and session
takes 9.2 s (12.4 s with output carry), about 0.7 s per definition for 8.4
million cells; pulse reads are normally lookback-bounded. The Inspection contract, `?ledgr_history_frame` and the
WS42 closeout notes that described the placeholder now state the real planes.

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

## Correction 1 (close review 43, 2026-10-18)

The independent close review (`close_review_43.md`, `83032e5e`) returned
CHANGES_REQUIRED with seven findings over eighteen acceptance items. The
maintainer decided its open questions as Cut 16 decisions (19) and (20).
Each finding:

- **F1 (fixed).** The Availability-Aware Strict Features sentence now says
  features are calculated from the data start through each window's scoring
  end, pointing to Scoring And Feature Start.
- **F2 (fixed).** Frame feature evidence reports every v12 Sections 5-6 state
  separately and with the internal reader's column meanings: `calculated`
  is admission, `ready` is first-valid readiness, `calculation_valid` is a
  ready finite value, and `missing_reason` is `not_expected`,
  `outside_calculation`, `required_input_missing`, `carried_input_excluded`,
  `not_ready` (warm-up and re-warming), `output_carry_expired` or
  `output_carried`. Preparation retains, beside the carry exceptions, each
  admitted segment's start, end and first-ready column (warm-up is derived by
  index from them) and run-length reason codes for unavailable expected
  cells (missing, carried-input-excluded, output-carry-expired); calculation
  bounds give `outside_calculation`. The projection keys every set row-major
  and a read finds its cells by binary search; nothing is recomputed per
  read. `ledgr_history_feature_planes()` now gives valid cells their own
  source time and age 0 without an output-carry policy, limits input carry
  to the calculation range and applies the decision (20) window rule, so
  both readers agree cell for cell when no lifetime or terminal fact is
  learned after the column it changes (LTB-0319 compares them); for
  later-known facts the frame keeps each pulse's earlier answer and the
  internal reader recomputes at its cutoff, as LTB-0313 requires. A projection
  sliced to anything but its own prepared axis drops its planes, so a frame
  read refuses instead of misreading (production slices only onto the
  validated identical axis). The WS42 closeout route is corrected.
  Retained size (`evidence/planes_scale_correction1.csv`, realistic panel,
  14 definitions, single runs on a shared host): 24.1 MB beside 907.8 MB of
  values at 1,166 x 7,213 (2.7 percent; 384,771 segments, 475,440 reason
  runs) and 45.6 MB with five sessions of output carry (5.0 percent);
  indexing 0.73 s; a full-panel evidence read takes about 1.8 s per
  definition for 8.4 million cells (lookback-bounded pulse reads are much
  smaller); preparation 163.3 s versus 154.8 s before (single runs).
- **F3 (decided, fixed).** Cut 16 decision (19): a custom indicator whose id
  matches a built-in runs its own function in both modes. LTB-0321 pins it
  on four public runs (custom and built-in, dense and availability); NEWS,
  `?ledgr_indicator` and the Strict Features contract record the dense
  change.
- **F4 (fixed).** LTB-0320 pins the sticky terminal barrier on feature input
  carry with the reviewer's relisting shape: SMA(2) at sessions 8-9 is
  `NA, NA` (17, 18 when the barrier is ignored).
- **Decision (20) (implemented).** A terminal interval ends bounded windows
  as well as carry. `ledgr_history_feature_calculate()` starts a new run
  where WS41's sticky terminal barrier plane changes along the calculation
  rows, so after a relisting a definition restarts and needs its rows from
  the relisting; no second barrier rule was added and dense is untouched.
  LTB-0320 asserts SMA(2) at the relisting session is `NA`, not
  mean(12, 17) = 14.5. Contract, NEWS, `indicators` teaching and
  `?ledgr_indicator` are updated.
- **F5 (routed).** The (lagged facts + 1) x prefix factor is stated in the
  seven-shape walk and appended to LDG-3070's scope with the reviewer's
  wording; not changed here.
- **F6 (fixed).** LTB-0316 adds a two-instrument panel: four recomputations
  and the refusal names the instrument with the most calculated cells
  (probe-first and probe-every mutations fail it). LTB-0319 adds a high-only
  gap: a close-only SMA reports no input carry, a high-only definition does
  (an all-price-fields mutation fails it). The slice re-index is now the
  identity-or-drop rule above, which LTB-0318's explicit-precompute route
  covers; there is no re-indexing code left to protect.
- **F7 (fixed).** NEWS and the Strict Features contract state the aroon
  dense fingerprint change and its extra dense warm-up row; the return-family
  sentence says calculated output and discloses optional output carry; the
  stale closeout lines (values-only preparation, recomputed evidence) are
  corrected; LDG-3067 evidence names `603966ec`, `6680bdb7` and this
  correction.

Correction 1 registered blocks: LTB-0319 (LCL-0311), LTB-0320 (LCL-0312),
LTB-0321 (LCL-0313), and LTB-0316 extended (LCL-0308). Mutations: 14 of 14
detected (`evidence/mutations_correction1.csv`, `scripts/mut3067c.R`):

| Mutation | Detector |
|---|---|
| `ready` aliased to `calculated` | LTB-0319 (LTB-0318, LTB-0320) |
| `calculation_valid` aliased to `calculated` | LTB-0319 (LTB-0318) |
| `not_ready` reason dropped | LTB-0319 (LTB-0318, LTB-0320) |
| `required_input_missing` back to `not_calculated` | LTB-0319 (LTB-0320) |
| carried-input-excluded code not retained | LTB-0319 |
| expired-output code not retained | LTB-0319 |
| `outside_calculation` dropped | LTB-0319 |
| segment spans not retained | LTB-0319 (LTB-0318, LTB-0320) |
| input carry from every price field | LTB-0319 |
| probe the first instrument | LTB-0316 |
| probe every instrument | LTB-0316 |
| terminal barrier ignored in feature input carry | LTB-0320 |
| windows cross the terminal interval | LTB-0320 |
| built-in shadows the custom function | LTB-0321 |

Registered oracles changed in Correction 1, with reasons:

- LTB-0318 (this workstream's block): `calculated`, `ready` and
  `calculation_valid` take the v12 meanings (F2), so BBB's SMA reads
  admitted at session 1 but not ready, the return reads admitted and not
  ready at sessions 1 and 5 (warm-up, re-warming) with reason `not_ready`
  instead of the placeholder `not_calculated`, and AAA's check moves to
  `calculation_valid`. The carry planes it was written for are unchanged.
- LTB-0144 and LTB-0276: the availability engine digest becomes
  `283ce161...` because the hashed `compute`, `calculate` and `runs` helpers
  changed (decision (20) split and the retained planes). Dense literals are
  unchanged.
- No WS42 registered oracle changed; the WS42 history frame and integration
  blocks pass unchanged.

## Correction 2 (focused re-review 1, 2026-10-18)

Focused re-review 1 (`close_review_43_rereview_1.md`, `c59a9b0f`) returned
CHANGES_REQUIRED with four findings over nine items. The maintainer recorded
decision (21) from its note. Each item:

- **R1 (fixed).** Decision (20) now restarts at every relisting.
  `ledgr_history_substrate_terminal_planes()` returns the per-column terminal
  assertion that `ledgr_history_substrate_terminal_at()` already computed,
  beside the sticky barrier (which `terminal_at()` still returns unchanged);
  feature inputs carry both. `ledgr_history_feature_terminal_breaks()` starts
  a new run at each row that follows a column inside any terminal interval,
  in preparation and in the internal reader's carried-input windows. The
  carry barrier stays sticky (2026-10-17): carry never crosses any terminal
  interval; only window restarts are per relisting. LTB-0320 adds the
  reviewer's two-cycle case B5 (SMA(3) at session 14 is not ready, never
  mean(20, 21, 24)) and the internal reader's window counts. Contract, NEWS,
  `?ledgr_indicator` and the `indicators` article now say "every relisting".
- **R2 (fixed, behavior change).** `used_before_window` for features now
  reports every returned value that used earlier history, derived from the
  frame's evidence by index: an output-carried value whose source time
  precedes the window; a bounded value whose window of `requires_bars`
  expected sessions does not fit inside the window's expected sessions (a
  short lookback, or a window spanning a lifetime-inactive interval) or
  reaches the window's leading run of input-carried sessions, whose source is
  before the window; and, as before, any history-dependent value when the
  window does not start at the data start. The bounded width is now
  `requires_bars` from the definition's declarations (it was `stable_after`
  for `strict_window` only). LTB-0322 pins the reviewer's output-carry and
  input-carry probes (FALSE at session 2, TRUE at session 3) and an SMA(2)
  window across an inactive interval; reverting to the width rule, ignoring
  output carry or the leading carried run each fail it. The Inspection
  contract states the rule.
- **R3 (fixed).** The unused `sma_n` config branch is deleted. A stored
  fingerprint that differs from the built-in's and has no registered
  indicator now refuses with `ledgr_run_hash_mismatch` instead of running the
  built-in. The package's load-time registrations (`return_1`, `sma_50`,
  `sma_200`, `ema_12`, `ema_26`, `rsi_14`) are kept and recorded as package
  defaults: config construction registers an experiment's indicator with
  `ledgr_indicator_register_config()`, which replaces an entry when either
  the existing entry or the new definition has the package default's logic,
  so a custom `return_1` or `sma_50` runs its own function in a default
  session and the built-in replaces it back; two different user definitions
  under one id still refuse. The public `ledgr_indicator_register()` is
  unchanged. LTB-0321 now runs custom and built-in `sma_50` and `return_1`
  through dense and availability runs in a default session without clearing
  the registry (it restores the package defaults on exit), checks the
  user-user refusal and the unregistered-fingerprint refusal.
- **R4 (fixed).** LTB-0316's panel puts the most-calculated instrument
  between two others, so probing the first, the last or every instrument
  fails it. LTB-0320 asserts the internal reader's decision (20) window
  counts (RR12 fails it). The F2 claim is scoped: both readers agree cell for
  cell when no lifetime or terminal fact is learned after the column it
  changes; for later-known facts the frame keeps each pulse's answer
  (LTB-0313) while the internal reader recomputes at its cutoff. LCL-0311
  and the Correction 1 text are corrected.
- **Decision (21) (implemented).** A ready cell whose calculation is not
  finite reports `missing_reason = "calculation_non_finite"` in both readers,
  derived from the value (no stored plane), so every cell that is not
  `calculation_valid` has a reason. LTB-0319 pins it with an fn-only
  definition that returns `NA` on later sessions, in both readers. Contract,
  NEWS and `?ledgr_history_frame` list the reason.

New block LTB-0322 (LCL-0314); LTB-0316, LTB-0319, LTB-0320 and LTB-0321
extended (LCL-0308, LCL-0311, LCL-0312, LCL-0313 updated). Mutations: 12 of
12 detected (`evidence/mutations_correction2.csv`, `scripts/mut3067d.R`):

| Mutation | Detector |
|---|---|
| Runs break only where the sticky plane changes | LTB-0320 |
| No terminal breaks | LTB-0320 |
| Internal reader's windows span terminal intervals (RR12) | LTB-0320 |
| `used_before_window` ignores output-carried sources (RR11) | LTB-0322 |
| `used_before_window` ignores the leading carried-input run | LTB-0322 |
| Window reach counted in columns, not expected sessions | LTB-0322 |
| Unregistered fingerprint falls back to the built-in | LTB-0321 |
| Package defaults block an experiment's own definition | LTB-0321 |
| Built-in shadows the custom function | LTB-0321 |
| Probe the last instrument (RR8) | LTB-0316 |
| Frame drops `calculation_non_finite` | LTB-0319 |
| Internal reader drops `calculation_non_finite` | LTB-0319 |

Registered oracles changed in Correction 2, with reasons:

- LTB-0144 and LTB-0276: the availability engine digest becomes
  `4b2bb8e6...`, because the hashed `calculate` and `inputs` helpers changed
  and the new `ledgr_history_feature_terminal_breaks()` joins the digest
  (LTB-0144's helper list names it). Dense literals are unchanged.
- LTB-0316, LTB-0319, LTB-0320 and LTB-0321 (this workstream's blocks) are
  extended as above; LTB-0321 no longer clears the registry, and its
  `sma_3` case moved to `sma_50` so it exercises a package default. No
  earlier assertion of these blocks was weakened.
- No WS42 registered oracle changed.

Cost: preparation reads the per-column assertion from the same fact plane
the sticky barrier was already derived from (no second resolution), and
`used_before_window` adds one cumulative sum over the read window. No new
loop grows with bars, pulses or cells.

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
| LCL-0310 | LTB-0318 | frame feature evidence reads the retained input- and output-carry planes; output-carried cells are not calculated (LDG-3067 follow-up) |

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

Follow-up mutations after decision (18) and the feature-evidence fix, 8 of 8
detected (`evidence/mutations_ldg3067b.csv`, `scripts/mut3067b.R`):

| Mutation | Detector |
|---|---|
| Causality call removed (rerun on the amended block) | LTB-0315, LTB-0316, LTB-0317 |
| Refused run left `RUNNING` instead of `FAILED` | LTB-0315 |
| Frame input carry constant FALSE | LTB-0318 |
| Frame output carry constant FALSE | LTB-0318 |
| Output-carried cells counted as calculated | LTB-0318 |
| Preparation drops input-carry exceptions | LTB-0318 |
| Preparation drops output-carry exceptions | LTB-0318 |
| Projection slice drops the planes (explicit-precompute route) | LTB-0318 |

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
   definition per preparation (LTB-0157), not per instrument or pulse. A
   lagged lifetime or terminal fact starts a new knowledge range that
   re-treats the instrument's inputs and recomputes every definition from
   the calculation start, so an instrument's cost is (lagged facts + 1) x
   its prefix length (close review F5; routed to LDG-3070).
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
   feature store, cache or second reader was added. History-frame evidence
   reads sparse planes retained by the same preparation (segment spans,
   reason runs, carry exceptions) by binary search; the internal
   per-instrument reader `ledgr_history_feature_planes()` recomputes one
   instrument on demand for inspection and tests.

The new loops over instruments and segments are linear and are the stated
reasons above; scaling is measured in the previous section.

## Routed, not fixed here

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
- Correction 2: full suite 1,140 blocks, no failures, the same skip (710
  seconds on a source copy); census report and check
  (`ws43-correction-2`), fold-phase checker, YAML parse and
  `git diff --check` pass; 12 of 12 Correction 2 mutations detected;
  `integrate/cut15-v0.2.2` had not moved past `42df9de9`.
- Correction 1: full suite 1,139 blocks, no failures, the same skip (711
  seconds on a source copy); census report and check
  (`ws43-correction-1`), fold-phase checker, YAML parse and
  `git diff --check` pass; 14 of 14 Correction 1 mutations detected;
  `integrate/cut15-v0.2.2` had not moved past `42df9de9`.
- LDG-3067 follow-up (decision 18, feature evidence, merge `9b5b17c4`):
  full suite 1,136 blocks, no failures, the same skip (702 seconds); census
  report and check (`ws43-ldg-3067-followup`), fold-phase checker, YAML
  parse and `git diff --check` pass; 8 of 8 follow-up mutations detected.
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
