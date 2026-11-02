# Cut 8 Review: Hot-path Ban-list Test

Mode: independent clean-context Type 1 cut review with adversarial input check.
Reviewer: Codex.
Base: `e04786ef`; reviewed head: `48a25dcf53b47a093eb9d935ae08bc55c656d740`.
Branch: `claude/rule17-banlist`.
Date: 2026-11-02.
Verdict: **NEEDS_TYPE_2**.

The chore is necessary and its grain is honest: one workstream establishes one
guard, with serial implementation, runtime evidence and integration tickets.
Keeping product removal in WS8/WS14a is correct. However, the proposed guard
misses existing pulse work and JSON, and several ordinary R rewrites evade both
its static count and its runtime comparison. The pulse boundary and blanket
signal exemption require design disposition, not implementation discretion.
Retain the maintainer's broad decision (1); revise how it is enforced.
(`tickets.yml:1011-1022`, `:1052-1066`, `:1122-1145`, `:2996-3069`.)

Citation convention: `tickets.yml` and the worktree `macro_plan.md` are in this
packet; `probe/` means `dev/bench/v0_2_3_hot_path_bans/`. All other relative
paths are from the reviewed worktree. **Main macro** means the separately read
`C:/Users/maxth/Documents/GitHub/ledgr/inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md`;
it is authority context, not content present at the reviewed head.

## Necessity and scope

The accepted rule calls for this test in the next drafted cut and permits an
initial baseline; it does not require this chore to optimize the product.
The nine banned base operations match that rule. Keeping `collapse::fmatch`,
`duplicated` and `order` outside this particular list is correct. The manual's
seven shapes remain broader review criteria: this detector cannot certify
absence of quadratic validation, discarded work or environment-copy costs.
(Main macro:124-136; `tickets.yml:1077-1085`, `:1129-1134`;
`inst/design/manual/optimization_coding_style.qmd:74-127`.)

An exact baseline, including failure on decreases, is a useful improvement over
a ceiling: deleting a call must retire its allowance before another cut can
reuse it. The test-only identity declarations are appropriate; no schema, API,
economic or compiled-default decision is needed. The three tickets are parts
of one claim, not three independent performance wins. These decisions should
survive revision. (`tickets.yml:1090-1096`, `:1117-1127`.)

## Numbered findings

### 1. Blocking design: five stage roots omit the pulse envelope itself

**Established:** scheduled-skip decision and plan execute between stage calls,
at `R/fold-engine.R:1921-1942` and `:1953-1965`. The former already contains
`%in%` at `:674`. Re-running the broader helper scan yielded its reported
344 reached functions and 251 calls, but neither skip helper was reachable;
scanning the omitted decision helper alone reported `%in%`. The runtime probe
only records while stage depth is positive (`probe/probe_dynamic.R:11-16`).

**Failure:** adding `match()` to either private skip helper escapes the proposed
export/S3 surface table and the runtime witness even when a workload executes
scheduled skips. Stop handling and code written directly between stage calls
have the same boundary problem (`R/fold-engine.R:1911-1914`, `:1943-1946`).
This is stronger than the admitted limitation about an unexercised path.

**Smallest fix:** amend decisions (1), (6) and both implementation tickets to
cover the complete repeated pulse body, including its inline expressions,
skip branches and stop/drain paths. A test-side AST boundary for that body plus
its callees avoids pulling all once-per-run setup into the baseline. The runtime
boundary must agree with it. Add a mutation in a skip helper and one directly
between stages; each must fail. Do not change product structure just to expose
a testing hook. (`tickets.yml:1052-1066`, `:1110-1113`, `:3004-3019`.)

### 2. Walker contract: commonplace indirection and lexical collisions lose calls

**Executed evidence:** the existing scanner reported `match` for a direct call,
but no hit for these synthetic package-owned reached functions:

| Body / form | Why the probe loses it |
| --- | --- |
| `do.call("match", list(x, x))` | String targets are ignored. |
| `f <- match; f(x, x)` | Local function aliases are not resolved. |
| `lapply(list(x), base::match, table = x)` | Qualified function arguments are not counted. |
| `lapply(x, FUN = function(z) match(z, z))` | Named closure gets a node but no invocation edge. |
| `state <- list(run = function(z) match(z,z)); state[["run"]](x)` | Literal `[[` invocation has no member edge. |
| `function(x = match(1,1)) x` | Only the body, not default arguments, is scanned. |

Sources: `probe/probe_static.R:35-62`, `:94-126`. The same member omission
applies to an environment or `fold_state` holding a callable under `[[`/`get`;
function-valued arguments and factory returns need explicit target treatment.

There is also a collision, not just an unresolved edge. In
`a <- function() { f <- function() match(x,x); f() }` and
`b <- function() { f <- function() 1; f() }` within one root, followed by
`a()`, the probe overwrites `root$f` with the second definition and reports no
hit. `collect()` retains the outer owner while descending, and `add_node()`
overwrites by ID (`probe/probe_static.R:29-40`, `:60`). The proposed
`owner$name` contract inherits this ambiguity (`tickets.yml:1071-1075`).

**Failure:** moving an existing direct call to these forms produces a freely
regenerable decrease. Base `match` is not among the namespace functions traced
by the runtime witness, so executing the rewritten function need not catch it.
(`tickets.yml:1093-1095`; `probe/probe_dynamic.R:18-28`.)

**Smallest fix:** bind lexical-scope identities with collision detection; scan
defaults and invoked named inline functions; resolve literal string targets,
qualified function values, simple local aliases and literal member indexing.
For unresolved package-owned callable sites, require a reasoned target/terminal
declaration instead of silently dropping the edge. Add the cases above to the
small synthetic namespace. This is a bounded conservative analyzer, not a
request to interpret arbitrary user strategies. (`tickets.yml:1131-1133`,
`:3015-3019`.)

**Over-approximation check:** `root <- function(x) x$run()` reaches both
`hot$run` and an unrelated `cold$run` in the synthetic probe, counting the
latter's `match`. The global member-name union explicitly permits this
(`probe/probe_static.R:76-81`, `:111-114`; `tickets.yml:1072-1076`). Accept
bounded extra rows, but retain root/edge provenance so each is explainable;
do not report total baseline calls as measured hot executions. Counts also
cannot distinguish moving a call within the same node while preserving its
count. Source review still matters; do not expand this chore into a general
performance proof.

### 3. Runtime witness: the positive control is real, but weaker than its claim

**Established:** deleting the declared cost edge from the probe graph removes
`ledgr_cost_resolver_from_model$resolver` and `ledgr_cost_model_resolve` from
reachability. The recorded trace contains the latter
(`probe/evidence/dynamic_seen.txt:32`). The closure calls that function
(`R/cost-model.R:368-380`). Thus this control can fail through a real observed
descendant; it is not vacuous.

But `ls(ns)` plus `trace(name, where = ns)` instruments namespace bindings,
not factory-returned/local closures (`probe/probe_dynamic.R:18-28`). It cannot
identify the missing resolver closure as demanded by `tickets.yml:3048`.
**Failure:** an undeclared returned closure doing only base operations, or
calling descendants already reachable elsewhere, escapes this witness.

**Smallest fix:** accurately specify this control as detecting the lost
namespace descendant, and add a separate callback-only control with no unique
namespace descendant. Either instrument that package-owned closure, or require
the static unresolved-callable gate from finding 2 to reject its missing edge.
Do not claim namespace tracing proves all nested closures covered. Trace
installation failures must fail or have explicit accepted exclusions, not be
silently converted to `FALSE` as in `probe/probe_dynamic.R:24-28`.

Worker coverage needs a corresponding acceptance amendment. A0 explicitly
includes two-worker paths (`dev/bench/v0_2_3_output_freeze/fixtures.R:251-267`),
and workers load their own package (`R/parallel-workers.R:293-313`,
`:330-332`; `R/sweep.R:366-369`). **Inference from that process boundary:**
tracing only the parent does not establish worker coverage. Require trace
installation, observations and an omission control in each executing worker,
with a workload/process census. This is test tooling, not a product change.

### 4. JSON list omits the package's actual serialization backend

**Established:** reconciliation diagnostics are serialized row by row through
`ledgr_fold_reconciliation_detail()` (`R/fold-carrier.R:848-870`). That helper
calls `ledgr_json_write_canonical_v2()` (`R/fold-engine.R:97-105`), which calls
`yyjsonr::write_json_str()` (`R/config-canonical-json.R:82-86`). Both package
nodes are reachable in the helper scan; neither has a JSON hit. The recorded
dynamic trace even sees the writer (`probe/evidence/dynamic_seen.txt:64`).
Decision (3) and the probe omit both names (`tickets.yml:1079-1084`;
`probe/probe_static.R:13-15`).

**Failure:** a new direct call to the current writer or yyjsonr backend is not
counted at all. Replacing a recognized JSON wrapper with this writer can appear
as a legitimate baseline reduction. Runtime reachability is not a JSON check.

**Smallest fix:** inventory current serializers/parsers and count the actual
boundaries, including the v2/verbatim/NDJSON wrappers and applicable yyjsonr
read/write functions (`R/config-canonical-json.R:68-99`). Preserve qualified
identity. Add direct-backend and wrapper-call mutations. This implements rule
14, not a new category of ban. Do not remove these product calls in this chore.

Also avoid making arbitrary package wrapper bodies opaque. A `match()` added
inside a JSON leaf otherwise leaves its call-site allowance unchanged
(`probe/probe_static.R:97`, `:105`; `tickets.yml:1083-1084`). Scan package
wrapper bodies for the base bans, while stopping traversal into external
serializer implementations; define counting so the same serialization is not
accidentally counted twice.

### 5. Blocking design: a signal's name does not establish a cold path

**Executed evidence:** `message(match(x,x))` and
`ledgr_check_abort(match(x,x))`, with `ledgr_check_abort <- function(x) x`,
both report zero hits. The exemption covers all signal arguments by bare name
or regex (`probe/probe_static.R:18-19`, `:115-123`), exactly as proposed in
`tickets.yml:1085-1089`.

**Failure:** normal per-pulse messages/warnings, a returning helper renamed
`*_abort`, or an error handled inside the pulse can repeatedly evaluate banned
work without a baseline row. Moving work from a signal's guard to its argument
can clear the detector without moving it off the hot path. Abort arguments may
also carry computed condition data, not just message text.

**Smallest fix:** remove blanket name-based exemptions. Count signal arguments
by default; any genuinely cold diagnostic construction gets a site-specific,
reasoned exception reviewed against control flow and binding identity. Keep a
negative witness for normal warnings/messages and a returning lookalike helper.
The accepted broad scope is retained; the proposed exemption is what changes.

### 6. Exact ratchet is sound only while coverage cannot shrink silently

**Established:** regeneration freely removes/lower counts; edge validation
only checks existing endpoints; the planned review sentence names baseline
and declared-edge diffs, not the surface classification (`tickets.yml:1090-1098`,
`:1114-1116`). The surface existence check cannot judge a reason's correctness
(`:3019-3024`).

**Failure:** changing a live export's `per_pulse` classification to false, or
removing a still-needed edge on an unexercised path, shrinks the scan. Regeneration
can then bless the loss of coverage as if product work had been deleted.
Renaming an ordinarily reached helper alone is not a loophole: it creates a new
row needing a reason. Findings 2, 4 and 5 describe ways to avoid that new row.

**Smallest fix:** retain exact equality and the existing maintainer acceptance
duty. Extend it to surface, root, exemption and edge changes, with a reachable-set
diff and explanation for lost coverage. Distinguish actual call removal from
analyzer/coverage changes in regeneration output; require accepted reasons for
the latter. Reject duplicate keys and blank reasons. Demonstrate the sequence
delete call -> old baseline fails -> regenerate -> reintroduce call fails, and
exercise the actual regeneration tool for new/increased/unreasoned rows.

### 7. Gates need anti-vacuity checks and an explicit budget disposition

The synthetic cases in LDG-3191 are a useful start, but omit the inexpensive
bypasses above. For LDG-3192, an empty observation set passes a subset comparison;
registration of one heavy block does not prove each workload/path executed.
The prototype has no per-workload observation assertion and ignores trace
failures (`probe/probe_dynamic.R:24-28`, `:32-47`).

**Failure:** a skipped workload, disabled tracer or unobserved worker can yield
a green block and census without testing the promised scope.
**Smallest fix:** bind nonempty pulse/trace observations per named workload and
executing process, assert completion of the requested path, and make disabling
tracing or omitting one required path fail. Exercise the edge-removal control
against the final merged graph; global over-approximation can make the present
descendant independently reachable. Reconcile the new block with the registered
checker (`tickets.yml:3045-3050`; `tests/heavy-protocols.yml:1-7`).

The 3 s bound is **unestablished, not disproved**. The recorded 5.1 s source
probe includes startup/parsing; my roughly 8 s shell/R probe also includes them.
Neither measures the proposed installed, in-process test
(`probe/findings.md:90-94`; `tickets.yml:3028`). Measure the complete added
ordinary-fast membership, including synthetic/surface checks and repeated
namespace walks, not just one comparison block.

There is a separate closeout contradiction: LDG-3193 requires fast-profile
success while the documented suite already takes about 211 s against 112 s
(Main macro:570-578; `tickets.yml:3063-3068`; `tests/test-gates.yml:1`).
**Failure:** a functioning test under 3 s still cannot satisfy the unchanged
whole-suite clock, and recording only its delta is not a pass.
**Smallest fix:** explicitly separate functional profile results, this test's
measured budget and the inherited full-lane failure. The maintainer must route
that existing blocker/closeout exception, or sequence closure after its owner
fixes it. Do not widen the bound, remove tests or quietly interpret delta as
success; follow the registered three-run median procedure
(`tests/README.md:25-33`). No full-suite timing was rerun for this draft review.

### 8. The surface table needs a coverage argument, not just a complete census

**Established:** the proposed table is broader than the probe, which roots
helpers by a small file list (`probe/probe_static.R:139-149`;
`tickets.yml:1055-1068`). History matrix subsetting, replacement, Math/Ops and
coercion are registered methods (`NAMESPACE:5-12`), and history readers are
exports (`NAMESPACE:152-155`). The two WS5 strategies exercise target-adjust,
equal weighting, hold/state and raw quantity construction; they are not a
complete authoring-API exercise (`dev/bench/v0_2_3_ws5/semantic_ports.R:96-108`,
`:133-150`). Do not misreport this as evidence that the future table already
omits those methods: it has not been written (`tickets.yml:2999-3007`).

**Failure:** a history-matrix operation inside a strategy can be wrongly marked
cold without a missing-row failure; a newly introduced package callback using
the forms in finding 2 can escape even when its exported factory is classified
hot. Private skip helpers in finding 1 are an existing example escaping both
surface roots and runtime boundary, independent of workload choice.

**Smallest fix:** require a reviewed map from each callable family to static
roots, returned package closures and representative runtime coverage or an
explicit uncovered-path statement. Include history/S3 group methods, signal
wrapper callbacks, sizing/selection/target families, service factories and
scheduled skips. Generic dispatch is not resolved by scanning the generic's
body; explicit method roots are the bounded solution. No S4 definition was
found in R sources in this review; if added, require classification/declared
targets rather than silently assuming the export/S3 census covers it. Preserve
the explicit exclusion of user-authored strategy bodies (`tickets.yml:1131`).

### 9. Reconcile authority and merge identity before acceptance/closeout

**Established:** this worktree's macro ends its rules at 16 and has WS14, not
the cited rule 17/WS14a amendments (`macro_plan.md:106-121`, `:460-499`). The
main checkout contains rule 17, the WS8 fill-heavy amendment and WS14a (Main
macro:124-136, :436-450, :529-578). Thus the authority exists, but the reviewed
artifact is not self-contained (`tickets.yml:1023-1031`).

**Failure:** another reviewer of this head cannot recover the cited scope or
budget context, and a concurrent cut can invalidate both numeric references
and the baseline while leaving plausible-looking evidence.
**Smallest fix:** pin/incorporate the accepted authority revision on the merged
base; check cut/workstream/ticket identifiers against the WS7/WS8 draft before
landing, and renumber all references if the other cut reserves them first.
The existing renumber/second-merge regeneration policy is correct; no collision
was established here (`tickets.yml:1019-1022`, `:1126-1127`). Regenerate and
attribute baseline changes, then rerun controls on that final tree as already
required (`:3062-3068`). Extend the future review_obligations sentence as in
finding 6. Its absence today is not an implementation failure: LDG-3193 is
pending. Clarify that tests/README and the macro cross-reference are permitted
test/packet documentation edits under the otherwise correct no-user-docs
release-impact declaration (`:1117-1120`, `:3060-3069`).

## Evidence and review limits

Read the draft, source probes, retained evidence, manual, test protocol and
workload definitions before executing probes. Executed the existing source
scanner with outputs under R's session temp directory, then mutated only its
in-memory synthetic graph. Reproduced 344/251, the scheduled-skip omission,
zero-hit JSON nodes, the cost-edge reachable-set difference, the table in
finding 2, the lexical overwrite, global member over-approximation and the two
signal bypasses. These are probe results, not results from a future installed
walker. Retained runtime evidence was inspected, not represented as a fresh
run of all A0/WS5/worker paths (`probe/findings.md:59-69`, `:90-94`).

The in-memory probe loads the published scanner without editing it:

```r
pkg <- "C:/Users/maxth/ledgr-wt/rule17-banlist"
e <- new.env()
e$commandArgs <- function(...) c(pkg, tempdir(), "helpers")
sys.source(file.path(pkg, "dev/bench/v0_2_3_hot_path_bans/probe_static.R"), e)
intersect(e$seen, c("ledgr_fold_scheduled_skip_decision",
                    "ledgr_fold_scheduled_skip_plan")) # character(0)
e$scanned[["ledgr_fold_scheduled_skip_decision"]]$hits # "%in%"
e$scanned[["ledgr_fold_reconciliation_detail"]]$hits  # character(0)
e$scanned[["ledgr_json_write_canonical_v2"]]$hits     # character(0)
e$nodes[["review_root"]] <- quote(function(x) do.call("match", list(x,x)))
e$node_owner[["review_root"]] <- "review_root"
e$scan("review_root")$hits                          # character(0)
```

For closure cases, reset the synthetic node/alias tables, call the same
`add_node()` and `collect()`, rebuild `top`, `local` and `member_of`, then scan
and traverse from the synthetic root, exactly as `probe_static.R:29-81` and
`:151-158` do. No product function or registered fixture was patched. Used
plain Rscript via its absolute R-4.6.1 path because PATH resolution failed.
Git status/diff was blocked by unsafe-repository ownership checks; no global
Git configuration was changed. The worktree Git pointer and referenced branch
ref confirmed the head above. Only this review file was written in the worktree.

Required next step: focused Type 2 disposition of the pulse boundary,
unresolved-callable policy and cold exceptions, followed by a revised cut and
targeted re-review. This follows the cut's own Type 1 escalation rule
(`tickets.yml:1144-1146`); it does not reopen the need for rule 17 or authorize
product optimization in this chore.
