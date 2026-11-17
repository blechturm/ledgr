# Feature-path oracle

The permanent differential harness of Cut 22 decision 2 (LDG-3249). It runs
the installed pin `d5b3a151` and a candidate ledgr on one case corpus and
diffs what they observe. Any feature-path change is compared with it before
it lands.

| file | role |
| --- | --- |
| `corpus.R` | substrates, definition sets, axes and public-entry fixtures (from `dev/spikes/feature_stage1_probe/fixtures.R`, extended with the RFC's case list) |
| `runner.R` | one arm per fresh process: loads ledgr from a library (`--lib`) or a source tree (`--source`), runs every case, writes `observations.csv` and `provenance.csv` |
| `check.R` | diffs a candidate's observations against the pin's and both against `corpus_expected.csv`; exit 0 pass, 1 difference (one `SIGNAL` line per differing component), 2 refusal (missing arm, case or component) |
| `faults.R` | the fault controls: seven deliberate faults each exit 1 with their own signal; a missing arm, case or component refuses; the pin against itself passes |
| `install_arm.R` | installs a commit as an arm (git archive, `R CMD INSTALL`) with its commit marker and R/ source hashes |
| `corpus_expected.csv` | the corpus: every case, and each case's certification, field union, route, refusal class and TTR-route agreement as the pin produced them |
| `memory.R` | candidate 5's memory rule (LDG-3252): object bytes and peak R heap of sweep feature preparation in fresh children |
| `census.R`, `census.csv` | the engine-version census (LDG-3253): the walk from the preparation roots and the replacement proof of every row |
| `timing_launch.R` | starts the shared timing runner with its temporary directory outside AppData/Local/Temp |
| `evidence/<ticket>/` | each ticket's commands, transcripts and the pin's observations under that ticket's harness |

## Cases (548)

- `compute` (378): 7 substrates x 3 calculation starts (data start, a late
  start, past the end) x 18 definition sets through
  `ledgr_history_compute_feature_series()`. The measuring step's 6 x 3 x 15
  are included unchanged; added: an empty and a 12-bar instrument, every
  package catalogue row (all warmup rules and documented or derived
  outputs, MACD histogram included), `stable_after` greater than
  `requires_bars`, and an unregistered ohlc form beside a custom ohlc
  callback.
- `read_entry` (14): the single-definition read entry
  (`ledgr_history_feature_planes()`), the measuring step's cases.
- `ttr_route` (132): each TTR catalogue row on three one-knowledge-range
  substrates, through the cached raw call (compute) and the emitted closure
  (`ledgr_ttr_call()`, the read entry); the two must be identical.
- `axis` (6): the formatted pulse axis at every consumer (matrix dimnames,
  `pulse_index`, `pulses_posix`, `pulses_iso`, the projection, its slice and
  the precompute `axis_hash`) on UTC, named, empty, New York, fractional and
  unset-time-zone axes.
- `e2e` (18): on both clocks (a bar-native fixed basket; declared sessions
  with gaps, a late-known inactive instrument, input and output carry): a
  run, an implicit sweep, explicit precompute and a sweep reusing it, pulse
  inspection, a run whose scoring starts after the data start, and a
  lookahead feature refusing a run (FAILED, no events, equity or strategy
  call), a sweep and a precompute.

## Components

Every case records `route` (calls of the built-in SMA, the registered raw
TTR call `ledgr_ttr_raw_call()`, `ledgr_ttr_call()` and the two callback
entries), `callback` (the columns and rows of every frame handed to a
custom callback), `causality` (the probe's definitions, instruments and
sampled positions in order), `refusal` (condition classes and every
identifying field), `refusal_class` and `rng` (the caller's
`.Random.seed` unchanged). Compute cases add `certification`, `field_union`,
`values`, `na`, `planes` (plane records), `proj` (the projection with its
indexed planes) and `reads` (history-read evidence over every instrument and
session). Values are sha256 digests of the R objects, so types, attributes,
names and encodings are compared exactly. The declared differences of
decision 1 are left out: the engine version (passed as `"fixed"` or
removed) and the precompute payload's physical shape (compared by feature as
matrices with planes and fingerprint-to-ID mapping). The generated snapshot
ID is compared only as agreement with its fixture.

## Commands

    Rscript dev/feature_parity/install_arm.R --repo=<git tree> --commit=<sha> --lib=<new dir>
    Rscript dev/feature_parity/runner.R --arm=<label> --lib=<library> --out=<dir>
    Rscript dev/feature_parity/runner.R --arm=<label> --source=<tree> --out=<dir>
    Rscript dev/feature_parity/check.R --pin=<pin out> --candidate=<candidate out>
    Rscript dev/feature_parity/faults.R --lib=<pin library> --pin=<pin out> --scratch=<dir> --evidence=<dir>

Each ticket's exact commands and results are in `evidence/<ticket>/COMMANDS.md`.
