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
