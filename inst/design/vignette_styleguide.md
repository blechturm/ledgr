# ledgr Vignette Styleguide

**Status:** Accepted styleguide from the v0.1.8.5 teachability cycle.
**Owner:** Maintainer.
**Canonicalization Point:** Canonized at the v0.1.8.5 release gate. Future
documentation cycles may revise this file, but the rules below describe the
accepted article bar that shipped with v0.1.8.5. Revised on 2026-09-28 after
the v0.2.0.2 documentation review with the house rules, canonical homes and
flow read, which address problems between articles rather than within one.
**Scope:** Installed user-facing articles and vignettes. README guidance is
adjacent but README may keep its existing render workflow unless the active
packet explicitly migrates it.

This design doc itself does not use Quarto callouts because it is an internal
reference, not a user-facing article. The rules below apply to files in
`vignettes/`.

This guide exists because v0.1.8.5 is not only a documentation-completeness
release. It is a teachability release. Articles should help a serious user
learn the ledgr workflow in the right order, with enough visual hierarchy to
scan and enough precision to avoid wrong research habits.

Quarto is the target source format for installed vignettes in this cycle.
Where a file is still `.Rmd`, treat it as migration input.

---

## House Rules

These rules apply to every article and keep the articles reading as one set.
The numbered sections carry the detail. Rules marked *checkable* can be
enforced by search over the sources or rendered Markdown; enforce them with a
documentation-contract block rather than by review.

1. Strategies read whole vectors: `ctx$vec$close`,
   `ctx$vec$feature(feature_id)`. `ctx$feature()` and `ctx$features()` are for
   inspecting one instrument. The one exception is a strategy that reads
   active aliases, which must loop over `ctx$features(id)`; show it with the
   disclosure sentence in Section 9.
2. The reader sees every strategy the lesson depends on, and it executes. The
   first strategy a reader runs, in the README and Quickstart, is always
   visible. A later article may run a `ledgr_demo_*` strategy after one
   sentence saying what it does and what each parameter means.
3. A candidate ID never appears without the parameters that produced it.
   Print the candidate or select its parameter columns. If that takes
   clutter, route the gap as Section 5 describes.
4. Run and snapshot IDs are fixed literals, never built from `Sys.getpid()`,
   the clock or random draws. The freshness check needs deterministic renders.
   *Checkable.*
5. An article that closes and reopens a store names it with
   `ledgr_temp_store()` and says once that a real project passes a persistent
   path. Other articles may rely on the default temporary store.
6. Every `eval: false` chunk states its reason in the adjacent prose, and the
   reason is one of the four in Section 5. Chunk options use the `#|` form.
   *Checkable* for the header form.
7. Every warning the render shows is explained where it first appears in the
   article. A chunk may set `warning: false` only when its prose says why the
   warning is irrelevant to the lesson. No other stray console output reaches
   the render: package attach and masking messages, startup banners, progress
   output and incidental messages are suppressed where they arise, in the
   project or setup configuration, never by hiding output the lesson uses.
   *Checkable* for known stray-output patterns.
8. Output that looks alarming or impressive gets one sentence of
   interpretation. The common case is annualized metrics from a few bars of
   fixture data: say once that they are an artifact of the sample.
9. A fact in Section 9's list is stated in its home article and linked from
   everywhere else, not restated in other words.
10. A concept is used without a gloss only after its home article in the
    Section 12 reading flow. Before that, give a one-sentence gloss and link
    the home.
11. No words a user cannot act on; Section 3 lists them. *Checkable.*
12. Where Next starts with the next article in the reading flow.

---

## 1. Article Job

Every article has one primary job. State or demonstrate that job in the first
section or first paragraph.

Good:

```text
You have an idea for a trading rule. How do you turn that hunch into evidence
you can reopen, inspect, and explain later?
```

Weak:

```text
This article describes several ledgr functions related to research.
```

The article job is not the same as a function list. A function list belongs in
reference documentation. An article should answer a workflow question.

---

## 2. Opening Pattern

Use an inverted-pyramid opening:

1. Name the user outcome.
2. Explain why it matters.
3. Show the path or artifact map.
4. Only then introduce detailed vocabulary.

The reader should know what they will be able to do before they see code.

Good shape:

```text
You have an idea...
Here is the evidence loop...
By the end, you will have...
```

Avoid starting with a table of contents in prose. A section list is useful for
maintainers; it rarely teaches a user.

---

## 3. Voice

Use second person for workflow guidance:

- "You will create..."
- "Before you sweep..."
- "If this run has no fills, stop here..."

Use present tense unless discussing roadmap scope.

Contractions are allowed when they improve readability: "doesn't", "can't",
"you're". Do not become chatty. ledgr's voice should be warm, direct, and
technical.

Avoid:

- cute analogies;
- exclamation marks;
- apology language;
- long passive chains;
- internal project shorthand that a user cannot act on.

Internal shorthand includes at least: fold core, oracle, touchpoint,
accelerator (outside the compiled-accounting section of Sweeps), legacy and
pre-provenance, parity contract, composable bundle, B2, and ticket, test or
claim IDs such as `LDG-`, `LTB-` and `LCL-`. Say what the reader sees or does
instead: "the engine computes", "this check", "runs created by an older
version". "Tier" means a reproducibility tier and nothing else.

Do not narrate the test suite in a user article. A sentence such as "the
matrix below is the executable oracle used by ledgr's tests", or a section
that ties an article's example to a shared test fixture, is a maintainer
cross-check; it belongs in a test.

Avoid current-version framing in user-facing vignette prose. Do not write
"in v0.1.8.5, ledgr does..." or "currently, this feature works..." when the
article is simply showing the package behavior readers should rely on today.
Assume demonstrated behavior is current unless the article explicitly says it
is historical or unstable.

Roadmap anchoring is different. It is acceptable to say that a future capability
is planned for a named release when that boundary helps the reader understand
scope. Prefer wording such as "the stable public API is planned for v0.1.9.x"
over "in v0.1.8.5, the public API is still internal." The first describes a
future boundary; the second makes the vignette stale the moment the current
release changes.

---

## 4. pkgdown-Safe Callouts

Use ledgr callout divs for guidance the reader should scan before continuing.
Do not use native Quarto callouts in public pkgdown vignettes: pkgdown does not
currently support Quarto callout rendering and falls back to plain blockquotes.
The custom classes below are styled by `pkgdown/extra.css` and render reliably
on the package site.

Preferred forms:

```markdown
::: {.ledgr-callout .ledgr-callout-note}
**Running this yourself**

The code blocks below write to `artifacts/ledgr_store.duckdb`.
:::
```

```markdown
::: {.ledgr-callout .ledgr-callout-warning}
**Promotion is not validation**

Promotion records the selected candidate. It does not prove generalization.
:::
```

Use callouts for:

- runnability caveats;
- demo-data caveats;
- validation or selection-bias caveats;
- pre-CRAN compatibility;
- backup requirements;
- future-roadmap boundaries;
- "this is intentionally not implemented yet" notes.

Callout-type mapping:

| Use case | Callout type |
| --- | --- |
| Runnability caveat ("Running this yourself") | `ledgr-callout-note` |
| Demo-data caveat | `ledgr-callout-note` |
| Selection-bias or validation warning | `ledgr-callout-warning` |
| Backup or persistence requirement | `ledgr-callout-warning` |
| Pre-CRAN compatibility note | `ledgr-callout-warning` |
| Future-roadmap boundary | `ledgr-callout-important` |
| Exercise ("Try it") | `ledgr-callout-tip` |
| Best-practice nudge | `ledgr-callout-tip` |

Do not use callouts for ordinary paragraphs. Too many callouts flatten visual
hierarchy.

During migration, old `.Rmd` articles may use blockquote callouts as a
temporary substitute. Do not add native Quarto callouts or blockquote callouts
once the article is `.qmd`.

---

## 5. Code Chunks

Code should be complete enough that a reader can copy the chunk or understand
why it is illustrative.

Use runnable chunks for ordinary examples. Use `eval: false` only when:

- the article intentionally writes project-local artifacts;
- the example requires external data or network access;
- the section is conceptual and says so plainly;
- the chunk is intentionally a fragment and is labeled as such.

State which reason applies in the prose next to the chunk. A reader should
never wonder whether an unexecuted chunk would work.

Quarto chunk options use YAML-in-comment syntax:

````markdown
```{r}
#| label: experiment-run
#| eval: false

ledgr_run(...)
```
````

Do not use R Markdown header-line syntax such as `{r, eval = FALSE}` in
Quarto files. Labels are useful for cross-referencing diagrams or tables; do
not add labels purely for documentation theatre.

Do not show orphaned fragments as executable chunks. If code depends on
objects such as `ctx`, `target`, or `params`, either show the minimal wrapper
or present it as an illustrative snippet with prose.

Good:

```r
strategy <- function(ctx, params) {
  target <- ctx$flat()
  # ...
  target
}
```

Acceptable illustrative snippet:

```r
values <- ctx$features(instrument_id)
passed_warmup(values)
```

Weak:

```r
target[[instrument_id]] <- params$qty
```

unless the surrounding scope has already been shown.

### Code Clarity

Vignette code should be as free of visual clutter as possible. Concretely:

- Use `library(pkg)` in the prerequisites block, then call functions unqualified. Do not write `dplyr::filter(...)`, `tibble::tibble(...)`, or `purrr::map(...)` in vignette code that has already attached the package.
- Use tidyverse verbs for data-wrangling examples when `dplyr` is attached. Prefer `filter()`, `arrange()`, `select()`, `mutate()`, `slice_head()`, `all_of()`, and `any_of()` over base-R row/column subsetting in user-facing table workflows. ledgr is tidyverse-adjacent; examples should look like readable data analysis, not defensive table plumbing.
- When an object has too many columns for a readable printed table, prefer `glimpse()` or a purposeful `select()` over letting wrapped output dominate the article. Use `select()` when the exact review columns are the lesson; use `glimpse()` when the object shape is the lesson.
- Avoid optional-argument boilerplate repeated across every chunk. If every example passes the same value for the same argument, ask whether the default should change rather than teaching users to repeat the boilerplate.
- Avoid repeated computed expressions when a single intermediate variable would carry the meaning.
- Avoid nested function calls more than two levels deep unless the nesting is the point of the example.

The valid exceptions are semantic. Use base R when base R is the subject of the
lesson, when the object is not tabular, or when preserving an S3 object requires
avoiding a table verb. Use qualified calls when the qualification is
semantically meaningful. The strategy preflight tier system uses `pkg::fn()`
form to distinguish Tier 1 (closed-form), Tier 2 (qualified external call), and
Tier 3 (unresolved external reference). When teaching tier semantics, the
qualification is the lesson; preserve it. The same applies to any explanation
where the qualification itself carries the point.

If a worked example needs visual clutter to make it work, treat that as a signal that the UX or API is missing something. The clutter is the API asking for a default change, a constructor, or a helper. Record the gap as a horizon item or as a note for the next spec packet; do not solve it by piling boilerplate into the vignette.

### Shape-Only Illustrative Snippets

When an article needs to show what a contract looks like without re-teaching
it — typically because the canonical home is another vignette and the
article only needs the shape to anchor a local teaching point — use a fenced
` ```r ` block (not a `{r}` Quarto chunk). The block is visible but does not
evaluate at render time.

The pattern has three parts: a framing sentence that names what the block
illustrates, the fenced block itself, and a cross-link to the canonical
vignette for the full contract.

Template:

````markdown
The demo strategy you assigned above has this shape internally:

```r
crossover_shape <- function(ctx, params) {
  targets <- ctx$flat()
  # ...
  targets
}
```

For the full strategy contract, read
`vignette("strategy-development", package = "ledgr")`.
````

Naming-collision footgun: if the shape-only block uses the same identifier
as a real variable assignment in an evaluated chunk above, careful readers
will wonder which definition the rest of the article uses. The block does
not actually shadow the variable at render time because it does not
evaluate, but the visual ambiguity costs comprehension. Either rename the
identifier in the illustrative block (`crossover_shape`, `strategy_body`,
`sma_strategy_skeleton`) or use disambiguating language in the framing
sentence ("has this shape internally" rather than just "follows this
shape").

Shape-only blocks are distinct from fragment snippets (a few lines out of
context to illustrate one call) and from `eval: false` chunks (real R code
that intentionally does not run for a stated reason). Use them only at
cross-vignette teaching boundaries — never as a substitute for evaluation
when the article's own teaching depends on the code actually working.

---

## Methodological Diagnostics

Methodological diagnostics must teach the method as ledgr ships it, not only
the function call. This applies to statistical, validation, selection-integrity,
business-objective, benchmark, risk, and similar diagnostics where a user can
misread a computed number as stronger evidence than it is.

Required coverage, scaled to interpretation risk:

- **Question:** the research doubt or decision the method addresses.
- **Evidence:** the ledgr artifacts consumed, such as retained returns,
  equity curves, closed trades, metric rows, sweep candidates, or
  walk-forward sessions.
- **Method shape:** enough of the computation to audit the shape and intuition.
  Defer full derivations to cited references.
- **Interpretation:** what high, low, pass, fail, or threshold-crossing values
  mean in ledgr's evidence chain.
- **Limits:** what the method does not prove.
- **Failure modes:** when ledgr refuses to compute, warns, or marks evidence
  incomplete.
- **References:** primary papers, package documentation, or implementation
  notes that justify the method.
- **Worked example:** a small executed example whose output teaches the
  interpretation.

Worked examples for methodological diagnostics must execute, subject only to
the standard `eval: false` exceptions in Section 5: artifact-writing,
external-data, conceptual, or labeled-fragment cases. For high-risk diagnostics,
at least one worked example should be disconfirming or cautionary: it should
show a case where the diagnostic prevents over-trust in an apparently
attractive result.

Worked examples must also be recognizable as research situations, not fixtures
constructed only to make a number appear. Prefer small scenarios with a
calibrating contrast -- for example high-risk versus low-risk evidence, short
sample versus longer sample, or clustered versus independent candidates -- so
the reader can see how interpretation changes.

Organize diagnostics by method family rather than one article per function.
For example, Selection Integrity can teach minimum track-record length, DSR,
effective-trial clustering, and later PBO/CSCV as one story. Clustering belongs
with the DSR/effective-trials evidence path unless a future packet gives it a
larger independent role.

Do not turn method sections into a statistics textbook. Teach the method as
ledgr feeds it and labels it, anchored to ledgr's evidence tables and failure
classes.

Each article or section that ships a methodological diagnostic must add
documentation-contract assertions for the relevant coverage. Do not add
vacuous tests for planned articles that do not exist yet; the assertions land
with the article or method section they cover.

---

## 6. Output

Show output when it teaches the reader what to expect. Prefer real rendered
output from executed chunks whenever the article can use package-owned data,
local fixtures, or a disposable store from `ledgr_temp_store()`. Hand-written `#>` transcript
blocks are brittle: they can drift away from the API and hide breakage that a
render would catch.

Use non-evaluated chunks only when the example cannot run safely or
deterministically during rendering. If a workflow would normally write to a
project-local artifact such as `artifacts/ledgr_store.duckdb`, run the vignette
against a temporary store and explain how users should change the path in a
real project.

If output is not rendered, compensate with:

- naming what the user should inspect;
- explaining what a plausible result would indicate;
- linking to the focused article where output is shown;
- adding a "Try it" exercise that tells the reader what to vary.

Do not leave long sequences of `summary(x)` or `ledgr_results(...)` calls
without saying what the reader is checking.

Do not maintain parallel manual output examples for chunks that are already
evaluated. The rendered output is the example. If that output is too wide,
verbose, or hard to read, simplify the code or improve the API surface instead
of replacing it with a hand-edited transcript.

---

## 7. Diagrams

Use diagrams when they reduce cognitive load or make an abstract distinction
concrete.

Good diagram jobs:

- workflow loops;
- artifact topology;
- train/test or selection/validation boundaries;
- before/after API migration;
- data lineage or provenance flow.

Weak diagram jobs:

- repeating a directory tree without adding meaning;
- decorative flowcharts that restate adjacent prose;
- diagrams whose labels require more explanation than the diagram saves.

Keep diagrams small enough to read at vignette width. As a default, stay under
about seven or eight nodes. If the idea needs more structure, split it into
multiple diagrams or use a static SVG/PNG designed for that complexity.

Mermaid is an acceptable source format for v0.1.8.5 Quarto articles, not a
requirement. Quarto rendering must be verified before accepting a diagram-heavy
article. If Mermaid rendering produces poor visual hierarchy in the target
output, simplify the idea into prose, a table, a text sketch, or a checked-in
static SVG/PNG asset.

---

## 8. Exercises

"Try it" exercises are encouraged when they make the reader test the concept.

Good exercises are:

- concrete;
- one or two questions;
- runnable without extra setup;
- tied to the preceding section;
- designed to reveal a useful tradeoff.

Good:

```markdown
::: {.ledgr-callout .ledgr-callout-tip}
**Try it**

Sort by `total_return` instead of `sharpe_ratio`. Does the first candidate
change? What does that tell you about the selection rule?
:::
```

Avoid broad exercises such as "try other parameters" without a reason to care.
Most articles should have one to three exercises, placed where they reveal a
tradeoff. Not every section needs one.

---

## 9. Cross-Links

Articles should link forward and sideways intentionally.

### Canonical Homes

Each topic has one home article. The home teaches it; every other article
uses it with a link, or with a one-sentence gloss and a link when the home
comes later in the reading flow.

| Topic | Home article |
| --- | --- |
| Sealed snapshots, snapshot hashes, bars-first input | Importing And Sealing Market Data |
| The strategy contract: `function(ctx, params)`, full target vectors, `ctx$flat()`, `ctx$hold()`, `ctx$vec` | Strategy Basics |
| One-pulse testing, the selection-weight-target helper pipeline, share sizing, strategy state | Strategy Authoring Tools |
| Engine feature IDs, feature maps, aliases, active aliases, warmup, the warmup and zero-trade checklist | Indicators And Features |
| Which indicators availability-aware runs accept | Indicators And Features |
| TTR declarations, bundles, bundle naming, TTR warmup | TTR Indicators And Bundles |
| Scalar `fn` and `series_fn` indicators, `gap_contract`, R and CSV adapters | Custom Indicators And External Features |
| Ledger events, fills, trades, equity, metrics | The Accounting Model |
| Cost models and risk chains | Risk And Cost Execution Policy |
| Stores, run IDs, labels, reopening, comparing runs | Experiment Store |
| Reproducibility tiers, strategy preflight, source capture | Reproducibility |
| The research loop: project layout, iterating on strategy code with committed runs, when a parameter question calls for a sweep, the research note | Research Workflow |
| Sweeps, candidates, failure rows, promotion, reopening and recovering a promoted run, the compiled-accounting opt-in | Exploratory Sweeps And Candidate Promotion |
| Look-ahead and leakage, including the `lead(close)` example | Leakage |
| DSR, PBO/CSCV, MinTRL, business-objective criteria | Selection Integrity |
| Walk-forward folds and what they establish | Walk-Forward Evaluation |
| Availability-aware runs and what turns them on | Preparing Point-In-Time Inputs |
| Session calendars, missing observations, trading status, stale marks, quarantine, `ledgr_run_explain()` and `ledgr_run_completion()` | Missing Data And Session Calendars |
| The corporate-action lines in a result print | Cash Distributions |
| Membership, held nonmembers, survivorship | Survivorship Bias And Point-In-Time Universes |
| Decision and fill clocks, next-open fills, the last-bar no-fill, affordability, the `Fill Timing` summary line | How Targets Become Fills |
| Annualization and metric contexts | Metric Contexts And Conventions |
| What ships today versus the roadmap | Design Philosophy: From Research To Production |

### Facts That Must Read The Same Everywhere

These facts drifted apart between articles before. The home states each one;
other articles link rather than paraphrase.

- **Affordability** (How Targets Become Fills): dense fills do not check cash,
  which can go negative; availability-aware runs refuse a cash-consuming fill
  they cannot afford, with reason `insufficient_cash`.
- **Availability-eligible indicators** (Indicators And Features, in its
  support matrix): built-in SMA and returns, custom indicators declaring a
  truthful `gap_contract = "strict_window"`, and single-output TTR SMA on
  `close` declared with only `n`. Every other form, including recursive
  indicators, TTR bundles and other TTR shapes, is refused.
- **Active aliases** (Indicators And Features): use this sentence wherever an
  active-alias strategy loops, so that it can be found and replaced when the
  read ships: "ledgr has no alias-aware whole-universe feature read yet, so a
  strategy that reads active aliases loops over `ctx$features(id)`. With
  fixed feature IDs, use `ctx$vec$feature()`."
- **Promotion** (Sweeps): promotion records which candidate was selected and
  why; it is not validation.
- **Selection diagnostics** (Selection Integrity): DSR, PBO/CSCV, MinTRL and
  business-objective criteria ship. No article lists them as non-goals.
- **Walk-forward** (Walk-Forward Evaluation): held-out folds are dependent
  evidence about a selection rule. They do not prove that it generalizes.
- **Corporate-action print lines** (Cash Distributions): what "Corporate
  actions: NOT SUPPLIED" and "Price basis: UNDECLARED" mean and when they
  matter. The first result in the README and Quickstart gives one sentence and
  links there.
- **Current capability** (Research To Production): ledgr is a research
  runtime; paper and live execution, broker adapters and operational
  observability are roadmap work.

Use `?function_name` for function-level details.

Avoid linking user-facing articles to internal RFCs unless the article is
explicitly a design or roadmap article. For ordinary package users, summarize
the future direction in user language and point to the public roadmap.

---

## 10. Reference Boundary

Vignettes teach workflows and concepts. Roxygen/help pages teach function
contracts.

Put these in help pages:

- argument validation;
- return object fields;
- condition classes;
- exact edge-case behavior;
- exhaustive parameter descriptions.

Put these in vignettes:

- why the function exists;
- where it fits in the workflow;
- how the output changes the next decision;
- common mistakes and how to notice them;
- small worked examples.

If a vignette starts sounding like a man page, shorten the vignette text and
make sure the roxygen page carries the contract.

---

## 11. Related Articles Ending

Most articles should close with a short "Related articles" or "Where next"
section. Do not make users rediscover the reading flow from pkgdown navigation.

Good shape:

```markdown
## Where Next

- For strategy authoring, see ...
- For sweep mechanics, see ...
- For durable stores, see ...
```

The related links should be selective. Link to the next useful article, not the
whole site.

Closing-section order for workflow articles:

1. Final mechanical step, such as "Reopen From Store".
2. Reflective section, if any, such as "Why This Is Not Validation".
3. Prescriptive closing, such as "Report And Review Outline".
4. Forward pointer to the next conceptual layer, such as "Future: ...".
5. "Where Next" or "Related Articles" links.

The reader should finish having done the workflow, understood what it did and
did not prove, recorded the decision, and seen where to go next.

---

## 12. Reading Flow

The current reading flow follows `_pkgdown.yml`:

```text
README
  -> Start Here:
       Who ledgr is for
       Quickstart
  -> Building Blocks:
       Importing And Sealing Market Data
       Strategy Basics
       Indicators And Features
       Leakage
       The Accounting Model
       Risk And Cost Execution Policy
       Experiment Store
       Reproducibility
  -> Research Workflow:
       Research Workflow
       Exploratory Sweeps And Candidate Promotion
       Selection Integrity
       Walk-Forward Evaluation
  -> Point-In-Time Evidence:
       Preparing Point-In-Time Inputs
       Missing Data And Session Calendars
       Cash Distributions
       Survivorship Bias And Point-In-Time Universes
  -> Going Deeper:
       Strategy Authoring Tools
       TTR Indicators And Bundles
       Custom Indicators And External Features
       Authoring A Corporate-Action Adapter
       Metric Contexts And Conventions
       How Targets Become Fills
  -> Design / Background:
       Design Philosophy: From Research To Production
       Why ledgr is built in R
```

Each article should know where it sits in that flow. Repeated concepts should
have one canonical home and short cross-links elsewhere.

Concept articles should get the reader through one complete workflow decision.
Technical companion articles can carry denser API detail, edge cases, and
diagnostics, but should still link back to their concept article.

### Release-Gate Roadmap Sections

Articles that summarize the product arc, especially
`research-to-production.qmd`, must be checked at every release gate. If an
article has a "delivered so far" / "planned next" section, update it against
`inst/design/ledgr_roadmap.md`, the active packet, and the release closeout
before tagging the release.

Keep these sections factual:

- list shipped capabilities only after they are in the release being gated;
- name future work with roadmap anchors such as `v0.1.9.x` or `v0.2.x`;
- avoid vague "future" phrasing when a cycle is already planned;
- do not imply that deferred runtime work has shipped.

---

## 13. Anti-Patterns

Avoid:

- README as a feature catalog;
- every vignette re-explaining sealed snapshots from scratch;
- feature factories taught as the primary parameterized sweep path;
- promotion presented as validation;
- exact-ID feature lookup presented as the primary active-alias workflow;
- per-instrument feature loops presented as the strategy path when the feature
  IDs are fixed;
- a concept used before its home article in the reading flow without a gloss
  and a link;
- one fact stated in different words in several articles;
- test fixtures, oracles or maintainer cross-checks narrated in a user
  article;
- internal RFC links in user-facing articles;
- orphaned code snippets that look executable but are not;
- diagrams that restate adjacent prose without adding structure;
- callouts used as decoration;
- output-free examples with no explanation of what to inspect;
- function signatures restated in vignette prose instead of using the function
  and linking to `?function_name`;
- package-qualified function calls (`dplyr::filter(...)`) in vignette code when the package is already attached and the qualification is not semantically meaningful;
- optional-argument boilerplate repeated across every chunk instead of changing defaults or adding a constructor;
- visual clutter in code that papers over a missing helper, default, or constructor instead of flagging the gap as a design note.

---

## 14. Review Checklist

For each article batch, reviewers should ask:

1. Does the opening name the user outcome?
2. Does the article have one primary job?
3. Are callouts used for scan-critical guidance?
4. Are examples runnable or explicitly conceptual?
5. Does rendered output appear where it teaches expectations?
6. Are diagrams doing teaching work?
7. Are exercises concrete and useful?
8. Are function contracts kept in help pages?
9. Are related articles linked intentionally?
10. Does the article avoid competing with another article's canonical home?
11. Does the article preserve the release boundary and roadmap sequence?
12. If the article summarizes delivered/planned capabilities, was that section
    updated during the release gate?
13. Does the article follow the house rules?

Use the checklist at two points:

- **Author self-check** before requesting batch review. The author should be
  able to answer all checklist questions positively or document exceptions.
- **Reviewer check** at batch close. The reviewer treats unresolved checklist
  items as findings unless the author has explicitly justified them in the
  batch notes.

The review is editorial and technical. A vignette can pass tests and still fail
the teachability bar.

### Flow Read

The checklist above works one article at a time. Problems between articles,
such as a concept used before it is taught or one fact told two ways, only
show up when someone reads the whole set in order. Once per release, and after
any change to the reading flow, one reader who did not write the changes reads
the README and every article in Section 12 order and asks:

1. Is any concept used before its home article without a one-sentence gloss
   and a link?
2. Does every fact in Section 9's list read the same everywhere, with only the
   home explaining it?
3. Does every article follow the house rules?
4. Is every line of the first result a reader sees explained, including the
   corporate-action lines?
5. Does each Where Next lead to the next article, so that following them
   reaches the end of the flow?

Findings from the flow read are recorded and corrected like article findings.
