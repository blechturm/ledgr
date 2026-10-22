# Cut 17 cut review: long-only estimator proof and dividend facts

**Mode:** combined Type 1 and Type 2 cut review (decision 9 makes this review
the challenge to decisions 1-9 and the defaults).
**Reviewer:** Claude Opus, independent session; did not write the cut.
**Baseline:** draft `79964bf6` on `integrate/cut15-v0.2.2` (package tree
`5d8efb87`); ledgr-research `6be0b99`.
**Date:** 2026-10-22.
**Verdict:** `CHANGES_REQUIRED`, with five Type 2 questions for the maintainer.

The cut has the right shape: WS7 as one package proof, a dividend-facts
workstream and a private run. The package side is buildable today. A probe
ran the planned strategy end to end through public APIs and a two-worker
sweep, with no engine change. Five problems need fixing before
implementation:

1. The design relies on "enter as `complete = FALSE` with a named reason" as
   the safe route for dividends. Today a held refused fact is silent: it is
   not counted, and fidelity reads `modeled` or `none` (LFB-014; adapter
   spec review F2). No ticket owns the fix.
2. The per-event check that sets `gross_cash_validated` comes after the
   adapter commit that must already set it.
3. The reconciliation tolerance and the gate rule are chosen after the data
   is seen.
4. The estimator is underspecified where the real data will break it. The
   shrinkage amount is open, a pairwise covariance can be indefinite, the
   universe is wider than the window (N > T), and a kept holding with no
   permissible mark aborts the run.
5. The WS50 memory budget has no defined comparator.

## Required findings

### R1. Held refused dividends are silent; no ticket owns the fix (Type 1, high)

**Where.** Decisions (7) and (9) defaults ("rows the adapter cannot validate
enter as complete = FALSE"; "dividend rows refuse with a basis-unverified
reason"). LDG-3088 ("dividends posted, refused and not supplied").

**Verified by execution** (`probe2.R`). One complete and two incomplete
dividends were sealed, and both parents were held across all three dates.
Result: one CASHFLOW; `refusal_counts` = `basis_unverified=0,
same_date_multiple_rows=0`; fidelity `modeled`. By reading,
`R/corporate-action-results.R` creates `refusal_counts` as zeros at :384-387
and never increments it. Every settlement path requires `complete`. This is
LFB-014 (open, high) and ledgr-research `spec-review.md` F2. The cut cites F3
to F8 but not F2.

**Consequence.**

- If the unit gate closes, the whole fallback is invisible in public results.
- Same-date rows refused under decision (7) are also invisible.
- G-016's "dividends refused" count could then come only from research-side
  accounting, which the WS7 exit statement forbids.

**Patch.** Add a WS49 ledgr ticket (or widen LDG-3085) titled "Count and
disclose refused corporate-action facts":

- scope: "`ledgr_corporate_action_summary()` counts sealed refused facts by
  `refusal_reason`. It separately counts refused facts whose parent was held
  at the entitlement pulse, by reason, with entitled quantity. A held refused
  cash dividend makes `corporate_action_fidelity` read `unsupported`."
  The maintainer decides the strict-preset behaviour (Q3).
- acceptance:
  - "a registered block reproduces LFB-014 (held incomplete dividend), and it
    fails if refusal counts read zero or fidelity reads `modeled` or `none`";
  - "LTB-0034's unheld case still passes";
  - "the adapter-authoring article's 'Refusal Is A Result' section matches
    the behavior".

LDG-3087 then depends on this ticket.

### R2. The per-event witness runs after the adapter is pinned (Type 1, high)

LDG-3086 sets `gross_cash_validated` "only after the per-event check" and pins
the commit. LDG-3087 runs "the G-025 check moved here" after the rebuild. The
check that decides validation has to run inside the adapter, before sealing.
Otherwise the pinned v004 either validates nothing or validates without
evidence.

**Patch.**

- LDG-3086 scope: replace "gross_cash_validated only after the per-event
  check" with: "the adapter computes, per mapped event, the dividend implied
  by the vendor `closeadj/close` step at the vendor date and sets
  `gross_cash_validated = TRUE` only for events that pass the preregistered
  rule in LDG-3086 acceptance. Other events enter `complete = FALSE` with a
  named reason (`closeadj_witness_failed`, `closeadj_witness_unavailable`)."
- LDG-3087 scope: "runs the v004 witness on the full build and records its
  census". If the census closes the basis gate, v004 is re-pinned with
  dividends refused and LDG-3087 is rerun.

### R3. The reconciliation oracle is chosen after the data is seen (Type 1, high)

"Within a tolerance this ticket states and justifies" and "events outside the
tolerance without an explanation keep the unit gate closed" let the tolerance
be fitted after the result. Neither phrase is failure-sensitive. Missing
pieces:

- F3 step 2's discriminating subset;
- a date-role check;
- a rule for when one event closes the gate for all events.

**Patch (LDG-3086 acceptance, before any full-build run):**

- "The tolerance is fixed in the build notes before the first full run:
  absolute error <= the error propagated from half-unit rounding of the four
  vendor prices (`close` and `closeadj`, prior session and vendor date), plus
  1e-6."
- "The unit basis is decided on events whose parent has `F = closeunadj/close
  != 1`. The census counts matches under `C` and under `C/F`. The gate opens
  only if at least 99% of decidable F != 1 events match the chosen hypothesis
  and at most 0.1% match the other."
- "The date role is checked. Events whose step falls on the adjacent session
  instead of the vendor date are counted, and they refuse."
- "Per-event outcomes are closed reasons: `matched`, `rounding_unresolvable`,
  `same_date_non_cash_action` (closeadj also adjusts spin-offs),
  `prior_bar_missing` (the adapter drops zero-volume bars),
  `adjacent_session_step`, `mismatch`."
- "A per-event failure refuses that event only. The global gate closes only
  on the basis rule above."

### R4. The fact identity and seal edges abort the whole build (Type 1, medium-high)

**Verified by execution** (`probe.R`):

- two incomplete same-parent, same-date rows without a `fact_id`, or with the
  same `fact_id`, raise `ledgr_fact_identity_conflict`;
- a Sunday ex-date raises `ledgr_fact_civil_date_unresolved` even on a
  `complete = FALSE` row, so one bad vendor date aborts the snapshot;
- a zero-row family raises `ledgr_fact_invalid_shape`.

By reading: a parent missing from the axis raises
`ledgr_fact_invalid_instrument` (F8). A fact_id built from the source row
number, or with the policy version as `source`, changes on every
re-acquisition or policy bump.

**Patch (LDG-3086 acceptance):**

- "`fact_id` = `div:<parent instrument_id>:<ex-date>:<ordinal by value
  within the same-date group>`. Two rebuilds, and a rebuild with permuted raw
  row order, give identical fact_ids. Any change of `source` is recorded as
  an intended identity change."
- "Each same-date row gets a distinct fact_id. The closeadj witness
  classifies each group as `sum_consistent`, `duplicate_consistent` or
  `neither`, as input for the maintainer under decision (7)."
- "Rows whose ex-date is not a declared XNYS open session, or lies outside
  [from, to], are counted and never entered with clocks."
- "Parents that are unmapped or off the axis are counted, never entered (F7,
  F8)."
- "The family is omitted when a window has no rows."
- "`DESCRIPTIONS.ACTIONTYPES` for `dividend` is validated against a pinned
  entry and fails closed on drift (equity-settlement spec Section 5; F3 step
  1). `spinoffdividend` is never a cash leg (F6)."

### R5. The estimator is underspecified where the real data breaks it (Type 1, medium-high)

All of the following were verified by execution (`probe.R`, `probe3.R`) on
the sim snapshot:

- **(a) Pairwise covariance can be indefinite.** `stats::cov(use =
  "pairwise.complete.obs")` on an 8-by-8 `na_action = "keep"` read gave a
  minimum eigenvalue of -8.4e-6. On Sharadar, N is about 500 and T is 252,
  so even the complete-case sample covariance is singular. The shrinkage
  intensity therefore decides whether the strategy ever trades, but no ticket
  fixes it.
- **(b) The alignment bridge forces a two-read order.**
  `ledgr_align_weights()` on a `keep` read requires one weight per requested
  instrument. A thresholded subset is refused with
  `ledgr_weight_alignment_mismatch`, and `keep` refuses any ID that also
  appears in `weights`, even at zero weight. The strategy must read closes,
  threshold, and then read `return_1` with `instruments = retained`. The
  working pattern ran end to end, including a two-worker DONE sweep.
- **(c) No minimum-observation rule.** The threshold sees only carried
  cells, not missing cells beyond the carry horizon or new listings, so it
  does not catch instruments with few valid returns.
- **(d) A kept holding without a permissible mark aborts.** This is
  `ledgr_target_sizing_unavailable`, an abort, by reading
  `R/strategy-helpers.R` :411-416. The hold-on-failure path does not cover
  it.
- **(e) The month start is undefined at the edges.** A month start detected
  from a lookback-2 read with `instruments = character()` works statelessly
  and is Tier 1 (fills followed every first session). The rule for the data
  start and the time zone is not stated.
- **(f) The article data is unnamed.** With a 252-session default lookback,
  the one-year causal-history sim yields at most one decision.

**Patch (LDG-3082 scope, append):**

- "Parameters: `lookback` (default 252), `threshold` (default 0.2), `shrink`
  (a fixed diagonal-shrinkage intensity in (0, 1], default stated), and
  `min_obs` (minimum valid returns per instrument, default stated). The read
  order is: a close read for carried shares; then a `return_1` read with
  `instruments` = admissible minus the threshold-excluded, `na_action =
  'keep'`; then instruments with fewer than `min_obs` valid returns are
  excluded by re-reading or by an explicit second selection. The solution is
  aligned against the final read only."
- "A month start is a session whose UTC civil month differs from that of the
  previous expected venue session. The data-start session counts as a month
  start. The strategy states that UTC is used because the close falls on the
  venue's civil date for this venue (G-018)."
- "If a kept instrument has no permissible mark, the strategy returns
  `ctx$hold()` for that decision and the article says so."
- "The article runs on `ledgr_sim_pit_inputs()` over at least three years, or
  shows a shorter lookback explicitly."

**LDG-3083 acceptance:** replace "no target change on any pulse that is not
a first session of a month" with "on the fixture, the decision pulses equal a
literal list of first sessions, including the data-start rule; every other
pulse returns `ctx$hold()`". Add "a block fails if a kept instrument without
a permissible mark aborts the run".

### R6. The WS50 memory budget has no comparator (Type 1, medium)

The "preregistered WS3 budget" is the decision-register E8 gate. E8 is
relative: within 10% of a paired pre-history baseline on the H1 workload,
for three metrics, median of three runs, a sampler of about 0.2 s. No
absolute number exists, and the estimator workload has no paired arm, because
the pre-history tree has no history API. "Representative parallel" is also
undefined; E7 claims one and two workers.

**Patch (LDG-3088 acceptance):**

- "Memory is measured as in LDG-3069: about 0.2 s sampler, median of three.
  The three E8 metrics are single-run parent private commit, two-worker
  parent private commit, and parent-plus-daemon private commit. The bound is
  1.10 against the LDG-3069 H6 candidate values (1,866.4, 2,292.1 and
  3,731.0 MiB), with the workload difference disclosed. A breach is
  corrected or accepted by the maintainer with a user-visible limit."
- "The parallel workload is two workers over a preregistered grid of four
  candidates (lookback {126, 252} x threshold {0.1, 0.2}). The candidate
  count is recorded because WS8 routes quadratic candidate assembly."

### R7. The private run can pass vacuously and drops an obligation (Type 1, medium)

**Patch (LDG-3088 acceptance):**

- "Decision dates are counted by outcome: solved, held for insufficient
  history, held for non-PD covariance, held for solver failure, held for no
  kept mark. Solved must be the large majority, or the maintainer decides."
- "The run crosses the supplied dividends under the research preset without
  becoming INCOMPLETE (macro DoD item 2)."
- "The headline states the posting clock: cash posts at the ex-date close
  (`effective_close`), and payment dates are absent."
- "The strategy is the article's strategy at a pinned ledgr commit. Its
  recorded strategy hash equals the article run's."
- The walk-forward sentence now retires the Cut 13 26-fold post-clock
  handover without an acceptance item. Either "the registered 26-fold shape
  is run and its clock recorded", or the maintainer retires it as a recorded
  decision.

### R8. LDG-3085 has an undecided format question and an ingest-path shape (Type 1, medium)

**Verified.** Corporate-action rows are written with knowledge `evidenced`
regardless of how knowledge arose (`R/availability-facts.R:671`; probe
output). `ledgr_fact_assumption_reasons()` covers four families only. A
filled time cannot be told apart from a supplied equal time after storage, so
an older store would keep misreporting assumed knowledge as evidenced. The
stored meaning changes, which is a stored-format question under AGENTS.md
(see Q4). A row fact_id without a supplied ID hashes `provenance_json`, so it
changes too.

**Patch (LDG-3085):**

- Cite register D1-F7 ("disclosed in results") as authority.
- Use the existing reason `knowledge_assume_effective`.
- "Compute the per-row knowledge label as one vector in the constructor; no
  new per-row pass on the ingest path (seven-shape walk recorded)."
- Acceptance: "the stored-format decision (Q4) is implemented. Changed golden
  roots, family hashes and fact_ids are listed with this reason."

### R9. Macro-plan edits belong at acceptance; LDG-3084 is misplaced (Type 1, medium)

The macro plan currently says "WS8 owns G-025". Its Remaining order still
calls the history wave current, which went stale at the Cut 16 close.
Decisions (5) and (8) change WS7 and WS8 scope, and macro_plan.md owns
release order. Those edits are maintainer amendments at cut acceptance, not
LDG-3084 work after LDG-3083. LDG-3084 also edits the Dividend facts route,
which WS49 and WS50 determine. And LDG-3088 depends on a document ticket.

**Patch:**

- At acceptance, amend macro_plan.md: Remaining order, Post-gate live routes
  (Dividend facts; G-025 per Q1), and H1 line 767.
- Move LDG-3084 to the last ticket with dependencies ["LDG-3088"] (cut-close
  record).
- Set LDG-3088 dependencies to ["LDG-3083", "LDG-3087"].

### R10. Claims, closeout and reservations (Type 1, low)

- **WS49 claim.** Append "or, where the witness cannot prove them, refuse
  with named reasons that public results count". Otherwise the gate-closed
  outcome cannot close WS49.
- **Closeout.** "each workstream that changes the ledgr package passes the
  quiet-host fast profile". WS50 changes none.
- **ID ranges.** Split per parallel workstream (Cut 16 sequencing rule):
  WS48 LCL-0421..0440 and LTB-0431..0450; WS49 LCL-0441..0460 and
  LTB-0451..0470.
- **LDG-3086.** Replace "an LTB-0411-style claim in ledgr-research" with "a
  failure-sensitive ledgr-research adapter test"; the LTB namespace belongs
  to the package.

### R11. Vendor vocabulary in out_of_scope (Type 1, low)

The canonical layer maps only `dividend` and `cashdividend` to
`cash_dividend` (`canonical-actions.R:125`). Unless the pinned dictionary
shows a separate special-dividend code, special dividends cannot be told
apart, so "mapping ... special dividends as cash" cannot be held out of
scope. Replace it with: "special dividends are not distinguished by the
vendor and map as `ordinary_cash_dividend`; the build notes state it." Add
"`spinoffdividend` is never a cash term".

### R12. Public proof details (Type 1, low)

LDG-3082 acceptance should add:

- "The article states the demo's dividend status, as G-016 requires of the
  public proof."
- "Tests and the article run without quadprog by skipping or conditional
  evaluation, or CI installs quadprog; R CMD check passes either way."

## Type 2 questions for the maintainer

These are challenges under decision (9). The reviewer does not rewrite the
decisions.

- **Q1, decision (8), G-025.** G-025 is "buy-and-hold equity reconciliation
  against a vendor total-return series, the only external check on
  corporate-action accounting". The per-event `closeadj` check tests the
  adapter's input amounts, not ledgr's entitlement, timing or posting.
  - Option A: rename the per-event check as the F3 unit/date witness in WS49,
    and keep G-025 as an end-to-end check. Run one buy-and-hold sample on
    the dividend build. Its posted cash is compared with `closeadj`-implied
    dividends times entitled quantity, in WS50 (cheap) or WS8.
  - Option B: accept the narrowing and record that ledgr's posting is
    checked only by synthetic tests.
  - Recommendation: A.
- **Q2, decision (1), the exclusion rule.** With `price_carry = 5L`, a
  carried run is at most five cells per gap. At lookback 252, a 0.2
  threshold needs at least 51 carried cells, that is 11 or more separate
  gaps in a year. The threshold will be nearly inert on S&P members, and
  item 18b's proof then rests on fixtures alone. Long halts and new listings
  are missing rather than carried, so the threshold misses them.
  - Option A: keep the carried-share threshold for 18b and add a
    minimum-valid-returns rule.
  - Option B: define exclusion on the share of non-valid return cells.
  - Either way, fix the shrinkage intensity, because N > T makes it
    load-bearing.
  - Recommendation: A.
- **Q3, decisions (7) and the gate fallback, LFB-014 semantics.** Should a
  held refused dividend make fidelity `unsupported` under research, and stop
  `INCOMPLETE` under strict? This is an execution-semantics change in both
  modes; decision 35's precedent says no mode branch. Without it, R1's
  counts are disclosure only. Recommendation: count under both presets, and
  stop under strict.
- **Q4, decision (6), stored format.** Labelling filled corporate-action
  knowledge `assumed` changes what stored provenance means.
  - Option A: add a format-fingerprint constant, so older stores refuse with
    `ledgr_store_rebuild_required`. The rebuild target then moves past
    schema 122.
  - Option B: record that older snapshots misreport and rely on pre-CRAN
    zero users.
  - Recommendation: A, per AGENTS.md.
- **Q5, default "the dividend unit basis is a gate".** Should one
  unexplained event close the gate for every dividend, or only refuse
  itself? R3 proposes a global basis rule plus per-event refusal. Under
  decision (7), the same `closeadj` witness can also settle sum versus
  duplicate for same-date rows instead of blanket refusal.

## Should-fix

- **Authority.** Add LFB-014, spec-review F2, register D1-F7 and
  decision-register E7 and E8.
- **Governance note, not a blocker.** `rfc_cycle.md` routes contract changes
  to a full RFC, and LDG-3085 (and R1, if added) changes a contract.
  Decision (9) waives the RFC explicitly. Record the waiver in the cut
  acceptance line.
- **LDG-3082 capability-gap note.** Record two expected gaps:
  - `ledgr_align_weights()` cannot align a subset of a `keep` read, so a
    second read is needed;
  - month-start detection needs a history read, because `ctx` has no
    previous-session field.
- **LDG-3087.** The schema number follows Q4.

## Antipattern walk

Planned package code adds no iteration over growing collections.

- **Per decision.** About 346 monthly decisions over 1998-2026. Each costs
  two windowed reads, O(L x N); one pairwise covariance in C, O(N^2 L); and
  one `solve.QP`, O(N^3) with N about 500. All are bounded by the finite
  lookback.
- **Per non-decision pulse.** One lookback-2 read with no instruments. Its
  selection table is O(N) per pulse and does not grow with bars.
- **LDG-3085.** It touches `ledgr_fact_provenance()` and the fact-ID path,
  which are already per-row shapes routed to F05. It must not add a second
  per-row pass (R8).
- **WS50 sweep.** The grid size meets the WS8-routed quadratic
  candidate-assembly shape. Keep it small and record it (R6).
- **Research adapter code.** It is outside the package style rule. The
  witness should still be one set-based query, not a per-event R loop.

## Input and clean checks

- `tickets.yml` parses. There are 166 unique ticket IDs, all dependencies
  resolve, workstream IDs are unique, and `git diff --check` is clean.
- LCL-0421..0460 and LTB-0431..0470 are free in `tests/claims.yml`; the
  highest IDs in use are LCL-0408 and LTB-0418.
- WS50 `depends_on_workstream: 49`, with prose for 48, matches the WS44
  precedent and is acceptable.
- Source-table code facts confirmed:
  - `carried_input_share` is 0 on a `return_1` read and 0.2 on the close read
    of the same window (executed);
  - the share is computed in `ledgr_history_estimator_admission()` over all
    window columns;
  - corporate-action provenance always reads `evidenced` (executed);
  - `ledgr_fact_assumption_reasons()` covers four families;
  - `keep` semantics, and the refusal when an ID is in both `keep` and
    `weights` (executed);
  - `ledgr_history_matrix()` accepts NA cells from `keep` (executed);
  - quadprog is Tier 2, with `require_namespace = quadprog` passed to workers;
    a two-worker sweep ran DONE on four candidates (executed);
  - DESCRIPTION has no quadprog.

Executed probes (scratchpad `cut17_review/`): `probe.R`, `probe2.R`,
`probe3.R`, `yamlcheck.R`. Read only: G-rows, E7/E8, the research adapter and
canonical layer, spec-review F2-F8, the equity-settlement spec, H006, and the
settlement entitlement binding (`R/corporate-action-settlement.R:36-48`;
binding the position before ex-date fills matches probe D). No vendor row was
inspected. A Type 1 focused re-review is required after the patches and the
maintainer's answers to Q1-Q5.
