# WS46 focused re-review 2 (Type 1), `d12fd384..6aed3940`

## Verdict: CHANGES_REQUIRED

Correction 2 closes R1-R3 as recorded, changes no product code path, and
the timing disclosure matches re-review 1's measurements.

- R1: `?ledgr_facts`, `?ledgr_sim_pit_inputs`, the four article passages and
  the rendered sibling no longer call a fact without a knowledge time
  audit-only. NEWS has the refusal. The article executes and its freshness
  check passes.
- R2: mutation D5 (`<=` to `<` at `R/history-substrate.R:940`) now fails
  LTB-0337 (2 expectations).
- R3: the scope sentence, the M-2 row, LCL-0325 and the empty-axis note are
  correct. I read every axis builder and found no public path that reaches
  an empty axis.
- The full suite, the census, the mode-branch self-test and the fold-phase
  checker pass.

Two low findings remain. Neither reopens a Cut 16 decision, so the verdict
is not NEEDS_TYPE_2. This is the review after correction round 2, so any
further round goes to the maintainer (AGENTS.md governance loop).

- S1: the new article text says an *inspection* of such a snapshot refuses.
  The public fact-inspection functions and the low-level pulse do not
  refuse. `ledgr_facts_validate()` still labels these rows `audit_only`
  without saying that they will block preparation.
- S2: the same tie mutation at the sibling comparison for complete headers
  (`R/history-substrate.R:897`) survives LTB-0337 and LTB-0335. It is wrong
  on 64 of 527 publicly constructible families.

Method:

- Read the inputs: AGENTS.md, `close_review_46_rereview_1.md`, Correction 2
  in `history_simplification_closeout.md`, Cut 16 decisions (22)-(24), and
  `git diff d12fd384..6aed3940` in full: `R/`, `man/`, NEWS, the article and
  its sibling, tests, `tests/claims.yml`, the census CSVs, the closeout and
  `tickets.yml`.
- Built a source copy with `git ls-files`. The working tree equals
  `6aed3940` apart from CRLF churn in five uncommitted files;
  `git diff --ignore-all-space --ignore-cr-at-eol` is empty. The suite run
  compiled the copy once, and a mutation copy was taken from it after the
  run.
- Ran these probes, all in scratchpad `ws46_rereview2/probes/`:
  - `r1_probe.R` and `r1_member.R`: a snapshot with one status fact, and one
    with one membership set header, each without a knowledge time, through
    `ledgr_facts_validate()`, `ledgr_run()`, `ledgr_facts_history()`,
    `ledgr_facts_resolve()`, `ledgr_experiment_plan()` and both
    `ledgr_pulse_snapshot()` forms. Also `ledgr_sim_pit_inputs()` under both
    knowledge modes.
  - `mutate2.R`: seven mutations, each restored byte for byte.
  - `d5c.R` and `d5c_known.R`: the line 897 mutant, the live counter and the
    canonical brute-force count of LTB-0337 on random tied families built
    through `ledgr_facts_membership_snapshots()`.
- Ran the full suite once, census `--mode=check`,
  `--self-test-mode-branches`, `tools/check-fold-phase-contract.R .`, and
  `tools/render-vignettes-gfm.R --check` on the article.
- `git diff --check d12fd384..6aed3940` is clean, and no added line contains
  a non-ASCII byte.

## Findings

### S1 (low, documentation): the corrected text overstates the refusal and leaves the validation report saying audit-only

Two places still disagree with decision (23).

(a) `vignettes/point-in-time-inputs.qmd:156-158` (`.md:133-136`): "a run,
sweep or inspection on that snapshot refuses with
`ledgr_fact_knowledge_missing`". Correction 2 wrote this sentence, and it
is false for inspection. On a snapshot with one membership set header that
has no knowledge time (`r1_member.R`):

| Call | Result |
| --- | --- |
| `ledgr_facts_history(snapshot, "membership", "u")` | runs, returns 4 rows |
| `ledgr_facts_resolve(snapshot, "membership", "u", at = ...)` | runs; the unknowable header does not resolve |
| `ledgr_pulse_snapshot(snapshot, universe = ids, ...)` (low-level) | runs |
| `ledgr_experiment_plan(exp)` | runs |
| `ledgr_run()` and `ledgr_pulse_snapshot(exp, ...)` | refuse with `ledgr_fact_knowledge_missing` |

`ledgr_facts_history()` and `ledgr_facts_resolve()` are documented under
"Inspect point-in-time fact evidence" (`?ledgr_facts_inspection`).
`?ledgr_facts` and NEWS say this correctly: "pulse inspection that prepares
availability" and "availability-aware pulse inspection". The status and
lifetime passages ("runs on that snapshot refuse") are accurate.

(b) `ledgr_facts_validate()`, a public dry run, still classifies these
rows outcome `audit_only`, reason `knowledge_time_missing`
(`R/availability-ingest.R:371-373`). It prints `Can seal: yes` and
`facts_audit_only 1` (`r1_probe.R`: one status row; `r1_member.R`: three
rows). Its help says "audit-only facts stay distinct"
(`R/availability-facts.R:1256-1258`, `man/ledgr_facts_validate.Rd:29`).
Nothing in the report or its help says that these rows make every
availability preparation refuse. The label predates WS46. Decision (23)
made it misleading for membership, status and lifetime rows, and the dry
run is where a user would look before sealing. The label stays correct for
a corporate action with no clock.

Smallest fix:

- In the article and its sibling, replace "a run, sweep or inspection" with
  wording scoped like `?ledgr_facts`, for example "a run, sweep, feature
  precompute, walk-forward session or experiment pulse inspection".
  Regenerate the sibling.
- Add one sentence to `?ledgr_facts_validate`: a membership, trading-status
  or lifetime row reported `audit_only` with reason `knowledge_time_missing`
  is sealed, but availability preparation refuses it with
  `ledgr_fact_knowledge_missing`.
- Renaming the outcome changes behavior, and the meaning of a missing
  knowledge time is LDG-3073's question under decision (23). Leave the
  label unless the maintainer routes it there.

### S2 (low, detector gap): the tie mutation at the complete-header comparison survives LTB-0337 and LTB-0335

The mutation (D5c) is at `R/history-substrate.R:897`, the sibling of R2's
comparison. It changes `head_known[[y]] <= head_known` to `<`, so a
later-ranked complete header no longer blocks an earlier header known at
the same instant. Results (`mutate2.R`):

- LTB-0337: 108 expectations, 0 failed.
- LTB-0335: 441 expectations, 0 failed.

The mutant is wrong on publicly constructible data (`d5c_known.R`, seed 97,
600 draws):

- 527 families are accepted by `ledgr_facts_membership_snapshots()`. Their
  headers have distinct effective times and share a knowledge time.
- The mutant differs from the canonical count on 64 of them.
- The live counter equals the canonical count on all 527.

Smallest witness: four complete sets, effective 2021-03-02 21:00,
03-05 22:00, 03-06 14:30 and 03-08 21:00, all known 2021-03-09 21:00. The
canonical and live counts are 4 per instrument; the mutant counts 5.

One shared knowledge time is the shape of a bulk delivery of historical
constituent lists. The mutant overcounts, so it fails closed: it refuses
families at their `segment_limit` that should run. Neither LTB-0335's
lagged clocks nor LTB-0337's 48 random families draw it often enough.
LCL-0327's smallest-failing-change list covers D5 but not this comparison.

Smallest fix: add the four-set literal family above to LTB-0337 (count 4
per instrument, runs at limit 4). Alternatively, tie the knowledge times in
a share of LTB-0337's generated families, as re-review 1 suggested for R2.

## Item results

| Item | Result |
| --- | --- |
| R1 user documentation | PASS for the passages named in re-review 1. `?ledgr_facts` (roxygen and Rd identical), `?ledgr_sim_pit_inputs`, NEWS, the four article passages and the sibling match the refusal. The `assume_effective` wording matches the code: `ledgr_fact_knowledge_time()` (`R/availability-facts.R:1547-1553`) replaces a missing knowledge time with `effective_from`. `ledgr_sim_pit_inputs()` leaves the knowledge time missing under `assume_effective` (sessions 31, membership 4, lifetime 5, status 5) and supplies one for every row under `evidenced` (all 0). Repo-wide grep outside `inst/design/`: the remaining "audit-only" texts describe clockless corporate actions (`R/availability-facts.R:56`, NEWS:40, LCL-0284), facts inspection history (`R/availability-inspection.R:30`) or the validation report (S1b). No other article, the README or the condition reference claims a run-neutral fact; `missing-data-and-sessions` and `survivorship-bias` describe only `assume_effective` and evidenced clocks. The article executes: `render-vignettes-gfm.R --check` exits 0 with "Verified vignette Markdown", and the sibling diff is prose only. New overstatement: S1a |
| R1 oracle change (LTB-0079) | Valid. The pinned rule string asserted the old rule, which decision (23) made false; the change and its reason are recorded under "Test changes in Correction 2" and in the LDG-3075 evidence. The negative check catches the old status sentence in the source alone (W1q fails 1) and in the sibling alone (W1m fails 1). Breadth: see N1 |
| R2 tie family | PASS. The literal family's counts (`4, 3, 3, 3, 3` facts; 2 segments each) and the limit-2 run assertion are in LTB-0337, and the comment derives them. D5 fails LTB-0337 (2): segment count 3 instead of 2, and the refusal "3 segments for 4 facts (ratio 0.750; limit 2)" at limit 2. LTB-0335 still passes D5 (441), as recorded. Sibling gap: S2 |
| R3a scope | PASS. The closeout F3 row and LCL-0327 `protected_contract_or_defect` limit "only undercounted" to header-only or interval-only families per universe and record the overcount on mixed families with re-review 1's numbers (22 over, 15 under, one both; 22 newly admitted and 7 newly refused evaluations) |
| R3b M-2 row | PASS (`history_simplification_closeout.md:103`) |
| R3c LCL-0325 | PASS. Four shapes, as LTB-0335 line 2192 draws them, and the breach rule as written: the membership limit applies only when the largest count exceeds 1, and the block asserts more than 100 refusals. The "five membership shapes" sentence at closeout line 458 is kept as a record of the run at `a86f8573`, with the reason stated |
| R3d empty axis | PASS, verified by reading the callers. The durable run builds `history_axis` with `ledgr_availability_calendar()` (`R/backtest-runner.R:874-880`) or takes a supplied substrate, which `ledgr_history_substrate_validate()` refuses unless `length(axis) > 0`. Sweep (`R/sweep.R:260`), precompute (`R/precompute-features.R:83`), walk-forward (`R/walk-forward.R:133`) and pulse inspection (`R/pulse-snapshot.R:430`) call `ledgr_history_substrate_for_experiment()`, which builds the axis with `ledgr_availability_calendar()` (`R/history-substrate.R:193`). That function refuses fewer than two open-session pulses with `ledgr_run_window_too_short` (`R/availability-provider.R:404-411`). `segment_limit` is a positive whole number, so a count of 1 cannot breach it |
| Timing disclosure | PASS. The closeout figures equal re-review 1's table: 80, 320 and 1,280 sets on BASE, `303ded9c` and the candidate. The item is under "Routed, not changed here" (M-8) with the O(S log S) exit and names `assume_effective` users. The section names no owner ticket for any item (N3) |
| `adcc9de8` | Legitimate. The shorter note says the same as the longer one: it drops only the explicit cross-reference sentence and keeps "(see [ledgr_facts()])", and `R/sim-pit-inputs.R` keeps its line count, so LTB-0269's census locations hold. Brittleness: N2 |
| No product path changed | PASS. Every changed line in `R/` begins with `#'` (`R/availability-facts.R`, `R/sim-pit-inputs.R`), and nothing in `src/` changed. The identity runner and fixture ladder were not re-run; their Correction 1 results (86 of 89, ladder 50 of 50) stand. The census CSV churn is line renumbering in `R/availability-facts.R` plus the two new LTB-0337 references (`helpers.csv`), as the closeout says |
| Regression | None. Full suite: no failure or error, 18,446 expectations, the count the closeout records for `adcc9de8`. LTB-0337 has 108 expectations, LTB-0335 441 and LTB-0079 128, all passing unmutated |

## Mutations (mutation copy, each restored and checked byte for byte)

| ID | Mutation | Block | Result |
| --- | --- | --- | --- |
| M0 | none | LTB-0337 / 0335 / 0079 | 108 / 441 / 128 expectations, none failed |
| D5 | `R/history-substrate.R:940` `<=` to `<` (R2) | LTB-0337 / 0335 | fails (2) / survives |
| D5c | `R/history-substrate.R:897` `<=` to `<` (complete-header tie) | LTB-0337 / 0335 | survives both (S2); wrong on 64 of 527 public families |
| W1q | old status sentence back in the `.qmd` only | LTB-0079 | fails (1) |
| W1m | old status sentence back in the `.md` only | LTB-0079 | fails (1) |
| W2 | lifetime passage reworded to "is kept but does not change the run" in both files | LTB-0079 | survives (N1) |
| W3 | true sentence added to both files: "A corporate-action row with neither an event clock nor a knowledge clock is audit-only." | LTB-0079 | fails (2) (N1) |

## Notes (not findings)

- N1, the LTB-0079 negative check is both too broad and too narrow.
  - Too broad: `knowledge[^.]*audit-only` matches any sentence that names
    knowledge and audit-only. It therefore forbids a true statement of the
    clockless corporate-action rule (W3), which `?ledgr_facts` makes and
    the article, with its four-clock corporate-action paragraph, could
    teach.
  - Too narrow: the comment says it guards against "audit-only or
    run-neutral" wording, but a run-neutral rewording without the word
    audit-only passes (W2).
  - Neither is a current defect. Scoping the pattern to the membership,
    status and lifetime families, or pinning the article's sentences
    positively, would fix both.
- N2, LTB-0269 pins schema-version literals by `file:line`, so any roxygen
  edit above such a literal in any `R/` file fails a fast block.
  `adcc9de8` fitted the prose to the old line count. That is legitimate,
  because the shorter text is equivalent. Updating the census location
  with a stated reason would also have been legitimate: it is a location
  fixture, not a product oracle. The brittleness is worth recording for the
  census owner, for example by keying each row by enclosing object and
  field. The closeout records the event.
- N3, "Routed, not changed here" names no owner ticket for any item. The
  section had this form when earlier reviews passed F4, so the M-8 cost
  item follows the existing convention.
- N4, independent of S2: across the 527 public tied families of
  `d5c_known.R`, the live counter equals the canonical brute-force count on
  every one. This adds evidence for decision (24) on the bulk-delivery
  shape.

## Suite and checkers

- Full suite on the candidate copy (`load_all()`, then `test_local(...,
  stop_on_failure = FALSE, load_package = 'none')`): 1,147 blocks, 18,446
  expectations, 0 failures, 0 errors, one optional skip
  (`ledgr_snapshot_from_yahoo requires quantmod`), 683 s of block time,
  11.5 min wall time.
- `tools/check-codebase-contracts.R --mode=check`:
  `LEDGR_CODEBASE_CENSUS_OK` (helpers 1,804, findings 72), and
  `LEDGR_MODE_BRANCH_CENSUS files=29 functions=55 branch_sites=158
  flow_sites=55`. `--self-test-mode-branches`:
  `LEDGR_MODE_BRANCH_SELF_TEST_OK`.
- `tools/check-fold-phase-contract.R .`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.
- `tools/render-vignettes-gfm.R --check vignettes/point-in-time-inputs.qmd`:
  exit 0, "Verified vignette Markdown".
- Not run: the identity runner and fixture ladder (no product change), the
  fast, review and heavy profiles, and `R CMD check`.

## Review ratio

Two findings (S1, S2) over six re-reviewed items (R1, R2, R3, the timing
disclosure, `adcc9de8`, and the product-path check): 2/6 = 0.333. This is
the review of correction round 2; under the AGENTS.md governance loop a
third correction round goes to the maintainer.
