# Lean Fold Core: Type 2 Response

- Mode: Type 2, RFC cycle stage 3; Codex; 2026-11-03.
- Status: provisional under `rfc_cycle.md#briefs`: Claude drafted the brief;
  the maintainer must read brief and response together and accept its framing.
- Reviewed HEAD: `940015bfaee78c7ebd7003a38ed19c4973cd064a`,
  `release/v0.2.3`, with pre-existing dirty accounting, handler and test files.
  Source probes used that working tree; HEAD alone does not identify its R code.
- Concurrent work advanced HEAD to `200266020a45abc6cde581daaa6d6d4d14e9e658`.
  Cited fold, carrier, target-contract, spike and macro files have no committed
  diff between those heads. The probes are not a review of that accounting work.
- Citation shorthand: `spike/` = `dev/spikes/r_floor/`;
  `macro` = `inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md`;
  `WS15` and `carrier` = the accepted per-pulse durable-records and
  typed-fold-carrier syntheses in this RFC directory.

**Disposition: REVISE.** Prefer B's isolated development and atomic package switch,
but authorize only a bounded next probe before committing v0.2.3 to a complete
rewrite. Preserve accepted semantic ownership and reuse canonical services;
review progress in small workstreams. Do not make reaching the measured floor,
an unpriced deadline, or an indefinitely growing second core the release plan.
A remains viable: the evidence does not show that a coordinated in-place
representation rewrite cannot achieve the same result.

The spike is useful constructive evidence of avoidable R overhead on one
restricted workload. It does not establish a 100x removable cost in the current
production fold, or show that stage boundaries cause that cost.

## Executed Evidence And Limits

R 4.6.1, DuckDB 2.0.0, collapse 2.1.8, Windows; `pkgload::load_all(...,
compile = FALSE)`; the spike's existing fixture, floor and layer functions.
No package compilation, source edits, new implementation or timing gate was run.

| Probe | Observed |
| --- | --- |
| 3 x 40 and 10 x 300, all six stage-2 configurations | Fill-key, equity and cash comparisons TRUE |
| In-loop full and rebuilt diff trace, both shapes | Spike's projected trace comparison TRUE |
| Existing `same_bar_fill` gut, both shapes | Fill-key and equity comparisons FALSE |
| Mutate only a returned fill fee | Runner's fill-key comparison still TRUE |
| Mutate only `feature_identity_json` | Trace projection still identical |
| Reverse a complete named target vector | ledgr normalizer accepts/reorders; lean validation refuses at pulse one |

These rerun narrow parity and its negative control; they do not rerun the three
recorded large timings or certify the published `R_FLOOR_CHECK_OK` against its
original installed `0d6c0b11` build. No current matching installed build was
identified in the default libraries; the repository's `lib/` is an older
0.1.7.9 installation. The command block below reproduces these source probes.
Evidence stays in this response because the brief permits no other file edits.

## Numbered Findings

1. **The measured opportunity is real; the 100x architectural conclusion is not (Q1).**
   `spike/run.R:39` times snapshot construction, feature setup, registration,
   preparation, execution and durable publication through `r_floor_ledgr_run()`.
   The lean denominator times a fold over already prepared planes
   (`spike/run.R:47`, `:57`). Stage 2 reports rebuild and writing separately
   (`spike/run2.R:53`, `:60`, `:70`).
   For 20 x 23,400 the recorded diff loop is 0.68 s, rebuild 0.71 s and the
   simplified write 0.10 s (`evidence/timings_layers.csv`); 29 us/pulse does not
   buy that complete result boundary. The writer only creates generic fills/
   equity tables, not ledgr's store/provenance/completion transaction
   (`spike/layers.R:287`). The 84 ms small-run arm also omits result reads,
   whereas ledgr reads fills/equity (`spike/fixed_cost.R:23`, `:51`).
   Its "loop" profile bucket includes the whole envelope (`:40`).
   Reprice matched loop, warm verified-snapshot-to-result and cold boundaries,
   durable and memory separately, after WS7/WS8/WS15. Do not present these
   ratios as the benefit of a switch or as a mathematical lower bound.

2. **Stage structure versus subtraction is a false restriction on option A.**
   The expensive shapes are allocation, repeated preparation/validation and
   publication placement, not the existence of five named functions.
   Constructors call field/axis validators (`R/fold-carrier.R:197`, `:489`);
   the current decision stage assembles context/helper views
   (`R/fold-engine.R:770`, `:786`). That identifies candidates for change,
   not a requirement to abandon E/P1-P5. Macro WS14 already allows flat contexts,
   prebinding, stage fusion, invariant preparation and batching (`macro:774`).
   No A implementation was measured. Conversely, B can reproduce today's
   overhead if it reinstates the same representations to pass conformance.
   Favor B to study the whole data flow without temporary production adapters,
   not because it has proven exclusive access to a faster architecture.
   Review B incrementally; "no per-step risk" confuses no immediate deployment
   with no development, integration or late-discovery risk.

3. **The layers price useful subsets, not the named production guarantees.**
   `spike/layers.R:53` reuses one mutable environment, rebinds the strategy's
   enclosure and stubs `ledgr_strategy_result()` (`:57`); it calls params NULL.
   Its rich context adds a few fields, not the public cutoff-bound history,
   flat helpers, position facts, pulse seeds and typed state semantics in
   `R/fold-engine.R:761` and `:770`. Retained public views must remain frozen
   (carrier Section 3.1; optimization manual `:170`); sharing a mutable ctx is
   not a free replacement for that requirement.
   Fixed-basket availability is all-pass here, and its off-path implementation
   silently changes targets (`spike/layers.R:99`). Target validation rejects
   reordered names (`:96`), unlike `R/strategy-contracts.R:83`.
   Positions are assigned targets without FIFO accounting (`:119`), whereas
   canonical positions come from lots (`R/fold-engine.R:1392`).
   Reuse the existing R lot/cost/history services before pricing their overhead;
   do not develop another accounting kernel. All-pass eligibility, binary
   positions and abundant cash have hidden the interactions that could erase
   the speed advantage. Preserve invalid-input classes and failure precedence.

4. **The trace layer is not the accepted WS15 codec or its whole cost.**
   It retains only unmet requests (`spike/layers.R:73`, `:126`).
   Accepted WS15 Section 3 explicitly requires instruction presence and
   irreducible sizing/intent evidence even when target equals outcome.
   The fixture never exercises those records. The source also grows residuals
   with `c()` and retains a full-run trace/planes (`:128`, `:65`, `:183`);
   tiny residual counts do not prove bounded candidate or intraday memory.
   The accepted carrier requires bounded diagnostic staging
   (`R/fold-carrier.R:776`), and filtered explanations may not first expand the
   entire trace (WS15 Section 2). Price frequent exact sizing, rejected requests
   and filtered reads using the accepted publication/decoder boundary.
   Do not claim a layer satisfies WS15 merely because this raw-target fixture
   has only final-pulse residuals. No strategy execution on read is permitted.

5. **The current oracle comparison is deliberately narrower than public parity (Q4).**
   Fill keys sort away order and omit fees, action/lot fields and event association
   (`spike/run2.R:19`). Equity comparison checks only equity and cash (`:65`).
   Trace projection drops `run_id` and `feature_identity_json` and normalizes
   timestamps (`spike/layers.R:273`); my fee and identity mutations survived it.
   That is acceptable spike evidence if labelled, insufficient switch evidence.
   Compare full ordered ledger events, lots/realized/unrealized PnL, fees, all
   logical diagnostic columns and sequence positions, explanations/history,
   summaries, completion, seeds and identity. Include persistence/reopen and
   selection/promotion outputs. Exclude only explicitly variable clock metadata;
   no broad sorting, rounding or column stripping that hides semantic drift.
   Current R is the executable oracle; contracts remain normative. A known
   oracle bug must be independently dispositioned/fixed, not copied into B or
   "corrected" only in its expected output. Pin a clean accepted reference build,
   not a moving installed package. The source probes here used a dirty tree.

6. **Proof families need interaction and failure coverage before the switch.**
   WS15's seven families are a necessary minimum, not exhaustive coverage of a
   new engine. Add adversarial combinations, not one happy run per layer:
   reordered/changing/empty axes and held nonmembers; restricted decisions with
   permitted exits; stale/frozen valuations and terminal/corporate-action barriers;
   sells funding buys in stable-ID affordability order but decision-order
   publication; chained costs, rounding/dust, repeated carried opening lots,
   FIFO and compensated realized PnL; a continued final decision; scheduled skips
   with settlement; seeded and unseeded callbacks, caller RNG restoration and
   worker-count/promotion equivalence.
   Include late-known facts, pre-scoring feature/mark history and venue-open
   staleness clocks; a dense missing-bar mask does not exercise those rules.
   Exercise P1/P2/P3 stop boundaries, first-pulse stops, strategy exceptions,
   append/flush failures and post-fold publication recovery. E installs stops
   independently after each stage (`R/fold-engine.R:1879`, `:1911`, `:1934`);
   a successful array loop proves none of those transactional prefixes.
   Add retained-view alias, no-lookahead future-perturbation and conservation
   witnesses plus mutations now, while both implementations exist. Keep the
   post-switch test rebuild, but do not postpone independent correctness evidence
   until the old core has gone. Measure parent/worker peak memory before switching.

7. **Choose a bounded version of B under dev/, not a hidden package engine (Q2-Q3).**
   `dev/lean_core/` is appropriate: `.Rbuildignore:4` excludes dev from packages.
   Acceptance must explicitly permit this temporary experimental executor;
   location alone does not amend AGENTS.md. No imports, options, exported hooks,
   automatic fallback or worker dispatch into it from R/. Every installable
   switch revision has one core, with the old one removed when the new enters.
   Keep a reference build/artifact externally for comparisons, not an old reader
   or alternate production mode. Candidate stages stay in R; no compiled stages
   in this cycle.
   First answer one bounded question: can the real cutoff-bound strategy/context
   boundary run over changing axes with preserved ownership, materially lower
   matched cost and bounded memory? Reuse accounting; do not charter all eleven
   omitted families as "stage 3". Probe, runnable seam, failure-derived cases,
   runner/checker/gut, then disposition, under `spike_protocol.md:25`, `:34`.
   If that prerequisite fails, stop/recharter before authorizing a complete core.
   The seed is a proposal, not a spike charter.

8. **B's freedom stops at accepted ownership and failure contracts.**
   Carrier Sections 3.1-3.6 bind axes, exclusive buffers, P1-only substrate
   access, no execution packet in P2, lot-derived positions, ordered accounting
   and publication. The source separates P2 observation from P3 execution
   (`R/fold-engine.R:1884`, `:1917`). Flattening/fusing code may preserve those
   barriers; importing private next-bar data into a reused public ctx may not.
   Removing repeated validation requires a trusted producer boundary with dynamic
   callback properties still checked. The seed's AGENTS exception alone does not
   authorize replacing the carrier's construction rule with unvalidated packets.
   Name any superseded internal representation/owner clause in synthesis before
   the cut, while preserving its guarantee. Keep one common substrate/semantics;
   do not turn the all-pass spike into a fixed-basket execution-mode fork.
   Stable service seams, with their costs included, are how B avoids rebuilding
   both a runner and a second preparation/publication architecture.

9. **The broad ordering is sound, but two dependencies need correction (Q5).**
   Land WS7/WS8/WS15 and freeze their oracle first. Earlier experiments may
   proceed, but their evidence is provisional until rebased to that interface.
   Preserve separate workstream reviews and the two independent holistic WS14a
   reviews of the whole integrated path, including preparation/read/finalization.
   Do not replace them with a review of the bare dev loop.
   Replacing the subtraction cut with a core switch needs an explicit macro-plan
   amendment (`macro:675`), not reinterpretation. Inventory internal structural
   tests before promising "every test unchanged": helper/layout detectors may
   need separately justified mechanical remapping. Their fixtures, semantic
   oracles and mutation strength cannot change to conceal a product failure.
   A0 is presently under repair in the dirty WS23 successor record, not a usable
   inherited PASS; accept its equivalence/exceptions before relying on it.
   Do not defer every WS9b decision: worker memory/batching boundaries constrain
   the candidate and must be measured before switch. Defer incompatible WS10
   economics changes or rebase/reprice B after each accepted change; otherwise its
   oracle moves beneath it. A switch of a frozen target can precede those changes,
   but then it cannot claim final WS14 performance until they land.

10. **Budgets, kill conditions and release date need evidence, not a ratio (Q6).**
    Keep 50/150 us and 100 ms as unvalidated aspirations, not replacement gates.
    The spike prices crossover runs, not defined no-fill pulses; fixed cost omits
    production surfaces, and PMwR comes from another build/host.
    Use the shared timing harness, matched semantics, alternating independent
    processes, registered noise bounds and separate setup/loop/publication/read
    clocks. Cumulative layer deltas with allocation interactions cannot simply
    become per-stage budgets. A stage's cost depends on its neighbors and workload.
    Stop after two correction rounds for maintainer disposition, as governance
    requires; do not automatically insert an A stage into B. That changes the
    design and may preserve the complexity B was meant to remove. A noisy
    micro-layer exceeding its old counterpart is not by itself a valid kill test:
    require comparable semantic scope and matched integrated measurements.
    Completion needs a complete conforming candidate, reproducible savings and
    acceptable memory, not merely all current samples passing.
    B adds a core implementation/integration/review workstream before the frozen
    test cut and final checkpoint. Expect a material release slip relative to
    subtraction; no defensible number of days/weeks follows from these timings.
    Estimate it after the hard-boundary probe records effort and the remaining
    obligation owners. A calendar promise now would be invented. The maintainer
    must own the cost/time cap and the disposition if it is reached; no indefinite
    dual-core development or silent target relaxation to keep v0.2.3 moving.

Section 10 answers: **Q1** opportunity yes, stage-structure causation unproved;
**Q2** bounded B with incremental review and one atomic switch, A still viable;
**Q3** dev only; **Q4** complete comparisons plus interacting negative/ownership/
lifecycle/resource evidence; **Q5** interfaces first, proof before removal, memory
constraints before switch, explicit macro amendment; **Q6** provisional aspirations,
material but unquantified delay, estimate after measured prerequisite work.

## Runnable Source Probes

Run this block on stdin with `C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe -`.
It uses the existing spike and scratch stores; no registered fixture/oracle is edited.

```r
pkgload::load_all("C:/Users/maxth/Documents/GitHub/ledgr",quiet=TRUE,compile=FALSE)
root<-"C:/Users/maxth/Documents/GitHub/ledgr/dev/spikes/r_floor"
for(f in c("fixture.R","floor.R","layers.R")) source(file.path(root,f))
key<-function(f) {f<-f[order(as.numeric(f$ts_utc),f$instrument_id,method="radix"),]
 data.frame(instrument_id=f$instrument_id,ts=as.numeric(f$ts_utc),side=f$side,
 qty=as.numeric(f$qty),price=as.numeric(f$price))}
cfg<-list(base=list(FALSE,"lean",FALSE,"none"),validate=list(TRUE,"lean",FALSE,"none"),
 rich_ctx=list(TRUE,"rich",FALSE,"none"),avail=list(TRUE,"rich",TRUE,"none"),
 trace_full=list(TRUE,"rich",TRUE,"full"),trace_diff=list(TRUE,"rich",TRUE,"diff"))
for(shape in list(c(3L,40L),c(10L,300L))) {
 fx<-r_floor_fixture(shape[1],shape[2]);bt<-r_floor_ledgr_run(fx,paste(shape,collapse="_"))
 ff<-as.data.frame(ledgr_results(bt,"fills"));eq<-ledgr_results(bt,"equity")
 d<-ledgr_results(bt,"diagnostics");dd<-r_floor_ledgr_trace_frame(d)
 p<-r_floor_prepare_rich(fx,r_floor_prepare(fx))
 for(nm in names(cfg)) {
  conf<-setNames(cfg[[nm]],c("validate","ctx","avail","trace"))
  z<-r_floor_fold_layers(p,r_floor_transition,conf)
  tr<-if(nm=="trace_full") identical(r_floor_trace_frame(p,z$trace),dd) else
   if(nm=="trace_diff") identical(r_floor_trace_frame(p,r_floor_rebuild_trace(p,z$fills,z$residual)),dd) else NA
  print(list(shape=shape,layer=nm,fills=identical(key(z$fills),key(ff)),
   equity=identical(z$equity$equity,eq$equity),cash=identical(z$equity$cash,eq$cash),trace=tr))
 }
 gut<-r_floor_fold_inline(p,gut="same_bar_fill")
 print(c(gut_fills=identical(key(gut$fills),key(ff)),gut_equity=identical(gut$equity$equity,eq$equity)))
 f2<-ff;f2$fee<-f2$fee+1;d2<-d;d2$feature_identity_json[]<-"mutated"
 print(c(fee_invisible=identical(key(ff),key(f2)),
  identity_invisible=identical(dd,r_floor_ledgr_trace_frame(d2))))
 print(ledgr:::ledgr_validate_strategy_targets(setNames(seq_along(p$ids),rev(p$ids)),p$ids))
 reverse<-function(ctx,params) list(targets=rev(ctx$hold()),state=ctx$state)
 print(tryCatch(r_floor_fold_layers(p,reverse,
  list(validate=TRUE,ctx="rich",avail=TRUE,trace="diff")),error=conditionMessage))
 close(bt)
}
```
