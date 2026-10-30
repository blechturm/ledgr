# Reproduce / review

Use R 4.6.1 and an idle host. All large outputs belong in scratch directories.
The two arms use the same package installed from `git archive 145cc93b`;
`carrier.R` patches only the fork process. Rcpp builds `carrier.cpp` in a
scratch cache; the production compiled spot-FIFO envelope is untouched.

Install an archive into a fresh scratch library, then run `prerequisite.R`
with `--lib=<library> --out=<prepared> --csv=<normalized 500x1260 CSV>`.
The normalized input is the peer suite's SMA 5/10 transition input, also used
by `dev/spikes/pmwr-performance/probe.R`. The prerequisite creates and seals
both snapshots through the public API, executes both producers and writes
producer evidence. Reuse those unchanged verified snapshots for warm clocks.
Changing bars or facts requires rebuilding them and paying preparation again.
The ranked boundary is the sweep call, including its internal preparation and
retained outputs. Experiment construction is outside it: these are partial warm
clocks, not complete warm workflows or cold end-to-end clocks.

Example commands from this host (each is a separate invocation):

```powershell
& 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe' C:/Users/maxth/ledgr-wt/ws4a-carrier-probe/dev/spikes/ws4a-carrier-probe/probe.R --mode=census --phase=base --out=C:/Users/maxth/AppData/Local/Temp/ws4a-census-base
& 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe' C:/Users/maxth/ledgr-wt/ws4a-carrier-probe/dev/spikes/ws4a-carrier-probe/probe.R --mode=census --phase=fork_floor --out=C:/Users/maxth/AppData/Local/Temp/ws4a-census-fork-floor
& 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe' C:/Users/maxth/ledgr-wt/ws4a-carrier-probe/dev/spikes/ws4a-carrier-probe/measure.R --out=C:/Users/maxth/AppData/Local/Temp/ws4a-profiles
& 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe' C:/Users/maxth/ledgr-wt/ws4a-carrier-probe/dev/spikes/ws4a-carrier-probe/measure.R --phase=components --out=C:/Users/maxth/AppData/Local/Temp/ws4a-components-final
& 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe' C:/Users/maxth/ledgr-wt/ws4a-carrier-probe/dev/spikes/ws4a-carrier-probe/summarize.R
& 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe' C:/Users/maxth/ledgr-wt/ws4a-carrier-probe/dev/spikes/ws4a-carrier-probe/attribute.R
& 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe' C:/Users/maxth/ledgr-wt/ws4a-carrier-probe/dev/spikes/ws4a-carrier-probe/check.R --out=C:/Users/maxth/AppData/Local/Temp/ws4a-review-fresh
```

Use new output directories for an independent rerun. `--lib` and `--prepared`
select other library/snapshot locations; summarize/attribute accept directory
arguments. Existing completed children are reused only for interrupted local
measurement continuation. `check.R` reruns exact outputs in its new scratch
folder, runs both guts, byte-diffs `identity.csv` / `gut.csv`, and guards
`R`, `src`, `tests`, `NAMESPACE`, `DESCRIPTION`, `man`, `inst/design`.
`--record=1` writes the initial executed deterministic answers; ordinary review
omits it. Timing/allocation diagnostics have their own runners and summaries;
they are variable measurements rather than byte-identical clock oracles.

The identity cases are wide, floor, sparse, the five applicable A0 workloads,
and the fee-bearing version of wide used by the fee gut (nine workload cases).
A0 retains its native fixtures and canonicalizer. Worker-2 paths are excluded
because namespace overrides do not propagate to workers; all applicable
workloads run through sequential committed/sweep paths, resume and walk-forward.
Memory equity excludes only generated `sweep_id`. The raw durable ledger,
strategy-state table, equity table and full final lot state stay exact.

Payload is an exclusive component. The memory sink defers JSON serialization;
the fork's row measures metadata construction. Durable JSON bytes are covered
by identity. Initial overlapped durable clocks remain excluded; the qualified
five-pair replacements for every arm are in `additional_arms.csv`. Legacy
`--phase=durable` is an unguarded diagnostic; use `extensions.R` for qualified reruns.

`Rprofmem` logs are large. Attribute streams 5,000 lines at a time, sums only
explicit-size records and preserves unpriced new-page counts. Native malloc
and RSS are outside this measure. No package tests or production files change.

## Maintainer's additional arms

`--arm=fork_r` uses a per-pulse batch that delegates FIFO transitions to
`ledgr_lot_apply_fill()`, the canonical R oracle, and carries sequential cash
and typed result vectors. The per-fill canonical calls and validation are
included in its cost. It also uses R affordability and never loads
`carrier.cpp`. This is a canonical batching control, not a claim that further
R vectorization is impossible.

`--arm=fork_indexed` keeps the original native lot batch and changes only
retained-fill publication. It uses the existing typed buffer and capacity
policy, then writes fixed columns by index using the production buffer helper.
The original copying arm remains available as `--arm=fork`.

`extensions.R --phase=timing` measures five alternating own-floor/wide pairs
for all three additional sweep arms and all five durable arms. A serial child
monitor samples external R CPU throughout each execution; overlap disqualifies
the sample and triggers a retry after a quiet interval. The qualification CSVs
remain beside the large scratch outputs. `--phase=profiles` records separate
lot, payload and event clocks plus Rprofmem allocations for the new sweep arms,
and component clocks for all durable arms. `summarize-additions.R` derives
additional CSV rows; the original 42.23 us/fill verdict is preserved.

The expanded `check.R` uses the same nine workload cases for every carrier
arm. Original identity rows are preserved as a prefix of `identity.csv`.
The reviewer assigned by the maintainer is Max Thomasberger; assignment does
not claim independent acceptance.

`--arm=fork_r_indexed` combines the canonical-R lot/affordability batch with
the indexed retained-fill writer. It loads no probe C++ module. It is measured
directly in both sweep and durable workflows, with its own floor pairs and
profiles, and is another carrier variant over the same identity cases.
`extensions.R --arms=<comma-separated arms>` can run a requested subset;
without it the expanded matrix includes this combined arm.

Final evidence uses strict `identical(..., num.eq=FALSE, single.NA=FALSE)`
for atomic values. The byte-compared CSVs use this Windows checkout's CRLF
convention (`core.autocrlf=true`). The committed reviewer assignment is pending
independent review; no acceptance is implied.

## Typed R lot addendum (2026-10-30)

`--arm=fork_typed` changes only the combined arm's lot kernel. It sources
`typed-lots.R`, uses R affordability and indexed publication, and never loads
probe C++. The typed core has no names on its primitive columns, per-instrument
list elements, S3 state or compiled helpers. Import/export adapters preserve
canonical lot representation for existing fold readers; their cost is included
in end-to-end clocks and reported separately from the kernel. The cache is
owned by the probe installation and keyed to one fold environment/event sequence.

The original nine cases also run on this arm. `--shape=partial` adds the tenth:
SMA transitions alternate targets 1 and 2 on the same bars. Its LIFO gut must
complete and fail strict identity. The addendum checker reruns the original
reorder/drop-fee guts too, and byte-diffs separate `typed_identity.csv` and
`typed_gut.csv`; original evidence remains unchanged.

```powershell
& 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe' C:/Users/maxth/ledgr-wt/ws4a-carrier-probe/dev/spikes/ws4a-carrier-probe/check.R --addendum=1 --out=C:/Users/maxth/AppData/Local/Temp/ws4a-typed-review-new
& 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe' C:/Users/maxth/ledgr-wt/ws4a-carrier-probe/dev/spikes/ws4a-carrier-probe/extensions.R --arms=fork_r_indexed,fork_indexed,fork_typed --workloads=wide,partial --phase=timing --out=C:/Users/maxth/AppData/Local/Temp/ws4a-typed-timing
& 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe' C:/Users/maxth/ledgr-wt/ws4a-carrier-probe/dev/spikes/ws4a-carrier-probe/extensions.R --arms=fork_r_indexed,fork_indexed,fork_typed --workloads=wide,partial --phase=profiles --out=C:/Users/maxth/AppData/Local/Temp/ws4a-typed-profiles
& 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe' C:/Users/maxth/ledgr-wt/ws4a-carrier-probe/dev/spikes/ws4a-carrier-probe/typed-summary.R
```

These are the same partial-warm sweep/durable boundaries, five alternating
own-floor/workload pairs, and explicit-size Rprofmem allocation method as the
recorded arms. Memory profiling is sweep-only; durable gets its own clocks and
component profiles. New qualification rows also record external R process IDs.
See [typed_lots_findings.md](typed_lots_findings.md) for the nonbinding result;
original bounds and the original inconclusive verdict remain in force.

The native wide lot timer initially quantized to zero. A single qualified
component repeat measured 0.10 s; both observations are retained in
`typed_component_repeat.csv`, with its qualification appended to `typed_host.csv`.
Ordinary clocks and original evidence remain unchanged. Reproduce that diagnostic
with `extensions.R --phase=one_component --arms=fork_indexed --workloads=wide
--out=<fresh scratch>` (one invocation). `typed_other_host.csv` records CPU deltas
for surviving processes between PowerShell Get-Process snapshots before/after the
main matrix; short-lived processes are outside that supplementary record.
