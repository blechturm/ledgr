# v0.2.0.1 Batch 4 Production Parity And Retirement Evidence

Status: Complete after independent review and maintainer acceptance.

This record closes the implementation side of LDG-2725 and LDG-2726. It is
internal release evidence, not a public performance claim.

## Pre-retirement baseline and containment

The final paired protocol ran from
`cf93d8622f4eb610145da90c08a7f0cc3e91678d` on branch `v0.2.0.1`, before any
reference path was removed. The exact ignored local evidence prefix is:

`dev/bench/results/v0_2_0_1_batch4_preretirement_cf93d86/`

The session used R 4.6.1 ucrt on Windows build 26200, x86_64-w64-mingw32,
24 detected logical cores, duckdb 1.5.2, testthat 3.3.2, and collapse 2.1.8
from `C:/tmp/ledgr-collapse-218-lib`. No other R workload overlapped the paired
measurement. Snapshot sealing happened once before both arms and is excluded
from every warm time below.

The writer checker first passed its independent semantic rerun with zero
failures, including byte-identical fixture, case, and 20,240-row diagnostic
files. The provider checker then reproduced all 3,676 shuffled and repeated
cutoff comparisons, all semantic scenarios, the provider-only passes, the
full persisted pair, and 85 tests per arm with zero test failures. Its legacy
byte-identity check correctly noticed that Batches 1-3 had added passing test
blocks since the historical `regression_tests.csv`; no provider semantic or
runtime assertion failed. The fresh Batch 4 runner therefore recorded the
current regression net rather than rewriting historical spike evidence.

## Paired warm record

The registered fixture has 563 instruments, a 505-member axis, 757 pulses,
60 complete membership lists, flat targets, zero fills, and 383,042 persisted
diagnostic rows. Each arm ran one warm-up followed by three measured runs in
one session. The block arm also ran once under the profiler.

| Arm | Measured wall seconds | Median | `diff(range())` | Measured peak working set MiB |
| --- | --- | ---: | ---: | --- |
| scalar columnar reference | 118.64 / 119.04 / 119.03 | 119.03 | 0.40 | 772.0 / 778.4 / 771.6 |
| production block | 25.92 / 26.33 / 26.02 | 26.02 | 0.41 | 757.5 / 810.4 / 757.2 |

The production median is 93.01 seconds lower than the reference median. That
gap exceeds the reference spread of 0.40 seconds, so the registered relative
criterion passes. The production median is also below the later 60-second
Stage H ceiling and every measured production peak is below 1,024 MiB, but
these pre-retirement results do not replace the post-retirement Stage H run.

The one-time cold seal took 1,019 seconds. It is reported separately and does
not enter the warm comparison. The profiled production run attributed 67.3%
of captured in-loop samples to valuation, 22.7% to residual fold work, and
8.8% to diagnostic construction, append, and durable diagnostic writes
combined. Final bind and provider membership had zero captured samples.

## Persisted parity

The non-measured parity pair used one shared run ID. DuckDB multiset difference
compared `runs`, `run_completion`, `run_diagnostics`, `ledger_events`,
`equity_curve`, and `strategy_state`. Every table was identical with zero rows
on either side of every difference. Counts were one run row, one completion
row, 383,042 diagnostics, zero ledger events, 757 equity rows, and 757 strategy
state rows.

The `runs` comparison excluded exactly:

- top-level `created_at_utc`;
- `config_json.db_path`; and
- `config_json.data.snapshot_db_path`.

Run IDs at both levels, `archived_at_utc`, `config_hash`, and every other field
were compared.

The fresh runner executed 103 test blocks under each arm with zero failures,
errors, or skips. The deterministic file contains 102 blocks per arm; the
optional mirai parallel-sweep block ran separately under both arms and passed
five expectations each. The Batch 4 checker validated the fresh evidence with
zero failures after its regression attestation was corrected to recognize the
new tests that deliberately selected each retained reference arm. Arm-specific
scenario and 757-pulse assertions still require the requested arm on every
call and reject fallback.

## Retirement result

Installed package code now has one provider and one diagnostic path:

- `ledgr_availability_provider_build()` calls the prepared provider directly;
- the fold always constructs typed per-pulse diagnostic segments and appends
  them through the bounded block writer;
- all four spike options and both arm-observation fields are absent;
- the old provider builder, per-pulse members/status/lifetime/terminal
  resolvers, scalar diagnostic constructor, row-list writer, scalar append,
  and row-list final bind are absent; and
- `ledgr_membership_resolve_at()`, `ledgr_membership_evidence()`, and their
  inspection helpers remain installed and independent.

The source guard scans every production R file for the forbidden names and
shapes, verifies the retired functions are absent from the namespace, verifies
the retained inspection helpers remain, and proves provider-build consumers
do not name them.

The Batch 3 review carry-forward is closed directly: an injected failure on
the production `append_block()` path leaves the full buffered chunk available;
retry persists that chunk exactly once, appends the remaining block, preserves
sequence 1:3, and releases only after success.

## Verification

- final writer checker: zero failures;
- final provider semantic and regression execution: all load-bearing checks
  passed; historical regression-file byte identity differed only because the
  current suite contains additional passing blocks;
- fresh Batch 4 diagnostic-block checker over the exact evidence prefix: zero
  failures and GREEN;
- all 17 `test-availability*.R` files after retirement: passed in 232.3
  seconds with no reported failure, warning, or skip; and
- focused source-guard, provider, writer, fold, inspection, parity, and
  test-only-reference files: passed;
- the complete source-tree suite: passed in 1,292.1 seconds with one expected
  skip for an unavailable-package path whose package was installed; and
- the rebuilt source package, including vignettes, passed
  `R CMD check --no-manual --no-build-vignettes` under R 4.6.1 in 1,232.9
  seconds with zero errors, zero warnings, and the existing long-path NOTE.

Independent review and maintainer acceptance remain outstanding.
