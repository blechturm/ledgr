# Workstream 15 Type 1 focused re-review 2

Reviewer: independent clean-context Claude Opus, 2026-11-02.
Range: second corrections `3a6dc7de..5471d835` on `codex/cut7-ws5`, read
against the original implementation, the first correction, and
[close_review_15_rereview_1.md](close_review_15_rereview_1.md).
Tickets: LDG-3179, LDG-3180, LDG-3181.

## Verdict

**CHANGES_REQUIRED.**

The second correction resolves the structural and detector findings from the
previous review, but one high correctness defect remains in the position-fact
carry path. The registered LTB-0304 wording also remains broader than its
actual mark-age/source assertions. Neither issue changes D1/D2, adds a schema
or persistence mechanism, or needs Type 2 disposition.

## High finding

### H1 (High): carried RFC 3339 labels lose their non-midnight clock time

`ledgr_position_facts_carried()` writes `entry_at` and `exit_at` as exact UTC
labels such as `2020-01-07T21:00:00Z`. The inverse path in
`ledgr_position_facts_from_carried()` passes those character labels to
`ledgr_position_fact_bar_index()`, whose unformatted `as.POSIXct()` parse can
retain only the date. A midnight-only fixture masks the defect. On a shared
axis whose sessions are at 21:00 UTC, the next carried window therefore looks
for midnight and refuses with `ledgr_position_fact_off_axis`; entry/exit facts
and ages cannot survive the three-window chain.

Required correction: parse both carried label vectors with the existing exact
UTC parser `ledgr_history_utc_many()` before the bar-axis lookup, and change
the public three-window `carry_test_state` witness to a non-midnight axis that
asserts both anchors and both ages in windows two and three.

## Prior N1--N7 dispositions

- **N1: implementation corrected, but H1 blocks full confirmation.** The
  current carried facts now seed the next replay, so an untouched window no
  longer discards provenance. The remaining failure is the inverse timestamp
  parse, not another replay engine or missing seed.
- **N2: resolved.** Service, resolver and fill-axis preparation counters are
  incremented at their actual preparation sites and observed over a
  multi-pulse run and two-candidate sweep; repeated reads remain cached.
- **N3: resolved.** Candidate preparation now supplies an integer fill bar by
  pulse and vectorized duplicate/conflict checks; the per-fill full-axis named
  lookup is gone while exact timestamp refusal remains.
- **N4: resolved for the bounded WS15 claims.** The correction adds the
  changing-universe, holdings-only, shared-buffer, candidate-isolation, hash,
  same-bar, skipped-decision, non-fill and live/rebuild fixtures. The existing
  isolated-copy runner detects all twelve D1/D2 source mutations. No generic
  detector or validator is necessary.
- **N5: resolved.** The timing record names `b5622f09` as the post-WS4a
  attribution base.
- **N6: resolved.** Pre-axis replay timestamps refuse, and the source census
  counts only positive `gregexpr()` matches.
- **N7: behavior is retained; evidence wording still needs correction.**
  LTB-0304 proves mark values through the exercised scoring paths, while mark
  age/source are asserted only on the promoted availability result. The claim,
  test title and implementation matrix must say exactly that; adding another
  result route is not necessary for this correction.

## Checks and limits

- Static review traced the carried serialization and inverse parse through
  `R/position-facts.R`, both walk-forward replay callers and the registered
  three-window test.
- A public 21:00 UTC `ledgr_walk_forward()` / `carry_test_state` reproduction
  on the reviewed product fails at the inverse parse with
  `ledgr_position_fact_off_axis`; this is the H1 witness required above.
- The reviewed candidate records all twelve isolated source mutations as
  detected, ordinary fast as 633/633, and passing focused, inventory, YAML and
  codebase/diff checks. Those results do not cover H1 because the registered
  chain used midnight sessions.
- Integrated Cut 7 timing remains descriptive milestone evidence, not a WS15
  correctness gate.

## Correction authority

This is the final findings-bearing focused review of WS15. On 2026-11-02 the
maintainer explicitly authorized one third and final bounded correction,
limited to H1, the N7 wording, exact evidence updates and the existing gates.
That authorization does not open a new review, WS16 work, a design change, a
schema change or a new orchestration layer. LDG-3179--LDG-3181 remain pending
until maintainer acceptance.
