# Common Calendar Schedule Closeout

**Cut:** 22. **Workstream:** 64. **Ticket:** LDG-3115.
**Implementation:** `0bd1ad01` on `v0.2.2`.
**Status:** Awaiting independent Type 1 close review.

## Result

`ledgr_schedule_weekday(day)` and `ledgr_schedule_month_day(day)` are public
version-1 declarations on the existing strategy-schedule compiler. They add no
fold path, persisted mask, parameter grammar, store version or orchestration
format. Both retain their normalized argument in authored and resolved
identity.

The compiler maps each anchor to the first declared open session on or after
it inside the same Monday-Sunday week or calendar month. It never crosses a
period. An anchor before the first open session on the parent axis is unproved
and contributes no decision. Existing fixed, date and parameter behavior is
unchanged.

## Detecting Evidence

- LCL-0501/LTB-0510 covers all seven weekday tokens, a closed anchor, no
  later open session, seven-day venues, partial executable windows, the two
  first-parent-period outcomes, month days 1, 15, 28, 29, 30 and 31 across a
  leap year and short months, typed refusals, integer normalization, labels,
  JSON round trips and distinct identities.
- The seven pre-Cut-22 declarations are pinned to literal canonical JSON and
  SHA-256 values captured from detached commit `946078d9`; all are unchanged.
- LCL-0502/LTB-0511 carries `weekday` through an independent public run,
  two-worker sweep, save/reopen and promotion, and carries `month_day` through
  a real walk-forward candidate and reproduction key. Run and sweep economics
  agree.
- The shared generated help and the executable Strategy Authoring Tools
  article teach Wednesday, month day 15, a closed Friday, weekend-only venues,
  same-month resolution and the parent-start difference from month start.

## Optimization-Shape Walk

| Shape | Result |
| --- | --- |
| one-row frames | absent; the compiler constructs no per-session frames |
| full-table subset in an ID loop | absent; there is no instrument loop |
| per-element parse or format | absent; month keys and anchors are vectorized once before the fold |
| per-row JSON | absent; canonical JSON remains one declaration-level identity operation |
| discarded or repeated work | absent; compilation remains once per resolved execution specification |
| quadratic validator | absent; validation is scalar and compiler work is linear in parent sessions |
| environment-held scalar writes | absent; due masks and temporary vectors are locally owned |

The compiler contains no R loop over sessions, locale weekday formatter,
suffix dispatch or pulse-time calendar work. Its new vectors are bounded by
the parent open-session axis and are discarded with the compiled execution
specification.

## Verification

- `test-strategy-schedule.R`: 330 expectations, zero failures or skips.
- `test-api-exports.R`: 21 expectations; `test-documentation-contracts.R`:
  1,084; `test-test-control-plane.R`: 76; all pass.
- The strategy-authoring vignette executes all 49 chunks and renders its
  tracked Markdown output.
- Codebase contract check, fold-phase check, both YAML files and
  `git diff --check` pass.
- A source build followed by `R CMD check --no-manual --no-build-vignettes`
  passes all tests and executes all 26 vignettes. It reports the two expected
  no-built-vignette warnings and the pre-existing unqualified `head` NOTE.
  A final static check after removing Cut 22's temporary `head`/`tail` use
  reports only that pre-existing NOTE.

