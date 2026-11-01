# Cut 7 Review: Strategy Authoring API

Mode: Type 1 cut review with adversarial input check.  
Reviewer: clean-context Claude Opus, high effort.  
Range: `14252ffb..e3c374f1`.  
Date: 2026-11-01.  
Verdict: **NEEDS_TYPE_2**.

## Overall assessment

The cut stays close to the accepted synthesis. Its four workstreams map to
D1-D9, Section 4 ownership is complete, and it creates no second execution
engine, scheduler or reader. One maintainer decision and eleven specification
patches are required. A focused re-review follows after they land.

## Type 2 decision

The draft's change-only state checkpoints break the durable resume cursor.
Today each pulse writes a `strategy_state` row and resume uses its maximum
timestamp. With no row on an unchanged pulse, resume restarts from the last
state change; a run whose loop completed but whose finalisation failed may
rerun the loop. A strategy with no declared state may resume from pulse one.

The accepted design also requires typed declared state and rejects per-pulse
list-per-ID JSON. The options are:

1. **Recommended: cursor row per completed pulse.** An unchanged pulse writes
   a constant marker without encoding state. A changed pulse encodes the
   complete state once. Resume uses the cursor row and restores from the latest
   preceding state payload. The remaining changed-state encode is measured and
   routed to the synthesis Section 7 storage RFC.
2. Checkpoint by writer block and deterministically replay pulses after the
   checkpoint. This changes crash recovery and `db_live` behavior.
3. Add a typed state table now. This changes the store schema and must be
   coordinated with WS8's accepted schema 125.

## Required patches

1. Preserve one cursor row per completed pulse, count axis-ID changes as state
   changes, restore the latest preceding payload by ID, and test unchanged-tail
   and finalisation-only resume.
2. Encode declared state with explicit field types, missing-position masks and
   asset-ID vectors. Decode from the declaration rather than JSON token types or
   key order. Test all four types, missing values, non-alphabetical axes, empty
   axes and whole-number doubles.
3. Add an unconditional `ledgr_strategy_state_rule_version` store-format
   binding and correct the declaration-identity wording.
4. Store D8 evidence in existing typed `run_diagnostics` fields: one sizing row
   per instrument/decision; quantities in target columns, mark in `price`, held
   quantity in `position_before`, typed reason codes, constant empty detail JSON
   and `intent_reason` in `reasons`. Add a sizing-rule binding. Report pooled,
   minimum and last-decision coverage; label cross-decision sums as diagnostics,
   not exposure or P&L.
5. Keep prepared frames and `ctx$bar(id)` for WS6. WS5 removes the vector,
   feature and scalar per-ID readers; `ctx$state` belongs to the state ticket.
6. Retire public `ledgr_strategy_schedule()` and migrate all experiment call
   sites affected by required opening inputs in the owning ticket.
7. Map every synthesis Section 3 contract amendment to one implementing ticket.
8. Cut 7 closes WS5 implementation; final WS5 acceptance remains at integration
   join J on the merged WS7 reader. The pattern article requires the
   maintainer's cold read.
9. Keep `ledgr_align_weights()`; it is a distinct causal-history helper used by
   maintained teaching. Put it and `ledgr_passed_warmup()` on the public-name
   allowlist. Other live exports retain their meaning; broader pruning is WS11.
10. Compare timing with both Cut 6 and the post-WS4a attribution base, report
    context/state phase shares, use the wide fixed-basket state cells, and make
    no warm-iteration claim without an experiment-construction clock.
11. Add a small pre-acceptance probe: declared-state round trip, unchanged-tail
    resume, and current context/state call counts.

## Should-fix items

- Route `sizing_unavailable` through the common diagnostic path and test the
  memory sink.
- Pin the unavailable-mark failure for `holding_value`.
- Record effective capital base and `invest_fraction` in target origin.
- Migrate pulse snapshots to declared state, decide their cash default under D7
  and give mock positions unknown position facts.
- Let the private vector adapter survive only until the last helper migration.
- Name validation-time state encodes and decide the JSON cache's last owner.
- Bind condition names and return types.
- Confirm that maintained strategies need no non-scalar or nested state.

## Coverage

| Authority | Owner | Review result |
| --- | --- | --- |
| D1 flat lazy view | LDG-3180 | Patch WS6 boundary and mark failure |
| D2 position facts | LDG-3181 | Clean |
| D3 target verbs | LDG-3183 | Add diagnostic/origin details |
| D4 selection and weights | LDG-3182 | Bind return types |
| D5 declared state | LDG-3185/3186 | Type 2 state checkpoint decision |
| D6 schedule | LDG-3184 | Retire decorator export |
| D7 investor inputs | LDG-3184 | Migrate every defaulted caller |
| D8 rounding disclosure | LDG-3187 | Bind physical mapping and coverage |
| D9 pattern teaching | LDG-3189 | Final acceptance remains at J |
| Section 4 item 1 | LDG-3180 | Clean after boundary patch |
| Section 4 item 2 | LDG-3181 | Clean |
| Section 4 item 3 | LDG-3183 | Add unavailable-mark witness |
| Section 4 item 4 | LDG-3185/3186 | Type/round-trip patches |
| Section 4 item 5 | LDG-3188/3189 | Maintainer cold read |
| Section 4 item 6 | LDG-3179/3187 | Timing and D8 mapping patches |

## Checked clean

- YAML parses; cut, workstream and ticket IDs are unique and dependencies
  resolve.
- README and ticket authority agree.
- `git diff --check` is clean.
- `cost_model` is already required; only the opening default changes.
- No second execution engine, scheduler or reader is introduced.
- Sweep/worker isolation, walk-forward reset and economic-fact carry have owners.
- Section 4 ownership by evidence family is complete.
- Performance and seven-shape duties use counters and records rather than
  treating hosted clocks as acceptance gates.

A focused re-review is required after the Type 2 decision and patches.
