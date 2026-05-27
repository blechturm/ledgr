# ledgr Vignette Styleguide

**Status:** Draft styleguide for the v0.1.8.5 teachability cycle.
**Owner:** Maintainer.
**Canonicalization Point:** After the v0.1.8.5 release gate, revise this file
against the shipped articles and mark it accepted or carry forward the open
items.
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

---

## 4. Quarto Callouts

Use Quarto callouts for guidance the reader should scan before continuing.

Preferred forms:

```markdown
::: {.callout-note}
## Running this yourself

The code blocks below write to `artifacts/ledgr_store.duckdb`.
:::
```

```markdown
::: {.callout-warning}
## Promotion is not validation

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
| Runnability caveat ("Running this yourself") | `callout-note` |
| Demo-data caveat | `callout-note` |
| Selection-bias or validation warning | `callout-warning` |
| Backup or persistence requirement | `callout-warning` |
| Pre-CRAN compatibility note | `callout-warning` |
| Future-roadmap boundary | `callout-important` |
| Exercise ("Try it") | `callout-tip` |
| Best-practice nudge | `callout-tip` |

Do not use callouts for ordinary paragraphs. Too many callouts flatten visual
hierarchy.

During migration, old `.Rmd` articles may use blockquote callouts as a
temporary substitute. Do not add new blockquote callouts once the article is
`.qmd`.

---

## 5. Code Chunks

Code should be complete enough that a reader can copy the chunk or understand
why it is illustrative.

Use runnable chunks for ordinary examples. Use `eval: false` only when:

- the article intentionally writes project-local artifacts;
- the example requires external data or network access;
- the section is conceptual and says so plainly;
- the chunk is intentionally a fragment and is labeled as such.

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

---

## 6. Output

Show output when it teaches the reader what to expect. Prefer real rendered
output from executed chunks whenever the article can use package-owned data,
local fixtures, or a disposable `tempdir()` store. Hand-written `#>` transcript
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
::: {.callout-tip}
## Try it

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

Use article links for workflow depth:

- Strategy Development for strategy authoring;
- Indicators / Feature Maps for feature declarations and alias identity;
- Sweeps for candidate grids, failure rows, and promotion mechanics;
- Experiment Store for durable artifacts and reopen;
- Reproducibility for hashes, source capture, and limits of provenance;
- Metrics And Accounting for derived fills, trades, equity, and metrics.

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

The current v0.1.8.5 reading flow is:

```text
README
  -> Getting Started
  -> Research Workflow
  -> focused articles as needed:
       Data Input / Snapshot Creation
       Strategy Development
       Indicators / Feature Maps
       Sweeps
       Experiment Store
       Reproducibility
       Metrics And Accounting
```

Each article should know where it sits in that flow. Repeated concepts should
have one canonical home and short cross-links elsewhere.

This flow is provisional until the v0.1.8.5 release gate. Batch-level
migration work may split, narrow, or retire articles; update this section when
the shipped article set changes.

---

## 13. Anti-Patterns

Avoid:

- README as a feature catalog;
- every vignette re-explaining sealed snapshots from scratch;
- feature factories taught as the primary parameterized sweep path;
- promotion presented as validation;
- exact-ID feature lookup presented as the primary active-alias workflow;
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

Use the checklist at two points:

- **Author self-check** before requesting batch review. The author should be
  able to answer all checklist questions positively or document exceptions.
- **Reviewer check** at batch close. The reviewer treats unresolved checklist
  items as findings unless the author has explicitly justified them in the
  batch notes.

The review is editorial and technical. A vignette can pass tests and still fail
the teachability bar.
