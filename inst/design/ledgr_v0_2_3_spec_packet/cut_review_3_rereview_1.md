Role: record; independent clean-context cut re-review, combined Type 1 and Type 2, of v0.2.3 cut 3, workstream 4.
Status: accepted; finalized reviewer record dated 2026-10-29; this status does not accept the draft cut.
Authority: maintainer-requested review of revision 2 of [tickets.yml](tickets.yml), against [macro_plan.md](macro_plan.md) and [contracts.md](../contracts.md); no implementation authority is granted by this record.

Verdict: PASS_AFTER_PATCHES

Apply exact patches P1 and P2 below before accepting the cut. No further cut review is needed for those exact patches. They repair the oracle allowance and restore a previously requested verification obligation; they change neither the chosen workstream nor the three maintainer decisions. LDG-3140 remains a real design gate: an unresolved Type 2 question still stops implementation for its stated checkpoint.

Reviewed branch `release/v0.2.3`, HEAD `5d6ca940405947ba4b93d51bb2ef6f73a24666f8`. The reviewed revision-2 `tickets.yml` SHA-256 is `73baf2cddc15a6f085932436ef11cf93518524515462ae228286241d814c6fc3`. References are repository-relative; `tickets.yml:N` means this packet's file. Cuts 1 and 2 are context only. No timing runner was executed. Only this review file was written in the repository.

## Verification of F1-F9

This assesses ownership and requirements in the revised cut, not completion of future implementation evidence.

| Prior finding | Revision-2 disposition |
| --- | --- |
| F1: A0 cannot differ only in seed_contract | Resolved at `tickets.yml:164,166,585,625`. The single-field assertion is gone. Original records and cut 1's historical claim remain unchanged; separately named successors require field-level predicates covering seed-dependent fixtures, metadata, configuration and hashes. The A0 economic dependency is correctly acknowledged at `:163`. |
| F2: static widening refuses the scoped recipe | Resolved by maintainer decision (11), `tickets.yml:164,166`, macro WS2's amendment, and horizon H086. Neither static widening nor scope recognition is implemented here. The unchanged list still refuses scoped runif; the executed sample.int recipe remains available. Documentation must teach an actually executable instance, as LDG-3143 requires. |
| F3: runtime comparison is not certification and resume can evade it | Resolved by the same scope decision. No runtime observer, durable observation scheme or new certification claim remains. The existing contract limitation and refusals remain. This review does not reopen their future design. |
| F4: visible-state restore loses a cached Box-Muller normal | Resolved by maintainer decisions (5)/(12) and `tickets.yml:585,595,615`. The promise is explicitly RNGkind plus .Random.seed or absence. Next-uniform/sample, non-default kinds, setup failure, worker-stop ordering and the documented Box-Muller case are owned. Hidden cached-normal preservation is excluded, not silently claimed. |
| F5: candidate-only re-freeze can bless defects; fix-shaped guts become inert | Substantially resolved at `tickets.yml:164,585-586,595-596,625-626`: immutable originals, predeclared successor predicates, regression mutations reaching production operations, and final-tree verification. P1 repairs the remaining seed-rule-only causal restriction, which excludes a required storage-fix difference. |
| F6: inherited timing checker cannot enforce the cut | Resolved at `tickets.yml:575-576,625-626`. A new version, seed-state dimension, complete threshold map, stochastic work control, invalid-record demonstrations, and separate A/A validity/noise versus final improvement are explicit. WS1 files and records remain unchanged. |
| F7: mixer gate can ignore execution seed or restart pulse numbering | Arithmetic, independent goldens, edge inputs, absolute calendar origin, cross-seed/shift checks and a seed-ignoring failing control are owned at `tickets.yml:585-586,605-606`. The previous explicit cross-platform golden verification has no owner; P2 completes that requirement. |
| F8: simulator/LSopt/API/write surfaces lack executable ownership | Resolved at `tickets.yml:164,585-586,595-596,615`. All three set.seed sites, worker start, exported API coverage, shared write helper, injected unguarded append, cleanup/error/interrupt coverage and actual LSopt agreement/repeatability/live-seed evidence are owned. Missing NMOF is missing evidence. Simulators are pinned by the maintainer's decision, which is not reopened. |
| F9: fingerprint bump cannot reject an old in-memory candidate | Resolved at `tickets.yml:164,585,605-606`. Executable sweep/WF candidates and promotion inputs must validate current markers before creating a run; old/missing markers and old stores refuse. Candidate and WF seed derivation remain unchanged, separately from the new pulse rule. |

## Required findings, ranked by severity

### P1 - P2 severity: the oracle allowance still excludes the storage fix's economic effects

**Evidence:** `tickets.yml:164` decisions (1), (3), (8), `:166`, `:585`, `:595-596`, `:625`; `dev/bench/v0_2_3_rng_baseline/probe.R:354-395`; `records/store_rng.csv:2-3`; `R/fold-engine.R:1558,2034`; `R/output-handler.R:74`.

Decision (8) requires every changed economic row to be explained by the seed rule, while out_of_scope permits no economic change beyond declared seed-rule effects. RNG-neutral storage intentionally changes economic outputs of ambient-RNG strategies even when the pulse rule is untouched. Decision (1)'s unqualified sentence that sequential default-kind results are unchanged also needs to be limited to pinning alone.

**Executed failure scenario:** the original checker passed all nine tables. Running it again with only the existing `flush_keeps_rng` namespace mutation, into a separate temporary directory, failed on `caller_rng` and `store_rng`, without a scope or probe failure. The pulse rule was unchanged. In store row a, checkpoint-5 final equity changed from `99992.116441100065` to `99984.34987600008`, agreeing with checkpoint-10000. In row b, committed-run final equity changed from `99969.62967899986` to `99967.891749199887`, agreeing with the memory sweep. Both equality fields became TRUE. These are expected economic corrections under decision (3), not v2 mapping effects.

As written, a correct successor must either fail the causal gate or misattribute those differences to the mixer. A broad exception for the whole store table would instead weaken F5's protection.

**Exact required patches:**

1. In decision (1), replace `Sequential results under R's default kind are unchanged` with `Kind pinning alone preserves sequential results under R's default kind; RNG-neutral storage and the v2 pulse rule have their separately declared result changes`.
2. In decision (8), replace `every changed economic row causally explained by the seed rule` with `every changed economic row causally explained by a named accepted change: kind pinning, RNG-neutral storage, or the v2 pulse rule; LDG-3140 freezes the affected rows and their cause, with no blanket economic-table allowance`.
3. In out_of_scope, replace `any economic, fill, cost or state change other than the declared seed-rule effects` with `any economic, fill, cost or state change other than the precisely declared effects of kind pinning, RNG-neutral storage and the v2 pulse rule`.
4. Append to LDG-3140's successor-plan scope: `For the RNG baseline, predicates require nontrivial worker agreement, preserved caller state, checkpoint/store equivalence and successful unseeded walk-forward; assign each changed field to its owning fix or the pulse-rule replacement. The detection-gap policy remains unchanged. Attribute store_rng economic corrections to RNG-neutral storage rather than the pulse rule.`

These patches authorize only effects already required by the cut. They do not permit unrelated economics, fixture changes or broader exclusions.

### P2 - P2 severity: F7's cross-platform golden verification is still unowned

**Evidence:** `cut_review_3.md`, F7's exact required change; `tickets.yml:585-586,605-606,625-626`; `dev/bench/v0_2_3_rng_baseline/probe.R:115-139`.

The revised cut requires a platform-independence argument and independent golden values, but all listed checks can pass on this Windows installation. No acceptance item requires executing the new arithmetic on another platform. The probe itself is one Windows/R toolchain; its successful mixer measurements do not supply that evidence.

**Failure scenario:** a platform-dependent implementation passes local goldens and the written arithmetic review, and the final Windows package check is green. The cut can close without ever comparing the actual production vector implementation to those same goldens on Linux. This is a missing verification obligation from F7, not a request for a different generator or stronger statistical certification.

**Exact required patch:** append to LDG-3142's scope and acceptance, respectively:

> Execute the production pulse-seed vector against the same independently derived fixed golden table on Windows and Linux, including negative, zero and integer-limit seeds and arithmetic-boundary pulse indices. Record the R/platform identities and exact integer results; both platforms must match the fixed expected values. This is a correctness check, not a timing run.

> The independent golden table passes on Windows and Linux with identical expected integer values; a skipped or unavailable platform is missing required evidence.

LDG-3144's final-candidate command record must include those results for the final implementation. An existing CI invocation may supply them; no new cross-platform timing requirement is added.

## Fresh Type 1 and Type 2 assessment

**Boundary and order.** This is the right cut. WS2 and C4 share the fold seed envelope, stochastic witnesses and identity transition; macro Section 4 explicitly permits combining them. The DuckDB and unseeded-WF defects were discovered by execution and belong to that same reproducibility claim. Six serial tickets are honest: executable timing protocol/base first, written design, isolation/pinning/storage fixes, pulse rule/validation, teaching, final oracles/checks/timing. LDG-3141 is large but coherent. Cut 2's peer harness is not a prerequisite and must not silently become this cut's oracle.

**Pinned kind.** Mersenne-Twister/Inversion/Rejection is sound for the seeded fold. Leaving the kind ambient retains the demonstrated one/two-worker defect. L'Ecuyer-CMRG is defensible in another design, but its stream/substream machinery is unnecessary for an integer seed addressed directly by pulse. Switching sequential default-kind execution to it would cause an additional result change without a demonstrated need here. Pinning the worker start is supplementary; the fold must enforce the policy for each seeded execution regardless of worker/package state. Users' outer choice no longer selects the seeded fold's generator; caller state is restored within the accepted visible-state boundary. Explicitly scoped strategy overrides, as in the probe's pinned recipes, still select their own kind. Agreement requires the same explicit override and dependencies on each worker.

**Mixer and statistics.** A once-per-run vector fits the optimization style: prepare/index once and read an integer by pulse index. The measured fmix implementation splits multiplication and xor into bounded halves; LDG-3140 must bind the exact expression, its ranges and independent expected answers before it becomes product code. Hashing and caching still pays all hashes and conflicts with the roadmap's total-run objective. nextRNGStream would introduce generator-specific state and stream-position concerns for random access/resume. A compiled seed kernel is not justified before measuring this small vectorized computation and is outside this cut.

The probe's add/stride controls show why simple consecutive seeds are inadequate: under Mersenne-Twister their first-draw lag correlations are approximately -0.066/-0.062, versus approximately 0.0044 for the mixer. The seed-ignoring control now closes the earlier seed-sensitivity hole. These are bounded empirical checks, not proofs of independent or disjoint streams; reducing to a positive 31-bit seed permits collisions. LDG-3140 must not declare collision freedom or choose bounds after observing candidate results. P2 adds the missing execution evidence for platform independence.

**Ambient detection.** It is outside the cut by explicit decision. No per-call state-copy cost or detector-provenance scheme belongs in the performance claim. Existing preflight remains best effort under `contract-strategy-reproducibility`; unchanged visible state is not certification. I independently confirmed that a scoped runif is still refused by parallel preflight while scoped sample.int is allowed. The one taught recipe can use the already exercised sample.int form; the ellipsis must not imply that every direct RNG call now passes preflight. This is documentation precision, not a request to reopen detection.

**Storage and caller isolation.** A single append helper is achievable on the reviewed source. The operational append sites are availability-persistence (10), backtest-fills (1), backtest-runner (1), derived-state (2), output-handler (4), run-finalize (2), sweep-persistence (4), and walk-forward (3): 27 sites; snapshots-seal has documentation examples, not additional operational sites. No operational dbWriteTable call was found. Direct SQL writes and tempfile-based snapshot registration do not use DuckDB's random view-name helper. Installed DuckDB 2.0.0 generates that name only for nonempty appends and unregisters it on exit. Two consecutive guarded appends, deliberately restoring the same RNG state, succeeded and retained all rows; repeated sequential names are not themselves a collision defect.

The helper must surround the dependency write, not the strategy/fold. Source coverage plus direct helper failures are essential because an outer public restore can conceal an unguarded append while the fold's strategy stream has already changed. The exported-API disposition must cover snapshot construction, run/config/backtest and benchmark wrappers, sweep and worker cleanup, promotion, WF and private windows, save/persistence APIs, nonempty fill readers and simulators. APIs that share a guarded owner can name that owner; adding redundant wrappers everywhere is unnecessary. Restoration must be registered before setup and finish after cleanup, including worker setup failure/stop. Present-state tests must compare saved kind/vector and next draws; absent-state tests must assert absence and active kind, since an unseeded next draw has no fixed untouched-session value. The Box-Muller exception remains exactly as decided.

**Identity and recovery.** Decision (7)'s axes are correct: identical canonical snapshot input keeps its content hash; seeded configuration gains the pulse-rule marker and therefore changes config JSON/hash; adding a recognized rule-version constant changes the store fingerprint (`R/store-gate.R:3-12`). Constants alone are insufficient evidence, which the new hash gates recognize. Old stores refuse; in-memory candidates need their independent marker validation before promotion (`R/sweep.R:845-855` currently just passes the integer seed). WF's existing `ledgr_walk_forward_seed_v1` describes derivation and must be distinguished from pulse-rule provenance, as the design gate now requires. Do not alter the candidate-key inputs used to derive WF seeds while claiming that derivation unchanged.

Resume uses start_idx on the full calendar (`R/run-resume.R:45-62`; `R/backtest-runner.R:1004-1006`); the vector must not restart at the retained tail. Windows need their explicitly frozen scoring-axis origin; scheduled skips consume their calendar positions even when no strategy runs. Finalization-only recovery still needs caller/write isolation although it invokes no strategy. The API/write inventory and LDG-3142's path comparisons own those concerns without adding an execution-mode branch. Preserve the unchanged derivation oracle `350931654L` in test-rng.R:12. Tests pinning ledgr_seed_v1 change only for the declared marker transition; existing context/resume/promotion arithmetic fixtures are not permission to rewrite unrelated oracles.

**Oracles and timing.** A0 now correctly permits a separately named semantic successor, rather than retroactively changing cut 1 decision (1). LDG-3140 must inventory observed configuration hashes and candidate provenance as well as sweep attributes. Its predicates must reject an unrelated row change, not merely identify a table that may differ. The old scalar census and mutations need attachment to the vector's actual owner; a crash or an inert scalar patch is not a successful regression gut. P1 supplies the missing causal allowance for storage fixes while retaining fixed positive predicates.

The timing target is appropriate as a local gate: <=1.03 for unseeded and other cells, <=0.97 for seeded 50x1260 run/sweep. The descriptive 6.2-6.6% profiler share motivates attempting 3% total improvement but does not establish it. At least eight fixed alternating fresh-process pairs, the inherited host/warmup/retention/clock protocol, arm-specific or invariant stochastic work, complete seed-state keys and threshold rejection demonstrations make the new protocol failure-sensitive. The A/A record establishes validity/noise, not a demand to improve against itself. Final misses require per-cell maintainer exceptions; a baseline exception is not a final exemption. No performance result is certified by this review.

## Can every acceptance item fail?

| Ticket | Assessment |
| --- | --- |
| LDG-3139 | The three acceptance items have inspectable chronology, synthetic checker rejections and a complete raw host/source record. Missing/duplicate seed-state rows and both threshold violations must fail. Freeze the exact protocol before product edits; do not run the inherited seeded-only checker as the new gate. |
| LDG-3140 | Four manual gates: site/API dispositions can fail on an omission; arithmetic/bounds/controls can remain unfrozen; successor predicates can miss a surface; an unresolved design requires its Type 2 checkpoint. A file's existence does not discharge them. P1 fixes the causal predicates. |
| LDG-3141 | Actual draws, caller next-draw/state comparisons, checkpoint equivalence, an unguarded-append mutation and LSopt/live-seed evidence can fail. Original-record differences must satisfy the ticket-assigned predicates, not generic equality. Full-suite success cannot substitute for a required skipped worker or optional-package witness. |
| LDG-3142 | Source inspection can reject per-pulse hashing; independent goldens, negative controls and absolute-axis comparisons reject wrong arithmetic/seed use/indexing. Old/missing candidates and old stores exercise real refusal paths. Bindings and actual config/snapshot hashes exercise distinct identity claims. P2 prevents Windows-only evidence satisfying the platform claim. |
| LDG-3143 | Contract/NEWS agreement is a manual review. The article must execute nonzero actions, worker agreement and seed sensitivity through public paths. A flat strategy or a preflight refusal cannot satisfy that acceptance. |
| LDG-3144 | Original-to-successor predicate checks, successor reruns, production-reaching guts, final-tree command exits, hash evidence and each timing bound can fail. Expected differences against immutable originals are assessed by predicates; they are not required to pass the old byte-equality checker unchanged. Record final implementation identities and exceptions explicitly. |

## source_table fact check

The behavioral claims at `tickets.yml:163` are supported by the code and reproduced records: 38/40 plain-recipe trades versus agreement for both explicit pins; three unpinned set.seed sites and no product RNGkind call; scalar pulse hashing at decision-due pulses; candidate/WF derivation sites; unseeded caller leaks; first storage divergences at pulses 8 and 10004; the unseeded WF refusal; unchecked candidate promotion; absent committed pulse-rule metadata; seed-dependent A0 economics; and current test pins. The existing parallel/promotion pulse tests use modular arithmetic rather than random draws. The descriptive cost figures agree with cost/share.csv and micro.csv; they are older host/load_all measurements, not quiet-machine current-tree evidence.

One literal overstatement remains: `Default seed is NULL on every public path` includes the just-mentioned simulators if read literally. Both public simulator defaults are 1L (`R/sim-bars.R:21`; `R/sim-pit-inputs.R:61`). Execution entry points default to NULL; promotion uses the stored candidate seed. This editorial correction is Optional below because the implementation scope already gives the simulators their correct disposition.

## Optional

- In source_table replace the default-seed sentence with `Execution entry points default to seed = NULL; promotion uses the stored candidate seed, and both simulators default to seed = 1L.`
- In the article, explicitly identify the supported sample.int recipe and the unchanged direct-runif/rnorm/sample preflight limitation, linking the parked detection design. Do not imply that the scope decision made those calls scope-aware.
- Add one actual-draw continuous/resumed/windowed witness alongside the required pulse-vector comparisons. The existing resume test at `tests/testthat/test-experiment-run.R:167-244` uses modulo arithmetic. Preserve its existing fixture/oracle; add a separately justified witness.
- Reconcile the historical roadmap/X1 detection wording to the macro amendment when those documents are next maintained, and fix horizon_open_classification.md:116's count (H086 is now present). Neither changes the maintainer's scope decision.

## Commands run and exit codes

All shell commands used absolute paths; git used `git -C C:/Users/maxth/Documents/GitHub/ledgr`. Read-only searches/range reads are consolidated by command family. No timing runner, --cost execution, full test suite, package build/check, NMOF runner or repository-writing gut.R was run. Temporary baseline outputs were written only under `C:/Users/maxth/AppData/Local/Temp/`.

| Command / invocation | Exit | Result |
| --- | ---: | --- |
| `Get-Content -LiteralPath <absolute path>` and numbered/ranged reads | 0 | AGENTS; design index/contracts/roadmap/RFC cycle/spike protocol/optimization style; packet macro/tickets/inventory/prior cut-3 review/cut-1 reviews; horizon routing; NMOF findings; RNG probe/findings/inventory/check/gut, all nine record tables and manifest, descriptive cost files; WS1 protocol/matrix/measure/check; A0 fixture/observer code; rng/fold/sweep/WF/worker/preflight/determinism/output/run/resume/identity/storage code and RNG/context/resume tests cited above. |
| `Get-ChildItem -LiteralPath <absolute directory> -Name` | 0 | Enumerated WS1 timing files and descriptive cost files. |
| `rg -n` over absolute design, R/ and tests/testthat paths | 0, except below | Located contract groups, seeding/restoration, every operational append, markers, refusal paths and existing pulse/seed oracles. |
| Initial exact-pattern search for quoted fold-core anchor | 1 | No match due command quoting; corrected by plain contract-execution-fold-core search, exit 0. |
| Search including guessed test-run-resume.R and test-walk-forward.R | 1 | Those paths do not exist. Corrected by searching tests/testthat; read test-experiment-run.R. No finding relies on a missing file. |
| Read guessed cost/profile.csv | 1 | File absent. Enumerated directory and read share.csv/micro.csv instead. |
| `git -C ... status --short --branch`, `rev-parse HEAD`, product `diff --ignore-cr-at-eol --stat -- R src tests man DESCRIPTION NAMESPACE` | 0 initially | Branch/HEAD above. No substantive product diff; generated bindings were already dirty. Global-ignore permission and CRLF warnings did not affect results. |
| Later `git -C ... status --short --branch` | 1 | Git reported unsafe ownership. No global configuration was changed. |
| `git -C ... -c safe.directory=C:/Users/maxth/Documents/GitHub/ledgr status --short --branch` and `rev-parse HEAD` | 0 each | Read-only per-command override succeeded; same HEAD and initial paths. |
| `Get-FileHash -Algorithm SHA256 -LiteralPath <absolute tickets.yml>` | 0 each | Digest above, unchanged on repeats before the review write. |
| `Rscript --vanilla C:/Users/maxth/Documents/GitHub/ledgr/dev/bench/v0_2_3_rng_baseline/check.R --out=C:/Users/maxth/AppData/Local/Temp/ledgr-cut3-rereview-rng-20261029` | 0 | `rng check: PASS (9 tables identical, product scope clean)`. |
| Same checker with `--gut=flush_keeps_rng --out=C:/Users/maxth/AppData/Local/Temp/ledgr-cut3-rereview-flush-20261029` | 1, expected | `FAIL caller_rng`, `FAIL store_rng`; two named table differences, no probe/scope failure. Economic corrections described in P1. Mutation exists only in the probe subprocess namespace. |
| `Rscript --vanilla -` inline preflight and installed-DuckDB inspection/append witness | 0 | R 4.6.1; simulator defaults 1/1; scoped runif refused and sample.int allowed; DuckDB 2.0.0 method inspected; unguarded append advanced state; two guarded nonempty appends preserved state and all three inserted rows. In-memory database only. |
| Review creation through apply_patch; read-only UTF-8/header/verdict/ticket-digest validation and final scoped git status | 0 | Review created and validated; tickets unchanged; only this review was added by this task. |

R emitted locale-setting startup warnings; both checker subprocesses and the inline witness completed with the exits above. Acceptance of future implementation, final oracles and performance remains the workstream's responsibility.
