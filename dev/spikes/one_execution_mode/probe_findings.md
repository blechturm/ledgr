# One-execution-mode probe: findings

Probe under `spike_protocol.md` Section 1; binds nothing, changes no product
code. Base `93d801a8` (codex/cut14-v0.2.2). Runner `probe.R`, checker
`check.R`, evidence `evidence/`. Copied to v0.2.2 from branch
`spike/one-execution-mode` at `bd0e1bd9` with the case summaries,
identities, clocks and errors only. The per-arm result tables
(`*/dense/*.csv.gz`, `*/availability/*.csv.gz`, 2.3 MB) were left out:
`probe.R` regenerates them, then `check.R` compares them (maintainer,
2026-10-14).

**Question.** Do the registered dense fixtures produce byte-identical fills,
ledger, equity, positions and metrics through the availability path with an
implied calendar, full membership, no lifetime or corporate-action facts and
a never-stale policy (`ledgr_valuation_stale(0, "refuse")`)?

**Prerequisite: no.** Nothing builds a calendar from bars. A valuation policy
on a dense snapshot refuses `ledgr_availability_sessions_required`
(`R/availability-policy.R:234`); the provider reads only sealed
`snapshot_sessions` (`R/availability-provider.R:44`), so coverage refuses
`ledgr_sessions_incomplete` (`:303`) and the calendar `ledgr_run_window_too_short`
(`:350`). Sessions must be sealed, so the snapshot root moves. Midnight-UTC
daily bars (`ledgr_sim_bars()`, the peer fixture) cannot even be declared as
UTC sessions: an open must precede its close on the same civil date
(`R/availability-facts.R:693`, `:705`). The probe declared venue zone
`Etc/GMT+1` for them; the long-window bars (21:00 UTC) used UTC.

**Cases** (dense arm vs availability arm, same bars; second snapshot adds
implied sessions; universe = all instruments):

| Case | Fixture | Result |
| --- | --- | --- |
| prereq | peer bars, dense snapshot | refused, see above; root unchanged |
| peer | peer record, TTR SMA 5/10 | equity, positions, metrics identical; fills, ledger, trades differ in `ts_utc` only (every row) |
| peer_builtin | peer, built-in SMA 5/10 | same as peer |
| peer_members | peer + complete membership facts, `ledgr_universe_members()` | same as peer |
| lw | durable-memory dense witness, 600 x 1,514, momentum | same as peer (790 fills) |
| gap_held | peer, one held bar removed | dense refuses; availability INCOMPLETE `valuation_horizon_exhausted` |
| gap_held_default | same, default policy (5, freeze) | dense refuses; availability DONE on a stale mark |
| gap_free | peer, one unheld bar removed | dense refuses; availability DONE |
| gap_exec | peer, an execution bar removed | dense refuses; availability DONE, fill dropped (`execution_bar_missing`) |
| gut | availability arm: one fill's open moved | checker flags `price` in fills |

**The `ts_utc` difference.** `recording_pulse_ts_utc`, prices, quantities,
cash and P&L match. Dense stamps a fill at the next bar
(`R/fold-engine.R:154`); availability stamps the next session's open
(`R/availability-facts.R:2011`, `R/availability-economics.R:444`, timing
version 2). Because open < close is required, no implied calendar can make
them equal. This is a calendar/timing rule, not a fold branch: unification
either moves dense fill timestamps (identity move) or lets an implied
calendar declare no opening clock (product change in calendar construction).
Dense also emits `LEDGR_LAST_BAR_NO_FILL` warnings (22 in peer,
`R/fold-engine.R:114`) where availability records
`final_pulse_no_execution` diagnostics.

**Missing bar.** Dense refuses before the fold with
`LEDGR_SNAPSHOT_COVERAGE_ERROR` in the run snapshot guard, a branch taken only
when availability is inactive (`R/run-snapshot.R:104`). Under never-stale the
availability path refuses only when a *held* instrument needs a mark, and
then as a typed INCOMPLETE stop after the accepted prefix, not up front. An
unheld gap and a missing execution bar run to DONE with no visible error.
No current valuation-policy value reproduces dense strictness; keeping it
needs either the dense-only guard branch or a new explicit coverage policy.

**Clock** (peer record, engine phase = the `ledgr_run()` call, 3 alternating
fresh-process pairs; `t_pre` = preparation incl. feature hydration, `t_loop`
= fold loop, ledgr telemetry):

| Features | Phase | Dense median s | Availability median s | Median pair ratio |
| --- | --- | --- | --- | --- |
| TTR SMA (registered canonical row) | engine | 2.88 | 22.69 | 8.07 |
| TTR SMA | `t_pre` | 0.14 | 19.22 | 137 |
| TTR SMA | `t_loop` | 1.20 | 2.27 | 1.89 |
| built-in SMA (attribution) | engine | 3.17 | 4.52 | 1.41 |
| built-in SMA | `t_loop` | 1.42 | 2.50 | 1.74 |

The long-window case (one in-process run each) shows the same loop gap at
scale: `t_loop` 2.47 s dense vs 9.31 s availability (3.8x).

The TTR slowdown is the strict feature path: availability routes every
feature through `ledgr_compute_feature_series_strict()`
(`R/backtest-runner.R:1101`); TTR SMA has no accelerated strict kind
(`R/features-engine.R:351`), so it falls to a per-window R loop that calls
the TTR function twice per bar (`R/features-engine.R:291`). The fold loop is
slower too: the fast prepared context is disabled on the availability path
(`R/backtest-runner.R:988`, `R/fold-engine.R:409`, `:838`); each pulse
rebuilds the context (`R/pulse-context.R:397`), resolves a decision view and
valuation (`R/fold-engine.R:458`) and writes a decision diagnostic per axis
instrument. An Rprof of the long-window availability run
puts 6.9 s in `ledgr_execute_fold`, of which 1.9 s is canonical JSON
encoding (strategy state, shared with dense, plus the per-pulse
reconciliation detail, `R/fold-engine.R:1267`) and 1.0 s the per-pulse
diagnostic block flush; context rebuild and decision view are 0.5 s and
0.4 s. These are availability-path costs a dense workload would start paying.

**Identity.** Moves on both layers. Snapshot root: sealed sessions
(peer `9021d0ac...` -> `da039df7...`; lw `604abcc1...` -> `9d322c07...`).
Config hash: the availability payload (policy, timing version 2) enters it
(peer `b87182ad...` -> `f89971b9...`). Fill `ts_utc` moves too.

**Verdict: red.** Charter clause: "a dense-only branch inside fold, context
or guard, or a material slowdown, means the history cut serves both modes and
the consolidation opens as an RFC." Both hold: the dense missing-bar refusal
exists only as a dense-only guard branch (`R/run-snapshot.R:104`), and the
dense peer fixture is materially slower on the availability path. The
economic results themselves reproduce exactly (equity, positions, metrics,
prices, quantities) on every dense fixture, so the RFC is about three
decisions, not about accounting: an unsealed or no-open implied calendar,
an explicit coverage-strictness policy, and an availability-aware fast
context plus a strict TTR kind.

**Not checked.** Sweep and walk-forward entry points; `ledgr_backtest()`;
compiled spot-FIFO (refused on availability by contract); corporate-action
snapshots (dense abort vs typed stop, `R/fold-engine.R:574`); the dense
warn-and-zero vs availability skip for unpriced rebalance members; intraday
or irregular bars; a fixture with targets in the final pulse beyond the peer
strategy; Ubuntu.
