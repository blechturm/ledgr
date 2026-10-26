# Workstream 60 closeout: schedule declarations and preparation

## Outcome

LDG-3109 and LDG-3110 add the declaration and preparation half of ledgr's
strategy scheduler. A strategy can now carry a validated schedule declaration;
run, sweep, window and walk-forward preparation compile that declaration once
against the authoritative parent venue-session axis and place one aligned
logical verdict plus its counts in the execution specification.

This workstream does not skip callbacks. Workstream 61 will teach the existing
five-stage fold to consume the prepared verdict and will add current-format
persistence. Workstream 62 owns saved sweeps, parallel transport, promotion and
walk-forward formats.

## Public declaration surface

`ledgr_strategy_schedule()` adds class `ledgr_scheduled_strategy` and one
`ledgr_schedule` attribute to the supplied function. It does not wrap the
function or create a cursor. The version-1 constructors are month start, month
end, Monday-based week start, quarter start, year start, explicit civil dates
and one scalar strategy-parameter reference. The parameter menu resolves only
to the five fixed schedules.

The decorator preserves the function body and environment. The declaration is
ordinary JSON-safe data and round-trips without capturing another function.
Nested decorators, malformed declarations and non-functions refuse.

## Compilation boundary

`ledgr_compile_strategy_schedule()` consumes the validated declaration,
resolved strategy parameters, the declared status-open parent sessions ordered
by session close, and the executable pulses. It returns one no-missing logical
vector and exact decision/skip counts. An absent private declaration returns
`decision_due = NULL`, meaning ordinary every-pulse behavior without allocating
a same-length mask or writing a public null field.

Start boundaries require a real predecessor and end boundaries a real
successor on the parent axis. A run-window edge therefore manufactures no
boundary. Explicit in-range dates snap forward to the next open session and
deduplicate. Dates outside the closed parent range refuse. The compiler binds
Monday weeks with integer-date arithmetic and does no locale formatting.

The typed condition children are:

- `ledgr_schedule_sessions_required` for no declared session axis;
- `ledgr_schedule_axis_invalid` for duplicate or misaligned axes;
- `ledgr_schedule_intraday_unsupported` for multiple pulses per session;
- `ledgr_schedule_date_out_of_range` for dates outside the parent range; and
- `ledgr_schedule_param_unresolved` for every invalid parameter form.

All inherit `ledgr_invalid_strategy_schedule` and are indexed in the public
condition reference.

## Identity boundary

Schedule metadata is removed before registry fingerprinting, source capture
and preflight. Two decorators around the same inner function retain the same
registry key, source text and hash, capture method, call signature and tier.
The canonical declaration instead enters the top-level config and therefore
run identity. Live sweep results and selected candidates carry the canonical
declaration and its independent hash in memory. Compiled verdicts do not enter
identity.

An ordinary unscheduled function is returned untouched by the stripping helper.
This detail is load-bearing: the first fixture record found that setting and
then removing attributes left an explicit `class = "function"` in deparsed
source. The correction returns early for ordinary functions and removes that
explicit class when recovering the inner function.

## Detecting evidence

- LCL-0492 / LTB-0501 pins all constructors, body and environment identity,
  declaration serialization, malformed declarations and nested decoration.
- LCL-0493 / LTB-0502 uses literal session tables for every fixed rule,
  date snapping, partial windows, every parameter token, exact counts and all
  typed refusals. Structural assertions reject bar input, locale formatting and
  an R loop in the compiler.
- LCL-0494 / LTB-0503 compares unscheduled, month-start and year-start strategy
  specifications and pins stripping at registry, source and preflight owners.
- LCL-0495 / LTB-0504 counts the compiler through public run, sweep, window and
  walk-forward construction, checks live schedule identity and dense refusal,
  and proves no fold stage compiles a schedule.

Mutation checks detected a manufactured first-axis start, a constant live
schedule hash and a sweep compiler bypass. The identity fixture itself detected
the subtler unscheduled-function attribute mutation and stayed red until the
source and walk-forward identity returned to their pre-cut bytes.

## Seven-shape walk

The compiler constructs no row-at-a-time frames, performs no full-table subset
inside a pulse loop, parses and orders timestamps once, writes no per-row JSON,
does no quadratic validation, and mutates no vector through an environment.
Date snapping uses `findInterval()` over atomic date vectors. Run construction
compiles once and sweep construction compiles once per candidate because a
parameterized schedule can resolve differently for each candidate; neither
compiles in the pulse loop. Fold stages only receive prepared primitives. The
execution spec and live-candidate metadata add fields only when a schedule
exists, preserving the unscheduled list shape.

The bounded 7,213-session compiler clock in
`dev/bench/v0_2_2_strategy_schedule/README.md` records a 0.030-second median.
It is diagnostic support for placement, not a release speed claim.

## Verification before close review

The registered real-data-scale fixture compares pre-cut `42ddf3aa` with
candidate `8c5cbc39`: 50/50 gated families and the informational identity
family are byte-identical. The checker detects 51/51 isolated corruptions.
Durable aggregate hashes and phase clocks are under
`dev/bench/v0_2_2_strategy_schedule/evidence/ws60/`.

The focused schedule, export, config, config-object, execution-spec, strategy
preflight, sweep, documentation-contract and test-control-plane suites pass.
The codebase census runs and the fold-phase checker prints
`LEDGR_FOLD_PHASE_CONTRACT_OK`. `git diff --check` is clean. The independent
Type 1 close review remains the workstream acceptance gate.

## Close-review correction

The first independent review returned `PASS_AFTER_PATCHES`. Correction
`791f6e38` removes the two explicit `NULL` schedule fields from unscheduled
live candidates, makes declaration names and civil-date text exact, classifies
two distinct pulses assigned to one session as unsupported intraday input, and
strengthens the parent-axis and identity detectors.

Five disposable mutations were detected by the registered schedule suite:

- truncating the parent axis to the visible pulse range failed five literal
  boundary and date assertions;
- restoring explicit `NULL` candidate fields failed two assertions;
- hashing only the declaration type failed both argument-identity assertions;
- accepting an extra declaration field failed the malformed-input assertion;
- removing distinct same-session pulse classification failed the typed
  intraday assertion.

The corrected focused schedule, sweep, config, execution-spec, preflight,
export and control-plane suites pass. The independent focused re-review remains
the acceptance gate.
