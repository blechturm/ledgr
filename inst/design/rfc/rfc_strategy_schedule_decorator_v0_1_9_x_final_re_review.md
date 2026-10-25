# Focused Final Re-Review: Strategy Scheduling And Held-Pulse Skipping

**Verdict:** `PASS`.
**Mode:** Focused Type 1 confirmation.
**Date:** 2026-10-26.
**Scope:** the four literal corrections required by
`rfc_strategy_schedule_decorator_v0_1_9_x_final_review.md`, plus the synthesis
review-state metadata and the scheduler row in `README.md`.

All four `PASS_AFTER_PATCHES` findings are corrected exactly. The patches do
not reopen design or alter another synthesis decision.

## 1. Confirmation

### F1 - PASS

Synthesis D2 now defines the parent axis as snapshot session rows with
`status == "open"`, ordered by `session_close`, and defines predecessor and
successor as adjacent rows on that ordered open-session axis. D3 binds Monday
weeks with the locale-independent formula
`(as.integer(session_date) - 4) %/% 7`. D4 asserts one executable pulse per
declared open session. These are the exact requested corrections.

### F2 - PASS

Section 5 now contains failure-sensitive gates for:

- refusal of a flat zero-decision run and successful P1/P4/P5 processing of
  zero-decision runs with opening or carried positions;
- explicit-date snap-forward, duplicate snapped-session collapse, and refusal
  on both sides of the bounded parent-axis range;
- absent, unknown and non-scalar schedule parameters, plus distinct verdicts
  and identities for two valid grid values;
- persisted decision and skip counts, including interruption/resume and zero;
- trusted recovery reattaching the declaration and a parallel worker retaining
  and compiling it; and
- refusal of every superseded version named by F3.

The first gate is narrowed to public strategy-visible history-helper
installation or calls and expressly permits the P1 history-reader work bound
by D6.

### F3 - PASS

Section 4 binds these exact current-only format changes:

- saved sweep schema 5 to 6;
- sweep provenance `ledgr_provenance_v1` to `ledgr_provenance_v2`;
- candidate reproduction key `ledgr_candidate_reproduction_key_v1` to
  `ledgr_candidate_reproduction_key_v2`;
- walk-forward candidate schema and corresponding inspection provenance `v1`
  to `v2`; and
- promotion context `ledgr_promotion_v2` to `ledgr_promotion_v3`.

It also requires old values to refuse and forbids compatibility readers and
missing-schedule fallbacks. Section 7 leaves only exact field placement to the
spec cut; it does not reopen the fixed bumps.

### F4 - PASS

Section 4 now makes the decorator the taught scheduling idiom, binds
replacement of hand-written guards in affected executable articles, documents
schedule identity/provenance/counts, updates the reference index and `NEWS`,
and requires changed vignettes to render. Section 7 leaves individual article
ownership to the spec cut without making the documentation surface optional.

## 2. Review State And Containment

The synthesis status, Section 10 and revision history accurately record
`PASS_AFTER_PATCHES`, the four applied corrections and this focused
confirmation as the next stage. The scheduler row in `rfc/README.md` likewise
records `Focused confirmation due`, links the final review first and describes
the four corrections accurately. Those pre-confirmation states are ready for
the primary agent to advance after this `PASS`.

D1 and D5-D13 are unchanged. Within D2-D4, Sections 4, 5 and 7, the only
changes are the requested corrections. No unrelated synthesis choice, future
obligation, acceptance route or LFB-035 boundary changed.

The synthesis and changed scheduler row use ASCII text and LF endings. The
README contains pre-existing non-ASCII bytes elsewhere, outside the changed
row. Worktree-wide `git diff --check` passes. No test or probe was needed for
this literal document confirmation.

## 3. Result And Change Record

The focused result is `PASS`. The synthesis is ready for maintainer acceptance
and the acceptance/routing steps already named in its Section 9.

This confirmation created exactly one file:
`inst/design/rfc/rfc_strategy_schedule_decorator_v0_1_9_x_final_re_review.md`.
It edited no synthesis, RFC index, code, contract, ticket, macro-plan, horizon
or roadmap file.
