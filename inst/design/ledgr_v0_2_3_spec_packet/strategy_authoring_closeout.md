# Workstream 18 Closeout: Final Strategy Authoring Surface

Status: close-review corrections implemented; awaiting focused confirmation.

## Product boundary

LDG-3187 through LDG-3190 complete the accepted strategy-authoring design.
The strategy callback sees one flat, named, pulse-frozen context; strategies
compose ordinary R conditions, character selections and named numeric weights,
then return one complete target or a classed strategy result. Opening capital,
costs, schedule, declared features and declared strategy memory remain explicit
experiment inputs. No compatibility alias or second callback path was added.

The sizing helper now carries one private typed evidence object to the strategy
return boundary. The fold validates it against the accepted decision axis,
marks, positions and normalized targets, then writes typed `run_diagnostics`
columns at stage `sizing`. The durable fields are:

- `instrument_id` identifies the sized instrument;
- `target_before_risk` is requested quantity;
- `target` is the post-guard, pre-floor quantity;
- `quantity` is the rounded helper target;
- `price` is the accepted decision mark;
- `position_before` is the held quantity at sizing;
- `reason_code` carries the typed sizing category;
- `reasons` carries the optional strategy intent reason; the physical non-null
  column uses an empty sentinel when absent and the public result exposes typed
  missing; and
- `detail_json` is the constant `{}`.

The categories distinguish ordinary rounding, rounded-to-zero additions and
liquidations, explicit zero targets, explicit liquidations and unavailable
sizing. The optional strategy intent reason likewise uses `reasons` and `{}`;
the result reader no longer parses intent JSON. Raw quantity strategies write
one `sizing_intent_unavailable` notice per durable run, including across
resume. If ordinary R code modifies a helper target, its stale private sizing
evidence is discarded and the pulse uses that same unavailable-evidence path;
malformed evidence still refuses. Ephemeral sweep candidates retain no sizing
row and make no coverage claim. `ledgr_sizing_evidence_rule_version` binds the
interpretation in the current-only store fingerprint.

`print()` and `summary()` label pooled, minimum-decision and last-decision
coverage as exposure-weighted decision diagnostics. They label the decision
clock, currency and aggregation and show final actual invested exposure from
the native final equity row separately. Cross-decision quantity and value sums
are explicitly not portfolio exposure, P&L or a time series. Undefined
denominators remain typed missing values. Helper decisions with no sizing
instruction are counted separately from unavailable sizing. Evidenced and
unavailable decisions may overlap when different instruments on one decision
have each outcome.

## Maintained strategies and teaching

The dense peer recipe uses flat feature columns and declared asset state. The
long-window run and sweep/walk-forward recipes use the external monthly
schedule, flat return feature, plain selection and weights, and ctx-first
target sizing. Their economic purposes are unchanged.

The external monthly schedule is an intentional measurement and policy
difference from the retired in-callback month gate: it avoids building the
callback context on non-decision pulses (about 21x fewer callback/context
builds on the registered daily fixture), and it waits for the first provable
month boundary rather than deciding in a partial first month.

`dev/bench/v0_2_3_ws5/semantic_ports.R` runs the original four-year,
30-stock/eight-ETF fixture. The current trailing-stop port preserves 58 fills;
the current Turtle quantity port preserves 741 fills and the pinned fill digest
`063721a2f68cd5977b703f5b5b44373d08786aa6cdbb0f52597f85241800bb6e`.
Each writes exactly
1,045 strategy-state cursor/checkpoint rows. The registered review-profile
LTB-0543 pins those totals and refuses retired grammar.

`vignette("strategy-authoring-tools")` executes and teaches six reusable
patterns: fixed mix, filter, rank-and-rotate, fixed slots, preserved holdings
with explicit index-leaver policy, and position facts with declared memory and
reset. It also executes the D8 summary disclosure. The article teaches selected
versus retained counts, clamps `open_slots`, explains FIFO percentage stops and
the shared bar axis, and does not use every advanced feature in every example.
The public-name contract explicitly allows the predicate
`ledgr_passed_warmup()` and adapter `ledgr_align_weights()`; the rest of the
strategy grammar remains verb-first.

`ledgr_target_quantity()` deliberately retains its existing classed-selection
entrance. Broader context-selection pruning remains owned by WS11b; WS18 adds
no adapter or alternative selection type.

## Failure-sensitive evidence

- LTB-0539/LCL-0529 pins every typed helper field and sizing category.
- LTB-0540/LTB-0545/LCL-0530 pin durable typed rows, intent-column migration,
  the binding guard, summary labels, raw-target unavailability, sweep
  exclusion, promotion and resume.
- LTB-0541/LCL-0531 pins the store rule and absence of sizing/intent JSON work
  in the pulse path.
- LTB-0542/LCL-0532 separates helper sizing from downstream risk and
  affordability outcomes.
- LTB-0543/LCL-0533 owns the two frozen strategy ports.
- LTB-0544/LCL-0534 owns the six-pattern source and rendered teaching surface.
- The isolated D8 mutation replaces all sizing reasons with ordinary rounding;
  it applies once and fails LTB-0540. A second isolated mutation swaps the
  requested and post-guard fields; LTB-0545's scale-below-one witness fails it.
- `dev/bench/v0_2_3_ws5/check.R` reconciles the surface, ownership, maintained
  state, timing protocol and current consumer inventories.

The frozen availability witness keeps its historical economic rows intact. It
explicitly removes the accepted D8 notice before comparing the older
diagnostic surface and independently asserts that diagnostic sequence remains
contiguous. It similarly validates current typed empty strategy-state payloads
before ignoring their accepted representation change. No frozen economic value
or fill oracle was edited.

The final integration pass repaired stale tests rather than weakening their
oracles. History tests now use the accepted flat context, named vectors and
current restriction reasons; corporate-action fixtures declare state;
indicator fixtures supply the required opening policy; peer and demo recipes
use the supported flat feature and state surfaces. One product defect found by
those migrations was fixed: the internal history adapter now reads its private
`.history` field without dispatching through the public S3 reader. The timing
harness now excludes its warm-up row with an exact numbered-run predicate,
rather than accidentally timing it as a ninth run.

The indicator-history config-hash re-pin is attributed to the earlier Cut 7
opening and declared-state identity change; the sizing store rule is not part
of `config_hash()`. The history-selection oracle's
`lifetime_inactive -> target_restricted` change is the accepted flat
`buyable`-plane collapse. WS6 owns restoring restriction specificity for
inspection without rebuilding availability facts.

## Optimization and representation review

Sizing evidence is built in preallocated atomic vectors while the helper sizes
the target. The strategy return adds one typed segment to the existing bounded
pulse staging. It creates no per-instrument data frame, growing accumulator,
JSON encode or JSON parse. The result summary performs grouped vector
reductions outside the fold. The raw-target notice state is one boolean, seeded
by one preparation-time store query so resume cannot duplicate it.

The memory sink's existing retained-row predicate drops stage `sizing`, so a
sweep candidate does not acquire a new per-pulse retained payload. The durable
store is the evidence owner. These choices preserve the accepted prepare-once,
reuse-in-pulses and typed-boundary rules.

## Handoff

WS6 receives exactly the flat context named in the Pulse Data and Availability
Context contracts: scalar pulse metadata and named atomic run-axis columns for
bars, eligibility, holdings, position facts, declared features and declared
state. It must not rebuild a nested frame or restore a scalar reader.

WS7's merged result reader consumes the D8 diagnostic fields and native final
equity facts named above. Macro join J therefore remains open after Cut 7:
closing WS5 implementation does not claim that the future merged reader has
landed. WS8 continues to own schema 125 and typed persistence. The old strategy
JSON cache has no remaining WS5 owner.

The strategy-authoring RFC pipeline row and decisions bridge stay until the
independent close review is accepted. Acceptance housekeeping may then remove
the implementation obligation while retaining the named future handoffs.

## Integrated gates and timing

The exact candidate passes all semantic gates:

- review profile: 523/523 blocks in 819.29 seconds, with the one registered
  optional-package skip;
- heavy profile: 183/183 blocks in 279 seconds;
- fast profile: 638/638 blocks in 214.22 seconds. The functional lane passes,
  while the historical 112-second backstop is an explicit timing miss already
  accepted for this cut; no block was retiered or weakened;
- source build passes; and
- `R CMD check --no-manual --no-build-vignettes` reports zero errors and zero
  notes. Its two warnings are the expected missing `inst/doc` products under
  the requested no-build-vignettes mode. Tests, examples and executable
  vignette code pass from the built tarball; and
- the codebase contract census passes with 70 connection, 176 version, 90 run
  configuration, 2,006 helper and 2,487 condition entries; its execution-mode
  census records 72 branch and 31 flow sites in 45 functions.

The registered fresh-process timing records live under
`dev/bench/timing/records/ws5-timing-1/`. Against the v0.2.2 release base all
nine ratios pass the 1.10 disposition threshold (0.926 to 1.024). Against the
post-WS4a attribution base, declared-session runs improve (0.747 to 0.929) and
construction is neutral (1.000), while fixed-basket ratios remain red: 2.762
no-fill, 2.758 sparse, 1.600 wide, 2.068 state-change and 2.039
state-unchanged. All 288 slots across the two comparisons are finite and retain
identical economic controls. The latter checker failure is recorded, not
described as a pass: macro WS14 continues to own the bounded response to this
known common-path premium, and Workstream 18 does not restore a second fold.

The close-review correction candidate reruns the focused sizing, result,
history, store-gate, availability, documentation and control-plane suites;
all pass. Both isolated D8 mutations apply once and are detected. The rendered
article executes all 61 chunks. The source package builds, and `R CMD check
--no-manual --no-build-vignettes` passes tests, examples and executable
vignette code with zero errors and the same two expected missing-`inst/doc`
warnings.

The first focused re-review found one remaining stale-evidence boundary: an
ordinary edit to an instrument without an evidence row. The second bounded
correction compares every unevidenced target with its held quantity in one
vectorized check; preserved-holding liquidation and extra-ID rebalance edits
both fall back to the raw notice, while malformed evidence still refuses. The
fixed-mix teaching now names `capital_base = "total_equity"`, so its statement
about preserving a held unbuyable constituent is executable rather than
implicit.
