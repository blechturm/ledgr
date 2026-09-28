# v0.2.0.2 Documentation Flow Map

**Status:** LDG-2895 working artifact, agent-drafted 2026-09-28. The
maintainer accepted D1 to D7 in Section 3 on 2026-09-28, before LDG-2896
started.

**Authority:** Cut 21 in `inst/design/ledgr_v0_2_0_2_spec_packet/tickets.yml`;
`inst/design/vignette_styleguide.md` house rules, canonical homes and facts
list. Line numbers are source lines at `217a41b` unless marked `md`.

## 1. The Set Today

Flow order is `_pkgdown.yml`. "Early" lists concepts used before their home
without a gloss. "Next" is the first Where Next link; `ok` means it names the
following article.

| # | Document | Job (reader outcome) | Early concepts | First result | Next |
|---|---|---|---|---|---|
| 1 | README | first run, then reopen it | `sma_20` ID (#6), print lines (#18) | `bt` print, uninterpreted | #3 |
| 2 | Who ledgr is for | decide if ledgr fits | pulse (#5), helper pipeline (#20), compiled accounting | none | #27 |
| 3 | Quickstart | smallest loop: run, sweep, promote | snapshot (#4), `ctx$vec` (#5), `sma_20`/warmup (#6), `seed` | run print; lines explained | #11 |
| 4 | Data Input | data frame or file to sealed snapshot | sessions, quarantine (#17), "availability" (#16) | bar tibble, interpreted | #16 |
| 5 | Strategy Basics | the strategy contract and a first run | warmup, aliases (#6), availability-aware (#16), helper pipeline (#20) | feature ID; summary with caveat | #20 |
| 6 | Indicators | declarations to IDs, aliases, warmup | sweeps, grids, precompute (#10), Tier 2 (#13), sessions (#17) | contracts table | #21 |
| 7 | The Accounting Model | read ledger, fills, trades, equity, metrics | cost chain (#8), metric context (#24), sweep rows (#10) | round-trip bps | #24 |
| 8 | Risk And Cost | policies outside the strategy | OMS (never) | cost description | #25 |
| 9 | Experiment Store | list, inspect, reopen, compare runs | tiers (#13), metric context (#24), print lines (#18) | run list; INCOMPLETE footer unexplained | #4 |
| 10 | Sweeps | parameter variation to candidate rows | metric-context hash (#24), print lines (#18) | stray dplyr block (md 44-52) | ok |
| 11 | Research Workflow | hunch to reopenable evidence | tiers (#13), leakage (#12) | bar head, interpreted | #5 |
| 12 | Leakage | spot and avoid lookahead | `series_fn` (#22) | `lead(close)` table | #5 |
| 13 | Reproducibility | tiers, preflight, provenance | resume, `pulse_seed` (never) | unexplained last-bar warning (md 110) | #11 |
| 14 | Selection Integrity | is any variant trustworthy | survivorship (#19) | return-panel table | #10 |
| 15 | Walk-Forward | held-out evaluation of a rule | survivorship (#19), "Session" hash | fold print | #10 |
| 16 | Point-In-Time Inputs | seal one full bundle; fact reference | stale policy, `run_explain` (#17) | case manifest | ok |
| 17 | Missing Data | a real gap and a staleness tolerance | next-open fills (#25) | session calendar | #4 |
| 18 | Cash Distributions | model and refuse a cash dividend | provenance tiers (never) | 50-line summary, 3 items read | #16 |
| 19 | Survivorship Bias | a point-in-time universe versus survivors | helper pipeline (#20), clocks (#25) | price tibble | none |
| 20 | Strategy Authoring Tools | one-pulse tests, helpers, state | clocks (#25), glossed | feature IDs | #5 |
| 21 | TTR Indicators And Bundles | declare TTR and bundles | `series_fn` (#22) | contracts table | #6 |
| 22 | Custom Indicators | scalar, series and adapter features | print lines (#18) | contracts table, unread | #6 |
| 23 | Corporate-Action Adapter | vendor rows to canonical facts | "physical axis" (never) | facts print, unread | #18 |
| 24 | Metric Contexts | annualization and risk-free assumptions | `ledgr_backtest()`, "Fill Timing" (never) | template print | #7 |
| 25 | How Targets Become Fills | when and at what price a target fills | availability refusal (#16) | same-bar vs next-open | #6 |
| 26 | Research To Production | what ships today versus roadmap | none | none | #11 |
| 27 | Why R | why ledgr is an R package | "fold semantics" | none | end |

Source total: 12,003 lines. The LDG-2902 length check measures against it.

## 2. Findings That Shape The Set

- **One demo, four times.** Quickstart, Sweeps, Research Workflow and the
  Selection Integrity setup rerun the same DEMO_01/02 grid and promotion.
  Research Workflow repeats Sweeps' exact grid, review and promotion; its own
  material is topology, the sanity run, reopen, promotion-context recovery,
  the research note and the plot.
- **Lessons ahead of their home.** Sweeps and grids appear in #3 and #6 before
  #10; tiers in #6, #9 and #11 before #13; cost detail in #7 before #8; the
  helper pipeline in #5 and #19 before #20; quarantine in #4 before #17.
- **Homes that do not hold their fact.** Execution Semantics lacks the
  affordability rule; Cash Distributions never explains NOT SUPPLIED or
  UNDECLARED; Point-In-Time Inputs never says plainly what turns on an
  availability-aware run; Walk-Forward never says it does not prove
  generalization. `Fill Timing:` in every summary is explained nowhere.
- **Contradictions.** Research To Production 244-247 says affordability is not
  enforced; Survivorship 887-889 puts corporate actions outside the surface
  that Cash Distributions models; Sweeps 589-590 calls DSR/PBO "later".
- **Point-in-time section.** #16 and #17 teach sessions, trading status,
  stale marks and `run_explain` twice; #17 is written as if it came first
  (555: "continue to point-in-time-inputs"). #19 reteaches both. #18 is thin
  (178 lines) and fails as the print-line home.
- **Hand-offs.** 23 of 26 articles send the reader somewhere other than the
  next article; Survivorship has no Where Next.

## 3. Decisions

The maintainer accepted all seven on 2026-09-28. Each names where every moved
lesson lands. Nothing is added.

**D1. Merge Research Workflow into Sweeps (recommended).** Sweeps becomes the
single home for grids, review, failure rows, promotion, reopening a promoted
run and the research note. From Research Workflow it takes the topology
diagram, the single-run sanity check, close-and-reopen with
`ledgr_run_promotion_context()`, the research-note outline and the promoted
equity plot. The duplicated grid, review and promotion code is dropped.
`research-workflow` redirects to `sweeps`. Alternative: keep Research
Workflow as the end-to-end narrative and make it link-only for mechanics.

**D1 amended (maintainer, 2026-09-28).** After LDG-2896 merged the two
articles, the maintainer noted that research iteration is mostly changing the
strategy code, not only sweeping parameters. Research Workflow is restored as
the loop article: project layout, a v1 rule, a v2 code change, committed runs
compared with labels, the hand-off to Sweeps for a parameter question, the
hand-off to Selection Integrity and Walk-Forward, and the research note. Sweeps
keeps grids, failure rows, review, promotion, reopening a promoted run and the
plot. Research Workflow opens the Research Workflow section, and its redirect
is removed. The count returns to 26.

**D2. Reorder the flow.** Start Here: Who ledgr is for, Quickstart.
Building Blocks: Data Input, Strategy Basics, Indicators, Leakage, The
Accounting Model, Risk And Cost, Experiment Store, Reproducibility. Research
Workflow: Sweeps, Selection Integrity, Walk-Forward. Point-In-Time Evidence,
Going Deeper and Design stay as they are. This puts Leakage next to the
feature lessons it depends on and puts tiers before the articles that use them.

**D3. Point-in-time section: keep four articles, one home each.** #16 is the
section entrance and data-model reference and states what turns on an
availability-aware run. #17 is the single home for sessions, trading status,
stale marks, `ledgr_run_explain()` and `ledgr_run_completion()`, and #16
links there. #18 stays and becomes the real home of the print lines. #19
links #16 and #17 instead of reteaching them. Alternative: merge #18 into #16
as a section.

**D4. Single homes for duplicated lessons.**

| Lesson | Home | Copies replaced by a link |
|---|---|---|
| sweeps, grids, promotion | Sweeps | Quickstart keeps its tiny loop; Indicators' grid and active-alias sweep block (423-530) leaves |
| `lead(close)` example | Leakage | Execution Semantics keeps its fill-timing contrast only |
| warmup and zero-trade checklist | Indicators | Metric Contexts 337-426; Strategy Basics 445-455 |
| cost chain and spread | Risk And Cost | The Accounting Model 186-244; Research To Production 177-209 |
| compiled accounting | Sweeps | Metric Contexts 428-440; Why R 62-69; Who 96 |
| quarantine | Missing Data | Data Input 220-291; Survivorship 991-1000 |
| stored-source inspection | Reproducibility | Experiment Store 260-326 |
| helper pipeline and state | Strategy Authoring Tools | Strategy Basics' main demo uses a plain visible rule |
| held nonmembers | Survivorship | Strategy Authoring Tools 633-658 keeps only the rebalance reserve rule |
| last-bar no-fill, affordability | How Targets Become Fills | Metric Contexts 423-426; Strategy Basics 230-242; Survivorship 539-544 |
| current capability | Research To Production | Who 42-43, 75-77; Why R 73-96, 152-155 |

LDG-2896 carried out every row except affordability and the last-bar no-fill:
those copies move in LDG-2900, when How Targets Become Fills gains the home
statement they would link to. Two rows kept a short gloss where a pinned
contract names the surface: Data Input still names
`invalid_observations = "quarantine"` (LTB-0079), and Strategy Basics keeps a
brief "Remembering Between Pulses" pointer and its fills-versus-trades lines.

**D5. Trims inside articles.** Experiment Store drops its Task Intent Map
(460-474) and feature-persistence section (405-425). Research To Production
drops its retaught store, contract and cost sections. TTR cuts its native-RSI
run to the ID contrast. Why R and Research To Production stay separate
(optional merge noted).

**D6. Rename `ttr-and-adapter-indicators` to `ttr-indicators`** with a
redirect, since R and CSV adapters live in Custom Indicators.

**D7. P8, the `?ledgr_indicator` help page.** It documents only `fn(window)`.
Workstream 29 may not edit `R/` beyond `vignette()` references. Owner: LDG-2903,
a roxygen ticket added to Cut 21, since it is the same documentation surface.

## 4. Violations By Pass

**LDG-2896 (structure)** carries D1 to D7, their references, redirects and
pins. LTB-0080 sections sit at Missing Data 550-579, Cash 131-160 and
Survivorship 1018-1045.

**LDG-2897 (openings and hand-offs).**
- Openings that are a function or content list: Experiment Store 38, Sweeps
  65, Reproducibility 46, Indicators 58-61, Accounting 54-57, TTR 59-62,
  Adapter 38-41, Metric Contexts 55-58, Research To Production 31-38,
  Who 12-14, Cash 30-35.
- Prose tables of contents: Quickstart 31-34, Research Workflow 63-66.
- Missing who-needs-this line: #16 to #19 and #20 to #25.
- Where Next: every article except Sweeps and Point-In-Time Inputs, plus
  Survivorship (none) and Why R's "Reading on" heading. The README's
  learning path must also match the new order.

**LDG-2898 (code idioms and Try-its).**
- Process- or clock-dependent IDs: Indicators 242, 385, 554; Reproducibility
  349, 395, 406, 470; TTR 192, 206; Custom 209, 210, 275; no `snapshot_id` at
  Data Input 261 and 279, Missing Data 307 and 498, Cash 69, Adapter 172.
- `eval: false` without a stated reason: Experiment Store 212, 299, 309, 378;
  Sweeps 534; Leakage 202; Reproducibility 109, 198, 434; TTR 344; Custom
  240; Metric Contexts 224, 240, 330, 374, 389; Research To Production 105.
  Data Input 166, 181, 200 already state reasons.
- Scalar strategy reads: Custom 72; Execution Semantics 203.
- Unexplained demo strategies: Indicators 487; Research Workflow 259; Walk-
  Forward 100; Selection Integrity setup 534-586.
- Stores reopened without `ledgr_temp_store()` or the persistent-path
  sentence: README 120; Research Workflow 182-185; Point-In-Time Inputs
  265-281; Survivorship 564-575.
- Try-its that a natural rerun breaks: Missing Data 454; Strategy Authoring
  609; Survivorship 806 and 1003.
- Use after close: Research Workflow 600. Hidden `close()`: Custom 342-349.
- Metric Contexts and The Accounting Model use `ledgr_backtest()`; label it
  or move to the ordinary entrance.

**LDG-2899 (results, warnings, stray output).**
- Stray output: Sweeps md 44-52. Root cause for the ticket: the project-level
  `message: false` does not apply; 20 articles mask it with per-chunk
  `message: false`, and Sweeps is the only one attaching dplyr without it.
- Unexplained warnings: Indicators md 362; Reproducibility md 110; Strategy
  Authoring md 316-323 and 444-451 (fires once per instrument).
- Candidate IDs without parameters: Quickstart md 136-138 and 163; Indicators
  md 529-533; Sweeps md 237, 361-376, 472-615, 719-724, 793-795; Research
  Workflow md 429-466; Walk-Forward 325.
- Fixture-scale metrics without the caveat: Quickstart; Sweeps md 863-891;
  Research Workflow; Experiment Store md 388-419; Accounting md 344;
  Metric Contexts md 302-339; Cash md 75-81; Walk-Forward md 151-152.
- Uninterpreted output: README first print and equity tail; the INCOMPLETE
  footer on DONE runs (Experiment Store, Research Workflow); run-info fields;
  Execution Semantics' realized P&L and held equity; Survivorship's January 14
  fill; Accounting's hidden cost output (225); Cash's settings wall;
  Leakage's grouped `slice_head`; Custom's contracts table; empty `## Cleanup`
  headings (Accounting, Metric Contexts).
- Output-to-prose mismatch: Missing Data 425 ("two sessions old" beside ages
  1 to 3); Walk-Forward Try-it 390-393 (2 months cannot clear a 90-day flag);
  Strategy Authoring 224-226 versus 339 on `ledgr_select_top_n` warnings.
- Missing `collapse`/`comment` setup: Execution Semantics; missing
  `cli.unicode = FALSE`: Indicators.

**LDG-2900 (facts and homes).**
- Add home statements: affordability (#25), print lines (#18),
  availability-aware activation (#16), walk-forward non-proof (#15),
  `Fill Timing:` meaning (#25).
- Replace paraphrases with the canonical active-alias sentence: Indicators
  164-165 and 521-524; Sweeps 178-181; Research Workflow 287-291; Missing Data
  246-248; Strategy Authoring 182-184.
- Remove contradictions: Research To Production 244-247; Survivorship 887-889;
  Sweeps 589-590.
- Glosses for concepts before their home: Section 1's "Early" column.

**LDG-2901 (maintainer language).** Section 3 terms at: Who 96; Sweeps
528-529, 546, 555; Research Workflow 373, 483, 674; Reproducibility 208,
386-389; Experiment Store 290, 362; Selection Integrity 694-702 and "fails
closed"; Metric Contexts 114, 286-288, 315, 430-438; TTR 245; Research To
Production 124, 137; Why R 12, 64, 66, 114-115; Strategy Basics 104-105, 142,
514; Indicators 157-159, 598-601; Missing Data 207-208; Cash 105;
Survivorship 434-438, 889; Adapter 203. Also "fold" for the execution loop
and changelog phrasing ("now", "currently", "no longer", "this release").
The shared-input sections pinned by LTB-0080 are rewritten in reader terms.

## 5. Routed Product Gaps

- P3 whole-universe active-alias read: feature-map read surface RFC.
- P8 `?ledgr_indicator` documents one arity: LDG-2903 (D7).
- The candidate print hides parameters behind hashes: sweep-surface reader
  question, already named in Cut 18's out-of-scope.
- `LEDGR_LAST_BAR_NO_FILL` fires once per instrument without naming it:
  warning-message owner in the next maintenance cut.
- The run-list INCOMPLETE footer prints for DONE runs with NA completeness:
  run-list print owner in the next maintenance cut.
