Verdict: CHANGES_REQUIRED

Independent review of `20034e00..2cbbd353`, HEAD
`2cbbd353dbf471279e9380dbdecfa62e9262c1e9`, 2026-10-28.
References below are relative to `dev/bench/v0_2_3_output_freeze/`.

1. **P2 - Nested serialization aliases different output structures.**
   `lib.R:69,85-88` escapes several delimiters but not the `/` used to join
   paths, and emits no node marker for a nonempty list. Consequently
   `list(a = list(b = 1))` and `list("a/b" = 1)` have identical bytes.
   This affects actual frozen output: I replaced the raw sweep attribute
   `execution_assumptions$opening` with sibling fields named `opening/cash`,
   `opening/date`, etc., before `a0_sweep_tables()` (`lib.R:319`). The
   `opening` object was absent, but the checker comparator reported **zero
   differences across all workloads**. WS1 could break this output structure
   without failing the gate. Positional names also collide:
   `list(1)` equals `list("[1]" = 1)` canonically.
   **Required fix:** encode list boundaries and distinguish positional from
   named elements; escape or length-prefix every path component. Re-freeze
   against the unchanged product and add a raw structural-corruption gut.

2. **P2 - Resume overwrites the interrupted output before it is observed.**
   `lib.R:497-501` runs both attempts before collecting any store tables
   (`lib.R:519-522`). Stable output from the first attempt is outside the
   oracle. I wrapped the persistent handler's `write_telemetry()` only for
   the resumed run's `RUNNING` write and persisted `pulse_count = -999`.
   SQL confirmed that wrong durable value after the interrupted call; the
   second call replaced it, and the checker comparator reported **zero
   differences across all workloads**. This is a handler-determined count,
   not excluded wall-clock telemetry. **Required fix:** freeze the store
   immediately after the interrupted call, before resuming, including its
   status, telemetry, ledger, state, equity and diagnostics; add a gut that
   changes this intermediate output. Basis: brief 5.1-5.2;
   `inst/design/contracts.md#contract-persistence-telemetry-and-recovery`.

Prior review verification: finding 1 now has gated native memory events,
typed attributes, diagnostics, completion and summaries, plus a missing-factory
failure (`lib.R:347-429`); finding 2's SQL NULL/text collision is fixed;
finding 3's walk-forward warning capture is fixed; finding 4 now has FAILED
candidate, persistent strategy-error/rollback and abort witnesses. The new
findings above are separate from those repaired cases.

Verification: `check.R` and `gut.R` exited 0. Gut control exited 0; all 15
corruptions exited 1 and named their table or the missing observer. Each
corruption acts on raw store/sweep/buffer output or a handler before
canonicalization. Agreement reproduced 213 comparisons and four documented
differences. Two fresh records matched the committed
manifest, SHA-256 `21285a80e45e35996388d41d021ed2ef09c1367cbce1dc1a3a6fd98ede20b2fb`.
All minimum workload categories execute. Keys are checked for uniqueness;
atomic numeric probes round-trip, including subnormals, infinities and signed
zero. Exclusions are justified. The checker hashes actual bytes against
committed files, checks expected-file hashes, and reports first differences;
ordinary missing workloads or emptied populated tables fail. Harness: **1,383
R lines**. Records: **279 payload files plus manifest, 575,563 bytes total**.
The commit range changes only the harness directory, with no product edits.
Timing code uses one prepared snapshot, warmup, three alternating repetitions
and medians; host conditions are recorded. I inspected timing, without rerunning it.

Commands executed (absolute paths; exit codes):

```text
Rscript C:/Users/maxth/ledgr-wt/a0-output-freeze/dev/bench/v0_2_3_output_freeze/check.R --agreement=C:/Users/maxth/AppData/Local/Temp/a0_review2_agreement.csv  # 0
Rscript C:/Users/maxth/AppData/Local/Temp/a0_review2_harness/gut.R --records=C:/Users/maxth/ledgr-wt/a0-output-freeze/dev/bench/v0_2_3_output_freeze/records  # 0; child exits 0, then fifteen 1s
Rscript C:/Users/maxth/ledgr-wt/a0-output-freeze/dev/bench/v0_2_3_output_freeze/record.R --out=C:/Users/maxth/AppData/Local/Temp/a0_review2_record1  # 0
Rscript C:/Users/maxth/ledgr-wt/a0-output-freeze/dev/bench/v0_2_3_output_freeze/record.R --out=C:/Users/maxth/AppData/Local/Temp/a0_review2_record2  # 0
Rscript C:/Users/maxth/AppData/Local/Temp/a0_review2_harness/review_attacks.R --pkg=C:/Users/maxth/ledgr-wt/a0-output-freeze  # 0; reproduces finding 2
Rscript C:/Users/maxth/AppData/Local/Temp/a0_review2_harness/review_serialization.R --pkg=C:/Users/maxth/ledgr-wt/a0-output-freeze  # 0; reproduces finding 1
Rscript C:/Users/maxth/AppData/Local/Temp/a0_review2_harness/review_verify.R  # 0; hashes, sizes, lines, numeric/NULL probes
git -C C:/Users/maxth/ledgr-wt/a0-output-freeze rev-parse HEAD  # 0
git -C C:/Users/maxth/ledgr-wt/a0-output-freeze diff --stat 20034e00..2cbbd353  # 0
git -C C:/Users/maxth/ledgr-wt/a0-output-freeze diff --name-only 20034e00..2cbbd353 -- R src tests man vignettes DESCRIPTION NAMESPACE  # 0; empty
git -C C:/Users/maxth/ledgr-wt/a0-output-freeze diff --exit-code 2cbbd353 -- dev/bench/v0_2_3_output_freeze  # 0 before adding this review
```

The scratch gut runner forwards `--pkg` to the reviewed source tree; that is
its only change. Its checker, library, fixtures and corruptions are copied
unchanged, and it compares against the original records. This keeps generated
gut/agreement reports outside the reviewed files. Read-only `Get-Content`,
`rg`, and Git inspections supplemented the commands above. Initial sandbox
Git ownership checks and unsuccessful searches exited 1; owner-context Git
and corrected inspections succeeded. R startup locale warnings were benign.
No reviewed file was edited; no commit was made.

## Optional

Retain the documented boundaries when cutting WS1: the memory observer needs
an explicit adapter after its factory disappears; source pkgload/worker loading,
`ledgr_run_store_open/close`, `ledgr_fold_list`, and unchanged fixture source
remain dependencies. Finalization-failure recovery and native daemon buffers
remain unrecorded (`closeout.md:193-210`); keep applicable tests for those paths.
