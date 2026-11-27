# LDG-3279 audit: rules ledger LR-01 to LR-11, LR-21 to LR-23

Scratch record, 2026-11-27. Pin: 7f65733f (`C:/Users/maxth/ledgr-wt/pin-src-7f65733f/R/`,
installed at `C:/Users/maxth/ledgr-wt/pin-lib-7f65733f`). Edited:
`inst/design/contracts.md` and
`inst/design/ledgr_v0_2_3_spec_packet/lean_core_rules_ledger.md` in
`C:/Users/maxth/ledgr-wt/cut27-dev`.

Targeted probe: `dev/lean_core/parity/evidence/ldg3279/ldg3279_probe.R`
(committed beside this file), run once on the installed pin with
`Rscript ldg3279_probe.R`. Scenario 1 is the WS42 declared-session fixture
(`tests/testthat/helper-history-fixtures.R`, BBB without bars on sessions 3
and 4) with AAA bought on session 1 and a final-pulse request of 5. Scenario 2
is a 32-instrument bar-native fixed basket, 40 days, random integer targets,
spread 7 bps plus notional fee 3 bps, opening cash 16,434 (near a binade
boundary, so partial cash sums cross powers of two). Output, all PASS:

```
session 3 universe: AAA BBB CCC | buyable: TRUE TRUE TRUE | close: 13 NA 33
PASS LR-06 BBB buyable without a bar (sessions 3, 4)
PASS LR-08 ctx$close NA without a bar (sessions 3, 4)
session 4 close history BBB: 21 22 22 22
session 1 hm3 dim: 1 0 | hm3_min1 dim: 1 3
final-pulse row: AAA execution no_fill target 5 quantity 2 target_before_risk 5 target_after_risk 5 position_before 2 position_after 2 execution_ts_utc NA
decision rows AAA: quantity 0 on session 1, then 2; final decision target 5 quantity 2
fills 1225 | decision pulses 39 | recorded = event-order plain scan 39 | virtual = priority-order plain scan 39 | virtual != recorded 31 | virtual = event-order scan 8
LR-04: cumsum() booking misses the stored recorded cash on 28 pulses | cash_before = recorded - sum(deltas) 39 of 39 | cash_before = previous recorded cash 10
```

A first scenario-2 run at cash 1e7 found no pulse where the two orders
differ: within one binade a plain double sum is order independent (each
addition adds the delta rounded to the fixed ulp grid), so the last-digit
difference needs partial sums that cross a power of two. The probe was
re-parameterised for that; the claim "can differ" holds, but rarely on large
steady cash balances.

No entry needed a maintainer decision: every written text describes the
pin's behaviour. Four facts written as contract may surprise the maintainer;
they are listed at the end.

---

## LR-01

Ledger: A decision row's `quantity` is the current holding, not zero.

Code: `R/fold-engine.R:ledgr_fold_stage_decide`, `append_decision_trace`
(lines 927-966): `target = strategy_qty`, `quantity = position` (:957),
`target_before_risk = strategy_qty`, `target_after_risk = target_after or NA`,
`position_before = position_after = position`. `position` is the pulse-start
holding on the context axis. The empty-axis row (`empty_public_domain`) has
no instrument and no quantity.

Existing contract: none for decision-row columns. Nearest:
`contract-persistence-fold-evidence` "one logical decision trace row per
invoked axis ID"; `contract-strategy-outputs` defines the sizing-row columns
only.

Added (contract-persistence-fold-evidence, new bullet, shared with LR-23):
"An instrument's decision row records the strategy's target in `target` and
`target_before_risk`, the risk-transformed target in `target_after_risk`
(missing when the pulse stopped before the risk chain ran), and the
pulse-start holding, not zero, in `quantity`, `position_before` and
`position_after`, also when the strategy requested its current holding
(LR-01, LR-23)."

Witness: `tests/testthat/test-availability-economics.R` "prepared valuation
and linear event growth coexist in one eventful fold" (:1119, a held AAA
decision row with `quantity != 0`; fails if quantity were zero); the probe
(quantity 0 before the fill, 2 on every later pulse); every lean gate
workload compares `run_diagnostics` with the pin.

Wording: none; "instrument's" excludes the empty-axis and skip rows.

## LR-02

Ledger: A final-pulse request that differs from the holding writes an
`execution / no_fill / final_pulse_no_execution` row with the request in
`target` and the holding in `quantity`.

Code: `R/availability-economics.R:ledgr_fold_build_availability_pulse_plan`
(:392-399): with no execution epoch (`exec_ts` NA) every actionable row is
rejected with reason code 1 (`final_pulse_no_execution`), NA price.
`R/fold-engine.R:ledgr_fold_stage_plan` (:1213-1227): `stage = "execution"`,
`outcome = "no_fill"`, `target = target_qty[k]` (post-risk), `quantity =
rejection$position` (the holding), `target_before_risk = strategy_qty[k]`,
`target_after_risk = target_qty[k]`, `position_before = position_after =
holding`, `price = NA`, `execution_ts_utc = NA`. Actionable means
`abs(target_qty - position) > sqrt(.Machine$double.eps)` (:1072). A continued
carry window's final pulse has an execution opportunity and executes.

Existing contract: reason table row `final_pulse_no_execution | execution |
record no fill because no later execution pulse exists`
(contract-availability-affordability); carrier rejection row "epoch NA
exactly for `final_pulse_no_execution`"; walk-forward continuous carry "the
final decision is recorded as `final_pulse_no_execution`".

Added (contract-persistence-fold-evidence, new bullet): "Each actionable
decision (post-risk target differing from the holding by more than
`sqrt(.Machine$double.eps)`) on a pulse without an execution opportunity
(the final pulse, unless a continued carry window executes it) writes one
`execution` row with outcome `no_fill` and reason `final_pulse_no_execution`:
the post-risk target in `target` and `target_after_risk`, the strategy
target in `target_before_risk`, the holding in `quantity`, `position_before`
and `position_after`, and no price or execution time (LR-02)."

Witness: the probe (target 5, quantity 2, NA execution time). Existing tests
assert only the row's existence and memory/durable identity
(`test-one-execution-path.R` LTB-0525, `test-availability-economics.R` "the
terminal availability decision has no execution opportunity"); gate workload
`final_pulse_trades` compares the table with the pin but has no reach
predicate asserting a nonzero holding. Proof gap for registered tests,
closed only by this targeted probe.

Wording resolved: "the request" is the post-risk target (equal to the
strategy request unless risk changed it); "differs" is the sqrt(eps)
actionable rule; "final pulse" excludes a continued carry window.

## LR-03

Ledger: The reconciliation detail books recorded cash fill by fill in event
order, and expected (virtual) cash fill by fill with sells before buys, so
the two can differ in the last digit on busy pulses.

Code: virtual = `R/availability-economics.R:ledgr_plan_affordability`
(:332-354): priority = generators (`side == SELL & before > 0 & delta < 0 &
cash_delta >= 0 & !blocked`) then the rest, each ordered by
`enc2utf8(id)` radix; accepted rows added one at a time. Recorded =
`fold_state$cash` after P4's `ledgr_cash_scan()` over the fill rows in
decision order. Detail built in `R/fold-engine.R:ledgr_fold_stage_commit`
(:1570-1596) and encoded by `ledgr_fold_reconciliation_detail` via
`R/fold-carrier.R:942`. `cash_before = fold_state$cash - sum(fill$cash_delta)`
(:1571), a `sum()`, not a scan. Compared at `ledgr_availability_cash_tolerance`
with `all.equal()` (:1555).

Existing contract (contract-availability-affordability): "Active
affordability evaluates accepted cash-generating reductions first, then
cash-consuming fills in C-locale stable-ID order against the fixed `1e-8`
tolerance. Rejected sales fund nothing. Accepted fills remain emitted in
decision-axis order, and recorded cash must reconcile with the virtual
ledger without implying an intrapulse cash floor."

Added (same bullet): "The reconciliation row's detail records
`virtual_final_cash`, the affordability scan's cash booked fill by fill in
that priority order, and `recorded_final_cash`, the cash after the accepted
fills booked fill by fill in event (decision-axis) order; the two are
compared at that tolerance and may differ in the last bits. Its
`cash_before` is the recorded cash less the pulse's summed fill cash
effects (LR-03)."

Witness: the probe, scenario 2: on all 39 pulses the stored
`recorded_final_cash` equals the event-order plain scan and
`virtual_final_cash` the priority-order plain scan (compared as canonical
JSON number text); they differ on 31 pulses; an event-order virtual would
match on only 8. No registered pin test; r_floor stage 2
(`dev/spikes/r_floor/evidence/parity_layers.csv`) at 0d6c0b11 only.

Wording resolved: "sells before buys" is the existing precise order
(generators first, then the rest, each by C-locale ID); "last digit" holds
only when partial sums cross a power of two (see top).

## LR-04

Ledger: Ordered accumulations use plain double additions in event order;
`cumsum()` accumulates in long double and differs in the last digit.

Code: `R/lot-accounting.R:ledgr_cash_scan` (:263-271, scalar loop; comment
names cumsum()); `ledgr_lot_apply` totals loop (:527-541; cost-basis total
plain, realized P&L through `ledgr_lot_add_realized` Kahan step);
`R/availability-economics.R:ledgr_plan_affordability` loop (:343-352, in
priority order, not event order). Not a scan: the reconciliation
`cash_before` (`sum()`, `R/fold-engine.R:1571`), the P3 pre-check
`fold_state$cash + sum(fill$cash_delta)` (:1179), and the run-order
valuation reduction `sum(position * mark)` (:574).

Existing contract: contract-execution-fold-core P4 "cash by an ordered scan
of P3's cash effects (`ledgr_cash_scan()`)"; contract-execution-fold-carrier
"the total cost basis and the Kahan-compensated realized P&L follow one
scalar scan in event order. The kernel computes no cash: cash is a separate
ordered scan of already computed effects".

Added (contract-execution-fold-carrier, end of the lot bullet): "Each
ordered scan (the cash scan, the affordability scan and the kernel's
event-order cost-basis total) adds one already computed value at a time in
double precision, in its stated order; an extended-precision accumulation
such as R's `cumsum()` is not an equivalent booking and can differ in the
last bits. This does not replace the Kahan-compensated realized P&L step,
and the reconciliation row's `cash_before` is derived from the recorded cash
rather than scanned (LR-04)."

Witness: FIFO mutation `ordered_total_by_sum`
(`dev/lean_core/parity/evidence/fifo_mutations.csv`: 5 streams, 47
fill-heavy calls differ); the probe (a cumsum() booking misses the stored
recorded cash on 28 of 39 pulses; `cash_before` equals recorded - `sum()` on
39 of 39 and differs from the previous pulse's recorded cash on 29).

Wording resolved: scoped to the named scans; "in event order" is not true of
the affordability scan (priority order); Kahan arithmetic unchanged; the
derived `cash_before` and the `sum()` valuation reduction are named as not
scans (the latter only in this audit).

## LR-05

Ledger: The decision axis is the members in stable order, then held former
members, not one sorted list.

Code: `R/availability-provider-prepared.R:ledgr_availability_provider_from_plan`,
`decision_view` (:517-522): `axis <- unique(c(members, held_nonmembers))`,
held nonmembers by `ledgr_availability_stable_ids()`
(`R/availability-provider.R:9`, `enc2utf8` radix); members are `key[...]`
with `key` in the same stable order (:356); a character-vector universe
returns its declared IDs.

Existing contract (contract-availability-provider-and-timing): "Its decision
axis preserves declared member order for character-vector universes. For
membership-rule universes, members are ordered by C-locale stable ID;
nonzero held nonmembers then follow in the same stable-ID order."

Added: nothing.

Witness: `tests/testthat/test-availability-state.R` "provider orders
members before stable held nonmembers" (expects `Alpha, BRAVO, alpha2,
mike, zeta, HOLD_A, HOLD_Z`; one sorted list gives `Alpha, BRAVO, HOLD_A,
HOLD_Z, ...`).

Wording: "stable order" = C-locale stable ID for membership rules, declared
order for character vectors; already stated.

## LR-06

Ledger: `buyable` follows membership, not whether the instrument has a bar at
the pulse.

Code: `R/fold-carrier.R:ledgr_carrier_provider_view` (:571) `buyable = member
& !restricted`; restrictions come only from trading-status and lifetime facts
(`R/availability-provider.R:ledgr_availability_restrictions`, :238-266) and
the valuation freeze (`R/availability-economics.R:179`). No bar test.

Existing contract: contract-strategy-decision-axis "An ID is eligible when
it is a member and not target-restricted. `ctx$buyable` is that plane";
contract-context-prepared-views "`buyable` guarantees neither a current
sizing close nor execution at the next open"; frozen holding restricted.

Added (contract-context-prepared-views, same bullet): "The absence of a
current bar does not by itself change `buyable`: an unrestricted member
without a bar at the pulse stays buyable (LR-06)."

Witness: the probe (BBB, a member without a bar on sessions 3 and 4, has
`buyable` TRUE, `close` NA). No registered pin test; r_floor stage 3 seam at
0d6c0b11. The test-history-integration fixture has the same gaps but asserts
planes only at session 7.

Wording resolved: "follows membership" is the membership-and-restriction
rule; a long absence can restrict a held instrument through the freeze, so
"by itself".

## LR-07

Ledger: `ledgr_history_matrix()` admits an instrument only with a complete
lookback window, and returns no columns before one exists.

Code: `R/history-frame.R:ledgr_history_requirements` (:801-827): NULL means
`lookback` for a finite lookback, else every available session; an explicit
value may be smaller, never larger. `ledgr_history_compact_admission`
(:770-788): `included = finite_observation_count >= min_observations`.

Existing contract (contract-context-pulse-data): "`min_observations` is the
per-instrument estimator admission rule. `NULL` means the finite lookback,
or every returned session for `lookback = Inf`; an explicit non-negative
integer may be smaller ... The count is finite values in the returned
treated plane ... Instruments below the requirement are excluded with
`insufficient_observations`." and "a zero-instrument wide result keeps its
sessions with only `ts_utc`".

Added (same bullet): "Under the default a finite-lookback read therefore
admits an instrument only with a complete window of `lookback` finite
treated values, and before `lookback` sessions exist on the history axis it
admits no instrument and returns no instrument columns; an explicit smaller
requirement admits earlier (LR-07)."

Witness: `tests/testthat/test-history-frame.R` LTB-0299 (default excludes
BBB as `insufficient_observations`; `min_observations = 0L` admits all-NA
warm-up cells at pulse 1); the probe (lookback 3 at session 1: matrix 1 x 0
by default, 1 x 3 with `min_observations = 1L`; at session 3 BBB is admitted
with a carried value counted).

Wording resolved: "complete" = `lookback` finite treated values (carried
values count), under the default only.

Side note (not edited): the code also records `carry_expired` and
`structural_exclusion` exclusion reasons; the contract names only
`insufficient_observations`.

## LR-08

Ledger: Missing price inputs are carried for up to five sessions for features
and history (history projection v11), while `ctx$close` stays `NA`; a
running-sum indicator passes through the carried value.

Code: `R/history-policy.R:ledgr_history_policy` (:22, `price_carry = 5L`,
`NULL` disables); the context bar comes from
`R/history-substrate.R:ledgr_history_substrate_bar_packet` (:475-485) over
the raw sealed matrices of `ledgr_history_substrate_bar_matrices` (:422,
NA where no bar), gathered at `R/fold-engine.R:601-612`.

Existing contract: contract-availability-units-and-universe (default at most
five later expected sessions; never backward, never volume, lifetime and
sticky terminal barriers; return/volatility consume no carried price);
contract-context-pulse-data history axis bullet (bar values carry within the
horizon, volume never, no fill across barriers); contract-context-strict-features
(treated once per preparation, default five sessions, `price_carry = NULL`
raw; level rows and undeclared custom definitions consume treated input;
`input_carry = "excluded"`).

Added (contract-context-pulse-data, new bullet): "The flat `open`, `high`,
`low`, `close` and `volume` columns hold the instrument's sealed bar at the
pulse and are `NA` without one. The history policy's price carry applies
only to feature inputs and history reads, and a stale or frozen mark never
fills these columns (LR-08)."

Witness: `tests/testthat/test-context-frame-retirement.R` LTB-0546
(`missing$close[["AAA"]]` NA on a missing-bar session);
`tests/testthat/test-history-integration.R` LTB-0300 (BBB close history 21,
22, 22, 22, 25, 26; SMA(2) 23.5 and 25.5 from the carried close); the probe.

Wording resolved: the five-session default with its overrides, exclusions
and terminal barriers was already contract and is reused; "running-sum
indicator passes through" is the existing level-row rule (the last-digit
TTR running-sum effect is an algorithm property, not written).

## LR-09

Ledger: Stored prices are rounded to eight decimals.

Code: `R/snapshot_adapters.R:ledgr_snapshot_from_df` (:123-127, OHLCV
`round(, 8L)`); fact-bearing ingest
`R/availability-ingest.R:ledgr_availability_prepare_observations` (:176-180);
`ledgr_snapshot_from_csv()` and `ledgr_snapshot_from_yahoo()` call
`ledgr_snapshot_from_df()`. `ledgr_snapshot_seal()` does not round rows
appended directly (`R/snapshots-seal.R`, the documented create/append/seal
route); the hash encoder rounds present numerics to 8 decimals
(`R/snapshots-hash.R:107`). No rounding on read.

Existing contract (contract-snapshot-bar-validation): "Every stored open,
high, low and close is positive (after rounding to 8 digits)".

Added (contract-snapshot-bar-validation, new bullet):
"`ledgr_snapshot_from_df()`, and through it `ledgr_snapshot_from_csv()` and
`ledgr_snapshot_from_yahoo()`, store open, high, low, close and volume
rounded to eight decimal places, and execution reads the stored values.
Rows appended directly to `snapshot_bars` before `ledgr_snapshot_seal()`
are stored as given (LR-09)."

Witness: `tests/testthat/test-snapshot-from-csv.R` "bars CSV rounds OHLCV to
8 decimals" (inputs off by 1e-9, checked at tolerance 1e-12). No witness for
the direct-append clause (read from code only).

Wording resolved: "stored prices" narrowed to the constructors; volume
included.

## LR-10

Ledger: A fill at the next session's open belongs to the first decision after
it.

Code: a pulse's fills are installed in its P4; the next pulse's P1 values
and records equity with them (`R/fold-engine.R:633`) and the next decision
sees them. Replay: `R/accounting-replay.R:ledgr_accounting_positions_at_pulses`
(:600-627) and `ledgr_accounting_equity_from_replay` (:637) include events
with `ts <= pulse`. Declared-session opportunities are the next sessions'
opens (`R/availability-facts.R:2674`); a continued carry window adds one
opportunity after its last pulse (`R/availability-provider.R:463`).

Existing contract: contract-availability-provider-and-timing "records
accepted fills and events at the next declared session opening";
contract-result-completion-and-valuation "`recording_pulse_ts_utc` ... A
unique session opening maps to its session close ... Align fills to equity
only after grouping fills by recording pulse"; contract-persistence-fold-evidence
entitlement "a fill executed at the entitlement session's open is not
entitled".

Added (contract-execution-fills-and-lots, new bullet): "A fill belongs to
the first decision pulse at or after its execution time: that pulse's
holdings, cash and equity row include it, and the pulse that decided it does
not. A declared-session fill at session `t + 1`'s opening belongs to the
decision at session `t + 1`'s close; a bar-native fill stamped at bar
`t + 1` belongs to pulse `t + 1`. A continued carry window's final fill has
no later pulse in its run and reaches the next window through that window's
opening (LR-10)."

Witness: `tests/testthat/test-availability-execution-timing.R` "fill results
expose derived recording-pulse alignment" (09:30 fill, recording pulse
16:00 the same day; replay equity under the `<=` rule equals stored
equity). The probe's scenario 2 also maps every bar-native fill to bar t+1.

Wording resolved: the carry-window exception added.

## LR-11

Ledger: The fills reader reports a closing leg's own `realized_close` and zero
for openings, not the book's running `event_realized`.

Code: `R/accounting-replay.R:ledgr_accounting_fills_from_replay` (:703)
`realized_pnl = ifelse(close_leg, replay$realized_close[source], 0)`;
`R/output-handler.R:ledgr_fill_leg_block` (:58-59) same. `realized_close`
is the FIFO price difference times the consumed quantity, before fees
(`R/lot-accounting.R:455-456`).

Existing contract: carrier leg row "an OPEN leg realizes 0";
trade statistics use `realized_pnl` of closed trade rows.

Added (contract-result-fills-and-sweep-restoration, new bullet): "In the
fills reader and the fold's leg group, a `CLOSE` row's `realized_pnl` is
that leg's own FIFO realization (its closed quantity against the consumed
lots' prices, before any fee) and an `OPEN` row's is 0; it is neither the
fill's fee-net realized delta nor the book's running realized total
(LR-11)."

Witness: `tests/testthat/test-accounting-consistency.R` LTB-0004 (CLOSE
`realized_pnl` 8 and 6 with fees 3 and 6; running `event_realized` would be
5 and 5, fee-net `realized_delta` 5 and 0).

Wording: "before any fee" added; the compiled spot-FIFO projection is not
claimed.

## LR-21

Ledger: A fill's fee is split outside the lot kernel: the closing leg takes fee
x close_qty / (close_qty + open_qty) and the opening leg the rest, a row
without a positive finite quantity splits nothing, and the kernel's realized
delta subtracts the whole fee.

Code: `R/lot-accounting.R:ledgr_fill_leg_fees` (:235-248):
`close_fee = fee * close_qty / total` when total finite > 0 and close_qty > 0;
`open_fee = fee - close_fee` when open_qty > 0; else 0. Called once per block
by `R/output-handler.R:ledgr_fill_leg_block` (:47). `ledgr_lot_apply` :484
`realized_delta <- realized_close - fee`.

Existing contract: contract-execution-accounting-events "a resolved fee is
split across the fill's close and open legs only by `ledgr_fill_leg_fees()`";
carrier leg row "the canonical fee split (`ledgr_fill_leg_fees()`)";
contract-result-fills-and-sweep-restoration "its fee is allocated pro rata by
the non-negative absolute leg quantities. The derived fees for that event
must sum to its source fee in durable, reconstructed, memory-backed, and
compiled spot-FIFO projections."

Added (same bullet, appended): "The fold's leg group splits each fill row's
fee once (`ledgr_fill_leg_fees()`): the closing leg takes `fee * close_qty /
(close_qty + open_qty)` and the opening leg the fee less that amount, and a
row without a positive finite total leg quantity assigns no leg fee. The lot
kernel's realized P&L delta for a fill subtracts the whole fee from its
closing realization (LR-21)."

Witness: `dev/lean_core/parity/evidence/fifo_parity.csv` leg-fee columns
(bit-exact lean vs pin) and FIFO mutation `swapped_fee_split` (9 streams
differ); `test-accounting-consistency.R` LTB-0004 (1.2/1.8 and 4/2, tolerance
1e-12, so not bit-level).

Wording resolved: scoped to the fold's leg group. Finding (not written): the
durable and replay fills reader (`ledgr_accounting_fills_from_replay`,
`R/accounting-replay.R:689-694`) computes its own split, `fee` for a pure
close and `fee * (close_total / total)` for a reversal. Both are the
contracted pro rata rule, but they are different floating-point expressions:
`0.1 * 3 / 3 != 0.1` and `f * 3 / 7 != f * (3 / 7)` were confirmed in R. So
a sweep candidate's inline fills (leg block, via `inline_summary`) and the
same run's durable fills can differ in a fee's last bit, and a pure close's
leg fee in the leg block need not equal its source fee exactly.

## LR-22

Ledger: A non-finite applied value with no earlier refusal (opening or
disposition overflow, any overflow on a corrupt book) refuses in production
with `ledgr_lot_state_invariant` "Invalid applied lot rows."; only the
applied rows' split and slack self-checks are debug-only (LR-13).

Code: `R/lot-accounting.R:ledgr_lot_applied` (:383-392) refuses any
non-finite, wrong-length, negative split, opening split, slack or split-shape
violation with `c("ledgr_lot_state_invariant", "ledgr_invalid_state")`,
"Invalid applied lot rows."; the fill overflow refusal of `ledgr_lot_apply`
(:565-568) is dropped for a corrupt book. In the pin every check runs; the
debug-only split and slack checks are the lean change of LR-13.

Existing contract: contract-execution-fold-carrier "the lot book and applied
rows [refuse] with `ledgr_lot_state_invariant`"; contract-execution-fills-and-lots
"A non-finite result from a corrupt book stays `ledgr_lot_state_invariant`.
Openings and dispositions are not covered by this refusal".

Added (contract-execution-fills-and-lots, same bullet): "A non-finite applied
value that no earlier refusal caught (an opening's or a disposition's
overflow, or any overflow from a corrupt book) refuses with
`ledgr_lot_state_invariant`, message `Invalid applied lot rows.` (LR-22)."

Witness: `dev/lean_core/parity/fifo_streams.R` stream `refuse_nonfinite_rows`
(opening 1e300 x 1e300, disposition 1e300 x 1e300, corrupt-book fill 1e308;
3 refusals identical with debug off and on, `fifo_streams.csv`);
`tests/testthat/test-ws4a-carrier.R` "[WS4a overflow refusal]" :2777-2786
(corrupt book, infinite total, reported-corrupt book). No registered pin test
drives an opening or disposition overflow (parity stream only).

Wording resolved: the debug-only half is not written as current behaviour;
it stays under LR-13 (change) and the contract's "Accepted change pending:
lean core pulse plumbing" headers.

## LR-23

Ledger: A decoded decision preserves the strategy target in `target` and
`target_before_risk`, and the transformed target in `target_after_risk`,
even when the strategy requested its current holding; a risk-changed
decision cannot be certified as a clean hold or clean decision/fill pair.
Extended by Cut 19: clean only on a current-close mark of age 0 with the
plain decision reason and no stale-mark risk row for its instrument; a
stale, frozen, expired or missing mark, a restriction reason or
sizing_unavailable keeps the row explicit.

Code: `R/fold-engine.R:ledgr_fold_stage_decide` (:949-965 decision segment;
:1025-1055 the risk segment, which holds only stale-mark rows);
`R/diagnostic-codec.R:ledgr_diagnostic_clean_fill` (:33-58) and
`ledgr_diagnostic_clean_hold` (:60-82): both require `target ==
target_after_risk`, finite price, `decision_recorded` reason and reasons,
`mark_source == "current_close"`, `mark_age == 0L` and no risk row for the
instrument; a hold also needs target = holding = after, a fill pair a
matching position_before, planned after = target and an empty fill reason.

Existing contract: contract-persistence-fold-evidence "Exact current-close
clean decisions and fills/holds may use the certified implicit codec; every
difference remains a typed physical residual"; contract-execution-fold-core
"P3 certifies exact clean decision/fill and clean-hold forms by context
ordinal".

Added (contract-persistence-fold-evidence, the LR-01 bullet): "... Only an
exact clean form may use the implicit codec: a clean hold or clean
decision/fill pair needs a transformed target equal to the strategy target,
a finite current-close mark of age 0, the plain `decision_recorded` reason
and no stale-mark risk row for its instrument. A decision the risk chain
changed, or one on a stale, frozen, expired or missing mark, with a
restriction reason or with `sizing_unavailable`, stays an explicit physical
row (LR-23)."

Witness: gate workloads `s2_risk_bind` (reach predicate: a held position the
strategy asked to keep, strictly reduced by risk, then a sell) and
`s3_gap_held`; variant `clean_rule_ignores_marks` (loop_parity.R:253,
`loop_variant_changes.csv`; caught with `ledgr_diagnostic_corrupt` and table
differences in cut19, cut20 and cut21 variant evidence);
`tests/testthat/test-strategy-sizing-evidence.R` LTB-0542 (decision rows with
`target_before_risk != target_after_risk`).

Wording: the conditions listed are necessary, not the complete predicate.

---

## For the maintainer (written as shipped, may surprise)

1. LR-11: closed-trade `realized_pnl` is gross of fees, so `win_rate` and
   `avg_trade` are gross of fees (tested by LTB-0004, now contract).
2. LR-03/LR-04: the reconciliation detail's `cash_before` is recorded cash
   minus a `sum()`, not the previous recorded cash; in the probe it differs
   from the previous pulse's recorded cash bitwise on 29 of 39 pulses.
3. LR-09: only the constructors round; rows appended directly before
   `ledgr_snapshot_seal()` keep their values while the hash rounds them.
4. LR-21: two leg-fee expressions exist (leg block vs replay reader); sweep
   inline fills and durable fills may differ in a fee's last bit.

Pre-existing contract text noticed, not edited: the
contract-result-completion-and-valuation fill-time bullet has a duplicated
broken sentence ("recorded fill association and sealed session facts; it is
not persisted ..."); the `min_observations` bullet omits the
`carry_expired` and `structural_exclusion` exclusion reasons the code
records.
