Verdict: NEEDS_TYPE_2

Role: record; independent clean-context design review of LDG-3157.
Status: accepted; review recorded 2026-10-29.
Authority: review evidence against the accepted cut; this file grants no new implementation scope.

The arithmetic and the executed economic models check out. The caller-isolation
boundary needs a Type 2 checkpoint (F1); this review does not choose that boundary.
F2-F4 are corrections against already accepted requirements. LDG-3157 is not ready
to discharge its design gate.

Reviewed `claude/ws2-rng` at `565e8bbf99051574a3d54864fbbf36708da6d3b6`.
The note's SHA-256 was
`4cdbe532925abd0a09b64d9bc7825b4b163aceae4a22368ffebc177b876fd851`;
the packet's `tickets.yml` SHA-256 was
`7afe432d74943d90678f513ef8ecf13c4ea37167a7d9880f083fddb88e42d4af`.
References below are repository-relative; `note:N` means
`inst/design/ledgr_v0_2_3_spec_packet/ws2_rng_design.md:N`, and `tickets.yml:N`
means that packet's ticket file. `R/` and `NAMESPACE` have no committed diff
between `aa2931e9` and the reviewed HEAD, and no working product diff was present.
The parallel timing directories were excluded from this review.

## Findings, ranked by severity

### F1 - P1 / Type 2: the static partition does not define the public evaluation boundary

**Evidence:** `note:25-28,275-305,307-317,510-513,517-518,537,572-573,592`;
`R/sweep-review.R:30,55-57,101-111`; `R/indicator-dev.R:29,83-90,93-121`;
`R/metric-context.R:196`; `R/backtest-results.R:322-326`;
`tickets.yml:166` decision (4), and `:596-598`.

The declared rule follows namespace symbols and registered ledgr S3 methods.
It misses supported evaluation of user code. In particular:

- `ledgr_sweep_review` is H, but evaluates arbitrary `rank_by` code in a
  caller-parented environment. I executed a valid one-row review with
  `rank_by = runif(1)`; it advanced `.Random.seed`. This is an explicit evaluator,
  not a hypothetical dependency draw. That expression can also invoke a store
  writer or a two-worker sweep through `do.call`/a user helper, without a static
  edge from `ledgr_sweep_review` to that operation.
- `ledgr_indicator_dev` is W because its body lexically contains callbacks, but
  it returns `e$test` and `e$test_dates`. The callbacks execute later, after the
  constructor's wrapper has returned. Both methods advanced the stream when I
  supplied `function(window) sample.int(100, 1)`. Wrapping the constructor does
  not guard either evaluation. The methods have no disposition of their own.
- `ledgr_metric_context` is N, but S3 dispatch can reach a method defined outside
  ledgr's registered-method set. A locally defined
  `ledgr_metric_context.review_rng` that draws and returns
  `ledgr_metric_us_equity()` executed and advanced the stream.
- An N helper can force an argument containing user code. The valid call
  `ledgr_utc({ invisible(sample.int(100, 1)); "2020-01-01T00:00:00Z" })`
  advanced the stream. Similarly, forcing `bt` at `ledgr_backtest_bench` can
  execute a run/store-creation expression despite the helper's telemetry-only
  implementation. All ordinary argument-forcing exports have this kind of
  dynamic reach; a namespace-only graph cannot prove its absence.

**Failure scenario:** all twelve constructor/export witnesses pass while an
explicit ranking expression or a later indicator-development call leaks RNG.
Tracing only fold/seeding/worker-start during the listed targeted tests misses
direct callback draws and unexercised dynamic routes. An inner wrapped run or
sweep also cannot restore draws made by the outer expression around that call.

**Type 2 question:** exactly which evaluation belongs to the caller-isolation
promise: only package-owned execution, explicit user expressions/callbacks,
arbitrary argument promises and external S3 methods, and/or callable methods
returned for later use? Decision (4) plainly covers exports that themselves
evaluate callbacks, but does not specify the returned-callable boundary or an
exception for arbitrary R argument/method evaluation. Choosing a universal
promise versus an explicit bounded promise affects much more than the current
twelve wrappers. This Type 1 review does not choose or silently narrow it.

**Required change:** record the Type 2 boundary, then revise Sections 1/5 and
Appendix A against it. Correct `ledgr_sweep_review`'s H disposition for its
explicit evaluator under decision (4). Give the returned `test`/`test_dates`
evaluations an explicit disposition; never claim that the constructor wrapper
protects their later calls. Include witnesses for the dynamic routes above,
including error/interrupt after a draw and a route reaching a real write/worker
operation. If a boundary is excluded, obtain and cite its operative decision
instead of calling it RNG-neutral. Regenerate the counts after that decision.

### F2 - P2: unseeded walk-forward candidates admit the missing marker the cut forbids

**Evidence:** `note:370,379-387,400`; `tickets.yml:166` decision (7),
`:618-619`; `R/walk-forward-inspection.R:194-219,251,271`;
`R/sweep.R:845-855`.

The note makes `pulse_seed_contract` absent on an unseeded walk-forward
candidate and validates it only when `execution_seed` is non-NA. Its remaining
`ledgr_walk_forward_seed_v1` marker is deliberately unchanged. An old unseeded
candidate, or one with its pulse marker removed, therefore satisfies the stated
walk-forward validation. This is an exception to decision (7)'s old/missing
marker refusal, not a consequence of keeping unseeded run configurations
unchanged. The unchanged derivation marker cannot identify the current pulse
contract.

**Failure scenario:** preserve an unseeded walk-forward candidate across the
upgrade, reconstruct its snapshot in a current store, then promote it. The store
gate passes and the proposed candidate gate accepts its missing pulse marker.

**Required change:** require a current pulse-contract marker on executable
walk-forward candidates, including unseeded ones, and refuse old/missing markers
before snapshot hold/run creation with the specified class. Generate that
candidate marker from the constant independently of the optional seeded-config
field. Preserve the separate walk-forward derivation marker and the unchanged
unseeded config/hash rule. Add old/missing/current cases for both seeded and
unseeded walk-forward candidates. Any desired exemption needs an explicit
amendment to decision (7), not an implementation fallback.

### F3 - P2: the census successor predicate rejects the design's own implementation

**Evidence:** `note:201-210,415-420,447`; `R/fold-engine.R:1629`;
`dev/bench/v0_2_3_rng_baseline/probe.R:170-213`;
`dev/bench/v0_2_3_rng_baseline/records/census.csv:2-11`.

The predicate requires `set_seed_callers` identical in rows 01-04 and 06-10.
Seeded rows currently say `ledgr_fold_envelope`; after Section 3's centralization,
the immediate caller traced by the probe is `ledgr_rng_seed_pinned`. Also,
`ledgr_rng_caller_state()` explicitly calls `RNGkind()`, yet the predicate says
every such call has caller `ledgr_rng_restore`. The existing `rngkind_calls`
column is zero in every operational original row, and has no replacement
numeric predicate despite the new queries/restores. The global identical-other-
fields rule would reject those necessary changes. The prose also extends the
observer with callers while Section 8 permits adaptation only at the deleted
scalar pulse helper.

**Failure scenario:** correct kind pinning and caller-state capture fail the
successor comparator, prompting an ad hoc allowance after implementation.

**Required change:** freeze the changed immediate seeding caller, the allowed
query/restoration caller roles, exact census counts (or a fully specified
independent expected-call ledger), and the schema of any new observer column.
Distinguish query calls from mutations. Explicitly authorize these observation
attachment changes; keep fixture semantics and all unrelated fields identical.
Retain positive predicates for row 05's outcome, zero seed calls/non-NULL pulse
seeds and 19 decision reads. Do not exempt the census table wholesale.

### F4 - P2: the source guard forbids the required caller-state query

**Evidence:** `note:202-204,253-264`.

The inventory rejects every `RNGkind` call outside `ledgr_rng_restore` and the
worker pin. `ledgr_rng_caller_state()` is required to query `RNGkind()`, so the
planned source test fails on the planned implementation. This is separate from
F3's record-comparison error.

**Failure scenario:** either the guard is weakened late or the accessor cannot
capture a non-default active kind with an absent `.Random.seed`.

**Required change:** allow exactly the zero-argument query in
`ledgr_rng_caller_state`, retaining the mutation allowlist for restore/worker
pin. Test that query explicitly and reject an argument-bearing `RNGkind` there
or an unowned query/mutation elsewhere. Keep the parsed-source unguarded-append
injection and direct helper normal/error/absent-state witnesses.

## The two requested readings

1. **Run-local pulse-axis origin: confirmed, with the note's same-calendar
   qualification.** `R/backtest.R:458-466` chooses the clamped ordinary scoring
   start or the window scoring start. `R/sweep.R:279-298` constructs that scoring
   calendar; `R/fold-engine.R:766,1903,1940` derives the seed from the loop index,
   rather than the historical substrate's projection index. Resume retains the
   full calendar and advances `start_idx` (`R/run-resume.R:45-57`); scheduled
   skips retain their calendar positions. The proposed vector preserves that
   addressing and changes only the mapping.

   A sweep candidate and a committed run/promotion on the same experiment,
   execution seed and scoring calendar agree. A run window and the corresponding
   walk-forward/sweep window agree when their calendar and execution seed agree.
   The same timestamp in a longer calendar need not agree: with execution seed
   7, v2 at local index 1 is 373418371, at index 3 it is 530954868 (today's rule
   likewise differs: 2140912200 versus 1898099501). Walk-forward also derives
   distinct window seeds (`R/walk-forward-identity.R:79-104`). Promotion of a
   walk-forward candidate on the original full experiment calls ordinary
   `ledgr_run`, not the old test window (`R/sweep.R:849-855`), so it does not
   promise same-bar equality with that shorter window. LDG-3159's same-calendar
   witnesses must not silently assert the stronger overlapping-bar claim.

2. **Exports that evaluate user indicator callbacks: confirmed as covered by
   decision (4).** Purity checking does not prove no draw: the unchanged
   `R/determinism.R:7,26-33` list misses `sample.int` and package-internal RNG.
   Thus precompute/execution callback evaluation cannot be declared neutral on
   that basis. This confirms the proposed broad reading for those exports; it
   does not make lexical reach into a returned closure an execution-time guard.
   F1 records the further boundary question and the concrete coverage failures.

## Independent verification of the remaining acceptance items

- **Inventory:** all 181 NAMESPACE exports occur in exactly one textual group:
  W 12, H 56, N 113, with no omissions or duplicate assignments. There are 93
  registered S3 methods, as stated. Textual completeness does not repair F1's
  semantic misclassifications. My source census found 27 operational appends:
  availability-persistence 10; backtest-fills 1; backtest-runner 1;
  derived-state 2; output-handler 4; run-finalize 2; sweep-persistence 4;
  walk-forward 3. Their locations match Section 4. The two snapshots-seal
  examples are comments. There is no operational `dbWriteTable`, `RNGkind`,
  `sample` or `runif` call in R/. There are three `set.seed` sites, two `daemons`
  calls, and eleven syntactic `stats::rnorm` calls in the two simulators. All
  these product sites have the stated disposition. `tempfile` registration and
  SHA/time/counter-derived IDs are correctly distinguished from R RNG draws.
- **Arithmetic:** the defined unsigned fmix/xor/fmix mapping is precise. The
  half-products and cross-product sum, not just the reduced product, stay below
  2^33; shifts and xor operands remain representable without signed overflow.
  The modulo-M result is in 1..2147483647. I independently recomputed all 63
  goldens with masked arbitrary-precision integers, without R or split halves.
  For example, seed 0/pulse 1 gives fmix32(1) = 1364076727 and seed 1364076728.
  The probe's R split implementation reproduced the mixer matrix digest
  `0394b14a6fcc71c47c9586a08f2323efb78db0d8f28a774e0c0ec0ab478975d9`.
- **Bounds:** every B1-B6 is numeric and failure-sensitive. Recomputed v2 maxima
  were B1 0.0257394, B2 0.0174000, B3 0.0169277; B4 10000 distinct/0 shared;
  B5 0; B6 minimum 1000. Add gave B1 0.3786365, B2 0.9999977, B4 519/517,
  B5 9481, B6 0. Stride gave B1 0.3746398, B2 0.9995343, B6 0. Seed-ignoring
  gave B4 500/500 and B6 0. Thus all three controls fail; no independence or
  collision-freedom claim follows. Production Windows/Linux verification
  remains an implementation obligation, not evidence supplied by this review.
- **A0 successor:** the actual records contain the stated 14 sweep directories
  and 11 seeded runs.csv directories, plus the two named unseeded exceptions.
  I executed the unchanged dense_risk_features fixture sequentially with a
  lookup of v2 seeds calculated using independent BigInt arithmetic, replacing
  only the old scalar helper in process. The changed rows reproduce A4 exactly:
  persistent ledger_events 5, fills 5, equity_curve 6, trades 2, metrics 7;
  memory_events 6, memory_fills 5, memory_equity 6; sweep 1, sweep_returns 6,
  sweep_trades 2. Only tight changes, from January 3; loose remains identical.
  The sweep summary changes eight cells (including annualized return), while
  the metrics table changes seven values, consistent with the note's wording.
  No extra economic table changed in this model. A1-A3 and A5 still require
  implementation evidence; no fresh worker/model equivalence was claimed here.
- **RNG successor:** an independently applied guard around every DBI append on
  the unchanged base reproduced both storage-model rows exactly: both sides
  99984.34987600008 in a, both 99967.891749199887 in b, TRUE equality and no
  differing pulse. This isolates storage from the pulse-rule replacement. The
  base-tree pulse-only model is a suitable economic oracle if its independent
  reference and base identity are retained; it must not be generated by calling
  the candidate implementation. Worker equality must be against this pinned
  sequential result. The positive model predicates are not blanket economic
  allowances. F3 prevents accepting the complete successor plan as written.
- **Identity:** the new constant matches the store binding census regex in
  `R/store-gate.R:3-12`. Seeded engine JSON/config hashes change; default seeded
  run IDs change through `R/run-registration.R:20`. Snapshot content identity,
  unseeded configs, candidate seed derivation and walk-forward derivation/key
  inputs remain unchanged. Sweep seed_contract/provenance moves to v2; the
  separate WF pulse marker is needed beside its unchanged derivation marker.
  Classed early config/candidate/store refusal is specified appropriately apart
  from F2. Existing store fingerprint refusal covers old stores, not detached
  candidates. Actual hash changes remain LDG-3159 evidence.
- **Restore and helper exits:** the extra forcing frame puts inner cleanup
  before outer restoration on success/error/interrupt, provided all covered
  evaluation really executes inside it (F1). The helper's on.exit preserves
  present/absent seed state even when the append throws; it does not wrap the
  strategy/fold. The parsed-source injected direct append can falsify the
  ownership test; F4 repairs its contradictory RNGkind allowlist. The
  Box-Muller exception is accurate: an independent seed-123 cached-normal
  experiment lost the next normal after Inversion pinning and visible-state
  restoration. No hidden-normal preservation is claimed.
- **Factual inputs:** the cited seeding, append, pulse-index, marker, simulator
  and worker sites match the unchanged aa2931e9/565e8bbf product sources.
  All 290 A0 record files and all nine RNG record files match their manifest
  hashes. The baseline retains the 38/40-trade worker defect, checkpoint
  divergence, unseeded-WF error and detection gaps. The historical cost figures
  are descriptive probe measurements, not a new timing result. LSopt ownership
  and the unchanged detection policy match the accepted cut and NMOF findings.

## Optional

- Clarify R3 at `note:466`: removing the outer caller wrapper can break
  worker rows 13/15, but storage neutrality already protects run rows 01/05/09
  with the flat fixture. I executed those three run cases on the base with
  only appends guarded: all preserved present MT, present L'Ecuyer and absent
  caller state. The listed row-set predicate can still fail through 13/15; do
  not require every listed row to change or undo the storage fix as well. Use a
  separate actually-drawing unseeded run witness to test its outer wrapper.
- Specify B5's endpoints explicitly: seed pairs (s,s+1) for s=1..19 and
  p=1..(500-k), in both directions. This gives the reported add-control 9481;
  allowing p+k beyond the 500-pulse matrix instead gives 9500. Both reject the
  control, but the frozen statistic should have one reproducible definition.
- Name how the new WF pulse marker appears in reproduction-key and promotion
  source metadata. Copying the unchanged WF derivation seed_contract alone
  does not expose that marker in those summaries; the full candidate provenance
  already has a propagation path through provenance_json.

## Commands run and exit codes

All shell calls used absolute paths; no timing runner, full tests, package
build/check, original gut runner or NMOF runner was executed. In-process models
used temporary DuckDB stores and `pkgload::load_all(..., compile=FALSE)`; no
product/source file was edited. Original checkers/guts were read rather than run
because their default loading/output paths can modify worktree artifacts. No
timing directory was read or changed.

| Command / invocation | Exit | Result |
| --- | ---: | --- |
| `Get-Content -LiteralPath <absolute file>` with range reads and `rg -n` over the named design, ticket, probe, A0, NMOF, source and NAMESPACE files | 0 | Authority, inventory, fixture, oracle and cited-code inspection; overlapping reads consolidated here. |
| Initial `git -C ... status --short`, command-local safe.directory attempts, and initial `rev-parse/log` attempts | 1 | Git 2.36.0 rejected worktree ownership. No global configuration was changed. |
| `git -c safe.directory=... -C ... config --show-origin --get-all safe.directory`; `git --version` | 0 | Diagnosed the ownership-check/tool-version issue. |
| `git -C C:/Users/maxth/ledgr-wt/ws2-rng --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws2-rng --work-tree=C:/Users/maxth/ledgr-wt/ws2-rng rev-parse HEAD` | 0 | Reviewed HEAD above; explicit known gitdir avoids repository discovery failure. |
| Same explicit-gitdir command with `diff --stat aa2931e9 HEAD -- R NAMESPACE`, `status --short`, and `diff --ignore-cr-at-eol --stat HEAD -- R NAMESPACE src` | 0 each | No product diff; only the two excluded timing directories were untracked before review creation. Git warned about an inaccessible global ignore file. |
| `Rscript --vanilla -e` inspecting load_all formals/R version, then a compile=FALSE load | 0 each | R 4.6.1; package loaded without compilation/generation. |
| `python -I -`, independent exact-integer goldens and first record scan | 1 | All 63 goldens passed; subsequent scan failed on typed CSV headers. No product conclusion used the failed scan. |
| `python -I -`, second A0 scan | 1 | Needed to undo canonical doubled backslashes before JSON parsing; corrected next. |
| `python -I -`, corrected A0 scan, full record-manifest hashes, note/ticket hashes and exact export partition | 0 each | 14 sweep/11 seeded config directories, immutable record hashes, 181 exports partitioned once. |
| `Rscript --vanilla -`, sweep_review and returned indicator callback witnesses | 0 | All three evaluations advanced RNG; namespace counts 181 exports/93 S3 methods. |
| `Rscript --vanilla -`, lazy-argument and external S3-method witnesses | 0 | Both valid calls advanced RNG. |
| `Rscript --vanilla -`, first DBI generic trace model | 1 | Neutrality assertion failed: tracing the nonstandard generic did not surround the dispatch as intended. Discarded; no model result was taken from it. |
| `Rscript --vanilla -`, corrected full-append storage model | 0 | First verified neutral direct append, then reproduced both quoted store_rng values/equalities. Namespace replacement was process-local and restored. |
| `Rscript --vanilla -`, B1-B6 recomputation over probe split arithmetic plus add/stride/seed-ignoring | 0 | Numeric results above; all controls rejected. Initial B5 used extended endpoints (9500); the explicit bounded-endpoint recomputation below reproduced 9481. |
| `Rscript --vanilla -`, independent-BigInt-lookup A0 model, then corrected typed-header cell comparison | 0 each | First located differing tables; second established the exact A4 row/cell counts above. No records were written. |
| `Rscript --vanilla -`, neutral-storage-only caller model | 0 | All three run caller states preserved without an outer wrapper; informs the optional R3 clarification. |
| `Rscript --vanilla -`, bounded B5, mixer digest, current pulse indices, constant regex and Box-Muller experiment | 0 | 9481; recorded digest reproduced; local-axis difference and cached-normal limitation confirmed. |
| Final `status --short` and `python -I -` review/header/UTF-8/input-hash validation | 0 each | Only this review was added by the reviewer; excluded timing work changed concurrently. Note/ticket hashes stayed unchanged. |
| Searches/reads using guessed nonexistent selection/folds/experiment-plan/json filenames and a Windows rg wildcard-path attempt | 1 | Corrected with searches over R/ and actual owners; no conclusion relies on missing-path output. |

R startup reported locale-setting warnings; successful invocations completed.
The empirical results establish base behavior and design-input checks, not
acceptance or performance of a future implementation. Only this review file is
the reviewer's repository write.
