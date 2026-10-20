# Cut 16 Workstream 47 closeout: proof-baseline trims

Role: record; Workstream 47 implementation evidence (LDG-3078, LDG-3079).
Authority: non-binding. `tickets.yml` owns status, `contracts.md` owns
behaviour, Cut 16 decision (25) and `cut16_architecture_audit.md` (F01 to
F04) are the work list.
Status: LDG-3078 and LDG-3079 are complete; Workstream 47 is
`review_pending` for its independent Type 1 close review. The two-worker
sweep peak question this record first raised was decided by the maintainer
as Cut 16 decision (26) and is implemented (Decision (26) below).

BASE for every byte-identity claim is `2ef0f2da` (`integrate/cut15-v0.2.2`,
the accepted Workstream 46 at `36d77574` plus record-only commits). The
implementation is commit `f367ed80` on `ws47/proof-baseline-trims`, this
record and the map follow in `fcadf1ae`, and Cut 16 decision (26) is
implemented with its evidence in the commit after that.

## Necessity and scope

The external audit measured four wastes on the accepted Workstream 46 tree:
a feature payload kept alive beside its projection (F01), membership fact
columns the execution cursor never reads (F03), a copy of the mask barrier
in every bar field's history-read cache (F04), and carry evidence that
feature preparation builds and discards (F02). Cut 16 decision (25) asks for
their removal, with byte-identical results apart from the availability
feature-engine identity, before Workstream 44 sets the proof baselines. F05
(generic fact compilation) waits for LDG-3080; execution-core consolidation
keeps its scope.

## LDG-3078: dead payloads and retained history state

- F01. `ledgr_sweep_impl()` (fresh, no precompute) and
  `ledgr_pulse_inspection()` remove the payload binding right after
  `ledgr_projection_from_payload()` returns. Map row R30 said the payload was
  dropped after the projection was built; it was not (the audit's dispatch
  probe, reproduced below). R30 is corrected in the map.
- F03. Before removing anything, the readers of the stored membership plan on
  BASE were read: `ledgr_availability_prepared_membership_from_plan()` (the
  cursor, every fold pulse, and its attached detailed resolver, read by tests
  only) reads `set_index$rows$instrument_id` and `$fact_id`,
  `headers$set_id` and `interval$fact_id`, and otherwise only the vectors the
  plan compiles from the clocks and states; the membership counter
  (`ledgr_history_membership_segment_counts()`, M-8) reads the availability
  data, not the plan; the canonical resolver builds its own set index; the
  other readers are `representation_sizes.R` (size only) and LTB-0291's
  `header_complete`. `ledgr_availability_prepared_membership_plan()` now
  keeps exactly those columns. The index-only membership layout stays with
  consolidation. No staging or substrate version changes: the staged
  invariant is built and read by the same loaded package within one sweep
  under an owner-scoped identity, as when Workstream 46 removed planes.
- F04. `ledgr_history_carry_positions()` (C-2) is now the composition of
  `ledgr_history_carry_source()` and `ledgr_history_carry_last_barrier()`,
  the two halves of its old body. The history-read memo stores only `source`
  in `base_<field>` and `overlay_<instrument>_<epoch>_<field>`, and one
  `last_barrier` in `base_masks` and in each overlay mask
  (`ledgr_history_mask_barrier()`, built on the first bar-field read, so a
  feature-only reader never builds it). Memo build counters are unchanged.

### Acceptance status

| Acceptance item | Status | Evidence |
| --- | --- | --- |
| Byte-identical to BASE across run, sweep (sequential, two-worker), window, walk-forward, inspection, history reads (reordered, late overlays), refusals | met | Byte-identity runner: 108 of 113 raw, 113 of 113 after substituting the engine digest; H1 audit parity 7 of 7 (sections below) |
| Structural detector for a retained payload, a removed membership column or a per-field barrier copy | met | LTB-0393 (payload), LTB-0391 (plan columns, memo layout); mutations A1-A3, B1-B4, C1, C2 |
| Retained sizes at H1 before and after; peak private commit of a two-worker sweep | met | Sizes, Two-worker sweep peak memory, Decision (26) and Correction 1 below: BASE's staging peak is bimodal (parent about 3.1-3.3 GB or 3.86-3.94 GB); with the decision (26) collection the candidate peaks at about 2.73 GB parent, about 530 MiB below the low mode and about 1,150 MiB below the high mode; the tree peak falls by about nothing to 1,000 MiB against the low mode and by about 1,170 MiB against the high mode |
| Seven shapes walked | met | Seven-shape walk |

## LDG-3079: feature inputs without discarded carry evidence

The canonical carry rule C-1 is split into its calculation,
`ledgr_history_input_carry_calculation()` (treated value, input-carried flag
and the positions the manifestation needs: observed, source, last barrier,
age, whether carry is allowed), and its evidence manifestation, the body that
remains in `ledgr_history_input_carry()` (source index and time, age,
missing and barrier reasons, readiness and validity). The calculation is the
old function's first half verbatim; the manifestation its second half.
`ledgr_history_feature_inputs()` calls only the calculation and keeps
`value` and `input_carried`; output carry (`ledgr_history_output_carry()`)
still takes the full manifestation. No third carry formula exists; C-1/C-2's
merge stays with consolidation.

Feature-engine identity: `ledgr_history_feature_inputs()` and
`ledgr_history_input_carry()` are hashed helpers and both bodies changed, and
the new calculation is added to the availability payload of
`ledgr_feature_engine_version()` so a change to it moves the identity. The
availability digest moves from
`4b2bb8e6989d77ef7fdd4fd2c0738340e97786724826951af1ddb47cb2a005a9` to
`0072232f5cf0eb40b15a2d93e83551573ffcc9f388226527fabce16f50e2d508`; the
dense digest (`80d1ae6d...c681`) is unchanged. The only literals changed are
these two availability digests in LTB-0144 and LTB-0276. No compatibility
path: a precomputed object from BASE refuses on the engine version as any
engine change does.

| Acceptance item | Status | Evidence |
| --- | --- | --- |
| Feature values and every retained evidence plane byte-identical across the catalogue, TTR multi-output, custom fn/series_fn, gaps, relistings, late facts | met | WS47 feature families (15 definitions, three policies, axis end and mid cutoff, four fixtures): identical; H1 digests equal for both mixes |
| Engine identity change recorded with its reason; digest literals change only for it | met | Above; LTB-0144, LTB-0276 |
| Detector if feature inputs again build the discarded evidence; detector if carry disclosure is lost | met | LTB-0392; mutations D1-D3 (D3 also fails LTB-0311, LTB-0314, LTB-0319) |
| H1 feature preparation time before and after for the audit mix and a broader catalogue mix | met | Timing below |

## Byte-identity runner

The WS46 runner (`run_identity.R`, `fixtures.R`, `check_identity.R`; scratch,
not committed) was reused unchanged and extended with `ws47_families.R`
(24 families):

- F02: `ledgr_history_compute_feature_series()` values with their retained
  evidence records for 15 definitions (SMA, EMA, RSI, returns 1 and 5, TTR
  SMA, TTR BBands `up`, `dn` and `pctB`, TTR ATR on HLC, TTR MACD signal, a
  custom `fn`, a custom `series_fn` with its scalar `fn`, a custom
  `input_carry = "excluded"` ratio and a custom open-times-volume reader),
  under the default policy, `price_carry = NULL, output_carry = 2` and
  `price_carry = 2, output_carry = 3`, to the axis end and to a mid cutoff,
  on fixtures A to D (gaps, a late-known delisting and relisting, a
  late-known inactive interval, a bankruptcy terminal).
- F04: direct `ledgr_history_read()` calls on fresh substrates with bound
  features: all five bar fields and four features at shuffled cutoffs,
  field-major and then cutoff-major in reverse with alternating layouts and
  lookbacks, plus the memo build counters.
- F03: the prepared cursor and its attached resolver at every session close,
  12 hours before it and one second after, forward, backward and shuffled.

Result (BASE 113 families recorded, no family retried): 108 of 113 identical
raw. The five differing families are the explicit-precompute families of
fixtures A, A without carry, B, C and D, each differing in two strings, the
precomputed object's and its projection's `feature_engine_version`. With the
BASE digest replaced by the candidate's (`check_engine_normalized.R`, which
rebuilds only subtrees containing the old string), 113 of 113 are
byte-identical. Checker self-test: 113 of 113 on both records.

Sensitivity: the gut mutation D3 run through the runner makes 20 of the 24
WS47 families differ (every feature and read family); the F04 mutations C2
and C3 leave all 24 identical, which is why LTB-0391 pins barrier reasons
literally (Mutation table).

## H1 parity (audit checker)

The audit's `audit_workflow_probe.R` and `check_audit.R` were copied to a new
scratch root with the root literal changed, the two arms made two source
trees (BASE copy and candidate) instead of a binding swap, worker profiling
hooks dropped, one repetition, and the projection digest taken without its
`feature_engine_version` field (the recorded difference). On a fresh H1
snapshot (`public_history_snapshot()`, 1,166 instruments by 7,213 sessions,
built by the BASE copy), all 7 checks pass: the complete projection and
the full-history close read digests (preparation), all 7,213 run equity rows,
all 163,313 run ledger events (economic columns and sequence), the two-worker
sweep's metric, status and configuration columns, and the carried two-fold
walk-forward fold fields and test equity (`parity.csv`, `check-audit.log`).
No R process the runner did not own was present at any start.

Separately, the H1 size probe found the ten five-field history reads
(end and first cutoff) digest-identical, and all 18 two-worker H1 sweeps with
features (six BASE, six candidate, nine diagnostic arms) produced
serialization-identical result tables.

## Sizes (H1 shape)

`h1_probe.R` (scratch), one process per arm, MiB object / serialized; two
features (returns 20 and 60) for the sweep rows, one (returns 20) for
inspection:

| Representation | BASE | Candidate | Change |
| --- | --- | --- | --- |
| Substrate, no features | 413.48 / 428.84 | 393.52 / 375.42 | -19.96 / -53.42 |
| Membership plan | 58.64 / 74.03 | 38.68 / 20.60 | -19.96 / -53.42 |
| Fresh sweep live payload at dispatch | 131.32 / 130.98 | none bound | -131.32 / -130.98 |
| Fresh sweep projection at dispatch | 134.27 / 132.41 | 134.27 / 132.41 | 0 |
| Staged invariant, fresh sweep | 548.05 / 561.40 | 528.09 / 507.98 | -19.96 / -53.42 |
| Pulse inspection live payload | 65.62 / 65.45 | none bound | -65.62 / -65.45 |
| Five-field memo (end and first cutoff, 240 overlay keys) | 365.29 / 365.07 | 232.51 / 232.33 | -132.78 / -132.74 |

These reproduce the audit's figures. In the memo, 205 field entries hold
`source` and `last_barrier` on BASE and `source` only on the candidate; the
41 masks gain `last_barrier`. Two workers avoid 2 x 53.42 = 106.8 MiB of
serialized invariant (arithmetic, not measured transport).

## Timing (H1)

Method: High performance plan (GUID `8c5e7fda-...635c`), PowerShell process
affinity 0xFFFF set before `Rscript.exe` was started by full path, BASE copy
and candidate alternating in pairs, three pairs, medians. The runner recorded
every R process it did not own and its CPU seconds during each run; none was
present during the feature pairs. The parallel census agent's R processes
appeared during one BASE sweep (pair 6) and one diagnostic run, using 0.0 CPU
seconds. Clocks are `proc.time()` around the call after the substrate is
built; the probes are scratch (`run_pairs.ps1`, `h1_probe.R`).

| Feature preparation (`ledgr_history_compute_feature_series()`) | BASE | Candidate | Change |
| --- | --- | --- | --- |
| Audit mix: returns 20, 60 (pairs) | 14.45, 14.61, 14.76 | 9.89, 9.72, 9.91 | median 14.61 -> 9.89 s (-32.3%) |
| Catalogue mix: SMA 20, EMA 20, RSI 14, returns 20 and 60, TTR BBands up 20, TTR ATR 14 (pairs) | 95.14, 95.13, 95.64 | 94.53, 93.43, 93.63 | median 95.14 -> 93.63 s (-1.6%) |
| R heap max, audit mix (`gc()` max used) | 1,478.6 MiB | 1,221.7 MiB | -256.9 MiB |

Value-and-evidence digests are identical in every pair (audit mix
`cf30bb06e1db1ef2688f3a91d6dd882f`, the audit's own lean-parity digest;
catalogue mix `eef4d0443215614f601d829f455fff9a`). The catalogue mix runs
second in the same process. Its absolute saving (1.5 s) is smaller than the
audit mix's (4.7 s) although inputs are prepared once per instrument range
for all definitions; the cause was not profiled (inference: in the audit mix
part of the saving is collection work that the longer catalogue run incurs
anyway). The claim is these two mixes, not arbitrary indicators.

## Two-worker sweep peak memory

Two-worker fresh sweep with features (returns 20 and 60, two candidates,
seed 41), sampled private commit every 250 ms over the R process and its
descendants (rediscovered every 2 s), MiB; six alternating pairs:

| | BASE | Candidate |
| --- | --- | --- |
| Parent peak private commit, median (range) | 3,250.8 (3,110.9-3,863.3) | 3,679.1 (2,762.4-3,719.6) |
| Tree peak private commit, median (range) | 5,206.1 (4,722.1-5,347.6) | 5,388.4 (4,716.3-5,652.4) |
| Parent R heap max (`gc()` max used, pairs 4-6) | 1,830.2 | 1,830.4 |
| Sweep call seconds, median | 111.2 | 107.7 |

The peak did not fall; its median rose. The time series (pairs 4-6) put every
peak at worker staging, 14 to 19 s into the sweep, after feature preparation
(about 4.5 s earlier on the candidate). Diagnostic arms, three runs each, same
method: the candidate with F01 reverted (payload kept) peaks at 3,001.8
parent / 4,931.7 tree and the candidate with F02 reverted at 3,016.6 /
4,951.9, both with R heap max 1,551.2; a diagnostic copy that adds one
`gc()` after the payload release peaks at 2,724.6 / 4,346.6 with R heap max
1,551.2 and the same sweep time (107.0 s). Inference: with both changes the
released payload is still uncollected when staging serializes the invariant,
so the peak depends on collection timing, not on retained bytes; each change
alone, or an explicit collection, lowers the peak by 230 to 520 MiB against
BASE. The explicit collection was not in `f367ed80`: it was a design choice
outside the ticket's smallest change, raised as a maintainer question and
decided as Cut 16 decision (26) (next section).

## Decision (26): one collection after the payload release

Cut 16 decision (26) (maintainer, 2026-10-20): a fresh sweep runs one explicit
garbage collection immediately after it releases the feature payload, before
staging workers. `ledgr_sweep_impl()` calls `invisible(gc(verbose =
FALSE))` right after `rm(payload)`, with a comment citing the decision. As
amended after close review 47 F1 (Correction 1), it runs only when the sweep
has two or more workers (`if (workers > 1L)`); the condition is on the worker
count, not on the execution mode, so it adds no mode branch (census
unchanged).

Pulse inspection does not get a collection: it was not measured, and the
mechanism behind decision (26), serializing the invariant to workers right
after preparation, does not occur there (inspection runs its one pulse in
process).

Re-measurement, same method as above (High performance plan, affinity
0xFFFF, Rscript by full path, six alternating BASE/candidate pairs, no R
process the runner did not own during any run), MiB:

| | BASE `2ef0f2da` | Candidate with decision (26) |
| --- | --- | --- |
| Parent peak private commit, median (range) | 3,873.5 (3,861.3-3,937.8) | 2,728.5 (2,311.1-2,819.8) |
| Tree peak private commit, median (range) | 5,676.7 (5,340.1-5,982.3) | 4,507.2 (4,283.9-4,755.2) |
| Sweep call seconds, median (range) | 110.7 (109.6-111.3) | 106.9 (106.4-107.5) |
| Process wall seconds, median | 122.3 | 118.5 |

Every candidate run is below every BASE run, for parent and tree. BASE peaked
higher in this round than in the first (3,250.8 parent median); peaks at
worker staging vary between rounds of the same tree, so the comparison is the
paired one. The parent R heap max reported by `gc()` after the sweep is
1,830.2 (BASE) and 1,830.4 (candidate); `gc()` max used is updated only at
collections, so it is not a sampled peak (the diagnostic copy reported
1,551.2). All twelve result tables are serialization-identical to the first
BASE run.

## Seven-shape walk

Changed code: `ledgr_sweep_impl()` and `ledgr_pulse_inspection()` (F01);
`ledgr_availability_prepared_membership_plan()` (F03);
`ledgr_history_prepare_positions()`, `ledgr_history_mask_barrier()`,
`ledgr_history_cutoff_planes()`, `ledgr_history_overlay_key()`,
`ledgr_history_carry_positions()`, `ledgr_history_carry_source()` and
`ledgr_history_carry_last_barrier()` (F04);
`ledgr_history_input_carry_calculation()`, `ledgr_history_input_carry()`,
`ledgr_history_feature_inputs()` and the engine payload in
`ledgr_feature_engine_version()` (F02).

1. One-row frame per element: none added.
2. Full-table subset inside a loop over ids: none added. The plan trim is
   three column subsets, once per plan.
3. Per-element parsing or formatting: none added. The overlay key is
   formatted once per overlay entry, as before (now by one helper).
4. Per-row JSON: none.
5. Work computed and discarded: removed in three places. Feature inputs no
   longer build source times, reasons, barrier reasons, readiness and
   validity per price field and instrument range (F02); the memo no longer
   computes and stores the same barrier plane once per field (F04); the plan
   no longer carries fact columns no reader uses (F03). F01 drops a binding
   whose value was never read again.
6. Quadratic validators: none.
7. Scalar writes into an environment-held vector: none. The memo receives
   one `assign()` per mask when its barrier is first built.

Loops on these paths: `ledgr_history_mask_barrier()` loops over instrument
blocks of 128 rows, the same block loop `ledgr_history_prepare_positions()`
already used; each step is one vectorised pass over the block by the axis.
The per-instrument, per-range, per-field loop in
`ledgr_history_feature_inputs()` and its callers is unchanged (late-prefix
replay stays with LDG-3070); each iteration now does less work.

## Test changes and reasons

No behavioural oracle changed.

- LTB-0144 (`test-strict-feature-acceleration.R`) and LTB-0276
  (`test-strict-ttr-cleanup.R`): the availability feature-engine digest
  literal changes from `4b2bb8e6...a5a9` to `0072232f...d508` because
  LDG-3079 edits two hashed helpers and adds the calculation to the hashed
  payload (Cut 16 decision 25). LTB-0144 also lists
  `ledgr_history_input_carry_calculation` among the helpers that must appear
  in the provenance (mutation D4 fails it). The dense digest, the indicator
  fingerprints and every other literal are unchanged.
- New: LCL-0381/LTB-0391 (fast, F03 and F04), LCL-0382/LTB-0392 (fast, F02),
  LCL-0383/LTB-0393 (review, F01; it builds a snapshot, sweeps and inspects,
  about 2.5 s) in `test-proof-baseline-trims.R`. For decision (26),
  LTB-0393 also asserts that the fresh-preparation statement of
  `ledgr_sweep_impl()` runs `invisible(gc(verbose = FALSE))` right after
  `rm(payload)` (mutations E1, E2); a structural check, since a missing
  collection changes no result, only the peak. No test asserted a removed
  structure, so no detector replaced an existing assertion.

## Mutation table

Each mutation was applied to one file of a source copy made with
`git ls-files -z | tar --null -T - -cf - | tar -xf - -C <copy>` (the new test
file staged first), the named blocks run in a fresh R process, and the file
restored byte for byte (`mutate.py`, scratch). "Fails (n)" is testthat's
failed count; "error" means the block stopped.

| ID | Mutation | File | Result |
| --- | --- | --- | --- |
| M0 | none (unmutated copy) | - | LTB-0391 21, LTB-0392 9, LTB-0393 6, LTB-0311 28, LTB-0314 16, LTB-0319 41, LTB-0144 23 expectations, none failed |
| A1 | fresh sweep keeps the payload after building the projection | `R/sweep.R` | LTB-0393 fails (1) |
| A2 | pulse inspection keeps the payload | `R/pulse-snapshot.R` | LTB-0393 fails (1) |
| A3 | fresh sweep keeps the payload under another name | `R/sweep.R` | LTB-0393 fails (1) |
| B1 | plan keeps every set-row column | `R/availability-provider-prepared.R` | LTB-0391 fails (1) |
| B2 | plan keeps every header column | `R/availability-provider-prepared.R` | LTB-0391 fails (1) |
| B3 | plan keeps every interval column | `R/availability-provider-prepared.R` | LTB-0391 fails (1) |
| B4 | plan drops the set-row fact id the resolver reads | `R/availability-provider-prepared.R` | LTB-0391 error (1 failed) |
| C1 | field positions store their own barrier copy again | `R/history-frame.R` | LTB-0391 fails (6) |
| C2 | a late overlay row reads the base mask's barrier | `R/history-frame.R` | LTB-0391 fails (3); LTB-0298 survives |
| C3 | the mask barrier ignores the terminal plane | `R/history-frame.R` | LTB-0391 and LTB-0298 survive: equivalent mutant (below) |
| D1 | feature inputs call the full carry manifestation again | `R/history-features.R` | LTB-0392 fails (1) |
| D2 | the calculation also builds a reason vector | `R/history-treatment.R` | LTB-0392 fails (1) |
| D3 | the calculation erases the input-carried flag, values kept | `R/history-treatment.R` | LTB-0392 fails (2); LTB-0311 fails (8); LTB-0314 fails (1); LTB-0319 fails (7) |
| D4 | the calculation leaves the feature-engine payload | `R/features-engine.R` | LTB-0144 fails (2) |
| M0b | none (unmutated copy, decision (26) tree) | - | LTB-0391 21, LTB-0392 9, LTB-0393 8 expectations, none failed |
| E1 | the fresh sweep drops the decision (26) collection | `R/sweep.R` | LTB-0393 fails (1) |
| E2 | the collection runs before the payload release | `R/sweep.R` | LTB-0393 fails (1) |

C2 first failed LTB-0391 only structurally, and LTB-0298 and the identity
runner did not see it: a wrong overlay barrier changes a barrier reason only
where the instrument has had no admissible print since the axis start. LTB-0391
now pins that case literally (a late-known inactive session before the first
print reads as `lifetime_restart` after the fact is known and as leading
missingness before), and C2 fails it. C3 is equivalent on the read path: the
terminal plane is sticky, every column from the first terminal column on is
reported `terminal`, and the last barrier at an earlier column cannot include
a terminal column. This was so on BASE too.

## Routed, not changed here

- Two-worker sweep peak private commit: decided (Cut 16 decision 26) and
  implemented; Workstream 44 measures it under the H6 two-worker parent gate.
- Building the projection directly from the feature matrices instead of
  through the payload (audit F01's later step), and R27 (features held twice
  in the public precomputed object): consolidation.
- Index-only membership layout, `header_from`, segment `effective_start` /
  `knowledge_start` / `n_key` and the provider plan's `universe_rule`:
  consolidation (audit Section 2).
- C-1/C-2 merge through one primitive: consolidation.
- Catalogue-mix preparation cost (93.6 s at H1 for seven definitions) is
  dominated by per-definition calculation; not profiled here.
- F05: waits for LDG-3080.

## Verification record

On the implementation commit `f367ed80` (product code identical to the tree
every record above ran on), Windows 11, R 4.6.1, run sequentially:

- Full suite (`pkgload::load_all('.'); testthat::test_local('.', reporter =
  'summary', stop_on_failure = FALSE, load_package = 'none')`): 1,150 blocks,
  18,502 expectations, no failure or error, one optional skip
  (`ledgr_snapshot_from_yahoo requires quantmod`); 665 s of block time.
  LTB-0391 21, LTB-0392 9 and LTB-0393 6 expectations pass.
- Byte-identity runner against BASE: 108 of 113 raw, 113 of 113 with the
  engine digest substituted; self-test 113 of 113.
- H1 audit parity: 7 of 7.
- `tools/check-codebase-contracts.R --mode=check`: OK, 158 branch and 55 flow
  sites in 55 functions across 29 files (unchanged from BASE), findings 72;
  the regenerated census tables (line references, five new helpers) are in
  the commit; `--self-test-mode-branches`: OK.
- `tools/check-fold-phase-contract.R .`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.
- `tickets.yml` and `tests/claims.yml` parse with `yaml::read_yaml()`;
  `git diff --check 2ef0f2da` is clean.
- Not run here (coordinator): the independent close review and the fast,
  review and heavy gate profiles. `R/cpp11.R` and `src/cpp11.cpp`
  line-ending churn from compilation is not committed.

On the decision (26) tree (the `f367ed80` product code plus the one
collection in `ledgr_sweep_impl()`), run sequentially:

- Full suite, same command: 1,150 blocks, 18,504 expectations, no failure or
  error, one optional skip (quantmod); 709 s of block time. LTB-0393 has 8
  expectations.
- Byte-identity runner against BASE: 108 of 113 raw (the same five
  explicit-precompute families, engine digest only), 113 of 113 with the
  digest substituted; no family retried.
- Census check: OK, 158 branch and 55 flow sites (unchanged), findings 72;
  the regenerated census tables (line references) are in the commit;
  `--self-test-mode-branches`, the fold-phase checker, the YAML parse and
  `git diff --check` pass.

Scratch (not committed), under the session scratchpad `ws47/`: the runner
(`runner/`), records (`records/`), mutation driver and specs (`mutate.py`,
`muts1.py`, `muts2.py`, `mut_runner.py`), H1 probes and raw runs
(`h1/h1_probe.R`, `h1/run_pairs.ps1`, `h1/out/`) and the adapted audit
parity probe (`parity/`).

## Correction 1 (close review 47, 2026-10-20)

`close_review_47.md` returned CHANGES_REQUIRED with three findings (3 of 8
acceptance items) and no product defect. The maintainer decided F1 on
2026-10-20; the coordinator verifies this correction (mutations included).

- F1, decision (26) scope. The collection ran on every fresh sweep. The
  reviewer measured about 60 ms per sequential sweep in a fresh process
  (0.062-0.068 s per collection; +43% on a small dense sweep), three
  collections per three-fold walk-forward, and 320 collections taking 58.9 s
  across the full suite (8.0%; fast profile 1.8 s, review 32.3 s, heavy 24.8
  s), against 0.08-0.11 s for the one collection in a 110 s H1 two-worker
  sweep. Decision (26) is amended (appended to the Cut 16 decisions): the
  collection runs only when the sweep stages two or more workers.
  `ledgr_sweep_impl()` now reads `if (workers > 1L) invisible(gc(verbose =
  FALSE))` after `rm(payload)`. The condition is the worker count, so a dense
  fresh sweep with two or more workers also collects there (no mode branch).
  Sequential sweeps and the training sweeps of a single-worker walk-forward
  no longer collect; the H1 two-worker measurements above are on the worker
  path and stand. LTB-0393 now counts `base::gc()` calls over a sequential
  fresh sweep (literal zero) and checks the deparsed worker-path statement;
  LCL-0383 says so.
- F2, LTB-0144. Its helper-name check matched substrings, so
  `ledgr_history_input_carry` was found inside
  `ledgr_history_input_carry_calculation` and removing the manifestation from
  the hashed payload failed only the digest literal (skipped under covr). The
  check now matches whole names (`\b` on both sides, perl). Stated reason:
  the detector's own gap, introduced by this workstream; no oracle changed.
- F3, peak claims. BASE's staging peak is bimodal: parent about 3,111-3,275
  MiB (tree 4,722-5,337) or 3,852-3,938 MiB (tree 5,340-5,982) over the
  implementer's twelve BASE runs and the reviewer's two (3,267.0 / 4,751.8 and
  3,852.2 / 5,970.2). The candidate with the collection peaks at about
  2,725-2,820 MiB parent (one run 2,311.1) and 4,284-4,755 MiB tree (the
  reviewer's 2,738.2 / 4,741.8 and 2,725.3 / 4,727.1). The effect is therefore
  about -530 MiB parent against the low mode and about -1,150 MiB against the
  high mode; the tree changes by about nothing (reviewer pair 1: 4,751.8 to
  4,741.8) to about -1,000 MiB against the low mode and by -1,170 MiB (median)
  against the high mode. The acceptance row and the LDG-3078 evidence now say
  this; proof baselines should quote the candidate's absolute peak.
- N1. The comment above `ledgr_history_input_carry_calculation()` said public
  reads take the full manifestation; only output carry does, and public
  reads use the matrix positions (C-2/C-3). Comment corrected (outside the
  hashed function body; the engine digest is unchanged, LTB-0144 passes).
- N2 to N6 stay recorded notes in the review. For N6: the engine digest also
  reaches the `feature_engine_version` attribute of every availability sweep
  result and the persisted sweep row; the runner's canonical sweep form drops
  that attribute, so the five differing families above are what the runner
  records, not every carrier of the digest.

Verification on the corrected tree, sequential:

- Touched files: `test-proof-baseline-trims.R` (LTB-0391 21, LTB-0392 9,
  LTB-0393 9 expectations), `test-strict-feature-acceleration.R` (LTB-0142,
  LTB-0143, LTB-0144 23) and `test-strict-ttr-cleanup.R` (LTB-0276 35): no
  failure; the engine digest literals still hold.
- Full suite: 1,150 blocks, 18,505 expectations, no failure or error, one
  optional skip (quantmod); 707 s of block time (unpaired; not a measurement
  of the collection's cost, which the review traced).
- Census check: OK, 158 branch and 55 flow sites (unchanged), findings 72;
  regenerated census tables (line references) committed;
  `--self-test-mode-branches`, the fold-phase checker, the YAML parse and
  `git diff --check` pass.
- Not run here (coordinator): mutations for the amended LTB-0393 and LTB-0144
  checks.
