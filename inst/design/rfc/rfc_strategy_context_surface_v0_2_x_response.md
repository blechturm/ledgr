# RFC Response: Strategy Context Surface And Helper Composability

**Status:** Type 2 response; revise the proposed direction before synthesis.
**Date:** 2026-09-26
**Author:** ChatGPT, response author; independent of the seed author.
**Baseline:** `v0.2.0.2` at `39de0bfceab71266c61a6d4fe60f8b8f2069b962`.
**Framing:** The seed author's brief is provisional. This response binds no design.

## 1. Assessment

The diagnosis is partly right: the pipeline already composes, its entrances are
awkward, and discovery of the current context is unnecessarily difficult.
The proposed cure confuses three different questions: how to read data, which
assets to allocate to, and how to construct complete portfolio intent.

Tidyverse usability should mean predictable composition, useful defaults and
errors, and a small number of concepts to learn. It does not require one
syntactic rule for objects with different dimensions, or at most 15 members.
The UX document's progressive-disclosure principle supports that distinction.

Keep the pipeline and add clear entrances. Reject the full-axis allocation
default, the claim that sparse selections violate the target contract, and
removing the feature bundle on the evidence of an empty example. Treat the
other removals as design choices, not consequences with "no second position."

## 2. Execution and limits

I executed the unmodified production R functions using R 4.5.2 and rlang 1.1.3.
The [probe](../../../dev/spikes/strategy-context-surface/probe.R) sources the
context, projection and helper modules directly. It exercises constructors and
helpers on synthetic data; it does not install the full package, run DuckDB,
execute a fold, or reproduce the seed's performance benchmark. Availability
cases supply synthetic member/holding planes to the production target helper.
They establish helper behavior, not provider or execution integration.

[Recorded observations](../../../dev/spikes/strategy-context-surface/observations.csv)
are rerun by [the checker](../../../dev/spikes/strategy-context-surface/check.py).
A local mutant removes the nonmember reservation and changes the allocation
from six shares to ten; the evidence diff detects it. Production files are
unchanged. The [findings](../../../dev/spikes/strategy-context-surface/probe_findings.md)
record the scope and reproduction command.

The seed instead names `codex/ws16-v0.2.1.0`, without a SHA or runnable fixture.
That branch was not advertised by the remote. Neither `ctx$tradable()` nor
`ledgr_scalar_accessor_loop` exists in the supplied revision. This is a baseline
mismatch, not evidence that the author's local experiment never happened.
The timing ratio, six-fill result and 9,466-fill result remain unverified here.
Publish that exact source and runner if those numbers are to decide the design.

### Re-derivation of Section 2

| Seed claim | Executed finding and disposition |
| --- | --- |
| 29 members, 15 functions | Dense constructor: 28 public names, 14 functions; eight `vec` members. Optional availability fields make one universal census inappropriate. |
| `hold()` identical to positions | True with complete named positions. False for an accepted sparse constructor input: `hold()` completes the axis. Equality on a fold snapshot does not equate the contracts. |
| `bar()` strictly supersets seven accessors | It contains OHLCV and bar metadata, but neither position nor feature values. There are five OHLCV accessors. |
| Empty features imply redundancy | Empty long table reproduced; no-map `features("AAA")` raises `ledgr_no_active_alias_map`, not `character(0)`. Active aliases return named values and warmup `NA`. |
| Empty long table implies no feature data | Projection-backed context has a 0-by-4 long table and still returns `c(trend = 10.25, ret = NA)` from the bundle. |
| Unnamed planes trap ID lookup | Reproduced: `["AAA"]` gives `NA`, `[["AAA"]]` errors, and `[[ctx$idx("AAA")]]` gives 10. |
| Two tombstones | Both calls raise `ledgr_context_helper_removed`. Remove them without replacements. |
| Pipeline already pipes | Reproduced through selection, equal weights and target construction. |
| Candidate/instrument prefix collision | `argmax` takes `metric`; its rule construction is source-confirmed in `R/walk-forward-selection.R:15-52`. |
| A through D are equivalent | Fresh dense fixture gives quantities `AAA=15, BBB=7` for all four. This is target parity, not reproduction of the reported fills or final equity. Availability breaks the equivalence. |

The alignment contract is incomplete, not unwritten: `contracts.md:744-749`
and `man/ledgr_strategy_context.Rd:17-29` already document alignment and `idx`.
They need explicit unnamed-vector examples. The reference also calls the
universe "instruments in the run"; teach the decision axis when availability
is active. Unnamed vectors' claimed performance advantage was not measured by
this probe and should not be asserted from their length alone.

## 3. The central error: target completeness is not selection completeness

**Contract:** Missing final strategy targets must not silently become zero.
That does not require every intermediate to contain every asset. Existing
signals and selections validate with `full_universe = FALSE`, and equal
weighting returns only selected IDs (`R/strategy-types.R:108-159`;
`R/strategy-helpers.R:175-187`).

**Executed:** Selecting only `AAA` in a dense `AAA, BBB` context produces the
complete target `AAA=30, BBB=0`. The target constructor supplies the other
quantity deliberately. No strategy output has been silently repaired.

The same helper starts held nonmembers at their current quantity, zeros current
members, reserves nonmember exposure, and sizes member allocations from the
remaining equity (`R/strategy-helpers.R:226-305`; `contracts.md:392-404`).
For equity 100, prices 10 and 20, and a two-share holding in former member OLD:

| Intent | Actual production helper result |
| --- | --- |
| Equal weights over the full visible axis | Error: OLD is outside the current member set. |
| Allocate to current member AAA | `AAA=6, OLD=2`; 40 of equity remains reserved. |
| Select no current member | `AAA=0, OLD=2`; the nonmember is preserved. |
| Seed's manual formula D | `AAA=5, OLD=2`; it allocates by axis length instead. |

Thus D is shorter but not a general replacement for the helper. Seed acceptance
criterion 4 must distinguish unselected members from preserved nonmembers.

A second executed case has a held member with a missing close but a usable
risk mark. The full selection fails sizing. Removing that asset from the
selection produces an explicit zero for its holding. This is an exit target,
not a guarantee of an executable sale. `priced & admissible` also fails
sizing here: a permissible valuation mark is not an accepted current close.

The design must explain **selection for allocation**, **preservation of an
existing holding**, and **an explicit exit**. Changing vector shape cannot
eliminate those distinctions. Unknown information must not silently become a
negative selection. Keep `NA` selection rejection and explicit `ctx$hold()`
for an author who chooses to skip a decision; do not add an imputation policy.

## 4. Positions on D1 through D4

### D1: retain scalar reads; do not make a warning the design's foundation

Keep `close(id)` and the other scalar accessors. They serve the single-asset
case clearly. Removing them cannot make loops unwriteable: looping `bar(id)`
is still possible, and its implementation slices or creates a frame
(`R/pulse-context.R:741-767`). Teach planes for cross-sectional operations.

The warning's implementation, overhead and detection quality are not established
at this baseline. Evaluate it when its source is available; do not add or
expand instrumentation in this RFC. A single elapsed-time pair cannot establish
an API prohibition. Cost of retaining scalars: a bounded parallel read surface
and documentation of when to use it. No new representation is needed.

### D2: retain feature bundles; move rectangles to explicit inspection

A feature value has two keys: asset and feature. A feature plane fixes the
feature; a bundle fixes the asset. They are different queries, not redundant
spellings. Retain `feature(id, fid)`, `vec$feature(fid)` and `features(id, map)`
with the active-alias shorthand. The probe executes all three successfully.

Concrete consumers exist in `vignettes/indicators.qmd:206`,
`vignettes/sweeps.qmd:163-176` and `vignettes/research-workflow.qmd:274`.
The bundle supports alias-based strategies across parameterized features and
the warmup guard; contracts bind this at `contracts.md:767-781`.

I support removing the long/wide rectangles from the callback's *public* read
surface, with explicit read-only inspection through the existing pulse APIs.
An empty compatibility table should not pretend to be the available data.
Cost: amend the context contract, update its internal consumers and inspection
boundary, and test alias/warmup behavior on projection and interactive paths.
Do not rebuild frames inside the callback to preserve the old spelling.
This is a surface change, not a feature-cache or execution-engine redesign.

### D3: default to investment membership, with no silent quality screen

Neither proposed default is right. Full visible axis includes holdings that
cannot receive allocation weights; a "tradable" screen mixes current sizing
and future execution and can turn missing input into an exit intent.

Default a context-derived selection to current investment members: all configured
instruments for dense contexts, `ctx$members` when availability is active.
Do not silently discard members for missing prices or restrictions. Preserve
existing sizing failures and downstream target restrictions. Let authors make
any narrower choice explicitly, including explicit exits from former members.

This changes no membership, valuation, execution or nonmember-preservation
policy. Cost: context-aware input alignment, documented omission semantics,
and small examples covering a held nonmember and a missing member close.

### D4: defer a class unless it makes inspection measurably clearer

A class on an existing list of planes does not itself materialize a frame.
A print method could summarize it without automatic coercion. The seed's
frame-or-nested-list dichotomy is false; `vec$feature` is also a function, not
a table column. However, no class is necessary for the proposed entrances.
Keep the representation; improve the current reference and inspection first.
Cost avoided: another class's dispatch and printing surface, not an inevitable
per-pulse table allocation. No lazy frame coercion on the strategy path.

## 5. Replacement surface direction

**Proposal, not implemented:** preserve value constructors for already named
vectors and add explicit context-derived forms. Use a consistent context-first
form with named `values`, `ids` or `where` arguments, rather than positional
signatures that swap whether the context comes first.

```r
# Proposed: membership allocation, preserving held nonmembers downstream.
ledgr_selection(ctx) |>
  ledgr_weight_equal() |>
  ledgr_target_rebalance(ctx)

# Proposed: an evaluated plane, not a data-masked expression.
ledgr_signal(ctx, values = ctx$vec$feature("return_20")) |>
  ledgr_select_top_n(10) |>
  ledgr_weight_equal() |>
  ledgr_target_rebalance(ctx)
```

For the context forms, unnamed inputs must have exact axis length; named inputs
must align by unique known IDs. Do not recycle. Distinguish a deliberately
chosen subset from incomplete or `NA` selection input. Reject attempts to
allocate weights to nonmembers. A full-axis mask is a reasonable constructor
output, but is not a correctness requirement on all intermediates. Generic
value constructors remain useful without a context; this is composability,
not a deprecation shim. Cost: explicit dispatch/argument validation and two
well-documented input forms. The downstream verbs remain unchanged.

Replace R1 with three teachable roles: read current state; select and weight
members; return complete intent. Use scalar/plane symmetry for OHLCV and
position. Explain the feature argument because there is a second dimension.
Do not manufacture scalar methods for every availability metadata plane merely
to satisfy "zero exceptions."

I support deleting the tombstones, choosing one position-plane spelling
(`position`), separating candidate-rule names from instrument selection, and
making `safety_state` private. Removing public `positions` is reasonable if the
plane remains the canonical read view; **do not teach `hold()` as its read
replacement**. It constructs and fills a new named target vector
(`R/pulse-context.R:796-828`). State and intent are deliberately different in
`contracts.md:754-762`. Remove `bars` as part of the explicit inspection-boundary
change, not because its information is completely represented by OHLCV planes.
Each removal costs a contract/reference and internal call-site update; none
owes an external compatibility shim.

Retain R4's documented-surface check, including dense and availability variants.
Do not build a new registry or documentation generator just for this task; use
the existing documentation-contract mechanism and one reference table.

## 6. Scope corrections and practical acceptance

Remove R3's rebalance band from this surface cut. It changes portfolio policy,
not just API spelling: units, comparison basis, explicit exits, residual cash
and downstream risk interactions all need decisions. A large fill count in a
per-pulse equal-weight strategy does not establish which band is appropriate.
Different holdings can produce different future equity, so requiring unchanged
equity while reducing fills is not a valid general detector. Park the band with
the existing rebalancing work; use a hold-unless-signal teaching example now.

There is a more immediate composability hole. The contract accepts an empty
availability decision axis (`contracts.md:375-379`). The probe gets a valid
empty named target from `hold()`, but the public target constructor and
rebalance helper reject it (`R/strategy-types.R:218-226`;
`R/strategy-helpers.R:1-9`). Resolve empty-domain behavior in this cut. A new
"everything" entrance should not require an undocumented escape for nothing.

Replace member-count and zero-exception gates with these practical checks:

1. The short equal-member pipeline yields the dense control's targets and the
   reserved-budget result with a held nonmember; final targets are complete.
2. Missing sizing input fails explicitly; deliberate omission, an explicit exit
   and `hold()` remain distinguishable. Empty membership and empty axis work.
3. Scalar, plane and alias-bundle reads agree on values, order and warmup;
   unknown IDs and length/name mismatches fail with useful context.
4. All taught workflows render against the chosen surface. A reader can find
   axis, units, missingness and omission rules in one reference without source
   archaeology. The documented surface covers conditional availability fields.
5. The change adds no per-pulse frame materialization or full-history work.
   Any performance justification uses a reproducible same-workload comparison;
   the current fold, caches, accounting and provenance remain outside this cut.

## 7. Route to synthesis

The maintainer should confirm the narrower question: **how does a strategy read
current information and express portfolio intent without alignment tricks or
hidden allocation policy?** That is the useful usability problem here.

The seed author can supply the missing WS16 commit and measurement runner while
correcting the full-axis and feature-bundle premises. No broad new spike or
extra provenance system is needed. The response's small probes already settle
those helper questions. Synthesis should choose the entrance and inspection
surfaces explicitly, preserve the stated non-negotiables, and schedule this
work after the current release gate. Current release articles should describe
APIs that actually ship; avoid teaching the proposed surface prematurely.
