# ledgr Horizon

**Status:** Active parking lot.
**Authority:** Non-binding design memory.

This file holds design observations that are not ready for the roadmap, an ADR,
or a versioned spec packet. It is not a backlog and does not imply commitment.

Use lightweight entries only:

```text
### YYYY-MM-DD [area] Short title

Freeform note.
```

Area tags:

```text
execution, ux, data, risk, cost, research, infrastructure, adapters
```

Do not add owners, due dates, priorities, acceptance criteria, or ticket
statuses. If an item becomes planned work, promote it into the roadmap, an RFC,
an architecture note, or a spec packet.

## Open

### 2026-05-13 [data] Data input and snapshot creation article

The experiment-store article currently carries some advanced low-level CSV
snapshot material. A future documentation pass may split this into a focused
"Data Input And Snapshot Creation" article so the experiment-store article can
stay centered on run management, labels, tags, comparisons, recovery, and
reopening.

### 2026-05-13 [execution] Compact execution semantics article

Several public articles explain next-open fills, targets-as-holdings,
decision-time close sizing, final-bar no-fill warnings, and open-position
handling. Consider a short consolidated article once sweep design stabilizes,
so users have one compact reference for decisions, targets, fills, and
last-bar behavior.

### 2026-05-13 [ux] Future tune-wrapper naming

After `ledgr_sweep()` exists and the fold core is stable, revisit whether a
convenience wrapper such as `ledgr_tune()` is useful. This should remain parked
until sweep result shape, objective/ranking ownership, and candidate promotion
are stable.

## Resolved

No resolved horizon entries yet.
