# v0.2.2 Teaching And Reference Documentation Audit

**Status:** Agent audit, Type 2. It proposes tickets only and has not been reviewed or accepted by
the maintainer. **Date:** 2026-10-06, branch `v0.2.2`.

**Line anchors:** test lines refer to HEAD `4b91bf9`. During the audit, another session edited
`test-documentation-contracts.R` without committing. In that working copy, lines after 1906 have
moved up by 4, and 48 new lines follow line 2012.

**Question:** which pages teach, which are reference, which mix the two, and which documentation
pins hold teaching pages to reference-grade exactness?

## Answer

- **No article is a reference page.** All reference documentation lives in `man/*.Rd`. Of the 26
  articles, 10 teach one idea, 3 are background and 13 are mixed. The mixed articles hold 8,057
  of the 11,836 article lines (68%).
- **Most article pins demand exact content.** Of 681 documentation assertion call sites, 426
  target an article or the README. Of those 426, 290 (68%) pin exact output, exact prose,
  specific code or reference content inside the article. Only 46 pin execution, navigation or
  a table checked against behaviour.
- **Output pins prove neither behaviour nor freshness.** They read the committed rendered
  `.md`, and nothing in CI runs the freshness check on those files.
- **Most documentation pins are untracked.** 518 of the 579 call sites in
  `test-documentation-contracts.R` sit in 13 blocks with no LTB ID and no `claims.yml` entry.

## Method And Counting

**Call sites.**

- `getParseData()` listed every `expect_*` call site in DC (579, which matches `grep -c`), PIT
  (49) and RCB (3).
- A grep for `vignettes`, `.qmd`, `man/`, `.Rd` and `README` found documentation-reading blocks
  in six more files, adding 50 sites:
  - CAP 24 (LTB-0037/0057/0060)
  - AF 11 (LTB-0073 at lines 373-414; LTB-0074 at 500, 511 and 581)
  - SCS 10 (LTB-0091)
  - TPI 2 (LTB-0161)
  - SPI 2 (LTB-0078)
  - ECA 1 (LTB-0030)
- That makes 681 in total. I counted call sites, not loop expansions; DC:1651, for example, runs
  ten times.

**Attribution.** Each site is assigned to the document behind the variable it reads. Where one
variable joins several articles, I searched for the needle in each source to find its home. A
site that reads several articles counts once per article.

**Grouping.** A heuristic did the first pass, and I then reviewed all 631 main-file sites line by
line. The line between groups B and D is a judgment call; about 10% of sites could move between
them.

**File abbreviations.** DC = `tests/testthat/test-documentation-contracts.R`; PIT =
`test-pit-input-documentation.R`; RCB = `test-release-claim-boundary.R`; CAP =
`test-corporate-action-policy.R`; AF = `test-availability-features.R`; SCS =
`test-strategy-context-surface.R`; TPI = `test-terminal-policy-identity.R`; SPI =
`test-sim-pit-inputs.R`; ECA = `test-equity-corporate-action-facts.R`. Line counts are `wc -l`.

## 1. Article Table

In the Pins column, the first number is call sites from the three main files and the second is
call sites from other files. A further 80 global call sites apply to every page.

| Page | Lines | Role | The one idea, if teaching | Reference material in disguise | Pins |
|---|---:|---|---|---|---:|
| README.Rmd | 244 | mixed | - | failure table 206-211; Status 228 | 5+4 |
| who-ledgr-is-for | 146 | background | - | - | 2 |
| quickstart | 210 | teaching | smallest loop: run, tiny sweep, keep one candidate | - | 2 |
| data-input-and-snapshots | 273 | teaching | bars to a sealed, reopenable snapshot | bar shape 72-95; input-shape table 144-151; CSV/Yahoo variants 157-223 | 12 |
| strategy-development | 576 | mixed | the strategy contract | `ctx` table 116-131 copies `ledgr_strategy_context.Rd`; tables 174-177, 434-439 | 33 |
| indicators | 678 | mixed | declare features once, read them pulse-known | accessor tables 111-123; contracts 415-436; troubleshooting 489-616; support matrix 649-658 | 38+2 |
| leakage | 322 | teaching | what was knowable at decision time | enforcement/responsibility tables 257-286 (boundary) | 5 |
| metrics-and-accounting | 442 | mixed | read a run as accounting, ledger first | inspection-surface table 105-119; fill columns 223-230 | 21 |
| risk-and-cost | 415 | mixed | execution policy lives outside the strategy | step catalogues 127-145; spread/fee formulas 293-332; Identity 333; Boundaries 353 | 10 |
| experiment-store | 412 | mixed | find, compare, reopen runs | run-field table 195-203; recovery, archive and backup 308-387 | 4 |
| reproducibility | 510 | teaching | which runs replay exactly (tiers) | preflight rejection table 411-418 | 1 |
| research-workflow | 320 | teaching | hunch to reopenable evidence while code changes | - | 1 |
| sweeps | 903 | mixed | parameter question to one promoted candidate | retention 503-522; compiled accounting 554-590; failure rows 591-640; non-goals 863-885 | 11 |
| selection-integrity | 714 | mixed | is a winner trustworthy given the search | four diagnostic sub-tutorials 125-516; references 681 | 0 |
| walk-forward | 444 | teaching | held-out test of a selection rule | non-claims 413-424 | 1 |
| point-in-time-inputs | 476 | mixed | add availability claims one at a time | data dictionary 356-382; ERD 383-444 | 23 |
| missing-data-and-sessions | 712 | mixed | what a day without a price means | questions table 57-62; strict-gap table 216-224; staleness 369-484; bad rows 574-645 | 20+8 |
| corporate-action-cash | 212 | teaching | credit an evidenced dividend under two presets | print-line meanings 41-53 | 8+10 |
| survivorship-bias | 1306 | mixed | the universe must be point-in-time | terminal outcome 980-1075; missing bar 1076; reopening 1125; invalid rows 1172; field table 827-832 | 74 |
| strategy-authoring-tools | 694 | mixed | make a first strategy trustworthy | object table 216-221; missing-input table 470-474; availability 640-668 | 70 |
| ttr-indicators | 363 | mixed | TTR functions as features | bundle naming 196-260; MACD 261-268; warmup rules 269-324 | 2 |
| custom-indicators | 379 | teaching | write the safest custom indicator | field table 72-81; fingerprints 193; adapter helpers 224 | 2 |
| corporate-action-adapter-authoring | 230 | teaching | vendor records to canonical sealed facts | canonical header and terms 57-102 | 1+19 |
| metric-contexts-and-conventions | 366 | mixed | metric assumptions travel with runs | common contexts 127-176; risk-metric formulas 256-344 | 39 |
| execution-semantics | 382 | teaching | a target fills at the next open | clock table 82-85 | 8 |
| research-to-production | 174 | background | - | capability list 124-166 | 24 |
| why-r | 177 | background | - | - | 0 |

The 10 teaching pages hold 3,282 lines, the 13 mixed pages 8,057 and the 3 background pages 497.
Invalid-observation refusal is taught three times: `data-input-and-snapshots.qmd:224`,
`missing-data-and-sessions.qmd:574` and `survivorship-bias.qmd:1172`.

## 2. Pin Table

The groups are defined by what an assertion fails on. Behaviour, wording and location fail for
different reasons, and each belongs on a different kind of page. Counts are given as
article+README / global / Rd / repo.

| Group | Protects | Counts | Example lines | Belongs |
|---|---|---|---|---|
| A executes and stays clean | files and renders exist, images resolve, no `eval: false`, no stray output | 23/35/6/0 (64) | DC:117, DC:1229, DC:1697, CAP:82, DC:2010 | teaching pages and global scans; keep |
| L house lint | ID idioms, chunk headers, maintainer vocabulary | 0/2/0/0 (2) | DC:1978 (LTB-0125), DC:2119 (LTB-0128) | global; keep |
| N navigation | Rd-to-article paths, pkgdown groups, handoff | 15/32/24/0 (71) | DC:572-573, DC:1120-1161, DC:1875, DC:1887, PIT:77 | keep |
| B boundary or claim | non-claims, behaviour facts, absent stale phrases | 90/9/35/0 (134) | RCB:74, RCB:82, CAP:220-234, DC:2073, DC:1085-1086, DC:344, DC:777 | one cross-page claim registry, homed on a reference page; articles link to it |
| C exact output | rendered `#>` rows, numbers, column spacing | 49/1/0/0 (50) | DC:284, DC:1651, DC:1795-1812, DC:1826, PIT:277-305, CAP:185 | a behaviour test, or nowhere if one already exists |
| D exact prose | headings, glossary sentences, titles, section order, exercises | 98/0/4/0 (102) | DC:631-635, DC:643-644, DC:1702-1705, PIT:54, PIT:95-106, DC:907 | nowhere |
| E code shape | article code contains or avoids a snippet | 114/1/13/0 (128) | DC:212-220, DC:228, DC:1595-1631, PIT:198-202; idiom bans DC:370, DC:795, DC:819 | snippets nowhere (execution covers them); idiom bans move to the L lint |
| R reference content | dictionaries, ERD, formulas, field and class lists | 29/0/46/0 (75) | PIT:113-115, PIT:181-190, DC:678-680, DC:853-859, DC:1484 | a reference page, and only if verified (T) |
| T table checked against behaviour | an authored table compared with real runs | 8/0/10/0 (18) | SCS:150-243 (LTB-0091), AF:386-414 (LTB-0073), AF:581 (LTB-0074) | a reference page; the model to extend |
| Z not documentation | Suggests, NAMESPACE, .gitignore, scripts, playbook, contracts.md, R source | 0/0/0/37 (37) | DC:155-161, DC:1277-1305, DC:1569-1590, DC:1661, AF:500 | project-metadata or release tests, or delete |

**Where the pins sit.** In total, 426 call sites target articles or the README, 80 are global,
138 target Rd pages and 37 target the repository. On articles, groups C+D+E+R come to 290 (68%).
They concentrate in survivorship-bias (C 26, D 15, E 23) and strategy-authoring-tools (E 27,
B 16, D 14).

**The cost of a behaviour change today.** Changing the momentum example's parameters breaks
DC:284 and DC:1651, which pin `#> [1] 136`, `#> [1] 177` and `#> 1 v1_ranking <NA> 11372.`.
The comment at DC:1636-1637 says a moved number "must also revisit the prose".

**No freshness gate.** `tools/render-vignettes-gfm.R --check` compares the committed `.md` files
with a fresh render (lines 126 and 155-246). Grep finds no call to it in `.github/workflows/` or
in `release_ci_playbook.md`, and DC:1282-1283 only checks that the script's text exists. The real
drift gate is the pkgdown build on `main` (`pkgdown.yaml:50`).

**Existing behaviour coverage.** All 11 sampled C strings also appear in a behaviour-test file:
for example, "withheld" in `test-result-output.R`, "Valuation: FROZEN" in
`test-terminal-reporting.R` and `insufficient_cash` in `test-availability-economics.R`. This only
locates matches; it does not show that the oracle is the same.

**Untagged blocks.** 13 of DC's 23 `test_that` blocks have no LTB ID. They hold 518 of DC's 579
call sites. `claims.yml` cannot cover them, because its detecting blocks are LTB IDs only. The
largest is DC:596-862, with 199 call sites.

## 3. Reference Surfaces And Gaps

**Reference surfaces that exist:**

- `ledgr_condition_classes.Rd` has 600 lines, 118 class aliases and a 46-row reason-code table at
  line 517. DC:1470-1486 pins 11 of the classes; nothing checks the page against code. A regex
  over `rlang::abort` and `warn` calls in `R/` finds 291 distinct first-class literals, of which
  91 are aliased. The regex is approximate, and some unaliased classes may be internal.
- `ledgr_strategy_context.Rd` has a 44-row surface table at lines 115-158. SCS:148-243 checks it
  against real callbacks in both directions, as the "Documentation Contract" requires.
- Help pages that are pinned: `LEDGR_LAST_BAR_NO_FILL` (DC:1518-1522), both policy pages (TPI:528,
  539) and `ledgr_demo_pit_inputs` (SPI:379, 386).
- Help pages that are unpinned: `ledgr_identity_fields`, `ledgr_objective_criteria`,
  `ledgr_sweep_retention`, `ledgr_ind_ttr_warmup_rules`, `ledgr_facts`, `ledgr_results`,
  `ledgr_compute_metrics` and `summary.ledgr_backtest`.
- Two article tables are already checked against behaviour: `missing-data-and-sessions.qmd:216-224`
  (AF:386-414) and `indicators.qmd:649-658` (AF:581).

**Gaps: behaviour documented only in an article.** A grep over `man/*.Rd` finds no statement of
any of these.

1. Dense-run affordability: cash can go negative, and an availability run refuses with
   `insufficient_cash` (`execution-semantics`, DC:2023-2024). The help pages for `ledgr_run`,
   `ledgr_experiment`, `ledgr_backtest` and `ledgr_strategy_context` have no match for `afford`,
   `insufficient` or `negative cash`.
2. When an experiment becomes availability-aware (`point-in-time-inputs`, DC:2031).
3. Strict-window eligibility for each indicator form (`indicators.qmd:649-658`). The help for
   `ledgr_ind_ttr`, `ledgr_ind_ema`, `ledgr_ind_rsi` and `ledgr_ind_ttr_outputs` says nothing about
   strict windows or availability.
4. What `dense_bar_timestamp` means (`execution-semantics`, DC:2025).
5. Intent that cannot execute is recorded, not queued (DC:2035, DC:2037). No Rd says "queued".
6. What `Corporate actions: NOT SUPPLIED` means (DC:2032). `print.ledgr_backtest.Rd:21-22` names
   the line but not its meaning.
7. `ctx$flat()` sells a departed holding (`survivorship-bias`, DC:2036).
8. The point-in-time ERD, which exists only at `point-in-time-inputs.qmd:383-444` and is pinned
   exactly by PIT:181-190.

**Contradiction.** The "Documentation Contract" says `ttr-indicators` must not remain a parallel
installed article without a stated reason, and that TTR reference facts belong in
`?ledgr_ind_ttr` and `?ledgr_ind_ttr_warmup_rules`. Yet the article ships (`_pkgdown.yml:73`),
DC:1341 and DC:1367 require it, and `vignette_styleguide.md:556` makes it the home for bundle
naming and warmup. Separately, style guide Section 10 already sends return fields, condition
classes and edge cases to help pages, which the 29 R pins on articles work against.

## 4. Proposed Tickets

These are proposals only; `tickets.yml` remains the authority.

**TR-1: Page roles and pin policy.** Type 2, because it sets an evidence boundary and amends a
contract.
- *Scope:* Amend the "Documentation Contract" and style guide Section 10. Each page gets one role:
  teaching, background or reference (Rd).
  - Teaching pages may carry A, L and N, plus B through the claim registry.
  - Rd pages may carry B, and R only when it is verified (T).
  - No page carries C, D or snippet E.
- *Also in scope:* resolve the `ttr-indicators` contradiction, and list each mixed page's sections
  to move for per-item sign-off. No prose moves in this ticket.
- *Acceptance:* A test fails if any `_pkgdown.yml` article entry (lines 28-85) has zero roles or
  more than one. The contract names every group and which roles may carry it. It no longer
  contradicts DC:1367.
- *Depends on:* none.

**TR-2: Drift gate and regrowth guard.**
- *Scope:* Make `render-vignettes-gfm.R --check` a named review or release gate. Add a scanner for
  `expect_*` calls that read `vignettes/` or README text outside the global scanners (images,
  stray output, LTB-0118, -0125, -0127, -0128, -0060, -0181). Seed a ratchet list with today's
  sites; the list may only shrink.
- *Acceptance:* A new article-text match not on the list fails. A chunk edited without
  re-rendering fails. Growing the list fails.
- *Depends on:* TR-1.

**TR-3: Reference homes for behaviour taught only in articles.**
- *Scope:* Move gap items 1-7 into their owning help pages. Repoint the LTB-0127 home registry
  (DC:2022-2038) to those pages, and extend its contradiction scan (DC:2039-2066) to `man/*.Rd`.
  Article glosses are offered for per-item sign-off.
- *Acceptance:* Each of the 15 home statements is found in exactly one `man/*.Rd`. Deleting one
  fails LTB-0127. A contradicting phrase in any Rd page fails.
- *Depends on:* TR-1.

**TR-4: Reference tables checked against behaviour.** Extends the LTB-0091 pattern.
- *Scope:*
  - Every class raised in `R/` is aliased in `ledgr_condition_classes.Rd` or listed on a named
    internal allowlist.
  - The reason-code table equals the code's closed vocabulary.
  - The strict-window matrix moves into an Rd table that AF:581 reads.
  - Each expression in `strategy-development.qmd:116-131` exists in the Rd surface table, or that
    table becomes a link (needs sign-off).
- *Acceptance:* Raising a new class without an alias or allowlist entry fails. Removing a reason
  code fails. Marking EMA as supported fails.
- *Depends on:* TR-1; coordinate the matrix move with TR-3.

**TR-5: Retire teaching-page pins in the point-in-time cluster.**
- *Scope:* survivorship-bias, missing-data-and-sessions, point-in-time-inputs, both
  corporate-action articles, data-input-and-snapshots and experiment-store (179 sites).
  - Delete the C, D and snippet-E pins.
  - For each C pin, name the behaviour test that covers it in the commit, or add one on
    `ledgr_demo_pit_inputs`.
  - Keep A, N, LTB-0181, LTB-0060 and LTB-0073.
  - The maintainer decides whether the ERD pins (PIT:181-190) are checked against the sealed
    schema or dropped.
  - Rewrite LCL-0032, LCL-0059, LCL-0079 and LCL-0080.
- *Acceptance:* Editing a heading and a sentence of `survivorship-bias.qmd`, then re-rendering,
  fails no test. Breaking the frozen-worthless bound in `R/` fails a behaviour test. The ratchet
  list shrinks by exactly the deleted sites.
- *Depends on:* TR-2 and TR-3.

**TR-6: Retire the remaining pins and close out.**
- *Scope:* the strategy, indicator and metric articles, research-to-production, sweeps,
  risk-and-cost, execution-semantics and the README.
  - Fold the idiom bans (DC:370, 795, 819) into LTB-0125.
  - Move the 37 Z pins to `test-project-metadata.R`, or delete them.
  - Give every surviving DC block an LTB ID and a `claims.yml` entry.
  - Rewrite LCL-0099, LCL-0101, LCL-0103 and LCL-0116.
- *Acceptance:* Changing `top_momentum` so its fill count is no longer 136, then re-rendering,
  fails no documentation assertion (today DC:284 and DC:1651 fail). The ratchet list is empty.
  Every DC `test_that` carries `[LTB-`. DC reads no DESCRIPTION, NAMESPACE, `.gitignore`, `R/` or
  `inst/design` file.
- *Depends on:* TR-2, TR-3 and TR-4.

## 5. Risks And Constraints

**What must not be lost:**
- the execution gate: real chunks, and no `eval: false` (DC:1697, CAP:82, CAP:135);
- LTB-0181, verbatim (RCB:59-83), and LTB-0060 (CAP:194-240);
- the LTB-0127 contradiction scan;
- the research-to-production roadmap boundary (DC:1082-1091);
- leakage non-certification (DC:343-344) and the disclaimer pins (DC:1428-1433);
- LTB-0126, image resolution (DC:117, DC:1229) and the Rd-to-article links (DC:497-573,
  DC:1311-1376);
- LTB-0118, unchanged. It checks reading order, not content, and Rd pages sit outside the flow.
  A split article needs only a new `_pkgdown.yml` entry and a "Where Next" link.

**Order.** C pins are today's only automated tie between committed `.md` files and specific
behaviour. TR-2's gate must therefore land before TR-5 or TR-6 deletes them. Where a C pin's
claim has no behaviour test, that test must be written first; the grep sample proves nothing.

**Sign-off and authority.**
- Section moves and glosses are prose changes and need per-item sign-off. This audit drafts none.
- TR-1 changes `contracts.md`, which may need a full RFC under `rfc_cycle.md`, "Review modes,
  workstreams, and routes".
- Another session is editing `tickets.yml`, `contracts.md`, `decisions.md` and DC. These proposals
  must merge with that work, not overwrite it.

**`claims.yml` entries.** The eight LCL entries named in TR-5 and TR-6 promise documentation
evidence that these tickets remove; LCL-0079, for example, promises an "exact eight-entity ERD".
Rewrite their scopes; do not leave them orphaned.

## Could Not Establish

- Whether `render-vignettes-gfm.R --check` runs anywhere outside local use. Only the workflows
  and the playbook were searched.
- The size of the condition-class gap; the figure is a regex estimate.
- Whether every C pin has a behaviour test with the same oracle; only 11 strings were sampled.
- Whether the rendered `.md` files are current. No vignette was rendered and no tests were run.
