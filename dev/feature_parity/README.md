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
| `faults.R` | the fault controls: eight deliberate faults each exit 1 with their own signal (all_fields not run, and recorded so, on a library without the field selector, checked before running; any runner failure fails the driver); a missing arm, case or component refuses; a cleared treated-fields observation, a dropped causality phase, or the preparation observer's outputs lost on refusing cases in both arms fails; the pin against itself passes |
| `install_arm.R` | installs a commit as an arm (git archive, `R CMD INSTALL`) with its commit marker and R/ source hashes |
| `corpus_expected.csv` | the corpus: every case, and each case's certification, field union, route, refusal class and TTR-route agreement as the pin produced them |
| `memory.R` | candidate 5's memory rule (LDG-3252): object bytes and peak R heap of sweep feature preparation in fresh children |
| `census.R`, `census.csv` | the engine-version census (LDG-3253): the walk from the preparation roots and the replacement proof of every row |
| `timing_launch.R` | starts the shared timing runner with its temporary directory outside AppData/Local/Temp |
| `evidence/<ticket>/` | each ticket's commands, transcripts and the pin's observations under that ticket's harness |

## Cases (631)

- `compute` (441): 7 substrates x 3 calculation starts (data start, a late
  start, past the end) x 21 definition sets through
  `ledgr_history_compute_feature_series()`. The measuring step's 6 x 3 x 15
  are included unchanged; added: an empty and a 12-bar instrument, every
  package catalogue row (all warmup rules and documented or derived
  outputs, MACD histogram included), `stable_after` greater than
  `requires_bars`, and an unregistered ohlc form beside a custom ohlc
  callback; and (close review round 1, F4) resolved parameterised forms
  (`ledgr_param()` through a feature map): single-output RSI and ATR, a
  BBands bundle, and both beside a custom definition.
- `read_entry` (22): the single-definition read entry
  (`ledgr_history_feature_planes()`): the measuring step's 14 cases and the
  four resolved parameterised definitions on two substrates.
- `ttr_route` (144): each TTR catalogue row and resolved parameterised TTR
  definition (`param:`) on three one-knowledge-range
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
`.Random.seed` unchanged) and `treated_fields` (the fields every
`ledgr_history_feature_inputs()` call actually treated, marked `prep:` or
`causality:`; close review round 1, F3). check.R does not compare
`treated_fields` between the arms: an arm with the field selector must treat
exactly the certified union recorded as `field_union` on a compute case, an
arm without it (the pin) all five fields, and the single-definition read
entry all five on every arm, each phase on its own. `handoffs` (re-review
1, G1) records, from other seams, the hand-offs each case reaches per phase
(the ranges the calculation and the causality probe get, the read entry's
bounded prefix, the definitions the probe checks) and how many were
observed; it is compared between the arms, and check.R requires a phase's
`treated_fields` entries exactly where that phase was observed, every
reached hand-off observed (a preparation refusal may stop early, but a case that reached preparation observes at least one hand-off; re-review 2, H1), and the
causality phase present exactly when the probe checked a definition.
Compute cases add `certification`, `field_union`,
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

Identities (Cut 22 decision 6; Cut 23 decision 5b adds the unchanged-engine
mode, in which an old precompute must be reused with the same result as fresh
preparation and each arm's record names must equal the committed
identity_names_unchanged_engine.csv, close review F1), the census (decision 5)
and the stored-config rebuild coverage (Cut 23 decision 5a):

    Rscript dev/feature_parity/identity.R --lib=<base library> --out=<base dir> --save-store=1
    Rscript dev/feature_parity/identity.R --lib=<candidate library> --out=<dir> --old=<base dir>
    Rscript dev/feature_parity/identity_check.R --base=<base dir> --candidate=<dir>
      [--mode=changed-engine | --mode=unchanged-engine --engine-prefix=<hex> [--expected=<csv>]]
    Rscript dev/feature_parity/identity_controls.R --base=<base dir> --candidate=<dir> --scratch=<dir> --engine-prefix=<hex>
    Rscript dev/feature_parity/census.R --source=<tree> --out=<dir> --census=<tree>/dev/feature_parity/census.csv
    Rscript dev/feature_parity/rebuild_coverage.R --lib=<library> --out=<scratch dir>

Each ticket's exact commands and results are in `evidence/<ticket>/COMMANDS.md`.
