# RNG baseline probe: findings

Measurement step for the v0.2.3 RNG cut (macro WS2: inventory X1 absorbing
H8; plus C4). Brief: `inst/design/ledgr_v0_2_3_spec_packet/rng_probe_brief.md`.
Tree `release/v0.2.3` at `c836d291`. R 4.6.1, digest 0.6.39, withr 3.0.3,
mirai 2.7.2, duckdb 2.0.0. No product change; nothing here binds. Rerun with
`Rscript probe.R` (add `--cost` for timings), `Rscript check.R`,
`Rscript gut.R`.

**Outcome:** green. All five questions are answered by execution, no stop
condition fired (790 R lines, 52 KB of records, deterministic over three
runs), and three defects were found beyond the known one.

## 1. Cost (descriptive, `cost/`)

- `ledgr_derive_pulse_seed`, isolated median: 84 us. Parts: `canonical_json`
  33 us, SHA-256 12.5 us, normalize 8 us.
- In context (Rprof): about 155 to 175 us per call.
- Rprof share on the WS1 fixtures: `timing_scale` 2.2% (run) and 3.9%
  (sweep); `dense_scale_50x1260` 6.2% (run) and 6.6% (sweep).
- Seeded minus unseeded wall time: 0.02 / 0.08 / 0.45 / 0.84 s.
- Caveats: one host, 3 repetitions, timed under `load_all`.

## 2. Who pays [census]

- The default `seed` is NULL everywhere. Promotion uses the candidate's
  stored seed.
- No path derives a seed when the user passes none.
- With a seed: `ledgr_run` uses it as is; sweep derives one seed per
  candidate; walk-forward derives one per (fold, window, candidate).
- `pulse_seed` is computed on every decision-due pulse (NULL when unseeded).
- `set.seed` is called only in `ledgr_fold_envelope`, without a kind.
  `RNGkind` is never called.
- Defect: `ledgr_walk_forward(seed = NULL)` aborts (census row 05).

## 3. Frozen behaviour

- [worker_agreement] The plain `with_seed` recipe gives different results
  with 1 and 2 workers (38 versus 40 trades). Pinning the kinds, either
  Mersenne-Twister or L'Ecuyer-CMRG, makes them agree. The daemons run
  L'Ecuyer-CMRG.
- [caller_rng] With `seed = NULL`, `ledgr_run` and two-worker sweeps advance
  the caller's RNG, or create it when absent. One-worker sweeps and every
  seeded call leave it unchanged. The caller's kind never changes.
- [store_rng] duckdb's `dbAppendTable` calls `sample(letters, 10)`. Inside a
  seeded fold, ambient-RNG strategies therefore diverge between `ledgr_run`
  and sweep after the first checkpoint (pulse 10,004 of 10,010). Unseeded,
  changing `checkpoint_every` changes results (from pulse 8).
- [pulse_seeds] Today's values for seven execution seeds.

## 4. Detection gap [detection_gap]

- Missed by preflight, all Tier 1 and allowed for `workers > 1`:
  `sample.int`, `rbinom`, `stats::rexp`, `jitter`, `stats::kmeans`.
- A `.Random.seed` comparison around each strategy call catches all of them
  and passes `withr::with_seed`.

## 5. Inventory

See `inventory.md`.

## Open points

- Pulse rule: unit-step arithmetic is ruled out (adjacent-pulse r = -0.36
  under L'Ecuyer-CMRG, -0.06 under Mersenne-Twister). A small integer mixer
  passes; compute it vectorised or compiled.
- RNG kind: pin it at fold or worker start.
- Make store flushes RNG-neutral and restore the caller's RNG for
  `seed = NULL`.
- Widen the preflight lists, and consider the runtime `.Random.seed` check.
- Identity: the `seed_contract` bump touches A0's `sweep_attrs`;
  `ledgr_derive_seed` can stay unchanged.
- Fix walk-forward with `seed = NULL`.
- Add an equivalence test that actually draws from an RNG.

*Written to file by Claude from the probe agent's report text, because the
agent's file tool refused to create it.*
