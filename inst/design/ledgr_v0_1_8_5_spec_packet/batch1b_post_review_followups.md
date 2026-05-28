# Batch 1B Post-Review Follow-Ups (LDG-2443)

**Status:** Pre-commit punch list for Codex.
**Scope:** Two medium findings from the post-review of `vignettes/research-workflow.qmd`. Apply both before committing Batch 1B.

Neither finding blocks the batch. Both are small editorial fixes that should land in the same commit as the Quarto migration so the article ships in its final shape rather than needing an immediate follow-up patch.

---

## M2: Anchor the "API gap" callout to a roadmap cycle

**Location:** [`vignettes/research-workflow.qmd:492-499`](../../vignettes/research-workflow.qmd#L492-L499)

**Problem.** The `callout-warning` block uses the word "future" without naming a roadmap cycle:

> "The next few lines are intentionally lower-level. They show what ledgr already records today, even though a future helper should summarize a promoted run's 'what caused this result?' record without asking users to inspect nested promotion-context fields directly."

This is inconsistent with the walk-forward callout at [`research-workflow.qmd:636`](../../vignettes/research-workflow.qmd#L636), which anchors explicitly: "the public roadmap places walk-forward evaluation at v0.1.9.x." Unanchored "future" claims rot faster than versioned references and leave the reader without a concrete expectation.

**Rationale.** The helper has now been scoped into v0.1.8.6 Workstream C (see [`inst/design/ledgr_roadmap.md`](../ledgr_roadmap.md) v0.1.8.6 detail and [`inst/design/horizon.md`](../horizon.md) 2026-05-27 research-loop ergonomics entry). The callout can reference v0.1.8.6 directly, which both matches the walk-forward callout's anchoring discipline and tells the reader when to expect the gap to close.

**Proposed change.** Replace the callout body with:

```markdown
::: {.callout-warning}
## API gap

The next few lines are intentionally lower-level. They show what ledgr
already records today. The v0.1.8.6 cycle plans a helper that summarizes a
promoted run's "what caused this result?" record without asking users to
inspect nested promotion-context fields directly.
:::
```

The `Design note` callout at [`research-workflow.qmd:412-419`](../../vignettes/research-workflow.qmd#L412-L419) covering the sweep-review helper is also scoped into v0.1.8.6 Workstream C; it should receive parallel anchoring if you agree the same treatment fits — proposed body:

```markdown
::: {.callout-note}
## Design note

This explicit table code keeps the selection rule visible. The v0.1.8.6
cycle plans a sweep-review helper that ranks completed candidates, returns
a compact review table, separates issue rows, and preserves the same
explicit selection rule.
:::
```

The contract test at [`tests/testthat/test-documentation-contracts.R:1077-1079`](../../tests/testthat/test-documentation-contracts.R#L1077-L1079) pins the literal strings `API gap`, `future helper`, and `Design note`. The first and third survive these edits. The second (`future helper`) does not appear in the proposed wording — replace the assertion with `expect_match(doc, "v0.1.8.6 cycle", fixed = TRUE)` or similar so the new anchor is pinned instead.

---

## M3: Annotate the `pkg_root` heuristic in the setup chunk

**Location:** [`vignettes/research-workflow.qmd:16-25`](../../vignettes/research-workflow.qmd#L16-L25)

**Problem.** The setup chunk does:

```r
pkg_root <- if (file.exists("DESCRIPTION")) "." else if (file.exists("../DESCRIPTION")) ".." else NA_character_
if (!is.na(pkg_root) && requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(pkg_root, quiet = TRUE)
}
```

This is correct — it covers Quarto rendering from the project root, Quarto rendering from `vignettes/`, and falls through to `NA` for installed builds where the prerequisites chunk's `library(ledgr)` picks up. But the chain reads as magic. A future contributor (human or agent) might "simplify" it by collapsing the `else if` or removing the `pkgload` branch entirely, breaking local renders silently.

**Rationale.** A one-line comment makes the fallback chain explicit and turns implicit knowledge into reviewable intent. Costs one line; prevents one class of accidental regression.

**Proposed change.** Add the comment immediately above the heuristic:

```r
```{r}
#| label: setup
#| include: false

options(width = 90)
# Local renders load the package from source via pkgload (working dir is
# either project root or vignettes/); installed builds fall through and
# rely on the library(ledgr) call in the prerequisites chunk.
pkg_root <- if (file.exists("DESCRIPTION")) "." else if (file.exists("../DESCRIPTION")) ".." else NA_character_
if (!is.na(pkg_root) && requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(pkg_root, quiet = TRUE)
}
```
```

No contract-test change needed.

---

## Verification after applying both

1. `quarto render vignettes/research-workflow.qmd` — must still render to HTML.
2. `quarto render vignettes/research-workflow.qmd --to gfm` — must still produce `vignettes/research-workflow.md`.
3. `testthat::test_file("tests/testthat/test-documentation-contracts.R")` — must pass after the M2 contract-test assertion update.
4. Verify rendered HTML still shows the `API gap` and `Design note` callouts with the new v0.1.8.6 anchoring text.

Once these are applied, Batch 1B is ready to commit.
