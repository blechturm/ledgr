# Type 2 Response v5: Equity Settlement After v0.2.0.2

**Status:** Fifth adversarial Type 2 review, read-only. Binds nothing.
**Author:** Claude. **Date:** 2026-09-23
**Reviews:** `rfc_equity_settlement_post_v0_2_0_2_seed_v5.md`

No licensed identifier, price or action value appears below. Claims about
package behavior are marked **executed**, **structural** (read from current
source) or **proposed**.

## 1. Judgment

The grouped-row direction is right and I would not reject it. The cash path is
ready. The upstream boundary is sound. The persistence change is a genuine
improvement over v4.

The stock-exchange feature should leave this release, and not for any reason
argued in the previous four rounds.

A supported stock exchange requires the parent to terminate. Every held
instrument carrying a terminal event stops the run today, unconditionally,
with no exemption for a settlement that could handle it. Seed v5 states that
this contract is preserved unchanged. It cannot be preserved unchanged and
also permit the one feature the whole grouped architecture exists to carry.

That is not a defect in the group design. It means the feature costs a
contract change nobody has priced, on top of a new event type, a table
recreation, a transaction boundary that does not exist, and a reader that
becomes group-unaware. Against a supported population the seed never counts.

## 2. Findings

### F1. The terminal stop forecloses the supported case (structural)

`R/fold-engine.R:398-405` takes the held identifiers, selects those whose
`terminal_event` string is non-empty, and stops the fold with
`terminal_status = "INCOMPLETE"` and `stop_reason =
"terminal_settlement_unsupported"`. There is no branch for a settlement that
is supported. `inst/design/contracts.md:434` binds that stop as a valuation
stop that preserves the holding and never fabricates cash settlement.

Seed v5 section 6.2 requires "one terminating parent". A terminating parent in
an acquisition carries a lifetime terminal event, and by premise it is held.
So the run stops at the valuation block before the settlement applies.

Section 8 presents this as untouched: "the existing
`terminal_settlement_unsupported` meaning preserves the holding and mutates
nothing." Both halves cannot hold. Supporting the exchange requires narrowing
a bound contract so that a held terminal with an admitted settlement does not
stop, which is a contract change with its own route under `rfc_cycle.md`.

The density spike did not meet this. It injected a positive holding into a
child with an ordinary parent; no terminal event existed in its fixture. The
atomic spike ran on a scratch fork below this layer. **Executed** evidence is
silent here; the finding is structural and checkable in eight lines.

### F2. The supported population is never counted (structural)

The census registered 41 candidates and resolved 39. Seed v5's rule admits
only a terminating parent with exactly one resolved on-axis recipient, one
positive ratio, and no cash or election leg. That excludes every spin-off,
because the parent is retained, and every mixed acquisition, because a cash
leg exists. What remains is a subset of the stock acquisitions, further
filtered by axis and ratio, and the corrected census has not run.

No seed in this cycle states that number. The feature carrying the new event
type, the group contract, group replay, lot consumption, carryover, the
transaction boundary and most of the gate is justified by a population bounded
above by the stock-acquisition count in one three-year window, against a
dividend population three orders of magnitude larger.

A design may be correct and still not earn its release. This one is not shown
to earn it, and the seed does not attempt the comparison.

### F3. "One transaction" does not exist on either writer (structural)

Section 7 says the handler "appends the complete row block in one transaction".
`R/backtest-runner.R:497-502` is the durable handler: a bare
`DBI::dbAppendTable(con, "ledger_events", rows)` with no `dbBegin` or
`dbCommit` around it. The memory handler at `R/sweep.R:1694` writes into
preallocated buffers.

Worse, the two writing paths do not share a boundary. Fills go through
`buffer_event`, and the buffer flushes separately at
`R/backtest-runner.R:525-531`. A group appended directly lands in the table
while earlier buffered fills have not. An interruption between those two
leaves a ledger holding a settlement whose preceding fills are absent, which
is a partial state neither the group check nor the row count detects.

The brief said not to accept "one transaction" unless the paths actually share
it. They do not. This is inherited rather than introduced, since the
opening-position path has the same shape, but the seed asserts a property the
code does not provide.

### F4. A public reader observes rows without the group authority (structural)

`R/backtest-results.R:988-997` is the user-facing ledger reader. It issues
`SELECT * FROM ledger_events WHERE run_id = ? ORDER BY event_seq` and returns
the rows as a tibble. It does not call `ledgr_prepare_accounting_events()` and
performs no validation.

So the validity boundary is not uniform. The preparer rejects an incomplete
group; this reader displays it. Section 7's requirement that "raw row count is
not presented as economic-event count" is work against this function, and
section 11 does not list it.

This is the state the brief asked me to look for, reached from the reader side
rather than the projection side. The projections do stay consistent, because
they all funnel through the preparer, which is the real strength of the
grouped design. The exposure is the surface that bypasses it.

### F5. Closure is safe only for per-instrument features (structural)

Section 4 requires fixed-point closure that never touches membership. I
checked the strategy-visibility half and it holds: the decision axis is
members plus nonzero held nonmembers
(`R/availability-provider-prepared.R:261-266`), so a presealed recipient is
invisible until held.

Feature preparation is the gap. Closure changes the instrument set the
projection is built over. A per-instrument feature is unaffected. A
cross-sectional feature, anything ranked or standardized across the axis,
changes value for every instrument when the axis grows, and it changes before
any settlement occurs. That is look-ahead reaching the strategy through
features while membership stays constant exactly as promised.

Gate case 6 would detect it for the case it runs. It is a property of the
experiment's features, not a property the closure can guarantee, and the seed
states it as guaranteed.

### F6. The path boundary is stated in internal terms (proposed)

Section 4 limits support to "availability-aware runs carrying the prepared
ragged bar matrix and fold equity". Whether a run carries a prepared ragged
matrix is not something a user can see or choose. A product boundary has to be
expressible in what the user selected.

The underlying distinction is probably fine. Say it as availability-aware runs
support settlement and other runs refuse it before execution, and let the
matrix representation be the reason rather than the rule.

### F7. Deterministic identities are stronger than the seed claims (structural)

A small credit. `R/db-schema-create.R:210-222` makes `event_id` the primary
key and adds `UNIQUE(run_id, event_seq)`. Deterministic per-row group
identities therefore make duplicate delivery a database rejection rather than
a validation concern. The seed mentions determinism without connecting it to
the constraint that already enforces it.

Two costs it does not mention: the `event_type` CHECK admits only `FILL` and
`CASHFLOW`, and `R/db-schema-create.R:382-427` shows constraint changes are
handled by recreating the table and copying rows. Adding `SETTLEMENT` is a
table-recreation migration on every existing store.

## 3. The strongest simpler alternative

Ship gross cash distributions and refuse every quantity mutation with its
actual reason.

This removes the new event type, the table recreation, the group metadata
contract, group replay, group-aware reporting, lot consumption, carryover, the
transaction boundary that does not exist, and the contract change in F1. Gate
cases 4, 5 and 9 collapse into the existing refusal case. What remains is the
sealed fact family, upstream normalization with bar vintage, the two posting
conventions, one `CASHFLOW` projection, fixed-point closure, and the compiled
guard, which the cash path needs anyway.

The refusal is honest rather than a gap: `terminal_settlement_unsupported`
already means preserve the holding and fabricate nothing, and under this
alternative it stays true instead of needing to be narrowed.

**Where it fails.** It leaves the grouped-row design unexercised, so B6 and B7
stay untested until the release that needs them, and the atomicity questions
in F3 go unanswered while the cash path quietly depends on the same writers.
It also means a held parent in an acquisition still halts the run, which for a
long backtest is a real loss of usable output, and the alternative offers
nothing better than the current stop. If the stock exchange is the only way to
keep those runs alive, that argument beats mine, but the seed does not make it
and the population in F2 would have to support it.

## 4. Scenarios

| Scenario | Seed v5 as written |
| --- | --- |
| Two valid rows then a duplicate recipient row | Rejected by the `event_id` primary key before validation. Sound. |
| Durable store holds only the parent row | Preparer rejects the group, so no projection computes. But F4's reader still shows the orphan row, and F3 means the state is reachable. |
| Position reconstruction before group-aware replay | Safe, because both go through the preparer. This is the design's real strength. |
| Recipient itself acquired later | Closure covers it if the second event is in the window. Its own settlement then hits F1 again. |
| Closure adds an instrument with features but no membership | Membership holds. F5's cross-sectional feature case is not covered. |
| No bar at entitlement, bar at the next pulse | Section 8 refuses before append, correctly, and rejects the non-finite error as the outcome. |
| Same fact encountered during resume | Group identity plus the primary key make it idempotent. Sound. |
| Dense non-availability run opens the snapshot | Refuses, but on the internal criterion in F6. |
| **Missed: the parent's own terminal event** | Not addressed anywhere. F1. |

## 5. Conditions for synthesis

If the direction survives, synthesis must bind all of these.

1. Decide the stock-exchange scope with F1 and F2 on the table. If it stays,
   the narrowing of `contracts.md:434` is part of this RFC and is named as a
   contract change, not inherited language. My recommendation is that it goes.
2. Replace the asserted transaction in section 7 with the actual boundary, or
   require one to be built, and state what happens to the buffered fill path.
3. Name the public ledger reader as work. A surface that shows unvalidated
   groups is part of the contract whether or not the seed lists it.
4. Restate closure's guarantee as holding for per-instrument features and
   require cross-sectional features to be refused or declared.
5. Restate the path boundary in user-selectable terms.
6. Price the `event_type` CHECK change as a table-recreation migration.

## 6. Bias, and where my own proposal was weakest

I proposed one row per affected instrument in response v4 and seed v5 adopts
it almost verbatim, so I reviewed it as if it were someone else's.

It survives the attack better than I expected on projections, because every
projection funnels through one preparer. It is weakest exactly where I was
most confident. I wrote that multi-row grouping "keeps every existing
reconstruction path working unchanged" and offered atomicity as coming free
from "one transaction". F3 shows that transaction does not exist on either
writer, and F4 shows a public reader I never traced. My alternative inherited
an atomicity gap I was charging seed v4 with, and I did not find it until I
was made to look for it.

I also over-read the finalization branch in response v4, and I have taken care
not to compensate by accepting the density spike past its evidence. Its
conclusion holds for the executed availability path. Seed v5 scopes it
correctly, and F6 is about how that scope is expressed, not whether it is
honest.

TYPE_2_DISPOSITION: PROCEED_TO_SYNTHESIS_WITH_BOUND_CONDITIONS
