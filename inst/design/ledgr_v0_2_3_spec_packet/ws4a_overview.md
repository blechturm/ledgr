# WS4a in plain terms

What workstream 4a changes in ledgr's engine, and why. This page is the
readable version. The [design note](ws4a_carrier_design.md) is the
checklist behind it: every rule there maps to a ticket, a test and a
deliberate breakage that the test must catch.

## What the engine does on each bar

ledgr runs a backtest as a loop over bars ("pulses"). Each pulse goes
through five steps:

1. **Observe.** Settle anything due (dividends, delistings), value the
   portfolio at today's prices, and work out which instruments the
   strategy may see.
2. **Decide.** Call the strategy with `ctx` and get back target
   quantities.
3. **Plan.** Turn targets into fills for the next bar's open: price,
   costs, and whether there is enough cash.
4. **Apply.** Book the fills: update the lots (which shares were bought
   when, at what price), cash and positions, and write ledger rows.
5. **Commit.** Write diagnostics and strategy state, then move on.

None of that changes. WS4a changes how the data travels between those
steps.

## What is slow today

Today, every fill is its own little R object. Planning one fill builds a
list, a "proposal" object, a "fill context" object and a "fill intent"
object, and checks its timestamp again. Applying it looks the instrument
up by name across the whole universe, copies the per-instrument lot
vectors, and builds another list for the ledger row. Diagnostics are lists
of lists, glued together at the end of each pulse.

R is slow at making many small objects and fast at working on whole
vectors. On a 500-instrument backtest with about 68,000 fills, this
object machinery costs about 226 microseconds per fill. The arithmetic
itself is a few microseconds.

## What changes

Each step now hands the next one a small set of plain vectors, one entry
per instrument or per fill, instead of a list of objects.

- **Observe** produces two things: what the strategy is allowed to see
  today, and, separately, tomorrow's opening prices for the planner. The
  strategy step never receives tomorrow's prices, even internally. Today
  the two travel together and the code is simply careful not to pass the
  second one on.
- **Decide** checks the strategy's return once. Today it is checked twice.
- **Plan** prices all of a bar's fills in one go: one vector of
  quantities, one of prices, one of fees, one of cash effects. The cost
  model (spread, fixed fee, notional fee) is applied to the whole vector,
  in the same order, with the same rounding. The cash check still walks
  the fills in its fixed order (sells that raise cash first), because
  that order is part of the rules.
- **Apply** books all of a bar's fills in one call, then writes them to
  the ledger as one block of columns.
- **Commit** writes diagnostics from one pre-sized table per pulse into
  the existing diagnostic writer.

## The lot book

Lots are how ledgr knows its positions and cost basis (FIFO: the oldest
shares are sold first). Today each instrument has its own little list of
lots, found by name.

After WS4a, all lots live in two long vectors, quantities and prices, and
each instrument owns a stretch of them. A small table says where each
instrument's stretch starts and which part is live.

Example. Two instruments; AAA holds two lots, BBB one:

| slot | 1 | 2 | 3 | 4 | 5 | 6 |
| --- | --- | --- | --- | --- | --- | --- |
| quantity | 10 | 5 | - | - | 7 | - |
| price | 100 | 102 | - | - | 50 | - |

AAA owns slots 1-4 (live: 1-2); BBB owns slots 5-6 (live: 5). If AAA
sells 12 shares, the engine takes all 10 from slot 1 and 2 from slot 2,
leaving 3 shares at 102. It records the realized profit and moves AAA's
live range to start at slot 2. If BBB buys on the same bar, its new lot
goes into slot 6. Both instruments are handled in the same pass.

The rules do not change:

- lots are still the only source of truth for positions;
- FIFO order is kept within each instrument;
- dust (tiny leftovers from floating-point arithmetic) is cleared exactly
  as today;
- running totals are added up in the same order as today, so results
  match to the last bit.

The same lot code serves every place that needs lots: the backtest itself,
re-reading results from the ledger, resuming a run, walk-forward
carry-over, delisting payouts, and the optional compiled path. Today some
of those places have their own copies of the logic.

## What stays the same

- Every number in every result: fills, trades, equity, ledger rows,
  diagnostics, strategy state.
- The strategy API (`ctx`, targets). The new flat `ctx` is WS5.
- Both engine modes still run. Removing the old "dense" mode is WS4b; WS4a
  only makes both modes hand over the same typed data from the decision
  onwards.
- The stored format, so existing stores keep working.
- No compiled code becomes the default. The probe showed plain R is fast
  enough: about 27 microseconds per fill against 25 for C++.

## How we know nothing changed

Before any code changes, today's outputs are frozen as references:

- the A0 workloads (295 checks);
- the dense-mode reference (nine runs);
- the real Sharadar workloads (six runs, including a sweep and a
  walk-forward);
- seventeen new cases for the corners the existing references miss:
  chained costs, rounding edges, tiny fractional leftovers, short
  reversals, carried lots, delistings and early stops.

After every step of the work, all of these must match byte for byte. Each
check is also shown to fail when the code is deliberately broken (for
example, selling the newest lot first instead of the oldest), so a passing
check means something.

## Expected result

On the 500-instrument test: about 27 instead of 226 microseconds per fill,
and a durable run of about 11 seconds instead of 25. Most of what is left
is the per-bar cost with no trades at all. That is WS4b's job.

## Order of work

1. Write the plan down (LDG-3162) and build the measuring tools on
   today's code (LDG-3163). Then the cut is reviewed and accepted.
2. Workstream 12: the lot book and its single implementation (LDG-3164).
   Reviewed on its own.
3. Workstream 13: observe and decide, plan, apply, and diagnostics with
   equity (LDG-3165 to LDG-3168), then the final checks and timing
   (LDG-3169).
