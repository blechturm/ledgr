# Type 2 Review: Common Civil-Calendar Schedules Amendment

**Mode:** Type 2 design review, adversarial.
**Date:** 2026-10-26.
**Reviewer:** Claude, in a session other than the amendment author's.
**Artifact reviewed:**
`rfc_strategy_schedule_common_calendar_amendment.md` (draft of 2026-10-26,
222 lines).
**Reviewed tree:** `c7267173` on `v0.2.2` (Cut 21 open; Workstreams 60
through 62 accepted, Workstream 63 evidence recorded, close review pending).
**Verdict:** **ACCEPT_AFTER_PATCHES**.

Read: `AGENTS.md`; `rfc_cycle.md`; the amendment; the accepted scheduler
synthesis and maintainer decisions; `contracts.md` entry-point, fold-core,
execution-identity, candidate, current-format, canonical-JSON and store-gate
groups; `R/strategy-schedule.R`; `R/backtest-runner.R:1252-1261`;
`R/sweep.R:1746-1761`; Cut 21 and LDG-3109 through LDG-3114 in
`tickets.yml`; registered claims LCL-0421 and LCL-0492 through LCL-0500;
`tests/testthat/test-strategy-schedule.R`; the Momento application case in
`portfolio_method_ux_exercises.md`.

Probe: one script sourcing `R/strategy-schedule.R` into a plain R session
compiled `ledgr_schedule_dates()`, `ledgr_schedule_week_start()` and an
out-of-range date against a synthetic declared axis (2024-03-25 to
2024-04-12, Good Friday 2024-03-29 and Wednesday 2024-04-03 closed), and
wrote `15L` and `15` through yyjsonr with the contract's options. No
package build, no store, nothing in the repository changed.

## 1. Necessity

The gap is real and the draft's two helpers are the smallest honest fill.

- The public workaround cannot express the proposed semantics. Expanding
  civil Fridays and passing them to `ledgr_schedule_dates()` compiled to
  `2024-04-01, 2024-04-05, 2024-04-12` on the probe axis: Good Friday
  snapped to the following Monday, which is exactly the cross-period
  resolution the amendment rejects. A user who wants period-local behavior
  must filter their civil dates against the open axis themselves.
- The workaround also makes the user own the axis range. A civil date past
  the axis refused with `ledgr_schedule_date_out_of_range`
  (`R/strategy-schedule.R:501-505`), so a generated "every Friday" vector
  must be clipped to the snapshot's exact open range or the whole run
  refuses.
- `ledgr_sweep(exp, param_grid)` (`R/sweep.R:93`) runs one experiment, so
  one strategy and one schedule per sweep. A date vector is data, not a
  recurrence; it cannot be reused across snapshots with different ranges.
- The corpus already carries the weekday cadence as an acceptance case:
  Momento decides on a signal weekday (`portfolio_method_ux_exercises.md`,
  input 2; synthesis D13). A mid-month monthly cadence is the ordinary
  "rebalance on the 15th" variant of the monthly rules the H1 workload uses.
- The existing fixed rules are transition rules (predecessor or successor in
  a different period). An anchor rule is a different primitive; neither
  `week_start` nor `month_start` can be composed into it.

The draft is therefore necessary and correctly small. It is not safe to
accept as written: its semantics are silent on the parent axis's own first
partial period, its format rationale argues from policy rather than from the
repository's actual gate mechanism, and its argument normalization,
dispatch seams and routing are under-specified. All of these are focused
corrections.

## 2. Findings

### F1 - High: the parent axis's first partial period can manufacture a decision

**Section:** 3, paragraphs 2 to 5; Section 6, items 1 and 2.

**Failure.** "The decision is the first open session on or after that
anchor" is provable only when every civil date from the anchor to that
session is covered by the declared axis. The draft addresses partial first
*run windows* ("A run that begins after the resolved decision ...") but not
the parent axis's own first period. Example: a declared axis beginning
Thursday 2021-01-14 with `ledgr_schedule_month_day(1L)`. The first open
session on or after 2021-01-01 inside January *on the axis* is 2021-01-14,
so the draft decides on the 14th although nothing declares the 1st through
the 13th closed. The same axis with `ledgr_schedule_weekday("wednesday")`
decides on Thursday the 14th with Wednesday the 13th undeclared. That is
the false first boundary accepted D1 and synthesis D3 forbid for the fixed
rules ("the first parent-axis session is not automatically a period
start"), and the probe shows the shipped compiler honoring it: on an axis
beginning Monday 2024-03-25, `week_start` first fires on 2024-04-01.

**Smallest correction.** Add to Section 3 after the month paragraph:
"An anchor earlier than the first parent-axis open session is unproved: the
absence of an open session between the anchor and the axis start is not
declared, so that period contributes no decision. An anchor on or after the
first open session resolves normally, including on that first session when
it falls on the anchor date." Change Section 6 items 1 and 2 to name both
"a parent axis beginning after the anchor" and "a run window beginning after
the resolved decision" as separate cases, with the first expected to decide
nothing and the second expected not to decide again.

Record the one visible consequence rather than hiding it:
`ledgr_schedule_month_day(1L)` decides on an axis whose first open session
is the 1st, while `ledgr_schedule_month_start()` does not, because the
anchor rule proves its decision from the anchor date and the transition
rule needs a predecessor. Help text states this.

**Classification.** Changes the draft's implied product semantics. The
correction follows the accepted D1 reading; it needs no new maintainer
decision unless the maintainer prefers the window-start reading, which
would contradict D1 and reopen the synthesis.

### F2 - Medium: the no-bump decision is right, its rationale is not the repository's mechanism

**Section:** 4, paragraphs 2 and 3.

**Failure.** The draft argues from "type_id is already the semantic
discriminator". The repository's actual format boundary is different, and
checking it changes what a bump would even do:

- The store format fingerprint enumerates namespace bindings matching
  `^ledgr_[a-z_]+_(schema|rule)_version$` (contracts, Store And Codebase
  Gates). `ledgr_schedule_version <- 1L` (`R/strategy-schedule.R:91`) does
  not match, so the declaration version is a per-record marker only and
  never part of the store gate.
- The schema-124 catalogue pins the columns `run_provenance.schedule_json`
  and `schedule_hash` (`tests/testthat/fixtures/schema-current-golden-rows.csv`),
  not their vocabulary. `contracts.md` nowhere enumerates the type IDs.
- The precedent the draft would need to distinguish, D7's `scheduled_skip`,
  extended a vocabulary the contract tables as "closed for this schema"
  (contracts, availability reason codes) and landed in the same change as
  new DDL columns. No such closure sentence exists for schedule types.
- Downgrade direction: an older implementation reading a `weekday` record
  refuses in `ledgr_schedule_validate()` (`:126-131`) and
  `ledgr_strategy_schedule_from_json()` wraps it in
  `ledgr_schedule_identity_mismatch` (`:306-315`). Fail-closed, as claimed.
- A declaration bump to version 2 would *not* produce "older stores refuse":
  the store gate passes, every version-1 scheduled run refuses per record
  (`:130`), unscheduled runs read normally. That half-refusal is not what
  the pre-CRAN policy describes, and the only coherent bump shape is store
  schema 125 plus the five orchestration versions, which the draft already
  forbids doing partially.

The operative test is whether any existing stored byte is reinterpreted.
It is not: existing declarations keep their bytes, hashes, meaning and
readers. Adding a tagged variant is additive. Section 4's conditional
("If review concludes ...") is resolved: it is not triggered.

**Smallest correction.** Replace paragraph 2 with the mechanism: the
declaration version is a per-record marker outside the store fingerprint;
the catalogue and contracts pin no type vocabulary; adding a variant
reinterprets no stored byte. Bind the rule in the same paragraph: "The
declaration version bumps when the encoding or meaning of an existing
variant changes. Adding a variant does not bump it. If a store-level bump
is ever owed it is the store schema and every orchestration version
together, never the declaration version alone." Add to Section 6: the
implementation ticket records the accepted type set in the contracts'
current-format group as the version-1 set under that rule.

**Classification.** Repairs rationale and evidence; confirms the product
decision.

### F3 - Medium: integer normalization must live in the validator, not only the constructor

**Section:** 2, month-day paragraph; Section 4, "single normalized
argument"; Section 6, item 4.

**Failure.** Canonical JSON version 2 writes whole-number doubles with a
decimal suffix (contracts, canonical JSON). The probe confirms:
`list(day = 15L)` encodes as `{"day":15}` and `list(day = 15)` as
`{"day":15.0}`; `{"day":15}` reads back as integer. If only the constructor
coerces, a declaration that arrives as a double through any other door (a
hand-built list, a worker payload, a JSON value written as `15.0`) hashes
differently from the stored hash and refuses with
`ledgr_schedule_identity_mismatch`. The validator already normalizes
`version` by reconstruction (`:128-130`, `:159`) and `dates` by
reformatting (`:152`); `day` needs the same treatment. Section 2's "accepts
exactly one non-missing integer" also reads as refusing `15`, which is
what R users type.

**Smallest correction.** Section 2: "accepts one non-missing whole number
from 1 through 31, supplied as integer or double, and stores it as
integer." Section 4: "The validator re-stamps `day` as integer before
hashing, so constructor, worker transport and stored JSON produce one
byte sequence." Section 6, item 4: add "`ledgr_schedule_month_day(15)` and
`ledgr_schedule_month_day(15L)` produce identical bytes and hashes, and a
declaration read from canonical JSON reproduces its stored hash."

**Classification.** Repairs wording and evidence.

### F4 - Medium: four dispatch seams assume the closed type set and are not named

**Section:** 3 (compiler), 4 (identity), 6 (evidence).

**Failure.** The draft says the rules "use the existing compiler" but
does not name where today's code dispatches on the fixed set. Each is a
place an implementation can go wrong silently:

- `ledgr_schedule_validate()`: the type allowlist (`:127`) and the rule
  that fixed types carry no arguments (`:133`). The new types carry one
  argument and need their own exact branch: one key `day`, accepted in
  either key order (the Workstream 60 re-review lesson at `tickets.yml`
  line 863 was an ordered-name check that broke reopening).
- `ledgr_compile_strategy_schedule()` dispatches on `grepl("_start$")`
  else end-rule (`:515-519`), and `ledgr_schedule_period_key()` aborts on
  any other type (`:409`). Anchor rules need explicit branches, vectorized
  (period key plus eligibility mask plus `!duplicated()`), linear in the
  axis.
- `ledgr_compile_strategy_schedule()` builds `resolved_schedule` with
  arguments only for `dates` (`:526`). For `weekday` and `month_day` it
  would silently return an argument-less rule. Neither call site reads that
  field today (`R/backtest-runner.R:1252-1261`, `R/sweep.R:1748-1760` use
  `decision_due` and the counts; identity flows from
  `ledgr_strategy_schedule_identity()`, `:178-193`, which keeps the
  declaration), so this is latent, not live. The ticket carries the
  arguments there or removes the field.
- `ledgr_strategy_schedule_label()` falls through to the parameter label
  for any unlisted type (`:265-282`). Cut 21 decision (5) pins
  `Strategy schedule: <label>`, so the two new labels are a spec-cut choice
  the ticket must pin.

`ledgr_schedule_resolve_type()` (`:422`) stays fixed-only, which matches
Section 5.

**Smallest correction.** Add one sentence to Section 3: "The validator,
compiler dispatch, period-key helper, compiler `resolved_schedule` field
and print label each gain an explicit branch; no branch infers behavior
from a name suffix." Extend Section 6, item 4, with the `resolved_schedule`
field and item 7 with the two pinned labels.

**Classification.** Repairs evidence; no product decision changes.

### F5 - Medium: the parameter exclusion should name its trigger and its non-grammar shape

**Section:** 5, paragraph 1.

**Failure.** The exclusion is right today, and I reject every token grammar
(`weekday:wednesday`, menu tokens that double as arguments). But the draft
leaves the next author to invent one. The one plausible sweep need is
already visible: varying the decision day of a monthly strategy to measure
rebalance-timing dispersion, on exactly the monthly workload Cut 21's H1
record uses. Because a sweep has one schedule (Section 1 above), that study
today needs one sweep per day value.

**Smallest correction.** Add to Section 5: "Known trigger: a research
request to vary the decision weekday or day of month across candidates of
one sweep. The accepted shape then is a typed parameter reference accepted
by each constructor's `day` argument and resolved from ordinary strategy
parameters before the fold, with identity through the resolved declaration
as D10 already binds; not a token grammar in
`ledgr_schedule_from_param()`."

**Classification.** Repairs wording; records a future route; no product
decision changes.

### F6 - Low: two deterministic traps need stating, not discovering

**Section:** 2, 3 and 6 item 7.

**Failure.** Both are consequences of rules I accept, but a user meets them
on the first holiday:

- `ledgr_schedule_weekday("friday")` on a week whose Friday is closed
  decides nothing that week. The practitioner's "last session of the week"
  is the week-end rule Cut 21 decision (1) declined, not this helper.
- `ledgr_schedule_weekday("saturday")` or `("sunday")` on a five-day axis
  resolves to zero decisions: a flat run refuses with
  `ledgr_schedule_no_decision` (`R/sweep.R:1754-1761`) and a carried run
  holds silently through D9. Correct, and worth one sentence.

**Smallest correction.** Section 6, item 7: "Teaching shows a closed-Friday
week deciding nothing and states that `saturday` and `sunday` only decide
on venues that open those days." Help text for the weekday helper says
"the next open session in the same week, never the following week".

**Classification.** Repairs wording.

### F7 - Low: routing names no cut and edits a closed decision

**Section:** 8; header "Would amend if accepted".

**Failure.** "One small scheduler-extension ticket after Cut 21's current
implementation is accepted" does not say which cut owns it. Cut 21 decision
(1) fixes the family at eight names, and Workstream 63's closeout
(`strategy_scheduler_closeout.md`) describes that family; adding a ticket
to Cut 21 would reopen the workstreams the amendment says it does not. A
cut's decision is a record; a later cut's decision supersedes it rather
than amending it in place. The header should also name the governance
supersession mechanics the cycle requires for an accepted amendment.

**Smallest correction.** Section 8: "If accepted, a new cut after Cut 21
closes owns one ticket." Header: "Acceptance appends a dated amendment
notice to synthesis Sections 2, 3 and 5 with the supersession table, adds a
`decisions.md` row and updates the scheduler redirect in `README.md`; the
owning cut's decision records the ten-name family." Drop "and the
corresponding public-family decision in Cut 21".

**Classification.** Repairs routing wording.

## 3. Disposition of every decision in Sections 2 through 6

| Section | Decision | Disposition |
| --- | --- | --- |
| 2 | Exactly two constructors; no generic recurrence or user function | Accept |
| 2 | Signatures `ledgr_schedule_weekday(day)`, `ledgr_schedule_month_day(day)` | Accept; names follow the family-first rule R1 |
| 2 | Weekday token: one exact lowercase English name, seven values, no locale, no aliases, no numbers | Accept (see Section 4 below) |
| 2 | Month day: one integer 1 through 31 | Accept after F3 (whole number in, integer stored) |
| 2 | A month without the numbered day has no anchor; `month_end` is the last-session rule | Accept |
| 2 | Version-1 declarations with type IDs `weekday` and `month_day`; decorator unchanged | Accept after F2 wording |
| 3 | Compile once, pre-fold, on the status-open parent axis ordered by close | Accept; matches D2 and `:461-468` |
| 3 | Monday-to-Sunday week period, named weekday anchor, first open session on or after it within the week | Accept; week key is D3's `(as.integer(date) - 4) %/% 7` at `:399` |
| 3 | Calendar-month period, numbered-day anchor, first open session on or after it within the month | Accept |
| 3 | A period with no valid session contributes no decision; no cross-period snap | Accept; the probe shows the dates helper does the opposite, which is why the rule must be stated |
| 3 | One anchor per period, so no duplicate verdicts; same vector shape | Accept |
| 3 | Full parent axis decides boundaries; run-window partial periods manufacture nothing | Accept, incomplete: F1 adds the parent-axis first-period rule |
| 3 | Zero-decision rule unchanged (D9) | Accept |
| 4 | Declaration records the type ID and one normalized argument | Accept after F3 |
| 4 | Enters config, provenance, recovery, promotion, sweep, walk-forward and worker surfaces unchanged | Accept; F4 names the one latent compiler field |
| 4 | Declaration stays version 1; no enclosing format bumps; tag set expansion is additive | Accept; F2 replaces the rationale and binds the rule |
| 4 | Conditional revise clause | Resolved: not triggered |
| 5 | `ledgr_schedule_from_param()` unchanged; no grammar; no structured parameter objects | Accept after F5 names the trigger and shape |
| 5 | Exclusion list (week-end, quarter-end, nth weekday, offsets, holiday policy, cron, intraday, mask) | Accept |
| 5 | Explicit dates remain the escape hatch | Accept, with the probe caveat in Section 1 recorded in help |
| 6 | One implementation ticket; seven evidence items | Accept after F1, F3, F4 and F6 additions |
| 6 | Seven-shape walk on the compiler; no benchmark gate; compile linear and absent from the loop | Accept; the existing LCL-0493 and LCL-0495 detectors already own the loop and axis properties |

## 4. Review questions

1. **Necessity.** A gap; see Section 1. `ledgr_schedule_dates()` is the
   right abstraction for finite, irregular schedules and the wrong one for
   a recurrence: it snaps across periods, binds the user to the axis range
   and persists an expansion instead of an intent.
2. **Rule semantics.** Period-local forward resolution is deterministic
   and, with F1, provable from declared facts alone. Case table on the
   probe axis and by reasoning:
   - Wednesday holiday (2024-04-03): `weekday("wednesday")` decides
     Thursday 2024-04-04.
   - Friday holiday (2024-03-29): `weekday("friday")` decides nothing that
     week; `weekday("thursday")` is unaffected.
   - No session after the anchor (Thursday anchor, Thursday and Friday
     closed): nothing that week.
   - 15th on a weekend: the following Monday, or the next open session
     after a Monday holiday; never the next month.
   - `month_day(29)`: February only in leap years. `month_day(30)`: not
     February. `month_day(31)`: seven months, and a Saturday 31st decides
     nothing that month. Deterministic; teaching points to `month_end`.
   - Partial first and last periods: F1 for the axis; run windows slice
     the parent verdict as today.
   - Seven-day venues: the anchor day itself, every period.
3. **Public inputs.** Exact lowercase English tokens are the right single
   representation. ISO integers invite the three weekday conventions R
   users already juggle (`%u` Monday = 1, `%w` Sunday = 0, lubridate
   Sunday = 1) and hide an off-by-one inside JSON. Case normalization
   creates two public spellings of one declaration for no gain. Locale
   output from `weekdays()` refuses with a message naming the seven
   tokens, which is the safe outcome.
4. **Format.** No bump; F2 gives the mechanism and binds the rule.
5. **Parameterization.** Narrow and correct; F5 records the trigger and
   the shape that avoids a grammar.
6. **Containment.** Holds. Both construction sites call the one compiler
   outside the loop; identity, persistence, recovery, promotion,
   walk-forward and workers consume the declaration, never the rule type.
   F4 names the four seams; none is a second scheduler or pulse-time work.
7. **Scope.** A focused amendment is the right route; see Section 5.

## 5. Scope route

This is a legitimate focused amendment, not a new RFC cycle. It adds two
tagged variants to an accepted declaration format and two names to an
accepted family, under the accepted compiler, identity, persistence and
skip semantics. It changes no contract rule group's semantics: the
entry-point group's scheduler paragraph describes compile-once gating that
is unchanged, and the current-format group gains an enumeration, not a
version. The history-manifestation amendment is the repository's precedent
for exactly this route: a focused amendment, its own Type 2 review, focused
confirmation, maintainer acceptance, one owning ticket. It would need a
full cycle only if the maintainer chose cross-period or backward
resolution, aliases, a parameter grammar or a format bump, each of which
reopens a parent decision.

## 6. Rejected alternatives worth retaining

- **Cross-period snapping.** Rejected by the draft; the probe shows it is
  what `ledgr_schedule_dates()` does, which is the strongest reason to say
  the new rules do not.
- **Backward or nearest resolution within the period.** Rejected: it moves
  a declared decision earlier than its anchor. Retained because it is what
  a Friday user wants on a Friday holiday; that need is the week-end rule,
  separately declined in Cut 21 decision (1) and reopenable only with
  evidence.
- **Clamp absent month days to month end.** Rejected by the draft; agreed.
- **ISO integer or case-normalized weekday input.** Rejected; Section 4,
  question 3.
- **A vector `day` for several anchors per period.** Rejected now; retained
  as the additive route for "Monday and Thursday" cadences. It changes the
  variant's argument shape, so it is a new variant or a declaration-version
  decision, not a silent widening.
- **A token grammar or menu extension in `ledgr_schedule_from_param()`.**
  Rejected; the typed parameter reference in F5 is the shape to use when
  the trigger arrives.
- **Declaration version 2 or store schema 125.** Rejected by F2; retained
  as the only coherent shape if the maintainer ever decides a vocabulary
  extension is a format change.

## 7. Detecting evidence the ticket cut must own

Extend the existing claims rather than add parallel ones; LCL-0493's oracle
rule (literal masks derived from named civil dates, never another
scheduling helper) applies to every item.

1. **Weekday matrix** (LCL-0493): every token on a declared five-day axis
   with closed rows; a closed anchor resolving to the next open session in
   the same week; anchor-through-Sunday closed deciding nothing; an axis
   beginning after the anchor in its first week deciding nothing; an axis
   beginning on the anchor day deciding on its first session; a last
   partial week; a seven-day axis deciding on the anchor day; `saturday`
   on a five-day axis compiling to zero decisions, refusing a flat run with
   `ledgr_schedule_no_decision` and completing a carried run.
2. **Month-day matrix** (LCL-0493): 1, 15, 28, 29, 30 and 31 across a
   leap February, a non-leap February and a 30-day month; the 15th on a
   weekend and on a Monday holiday; a Saturday 31st deciding nothing; an
   axis beginning after the 1st with `month_day(1L)` deciding nothing until
   the next month; an axis beginning on an open 1st deciding on it, pinned
   beside `month_start` deciding nothing on the same axis.
3. **Identity** (LCL-0494): `weekday("monday")` versus `("friday")` and
   `month_day(1L)` versus `(15L)` differ in bytes, hash, config identity
   and live-candidate identity; `month_day(15)` equals `month_day(15L)`; a
   declaration read back from canonical JSON reproduces its stored hash;
   the compiler's `resolved_schedule` carries the argument; the mutation
   "ignore a schedule argument when deriving identity" fails.
4. **Byte pins:** the canonical JSON and hash of each of the eight existing
   declaration forms are unchanged against the pre-ticket tree.
5. **Refusals** (LCL-0492): `Wednesday`, `wed`, `3`, `NA`, two tokens, a
   factor; `0`, `32`, `15.5`, `"15"`, `NA`, `c(1, 15)`; each refuses under
   `ledgr_invalid_strategy_schedule` before fold entry with a message
   naming the accepted tokens or range; stored JSON with an unknown
   `type_id` refuses with `ledgr_schedule_identity_mismatch`.
6. **Orchestration parity** (LCL-0495, LCL-0499): each new rule through
   `ledgr_run()`, a one-candidate and a two-worker `ledgr_sweep()`, saved
   and reopened sweep, reproduction key, promotion and walk-forward, with
   identical verdict vectors at both construction sites and no version
   constant changed.
7. **Structure** (LCL-0493, LCL-0495 lineage): the compiler source
   detector still rejects an R loop over the axis, observed bars, locale
   formatting and `weekdays()`; the compiler call count in P1 through P5
   stays zero; the seven shapes are walked on the changed functions.
8. **Surface pins:** `tests/testthat/test-api-exports.R` export lock,
   `tests/claims.yml`, documentation contracts, NEWS, and the reference
   index. The export-shape audit of 2026-10-26 records that the
   `ledgr_strategy_schedule` topic is not listed in `_pkgdown.yml`; the
   ticket lists it rather than inheriting the gap.
9. **Teaching** (LCL-0500): one executable weekday and one month-day
   example; the closed-Friday week and the weekend tokens stated; help
   names the `month_day(1L)` versus `month_start()` first-session
   difference and that explicit dates snap across periods.

## 8. Release placement

Recommend v0.2.2, as one ticket in a new cut after Cut 21 closes. The
change carries no format bump, no new fold or identity mechanism and no
clock; the compiler, its detectors and the reviewers' context are fresh;
and the no-backward-compatibility window is open. Deferring it to the next
release places it inside the execution-core consolidation, where the
session-axis supply itself changes (dense removal, synthesis Section 8),
and a two-variant addition would then be reviewed against a moving
compiler input. If the maintainer prefers to hold v0.2.2's scope closed,
the next release is acceptable; nothing in the amendment depends on
consolidation and nothing in consolidation depends on it.

## 9. Maintainer decision and next review

One maintainer decision is required: accept the amendment after the
textual patches above and name the owning cut. No product-level binary
choice is open, because F1 follows the accepted D1 reading, F2 confirms
the draft's own format choice and F5 defers the parameter question with a
recorded shape.

A focused confirmation by this reviewer is sufficient after the in-place
patches. It checks the Section 3 first-period sentence, the Section 4
mechanism and rule, the Section 2 and 6 integer wording, the four named
seams, the Section 5 trigger, the Section 6 and 8 wording and the header
supersession note. Another Type 2 round is needed only if the maintainer
chooses window-start resolution, backward or cross-period snapping,
weekday aliases, a parameter grammar or a format bump.

## 10. Focused confirmation

**Date:** 2026-10-26. **Reviewer:** the same session. **Tree:** `c7267173`.
**Artifact:** the amendment as revised on 2026-10-26 (283 lines, ASCII).
**Verdict:** **PASS**.

| Finding | Where incorporated | Check |
| --- | --- | --- |
| F1 first parent-axis period | Section 3, paragraph 4; Section 6, items 1 and 2 | An anchor earlier than the first open session is unproved and decides nothing; an anchor on that session decides there; the parent-axis and run-window cases are separate expected outcomes; the `month_day(1L)` versus `month_start()` difference is stated and gated. |
| F2 format mechanism | Section 4, paragraphs 2 and 3; Section 6, item 4 | Cites the per-record `ledgr_schedule_version` outside the store fingerprint and the vocabulary-free catalogue and contracts; binds "adding a variant does not bump, changing one does"; a store-level bump moves the schema and every orchestration format together, never the declaration alone; the ticket records the version-1 type set in the contracts. |
| F3 integer normalization | Section 2; Section 4, paragraph 5; Section 6, items 4 and 5 | Whole numbers in, integer stored; the validator re-stamps before hashing; `15` and `15L` pinned byte-identical with a JSON round trip; refusals name fractional and non-numeric values. |
| F4 dispatch seams | Section 3, paragraph 7; Section 6, items 4 and 7; Section 8 | Validator, compiler dispatch, period-key helper, `resolved_schedule` and print label each gain an explicit branch under the one ticket; no suffix inference; key-order independence stated; two labels pinned. |
| F5 parameter route | Section 5, paragraph 2 | Trigger named; typed reference through each constructor's `day` argument, resolved before the fold with identity through the resolved declaration; token grammars rejected by name. |
| F6 teaching | Section 6, item 7 | Closed-Friday week, weekend tokens, no cross-week resolution and the first-session difference are concrete obligations. |
| F7 routing | Header; Section 8 | A new cut after Cut 21 closes owns one ticket; Cut 21's record is superseded, not rewritten; the amendment notice, supersession table, `decisions.md` row and README redirect are named. |

No patch introduces a new product decision without a gate, and none
contradicts the accepted synthesis or Cut 21. The artifact remains a focused
amendment. Its routing (one ticket in a new cut after Cut 21 closes, inside
the active packet) matches Section 8 of this review; the release itself stays
the roadmap's call.

Record-only notes, none blocking:

- The pinned labels are asymmetric: `Strategy schedule: wednesday` carries no
  rule name while `Strategy schedule: month day 15` does. The ticket may
  prefer `weekday wednesday`; either satisfies Cut 21 decision (5).
- The first-period rule keys on the first *open* session, as the explicit-date
  range check does (`R/strategy-schedule.R:501`). An axis whose declared first
  row is a closed 1 January therefore decides nothing in January under
  `month_day(1L)`, although the closure is declared. This is conservative and
  consistent with shipped behavior; the ticket's month-day matrix should pin
  that case explicitly.
- Section 6, item 5 does not name an extra or renamed argument key. The
  existing malformed-declaration mutation under LCL-0492 already covers that
  shape for `dates`; the ticket extends it to `day`.

Next step: maintainer acceptance, then the amendment notice, `decisions.md`
row and README redirect named in Section 8 of the amendment, then one ticket
in a new cut after Cut 21 closes.
