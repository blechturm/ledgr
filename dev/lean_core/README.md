# dev/lean_core

The lean fold core grows here beside the pinned build `d5b3a151` (macro
WS16). Nothing in `R/` calls this directory, and `dev/` is excluded from the
package. Authority: `inst/design/ledgr_v0_2_3_spec_packet/lean_core_interface.md`
(Sections 8, 9, 14 and 17).

## Loading

```r
source("dev/lean_core/load.R")
lean <- lean_core_load("<pinned library>", debug = FALSE)
```

`lean_core_load()` refuses any build but the pin. An installed library must
hold `LEDGR_INSTALLED_FROM_COMMIT` = `d5b3a151`, and the ledgr namespace must
load from exactly `<lib>/ledgr`, checked before and after loading. A source
archive (the test-suite capture) must hold `LEDGR_SOURCE_COMMIT` =
`d5b3a151`, is loaded with `pkgload`, and must be the namespace's own path.
Lean files (`dev/lean_core/*.R` except `load.R`) are sourced into one
environment whose parent is the ledgr namespace; `debug` is stored there as
`.lean_debug`.

## Recorder (LDG-3212)

| File | Role |
| --- | --- |
| `recorder/fields.R` | Parses the table: replay field lists with Section 8's write flags, mutable `services` fields, the 22 slots, the clock allowlist. |
| `recorder/capture.R` | Wraps the pinned boundary functions and freezes each call's input and output; writes manifests. |
| `recorder/compare.R` | `lc_compare()`, the one comparison for every family. |
| `recorder/replay.R` | `lc_replay()`, the replay check. |
| `recorder/run.R` | Runner: captures, replays each capture in a fresh R process, writes evidence and manifests. |
| `recorder/omissions.R` | The seven registered omissions and the review's witnesses. |
| `recorder/check.R` | Checker: reruns both into a scratch directory, diffs, gates, guards package scope. |
| `recorder/findings.csv` | Table gaps the replay found, with evidence and resolution. |

Boundaries: `E`, `P1`-`P5`, `P2_skip`, `P3_skip`, `E_skip_row` (E's staging
of the skip row), `E_stop`, `E_flush`, `lot` (every `ledgr_lot_apply` call),
and the preparation boundaries `hydrate`, `substrate`, `features`, `reader`,
`packet` and the history reads `history_read` (`ledgr_history_read_plan`:
view, request, decision planes), `history_frame` and `history_matrix` (the
plan's frame or matrix). The public `ledgr_history_frame()` and
`ledgr_history_matrix()` take the pulse context, whose closures reach the
whole `services` list, so reads are captured through these three
(`capture.R`, `lc_boundaries`).

### Freezing

Values are serialized in format 2, which writes an ALTREP vector's
materialized data, so an in-place write to a compact sequence is captured.
Each environment a value reaches becomes a node whose bindings are stored
one by one under content digests; atomic vectors of 2,048 or more elements
are separate leaves. Only prepared planes (leaves of the substrate and
feature outputs and of the runtime projection, immutable under Section 12.1)
are remembered by address; everything else is serialized at every boundary,
and every 25th reuse of a remembered plane is re-serialized and checked.
Thawing builds new environments and copies every leaf, so no two thaws
share a buffer. An unforced promise is not forced; replay refuses to read
it.

`ledgr_feature_engine_version()` fingerprints function bodies, among them
the wrapped `ledgr_history_compute_feature_series()`; it runs on the pinned
bindings, and `run.R` stops if its value under capture differs. The JIT is
off during capture so a closure's serialization does not change when it is
compiled.

### Comparison and replay

`identical()` over values, names, attributes, types and order. The table's
clock fields are dropped only at their owners' paths: a stage's timing
locals (its value, P1's observation, and the observation, decision, plan
and apply arguments that hand them on) and the telemetry environment
(`lc_clock_paths()`); the same names elsewhere are compared. Closures are
compared on formals and body without source references (Section 14), then
attributes and environment by content.

Replay runs in an R process that holds only the pinned build, the recorder
and the capture: no workload is sourced and the global environment is empty,
so a global read fails. Fold state and `services` are reduced to the table's
fields for the boundary; reading or writing another slot, or reading another
field through `$`, `[[` or `[`, raises `lc_unnamed_field`. The full captured
output is compared: undeclared slots and fields must equal their input, and
a named slot Section 8 does not let the boundary write must be unchanged in
the capture. The pinned namespace's code and constants are trusted as the
oracle and are not sealed.

### Manifests

`recorder/manifests/<workload>.csv`: per boundary, captured calls, raised
conditions and one SHA-256 over every call's canonical digests in order. A
call's digest covers its fold's fixed `services` and handler and writer
shapes, its frozen input and output, its condition and warnings, and each
handler or writer call with arguments, value and condition. Digests start
after the serialization header, so they do not depend on locale or R build
details. Left out of digests only (never out of the comparison): clock
fields at their owners' paths, a snapshot's `metadata$created_at`,
external-pointer contents, and a DBI object's run-specific state (it is
digested as its class, database directory, read-only flag and integer
mode). Snapshots are built in `<system temp>/ledgr_lean_core_work`, so
paths are the same from any checkout on one host.

### Running

```sh
Rscript dev/lean_core/recorder/run.R --lib=<pinned library> --src=<pinned source archive> --captures=<dir>
Rscript dev/lean_core/recorder/omissions.R --lib=<pinned library> --captures=<same dir>
Rscript dev/lean_core/recorder/check.R --lib=<pinned library> --src=<pinned source archive> --scratch=<empty dir>
```

**Day-to-day use by a family.** Capture only the family's own boundaries
with `--boundaries=` (names from `lc_boundaries` in `capture.R`), then
compare the lean function against the captured outputs. For example,
`--workloads=fill_heavy_500x1260 --boundaries=lot` captures and replays the
1,249 FIFO kernel calls in about 30 seconds. The full all-boundary run
(about 35 minutes on fill-heavy) is the table check: rerun it only when the
interface table changes or a family adds boundaries.

`run.R` also takes `--workloads=`, `--out=` and `--manifests=`. With `--src=`
it captures `history_fixture` in a child R process loaded from the pinned
source archive: the pinned tests' WS42 history fixture, sourced unchanged
with its temporary database path and clock-generated snapshot id pinned,
reading every public request shape on every decision pulse. Evidence
(`recorder/evidence/`): `replay.csv`, `table_fields.csv`, `omissions.csv`.

### Coverage limits

- Folds run in sweep worker processes (`workers = 2`) are not captured; the
  same candidates run in-process in each workload's one-worker sweep.
- The runner's own bars query (`R/backtest-runner.R:629`) is inline code with
  no function to wrap; every captured substrate build has a captured
  `hydrate` call (equal counts in `replay.csv`).
- A large atomic leaf (stored separately by the binding store) whose
  attribute is an environment shared with another binding thaws as two
  copies, so the sharing is lost (Codex round 2, synthetic witness; no
  registered workload contains one). Since the WS26 close review the
  comparison pairs environments one to one, so such a capture would fail
  replay rather than pass silently.
- Review: Codex round 1 (eight findings, all fixed) and a narrow round 2
  limited to wrong answers (`recorder/evidence/codex_review_round*.md`).
  Round-1 items outside that question were not re-reviewed. The WS26 close
  review (`recorder/evidence/ws26_close_review_round*.md`) found that the
  comparison ignored environment sharing and lock state, and that an atomic
  value with an environment attribute was both falsely rejected and able to
  skip the sharing check; all three are fixed (environments pair one to one,
  attributes are compared before bare payloads), and every existing capture
  replays clean under the stricter
  comparison, fill-heavy's full replay included
  (`recorder/evidence/replay_strict_compare.csv`, 23,224 records over the
  ten default workloads, the history fixture and the preparation fixture and
  500 x 1,260 captures).

## FIFO kernel (LDG-3213)

`fifo.R` is the one lean lot kernel: `lean_lot_input()` (the trusted input
boundary: economic rules in production, `ledgr_lot_input()`'s shape and
distinct-position checks in debug), `lean_lot_apply(book, input)` (same
arguments, result and refusals as the pinned `ledgr_lot_apply()`), the
operation wrappers `lean_lot_opening/fill/disposition()`, the block driver
`lean_lot_apply_blocks()` and the leg-fee split `lean_fill_leg_fees()`. It
calls no pinned arithmetic; it shares `ledgr_lot_input`, `ledgr_lot_applied`,
`ledgr_lot_book_problem`, `ledgr_lot_book_validate`,
`ledgr_accounting_event_error` and `ledgr_lot_blocks`.

```sh
Rscript dev/lean_core/recorder/run.R --lib=<pinned library> --captures=<caps> --out=<tmp> --manifests=<tmp> --boundaries=lot
Rscript dev/lean_core/parity/fifo_capture_tests.R --src=<pinned source archive> --out=<tests>   # about 25 minutes
Rscript dev/lean_core/parity/fifo_parity.R --lib=<pinned library> --captures=<caps> --tests=<tests> --out=dev/lean_core/parity/evidence
Rscript dev/lean_core/parity/fifo_check.R --lib=<pinned library> --captures=<caps> --tests=<tests> --scratch=<empty dir>
```

`fifo_parity.R` compares every captured call (A0 workloads, momentum,
fill-heavy, the pinned test suite) with debug off and on: the whole result or
the condition's class and message `identical()`, inputs unchanged, results
and inputs independent under later edits, fill leg fees equal to
`ledgr_fill_leg_fees()`. It runs the generated streams (`fifo_streams.R`),
the six registered mutations of `fifo.R` (each must fail) and a static scan of
the ledgr functions the lean code calls. Evidence: `parity/evidence/`.

## Preparation fixture and request set (LDG-3215)

`parity/prep_fixture.R` holds the cross-edge fixture and the registered
history-read request set (`lc_prep_strategy`, R1-R8). The fixture has six
instruments on 96 declared sessions; its exit while held (changed column
order), entry, re-entry, listing, relisting, carry expiry, late-known fact,
off-axis request and `min_observations` window with carried and missing
values all sit within one session of an edge shared by tile widths 8 and 12
(after sessions 24, 48 and 72). `parity/prep_edges.R` derives each event
from the fixture's input frames and checks it
(`parity/evidence/prep_edges.csv`).

The recorder runs it as `prep_fixture`, and the portable shapes as
`prep_500x1260`, `prep_500x2520` and `prep_500x5040` (the WS16 entry
momentum snapshot with the request set on each monthly decision); with
`--state=<build-state.json>`, `prep_h1` runs the private H1 store. These are
named explicitly and are not part of the default table-check run:

```sh
Rscript dev/lean_core/recorder/run.R --lib=<pinned library> --captures=<dir> --out=<dir> --manifests=<dir> --workloads=prep_fixture --boundaries=hydrate,substrate,features,reader,packet,history_read,history_frame,history_matrix
```

Manifests: `recorder/manifests/prep_*.csv` (counts and digests only; private
H1's capture stays on E:).

The long and thin intraday shapes (`prep_intraday_1x100k`, `_5x100k`,
`_20x50k`: 5-minute bars on the bar-native clock, the request set read once
a day) capture preparation only (`hydrate`, `substrate`, `features`,
`reader`; `run.R`, `lc_workload_only`). Every bar is a pulse, so a full
capture would freeze about 200,000 packets per 100k-bar shape, hours of work
that repeats what the short shapes already capture. Their history reads are
checked by a digest stream instead: `parity/prep_digests.R` runs the fixture
and the intraday shapes with the two public reads wrapped and records every
call's function, pulse and SHA-256 in order; `--against=<dir>` compares a
rerun (later, the lean read path) and stops at the first differing call.
Manifest: `parity/evidence/prep_digests.csv` (calls, first and last pulse,
one SHA-256 per workload and function).

```sh
Rscript dev/lean_core/parity/prep_digests.R --lib=<pinned library> --out=<dir> [--against=<reference dir>]
```
