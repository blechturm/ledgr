# Maintainer Decisions: Strategy Scheduling And Held-Pulse Skipping

**Status:** Accepted 2026-10-25.
**Stage:** RFC cycle stage 6.
**Authority:** Maintainer decisions resolving seed v2 Section 11.

## D1. Partial First Period

**Decision:** Option A. A run or fold that begins inside an already-started
period waits for the next genuine declared boundary. Its first executable
pulse is not promoted into an artificial period start.

Opening allocation remains an opening-policy concern. A carry-forward fold
continues the parent schedule rather than rebalancing merely because a new
window began. Performance comparisons start at a true boundary or at the
first boundary shared by both arms.

This also means that a parent session axis whose first session has no
predecessor cannot prove that session is a period start. The conservative
verdict is not due. A declared opening or explicit-date schedule remains
available when immediate initialization is intended.

## D2. Zero Decision Pulses

**Decision:** Option A. Refuse before executing a run only when its resolved
schedule contains no decision pulse and it has neither opening nor carried
positions. Such a run cannot trade and is treated as a schedule/window
misconfiguration.

A run or fold with opening or carried positions remains valid when its window
contains no decision pulse. It continues observation, settlement, valuation,
accounting and persistence, holds the positions, and discloses zero decision
pulses in run information.

An unconditional zero-decision refusal is rejected because it would abort
legitimate carry-forward walk-forward folds.

## Next Stage

Decision synthesis by Codex, followed by an independent Type 1 final review.
