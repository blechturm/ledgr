# Workstream 30 Closeout: Current-Only Records And Public Surfaces

**Status:** Close-review corrections implemented; awaiting focused Type 1 re-review.
**Date:** 2026-10-14
**Baseline commit:** `fc4d8fc7`
**Implementation range:** `fc4d8fc7..10c8b444`
**Tickets:** LDG-3028 through LDG-3031

## A. Claim And Boundary

Once the Workstream 29 gate admits a store, every supported record and call
surface now speaks only the current format. There is no migration, older
record reader, missing-marker fallback, compatibility argument or replacement
legacy condition.

The workstream changes four related boundaries:

- LDG-3028 removes record-level legacy branches and requires identity rule 2,
  policy schema 2, timing version 2, saved-sweep schema 4 and snapshot hash
  rule 3;
- LDG-3029 removes obsolete public call forms and unreachable fallbacks;
- LDG-3030 reconciles claims, contracts, conditions, help and teaching with
  the current-only surface; and
- LDG-3031 builds a fresh current-format research store and exercises the
  documented aggregate Sharadar lane without exporting private rows.

This workstream does not redesign current records or results. It does not
remove `ledgr_backtest()`, parameterized strategy factories or the existing
R6 refusal. It adds no compatibility code.

## B. Ticket Commits

| Ticket | Commits | Result |
| --- | --- | --- |
| LDG-3028 to LDG-3030 | `7db5e298` | current-only product, tests, contracts, help and teaching |
| Census refresh | `02167e15` | current source-derived check-mode reports |
| Exactness correction | `b55552e3` | retain the current run-information shape exactly |
| LDG-3031 | `fe95d4e7` | fresh current-format lake and aggregate-only lane record |
| Close-review product corrections | `d9a0306a` | close F1-F9, F11 and F12 with detecting evidence |
| roxygen2 8.1 tooling regeneration | `b538246c`, `b623d758` | upgrade and repin generator-only output |
| F10 documentation correction | `0adbd7b1` | regenerate only the corrected current-only help text |
| Final current-config fixture | `10c8b444` | supply required identities and repin the sweep hash |

## C. Current Record And Call Surface

Current run configuration hashing and validation require identity rule 2 and
`data.snapshot_hash`. Policy identities require their current schema-2
representations. Availability execution timing accepts only version 2.
Saved sweeps accept only schema 4 and retention schema 2. Strategy provenance
and run reopening no longer infer older shapes. Promotion contexts require
version 2. Stored configurations require both `risk_chain` and
`corporate_actions`; only public experiment construction normalizes an
omitted risk declaration. The metric kernel has no context-free result
fallback.

The executable tree no longer contains the six retired condition classes:

- `ledgr_future_schema_version`;
- `ledgr_snapshot_rebuild_required`;
- `ledgr_identity_rule_retired`;
- `ledgr_legacy_fill_model_shape`;
- `ledgr_legacy_config_shape`; and
- `ledgr_execution_timing_version_mismatch`.

The public `fill_model`, `spread_bps` and `commission_fixed` formals and their
forwarding or refusal plumbing are gone. `as_tibble(type =)` is unsupported;
the S3 method retains `...` only for method consistency and rejects non-empty
dots. Retention-v1 normalization and the unreachable metric-kernel fallback
are absent. Old calls fail as unsupported calls through ordinary current API
validation; no translator or compatibility alias replaces them.

LTB-0264 and LCL-0262 pin validation and resume refusal for missing or
non-current identity fields, reopen refusal for missing stored risk and
corporate-action identities, exact policy-schema refusal and missing strategy
provenance. LTB-0265 and LCL-0263 pin the removed public forms, the exact
retention-schema reader, the removed metric fallback and retired conditions.
LTB-0250 again covers missing, older and future snapshot-hash rules across the
current row-dependent read surfaces. Separate owning tests retain the
typed-missing telemetry, construction-time risk normalization and timing-v2
contracts.

## D. Source-Derived Checks

`tools/check-codebase-contracts.R --mode=check` passes at the implementation
tree and writes the committed census under
`dev/bench/v0_2_2_pre_cran_removal/census/`:

| Family | Rows | Recorded findings |
| --- | ---: | ---: |
| connection entries | 69 | 0 |
| persisted versions and conventions | 136 | 1 |
| hand-built run-config entries | 80 | 0 |
| helpers | 1,640 | 11 |
| condition call sites | 2,267 | 64 |
| condition classes | 379 | 247 |

The version and run-config families are binding in this workstream. Check mode
finds no current-only violation and no hand-built run-config violation. The
sole version-inventory finding is the separately versioned promotion context,
whose reader now requires exact v2 equality. Helper and condition counts are
measured inputs for Workstream 31, not Workstream 30 failures. The production
format-fingerprint inventory contains twenty members.

The registered detector uses positive rules for persisted-version reads and
rejects a restored rule-1 or `availability_close_v1` arm, a hand-built current
run config missing either identity field and a restored removed call or
fallback surface. Its self-test injects a legacy branch and proves that check
mode fails rather than relying on a fixed text denylist.

## E. Exactness

The final fixture record is under
`dev/bench/v0_2_2_real_data_scale/evidence/ladder24/`. It compares the
accepted Workstream 29 tree with `b55552e3`:

- 51 of 51 fixture families are byte-identical;
- the identity family is byte-identical; and
- the checker self-test detects each of 52 independently changed families.

The first candidate record exposed one unintended run-information difference:
the current `legacy_pre_provenance = FALSE` field had been removed together
with the obsolete inference branch. Commit `b55552e3` restores the field as
an unconditional current output, not as compatibility behavior. The final
ladder then became exact.

Ties, typed missing telemetry, current policy identities, saved-sweep bytes,
current provenance, fills, equity, metrics, run information and public result
shapes remain exact. No tolerance or replacement legacy branch was added.

## F. Current-Format Research Store

LDG-3031 ran the documented build and census stages at ledgr commit
`b55552e322464fa9ed179e824223ca489dab4ab0` and ledgr.sharadar commit
`6be0b99e63f9feaa07f782a5bd2545c3bcccb28a`. It used the existing vendor
canonical lake to create a fresh ledgr store. It did not rebuild or change the
vendor lake, migrate or delete an older ledgr store, or add the later
dividend-fact mapping.

The fresh snapshot is SEALED under schema 119, snapshot hash rule 3 and the
recorded current format fingerprint. Its aggregate population is:

- 5,481,906 bars;
- 1,166 instruments with bars;
- 7,213 open sessions;
- 290,811 membership rows in 580 sets; and
- 829 lifetime rows.

The build stage completed in 217.6 seconds with sampled peak child RSS of
5,848 MiB. The retained Cut 11 aggregate arm recorded 359.0 seconds and
7,621 MiB, reductions of 39.4% and 23.3%. Snapshot construction inside the
current build took 204.46 seconds; the post-build complete verification took
9.16 seconds. These are cumulative current-tree measurements rather than an
isolated Workstream 30 effect estimate.

The documented scale lane then completed the momentum and equal-weight runs,
result readers, availability and explain surfaces, a three-candidate sweep,
promotion and walk-forward. Only ledgr-native identity, aggregate counts,
per-family hashes and phase clocks were exported. The committed record under
`dev/bench/v0_2_2_sharadar_run/evidence/ws30_current_only/` contains no vendor
row, instrument identifier, private path, credential or vendor canonical-build
identity.

## G. The Seven Shapes

1. No one-row frame is built per element. The work removes legacy parsing and
   keeps current records in their existing whole-table or fixed-record forms.
2. No changed function subsets a full data table inside an instrument,
   event, pulse, fact or candidate loop.
3. No per-element parser or formatter was introduced. Removed version
   inference and legacy decoding reduce parsing work.
4. No scale-growing collection gained per-row JSON. Current canonical record
   writes remain at their existing boundaries.
5. No candidate-invariant work was moved into a candidate or pulse loop. The
   source census is an offline development tool, not a runtime path.
6. No pairwise validator was introduced. Current checks are scalar version
   assertions or the Workstream 29 catalogue oracle.
7. No environment-held scale-growing vector is updated element by element.

The largest product diff is deletion. The new registered tests use bounded
fixtures, and the census runs once as a development gate.

## H. Verification

The focused identity, policy, timing, sweep, provenance, result, condition,
documentation-contract and control-plane suites pass. The original ordinary
fast record executes 563 of 563 blocks with zero failures or skips in 101.40
seconds. The final correction record at
`C:/Users/maxth/ledgr-research/.test-evidence/ws30-correction-fast-10c8b444`
executes 562 of 562 blocks with zero failures or skips in 106.21 seconds
against the unchanged 112-second bound. The original complete review profile
executes 334 of 334 blocks with zero failures and one pre-existing optional
path skip in 278.98 seconds.

The package builds. The final
`R CMD check --no-manual --no-build-vignettes` completes with all tests and
all 24 vignette replays passing. Its two warnings and two notes are the
pre-existing no-built-vignette, hidden `.lintr` and long evidence-path
findings. All Rd, cross-reference, usage and code/documentation checks pass;
roxygen2 8.1.0 introduces no Rd warning.

The implementation removes 3,179 lines and adds 2,474 across 79 changed files
before the evidence and closeout commit. Most additions are updated fixtures,
claims and refreshed census rows; production compatibility branches are
deleted rather than hidden.

## I. Review Boundary

The independent Type 1 close review returned CHANGES_REQUIRED with twelve
findings. Its durable record is `close_review_30.md`. Corrections
`d9a0306a`, `b538246c`, `b623d758`, `0adbd7b1` and `10c8b444` close the
current-only reader, detector, census, provenance and generated-help gaps
without changing the accepted design. A focused Type 1 re-review should verify
only those corrections and anything they could break. A third correction
round stops for maintainer disposition. Review counts are measured once at
Cut 14 close and are not a workstream gate.

Workstream 30 remains `review_pending` until focused re-review and maintainer
acceptance. Workstream 31 resumes only after acceptance.
