# Per-Pulse Durable Records: Decision Synthesis

- Mode: Decision synthesis, RFC cycle stage 7.
- Author: Codex; date: 2026-11-03.
- Status: proposed, provisional pending maintainer acceptance of the drafted
  brief and this synthesis together (`../rfc_cycle.md#briefs`), then stage 8
  final review by a different session. No implementation is claimed.
- Baseline: `release/v0.2.3`, `04fac1bfff9055c440d09c0d98b6e6da652303b8`.
  Code citations resolve at this commit.
- Inputs, in order: [historical v1](rfc_per_pulse_durable_records_v0_2_3_seed.md),
  [Type 2 response](rfc_per_pulse_durable_records_v0_2_3_response.md),
  [response review](rfc_per_pulse_durable_records_v0_2_3_response_review.md),
  [v2](rfc_per_pulse_durable_records_v0_2_3_seed_v2.md).
- Scope: this synthesis only. Existing working-tree changes are untouched.

## 1. Disposition And Authority

**ADOPT WITH CORRECTIONS:** remove pulse-level resume and compress physical
diagnostic storage while preserving the entire logical trace. Reject literal
"store only the quantity difference": irreducible diagnostic facts must survive
even when requested and achieved positions are equal. Store differences from an
exact reconstruction rule, including row-presence evidence, not just differences
between target and outcome. A row may disappear physically only if its presence,
every field and its sequence position can be recovered without user code.

The response review correctly restores two controlling decisions that v1 and my
response missed: [asset-availability synthesis Section 9.4](rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md#94-explainability-surfaces)
(`:717`) requires reopened explanations without strategy execution;
[history-wave E9](rfc_history_wave_v0_2_2_decisions.md) (`:468`) preserves the full
logical trace and permits physical compression only with exact reconstruction.
V2's change from replay to decoding honors those decisions. Its proposed economic
difference predicate alone does not establish E9's prerequisite.

Upon acceptance, Sections 2-7 bind the pending v0.2.3 implementation scope.
Current `contracts.md` continues to describe shipped behavior until implemented.
The physical full-row requirement
(`inst/design/ledgr_v0_2_0_0_spec_packet/v0_2_0_0_spec.md:431`) is
superseded for that pending scope; its explanation guarantee survives.
Keep `contract-verification-release-gates` (`contracts.md:3370`): exact physical
compression satisfies "never ... weakening the trace"; do not replace that
protection with a weaker evidence obligation.

## 2. Logical Diagnostics Are Unchanged (D1)

**Q1: full reconstructed trace by default**, through `ledgr_results(bt,
"diagnostics")` and the same `tibble::as_tibble()` result path. No argument,
retention tier, public sparse alternative or new explanation API is introduced.
Point and history-mode `ledgr_run_explain()` preserve their current rows,
defaults and refusal behavior (`R/availability-results.R:722`, `:730`, `:755`).
Do not fabricate a decision for a scheduled skip, an off-axis ID or an unprocessed
pulse. A legitimately encoded decision counts as retained evidence; missing or
invalid encoding is an error, never permission to infer arbitrary intent.

Equality includes column order/types, typed missing values, exact numeric values,
reason ordering, canonical `detail_json` bytes, timestamps, event associations,
row order and `diagnostic_seq`. Preserve the current sizing-reason empty-to-NA
projection (`R/availability-results.R:44`). The durable handler currently
renumbers written rows contiguously (`R/output-handler.R:645`); merely copying
the memory sink's sparse numbering will not preserve durable sequence numbers.

Reads use only current-format stored evidence, sealed snapshot facts and
identity-bound package reconstruction rules. They execute no strategy, custom
indicator, risk or cost callback, and do not evaluate recovered source. Reads
write no tables, projections, metadata or persistent caches. Filtered explanation
reads decode only their necessary dependency prefix/window; they must not expand
the full run's instrument-by-pulse trace first. No second execution engine or
execution-mode branch is authorized.

## 3. What Must Survive Compression (D2)

The writer selects an exact implicit form or explicit residual evidence from the
canonical typed carriers, before diagnostic row expansion, validation/JSON and
publication. Keep economic validation, stop handling and strategy-state updates.
The current late selection is `R/fold-engine.R:277`; expansion happens earlier
at `R/fold-carrier.R:795` and `:842`. Read-side decoding is a projection of
recorded evidence, not another planner or a re-evaluation of fill eligibility.

An implicit decision means the writer certified exact equality of original
pre/post-risk intent to the recorded outcome and certified all other implicit
fields. Absence alone is not a hold assertion outside that valid encoding.
Sub-tolerance target differences are still evidence: the actionability threshold
at `R/fold-engine.R:1071` must not become a lossy compression threshold.
Preserve explicit evidence for risk changes, restrictions, unfilled/repeated
requests, final-pulse requests, unavailable sizing, intent notes, informational
execution reasons, valuation/lifetime transitions, stop/error rows and any field
not covered by a proved reconstruction rule. No quiet-pulse speed claim is a
license to discard a field. Non-reconstructible rows remain explicit in the one
current-format codec; this is not a legacy-reader fallback or optional mode.

**Exact sizing is irreducible too.** P2 emits sizing evidence whenever a validated
helper instruction exists, including an integer instruction that changes nothing
(`R/fold-engine.R:889`, `:896`). Store its pulse/ID presence and all values not
exactly derivable. Preserve exact-zero/liquidation classifications and raw versus
helper/no-instruction distinctions. A run summary cannot replace that evidence.

Execution probe on this baseline: six constant-price pulses, one AAA holding of
50 shares, USD 500 cash, zero costs. A supported sequential Tier 2 strategy uses
ambient RNG only to choose whether to return an exact 50-share sizing helper or
the same raw holding. With caller seeds 14 and 47 and execution seed NULL:

| Compared output | Result |
| --- | --- |
| Stored configuration hash; ledger; equity; complete D8 summary | Each identical |
| Raw-sizing notice | Same first-pulse row |
| Exact sizing instruction, 50 requested / 50 rounded | Pulse two versus pulse three |
| Full diagnostics, including downstream sequence positions | Different |

Thus even all of v2's proposed compact summaries plus identical economics and
configuration cannot identify this row's timestamp. This is permitted ordinary
sequential Tier 2 behavior (`contract-strategy-reproducibility`,
`contracts.md:2100`), not a replay-certification claim. Source/options inspection
is unnecessary: the actual helper evidence must be encoded when produced.
R 4.6.1, DuckDB 2.0.0, collapse 2.1.8, Windows, source loaded without compiling;
the reproducer is below. No codec prototype or performance ranking was run.

A successful unchanged reconciliation may be implicit, but its exact tuple and
row existence must decode identically. P5 records three different exposure sums,
virtual and recorded cash, and `cash_before = final_cash - sum(fill_cash_delta)`
(`R/fold-engine.R:1457`). Preserve that arithmetic/order and floating-point
results; algebraic equivalence is insufficient. If a tuple is not exactly
derivable, keep its typed residual. Its checks always execute
(`R/fold-engine.R:1159`, `:1444`); failed reconciliation remains a stop.

## 4. Clean Trades, Timing And Scheduled Skips (D3)

**Q2: a different execution price with the requested quantity is not by itself a
diagnostic residual.** Actual price, fees and cash effects remain authoritative
ledger economics. An otherwise reconstructible clean trade may omit decision
and execution rows physically. This does not discard informational flags or
promise that quantity equality makes every field reconstructible.

A decision at t and its next-open outcome are available in the same canonical
fold step (`R/fold-engine.R:619`, `:1204`, `:1271`); retention selection may use
that outcome only after strategy/risk decisions. Never expose the private next
bar to P2 or change fill timing. A decision row's before/after position is the
decision-time holding, whereas the execution row's after position is its outcome
(`R/fold-engine.R:960`, `:1219`). Preserve that distinction.

Break the circular association dependency before omitting clean-fill rows.
Today's fills reader queries execution diagnostics (`R/execution-timing.R:224`);
those diagnostics cannot in turn be rebuilt by calling that reader.
Derive the decision/event association from authoritative event sequence and the
original configured opportunity calendar when unique; otherwise retain the
association explicitly. Do not guess or restamp events. Distinguish decision time,
execution time and the public `recording_pulse_ts_utc`, which is mapped to the
execution session's close (`R/execution-timing.R:189`, `:201`).
Use source economic events, not duplicated CLOSE/OPEN fill legs, for decoding.
Opening lots, P1 settlements/dispositions, pre-decision holdings, carry-window
final execution and INCOMPLETE prefixes must retain their current ownership.

**Q3: keep one physical scheduled-skip disclosure row per skipped pulse in this
cut.** Logical rows remain exactly today's `decision/skipped/scheduled_skip`,
empty ID and `{}`; keep accompanying stale/frozen valuation evidence.
A count alone does not replace them. This selects v2's existing Section 6 rule
and `contract-execution-fold-core` (`contracts.md:147`), avoiding another codec
variant for little record volume. Scheduled skips never become strategy holds.

## 5. Summaries, Consumers And Resume Retirement (D4-D5)

Persist the compact D8 and decision-count summaries v2 proposes, computed from
the same canonical instructions and invocation domain as today. Preserve all
values, currency/clock labels, missing denominators, overlapping evidenced and
unavailable counts, minimum/last coverage and final exposure. Preserve the
current reduction results (`R/sizing-evidence.R:139`, `:169`, `:187`); an
incremental sum is not automatically bit-identical to the existing grouped sum.
Summary evidence accelerates readers; it does not authorize loss of logical
sizing rows. SQL consumers must use the logical decoder or equivalent exact
summary evidence, never assume sparse physical rows are the full trace.

Consumers include point/history explanations, D8, valuation counts/exposure,
batched assumption flags (`R/valuation-summary.R:636`), completion validation
(`R/run-finalize.R:129`), corporate-action reporting bounds
(`R/corporate-action-results.R:159`), fill associations, sweep/walk-forward
completion and promotion. Candidates preserve their existing compact retained
evidence, numbering and metrics (`R/output-handler.R:22`, `:360`); they do not
acquire a full trace or D8 coverage claim. Retention capability changes storage
work only, through the common handler and fold.

Remove the `strategy_state` cursor table, intermediate durable checkpoints,
restore reader and `ledgr.interrupt` option. Keep declared in-memory state,
axis/default/patch/reset rules and walk-forward window resets
(`R/fold-engine.R:1495`; `R/strategy-state.R:285`).
Real interrupts still propagate, roll back the fold and leave FAILED.
Do not remove a still-used buffer-flush control merely because it says
`checkpoint_every`; no pulse-durability promise is implied by a flush.

Keep completion-based publication recovery without strategy execution
(`R/backtest-runner.R:513`, `:539`, `:757`).
For nonterminal runs without valid committed terminal evidence, verify identity
and snapshot trust before atomically clearing derived attempt output and
restarting at pulse one. Preserve run identity, provenance and tags; post opening
lots once. Invalid terminal evidence refuses before deletion. Clear old error
diagnostics, summaries, encoding coverage and derived projections together so
attempts cannot mix. Fold rollback cannot leave decodable fictitious decisions.
Completion/stop evidence must distinguish which stages actually completed;
unprocessed requested pulses never acquire rows by default decoding.

DONE/INCOMPLETE reruns remain idempotent; walk-forward skips terminal test runs.
Keep today's terminal validation boundaries: DONE has an identity-checked early
return (`R/run-registration.R:115`; `R/backtest-runner.R:396`); INCOMPLETE and
publication recovery validate completion. Do not claim DONE already traverses
those checks or add unrelated DONE lifecycle changes here.
Remove only resume-specific ambient-RNG refusal and restart-counter continuation;
keep pulse-seed v2, caller RNG restoration and parallel restrictions unchanged.
There is no new RNG replay certification.

## 6. Q4: Required Proof And Placement (D6)

**The private registered Sharadar reference is mandatory**, alongside portable
public/synthetic evidence. It exercises the scale and read boundary that caused
this cycle; it is not a substitute for inspectable public oracles.
Use existing registered input identities and the shared `dev/bench/timing/`
harness. Record the pre-change canonical R full trace before deleting its writer;
compare outputs externally, not through an old-format runtime reader.

Mandatory proof families are: (1) quiet and fill-heavy runs; (2) raw, mixed and
helper sizing, including the unchanged-integer witness above, guard/rounding,
zero/liquidation and unavailability; (3) declared sessions with restrictions,
stale/frozen marks, terminal/lifetime effects and empty axes; (4) due/skipped
schedules; (5) opening/carried lots, corporate actions and continued final fills;
(6) stop-phase INCOMPLETE prefixes, rollback, restart and publication recovery;
(7) the registered private reference. Existing registered tests/oracles remain
unchanged except for separately justified removal of retired resume semantics.

Cut-entry gate: a field-by-field derivation/presence/order map for every logical
row kind, with each non-derivable item assigned explicit residual evidence, and
frozen baseline trace/explanation/summary/economic records.
Release/workstream gate: exact full and filtered trace, point/history explanation,
summary, sequence and economic parity on these families, including close/reopen;
no-callback/no-write reads; current-format refusal; no-lookahead and interrupted
publication witnesses. Corrupt residual/coverage/association evidence must refuse,
not silently decode a hold. Missing private evidence leaves that gate open and
requires explicit maintainer disposition; it is never reported as a pass.

Measure quiet/fill-heavy durable and sweep clocks, stored rows/bytes, explanation
latency and peak memory, full-trace read peak, and decoding/summary costs.
Retain the existing paired history memory gate where triggered. The seed's "few
microseconds" comparison cost and presumed total savings are hypotheses, not
accepted bounds; the implementing cut establishes attribution and budgets.

Land as a semantic workstream before or with WS7/WS8; if necessary, make a
prerequisite cut. WS14a explicitly freezes behavior and tests
(`inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md:567`).
One current store version/fingerprint must cover dropped state storage, codec
rules, residual/association data and summaries, coordinated with WS7/WS8's format
change. Older/unmarked/mismatched stores refuse `ledgr_store_rebuild_required`;
no migration, compatibility argument, old reader or missing-marker fallback.
Economic/snapshot/run identity rules are unchanged; record any unavoidable
identity impact explicitly at cut. Implementation remains ticket-owned.

## 7. Decisions Rejected And Record Routing

| Rejected direction | Reason / replacement |
| --- | --- |
| V1 strategy replay; response F3-F5/F9 replay safeguards | Violates Section 9.4 and this brief. Decode original evidence; no dependency capture, trust opt-in, replay API or RNG certification is needed. |
| Response F4 run-level explanation hash | A digest cannot reconstruct a missing sizing fact; preserve irreducible facts instead. |
| V2 outcome-only predicate / summaries replacing exact sizing rows | Counterexample in Section 3; summaries lose instruction placement and sequence. |
| Sparse public diagnostics, changed sequence numbers, full-trace opt-in | Contradict Q1 and unchanged logical answers. One current physical representation. |
| Count-only scheduled skips | Q3 preserves their rows and distinction from an invoked hold. |
| Broadly replacing the non-weakening release clause | E9's existing safeguard is the acceptance criterion, not an obstacle. |
| Cursor retention for future live execution or a new progress/checkpoint split | Sealed research runs restart; live extension has different requirements. |
| Richer factor/rank/weight recorder | Separate research scope; exact current diagnostics do not imply a decision graph. |

**Horizon dispositions on acceptance** (recorded here; `horizon.md` is not edited):
the [2026-11-01 progress/state split](../horizon.md#2026-11-01-execution-split-progress-and-typed-strategy-state)
is superseded for sealed research runs. Close that proposed split with this reason;
do not build a replacement durable progress carrier. The strategy-authoring
synthesis Section 7 (`rfc_strategy_authoring_api_v0_2_3_synthesis.md:515`)
state-storage optimization obligation remains
conditional for a measured runtime-state workload; it is not discharged by
removing cursors and does not mandate this rejected split.
The [2026-11-03 explanation showcase](../horizon.md#2026-11-03-ux-showcase-exact-decision-explanations)
stays non-binding, with its existing executed-public-data scope and dependency on
settled storage plus measured explanation read-cost repair. Route it to the
documentation owner when scheduled; this synthesis promises neither its delivery
nor a read-latency result. The 2026-10-10 factor/decision-evidence entry stays parked.

**Open Questions Promoted To Spec-Cut:** physical typed layout, exact decoder
derivations/indexes/chunk sizes, summary reduction method and coordinated schema
number; all constrained by D1-D6. Q1-Q4 are settled; no product choice is escalated.
**Future Obligations Recorded:** none newly unconditional. Preserve the existing
conditional state-storage and richer-recording RFC triggers; do not convert
speculation about replay/debugging/live trading into an implementation duty.
After acceptance/final review, the record owner updates pipeline/decision/horizon
links and assigns proof obligations in `tickets.yml`. Only this file is written now.

## Reproducer For The New Sizing Witness

Run on stdin with `C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe -`.
Disposable stores only; this executes the existing package, not a codec prototype.

```r
pkgload::load_all("C:/Users/maxth/Documents/GitHub/ledgr",quiet=TRUE,compile=FALSE)
RNGkind("Mersenne-Twister","Inversion","Rejection")
local({
  ts<-as.POSIXct("2020-01-01",tz="UTC")+86400*0:5
  bars<-data.frame(ts_utc=ts,instrument_id="AAA",open=10,high=10,low=10,close=10,volume=1000)
  s<-ledgr_snapshot_from_df(bars,instruments_df=data.frame(instrument_id="AAA",currency="USD"))
  on.exit(ledgr_snapshot_close(s))
  f<-function(ctx,params) {
    if(ctx$ts_utc!="2020-01-01T00:00:00Z" && runif(1)<.5)
      ledgr_target_rebalance(ctx,weights=c(AAA=.5),capital_base="total_equity")
    else ctx$position
  }
  e<-ledgr_experiment(s,f,opening=ledgr_opening(cash=500,positions=c(AAA=50),
    cost_basis=c(AAA=10)),cost_model=ledgr_cost_zero())
  set.seed(14);a<-ledgr_run(e,run_id="sizing2",seed=NULL)
  set.seed(47);b<-ledgr_run(e,run_id="sizing3",seed=NULL)
  on.exit({close(a);close(b)},add=TRUE)
  norm<-function(x) {x<-as.data.frame(x);x$run_id<-NULL;x$event_id<-NULL;x}
  print(ledgr_strategy_preflight(f)$tier)
  print(identical(norm(ledgr_results(a,"ledger")),norm(ledgr_results(b,"ledger"))))
  print(identical(norm(ledgr_results(a,"equity")),norm(ledgr_results(b,"equity"))))
  print(identical(ledgr:::ledgr_run_sizing_summary(a),ledgr:::ledgr_run_sizing_summary(b)))
  for(bt in list(a,b)) {
    d<-ledgr_results(bt,"diagnostics")
    print(d[d$stage=="sizing",c("ts_utc","instrument_id","reason_code","target","quantity")])
  }
  o<-ledgr:::ledgr_run_store_open(s$db_path)
  h<-DBI::dbGetQuery(o$con,"SELECT config_hash FROM runs WHERE run_id IN ('sizing2','sizing3')")
  ledgr:::ledgr_run_store_close(o);print(length(unique(h$config_hash))==1L)
})
```
