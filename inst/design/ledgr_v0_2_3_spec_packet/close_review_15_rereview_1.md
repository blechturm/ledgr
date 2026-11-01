# Workstream 15 Type 1 focused re-review 1

Reviewer: independent clean-context Claude Opus, 2026-11-01.
Range: corrections `29188f87..3a6dc7de` on `codex/cut7-ws5`, read against
the original implementation `cb332627..29188f87` and
[close_review_15.md](close_review_15.md).
Tickets: LDG-3179, LDG-3180, LDG-3181.

## Verdict

**CHANGES_REQUIRED.**

F2, F3, F5, F6 and F8 are resolved. F1 is resolved for durable resume, but
the same defect class remains in a longer walk-forward carry chain. F4, F9
and F10 are partially resolved, and F7 remains open. None of the remaining
work needs a design change; it stays inside accepted D1/D2 and Cut 7 decision
(7).

Method limit: this restricted review could read source but could not execute
R. The reported fast, focused, inventory, YAML and census gates were not
rerun. Findings below are static traces and must receive executable witnesses
in the correction.

## Original-finding dispositions

- **F1: resolved for durable resume.** The runner seeds replay from carried
  facts, and ordinary supplied openings remain unknown. N1 covers the second
  walk-forward replay caller.
- **F2: resolved.** Pulse inspection masks an unknown supplied basis and has
  a detector.
- **F3: resolved.** Fact columns build on first read inside the lazy field.
- **F4: partially resolved.** Retired closures and per-pulse name matching are
  gone and live off-axis labels refuse. N2, N3 and N6 remain.
- **F5: resolved.** Contracts, help and README.Rmd use the flat surface.
- **F6: resolved in the record.** The cited identity detectors do not exist;
  N4 owns that evidence gap.
- **F7: unresolved.** See N4.
- **F8: resolved.** Concrete mapped IDs are checked against reserved fields.
- **F9: partially resolved.** The declared-state adapter exists, but the
  attribution base is wrong (N5).
- **F10: partially resolved.** LTB-0167 is restored; LTB-0304 routing
  overstates what remains (N7).

## Findings

### N1 (High): a third carried window loses known position facts

`R/walk-forward.R` rebuilds the next window's facts from only the current
window ledger. It does not seed replay from that window's carried opening.
Because opening rows are correctly not transitions, a position carried into
window 2 and left untouched becomes unknown in window 3.

Fix: pass the current carried facts as `initial_state` to this replay and add
a registered three-window `ledgr_walk_forward()` witness for entry and exit
anchors and ages.

### N2 (Medium): preparation counters are constants

`R/fold-engine.R` initializes the service, resolver and fill-axis-map counters
to literal `1L`; no preparation function increments them. The test therefore
passes even if preparation is moved back into a loop.

Fix: increment counters at the actual preparation sites and assert them over
a multi-pulse run and two-candidate sweep. Add a repeated-read witness or
narrow the name-matching claim.

### N3 (Medium): fill batches still perform full-axis named lookup

`ledgr_position_fact_bar_index()` indexes a named vector containing the whole
axis for every fill batch. This remains O(fill batches x axis length).
`ledgr_position_fact_axis_map()` also uses `vapply(split())` over every
execution opportunity.

Fix: prepare an integer fill-bar-by-pulse vector once per candidate and read
it by pulse index, retaining an exact timestamp check. Replace the split loop
with a vectorized duplicate/conflict check.

### N4 (Medium): evidence claims tests that are absent or vacuous

The flat-context test still lacks changing-universe, holdings-only,
shared-buffer and candidate-leak fixtures. Its frozen-view mutation changes a
caller-owned copy rather than a buffer the fold reuses. Position-fact coverage
still lacks zero-fill disposition, split/recipient changes, a real same-bar
double transition, a skipped decision bar and live/rebuild equality across
non-fill boundaries. Replay fixtures contain no relevant non-fill event, so
fills-only and disposition-as-fill mutations cannot fail. Mutation commands
only run unmodified tests, and expected-difference hash rows point to no hash
assertion.

Fix: add real fixtures and mutations, including a shared fold buffer,
two-candidate isolation, plain/uncarried/carried hash checks and non-fill
replay cases. Correct evidence text until every claim has a detector.

### N5 (Medium): the named attribution base is wrong

The timing protocol names `cb332627` as the post-WS4a attribution base, but
`14252ffb..cb332627` contains no product-code change. The WS4b final record
identifies `b5622f09` as the measured post-WS4a base.

Fix: name and pin `b5622f09` before taking records.

### N6 (Low): replay maps a pre-axis time to bar one

The replay interval map fails to reject a timestamp earlier than the first
bar. The source check also counts a missing `findInterval` call as one match
because `gregexpr()` returns `-1`.

Fix: reject pre-axis times with `ledgr_position_fact_off_axis`, preferably
check against prepared execution opportunities, and count only positive
source matches.

### N7 (Low): LTB-0304 routing overstates retained parity

Five-entry-point mark value parity remains through `holding_value`, but mark
age/source remain asserted only for the promoted run. The matrix says the
assertions were moved rather than narrowed.

Fix: add public availability-result assertions for the persisted runs or
state the narrower, accurate ownership.

## Clean areas

- No compatibility path or WS16+ surface was added.
- Pulse inspection, lazy fields, mapped-ID collision refusal and flat
  contract spellings are corrected.
- Off-axis carried labels refuse; maintained dense and long-window consumers
  are migrated.
- The wider walk-forward boundary timestamp maps consistently to the next
  session close on the shared axis.

## Review accounting

This is the second findings-bearing review of WS15. One further correction
and focused confirmation is permitted. A further findings-bearing correction
round after that stops for maintainer disposition.
