# Strategy-Helper Axis Audit

**Status:** Cut 22 audit record (LDG-2905), agent-drafted 2026-09-28 at the
maintainer's request. Findings are executed, not inferred.

**Question:** does every strategy helper and context surface behave the same
way in a dense universe and in a ragged, availability-aware universe?

**Evidence:** `dev/spikes/strategy-helper-axis/probe.R` runs every helper and
surface against five pulse contexts and records 155 observations in
`observations.csv`; `check.R` reruns the probe and prints every changed row,
so each fix can show exactly what it changed.

| Context | Universe | Members | Positions | Restricted |
|---|---|---|---|---|
| `dense` | AAA, BBB | not declared | none | none |
| `ragged_all` | AAA, OLD | AAA, OLD | none | none |
| `ragged_held` | AAA, OLD | AAA | OLD = 2 | OLD (nonmember) |
| `ragged_restrict` | AAA, OLD | AAA, OLD | none | AAA |
| `ragged_empty` | AAA, OLD | none | OLD = 2 | AAA, OLD |

Each context also runs with a missing (`NA`) feature on its first and on its
second instrument.

## What Already Works In Both

- Pipelines through `ledgr_selection()` align values by name, choose only
  among members, and keep held nonmembers:
  `ledgr_selection() |> ledgr_weight_equal() |> ledgr_target_rebalance()` and
  `ledgr_selection() |> ledgr_target_quantity()`.
- The value constructors fail loudly on a wrong universe: `ledgr_target()`
  refuses a member-only vector when the universe is larger.
- `ctx$flat()`, `ctx$hold()` and every `ctx$vec` plane cover the whole
  decision axis in both kinds of run.

## Findings

**A1. Signal helpers change shape in ragged universes (critical).**
`ledgr_signal_feature()`, `ledgr_signal_return()` and `ledgr_signal(ctx, ...)`
return one value per current member, while targets and `ctx$vec` cover the
whole decision axis. In `ragged_held` the signal has one element and the target
two, so `targets[signal > 0.1] <- 10` recycles and gives the held nonmember
`OLD` a target of 10 with no error. The same code is correct in `dense`.

**A2. Dense contexts lack the eligibility planes (critical).** In `dense`,
`ctx$members` is `NULL` and `ctx$vec` has no `member`, `admissible` or
`target_restricted` plane. A mask written for ragged runs,
`ctx$vec$member & condition`, becomes `logical(0)` in a dense run, so the
strategy targets nothing and goes flat without an error.

**A3. Hand-built rules have no eligibility surface that works in both (high).**
A rule built from `ctx$vec` targets held nonmembers and restricted instruments
in ragged runs; in `ragged_empty` it targets both instruments although none is
a member. Masking with `ctx$vec$member` excludes nonmembers but still targets
the restricted member in `ragged_restrict`, and breaks dense runs (A2).
`ctx$tradable()` returns instrument IDs rather than a mask.

**A4. `ledgr_signal_strategy()` applies no eligibility (high).** It requires
one signal per universe instrument. Member-only signals fail in `ragged_held`
and `ragged_empty`; axis signals target nonmembers in every ragged context,
including the held nonmember and the empty-member case.

**A5. Ineligibility is reported as missing data (medium).** Signal helpers
set target-restricted members to `NA`. The default
`ledgr_selection(where = ..., missing = "error")` then refuses the pulse in
`ragged_restrict` as if the data were missing, and `ledgr_select_top_n()`
counts restricted members in its partial-selection warning. `ledgr_signal(ctx,
values = ...)` does not mask, so the two signal constructors disagree.

**A6. The warmup gate is not eligibility-aware (medium).**
`ledgr_passed_warmup(ctx$vec$feature(...))` counts nonmembers: a missing
value on a held or delisted nonmember keeps the gate closed indefinitely.
Applied to a member-only signal instead, it errors when there are no members.

**A7. Surfaces disagree on type (low).** `ctx$vec` planes are unnamed and
positional, targets and signals are named, eligibility planes are logical,
and `ctx$tradable()` returns IDs.

## Consequence For Teaching

The maintainer decided on 2026-09-28 that the articles teach strategies as
named-vector manipulation before any strategy helper appears. That promise
only holds if a named vector means the same thing in both kinds of run: one
entry per decision-axis instrument, in `ctx$universe` order, with eligibility
available as a plane in both. Findings A1 to A4 break it today; Cut 22 repairs
it before the code-idioms pass teaches it.

## Proposed Principle

One decision axis and one definition of eligibility, present in both kinds of
run:

1. every per-instrument vector a strategy receives from `ctx` or a helper
   covers the decision axis in `ctx$universe` order;
2. dense contexts carry the eligibility planes too, with every instrument a
   member and none restricted;
3. eligibility (member and not target-restricted) is applied in one place,
   the selection step, and the `missing` policy covers only missing values
   of eligible instruments;
4. every target-producing helper, including `ledgr_signal_strategy()`, keeps
   held nonmembers at their current quantity;
5. the warmup gate considers eligible instruments only, and passes when there
   are none.

The principle changes the accepted strategy-helper contract, so LDG-2906
records the maintainer's decision and extends `inst/design/contracts.md` in
place before any implementation ticket starts.
