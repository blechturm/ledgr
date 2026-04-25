# ledgr v0.1.3 Implementation Tickets

**Version:** 1.0.0
**Date:** April 25, 2026
**Total Tickets:** 5
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
LDG-601 -> LDG-602 -> LDG-604
LDG-601 -> LDG-605 -> LDG-604
LDG-603 -----------> LDG-604
```

`LDG-604` is the release automation gate. It should not be accepted until the
README, vignette, exported examples, and target-vector error polish are all in
place.

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
5. Add a short "What just happened?" section.
6. Add a concise reproducibility/tamper-detection hint.
7. Add Linux/WSL troubleshooting notes for binary package installation.

**Acceptance Criteria:**
- [ ] The README MWE can be copied into `R --vanilla` and run unchanged.
- [ ] The example does not use `pkgload::load_all()` or local repository files.
- [ ] The example uses a fixed seed and deterministic synthetic data.
- [ ] Reproducibility is demonstrated with either a fixed `run_id` or normalized
      comparison excluding identity/path columns.
- [ ] The "What just happened?" section explains the strategy, outputs, and the
      next modification path in three concise bullets.

**Test Requirements:**
- `R --vanilla -f tools/check-readme-example.R`
- Manual copy-paste check in a clean R session

**Spec Reference:** Sections 0, 1/R1-R3, 2.1

---

## LDG-602: Getting Started Vignette and Historical Data Paths

**Priority:** P1
**Effort:** 1-2 days
**Dependencies:** LDG-601

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
- [ ] Unnamed target vectors produce a clear, actionable error.
- [ ] Missing instruments are listed in the error message.
- [ ] Extra instruments are listed in the error message.
- [ ] Error messages mention the expected named numeric target-vector contract.
- [ ] Existing strategy validation tests continue to pass.

**Test Requirements:**
- `tests/testthat/test-strategy-contracts.R`
- `tests/testthat/test-backtest-wrapper.R`

**Spec Reference:** Section 1/R5

---

## LDG-604: Automation, CI Gates, and Cold Start Script

**Priority:** P0
**Effort:** 1-2 days
**Dependencies:** LDG-601, LDG-602, LDG-603, LDG-605

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

