# Durable-Path Observations Note

Status: Observations, plus two maintainer decisions recorded on 2026-09-17.
Still not a ticket and not a gate. Nothing here may be implemented inside
v0.2.0.1.

Read after: the Batch 9 independent review closes. These observations are
roadmap or horizon input at Stage J, alongside the complexity audit's other
later findings.

Source: read and profile of the working tree at the Batch 8 correction state,
baseline `0e214f0862bd60dd0820877f6f332343e36b8a5d`. Nothing was modified.

## Maintainer decisions

Two decisions were taken on 2026-09-17, after the measurements in observations
6 and 7. They set direction for the cycle that picks this up. They do not
authorize work inside v0.2.0.1 and do not move any Batch 9, 10 or 11 boundary.

There are three exported ingestion surfaces, not two, and an earlier revision
of this note conflated them:

- `ledgr_snapshot_from_df()` at `R/snapshot_adapters.R:38`, the in-memory
  constructor the other paths funnel through;
- `ledgr_snapshot_from_csv()` at `R/snapshot_adapters.R:526`, a thin wrapper
  that reads with `ledgr_read_csv_strict()` and delegates straight to
  `from_df()`. It never calls the strict field parsers; and
- `ledgr_snapshot_import_bars_csv()` at `R/snapshots-import-bars.R:92`, the
  strict importer that fills an existing snapshot. It has its own parser, its
  own validation, and the duplicate-key check at `:158`.

The third is not reachable from the first two. Optimizing it does not speed up
`from_csv()`, and `from_csv()` does not exercise its duplicate-key check.
Merging their contracts would be a product decision about accepted input, not
a transparent optimization, and is not decided here.

Decision 1. Fix and optimize all three surfaces, under one explicit
compatibility matrix and with their public contracts kept distinct. The line
104 reformat and the branch work in observation 7 belong to `from_df()`, and
reach `from_csv()` through it. The deduplicated strict parse and the
duplicate-key check at `R/snapshots-import-bars.R:158` belong to
`import_bars_csv()` alone. Shared narrow helpers are welcome; a silently
unified contract is not.

Decision 2. Switch the peer harness to call `ledgr_snapshot_from_csv()` in
place of its hand-rolled `read.csv()`, `as.POSIXct()` and
`ledgr_snapshot_from_df()` sequence at
`dev/bench/peer_benchmark/peer_benchmark.R:346` and `:349`.

The reasoning for decision 2 is that the harness today measures a path no user
calls, while the shipped entry point goes unmeasured. Calling the exported
function makes `snapshot_prepare_sec` report what a user would actually pay.
This is the opposite of tuning the harness, and it does not reopen that
question: speeding up the harness's own `read.csv()` stays declined, because
that would improve a published number without improving ledgr.

One consequence to carry into the batch that does it. The switch changes what
`snapshot_prepare_sec` contains, so the resulting record is not directly
comparable with earlier records on that phase. Say so in the record notes
rather than presenting as a speedup what is partly a change of definition.

No fixture regeneration is required. An earlier revision of this note claimed
the peer bars fixture had to be rewritten with full ISO8601 timestamps because
the strict importer rejects the date-only form. That was wrong: `from_csv()`
never reaches the strict importer. Verified directly: `from_csv()` accepted
the existing date-only `peer_benchmark_shared_bars_record.csv` and
produced a sealed snapshot in 20.3 seconds, and `from_df()` accepts date-only
character timestamps by design at `R/snapshot_adapters.R:119`. Standardizing
the fixture on full ISO8601 stays available as a deliberate choice. It is not
a precondition for decision 2.

## Correction to carry forward

An earlier informal statement in conversation held that roughly 22 of the
durable engine's seconds were DuckDB persistence. That is wrong and should not
be repeated in any record, manual, or closeout. Profiling the durable engine
phase alone attributes about 5 percent to the database layer: `rapi_execute` at
3.54 percent and `rapi_bind` at 1.77 percent of sampled self time. In this
profile the durable engine was dominated by R-side preparation and
serialization rather than by sampled DuckDB calls. State it that way: it is one
`Rprof()` run, on one Windows host, against one fixture, and it does not
support a general claim that storage never matters.

If that claim propagated into a draft, correct it there too.

## Method and measurement base

One profiled `ledgr_run()` over the peer fixture shape at 200 instruments and
1,260 sessions, SMA 5/10, seed 20260530, zero costs, 27,668 fills. `Rprof()` at
20 ms sampled 14.68 seconds inside `ledgr_run()`. Percentages below are of that
sampled total. Per-event figures come from separate direct timings at the same
event count.

This is a single diagnostic run, not a spike and not a benchmark record. It is
enough to rank candidates and not enough to size a correction.

Observations 4 through 7 were measured separately, outside `ledgr_run()`, and
each states its own shape and fixture. Observations 6 and 7 used a generated
500 by 1,260 ISO8601 bars set, which was needed to exercise
`ledgr_snapshot_import_bars_csv()` because its strict parser requires the full
form. That is a property of the strict importer only, not of
`ledgr_snapshot_from_csv()`. Their component timings are single cold runs or
medians of three, as marked, not spike-grade repetitions.

Provenance is discovery-grade and insufficient for cutting tickets. The stated
base is `0e214f0`, but the tree measured was a Batch 8 correction state that
included working-tree changes committed later, and no runner, raw profile,
environment record, or checksum set accompanies these figures. Before any of
this becomes a packet, preserve a small reproducible probe carrying the exact
source commit or dirty-diff hash, R, DuckDB, collapse, digest and yyjsonr
versions, host metadata, the commands and fixture generator, raw timings and
profile summaries, equality checks, and a checker for the derived tables.

## Observation 1: per-event payload construction

About 14.3 percent of the engine, 2.10 seconds, inside
`ledgr_fill_event_payload()`. It runs once per fill and performs canonical JSON
serialization, a `paste0()` plus `sprintf()` to build the event identifier, and
timestamp coercion, all per row.

The memory handler calls the same function with `serialize_meta_json = FALSE`
(`R/sweep.R:1936`) and keeps metadata as parsed lists, serializing only when a
caller asks for rows. The durable handler passes `TRUE`
(`R/backtest-runner.R:188`). Durable rows are not written until
`flush_pending()`, so the serialization is eager work that a batch pass at
flush time could absorb.

Direct timings at 27,668 events: canonical JSON 14.1 microseconds each,
timestamp coercion 15.5, identifier construction 1.8. Building the identifiers
vectorised in one call rather than per event is about five times faster.

Shapes 3 and 4 of the optimization coding style.

## Observation 2: snapshot hash recomputed inside the run guard

About 13.35 percent of the engine, 1.96 seconds, attributed to
`ledgr_snapshot_hash` beneath `ledgr_run_snapshot_guard`.

The call site is `R/run-snapshot.R:55`. The guard reads the stored
`snapshot_hash`, recomputes the hash over the sealed snapshot, and aborts with
`LEDGR_SNAPSHOT_CORRUPTED` when they differ. This is deliberate tamper
detection documented in the comment above the call, not an oversight, and it
should not be labelled an antipattern.

Two facts bound it. Sweeps do not pay it, because the sweep path runs
`ledgr_execute_fold()` with a memory handler rather than `ledgr_run()`. And one
verification per durable audit-grade run is a defensible trade for the
guarantee.

What is worth attention is the cost of the hash itself, not the decision to
verify. See observation 4: the same hash runs once at seal and again on every
durable run, so making the payload cheaper improves both.

## Observation 3: one-row frame per pulse for strategy state

`buffer_strategy_state()` at `R/backtest-runner.R:471` builds a `data.frame()`
per pulse into a list grown in thousand-element chunks with `c()`, then flushes
with `do.call(rbind, ...)`. That is shape 1, the first shape the manual names.

At 1,260 pulses the absolute cost is small and it did not surface in the
profile. Record it as a cleanliness item rather than a performance one.

A related minor point: `write_strategy_state()` issues one `INSERT` per pulse
in live event mode. Buffered mode uses the batch path, so the registered peer
record does not exercise it.

## Observation 4: snapshot hashing reformats repeated timestamps per row

This is the largest single item found and it sits outside the engine phase, in
snapshot creation and in the per-run rehash above.

Dense snapshot creation at 200 instruments and 1,260 sessions takes 5.34
seconds for 252,000 bars. Of the 3.4 seconds sampled, `ledgr_snapshot_seal()`
is 60 percent and `ledgr_snapshot_hash()` within it is 58.8 percent. Sampled
self time is 50 percent `format.POSIXlt`, 20.6 percent `sprintf`, and 11.2
percent `paste` and `paste0`. The DuckDB layer is about 10 percent.

`ledgr_snapshot_hash_format_ts_utc()` at `R/snapshots-hash.R:8` is already
vectorised. The waste is that the bars timestamp column holds only one distinct
value per session, repeated once per instrument, and every row is formatted.

Measured at the release shape, 630,000 rows over 1,260 distinct timestamps,
mean of 30 calls:

| Approach | Per call |
| --- | ---: |
| `format(ts, fmt, tz)` for every row, as today | 3,390 ms |
| `collapse::funique()` + `collapse::fmatch()` | 14.7 ms |
| `collapse::group()` + `funique()` | 15.7 ms |
| base `unique()` + `match()` | 19.7 ms |
| `collapse::qG()` + `funique()` | 28.3 ms |
| `collapse::qF()` + format the levels | 34.7 ms |

Every variant is byte-identical to the current output, verified with
`identical()`. That matters: it changes no hash value, needs no
`hash_rule_version` bump, and touches no identity contract. It is shape 4 of
the optimization coding style applied to timestamps rather than JSON.

On the choice among variants: `funique()` and `fmatch()` are the fastest and
collapse is already a declared dependency, so they add nothing. Note that the
collapse factor generators are the wrong tool here. `qF()` and `qG()` are
slower than base `unique()` and `match()` for this job, because constructing a
factor or grouping object does more work than a dedup-and-remap needs. The
choice among variants is worth about 5 milliseconds; deduplicating at all is
worth about 3,370. Do not spend review time on the tiebreak.

That table is measured over the whole 630,000-row column, and production does
not see the column whole. `ledgr_snapshot_hash()` streams with
`chunk_size = 10000` at `R/snapshots-hash.R:104`, ordered by
`instrument_id, ts_utc` at `:168`. A dedup dropped into the existing formatter
therefore deduplicates within a chunk, not globally, and at 500 by 1,260 each
10,000-row chunk still spans most of the calendar. Measured in that shape:

| Dedup window | Format calls | Time |
| --- | ---: | ---: |
| none, as today | 630,000 | 3,200 ms |
| `chunk_size` 10,000, as shipped | 79,380 | 410 ms |
| `chunk_size` 50,000 | 16,380 | 80 ms |
| `chunk_size` 100,000 | 8,820 | 50 ms |
| whole column | 1,260 | 20 ms |

Every row byte-identical. So the realizable gain at the shipped chunk size is
about 7.8 times, not the roughly 160 times the whole-column row implies. That
is still worth about 2.8 seconds of the 7.95-second hash and it still pays
twice, but the mechanism is throttled by the streaming design. Widening the
window or carrying a cross-chunk cache recovers the rest and is a
bounded-memory question for datasets whose timestamps are mostly unique, not a
free change. Observation 4 is therefore a strong candidate but not the
implementation-free one an earlier revision of this note described.

A gate for it needs real `ledgr_snapshot_hash()` timings at several
`chunk_size` values, exact old-equals-new hashes, bounded-memory evidence,
both rule 1 dense and rule 2 availability snapshots, and old-snapshot reopen
plus tamper detection.

The saving applies twice, once at seal and once per durable run. It also grows
with instrument count, since the distinct-timestamp count stays at the session
count while the row count does not.

## Observation 5: the hash payload could be bytes instead of strings

Larger than observation 4 and more expensive to adopt. Recorded together with
it because they target the same function and should be decided in order.

Today the hash builds a canonical string payload: `sprintf("%.8f", ...)` per
numeric column, formatted timestamps, `paste()` row assembly, then a digest
over the concatenated text. The alternative is to round as today, convert
timestamps with `as.numeric()`, and digest the raw bytes.

Measured over the bars table at the release shape, 630,000 rows, five numeric
columns plus the timestamp column:

| Payload | Time |
| --- | ---: |
| `sprintf`, `format`, `paste`, digest, as today | 7,283 ms |
| `round()`, `writeBin()`, digest of raw bytes | 173 ms |

Components: `sprintf` over the five numeric columns is 2,540 ms and timestamp
formatting about 3,390, while `round()` costs 70 ms and SHA-256 over roughly
50 MB of raw bytes costs 127. The hash stops being formatting-bound.

What is and is not measured. The 7,283 ms figure is a reconstruction of the
payload shape, not an instrumented run of `ledgr_snapshot_hash()`. It sits
close to the 8.11 seconds that function actually takes for a 500-instrument
rehash, which suggests it covers most of the real cost, but the end-to-end gain
was not itself measured. Do not quote a whole-hash speedup from it.

The cost of adopting it is the part observation 4 does not have. Every hash
value changes, so it requires `hash_rule_version` 3. The mechanism exists,
rules 1 and 2 are in use and legacy snapshots stay on rule 1 without rehashing,
but this is a snapshot identity decision rather than an optimization.

Four canonicalization choices come with it:

- keep `round(x, 8)`. It collapses last-bit float noise, and hashing the bytes
  of the rounded value preserves that tolerance because two inputs rounding to
  the same decimal give the same double. Hashing unrounded doubles would make
  the hash stricter and could raise spurious corruption alerts;
- normalize what the string form hid. Negative and positive zero have distinct
  bit patterns but both print as `0.00000000`; `NaN` has many bit patterns and
  R's `NA_real_` is a specific one; infinities likewise. Each needs an explicit
  canonical encoding;
- pin endianness, for example `writeBin(..., endian = "little")`; and
- keep the existing string-encoding normalization for character columns, which
  still have to be hashed as bytes of a normalized UTF-8 form.

The chunking correction in observation 4 favours this option. Deduplication
exploits repetition, so streaming in 10,000-row chunks throttles it. Byte
conversion is per-value work and is chunk-insensitive, so its gain survives the
streaming design intact. The gap between the two options is wider than the
headline numbers suggest.

The version question is also bigger than a number bump. Rule 1 is the
historical bars and instruments hash, rule 2 adds availability evidence, and
only those two are accepted at `R/availability-persistence.R:122`. A binary
base payload touches both, so "rule 3" must say whether it means a binary
dense rule with a separate rule 4 for binary plus facts, or one rule with an
explicitly encoded optional facts section. Beyond endianness and the special
doubles above it also needs field and row framing, length-prefixed character
values, a missing-value encoding distinct from the literal string `NA`, column
order and type tags, fixed integer and double widths, block-boundary rules,
golden cross-platform byte vectors, and a guarantee that rules 1 and 2 keep
verifying without rehashing.

That is an identity RFC, not an implementation ticket, and it must not share a
ticket with the byte-identical timestamp work.

Order of adoption: observation 4 first, because it is byte-identical and needs
no identity decision. This one is separate, worth more, and gated on the RFC.

## Observation 6: CSV import reformats timestamps it just parsed

This one is in shipped package code on a user-facing path, not in the engine
and not in the benchmark harness. That distinction decides whether it is worth
doing, so it comes first.

The peer harness reads its bars CSV with `utils::read.csv()` at
`dev/bench/peer_benchmark/peer_benchmark.R:346`, `:406` and `:603`, inside
`snapshot_prepare_sec`. Making the harness read faster would improve ledgr's
published cold number without improving ledgr. That is declined here and
should stay declined. It is also beside the point, because the harness calls
`ledgr_snapshot_from_df()` and never touches the package's CSV importer.
Nothing in this observation moves a peer number.

What it does move is `ledgr_snapshot_from_csv()` at
`R/snapshot_adapters.R:526` and `ledgr_snapshot_import_bars_csv()` at
`R/snapshots-import-bars.R:92`. Both are exported, and both are what a user
calls to turn a CSV into a snapshot.

Measured at the release shape, 500 instruments and 1,260 sessions, 630,000
rows of ISO8601 bars, one cold run each:

| Path | Time |
| --- | ---: |
| `ledgr_snapshot_from_csv()` end to end | 20.36 s |
| `ledgr_snapshot_import_bars_csv()` | 10.25 s |

Sampled self time inside the import is 31.0 percent `format.POSIXlt`, 24.8
percent `scan`, and 10.5 percent `strptime`. By total time, `paste0()` is 33.4
percent, `read.csv()` 30.5, and `ledgr_csv_parse_ts_utc()` 17.6.
`DBI::dbAppendTable()` is 6.9 percent, so the database is again not the cost.

Three separable items, isolated at the same shape:

| Component | Today | Alternative |
| --- | ---: | ---: |
| duplicate-key check, `R/snapshots-import-bars.R:158` | 3.38 s | 0.02 s |
| `utils::read.csv()`, no `colClasses` | 4.02 s | 0.67 s |
| `ledgr_csv_parse_ts_utc()`, `R/csv-utils.R:66` | 1.85 s | 0.02 s |
| five `ledgr_csv_parse_num()` calls | 0.09 s | not a candidate |

The duplicate-key check is the clearest defect, and it is shape 4 again. Line
158 formats all 630,000 `ts_utc` values back into strings with
`format(ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")`, pastes each to its
instrument id, and runs `anyDuplicated()` over the resulting character vector.
Those timestamps were parsed from strings six lines earlier, so the round trip
buys nothing. The check only needs to know whether an instrument and timestamp
pair repeats. `collapse::fduplicated(list(iid, as.numeric(ts_utc)))` answers
that in 0.02 seconds, and `anyDuplicated()` over a two-column frame of the
same values answers it in 0.39 with no new call. All three agree on the
fixture.

`ledgr_csv_parse_ts_utc()` is the same dedup as observation 4, on the same
kind of column and for the same reason: 1,260 distinct timestamps repeated
across 630,000 rows. Deduplicating the parse gives an `identical()` result.
The ISO8601 regex is only 0.09 seconds of the 1.85 and can validate the
distinct set instead, since `grepl()` is elementwise.

The reader is the one item that is a choice rather than a repair. Declaring
`colClasses` for the seven known bars columns is a four-times gain with no new
dependency, and the parsed result is `all.equal()` to today on well-formed
input. It is not automatically free of behavior change, and an earlier revision
of this note overstated that. `ledgr_read_csv_strict()` is shared with
instrument import, so the declaration belongs at the call site rather than in
the shared reader, and forcing numeric classes makes `read.csv()` reject
malformed input earlier than `ledgr_csv_parse_num()` would, changing which
error fires and what it says. It needs compatibility tests for numeric-looking
instrument IDs and leading zeros, missing or extra columns, optional volume,
malformed numerics, error class and ordering, and BOM and encoding handling.
Beyond that,
`duckdb::read_csv_auto()` reads the same file into a data frame in 0.17
seconds and duckdb is already an Import, while `data.table::fread()` is 0.10
seconds single-threaded but data.table is not a dependency at any level, which
makes it the only option here that widens the dependency surface. The order
that respects the existing dependency stance is `colClasses` first,
`read_csv_auto()` only if more is wanted, `fread()` only if data.table is
wanted for other reasons.

Together these would put `ledgr_snapshot_import_bars_csv()` near 3 seconds
against 10.25 today. `ledgr_snapshot_from_csv()` also pays the seal hash, so
observations 4 and 5 apply to it on top of this.

One suspicion that did not survive measurement: `fileEncoding = "UTF-8"` in
`ledgr_read_csv_strict()` is not a cost. It is 0.14 seconds of the 4.02.

## Observation 7: the same reformat sits on the registered path

Observation 6 raised a scope question about whether an unregistered path
counts. That question turns out to matter less than it first appeared, because
the same defect is in `ledgr_snapshot_from_df()` at `R/snapshot_adapters.R:38`,
which the peer harness calls directly at
`dev/bench/peer_benchmark/peer_benchmark.R:349`. This one is exercised by the
registered workload on every durable row.

The harness converts its CSV column to POSIXct and passes it in. `from_df`
takes the POSIXt branch and at `R/snapshot_adapters.R:104` formats all 630,000
values back into ISO8601 strings. Measured at the release shape:

| Item | Today | Deduped |
| --- | ---: | ---: |
| `format(ts_posix, fmt, tz)` at line 104 | 3.25 s | 0.02 s |
| `ledgr_snapshot_from_df()` total, POSIXct input | 11.91 s | |
| `ledgr_snapshot_from_df()` total, character input | 13.70 s | |

The deduped form is `identical()`. So roughly 27 percent of `from_df` at this
shape is reformatting 1,260 distinct timestamps 630,000 times, on the path the
benchmark measures.

Two further facts about the character branches, which a user hits directly.

For ISO8601-Z input the round trip at `R/snapshot_adapters.R:127` and `:131` is
provably an identity. The branch parses `ts_raw` to POSIXct, which it needs,
and then formats it back to a string that is `identical()` to `ts_raw`,
verified at this shape. The parse must stay because `ts_posix` is used later;
the format can be replaced by `ts_utc <- ts_raw` and saves the same 3.25
seconds.

The other character branches are cheap but are not identities, and an earlier
revision of this note wrongly gave the date-only branch "the same character".
It does not have it. The branch at `:125` turns `2020-01-01` into
`2020-01-01T00:00:00Z`, so the original string cannot be preserved; the saving
there is appending a constant suffix instead of calling `format()`. The no-Z
datetime branch at `:132` to `:137` is the same shape, its normalized output
being the input plus `Z`, and it was omitted entirely.

Before any of this is ticketed, register an explicit branch matrix covering
POSIXct, Date, date-only character, ISO datetime with `Z`, ISO datetime
without `Z`, the `ledgr_iso_utc` fallback, and invalid or mixed-form input.
Each branch needs its own stated before and after, because only one of them is
an identity.

The fallback at `R/snapshot_adapters.R:139` and `:146` is shape 3 and is the
worst thing in this note per row. It calls `vapply(ts_raw, ledgr_iso_utc,
character(1))`, once per row. On 20,000 rows it takes 1.58 seconds, which
extrapolates linearly to roughly 50 seconds at 630,000; the extrapolation was
not run to completion. It is only reached for timestamp forms the three fast
branches miss, so the peer workload never touches it, but a user with an
unusual timestamp column pays it.

## Measured non-candidates

Recorded so they are not re-proposed.

Replacing `paste()` with `sprintf()` for row assembly is slower, not faster. At
252,000 rows, `paste(a, b, c, d, sep = ...)` takes 0.020 seconds against 0.080
for the equivalent `sprintf()`, with identical output. Appending the newline is
a tie at 0.020 seconds either way. The numeric path already uses `sprintf()`;
`formatC()` is about 1.4 times faster there but produces different strings, so
it would change the hash and is not a drop-in.

The string-function choice is not where the cost is. The timestamp formatting
in observation 4 is.

Deduplicating the numeric columns does not help, because they are not
repetitive. At 630,000 rows the four price columns are 100 percent distinct and
volume is 97.6 percent, so `funique()` and `fmatch()` come out slightly slower
than formatting directly: 472 against 444 milliseconds on close. The same
technique on a genuinely repetitive two-value column is 33 times faster, which
is why it works for timestamps and not here.

`collapse::timeid()` fits neither column. On prices it aborts with "GCD is
approximately zero", which is expected since it derives a step from the
greatest common divisor of sorted unique differences and arbitrary doubles have
none. On timestamps it runs in 10 ms but its identifiers are relative to the
vector it sees: the same timestamp took identifier 883 in the full column and 1
in a June-onward subset. That is correct for grouping and wrong for a content
hash, since adding one earlier row would renumber everything after it.
`as.numeric()` measured at 0 ms, is absolute, and is exact because ledgr
timestamps are whole seconds by contract.

`round()` is also not a cost worth removing. It is small against the 2,540 ms
`sprintf()` that follows it, and it carries the tolerance described in
observation 5.

The per-instrument chronology check at `R/snapshot_adapters.R:185` is not a
candidate either, and it was probed because it looked like one. `tapply()` over
500 instrument groups with a closure calling `diff()` costs 40 ms at the
release shape. An order-and-group rewrite using `collapse` came out about 20
times slower at 780 ms, because the ordering dominates and `tapply()` over a
few hundred groups is already cheap. `tapply()` is not automatically shape 1;
group count is what decides, and 500 groups is not many.

## Scope and authorization

The accepted hot-path complexity amendment excludes this work by name. Its
non-goals cover general loop cleanup, dense and availability finalization,
result readers, and broader loop work. None of these observations is a Batch 9,
Batch 10, or Batch 11 item, and none may be folded into the release gate.

Observations 1 and 2 together account for roughly 28 percent of the durable
engine phase at the measured shape. Observation 4 accounts for roughly a
quarter of dense snapshot creation and repeats inside the per-run rehash. That
makes them plausible candidates for a later cycle, subject to the usual rule: a
candidate becomes work only when it is avoidable, exercised by a registered
workload, and material there.

Observation 4 is the strongest candidate on effort against benefit. It is
byte-identical, so it carries no identity or hash-rule consequence, and it pays
twice. Observation 5 is worth more but is a snapshot identity decision, and a
measured speedup does not waive the semantic, persistence, identity, and
reopen gates any more than it does elsewhere in this packet. Decide them in
that order, not together.

Observations 6 and 7 share a scale-growing timestamp-conversion pattern across
distinct contracts; they are not one reachable defect. Observation 7 passes
the candidate rule outright: the reformat at `R/snapshot_adapters.R:104` is
avoidable, is material at roughly 27 percent of `from_df`, and is exercised by
the registered peer workload on every durable row. No new workload is needed
to authorize that correction.

Observation 6 remains outside the registered workload because nothing in the
benchmark calls the strict CSV importer. Decision 1 nevertheless settles its
direction: correct the strict importer under the shared compatibility matrix.
Decision 2 puts the public `from_csv()` wrapper and its `from_df()` path under
the future registered workload; it does not register
`ledgr_snapshot_import_bars_csv()` or its duplicate-key check.

The duplicate-key check at `R/snapshots-import-bars.R:158` stands apart from
that argument entirely. It formats data it already holds in parsed form, for a
comparison that never needed strings, and removing it is behavior-preserving
on any input. That is a defect repair rather than an optimization.

None of this licenses touching the harness. Its `read.csv()` calls are
measurement scaffolding, and making them faster would improve a published
number without improving ledgr. The registered-workload argument above is
about `from_df`, which is package code that the harness calls, not about the
harness itself.

## Projected outcome if everything here is adopted

An estimate, not a measurement. Recorded so the cycle that does the work can
check itself against it, and so nobody has to re-derive it. It assumes every
observation above including the byte payload of observation 5, and both
decisions.

The snapshot side is decomposed from direct measurement.
`ledgr_snapshot_from_csv()` at 500 by 1,260 is 19.89 seconds: the strict read
4.19, `ledgr_snapshot_hash()` 7.95, the line 104 reformat 3.25, and an
irreducible remainder of 4.50 covering validation, rounding, the DuckDB append
and seal bookkeeping. That 7.95 independently corroborates the 8.11 quoted in
observation 4. Optimized it becomes roughly 0.67 plus 0.02 plus about 0.84
plus the unchanged 4.50, so near 6 seconds.

| Durable phase | Registered | After Batch 8 | Projected |
| --- | ---: | ---: | ---: |
| snapshot prepare | 19.86 | about 19.9 | about 6.0 |
| experiment setup | 0.41 | 0.44 | 0.44 |
| engine | 136.67 | 49.37 | about 41.3 |
| results | 9.66 | 10.07 | 10.07 |
| cold end to end | 166.60 | about 79.8 | about 57.8 |

Read the projected cold as a range of 55 to 62 seconds rather than a point, and
as an aspiration rather than a defensible forecast. It is not a target for
v0.2.0.1 and must not become a reason to fail an otherwise valid release gate.

The 0.84-second hash in that arithmetic assumes observation 5. Observation 4
alone does not reach it: inside the shipped `chunk_size` the hash lands near
5.2 seconds rather than 0.84, which moves the projected snapshot phase from
about 6.0 to about 10.4 and the projected cold to about 62. The two
observations are not interchangeable, and the binary payload is doing most of
the work in the headline figure.

Two warnings about the columns. The registered column is the 2026-09-17 record
taken at `6b09a1b`, which predates Batch 8, so it does not describe the
current tree. The Batch 8 column is a local probe and not a registered record;
the peer benchmark has not been rerun since Batch 8 landed, and it should be
before any of these projections are treated as a baseline.

The engine projection is the softest figure in this note. It subtracts the
guard rehash using the same reconstructed payload gain that observation 5 says
not to quote a whole-hash speedup from, and about one second for observation 1.
If canonicalization forces a slower encoding, the snapshot and engine numbers
move up together.

The memory-backed row does not move. It builds no snapshot, so observations 2,
4 and 5 do not apply to it, and it already passes `serialize_meta_json =
FALSE`. Its own snapshot phase is mostly harness scaffolding with no shipped
CSV equivalent, which is why decision 2 does not touch it.

For orientation only, and not as a claim to publish: the registered Backtrader
row is 85.69 seconds cold with 78.75 in the engine phase. No peer row changes,
because none of this work touches them.

## Reproduction

Profile `ledgr_run()` alone over the peer fixture shape rather than the whole
`peer_run_ledgr()` call. Profiling the full call mixes snapshot preparation and
result extraction into the same attribution and made the first pass misleading.
