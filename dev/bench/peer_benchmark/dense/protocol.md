# Dense native oracle protocol (LDG-3133)

Authority: accepted cut 2, tickets.yml; peer-suite synthesis D3/D4/D6 and
Amendment 1. Product baseline: 5d28db40 (R/src identical to
release/v0.2.3 at 145cc93b). Prerequisite evidence is preserved unchanged at
5d28db40 from accepted source commit 7879e8ba. Reviewer intended:
clean-context Claude CLI, review pending. No execution-core change.

## Inputs and configurations

Four recipe families: SMA crossover, return filter, mean reversion, EMA trend.
The separate cost/final-pulse fixture is a controlled witness, not a fifth
recipe family. Exactly ten coverage configurations follow; two have two arms.

| Configuration | Execution and rule | Inputs / observable evidence |
| --- | --- | --- |
| historical_start | Dense and fact-bearing; verbatim historical first-state SMA5/10 | 12 x 90; ledger, fills, state, stamps, diagnostics, balances |
| transition | Dense; two consecutive usable SMA5/10 scores must cross | Same bars; native above/usable state and fills |
| positive_return | Dense; hold one share if ten-bar return > 0, otherwise zero; warmup holds | Same bars; fills and balances |
| mean_reversion | Dense; enter below .99*SMA10, exit at/above SMA10; warmup holds | Same bars; entries/exits and balances |
| ema_trend | Dense; one share above recursive TTR EMA5, otherwise zero; warmup holds | Same bars; fills and balances |
| historical_late | Dense and fact-bearing; historical body, opening at session 30 | Same bars; separate history/stamp outputs, never forced equal |
| cost_final | Dense; enter AAA=1 on day 1; request AAA=3 on day 8, no next bar | Retyped A0 dense_cost input bars, cash 10000, spread 5 bps + fixed fee 1; fee, held terminal share, warning |
| risk_features (reference) | Independent existing A0 dense_risk_features/run | Opening AAA=5, risk cap, features, fees; ledger/fills/state/conditions |
| dividend_state (reference) | Independent existing A0 dense_dividend_state/run | Opening AAA=2, dividend entitlement/payment, state; ledger/equity/state |
| refusal (reference) | Independent existing A0 failures/run_abort | Dense run abortion; runs/status, conditions, ledger |

The six recipe/window configurations use public ledgr_sim_bars(12, 90,
seed=20260530, start='2020-01-01', instrument_prefix='P'), shifted to
21:00 UTC. Cash 1e7, zero cost, no risk, fixed one-share quantities, seed
20260530 for execution. Daily weekday labels are synthetic, not an exchange
calendar. Fact arms use the same session dates, explicit intervening closures,
14:30 opens / 21:00 closes, all IDs members from the prior day, knowledge
assume_effective, universe 'u'. Price basis split_adjusted. No schedule.

The historical body is retained verbatim from peer_strategy('fast','slow')
at accepted source commit 7879e8ba, attributed in recipes.R, with base R's
%||% (R >= 4.6).
Its public feature map uses ledgr_ind_ttr('SMA', input='close', id='fast',
n=5L), and id='slow', n=10L. New recipes read the flat `ctx$fast` and
`ctx$slow` alias columns.
Scoring opens at data start except historical_late (session 30). Dense
history starts at scoring start; fact-bearing history starts at data start
(contracts#contract-execution-window-start). Usable scores hold during
warmup, except the unchanged historical body's exact first-state behavior.
Unknown prior usable state is never a transition in the new recipe.

The cost input is retyped from A0 fixtures.R:12-51, no imported helper:
AAA opens 100,101,103,102,104,107,106,108; closes
100,102,103,102,105,107,106,108; BBB opens 50,51,50,49,48,50,52,51;
closes 50,51,50,49,48,50,52,51. Original highs/lows/volumes retained.
Its dates are Jan 1-8, 2020 at 00:00 UTC. Full named targets hold outside
specified days. open_end parameters: aaa_qty=1, aaa_partial_qty=1, bbb_qty=0,
close_day5=FALSE, last_bar_qty=3; a fresh target function expresses this case.

## Native surfaces and exact comparison

Read-only DBI extraction of native runs, ledger_events, strategy_state,
equity_curve, run_diagnostics and run_completion; public ledgr_results fills
and trades; public ledgr_state_reconstruct positions, cash, pnl, equity.
Capture emitted warning classes/messages (including final-pulse no-fill).
Features are not a durable results table in this product: native config
retains definitions/aliases/strategy source and persisted crossover state
retains usability/above. No new decision recorder or accounting engine.

Native frames remain complete in native.rds (standard RDS v3), including
all IDs, paths, hashes, timestamps, NA masks, types and metadata. Round-trip
must satisfy identical, including attributes. Readable CSVs accompany frames;
CSV decimal formatting is never the exact oracle. Sources are git revisions
and native config/snapshot identities; no hash manifest or registry.

Economic projection: ledger event_seq, event_type, instrument_id, side, qty,
price, fee, meta_json plus recording pulse obtained by matching native fill
event_seq; fills/trades keep native recording_pulse_ts_utc, instrument_id,
event_seq (within-pulse order), side, qty, price, fee, realized_pnl, action;
equity keeps every economic column and pulse; reconstructed positions retain
every instrument and quantity, including zero; cash/pnl/equity and complete
strategy_state.state_json remain exact. Keys are checked unique: event_seq
for ledger/fills/trades, ts_utc for equity/state, instrument_id for final
positions. No rows are sorted away or aggregated. Existing reconstruction
owns opening positions and all quantity-changing corporate actions, covered
independently by the A0 dividend/risk references; this harness does not replay
economics. Terminal quantities are supplemented by the complete native ledger.

Representation projection also compares the complete frames in their native
sequence: execution stamps, diagnostics (diagnostic_seq), completion, warning
order/classes/messages, event IDs, every payload and schema attribute.
Only `runs.created_at_utc`, `run_provenance.created_at_utc` and the
`runs.config_json` locator fields `db_path` and `data.snapshot_db_path` are
omitted. All other config fields/hashes
and run metadata are checked. Originals remain stored. No numeric tolerance,
NA/Inf normalization, timestamp mapping or cross-arm equality is permitted.
Source/harness revision and loaded checkout path are provenance, not economic
payload. Stable run/snapshot IDs are chosen per fixture. Different host or
product representations fail for explicit disposition, not auto-normalization.

A0 references point to every CSV under records/dense_risk_features/run/,
records/dense_dividend_state/run/, records/failures/run_abort/ in the separate
v0_2_3_output_freeze harness; reference CSV records exact file names and row
counts. The new checker reads those files, never executes/imports A0.
Cut 4 intentionally superseded the executable A0 comparison after this
protocol was first accepted: its pulse-seed rule changes 52 original files,
and its accepted successor also excludes the walk-forward wall clock. The
three reference controls still point at the immutable original A0 tables.
Implementer and reviewer independently run Cut 4's whole A0 successor
record.R and compare.R on the current pinned checkout, with all output and
the result CSV in fresh scratch. The original A0 check.R is also run once to
show that its failure population is the accepted successor population, not
used as a pass. No A0 file, fixture, canonicalization or frozen byte changes.

## File plan and stop signals

| Fresh R file | Responsibility | Estimated lines |
| --- | --- | ---: |
| recipes.R | Seven fixtures, historical body, public maps and fact inputs | 210 |
| native.R | Native extraction, projections, exact diff, readable output | 310 |
| record.R | Public recorder CLI and orchestration | 100 |
| check.R | Scratch rerun, scope guard, A0 pointers and exact diff | 100 |
| gut.R | Six real native/rule corruptions, control and named failures | 100 |
| Later timing.R / timing_check.R | Workstream 3 runner/checker/guts (not built here) | 400 |
| **Total planned** | All helpers/children counted; no line packing | **1220** |

Maximum 1500 R lines across the fresh harness; ten total detectors (six here,
four timing later). Stop at budget breach, unavailable required native data,
vacuous required action, unexplained difference or a third correction round.
Run the smallest public recorder before freezing any expected output. Commit
candidate records naming the reviewer, then check into scratch and gut before
independent Type 1 acceptance of that immutable freeze. A failure never writes
new expected files. Workstream 3 and product deletion remain unstarted.

## Legacy commands and consumer inventory

| Maintained surface | Current consumer | Later disposition owner |
| --- | --- | --- |
| peer_benchmark.R --preset smoke/record; --engine-set; --compiled-accounting-model | peer_benchmark/README.md; dev/bench/README.md; benchmark_methodology.qmd/.md | Final WS3 replacement cut maps useful comparisons/clocks, then redirects commands |
| peer_benchmark/run_record.ps1 | README commands, Python peer provisioning README links | Final WS3 replacement cut supplies fresh provisioning/driver before retirement |
| peer_benchmark.qmd and rendered peer_benchmark.md | Explicit render command and historical reports | Full-suite Quarto artifact cut replaces active renderer; preserves old reports |
| old driver private handler constructor | Accepted WS1 LDG-3130 migration | WS1 maintains consumer until replacement, no change here |
| dev/bench/v0_2_3_output_freeze/check.R and gut.R | WS1/C1 regression | Remains independent; never deprecated with the peer driver |

Historical stage_o/workstream8 launchers, real-data overnight scripts,
notes/archive reports and prerequisite spikes remain attributed evidence.
No hosted workflow currently calls the old peer driver. Final retirement
must review these callers and the active documentation, not delete by name.

## C1 handoff (not runtime exemptions)

WS4 must decide each implied-calendar/execution-stamp/diagnostic/history
change before accepting oracle differences; retain the two historical arms
and their first divergence. M8b owns final-bar no-fill disclosure. This cut
accepts no changed meaning and does not implement those decisions.
