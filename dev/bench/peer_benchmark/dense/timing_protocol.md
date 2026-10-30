# Public cold/warm baseline protocol (LDG-3136)

Frozen before measured attempts or baseline promotion. Authority: cut 2,
LDG-3136/3137, synthesis D7/D9, benchmark methodology host rules. Canonical
product source **LDG3136_FREEZE_COMMIT**; accepted native oracle freeze
**cbf25359**. Independent close reviewer: clean-context Claude, pending.
This baseline changes no product code and has no speed threshold.

## Workload and reuse

Exactly two dense daily transition-only SMA5/10 shapes: 12 instruments x 90
sessions (1080 bars, fixed overhead diagnostic) and 500 x 1260 (630000 bars,
daily anchor). Public ledgr_sim_bars seed 20260530, Jan 1 2020 start, P IDs,
21:00 UTC bars; cash 1e7, zero cost/no risk, one-share targets. Feature map is
public TTR SMA5/SMA10, matching dense_transition in recipes.R. Two consecutive
usable scores must cross; warmup holds. Input preparation verifies that buying
one of every asset at each session's opens is affordable. Actual results must
have nonnegative cash, unit fills, zero fees and DONE status. No schedule,
precomputed feature payload or private output-handler/engine call.

run_timing.ps1 exports the explicitly pinned git revision into a fresh TEMP tree and
installs it into a fresh isolated library. Installation, standard package
byte compilation and common simulated raw-bar generation are outside clocks.
Each child verifies its loaded ledgr namespace is that installation. Common
input RDS files are generated once; their read IO belongs to every cold clock.
This is a deterministic public synthetic fixture, not a historical peer record.

Five separate R processes per shape. Each performs cold then warm, with a new
experiment, opening and run ID for each book. The same unchanged sealed native
snapshot is reused in warm; the first run's book/state/results are not reused.
Native config/snapshot hashes and actual economic controls must agree exactly.
Raw input bars, loaded namespaces, compiled code and completed first-use work
remain resident; all features hydrate again inside each public ledgr_run.
The small core probe executed both books and matched the frozen transition
oracle's fills, terminal cash/equity and every terminal asset quantity exactly.
Its unpinned/busy-host clock values are not promoted to this baseline.

## Clocks and results

The parent records UTC launch milliseconds immediately before starting R.
At its first instruction the child captures UTC and proc.time elapsed. Cold
is the observed parent-to-child startup plus monotonic child elapsed through
required result materialization. It includes R/script startup, installed-package
import and harness bootstrap, input read, public snapshot creation/sealing,
experiment/feature declaration, public run and public result reads. Startup's
wall-clock precision is 1 ms; other phases use R elapsed-clock resolution.
This is a process-cold clock, not an OS/filesystem-cache-cold claim.

Warm starts immediately before a new experiment/feature declaration and ends
at the same required results. Setup, run and results phases are measured in
both; startup/import/input/snapshot phases are explicitly excluded (NA) in
warm. A residual phase reconciles clock/phase boundaries to 1 microsecond
(arithmetic tolerance for clocks only; economic controls use identical).
Engine run time is diagnostic and never substitutes for a public clock.

Required objects inside each endpoint: public fills and equity plus public
ledgr_state_reconstruct cash and terminal holdings for every ID, including zero.
No accounting is reconstructed by the harness. Output validation, control SQL,
environment/record writing, closing connections/books and explicit gc between
books are outside clocks. Per-arm native controls: fill count, terminal
cash/equity, keyed full-precision asset quantities, opening cash/position value,
first persisted strategy state and native snapshot/config hashes. RDS v3 is the
lossless primary record; readable timing CSV uses 17 significant digits.

R_ENABLE_JIT=3 is configured before process launch and observed through
compiler::enableJIT; standard installed package bytecode is already present.
Cold includes any remaining first-use compilation; warm follows a completed
cold run in the same process. Persisted strategy_state row counts and equity
row counts report observed decision callbacks/pulses (excluding preflight
validation invocations), without instrumenting the timed strategy.

## Shared host observation, order and limits

Windows i9-12900K host: High performance GUID
8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c. Parent affinity is set to 0xFFFF before
R starts; actual child affinity is observed and must equal 0xFFFF.
OMP/OPENBLAS/MKL/NUMEXPR thread limits are 1; actual DuckDB thread setting is
reported, not overridden through a private connection policy.

Every host observation loads repository-relative dev/bench/timing/host.R and
calls timing_host_probe(harness_dir = dev/bench/timing/), whose only process
probe is host.ps1. The preflight and per-attempt before/after probes are all
outside the cold and warm intervals. The record binds the harness commit and
the actual host.R and host.ps1 Git blobs. High performance and the inherited
0xFFFF root/child affinity are qualifying rules. CPU load and foreign R
processes are retained as observations under the shared harness policy and do
not select or replace a run. No dense-local host parser, host.ps1 copy or
generic paired-gate runner/checker exists.

Cold precedes warm per required lifecycle. Shape order is counterbalanced:
odd repetitions small then anchor; even repetitions anchor then small. All
ten processes are serial. No automatic retries, favourable subset or replacement
shape. Each process has a 1200-second limit; the whole measured window has
5400 seconds, including inter-attempt overhead. Invalid, failed, censored and
unstarted required rows leave readiness incomplete. Preserve every attempt,
partial cold results and logs, then stop for maintainer disposition.

## Runner, checker and failure demonstrations

```powershell
& dev/bench/peer_benchmark/dense/run_timing.ps1 -Out dev/bench/peer_benchmark/records/20261030-current-tree -SourceRevision LDG3136_FREEZE_COMMIT
& 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe' --vanilla dev/bench/peer_benchmark/dense/timing_check.R --records=dev/bench/peer_benchmark/records/20261030-current-tree --gut
```

Checker requires all 20 clock cells, ten unique processes, full schemas,
finite positive clocks, reconciled phases, installed source/path, shared-host
identity and observations, JIT/reuse and required-output evidence. Every
cold/warm economic control compares exactly
with that shape's first cold baseline; small economics also match the native
oracle. The large row is timing-only, not a full-path parity claim. Four
behavioral guts use the actual measured record: remove one cell; invalidate
affinity; mark an attempt censored; change one terminal asset quantity with
times/equity unchanged. Together with six oracle guts this is ten behavioral
detectors. Four additional structural demonstrations remove the live shared
call, repoint host.R locally, repoint its harness directory and move a probe
inside the timed interval.

New R: timing.R (worker/input preparation), timing_check.R (collection/check/guts).
Windows-only process orchestration is run_timing.ps1, not hidden R helpers.
All fresh R remains below the accepted 1500-line allowance. Stop on unexplained
native differences or resource limits; no optimization round in this cut.
Baseline readiness needs its independent Type 1 close review and a fresh native
oracle check on the measured product. No peer, report, memory or speed claim.
