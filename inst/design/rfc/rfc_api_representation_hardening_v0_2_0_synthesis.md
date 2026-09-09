# RFC Synthesis: Public API And Representation-Boundary Hardening

**Status:** Draft synthesis awaiting final review

**Date:** 2026-09-09

**Author:** ChatGPT Astra, assigned synthesis author. Role rotation recorded for this cycle:
Codex wrote the seed and response review; Claude wrote the response; Max recorded the decisions.
This synthesis consumes those records and claims no independent R execution.

**Baseline:** `v0.1.9.8` at `27a95f20324e6514d33e34c93cb83a3b545b3970`, package `0.1.9.7`.
The next release is `v0.2.0`. This document changes no package, schema, or hash-rule version.

**Accepted inputs and citation keys:** documents below were read from Git at that baseline.

- S: [Original seed][seed], historical proposal; dispositions below supersede its rejected parts.
- R: [Accepted response][response], including Section 10 decisions and the patched Section 5 map.
- V: [Response review][review]; M-1, L-1, and L-2 are already incorporated into R.
- P: [Probe findings][probe], twelve observations from ten cases at `c78ab4f`.
- A: [Test audit][audit], including Section 7; the audit remains open.
- C: [Contracts][contracts]; N: [Naming synthesis][naming];
  U: [Availability synthesis][availability].
- [RFC cycle][cycle], [spike protocol][protocol], [horizon][horizon], and [styleguide][styleguide].

Evidence labels follow R: *executed* means P's recorded observations, not a new run here;
*contract* means a cited existing contract or accepted maintainer decision; *source* means a
cited source observation without execution; *proposal* marks this synthesis's prescribed changes,
tests, or resolutions. Prescriptions become binding on acceptance; they are not shipped behavior.
P's unresolved questions are historical where R Section 10 subsequently settles them.

This RFC uses 'v1' as shorthand for the first implementation of API and representation hardening;
ledgr's roadmap does not have an API and representation hardening v1 milestone. Post-v1 work lives
in named follow-up RFCs at their own roadmap windows. Seed/response revision numbers are separate.

## 1. Decision Summary

*contract* -- R Section 10 and the maintainer's synthesis brief settle these four decisions:

1. Split derived-fill fees pro rata by quantity. Conserve each event's fee; change neither lot
   cost basis nor `realized_pnl` nor trade metrics.
2. Remove the fills cursor and both `lazy` and `stream_threshold`. Keep `ledgr_run_fills(bt)`
   as an eager tibble reader, including full-schema empty results.
3. A run handle is a durable locator. `close()` releases a held connection; reads can reopen
   by path. Teach reopening as a new-session workflow, not a prerequisite after `close()`.
4. Extract `ledgr_run_fold()` in R Section 5's four stages. These are extraction/commit order,
   never runtime order. Preserve effects and seeding placement; stage 4 awaits failure injection.

*proposal* -- Carry R's accepted direction: fix review lineage, complete risk restoration, expose
`risk_chain_hash` through run info, teach base-R target extraction, and split `R/backtest.R`.
Keep one fold engine. No new public export or entry point is introduced.

*proposal* -- Resolve R Section 10's remaining synthesis choices: restore `ranked`; keep `top`
as a presentation table; add only `risk_chain_hash` to run info; separate the review-helper and
restore-list fixes into two commits. Sections 3 and 13 give the operational meaning.

## 2. Reconciliation With Code And Contracts

| Evidence | Baseline fact or prior rule | Binding disposition |
| --- | --- | --- |
| *executed*, P1-4; A7 | Tested subset/reorder/save/reopen paths preserve nondefault risk; promotion reproduces final equity `10593.491941` | Preserve that behavior; do not describe supported subsetting as demonstrated risk loss |
| *source*, R6; A T-3 | `R/sweep-retention.R:1245-1268` omits two risk attributes from explicit restoration | Complete the list and test the owner directly; the omission is latent |
| *executed*, P6 | Review `ranked` loses sweep metadata; promotion records `source_sweep$sweep_id = NULL` | Restore lineage at `R/sweep-review.R`, independently of the latent restoration omission |
| *executed*, P5 | Run info has no risk field; recorded config and promoted context expose it | Add the run's recorded `risk_chain_hash` to the existing reader |
| *executed*, P7-8; *contract*, C Result | Result wrappers preserve table data; base R already extracts target values | Keep result dispatch; reject `ledgr_target_values()` |
| *executed*, P9-11; *contract*, R decision 2 | Cursor behavior and argument validation depend on data | Delete the cursor branch and both arguments; do not implement a transitional threshold policy |
| *executed*, P12; *source*, `R/backtest.R:1413-1426` in R6 | Seven events produce thirteen rows, fees `13.045` versus `6.775`; six events duplicate fees | Correct projection, with conservation and allocation tested separately |
| *contract*, N7.6 | The earlier naming cycle retained streaming | This synthesis supersedes that retention clause for the hardening packet only |
| *source*, R5 and V M-1 | Every coordinator block has effects; cleanup and handler dependencies cross blocks | Preserve the effect-aware map and runtime order in Section 5 |

*source* -- A's T-2, RNG, wide-collision, cleanup, and interrupted-persistence leads remain
unexecuted in P. A7 supersedes older uncertainty only for the observations it actually records.
Neither historical CI success nor the probe closes the audit or certifies the whole package.

*contract* -- C prohibits output handlers from repricing canonical events. Allocating an existing
event fee among derived rows is a projection rule, not a second cost calculation. No ledger fee,
cash delta, price, or cost metadata is rewritten to reconcile a display table.

## 3. Public Surface Contract

*proposal* -- This is the compatibility disposition of every S Section 3 surface row, plus R's
two amendments. "Remove" for the rejected accessor means remove the proposal, not an export.

| Surface | Disposition | Contract for this packet |
| --- | --- | --- |
| `ledgr_run`, `ledgr_sweep`, `ledgr_walk_forward`, `ledgr_candidate`, `ledgr_promote` | Retain | Existing execution/selection roles and explicit promotion |
| `ledgr_results` | Retain | Delegate to `tibble::as_tibble()`; retain the five current result tables |
| `ledgr_run_fills` | Change | Exactly one argument, `bt`; eager tibble for empty and populated runs |
| Fills cursor, `lazy`, `stream_threshold` | Remove | No threshold switching, ignored arguments, compatibility shim, or cursor consumer |
| `ledgr_promotion_context`, `ledgr_run_promotion_context`, `ledgr_metric_context` | Retain | Source-selection and committed-run contexts remain distinct |
| `ledgr_backtest` | Retain | Lower-level convenience/compatibility surface; experiment workflow remains primary |
| `ledgr_db_init`, `ledgr_state_reconstruct`, `ledgr_backtest_bench` | Retain | Explicit recovery/developer roles; recovery writes are not inspection |
| Proposed `ledgr_target_values` | Remove proposal | No export; teach `c(target)` and named indexing |
| `ledgr_sweep_review` | Change | Restore sweep lineage on `ranked`; preserve explicit ranking and issue reporting |
| `ledgr_run_info` | Change | Add one `risk_chain_hash` field beside `config_hash`; no new reader |

### Fills and fees

*contract* -- R decision 2: `ledgr_run_fills(bt)` always returns the eager fills tibble.
*proposal* -- Retain the existing columns, types, and row meaning; only the fee correction below
changes values. The public function has no `...`: former arguments are rejected by argument
matching before empty-result shortcuts. Do not promise `ledgr_invalid_args` for removed arguments.
Remaining input validation precedes artifact queries. Data size never changes the return class.

The following snippets illustrate contracts; their comments do not claim new execution.

```r
# Before: P9-10 show data-dependent return types.
fills <- ledgr_run_fills(bt, lazy = FALSE, stream_threshold = 0)
# After: same reader for populated and no-fill runs.
fills <- ledgr_run_fills(bt)
nrow(fills)  # Zero means no fills; the table schema remains available.
```

*contract* -- R decision 1: for event `e`, fee `F_e`, and positive derived quantities `q_ej`,
define `Q_e = sum_j(q_ej)` and `f_ej = F_e * q_ej / Q_e`. Thus `sum_j(f_ej) = F_e`.
Quantity is absolute executed quantity, not signed position or notional. Apply the rule to both
reversal directions. A single derived row receives the whole fee; zero fees remain zero.
Numerical assertions use declared test tolerance; this adds no economic rounding or cash policy.

```r
# Illustration, not the probe's fixture: close 4 and open 6, event fee 1.
before <- c(CLOSE = 1, OPEN = 1)     # Duplicates the event fee.
qty <- c(CLOSE = 4, OPEN = 6)
after <- 1 * qty / sum(qty)         # CLOSE 0.4, OPEN 0.6; total 1.
```

*proposal* -- Match derived rows to source events by `event_seq` within their run. Test the
per-event sum independently of the allocation ratio: putting the entire fee on either leg
conserves fees but violates the chosen allocation. Preserve quantity, price, event order, cash,
positions, lot cost basis, `realized_pnl`, and trade metrics. Historical wrong fill totals are
not an equivalence oracle. No new shorting support follows from the algebraic fixture.

### Review lineage

*proposal* -- For a ledgr sweep artifact, including a reopened one, `review$ranked` is restored
from the input as a `ledgr_sweep_results` view with its candidate columns, row provenance, and
applicable parent metadata. Selection-view ordering follows the explicit ranking expression;
retained evidence follows the selected candidate IDs. The input object and saved rows do not change.

```r
# Same public code before and after; the correction is retained lineage.
review <- ledgr_sweep_review(sweep, rank_by = -final_equity)
candidate <- ledgr_candidate(review$ranked, 1)
bt <- ledgr_promote(exp, candidate)
ledgr_promotion_context(bt)$source_sweep$sweep_id
# Before: NULL in P6. After: the input sweep's ID.
```

*proposal* -- `top` remains a presentation table. Teach candidate extraction from `ranked`;
do not add a promotable class to `top` without its full payload. Its promotion completeness is
not established by P6. This resolves R10's open choice without broadening the helper's role.
Keep `issues`, explicit `rank_by`, and `n`; the helper never selects or promotes automatically.
Compatible plain-table inputs do not acquire invented source-sweep metadata. P3's successful
row-provenance reconstruction remains valid; missing parent lineage is a separate question.

### Run risk identity

*proposal* -- Add character `risk_chain_hash`, not `risk_plan_json`, to `ledgr_run_info()`.
Read it from the committed run's recorded risk/config identity. Never substitute the current
experiment's chain or a source sweep's ranking context. Reading it writes nothing and executes
no recovered strategy. A recorded no-op plan has its actual hash; absent historical evidence is
`NA_character_`, not an invented no-op plan. Existing integrity checks remain applicable.

```r
# Before: P5 requires detailed config inspection.
bt$config$risk_chain$risk_chain_hash
# After: inspect the recorded run through the existing public reader.
info <- ledgr_run_info(snapshot, run_id)
info$risk_chain_hash
```

### Targets and run handles

*executed* -- P8 establishes these existing target operations; no target semantics change:

```r
# Before teaching idiom:
unclass(target)[["DEMO_01"]]
# After teaching idioms:
target[["DEMO_01"]]
c(target)  # Plain named numeric; no wrapper metadata.
```

*contract* -- C Strategy still requires full named target quantities, not orders or weights.
Teaching extraction does not fill missing targets, alter zeros, reorder IDs, or authorize shorts.

*contract* -- R decision 3 and C Persistence: `close(bt)` releases a held connection, not the
locator or completed evidence. Ordinary reads may open temporary connections from the path and
must release their owned resources. Reads after close are valid; P11 executed fills and summary
reads specifically, not an exhaustive census of every reader. `ledgr_run_open()` still opens
only `DONE` runs and neither executes a strategy nor recomputes fills or writes run artifacts.

```r
# Before teaching pattern: reopen immediately to continue inspecting.
close(bt)
bt <- ledgr_run_open(snapshot, run_id)
# After: read normally; close is resource management.
fills <- ledgr_run_fills(bt)
close(bt)
# In a later R session, recover the saved locators explicitly.
snapshot <- ledgr_snapshot_open(db_path, snapshot_id)
bt <- ledgr_run_open(snapshot, run_id)
```

## 4. Teaching Contract

*proposal*, carrying S4 and R4/7 -- Teach snapshot, experiment, run/sweep, review, explicit
candidate, promotion, and new-session inspection through exports and documented fields.
The research-workflow selection expression stays usable because lineage is repaired underneath it.
Do not teach an immediate close/open pair as a requirement for durable handles.

*proposal* -- Four reference tiers remain documentation placement: workflow; construction and
authoring; advanced inspection; infrastructure and development. Reuse `_pkgdown.yml`; add no tier
flags, execution modes, export registry, or target export count. Explain the run-info risk hash
without dumping config JSON into the ordinary path. Teach target idioms in
`vignettes/strategy-authoring-tools.qmd` and the existing `ledgr_target()` help.

*contract*, C Documentation/Result and styleguide -- State the outcome first, show visible setup,
use the base pipe, and keep numeric data unformatted. Register cleanup when acquiring resources;
explain which operation reads, writes, or returns a replacement object. Show statuses and issues
with useful next steps. Hash detail belongs in inspection. Do not silently omit incomplete evidence.

*proposal* -- Check the September 4 stale-example leads against the current API before repairs.
Retain installed README/vignette execution and useful name/schema/disclosure checks. Replace
editorial locks selectively; do not equate matching wording with an executable research workflow.

## 5. Module Boundaries And Staged Extraction

*source* -- R5's map below is the accepted effect-aware description of `ledgr_run_fold()` in
`R/backtest-runner.R`. Line ranges are baseline citations, not future file-layout requirements.

| Runtime block, in existing order | Cited lines | Effects to preserve |
| --- | --- | --- |
| Config/control normalization | 574-625 | Clock read at 598; `set.seed()` at 623 |
| Store open, schema, cleanup registration | 626-640 | Connection lifetime; coordinator-scoped `on.exit` |
| Registration, resume detection, DONE shortcut, handler | 641-773 | `runs` writes; handler available before resume |
| Sealed-snapshot guard and TEMP views | 774-876 | Session views; run-row snapshot update at 875 |
| Calendar, resume-tail cleanup, opening events | 877-982 | Tail deletion; opening ledger writes at 973 |
| Preparation, risk plan, execution spec | 983-1274 | `RUNNING` at 994; state and feature-cache effects at 1193 |
| Fold call, failure recording, partial return | 1275-1305 | Status writes and early-return behavior |
| Finalization, replay, equity, DONE, telemetry | 1306-1497 | Table writes; second lot pass beginning at 1396 |

*contract*, R decision 4 -- No block is pure. Stage numbers below describe extraction/commit
order only. Runtime calls, `set.seed()`, status writes, guards, and transaction boundaries stay
where they are. A helper that opens a store returns its closer; cleanup remains registered in
the coordinator's scope. Resume retains its handler dependency; finalization retains the second
lot pass. Helpers take explicit inputs and return records, not a shared coordinator environment.

| Coordinator stage | Extraction and retained effects | Named regression net | Packet slice |
| --- | --- | --- | --- |
| 1 | Lowest-effect preparation/config/control work; leave `RUNNING` and `set.seed()` in place; delete internal `ledgr_backtest_run()` and `ledgr_backtest_run_internal()` wrappers | Existing suite; resume cases in `tests/testthat/test-runner.R:110,146,168`; existing callers retargeted without changing assertions | 3 |
| 2 | Snapshot guard returns stored hash and calendar; preserve their existing computation and verification order | `tests/testthat/test-runner-snapshots.R` and `tests/testthat/test-acceptance-v0.1.1.R` | 3 |
| 3 | Finalization and its second lot pass | Clean/resumed equality in `tests/testthat/test-acceptance-v0.1.0.R:291-362`; slice 4's failure test already passes | 5 |
| 4 | Registration, resume, tail cleanup | Section 6's new coordinator failure-injection test, plus existing resume tests | 5 |

*proposal* -- Stage 2 does not hoist calendar computation ahead of its existing prerequisites.
Assemble its returned information at the existing runtime points; extraction is not rescheduling.

*proposal* -- Split `R/backtest.R` along results, fills/projection, handle, and config ownership.
Use S's proposed `backtest-results.R`, `backtest-fills.R`, and `backtest-handle.R` boundaries;
the config destination filename is not established and remains spec-cut. Keep public construction
thin and preserve the existing config contract. The broader S ownership table is not a mandatory
file manifest. `R/sweep.R` modularization waits; `R/fold-engine.R` is untouched by this packet.

*proposal* -- Mechanical moves first preserve bodies/formals. Corrections and wrapper deletion
are identified separately in review. Follow R's bounded commits and the protocol's 500-line
correction limit; each coordinator stage is one bounded commit. Whether the exact cuts fit is
not established. If they do not, obtain a maintainer amendment instead of silently merging stages
or recasting source lines as pure to justify a larger move.

## 6. Correctness Obligations And Tests

*proposal* -- Every correction has a detecting assertion before its fix. For a latent omission,
test the restoration owner with the relevant attributes absent from its output; a pass through
an unrelated attribute-copy mechanism is insufficient. Mechanical equivalence uses the corrected
baseline. Production-derived expected values do not establish independent economic correctness.

### Coordinator failure injection: fixture, fault, and three assertions

*proposal*, implementing R5 stage 4 -- Extend `tests/testthat/test-runner.R`, with the comparison
pattern in `tests/testthat/test-acceptance-v0.1.0.R:291-362`. Use two isolated stores with the same
sealed snapshot ID/hash and eight daily pulses, extending P's small dense input shape. At every
pulse, AAA has OHLC 100 and BBB has OHLC 50, with positive volume. Initial cash is 10000 and
positions are zero. The full named target sets BBB to zero and AAA, by pulse, to
`10, 20, 10, 0, 15, 5, 0, 0`. Persist a pulse counter as strategy state and a two-session
moving-average feature. Use `ledgr_cost_notional_bps_fee(10)`, `ledgr_risk_max_weight(0.4)`,
seed 1, and the same next-open/config assumptions in both stores. No short or financing is needed.
Set the existing periodic checkpoint cadence to two decisions. The test must demonstrate two
nonempty periodic flushes before finalization; their actual binding is the Section 11 question.

Run one copy cleanly. In the other, let the first nonempty periodic flush complete and record
checkpoint K: its accepted strategy-state cutoff, durable event sequence, and table contents.
K is a logical resumable boundary, not the later DuckDB file `CHECKPOINT` on disconnect.

On the second nonempty periodic flush (`n = 2`), inject one exception after its first persistent
economic write and before the remaining writes/checkpoint advancement. Run the real coordinator,
handler transaction/error path, failure recording, and cleanup; do not stub their outcomes.
Remove the injection before resuming. A fault before all writes cannot establish mid-write safety.

The single scenario has three assertions, inspected through fresh connections:

1. The interrupted run records `FAILED` and the injected failure is observable.
2. Before resume, no economic/state tail beyond K survives: ledger rows, strategy state, persisted
   features, and equity evidence equal their recorded checkpoint prefix, with no partial append
   or advanced checkpoint. Status/error/telemetry writes describing failure are allowed.
   Use each table's decision/execution cutoff; a next-open fill need not share a decision timestamp.
3. With injection removed, resuming the same logical run yields the clean run's ordered ledger,
   features, strategy state, equity, fills, and trade results, with contiguous event sequences
   and no duplication. Exclude store-local IDs and wall-clock telemetry from economic comparison.

*source* -- R5/V identify the missing coordinator test; existing lower-level writer atomicity is
not its substitute. The exact checkpoint cadence, injection binding, and table-cutoff mapping are
not established by the twelve observations. Spec-cut must name those existing seams and prove
that the fixture reaches the mid-write fault. This test has not run or passed. A failing baseline
requires an explicit correction before stages 3-4, not an order-changing extraction workaround.

### Complete disposition of S Section 6

All rows prescribe packet work; evidence status states what is already known. Test filenames
below are existing owners from A's invariant map, not claims that the new assertions exist.

| Obligation | Evidence | Implementation owner | Detecting test / required assertion | Slice |
| --- | --- | --- | --- | --- |
| T-1 fee conservation and allocation | *executed*, P12 | Fill projection, `R/backtest.R`, then fills module | `test-fifo-torture.R`: per-event conservation; separate unequal-quantity ratio assertion. `test-accounting-consistency.R`: unchanged cash/PnL/trades | 1 |
| T-2 no-lookahead | *source*, A T-2 | `R/features-engine.R` | `test-features.R`: leaking `series_fn` rejected with `ledgr_feature_lookahead_detected`, causal control passes, gutted checker fails. `test-precompute-features.R`: earlier-output invariance under future perturbation | 4 |
| T-3 risk restoration | *source* omission; *executed* preservation in P1-3 | `R/sweep-retention.R` | `test-sweep-persistence-roundtrip.R`: restore both risk fields explicitly, then assert base `[` and downstream identity without a dplyr skip | 1 |
| RNG temporary names | *source*, A5 | `R/snapshot_adapters.R` and fills reader | `test-rng.R`: prepared fixtures; caller RNG state and next draw unchanged by ingestion/nonempty reads, including initially absent `.Random.seed` | 4 |
| Wide projection collisions | *source*, A5 | `R/sweep-retention.R` | `test-sweep-retention.R`: candidate `ts_utc` cannot overwrite timestamps; escaped names map reversibly to the same candidate IDs and values | 4, last shape correction |
| Streaming argument validation | *executed*, P9-10 | Fills reader, `R/backtest.R` | `test-fills-streaming.R`: removed arguments rejected even for empty runs; default empty/nonempty outputs are full-schema eager tibbles | 1; supersedes threshold-value tests |
| T-4 cleanup and warnings | *source*, A T-4 | Handle ownership and integration fixtures | `test-walk-forward-orchestrator.R`, `test-backtest-audit-log-equivalence.R`, `test-backtest-lifecycle.R`: explicit cleanup, expected warnings only, fresh-session repeat | 4 |
| T-5 documentation locks | *source*, A T-5 | `test-documentation-contracts.R` and affected articles | Retain API/schema/disclosure assertions; `tools/check-readme-example.R` executes the installed workflow; retire only identified editorial locks | 2 teaching; 4 test changes |

*proposal* -- Add R's review-lineage assertion to `tests/testthat/test-promotion-context.R`:
promoting a candidate from `review$ranked` preserves source sweep ID and nondefault risk identity.
Risk restoration is a separate commit; do not conflate it with this demonstrated loss.

*proposal* -- Future-data perturbation compares only decisions whose information sets and final-
bar status are unchanged, and fills whose execution bars are unchanged. Snapshot/config hashes
may differ. The diagnostic remains a diagnostic, not a proof for arbitrary R code. Preserve
declared strategy seeding when removing infrastructure RNG consumption. Do not add an imputer.

## 7. Compatibility

*contract*, R7 and C -- Pre-release status does not create an external migration guarantee.
Use Section 3's disposition and before/after examples as the compatibility record. Inventory
maintainer-owned stores before the wide-shape correction; do not promise migration without a
named artifact. Existing saved-sweep compatibility and candidate verification still apply.

*proposal* -- Current arguments `lazy` and `stream_threshold` are removed, including calls that
supplied their former defaults. No alias, ignored argument, or replacement cursor API survives.
Keep the public function name. Update help and affected tests, including the superseded N7.6
contract reference; retain the historical naming synthesis unchanged.

*contract*, C Persistence/Result -- Read-only inspection may use temporary connections, but
must not rebuild persistent projections, rerun strategies, or change identity. Locator handles
do not guarantee successful reads after the underlying store disappears or becomes invalid.
No new path-recovery or store-repair policy is introduced.

*proposal*, preserving S7 and U9 -- Compare mechanical moves under identical declared package,
schema, feature-engine, and serialization versions. Corrected fill fees intentionally differ
from the baseline. A later version-bound hash change is not evidence of economic drift, and
economic equality alone does not prove identity preservation. No speedup or peer ranking is claimed.

## 8. Availability Boundary

*contract*, U Sections 1, 5-9, 12, 14-16 -- This packet leaves the accepted availability design
intact. Its representation spike selected no performance or storage winner. Keep these handoffs:

- One shared fold and provider boundary; complete, knowable venue sessions independent of bars.
  Feature/classification expected sessions and the valuation aging clock remain distinct.
- Members union nonzero holdings, deterministic axis/event ordering, pulse-local indices,
  carried holdings, and the active-mode empty-axis rule. Do not harden dense-only validation.
- Separate membership, observation, restriction, valuation, and execution planes. No future IDs
  or execution evidence leak through supported strategy, diagnostic, or error interfaces.
- Literal zero, no automatic liquidation, no hidden retry, bounded affordability, and post-risk
  admissibility. Fee presentation does not become financing or execution policy.
- Required valuation horizon, stale marks never used as fresh closes or fill prices, strict
  feature gaps, explicit exhaustion/terminal stops, and visible but selection-ineligible prefixes.
- Availability identity enters the layers U9 specifies. Reading a risk hash or a valuation
  plane does not redefine `risk_chain_hash`; no new candidate identity field is inferred here.
- `ledgr_results()` continues delegating. Its five-table hardening baseline does not prohibit U9's
  later `diagnostics`/`availability` views or `ledgr_run_explain()` and new-session reproduction.

*proposal* -- Fee allocation, eager-reader semantics, and explicit risk restoration land first.
Availability implementation follows slice 5 below. Its 24 acceptance obligations remain in U14;
they are not copied here or claimed as existing regressions. Storage, fitted preprocessing,
imputation, calendar expansion, and corporate-action economics do not enter this packet.

## 9. Scope And Non-Scope

*proposal*, carrying R9 -- One hardening packet, these five ordered slices. Listed nets must
remain meaningful after wrapper removal; adapt callers, not the economic assertions.

| Slice | Deliverable | Named net |
| --- | --- | --- |
| 1 | Review lineage; eager fills/removal of old arguments; pro-rata fee projection; explicit risk restoration. Separate correction commits, assertions first | `test-promotion-context.R`, `test-fills-streaming.R`, `test-fifo-torture.R`, `test-accounting-consistency.R`, `test-sweep-persistence-roundtrip.R` |
| 2 | Target idioms; run-info risk hash; locator teaching; checked stale examples; reference tiers | Target example and run-info equality checks; `test-documentation-contracts.R`; installed README execution |
| 3 | Mechanical `R/backtest.R` split and coordinator stages 1-2 | Corrected existing suite, `test-runner.R`, `test-runner-snapshots.R`, `test-acceptance-v0.1.1.R` |
| 4 | Failure injection; T-2; RNG names; cleanup/warnings; selective doc locks; wide escaping last among artifact-shape corrections | Section 6's assigned test files and three-assertion failure scenario |
| 5 | Coordinator stages 3-4 | Passing failure scenario plus `test-acceptance-v0.1.0.R:291-362` clean/resumed equality |

*proposal* -- No new engine, export, entry point, registry, witness bureaucracy, generic testing
framework, export-count target, broad renaming, package split, or broad sweep-file split.
No availability policy redesign, storage/ML decision, OMS, financing, corporate-action accounting,
CI redesign, or coverage reduction. Retain the existing release checks and 80% coverage contract.
Version changes belong to the later release packet, not this synthesis draft.

## 10. Acceptance Gates Before A Spec Packet

*proposal* -- Before ticket cut, the packet names these twelve falsifiable gates, their test
owners, and expected baseline outcomes. This is not a claim that changes must be implemented
before their own packet can be authorized. Each gate must pass before its listed slice closes;
G12 additionally precedes coordinator stages 3-4. Any unresolved Section 11 mapping blocks the
affected ticket. The table is the gate definition, not a new executable registry.

Test owners are files already named in R5 or A4. "One test" means one focused scenario with its
necessary assertions; additional existing release checks remain mandatory under C Verification.

| Gate | Falsifiable test or command | Owner file | Pass before |
| --- | --- | --- | --- |
| G1 Conservation | One unequal-quantity reversal test: every grouped derived fee equals its own source event fee; no per-event mismatch remains | `tests/testthat/test-fifo-torture.R` | Slice 1 |
| G2 Allocation and unchanged economics | One two-direction fixture: leg fees equal the pro-rata formula, while ledger fee, cash, lot basis, realized PnL, and trade metrics retain their independent expected values | `tests/testthat/test-accounting-consistency.R` | Slice 1 |
| G3 Eager fills | One populated/empty scenario: formals contain only `bt`; both return full-schema tibbles; supplying either removed argument fails before reads | `tests/testthat/test-fills-streaming.R` | Slice 1 |
| G4 Review lineage | One reopened/nondefault-risk review-to-promotion journey: `ranked` retains class, source sweep ID, candidate identity, and selection order; `top` stays presentation-only | `tests/testthat/test-promotion-context.R` | Slice 1 |
| G5 Explicit restoration | One test removes output-side risk attributes before invoking restoration, then checks both restored fields and base-subset/downstream identity; no dplyr skip around base cases | `tests/testthat/test-sweep-persistence-roundtrip.R` | Slice 1 |
| G6 Run-info risk field | One direct/promoted/legacy fixture: reported hash matches recorded run identity, absent evidence is `NA`, and reading changes no persistent rows | `tests/testthat/test-runner.R` | Slice 2 |
| G7 Locator and cleanup | One lifecycle scenario: explicit close, successful read, owned read-resource release, and new-session open of a DONE run; persistent rows unchanged | `tests/testthat/test-backtest-lifecycle.R` | Slice 2; retained through 4 |
| G8 Teaching | One executable documentation scenario checks the names-preserving target idiom and explicit review/candidate/promotion/new-session path, without private fields or invented lineage | `tests/testthat/test-documentation-contracts.R` | Slice 2 |
| G9 Causality | One causal/leaking feature scenario plus a future-only data perturbation: correct rejection and unchanged eligible prefixes; disabling the checker defeats the negative assertion | `tests/testthat/test-features.R` | Slice 4 |
| G10 Boundary corrections and fixture hygiene | `Rscript -e "testthat::test_local('.', filter = '^(rng|sweep-retention|walk-forward-orchestrator|backtest-audit-log-equivalence|documentation-contracts)$', reporter = 'summary')"` verifies the Section 6 assertions | `tests/testthat/test-rng.R`, `test-sweep-retention.R`, `test-walk-forward-orchestrator.R`, `test-backtest-audit-log-equivalence.R`, `test-documentation-contracts.R` | Slice 4 |
| G11 Mechanical preservation | `Rscript -e "testthat::test_local('.', reporter = 'summary')"` after each mechanical/extraction commit; snapshot guards, resume/DONE paths, event order, and corrected economic/identity outputs remain covered | `tests/testthat/test-runner.R`, `test-runner-snapshots.R`, `test-acceptance-v0.1.0.R` | Slices 3 and 5 |
| G12 Mid-write failure | One Section 6 fixture reaches the second nonempty flush after a confirmed checkpoint and passes all three assertions: FAILED, no tail, clean/resumed equality | `tests/testthat/test-runner.R` | Slice 4; before stages 3-4 |

*proposal* -- G10/G11 use the existing `testthat::test_local()` runner convention. A setup error,
unexecuted conditional, skip, or unrelated failure does not demonstrate fault detection. Report
those outcomes explicitly. Keep installed README execution as an existing release check; G8 does
not require expanding README into a second research-workflow article. Retire obsolete cursor checks.

## 11. Open Questions Promoted To Spec-Cut

These are bounded packet decisions, not reasons to restart the four maintainer decisions.

1. Exact internal file destinations, especially config, and helper input/return records are
   **not established**. Bind them to Section 5's source owners and preserved effects; verify the
   four coordinator cuts fit their commit budget. A necessary budget exception returns to Max.
2. The checkpoint cadence and precise injectable existing write seam for Section 6 are
   **not established** by P. Name the hook, per-table checkpoint cutoffs, and the command that
   demonstrates the fault is reached. Immediate post-failure prefix preservation remains required;
   checking only after resume does not close it. Route a failing baseline to a separate correction.
3. Collision escaping syntax, mapping placement, and affected maintainer-owned wide artifacts are
   **not established**. Choose a deterministic reversible mapping, preserve structural columns and
   original IDs, and record artifact disposition before that shape correction. No generic registry.
4. Legacy run-info fixture inputs and the detailed assertions for unobserved leads are
   **not established**. Bind them before their tickets; preserve absent-risk-as-unknown and
   existing identity checks. Demonstrate the specific risk each new assertion claims to detect.

## 12. Future Obligations

*contract*, U16 -- Corporate/terminal economics, OMS, multi-venue/subdaily scheduling, fitted
preprocessing/ML, financing, and live-feed recovery remain separate future work. This packet
neither implements nor closes them. The accepted availability packet is an immediate handoff.

*proposal* -- A future streaming design requires measured demand and an explicit public consumer,
return type, and resource owner. The removed cursor is not grandfathered into it. Broader sweep
modularization needs a concrete coupling problem; CI critical-path work stays in its September 6
track. Neither is required to finish hardening or begin the accepted availability implementation.

## 13. Disagreements With The Seed And Response And Decisions Beyond Them

| Input wording or open item | Resolution and authority |
| --- | --- |
| S proposes a target getter | Reject under R and P8; use existing base-R idioms |
| S retains streaming; R2/6 still describe threshold fixes | R decision 2 wins: remove cursor and both arguments; no intermediate threshold behavior is shipped |
| S questions reads after close | R decision 3 makes locator semantics explicit; remove immediate reopen ceremony, retain genuine new-session teaching |
| S suggests a broad ownership/file map | R5 narrows implementation to `backtest.R` and four coordinator stages; defer broad `sweep.R` moves |
| R calls its corrections-first sequence a reorder | V confirms S already put corrections first; R specifies the order and nets more precisely |
| R4 proposes restoring both `top` and `ranked`; R10 leaves `top` open | *proposal*: restore `ranked`; retain `top` as presentation-only. Do not imply promotion completeness not established by P |
| R10 leaves the run-info payload open | *proposal*: add only `risk_chain_hash`; retain detailed config inspection, report absent historical identity as unknown |
| R10 leaves correction grouping open | *proposal*: separate review-lineage and risk-restore commits because one fixes observed loss and the other explicit ownership |
| S overstates loss on arbitrary coercion; R6 overgeneralizes supported preservation | P establishes its tested cases: row provenance can support promotion without parent attributes; neither result proves every external transformation safe |
| M-1, L-1, L-2 | Carry patched effects, remove both arguments, and say no new export/entry point rather than no changed public surface |

*proposal* -- Section 6's explicit mid-write point and three observations operationalize decision
4; they do not claim current rollback behavior is verified. Section 10 distinguishes packet-open
test ownership from implementation pass deadlines to avoid circular authorization.
No other decision beyond the accepted inputs is introduced.

## 14. Proposed Post-Synthesis Horizon Entry

This entry is *proposal* until final review and synthesis acceptance.
Do not append it as accepted yet.

### 2026-09-09 [infrastructure] API hardening post-v0.2.0 direction

The API and representation-boundary hardening synthesis binds corrections, a simpler fills
reader, explicit inspection lineage, and effect-preserving coordinator extraction for v0.2.0.
Here "v1" means its first hardening implementation, not ledgr v1.0.0. The following themes record
later work; current packet tests and the accepted availability handoff stay in the immediate plan.

**Accounting and shorting**

- *executed*, P12: the reversal probe accepted negative targets without a settled shorting
  contract. Pass this observed contract/enforcement gap to the shorting/leverage seed.
- *contract*, C Strategy and U16: algebraic reversal coverage authorizes no borrowing, margin,
  or terminal settlement; accounting-critical events and financing own those economics.

**Availability extensions**

- U owns current availability semantics; multi-venue/subdaily calendars require later scoping.
- Live degradation and broad provider adaptation need their own evidence and source contracts.

**Features and model research**

- Fitted preprocessing/imputation must define causal fit/use boundaries and estimation populations.
- Native-missingness consumers and cross-sectional cache families belong to that later ML work.

**Resources and performance**

- Revisit streaming only after measured memory pressure and a proposed public consumption contract.
- Revisit wider sweep/module cuts and representation optimization only after a concrete problem;
  no small-fixture structure count establishes a performance winner.

**Tooling and teaching**

- September 6 CI parallelism/duplicate-work proposals remain separate; retain release evidence.
- Keep documentation executable and freshness repairs local; no new documentation registry.

#### Promoted roadmap hooks

- Shorting/leverage RFC: v0.2.x, before claiming supported negative-target economics.
- Accounting-critical events RFC: v0.2.x, before corporate/terminal settlement or accrual costs.
- Fitted preprocessing/ML RFC: later v0.2.x research window, after availability semantics land.
- Multi-venue/subdaily scheduling RFC: later v0.2.x-v0.3.0, when a concrete dataset requires it.
- OMS lifecycle RFC follow-through: v0.2.x-v0.3.0, before persistent or partially filled orders.
- Explicit streaming contract RFC: later window, triggered only if eager reads become limiting.

#### Immediate cross-cycle obligations

- Hardening packet owns the five slices, twelve gates, and unresolved spec-cut mappings above.
- Availability consumes corrected fee projection, eager readers, and explicit risk restoration.
- Preserve U14's acceptance obligations and U15's open choices without creating another registry.
- Shorting seed receives P12, distinguishing accepted execution from supported semantics.

This entry authorizes none of the deferred capabilities and commits no release date. It records
direction and routes each concern; final review and concrete spec packets remain separate actions.

## 15. Revision History

- **2026-09-09** -- Draft synthesis by ChatGPT Astra from baseline `27a95f2`, incorporating the
  accepted response, four maintainer decisions, and patched M-1/L-1/L-2. Original seed remains
  historical. A second seed is skipped because the accepted response and decisions supply the
  resolutions directly. Final review and horizon acceptance remain pending; no implementation,
  R execution, package/schema bump, or release authorization is claimed.

[seed]: rfc_api_representation_hardening_v0_2_0_seed.md
[response]: rfc_api_representation_hardening_v0_2_0_response.md
[review]: rfc_api_representation_hardening_v0_2_0_response_review.md
[probe]: ../../../dev/spikes/api-representation-hardening/probe_findings.md
[audit]: ../audits/v0_2_0_test_suite_audit.md
[contracts]: ../contracts.md
[naming]: rfc_api_naming_consistency_v0_1_9_5_synthesis.md
[availability]: rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md
[cycle]: ../rfc_cycle.md
[protocol]: ../spike_protocol.md
[horizon]: ../horizon.md
[styleguide]: ../vignette_styleguide.md

Final reviewer: verify these ten claims against the code first.
1. Eager fills have only `bt`; removed arguments fail before reads, including on empty runs.
2. Per-event fee conservation holds independently of pro-rata allocation in both directions.
3. The projection correction leaves cash, lot basis, realized PnL, and trade metrics unchanged.
4. Review `ranked` preserves source lineage; `top` does not masquerade as a complete candidate view.
5. Run-info risk comes from the recorded run; explicit restoration owns both risk fields.
6. `c(target)` preserves names; named indexing works without removing the target class.
7. Close frees resources; reads preserve durable evidence and release owned connections.
8. Extraction preserves runtime order, seeding, status writes, cleanup, and handler dependencies.
9. The real mid-write failure yields FAILED, no checkpoint tail, and clean/resumed equality.
10. The second lot pass and snapshot guards survive; availability contracts stay untouched.
