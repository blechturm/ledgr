# WS49 phase A / LDG-3089, LDG-3085, LDG-3086 close review (Type 1), package `c79793e6..d71b8e9e`, adapter `6be0b99..8692311`

## Verdict: PASS_AFTER_PATCHES (no blocking defect; two detector gaps, one over-general contract sentence, one missing record line)

The three tickets do what their acceptance asks, and the piece LDG-3087 will
consume works end to end. I sealed v004 rows with the reviewed package. Every
row reads `assumed`, held refused dividends are counted by reason, and the
strict preset stops the run at the first held refused fact. The four findings
below change nothing in the private build.

What holds:

- LDG-3089 (refused-fact disclosure).
  - Route. A refused fact joins the plan's `unmodeled` mask
    (`!rows$complete`, `R/corporate-action-settlement.R`). A held one
    therefore reaches the existing `check_quantity_effects()` refusal and
    the existing `ledgr_corporate_action_refusal_abort()` dense raise. No
    branch on `availability_active` or an equivalent was added.
  - Census and checker. On a clean copy of `d71b8e9e`,
    `tools/check-codebase-contracts.R --mode=check` reads 158 branch and 55
    flow sites in 29 files against the unchanged committed record. Its
    self-test prints `LEDGR_MODE_BRANCH_SELF_TEST_OK`.
    `tools/check-fold-phase-contract.R` prints
    `LEDGR_FOLD_PHASE_CONTRACT_OK`.
  - Strict forms. LTB-0452 pins both:
    - availability: INCOMPLETE with `corporate_action_quantity_refused`,
      and the stopped diagnostic is at the fact's effective pulse;
    - dense: raises `ledgr_corporate_action_quantity_unsupported`, carrying
      the fact's `source_fact_ids`.
  - Counts.
    - `sealed_refusal_counts` comes from one `GROUP BY refusal_reason`
      query over every sealed refused fact.
    - `refusal_counts` counts only facts whose parent the run held at
      entitlement, keyed by the same sealed reasons, so a reason with no
      held fact reads 0. It uses `tabulate()`, and the entitled quantities
      use `rowsum()`.
    - LTB-0453 pins the unheld case under both presets: sealed 1, held 0,
      fidelity `none`, strict run DONE.
  - LTB-0034 changes only in its two `unsupported_quantity` identity
    strings (v001 to v002) and one comment. Its `refusal_counts` oracle
    (`missing_terms = 0L`) and its printed line are untouched, which
    decision (18) allows.
  - Policy ids.
    - `ledgr_corporate_action_policy_ids()` returns
      `...unsupported_quantity.report_only.v002` and `...refuse.v002`.
    - The three re-pinned config hashes (`test-config.R`,
      `test-sweep-parity.R`, LTB-0309) follow from that id bump alone.
    - Every other changed test literal is a schema literal.
  - Contract and article.
    - `contracts.md` states the route once, in
      `#contract-result-corporate-actions` plus one counts bullet.
    - The `#contract-config-policies` sentence gives only the reason for
      v002 and points to that section.
    - The adapter-authoring article's "Refusal Is A Result" section matches
      the contract.
- LDG-3085 (assumed knowledge).
  - Label.
    - `ledgr_corporate_action_assumed_knowledge()` now returns the `assume`
      vector it already computed.
    - The constructor turns it into two `ifelse()` vectors, and the
      existing per-row provenance pass writes them. There is no new pass.
    - A supplied knowledge time keeps `evidenced` with no
      `knowledge_reason`.
    - My mutation P2 writes a reason on evidenced rows. It fails LTB-0454
      and the frozen fact-identity oracles LTB-0149 and LTB-0151, so the
      bytes of supplied-knowledge families are pinned.
  - Disclosure.
    - The family records `knowledge = assume_effective` metadata, and
      `ledgr_fact_assumption_reasons()` reads it.
    - `ledgr_valuation_summary()` applies the corporate-action family to
      every run.
    - The printed line reads "assumption-backed facts:
      equity_corporate_actions (knowledge assumed effective)".
    - Dense results have no point-in-time line, as the evidence says.
  - Schema 123.
    - LTB-0260 classifies a schema-122 marker as `older`, which raises
      `ledgr_store_rebuild_required`.
    - I compared `schema-current-golden-rows.csv` column by column over
      its 2,496 rows: only `schema_version` differs.
    - The four catalogue hashes in `schema-current-golden.csv` are
      unchanged.
  - Identity claim, re-checked at base and head on my own v004-shaped rows
    (Date clocks, no knowledge time, one refused row):
    - supplied `div:` fact_ids are identical;
    - the family hash changes (`8080ebe3` to `5d55d3a6`);
    - generated fact_ids change, as NEWS says.

    In the suite, the fact-integrity, sim-PIT and
    equity-corporate-action blocks pass on head with no literal edited, so
    no pinned root, family hash or fact_id changed.
  - Article and contracts.
    - The article names only `snapshot_bound` and `upstream_vintage_bound`,
      the two tiers the validator accepts.
    - `build_and_vintage_bound` no longer appears anywhere in the tree.
    - The three named anchors are updated, and Current Store Format reads
      schema 123.
- LDG-3086 (adapter v004).
  - Chronology, from commit times and the census JSON `started_at` fields
    (+02:00 unless marked):

    | Time | Event |
    | --- | --- |
    | 23:59:51 | 3aebc55 preregistration |
    | 00:17:41 | df6773f implementation |
    | 00:17:46 (22:17:46 UTC) | bounded 2019-2021 census starts |
    | 00:20:36 | cfea96f NEEDS_TYPE_2 stop |
    | 00:23:43 | decision (15) recorded on the integration branch (854a97d0) |
    | 00:24:37 | dbd9fdd re-preregistration (Section 1b) |
    | 00:32:54 | 8cd7760 implementation |
    | 00:33:01 (22:33:01 UTC) | only full-lake census starts; its JSON records adapter commit 8cd7760, a clean tree and basis `unverified` |
    | 00:39:36 | 8692311 pins `split_adjusted` |

    - Each diagnosis script (00:18 and 00:19) ran for less time than one
      full-lake projection takes (150.8 s), so both ran on the bounded
      window.
    - The scratchpad holds one full-lake census file and one full-lake
      log.
    - Section 1 of the build notes is byte-unchanged since 3aebc55; later
      commits only add Section 1b and Sections 2-4.
  - Decision (15) is implemented exactly.
    - The step SQL is `X.c * Y.a / X.a - Y.c`, where X is the session
      before the vendor date and Y is the vendor date. That is
      `c0*a1/a0 - c1 = c1*(r1/r0 - 1)` with `r = closeadj/close`.
    - The tolerance SQL is
      `h(c0)|a1/a0| + h(a1)|c0/a0| + h(a0)|c0*a1|/a0^2 + h(c1) + 1e-6`.
      I re-derived it from the four first-order partial derivatives of
      `D_hat`, and it matches build notes 1b.2 term by term.
    - `h` is `0.5*10^-max(2, decimals - exponent)`, as Section 1.3
      defines it.
  - Gate.
    - The gate opens only when the whole lake passes, the out-of-sample
      years pass, and both choose the same hypothesis.
    - It uses exact integer arithmetic: `100*chosen >= 99*n` and
      `1000*other <= n`. This is the 1b.3 rule.
  - The census is internally consistent.
    - For each population and basis, outcomes sum to the entered rows:
      57,593 = 51,705 + 5,888.
    - In-sample plus out-of-sample literal and decidable counts equal the
      whole lake.
    - The 11,254 F != 1 events split into 10,469 matching C only, 767
      matching both, 0 matching C/F only and 18 matching neither.
    - The shares recompute: 8,513/8,531 = 0.99789 and 8,879/8,897 =
      0.99798.
    - The dispositions (57,593 + 495,308 + 19 + 3) equal the 552,923
      lake-wide dividend rows in build notes Section 2.
  - Rows and identity.
    - fact_id is `div:<parent>:<ex-date>:<ordinal>`, or `:sum` for a summed
      group. The ordinal ranks rows by vendor value, ties broken by raw
      text. The source is the stable `sharadar_actions`.
    - `sharadar_ledgr_adapter_dividend_reasons()` equals the closed list.
    - No knowledge, payment or record clock is emitted, and a guard aborts
      if one appears.
    - `spinoffdividend` is used only as a same-date non-cash marker.
    - The dictionary entry is pinned by hash, unit type and phrases, and
      the build fails closed on drift.
    - An empty window omits the family.
    - One grouped query counts non-session, out-of-window, unmapped and
      off-axis rows, and none of them enters. The projection aborts unless
      entered rows equal witness rows.
  - The witness is one SQL query plus a vectorised `ifelse`/`rowsum`
    classification, with no per-event loop.
  - Adapter tests.
    - The dividend tests pass on my copy against ledgr `c79793e6` (11
      tests, 96 expectations).
    - The full adapter suite passes against the reviewed package
      (`d71b8e9e`, schema 123): 323 tests including my probe, 1,380
      expectations, 0 failures and 39 library-selection skips.
    - The implementer ran against `c79793e6` and saw 29 skips. None of
      the 10 extra skips is a dividend or snapshot-adapter test.
- Integration with the reviewed package (neither implementer ran this).
  - Setup: the adapter's synthetic dividend fixture, sealed by `d71b8e9e`,
    with both parents held at 10 shares from the start.
  - Sealing: all 8 rows seal (3 complete, 5 refused), and all 8 read
    knowledge `assumed`.
  - Research preset:
    - the run is DONE and fidelity reads `unsupported`, with 5 unsupported
      facts;
    - cash posted is 6.0 (2.5 + 2.5 + 1.0, the three complete facts at 10
      shares);
    - each of the five refusal reasons counts 1 held fact with entitled
      quantity 10, and 1 sealed fact;
    - `equity_corporate_actions` is listed with
      `knowledge_assume_effective`.
  - Strict preset: the run stops INCOMPLETE with
    `corporate_action_quantity_refused` at 2020-06-03 20:00 UTC, the first
    held refused fact.

What does not hold:

- F1 (low, LDG-3085 acceptance 1-2, detector). LTB-0454 pins only one
  filled-row shape and one universe kind. Two of my mutations survive:
  - P3, which labels a knowledge time filled from an entitlement-only row
    as `evidenced`;
  - P4, which drops the corporate-action disclosure from fixed-basket
    availability runs.
- F2 (low, contract and article precision; the implementer's Note 2).
  - A held refused fact that has an entitlement clock and no effective
    clock is counted as held, and fidelity reads `unsupported`.
  - The strict preset never refuses it: the run ends DONE.
  - The contract and the article say strict stops the run.
  - This is an existing-route limitation, not a gap the ticket must close.
    The sentences need a qualifier.
- F3 (low, LDG-3086, detector). No adapter test fails when the witness
  never assigns `duplicate_consistent` (A1), or when the `h(c1)` term is
  dropped from the tolerance (A2). The same-date classes other than
  `sum_consistent`, and the tolerance formula, are pinned only by reading.
- F4 (low, record). The adapter's edits to existing tests (`persist_features`
  dropped from SHR-T335, SHR-T336 and two lifetime tests) give their reason
  only in commit df6773f. AGENTS.md puts that reason in the ticket evidence.

Review ratio: 4 findings over 3 completed tickets (LDG-3089, LDG-3085,
LDG-3086) = 1.33, recorded and not a gate. Over the 18 in-scope acceptance
items (4 + 4 + 10) it is 4/18 = 0.22.

## Method

- I read:
  - AGENTS.md and both implementer briefs;
  - the Cut 17 entry, decisions (1)-(18) and the acceptance N1 line;
  - Workstream 49, and LDG-3089, LDG-3085, LDG-3086 and LDG-3087 on the
    integration branch;
  - `cut_review_17.md` R1-R4 and R8;
  - `cut_review_17_rereview_1.md` N1-N3, N6 and N8;
  - register D1-F7;
  - the whole package diff (`R/`, tests, `contracts.md`, articles, NEWS,
    claims);
  - the whole adapter diff, build notes v004, both census JSONs, the
    adapter scratchpad's progress notes, scripts and mutation table, and
    the package scratchpad's mutation and identity records.
- Copies. I took clean `git archive` copies of `d71b8e9e`, `c79793e6` and
  the adapter at `8692311`, and installed `d71b8e9e` into a review-only
  library. Everything ran in `scratchpad/ws49a_review/`. R ran in one
  process at a time, and I did not touch `ledgr-wt/ws48`. Both worktrees
  are clean, with nothing written.
- No lake run. I read only aggregate census files and printed no vendor
  row, identifier or credential. The adapter fixture is synthetic.
- Probes, all in `scratchpad/ws49a_review/`:
  - `setup.R`: the golden-rows column comparison;
  - `run_blocks.R`: 14 test files, run singly;
  - `pkg_probe.R`: the identity check at base and head, Note 2 and warm
    block timings;
  - `perf_probe.R`: the result-reader cost of the widened route;
  - `test-zz-review-probe.R`: the adapter integration probe, run inside
    the adapter suite against `d71b8e9e`;
  - `pkg_mutations.R` and `adapter_mutations.R`: my mutations.

## Findings

### F1 (low, LDG-3085 acceptance 1-2, detector; LCL-0444): LTB-0454 pins one filled-row shape and one universe kind

Verified facts:

- `ledgr_corporate_action_assumed_knowledge()` fills knowledge from the
  effective time, or else from the entitlement time. LTB-0454's filled row
  has both clocks.
- Mutation P3 sets `assumed = assume & !is.na(rows$effective_time)`, so an
  entitlement-only fill is labelled `evidenced`. It passes all 18 blocks in
  the corporate-action, fact-integrity and sim-PIT files.
- `ledgr_valuation_summary_add_basis()` treats a fixed basket and a
  membership rule differently, and LTB-0454 runs only a membership
  universe.
- Mutation P4 adds the corporate-action family to the applied set only
  when a membership rule exists. It also passes the same 18 blocks.
- v004 rows carry both clocks, so the private build is unaffected.

Smallest fix (test only, LTB-0454 in
`tests/testthat/test-corporate-action-assumed-knowledge.R`):

- After the `mixed` checks, build a one-row family with
  `entitlement_time = as.POSIXct("2021-01-08 21:00:00", tz = "UTC")`, no
  `effective_time` and no `knowledge_time` (complete dividend, 0.5,
  validated). Assert that its provenance `knowledge` is `"assumed"`, that
  `knowledge_reason` is `"knowledge_assume_effective"`, and that
  `metadata$knowledge` is `"assume_effective"`.
- Give `disclosed()` a `universe` argument, defaulting to
  `ledgr_universe_members("u")`. Run the `mixed` family once more with
  `universe = c("AAA", "BBB")`, and assert that
  `assumption_backed_families` is `"equity_corporate_actions"`.
- Add P3 and P4 to LCL-0444's `smallest_failing_change`.

### F2 (low, contract and article precision; implementer Note 2): strict does not refuse a held fact that has no effective clock

Verified by execution (`pkg_probe.R`, availability run, AAA held from the
first pulse):

| Sealed fact | Preset | Status | Fidelity | unsupported_facts | refusal_counts |
| --- | --- | --- | --- | --- | --- |
| refused dividend, entitlement only | research | DONE | unsupported | 1 | basis_unverified 1 |
| refused dividend, entitlement only | strict | DONE | unsupported | 1 | basis_unverified 1 |
| complete `rights_issue` (unmodeled), entitlement only | research | DONE | unsupported | 1 | none |
| complete `rights_issue` (unmodeled), entitlement only | strict | DONE | unsupported | 1 | none |

How the code produces this:

- The summary binds the held quantity at the entitlement pulse.
- The plan's `quantity_due_idx` is `pmax(effective_idx, knowledge_idx)`, so
  with no effective clock the fact is never due and never refused.

Assessment: this is an acceptable existing-route limitation, not a gap the
ticket must close.

- Complete unmodeled facts have behaved the same way since Cut 12, as the
  probe's last two rows show.
- Decision (12), as confirmed with N1, binds "the existing
  unsupported-quantity route" and "each execution mode's existing form".
- The fact is not silent: fidelity reads `unsupported` and it is counted.
- v004 rows carry both clocks, so LDG-3087 is unaffected.
- Refusing such a fact at its entitlement pulse would change the route's
  due-pulse semantics for both fact kinds. That is a design question.

The contract and the article are still too general:

- `contracts.md#contract-result-corporate-actions` says strict stops "at the
  fact's effective pulse" without saying what happens when there is none.
- The article says "Under the strict preset an availability-aware run stops
  `INCOMPLETE`" with no qualifier.

Smallest fix (record only):

- In `contracts.md#contract-result-corporate-actions`, after "a dense run
  raises `ledgr_corporate_action_quantity_unsupported`;", add:

  > a held fact with no effective clock has no effective pulse, so under
  > either value it only counts in `unsupported_facts` and makes
  > `corporate_action_fidelity` read `unsupported`;

- Add the same clause to the article's "Refusal Is A Result" paragraph and
  re-render it.
- Optionally, add one line to the WS8 routed inputs: "strict refusal of
  held corporate-action facts that carry only an entitlement clock (design
  question; existing behavior since Cut 12)".

### F3 (low, LDG-3086 acceptance 2 and 7, detector): the tolerance formula and two same-date classes are pinned only by reading

Verified facts:

- My mutation A1 makes `duplicate_consistent` unreachable (every non-sum
  group becomes `neither`). All 11 dividend tests still pass.
- The fixture's only same-date group is `sum_consistent`.
  `same_date_duplicate_consistent` and `same_date_unresolved` are never
  produced in a test.
- My mutation A2 drops `h(c1)` from the tolerance, about half of it for the
  fixture's two-decimal closes. All 11 tests still pass.
- The implementer's M8b changes the formula and the tolerance together, so
  the formula alone is what kills it.
- The full lake has 0 same-date groups. I verified the tolerance by
  re-deriving it. The current build is therefore right, but a later edit
  to either piece would go unnoticed.

Smallest fix (one new test, no fixture change):

- Add SHR-T373, which calls `sharadar_ledgr_adapter_dividend_outcomes()` on
  a hand-built witness frame shaped like SHR-T370's `witness_of`. Use
  `basis = "split_adjusted"` and three two-row groups:
  - sum: rows 0.10 and 0.15, `d_step = 0.25`, expecting reason `matched`
    and group class `sum_consistent`;
  - duplicate: rows 0.10 and 0.10, `d_step = 0.10`, expecting
    `same_date_duplicate_consistent` on both rows;
  - neither: rows 0.10 and 0.30, `d_step = 0.07`, expecting
    `same_date_unresolved` on both rows.
- In the same test, evaluate
  `sharadar_ledgr_adapter_dividend_step_sql("x", "y", "s")` in an
  in-memory DuckDB:
  - one-row inputs: `x` = (c 10.00, a 9.50, hc 0.005, ha 0.00005) and
    `y` = (c 10.50, a 10.00, hc 0.005, ha 0.00005);
  - assert that `d_s` equals `10 * 10 / 9.5 - 10.5`;
  - assert that `tol_s` equals the 1b.2 closed form computed in R.
- Record A1 and A2 as killed mutations.

### F4 (low, record): the adapter's existing-test edits lack their reason in the ticket evidence

Verified facts:

- Commit df6773f edits the setup of four existing adapter tests:
  `persist_features` is dropped from SHR-T335, SHR-T336 and two
  `test-lifetime-facts-v002.R` tests.
- The adapter's progress notes record a baseline of 311 tests with 3
  errors from that removed argument. This was before any v004 change, so
  the edits do not hide a product failure.
- The reason appears only in the commit message. The LDG-3086 evidence
  does not mention it.

Smallest fix: append this to the LDG-3086 evidence:

> Existing adapter tests changed for a stated reason: SHR-T335, SHR-T336
> and two lifetime-facts-v002 tests drop the persist_features argument that
> ledgr v0.2.2 removed (they errored on ledgr c79793e6 before any v004
> change); SHR-T351 expects the v004 policy string; the adapter fixture
> adds the synthetic dictionary entry and policy pin the dictionary check
> needs.

### Notes (no change required)

- N1. Result-reader cost of the widened route (seven-shape walk, shapes 4
  and 5).
  - What changed. Before, a dividend-only snapshot never reached
    `ledgr_corporate_action_held_unsupported()`. Now a refused fact does,
    so every `summary()` and `print()` reads its parent's
    FILL/CASHFLOW/DISPOSITION events and parses each event's `meta_json`.
  - Measurement (`perf_probe.R`): a synthetic dense run, 60 instruments,
    47,940 fills, one dividend per instrument, research preset, median of
    3:

    | Facts | Summary | Print |
    | --- | --- | --- |
    | complete | 0.030 s | 0.48 s |
    | refused | 0.290 s | 0.67 s |

  - The cost grows linearly with the refused parents' events. It is
    existing code reached more often, not a new loop.
  - On the dividend build, refused parents probably hold most fills, so
    LDG-3088 should record `print(bt)` and summary time beside its run
    clock.
- N2. Fast-profile cost.
  - Warm timings on this host (not quiet): LTB-0451 1.31-1.46 s, LTB-0452
    1.14-1.16 s, LTB-0454 1.33-1.39 s, about 3.9 s in all.
  - LTB-0451 takes 9.9 s cold, as the first block in a process.
  - Cut 16 left 6.04 s of headroom, and Workstream 48 adds blocks too.
  - The coordinator's quiet-host gate decides.
- N3. Decision (15) said "r0, r1 the prior and vendor-date closeadj". The
  coordinator's correction (r = closeadj/close) was recorded at 00:40:51 in
  619067ab, after the full run. Only the wording moved, for three reasons:
  - the binding preregistration dbd9fdd already defined `r = closeadj /
    close` before the run;
  - the diagnosis table that decision (15) cites (cfea96f, Section 4.2)
    already stated it;
  - the raw-closeadj reading would count the day's price change as a
    dividend.
- N4. The full-lake numbers come from a scratchpad driver
  (`ws49adapter/census.R`). That driver calls the committed
  `sharadar_ledgr_adapter_dividend_census()`. The non-cash action counts
  and the constructor-by-basis check exist only in the driver. LDG-3087's
  "check script ... rerun reproduces the counted files" is where a
  committed driver belongs.
- N5. `same_date_non_cash_action` is 0 lake-wide, although axis parents
  have 278 `spinoff` and 263 `spinoffdividend` rows in the window. The
  marker needs the same parent and date as a cash dividend, which is
  plausibly rare. My A3 kills the marker path on the fixture.
- N6. `prior_bar_missing` also catches a present bar with a non-positive or
  non-finite price, because `has_step` requires positive finite prices.
  That is slightly wider than "no exported bar" in build notes 1.4. It
  covers 14 rows lake-wide.
- N7. Refused rows now always pass through the plan's clock-to-pulse check
  (`ledgr_corporate_action_clock_mismatch`). Before, they did so only when
  another row was eligible. v004 Date clocks fall on sessions, so the
  build is unaffected.
- N8. `ledgr_experiment_plan()` still lists four runtime families in its
  checks table. The corporate-action assumption appears in results only,
  which is what the ticket asks for.

## Acceptance items

| Item | Result |
| --- | --- |
| 3089-1 LFB-014 reproducer fails on zero counts or modeled/none | met (LTB-0451, both modes; implementer M2, M3, M7) |
| 3089-2 strict: availability INCOMPLETE, dense raises, only held fact | met (LTB-0452; adapter-level probe agrees); F2 for facts without an effective clock |
| 3089-3 LTB-0034 unchanged except identity (decision 18); sealed 1; unheld neutral | met (LTB-0453) |
| 3089-4 v002 ids; contract once; article matches; mutations | met (F2 for precision) |
| 3085-1 filled reads assumed, disclosed; supplied evidenced | met for the both-clock shape and membership runs (F1) |
| 3085-2 block fails on mislabel or omission | partial (P3, P4 survive; F1) |
| 3085-3 schema-122 refuses; changed goldens listed | met (LTB-0260; golden rows differ only in version; identity re-probed) |
| 3085-4 article tiers; contract once; seven-shape walk | met (N1 adds to the walk) |
| 3086-1 only dividends, entitlement clock, no knowledge; test fails on either | met (SHR-T362; implementer M2, M2b, M3, M3b) |
| 3086-2 tolerance fixed before the first full run | met (dbd9fdd before 22:33 UTC; formula verified); not test-pinned (F3) |
| 3086-3 basis rule on F != 1 decidable events, 99/0.1 | met (code, SHR-T370 and SHR-T371, census recomputed) |
| 3086-4 date role checked, adjacent refuses | met (51 adjacent_session_step; SHR-T364) |
| 3086-5 closed reasons; per-event refusal | met (my A4 kills a reason-precedence change) |
| 3086-6 fact_id scheme, stable under rebuild and permutation | met (SHR-T365, implementer M4) |
| 3086-7 same-date classification | met in code; only `sum_consistent` tested (F3); 0 groups in the lake |
| 3086-8 non-session, out-of-window, off-axis counted; empty family omitted | met (SHR-T364, SHR-T368; dispositions sum checked) |
| 3086-9 dictionary pinned and fail-closed; spinoffdividend never cash | met (SHR-T367, SHR-T364; my A3) |
| 3086-10 as-traded test fails; suite passes; pin recorded | met (implementer M1; 11/11 on c79793e6, 323/323 on d71b8e9e) |

## Seven-shape walk (package `R/` diff, verbatim shapes)

- One-row frame per element, bound at the end: none.
  `ledgr_corporate_action_held_unsupported()` builds one frame from
  vectors.
- Full-table subset inside a loop over ids: none.
- Per-element parsing or formatting where a vectorised call exists:
  - the print path's `vapply(..., ledgr_corporate_action_value)` runs over
    refusal reasons, which the closed vocabulary bounds;
  - `sprintf` is vectorised.
- Per-row JSON on repetitive strings:
  - `ledgr_fact_provenance()` was already one canonical JSON per row
    (routed to LDG-3080/F05). The label and reason are written inside that
    same pass, so the shape is not widened;
  - the existing per-event `meta_json` parse is newly reached by refused
    facts (N1).
- Work computed and discarded, or recomputed on every call: the held route
  re-reads events and run pulses apart from the composition report. That
  structure already existed and is now reached by refused facts (N1).
- Quadratic validators: none.
- Scalar writes into an environment-held vector: none new.
- Adapter: the witness is one set-based SQL query, and the classification
  and census use vectorised `ifelse`, `rowsum` and `table`.

## Mutations (restored and verified)

| ID | Mutation | Detector | Result |
| --- | --- | --- | --- |
| P0 | control, no change | 18 package blocks | all pass |
| P1 | `assumed` is TRUE for every row without knowledge, including audit-only rows | 18 package blocks | passes (audit-only labelling is not specified; no finding) |
| P2 | evidenced rows get a `knowledge_reason` | LTB-0454, LTB-0149, LTB-0151 | fails |
| P3 | entitlement-only fill labelled evidenced | 18 package blocks | passes (F1) |
| P4 | fixed basket drops the corporate-action disclosure | 18 package blocks | passes (F1) |
| A0 | control, no change | 11 dividend tests | all pass |
| A1 | `duplicate_consistent` never assigned | 11 dividend tests | passes (F3) |
| A2 | tolerance without `h(c1)` | 11 dividend tests | passes (F3) |
| A3 | same-date non-cash flag ignored | SHR-T362 to SHR-T365, SHR-T369 | fails |
| A4 | `matched` checked before `rounding_unresolvable` | SHR-T364, SHR-T369 | fails |

The 18 package blocks are the files `corporate-action-assumed-knowledge`,
`corporate-action-refused-facts`, `corporate-action-results`,
`equity-corporate-action-facts`, `fact-integrity-oracles`,
`fact-integrity-persistence` and `sim-pit-inputs`.

A first run of P1-P4 made LTB-0078 fail in every copy, which looked like a
kill. The copy had left out `data-raw/`; the P0 control rerun with
`data-raw/` restored is clean. The table above is from the rerun.

I re-ran neither implementer's mutation tables (M1-M10, N1-N7, the 12
adapter mutations). I read their scripts and results, and the targets match
the claims.

## Verification record

Windows 11, R 4.6.1, sequential, on clean archive copies:

- Each new or changed package test file, run singly on `d71b8e9e`, passes:
  - `corporate-action-refused-facts` (2);
  - `corporate-action-results` (2);
  - `corporate-action-assumed-knowledge` (1);
  - `corporate-action-policy` (4);
  - `store-gate-contracts` (4);
  - `schema-current` (2);
  - `config` (10);
  - `availability-fold-witnesses` (4);
  - `fact-integrity-oracles` (3);
  - `fact-integrity-persistence` (1);
  - `equity-corporate-action-facts` (5);
  - `sim-pit-inputs` (4);
  - `indicator-history` (4);
  - `sweep-parity` (6).

  Every block named in the evidence (LTB-0032, LTB-0034, LTB-0258,
  LTB-0260, LTB-0309 and LTB-0451 to LTB-0454) is 0 failed, 0 error.
- Census, checker and diff checks:
  - the census check prints `LEDGR_CODEBASE_CENSUS_OK` and
    `LEDGR_MODE_BRANCH_CENSUS mode=check files=29 functions=55
    branch_sites=158 flow_sites=55`;
  - the census self-test and the fold-phase checker print OK;
  - `git diff --check` is clean on both ranges, and the changed package
    files are LF in the index.
- Adapter:
  - the dividend tests pass on ledgr `c79793e6` (11 tests, 96
    expectations);
  - the full suite plus my probe passes on ledgr `d71b8e9e` (323 tests,
    0 failures, 39 skips).
- I did not run the package full suite, `R CMD check`, the render check or
  the timing gate. The evidence covers the first three, and the coordinator
  owns timing.
- Test changes:
  - LTB-0451, LTB-0452, LTB-0453 and LTB-0454 are new (LCL-0441 to
    LCL-0444, within the reserved ranges);
  - LTB-0034, LTB-0032 and the three config-hash pins change only for the
    v002 identity (decision 18);
  - LTB-0258, LTB-0260, the golden CSVs and the fold-witness literal
    change only for schema 123.

  No other registered test, fixture or oracle changed. The adapter test
  changes are F4.
