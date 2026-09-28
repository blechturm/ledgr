# Strategy-Helper Axis Audit

**Status:** Cut 22 audit record (LDG-2905), agent-drafted 2026-09-28 at the
maintainer's request and revised the same day after the Codex cut review
(CHANGES_REQUIRED, invocation 1). Findings are executed, not inferred.

**Question:** does every strategy helper and context surface behave the same
way in a dense universe and in a ragged, availability-aware universe?

## Evidence

`dev/spikes/strategy-helper-axis/probe.R` runs 41 probes on each context:
every signal,
selection, weight and target helper; `ledgr_signal_strategy()`; the warmup
gate; `ctx$vec` planes, `ctx$flat()`, `ctx$hold()`, `ctx$tradable()`,
`ctx$position()`, `ctx$features()` with an explicit map and with the active
alias map; `ctx$state_prev$asset_state`; and the input forms of
`ledgr_signal(ctx, values = ...)`. Two input-only warmup probes, six runtime
runs and the public pulse snapshot complete the set: 789 observations in
`observations.csv`.

- **Constructed contexts.** Built with the internal pulse-context
  constructor. Target restriction is set independently of membership, as the
  production provider derives it from status and lifetime evidence:

  | Context | Axis | Members | Held | Restricted |
  |---|---|---|---|---|
  | `dense` | AAA, BBB | not declared | none | none |
  | `ragged_all` | AAA, OLD | AAA, OLD | none | none |
  | `ragged_held` | AAA, OLD | AAA | OLD = 2 | none |
  | `ragged_restrict` | AAA, OLD | AAA, OLD | none | AAA |
  | `ragged_holdings_only` | OLD | none | OLD = 2 | none |

  Each also runs with a missing feature on its first and on its second
  instrument. The constructor refuses an empty universe, so the zero-length
  axis comes from a real fold only.

- **Real folds.** Contexts captured inside `ledgr_run()` on two small
  point-in-time snapshots:

  | Context | Axis | Members | Held | Restricted |
  |---|---|---|---|---|
  | `real_members` | AAA, BBB | AAA, BBB | AAA, BBB | none |
  | `real_departed` | BBB, CCC, AAA | BBB, CCC | BBB, AAA | none |
  | `real_departed_restricted` | BBB, CCC, AAA | BBB, CCC | BBB, AAA | BBB (halted) |
  | `real_holdings_only` | AAA | none | AAA | none |
  | `real_zero_axis` | none | none | none | none |

- **Runtime.** Six strategies are run to completion or failure through
  `ledgr_run()`, with the real strategy preflight. They cover membership
  departure, a halted member, an opening nonmember position and an empty
  axis.

- **Public pulse snapshot.** `ledgr_pulse_snapshot()` on the
  availability-bearing snapshot.

`check.R` reruns the probe. It fails on duplicate keys, on a row count that
differs from the baseline plus the manifest's additions and removals, and on
any change not listed in `expected_delta.csv`. It also fails on a manifest row
whose `was` differs from the frozen baseline, or whose change is not realized.
`observations.csv` stays frozen as the Cut 22 input until LDG-2911 accepts the
new baseline with `--accept`.

## What Already Works In Both

- `ctx$flat()`, `ctx$hold()`, every `ctx$vec` plane and
  `ctx$state_prev$asset_state` cover the decision axis in both kinds of run,
  including a joining member and a held nonmember (`real_departed`).
- In ragged runs `ctx$vec$admissible` already equals member and not
  target-restricted. A hand-built rule masked with it gives the intended
  target in every ragged context, constructed and real.
- The following behave identically in dense and ragged contexts:
  `ctx$position(id)`; `ctx$features(id, map)`; `ctx$features(id)` under an
  active alias map, which fails with `ledgr_no_active_alias_map` without one;
  and `keep =` in `ledgr_target_rebalance()`, which reserves a held
  nonmember's exposure once (`ragged_held`: `AAA=26 OLD=2` with and without
  it).
- Pipelines through `ledgr_selection()` align by name and keep held
  nonmembers at their quantity. The value constructors fail loudly on a wrong
  universe.

## Findings

**A1. Signal helpers change length in ragged runs (critical).**
`ledgr_signal_feature()`, `ledgr_signal_return()` and `ledgr_signal(ctx, ...)`
return one value per current member, while targets and `ctx$vec` cover the
decision axis. In `real_departed` the signal is `BBB, CCC` and the axis
`BBB, CCC, AAA`, so `targets[signal > 0] <- 10` recycles the mask and targets
the departed holding AAA (`BBB=10 CCC=0 AAA=10`). A strategy doing this runs
to completion without an error (runtime row). The same code is correct in
`dense`.

**A2. Dense contexts and the public pulse snapshot lack the eligibility
planes (critical).** `dense` and `ledgr_pulse_snapshot()` have
`ctx$members = NULL` and no `member`, `admissible` or `target_restricted`
plane. A mask written for ragged runs, `ctx$vec$admissible & condition`,
becomes `logical(0)` in a dense run, so the strategy goes flat without an
error. The fix is the existing `admissible` plane, present in dense
contexts too; no new plane is needed. `ctx$tradable()` stays a character
vector of IDs, since it also requires a price.

**A3. Selections choose target-restricted members (high).**
`ledgr_selection(ctx)` and `ledgr_selection(ctx, ids = ...)` select a
restricted member. `ledgr_target_quantity()` then changes its quantity, and
the run fails with `ledgr_restricted_target`. This happens in
`real_departed_restricted` and in two runtime rows, when BBB is halted and
the quantity changes. `ledgr_target_quantity()` also rejects any selection
name outside the members (`real_holdings_only`, `ids = AAA`). A selection over
the whole axis would therefore need that check relaxed for unselected names.

**A4. `ledgr_signal_strategy()` applies no eligibility (high).** It requires
one signal per axis instrument, so member-only signals fail whenever a
nonmember is held (runtime: `ledgr_strategy_error`). Axis signals map held
nonmembers like members: `real_departed` targets `AAA=10`, and a run with an
opening nonmember position of 2 fails with
`ledgr_nonmember_exposure_increase`. On an empty axis the wrapper refuses
the context (`ledgr_strategy_error`), although the execution contract invokes
strategies on an empty axis and accepts a named zero-length target.

**A5. Ineligibility is reported as missing data (medium).** Signal helpers set
target-restricted members to `NA`, as the probe shows in `ragged_restrict` and
`real_departed_restricted`. The default
`ledgr_selection(where = ..., missing = "error")` then refuses the pulse as if
data were missing. `ledgr_select_top_n(signal, 2)` warns
`ledgr_partial_selection`, and `ledgr_passed_warmup(signal)` is `FALSE`.
`ledgr_signal(ctx, values = ...)` does not mask, so the two signal
constructors disagree. Its input forms also disagree across universes: an
unnamed member-length vector is accepted in dense runs and refused in ragged
runs.

**A6. There is no cross-sectional warmup form (medium; API gap, not a
defect).** `ledgr_passed_warmup()` is contracted for the feature-alias vector
from `ctx$features(id)`. It also returns `all(!is.na(x))` for any vector and
refuses zero-length input. Applied cross-sectionally, it has no eligibility
to work with. In `ragged_held+missing_second` it returns `FALSE` on the axis
feature, because the held nonmember's value is missing, and `TRUE` on the
member signal. On a holdings-only or empty axis the member signal is empty,
so it errors. A context-aware form is new API. The one-argument form keeps
its behaviour, including the zero-length error.

**A7. The surfaces have different representations, which are undocumented
(low; inventory).** Most differences are intentional:

| Surface | Domain | Names | Type |
|---|---|---|---|
| `ctx$vec` planes | decision axis | unnamed, positional | numeric, logical or character |
| `ctx$flat()`, `ctx$hold()`, targets | decision axis | named | numeric |
| `ctx$tradable()` | admissible and priced | not applicable | character IDs |
| signals | members (A1) | named | numeric, classed |
| selections | members | named | logical, classed |
| weights | selected instruments only | named | numeric, classed |
| `ctx$features(id)` | feature aliases, not instruments | named | numeric |

The articles need this table's relationships stated once. The types
themselves need not be unified.

## Outside Cut 22

Two loops seen while probing:

- `ledgr_fold_asset_state_normalize()` iterates over the decision axis every
  pulse (`R/fold-engine.R:97`). That is the instruments x pulses shape. It is
  routed to the fold optimization workstream, not fixed here.
- `ledgr_target_rebalance()` emits one warning per unpriced instrument
  (`R/strategy-helpers.R:432`). A Cut 22 ticket that touches that function
  aggregates the warnings into one condition.

## Consequence For Teaching

The maintainer decided on 2026-09-28 that the articles teach strategies as
named-vector manipulation before any strategy helper appears. That promise
holds only if the named vectors ledgr hands a strategy mean the same thing in
both kinds of run, and if one eligibility plane exists in both. Findings A1
to A4 break it today; Cut 22 repairs it before the code-idioms pass teaches
it.

## Proposed Principle And Domain Table

LDG-2906 decides this. The proposal, narrowed after the cut review:

1. **One axis for cross-sectional data.** Context-derived signals, `ctx$vec`
   planes, eligibility masks and final targets cover the decision axis in
   `ctx$universe` order.
2. **One eligibility plane.** `ctx$vec$admissible`, which is member and not
   target-restricted, exists in every context: dense contexts (all `TRUE`),
   real folds and `ledgr_pulse_snapshot()`. No second plane is added.
3. **Standard pipelines apply eligibility automatically; other paths state it
   explicitly.** `ledgr_selection()` and `ledgr_select_top_n()` exclude
   ineligible instruments, and the `missing` policy covers only eligible
   instruments. `ledgr_signal_strategy()` maps only eligible instruments.
   Hand-built rules combine a condition with `ctx$vec$admissible`, and the
   runtime validators remain the backstop. The selection step is not the sole
   enforcement point.
4. **Convenience helpers keep ineligible holdings.** A helper that
   synthesizes targets without explicit intent keeps held nonmembers and
   held restricted members at their current quantity. Examples are
   `ledgr_target_rebalance()`, `ledgr_target_quantity()` and
   `ledgr_signal_strategy()`. Raw named targets, `ledgr_target()` and
   `ctx$flat()` stay literal: they may exit or reduce, exactly as the
   availability contract allows.
5. **Warmup.** A new context-aware form considers eligible instruments only
   and passes vacuously when there are none. The one-argument form is
   unchanged.

| Object | Domain after Cut 22 (proposal) | Open choice for LDG-2906 |
|---|---|---|
| `ctx$vec` planes | axis, positional; dense gains `member`, `target_restricted`, `target_restriction_reason`, `admissible` | none |
| signals | axis, named | value for an ineligible entry: the raw value plus an eligibility attribute (recommended, since mistakes then fail loudly at the runtime validators), or `NA` plus the attribute |
| selections | axis, named; ineligible entries `FALSE` (recommended) | or stay member-domain, and say so in the inventory |
| weights | selected instruments only (unchanged) | none |
| explicit `ids` naming an ineligible member | unselected, so the target helper holds it (recommended) | or a classed error |
| `ledgr_signal(ctx, values)` input | named axis, unnamed axis, named member-only; the result is axis-length | whether unnamed member-length input stays refused in both kinds of run |
| empty axis | every helper returns a zero-length named result; the wrapper returns `numeric(0)` named | none |
| targets | axis, named; literal when raw | none |

The principle changes the accepted strategy-helper contract. LDG-2906
therefore records the maintainer's decision and extends
`inst/design/contracts.md` in place, with its manifest rows, before any
implementation ticket starts.
