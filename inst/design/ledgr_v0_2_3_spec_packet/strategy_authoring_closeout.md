# Workstream 18 Closeout: Final Strategy Authoring Surface

Status: implementation complete; awaiting independent Type 1 close review.

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
- `reason_code` and `reasons` carry the typed sizing category; and
- `detail_json` is the constant `{}`.

The categories distinguish ordinary rounding, rounded-to-zero additions and
liquidations, explicit zero targets, explicit liquidations and unavailable
sizing. The optional strategy intent reason likewise uses `reasons` and `{}`;
the result reader no longer parses intent JSON. Raw quantity strategies write
one `sizing_intent_unavailable` notice per durable run, including across
resume. Ephemeral sweep candidates retain no sizing row and make no coverage
claim. `ledgr_sizing_evidence_rule_version` binds the interpretation in the
current-only store fingerprint.

`print()` and `summary()` label pooled, minimum-decision and last-decision
coverage as exposure-weighted decision diagnostics. They label the decision
clock, currency and aggregation and show final actual invested exposure from
the native final equity row separately. Cross-decision quantity and value sums
are explicitly not portfolio exposure, P&L or a time series. Undefined
denominators remain typed missing values.

## Maintained strategies and teaching

The dense peer recipe uses flat feature columns and declared asset state. The
long-window run and sweep/walk-forward recipes use the external monthly
schedule, flat return feature, plain selection and weights, and ctx-first
target sizing. Their clocks and economic purposes are unchanged.

`dev/bench/v0_2_3_ws5/semantic_ports.R` runs the original four-year,
30-stock/eight-ETF fixture. The current trailing-stop port preserves 58 fills;
the current Turtle quantity port preserves 741 fills. Each writes exactly
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
- LTB-0540/LCL-0530 pins durable typed rows, intent-column migration, summary
  labels, raw-target unavailability, sweep exclusion, promotion and resume.
- LTB-0541/LCL-0531 pins the store rule and absence of sizing/intent JSON work
  in the pulse path.
- LTB-0542/LCL-0532 separates helper sizing from downstream risk and
  affordability outcomes.
- LTB-0543/LCL-0533 owns the two frozen strategy ports.
- LTB-0544/LCL-0534 owns the six-pattern source and rendered teaching surface.
- The isolated D8 mutation replaces all sizing reasons with ordinary rounding;
  it applies once and fails LTB-0540.
- `dev/bench/v0_2_3_ws5/check.R` reconciles the surface, ownership, maintained
  state, timing protocol and current consumer inventories.

The frozen availability witness keeps its historical economic rows intact. It
explicitly removes the accepted D8 notice before comparing the older
diagnostic surface and independently asserts that diagnostic sequence remains
contiguous. It similarly validates current typed empty strategy-state payloads
before ignoring their accepted representation change. No frozen economic value
or fill oracle was edited.

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
