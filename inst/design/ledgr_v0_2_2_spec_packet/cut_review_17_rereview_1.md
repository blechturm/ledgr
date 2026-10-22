# Cut 17 focused cut re-review

**Mode:** Type 1 focused re-review with input check.
**Reviewer:** Claude Opus 5.5, independent session; did not write the cut or
its first review.
**Baseline:** patched draft `5ee995bc` on `integrate/cut15-v0.2.2`, compared
with the first draft `79964bf6`; package tree `5d8efb87`.
**Date:** 2026-10-22.
**Verdict:** `PASS_AFTER_PATCHES`, with one maintainer confirmation at
acceptance (N1).

R1-R12 and the should-fix items from [`cut_review_17.md`](cut_review_17.md)
are incorporated. Decisions (10)-(14) are carried into the right tickets, and
decisions (7) and (8) now point at them without contradiction. The
regeneration introduced eight bounded problems. Two of them contradict
shipped behavior: dense runs cannot stop `INCOMPLETE`, and LTB-0034 pins a
zero refusal count. One is a dropped acceptance item. Each has an exact patch
below. None changes the cut's design.

## Original findings

| Item | Disposition | Where |
| --- | --- | --- |
| R1 held refused facts silent | incorporated (new LDG-3089, WS49 claim, LDG-3087 depends on it); see N1, N2 | LDG-3089 |
| R2 witness after pinning | incorporated: witness inside the adapter before sealing; census and re-pin loop in LDG-3087 | LDG-3086, LDG-3087 |
| R3 oracle chosen after data | incorporated verbatim (tolerance, F != 1 basis rule, date role, closed outcomes, per-event refusal) | LDG-3086 |
| R4 identity and seal edges | incorporated; same-date classification amended by (14); see N8 | LDG-3086 |
| R5 estimator underspecified | incorporated (parameters, read order, month start, kept-mark hold, three-year sim; LDG-3083 literal pulses and kept-mark block); see N7 | LDG-3082, LDG-3083 |
| R6 memory comparator | incorporated (LDG-3069 sampler, three E8 metrics, 1.10 bound, four-candidate grid) | LDG-3088 |
| R7 vacuous private run | incorporated; walk-forward run rather than retired (deliberate, acceptable); see N4, N5 | LDG-3088 |
| R8 LDG-3085 format and shape | incorporated (D1-F7, existing reason, one vector, Q4 bump, changed roots listed); see N6 | LDG-3085 |
| R9 macro edits, LDG-3084 placement | incorporated: amendments named in the opening; LDG-3084 moved to WS50 last with deps LDG-3088 (deliberate, acceptable); LDG-3088 deps LDG-3083 and LDG-3087 | opening, LDG-3084, LDG-3088 |
| R10 claims, closeout, IDs | incorporated (WS49 claim, package-only fast profile, split ranges, research-side adapter test) | WS49, closeout, sequencing, LDG-3086 |
| R11 vendor vocabulary | incorporated (defaults; out_of_scope no longer lists special dividends) | decisions, out_of_scope |
| R12 public proof details | incorporated (dividend status, quadprog-optional path) | LDG-3082 |
| Should-fix: authority | incorporated (LFB-013, LFB-014, F2-F8, D1-F7, E7-E8) | authority |
| Should-fix: RFC waiver | incorporated in decision (9) rather than the acceptance line; acceptable, because the decision text is the binding record | decisions |
| Should-fix: capability-gap note | incorporated (both expected gaps) | LDG-3082 |
| Should-fix: schema follows Q4 | incorporated ("the stored format bumped by LDG-3085") | LDG-3087 |

Known deliberate choices, all acceptable: stable ticket IDs, new LDG-3089,
LDG-3084 last in WS50, and the 26-fold walk-forward run rather than retired.

## Decisions (10)-(14)

- **(10)** is in LDG-3086 (the unit and date witness), LDG-3087 (full-build
  census) and LDG-3088 (end-to-end sample). WS8's citation goes through the
  opening amendment and LDG-3084. LDG-3086 does not cite (10) by number; this
  is cosmetic. The LDG-3088 acceptance is not failure-sensitive (N4).
- **(11)** is in LDG-3082 (`min_obs`, fixed `shrink` with a stated default)
  and LDG-3083 (the `min_obs` block). The threshold block is unchanged.
- **(12)** is in LDG-3089. The dense half contradicts the shipped refusal form
  (N1), and the LTB-0034 clause contradicts the counting rule (N2).
- **(13)** is in LDG-3085 (the bump and refusal) and LDG-3087 (builds in the
  bumped format). The condition and constant are unnamed (N6).
- **(14)** is in LDG-3086 (per-event refusal, the global basis rule, summed
  `sum_consistent` groups). The summed fact's ID is undefined (N8).
- **(7) and (8)** now read "as amended by (14)" and "as amended by (10)". The
  defaults sentence agrees with both.

## New findings

### N1. Strict refusal "in dense and availability runs" contradicts the dense contract; the governing policy field is unnamed (Type 1, medium)

**Where.** LDG-3089 scope ("stops the run INCOMPLETE under the strict preset,
in every execution mode") and acceptance item 2 ("stops INCOMPLETE on a held
refused fact, in dense and availability runs").

**Verified by reading.** A dense run has no typed stop. A refused settlement
there raises instead (`R/fold-engine.R:365-370`, which calls
`ledgr_corporate_action_refusal_abort()` when `!services$availability_active`;
`R/corporate-action-settlement.R:119-153`). The contract says the same:
`contracts.md#contract-result-corporate-actions` states that under
`unsupported_quantity = "refuse"` an availability run stops `INCOMPLETE` and
"a dense run raises `ledgr_corporate_action_quantity_unsupported`". The
acceptance item therefore cannot pass without adding a stop to frozen dense
mode.

Separately, "the strict preset" is not a policy value. The presets are two
combinations of five fields (`R/corporate-action-policy.R:244-258`), so a
custom policy has no defined behavior. The existing unmodeled-fact route
already gives decision (12)'s behavior under both presets: report-only
fidelity `unsupported` under research, refusal under strict.

**Patch (LDG-3089).**

- Scope: replace "A held refused fact makes corporate_action_fidelity read
  unsupported under the research preset and stops the run INCOMPLETE under
  the strict preset, in every execution mode." with:

  > A held refused fact takes the unsupported-quantity route of
  > contracts.md#contract-result-corporate-actions. Under
  > `unsupported_quantity = "report_only"` (research), nothing posts, it
  > counts in `unsupported_facts` and fidelity reads `unsupported`. Under
  > `"refuse"` (strict), an availability run stops `INCOMPLETE` with
  > `corporate_action_quantity_refused` and a dense run raises
  > `ledgr_corporate_action_quantity_unsupported`, as held unmodeled facts
  > already do. There is no new execution-mode branch (decision 35
  > precedent). Because the route's trigger widens, the
  > `unsupported_quantity` policy IDs advance (v001 to v002, as the
  > held-terminal IDs did, `R/corporate-action-policy.R:72-74`), and the
  > identity change is recorded.

- Acceptance item 2: replace it with "a registered block shows the strict
  preset stops an availability run INCOMPLETE and raises
  `ledgr_corporate_action_quantity_unsupported` in a dense run on a held
  refused fact that is the fixture's only held corporate-action fact".
- **Maintainer confirmation at acceptance.** Confirm in one line that (12)'s
  "stops INCOMPLETE ... in every execution mode" means each mode's existing
  refusal form. A literal dense `INCOMPLETE` stop would be a dense-mode
  extension and a Type 2 question.

### N2. "LTB-0034's unheld case still passes" contradicts counting sealed refused facts (Type 1, medium)

**Where.** LDG-3089 scope ("counts sealed refused (complete = FALSE) facts by
refusal_reason") and acceptance item 3.

**Verified by reading.** The LTB-0034 fixture seals one unheld refused
`spin_off` (`missing_terms`) under a flat strategy. It asserts
`none$refusal_counts == c(missing_terms = 0L)`
(`tests/testthat/test-corporate-action-results.R:109`) and the printed line
`"    missing_terms: 0"` (`:131`). If sealed refused facts are counted in
`refusal_counts`, LTB-0034's oracle must change. AGENTS.md forbids that
without a stated reason. The draft states the opposite.

**Patch (LDG-3089 scope).** Append:

> `refusal_counts` counts held refused facts by reason, so LTB-0034's unheld
> fixture keeps `missing_terms = 0`. A new field, `sealed_refusal_counts`,
> counts every sealed refused fact by reason, and `print()`/`summary()` show
> it on its own line.

Acceptance item 3 then reads: "LTB-0034 passes unchanged; its unheld refused
fact reads 1 in `sealed_refusal_counts` and changes neither
`refusal_counts`, fidelity nor the run outcome."

(The alternative is to put sealed counts in `refusal_counts` and change
LTB-0034's oracle to 1, recording the reason. That is also acceptable, but
then the ticket must say so.)

### N3. The regeneration dropped LDG-3086's entitlement-clock and no-knowledge acceptance item (Type 1, medium)

**Where.** LDG-3086 acceptance. The first draft (`79964bf6`) had: "policy
v004 emits only ordinary_cash_dividend corporate-action facts, every complete
row has an entitlement clock (no decision 33 refusal can fire on a mapped
row), and no knowledge time is supplied". `cut_review_17.md` did not ask to
remove it, and the patched draft omits it.

**Consequence.** Decisions (6) and (13) assume every dividend row arrives
without a knowledge time. If v004 supplied one, LDG-3085 would correctly read
it as `evidenced` (decision 31), and the assumed-knowledge disclosure would be
silently empty on the private build. The scope sentence alone has no test.

**Patch.** Restore as LDG-3086's first acceptance item: "policy v004 emits
only ordinary_cash_dividend corporate-action facts; every complete row has an
entitlement clock (no decision 33 refusal can fire on a mapped row) and no row
supplies a knowledge time; the adapter test fails on either". Add to LDG-3087
acceptance: "the census shows every supplied dividend's knowledge reads
`assumed`".

### N4. The G-025 sample cannot fail on a missing posting (Type 1, low-medium)

**Where.** LDG-3088 acceptance item 5.

"Each posted dividend CASHFLOW equals ..." checks only postings that exist.
An entitled event that never posts passes, and the posting time is not
checked. "Mismatches are counted by reason" leaves open whether a mismatch
fails. Decision (10) names a buy-and-hold sample, but the acceptance does not
say which run is compared.

**Patch.** Replace the item with:

> In a separate buy-and-hold run over a sample of names without spin-offs,
> preregistered before the run with its size, every witness-matched ex-date
> of a sampled name inside the holding produces exactly one CASHFLOW. It
> posts at that ex-date's session close and equals the witness-implied amount
> times the held quantity within the LDG-3086 tolerance. Sampled events that
> the witness refused post nothing and appear in `refusal_counts`. Any
> missing, extra, mistimed or unequal posting fails unless the maintainer
> accepts it with a recorded reason. If the basis gate is closed, the sample
> shows zero postings and every sampled event is counted as refused.

### N5. "The registered 26-fold walk-forward shape" is not registered and is ambiguous (Type 1, low)

**Where.** LDG-3088 scope and acceptance item 7.

**Verified by reading.** No 26-fold shape is registered in
`tests/claims.yml`. Two 26-fold shapes exist in `dev/bench`:

- `dev/bench/v0_2_2_real_data_scale/run_record.R:265-279`: rolling from
  1998-01-02 to 2026-09-04, 2-year train, 1-year test and step,
  `scale_momentum` with `n` in {10, 20}, `ledgr_rule_argmax("sharpe_ratio")`,
  seed 1. This produced the `sharadar_pair` before arm that the Cut 13
  handover (LDG-3019) names.
- `dev/bench/v0_2_2_sharadar_run/stage.R:147-160, 189-191`: from 1998-01-05,
  momentum with lookback 63 and `n` in {10, 20, 40}.

The scope also says the WS48 strategy runs "unchanged". Without naming the
shape, an implementer could run the estimator under walk-forward, and its
clock would not be comparable.

**Patch.** Replace the sentence with:

> Run the 26-fold walk-forward phase of
> `dev/bench/v0_2_2_real_data_scale/run_record.R` (its own momentum strategy
> and grid, not the Workstream 48 estimator) on this build. Record its clock
> beside `dev/bench/v0_2_2_real_data_scale/evidence/sharadar_pair`, disclosing
> the build differences (rule 4, the LDG-3085 format, dividend facts). This
> discharges the Cut 13 LDG-3019 post-clock handover.

Acceptance item 7: "the named 26-fold walk-forward completes 26 of 26 folds
DONE and its clock is recorded beside the sharadar_pair arm".

### N6. Name the rebuild condition, the format constant and the contract addresses (Type 1, low)

**Verified by reading.** Every older, newer or fingerprint-mismatched store
refuses with `ledgr_store_rebuild_required` (`R/store-gate.R:59-84,
158-206`). The fingerprint covers every `ledgr_*_(schema|rule)_version`
constant. No constant is called the "snapshot stored-format version"; the
contract's term is experiment-store schema 122
(`contracts.md#contract-persistence-current-format`). AGENTS.md asks tickets
to cite stable contract rule-group addresses, but LDG-3085 and LDG-3089 say
only "State the rule in contracts.md".

**Patch.**

- LDG-3085: replace "The snapshot stored-format version is bumped so older
  stores refuse with the classed rebuild condition" with:

  > `ledgr_experiment_store_schema_version` advances from 122 to 123, so
  > schema-122 stores refuse with `ledgr_store_rebuild_required`.

  Replace "State the rule in contracts.md" with:

  > State the rule in contracts.md#contract-snapshot-point-in-time-facts and
  > #contract-availability-disclosure, and move
  > #contract-persistence-current-format to schema 123.

- LDG-3089: replace "State the rule in contracts.md" with:

  > State the rule in contracts.md#contract-result-corporate-actions and
  > #contract-config-policies.

- Decision (13) and LDG-3087 may keep their wording once LDG-3085 names the
  constant.

### N7. The hold-on-failure path misses the second sizing-unavailable trigger (Type 1, low)

**Verified by reading.** `ledgr_target_rebalance()` raises
`ledgr_target_sizing_unavailable` in two places:

- for a reserved (kept or ineligible held) holding without a risk mark
  (`R/strategy-helpers.R:403-416`);
- for a held, positively weighted member with no current close and no risk
  mark (`:449-457`).

The second can occur with `keep`: an instrument whose current close is
missing can pass the threshold and `min_obs` screens and receive weight.
LDG-3082 holds only for "a kept instrument without a permissible mark".

**Patch.**

- LDG-3082 scope: replace "or a kept instrument without a permissible mark"
  with:

  > or a held instrument the rebalance must value has no permissible mark
  > (kept, or weighted without a current close), detected before the call
  > or by catching `ledgr_target_sizing_unavailable`.

- LDG-3083: extend the kept-mark item to "and a block fails if a held
  weighted instrument without a current close or permissible mark aborts the
  run".

### N8. The summed same-date fact has no fact_id, and some refusal reasons are outside the closed vocabulary (Type 1, low)

**Where.** LDG-3086 acceptance. The R4 fact_id scheme gives each same-date
row an ordinal. Decision (14) then merges a `sum_consistent` group into one
fact, and that fact's ID is undefined. The same-date refusal and the
gate-level `basis_unverified` reason are named "a named reason", but neither
is in the closed list.

**Patch.**

- Append to the fact_id item:

  > a summed sum_consistent group has fact_id
  > `div:<parent instrument_id>:<ex-date>:sum`; a group whose classification
  > changes between rebuilds is recorded as an intended identity change.

- Extend the closed reasons with `same_date_duplicate_consistent`,
  `same_date_unresolved` and the gate-level `basis_unverified`.

## Record-only note

Under decision (12), one held refused dividend makes the whole research run's
fidelity read `unsupported`. Per-event refusals are expected on 28 years of
vendor data, so the LDG-3088 headline will probably read `unsupported`
together with refused counts. That is the decided behavior. It is not a
finding, but the private record should say so plainly.

## Governance and clean checks

- **Cut record shape.** It matches Cut 16 apart from `evidence_owners` and
  `contract_receivers`, which only Cut 16 (an RFC-bound cut) carries. Cuts
  1-15 have neither, so N6's addresses suffice.
- **RFC waiver.** Recorded in decision (9) for the LDG-3085 and LDG-3089
  contract changes.
- **Macro plan amendments.** Named in the opening for acceptance: Remaining
  order, the Dividend facts route (currently "WS8 owns G-025",
  `macro_plan.md:1081`) and the H1 line (`:767`).
- **ID ranges.** WS48 LCL-0421..0440 and LTB-0431..0450; WS49 LCL-0441..0460
  and LTB-0451..0470. All are free: the highest IDs in use are LCL-0408 and
  LTB-0418, and no LCL/LTB-042x..047x appears under `tests/`. WS50 changes no
  package code and reserves none.
- **YAML.** `tickets.yml` parses. It has 167 unique ticket IDs, all
  dependencies resolve, workstream IDs are unique, and every ticket names a
  listed workstream.
- **Dependencies.** LDG-3087 depends on LDG-3085, LDG-3086 and LDG-3089;
  LDG-3088 on LDG-3083 and LDG-3087; LDG-3084 on LDG-3088. These agree with
  the sequencing prose.
- **Diff hygiene.** `git diff --check 79964bf6 5ee995bc` is clean. The patch
  adds no non-ASCII line; the file's only non-ASCII characters are two
  pre-existing em dashes in the Cut 15 record.
- **Posting clock.** Consistent. The research preset is
  `ledgr_corporate_actions()` with `cash_posting = "effective_close"`
  (`R/corporate-action-policy.R:193-246`). With the effective clock at the
  vendor ex-date (a Date naming the session close, Cut 16 decision 12), cash
  posts at the ex-date close.
- **Decision (3) and LDG-3082.** Consistent. Both read "excluded by the
  history or by the strategy's screens", so the threshold and `min_obs`
  exclusions are covered.
- **Code claims.**
  - `knowledge_assume_effective` exists as a reason
    (`R/availability-policy.R:168`, `R/valuation-summary.R:261`).
  - LTB-0034 is the unheld refused-fact case
    (`test-corporate-action-results.R:1-44, 47-116`), and see N2.
  - The `upstream_vintage_bound` tier is validated
    (`R/availability-facts.R:491`), and the article's tier name is wrong
    (`vignettes/corporate-action-adapter-authoring.qmd:95`), as LDG-3085 says.

**Verified by reading:** every code claim above, the E8 values in the
source table against the LDG-3069 numbers quoted in the first review,
LFB-013 and LFB-014 in ledgr-research `docs/governance/ledgr-feedback.md`,
and both 26-fold scripts. **Verified by execution:** YAML parse and
structure checks, the first-draft dump for comparison, the non-ASCII scan and
`git diff --check` (scratchpad `cut17_rereview/dump.R`, `dump_old.R`,
`fields.R`, `nonascii.R`). No product probe was run, no private vendor row
was read and no tracked file was edited.

This is the second independent Type 1 verdict in the Cut 17 sequence. The
exact patches above can be verified directly; a third review round is not
required unless the maintainer answers N1 with a dense-mode extension.
