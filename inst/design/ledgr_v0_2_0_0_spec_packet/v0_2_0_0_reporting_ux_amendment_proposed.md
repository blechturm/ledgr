# Proposed amendment: honest reporting defaults

**Target:** accepted ledgr v0.2.0.0 spec.
**Status:** Accepted by the maintainer 2026-09-13. Cut as LDG-2712 through LDG-2715 in Batch 14.
**Date:** 2026-09-13.
**Baseline:** [c50e5eb](https://github.com/blechturm/ledgr/commit/c50e5eb2a0b2ce4fa10a0d357662cf752924747e), the reviewed closure of Batch 13 and LDG-2711.
**Related:** the [inspectable availability workflow amendment v2](v0_2_0_0_workflow_amendment_proposed_v2.md), whose surfaces this amendment corrects rather than reopens.

The maintainer read the rendered Survivorship Bias article and rejected the
reporting UX. The complaint is specific and fair: the article repeatedly
defines helper functions and reshapes data to display what the package should
present by default. Four blocks were cited - a session-inspection wrapper, a
history table reduced by `select()`, a four-scenario membership counterfactual,
and a hand-built common-window and horizon comparison.

Two adversarial reviews and executed probes established that these blocks are
not one problem. They are an objectively poor default print, a missing
completion projection on the existing multi-run inventory, and article-specific
analysis that does not justify generic APIs. A fourth candidate correction was
proposed twice and rejected twice on executed evidence; this amendment records
that rejection as a binding decision so it is not re-proposed.

Nothing here reopens Batches 11 to 13, or their acceptance records. The batch
proposed here depends on LDG-2711's reviewed closure, which is this document's
baseline.

## 1. Release outcome

Add this outcome to the packet:

> A user reading default ledgr output can see which runs are comparable and
> which are not, and can read point-in-time evidence without reshaping it.

## 2. Curated fact inspection printing

`print.ledgr_facts_history()` and `print.ledgr_facts_resolution()` currently
print every column of `$rows`. For membership that is ten columns, so console
truncation hides `knowledge_time` and `complete` - the two columns the
point-in-time model exists to express - behind `evidence_id`, a long opaque
evidence identifier of no interpretive value at a glance.

Bind a curated print selected by **family and operation**:

- Membership history shows `evidence_type`, `instrument_id`, `member`,
  `effective_from`, `knowledge_time`, `complete`. `evidence_type` is required,
  not optional: without it a set-header row reads as an unexplained `NA`
  member.
- Membership resolution shows `instrument_id`, `member`, `reason`, and the
  cutoff already carried in metadata.
- Session history shows `session_date`, `status`, `session_open`,
  `session_close`, `knowledge_time`. Knowledge time is shown because causal
  availability is the point of the family, not an advanced detail.
- Session resolution shows `session_date`, `status`, `session_open`,
  `session_close`, `reason`. `reason` is required: resolution rows carry no
  `knowledge_time` column, so without it an `NA` status cannot distinguish
  `missing_coverage` from evidence that is not yet knowable at the cutoff.
  Resolution also shows a `knowledge_time` derived solely from the applicable
  supporting `$evidence`, typed missing when no applicable evidence exists.
  Excluded future evidence is never inspected to populate it.

`$rows` and `$evidence` remain complete and byte-identical. Printing is a
presentation boundary; it never filters what programmatic callers receive. A
curated print must disclose any columns it omits and the full row count.

## 3. Completion-aware run inventory

`ledgr_run_list()` lists every run status and prints `total_return` beside
`final_equity` with no completion qualification. On the article's own two runs
the default print is:

```text
1 pit    INCOMPLETE   8290   -17.1%
2 sur    DONE        11440   +14.4%
```

Two returns are presented as peers. Nothing says the first covers three fewer
sessions. This is the reporting-honesty defect behind the rejected UX, and it
is worse than a refusal because it is the default listing, reached with no
guard and no error.

Project the recorded completion evidence already available to
`ledgr_run_info()` onto the inventory, binding this result shape:

- **Append** these eleven fields, in this order, after the existing columns:
  `completion_evidence_available`, `completion_status`, `requested_start_utc`,
  `requested_end_utc`, `achieved_start_utc`, `achieved_end_utc`, `stop_reason`,
  `last_fully_valued_ts_utc`, `last_executed_ts_utc`, `complete_performance`,
  `affected_instrument_ids`. Do not insert them among existing columns.
- Project recorded completion evidence **whenever it exists, including for
  `FAILED` runs**. A finalization failure can leave a valid `run_completion`
  row while the run status is `FAILED`, and that evidence is real. Status does
  not gate the projection.
- Use typed `NA` only when completion evidence is genuinely absent, as for
  dense and historical runs. Absence stays unknown; it is never inferred.
- Keep timestamps as `POSIXct`.
- Represent `affected_instrument_ids` as one list-column element per run, with
  three distinguishable states: `list(NA_character_)` when evidence is
  unavailable, `list(character())` when evidence exists and no instrument is
  affected, and `list(c("AAA", ...))` for a known affected set.
- Retain the raw prefix metrics unchanged, and place `complete_performance`
  and the achieved end beside them in the curated print.
- State explicitly, in the print and the help, that an `INCOMPLETE` row's
  metrics describe only its achieved prefix.

Implement the projection at `ledgr_run_list()`. Do not widen the shared
low-level fetch unless another caller needs it.

## 4. Forbidden behaviour: comparing incomplete runs

`ledgr_run_compare()` has two selection modes, and both are bound here as
forbidden behaviour rather than implementation detail:

- With explicit `run_ids`, a run whose status is not `DONE` raises
  `ledgr_run_not_complete`. Asking for a named incomplete run is an error, not
  a silent omission.
- Without `run_ids`, non-`DONE` rows are excluded from the selection rather
  than raising. Surveying a store must not fail because it contains an
  incomplete run.

Both rules require their own test. Neither may be relaxed.

The function returns metrics intended for ranking and filtering. An incomplete
horizon does not merely qualify those metrics; it changes what return, Sharpe
and drawdown *mean*, because the denominators differ. `fill_timing_comparable`
is not a precedent for loosening it: that flag qualifies a fill-equivalence
claim under a shared horizon, whereas truncation changes the measurement
itself.

Incomplete runs remain fully inspectable through `ledgr_run_info()` and the
completion-aware inventory in Section 3. That is the supported way to see two
runs of different horizons side by side, with the difference visible.

## 5. Rejected: a common-endpoint return helper

A narrow "return at the last session both runs valued" helper was proposed as a
smaller alternative to general common-window comparison. It is **rejected**, and
recorded here so it is not re-proposed without addressing the following.

Its premise was that runs on one snapshot share a pulse prefix and can be
rebased on recorded `initial_cash`. Both halves are false:

- `ledgr_opening(cash, date = ...)` moves a run's start inside the same
  snapshot, and walk-forward stores internally windowed test runs in the same
  store. Stored pairs can therefore be shifted, partially overlapping, or
  disjoint, and an `INCOMPLETE` availability run may have zero equity rows.
- Rebasing on `initial_cash` is wrong whenever opening positions exist. An
  executed probe with `cash = 1000` and one opening unit recorded first equity
  of 1101 and final equity of 1106: rebasing on cash reports +10.60% where the
  portfolio actually returned +0.45%.

Any future common-window surface must define common start as well as end,
exact timestamp intersection, empty overlap, zero-row runs, and the
portfolio-value denominator. That is general common-window comparison, not a
separable shortcut, and it is a named follow-up rather than release work.

## 6. Article corrections

Rewrite the Survivorship Bias article against the surfaces above.

- Remove the `inspect_session()` wrapper and its output block. Teach the
  difference between an open-session feed outage and a closed date from the
  already printed calendar and observation tables. A future snapshot-coverage
  accessor may restore an executable joined view; until then the distinction is
  taught, not computed by a user-defined helper.
- Remove the hand-built common-window calculation and the hand-built
  `run_horizons` table. The horizon comparison comes from the completion-aware
  inventory.
- Retain the four-scenario membership counterfactual, visibly labelled as
  article-specific analysis, with its mechanical fixture construction folded.
  It varies the evidence itself by rewriting `knowledge_time`, which is
  sensitivity analysis over alternative facts rather than ordinary resolution.
  No API should make re-authoring vendor knowledge timestamps ergonomic. It
  must not read as part of the canonical ingestion-to-run path.
- No user-defined reporting wrapper remains in the canonical workflow.

## 7. Named follow-ups, with direction bound where decided

These are deferred, not open questions. Each carries its decided direction so a
later cycle does not re-derive it.

**Vectorized fixed-evidence resolution.** `ledgr_facts_resolve()` accepts one
cutoff, so resolving membership at each decision pulse is one call per pulse.
Independent probes by two reviewers established the direction: against a sealed
snapshot the loop is an order of magnitude slower than the same loop over
in-memory facts, and repeated snapshot hash recomputation is a substantial
share of it. The ratio is fixture-sensitive, compressing materially when more
fact families are present, so no constant is recorded here. The ticket must
reproduce the measurement and record it with its fixture, operating system, R
version, dependency versions, and probe artifact.

Direction is bound: **batch cutoffs within one call; never cache verification
across calls.** A batched call may verify the sealed snapshot once, load
canonical evidence once, and resolve every requested cutoff. Every later public
call verifies again, preserving tamper detection at the call boundary.

**General common-window comparison.** Deferred with the requirements in
Section 5, including trade truncation and metric recomputation over a truncated
series.

**Snapshot coverage accessor.** Observation counts beside declared sessions
belong in their own cross-plane accessor. They must not enter
`ledgr_facts_resolve()`, whose facts and snapshot inputs resolve to identical
rows today under test; making one input's schema depend on evidence provenance
would break that neutrality.

## 8. Scope, sequencing, and acceptance

Insert a separately reviewed batch before the release gate. Batches 11-13 are
not reopened. The release gate moves to the following batch number.

| Work | Detecting acceptance evidence |
| --- | --- |
| Curated fact printing | Membership history print shows `knowledge_time` and `complete` without truncation and retains `evidence_type`; session history print shows `knowledge_time` from its own rows; session resolution print shows `reason` and a `knowledge_time` derived only from applicable supporting evidence, typed missing when none applies; `$rows` and `$evidence` unchanged for every family and operation; omitted columns and full row count disclosed. |
| Completion-aware inventory | `DONE`, `INCOMPLETE`, dense-without-completion, `FAILED`, and legacy rows produce one stable schema with the eleven fields appended in the bound order; a finalization-failed run that retains a `run_completion` row reports that evidence, and inventory and `ledgr_run_info()` agree on it; absence is typed unknown; `affected_instrument_ids` distinguishes unavailable, empty, and known sets; the print marks an incomplete row's metrics as prefix-only; reopen parity holds; no strategy executes and no stored row changes. |
| Comparison prohibition | Naming a non-`DONE` run explicitly raises `ledgr_run_not_complete`; omitting `run_ids` excludes non-`DONE` rows without raising; both modes are tested, and both runs still appear in the inventory with their horizon difference visible. |
| Article | No user-defined reporting wrapper in the canonical path; the outage/closed distinction is still taught; the counterfactual block is labelled article-specific and folded; rendered output regenerates from current execution. |

Packet-open gate: the run-inventory result shape in Section 3 is approved
before implementation begins, because it changes a public returned tibble and
its default print.

Release gate: no canonical workflow in shipped documentation defines a helper
to display recorded evidence; `ledgr_run_compare()` never returns a non-`DONE`
row, rejecting it when named explicitly and excluding it when `run_ids` is
omitted; deferred items in Section 7 are recorded with their bound directions.

This amendment adds no execution engine, schema change, persistence identity
change, strategy-context change, provider registry, or query abstraction. It
changes presentation defaults, projects evidence already recorded, and binds one
prohibition.

## Source basis

- Maintainer UX rejection of the rendered Survivorship Bias article, 2026-09-13.
- Two adversarial peer reviews of proposals A-E and of the revised plan,
  including executed probes for the run inventory print, the opening-position
  rebasing counterexample, the shifted-start counterexample, and the resolution
  cost measurements.
- `inst/design/contracts.md`, Result Contract.
- `inst/design/rfc_cycle.md`, amendment discipline of 2026-06-04: an amendment
  must bind a substantive default, operational contract, or forbidden-list, or
  name a ticket-cut gate matrix. This document binds all three.
