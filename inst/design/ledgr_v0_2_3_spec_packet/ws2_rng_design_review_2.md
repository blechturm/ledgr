Verdict: CHANGES_REQUIRED
Role: record; independent clean-context focused re-review of LDG-3157 (correction round 1).
Status: accepted; review recorded 2026-10-29.
Authority: review evidence against the accepted cut; this file grants no new implementation scope.

Reviewed response: `607ce382..d7a68d9d`, specifically `33af42b5`, `a9517d40`
and `d7a68d9d`, against cut 4 decisions (14), (15), including B-1, and (16)
in `tickets.yml:166`. References to `note` below mean `ws2_rng_design.md` at
`d7a68d9d`. This reviews a design gate, not an implementation of LDG-3158/3159.

The maintainer decisions settle the original boundary question. I found no
additional policy choice requiring Type 2. The remaining findings are failures
to specify that accepted direction consistently: preserving expression captures
across the implementation split, counting the default candidate method's
wrapper, and making the new census schema representable. These require a
corrected note before the design gate passes.

## Original findings and maintainer decisions

### F1 / decision (14): boundary resolved; implementation specification still needs N1/N2

The boundary in `note:325-391` follows decision (14), as refined by (15) and
(16): own work and service evaluation are restored; supplied ordinary argument
draws occur first; user S3 methods dispatched after that entry are inside the
restore; the two indicator development helpers restore on their own calls.
The constructor is not claimed to protect their later execution. Decision (16)
explicitly excludes the signal strategy and adapter indicator from an own
restore. The documentation paragraph states these distinctions.

I independently searched `R/` for evaluation/capture operations, function checks
and nested/returned functions, and inspected their operational owners. The
explicit evaluators added in this round are real:

| Evaluator | Source and disposition |
| --- | --- |
| `rank_by` | `R/sweep-review.R:51-53,104-121`: capture plus evaluation with caller lookup; W. |
| PBO metric | `R/validation-pbo.R:44,215-232,259-260,297`: supplied function is called over matrices; W. Its expression is also a label. |
| Grid `.filter` | `R/param-grid.R:32-36,45-49,178-215`: captured expression is evaluated over atomic grid columns; W. The current symbol allowlist rejects `runif(1) > 0`. |
| Development helpers | `R/indicator-dev.R:83-121`: `test` and `test_dates` invoke supplied `fn`; R, each with its own restore and cleanup inside that restore. |

Other callback routes are accounted for: feature factories at
`R/experiment.R:542`; scalar/series callbacks in `R/features-engine.R` and
`R/history-features.R`; adapter and TTR closures; and the signal wrapper.
`ledgr_strategy_schedule()` decorates the existing function rather than
executing/wrapping its body (`R/strategy-schedule.R:44-55`). Indicator
construction stores a callback. Stored-strategy reconstruction evaluates a
function literal, not its body (`R/strategy-extract.R:272`). The business-objective
case is correctly excluded: validation actually replaces `$evaluate` with the
builtin evaluator (`R/business-objective.R:390-392`) before the call at `:818`;
the hash check alone would not have established that. Pulse feature/bar
accessors are product-built readers, not additional user callback parameters.
I found no further supported service evaluator missing from the note, and no
other callable that ledgr itself runs mistakenly assigned an own restore.

An independent NAMESPACE comparison verifies the *textual* partition exactly:
181 exports, W/H/N = 15/55/111; 93 registered S3 methods, 1/42/50; no overlap
or omission. This does not resolve its conflict with the specified wrapper on
`ledgr_candidate.default` (N2).

The witnesses at `note:611-635` include genuinely drawing ranking/metric
callbacks, error and interrupt after a draw, later helper calls, and a ranking
helper that draws around a real two-worker sweep and persistent sweep save.
The worker/store route is explicitly required, not replaced by a mocked call.
I executed the actual ranking success/error/interrupt shapes under a temporary
outer preserve frame: all restored the state, and the error had the specified
`ledgr_invalid_sweep_review_rank` class. The worker route remains a future
LDG-3158 execution obligation; I did not run workers in this re-review.

### Decision (15), including B-1: forcing rule works; capture transport is incomplete

`note:500-527` correctly describes forcing supplied ordinary arguments in the
export frame, leaving defaults/missing arguments lazy, forcing dots, and
surfacing forcing errors before any save. The frozen never-forced names match
the actual service captures: `rank_by` and `.filter`. `metric` should be forced;
in the *same frame*, `substitute(metric)` retains its original expression after
forcing. Forwarding to a new implementation frame is a separate issue (N1).

R 4.6.1 probes confirmed two supplied `sample.int()` seed arguments give the
two successive caller draws; supplied dots advance the stream; omitted defaults
stay lazy; a default can refer to an already-forced supplied argument; missing
required arguments remain detectable; and an error after an argument draw
surfaces before saving, retaining that draw's advancement.

I inspected every W signature and the two candidate method signatures. Their
defaults are literals, arithmetic, lists/vectors, or the four constructors
`ledgr_timing_next_open`, `ledgr_risk_none`,
`ledgr_corporate_actions_research`, and `ledgr_sweep_retention`. There is no
current default referencing a supplied argument or drawing RNG. Direct checks
of those four constructor defaults preserved the RNG state. This conclusion is
from the actual defaults, not the note's overbroad claim about the source guard
(Optional O1).

Keeping `missing()` and argument-choice normalization in the export/method
prologue is appropriate. Relevant sites include `R/backtest.R:203`,
`R/pulse-snapshot.R:80-84`, `R/walk-forward.R:89,122`,
`R/walk-forward-inspection.R:104`, `R/sweep-review.R:30`, and the grid flags.
The generic must retain `UseMethod()` in its own frame; placing the steps in
its operational registered methods is executable. The note must classify and
count both such wrappers consistently (N2).

The cleanup rule is correct: an export-frame `on.exit(runif(1))` runs after an
inner preserve helper returns and leaks the draw; moving that cleanup into the
called implementation makes restoration run last. I executed both shapes.
Apply that same rule to `test_dates()`'s snapshot release, not only exports.

B-1 is stated at `note:572-579`. Using the real development helper in a small
in-process wrapper model, two supplied `dates = sample(x, 3)` arguments matched
the two untouched-session samples, while callback draws were restored. Removing
the force step repeated the first date sample and failed the predicate. Only
irrelevant timestamp-vector names were removed for comparison; dates, sampling
and callback behavior were unchanged.

### Decision (16): resolved

`note:562-570,672-686` correctly requires no own restore for the signal strategy
or adapter indicator. On the current product, the proposed 30-pulse,
one-instrument signal example produced 19 BUY/SELL fills, repeated identical
economic fill columns in a second seed-7 run, and preserved the caller state
around those seeded runs. A direct call consumed one caller draw. A drawing
`ledgr_adapter_r()` callback called through `$fn` also advanced the caller stream.
These establish runnable input witnesses; isolation after future changes must
still be tested. No additional Type 2 decision is needed here.

### F2: resolved in the specification

`note:718-747` now stamps the current pulse-contract attribute from the constant
when walk-forward results are produced or opened, for seeded and unseeded
sessions, and copies that attribute into candidate provenance/attributes rather
than manufacturing it at extraction time. The unchanged
`ledgr_walk_forward_seed_v1` marker continues to identify seed derivation.

The validation matrix covers current/old/missing markers for seeded/unseeded
sweep and walk-forward candidates, before `ledgr_snapshot_hold()` and run-row
creation, with class `c("ledgr_seed_rule_mismatch", "ledgr_invalid_args")`.
It also rejects a changed derivation marker. This repairs the original
unseeded exception without changing the unseeded config/hash rule. The store
gate remains separately responsible for refusing old store bindings. The
reproduction key and promotion source metadata now expose the pulse marker
(`note:720-721`). See Optional O2 for making R10's extraction fixture explicit.

### F3: partly resolved, still blocked by N2/N3

The successor now names the seven added observer columns, the central seeding
caller and its MT argument, separate query/mutation caller roles, an independent
numeric ledger, and an entry-state observation. Row 05 still must succeed with
zero seed calls, zero non-NULL pulse seeds and exactly 19 decision reads.
Unrelated fields remain identical; there is no table-wide exemption.

The original counts in `records/census.csv` agree with `probe.R`: seed counts
0/0/0/0/1/2/1/6 over operational rows 01/02/04/05/06/07/09/10; decision reads
10/20/10/6/10/20/10/19. The planned NA-to-NULL repair makes row 05 execute
the remaining windows, giving 19 reads. Queries belong only to
`ledgr_rng_caller_state`, mutations to `ledgr_rng_restore` on these one-worker
paths, and nonzero seed calls belong to `ledgr_rng_seed_pinned` with MT.

I checked the entry-state assumption rather than inferring it from the last
`rp_clear_seed()`. On the **unchanged base**, it is false in all eight operational
cases: `rp_census()` constructs `a0_fx_walk_forward()` first (`probe.R:209`),
whose persistent appends create the seed before case 01. In a model with every
production append guarded, the specified export/method wrappers, and the
unseeded walk-forward repair, the fixture left the seed absent and all eight
case starts were absent, without resets between cases. Thus the precondition
is valid for the intended successor, not a literal fact about the original
probe run. Qualify `note:828-831` accordingly, and retain the column assertion.

The non-promotion E/S arithmetic is consistent under that successor precondition.
The promotion rows omit the wrapper evaluated in their candidate argument (N2).
The declared new types also conflict with the blanket empty-string copy rule
(N3).

### F4: resolved for RNGkind ownership; shape guard needs N1/N2 consistency

`note:278-305` allows exactly a zero-argument query inside
`ledgr_rng_caller_state`, and argument-bearing mutations only in restore and
the named worker pin, including its quoted worker expression. It specifies the
clean-source pass plus injected direct append, mutation in the query owner,
unowned query, and unowned mutation failures. The append helper's direct
present/absent/error tests remain required.

The decision-(15) check at `note:554-560` has falsifiable conditions: force
before preserve, exact lazy-name sets, and no export-frame `on.exit`; force-step
removal also has behavioral failing witnesses at `:669-670` and `:577-579`.
Specify its permitted prologue/capture transport and method list consistently
with N1/N2. This is not a reason to weaken either ownership allowlist.

## Required findings, ranked by severity

### N1 - P2: splitting the export frame loses the captured expression and caller environment

**Evidence:** `note:487-497,515-524,529-560`;
`R/sweep-review.R:30,51-53,104-111`; `R/param-grid.R:32-36,45-49,178-185`;
`R/validation-pbo.R:44`.

The two-step export/implementation example forwards formal names into the
implementation. The exception paragraph retains `missing()`/`match.arg()` in
the prologue, but does not retain `substitute()` or the original caller frame.
Never forcing a promise does not preserve its source expression across another
function frame.

**Failure scenario:** put the existing sweep-review body in an implementation
and call it with `rank_by = rank_by`, following the example. Its substitute is
now the symbol `rank_by`; following the promise evaluates `-sharpe_ratio` outside
the candidate data mask. I executed this against the real product body: the
valid original call passes, while the split call raises
`ledgr_invalid_sweep_review_rank` with `object 'sharpe_ratio' not found`.
The corresponding real grid split rejects the unknown symbol `.filter`.
A toy PBO-label shape returns `metric` instead of the caller's `fun` label,
even though same-frame substitution after forcing returns `fun` correctly.

**Exact required change:** add the following to Section 5.4 and its source/
behavioral checks. After the force step, capture `substitute(rank_by)` and the
export's `parent.frame()` in the export prologue and pass those explicit values
to the implementation; it must evaluate that expression against its completed
rows with the captured caller environment. Capture `substitute(.filter)` and
its missing flag in each grid export and pass them explicitly. Capture
`substitute(metric)` in the PBO export and pass it as the label expression;
`metric` itself remains forced. Do not recapture forwarded formal symbols in
the implementations. Permit these inert captures and the stated flags/
normalization between the force step and the single preserve call, while still
forbidding export-frame cleanup. Add witnesses for a column-based ranking,
caller-local ranking helper, both grid filters and omitted filter, and a named
PBO callback retaining its existing metadata label. A corrected expression/
environment transport probe succeeded. This preserves existing evaluation
semantics under decisions (14)/(15); it chooses no new boundary.

### N2 - P2: candidate-method wrapping contradicts the partition and promotion census ledger

**Evidence:** `note:543-547,554-558,879-897,1010-1011,1041-1043`;
`dev/bench/v0_2_3_rng_baseline/probe.R:226-227`;
`R/sweep.R:567-582,849`.

Section 5.4 explicitly puts both steps in `ledgr_candidate.default`, as well as
the walk-forward method. Appendix A still puts the default method in H, defined
as not wrapped. More consequentially, the unchanged census promotion expression
is `ledgr_promote(..., ledgr_candidate(sw, 1L), ...)`. Decision (15)'s first
step evaluates that candidate argument, including its method's restore, before
the promote save. The trace covers the entire expression, not just frames
entered after that save. The ledger's claim that promote has only two wrapper
entries is therefore false.

**Failure scenario:** implement the method wrappers exactly as Section 5.4
requires. Correct source fails the H-not-wrapped partition and correct census
rows 04/09 fail their frozen counts. An in-process model using the production
fixture and promotion expression observed, in order,
`ledgr_candidate.default`, `ledgr_promote`, `ledgr_run`, with absent entry states.
All other operational paths had the ledger's one outer entry.

**Exact required change:** retain the two operational method wrappers; classify
`ledgr_candidate.default` as W. Correct the S3 partition to W 2/H 41/N 50 and
update every summary/shape-check list (exports stay 15/55/111). Define E as all
preserve entries in the traced case, including supplied-argument evaluation.
Set promotion E/preserve to 3. Row 04 then has query 3, mutation 3,
`rngkind_calls` 6; row 09 has query 4, mutation 4, `rngkind_calls` 8 (S remains
1). Other listed cells are unchanged. Include the candidate-argument edge in
the independent call ledger and correct the after-LDG-3158 staging counts too.
Do not precompute that argument outside the observed expression or change the
registered fixture to recover the old ledger. Qualify the absent-state fixture
claim as successor-only, as described under F3.

### N3 - P2: blank copy rows coerce the new logical/integer schema to character

**Evidence:** `note:833-847`;
`dev/bench/v0_2_3_rng_baseline/probe.R:222-225,236`;
`dev/bench/v0_2_3_output_freeze/lib.R:150-168,171-175`;
`records/census.csv:1`.

The new schema declares logical/integer counter columns, but says every new
column in copy rows 03/08 is `""`. Following the existing copy-row assignment
and row binding coerces all seven new columns to character. The canonical
writer records their actual classes in its typed header. The original 13
columns are already all character for precisely this reason; that does not
make a new logical/integer schema plus literal blank cells implementable.

**Failure scenario:** a correctly typed observer assembles the required copy
rows, then produces `entry_seed_present:character` and character counter
headers, failing the declared successor schema. I reproduced that coercion in
R independently of the comparator.

**Exact required change:** preserve the seven declared types, but specify
`NA` logical for `entry_seed_present` and `NA_integer_` for numeric observer
columns in copy rows; keep empty strings only for the two character caller
columns. Freeze those typed missing cells and resulting canonical headers in
the comparator. Keep the original 13 fields unchanged. Operational rows must
still have FALSE/nonmissing exact integer counts. This concerns only the new
observer schema; it authorizes no change to original records or fixtures.

## Optional

- **O1:** correct `note:511-512`: the specified source guard forbids unowned
  `set.seed`/`RNGkind`, not every RNG function. For example, it does not reject
  `runif()` in a default. The current defaults are safe by inspection and the
  constructor probes above. Say that, or separately specify a default-expression
  guard if desired; do not claim the existing allowlist proves it.
- **O2:** make R10's source-marker fixture explicit. For each seeded/unseeded
  walk-forward results object, replace/remove its *results attribute*, then
  extract the candidate and check its copied old/missing marker and early
  promotion refusal. Repeat under R10 and require failure. Corrupting only the
  completed candidate's provenance would test validation but would not expose
  R10's re-derivation bug. The mutation is a proper reversal of the copying fix,
  and the named predicate is appropriate; freezing this fixture removes an
  avoidable ambiguity in the Section 6 matrix.

## Optional items from the first review and regression spot-check

- R3 now requires caller rows 13/15 and a genuinely drawing unseeded run and
  dynamic routes to fail; it correctly does not require flat run rows 01/05/09
  to change after storage neutrality (`note:632-635,822,933`).
- B5 now states bounded endpoints and both directions. Independent integer
  recomputation gives the stated add-control 9481. The optional reproduction-key
  and promotion metadata fields landed at `note:720-721`.
- Reading (i) is qualified at `note:127-138`: same calendar and execution seed;
  no promise for an overlapping timestamp on a longer calendar. Walk-forward
  promotion uses the full experiment run, not the old shorter window.
- R9 undoes centralized seeding by reinstating a direct fold-envelope
  `set.seed`, which necessarily fails `set_seed_callers` (and the kind column
  if restored to its original call). R10 undoes copying rather than merely
  corrupting an observer; its extraction witness should be explicit (O2).
  Both are specified to reach production operations; crash/scope failure is
  explicitly insufficient (`note:923-940`). Neither was executed against a
  future implementation in this review.
- Arithmetic/platform reasoning and all 63 goldens are unchanged from the
  reviewed input. I independently recomputed the goldens with masked Python
  integers; all match. B1-B6 and their controls retain the first review's
  definitions/results apart from B5's endpoint clarification. I did not rerun
  the full statistical suite.
- The complete A0 successor subsection is unchanged byte-for-byte in normalized
  text. A1-A5 still restrict marker/config/economic changes; the independent
  sequential pulse-rule model and worker equality requirement remain. The
  `store_rng` model and its two numeric equalities are retained separately from
  the pulse model. No blanket economic allowance was introduced. Those economic
  models were not rerun here.
- Identity still changes seeded config/hash/default run IDs and the store
  binding fingerprint; snapshot content identity, unseeded config/hash and
  candidate/window seed derivation stay unchanged. Marker propagation is
  strengthened as required by F2. The constant still matches the store-gate
  binding rule. This stays within
  `contracts.md#contract-strategy-reproducibility` and
  `contracts.md#contract-execution-fold-core`, with the cut's expressly pending
  behavior changes; acceptance alone does not change shipped behavior.
- A parsed-source spot census found the same 27 operational DBI appends, three
  seeding sites and no operational `RNGkind` call on the current product. No
  product/NAMESPACE/RNG-baseline/A0 change intervened during this review.

## Commands run and exit codes

All shell paths were absolute. Multiline R/Python probes were passed on stdin
(`@' ... '@ | Rscript --vanilla -` / `python -I -`), without saved probe scripts.
R used `pkgload::load_all(root, quiet=TRUE, compile=FALSE)` and temporary stores.
Namespace/attached/S3 replacements were process-local models. Only this review
file was written in the repository. No excluded file contents were read. No
timing runner, full package tests, package build/check, baseline writer or gut
runner was run. No result below is performance evidence.

| Command / invocation | Exit | Result |
| --- | ---: | --- |
| Initial `git -C C:/Users/maxth/ledgr-wt/ws2-rng status --short` and initial range `diff` | 1 each | Ownership/discovery refusal. Used the supplied explicit gitdir fallback; no global config change. |
| `git --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws2-rng --work-tree=C:/Users/maxth/ledgr-wt/ws2-rng` with scoped `diff 607ce382..d7a68d9d`, `diff --stat`, `status --short`, `rev-parse HEAD`, `log -3 --oneline`, scoped `diff d7a68d9d` and `show` | 0 each | Response and input-identity checks. Concurrent HEAD advanced to `6924814e`; the reviewed note, R/, NAMESPACE, baseline and A0 inputs stayed unchanged. Only unrelated ticket evidence was added; decision line 166 is identical to d7a68d9d. No timing conclusions were used. |
| `Get-Content -LiteralPath <absolute file>` ranges; `rg -n <patterns> <absolute R/design/probe paths>` | 0 each | Authority, original review, note, census, capture, callback, closure and source-guard inspection. Broad truncated searches were followed by narrower reads. |
| R signature/default and nested-function census | 0 | 181 exports/93 methods; all W/default signatures and exported nested-function owners inspected. |
| Python NAMESPACE/set comparison | 0 | Exact textual W/H/N sets, no omission or overlap for exports and S3 methods. |
| R forcing/capture/cleanup toy shapes | 0 | Supplied seed/dots/missing/default/error behavior passes; exposes split label/rank behavior and export-frame cleanup leakage. |
| First R append/wrapper census model | 1 | Model patched namespace bindings but missed pkgload's attached public bindings and registered method table; discarded call-count result. Fixture absence alone was observed. |
| Corrected R append/wrapper census model, including public bindings/method table and NA-to-NULL window repair | 0 | All eight successor case entries absent; promotion has three preserve entries; every other operational path one. Production fixtures were unchanged. |
| R signal/adapter/seeded-run/B-1 probe | 1 | Direct callable checks and seeded 19-fill repetition pass; final date comparison failed because helper timestamp vectors carry names. |
| Corrected R B-1/default/schema probe | 0 | Compared un-named timestamp values; intended two samples pass, force removal fails; constructor defaults preserve RNG; blank-copy coercion reproduced. |
| R unchanged baseline census with added entry-state observation | 0 | Original seed/read counts reproduced; all eight base case entries have a present seed, unlike the successor precondition. Only definitions were loaded from probe.R; its runner was not executed. |
| R actual sweep-review/grid implementation-split probes and explicit capture correction | 0 | Original calls pass; naive split has the named rank/grid failures; explicit original-frame expression/environment capture works. |
| R ranking draw/error/interrupt shapes and parsed-source census | 0 | Restore predicates pass; 27 appends, three original seeding owners, no RNGkind. |
| Python independent goldens, B5, unchanged-section comparisons and input hashes | 0 | All 63 goldens, add 9481; arithmetic/goldens/A0 subsection unchanged. |
| Python pinned-note and decision-line comparison | 0 | Working note and operative decisions identical to d7a68d9d despite concurrent unrelated commits. |
| Final review/header/UTF-8/input checks and status | 0 | This review is the reviewer's only repository write; scoped input checks remain clean. |

Input fingerprints: note SHA-256
`047d56d89587e9ff297620be76e7fea07584ffc23cdfb3281a26a147087b1c96`;
baseline `probe.R`
`43b565b0f5c0fcbba07b096bb9dd4c7f8fa7e0a7cecb5039c2e460ae5669e827`;
baseline `records/census.csv`
`0213a6b83c9e9c15cce6fd11038c3cc4e2cd5624cda062d41742a737dcd0dad1`.
R 4.6.1 emitted locale-startup warnings. The signal fixture emitted expected
last-bar-no-fill warnings; its assertions passed before the separately reported
date-name comparison failure.
