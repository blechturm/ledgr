# R-floor probe findings, 2026-11-03

`probe.R` ran the published SMA5/SMA10 transition rule (quantities 0 or 1,
cash 1e7, zero cost, no risk, fixed basket) through installed ledgr at
`0d6c0b11` on 3 instruments x 40 simulated daily bars, before any floor code
existed. Observed:

- A decision at pulse t fills at the open of pulse t + 1 and the fill is
  stamped with that bar's timestamp (`recording_pulse_ts_utc` is a separate
  column). The first fill's price equals that bar's open exactly.
- The last pulse never fills.
- `ledgr_results(bt, "equity")` has one row per pulse with `equity`, `cash`
  and `positions_value`; equity at pulse t is valued at its close before
  decision t executes.
- The feature values match `TTR::SMA()` on the close series.

Found while building the floor (`run.R` parity rows): booking a pulse's fills
as one summed cash change differs from ledgr by 9.3e-9 in cash at 10 x 300.
ledgr books cash fill by fill in event order; the floor does the same and is
then bit-identical.

## Stage 3 probe: a changing axis, 2026-11-03

`probe_axes.R` on `axes_fixture.R` (30 instruments, 250 declared daily
sessions, membership intervals that start and end, about 3 percent missing
bars, `ledgr_valuation_stale(5)`), installed ledgr at `0d6c0b11`:

- The decision axis changes on almost every pulse: 0 to 27 instruments, 26
  distinct sizes, one pulse with an empty public domain.
- A context retained by the strategy at pulse 20 is unchanged after the run
  (`close`, `universe`): ledgr's frozen-view guarantee holds.
- ledgr refuses a target that increases a held former member: "Held
  nonmembers may only hold, exit, or reduce existing exposure". The strategy
  must read `ctx$member`.
- `ledgr_history_matrix(ctx, bar = "close", lookback = 10)` returns a
  10 x n matrix of admissible instruments and costs about 200 us per call.
- 2,717 fills, 788 of them partial sells, so FIFO lots are consumed
  partially. Diagnostics carry rules the fixed basket never exercised: 85
  `no_fill / execution_bar_missing`, 7 fills with
  `membership_changed_before_execution`, 93 `risk / passed /
  stale_mark_pass_through`, 147 stale marks, 5 final-pulse requests.
- Per pulse (`prof_axes`, scratch): ledgr spends about 4.4 ms, of which the
  fold stages take 3.1 ms (decide 0.67, plan 0.64, commit 0.61, apply 0.49,
  observe 0.37, envelope 0.34) and setup and finalisation 1.3 ms spread over
  250 pulses. Reading history every pulse adds about 0.5 ms to decide.
