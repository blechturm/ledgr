# RFC Response: Peer Benchmark Suite (Type 2)

**Status:** response stage 3 of `rfc_cycle.md`, written by Claude in a clean
context on 2026-10-28 at the maintainer's request. Non-binding.
**Seed:** [rfc_peer_benchmark_suite_v0_2_3_seed.md](rfc_peer_benchmark_suite_v0_2_3_seed.md).
**Inputs read:** macro plan revision 2; roadmap and horizon suite entries;
`benchmark_methodology.qmd`; `spike_protocol.md`; `dev/bench/peer_benchmark/`;
A0; the strategy-grammar benchmark; strategy-authoring synthesis D1, D3, D4;
`contracts.md`. **Probe:** `dev/spikes/peer_suite_response/` (runner, checker,
gut, inventory, findings), executed on `07dbbc87`. Facts are labelled
*verified* (source or documentation), *executed* (probe or record) or *proposal*.

## 0. Verdict

**REVISE: seed v2 required.** The five-lane shape, parity-first policy, the
separation of internal regression from cross-framework parity, and the
report goals are right and well argued. Three load-bearing contracts would
not deliver what the seed promises as written: the "exact" C1 oracle (F1),
the dense decision contract (F2) and the equivalence/retention vocabulary the
headline depends on (F3, F4). Several practical dependencies are unverified
or unavailable (F7, F9). None of this needs a benchmark framework of our own;
it needs three reuses and about ten contract sentences.

## 1. What the seed's prerequisite probe proves, and what the new probe adds

The seed probe (`dev/spikes/peer_suite_seed/`) proves one thing, correctly:
`peer_parity()`'s label reads only equity (`peer_benchmark.R:1724-1726`), so a
fill mutation with unchanged equity stays "passes Tier 1 tolerance". Its
diagnostics file is empty, its equity carries only `positions_value`, and it
says nothing about what C1 will change. The response probe (executed) adds:

| Observation | Result |
| --- | --- |
| Dense vs availability fills, opening at data start, keyed on recording pulse, instrument, side, qty, price, fee | identical (121 fills) |
| Same tables compared with `identical()` | differ: dense stamps `ts_utc` at the bar time 21:00, availability at the session open 14:30 |
| Diagnostic rows, dense vs availability | 0 vs 1,291 |
| Opening at session 30 | 87 vs 89 fills; 11 availability fills at the scoring start have no dense counterpart |
| Instruments entering on the first usable score with no observed transition | 6 of 12 |
| Decisions under the recipe's first-state rule vs a transition-only rule | 121 vs 115; first divergence 2020-01-14T21:00Z; dense fills match the first-state timeline 100% |
| Holdings by asset from `ledger` FILL events times close vs `positions_value` | max abs 2.1e-8 |

The late-opening difference is accepted design: dense feature state starts at
the scoring start, availability history at the data start
(`contracts.md:183-197`, "History start (Cut 16, LDG-3064)").

## 2. Ranked findings

### F1. The C1 oracle cannot be "exact" on the seed's table set (maintainer decision)

*Evidence.* Seed 5.1 freezes fills, equity/cash, holdings, diagnostics and
state evidence and compares "exactly". Executed: after C1 every dense fill's
`ts_utc` changes representation (bar time to session open), the diagnostics
table goes from zero rows to a full trace (`R/fold-engine.R:161` only warns in
dense mode; the availability path records reason rows), and any witness that
opens after the data start changes its fills by design.

*Consequence.* As written, every dense row fails after C1, or every failure
is waved through as a "decided difference", which is the same as no gate.

*Disposition.* Define the oracle on declared keys, frozen before C1:
fills exact on (`recording_pulse_ts_utc`, `instrument_id`, `side`, `qty`,
`price`, `fee`, `realized_pnl`, `action`); equity, cash and holdings by asset
exact per pulse (holdings from cumulative ledger FILL quantities, or from
`ledgr_state_reconstruct()`, both native); terminal/corporate-action evidence
exact where the workload has it. The execution stamp and the diagnostics
trace are compared under a separate *representation* contract whose expected
changes (session-open stamp, new diagnostic categories, M8b disclosure) the
C1 cut lists before implementation; unlisted changes fail. Every dense witness
opens at the data start; one late-opening witness is carried as a labelled
known-changed-meaning row, not as a parity failure. The maintainer decides:
(a) the fill identity key above; (b) whether the session-open stamp is the
intended post-C1 representation (implied-calendar disclosure, WS4).

### F2. The dense recipe's entry rule is undeclared and is not the peers' crossover (maintainer decision on the rule, spec-cut on the rest)

*Evidence.* Executed: 6 of 12 instruments enter on the first usable score
without an observed transition; the recipe seeds `was_above = FALSE`
(`peer_benchmark.R:203-205`). Verified: backtrader `CrossOver` and quantstrat
`sigCrossover` need a prior relation; the zipline adapter copies ledgr's
default. The v0.2.2 record shows backtrader at -238 trades and zipline at
-682 with 1,250 diverging bars, yet "pass" (`peer_benchmark.md`, Tier 1 and
Tier 3); the classifier labels any unexplained residual
"position_size_differs" (`peer_benchmark.R:1856`), printed as 99.99% position
size. Nobody has attributed those trades.

*Consequence.* The first dense row the suite publishes would inherit an
unexplained decision divergence and a mislabelled attribution.

*Disposition.* Seed 4 item 1 states the warmup entry rule in one sentence
(recommend: no decision on the first usable score; an entry needs two
consecutive usable scores with an observed transition, which every peer can
express) and every adapter implements that sentence. The oracle is frozen
after the rule is fixed, not before. First divergence is located on decision
timelines (instrument, signal pulse, target) before any price is compared;
the probe shows this needs no peer. Retire `peer_parity()` tiers and
`peer_classify_divergence()`; keep `peer_exact_surface()` and
`peer_equity_parity()` (`peer_benchmark.R:1159-1225`), the phase clocks
(`:245-340`), the uv runtime and the adapters' output shape.

### F3. Fill-level equivalence is natively reachable for four peers, decision-level for six; the headline needs both counts (maintainer decision)

*Verified per peer.* backtrader: market orders fill at the next bar's open
(official docs, "Order creation/execution"). quantstrat: `ruleOrderProc`
fills at `getPrice(mktdataTimestamp, prefer = prefer)`; with `prefer = NULL`
it greps "price", "trade", then "close" (`ruleSignal` docs); the existing
adapter passes no `prefer` (`peer_benchmark.R:863-864`), so its recorded
"fill timing" residual is harness-attributable and `prefer = "Open"` is the
native fix. PMwR `btest`: "Trading then takes place at the opening price of
`t`" with signals from information before `t` when `prices` is the OHLC list
(CRAN reference); the grammar spike used close-only lagged execution and
fractional weights (its inventory), so a next-open numeric row is expressible
but has not been run. PyBroker 2.0.2 (PyPI, 2026-10-20, Python >= 3.11):
`buy_delay = 1` fills on the next bar; default fill is the bar midpoint;
`ExecContext.buy_fill_price` accepts `PriceType.OPEN` (reference docs).
zipline-reloaded: orders placed in `handle_data` are processed before the
next bar's `handle_data` ("orders placed in the last bar",
`gens/tradesimulation.py`) at `data.current(asset, "close")`
(`finance/slippage.py`), so daily rows fill at the next session's close;
next-open is not natively expressible. bt: trades at the current close
(grammar spike, executed).

*Consequence.* Seed 8 promises one "equivalent" count per peer. zipline and bt
can only be decision-equivalent on the next-open contract, so one count shows
them permanently non-equivalent or tempts the adapter-owned fill simulator
seed 4 rightly forbids.

*Disposition.* Two declared equivalence levels per row: *decision-equivalent*
(axes, NA masks, decision timelines and quantities exact) and
*fill-equivalent* (that plus execution session, price, cash and equity under
the field tolerances). Only fill-equivalent rows enter the warm runtime ratio
set; decision-equivalent rows sit beside it with the named execution
difference. Assignment follows: dense numeric rows for ledgr, backtrader,
quantstrat (`prefer = "Open"`), PMwR (OHLC list) and PyBroker
(`PriceType.OPEN`); zipline in dense at decision level with its next-close
residual classified once; bt in authoring plus decision-level rows where
cheap. No peer is forced.

### F4. The ledgr headline surface and retention are unsettled (maintainer decision)

*Verified.* The fastest ledgr row in the record is the one-candidate sweep
(16.2 s warm) retaining returns and closed trades only; its cash and holdings
columns are `NA` and its fills table empty (`peer_benchmark.R:1095-1097`),
while backtrader's row writes equity, cash and fills. The durable `ledgr_run`
row (27.8 s warm) materializes the full tables. Seed 6 states the
comparable-retention rule only for PyBroker.

*Disposition.* Name the headline ledgr surface: `ledgr_run` with the required
tables, or `ledgr_sweep` with retention that materializes them; the minimal
sweep belongs in the labelled amortized session view. One retention sentence
for every engine: the warm clock ends when fills, equity, cash and holdings
by asset exist in process memory or on disk via the public workflow.

### F5. The portable report has no committed input (spec-cut detail)

*Verified.* The current report reads git-ignored `dev/bench/results/`, falls
back to the latest status file when no prefix is given
(`peer_benchmark.qmd:99-112`) and renders GFM with PNG side files. Seed 8
requires explicit selection and a self-contained HTML; seed 9 keeps raw
records local without defining what is committed.

*Disposition.* One committed directory per accepted record under
`dev/bench/peer_benchmark/records/<id>/`: status, parity at both equivalence
levels, performance repeats, first-divergence rows, memory peaks, environment
and lockfile hashes; no raw fills. The render takes `-P record:<id>`, fails
without it, uses `embed-resources: true` and reads only that directory. The
`parity_history/*.json` registry is retired (spike protocol 5).

### F6. Headline set, denominators and caveats need predeclaration (spec-cut detail)

*Disposition.* Commit before the first promoted run: the headline rows (one
warm median ratio per fill-equivalent workload and peer; one memory view with
warm-execution private bytes and working set per engine); per-peer counts
attempted, fill-equivalent, decision-equivalent, classified residual,
unsupported, unavailable and failed, each peer's own attempted rows as its
denominator; absolute medians with min and max; sorted by workload, never by
ratio; no pooled speedup; one caveat line per headline (host, versions,
retention, JIT state); authoring-only peers in a separate table with no
numeric claim; record identity and commit on the first screen.

### F7. Peer provisioning is not reproducible from the repository today (spec-cut detail, release-gate owner)

*Verified.* The isolated quantstrat library and R profile lived under
`C:/tmp` and are gone; the README records GitHub SHAs but no installer;
`write_quantstrat_environment.R` correctly records UNAVAILABLE. backtrader
1.9.78.123 and zipline-reloaded 3.1.1 are uv-pinned (zipline needs Python
< 3.13, PyBroker 2.0.2 needs >= 3.11). PMwR is on CRAN; bt was temporary.

*Disposition.* One `provision/` recipe per peer in the suite directory:
R scripts installing pinned SHAs into an isolated library for quantstrat
and PMwR, uv projects for the three Python peers, each writing the sidecar
the harness already expects. "Every selected peer needs a completed native
row" (seed 3) becomes a named release-gate item with an owner, otherwise the
suite is called complete with UNAVAILABLE rows, as the v0.2.2 record was.

### F8. Strategy-source generations will invalidate naive exact comparison (spec-cut detail)

*Verified.* The recipe reads `ctx$features_wide` (`peer_benchmark.R:189`),
which context-frame retirement removes; the accepted D1 replaces public
`ctx$vec`, `ctx$feature()` and `ctx$features()` after WS5 (synthesis D1).
A0's records embed `config_json` and `strategy_hash` (A0 closeout, open
point 3). The reruns after WS4 and WS8 therefore run rewritten ledgr strategy
source by necessity.

*Disposition.* Author the dense workloads once on `ctx$vec$feature()` so they
survive WS4 unchanged, migrate them once to the flat `ctx` at WS5 and label
the generation; exclude strategy source and hash fields from the exact
oracle by declaration and record them per generation in provenance. The old
pipeline row's `ctx$features()` correction is a generation label for the
authoring lane, not an accessor to revive.

### F9. Simulator and geometry gaps (answers seed question 3)

*Verified.* `ledgr_sim_bars()` emits complete weekday daily bars, no holidays,
gaps or sub-daily spacing (`R/sim-bars.R:44-105`). `ledgr_sim_pit_inputs()`
supplies calendar, missing-observation, delisting and halt cases for the
point-in-time demonstration. zipline's csvdir bundle needs a calendar that
matches the sessions; the current adapter maps sessions positionally
(`peer_zipline_full.py:source_session_labels`), which seed 5.2 forbids.

*Disposition.* A benchmark-owned seeded generator for holiday gaps, missing
instrument bars and minute-labelled sessions; missing-bar witnesses stay
internal. Narrow intraday row: 20 instruments by 23,400 pulses (60 sessions
of 390 one-minute labels, 14:30-21:00 UTC), about 468k instrument-bars, 18.6
times the reference pulses at 0.74 times its bars, isolating the per-pulse
floor. Peers: ledgr, backtrader, quantstrat, PMwR, PyBroker; zipline
unsupported unless a native minute bundle is built, which is not required.
Stress row 1,166 by 7,200: one repetition per engine, 120-minute wall and
16 GB private-bytes limits, censored otherwise. Batches 10 and 100 measured;
1,000 projected only where 100 ran under 30 minutes, labelled projection.

### F10. Memory sampling is one combined working-set peak (spec-cut detail)

*Verified.* `run_record.ps1:46-77` sums `WorkingSet64` over the whole process
tree once per second; the promoted figure is one peak for all engines, which
the horizon memory addendum already rejects. *Disposition.* The runner samples
each row's own child tree, records working set and private bytes with the
interval, and reports cold-preparation and warm-execution peaks separately,
plus the retained baseline after results exist. One implementation, no
per-adapter sampler.

### F11. Protocol and reuse: no framework needed (proposal)

Reuse three things instead of building: LDG-3127's timing protocol and
checker (fresh process per measurement, alternating pairs, ratio of medians,
power plan and affinity recorded); A0's canonical CSV writer and gut pattern
(`dev/bench/v0_2_3_output_freeze/lib.R`) for the frozen dense tables; the
existing adapters' output shape and uv runtime. One runner file per lane plus
adapters under the 1,500-line budget; four rule families and ten detectors
first, as seed 9 says.

## 3. Answers to the seed's five questions

1. Assignments: sufficient once F3's two levels are adopted. Numeric rows
   for ledgr, backtrader, quantstrat, PMwR and PyBroker; zipline and bt at
   decision level; bt's authoring role stands; the first ledgr/PyBroker
   rotation is viable natively (`long_score` ranking with
   `set_max_long_positions`, next-bar fills at `PriceType.OPEN`,
   `calc_target_shares` on the symbol's price), with ties resolved by the
   contract (ledgr: instrument-ID C-locale order, `R/strategy-helpers.R:204`;
   PyBroker's tie order must be observed and recorded, not assumed).
2. Dense deletion witnesses beyond SMA: time-series momentum filter, mean
   reversion and one recursive TTR case, each with one cost and one risk
   witness; calendar and missing-bar rows internal only; final-pulse no-fill
   and warmup rows under F1's representation contract. Exact comparison stops
   at the execution stamp and diagnostics (C1, listed), late-opening warmup
   (Cut 16), whole-share or fill-policy changes (WS10, separate rows) and
   strategy-source generations (F8).
3. Geometry and budgets: F9.
4. Tolerances: exact on axes, NA masks, decision timelines, quantities and
   execution session; per-field numeric tolerance on price, cash and equity
   only, fixed before any peer row from the ledgr-vs-ledgr spread (4.0e-7
   durable versus sweep in the record), recommended abs 1e-6 or rel 1e-9;
   first divergence is the earliest (pulse, instrument) decision difference,
   else the earliest field residual; a widened tolerance is never a pass.
5. Reuse boundaries: ledgr, sealed snapshot reusable, experiment warm;
   backtrader, pandas frames reusable, feeds and `cerebro` rebuilt inside
   warm; zipline, bundle ingestion cold, `run_algorithm` warm; PyBroker,
   data-source and indicator caches public (`enable_*_cache`), Numba JIT warm
   only within a process, so cold-JIT is a fresh process and warm-JIT a second
   run in it; quantstrat, xts reusable, portfolio/strategy objects
   re-initialised per run; PMwR and bt, price matrix reusable, `btest` or
   `Backtest` per run. First cut: five alternating repeats per row in two
   engine orders, one fresh process per measurement, the registered host
   rules, a 20-minute per-row limit outside the stress tier.

## 4. What the maintainer decides versus spec-cut detail

Maintainer: F1 (fill identity key and post-C1 stamp), F2 (warmup entry rule),
F3 (two-level equivalence in the headline), F4 (headline ledgr surface and
retention sentence), the late-opening witness disposition, and whether an
UNAVAILABLE peer blocks "suite complete". Spec-cut: F5-F11 and all numbers.

## 5. Disagreements preserved

- Seed 2 calls the old residual-attribution machinery reusable; the record it
  produced labels an unexplained 238-trade gap as position sizing. Retire it.
- Seed 5.1 puts diagnostics in the exact oracle; the table is empty today and
  full after C1. A representation contract instead.
- Seed 8's single "equivalent" count would misreport zipline and bt forever.
- Seed 3 treats the SMA crossover as settled; its entry rule is not.
