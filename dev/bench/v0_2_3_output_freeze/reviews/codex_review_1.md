Verdict: CHANGES_REQUIRED

Independent review of `b19fda1bebe2353898e977418fc26ffbfc541609` against
`20034e00`, 2026-10-28. File references below are relative to
`dev/bench/v0_2_3_output_freeze/` unless prefixed otherwise.

1. **P1 - Native memory output is outside the gate.** `lib.R:281-305`
   captures events/diagnostics/completion only for descriptive agreement;
   `check.R:87-100` ignores agreement failures. Capture disappears when WS1
   deletes the factory (`lib.R:287-288`). I corrupted a native memory
   diagnostic's `detail_json` before consumption/canonicalization:
   agreement detected it, but the byte comparator found **zero differences**.
   **Fix:** freeze native memory events, retained diagnostics and completion
   through an observation boundary available to the replacement sink; fail
   when missing. Add raw memory-output guts. Basis: brief 5.2;
   `inst/design/contracts.md#contract-execution-fold-core`.

2. **P2 - Canonicalization conflates SQL NULL with literal text.**
   `lib.R:56-60` converts both `NA_character_` and `"NA"` to the same string;
   `lib.R:155` writes both as unquoted `NA`. I changed raw
   `runs.error_msg` from SQL NULL to literal `'NA'` on
   `a0-avail_terminal_resume-straight`; SQL confirmed `IS NULL = FALSE`,
   yet the byte comparator found **zero differences**. **Fix:** distinguish
   missingness from literal text, including nested values; escape sentinel/control
   sequences unambiguously. Re-freeze on the baseline and add this raw-store gut.

3. **P2 - Walk-forward warnings are fabricated as empty.**
   `lib.R:614-626` calls `ledgr_walk_forward()` without warning capture and
   supplies a new empty sink to `a0_reader_tables()`. I wrapped the persistent
   handler's telemetry writer to emit a warning only for `wf_` run IDs:
   **two native warnings, zero frozen warning rows, zero byte differences**.
   **Fix:** capture walk-forward warnings with order/class/message and available
   run association; add a warning gut.

4. **P2 - Failure output has no frozen witness.** `lib.R:526-540` selects
   only DONE/INCOMPLETE candidates; `closeout.md:121-124` explicitly defers
   `record_failure`, `abort_run`, `write_exception_diagnostic`, FAILED candidates
   and finalization failure. WS1 replaces these methods too: losing an exception
   diagnostic after rollback changes no record. `lib.R:582-584` lets expected
   run errors escape before collection. **Fix:** freeze failing-candidate and
   persistent failure fixtures, conditions and post-failure artifacts; gut their
   error/diagnostic/rollback output. Existing coverage includes
   `tests/testthat/test-sweep-persistence-parity.R:244-282`. Basis: brief 5.1-5.2;
   `inst/design/contracts.md#contract-persistence-telemetry-and-recovery`.

Verification: all named minimum workload categories execute, including actual
resume, dense/availability, costs, risk, dividend/acquisition/bankruptcy,
walk-forward and workers 1/2. Declared keys are checked for uniqueness at
runtime. `%.17g` detects the tested one-ULP changes. Listed exclusions concern
clock/version/host/random identity fields and are justified. The checker
hashes actual bytes against independent committed files and reports first
differences; skipped workloads or emptied populated tables cannot normally
pass its manifest/row comparisons. All five supplied guts corrupt raw store
or sweep output before canonicalization (`lib.R:566,587,651-694`): control
exited 0; fill/equity/diagnostic/order/sweep-equity cases each exited 1 and
named the right table. Harness: **1,129 R lines**; records including manifest:
**193 files, 430,638 bytes**. Both new manifests and the committed manifest
hash to `81bc80f93043b594fe94ef41d7f86d2078c936f09320df624af08147da8e99b8`.
Timing code uses one prepared snapshot, warmup, three repetitions alternating
which path goes first, medians and ratios; host conditions are recorded. I
inspected timing, without rerunning it.

Commands executed for verification (absolute paths; exit codes shown):

```text
Rscript C:/Users/maxth/ledgr-wt/a0-output-freeze/dev/bench/v0_2_3_output_freeze/check.R --agreement=C:/Users/maxth/AppData/Local/Temp/a0_codex_agreement.csv  # 0
Rscript C:/Users/maxth/ledgr-wt/a0-output-freeze/dev/bench/v0_2_3_output_freeze/gut.R  # 0; subprocess exits 0,1,1,1,1,1
Rscript C:/Users/maxth/ledgr-wt/a0-output-freeze/dev/bench/v0_2_3_output_freeze/record.R --out=C:/Users/maxth/AppData/Local/Temp/a0_codex_record_1  # 0
Rscript C:/Users/maxth/ledgr-wt/a0-output-freeze/dev/bench/v0_2_3_output_freeze/record.R --out=C:/Users/maxth/AppData/Local/Temp/a0_codex_record_2  # 0
Rscript C:/Users/maxth/AppData/Local/Temp/a0_codex_attacks.R  # 0; reproduced findings 1/2 with the actual checker comparator
Rscript C:/Users/maxth/AppData/Local/Temp/a0_codex_wf_warning.R  # 0; reproduced finding 3 with the actual checker comparator
Rscript C:/Users/maxth/AppData/Local/Temp/a0_codex_verify.R  # 0; manifest equality, sizes, lines, statuses, gut exits
git -C C:/Users/maxth/ledgr-wt/a0-output-freeze rev-parse HEAD  # 0
git -C C:/Users/maxth/ledgr-wt/a0-output-freeze diff --stat 20034e00 b19fda1b  # 0; only the harness directory
git -C C:/Users/maxth/ledgr-wt/a0-output-freeze diff --name-only 20034e00 b19fda1b -- R src tests man vignettes DESCRIPTION NAMESPACE  # 0; empty
git -C C:/Users/maxth/ledgr-wt/a0-output-freeze diff --exit-code b19fda1b -- dev/bench/v0_2_3_output_freeze  # 0 before adding this review
```

Read-only `Get-Content`/`rg` inspections supplemented these commands. Initial
sandbox Git ownership checks and some searches exited 1; owner-context Git
succeeded. R startup locale warnings did not prevent checks. Reviewed content
is unchanged; existing generated-file line-ending status/untracked brief remain.
No commit was made.

## Optional

Document the toolchain boundary for transport-size attributes:
`lib.R:263-269` records `staged_invariant_bytes` and `staged_payload_census`,
whose product values use `object.size()` (`R/sweep.R:1347,1385`). Representation
or host changes can alter these independently of economics. Fixture source/hashes
require unchanged strategy definitions. Internal helpers, pkgload and source
worker loading work here; no additional WS1-only false failure was demonstrated.
