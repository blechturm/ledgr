# ledgr v0.1.3 Specification - Onboarding & Polish

**Document Version:** 1.6.0
**Author:** Max Thomasberger
**Date:** April 25, 2026
**Release Type:** Onboarding Milestone
**Status:** **LOCKED FOR EXECUTION**

## 0. Goal

Transition **ledgr** from a working engine to a usable product. Success is
measured by the **"5-Minute Success Path"**: a stranger can install the package
and execute a complete, auditable backtest in a fresh R session without
modification or confusion.

---

## 1. Hard Requirements (Invariants)

* **R1 Fresh Session Integrity**: All code examples MUST run in a vanilla R
  instance (`R --vanilla`) using only the installed package.
* **R2 API Precision**: Documentation MUST mirror v0.1.2 implementation exactly
  (for example, `what = "trades"`).
* **R3 Deterministic Validation**: The README example MUST produce identical
  normalized `ledger_events` and `equity_curve` results across separate
  sessions/platforms. The check MUST either use a fixed `run_id` or compare
  normalized result tables after excluding identity/path columns (`run_id`,
  `event_id`, `db_path`). Floating-point differences below `1e-10` are
  acceptable; otherwise, values must be rounded before comparison.
* **R4 `@examples` Policy**: Examples MUST be offline-only, use `tempfile()`,
  avoid local repository files, and wrap optional dependencies in
  `requireNamespace()`.
* **R5 Error Clarity (CORE UX)**: Common user errors (unnamed vectors,
  mismatched universes) MUST produce clear, actionable error messages.

---

## 2. Content & UX Strategy

### 2.1 The Master README

* **Minimal Working Example (MWE)**: Self-contained block defining synthetic
  data, setting a fixed seed, and running a backtest.
* **"What Just Happened?"**: A 3-bullet summary explaining the strategy logic,
  the output metrics, and how to modify the next run.
* **The ledgr Difference**: A two-line example showing a "provable
  reproducibility" check and a hint at "tamper detection."
* **Troubleshooting**: Concise Linux/WSL binary installation snippet.

### 2.2 Getting Started Vignette

* **Result-First Flow**: First run -> Inspection -> Strategy Contract ->
  Interactive Debugging.
* **Historical Data Paths**:
    * *Primary*: In-memory `data.frame`.
    * *Reproducible*: CSV -> sealed snapshot.
    * *Convenience*: Yahoo, explicitly labeled as a non-deterministic source.

---

## 3. Release Gates (Executable)

1. **Gate: README Check**:
   `R --vanilla -f tools/check-readme-example.R` passes.
2. **Gate: Integrity**:
   `rcmdcheck::rcmdcheck(args = c("--no-manual", "--no-build-vignettes"), error_on = "warning", check_dir = "check")`
   results in 0 Errors/Warnings.
3. **Gate: Documentation**:
   `pkgdown::build_site()` completes with 0 broken internal links.
4. **Gate: Cold Start**:
   Clone the repo on a different machine and successfully run the README
   example without manual fixes.

---

## 4. Implementation Notes

### 4.1 DuckDB Run Lifecycle

ledgr writes run metadata, ledger events, features, and derived equity rows to
DuckDB, then tests and user code often reopen the same database from a fresh
connection. Runner code MUST force a DuckDB `CHECKPOINT` before disconnecting a
write connection.

This is required for cross-platform determinism. On Linux, especially in CI,
rows written by a completed run may remain invisible to a later fresh
connection if the process relies only on disconnect/shutdown behavior. The
observed failure mode is a consecutive-run replay where the first run is
persisted but the second run's `runs`, `ledger_events`, `features`, and
`equity_curve` rows are missing from the reopened database.

Implementation rule:

```r
on.exit({
  ledgr_checkpoint_duckdb(con)
  DBI::dbDisconnect(con, shutdown = TRUE)
  duckdb::duckdb_shutdown(drv)
}, add = TRUE)
```

Any future code path that owns a DuckDB write connection and expects another
connection to read the same file immediately must follow the same rule. This is
a lifecycle guarantee, not an acceptance-test workaround.

---

# v0.1.3 Task Breakdown (Tickets)

The v0.1.3 ticket range starts at `LDG-601` to avoid collisions with v0.1.2
ticket IDs.

| Ticket ID | Title | Priority | Dependency |
|:---|:---|:---|:---|
| **LDG-601** | **Master README & MWE (Success-Focused)** | **High** | None |
| **LDG-603** | **Exported Reference & `@examples` Audit** | High | None |
| **LDG-606** | **Pulse Context Strategy Authoring Helpers** | High | LDG-601, LDG-605 |
| **LDG-602** | **"Getting Started" Vignette (Path Logic)** | High | LDG-601, LDG-606 |
| **LDG-605** | **Error Message Polish (Target Vectors)** | **High** | **LDG-601** |
| **LDG-604** | **Automation: CI Gates & Cold Start Script** | Medium | LDG-601, LDG-602, LDG-603, LDG-605, LDG-606 |

### LDG-601 - Master README & MWE

**Acceptance Criteria**:

* Copy-pasteable MWE with fixed seed.
* Includes "What just happened?" section.
* Includes a visual "Identity" hint, for example:
  `# Reproducibility: normalized ledger/equity match across runs`.
* Uses either a fixed `run_id` or a normalized comparison that excludes
  identity/path columns.
* Runs from an installed package in `R --vanilla` without `pkgload::load_all()`.

### LDG-605 - Error Message Polish (PROMOTED)

**Acceptance Criteria**:

* Strategy validator throws an explicit error if the return vector is unnamed.
* Strategy validator lists missing/extra instruments if the universe does not
  match.
* Error messages name the expected contract: a named numeric target vector with
  names matching `ctx$universe`.
* Existing strategy validation tests continue to pass.

### LDG-606 - Pulse Context Strategy Authoring Helpers

**Acceptance Criteria**:

* Runtime and interactive pulse contexts expose readable scalar accessors such
  as `ctx$bar(id)`, `ctx$close(id)`, `ctx$position(id)`, and
  `ctx$targets(default = 0)`.
* Accessors must be exact-match and fail clearly for missing instruments or
  missing bar fields.
* `ctx$cash` and `ctx$equity` remain scalar fields, not methods.
* Helpers are derived views over the existing pulse context and must not change
  feature computation, strategy validation, or execution semantics.

### LDG-602 - Getting Started Vignette

**Acceptance Criteria**:

* Labels Yahoo path as "Convenience/Non-Deterministic."
* Uses `as_tibble(bt, what = "trades")` and `what = "ledger"` correctly.
* Shows the three historical data paths: in-memory data frame, CSV snapshot,
  and Yahoo snapshot.
* Explains that reproducibility guarantees begin after data is sealed in a
  snapshot.
* Explicitly states that live/streaming data is out of scope for v0.1.3.

### LDG-603 - Exported Reference & `@examples` Audit

**Acceptance Criteria**:

* Every exported user-facing function has an `@examples` block or an explicit
  documented reason for omission.
* Examples are offline-only and use temporary files/databases.
* Examples that require optional packages are guarded with
  `if (requireNamespace(..., quietly = TRUE))`.
* No example depends on network access, local repository files, or
  `pkgload::load_all()`.
* `R CMD check` runs examples without warnings.

### LDG-604 - Automation: CI Gates & Cold Start Script

**Acceptance Criteria**:

* Adds `tools/check-readme-example.R` and runs it under `R --vanilla`.
* CI runs the README example check, `rcmdcheck`, `pkgdown::build_site()`, and
  the existing coverage gate.
* README deterministic validation compares normalized `ledger_events` and
  `equity_curve` outputs according to R3.
* Cold-start documentation names the exact commands used to install dependencies
  and run the README example on a fresh checkout.
* The CI workflow remains green on Ubuntu and Windows.
* Runner-owned DuckDB write connections checkpoint before
  disconnect/shutdown, per Implementation Note 4.1.
* `contracts.md` is synchronized with persistence, canonical JSON, and
  reconstruction invariants needed by future agents.
