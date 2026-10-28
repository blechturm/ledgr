# Strategy grammar stage 5: view-based flat context

**DRAFT brief written by Claude, 2026-10-28. Provisional until the maintainer
accepts or edits it.** Spike under `inst/design/spike_protocol.md`.

## 1. Why

Stage 4 (`a38a24e0`, `ee1028af`) showed that a flat `ctx` reads better and
keeps fills, but stopped at its timing gate: Turtle ran +5.51% slower
against a 5% limit. The prototype was an adapter: it built today's `ctx`,
copied it into an environment and installed one binding per feature on
every decision pulse. The gate measured that adapter, not the design.

The history panels already use the right architecture: prepare a read
service once per run, attach a small view per pulse
(`R/history-frame.R:484`, `ledgr_history_view()`), and build only what the
strategy reads (`R/history-substrate.R:372`).

Maintainer decisions since stage 4 (2026-10-28):
- ledgr provides per-asset position facts `entry_price` (average cost),
  `entry_at`, `exit_at`, `bars_since_entry` and `bars_since_exit`;
- bar counts count the run's calendar bars, never calendar units, because
  intraday support is planned;
- `peak_since_entry` is not provided; a trailing stop keeps its peak in
  strategy state;
- `adjust(weights =)` defaults to total equity, disclosed;
  `capital_base = "remaining_equity"` is the override.

## 2. Question

Does a view-based flat `ctx`, carrying the agreed position facts, stay
within 5% of the current `ctx` end to end on every stage 4 workload?

## 3. Inputs

- Spike branch `spike/strategy-grammar` at `ee1028af`, worktree
  `C:/Users/maxth/ledgr-wt/strategy-grammar`. Do not touch the uncommitted
  `dev/spikes/strategy-grammar/rfc_response/`.
- Stage 4: `dev/spikes/strategy-grammar/stage4/` (closeout, optimization
  notes, `time.R`, `check.R`, `run.R`, evidence, profiles).
- The history pattern: `R/history-substrate.R`, `R/history-frame.R`.
- Current context construction: `R/pulse-context.R`; fold position and lot
  state: `R/fold-engine.R` (cost basis near line 581).

## 4. What to build (prototype only, not product)

1. **The view.** Prepare once per run: the per-asset column sources, the
   feature-name lookup (reusing the feature-map alias resolution) and the
   pulse indices. Per decision pulse, `ctx` is a small classed object
   holding a reference to that service, its pulse index and the values of
   the mutable fold vectors it exposes (positions, entry and exit bars,
   cost basis). A shared `$` method serves `ctx$close`, `ctx$average` and
   the rest on read.
2. **View rules.**
   - Reading the same field twice in one pulse builds it once.
   - A view kept from an earlier pulse returns that pulse's values,
     including positions and position facts, never later ones.
   - `names(ctx)` and `str(ctx)` list the available columns.
   - Reserved names, unknown-field errors and the fail-closed rules from
     stage 4 are unchanged.
3. **Position facts.** Track an entry bar and an exit bar per asset as two
   integer vectors, written only when a fill opens a position from flat or
   closes it to zero. Derive `bars_since_entry`, `bars_since_exit`,
   `entry_at` and `exit_at` from them on read, and `entry_price` as cost
   basis over quantity. `NA` where the fact does not exist (never held,
   never exited). Remove `peak_since_entry` and `days_since_exit`.
4. **Rebuild check.** Show by execution that a single pass over a run's
   fills rebuilds both bar vectors exactly at an arbitrary pulse. This is
   the basis for resume, sweeps and walk-forward; full resume plumbing is
   out of scope.
5. **Readability fixes for cold read v3.**
   - `NA` in a candidate buy set means "do not buy"; `NA` in a sell,
     `exit` or `keep` set stays an error.
   - A single-asset universe needs no `[["SPY"]]` and no `isTRUE()`.
   - `keep` accepts asset IDs (`keep = "GLD"`) as well as a logical mask.
   - `partial = "allow"` becomes the selection default.
   - The trailing stop keeps its peak in one strategy-state field and uses
     `bars_since_exit` for the cooldown.

## 5. Deliverables

Under `dev/spikes/strategy-grammar/stage5/`:

- the six strategies against the view-based `ctx`;
- fill comparison with the stage 4 checker against the stage 4 baselines.
  The trailing stop should now match its baseline exactly; any
  difference must be named and shown;
- a gut demonstration: a stale view leaking a later pulse's position, a
  wrong entry bar, and a reserved name each make the checker or the run
  fail;
- the stage 4 timing run, with only the context mode changed: the same
  four workloads, threshold, host rules (High performance plan, P-core
  affinity, alternating pairs) and pair count;
- if any workload misses the gate, a profile attributing the overhead, and
  then stop: no optimization round inside this stage;
- `cold_read_v3.md`: the six strategies only, in the cold-read format;
- a one-page closeout: answer, timing table, fact definitions, rebuild
  result, open points.

Commit on `spike/strategy-grammar` with `git commit --only <paths>`. Do not
merge, do not push.

## 6. Kill conditions and budgets

Stop and report if:
- any workload is more than 5% slower end to end than the current `ctx`;
- a strategy's fills differ from its baseline for an unnamed reason;
- a position fact needs future data or a per-instrument R loop;
- a kept view can observe a later pulse;
- the stage 5 harness passes 1,500 R lines.

## 7. Authority this probe would amend

Unchanged from the stage 4 brief, Section 7: the feature-map read-surface
synthesis (single resolver, alias rule), the context frame retirement seed
(follows this probe and takes the view as its input), the contracts on
context and state, decision axis and target semantics, and maintainer
decision 1 for `adjust`. Seed v2 records the position-fact decisions.

## 8. Out of scope

Product code outside the prototype, full resume plumbing, history-panel
changes, state storage, recording, schedule redesign, cash-shortfall fill
policy.
