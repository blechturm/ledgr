# Feature Engine Stages 2-3: Seed

- Author: Claude, 2026-11-18, at the maintainer's request (macro plan, order
  after Cut 20, item c: the feature cut for stages 2-3, before slice 5).
- Status: seed v1, for a Type 2 response. Binds nothing.
- Parent: the accepted feature-engine seed v2
  ([seed v2](rfc_feature_engine_v0_2_3_seed_v2.md)). Its Stage 2 and Stage 3
  sections, Section 4 (constraints), Section 6 (identity) and Section 7
  (maintainer answers) stay binding. This seed does not restate them; it
  turns them into a concrete design using the measurements seed v2 asked
  for, and names what it changes or leaves open.
- Code measured: release/v0.2.3, R/ at `68b505b9` (stage 1 by Cut 22, the
  legacy feature definitions removed by Cut 23); engine version
  `bc6a3ea254d0a37b`.
- Evidence: `dev/spikes/feature_stage23_probe/` (charter, runner, checker,
  gut; `probe_findings.md`; CHECK PASS). Timings were taken on a busy
  machine (another session's R workload), High performance plan, P-cores,
  7 repetitions; shares and ratios are the evidence, absolute seconds are
  high and noisy. A clean-machine rerun is open if the review asks for one.
- Not decided here: compiled code, a matrix entry point, a TA-Lib adapter,
  a public adapter interface, new indicators, the sweep-architecture
  questions (macro plan item f), the real-data gate count (Section 6).

## 1. The question

Seed v2 fixed the direction: stage 2 moves TTR's knowledge behind one
internal adapter description, so certification, dispatch, `source` values,
the parameter registry and provenance stop naming TTR; stage 3 computes
proven simple cells with one direct adapter call per instrument, with the
same records as the general path. It left two things to this RFC: whether
stage 3 pays for itself on the cleaned path, and the concrete shape of both
stages. This seed answers the first with numbers and proposes the second.

## 2. What the measuring step found

**Stage 3 ceiling** (`results/direct.csv`; seconds of the feature compute
call; "kept" is certification, the causality probe and the plane records,
which a direct path still pays; "gate" is the probe's gate as written):

| Cell | compute call | kept | gate | direct | ceiling |
| --- | --- | --- | --- | --- | --- |
| 10 x 7,200 run | 0.074 | 0.036 | 0.010 | 0.009 | 27% |
| 10 x 7,200 sweep | 0.200 | 0.106 | 0.016 | 0.025 | 27% |
| 500 x 1,260 run | 0.580 | 0.031 | 0.100 | 0.160 | 50% |
| 500 x 1,260 sweep | 1.410 | 0.092 | 0.130 | 0.500 | 49% |
| 1,166 x 252 run | 0.830 | 0.030 | 0.073 | 0.240 | 59% |
| 1,166 x 252 sweep | 2.000 | 0.091 | 0.100 | 0.710 | 55% |

The charter's kill condition (under 10 percent on every wide cell) is not
met, so stage 3 stays in scope. The ceiling is an upper bound: a real stage
3 adds its debug comparison (debug only) and whatever its own gate costs.
All 13,408 admitted cells were identical to the general path: values on
the whole axis, segment start, ready and end, and no carry or reason
exception.

**Where the per-instrument time goes** (`results/steps.csv`). On the wide
cells, the steps a direct path skips are 57-67 percent of the feature path:
input treatment with the expected and terminal planes, required-field
admission, runs and terminal breaks, segment bookkeeping, plane exceptions,
ranges (`R/history-features.R:185-296`, `349-427`, `561-606`). The TTR call
itself is close to bare TTR (0.12-0.57 s against 0.08-0.53 s).

**Certification costs about 14 ms per definition per call** (28 ms for two
definitions, 83 ms for six), independent of instruments; 37-41 percent of
the narrow compute call. `ledgr_feature_catalogue_candidates()`
(`R/history-features.R:96-154`) builds four built-in candidates per width
and, for a TTR definition, a full `ledgr_ind_ttr()` construction, which
calls TTR on synthetic bars to validate the output contract
(`R/indicator-ttr.R:250`, `868-871`). Each candidate is then turned into a
definition and fingerprinted twice (`R/history-features.R:30-37`). This is a
stage-2 cost, not a stage-3 one.

**Gate coverage on public substrates** (`results/gate_count.csv`;
structural counts, not a ranking). The conservative gate admits every cell
of the dense crossover fixtures, 197 of 200 instruments of a simulated
point-in-time panel (one terminal, three gaps), 4 of 6 on each corpus
panel, and none on the three hostile corpus substrates. Custom definitions
are never admitted.

**Gut.** Without the full-coverage clause the gate admits 14 cells that
differ from the general path (input carry 6, reason runs 6, output carry
with reasons 2). The clause is load-bearing, and the identity check sees a
missing clause.

**Found by running.** A block shorter than `stable_after` must make no
adapter call: TTR refuses a window longer than its input. The general path
already guards it (`R/history-features.R:394`).

**Stage 2 scope** (`results/ttr_inventory_by_function.csv`). Outside
`R/indicator-ttr.R`, 57 code lines in 9 functions name TTR or call an
adapter helper: `ledgr_feature_certify`, `ledgr_feature_catalogue_candidates`,
`ledgr_history_feature_segment` (`R/history-features.R`),
`ledgr_indicator_history_catalogue` (`R/indicator-history.R:203-272`, 26
lines), `ledgr_indicator` and `ledgr_indicator_source` (the `source`
values, `R/indicator.R:137`, `R/feature-inspection.R:295`),
`ledgr_param_constructor_registry` (`R/feature-parameters.R:290`),
`ledgr_dependency_versions_json` (`R/strategy-provenance.R:105`) and the
engine version's bind list (`R/features-engine.R`, 11 lines).

## 3. Proposal: stage 2, the adapter registry

**Shape.** One internal function, `ledgr_feature_adapters()`, returns a fixed,
ordered list of adapter descriptions, built from package code only. Two
entries: `ledgr` (the built-ins `sma`, `ema`, `rsi`, `returns`) and `TTR`.
Registering the built-ins as an adapter is new in this seed: it lets
certification and dispatch read one table instead of keeping a built-in
branch beside the adapter one. Each description is a plain list carrying
what seed v2's Stage 2 bullet list requires (identity, inputs, widths,
catalogue matching, raw calls and outputs, certification, proof), as data
and functions:

- `name`, `package`, and `version()`: the backend identity used by
  provenance and the engine version.
- `rows`: this adapter's catalogue rows, in today's column layout.
  `ledgr_indicator_history_catalogue()` becomes the row-bind of the
  adapters' rows, in today's order.
- `constructors`: the public constructors the parameter registry exposes
  (`ledgr_ind_sma` ... for `ledgr`; `ledgr_ind_ttr`, `ledgr_ind_ttr_outputs`
  for `TTR`).
- `candidate(def)`: at most one canonical candidate for a definition,
  found by key (adapter function, input, output, algorithm variant, width),
  or `NULL`. It never calls the backend.
- `call_key(cert)` and `segment(cert, inputs, fields, rows, cache)`: what
  `ledgr_history_feature_segment()` does today per kind
  (`R/history-features.R:297-344`), moved behind the adapter. TTR's raw
  call, output selection, derivation (MACD `histogram`) and preparation-local
  raw sharing stay as they are, keyed as today.

**Readers.** Certification loops the adapters and asks each for its one
candidate. The kind dispatch in `ledgr_history_feature_segment()` calls the
certified adapter's `segment`. `ledgr_indicator()` and
`ledgr_indicator_source()` accept `c(names(adapters), "custom")`: still
exactly `ledgr`, `TTR`, `custom`, so the public `source` argument and its
refusal message do not change. The parameter registry and
`ledgr_dependency_versions_json()` read the adapters' constructors and
packages. `R/indicator-ttr.R` keeps the user-facing constructors and their
helpers; only the sites in Section 2 move.

**Certification by key.** Today a TTR definition costs a full constructor
run including a TTR call on synthetic bars, plus four unrelated built-in
candidates. The proposal builds the canonical definition for the one
matching key directly, without the constructor's user-input validation
(which already ran when the user built the indicator, and which the
canonical candidate does not need to repeat). The recognised set must not
change: every definition that certifies as `builtin` or `catalogue` today
certifies the same way with the same canonical definition, and every
refusal certification raises today (the input-carry contradiction,
`R/history-features.R:42-56`) is raised for the same inputs. The cut
proves this on the oracle corpus and on hostile near-misses: a wrong
width, an edited ID, copied functions, an unregistered argument, an
unknown output.

**TTR and built-in fingerprints stay fixed** (seed v2, F9). The emitted
`fn` and `series_fn` bodies, formals, captures, params, IDs and declarations
do not change. Before refactoring, the cut pins the ordinary and
declared-session fingerprints of concrete, parameterised and bundled TTR
forms and of every built-in, and checks that certification still
recognises them.

**Engine version.** It binds `ledgr_feature_adapters()` and every adapter
function it reaches, through the existing census (`dev/feature_parity/`)
and its replacement proofs. The engine version changes in this stage
(seed v2, Section 6); nothing else in identity does.

## 4. Proposal: stage 3, the direct path

**Where.** Only in `ledgr_history_compute_feature_series()`
(`R/history-features.R:466-526`), which run, sweep and explicit precompute
reach (`R/backtest-runner.R:668`, `R/history-substrate.R:381`). The
single-definition read entry (`R/history-features.R:793-896`) and the
causality probe keep the general path.

**The gate.** Computed once per call, before the instrument loop, as a
logical matrix over (definition, instrument), from whole-matrix sweeps: the
expected plane at the cutoff, the terminal planes over the prefix, and one
finiteness matrix per distinct required-field set, shared across
definitions. A cell is admitted when all of these hold:

1. the definition certifies as `builtin` or `catalogue` (custom and
   unregistered forms keep the general path);
2. the instrument has exactly one knowledge range over the calculation
   slice (`ledgr_history_feature_ranges()`);
3. every calculation column is an expected session at the cutoff;
4. every required field is finite on every calculation column (so nothing
   is carried, and raw and treated inputs agree for both input-carry
   families);
5. no terminal assertion anywhere in the prefix, and no sticky barrier in
   the calculation slice.

The probe's gate cost 0.07-0.13 s on the wide cells, mostly per-instrument
range calls and full planes. The cut must measure its gate and keep it
well under the saving; the ranges are computed once and reused by the
general path rather than twice.

**The direct calculation.** In the existing loop order (instrument outer,
definition inner), so the first refusal is the same one the general path
raises today. For an admitted cell, the loop builds a minimal input from
the raw bar rows of that instrument and calls the same adapter `segment`
function over the whole calculation slice, with the same raw-call cache, so
outputs of one TTR call still share one raw result. There is no new
calculation code: the adapter call, normalisation and refusals are the
general path's own. It then writes:

- values at the calculation columns, `NA` before `stable_after`; nothing
  outside the calculation bounds;
- one segment record (start = first calculation column, ready = the
  `stable_after`-th column or `NA` when the slice is shorter, end = last
  column); no adapter call when the slice is shorter than `stable_after`;
- no carry and no reason exceptions: on an admitted slice no column is an
  expected gap, so input carry, output carry and reason runs are provably
  empty (`R/history-features.R:404-414`);
- the calculated count (`ready & is.finite(value)`), so the causality
  probe picks the same instrument and positions.

The general path builds an instrument's treated inputs only if one of its
definitions is not admitted.

**Causality.** The sampled causality probe (`R/history-features.R:634-766`)
runs unchanged for every concrete definition. It recomputes prefixes on the
general path and compares them with the prepared value, which may now come
from the direct path, so it also cross-checks one instrument per definition
in production.

**Debug.** With debug on, every admitted cell is also computed on the
general path, and values, calculated counts and every plane record are
compared; any divergence fails closed with an internal classed error. The
fast answer is never chosen silently, and a mismatch is never hidden by
falling back. Debug changes assertions only, never values. See question 1:
the package has no internal debug mode yet.

**Is this a second execution mode?** AGENTS.md forbids new execution-mode
branches in fold, run, sweep or walk-forward code. The direct path is not
in those; it is a calculator choice inside feature preparation, like
today's `sma` dispatch (`R/history-features.R:303-306`), with identical
outputs proved per cell in debug. The response should challenge this
reading.

**The looser gate is not proposed.** A gate that admits one contiguous
usable block (leading or trailing inactive or missing columns allowed)
added 2 cells on public data. Their values and segments matched, but the
general path also records reason runs for the missing expected sessions
outside the block, so the looser gate would have to produce them. It is a
later option; the decision input is the real-data gate count (Section 6).

## 5. Proof and oracle

- **Oracle.** The stage-1-cleaned general path is the normative executable
  oracle (AGENTS.md). Against the pin `d5b3a151`, the permanent oracle
  (`dev/feature_parity/`) must show identical values, planes and refusals
  for every case, with no new recorded exception. The identity tooling's
  changed-engine mode must show only the engine version changing.
- **Gate witnesses.** A near miss on each gate clause (a second knowledge
  range, an unexpected session, a non-finite required field for each
  input-carry family, a terminal assertion, a sticky barrier), plus a short
  and an empty calculation slice, in run and sweep, debug on and off. Each
  near miss must take the general path, and each admitted case must match
  it.
- **Witnesses can fail.** The probe's gut becomes a test: with a gate
  clause removed, the debug comparison must refuse on the hostile corpus.
- **Certification witnesses** as in Section 3.
- **Timing.** Busy-machine figures are labelled as such. The cut reports
  the feature clock on the four wide cells and the 10 x 7,200 cells, before
  and after, through the shared harness `dev/bench/timing/` (one protocol
  folder for the cut). No public speed claim (no peer suite here).
- **Sizes.** Production lines are reported per stage; the direct path is
  expected to add a gate and a short loop branch, and stage 2 to remove
  the candidate loop.

## 6. Open items

- **Real-data gate count.** On the real point-in-time universe, the
  conservative gate turns away any instrument that lists, delists or has a
  gap inside the window, so the real-data saving is likely well below the
  ceiling. The count needs the private aggregate route and the maintainer's
  go. The maintainer decided (2026-11-18) that the seed does not wait for it;
  it decides only whether the looser gate is worth building.
- **Clean-machine timing**, if the review asks for one.

## 7. Questions for the maintainer

1. **The debug switch.** The package has no internal debug mode before the
   switch; the pulse-plumbing synthesis (R1) creates one for the lean core
   and forbids a public debug option. Options:
   (a) the cut adds one unexported debug flag in `R/`, which the suite turns
   on and the switch later reuses for the lean core (example: an internal
   setter the test helpers call). Consequence: one internal mechanism lands
   before the switch; parity can run debug on and off.
   (b) no flag; the direct-versus-general comparison runs only in tests,
   through an internal helper. Consequence: nothing new in `R/`, but a real
   workload cannot be run with the comparison on. The seed recommends (a).
2. **One cut or two.** The seed proposes one cut with two workstreams,
   stage 2 then stage 3, since the gate reads the registry. The other
   option is two cuts, each with its own close review; slower, and stage 2
   alone shows little speed on wide cells.
3. **Built-ins as an adapter.** The seed registers the built-ins as the
   `ledgr` adapter (Section 3). The other option keeps built-ins as a
   separate branch and registers only TTR; less change, two dispatch paths
   kept.
