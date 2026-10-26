# Workstream 60 focused re-review

**Mode:** focused Type 1 re-review, independent clean-context Claude Opus
session.

**Range:** `5e88c562..cc6428c4`.

**Verdict:** `CHANGES_REQUIRED`.

Six of the seven original findings were closed. The strengthened declaration
shape check introduced one blocking regression: canonical JSON orders object
keys as `args`, `type_id`, `version`, while the validator required constructor
order. A completed scheduled run therefore failed reopening through
`ledgr_run_open()` with `ledgr_invalid_run`, caused by
`ledgr_invalid_strategy_schedule`.

The final correction must require exactly the three unique declaration keys
without requiring their order. It must pin every declaration shape through the
native canonical JSON writer and nested reader and pin a completed scheduled
run through public reopening. The low observation that an off-close weekend
pulse may receive the intraday rather than axis-invalid child does not block:
both inputs refuse, and current public execution pulses are exact session
closes.

The reviewer reproduced all five recorded mutations, compared unscheduled
candidate names with the pre-cut tree, verified scheduled candidate fields and
argument identity, ran seven focused suites, parsed both YAML records and found
the correction diff clean. A final focused confirmation remains the Workstream
60 acceptance gate.
