# Peer-suite response probe

2026-10-28, response stage. **Answer: the availability core reproduces today's
dense SMA fills only when keyed on the recording pulse and only when the run
opens at the data start; the recipe enters on first usable scores without a
transition; holdings by asset are readable from native ledger events.** This
is a small correctness probe on a 12-instrument, 90-session simulated
fixture. It is not a timing, memory or peer record.

`probe.R` runs the existing public TTR SMA 5/10 crossover recipe four times on
the same bars (session close 21:00 UTC): dense (no facts) and availability
(declared sessions plus a complete membership snapshot), each opening at the
data start and at session 30. Observations (`evidence/observations.csv`):

- Opening at the data start, both paths produce 121 fills with identical
  recording pulse, instrument, side, quantity, price and fee. The tables are
  not `identical()`: dense stamps `ts_utc` with the next bar's timestamp
  (21:00), availability with that session's open (14:30). Dense writes 0
  diagnostic rows, availability 1,291.
- Opening at session 30, dense produces 87 fills and availability 89. Eleven
  availability fills (2020-02-12 to 2020-02-21) have no dense counterpart:
  availability history starts at the data start, so its indicators are warm at
  the scoring start, while dense feature state starts at the scoring start
  (`contracts.md`, History start, Cut 16). The paths diverge from the first
  scoring pulse onward.
- Six of twelve instruments take their first long position on the first bar
  where both SMAs are usable, with no observed below-to-above transition. A
  decision timeline rebuilt from TTR under the recipe's first-state rule
  matches every dense fill by (instrument, next session); a transition-only
  rule (an entry needs a usable prior below-state, as backtrader `CrossOver`
  and quantstrat `sigCrossover` require) differs in 6 of 121 decisions, first
  at 2020-01-14T21:00Z. This locates a first divergence without any peer.
- Cumulative signed FILL quantities from `ledgr_results(bt, "ledger")` times
  the bar close reproduce `positions_value` within 2.1e-8 on every pulse, so
  holdings by asset need no accounting re-implementation.

The seed may consume: the C1 oracle must declare its fill identity key and its
expected representation changes (execution stamp, diagnostics) before C1; a
dense witness that opens after the data start is a known changed-meaning row
under accepted contracts; the dense recipe's warmup entry rule must be fixed
in the workload contract before the oracle is frozen; decision timelines are
the right first-divergence surface. It may not infer peer runtime, memory,
availability or the behaviour of any peer.

`check.R` reruns into scratch and reproduces the recorded CSVs; with `--gut`
the transition-only rule loses its prior-usable-state requirement and the
observations diff fails. Tracked package and design scope are unchanged.
Source, snapshot and config identity are in `evidence/environment.txt`.
