# Workstream 60 close review

**Mode:** Type 1 close review, independent clean-context Claude Opus session.

**Range:** `42ddf3aa..5e88c562`.

**Verdict:** `PASS_AFTER_PATCHES`.

The reviewer found the schedule architecture and production compiler semantics
sound. It reproduced declaration identity, calendar behavior, both pre-fold
construction sites, dense refusal, the fixture aggregates and the diagnostic
clock. Seven findings required focused correction or an explicit record.

1. The parent-axis behavior was correct but the tests did not distinguish it
   from a window-truncated axis at true start and end boundaries.
2. Unscheduled live candidates gained explicit `NULL` schedule fields, contrary
   to LDG-3110's byte-shape requirement.
3. Identity tests varied schedule types but did not prove that date or parameter
   arguments independently change schedule and config hashes.
4. Malformed textual dates could fail without the registered condition, accept
   trailing text, or carry an unrecognized top-level field.
5. The intraday condition detected duplicated timestamps but not two distinct
   timestamps assigned to one session.
6. Invalid parameter tokens refuse before the fold but may leave a failed run or
   candidate; WS62 owns earlier orchestration validation.
7. The closeout did not disclose that a sweep compiles once per candidate. This
   is required because the schedule may resolve from candidate parameters and
   remains outside the pulse loop.

The correction must pin literal parent-axis edge masks, omit absent candidate
fields, distinguish argument identity, validate declaration shape and canonical
dates, classify distinct same-session pulses, and correct the seven-shape
record. A focused independent re-review is required before acceptance.
