# v0.2.0.2 Vignette Audit

**Status:** Frozen findings and proposed dispositions; awaiting maintainer
acceptance before LDG-2885 through LDG-2888 start.

**Audit date:** 2026-09-28

**Authority:** LDG-2859, `inst/design/vignette_styleguide.md`, and the reading
order in `_pkgdown.yml`.

## 1. Baseline And Method

The tracked source census contains 26 Quarto articles, not the 23 stated in
LDG-2859 or the 24 expected by the kickoff. There are 24 files directly under
`vignettes/` and two under `vignettes/articles/`. `_quarto.yml` renders both
locations, so all 26 are executed articles. None may be excluded from this
audit.

The audit read them in `_pkgdown.yml` order, then read the unlisted
`corporate-action-adapter-authoring.qmd`. Each article was checked as if the
reader knew only earlier articles. The five required categories are:

- **S:** superseded idiom;
- **W:** shipped capability worked around by hand;
- **C:** overclaim or missing non-claim;
- **R:** stale path, version, identifier, cross-reference, render, or other
  executable-documentation defect;
- **L:** broken capability ladder.

`OK` means the category was checked and no finding was found. A finding is one
failed article/category cell. A cell can group several corrections that have
one owner and one teaching outcome. This keeps the correction phase focused
without dropping any item from the input audit.

The capability-ladder column names the smallest valid path and the limit that
must remain visible. An article does not fail merely because it omits an
advanced capability.

Verification included source inspection, public-API probes, cross-reference
resolution, and a freshness render. The probes independently reproduced:

- an unresolved parameterized feature map makes
  `ledgr_feature_contracts()` fail with unclassed `simpleError` text
  `values must be length 1`;
- a bundle entered as `bands = ledgr_ind_ttr_outputs(...)` exposes names
  `bbands_dn` and `bbands_up`, silently discarding the outer alias;
- integer-backed `POSIXct` input reaches snapshot insertion and reports
  `Bars insert failed (likely duplicate PKs)` instead of the type defect.

The freshness run rendered the ordinary root articles. It found eight stale
Markdown siblings: Cash Distributions, Custom Indicators, Metric Contexts,
Quickstart, Strategy Basics, Survivorship Bias, Sweeps, and Walk-Forward. The
checker itself could not cover all 26 articles; Section 4 records why.

## 2. Per-Article Verdicts

The table is the frozen correction register. Ticket codes in parentheses are
the proposed owners: F = LDG-2885, W = LDG-2886, O = LDG-2887, and X =
LDG-2888.

| Article | S | W | C | R | L | Capability ladder |
| --- | --- | --- | --- | --- | --- | --- |
| Who ledgr is for | OK | OK | WHO-C (O) | OK | OK | Quickstart is the entrance; it does not establish validation or a shipped live runtime. |
| Quickstart | OK | QUICK-W (O) | OK | QUICK-R (O) | OK | One run precedes one small sweep; neither promotion nor the demo proves generalization. |
| Importing And Sealing Market Data | OK | OK | OK | DATA-R (O) | OK | Bars are enough for a dense study; sessions, membership, restrictions, and actions are added only when the question needs them. |
| Research Workflow | OK | FLOW-W (W) | FLOW-C (W) | OK | OK | One run precedes sweep and promotion; promotion records selection and is not validation. |
| Leakage | OK | OK | LEAK-C (W) | LEAK-R (W) | LEAK-L (W) | A visible lead is the smallest demonstration; even corrected code does not prove vendor point-in-time integrity. |
| Reproducibility | REPRO-S (W) | OK | REPRO-C (W) | REPRO-R (W) | REPRO-L (W) | Tier 1 is the smallest self-contained path; recorded identity is not correctness or safe code. |
| Preparing Point-In-Time Inputs | OK | OK | OK | OK | OK | Start with the missing observation and add one fact family at a time; sealing does not imply complete evidence or a dense panel. |
| Missing Data And Session Calendars | MISS-S (O) | OK | OK | OK | OK | Sessions and status are introduced only to explain a real gap; neither infers its cause or permits stale execution. |
| Cash Distributions | OK | OK | OK | CASH-R (O) | OK | Gross effective-date cash under the research preset comes before strict refusal; neither claims broker net, tax, or payment-date fidelity. |
| Survivorship Bias And Point-In-Time Universes | SURV-S (O) | OK | SURV-C (O) | SURV-R (O) | SURV-L (O) | The static-universe counterfactual precedes point-in-time evidence; the article must then demonstrate the availability behavior it claims. |
| Strategy Basics | OK | OK | OK | BASIC-R (O) | OK | `flat()` and `hold()` precede vector reads and a run; targets are intent, not orders or broker execution. |
| Indicators And Features | IND-S (F) | OK | IND-C (F) | IND-R (F) | IND-L (F) | Built-ins and one pulse are the entrance; warmup, gap certification, and parameterized aliases add stricter evidence only when needed. |
| The Accounting Model | OK | OK | OK | ACCT-R (O) | OK | Headline results precede event detail; metrics do not establish strategy quality and open positions are not closed trades. |
| Risk And Cost Execution Policy | OK | OK | OK | RISK-R (X) | OK | Explicit zero policies precede composed chains; cost and risk are not optimization, liquidity, an OMS, or a broker. |
| Experiment Store | STORE-S (O) | OK | OK | OK | OK | List, inspect, and reopen come before trusted source evaluation; persistence proves identity, not safety or generalization. |
| Exploratory Sweeps And Candidate Promotion | OK | SWEEP-W (W) | SWEEP-C (W) | SWEEP-R (W) | SWEEP-L (W) | A checked single run precedes a grid; candidate review and promotion remain in-sample evidence. |
| Selection Integrity | OK | OK | OK | OK | OK | A validated return panel precedes one diagnostic at a time; diagnostics are eligibility evidence, not a winner or a causal claim. |
| Walk-Forward Evaluation | OK | OK | OK | WF-R (O) | OK | Rolling folds follow sweeps; test folds are dependent evidence and do not prove generalization. |
| Strategy Authoring Tools | OK | AUTHOR-W (O) | OK | AUTHOR-R (X) | OK | Signal, selection, weights, then target is the smallest helper pipeline; only the final complete target executes. |
| TTR And Adapter Indicators | TTR-S (F) | OK | TTR-C (F) | TTR-R (F) | TTR-L (F) | One supported TTR output comes first; recursive shapes and bundles are not availability-certified. |
| Custom Indicators And External Features | CUSTOM-S (F) | OK | CUSTOM-C (F) | CUSTOM-R (F) | CUSTOM-L (F) | Scalar `fn` is the safe entrance; `series_fn` and adapters add performance and external data without proving causality. |
| Metric Contexts And Conventions | METRIC-S (O) | OK | OK | METRIC-R (O/X) | OK | The default US-equity context is the entrance; it does not supply time-varying rates or benchmark data. |
| How Targets Become Fills | EXEC-S (O) | OK | EXEC-C (O) | EXEC-R (X) | OK | A target and next-open fill are the entrance; the engine is not an order-management or broker simulator. |
| Design Philosophy: From Research To Production | RTP-S (W) | OK | RTP-C (W) | RTP-R (W) | RTP-L (W) | The shipped research runtime must come first; paper and live execution remain roadmap layers. |
| Why ledgr is built in R | OK | OK | WHY-C (O) | OK | OK | The research package is the current path; language portability does not establish a shipped deployment runtime. |
| Authoring A Corporate-Action Adapter | OK | OK | OK | ADAPTER-R (O/X) | OK | This is for adapter authors after the canonical fact model; normalized facts still need sealing and an execution policy. |

### Finding Details

**Feature articles -- LDG-2885**

- **IND-S:** make `ctx$vec$feature()` the normal strategy path. Scalar and
  mapped accessors are one-instrument inspection, except where the missing
  active-alias vector surface forces `ctx$features(id)`.
- **IND-C:** correct the claim that aliases permit duplicate feature IDs, and
  make the warmup contrast actually include a `FALSE` row.
- **IND-R:** guard the optional TTR chunk, execute the runnable grid examples,
  remove their naming collisions, interpret the run output, and repair the
  dead "TTR bundle section below" pointer.
- **IND-L:** move expected-session certification after the basic dense feature
  lifecycle. It is stricter evidence, not a prerequisite for every indicator.
- **CUSTOM-S:** replace the per-instrument exact-ID feature loop with the
  whole-vector surface.
- **CUSTOM-C:** make the threshold and Try-it empirically true, reconcile
  `fn(window, params)` with `?ledgr_indicator`, and teach the required
  `gap_contract` non-claim for availability runs.
- **CUSTOM-R:** explain or execute the `series_fn` chunk, put the learning
  outcome before package setup, avoid repeating the Indicators diagram, and
  refresh the changed result output.
- **CUSTOM-L:** distinguish the scalar implementation from the optional
  vectorized and external-adapter paths instead of presenting setup first.
- **TTR-S:** use the whole-vector feature read in the RSI strategy.
- **TTR-C:** correct the `requires_bars` advice and state the closed
  availability boundary for recursive TTR shapes and bundles.
- **TTR-R:** replace the old `{r demo-bars}` header and align the title with
  where R/CSV adapters are actually taught.
- **TTR-L:** consolidate the three warmup sections and print the warmup rules
  once.

**Workflow articles -- LDG-2886**

- **FLOW-W:** use `ledgr_run_promotion_context()` instead of reaching through
  `info$promotion_context` by hand.
- **FLOW-C:** the active-alias loop is currently necessary; say that no
  alias-aware whole-universe read exists rather than presenting it as the
  preferred general strategy shape.
- **LEAK-C:** the allegedly honest quarterly threshold still uses later rows
  from the quarter it judges. Compare it with a genuinely expanding rule and
  interpret the observed counts.
- **LEAK-R:** link the point-in-time and survivorship tools while retaining the
  vendor-data non-claim.
- **LEAK-L:** lead with the research failure, not setup code; remove the
  duplicate obvious-leak lesson and execute runnable chunks.
- **REPRO-S:** replace the ordinary exact-ID loop with a whole-vector rule;
  keep qualified calls only where qualification is the tier lesson.
- **REPRO-C:** remove the stale future-worker boundary and align the provenance
  prose with what the printed object actually exposes.
- **REPRO-R:** execute the runnable Tier 1/Tier 2 captured-value contrast.
- **REPRO-L:** teach the common Tier 3 repair: move a helper into the strategy
  body. Functions in `params` remain invalid.
- **SWEEP-W:** show the parameters behind a row or route the candidate-print
  gap explicitly; hashes alone are not teachable candidate identities.
- **SWEEP-C:** remove shipped DSR, PBO, objective, and risk-chain features from
  the non-goals, and disclose why the central strategy still needs a mapped
  alias loop.
- **SWEEP-R:** refresh Markdown, interpret outputs, make the Try-it rerunnable,
  remove the unrelated B2 shorthand, and avoid calling these layers the same
  "evidence tiers" used by Reproducibility.
- **SWEEP-L:** make the strategy runnable and inspect failure rows before
  selection and promotion; do not hide the error columns in that inspection.
- **RTP-S:** replace the parameter-built exact-ID lookup with a whole-vector
  feature read.
- **RTP-C:** distinguish shipped research behavior from paper/live roadmap
  work, stop calling selection validation, fix the undeclared feature in the
  cost example, and stop claiming every decision is an immutable event.
- **RTP-R:** replace the v0.1.x release summary with the current roadmap and
  release boundary.
- **RTP-L:** organize the article from the shipped research runtime outward;
  paper and live cannot be middle rungs described in the present tense.

**Other articles -- LDG-2887**

- **WHO-C / WHY-C:** distinguish the portable research architecture and the
  long-term deployment goal from a shipped paper/live runtime. "Whatever can
  run R" and "schedule a daily script" currently read as product claims.
- **QUICK-W:** use the new one-screen backtest print before asking a beginner
  to read a long `summary()` plus hand-selected fills.
- **QUICK-R:** refresh the output and either execute the safe temporary-store
  promotion or state why it is intentionally not run.
- **DATA-R:** state why the CSV and Yahoo chunks are not executed: project
  files and an external network source respectively.
- **MISS-S:** the strategy fragment uses a mapped scalar read. Make it a
  vector rule or label it as one-instrument inspection and explain the P3
  boundary.
- **CASH-R:** refresh the result output and add a selective forward pointer.
- **SURV-S:** replace the hand-built equal-weight target with the shipped
  selection/weight/target pipeline.
- **SURV-C:** exercise availability after the first pulse and qualify the
  availability-only insufficient-cash rule.
- **SURV-R:** refresh the result output, correct `achieved_end_utc`, caption
  the figures, and remove the maintainer-facing bundle ending.
- **SURV-L:** add the missing availability Try-it: held-nonmember preservation
  versus accidental liquidation on a feed gap.
- **BASIC-R:** refresh the changed result output.
- **ACCT-R:** replace the old cleanup chunk header.
- **STORE-S:** make the ordinary strategy use whole-vector reads.
- **WF-R:** refresh the nondeterministic session output and execute the safe
  promotion or state why it is intentionally not run.
- **AUTHOR-W:** execute `ledgr_signal_feature()` rather than only naming it.
- **METRIC-S:** either use the ordinary experiment/run path or label
  `ledgr_backtest()` as the compact fixture compatibility surface.
- **METRIC-R:** refresh the changed output and replace the old cleanup chunk
  header.
- **EXEC-S:** teach the ordinary experiment/run entrance before the
  compatibility wrapper.
- **EXEC-C:** add decision and fill clocks plus the principal no-fill reasons;
  fix the zero-fill/zero-trade section so its cases and arithmetic match.
- **ADAPTER-R:** register the rendered article in pkgdown navigation, repair
  freshness checking for its companion R file, and add a selective next step.

**Cross-cutting -- LDG-2888**

- **AUTHOR-R / RISK-R / EXEC-R / METRIC-R:** `_quarto.yml` suppresses warnings
  globally while these articles teach `LEDGR_LAST_BAR_NO_FILL`. Choose a
  visible per-chunk or project-wide rule and make the render match the prose.
- The style guide's reading flow is labelled v0.1.9.5, omits five current
  article families, disagrees with `_pkgdown.yml`, and assigns adapter
  declarations to the wrong canonical article.
- `tools/render-vignettes-gfm.R --all` is non-recursive, so it skips both
  `vignettes/articles/*.qmd` files. Explicitly passing those files instead
  reports missing Markdown siblings. The adapter-authoring article also fails
  in check mode because only its QMD, not its companion R file, is copied into
  the temporary tree. A green `--check --all` therefore cannot currently mean
  all 26 executed articles are fresh.

## 3. Counts

There are 53 failed article/category cells:

| Category | Failed article cells |
| --- | ---: |
| Superseded idiom | 10 |
| Hand-built workaround | 4 |
| Claim or missing non-claim | 12 |
| Stale reference/render | 19 |
| Capability ladder | 8 |
| **Total** | **53** |

Article counts, in reading order, are:

| Findings | Articles |
| ---: | --- |
| 0 | Point-In-Time Inputs; Selection Integrity |
| 1 | Who ledgr is for; Data Input And Snapshots; Missing Data And Sessions; Cash Distributions; Strategy Basics; The Accounting Model; Risk And Cost; Experiment Store; Walk-Forward; Why R; Adapter Authoring |
| 2 | Quickstart; Research Workflow; Metric Contexts; Strategy Authoring Tools |
| 3 | Leakage; Execution Semantics |
| 4 | Reproducibility; Research To Production; Custom Indicators; Indicators; Survivorship Bias; Sweeps; TTR And Adapter Indicators |

The 53 cells are correction-routing units, not 53 proposed tickets. They map
to the four already-cut correction tickets. The cross-cutting checker and
style-guide defects are additional LDG-2888 work but do not add article cells.

## 4. Product And API Findings

Documentation cannot close these four findings. The maintainer must accept a
release disposition before the correction tickets start.

| Finding | Verified behavior | Proposed owner | Proposed release disposition |
| --- | --- | --- | --- |
| P3: no whole-universe active-alias read | `ctx$vec$feature()` and `ledgr_signal_feature()` take engine IDs; mapped aliases require `ctx$features(id)` | Feature-engine RFC named by the strategy-helper synthesis | Defer to the next feature-engine cycle. This release must disclose the forced loop and must not warn as though a replacement existed. |
| P4: feature-contract inspection fails opaquely | An unresolved parameterized map raises unclassed `simpleError` instead of an actionable ledgr condition | Feature-engine inspection surface | Defer with an explicit materialize-first instruction in this release; schedule classed validation with the active-alias design. |
| P5: integer-backed POSIXct masks its cause | `ledgr_snapshot_from_df()` reports likely duplicate keys and an aborted transaction instead of the invalid timestamp storage type | Snapshot ingestion owner | Treat as a pre-tag product correction candidate. If deferred, the maintainer must accept the misleading-error non-claim explicitly; prose alone cannot repair it. |
| P6: outer alias is discarded for TTR bundles | `bands = bundle` exposes bundle feature IDs such as `bbands_dn`, not `bands`; no warning explains that the outer alias has no effect | Feature-map and TTR-bundle owner | Defer to the feature-engine RFC unless the maintainer chooses a bounded validation error before tag. The TTR article must teach the actual naming rule. |

No production change is authorized by this audit.

## 5. Reconciliation With The Audit Input

Every earlier item was rechecked at the current tree.

### Rejected Because The Tree Already Closed It

- **P1 pulse/run feature parity:** closed by LDG-2876. Current pulse and run
  paths share scalar-at-index behavior while `series_fn` retains full history.
  The old Custom and TTR pulse findings are not carried forward.
- **P2 exact-ID feature-loop warning:** closed by LDG-2877. `ctx$feature()` is
  recorded and names `ctx$vec$feature()`; mapped `ctx$features()` remains
  deliberately unwarned and is P3, not an unfinished P2.
- **Run-info print defects:** Cut 18 corrected elapsed formatting and metadata
  spacing. The old product finding is not carried forward; stale article
  outputs are carried as freshness findings.
- **Strategy Basics opening list:** this is an editorial preference, not a
  style-guide violation after the article states its outcome. Rejected.
- **Strategy Authoring Tools holding explanation:** the current text now says
  the zero target sells the holding because inputs have not warmed up and later
  names `missing = "exclude"`. Rejected as closed.
- **Leakage Markdown stale:** the prior audit correctly rejected this. The new
  render also found it fresh.
- **Custom/TTR pulse-value findings:** consequences of P1 and now closed.

### Adopted, With Current Owners

- P3, D1, D2, the three remaining incidental product defects, the stale
  release section, and the stale style-guide flow are adopted in Sections 2
  and 4.
- All numbered Indicators findings are adopted under IND-S/C/R/L.
- Custom findings 1 and 3 through 5 are adopted. Finding 2's pulse failure is
  rejected as closed, but its `?ledgr_indicator` signature mismatch remains in
  CUSTOM-C.
- TTR findings 2 through 6 are adopted. Finding 1 is rejected as closed.
- All Sweeps, Reproducibility, Research To Production, Leakage, Survivorship,
  and Execution Semantics findings are adopted under their article cells.
- The scanned-article findings for Experiment Store, Metric Contexts, and the
  old cleanup headers are adopted. The earlier statement that Corporate Action
  Cash, Missing Data, Point-In-Time Inputs, and Risk And Cost had idiomatic
  strategies remains true; their current findings are render, disclosure, or
  warning findings rather than strategy API errors.

### Articles Previously Not Read In Full

- **Quickstart:** QUICK-W and QUICK-R.
- **Research Workflow:** FLOW-W and FLOW-C.
- **Walk-Forward:** WF-R.
- **Data Input And Snapshots:** DATA-R only; its capability ladder is the best
  compact example in the set.
- **Selection Integrity:** no finding in any category.
- **Corporate-Action Adapter Authoring:** ADAPTER-R.
- **Who ledgr is for / Why R:** both were absent from the earlier 24-file
  expectation; each has one current-versus-roadmap overclaim.

## 6. Stop State

LDG-2859 is complete as an audit and remains `review_pending` until the
maintainer accepts or changes the proposed dispositions. LDG-2885 through
LDG-2888 must not start before that decision. This artifact changes no article,
teaching claim, public API, production code, or test.
