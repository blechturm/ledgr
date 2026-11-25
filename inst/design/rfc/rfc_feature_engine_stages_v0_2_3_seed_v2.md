# Feature Engine Stages 2-3: Seed v2

- Author: Claude, 2026-11-25, seed author of v1. The maintainer gave the
  go-ahead for this revision on 2026-11-25.
- Status: seed v2, for the synthesis. Binds nothing until accepted.
- Changes from v1 ([seed v1](rfc_feature_engine_stages_v0_2_3_seed.md),
  `b3454fc7`): applies every finding of the
  [Type 2 response](rfc_feature_engine_stages_v0_2_3_response.md) (Codex,
  REVISE_SEED, 1-8) as recorded in the
  [response review](rfc_feature_engine_stages_v0_2_3_response_review.md).
  - F1, F2: certification keeps today's full candidate walk and the TTR
    constructor call; no lookup by metadata, no "never calls the backend".
  - F3: debug compares refusals, not only answers; production keeps the
    loop order.
  - F4: the direct path states its exit and adds its representation-map row;
    the contract wording is named for the synthesis.
  - F5: the 49-59 percent figure is a component estimate; stage 3 is
    measured after stage 2, on poor admission and for memory.
  - F6: the permanent checker's mechanism observations get a stated, narrow
    disposition.
  - F7: evidence claims narrowed; relaxed count corrected to four cells.
  - F8: the sticky-barrier clause is dropped as implied.
- Parent: the accepted feature-engine seed v2
  ([parent](rfc_feature_engine_v0_2_3_seed_v2.md)). Its Stage 2 and Stage 3
  sections, Section 4 (constraints), Section 6 (identity) and Section 7
  (maintainer answers) stay binding.
- Code: release/v0.2.3 at `ff8e9a63`; R/ unchanged since `68b505b9`;
  engine version `bc6a3ea254d0a37b`.
- Evidence: `dev/spikes/feature_stage23_probe/` (busy-machine timings,
  shares and ratios only; CHECK PASS) and the response's probes in
  `C:/Users/maxth/ledgr-wt/fe-stages-probes/`.
- Not decided here: compiled code, a matrix entry point, a TA-Lib adapter,
  a public adapter interface, new indicators, the looser gate, the
  sweep-architecture questions (macro plan item f).

## 1. The question

The parent fixed the direction. Stage 2 moves TTR's knowledge behind one
internal adapter description, so certification, dispatch, `source` values,
the parameter registry and provenance stop naming TTR. Stage 3 computes
proven simple cells with one direct adapter call per instrument, with the
same values, records and refusals as the general path. This RFC gives both
stages a concrete design, on the cleaned path's measurements.

## 2. What the measuring step found

**A component estimate for stage 3** (`results/direct.csv`; seconds of the
feature compute call). "Kept" is certification, the causality probe and
plane records, which a direct path still pays. "Gate" is the prototype's
gate. The estimate is compute minus kept, gate and direct, each timed
separately; it is not a measured saving and not an upper bound, since it
leaves out integrated record writes and assembly.

| Cell | compute call | kept | gate | direct | estimate |
| --- | --- | --- | --- | --- | --- |
| 10 x 7,200 run | 0.074 | 0.036 | 0.010 | 0.009 | 27% |
| 10 x 7,200 sweep | 0.200 | 0.106 | 0.016 | 0.025 | 27% |
| 500 x 1,260 run | 0.580 | 0.031 | 0.100 | 0.160 | 50% |
| 500 x 1,260 sweep | 1.410 | 0.092 | 0.130 | 0.500 | 49% |
| 1,166 x 252 run | 0.830 | 0.030 | 0.073 | 0.240 | 59% |
| 1,166 x 252 sweep | 2.000 | 0.091 | 0.100 | 0.710 | 55% |

The charter's kill condition (under 10 percent on every wide cell) is not
met, so stage 3 stays in scope as a measured hypothesis. The 13,408 admitted
cells, all TTR SMA on dense fixtures, were identical to the general path
(values, segment start, ready and end, no exceptions). The prototype covered
built-in SMA and close-input TTR only, compared no refusals and had no raw
sharing. The response's separate probe matched 192 admitted cases across
every catalogue row, short slices and later starts by reusing the segment
call over the whole slice (`gate_probe.txt:1`). That supports the design; it
does not replace the oracle.

**Where the per-instrument time goes** (`results/steps.csv`). On wide cells
the steps a direct path skips are 57-67 percent of the feature path (sums of
sampled step shares): input treatment with expected and terminal planes,
admission, runs and terminal breaks, segment bookkeeping, plane exceptions,
ranges (`R/history-features.R:185-296`, `349-427`, `561-606`).

**Certification costs about 14 ms per definition per call** (28 ms for two,
83 ms for six), independent of instruments; 37-41 percent of the narrow
compute call. `ledgr_feature_catalogue_candidates()`
(`R/history-features.R:96-154`) builds all four built-ins for every width it
finds, and for a TTR definition runs `ledgr_ind_ttr()`, which calls TTR on
synthetic bars (`R/indicator-ttr.R:250`, `868-871`). Each candidate becomes
a definition and is fingerprinted twice (`R/history-features.R:30-37`). How
these parts split is not yet measured.

**Gate coverage on public substrates** (`results/gate_count.csv`). The
conservative gate admits every dense crossover cell, 197 of 200 instruments
of a simulated point-in-time panel, 4 of 6 on each corpus panel, none on the
three hostile corpus substrates. Custom definitions are never admitted. The
looser gate (one contiguous usable block) adds four cells (two instruments,
two definitions); their values and segments match, but the general path
also records reason runs for them.

**Gut.** Without the full-coverage clause the conservative gate admits 14
differing cells on all substrates (input carry 6, reason runs 6, output
carry with reasons 2); the response reproduced 10 on the corpus alone. The
next evidence record keeps the full gut output.

**Short slices.** A slice shorter than `stable_after` makes no adapter call
(`R/history-features.R:394`); TTR refuses a window longer than its input.

**Stage 2 scope** (`results/ttr_inventory_by_function.csv`). Outside
`R/indicator-ttr.R`, 57 code lines in 9 functions name TTR or call an
adapter helper: certification and its candidates, the segment dispatch
(`R/history-features.R`), the catalogue rows (`R/indicator-history.R:203-272`),
the `source` values (`R/indicator.R:137`, `R/feature-inspection.R:295`), the
parameter registry (`R/feature-parameters.R:290`), provenance
(`R/strategy-provenance.R:105`) and the engine version's bind list
(`R/features-engine.R`).

## 3. Stage 2: the adapter registry

**Shape.** One internal function, `ledgr_feature_adapters()`, returns a fixed,
ordered list of two adapter descriptions, built from package code only:
`ledgr` (the built-ins `sma`, `ema`, `rsi`, `returns`) and `TTR`. No runtime
registration, discovery or mutable hooks; no loading TTR to inspect a
built-in; no public schema. Each description is a plain list:

- `name`, `package`, `version()`: backend identity for provenance and the
  engine version;
- `rows`: its catalogue rows in today's layout;
  `ledgr_indicator_history_catalogue()` row-binds them in today's order;
- `constructors`: the public constructors the parameter registry exposes;
- `candidates(def)`: this adapter's candidates for a definition, in today's
  order, built as today (Certification, below);
- `call_key(cert)` and `segment(cert, inputs, fields, rows, cache)`: today's
  per-kind body of `ledgr_history_feature_segment()`
  (`R/history-features.R:297-344`), unchanged in arithmetic, cache key and
  cache lifetime (one instrument and knowledge range). MACD's `histogram`
  derivation and BBands' distinct carry-family keys stay as they are.

**Readers.** Certification walks the adapters in order and each adapter's
candidates in order. The kind dispatch calls the certified adapter's
`segment`. `ledgr_indicator()` and `ledgr_indicator_source()` accept
`c(names(adapters), "custom")`, which is still `ledgr`, `TTR`, `custom`, so
the public `source` argument and its refusal do not change. The parameter
registry and `ledgr_dependency_versions_json()` read the adapters.
`R/indicator-ttr.R` keeps its user-facing constructors and helpers.

**Certification keeps its semantics** (F1, F2). The candidate walk keeps its
order (built-ins by width, then the TTR row), the ID substitution, the
comparison of both the claimed and the content identity, the input-carry
contradiction refusal (`R/history-features.R:42-56`), and the TTR
constructor with its synthetic output-contract call. No candidate is chosen
from metadata. The one permitted lever is building candidates lazily, in the
same order, stopping at the first identity match. That keeps every outcome
except refusals raised by constructing a candidate after the match; the
response found one, a valid `ledgr_ind_sma(.Machine$integer.max)` that
refuses only because the unrelated EMA candidate overflows. Whether that
difference is taken is question 4. The stage-2 workstream first measures
how certification's cost splits (candidate construction, the TTR call,
definition building, fingerprints). If lazy construction buys no measured
saving, certification stays as it is and stage 2 is only the move behind
the registry.

**Certification witnesses.** On the oracle corpus and on hostile
definitions: a wrong width, an edited ID, copied functions, an SMA carrying
RSI's fingerprint, an unregistered argument, an unknown output, ROC with an
invalid `type`, MACD with `nFast = 100, nSlow = 3`. Each certifies, refuses or falls
to custom exactly as the pin does, with the same canonical definition.

**Fingerprints stay fixed** (parent, F9). Emitted `fn` and `series_fn`
bodies, formals, captures, params, IDs and declarations do not change. The
cut pins the ordinary and declared-session fingerprints of concrete,
parameterised and bundled TTR forms and of every built-in before
refactoring, and checks that certification still recognises them.

**Engine version.** It binds `ledgr_feature_adapters()` and every function it
reaches, through the existing census and its replacement proofs. It changes
in this stage; no other identity does.

## 4. Stage 3: the direct path

**Where.** Only in `ledgr_history_compute_feature_series()`
(`R/history-features.R:466-526`), which run, sweep and explicit precompute
reach (`R/backtest-runner.R:668`, `R/history-substrate.R:381`). The
single-definition read entry (`R/history-features.R:793-896`) and the
causality probe keep the general path. It adds no option, argument or
user-visible mode.

**The gate.** Computed once per call before the instrument loop, as one
logical flag per (definition, instrument). It exits early: no planes are
built when no definition certifies as `builtin` or `catalogue`, or when
bounds are empty. Finiteness is reduced to per-instrument flags per
required-field set as it is computed; no instrument-by-axis plane is kept
beyond the gate. A cell is admitted when all of these hold:

1. the definition certifies as `builtin` or `catalogue`;
2. the instrument has exactly one knowledge range over the calculation
   slice (`ledgr_history_feature_ranges()`, computed once and reused by the
   general path);
3. every calculation column is an expected session at the cutoff, and
   every required field is finite on every calculation column (so nothing
   is carried, and raw and treated inputs agree for both input-carry
   families);
4. no terminal assertion anywhere in the prefix. This implies no sticky
   barrier in the slice, since the sticky plane is built from the first
   asserted terminal in the prefix (`R/history-substrate.R:1437-1459`).

The gate is conservative, not minimal: harmless histories with a second
knowledge range or an early terminal fall to the general path.

**The direct calculation.** In the existing loop order (instrument outer,
definition inner), interleaved with general cells, so the first refusal is
the one the general path raises today. For an admitted cell the loop builds
a minimal input from the instrument's raw bar rows and calls the adapter's
`segment` over the whole calculation slice, with prefix-relative row indices
and the instrument's raw-call cache. It reuses the canonical arithmetic,
normalisation and output refusals; the bookkeeping it replaces is:

- values at calculation columns, `NA` before `stable_after`, nothing outside
  the calculation bounds;
- one segment record (start, ready or `NA`, end); no adapter call when the
  slice is shorter than `stable_after`;
- no carry and no reason exceptions: with no expected gap in the slice,
  input carry, output carry and reason runs are empty
  (`R/history-features.R:404-414`);
- the calculated count (`ready & is.finite(value)`), so the causality probe
  picks the same instrument and positions.

An instrument's treated inputs are built only if one of its definitions is
not admitted.

**Causality** (`R/history-features.R:634-766`) runs unchanged for every
definition with calculated cells. It recomputes sampled prefixes on the
general path against the prepared value, so in production it also refutes
direct-path answers at those positions. It is a refutation, not a proof.

**Debug** (F3). With debug on, every admitted cell is also computed on the
general path with its own preparation-local cache. The comparison covers the
outcome, not only the answer: success against success compares values,
calculated counts and every plane record; a refusal compares class and
message. Agreement re-raises the agreed refusal; any disagreement fails
closed with an internal classed error. The fast answer is never chosen
silently and a mismatch is never hidden by fallback. Debug changes
assertions only, never values.

**Exit and map** (F4). The canonical path is the general calculate path; the
differential is the debug comparison plus the registered witnesses
(Section 5). Exit condition: the direct path is removed, or merged into the
general path, when a simplification of the general path brings the wide
cells' compute call within the label-exchange range of the direct path, or
when the gate's coverage on the workloads the timing harness records falls
to where its measured saving is inside that range. The cut adds a row to
`inst/design/ledgr_v0_2_2_spec_packet/history_representation_map.md` naming
the path, its oracle, its gate and this exit.

**Second execution mode?** No. AGENTS.md forbids a second set of execution
semantics. This is a calculator choice inside one preparer, authorised by
the parent's Stage 3, decided per cell by a deterministic predicate, with
identical outcomes required and checked in debug. File placement is not
the argument.

**Cost** (F5). Stage 3 is measured against completed stage 2, through the
shared harness `dev/bench/timing/` (one protocol folder): the four wide
cells and 10 x 7,200 fully admitted; zero-admission and low-admission
public fixtures (the hostile corpus substrates, a custom-definition run);
mixed admission (the simulated PIT panel); peak R heap on the wide cells.
No-regression rule: on zero-admission fixtures the feature clock stays
within the label-exchange range of the stage-2 base; a gate that costs more
than that is narrowed or dropped. Busy-machine figures are labelled.

**The looser gate** stays out. It would have to produce the general path's
reason runs. The decision input is the real-data gate count, which the
maintainer deferred on 2026-11-18.

## 5. Proof and oracle

- **Oracle.** The stage-1-cleaned general path is the normative executable
  oracle. Against the pin `d5b3a151` the permanent oracle
  (`dev/feature_parity/`) shows identical values, planes, reads,
  certification outcomes, refusal classes and order, RNG and causality
  selection, with question 4's difference as the only possible recorded
  exception. The identity tooling's changed-engine mode shows only the
  engine version changing, and the helper census grows to the new
  functions with replacement proofs.
- **Checker** (F6). The checker counts constructor and backend calls and
  hand-offs to treated inputs (`dev/feature_parity/runner.R:133-190`,
  `check.R:109-129`), which stage 2 (if lazy construction is taken) and
  stage 3 change by design. Stated reason and narrow disposition: those
  mechanism components stop being compared candidate-against-pin. They are
  replaced by independently observed gate decisions, actual adapter calls,
  raw-sharing hits and fallback treatment, checked against a committed
  expected set, with the fault controls kept. No value, plane, read,
  certification, refusal or identity comparison changes.
- **Gate witnesses.** A near miss on each clause (a second knowledge range,
  an unexpected session, a non-finite required field for each input-carry
  family, a terminal assertion), plus a short and an empty slice, in run and
  sweep, debug on and off. Each near miss takes the general path; each
  admitted case matches it.
- **Family witnesses** (F7). Every adapter input shape (`close`, `hl`,
  `hlc`, `ohlc`, `hlcv`, TTR's separate volume argument), multi-output calls
  with raw sharing (MACD with `histogram`, BBands with both carry families),
  every built-in, and `stable_after` variants.
- **Refusal witnesses** (F3). An admitted definition that refuses
  (catalogue `runSD(n = 1)`), competing refusals between admitted and
  general definitions in both orders, and empty bounds before the gate.
- **Witnesses can fail.** With a gate clause removed, the debug comparison
  refuses on the hostile corpus; the full gut output is kept.
- **Sizes.** Production lines per stage, beside debug and witness lines.
- **Contract wording** (F4). Feature Path And Intent Constructors says
  "Feature computation follows one uncached production path." The synthesis
  rewords it to one preparer that may select an equivalent internal
  calculator per cell, proven by a registered differential, with no cache
  across preparations.

## 6. Open items

- **Real-data gate count.** Deferred by the maintainer (2026-11-18); it
  decides only the looser gate.
- **Clean-machine timing**, if the synthesis or final review asks for one.
  The cut's own timings are taken on the host it gets.

## 7. Maintainer questions

Questions 1-3 carry the seed's and the response's shared recommendation;
they become binding when the synthesis is accepted unless the maintainer
answers otherwise.

1. **Debug switch.** (a) One unexported debug flag in `R/`, restoring its
   prior state, set explicitly in parity and timing workers, turned on for
   the suite; the switch reuses it for the lean core (pulse plumbing R1).
   (b) The comparison runs only in tests. Recommended: (a). Cost: duplicate
   work for admitted cells when on, and the worker wiring.
2. **Cut shape.** One cut, two workstreams (stage 2, then stage 3), each with
   its own close review; stage 3 starts only after stage 2's review.
   Recommended over two cuts.
3. **Built-ins as an adapter.** A small fixed `ledgr` description beside
   `TTR`, kernels and fingerprints unchanged; taken only if it removes the
   parallel built-in branch. Recommended over registering TTR alone.
4. **The spurious refusal** (new, F1). Lazy candidate construction stops at
   the first match, so a valid `ledgr_ind_sma(.Machine$integer.max)` no
   longer refuses because the EMA candidate of the same width overflows.
   (a) Take it as the one recorded oracle difference against the pin.
   Consequence: that definition certifies as a built-in and computes.
   (b) Keep eager construction. Consequence: today's refusal stays, and
   lazy construction is not available as a certification saving.
   Recommended: (a), if the stage-2 measurement shows lazy construction
   saves time; otherwise the question lapses.
