# Per-Pulse Durable Records: Type 2 Response

- Mode: Type 2, RFC cycle stage 3; Codex; 2026-11-03.
- Status: provisional. Claude drafted the brief; under
  `rfc_cycle.md#briefs`, the maintainer must reread brief and response together
  and accept the framing. This response authorizes no implementation.
- Reviewed: `release/v0.2.3`, `fbc02ba8a1611088c3b39741d229239c5526baa4`.
  Citations below resolve at that commit, rather than the seed's older baseline.
- Scope: response only; seed, product, tests and ticket authority unchanged.

**Disposition: REVISE before synthesis.** Retire pulse continuation and prefer exception diagnostics, but replace "keep only what cannot be recomputed cheaply"
with "keep authoritative economics, terminal evidence, material exceptions and
cheap summary evidence; regenerate detailed context only with verified inputs."
Cheap recomputation is neither a sufficient retention criterion nor a proof of
historical intent. The seed identifies real waste, but couples its removal to an
explanation guarantee that its proposed checks cannot establish.

Execution evidence (functional probes, not a performance ranking):

| Probe | Observed |
| --- | --- |
| Three IDs, six flat pulses | 18 decisions, six reconciliations, one sizing notice; six cursors |
| Strategy error at call four | FAILED; zero cursors, one error diagnostic; retry calls strategy six times |
| Soft stop at call three | RUNNING; three cursors; retry calls strategy three times |
| Reopen DONE | Zero strategy calls |
| Inject failure at finalizer entry after fold commit | FAILED with six cursors; retry reaches DONE with zero calls |
| Same source/configuration/seed, different final-pulse option input | Identical stored config hashes, ledger and equity; targets differ (1 versus 2) |
| Tier 1 strategy with custom feature | Strategy recovers; stored-config feature reconstruction refuses `ledgr_invalid_config` |
| Sizing at 50 and 1.1 shares | Coverage 0.9980431; keeping only changed rounding gives 0.9090909 |
| Shorten a four-pulse run to pulse three | Pulse-three outcome changes from filled to no_fill |
| Direct seeded `runif()`, two fresh executions | Tier 2; identical ledger and equity |

R 4.6.1, DuckDB 2.0.0, collapse 2.1.8, Windows; `pkgload::load_all(..., compile = FALSE)` (DESCRIPTION: 0.2.2).
The final-pulse option probe intentionally violates deterministic-input discipline:
it demonstrates a certification limitation, not a failure of deterministic strategies.
No replacement engine, storage prototype, timing experiment or full regression suite was run. The seed's microsecond savings and "seconds" explanation latency
remain unverified here. The runnable evidence is embedded below because this brief
permits only this response file; no separate spike artifacts were created.

## Numbered findings

1. **The product framing supports subtraction, but not the proposed universal rule.**
   Fills and equity are themselves recomputable under the seed's assumptions.
   Keeping them is a deliberate product choice: authoritative, immediately readable
   research evidence. Apply that same reasoning to inexpensive summary evidence.
   "No users" removes compatibility obligations, not accepted research semantics
   or the maintainer's need to inspect an old run without its execution environment
   (`rfc_cycle.md#pre-cran-no-users-framing`). Full trace has forensic value when
   replay dependencies disappear; option 3 is therefore not logically redundant.
   I still recommend a single sparse durable default, without a full-trace option
   in this cut, provided its reduced historical explanation availability is explicit.
2. **Remove pulse resume; retain completion-based publication recovery (Q2, Q5).**
   The seed combines two distinct mechanisms. Cursor continuation reads
   `strategy_state` and trims tails (`R/run-resume.R:28`, `:71`);
   completion-based recovery already bypasses that reader
   (`R/backtest-runner.R:513`, `:539`, `:560`, `:757`).
   The latter needs no strategy checkpoint and repairs a committed fold whose
   equity/status publication failed. The injected failure exercised this path.
   Keep it; restart from pulse one only when no valid committed terminal evidence
   exists. DONE currently shortcuts these checks (`R/backtest-runner.R:396`);
   state the intended terminal gate explicitly. Malformed evidence must refuse
   before deletion. Verify configuration,
   snapshot and strategy identity before any restart cleanup; atomically clear
   derived attempt rows, reset counters, and post opening lots exactly once.
   Keep run identity/provenance and tags. A failed restart must not expose mixed
   attempts. Preserve in-memory declared strategy state and axis/default/reset
   semantics (`R/strategy-state.R:285`, `:311`; `R/fold-engine.R:1495`).
   Remove the `ledgr.interrupt` option, rather than introduce another cancellation
   control. Actual R interrupts continue to propagate, roll back the fold and
   record FAILED (`R/output-handler.R:107`; `R/fold-engine.R:1578`).
3. **Tier 1 strategy recovery is not store-only experiment recovery.**
   The current API is `ledgr_run_strategy(trust = TRUE)`, not the seed's
   `ledgr_extract_strategy()` (`R/strategy-extract.R:157`, `:225`).
   Indicator objects are explicitly excluded from stored configuration
   (`R/run-registration.R:7`); reconstruction may require the experiment's
   custom indicator or session registry (`R/backtest-runner.R:1099`, `:1189`).
   The custom-feature probe recovered a Tier 1 function but could not rebuild its
   feature runtime. Define replay eligibility for the whole execution dependency
   set: indicators, parameters, histories, schedule, policies, opening/carried lots
   and entitlements, R/ledgr/dependency versions, and strategy closure inputs.
   Require the original experiment whenever any dependency is unavailable from the
   store, regardless of strategy tier. Match fingerprints and refuse discrepancies.
   Version metadata exists (`R/strategy-extract.R:210`); extraction does not enforce
   runtime parity. Do not add general environment capture to rescue arbitrary runs.
4. **Economic equality cannot certify an exact historical explanation.**
   P2 records pre-risk targets separately from post-risk targets; final decisions,
   rejected orders, rounding and state/intent notes can change without a fill
   (`R/fold-engine.R:863`, `:953`, `:1019`, `:1185`).
   The option-input probe passed source/configuration and economic comparisons
   while producing different final targets. Static preflight is expressly not
   proof of reproducibility (`contracts.md#contract-strategy-reproducibility`).
   Resolve this before promising "exact": my recommendation is a single versioned
   run-level commitment to the canonical explanation-relevant stream, produced
   from typed carriers during original execution and checked on replay, alongside
   complete economic comparison. It must cover axis/time, intent, sizing, risk
   and outcome evidence; persist no per-pulse hash table or checkpoint.
   A single whole-run commitment requires completing replay to verify it; a partial
   rerun cannot claim this verification. Measure its added cost. If the maintainer
   rejects that evidence, explicitly narrow the replay claim to recomputation
   under supplied deterministic inputs; never label economic agreement alone as
   verification of original intent. An intent matrix also omits reasons and state.
5. **Replay must preserve the original execution calendar and remain explicit.**
   Reuse the canonical preparation and fold with a read-only input connection and
   a retaining sink; never call the durable runner to implement an explanation.
   Preserve original run ID (`ctx$run_id`, `R/fold-engine.R:771`), full universe,
   scoring/calendar origin, warmup history, schedule and continuation opening.
   Filter retained trace to the requested window; portfolio decisions still need
   the whole preceding book. A shortened public run/window is not replay: the
   probe lost its next-open fill. P1 values equity before P4's next-open execution
   (`R/fold-engine.R:616`, `:636`, `:1271`), so compare economic prefixes by
   recording pulse, including its later execution instant, not `event_ts <= t`.
   Compare every economic event type, fees, lots/cash/positions and equity, plus
   completion/stop evidence, using canonical exact values; no tolerance that
   admits changed economics. Refuse beyond an INCOMPLETE run's accepted prefix.
   Keep ordinary diagnostics, summary, comparison and printing free of callbacks.
   An explanation requiring replay must explicitly opt into execution/trusted
   recovery; a hash proves text identity, not safety
   (`contracts.md#contract-result-read-surfaces`; `R/strategy-extract.R:80`).
   Read retained exception evidence without rerunning when it suffices.
6. **Option 1 needs compact D8 evidence, not rounding-only sizing (Q3, Q4).**
   `ledgr_run_sizing_summary()` reads both all sizing rows and instrument decision
   times (`R/sizing-evidence.R:130`, `:139`, `:165`, `:181`).
   An exact integer instruction contributes to its denominator and counts even
   when position and target are unchanged. The executed coverage counterexample
   rules out merely filtering rows whose pre-floor and rounded quantities differ.
   Accumulate the existing pooled numerator/denominator, minimum/last coverage,
   counts and value totals in typed state and persist their compact run summary.
   Preserve no-instruction versus unavailable evidence, mixed decisions, zero
   denominators and final actual exposure. Ordinary summaries must not replay.
   Keep individual sizing exceptions for guard changes, rounding changes,
   rounded-to-zero addition/liquidation and unavailability; retain explicit
   liquidation/intent reasons when material. An unchanged integer instruction
   can disappear from the trace only after it contributes to summary evidence.
   Option 2's matrix does not recover pre-floor sizing or those classifications.
7. **The exception vocabulary and consumer inventory need explicit closure (Q1, Q4).**
   No additional product reader of the durable `strategy_state` table was found:
   the resume cursor/restore readers are `R/run-resume.R:31` and
   `R/strategy-state.R:432`; runtime state is a separate surviving concept.
   Add to the trace inventory: history-mode explanations
   (`R/availability-results.R:730`), fill recording-pulse association
   (`R/execution-timing.R:224`), corporate-action reporting bounds
   (`R/corporate-action-results.R:159`), and the decision-row existence gate
   in batched assumption flags (`R/valuation-summary.R:636`, `:645`).
   Quiet-row removal must replace that gate with recorded completion/summary
   evidence; absence of a row cannot mean no decisions or missing provenance.
   Retain target requests differing from current holdings (including repeated
   unfilled requests), risk transformations even if they restore a hold,
   restrictions, rejected/no-fill outcomes, fill associations, sizing exceptions,
   supplied intent reasons, stop/error evidence and terminal/valuation transitions.
   Preserve every held stale/frozen instrument-session observation, including
   scheduled skips, unless equivalent summary evidence replaces it: readers count
   occurrences and exposure, not just entry/exit (`R/valuation-summary.R:105`).
   Keep scheduled-skip disclosure distinct from a strategy hold; schedule counts
   already have provenance/telemetry authority (`R/backtest-runner.R:746`).
   A successful unchanged reconciliation is not an exception. Its checks must
   still run; failures remain stops (`R/fold-engine.R:1159`, `:1444`).
   Define "changed" against current normalized request/plan/outcome, not merely
   against the previous pulse's target or whether any fill occurred.
8. **Avoid unretained materialization without changing execution semantics.**
   Today every segment is expanded and validated before the sink filters it
   (`R/fold-carrier.R:795`, `:842`; `R/fold-engine.R:277`).
   Move retention selection before expansion, JSON and diagnostic validation.
   Do not skip target validation, sizing-evidence validation, reconciliation,
   state transitions or stop construction. Output detail selection belongs to
   the handler contract, not an execution-mode branch. The existing memory sink
   keeps valuation/terminal/final-pulse/stop rows (`R/output-handler.R:22`);
   replay needs richer retention through that same seam, not a second fold.
   Sequence numbers may become sparse/different; event association and ordering
   must remain stable, and any public diagnostic sequence change must be stated.
   Filtering after today's staging will save writes but miss much of the
   measured CPU cost. Sparse exceptions can still be dense on adverse workloads.
9. **Resume's RNG restriction is not the right replay criterion.**
   Restarting at pulse one restores a seeded sequential stream without restoring
   a midstream RNG state. The direct-`runif()` probe was economically identical
   on two seeded fresh executions; E pins seed/kind and storage preserves RNG
   (`R/fold-engine.R:1625`; `contracts.md#contract-strategy-reproducibility`).
   Do not automatically carry `ledgr_strategy_ambient_rng_resume` into replay.
   Permit seeded sequential draws only under a defined reproducible full-run
   environment and successful verification; refuse unseeded ambient RNG without
   its original state. Pulse-local seeded strategies keep their existing rule.
   This is a new certification contract, not blanket Tier 2 certification.
   Preserve caller RNG restoration and original absolute pulse positions,
   including scheduled skips. Parallel equivalence is a separate restriction.
10. **Land this as semantic work before/with WS7/WS8, not WS14a (Q6).**
    The macro plan's WS14a subtraction cut adds no behavior and freezes tests/oracles
    (`inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md:567`). This RFC changes
    public evidence, recovery and callback execution, so it cannot hide there.
    Accept the decisions before cutting WS7/WS8; give them a separately reviewed
    semantic workstream in that ordered cut, with sparse readers and replay
    available before retiring the full trace. If that makes the cut too large,
    use a prerequisite cut with explicit identity impact rather than defer the
    semantic choice to WS14a. Bump store version/fingerprint, rebuild and refuse
    old stores; no migration, old reader or fallback. Measure quiet and fill-heavy
    durable/sweep paths, retained bytes, replay latency and peak memory under the
    shared timing harness, including verification and commitment cost.
    Registered oracle changes need the accepted semantic reason in ticket
    evidence; economics/no-lookahead oracles stay intact. Include changed-input
    refusal, economically invisible intent drift, interruption/restart, terminal
    recovery, scheduled skips, carried openings, and store immutability witnesses.

Section 11 answers: **Q1** findings 6-7; **Q2** remove the soft-stop option, retain ordinary FAILED interrupts; **Q3** option 1 plus compact existing
summary evidence; **Q4** finding 7's vocabulary, no unchanged reconciliation,
no rounding-only sizing; **Q5** restart from pulse one, no checkpoint, complete
replay when needed to verify the whole-run commitment; **Q6** finding 10.

The seed's Section 8 list is incomplete. Synthesis must also address
`contract-execution-fold-core` and `contract-execution-fold-carrier` (state output,
diagnostic carriers/retention), `contract-availability-context-and-state`,
`contract-availability-affordability` (reason vocabulary),
`contract-result-read-surfaces` (history mode and explicit execution),
`contract-result-completion-and-valuation` and `contract-result-fills-and-sweep-restoration`
(association/summary consumers), and `contract-strategy-reproducibility` with
Strategy / Provenance And Recovery (whole-experiment eligibility and trust).
Update `contract-persistence-fold-evidence` and
`contract-persistence-completion-evidence` while preserving publication recovery.
Explicitly supersede the full-trace non-weakening clause in
`contract-verification-release-gates` (`contracts.md:3370`); update its resource
witness rather than silently declare it satisfied by a sparse result.
D8's shipped contract at `contracts.md:1815` and pending WS5/WS7 Join J need
reconciliation. Accepted text and test changes follow synthesis, not this review.

## Runnable reproduction

Run this block via `C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe -` on stdin.
It uses disposable stores; the finalizer mock is fault injection. Package files remain unchanged.

```r
local({
  pkgload::load_all("C:/Users/maxth/Documents/GitHub/ledgr", quiet=TRUE, compile=FALSE)
  ids <- c("AAA","BBB","CCC"); ts <- as.POSIXct("2020-01-01",tz="UTC")+86400*0:5
  bars <- expand.grid(instrument_id=ids,ts_utc=ts,KEEP.OUT.ATTRS=FALSE)
  bars$open <- bars$high <- bars$low <- bars$close <- 10; bars$volume <- 1000
  s <- ledgr_snapshot_from_df(bars,instruments_df=data.frame(instrument_id=ids,currency="USD"))
  on.exit(ledgr_snapshot_close(s),add=TRUE)
  prior <- options(ledgr.interrupt=FALSE); on.exit(options(prior),add=TRUE)
  q <- function(sql,id) {o <- ledgr:::ledgr_run_store_open(s$db_path)
    on.exit(ledgr:::ledgr_run_store_close(o)); DBI::dbGetQuery(o$con,sql,params=list(id))
  }
  exp <- function(f,features=list()) ledgr_experiment(s,f,features=features,opening=ledgr_opening(cash=1000),cost_model=ledgr_cost_zero())
  run <- function(e,id) ledgr_run(e,run_id=id,seed=7)
  count <- function(id) cat(id,q("SELECT status FROM runs WHERE run_id = ?",id)$status,
    q("SELECT COUNT(*) n FROM strategy_state WHERE run_id = ?",id)$n,
    q("SELECT COUNT(*) n FROM run_diagnostics WHERE run_id = ?",id)$n,"\n")
  b <- run(exp(function(ctx,params) ctx$position),"quiet"); count("quiet"); close(b)
  f <- function(ctx,params) {
    n <- getOption("probe.calls",0L)+1L; options(probe.calls=n)
    if(n==getOption("probe.fail",-1L)) stop("probe failure")
    if(n==getOption("probe.stop",-1L)) options(ledgr.interrupt=TRUE)
    ctx$position
  }
  e <- exp(f); options(probe.calls=0L,probe.fail=4L)
  print(class(tryCatch(run(e,"error"),error=identity))[1]); count("error")
  options(probe.calls=0L,probe.fail=-1L); b <- run(e,"error"); cat("retry",getOption("probe.calls"),"\n"); close(b)
  options(probe.calls=0L,probe.stop=3L); b <- run(e,"soft"); close(b); count("soft")
  options(probe.calls=0L,probe.stop=-1L,ledgr.interrupt=FALSE)
  b <- run(e,"soft"); close(b); cat("continue",getOption("probe.calls"),"\n")
  options(probe.calls=0L); b <- run(e,"soft"); close(b)
  cat("DONE",getOption("probe.calls"),"\n")
  bad <- testthat::with_mocked_bindings(tryCatch(run(e,"postfold"),error=identity),
    ledgr_run_finalize=function(...) stop("postfold"),.package="ledgr")
  count("postfold"); options(probe.calls=0L); b <- run(e,"postfold"); close(b)
  cat("recovery",getOption("probe.calls"),"\n")
  f <- function(ctx,params) {
    x <- ctx$flat()
    if(ctx$ts_utc=="2020-01-06T00:00:00Z") x[] <- getOption("probe.target",1)
    x
  }
  e <- exp(f); options(probe.target=1); a <- run(e,"intent1")
  options(probe.target=2); b <- run(e,"intent2")
  econ <- function(b,w) {x<-as.data.frame(ledgr_results(b,w));x$run_id<-NULL;x$event_id<-NULL;x}
  same <- function(a,b) c(identical(econ(a,"ledger"),econ(b,"ledger")),identical(econ(a,"equity"),econ(b,"equity")))
  print(ledgr_strategy_preflight(f)$tier)
  print(identical(q("SELECT config_hash FROM runs WHERE run_id = ?","intent1")$config_hash,
    q("SELECT config_hash FROM runs WHERE run_id = ?","intent2")$config_hash))
  print(same(a,b)); print(c(tail(ledgr_run_explain(a,"AAA")$target_before_risk,1),
    tail(ledgr_run_explain(b,"AAA")$target_before_risk,1))); close(a); close(b)
  f <- function(ctx,params) {x<-ctx$flat();x[]<-floor(runif(length(x),0,4));x}
  e <- exp(f); a <- run(e,"rng1"); b <- run(e,"rng2"); print(same(a,b)); close(a);close(b)
  f <- function(ctx,params) ledgr_target_rebalance(ctx,
    weights=c(AAA=.5,BBB=.011),capital_base="total_equity")
  b <- run(exp(f),"sizing"); d <- ledgr_results(b,"diagnostics")
  z <- d[d$stage=="sizing" & d$instrument_id!="",]; k <- z$target!=z$quantity
  print(c(ledgr:::ledgr_run_sizing_summary(b)$pooled_coverage,sum(z$quantity[k]*z$price[k])/sum(z$target[k]*z$price[k]))); close(b)
  f <- function(ctx,params) {x<-ctx$flat();if(ctx$ts_utc>="2020-01-05T00:00:00Z") x[]<-1;x}
  e <- exp(f); a <- run(e,"whole")
  w <- ledgr:::ledgr_experiment_window(e,ts[1],ts[5],opening_state_policy="flat_test_state")
  b <- ledgr:::ledgr_run_window(e,window=w,run_id="short",seed=7)
  print(c(ledgr_run_explain(a,"AAA",ts[5])$execution_outcome,
    ledgr_run_explain(b,"AAA",ts[5])$execution_outcome)); close(a);close(b)
  ind <- ledgr_indicator("probe_custom",function(window) tail(window$close,1),1L)
  f <- function(ctx,params) {x<-ctx$flat();x[ctx$probe_custom>0]<-1;x}
  b <- run(exp(f,list(ind)),"custom")
  print(ledgr_run_strategy(s,"custom",trust=TRUE)$reproducibility_level)
  cfg <- ledgr:::ledgr_json_read_config(q("SELECT config_json FROM runs WHERE run_id = ?","custom")$config_json)
  print(tryCatch(ledgr:::ledgr_feature_defs_from_config(cfg),error=conditionMessage))
  close(b)
})
```
