Role: record; independent clean-context cut review, combined Type 1 and Type 2, of v0.2.3 cut 3, workstream 4.
Status: accepted; finalized reviewer record dated 2026-10-29; this status does not accept the draft cut.
Authority: review requested by the maintainer against [tickets.yml](tickets.yml), [macro_plan.md](macro_plan.md), and [contracts.md](../contracts.md); this record grants no implementation authority.

Verdict: CHANGES_REQUIRED

Reviewed the uncommitted cut 3 at `5d6ca940405947ba4b93d51bb2ef6f73a24666f8`, branch `release/v0.2.3`. The reviewed `tickets.yml` SHA-256 is `c7d50dd616f88b9eb56f10363dd14b1f7d611d26a0ddba139e62d3057a42a6da`. References below are repository-relative; `tickets.yml` means this packet's file. Cuts 1 and 2 are context, not review targets. No timing runner was executed. No product, ticket, fixture or recorded oracle was edited.

This is the right workstream boundary. WS2 and C4 share the fold's seed envelope, reproducibility witnesses and identity transition; macro Section 4 expressly permits combining them. The two additional probe defects belong here. A pinned generator and a vectorized counter mixer are defensible directions. The cut cannot be accepted as written: its A0 allowance is false, its static detection conflicts with its taught recipe, and runtime detection/recovery and caller isolation need narrower, executable semantics. Re-recording against the candidate alone would also absorb regressions.

## Required findings, ranked by severity

### F1 - P1: A0 cannot have seed_contract as its only difference

**Evidence:** `tickets.yml:163,584,604,634-635`; `dev/bench/v0_2_3_output_freeze/fixtures.R:58-78`; `dev/bench/v0_2_3_output_freeze/lib.R:319-326,460-484,516-530`; `R/backtest-config.R:186-200`; `R/sweep.R:2179`.

A0's `dense_risk_features` strategy makes BBB targets depend on `ctx$pulse_seed %% 2L`. A new pulse mapping can therefore change its native economic outputs. A0 also records candidate provenance, not just `sweep_attrs`, and committed configuration is observed. Recording the new rule in run configuration changes `config_json` and its hash. Even if the field is placed outside hashed configuration, that would not satisfy decision (7)'s declared configuration identity change.

**Executed failure scenario:** using the existing A0 fixture unchanged and substituting only the probe's proposed mixer in memory changed the tight candidate's final equity from approximately 10666.89 to 10626.70. Its trade count remained four. Thus equal trade counts do not rescue byte identity. This demonstrates the problem for the measured mixer; the draft has not selected another exact mapping that preserves all A0 economic outputs.

**Exact required change:** replace decision (8)'s single-field allowance and LDG-3145's corresponding acceptance. Before recording the candidate, inventory A0's seed-dependent fixtures and every observed metadata/configuration surface. Declare the precise intended differences, including derived configuration hashes and candidate provenance where applicable, and require an exact baseline-to-candidate diff outside that allowance. Preserve the original A0 records and fixtures. Authorize a separately identified successor record for this semantic change, with an explicit cut-3 supersession statement; do not rewrite cut 1's historical byte-identity claim or broaden exclusions. Each changed economic row needs a causal explanation tied to the accepted seed mapping, not permission for an entire table to drift. LDG-3141's pre-mixer A0 gate also needs the declared allowance for any runtime provenance fields introduced there, or those fields must be introduced at their actual owning ticket.

### F2 - P1: Static widening rejects the very scoped recipe the cut promises to support

**Evidence:** `tickets.yml:163,594,614-615,624`; `R/strategy-preflight.R:258-265,677-679,1047-1088`; `R/sweep.R:211-216`; `R/run-resume.R:1-5`.

Current static analysis collects RNG names without recognizing their seed scope. `withr::with_seed(ctx$pulse_seed, stats::runif(1))` is already marked ambient and refused for parallel execution. The probe's `sample.int` recipe works through static preflight only because `sample.int` is missing from the list.

**Executed failure scenario:** adding `sample.int` to the list in memory changed the scoped recipe's ambient flag from FALSE to TRUE. Both existing refusal helpers then raised their parallel/resume classes. A post-call comparison cannot correct a refusal that happens before the strategy is called. Widening `determinism.R` must also preserve the distinct, stricter indicator-purity policy.

**Exact required change:** decide and specify how static evidence distinguishes a supported, explicitly seeded scope from unscoped draws. Keep existing pre-execution refusal for definitely unscoped calls. Do not exempt a whole strategy merely because `with_seed` appears somewhere. At minimum, require public execution tests for scoped `runif`, `sample.int` and a stats generator in one and two workers and on interrupted/resumed execution, plus mixed scoped/unscoped and NULL-seed cases that still refuse where required. Include a seed-required guard in the taught recipe. These tests must exercise the widened lists and the public refusal path, not just call the runtime comparator directly.

### F3 - P1: Net RNG-state comparison is not certification, and resumed tails can evade it

**Evidence:** `tickets.yml:163,584,614-615`; `contracts.md:1790-1794,1863-1868` (`contract-strategy-reproducibility`); `R/fold-engine.R:831-846`; `R/run-resume.R:1-5,27-90`; `R/backtest-runner.R:930-970`; `R/sweep.R:479`.

A before/after comparison detects a net change in R's visible RNG state. It cannot establish that output is deterministic in `(ctx, params)`. I executed `withr::with_preserve_seed(stats::runif(1))`: the state was identical before and after, while different ambient seeds produced different outputs. Package-internal use can hide that pattern from static analysis. This is a limitation of the proposed observation, not a request for a sandbox.

There is a separate recovery hole: a package call can consume ambient RNG only before an interruption. Comparing calls in the resumed tail observes no change. Finalization-only recovery can invoke no strategy at all. The draft says provenance is recorded but does not require resume to consult that durable observation before recovery modifies the run. A top-level sweep preflight object also cannot represent differing runtime observations across candidate branches by itself.

**Failure scenario:** an originally misclassified Tier 1 strategy draws through a qualified package on an early pulse, stores a result in strategy state, and stops later. Resume accepts its deterministic tail unless the earlier observation survives and is consulted. A workers>1 error can also be reduced to a generic failed candidate unless its propagation is specified.

**Exact required change:** describe this as best-effort detection of observed ambient-state mutation, with an explicit preserved-state false-negative limitation; absence of a change is not a new certification guarantee. Place the comparison tightly around strategy evaluation, including its error exit, outside context preparation, storage and error-reporting work. Specify candidate-level observations, durable committed-run provenance, treatment of failures/interrupts and rollback, worker condition propagation, and promotion/save/open behavior. Resume must check a recorded prior observation before cleanup or continuation, including the finalization-only branch. Add witnesses for early-only and late-only package-internal draws, a callback that draws then errors, worker execution, and recovery with no callback. A package that changes the ambient stream inside a strategy is ambient use under this policy even if its returned value happens to be constant; document that conservative meaning rather than claiming semantic false-positive freedom.

### F4 - P1: Saving .Random.seed and kind does not fully restore all caller generators

**Evidence:** `tickets.yml:163,584,594-595`; `R/fold-engine.R:1615-1629`; `R/backtest-runner.R:386-399`; `R/sweep.R:157-174,224-225`; `R/walk-forward.R:99-114`; `dev/bench/v0_2_3_rng_baseline/probe.R:rp_caller_rng` (only Inversion normal kinds).

Pinning Inversion clears a pending Box-Muller normal variate. That cached value is not represented by `.Random.seed`. Restoring the old kind and integer vector therefore does not restore the caller's next normal draw.

**Executed failure scenario:** with Mersenne-Twister/Box-Muller/Rejection and seed 123, after one normal draw the expected next value was `0.67060308029617122`. Pinning Inversion, seeding, then restoring the old kind and identical `.Random.seed` gave `-0.4194402797747212`. Equality of the two fields named in the proposed tests would miss this stream change. User-supplied generators likewise need an explicit support boundary, not an inferred guarantee about state outside the vector.

**Exact required change:** resolve the supported caller-kind policy before implementation. Either provide isolation that preserves the promised complete stream, or explicitly narrow the contract to the state that can be restored and obtain acceptance for the limitation. If unsupported kinds are refused, do so before changing RNG state or creating execution artifacts, with a classed condition and an executed witness. Tests must include the next draw, a primed Box-Muller cache, non-default uniform/sample kinds, and an absent `.Random.seed` with a non-default active kind. Keep restoration outside all cleanup so worker stop and store closing occur before the caller's final restore; test a setup failure and a stop operation that consumes RNG. Success-only tests are insufficient.

### F5 - P2: Re-freezing the RNG baseline can bless a defect and leaves several guts inert

**Evidence:** `tickets.yml:163,584-585,595,634-635`; `dev/bench/v0_2_3_rng_baseline/check.R:27-39,49-91`; `dev/bench/v0_2_3_rng_baseline/probe.R:449-486`; `dev/bench/v0_2_3_rng_baseline/gut.R:run_check,failed_tables`.

The existing checker compares a rerun with recorded bytes. Regenerating those bytes from a broken candidate makes that broken behavior the new expected result. A list of changed table names is not a semantic oracle: for example, another incorrect worker result can be accepted under the name `worker_agreement`.

Several current guts deliberately install the proposed fixes: `worker_kind`, `flush_keeps_rng`, and `preflight_wide`. Once those fixes ship, those mutations may be idempotent. `pulse_shift` patches the scalar derivation helper; moving execution to a precomputed vector can disconnect that patch from stochastic execution. The census traces the same scalar helper, so its interpretation also changes. The current scope guard compares working product files to HEAD; it is not a base-versus-candidate semantic guard.

**Failure scenario:** worker agreement remains FALSE but is re-recorded; the baseline checker passes. Alternatively, correct implementation makes old fix-shaped guts stop changing their named tables, so the demanded final gut pass becomes impossible without an unreviewed harness change.

**Exact required change:** preserve the original record and compare against a separately named successor. Freeze field/row-level change predicates before re-recording: worker agreement TRUE with nontrivial actual draws, caller state preserved, checkpoint/store equivalence TRUE, successful unseeded walk-forward, and the specified detection/refusal outcomes. Require all unlisted fields to remain identical. Explicitly authorize observer/census adaptation to the vector owner and replace fix-shaped guts with regressions that undo or corrupt the shipped fixes. Each must reach its intended production operation and cause the named semantic assertion to fail; probe crashes or scope failures do not count. Preserve the old guts as historical evidence. Apply the same discipline to A0 under F1.

### F6 - P2: The timing protocol needs explicit changes, not an unchanged WS1 checker

**Evidence:** `tickets.yml:574-575,634-635`; `dev/bench/v0_2_3_ws1_timing/protocol.md`, sections Pairs, The statistic, Records; `dev/bench/v0_2_3_ws1_timing/matrix.R:6-18,60-80`; `dev/bench/v0_2_3_ws1_timing/check.R:168-207`; `dev/bench/v0_2_3_ws1_timing/measure.R:76-116`.

WS1 already uses seeded fixtures. Its checker has one 1.03 bound and rejects differing trade counts across all rows of a cell. This cut needs seed-state as a cell dimension, a 0.97 bound for two cells, and a declared policy for stochastic work whose economic outputs intentionally change with the seed rule. The smaller seeded and stochastic cells currently have no stated final bound. The inherited A/A baseline also cannot reasonably be required to improve by 3% against itself.

**Failure scenario:** a 0.98 ratio passes the unchanged checker but fails the intended seeded gate. An omitted seeded/unseeded arm can go unnoticed if the matrix has no seed-state key. Correct seed changes can fail the inherited work-equality check, encouraging an ad hoc relaxation after measurement.

**Exact required change:** version and commit the new executable matrix/checker before product edits while preserving WS1's historical files and records. Freeze exact pair count, inputs, seeds, candidate counts, retained surfaces, clock endpoints and the complete threshold map. Use 0.97 for seeded 50x1260 run/sweep and a stated no-regression bound for every other measured cell. Keep baseline validity/noise disposition separate from the final improvement requirement. Demonstrate rejection at 0.98 for a 0.97 cell and at 1.031 for a 1.03 cell, missing seed-state rows, duplicates and the inherited invalid-record cases. Freeze an arm-specific stochastic economic control or a stochastic workload with invariant work counts; do not remove work controls generally. Keep raw records, fixed alternation, quiet-host procedure and explicit per-cell maintainer exceptions. LDG-3139 remains first; the descriptive probe cost is not the quiet-machine timing gate.

### F7 - P2: The mixer gate can pass while ignoring the execution seed

**Evidence:** `tickets.yml:163,584-585,604-605`; `dev/bench/v0_2_3_rng_baseline/probe.R:110-162`; `dev/bench/v0_2_3_rng_baseline/records/rule_overlap.csv`; `R/rng.R:1-31`; `R/fold-engine.R:766,1586-1589`; `R/run-resume.R:45-53`; `R/walk-forward-folds.R:773-790`.

The probe tested both cross-seed overlap and adjacent first draws. The ticket keeps only adjacent correlation and uniformity, with numeric limits deferred. A good pulse-only mixer that ignores the execution seed can pass those statistics. Golden values generated from the same faulty rule do not independently test seed sensitivity. Neither a few empirical statistics nor a 31-bit result space establishes independent random streams or collision freedom.

**Failure scenario:** every execution seed produces the same stochastic decisions, while the chosen seed-7 first-draw distribution looks acceptable. A vector built only from the resumed tail can also restart pulse numbering and pass a test that uses a fresh local index in its expected values.

**Exact required change:** freeze the exact v2 arithmetic and numeric acceptance bounds before its implementation, using the measured mixer or another explicitly reviewed rule. Carry forward cross-seed and shifted-stream controls, add a rule that ignores the execution seed as a failing control, and cover negative/zero/integer-limit execution seeds and pulse indices at arithmetic boundaries. Derive golden answers independently of the production vector routine. Specify the pulse-axis origin for ordinary runs, windows, scheduled skips and resume; compare the same execution seed and scoring calendar, with resume preserving absolute indices on that calendar. Keep candidate and walk-forward derivation unchanged. Provide a platform-independent arithmetic argument (including intermediates below exact-double limits, unsigned operations and no signed overflow), plus cross-platform golden verification. No claim of cryptographic quality or disjoint streams is needed.

### F8 - P2: Accepted WS2 obligations and caller/store surfaces are not all owned by executable gates

**Evidence:** `macro_plan.md`, WS2 gate; `tickets.yml:163,584,594-595,624-625`; `R/sim-bars.R:33-45`; `R/sim-pit-inputs.R:400-423`; `R/backtest.R:86,265,313`; `R/walk-forward-folds.R:773`; `NAMESPACE:99-100,230-231,259`; `dev/spikes/nmof-probe/probe_findings.md`, Heuristic and Preflight; `dev/bench/v0_2_3_rng_baseline/inventory.md`.

The accepted plan says to pin wherever ledgr seeds and to reproduce the NMOF LSopt probe. Decision (1) calls the fold envelope the seeding location, but two public simulators also call `set.seed` without a kind. No ticket explicitly runs the LSopt behavioral gate. The six-entry list called every public entry point includes private window helpers but omits exported `ledgr_backtest` and its benchmark wrapper, simulators and storage-facing APIs such as `ledgr_sweep_save`.

The proposed write helper is achievable for the current DuckDB append sites. I inspected the installed nonempty-append method: it generates a random view name and unregisters that view on exit. Sequential repeated names after RNG restoration are consequently not by themselves a collision defect. But public caller-restore tests can hide an unguarded store append; they do not prove that appends inside a fold preserve its strategy stream.

**Failure scenario:** all six named entry tests pass while a simulator remains kind-dependent or an omitted write surface advances RNG. Wrapping only `flush_pending` passes the long-run checkpoint witness but leaves completion, diagnostics, finalization, fill-reader scratch appends or sweep/walk-forward persistence unguarded. The simpler sample strategy passes while LSopt is rejected by the widened static list.

**Exact required change:** add a disposition for all three product `set.seed` sites. Implement pinning for the simulators as the accepted scope requires, or explicitly obtain a scope exception; state that content identity of an identical snapshot remains unchanged even though newly simulated inputs under a non-default kind may differ. Replace the purported exhaustive entry list with exported API-to-guard coverage, including wrappers/private windows and APIs whose neutrality follows from the shared write helper. Require success/error/interrupt and present/absent-state witnesses where RNG is consumed. Route every current RNG-consuming append through the one helper, with a source inventory detecting an unguarded site and direct helper tests on normal/error exits, plus live/buffered checkpoint and post-fold persistence witnesses. Do not wrap the whole strategy/fold in the store helper. Add the actual LSopt one/two-worker, repeatability and live-seed checks to an owning ticket, allowing only the explicitly accepted v2 output changes. A missing optional package is missing required evidence, not a passing skip.

### F9 - P2: A store fingerprint bump does not reject an old in-memory candidate

**Evidence:** `tickets.yml:163,165,604-605`; `macro_plan.md:35-41` (rule 5); `R/store-gate.R:3-12`; `R/sweep.R:733-736,796-855`; `R/promotion-context.R:126-144`; `R/walk-forward-inspection.R:217,271`.

The new `*_rule_version` constant can correctly change the store fingerprint without changing snapshot content identity. It does not protect an in-memory or separately serialized candidate. Promotion currently takes the candidate's integer seed and invokes the current run path without checking its seed contract. The source contract is then copied into promotion context. Walk-forward also has a separately named seed contract that needs a precise disposition; its derivation version need not change merely because the pulse rule changes.

**Failure scenario:** a v1 candidate is retained across a package upgrade, the snapshot is reconstructed in a current store, and promotion silently executes v2 pulse seeds while recording a v1 source. Existing same-snapshot checks cannot establish seed-rule compatibility.

**Exact required change:** include current seed-rule validation for executable candidate/promotion inputs before a run is created, including walk-forward candidates. Reject old or missing required markers with a classed incompatibility condition; do not add a compatibility path or a fallback. Specify separately the unchanged candidate/WF seed derivation version and the changed pulse rule carried in execution provenance. Test a valid current candidate, an old-rule candidate, a missing marker, and an old store refusal. Keep the seeded run-configuration and store-fingerprint declarations, verify their actual hashes, and show unchanged snapshot hashes for identical canonical input.

## Type 2 assessment and ticket grain

Mersenne-Twister/Inversion/Rejection is a reasonable pinned choice for the ledgr execution envelope. Leaving the ambient kind alone preserves the demonstrated defect. Choosing L'Ecuyer-CMRG is possible, but the stream/substream facilities are not necessary for a counter-derived integer seed per pulse; selecting that kind would also deliberately change ordinary default-kind sequential results. Users who intentionally pin a kind inside a scoped strategy helper need a stated policy, and caller-selected kinds must be handled under F4. A worker-start pin alone is insufficient protection against later task/package state; the fold envelope must enforce the execution policy.

A vectorized mixer fits the measured cost and the optimization style. Caching all SHA values still pays their total preparation cost, which the roadmap expressly rejects as the desired optimization. `nextRNGStream` changes the representation and semantics to generator-specific stateful streams and makes direct pulse access/resume more complicated. A compiled kernel is not justified before measuring the small vectorized preparation and is expressly outside this cut. The probe mixer is evidence of a viable direction, not a statistical certification. F7 supplies the missing failure-sensitive checks.

Runtime state comparison is plausible fixed-size work per strategy call under the pinned generator, and catches the five executed gaps. Its cost must still be measured as part of the final total-run gate; it cannot be declared cheap from source alone. F2/F3 are necessary to make the policy coherent. RNG touched by ledgr context construction or sink work must be excluded from the callback observation. RNG touched inside a package evaluation belongs to that callback's observed footprint, unless the package scopes/restores it; an unchanged footprint remains insufficient proof of determinism.

The seven serial tickets form one honest workstream. Measurement first, then written design, implementation, documentation and final verification is sensible. LDG-3141 has several repairs but one shared isolation claim, so another workstream is not needed. LDG-3140 is a manual design gate and cannot turn unresolved Type 2 choices into automatic Type 1 acceptance: the revised cut must bind the decisions identified above or name the additional Type 2 checkpoint before their implementation. Full tests, package build/check and final-candidate source identity are correctly owned by LDG-3145. Retain this final-tree requirement after all harness/test/documentation changes that affect those checks.

## Can every acceptance item fail?

| Ticket | Assessment of its acceptance items |
| --- | --- |
| LDG-3139 | Commit chronology, host fields and complete raw cells are inspectable; numeric demonstrations can fail. F6 is needed for the 0.97 rejection, seed-state completeness, stochastic control and baseline/final distinction. A quiet-machine departure requires disposition before implementation, as drafted. |
| LDG-3140 | Inventory, detection/identity fields and named-difference plans are legitimate manual gates. They fail on an omitted site or unresolved rule; presence of prose alone is not discharge. Bind F1-F4 and F7-F9 before product edits. |
| LDG-3141 | Actual draws and checkpoint differences provide executable witnesses. F4/F8 prevent success-only and outer-restore tests from masking isolation gaps. A0 zero-difference is not a generic permission to omit new provenance; F1 resolves its exact allowance. Full tests remain required. |
| LDG-3142 | Source review can reject per-pulse hashing; binding comparison can reject undeclared constants. Golden/statistical gates need F7 to reject seed-independent or misindexed rules. Configuration hashes and incompatible candidates need F9; bindings alone do not prove them. |
| LDG-3143 | Every gap must reach runtime through an allowed path and mutate state. F2 avoids static refusal satisfying the wrong claim; F3 requires real workers, durable observations and recovery. Cost needs a numerical predeclared bound and final measurement. No new data-scale loop is a source-review gate. |
| LDG-3144 | Contract/NEWS agreement is a manual check. Executed article agreement must include nonzero draws/actions, a seed-required guard and seed sensitivity; identical flat output is vacuous. Include caller-kind limitations and the actual NMOF gate under F8. |
| LDG-3145 | Final-tree command exits and the timing record can fail. Re-recording followed by byte comparison alone is self-confirmation; F1/F5 require constrained differences and regression guts. Missing required worker/recovery/LSopt evidence is not a passing skip. |

## source_table fact check

The main behavioral claims are supported. The independent baseline checker reproduced all nine tables on the reviewed tree. `worker_agreement.csv` records 38 versus 40 trades for the plain recipe, with both explicitly pinned recipes agreeing. `caller_rng.csv` shows unseeded committed runs and two-worker sweeps creating/advancing state. `store_rng.csv` first differs at pulses 8 and 10004. `detection_gap.csv` confirms the five missed calls and the restored-state `with_seed` example. `census.csv` confirms the unseeded walk-forward refusal and the unchanged candidate/WF seed derivation sites. Code confirms checkpoint locations, scalar pulse hashing, absent committed seed-rule metadata and the existing narrow static lists. The installed DuckDB function uses `sample(letters, 10, replace = TRUE)`; empty appends bypass that draw.

Corrections/qualifications: the A0 single-difference claim is false (F1); the simulator seeding sites are omitted by the fold-only description (F8); sample.int inside the scoped recipe is not evidence that widening the list preserves that recipe (F2). The roughly 160 us and 2.2-6.6% figures are descriptive measurements on the probe's older source/host conditions, not quiet-host measurements of HEAD or proof of the proposed 3% improvement. Current `test-rng.R:12` pins the unchanged candidate derivation number; it does not pin an old pulse golden number. Other tests pin `ledgr_seed_v1` (`test-sweep.R:549,573,755`) and must change for that specifically stated reason. Preserve fixtures and unrelated assertions. Existing resume/promotion/parallel pulse arithmetic tests remain useful but do not substitute for real random draws.

## Optional

- Use one named seed-rule constant for sweep attributes, candidate provenance, committed configuration and compatibility validation, avoiding several independently editable v2 literals.
- Include provenance of explicit user kind overrides in the taught stochastic example if such overrides remain supported. Do not imply that the default pinned rule promises agreement across arbitrary package or R versions.
- Keep cut 2 independent. Record exact product identities in every new record so concurrent harness commits cannot accidentally label mixed product revisions.

## Commands run and exit codes

All shell paths were absolute; git commands used `git -C C:/Users/maxth/Documents/GitHub/ledgr`. Read-only range reads/searches are consolidated below rather than repeating every overlapping context window. No timing runner, full package test run, package build/check, NMOF runner or gut script was executed in this review. In particular, `gut.R` would write its results beside the script and was read only. Inline probes used temporary DuckDB files and temporary namespace substitutions that were restored; they wrote no repository file.

| Command / invocation | Exit | Result |
| --- | ---: | --- |
| `git -C C:/Users/maxth/Documents/GitHub/ledgr status --short` | 0 | Initial changes: tickets.yml and pre-existing generated R/cpp11.R/src/cpp11.cpp. Git warned that its global ignore file was inaccessible. |
| `git -C C:/Users/maxth/Documents/GitHub/ledgr rev-parse --abbrev-ref HEAD` | 0 | release/v0.2.3. |
| `git -C C:/Users/maxth/Documents/GitHub/ledgr rev-parse HEAD` | 0 | 5d6ca940405947ba4b93d51bb2ef6f73a24666f8. |
| `git -C C:/Users/maxth/Documents/GitHub/ledgr diff --ignore-cr-at-eol --stat -- R src tests man DESCRIPTION NAMESPACE` | 0 | No substantive product diff; line-ending warnings on the two generated files. |
| `Get-FileHash -Algorithm SHA256 -LiteralPath 'C:\Users\maxth\Documents\GitHub\ledgr\inst\design\ledgr_v0_2_3_spec_packet\tickets.yml'` | 0 | Reviewed digest above, unchanged on the pre-write repeat. |
| `Test-Path -LiteralPath 'C:\Users\maxth\Documents\GitHub\ledgr\inst\design\ledgr_v0_2_3_spec_packet\cut_review_3.md'` | 0 | FALSE before creation. |
| `Get-ChildItem -LiteralPath 'C:\Users\maxth\Documents\GitHub\ledgr\inst\design\ledgr_v0_2_3_spec_packet' -Name` | 0 | No existing cut-3 review. |
| `Get-Content -LiteralPath <absolute file>` and numbered/ranged reads | 0 | AGENTS.md; design README, contracts, roadmap, RFC cycle, spike protocol, optimization style; packet macro plan, inventory, tickets, RNG/A0 briefs and cut-1 reviews/close review; NMOF findings; RNG probe/findings/inventory/check/gut and records census, worker_agreement, caller_rng, store_rng, rule_overlap, detection_gap; WS1 timing protocol/matrix/measure/check/runner; A0 fixtures/lib; rng.R, fold-engine.R, backtest-runner.R, backtest-config.R, parallel-workers.R, output-handler.R, walk-forward.R, walk-forward-identity.R, walk-forward-folds.R, run-resume.R, store-gate.R, determinism.R, strategy-provenance.R, test-rng.R. |
| `rg -n` searches with context over the same absolute design/probe/code paths, `R/`, `NAMESPACE`, and `tests/testthat/` | 0 | Located contract groups, RNG lists/seeding/restoration, append/write sites, public exports, identity/promotion consumers, pulse-seed tests, timing controls and source evidence cited above. Append census included availability-persistence, backtest-fills, backtest-runner, derived-state, output-handler, run-finalize, sweep-persistence, walk-forward and snapshot adapter registration. |
| `rg -n -A 260 -B 2 'id: "LDG-3139"' <absolute tickets.yml>` | 1 | Initial quoting/pattern search found no match; corrected by numbered reads of lines 567-636. |
| `rg` searches including guessed filenames store-format.R/config.R/run-provenance.R, run-window.R/sweep-window.R, execution-window.R, run-calendar.R or provenance.R | 1 | Those guessed paths did not exist. Corrected by searching R/ and reading store-gate.R, backtest-config.R, strategy-provenance.R and walk-forward-folds.R. No conclusion rests on missing-path output. |
| `rg -n -A 12 -B 4 'record rule\|Record rule\|record-rule\|Finding-bearing' <absolute rfc_cycle.md>` | 1 | No matching heading; the process file and prior review records were read directly. |
| `rg --files C:/Users/maxth/Documents/GitHub/ledgr/R -g '*calendar*' -g '*provenance*' -g '*window*'` | 0 | Located strategy-provenance.R; window functions were found by symbol search. |
| `Rscript --vanilla C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/v0_2_3_rng_baseline/check.R --out=C:/Users/maxth/AppData/Local/Temp/ledgr-cut3-independent-rng-check-20261029` | 0 | `rng check: PASS (9 tables identical, product scope clean)`. No --cost option. |
| `Rscript --vanilla -` with inline preflight/Box-Muller/DuckDB/bindings probe | 0 | Scoped runif refused; identical restored state did not preserve the cached next normal; inspected DuckDB random-name function and all 27 current store bindings. |
| `Rscript --vanilla -` with inline A0/mixer/preserved-state probe | 0 | Unchanged dense_risk_features fixture executed old and probe-mixer sweeps; tight final equity differed. Preserved ambient RNG had unchanged visible state but seed-dependent output. RNGkind query alone did not create an absent seed. |
| `Rscript --vanilla -` with inline installed-method inspection | 0 | R 4.6.1; inspected DuckDB dbAppendTable and withr::with_seed/with_preserve_seed bodies, including view cleanup. |
| `Rscript --vanilla -` with inline sample.int static-widening probe | 0 | Temporarily added sample.int using a0_with_patches; scoped recipe changed from unflagged to flagged; parallel and resume helpers both refused. |
| `Rscript --vanilla -` with read-only review validation | 0 | Verified Role/Status/Authority, verdict, nine ranked findings, Optional, command log and valid UTF-8. |
| Post-write `Get-FileHash` on tickets.yml and `git -C C:/Users/maxth/Documents/GitHub/ledgr status --short` | 0 each | Ticket digest unchanged; the only added path is this review. The three initial modified paths remain as found. |

R startup emitted locale-setting warnings; the baseline subprocess and inline probes completed successfully. The commands above establish current behavior and the demonstrated contradictions, not performance or acceptance of an implementation that does not yet exist.
