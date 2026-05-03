# ledgr v0.1.7.4 Spec

**Status:** Draft
**Target Version:** v0.1.7.4
**Scope:** feature-map authoring UX, auditr documentation fixes, and release-package hygiene
**Inputs:**

- `inst/design/ledgr_v0_1_7_4_spec_packet/ledgr_triage_report.md`
- `inst/design/ledgr_v0_1_7_4_spec_packet/cycle_retrospective.md`
- `inst/design/ledgr_feature_map_ux.md`
- `inst/design/contracts.md`
- `inst/design/release_ci_playbook.md`
- `inst/design/ledgr_design_philosophy.md`
- `C:/Users/maxth/Documents/GitHub/auditr/episodes_v0.1.7.3/`

---

## 1. Purpose

v0.1.7.4 is an authoring-UX and documentation stabilisation release.

v0.1.7.3 made the accounting and indicator story much stronger, but the auditr
cycle still found repeated friction around feature IDs, helper discovery,
short-data diagnostics, and headless copy-paste examples. The package is
holding: 22 auditr episodes exited cleanly and no high-severity ledgr themes
were found. The next improvement is to make correct strategy authoring easier
to discover and harder to write in a stringly typed style.

This release promotes the feature-map design from
`inst/design/ledgr_feature_map_ux.md` into a narrow public authoring surface:

```text
indicator objects -> feature map -> pulse-time feature bundle -> target vector
```

The release must not change ledgr's execution model. Strategies still return
full named numeric target vectors, or helper objects that unwrap to that same
target-vector validator. Feature maps are an authoring convenience over the
existing feature registry and pulse context, not a second strategy path.

---

## 2. Release Shape

v0.1.7.4 has four coordinated tracks.

### Track A - Feature-Map Authoring UX

Add `ledgr_feature_map()`, `ctx$features()`, and `passed_warmup()` so users can
define indicators once, assign readable aliases once, register the same object
with an experiment, and read a named feature bundle inside a strategy.

Plain `features = list(...)` registration remains supported.

### Track B - Auditr Documentation Fixes

Resolve all ledgr-side auditr findings from the v0.1.7.3 cycle:

- hidden `article_utc()` helpers in visible vignette code;
- homepage and accounting-vignette framing gaps from external review;
- leakage examples that make the no-lookahead pulse model concrete;
- helper pages that are discoverable only after reaching a vignette;
- feature-ID and parameter-grid registration friction;
- short-data, warmup, zero-trade, and final-bar diagnosis gaps;
- TTR dependency and multi-output examples;
- non-runnable first-path examples or stale navigation.

### Track C - CSV Snapshot Import Investigation

Investigate the single auditr report of a CSV snapshot import/seal workflow
requiring an undocumented metadata workaround before `ledgr_run()` accepted the
sealed snapshot. If reproducible, fix the code. If not reproducible, document
the supported workflow and add a regression that protects it.

### Track D - Release And Installed-Doc Hygiene

Ensure the installed documentation spine is coherent after the v0.1.7.3
indicator rewrite. Stale generated installed files such as `inst/doc` artifacts
for retired vignettes must not remain in the source tree or release tarball.

---

## 3. Hard Requirements

### R1 - Feature Maps Are One Object Across Declaration, Registration, And Use

`ledgr_feature_map()` returns a typed object carrying:

- user-facing aliases;
- ledgr indicator objects;
- resolved feature IDs from `ledgr_feature_id()`;
- enough metadata for validation and printing.

The same object must work in both places:

```r
features <- ledgr_feature_map(
  rsi = ledgr_ind_ttr("RSI", input = "close", n = 14),
  bb_up = ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20)
)

exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  opening = ledgr_opening(cash = 10000)
)
```

Inside the strategy, the function closes over `features`:

```r
x <- ctx$features(id, features)
```

That closure is the mechanism that gives ledgr a single-definition feature
pattern. The user should not need to maintain a parallel `features = list(...)`
object and a separate named character vector of feature IDs.

### R2 - Plain Feature Lists Remain Supported

Existing code using:

```r
features = list(ledgr_ind_returns(5), ledgr_ind_sma(10))
```

must continue to work. `ledgr_feature_map()` is the preferred form when
aliases and bundled lookup are needed; it does not replace plain lists.

### R3 - Feature Maps Are Copied Into Experiments

A feature map passed to `ledgr_experiment(features = ...)` must be treated as
immutable for that experiment.

`ledgr_experiment()` should extract and store the indicator list and resolved
feature IDs at construction time. Subsequent mutation or rebinding of the
caller-owned `features` variable must not change the experiment's registered
feature set.

### R4 - `ctx$features()` Is Narrow And Pulse-Scoped

The first implementation exposes a per-instrument lookup:

```r
ctx$features(id, features)
```

It returns a named numeric vector keyed by feature-map aliases. It must show
only values available at the current pulse and must preserve the no-lookahead
guarantee already enforced by `ctx$feature()`.

`ctx$features()` must fail loudly when:

- `id` is not in `ctx$universe`;
- `features` is not a valid feature map;
- the feature map requests a feature ID not registered with the experiment;
- any mapped feature value is not scalar numeric at the current pulse.

Warmup `NA` values are not errors.

### R5 - `passed_warmup()` Is A Guard, Not A Pipeline Stage

`passed_warmup(x)` is exported as a strategy-authoring predicate for vectors
returned by `ctx$features()`:

```r
passed_warmup(x)
```

For named numeric vectors produced by `ctx$features()`, `TRUE` means all mapped
features are usable at this pulse. For arbitrary vectors, the function is only
an `all(!is.na(x))` predicate and does not prove why values are missing.

Docs must state this boundary. `passed_warmup()` is not a
`signal -> selection -> weights -> target` pipeline transformation.

### R6 - Feature-Map Validation Is Loud

`ledgr_feature_map()` must reject:

- missing, duplicated, empty, or `NA` aliases;
- aliases that are not syntactically valid R names;
- mapped values that are not ledgr indicator objects;
- duplicate resolved feature IDs unless a later design explicitly supports
  duplicate aliases.

Error messages should name the alias or feature ID involved.

### R7 - Feature Maps Must Not Change Execution Semantics

Feature maps do not alter fill timing, target validation, result storage,
ledger events, metrics, or experiment identity semantics except where the
feature registration object needs to be serialized or fingerprinted exactly as
the equivalent list of indicators would be.

Runs using a feature map and runs using the equivalent list of indicators should
register the same feature definitions and compute the same feature values.

They should also produce the same feature-related experiment identity. For
equivalent indicator sets, the feature portion of `config_hash` must be derived
from the indicator definitions and fingerprints, not from whether the user
supplied those indicators through a plain list or a `ledgr_feature_map()`
wrapper. If a later implementation intentionally makes aliases part of run
identity, that must be a deliberate contract change and documented migration
boundary, not an accidental consequence of this wrapper.

### R8 - Hidden Vignette Helpers Must Not Appear In Visible Code

Visible vignette code must not call hidden setup helpers such as
`article_utc()`. Use exported `ledgr_utc()` or show the helper before first
use.

This release should replace visible `article_utc(...)` calls with
`ledgr_utc(...)` unless a specific example requires a different timestamp
shape.

### R9 - Helper Pages Must Be First-Contact Discoverable

The following help pages must include article links and enough local context to
be useful before a user has read the vignette:

- `signal_return()`;
- `select_top_n()`;
- `weight_equal()`;
- `target_rebalance()`;
- `ledgr_signal_strategy()`;
- `ledgr_signal()`;
- `ledgr_selection()`;
- `ledgr_weights()`;
- `ledgr_target()`;
- `ledgr_feature_map()`;
- `passed_warmup()`.

Each article link should include both forms:

```r
vignette("strategy-development", package = "ledgr")
system.file("doc", "strategy-development.html", package = "ledgr")
```

or, for indicator-specific pages:

```r
vignette("indicators", package = "ledgr")
system.file("doc", "indicators.html", package = "ledgr")
```

### R10 - Feature-ID Friction Must Be Addressed In Current Docs

Until users can fully rely on feature maps, docs must still teach the current
feature-ID workflow:

- call `ledgr_feature_id(features)` before using feature IDs;
- keep feature definitions and IDs together with named objects or named lists;
- register every feature a strategy may request;
- for parameter grids, register all swept lookbacks or construct experiments
  so the feature set matches the parameter domain.

Feature maps should be introduced as the better authoring pattern, not by
removing the old `ctx$feature(id, feature_id)` explanation.

### R11 - Warmup And Zero-Trade Diagnosis Must Cover Short Data

The zero-trade diagnosis recipe must include a preflight step before strategy
debugging:

- compare each indicator's `requires_bars` and `stable_after` to available
  bars per instrument;
- explain that warmup is per instrument;
- distinguish "sample is too short" from "early warmup" and "signal never
  becomes usable";
- mention final-bar no-fill behavior under next-open fills.

### R12 - TTR Examples Must Be Explicit About Dependencies And Outputs

TTR-backed examples must state that `TTR` is a suggested package. Examples that
are skipped when `TTR` is unavailable must say so in prose.

`?ledgr_ind_ttr` and the `indicators` vignette must show:

- BBands output names such as `dn`, `mavg`, `up`, and `pctB`;
- MACD examples with matching explicit arguments for `macd` and `signal`
  outputs;
- TTR warmup inspection through `ledgr_ttr_warmup_rules()`;
- how to debug a TTR-backed feature in `ledgr_pulse_snapshot()`, including the
  requirement that the snapshot handle remains open.

### R13 - CSV Snapshot Import Must Be Verified

The documented CSV path must work without undocumented metadata edits:

```r
snapshot <- ledgr_snapshot_from_csv(
  "data/daily_bars.csv",
  db_path = "research.duckdb",
  snapshot_id = "eod_2019_h1"
)

exp <- ledgr_experiment(snapshot = snapshot, ...)
bt <- ledgr_run(exp, ...)
```

If a new session is involved, the supported reload path must be:

```r
snapshot <- ledgr_snapshot_load("research.duckdb", snapshot_id = "eod_2019_h1")
```

The release must either reproduce and fix the auditr metadata workaround or add
a regression showing the documented path works.

### R14 - Installed Documentation Must Not Contain Retired Teaching Paths

The source tree and package build must not include stale installed
`ttr-indicators` artifacts after `indicators` became the single installed
indicator article.

At minimum, release checks should assert:

- `vignettes/ttr-indicators.Rmd` is absent;
- `inst/doc/ttr-indicators.Rmd`, `.R`, and `.html` are absent if `inst/doc` is
  tracked;
- package help and function help do not link to `ttr-indicators`;
- installed article links target existing installed vignettes.

### R15 - Auditr Harness Bugs Are Recorded But Not Fixed In ledgr

The repeated `ledgr_read_vignette(..., n = Inf)` failures belong to auditr's
`DOC_DISCOVERY.R`, not ledgr. v0.1.7.4 should record this as an external
follow-up so the next audit cycle is less noisy, but ledgr should not add
package API solely to work around that harness bug.

---

## 4. Track A Scope - Feature-Map Authoring UX

### A1 - Feature Map Type

Implement `ledgr_feature_map(...)`.

The object should print compactly with aliases and resolved feature IDs. It
should expose internal helpers only as needed for experiment registration and
pulse lookup; public accessors can be deferred unless required by docs or
tests.

Acceptance points:

- valid named indicators create a feature map;
- alias names are preserved;
- resolved feature IDs match `ledgr_feature_id()` on the same indicators;
- invalid aliases and invalid values fail with classed errors;
- duplicate resolved feature IDs fail before experiment construction writes
  any features.

### A2 - Experiment Integration

Teach `ledgr_experiment(features = ...)` to accept feature maps while keeping
plain lists valid.

The experiment should store the copied indicator definitions, not a mutable
reference to the caller's map object.

Acceptance points:

- list registration still works;
- feature-map registration works;
- mutating or rebinding the caller's map after `ledgr_experiment()` does not
  alter the experiment feature set;
- run provenance/fingerprints remain stable for equivalent indicator
  definitions.

### A3 - Pulse Context Bundle Lookup

Add `ctx$features(id, features)`.

Acceptance points:

- returns a named numeric vector keyed by aliases;
- returns `NA` for known warmup values;
- unknown or unregistered mapped feature IDs fail loudly with available
  feature IDs;
- invalid instrument IDs fail loudly;
- no future data is exposed relative to `ctx$ts_utc`;
- behavior is identical in standard and audit-log execution modes;
- the snapshot or backtest handle lifecycle is documented where pulse
  snapshots are used.

### A4 - Warmup Predicate

Implement and export `passed_warmup(x)`.

Acceptance points:

- returns `TRUE` only when all values are non-`NA`;
- aborts on zero-length inputs with a classed error;
- docs state the semantic boundary: warmup meaning applies to
  `ctx$features()` output;
- behavior is identical in standard and audit-log execution modes;
- examples show it as a guard inside a strategy body, not as a helper pipeline
  stage.

### A5 - Vignette Integration

Update `indicators` and `strategy-development` so feature maps appear only
after the basic pulse, target, feature-ID, and warmup contracts are clear.

`strategy-development` is the primary teaching home because feature maps are a
strategy-authoring ergonomic. `indicators` should introduce the configuration
side and link to the strategy-development feature-map section, but it should not
become a second full tutorial for strategy authoring.

The docs should show both:

- the current explicit `ctx$feature(id, feature_id)` pattern;
- the feature-map pattern as the preferred readable pattern for feature-heavy
  strategies.

---

## 5. Track B Scope - Auditr Documentation Fixes

### B1 - Replace Hidden `article_utc()`

Replace visible vignette uses of `article_utc()` with `ledgr_utc()` and remove
hidden setup helpers where they are no longer needed.

Regenerate rendered vignette markdown if the repo keeps `.md` companions in
sync.

### B2 - Helper Help Pages

Add `@section Articles:` and useful examples to helper pages and value-type
constructors listed in R9.

`ledgr_target()` should be discoverable as the object that unwraps to the same
target-vector validator. `ledgr_signal_strategy()` should remain clearly
described as a wrapper that returns a normal `function(ctx, params)` strategy.

### B3 - Feature-ID And Parameter-Grid Examples

Add examples showing:

- a named list of features;
- `ledgr_feature_id(features)` with readable aliases;
- registering all feature definitions needed by a parameter grid;
- the feature-map equivalent once Track A lands.

The parameter-grid example must be concrete. It should show a swept lookback
parameter where all candidate feature definitions are registered up front, for
example:

```r
features <- list(
  ledgr_ind_returns(5),
  ledgr_ind_returns(10),
  ledgr_ind_returns(20)
)
```

and a strategy that chooses `return_<params$lookback>` at pulse time. The docs
must make clear that helpers do not auto-register swept feature variants.

Do not change existing feature ID generation for documentation convenience.

### B4 - Warmup, Short Data, And Final-Bar Diagnosis

Extend the zero-trade checklist in `metrics-and-accounting` and relevant help
pages with the short-data preflight from R11.

Final-bar no-fill documentation should state that a target emitted on the final
pulse under next-open filling may warn and produce no fill because no next bar
exists.

### B5 - TTR Examples

Update `indicators` and `?ledgr_ind_ttr` with the TTR requirements from R12.

The docs should make it clear when a code path is skipped because `TTR` is not
installed, rather than letting conditional vignette chunks hide the dependency
from readers.

### B6 - First-Path Navigation

Remove or rewrite any first-path navigation that points users or agents to
non-runnable example placeholders.

If an examples README remains, it must clearly say where the runnable installed
workflow starts.

### B7 - External Review Framing Fixes

Add the three confirmed external-review items that were promoted to the
roadmap before the auditr report was available:

- Homepage framing near the canonical workflow:
  "The setup is not overhead. The setup is the audit trail."
- `metrics-and-accounting` clarification near the first `ledgr_backtest()` use:
  the article uses `ledgr_backtest()` as a compact fixture helper for
  hand-checkable accounting examples; the canonical research workflow remains
  `snapshot -> ledgr_experiment() -> ledgr_run()`.
- A leakage wrong/right example, either as a pkgdown-only article or a focused
  `strategy-development` section, contrasting a seductive vectorized
  `lead(close)` lookahead pattern with the ledgr pulse equivalent.

The leakage example should end with the explicit mental-model line:

```text
The ledgr strategy has no object from which it can accidentally read
tomorrow's close.
```

---

## 6. Track C Scope - CSV Snapshot Import Investigation

### C1 - Raw Episode Review

Read the raw Task 008 auditr script and logs before implementation. Identify
the exact workaround and the failing call.

The ticket should classify the finding as one of:

- confirmed ledgr bug;
- documentation mismatch;
- auditr script misuse;
- no longer reproducible after v0.1.7.3.

### C2 - Regression Or Documentation Fix

If confirmed as a bug, add a failing-then-passing regression that uses a CSV
snapshot, sealed store, experiment, and run.

If not a bug, add a regression or vignette example demonstrating the supported
path and explaining any required metadata.

---

## 7. Track D Scope - Release And Installed-Doc Hygiene

### D1 - Stale `inst/doc` Artifacts

Remove stale generated installed docs for retired articles. Add tests or a
release-gate script that prevents retired installed article paths from
reappearing.

The check should specifically guard `ttr-indicators` until a broader installed
doc hygiene rule exists.

### D2 - Roadmap, Contracts, And NEWS

Update:

- `inst/design/ledgr_roadmap.md`;
- `inst/design/contracts.md`;
- `NEWS.md`;
- `_pkgdown.yml`;
- package help and documentation tests.

Contracts must record:

- feature maps are authoring UX, not execution semantics;
- `ctx$features()` is no-lookahead and pulse-scoped;
- `passed_warmup()` is a guard for ledgr feature bundles;
- installed docs must not expose stale retired article paths.

### D3 - Auditr Follow-Up Note

Record the auditr-side `DOC_DISCOVERY.R` `n = Inf` bug as external follow-up,
but do not build ledgr package API for it.

---

## 8. Non-Goals

v0.1.7.4 must stay narrow:

- no sweep/tune implementation;
- no live/paper trading API;
- no new execution path;
- no changes to fill timing or ledger accounting unless required by the CSV
  snapshot investigation;
- no feature roles, selectors, `prep()`, `bake()`, or recipes-like pipeline;
- no `ctx$features_wide()` in the first feature-map implementation;
- no short-selling, margin, or risk-layer semantics;
- no `ledgr_docs()` helper solely to compensate for auditr harness issues;
- no compatibility break for `features = list(...)`.

---

## 9. Release Gate

The release is not ready until:

- `ledgr_feature_map()`, `ctx$features()`, and `passed_warmup()` are
  implemented, documented, and tested;
- feature maps and equivalent plain feature lists register equivalent feature
  definitions;
- feature maps and equivalent plain feature lists produce the same
  feature-related `config_hash` for equivalent indicator definitions;
- feature maps are copied into experiments and are not mutable through caller
  rebinding after experiment construction;
- `ctx$features()` and `passed_warmup()` behave identically in standard and
  audit-log execution modes;
- `passed_warmup()` zero-length behavior is implemented as a classed error and
  tested;
- visible vignette code no longer calls hidden `article_utc()` helpers;
- homepage setup/audit-trail framing is present;
- `metrics-and-accounting` labels `ledgr_backtest()` as a compact accounting
  fixture helper, not the canonical research workflow;
- the leakage wrong/right example is present;
- helper and value-type help pages have article links and local examples;
- feature-ID docs cover aliases and parameter-grid registration;
- warmup/zero-trade diagnostics include short-data and per-instrument checks;
- TTR docs cover dependencies, multi-output names, MACD argument matching, and
  pulse snapshot prerequisites;
- the CSV snapshot import/seal finding is reproduced and fixed, or explicitly
  classified with a regression or documentation update;
- stale `inst/doc/ttr-indicators.*` artifacts are removed or deliberately
  justified by a changed documentation contract;
- auditr `DOC_DISCOVERY.R` `n = Inf` is recorded as external follow-up;
- `contracts.md`, `NEWS.md`, package help, and documentation tests match the
  shipped behavior;
- full Windows and Ubuntu/WSL checks pass using
  `inst/design/release_ci_playbook.md`;
- remote CI is green before any release tag is moved.
