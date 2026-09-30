# Editorial Pass Closeout

**Status:** Accepted by the maintainer on 2026-09-30, at `78a3ce3`. The writer
records no learner-read verdict on its own work; the flow read belonged to the
close review.
**Date:** 2026-09-29
**Cut:** 21
**Workstream:** 29
**Implementation range:** `fca6eb6..86ef8aa`, the close-review corrections
`78f4aba` and `78a3ce3`, and this closeout record.

## Decisions

The maintainer accepted the LDG-2895 flow map's decisions D1 to D7 on
2026-09-28 (Cut 21 decision 4): merge Research Workflow into Sweeps, reorder
the flow, one home per point-in-time topic, single homes for eleven duplicated
lessons, three trims, rename `ttr-and-adapter-indicators` to `ttr-indicators`,
and route the `?ledgr_indicator` gap to LDG-2903. Decision 5 amended D1:
Research Workflow was restored as the loop article. Decision 6 added
`ledgr_target_quantity()` (LDG-2904). Decision 7 teaches strategies as
named-vector manipulation before any helper and made LDG-2898 to LDG-2901 wait
for Workstream 30. Decision 8 adds the intent model to LDG-2900's scope. The
map is `inst/design/audits/v0_2_0_2_flow_map.md`.

## Passes

| Ticket | Pass | Commit |
| --- | --- | --- |
| LDG-2895 | flow map | `fca6eb6`, decisions `469d9d2` |
| LDG-2896 | merges, deletion, moved lessons, rename, redirects | `0e26690`, restored loop `d4ec2d6` |
| LDG-2904 | `ledgr_target_quantity()` | `82faff2` |
| LDG-2897 | openings and hand-offs | `6eb5975` |
| LDG-2898 | code idioms | `477b0f9` |
| LDG-2899 | results, warnings, stray output | `bbd5996` |
| LDG-2900 | one home per shared fact | `84e404b` |
| LDG-2901 | maintainer language | `632eba5` |
| LDG-2903 | `?ledgr_indicator` arities | `86ef8aa` |

Each ticket's evidence in `tickets.yml` carries its detail. Two findings left
the pass as tickets rather than edits: LDG-2918 (trusted strategy recovery
cannot see ledgr's exports, scheduled in Workstream 15 by the maintainer) and
the routed gaps in the flow map's section 5.

## Documentation-Contract Blocks

Each new block is registered in `tests/claims.yml` with the five review
obligations. The change that makes each fail:

| Block | Claim | Fails when |
| --- | --- | --- |
| LTB-0117 | LCL-0117 | the quantity helper ignores the selection, zeroes held nonmembers, accepts a negative quantity or skips the member check |
| LTB-0118 | LCL-0118 | a Where Next list is reordered, a Where Next heading dropped, the README or sidebar start article changed alone, or a setup chunk moved above an opening |
| LTB-0125 | LCL-0125 | an ID is built from the process ID, clock or a random draw, an `{r name}` header returns, `ctx$feature()` sits in a loop over `ctx$universe`, or an active-alias loop lacks the disclosure sentence; 12 violations on the pre-pass tree `83eb356` |
| LTB-0126 | LCL-0126 | a rendered page shows a package attach, masking, startup or build-version message; 3 on the pre-pass tree |
| LTB-0127 | LCL-0127 | a home statement is removed or a known contradicting phrase returns; 18 on the pre-pass tree |
| LTB-0128 | LCL-0128 | a section 3 term appears in a source or render, outside Sweeps' compiled-accounting section for accelerator; 10 on the pre-pass tree |
| LTB-0129 | LCL-0129 | the second `fn` arity is removed from `?ledgr_indicator` |

## Checks

- `tools/render-vignettes-gfm.R --check --all` verifies all 26 articles.
- The five test files that read articles pass: documentation contracts,
  point-in-time input documentation, corporate-action policy, availability
  features and equity corporate-action facts.
- The fast profile passes 490 blocks in 79.53 seconds against the 112-second
  bound.
- `_quarto.yml` sets `message: false` as a knitr default, because Quarto
  silently ignores `message` under `execute:`; that is how the dplyr block
  reached Sweeps.

## Length

The README and article sources total 11,784 lines against 12,003 at `217a41b`,
the flow map's baseline, over the same 27 documents. No article was removed:
Research Workflow was merged, then restored under decision 5, and
`ttr-and-adapter-indicators` was renamed `ttr-indicators` with a redirect.

| Document | Before | After | Change |
| --- | ---: | ---: | ---: |
| README | 198 | 238 | +40 |
| Who ledgr is for | 161 | 158 | -3 |
| Quickstart | 202 | 210 | +8 |
| Data Input | 333 | 273 | -60 |
| Strategy Basics | 517 | 576 | +59 |
| Indicators | 631 | 678 | +47 |
| Leakage | 305 | 314 | +9 |
| The Accounting Model | 497 | 440 | -57 |
| Risk And Cost | 370 | 413 | +43 |
| Experiment Store | 496 | 419 | -77 |
| Reproducibility | 489 | 510 | +21 |
| Research Workflow | 687 | 320 | -367 |
| Sweeps | 706 | 902 | +196 |
| Selection Integrity | 711 | 714 | +3 |
| Walk-Forward | 426 | 444 | +18 |
| Point-In-Time Inputs | 460 | 476 | +16 |
| Missing Data | 590 | 604 | +14 |
| Cash Distributions | 178 | 204 | +26 |
| Survivorship Bias | 1,099 | 1,127 | +28 |
| Strategy Authoring Tools | 689 | 694 | +5 |
| TTR Indicators (renamed) | 401 | 363 | -38 |
| Custom Indicators | 370 | 379 | +9 |
| Adapter Authoring | 222 | 230 | +8 |
| Metric Contexts | 459 | 366 | -93 |
| How Targets Become Fills | 364 | 381 | +17 |
| Research To Production | 262 | 174 | -88 |
| Why R | 180 | 177 | -3 |

## Governance

Cut 21 planned one Type 1 close review over ten tickets (LDG-2895 to
LDG-2904): 1 over 10, `0.100`, against the 0.5 gate. The close review is a
clean-context Codex session that receives the Workstream 29 review brief, the
commit range, the style guide and the accepted flow map, and nothing from the
writer's conversation.

The close review (invocation 1, at `8ce374d`) returned CHANGES_REQUIRED on two
findings: Who ledgr is for showed a helper pipeline before Strategy Basics, in
a plain Markdown block the writer's survey missed, and Reproducibility sorted
its dependency list with locale-dependent `sort()`. Both were fixed at
`78f4aba`, and LTB-0125 gained a check that no strategy helper is named in the
README, Who ledgr is for, Quickstart or Data Input. The re-review (invocation 2,
at `78f4aba`) confirmed both fixes and found that the new check missed
`ledgr_signal_strategy()`; it was added at `78a3ce3` and verified with the
reviewer's own control. The maintainer accepted without a third review: 2 over
10 tickets, `0.200`.
