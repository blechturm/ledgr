# Diagnostic reader validation reuse

The WS25 private gate found exact compact-diagnostic order validation repeated
by public result readers. On the 3.8-million-row Sharadar workload, reader
clocks regressed by 2--20x and process peak memory rose from roughly 2.4 GiB to
4.9 GiB. This public synthetic probe reproduces the same width and duration:
500 instruments by 7,200 sessions, or 3.6 million decision rows.

`build_run.R` creates a public `ledgr_sim_bars()` snapshot and completed hold
run per source tree. `measure_surface.R` opens a fresh handle and records wall
time, process peak working set/private bytes and validator calls/time for
print, summary, point/history explanation, diagnostics and metrics. Each
surface runs in a fresh R process. `check.R` checks shape and completeness;
clocks and memory are evidence, not gates.

The pre-correction record reproduces the issue. The candidate calls the order
validator once for print, diagnostics and metrics and twice for summary and
both explanation surfaces. Validation alone costs about 1.1 seconds per full
call. Candidate peak working set is 2.76--3.16 GiB versus 0.32--2.40 GiB for
the base, while the much larger private-byte figures show DuckDB reservation
and are not resident-memory measurements.

The committed records are never run in place. Reproduce them into a fresh
temporary directory from the repository root. Source archives have no `.git`
directory, so each one must carry a `SOURCE_COMMIT` file containing the exact
eight-character short hash. `LEDGR_SOURCE_COMMIT` is the equivalent override
for a one-arm script, but it must be unset for the two-arm runner because its
single value cannot identify both source trees.

The pre-correction record used the protocol as committed at `c62adf83`, base
`0d6c0b11` and candidate `93e4b347`:

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$scratch = Join-Path $env:TEMP "ledgr-diagnostic-pre-$stamp"
New-Item -ItemType Directory -Path $scratch | Out-Null
foreach ($commit in @('0d6c0b11', '93e4b347')) {
  $dest = Join-Path $scratch $commit
  New-Item -ItemType Directory -Path $dest | Out-Null
  git archive --format=tar --output="$dest.tar" $commit
  tar -xf "$dest.tar" -C $dest
  [IO.File]::WriteAllText(
    (Join-Path $dest 'SOURCE_COMMIT'), $commit,
    [Text.UTF8Encoding]::new($false)
  )
}
$protocol = Join-Path $scratch 'protocol'
New-Item -ItemType Directory -Path $protocol | Out-Null
git archive --format=tar --output="$protocol.tar" c62adf83 -- `
  dev/bench/v0_2_3_diagnostic_reader_reuse
tar -xf "$protocol.tar" -C $protocol
Remove-Item Env:LEDGR_SOURCE_COMMIT -ErrorAction SilentlyContinue
$record = Join-Path $scratch 'record'
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  (Join-Path $protocol 'dev/bench/v0_2_3_diagnostic_reader_reuse/run_probe.R') `
  (Join-Path $scratch '0d6c0b11') (Join-Path $scratch '93e4b347') $record

& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/bench/v0_2_3_diagnostic_reader_reuse/check.R $record
```

The post-review record used base `93e4b347`, candidate `f4ead35d` and the
protocol as committed with the record at `de0f0efa`:

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$scratch = Join-Path $env:TEMP "ledgr-diagnostic-post-$stamp"
New-Item -ItemType Directory -Path $scratch | Out-Null
foreach ($commit in @('93e4b347', 'f4ead35d')) {
  $dest = Join-Path $scratch $commit
  New-Item -ItemType Directory -Path $dest | Out-Null
  git archive --format=tar --output="$dest.tar" $commit
  tar -xf "$dest.tar" -C $dest
  [IO.File]::WriteAllText(
    (Join-Path $dest 'SOURCE_COMMIT'), $commit,
    [Text.UTF8Encoding]::new($false)
  )
}
$protocol = Join-Path $scratch 'protocol'
New-Item -ItemType Directory -Path $protocol | Out-Null
git archive --format=tar --output="$protocol.tar" de0f0efa -- `
  dev/bench/v0_2_3_diagnostic_reader_reuse
tar -xf "$protocol.tar" -C $protocol
Remove-Item Env:LEDGR_SOURCE_COMMIT -ErrorAction SilentlyContinue
$record = Join-Path $scratch 'record'
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  (Join-Path $protocol 'dev/bench/v0_2_3_diagnostic_reader_reuse/run_probe.R') `
  (Join-Path $scratch '93e4b347') (Join-Path $scratch 'f4ead35d') $record

& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/bench/v0_2_3_diagnostic_reader_reuse/check.R $record
```

The base arm is commit `0d6c0b11`; the pre-correction candidate is clean head
`93e4b347`. The committed record contains only aggregate counts, clocks,
memory peaks and source identities. Stores stay outside version control.

## Correction result

Commit `d24b081e` first kept the exact logical-trace integrity check but reused
one successful validation within an opened run handle. The
`records/post_correction` directory preserves that historical first correction.
It included an experimental DuckDB memory-limit cap which was later removed:
DuckDB reports a rounded setting (`3000MB` reads back as `2.7GiB`), and setting
that reported value does not restore the caller's original limit exactly.

The review correction at product commit `f4ead35d` uses no memory-limit mutation.
It reuses a successful proof only for a durable, unchanged run and snapshot
store on the same public handle. Direct internal decodes, in-memory stores and
explicit transactions remain cold. Coverage, summary, main database and WAL
state form the reuse token; a checkpointed change, split-store change or fresh
handle validates again. Only full-run validation can publish a proof. DuckDB
out-of-memory failures are returned as `ledgr_diagnostic_resource_exhausted`
instead of leaking an unclassed backend error.

The reproducible availability-active record is in
`records/post_review_correction`. It uses 500 instruments, 7,200 sessions and
600 complete membership sets: 3.6 million logical decision rows represented by
7,201 physical diagnostic rows. Both arms have the same fixture hash, decoded
result size (591,619,152 bytes) and normalized result SHA-256.

Across the public same-handle reader sequence, validation fell from 17 calls and
103.25 seconds to one call and 2.67 seconds; total elapsed time fell from 119.84
to 15.25 seconds. A cold diagnostic read fell from 9.10 to 4.94 seconds, of
which validation fell from 6.65 to 2.42 seconds. These clocks describe the
record and are not acceptance gates.

The correction does **not** solve cold-read memory. Cold diagnostic peak working
set was about 4,419 MiB (4.32 GiB) on the base and 4,875 MiB (4.76 GiB) on the
candidate; the repeated sequence was about 5,217 and 5,326 MiB. The returned R
object alone is about
592 MB. The committed physical plan shows that exact validation still evaluates
the full logical UNION with ASOF joins and window/order operators, with extremely
large intermediate cardinality estimates. Public evidence can therefore assign
the residual to cold logical-trace validation/materialization plus the decoded
result and DuckDB working memory, but it cannot isolate the candidate's roughly
456 MiB cold-peak difference further. Fixture construction is separate and
peaked at about 5,073 and 5,760 MiB for the two arms.

The earlier dense public record likewise remains an explicit residual: cold
metrics were about 0.13 seconds and 320 MiB before the codec versus 1.52 seconds
and 1,445 MiB after the first reuse correction. Handle reuse removes repeated
validation; it does not remove the cold full-trace query. Private milestone and
H1 gates remain open pending maintainer disposition of that memory limit.

`run_probe.R` now builds both dense and availability-active fixtures, runs the
individual surfaces and same-handle sequences, and writes the three availability
summary CSVs checked by `check.R`. The two committed plans are raw `EXPLAIN`
output. Stores and full decoded results stay outside version control.

Clocks and process memory are diagnostic rather than gates. Registered gates are
the exact result/corruption tests, public-entry and one-validation counters,
durable-state invalidation witnesses, and source-shape checks that reject the
former correlated per-row membership subqueries and R-side materialization of
the full logical trace.
