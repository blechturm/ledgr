# ledgr v0.1.3 Implementation Tickets

**Version:** 1.0.0
**Date:** April 25, 2026
**Total Tickets:** 6
**Estimated Duration:** 1-2 weeks

---

## Ticket Organization

v0.1.3 is an onboarding and polish release. The implementation work is scoped
around the "5-Minute Success Path": a new user should be able to install ledgr,
run a complete backtest, inspect results, and understand the reproducibility
model from a clean R session.

The ticket range starts at `LDG-601` to avoid collisions with v0.1.2 tickets.

### Dependency DAG

```text
LDG-601 -> LDG-606 -> LDG-602 -> LDG-604
LDG-601 -> LDG-605 -> LDG-604
LDG-603 -----------> LDG-604
```

`LDG-604` is the release automation gate. It should not be accepted until the
README, context helper ergonomics, vignette, exported examples, and
target-vector error polish are all in place.

### Priority Levels

- **P0 (Blocker):** Required before release validation can be trusted
- **P1 (Critical):** Required for the public onboarding experience
- **P2 (Important):** Required for package quality and maintainability

---

## LDG-601: Master README and 5-Minute Success Path

**Priority:** P0
**Effort:** 1-2 days
**Dependencies:** None

**Description:**
Rewrite the README around a minimal, copy-pasteable success path that works
from an installed package in a fresh R session.

**Tasks:**
1. Replace the current quickstart with a self-contained minimal working example.
2. Use synthetic, offline OHLCV data with a fixed seed.
3. Run `ledgr_backtest()` through the v0.1.2 data-first API.
4. Show `print(bt)`, `summary(bt)`, and `as_tibble(bt, what = "trades")`.
5. Explain what happened after the first visible result without adding an
   unmotivated standalone section.
6. Add a concise reproducibility/tamper-detection hint.
7. Keep Linux/WSL troubleshooting out of the front-door README unless a
   release-blocking install issue needs a targeted note.
8. Add a post-result "Why ledgr?" frame without delaying the first runnable
   example.
9. Add the pipeline mental model:
   `data -> sealed snapshot -> deterministic engine -> ledger -> results`.
10. Add an explicit strategy-contract example with named numeric target vectors.
11. Rename the determinism proof as a trust check.
12. Add a concrete "what to try next" modification path.
13. Convert the README source to `README.Rmd` with `github_document` output and
    treat `README.md` as a generated artifact.
14. Replace hand-written "Expected result" blocks with rendered R output.
15. Open with a concise explanation of what ledgr is under the hood:
    event-sourced backtesting, sealed snapshots, pulses, event ledger, and
    ledger-derived results.
16. Contrast ledgr with vectorized backtesting frameworks: vectorized engines
    compute directly from signals/price arrays; ledgr records pulse-by-pulse
    events and derives results from that ledger.
17. Use `library(ledgr)` and `library(tibble)` in the first path, not
    `library(tidyverse)`. This signals tidyverse adjacency while keeping the
    fresh-session dependency surface small.
18. Prefer natural tidyverse-adjacent inspection syntax, for example
    `bt |> as_tibble(what = "trades")`, after `library(tibble)` is attached.

**Acceptance Criteria:**
- [x] The README MWE can be copied into `R --vanilla` and run unchanged.
- [x] The example does not use `pkgload::load_all()` or local repository files.
- [x] The example uses a fixed seed and deterministic synthetic data.
- [x] Reproducibility is demonstrated with either a fixed `run_id` or normalized
      comparison excluding identity/path columns.
- [x] The post-result narrative explains the strategy, outputs, and the next
      modification path without interrupting the first-run flow.
- [x] The README explains why ledgr matters after the first visible result.
- [x] The README includes the core pipeline mental model.
- [x] The README explains target vectors where the first strategy is introduced.
- [x] The README gives a concrete next modification path.
- [x] `README.Rmd` is the editable source and `README.md` is rendered from it.
- [x] The README no longer contains hand-written "Expected result" blocks.
- [x] The opening explains pulses and how ledgr differs from vectorized
      frameworks.
- [x] The first path attaches `ledgr` and `tibble`, not the full `tidyverse`.
- [x] Trade inspection uses natural rendered tibble output, not
      `print(as.data.frame(...))`.

**Test Requirements:**
- `R --vanilla -f tools/check-readme-example.R`
- Manual copy-paste check in a clean R session

**Acceptance Audit (2026-04-25):**
The README now starts with runnable code and expected results. The first
backtest creates synthetic business-day OHLCV data, runs `ledgr_backtest()`,
prints summary/trade output, and demonstrates deterministic replay through
normalized `ledger` and `equity` comparisons. The example was smoke-tested
against an installed copy of the current checkout via `Rscript --vanilla`.
After reviewer feedback, the README was polished with a post-result "Why
ledgr?" frame, the core pipeline mental model, strategy-contract examples, a
renamed trust check, and a concrete next-modification path. The polished README
example was smoke-tested again against an installed copy of the current checkout
via `Rscript --vanilla`. The reusable `tools/check-readme-example.R` gate
remains tracked under `LDG-604`.

**Reviewer-Driven README Structure Decision (2026-04-25):**
The next LDG-601 polish pass should move from hand-written Markdown output to a
rendered `README.Rmd`. The front matter should render `README.md` with
`github_document`, so GitHub still displays a normal Markdown README while the
source remains executable. The first runnable path should attach `ledgr` and
`tibble`, then inspect trades with `bt |> as_tibble(what = "trades")`. Do not
attach the full `tidyverse` in the 5-minute path; ledgr should remain
tidyverse-adjacent without making the full tidyverse a first-run requirement.

The opening narrative should explain what ledgr is under the hood before
installation: an event-sourced backtesting engine that advances through pulses,
records events in a ledger, and derives trades/equity/metrics from those
events. It should explicitly distinguish this from vectorized backtesting
frameworks that compute portfolio results directly from signals and price
arrays. The core mental model should be:
`data -> sealed snapshot -> pulses -> event ledger -> results`.

**Rendered README Audit (2026-04-25):**
`README.Rmd` now owns the README source and renders `README.md` with
`github_document`. The generated README opens with the pulse/event-ledger model,
uses `library(ledgr)` plus `library(tibble)`, and inspects trades with
`bt |> as_tibble(what = "trades")`. Hand-written "Expected result" blocks were
removed in favor of rendered R output. Local rendering used the bundled RStudio
Pandoc path because Pandoc was installed but not on `PATH`; `LDG-604` should
turn this into a repeatable CI check.

The install snippet uses the canonical GitHub repository path:
`pak::pak("blechturm/ledgr")`.

**Narrative Cleanup (2026-04-25):**
The standalone "What Happened", "Strategy Contract", and Linux/WSL
troubleshooting sections were removed from the README. The target-vector
contract is now introduced before the first strategy implementation, and the
ledger/equity shape check lives inside the "Why ledgr?" flow where it supports
the reproducibility claim.

The first backtest walkthrough is now split into data creation, target-vector
contract, strategy definition, backtest execution, and result inspection. The
strategy example uses a small `close_price()` helper instead of constructing a
named lookup vector, so the strategy body reads in terms of the current pulse
and target holdings.

**Final README Framing Polish (2026-04-25):**
The opening now states ledgr's value directly: reproducible and auditable
backtests. The heavier explanation of pulses and sequential state evolution was
moved below the first visible result, inside the "Why ledgr?" section. That
section now explains the non-dogmatic distinction from full-array backtests:
ledgr follows the step-by-step process where new data arrives, a strategy sees
one pulse, positions/cash can change, and every state change is recorded in the
event ledger. The determinism section was renamed "Optional But Important" and
the README now says the invariant is matching ledger/equity outputs across
identical data and strategy, not the exact toy output values.

**Spec Reference:** Sections 0, 1/R1-R3, 2.1

---

## LDG-606: Pulse Context Strategy Authoring Helpers

**Priority:** P1
**Effort:** 1 day
**Dependencies:** LDG-601, LDG-605

**Description:**
Add human-readable pulse context helpers so strategy authors do not need to
memorize the internal `ctx$bars`, `ctx$features`, and `ctx$positions`
data-frame layouts for common operations.

The README exposed this API gap: a strategy should read like strategy logic,
not like manual data-frame plumbing.

Treat this as a strategy authoring interface, not a generic convenience layer.
The helpers should nudge users toward readable pulse-by-pulse code and the
core ledgr contract: strategies read the current pulse and return target
holdings.

**Proposed Strategy Syntax:**

```r
strategy <- function(ctx) {
  c(
    AAA = if (ctx$close("AAA") > 100.4) 10 else 0,
    BBB = if (ctx$close("BBB") > 80.0) 5 else 0
  )
}
```

For mutable target construction:

```r
strategy <- function(ctx) {
  targets <- ctx$targets(default = 0)

  if (ctx$close("AAA") > 100.4) {
    targets["AAA"] <- 10
  }

  targets
}
```

**Tasks:**
1. Add pulse-context methods for common OHLCV lookups:
   `ctx$bar(id)`, `ctx$open(id)`, `ctx$high(id)`, `ctx$low(id)`,
   `ctx$close(id)`, and `ctx$volume(id)`.
2. Add portfolio/target helpers:
   `ctx$position(id)` and `ctx$targets(default = 0)`.
3. Preserve the existing long-table and wide-table context fields
   (`ctx$bars`, `ctx$features`, `ctx$features_wide`) for advanced users and
   backward compatibility.
4. Keep `ctx$feature(id, name)` behavior compatible with the v0.1.2 runtime and
   interactive pulse contexts.
5. Do not add `ctx$cash()` or `ctx$equity()`. `ctx$cash` and `ctx$equity`
   already exist as scalar fields, and function variants would make context
   code ambiguous.
6. Require exact instrument matching. Do not partial-match identifiers.
7. Make scalar accessors return unnamed length-one values for one instrument.
   Do not return named vectors, rows, or list-columns from scalar helpers.
8. Make `ctx$position(id)` return `0` for a known instrument with no current
   position, but fail clearly for instruments outside `ctx$universe`.
9. Build per-pulse lookup vectors or maps when constructing or refreshing the
   context so accessors do not scan `ctx$bars` repeatedly during strategy
   execution.
10. Add optional pipe-friendly exported helpers only if they remain clearly
    namespaced, for example `ledgr_ctx_close(ctx, "AAA")`. Do not export
    unprefixed names such as `get_close_price()`.
11. Update the README strategy example after helper implementation.
12. Update the getting-started vignette to prefer the accessors.

**Acceptance Criteria:**
- [x] Runtime pulse contexts expose `ctx$close("AAA")` and related OHLCV
      accessors.
- [x] Interactive `ledgr_pulse_snapshot()` contexts expose the same accessors.
- [x] `ctx$targets(default = 0)` returns a named numeric vector over
      `ctx$universe`.
- [x] `ctx$cash` and `ctx$equity` remain scalar fields; no `ctx$cash()` or
      `ctx$equity()` methods are added.
- [x] Scalar accessors return unnamed length-one values.
- [x] Instrument matching is exact; partial identifiers do not match.
- [x] `ctx$position(id)` returns `0` for known flat instruments.
- [x] Missing instruments produce clear errors that name the requested
      instrument and available universe.
- [x] Missing bar fields produce clear errors that name the field.
- [x] Accessors are backed by per-pulse lookup structures, not repeated
      data-frame scans.
- [x] Existing `ctx$bars`, `ctx$features`, `ctx$features_wide`, and
      `ctx$feature()` behavior remains backward compatible.
- [x] The README no longer needs local helper functions such as
      `close_price <- function(id) ...`.

**Performance Guardrail:**
Accessor overhead must be negligible compared with pulse execution. Add a
targeted test or microbenchmark-style check showing that repeated accessor calls
do not perform repeated full `ctx$bars` scans. The implementation should build
lookup state once per pulse.

**Test Requirements:**
- `tests/testthat/test-pulse-context-accessors.R`
- `tests/testthat/test-backtest-wrapper.R`
- `tests/testthat/test-indicator-tools.R`
- README render smoke test

**Acceptance Audit (2026-04-25):**
Runtime and interactive pulse contexts now expose `ctx$bar(id)`, OHLCV scalar
accessors, `ctx$position(id)`, and `ctx$targets(default = 0)`. The helpers use a
hidden per-pulse lookup environment so repeated scalar accessors do not scan
`ctx$bars`; `ctx$cash` and `ctx$equity` remain scalar fields. The README
strategy now uses `ctx$targets()` and `ctx$close()` instead of direct
`ctx$bars` indexing. Local verification passed with
`testthat::test_local('.', filter = 'acceptance-v0.1|pulse-context-accessors|strategy-contracts|backtest-wrapper|indicator-tools', reporter = 'summary')`.

**Spec Reference:** Sections 0, 1/R2, 1/R5, 2.1

---

## LDG-602: Getting Started Vignette and Historical Data Paths

**Priority:** P1
**Effort:** 1-2 days
**Dependencies:** LDG-601, LDG-606

**Description:**
Update the getting-started vignette so it teaches the public workflow in the
same order a first-time user experiences it: run first, inspect results, learn
the strategy contract, then debug interactively.

**Tasks:**
1. Restructure the vignette around a result-first flow.
2. Document the in-memory `data.frame` path as the primary first-use path.
3. Document the CSV-to-sealed-snapshot path for reproducible research.
4. Document Yahoo as a convenience source and label it non-deterministic.
5. Use the exact v0.1.2 API names and arguments in every snippet.
6. Clarify that reproducibility guarantees begin after data is sealed.
7. State that live, streaming, paper-trading, and broker integrations are out
   of scope for v0.1.3.

**Acceptance Criteria:**
- [ ] The vignette uses `as_tibble(bt, what = "trades")` and
      `as_tibble(bt, what = "ledger")` correctly.
- [ ] The three historical data paths are covered: in-memory, CSV snapshot,
      and Yahoo snapshot.
- [ ] Yahoo examples are explicitly marked as convenience/non-deterministic.
- [ ] Snapshot sealing is explained as the start of the auditable data contract.
- [ ] The vignette does not imply support for live or streaming data.

**Test Requirements:**
- `R CMD check --no-manual --no-build-vignettes`
- `pkgdown::build_site()` link check

**Spec Reference:** Sections 1/R2, 2.2

---

## LDG-603: Exported Reference and `@examples` Audit

**Priority:** P1
**Effort:** 1-2 days
**Dependencies:** None

**Description:**
Audit exported user-facing functions and make reference examples safe for CRAN,
offline use, and installed-package execution.

**Tasks:**
1. Enumerate exported user-facing functions from `NAMESPACE`.
2. Add an `@examples` block for each public function where useful.
3. Document explicit reasons where examples are intentionally omitted.
4. Ensure examples use `tempfile()` for databases and generated files.
5. Guard optional dependencies with `requireNamespace()`.
6. Remove or rewrite examples that depend on network access, local repository
   files, or source-tree loading.
7. Regenerate Rd files.

**Acceptance Criteria:**
- [ ] Every exported user-facing function has an example or documented omission.
- [ ] Examples are offline-only and use temporary files/databases.
- [ ] Optional packages are guarded with `requireNamespace(..., quietly = TRUE)`.
- [ ] No example depends on network access, local repository files, or
      `pkgload::load_all()`.
- [ ] `R CMD check` runs examples without warnings.

**Test Requirements:**
- `devtools::document()`
- `R CMD check --no-manual --no-build-vignettes`

**Spec Reference:** Sections 1/R1, 1/R4, 3/Gate 2

---

## LDG-605: Error Message Polish for Target Vectors

**Priority:** P0
**Effort:** 0.5-1 day
**Dependencies:** LDG-601

**Description:**
Improve common strategy-contract errors so new users can diagnose failed
functional strategies without reading internals.

**Tasks:**
1. Audit validation paths for functional strategy return values.
2. Add an explicit error when the target vector is unnamed.
3. Add explicit missing/extra instrument reporting when target names do not
   match `ctx$universe`.
4. Ensure errors name the required contract: a named numeric target vector with
   names matching `ctx$universe`.
5. Add regression tests for unnamed, missing, extra, and non-numeric returns.

**Acceptance Criteria:**
- [x] Unnamed target vectors produce a clear, actionable error.
- [x] Missing instruments are listed in the error message.
- [x] Extra instruments are listed in the error message.
- [x] Error messages mention the expected named numeric target-vector contract.
- [x] Existing strategy validation tests continue to pass.

**Test Requirements:**
- `tests/testthat/test-strategy-contracts.R`
- `tests/testthat/test-backtest-wrapper.R`

**Acceptance Audit (2026-04-25):**
`ledgr_validate_strategy_targets()` now uses one explicit contract phrase:
"a named numeric target vector with names matching ctx$universe". Target-name
mismatches report missing and extra instruments in the same error. Targeted
tests passed with
`testthat::test_local('.', filter = 'strategy-contracts|backtest-wrapper')`.

**Spec Reference:** Section 1/R5

---

## LDG-604: Automation, CI Gates, and Cold Start Script

**Priority:** P0
**Effort:** 1-2 days
**Dependencies:** LDG-601, LDG-602, LDG-603, LDG-605, LDG-606

**Description:**
Turn the v0.1.3 release gates into repeatable checks that run locally and in CI.

**Tasks:**
1. Add `tools/check-readme-example.R`.
2. Make the README check run under `R --vanilla`.
3. Normalize deterministic comparisons for `ledger_events` and `equity_curve`.
4. Add CI steps for README check, `rcmdcheck`, `pkgdown::build_site()`, and the
   existing coverage gate.
5. Document cold-start commands for a fresh checkout on a different machine.
6. Verify Ubuntu and Windows CI pass.

**Acceptance Criteria:**
- [ ] `R --vanilla -f tools/check-readme-example.R` passes.
- [ ] `rcmdcheck::rcmdcheck(args = c("--no-manual", "--no-build-vignettes"),
      error_on = "warning", check_dir = "check")` passes.
- [ ] `pkgdown::build_site()` completes with no broken internal links.
- [ ] README deterministic validation follows spec requirement R3.
- [ ] Cold-start documentation includes exact dependency-install and execution
      commands.
- [ ] CI is green on Ubuntu and Windows.

**Test Requirements:**
- `tools/check-readme-example.R`
- `.github/workflows/R-CMD-check.yaml`
- `tools/check-coverage.R`
- `pkgdown::build_site()`

**Spec Reference:** Section 3

---

## Out of Scope

Do not add new execution semantics in v0.1.3. The following remain out of scope:

- Live trading
- Paper trading
- Broker adapters
- Streaming data
- Parameter optimization
- Walk-forward testing
- PerformanceAnalytics integration
- New indicator-library expansion
- Shiny dashboards
