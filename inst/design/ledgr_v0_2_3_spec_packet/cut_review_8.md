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

## Re-review 1 (revision 2)

Mode: targeted Type 1 cut re-review.
Reviewer: Codex. Date: 2026-11-02.
Reviewed head: `8984329916ed3d7f75461dce5e4a21f4d2e44b26`.
Verdict: **PASS_AFTER_PATCHES**, conditional on R1-R5 below.

Revision 2 faithfully records the four maintainer dispositions: static scanning
of the loop body, refusal of unresolved callables, no error-path exemption, and
single-process runtime evidence relying on the one fold core
(`tickets.yml:1093-1100`, `:1135-1140`, `:1154-1162`). None is reopened here.
The remaining defects have bounded text patches. This verdict approves the
revised cut after those patches; implementation and close-review evidence are
still pending (`tickets.yml:3177`, `:3241`, `:3273`).

References below use this worktree, including its macro plan. The earlier
section's separate-main-checkout convention does not apply to this re-review.

### Disposition of round-one findings, in order

| Original | Status in revision 2 | Revised evidence and remaining issue |
| --- | --- | --- |
| F1 pulse envelope | Partially resolved | The complete AST loop body is now a root, including inline, skip and stop work; direct-body and skip mutations are required (`tickets.yml:1096-1100`, `:3220-3223`). The runtime window still differs: R1. |
| F2 indirection/collisions | Partially resolved | Defaults, qualified values, literal do.call, aliases, indexed members and inline callbacks are bound; unresolved targets fail (`tickets.yml:1115-1140`, `:3206-3213`). Lexical identity versus the same-name fixture needs R2; unresolved higher-order arguments need explicit R3 coverage. |
| F3 runtime limitations | Resolved in direction and controls | The witness admits its local-closure limitation, refuses trace failures without an exclusion, and covers only sequential paths as decided (`tickets.yml:1158-1182`). The namespace control now names the descendant; the callback control uses the static gate (`:3255-3260`). R1 fixes the separate boundary defect; worker tracing is no longer an obligation. |
| F4 JSON | Partially resolved | Current ledgr wrappers and yyjsonr/jsonlite functions are included; wrapper bodies remain scanned and counting is per static call site (`tickets.yml:1144-1153`, `:3214-3215`). This covers the current backend (`R/config-canonical-json.R:68-99`). Inventory weakening still needs R4. |
| F5 cold exemption | Resolved in direction | All helper and signal arguments count; both original bypasses have required witnesses (`tickets.yml:1154-1157`, `:3216-3217`). R5 reconciles the prescribed reason with initial seeding. |
| F6 regeneration | Partially resolved | Surface/declaration/root changes and departing nodes need reasons, as do new/increased rows; duplicate keys and blank reasons fail; the full delete/regenerate/reintroduce sequence is required (`tickets.yml:1183-1196`, `:3224-3227`). R4 closes the omitted inventory/analyzer-policy category. |
| F7 gates/budget | Resolved in direction | Per-path observations/completion, both controls, disabled tracing and dropped-path failures are specified (`tickets.yml:3248-3267`). Added fast membership has its own budget; inherited timing is separate (`:1197-1204`, `:3282-3288`). Boundary and fixture corrections remain R1-R3. |
| F8 surface coverage | Resolved as a cut obligation | History/group methods, returned signal callbacks, S4 discovery and a family-to-root/closure/workload or uncovered-path map are required (`tickets.yml:1104-1114`, `:3186-3195`). This is an obligation to produce evidence, not a claim that every family is runtime-covered. |
| F9 governance/base | Resolved | Authority is now present (`macro_plan.md:95-100`, `:124-136`, `:436-450`, `:529-628`). Identifier checks, full reference renumbering, final-base regeneration, controls and permitted test/packet pointers are explicit (`tickets.yml:1032-1041`, `:1205-1217`, `:3277-3289`). |

### R1. Runtime and static pulse boundaries still disagree

**Concrete scenario:** the static root includes `ledgr_time_now()` and pulse
setup before observe/settle (`R/fold-engine.R:1895-1902`). The proposed runtime
window opens only at observe/settle entry (`tickets.yml:1172-1174`). After each
stop application, the loop still calls `flush_pulse_block(ts)` before breaking
(`R/fold-engine.R:1915-1917`, `:1947-1949`, `:1970-1972`), but the window has
already closed. It also closes before the post-commit `isTRUE`/continue check
at `:1994-1996`. Thus a dynamically reached package helper in these regions can
escape the runtime comparison even on an exercised path. Static scanning still
covers these regions; the defect is the claim of matching runtime evidence.

There is a possible mismatch in the other direction on exceptions: an error
escaping before commit or stop application has no specified closing hook. A
sticky active flag can count the outer exception diagnostic as pulse work
(`R/fold-engine.R:2024-2049`). This is an implementation risk inferred from
the specified hooks, not an observed failure of an implemented witness.

**Exact patch:** replace decision (6)'s two boundary sentences at
`tickets.yml:1172-1174` with:

> The runtime boundary is the same AST-located loop body as decision (1).
> Test-side instrumentation opens before its first expression and closes after
> its last expression, or when that iteration exits by break, next, error or
> interrupt. Stop application does not close the boundary before the remaining
> in-loop drain. Unwinding clears the boundary before out-of-loop recovery or
> finalisation; there is no product change.

Add to LDG-3192's scope and acceptance:

> Boundary controls observe a synthetic package sentinel before observe/settle,
> after stop application during the drain, and after commit before iteration
> exit. Each is subject to the reachable-set comparison. A sentinel outside the
> loop after normal exit or error unwinding is excluded. Each control fails if
> its entry/exit boundary is displaced past the sentinel.

Use test-side synthetic code/instrumentation; do not add sentinels to product
files or change the frozen workload fixtures. This implements the accepted AST
boundary decision rather than adding another runtime mode.

### R2. Same name in different lexical scopes is not a key collision

**Concrete scenario:** decision (2) keys definitions by lexical path and rejects
two different definitions under one key (`tickets.yml:1117-1119`). The ticket
instead requires "two same-named local closures" to fail (`:3211`). The original
regression has `root/a/f` and `root/b/f`: these must coexist and preserve the
first closure's banned call. A literal same-name rejection would fail legitimate
distinct scopes; merely rejecting both could pass the ticket without proving
that lexical lookup works. The probe's overwriting behavior is the historical
defect (`probe/probe_static.R:29-40`, `:60`), not the revised implementation.

**Exact patch:** replace the `:3211` witness with:

> Two different closure definitions assigned to the same lexical key fail with
> that key reported. Two same-named closures in different lexical scopes have
> distinct keys; calling the first reaches and counts its banned operation even
> when the second has none. No definition may overwrite another silently.

Keep collision rejection in decision (2) and the acceptance at `:3233`, qualified
as a same-key collision. Add both positive and failing cases to the synthetic
namespace. No product restriction on ordinary shadowing is authorized.

### R3. Make the unresolved gate cover higher-order callable arguments explicitly

**Concrete scenario:** `function(xs, f) lapply(xs, FUN = f)` has a resolved call
head, `base::lapply`, but an unresolved invoked callable `f`. The current gate
speaks of a "call ... whose target ... cannot resolve" (`tickets.yml:1135-1139`),
and its mandated negative witness only says "call through an argument"
(`:3212-3213`). An implementation that checks unresolved call heads can pass
`f(xs)` while silently dropping `FUN = f`; it can still pass the specified
bare/qualified known-function and named-inline witnesses (`:3207-3210`).
The external apply implementation is intentionally not traversed
(`:1151-1153`), so the missing invocation will not be found there.

**Exact patch:** append to decision (3), mirrored in LDG-3191:

> Unresolved invoked function-valued arguments count as unresolved callable
> sites even when the enclosing call head resolves, including apply-family
> FUN arguments. Declarations identify the lexical node and callable site,
> including the invoked argument where applicable. A declaration for one site
> does not discharge a newly added site. A synthetic lapply(xs, FUN = f) fails
> until that site's callable is declared; deleting its declaration fails again.

This clarifies the maintainer's fail-until-declared decision. Known external
targets can remain terminals; it does not require scanning arbitrary dependency
implementations or user strategy bodies.

### R4. JSON inventory and analyzer policy can still weaken counts freely

**Concrete scenario:** remove an active JSON function from the inventory, keeping
its external call resolved as a terminal. Reached nodes, roots, declarations and
surface classification can remain unchanged while JSON counts decrease. Decision
(7) permits lower counts freely and lists none of the JSON inventory or analyzer
policy among the reason-required changes (`tickets.yml:1183-1192`). A synthetic
direct yyjsonr case alone need not detect removal of a different jsonlite/parser
entry (`:3214-3215`). The same loophole applies to weakening counting/resolution
rules while retaining the reached nodes.

**Exact patch:** add this bullet to decision (7)'s reason-required list:

> A change to the JSON inventory or analyzer policy, including callable
> resolution, ban counting and the pulse-loop locator; these changes are
> distinguished from product call removals even if the reachable set is stable.

Add those diffs to decision (8)'s review duty and LDG-3193's sentence. Require
LDG-3191 to retain the prior policy/inventory identity as regeneration input and
demonstrate refusal without a reason when an active JSON entry is removed while
reachability is unchanged. Validate inventory identities against installed
functions and add a failing missing-entry inventory check using an independent
expected backend case. Reason acceptance stays with the maintainer. This closes
coverage loss; it does not enlarge the accepted ban list.

### R5. Initial seeding contradicts the error-path reason requirement

**Concrete scenario:** decision (5) requires a genuine error-path row's reason
to be "error path" (`tickets.yml:1154-1157`); LDG-3191 requires seeding the
baseline with "initial baseline, cut 8" (`:3199-3201`). One reason field cannot
satisfy both literal instructions for the same row.

**Exact patch:** replace the baseline seeding sentence with:

> Seed ordinary rows with reason "initial baseline, cut 8". Rows established by
> review to occur only on an error path use reason "error path". Mixed-path
> node/call rows remain ordinary rows. Both kinds retain their full counts and
> participate in exact equality; neither reason grants an exemption.

The mixed-path qualifier follows the chosen node/call/count grain. Add one
synthetic error-only baseline row to verify that its reason does not suppress
counting or permit a count change.

### Acceptance audit and timing disposition

Every revised acceptance category has a concrete failing construction after
R1-R5. Close review should apply the following bounded mutations, rather than
infer detector quality from a green seeded baseline:

| Gate | Required failure / successful counterpart |
| --- | --- |
| Pulse-loop locator | Remove or duplicate the structurally identified pulse loop inside the lexical run_loop; zero/two candidates fail. An unrelated loop must not be selected. Add these explicit locator fixtures to LDG-3191 (`tickets.yml:1096-1100`, `:3222-3223`). |
| Collision and resolution | Same-key duplicate fails; distinct-scope names preserve counts (R2). All listed edge forms count their known bans; direct and higher-order unresolved targets fail until declared (R3); nonexistent declared targets fail (`:1135-1140`, `:3206-3213`). |
| JSON and signals | Direct backend, package wrapper and base ban inside wrapper each count; inventory weakening fails (R4). Signals/lookalike helpers never suppress counts; error reasons do not exempt (R5) (`:3214-3217`). |
| Exact baseline and regeneration | Add/remove a call; delete/regenerate/reintroduce; change each surface/root/declaration/policy input; remove a reachable node; supply duplicate keys or blank reasons. Unreasoned changes fail under decision (7), including stable-reachability policy loss (R4) (`:1183-1192`, `:3224-3227`). |
| Namespace runtime control | Remove the cost-resolver declaration and require loss of the named observed descendant on the final graph (`:3255-3257`, `:3282`). If another edge keeps it reachable, the control has not met acceptance; do not edit the reachable set to manufacture loss. |
| Callback control | Remove the declaration of an unresolved callback with no unique namespace descendant; the static unresolved gate must fail (`:3258-3260`). No assertion that namespace tracing observes local closures is needed. |
| Runtime validity | Disabled/uninstalled tracing and one omitted required path fail. Each path has its own observations and expected completion outcome, rather than a cumulative seen-set inherited from an earlier path (`:3248-3266`). Expected FAILED/INCOMPLETE workloads complete their protocol when their recorded expected outcome is obtained, not only on DONE. Apply R1 boundary controls as well. |
| Packaging/profile evidence | Installed/source-free execution, the 3 s added-membership bound, process isolation and reconciled heavy census remain required (`:3235`, `:3267`); missing evidence cannot be recorded as success. |

Decision (9)'s separation is sound and non-evasive. It measures all added fast
membership in-process, retains the 3 s limit, reports functional results
separately, and explicitly denies treating a small delta as a whole-lane pass
(`tickets.yml:1197-1204`, `:3228-3235`, `:3282-3288`). The inherited 214.22 s
functional run and accepted 112 s miss are recorded (`tickets.yml:3154-3155`);
WS14a owns the test-suite response (`macro_plan.md:570-578`, `:621-628`).
The old source-probe timing is not evidence of compliance with the new bound
(`probe/findings.md:90-94`).

At closeout, retain the ordinary timing record/checker outcome under the existing
median procedure (`tests/README.md:25-33`), alongside the accepted inherited miss.
Functional success does not turn that checker outcome green. A breach of this
cut's own 3 s bound, a new functional failure or a missing heavy path remains
this cut's failure; none is covered by the inherited exception. No timing gate
or product change is silently authorized by this re-review.

Evidence limits: read revision 2, the current pulse loop, JSON implementation,
authority, test protocol and old probe/evidence description before assessment.
These remaining findings follow from text and code boundaries; no runtime
measurement was needed to settle them. The old probe was not rerun as if it
implemented revision 2, and no future gate is claimed to have passed. The branch
ref was read directly to confirm the head; no global Git configuration changed.
Only this appended review section was written; no commit was made.

## Focused review (revision 3, census delivery)

Mode: focused Type 1 review of delivery change only.
Reviewer: Codex. Date: 2026-11-02.
Reviewed head: `bef6dfb6e00d844dd198a2bf7bf6d8a5447ca58f`.
Verdict: **PASS_AFTER_PATCHES**, conditional on C1-C4 below.

Census delivery is suitable for rule 17. Revision 3 retains the substantive
loop, lexical identity, unresolved-callable, JSON, exact-ratchet and runtime
obligations, including R1-R5 (`tickets.yml:1149-1245`, `:3278-3319`,
`:3330-3366`). Those decisions are closed. The remaining patches specify how
the new delivery works without weakening isolated tests, confusing specialized
census projections with the lexical graph, or leaving existing records stale.
No new Type 2 disposition is required for these bounded delivery corrections.

References use this worktree; `tickets.yml` is in this packet and `census/`
means `dev/bench/v0_2_2_pre_cran_removal/census/`.

### 1. Gate preservation and isolated-context enforcement

One former acceptance criterion is intentionally replaced: revision 2 required
an installed-library scan without R/ sources. Revision 3 parses source, with
record comparison only in a checkout (`tickets.yml:1129-1149`, `:3320`). It
cannot claim source-free installed enforcement. This is consistent with the
maintainer's selected census delivery, provided the record-backed checkout
check remains mandatory at closeout (`:3381-3387`). Rule 17 can be enforced
there; CRAN need not carry the development baseline. CRAN scan execution is
portability evidence, not evidence that its package matches the baseline.

The actual precedent locates a source package, including `00_pkg_src/ledgr`,
or uses `LEDGR_TEST_SOURCE_ROOT`; it does not recover R syntax from the installed
namespace (`tests/test-control-plane.R:12-52`). Checkout detection uses `.git`
or `.Rbuildignore`, not the presence of dev/ (`tests/testthat/helper-test-control-plane.R:3-6`).
The built package excludes dev/ (`.Rbuildignore:4`), while LTB-0331 still loads
tools and scans R/ in its located source tree
(`tests/testthat/test-codebase-contracts.R:114-139`).

### C1. "Only asserts that the scan runs" understates the precedent

**Failure scenario:** an implementer follows `tickets.yml:1145-1146` literally
and puts all comparisons, negative witnesses and malformed-input checks under
the checkout guard. The isolated test then passes for an empty scan or broken
checker. LTB-0331 does more: nonempty inventories and expected production-file
coverage are asserted before the guard, and its synthetic add/remove/checker
tests and ordering assertion run after the guard in either context
(`tests/testthat/test-codebase-contracts.R:118-124`, `:142-233`). Missing dev/
in a checkout also must not become permission to skip comparison.

There is an input issue unique to this section: surface, declarations and policy
are also under dev/ (`tickets.yml:1137-1141`), so they are absent in isolated
source. The mode-branch scanner needs no equivalent tables. An isolated scan
must not silently mark unresolved sites terminal to manufacture a successful
checked result (`tickets.yml:1168-1180`).

**Exact patch:** replace decision (2)'s isolated-context bullet and mirror it in
LDG-3191's scope/acceptance with:

> Use ledgr_test_source_root() and ledgr_test_checkout_context(). In a checkout,
> missing hot-path records or inputs fail; compare the complete scan with the
> committed records. Outside a checkout, assert dev/ is absent and exercise
> source discovery with nonempty function/loop inventories. Discovery may
> return unresolved sites as data; it is not a successful record-backed check.
> All synthetic checker, locator, collision, unresolved-callable, JSON and
> regeneration witnesses run in both contexts with their explicit synthetic
> inputs. Only comparison with the development record set is checkout-only.

Add isolated-context witnesses for empty discovery and a broken synthetic
checker, plus a checkout-with-missing-record failure. This preserves the
accepted fail-until-declared rule in actual checks and follows the precedent's
test placement. No records need to be installed or copied into another fixture.

### 2. Reuse fit and permitted new code

The source index is reusable: it retains parsed expressions, parse data and
top-level definitions with full RHS ASTs
(`tools/check-codebase-contracts.R:337-380`). Its derived projections are not
the required hot-path graph:

- `call_rows()` assigns calls to top-level owners and loses qualification and
  local scope (`tools/check-codebase-contracts.R:383-389`, `:438-454`). A small
  in-memory probe put calls from `root/a/f` and `root/b/f` under owner `root`.
- `reachable_guards()` returns selected guard names, not the full reached-node
  graph (`tools/check-codebase-contracts.R:627-642`). Executing it with
  A -> B, A -> guard, B -> A returned guard for A, then an empty result for B:
  its cached partial cyclic result is unsuitable as complete reachability.
- `build_dynamic_map()` is a name-to-location reference map, not an invocation
  map. It collects literal strings from all arguments and discards call-site
  argument role (`tools/check-codebase-contracts.R:1060-1084`). An in-memory
  `get("target", mode="function")` probe recorded both target and function as
  keys. It cannot establish callable targets or declaration identities alone.

These are existing specialized behaviors, not regressions introduced by the
draft. Decision (2)'s "where they fit" permits retaining the stronger lexical
and qualified semantics rather than forcing these projections onto them
(`tickets.yml:1147-1163`, `:3243-3245`).

### C2. Shared helpers currently live behind the CLI's write path

**Failure scenario:** the fast scanner in tools/codebase-structure.R cannot
directly call source_index(), call_rows() or build_dynamic_map(): they are
defined inside the executable checker. Sourcing that checker to obtain them
executes its default report mode and writes records
(`tools/check-codebase-contracts.R:157-172`, `:240`, `:1554-1600`). Copying
them instead creates the duplicate census helpers the delivery decision is
intended to avoid. Calling them before the new pre-write check is also
impossible at their current definition positions (`:366`, `:438`, `:1060`).

**Exact patch:** append to decision (2) and LDG-3191:

> Extract reusable parsing/index primitives into tools/codebase-structure.R
> once, with existing census callers using them through unchanged interfaces
> where needed. The fast scanner must not source or execute the CLI. Preserve
> the existing census projections; add the lexical, qualified, callable-site
> graph and complete reachability needed by this contract where the existing
> projections do not fit. New contract-specific code is allowed; duplicate
> copies of shared parsing/index helpers are not. Build the index and complete
> all hot-path validation before entering the record-write phase.

Run the same synthetic input through the CLI and fast scanner to require equal
hot-path results. This is a concrete extraction allowance, not a requirement to
broaden or repair the old guard census in this cut.

### 3. Record conventions and existing tests

The seven hot_path_* tables can be an additive section like mode_branches and
mode_branch_counts (`tickets.yml:1137-1141`;
`tools/check-codebase-contracts.R:1574-1583`). They should not be added to the
six-family ledgr_census_summary() contract: it requires exactly the six declared
schemas, and LTB-0272 explicitly expects six zero row/finding counts
(`tools/codebase-structure.R:12-55`, `:77-114`;
`tests/testthat/test-codebase-contracts.R:83-110`). A separate hot-path status
line can report nodes, call sites, counted bans and unresolved sites, without
changing summary.csv. Policy/source hashes are tooling provenance, not members
of the product format fingerprint. The existing fingerprint_members metadata
counts the 23 named product bindings; adding seven CSVs must not change it
(`tools/check-codebase-contracts.R:657-680`, `:1595-1600`; `census/metadata.csv:1-5`).

LTB-0331 can remain unchanged if its exact check call stays before the first
write and its semantics stay unchanged. LTB-0271's condition inventory need not
move because new tooling functions are outside R/. LTB-0270 still requires
concrete contracts for actual test-only package seams; it must not be weakened
to accommodate the new tests (`tests/testthat/test-codebase-contracts.R:20-79`).

### C3. The absolute ban on other record changes conflicts with regeneration

**Failure scenario:** a new test refers to a package helper, changing its
test_reference_count and reference_locations in helpers.csv. For existing
test-only helpers the same change propagates into test_only_seams.csv
(`tools/check-codebase-contracts.R:1040-1057`, `:1103-1154`, `:1496-1521`).
The in-memory symbol-map probe confirmed that adding an ordinary test reference
creates a new recorded location. New tools functions themselves are not package
helpers; their location in tools/ is not the problem.

The CLI also rewrites metadata.csv's mode and source_commit on each run
(`tools/check-codebase-contracts.R:1595-1600`). Its committed source_commit is
currently d154a2d7 (`census/metadata.csv:5`). Running final-candidate regeneration
with that candidate's identity changes this record even if all product rows
remain identical. Thus LDG-3193's blanket "no other census record" condition
(`tickets.yml:3388`) is not a sound invariant. It can encourage leaving generated
reference/provenance evidence stale, or suppressing natural test references to
avoid a diff. An implementation with no new package references might avoid the
helper diffs; that cannot be assumed as a contract.

**Exact patch:** replace the final LDG-3193 acceptance item with:

> No R/ product file, unrelated fixture/oracle, NEWS or user documentation page
> changes. New hot_path_* records are allowed. Existing census record changes
> are limited to source-derived test reference locations/counts and resulting
> test-seam rows or summary counts, plus regeneration metadata naming the
> candidate. Every such diff has its generating cause recorded. Product
> inventory, mode-branch keys/counts, condition/schema/config semantics, the
> six-family summary contract and product fingerprint membership are unchanged.
> Do not edit a test or suppress a reference to obtain an empty record diff.

Also state in decision (10)/LDG-3191 that hot-path reporting uses a separate
status/count output and does not extend the six summary families or product
fingerprint. Preserve LTB-0270..0272 and LTB-0331; any genuine need to change
their predicates requires its own stated reason, rather than being implied by
the new section. This is a bounded record-refresh allowance, not permission to
change product or existing oracles.

### C4. Report-mode inputs and all-record preflight must be explicit

**Failure scenario:** the current --output option controls where the CLI writes,
while the committed mode-branch input is resolved independently from root
(`tools/check-codebase-contracts.R:160-167`, `:215-237`). If the new section
treats an empty output directory as its prior baseline, --mode=report
--output=<fresh-dir> can lose the prior policy/inventory and bypass the agreed
refusals. If it writes the baseline before validating a later inventory or
policy refusal, it can partially bless itself. Conversely, placing the new
check after the index's current definition at :433 would put it after
dir.create(output) at :240, contrary to the stated pre-write boundary.

**Exact patch:** append to LDG-3191's CLI integration and acceptance:

> Resolve the prior seven-file hot-path record set independently of --output,
> from the checkout record directory or an explicit input-record directory.
> A different/empty output directory does not reset prior policy or allowances.
> Missing or partial prior records fail except for an explicit initial-seeding
> operation with its recorded initial reason. Before any directory creation or
> record write, check mode validates the complete hot-path section and report
> mode validates every regeneration refusal against that prior set. A rejected
> operation leaves every prior and output record byte-identical. Only after
> successful preflight may the existing record-write phase run.

> Prove this with missing/partial-input, empty-output-directory and late-policy
> refusal controls, using temp copies and before/after file hashes for both the
> hot-path set and the existing census records. Check mode never updates an
> allowance; report mode records each required reason before a later check.

This retains the mode-branch check-before-write precedent, whose check is at
`tools/check-codebase-contracts.R:237`, before :240; its test inspects this
ordering (`tests/testthat/test-codebase-contracts.R:223-233`). It does not claim
that the entire legacy CLI is transactionally read-only: after a successful
mode-branch precheck it currently writes tables even in check mode, and its
current-only refusal comes later (`tools/check-codebase-contracts.R:1554-1639`).
The new section must protect its own refusals before that write phase.

### Delivery disposition and evidence

The 3 s budget and inherited fast-lane disposition remain intact
(`tickets.yml:1246-1258`, `:3320`). Measure the complete added fast membership,
including shared-index construction costs attributable to this cut, in both
checkout and isolated contexts. The heavy runtime witness still compares the
named installed package's execution with the new source-derived graph; record
matching source/installed identities so source discovery is not mistaken for
evidence about a different build (`tickets.yml:3330-3332`, `:3386`). This is
ordinary evidence provenance, not an additional execution path.

Read the revised brief, census code, records/README, context helpers and tests
before probing. Executed only selectively loaded function definitions in a
fresh Rscript process and tiny in-memory parsed examples: flattened owners,
cyclic guard caching, dispatch-map over-approximation, reference-map change and
the six schema names. The CLI's write path was not executed. These probes
establish reuse constraints; no revision-3 hot-path implementation or future
3 s result is claimed. The branch ref confirms the reviewed head. Only this
review section was appended; no commit or global Git configuration change.
