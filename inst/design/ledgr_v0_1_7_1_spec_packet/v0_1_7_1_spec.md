# ledgr v0.1.7.1 Specification - Installed UX Stabilisation

**Document Version:** 0.1.0  
**Author:** Max Thomasberger  
**Date:** April 30, 2026  
**Release Type:** Patch / UX Stabilisation  
**Status:** **DRAFT FOR REVIEW**

## 0. Goal

v0.1.7.1 is a focused patch release for the v0.1.7 experiment-first API.

v0.1.7 shipped the right public architecture, but the external UX audit found
that an installed-package user still has to work too hard to discover and run a
complete workflow. The patch release closes that gap without changing the
public execution model.

The target user story is:

```text
I install ledgr.
I can find a start-here narrative from the installed package.
I can run an offline example end to end.
I can understand strategy context, feature IDs, warmup, snapshots, and run
comparison without reading source or design docs.
```

v0.1.7.1 also investigates and fixes the one likely runtime defect surfaced by
the audit: TTR MACD warmup for `output = "macd"`.

---

## 1. Inputs

v0.1.7.1 is derived from:

- `inst/design/ledgr_v0_1_7_1_spec_packet/ledgr_triage_report.md`;
- `inst/design/ledgr_v0_1_7_spec_packet/v0_1_7_spec.md`;
- `inst/design/ledgr_v0_1_7_spec_packet/v0_1_6_to_v0_1_7_migration.md`;
- `inst/design/ledgr_ux_decisions.md`;
- `inst/design/contracts.md`;
- `inst/design/model_routing.md`;
- the implemented v0.1.7 experiment-first API and documentation set.

The triage report groups 51 classified feedback items into nine themes. The
patch release prioritises:

- high-severity installed documentation and runnable-example gaps;
- the high-severity MACD warmup runtime defect;
- medium-severity documentation gaps that block ordinary strategy development;
- low-severity Windows shell quoting friction where it affects examples.

---

## 2. Hard Requirements

### R1: Patch Release, Not API Reset

v0.1.7.1 must not introduce a second public workflow or reopen the v0.1.7 API
reset.

The release must preserve:

- `ledgr_experiment()` as the start-here object;
- `ledgr_run()` as the public single-run API;
- `function(ctx, params)` as the strategy contract;
- `ctx$flat()` and `ctx$hold()` as the target constructors;
- snapshot-first experiment-store APIs;
- the v0.1.7 non-goal boundary around sweep/tune execution.

Any new helper API requires explicit review. The default answer for triage
findings in this release is documentation, examples, or a bug fix.

### R2: Installed Narrative Docs Must Be Discoverable

Installed users must be able to discover the main narrative docs from R help
and from pkgdown.

Required installed narrative surfaces:

- getting started with the experiment-first workflow;
- strategy development with `ctx`, `params`, features, warmup, and target
  vectors;
- experiment store and run comparison;
- TTR and built-in indicators.

These docs must be rendered and installed as package vignettes/articles
according to the repository's pkgdown and R package conventions. If a document
is pkgdown-only, the spec or ticket must state why it is intentionally not an
installed vignette.

### R3: At Least One Offline Example Must Be Runnable End To End

The package must ship at least one runnable offline example that works without:

- network access;
- shell quoting tricks;
- manually constructed large data frames;
- hidden test fixtures.

The example must cover:

- snapshot creation from `ledgr_demo_bars` or `ledgr_sim_bars()`;
- `ledgr_experiment()`;
- `ledgr_run()`;
- result extraction with `ledgr_results()` or tibble conversion;
- run listing or comparison;
- cleanup with `close(bt)` and `ledgr_snapshot_close(snapshot)`.

The example may live in an installed vignette, an `examples/` script, or both.
It must be exercised by tests or by a documented release-gate command.

### R4: Experiment-First Must Be The First Path Users See

Docs and examples must not accidentally teach the compatibility path first.

The following surfaces must start with the experiment-first workflow or clearly
redirect to it:

- README quickstart;
- package-level help;
- main getting-started vignette;
- `ledgr_backtest()` help;
- result extraction and experiment-store examples.

Compatibility helpers may remain documented, but they must be framed as
low-level or legacy-compatible escape hatches, not the normal public workflow.

If defaults differ between `ledgr_run()` and compatibility helpers, docs must
either align them or state the difference explicitly.

### R5: Feature IDs Must Be Taught End To End

The user must not have to guess feature IDs.

Docs must show:

- constructing built-in indicators;
- constructing TTR indicators;
- calling `ledgr_feature_id()` on a single indicator and a list;
- attaching features to `ledgr_experiment()`;
- reading features in a strategy with `ctx$feature(instrument_id, id)`;
- exact IDs for common examples, including SMA, RSI, momentum, Bollinger Bands,
  and MACD where applicable.

Examples must use compile-time string IDs inside strategies unless the example
is explicitly teaching a higher-level factory pattern. Runtime feature-ID
lookup from captured indicator objects should not be taught as the default
strategy style.

### R6: Warmup And Short-History Behavior Must Be Explicit

Docs must explain:

- `requires_bars`;
- `stable_after`;
- why early feature values are `NA`;
- how to guard strategy logic with `is.na()`;
- what happens when a snapshot or pulse window is shorter than the indicator
  requires;
- how warmup differs from an unknown feature ID error.

At least one short-history example must show a successful no-trade or guarded
strategy result. At least one failure example must show the classed error users
get when there are not enough bars.

### R7: MACD Warmup Defect Must Be Reproduced And Resolved

The audit reports:

```r
ledgr_ind_ttr(
  "MACD",
  output = "macd",
  nFast = 12,
  nSlow = 26,
  nSig = 9,
  percent = FALSE
)
```

constructing an indicator with `requires_bars = 26`, but first feature
computation failing unless `requires_bars` and `stable_after` are overridden to
34.

v0.1.7.1 must:

- reproduce the failure in a targeted test;
- determine whether the rule is specific to `percent = FALSE`, TTR version,
  output column, or ledgr normalization;
- fix the deterministic warmup rule if the audit is correct;
- keep the TTR warmup table and inference logic in sync;
- update the TTR warmup verification tests against direct TTR output;
- document any intentional limitation if the audit finding is not reproducible.

This is the only planned executable-code bug fix in v0.1.7.1. If investigation
shows a broader feature-engine defect, the ticket must escalate before changing
shared feature semantics.

### R8: Sizing And Allocation Semantics Must Be Documented Before New Helpers

The audit found that target-vector semantics are less natural than user tasks
such as "allocate to the stronger asset".

v0.1.7.1 should document the current model before adding helpers:

- targets are named share/quantity vectors, not weights;
- names must match `ctx$universe`;
- `ctx$flat()` means zero target quantities;
- `ctx$hold()` means current position quantities;
- cash-aware sizing must be calculated by user code in v0.1.7.1;
- short selling and portfolio optimizers remain out of scope.

Examples should include at least one multi-asset allocation pattern using
current APIs. If the docs reveal that a helper is necessary, the helper should
be parked for a later version unless it is trivial and explicitly ticketed.

### R9: Run Discovery And Comparison Semantics Must Be Clear

Docs must explain the current run-management model:

- list runs with `ledgr_run_list(snapshot)`;
- inspect details with `ledgr_run_info(snapshot, run_id)`;
- compare explicit run IDs with `ledgr_compare_runs(snapshot, run_ids = ...)`;
- use labels and tags to organise runs;
- use `ledgr_run_tags()` to inspect tags where relevant.

Comparison metric semantics must be explained, especially:

- `n_trades` counts closed/realised trades, not every fill;
- `win_rate` is derived from realised closed-trade observations;
- a run can have fills but zero closed trades.

Narrative examples must demonstrate the curated defaults directly. The main
path should call:

```r
ledgr_run_list(snapshot)
ledgr_compare_runs(snapshot, run_ids = c("run_a", "run_b"))
```

It should not immediately slice the returned object with base `[` just to make
the output readable. If the default print is not good enough for the vignette,
the print method is the thing to fix. Full-column access belongs in a separate
"dig deeper" note using tibble-compatible tooling, for example:

```r
ledgr_run_list(snapshot) |>
  tibble::as_tibble() |>
  dplyr::select(run_id, status, final_equity, execution_mode)
```

v0.1.7.1 may add documentation examples for tag/label filtering with existing
tibble operations. New filter arguments on `ledgr_run_list()` or
`ledgr_compare_runs()` are out of scope unless explicitly ticketed.

Docs must also clarify handle lifecycle without making cleanup feel like the
central user task:

- completed runs can be reopened with `ledgr_run_open()` without recomputing;
- reopened handles are useful for inspecting full artifacts after a new session;
- `ledgr_run()` and `ledgr_run_open()` return handles that may own DuckDB
  resources while they are live;
- durable handles have a finalizer safety net, but `close(bt)` is still the
  deterministic way to release DuckDB resources in scripts, tests, and long
  sessions;
- snapshot handles should be closed with `ledgr_snapshot_close(snapshot)` when
  the workflow is finished.

The first vignette that calls `close(bt)` must explain this before the call.
`close(bt)` must not fall out of the sky as unexplained ceremony.

### R10: Snapshot CSV Lifecycle Must Be Split Into High-Level And Low-Level Docs

The CSV snapshot docs must distinguish:

- high-level snapshot creation through `ledgr_snapshot_from_*()` helpers;
- low-level adapter/import flows;
- auto-seal behavior;
- reseal behavior for already sealed snapshots;
- how snapshot metadata, start/end dates, and instrument metadata are populated;
- what users must supply manually when using lower-level paths.

The goal is to make the lifecycle unsurprising, not to change snapshot sealing
semantics in this patch release.

Docs must also explain the core data mental model:

- market data is real input data;
- sealing a snapshot freezes that market data and its hash;
- users do not append more instruments, more dates, corrected bars, or tick
  data to an already sealed snapshot;
- those changes create a new snapshot;
- indicator features are derived data computed from sealed market data;
- users may compute new indicators/features against a sealed snapshot at any
  time through new experiments or runs;
- derived feature computation must not mutate the sealed market-data artifact.

This distinction should be introduced before examples show repeated runs with
different indicators against the same snapshot.

### R11: Windows-Facing Examples Must Avoid Shell `$` Expansion Traps

Docs intended for Windows or command-line copy/paste must avoid examples that
break because PowerShell expands `$`.

Preferred pattern:

```text
Put the R code in a .R script and run:
Rscript path/to/script.R
```

One-liners may still be used where useful, but examples containing `ctx$...`,
`df$...`, or function fields must either be PowerShell-safe or avoided.

### R12: Examples Must Use Modern R Data Workflows

README and narrative vignette examples must look like contemporary applied R.

Rules:

- `ledgr_demo_bars` must be presented as a tibble-like object.
- examples should use the base R pipe `|>`.
- examples should use `dplyr::filter()` / attached `filter()` rather than
  `subset()`.
- examples should use `dplyr::between()` where it makes date windows clearer.
- README and narrative vignettes may attach `dplyr` and `tibble` explicitly
  when that improves readability.
- package code and compact Rd examples may still use namespaced calls where
  avoiding attached packages is clearer.
- user-facing examples should avoid raw
  `as.POSIXct("2019-01-01", tz = "UTC")` boilerplate.

v0.1.7.1 should evaluate adding a small UTC datetime helper, tentatively:

```r
ledgr_utc("2019-01-01")
ledgr_utc("2019-01-01 09:30:00")
```

The helper should prefer base R implementation unless a stronger dependency
case is made. Adding `lubridate` as an `Imports` dependency is not assumed by
this spec.

---

## 3. Public Scope

### 3.1 Documentation Updates

Update, reconcile, or add:

- `README.Rmd` and generated `README.md`;
- package-level documentation if present;
- `vignettes/getting-started.Rmd`;
- `vignettes/strategy-development.Rmd`;
- `vignettes/experiment-store.Rmd`;
- `vignettes/ttr-indicators.Rmd`;
- `vignettes/research-to-production.Rmd` where it references the workflow arc;
- relevant Rd examples for `ledgr_experiment()`, `ledgr_run()`,
  `ledgr_backtest()`, indicator constructors, snapshot helpers, run-store APIs,
  and strategy extraction/comparison APIs;
- `_pkgdown.yml` if navigation changes are needed.

Docs must render without network access. Examples must prefer
`ledgr_demo_bars` and `ledgr_sim_bars()`. README and narrative examples should
use the base pipe and modern data-frame verbs instead of `subset()` or
hand-written `as.POSIXct(..., tz = "UTC")` filters.

Example style:

```r
library(ledgr)
library(dplyr)
library(tibble)

bars <- ledgr_demo_bars |>
  filter(
    instrument_id %in% c("DEMO_01", "DEMO_02"),
    between(ts_utc, ledgr_utc("2019-01-01"), ledgr_utc("2019-06-30"))
  )

bars |>
  slice_head(n = 4)
```

### 3.2 Runnable Offline Example

Add or designate a canonical offline example. Candidate location:

```text
examples/experiment_first_demo.R
```

The example should be short enough for a user to read, but complete enough to
serve as a smoke test for the installed package. It should avoid local
workspace paths except for `tempfile()`/`tempdir()` outputs.

If the package does not currently ship `examples/`, a ticket must decide
whether to add that directory or to make the installed getting-started vignette
the canonical runnable example instead.

### 3.3 TTR MACD Warmup

The likely affected implementation area is:

```text
R/indicator-ttr.R
tests/testthat/test-indicator-ttr.R
```

The fix must preserve the deterministic inclusion rule for TTR warmup
inference: only functions whose warmup is deterministic from explicit args may
be inferred.

If MACD `output = "macd"` needs `nSlow + nSig - 1` under some argument
combination, the rules table must represent that distinction explicitly or use
the more conservative deterministic warmup for all MACD outputs, with tests
pinning the decision.

### 3.4 Contracts And Roadmap

Update `inst/design/contracts.md` only where the patch release clarifies an
existing contract. v0.1.7.1 should not redefine execution, persistence, or
identity contracts.

Update `inst/design/ledgr_roadmap.md` to mark v0.1.7.1 as an installed UX and
MACD warmup stabilisation patch between v0.1.7 and the next planned cycle.

---

## 4. Non-Goals

v0.1.7.1 must not implement:

- sweep mode;
- `ledgr_tune()`;
- `ledgr_precompute_features()`;
- persistent sweep results;
- tag/label query DSLs unless explicitly ticketed after review;
- target-weight or portfolio-optimizer APIs;
- short selling;
- broker integrations;
- live or paper trading;
- schema migrations unless the MACD investigation unexpectedly proves a
  persisted identity problem, in which case the ticket must escalate.

---

## 5. Storage, Identity, And Compatibility

v0.1.7.1 should not change the experiment-store schema.

The MACD warmup fix may change indicator fingerprints if and only if the
indicator's explicit identity payload changes. If only `requires_bars` or
`stable_after` changes for an indicator with the same TTR function and args, the
ticket must state whether this affects reproducibility identity or only
execution readiness.

Documentation changes must not teach users to mutate stored run identity. Labels
and tags remain mutable metadata only.

The `DESCRIPTION` version must be `0.1.7.1`, and `NEWS.md` must include a
`# ledgr 0.1.7.1` section before release.

---

## 6. Verification Gates

v0.1.7.1 is complete only when:

- `DESCRIPTION`, `NEWS.md`, spec, roadmap, and tickets agree on version scope;
- the MACD audit case is reproduced and either fixed or explicitly documented
  as not reproducible;
- TTR warmup verification tests pass against direct TTR output;
- installed narrative docs are discoverable from pkgdown and R package
  documentation;
- the canonical offline example runs from a clean R session;
- README and vignettes render offline;
- experiment-first examples precede compatibility examples;
- feature-ID examples cover built-in and TTR indicators;
- warmup/NA behavior is documented with success and failure examples;
- run comparison metric semantics are documented;
- narrative run-list and comparison demos use curated print defaults instead
  of base column slicing;
- full-column access is shown only as an explicit tibble-compatible
  "dig deeper" pattern;
- reopened-run cleanup is framed as deterministic resource cleanup, not as a
  requirement to make the run valid;
- CSV snapshot lifecycle docs distinguish high-level and low-level workflows;
- Windows-facing docs avoid unsafe `$` one-liners;
- README and narrative docs use modern data workflows with the base pipe;
- raw UTC parsing boilerplate is replaced by a documented helper or by a
  clearly justified local pattern;
- no sweep/tune APIs are exported;
- `devtools::test()` passes;
- `R CMD check --no-manual --no-build-vignettes` passes with 0 errors and
  0 warnings;
- pkgdown builds;
- Ubuntu and Windows CI are green.
