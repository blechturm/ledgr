# Focused Amendment: Common Civil-Calendar Schedules

**Status:** Accepted by the maintainer on 2026-10-26; implementation owned by
Cut 22, Workstream 64 and LDG-3115.
**Author:** Codex, for maintainer adjudication.
**Date:** 2026-10-26.
**Would amend if accepted:** Sections 2, 3 and 5 of the
[accepted strategy-schedule synthesis](rfc_strategy_schedule_decorator_v0_1_9_x_synthesis.md)
through a dated amendment notice and supersession table. Acceptance also adds
a `decisions.md` row and updates the scheduler redirect in `README.md`.
**Parent authority:** the accepted synthesis and
[maintainer decisions](rfc_strategy_schedule_decorator_v0_1_9_x_maintainer_decisions.md).

This is a focused amendment under `../rfc_cycle.md`. Its accepted changes are
incorporated by reference into the parent synthesis. It does not reopen the
scheduler carrier, fold-stage boundary, session-axis
requirement, identity model, persistence model, scheduled-skip semantics or
one-pulse-per-session limitation.

## 1. Problem and necessity

The shipped scheduler directly expresses week starts, month starts and ends,
quarter starts, year starts and explicit dates. It cannot directly express two
ordinary research cadences:

- the first open session on or after a named weekday, such as every Wednesday;
- the first open session on or after a numbered day of each month, such as the
  15th.

Both can be expanded by user code into a `Date` vector and passed to
`ledgr_schedule_dates()`. That workaround is deterministic, but it makes the
user own range construction, civil-calendar edge cases and the distinction
between an authored recurrence and its resolved dates. It is also materially
less readable than the fixed helpers beside it.

The existing architecture already has the required mechanism: a canonical
declaration is compiled once against the authoritative parent session axis.
The smallest addition is therefore two declaration types handled by the same
compiler. No new scheduler, callback form or pulse-time calculation is needed.

## 2. Bound public surface

Add exactly two constructors:

```r
ledgr_schedule_weekday("wednesday")
ledgr_schedule_month_day(15L)
```

Their signatures are:

```r
ledgr_schedule_weekday(day)
ledgr_schedule_month_day(day)
```

`ledgr_schedule_weekday()` accepts exactly one non-missing lower-case ASCII
token from `monday`, `tuesday`, `wednesday`, `thursday`, `friday`, `saturday`
or `sunday`. It does not consult the process locale and does not accept
abbreviations, numbers or multiple representations of the same weekday.

`ledgr_schedule_month_day()` accepts exactly one non-missing whole number from
1 through 31, supplied as integer or double, and stores it as integer. A month
without that numbered civil day has no anchor and therefore no decision for
that month. Users who mean the final open session of every month use
`ledgr_schedule_month_end()` instead.

The helpers return ordinary version-1 schedule declarations with new type IDs
`weekday` and `month_day`. `ledgr_strategy_schedule()` remains the sole public
decorator. No generic recurrence constructor or user function is accepted.

## 3. Resolution semantics

Both rules compile once, before fold entry, against the same authoritative
status-open parent session axis used by the existing fixed rules.

For `weekday`, each Monday-through-Sunday civil week is one recurrence period.
The named weekday is its anchor. The decision is the first open session on or
after that anchor and before the next civil week begins. If no such session
exists, that week contributes no decision.

For `month_day`, each calendar month is one recurrence period. The requested
numbered civil day is its anchor. The decision is the first open session on or
after that anchor and before the next month begins. If the numbered day does
not exist, or no later session is open in that month, that month contributes no
decision.

An anchor earlier than the first parent-axis open session is unproved. The
absence of an open session between the anchor and the axis start is not
declared, so that period contributes no decision. An anchor on or after the
first open session resolves normally, including on that first session when it
falls on the anchor date. Consequently, `ledgr_schedule_month_day(1L)` decides
on an axis whose first open session is the 1st, while
`ledgr_schedule_month_start()` does not: the anchor rule proves its decision
from the anchor date, whereas the transition rule needs a predecessor.

Period-local resolution prevents a closed Friday from silently becoming the
following Monday and prevents a late monthly anchor from becoming a decision
in the next month. It also makes repeated anchors incapable of producing two
decisions on one session. The compiler nevertheless returns the same complete,
deduplicated logical verdict vector as every existing schedule.

The full parent axis decides recurrence boundaries before the executable range
is selected. A run that begins after the resolved decision in its first partial
week or month does not manufacture another one. A run that begins before the
anchor may decide later in that period. The existing zero-decision rule remains
unchanged.

The validator, compiler dispatch, period-key helper, compiler
`resolved_schedule` field and print label each gain an explicit branch. No
branch infers behavior from a type-name suffix. The two resolved-schedule forms
retain their normalized argument rather than becoming argument-less rules. The
validator requires exactly the existing outer declaration keys and exactly one
argument key named `day`, independent of input key order, before rebuilding the
canonical declaration.

## 4. Identity and format

The canonical declaration records the new type ID and its single normalized
argument. These bytes and the resulting schedule hash enter every existing
identity, persistence, recovery, promotion, sweep, walk-forward and worker
surface exactly as current schedule declarations do.

The declaration stays at version 1 and the enclosing current formats do not
bump. `ledgr_schedule_version` is a per-record marker outside the store-format
fingerprint; the current catalogue and contracts pin the stored declaration
columns but do not close their type-ID vocabulary. Adding a tagged variant
reinterprets no existing stored byte. An older implementation rejects an
unknown type rather than misreading it, while every existing declaration keeps
byte-identical canonical JSON, hashes, meaning and readers.

The declaration version bumps when the encoding or meaning of an existing
variant changes. Adding a variant does not bump it. If a store-level bump is
ever owed, the store schema and every containing orchestration format change
together; the declaration version never acts alone as a partial store gate.
This amendment adds no fallback, migration, old reader or missing-marker
behavior.

The validator re-stamps `month_day`'s `day` as integer before hashing, so the
constructor, worker transport and stored canonical JSON produce one byte
sequence for `15` and `15L`.

## 5. Parameterization and exclusions

`ledgr_schedule_from_param()` remains limited to its current scalar fixed-rule
tokens. This amendment does not invent string grammars such as
`weekday:wednesday`, accept structured objects through strategy parameters or
add two more parameter-specific constructors. Evidence of a real sweep need is
required before widening that surface.

The known trigger is a research request to vary the decision weekday or day of
month across candidates of one sweep. If that need recurs, the accepted shape
is a typed parameter reference accepted by each constructor's `day` argument
and resolved from ordinary strategy parameters before the fold, with identity
through the resolved declaration as the parent synthesis already requires. It
is not a token grammar in `ledgr_schedule_from_param()`.

The amendment also does not add:

- week-end or quarter-end helpers;
- nth-weekday rules such as the third Friday;
- business-day offsets;
- exchange-specific holiday policy outside the declared session axis;
- cron expressions, formulas, predicates or arbitrary R functions;
- within-session or intraday schedules; or
- a persisted decision mask.

Those are separate design questions. The explicit-date helper remains the
escape hatch for uncommon finite schedules.

## 6. Detecting evidence required by an implementation ticket

One follow-up implementation ticket is sufficient if this amendment is
accepted. It must carry at least these failure-sensitive checks:

1. Table-driven weekday cases cover every weekday, a mid-week holiday, a week
   with no open session after its anchor, a parent axis beginning after the
   anchor in its first week, a run window beginning after a separately resolved
   decision, and a partial last week. The first two partial-period cases are
   distinct: the parent-axis case decides nothing, while the run window does
   not decide again.
2. Table-driven month-day cases cover 1, 15, 28, 29, 30 and 31; short months,
   a closed anchor, no later open session, a parent axis beginning after its
   first anchor, a run window beginning after a separately resolved decision,
   and a partial last month. `month_day(1L)` on an axis beginning on an open 1st
   decides there while `month_start()` on that same axis does not.
3. Run and sweep construction compile identical verdicts, and parallel,
   persistence, reopen, recovery, promotion and walk-forward retain the exact
   declaration and hash through their existing generic paths.
4. Distinct weekday and month-day arguments produce distinct canonical bytes,
   hashes and candidate identities. `month_day(15)` and `month_day(15L)`
   produce identical bytes and hashes, canonical-JSON round trips reproduce
   the stored hash, and the compiler's `resolved_schedule` retains the
   argument. Existing rule bytes and hashes remain unchanged. The contracts'
   current-format group records the accepted version-1 type set and the rule
   that additive variants do not bump it.
5. Unknown, upper-case, abbreviated, missing, non-character or non-scalar
   weekdays and missing, fractional, non-numeric, non-scalar or out-of-range
   month days refuse through `ledgr_invalid_strategy_schedule` before fold
   entry.
6. Structural checks prove the new rules enter the existing compiler and add
   no calendar parsing, formatting, scanning or allocation inside the pulse
   loop.
7. Executable teaching shows one weekday and one month-day example and states
   the period-local closed-session behavior. It shows a closed-Friday week
   deciding nothing, states that `saturday` and `sunday` decide only on venues
   open on those days, explains that weekday resolution never crosses into the
   following week, pins `Strategy schedule: wednesday` and
   `Strategy schedule: month day 15` as the two representative display labels,
   and distinguishes `month_day(1L)` from `month_start()` at the parent-axis
   start.

The implementation review walks the seven optimization shapes on the changed
compiler code. No benchmark gate is required beyond showing that compilation
is linear in the parent session axis and absent from pulse execution; these
rules do not introduce a new runtime mechanism.

## 7. Rejected alternatives

### Require users to generate explicit dates

This is possible today and remains useful for uncommon finite schedules. It is
rejected as the only UX for these two recurring rules because it obscures
intent, duplicates civil-date construction and persists the expansion rather
than the authored recurrence.

### Accept an arbitrary scheduling function

Rejected. It would reopen preflight, serialization, worker transport,
deterministic identity and causal-calendar review for a problem covered by two
small tagged declarations.

### Snap across recurrence periods

Rejected. A Friday anchor becoming Monday or a monthly anchor becoming a date
in the following month silently changes the declared cadence. A period with no
valid open session contributes no decision instead.

### Clamp missing month days to month end

Rejected. `month_day(31)` should not silently mean February month-end while
meaning the 31st elsewhere. `ledgr_schedule_month_end()` already expresses the
month-end rule directly.

## 8. Proposed routing

If accepted, a new cut after Cut 21 closes owns one small scheduler-extension
ticket. It owns both constructors, compiler cases, identity and recovery
parity, help, teaching and the detecting matrix above. It does not reopen Cut
21, its decisions or Workstreams 60 through 63, and it does not claim their
evidence for the new rules. The new cut's decision records the ten-name public
family and supersedes only Cut 21's closed eight-name family record.

Acceptance appends a dated amendment notice to the parent synthesis Sections 2,
3 and 5 with its supersession table, records this amendment in a new scheduler
row of `../decisions.md`, and links it from the implemented scheduler redirect
in `README.md`. No contract wording changes until the implementation ticket
lands.

## 9. Questions for adversarial review

1. Are these two recurrence forms common enough to justify public helpers
   instead of leaving them to explicit dates?
2. Are period-local forward resolution and absent-period behavior the least
   surprising rules for equities and continuously traded assets?
3. Is the strict lower-case weekday vocabulary preferable to accepting aliases
   that must be normalized and identified?
4. Is keeping declaration version 1 consistent with the repository's current
   format policy, given that the tagged shape is unchanged and unknown type IDs
   already refuse?
5. Does excluding parameterized weekday/month-day rules leave a material hole,
   or correctly keep this amendment narrow?
6. Can any implementation bypass the existing identity or orchestration paths,
   or cause calendar work to re-enter the pulse loop?

## 10. Revision history

- **2026-10-26:** initial draft for Type 2 review.
- **2026-10-26:** applied the Type 2 ACCEPT_AFTER_PATCHES findings: bound the
  unproved first-parent-period rule, corrected the additive-tag format
  rationale, normalized whole-number month days in the validator, named every
  closed-set dispatch seam, recorded the typed future parameter route, expanded
  holiday teaching and routed implementation to a new cut after Cut 21.
- **2026-10-26:** focused confirmation returned PASS; the maintainer accepted
  the amendment and routed its one implementation ticket to Cut 22.
