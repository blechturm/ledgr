# ledgr v0.1.7.8 Spec

**Status:** Draft
**Target Version:** v0.1.7.8
**Scope:** Strategy reproducibility preflight, reproducibility-tier
documentation, leakage-boundary documentation, fold-core boundary sign-off, and
v0.1.7.7 auditr triage intake
**Inputs:**

- `inst/design/ledgr_roadmap.md`
- `inst/design/contracts.md`
- `inst/design/ledgr_design_document.md`
- `inst/design/ledgr_design_philosophy.md`
- `vignettes/strategy-development.Rmd`
- `vignettes/indicators.Rmd`
- `vignettes/custom-indicators.md`
- `vignettes/interactive-strategy-development.md`
- `vignettes/research-to-production.Rmd`
- `inst/design/ledgr_v0_1_7_8_spec_packet/cycle_retrospective.md`
- `inst/design/ledgr_v0_1_7_8_spec_packet/ledgr_triage_report.md`
- `inst/design/ledgr_v0_1_7_8_spec_packet/auditr_v0_1_7_7_followup_plan.md`

---

## 1. Purpose

v0.1.7.8 locks the strategy reproducibility boundary before v0.1.8 sweep mode
runs user strategies across parameter grids and optional worker processes.

The existing experiment store already records strategy source, parameter hashes,
dependency metadata, R version, and a reproducibility tier. That is useful
provenance, but it is mostly descriptive after the run. Sweep mode needs the
same idea as a preflight contract before execution: Tier 1 and Tier 2 strategies
may run; Tier 3 strategies must fail loudly because their behavior depends on
unresolved, non-recoverable external state.

This release also uses the v0.1.7.7 documentation review as a scope correction:
ledgr's leakage story should not depend on a toy `lead(close)` example alone.
Public documentation must explain the two ledgr leakage boundaries:

- the strategy boundary, where strategies receive a pulse context rather than a
  future market-data table;
- the feature boundary, where registered indicators have declared IDs, warmup,
  fingerprints, and output validation.

The release must stay narrow. It prepares the correctness surface for sweep
mode. It does not implement sweep mode, dependency declarations, automatic
environment management, paper trading, or new execution semantics.

---

## 1.1 Evidence Baseline

| Evidence | Classification | v0.1.7.8 handling |
| --- | --- | --- |
| v0.1.8 sweep will execute many strategy variants | Design prerequisite | Add preflight so Tier 3 strategies are rejected before sweep exists. |
| Existing provenance tiers are descriptive | Contract gap | Turn tiers into a user-facing classification and enforcement surface. |
| `codetools::findGlobals()` can classify ordinary free variables | Implementation path | Use static analysis but document dynamic-dispatch blind spots. |
| Package-qualified helpers are common in real strategies | Expected Tier 2 workflow | Classify `pkg::fn()` dependencies as Tier 2, not Tier 3. |
| Unqualified external helpers such as `my_helper()` are not recoverable | Reproducibility risk | Classify as Tier 3 unless a later dependency-declaration API exists. |
| Mutable closure state and `<<-` can break sweep parity | Static-analysis blind spot | Document as unsupported for sweep and warn users explicitly. |
| Current leakage vignette example is too blunt | Documentation maturity gap | Add a dedicated leakage article and soften the old over-absolute wording. |
| Feature generation is strict but under-explained | Documentation positioning gap | Explain feature contracts as a leakage boundary without overclaiming. |
| `ledgr_check_no_lookahead()` is internal | API boundary risk | Do not cite as user-facing unless a separate API ticket exports a wrapper. |
| Placeholder public docs remain in `vignettes/` | Documentation hygiene gap | Route stale placeholders into this release if they affect public positioning. |
| v0.1.7.7 auditr report | Incoming evidence, now routed | Promote only verified reproducibility/leakage/provenance findings into v0.1.7.8; route broad ergonomics to v0.1.7.9. |

---

## 2. Release Shape

v0.1.7.8 has five coordinated tracks.

### Track A - Reproducibility Preflight Contract

Define and document the preflight contract for user-written strategy functions.
The contract must classify strategies as Tier 1, Tier 2, or Tier 3 before
execution and must specify which tiers future sweep mode may accept.

The contract must also define the public preflight result shape: class name,
stable fields, and the minimum accessor or print behavior needed by users,
tests, `ledgr_run()`, and future `ledgr_sweep()`.

### Track B - Preflight Implementation

Implement the smallest stable API that v0.1.8 can call without changing tiering
semantics. The implementation may use `codetools::findGlobals()` as the first
static-analysis mechanism, but the API must not expose codetools internals as
the public contract.

### Track C - Reproducibility Documentation

Add a reproducibility design article and update relevant reference docs so users
understand what each tier means for ordinary runs, future sweep workers, and
later paper/live use.

This article should be framed as a narrative design article, parallel to the
leakage article, rather than a narrow reference page.

`vignettes/reproducibility.Rmd` is the authoritative narrative for ledgr's
experiment model, provenance model, strategy extraction, trust boundary, and
reproducibility tiers. `vignettes/experiment-store.Rmd` remains the
workflow-oriented article for durable run storage and inspection. Its stored
strategy section should either be trimmed to a concise workflow example with a
link to the reproducibility article, or explicitly cross-link to the
reproducibility article so the trust semantics do not drift.

### Track D - Leakage Boundary Documentation

Add a focused leakage article that teaches the strategy boundary, feature
boundary, and remaining user responsibilities. Update the existing strategy
vignette so its `lead(close)` example becomes an entry point rather than the
whole leakage story.

### Track E - auditr v0.1.7.7 Intake And Release Gate

The v0.1.7.7 auditr triage report has been received and routed through
`auditr_v0_1_7_7_followup_plan.md`. Only verified ledgr package issues belong
in v0.1.7.8 tickets. Auditr harness/environment issues remain out of ledgr scope
unless explicitly reframed as package defects.

Track E is the only track blocked on the incoming auditr report. Tracks A-D are
independent and may begin immediately.

---

## 3. Hard Requirements

### R1 - Preflight Runs Before User Strategy Execution

The public execution path must classify the strategy before normal
`ledgr_run()` strategy execution begins.

Tier 3 is an error in both ordinary runs and future sweep mode. Ordinary
single-run APIs may provide an explicit maintainer-approved override such as
`force = TRUE`, but the default semantics must match sweep: Tier 3 is not
accepted silently and is not downgraded to a warning.

The `force = TRUE` override is deferred out of LDG-1803. LDG-1803 must implement
the default hard-stop behavior only. If a later ticket adds an override, the run
must still record `tier_3` in provenance rather than upgrading the tier.

### R2 - Tier 1 Is Self-Contained

Tier 1 means a `function(ctx, params)` strategy can be understood from stored
source and explicit parameters without unresolved external objects.

Base R references are Tier 1-compatible when they are ordinary function calls or
constants and do not introduce hidden mutable state. The implementation must not
depend on a hand-maintained allowlist of individual package names.

For v0.1.7.8, "base R" means functions and constants resolved from packages
distributed with the active R installation, discovered by package metadata rather
than by a fixed list. A practical implementation may treat packages whose
installed `Priority` is `base` or `recommended` as Tier 1-compatible. This rule
applies whether calls are unqualified, such as `mean(x)`, or package-qualified,
such as `stats::sd(x)`.

### R3 - Tier 2 Is Explicit External Dependency

Tier 2 means the strategy is inspectable but requires user-managed environment
parity. Package-qualified calls to packages outside the active R distribution,
such as `pkg::fn()`, are Tier 2-compatible.

Tier 2 is allowed for ordinary runs and future sweep mode, but documentation
must state that users own package installation, package version parity, and any
non-ledgr dependency management. The reproducibility vignette should point users
to established environment-management approaches such as `renv`, Docker,
`{rix}`, and `{uvr}` without becoming a tutorial for those tools.

### R4 - Tier 3 Is Unresolved External State

Tier 3 means the strategy depends on external state that ledgr cannot recover
from stored metadata.

Examples include:

- unqualified user helper calls such as `my_helper(ctx)` that cannot be resolved
  to base R or ledgr's exported public namespace;
- free variables not supplied through `params` or explicit strategy source;
- dependency on hidden files, global options, environment variables, or mutable
  external objects;
- dynamic dispatch patterns whose target cannot be statically resolved.

Tier 3 diagnostics must be classed and actionable.

### R5 - No Silent Upgrade Of Unqualified Helpers

Unqualified external helpers are Tier 3 unless and until ledgr ships an explicit
dependency-declaration contract. Do not infer that a helper is safe because it
exists in the current interactive session.

Unqualified calls to ledgr's exported public namespace are not user-defined
external helpers. Documented strategy helpers such as `signal_return()`,
`select_top_n()`, `weight_equal()`, `target_rebalance()`, and `passed_warmup()`
are Tier 1-compatible because ledgr itself is the required execution environment
for any ledgr experiment. They must not be treated as unresolved Tier 3 symbols
merely because examples call them without `ledgr::`.

### R6 - Static Analysis Limits Are Part Of The Contract

The preflight must document what it can and cannot prove.

Known limits include:

- `do.call()`;
- `get()`;
- `eval()`;
- dynamically constructed functions;
- S3/S4/R6 dispatch that depends on runtime object state;
- closures that mutate captured environments;
- `<<-` assignment.

The user-facing message must not imply static analysis is a proof of full
semantic reproducibility.

### R7 - Mutable Closure State Is Unsafe For Sweep

Strategies that mutate external or captured state can produce order-dependent
results across sweep workers. Static analysis may not always detect the problem.

The reproducibility article must explicitly warn that these patterns are
unsupported for sweep even when symbol resolution appears acceptable.

### R8 - API Is Stable Enough For v0.1.8

The preflight API must be designed so v0.1.8 can call it directly from sweep
execution without adding v0.1.8-specific tiering parameters.

The public result object must have a stable class and stable field names. The
preferred shape is:

```r
structure(
  list(
    tier = "tier_1" | "tier_2" | "tier_3",
    allowed = TRUE | FALSE,
    reason = character(),
    unresolved_symbols = character(),
    package_dependencies = character(),
    notes = character()
  ),
  class = "ledgr_strategy_preflight"
)
```

The final implementation may add fields, but these fields are the minimum
contract unless a ticket records a better shape before implementation starts.
In v0.1.7.8, `allowed` means `TRUE` for `tier_1` and `tier_2`, and `FALSE` for
`tier_3`.

The API may also expose:

- warnings or notes;
- classed condition objects.

It must not expose implementation details that would force users to depend on
`codetools` output shape.

### R9 - Fold-Core Boundary Is Signed Off In Writing

v0.1.7.8 must record the fold-core/output-handler boundary that v0.1.8 will use.
The sign-off may live in `contracts.md` or a dedicated design document under
`inst/design/`.

For this spec, the fold-core means the deterministic per-pulse execution engine
that applies strategy output, risk/target validation, fill timing, and state
transition semantics. The output-handler means the layer that records or
accumulates execution artifacts such as ledger events, fills, equity rows,
feature rows, telemetry, and comparison-ready summaries.

This is a written contract only. It must not implement sweep mode.

### R10 - Leakage Article Teaches Boundaries, Not Exhaustive Taxonomy

The leakage article must teach the mental model:

- leakage can enter through strategy logic;
- leakage can enter through feature construction;
- leakage can enter before ledgr sees the data;
- ledgr prevents or constrains some categories and leaves others to the user.

The article should include one blunt example and one subtle example, but it
should not become an exhaustive encyclopedia of every possible leak.

### R11 - Strategy Vignette Wording Must Be Honest

The current `strategy-development` leakage section must be softened.

It may still teach `lead(close)` as an obvious error, but it must not imply that
ledgr makes all leakage impossible. It must point readers to the dedicated
leakage article.

### R12 - Feature Boundary Gets Proper Credit

Documentation must state that ledgr features are registered artifacts, not
casual full-sample signal columns.

At minimum, the public docs must mention:

- declared feature IDs;
- `requires_bars` and `stable_after`;
- warmup `NA_real_`;
- pulse-time feature lookup;
- exact failure for unknown feature IDs;
- scalar bounded-window evaluation;
- vectorized `series_fn` shape/value validation;
- the residual risk of semantically leaky custom `series_fn` code.

### R13 - Internal Diagnostics Are Not Marketed As Public API

Do not cite `ledgr_check_no_lookahead()` as a user-facing safeguard unless a
separate ticket deliberately exports, documents, and tests a supported public
wrapper.

Internal tests may continue to use the internal helper.

### R14 - Stale Public Vignette Placeholders Are Resolved Or Routed

The public `vignettes/` directory must not contain stale placeholder text that
suggests unfinished v0.1.3 documentation.

`custom-indicators.md` is in v0.1.7.8 scope for promotion into a current public
article because custom `series_fn` is the highest-risk user-extensible leakage
boundary. The leakage article must link to the promoted custom-indicator
article.

`interactive-strategy-development.md` must either be:

- moved out of the public vignette surface; or
- explicitly routed to a later ticket with a clear reason.

### R15 - auditr Findings Must Be Classified Before Promotion

The v0.1.7.7 auditr triage report is an input, not an implementation plan.
`auditr_v0_1_7_7_followup_plan.md` is the routing artifact for this cycle.

Every promoted finding must be classified as one of:

- confirmed ledgr bug;
- documentation mismatch;
- expected user error with weak messaging;
- auditr harness/environment issue;
- no longer reproducible;
- new product/design backlog.

The spec and tickets must record which findings are in v0.1.7.8 scope and which
are deferred or excluded.

---

## 4. Track A Scope - Preflight Contract

Track A updates `contracts.md` and any needed design docs.

The contract must define:

- Tier 1, Tier 2, and Tier 3 in terms of strategy source, params, dependencies,
  and recoverability;
- which tiers ordinary runs accept;
- which tiers future sweep mode accepts;
- why Tier 3 is not sweep-safe;
- how R6 strategies are treated unless they provide explicit source and
  parameter metadata;
- how package-qualified dependencies differ from unresolved free variables;
- how mutable closure state and dynamic dispatch are handled.
- the `ledgr_strategy_preflight` result contract, including at least `tier`,
  `allowed`, `reason`, `unresolved_symbols`, `package_dependencies`, and
  `notes`.

Acceptance criteria:

- `contracts.md` contains the preflight contract.
- `contracts.md` does not promise semantic proof beyond static analysis.
- The contract states that future sweep mode inherits these tier semantics.
- The classed preflight result shape is documented before implementation.
- The contract defines `allowed` as `TRUE` for `tier_1` and `tier_2`, and
  `FALSE` for `tier_3`.
- The contract records that the optional single-run force override is deferred
  out of LDG-1803.

---

## 5. Track B Scope - Preflight Implementation

Track B implements the smallest production API needed for the contract.

Candidate API shape:

```r
ledgr_strategy_preflight(strategy)
```

The return value should be inspectable and stable enough for tests and future
sweep integration. A classed object is preferred over a bare list.

Track B must also wire `ledgr_strategy_preflight()` into `ledgr_run()` so the
preflight runs automatically before strategy execution. A standalone preflight
helper alone is not sufficient.

The implementation should:

- inspect functional strategies first;
- preserve existing strategy validation;
- classify base-R-distribution calls as Tier 1-compatible without relying on a
  fixed hand-maintained allowlist;
- classify calls that resolve to ledgr's exported public namespace as
  Tier 1-compatible;
- classify package-qualified calls outside the active R distribution as
  Tier 2-compatible;
- classify unresolved free variables as Tier 3;
- produce a classed error for Tier 3;
- include enough detail for actionable user messages.
- not implement the optional single-run `force = TRUE` override in LDG-1803.

If the API name changes during implementation, the ticket must record the final
name and rationale.

Acceptance criteria:

- Tier 1 example passes.
- Tier 2 package-qualified example passes with Tier 2 classification.
- Ledgr public helper example returns Tier 1.
- Tier 3 unqualified helper example stops execution with a classed error.
- `ledgr_run()` calls the preflight automatically before strategy execution.
- Tier 3 default execution stops with a classed error, not a warning.
- The optional single-run `force = TRUE` override is not implemented in
  LDG-1803.
- Diagnostics name unresolved symbols where possible.
- Existing `ledgr_run()` tests still pass.
- No second execution path is introduced.

---

## 6. Track C Scope - Reproducibility Documentation

Track C adds the public teaching layer.

Required article:

```text
vignettes/reproducibility.Rmd
```

Working title:

```text
On Reproducibility: ledgr Design Choices
```

The article must explain:

- ledgr's experiment model: sealed snapshot, strategy, params, features,
  opening state, run identity, and derived result tables;
- ledgr's provenance model: what is stored with a run, what is hashed, and why
  a result should be explainable later;
- strategy source extraction through `ledgr_extract_strategy()`;
- why `trust = FALSE` is the safe inspection path;
- why `trust = TRUE` proves stored-source identity but not code safety;
- why stored source text is not the same as full reproducibility;
- Tier 1, Tier 2, and Tier 3;
- examples of each tier;
- consequences for ordinary runs;
- consequences for future sweep workers;
- consequences for later paper/live use;
- why Tier 2 is allowed but not fully reproducible by ledgr alone;
- why Tier 2 users must manage their own runtime environment;
- why `params` is the preferred boundary for strategy variation;
- why unqualified helper calls are Tier 3 in v0.1.7.8;
- why package-qualified calls are Tier 2;
- why hidden mutable state is unsafe.

The article should name environment-management tools as examples only:

- `renv`;
- Docker;
- `{rix}` (<https://github.com/ropensci/rix>);
- `{uvr}` (<https://github.com/nbafrank/uvr>).

It must not teach those tools in detail or make them ledgr dependencies.

Acceptance criteria:

- Article is included in `_pkgdown.yml`.
- Article has a rendered companion markdown if this repository keeps one for the
  article type.
- Reference docs for the preflight API link to the article.
- `?ledgr_extract_strategy`, `?ledgr_experiment`, and the preflight API docs
  link to the article where appropriate.
- Documentation contract tests pin the experiment/provenance model, safe
  extraction boundary, tier definitions, and Tier 3 behavior.

---

## 7. Track D Scope - Leakage Boundary Documentation

Track D adds the concept article that was missing from v0.1.7.7.

Required article:

```text
vignettes/leakage.Rmd
```

Working title:

```text
On Leakage: ledgr Design Choices
```

The article should include:

- the blunt `lead(close)` example as an obvious first warning or short teaser;
- a subtler full-sample preprocessing example, such as a `quantile()` threshold
  computed over the full sample;
- a strategy-boundary section explaining pulse contexts;
- a feature-boundary section explaining registered indicators;
- a residual-risk section covering biased snapshots, bad event availability
  timestamps, survivorship, research-loop leakage, and custom vectorized
  `series_fn` code;
- a short checklist before trusting a run.

The article must avoid overclaiming. Recommended thesis:

```text
ledgr makes several common leaks harder to express or easier to diagnose. It
does not certify that the dataset, event timestamps, universe construction,
parameter search, or custom vectorized feature code are causally clean.
```

Related edits:

- Update `vignettes/strategy-development.Rmd` so the leakage section points to
  the new article.
- Update README/pkgdown homepage with a short pointer only if it improves the
  first-page positioning without making the README longer than necessary.
- Promote `custom-indicators.md` into a current article and link it from the
  leakage article.
- Move or route `interactive-strategy-development.md`.
- Soften the future live/paper overclaim in
  `vignettes/research-to-production.Rmd` where the ledger is described as the
  state without reconciliation.

Acceptance criteria:

- `vignettes/leakage.Rmd` exists and is linked in pkgdown navigation.
- The subtle feature-construction leak is explained.
- The article distinguishes ledgr-enforced boundaries from user
  responsibilities.
- Public docs do not cite internal-only diagnostics as public API.
- The old strategy vignette no longer contains the over-absolute "no object"
  claim without caveat.

---

## 8. Track E Scope - auditr Intake

Track E owns the v0.1.7.7 auditr routing artifact.

The first implementation ticket after this spec must:

1. read `auditr_v0_1_7_7_followup_plan.md`;
2. confirm whether any routed v0.1.7.8 promotions need raw episode review before
   ticket execution;
3. keep broad ergonomics findings routed to v0.1.7.9 unless raw evidence proves
   a v0.1.7.8 blocker.

Current routing rules:

- Strategy reproducibility, leakage, custom-indicator boundary, and provenance
  findings belong in v0.1.7.8 when verified.
- Broad feature-map, ctx accessor, warmup/current-bar, first-run, print, metrics,
  and snapshot-metadata discoverability findings belong in v0.1.7.9 or docs
  backlog.
- Sweep implementation findings belong to v0.1.8 unless they block the preflight
  contract.
- Auditr harness/environment findings remain outside ledgr unless reframed as a
  package defect.

Acceptance criteria:

- `auditr_v0_1_7_7_followup_plan.md` exists in this packet.
- No auditr finding is promoted without raw-evidence classification.
- Tickets created from auditr findings name the evidence source.

---

## 9. Non-Goals

v0.1.7.8 must not implement:

- sweep execution;
- tune/optimization APIs;
- parallel backend selection;
- dependency declaration APIs;
- automatic package installation;
- worker environment management;
- public no-lookahead diagnostic exports unless separately ticketed;
- paper trading;
- live trading;
- OMS simulation;
- new asset-class semantics;
- broad strategy-author ergonomics work that belongs to v0.1.7.9.

---

## 10. Release Gate

The release is complete when:

- the reproducibility-tier preflight contract is recorded;
- the preflight API classifies Tier 1, Tier 2, and Tier 3 examples;
- Tier 3 diagnostics are classed and actionable;
- the reproducibility article is public and linked;
- the leakage article is public and linked;
- the old leakage wording is softened;
- stale public vignette placeholders are resolved or explicitly routed;
- the v0.1.8 fold-core/output-handler boundary is signed off in writing;
- the v0.1.7.7 auditr report is routed through
  `auditr_v0_1_7_7_followup_plan.md`;
- all promoted auditr findings have raw-evidence classifications;
- documentation contract tests pin the new public claims;
- targeted tests for strategy preflight pass;
- full Windows tests pass;
- Ubuntu CI is green before merge.

---

## 11. Expected Ticket Families

Tracks A-D can be cut and implemented now. Auditr-derived tickets must follow
`auditr_v0_1_7_7_followup_plan.md` and must name raw evidence before changing
runtime behavior.

Expected families:

1. Scope and auditr routing baseline.
2. Reproducibility-tier contract update.
3. Strategy preflight implementation.
4. Reproducibility article and reference docs.
5. Leakage article and strategy-vignette cleanup.
6. Public placeholder vignette cleanup or promotion.
7. Fold-core/output-handler sign-off.
8. Release gate, NEWS, and packet finalization.

The final ticket list may change after item-level auditr evidence review, but it
must preserve the hard requirements above.
