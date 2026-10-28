Verdict: PASS

Independent review of `20034e00..9b43880f`, HEAD
`9b43880f7d4a6270438fec151ebbaa01ae31f3ae`, 2026-10-28.
References are relative to `dev/bench/v0_2_3_output_freeze/` unless specified.
No findings requiring changes. This is a trustworthy regression oracle for
the recorded WS1 workloads, with the coverage boundaries stated below.

All six previous findings are fixed, verified from code and execution:

| Finding | Evidence and verification |
| --- | --- |
| Review 1: native memory output ungated | `lib.R:358,391`: native events and typed auxiliaries, diagnostics, completion and inline equity/fills have committed records. Missing observer fails closed. Memory event/diagnostic guts fail; independent completion and typed cash-delta mutations also fail the actual comparator. |
| Review 1: NULL aliases literal NA | `lib.R:39,176`: missing values remain missing; present strings are quoted. Raw SQL NULL-to-text gut fails. |
| Review 1: walk-forward warnings omitted | `lib.R:513`: warning capture encloses the actual walk-forward call. Injected handler warnings produce two recorded rows and fail. |
| Review 1: failure output omitted | `fixtures.R:217`, `lib.R:472,488`: mid-run strategy failure and abort refusal record conditions and durable state; FAILED sweep candidates run with one/two workers. Error-message, exception-diagnostic, rollback and abort-status guts fail. |
| Review 2: nested structures alias | `lib.R:79`, `serialization_probe.R:18`: explicit node boundaries, lengths and named/positional markers distinguish the reported cases. All 15 probes pass; raw opening-to-sibling restructuring fails. |
| Review 2: interruption overwritten | `lib.R:501,503`: store collection precedes the second invocation. The raw handler pulse-count corruption fails specifically at `run_interrupted/run_telemetry`, before resume replaces it. |

Fresh review: the eight workloads satisfy brief 5.1: run/sweep on the same
inputs, dense/availability, costs, risk chain, dividends/acquisition/bankruptcy,
soft interruption/resume, walk-forward and workers 1/2. Store collection includes
all ten run tables and their columns; readers add fills, trades and metrics.
Native in-process memory output is independently frozen, rather than merely
compared with the current persistent handler. FAILED buffers are deliberately
discarded; their public failure output is frozen.

Declared keys are checked for uniqueness during execution. Numeric samples,
including subnormals, signed zero, infinities, NaN and NA, round-trip bit for
bit. The listed exclusions concern clock, host/version, random sweep identity
and transport measurements; stable handler-owned counts remain recorded.
The checker hashes actual file bytes against committed files and verifies the
expected hashes. Independent empty-table, skipped-workload and CRLF-only
attacks all fail. Expected failures become evidence; they do not bypass the
fixed manifest or output comparisons. Agreement reproduces 213 comparisons
and the four documented differences.

Both fresh recordings exactly match the committed files and manifest:
SHA-256 `64b452e78d9eeb7de6886f35a5550d21302ff9dd417fa5faeb31d0fa2a239c83`.
Harness: **1,445 R lines**. Records including manifest: **291 files,
598,875 bytes**. The full commit range changes only this harness directory;
no product changes. Timing uses one reusable snapshot, warmup, three
repetitions alternating path order, medians and ratios; host conditions are
recorded. I inspected timing without rerunning it; the failure fixture is
explicitly excluded from timing (`fixtures.R:266`, `timing.R:54`).

Commands executed for verification (absolute paths; exit codes):

```text
Rscript C:/Users/maxth/ledgr-wt/a0-output-freeze/dev/bench/v0_2_3_output_freeze/check.R --agreement=C:/Users/maxth/AppData/Local/Temp/a0_review3_agreement.csv  # 0
Rscript C:/Users/maxth/AppData/Local/Temp/a0_review3_setup.R  # 0
Rscript C:/Users/maxth/AppData/Local/Temp/a0_review3_harness/gut.R --records=C:/Users/maxth/ledgr-wt/a0-output-freeze/dev/bench/v0_2_3_output_freeze/records  # 0; control 0, all 17 corruptions 1
Rscript C:/Users/maxth/ledgr-wt/a0-output-freeze/dev/bench/v0_2_3_output_freeze/serialization_probe.R  # 0
Rscript C:/Users/maxth/ledgr-wt/a0-output-freeze/dev/bench/v0_2_3_output_freeze/record.R --out=C:/Users/maxth/AppData/Local/Temp/a0_review3_record1  # 0
Rscript C:/Users/maxth/ledgr-wt/a0-output-freeze/dev/bench/v0_2_3_output_freeze/record.R --out=C:/Users/maxth/AppData/Local/Temp/a0_review3_record2  # 0
Rscript C:/Users/maxth/AppData/Local/Temp/a0_review3_harness/review_verify.R  # 0; hashes, budgets, numeric samples and comparator attacks
Rscript C:/Users/maxth/AppData/Local/Temp/a0_review3_harness/review_memory.R --pkg=C:/Users/maxth/ledgr-wt/a0-output-freeze  # 0; both independent raw memory corruptions detected
git -C C:/Users/maxth/ledgr-wt/a0-output-freeze rev-parse HEAD  # 0
git -C C:/Users/maxth/ledgr-wt/a0-output-freeze diff --stat 20034e00..9b43880f  # 0
git -C C:/Users/maxth/ledgr-wt/a0-output-freeze diff --name-only 20034e00..9b43880f -- R src tests man vignettes DESCRIPTION NAMESPACE  # 0; empty
git -C C:/Users/maxth/ledgr-wt/a0-output-freeze diff --exit-code 9b43880f -- dev/bench/v0_2_3_output_freeze  # 0 before adding this review
git -C C:/Users/maxth/ledgr-wt/a0-output-freeze diff --ignore-space-at-eol --exit-code -- R/cpp11.R src/cpp11.cpp  # 0
```

The scratch setup copies the R harness unchanged except for one line in the
gut driver forwarding `--pkg` to the reviewed tree. Every gut corrupts raw
store/sweep/buffer output or a handler before canonicalization; none edits
canonical records. Reports went to Temp. Additional read-only Git
status/diff/numstat, Get-Content, Get-ChildItem and rg inspections succeeded;
initial sandbox Git attempts exited 1, and one rg inspection of nonexistent
`R/metrics.R` exited 1. Owner-context Git succeeded. R startup locale warnings
were benign. Reviewed files remain unchanged; no commit was made.

## Optional

Retain tests for finalization-failure recovery, daemon-side native buffers
and event-buffer growth when removing the mutual parity suite
(`closeout.md:219`, `tests/testthat/test-ledger-writer.R:559`). These small
record fixtures do not replace those tests. For WS1, adapt only the documented
memory observer (`lib.R:349`) when deleting its factory; preserve fixtures,
canonicalization and records. Source pkgload/worker loading and the internal
run-store/fold-list helpers remain dependencies (`closeout.md:213`). Embedded
fixture source/config hashes require unchanged strategy definitions; no
additional WS1-specific false failure was demonstrated.
