# RFC: RNG Contract For v0.1.8 Sweep And Fold Core

**Status:** Draft RFC for v0.1.8 spec decision.
**Date:** 2026-05-13
**Author:** Codex
**Related documents:**

- `inst/design/ledgr_v0_1_8_spec_packet/v0_1_8_spec.md`
- `inst/design/audits/v0_1_8_spec_deep_review.md`
- `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`
- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`

## Purpose

v0.1.8 introduces a shared fold core and `ledgr_sweep()`. That makes RNG
semantics a live architectural concern even if most strategies remain
deterministic.

The current ledgr state is mixed:

- `ledgr_run(seed = NULL)` is the only supported public path;
- non-`NULL` public seeds are rejected;
- `seed = NULL` is stored in run identity;
- lower-level configs can carry `engine.seed`;
- the runner still calls `set.seed(runtime_seed)`, with `runtime_seed = 1L`
  when the config seed is `NULL`.

This RFC proposes a narrow, explicit RNG contract for v0.1.8 so sweep does not
inherit ambient RNG state or force a later refactor under the parity contract.

## Prior Art: CausalStress

This RFC uses Max's CausalStress package as prior art. The source document is
outside the ledgr repository, so it is cited here as design inspiration rather
than as a navigable ledgr design input.

The CausalStress constitution treats RNG as part of the scientific instrument:

- synthetic generators must accept explicit `seed`;
- the runner records the seed in result metadata;
- the RNG backend is fixed with
  `RNGkind("Mersenne-Twister", "Inversion", "Rounding")`;
- top-level runs use one task seed;
- stochastic subroutines derive child seeds from the task seed and a salt;
- fingerprints include the task seed as run identity, while avoiding duplicate
  `config$seed` drift.

Relevant implementation patterns:

- `cs_set_rng(seed)` sets the fixed RNG kind and optionally calls `set.seed()`;
- `cs_run_single()` calls `cs_set_rng(seed)` once at the highest runner
  boundary;
- DGPs are called with the same `seed`;
- estimators receive `config$seed`;
- bootstrap routines derive child seeds through `cs_derive_seed(base_seed,
  salt)`;
- result metadata records `seed`.

The important design lesson is not the exact RNG algorithm. It is the contract:
randomness is an explicit run input, sub-seeds are derived deterministically,
and reproducibility does not depend on ambient session RNG state.

## Proposed ledgr Contract

### 1. Seed belongs to execution, not the snapshot

Execution randomness must not affect `snapshot_hash`.

A sealed snapshot records the data artifact. If the data was simulated, the
simulation seed belongs in snapshot source metadata, not in execution identity.
Strategy randomness belongs to the experiment/run execution config.

### 2. `seed` becomes a first-class execution identity input

`ledgr_run(seed = 123)` should be accepted in v0.1.8 if this RFC is adopted.

The seed must:

- be `NULL` or an integer-like scalar;
- be stored in `config_json`;
- participate in `config_hash`;
- appear in run info/provenance;
- affect auto-generated run identity when `run_id = NULL`;
- leave existing `seed = NULL` behavior reproducible for old deterministic
  workflows.

Changing seed means changing the execution identity.

### 3. Sweep derives candidate seeds from the master seed

`ledgr_sweep(seed = NULL)` remains deterministic for deterministic strategies.

If `seed` is supplied:

```text
candidate_seed = derive_seed(master_seed, candidate_label)
```

Candidate seed derivation must be independent of:

- grid row order;
- worker assignment;
- completion order;
- cache warmth;
- whether the sweep is sequential or parallel in a future release.

The candidate label should be the `run_id` column value from
`ledgr_param_grid()`.

### 4. Fold core receives seed explicitly

The sweep dispatcher derives the candidate seed before candidate execution and
passes it to the fold core as explicit input.

The fold core must not infer candidate RNG state from:

- daemon/global worker RNG;
- ambient `.Random.seed`;
- output handler state;
- cache state.

This keeps the future parallel contract simple:

```text
same experiment + params + candidate label + seed + snapshot + features
  -> same candidate result
```

### 5. Strategy RNG access is through `ctx`, not ambient RNG

Strategies that want ledgr-level reproducibility must use ledgr-provided RNG
accessors.

Minimum v0.1.8 surface:

```r
ctx$seed(stream = "default")
```

Possible later convenience helpers:

```r
ctx$random_uniform(stream = "tie_break")
ctx$sample(x, size, replace = FALSE, stream = "tie_break")
ctx$rng(stream = "tie_break")
```

The first implementation can expose only `ctx$seed()` and document that users
must use it to seed local deterministic draws. Longer term, helper functions
are safer because they avoid requiring user code to call `set.seed()` inside a
strategy.

Direct unscoped calls to `runif()`, `rnorm()`, `sample()`, or `set.seed()`
inside a strategy should not be considered ledgr-reproducible. Preflight should
either classify them as Tier 3 or emit a loud note that the strategy uses
ambient RNG outside the ledgr contract.

### 6. Stream seeds are derived, not consumed

`ctx$seed(stream)` should derive a stable integer seed from:

```text
candidate_seed + pulse timestamp + stream label
```

Open question:

- Should instrument ID also be included when a strategy requests a seed inside
  an instrument loop?

Conservative default:

- do not include instrument ID implicitly;
- require the user to include it in the stream label if needed, e.g.
  `ctx$seed(paste0("tie_break:", id))`.

This avoids hidden changes when a strategy changes loop structure.

### 7. Scoped RNG is preferred over global mutation

The current runner calls `set.seed(runtime_seed)` at engine entry. That mutates
caller session RNG state and is not a good long-term fold-core primitive.

v0.1.8 should aim for one of these:

1. A scoped RNG helper around strategy invocation that restores caller RNG
   state after each draw or pulse; or
2. `ctx$seed()` only, with no fold-core global `set.seed()` call for
   `seed = NULL`.

The minimum acceptable v0.1.8 correction is:

- remove or neutralize the unconditional `set.seed(1)` side effect for
  `seed = NULL`;
- preserve deterministic behavior for strategies using no ambient RNG;
- require `ctx$seed()` for reproducible stochastic strategies.

## Proposed API Shape

### `ledgr_run()`

```r
ledgr_run(exp, params = list(), run_id = NULL, seed = NULL)
```

`seed = NULL`:

- deterministic strategy behavior unchanged;
- no stochastic reproducibility claim;
- no ambient RNG reset should be needed.

`seed = 123`:

- accepted;
- stored in `config_json`;
- included in `config_hash`;
- made available to the fold core;
- available to strategy code through `ctx$seed()`.

### `ledgr_sweep()`

```r
ledgr_sweep(exp, param_grid, precomputed_features = NULL, seed = NULL, ...)
```

`seed = NULL`:

- no candidate seed is derived;
- deterministic strategies remain deterministic.

`seed = 123`:

- each candidate receives a derived seed;
- the derived seed is included in candidate metadata;
- candidate result identity includes the master seed and derived seed contract.

## Seed Derivation

ledgr should use a simple deterministic integer derivation helper:

```text
derive_seed(base_seed, salt) -> integer in [1, 2147483647]
```

The helper should be:

- stable across platforms;
- independent of R's current RNG state;
- based on canonical string inputs;
- tested against fixed fixtures.

CausalStress uses a simple rolling integer hash in `cs_derive_seed()`. ledgr
can either reuse that pattern or use a digest-based implementation that converts
the first bytes of a SHA-256 hash into a valid R integer seed. The key property
is stable output, not cryptographic strength.

Suggested salts:

```text
candidate seed:
  paste("candidate", candidate_label, sep = "::")

pulse stream seed:
  paste("pulse", ts_utc, stream, sep = "::")
```

## Identity And Metadata

Committed runs should record:

- public seed argument;
- RNG contract version;
- RNG backend/version if ledgr fixes one;
- whether strategy used ledgr RNG helpers, if detectable;
- preflight notes about ambient RNG usage.

Sweep results should record:

- master seed;
- per-candidate derived seed;
- RNG contract version;
- candidate label used for derivation.

## Preflight Implications

`ledgr_strategy_preflight()` should detect obvious ambient RNG usage:

- `runif`
- `rnorm`
- `sample`
- `set.seed`
- `RNGkind`

Proposed classification:

- `ctx$seed()` usage: allowed under the ledgr RNG contract;
- ambient RNG calls without ledgr seed helpers: Tier 3 or loud Tier 2 warning;
- explicit `set.seed()` inside strategy: Tier 3 by default, because it mutates
  global RNG and can break parallel parity.

This is a policy decision. The important point is that ambient RNG calls cannot
quietly be treated as reproducible under ledgr provenance.

## Relationship To Parallel Sweep

The design is intentionally parallel-ready:

- the orchestrator derives candidate seeds before dispatch;
- workers receive candidate seeds as plain scalar inputs;
- worker global RNG state is irrelevant;
- candidate result does not depend on daemon assignment;
- future `mirai` RNG streams can still be used internally, but they are not the
  ledgr semantic source of truth.

## Non-Goals

This RFC does not require v0.1.8 to add:

- stochastic strategy examples;
- random strategy templates;
- distributional simulation helpers;
- public parallel sweep;
- convenience RNG helpers beyond `ctx$seed()`;
- snapshot seed semantics.

## Recommended v0.1.8 Decision

Adopt a narrow RNG ticket in v0.1.8:

1. Accept public non-`NULL` `seed` in `ledgr_run()`.
2. Store seed in config identity and run metadata.
3. Add deterministic seed derivation helper.
4. Add `ctx$seed(stream = "default")`.
5. Derive sweep candidate seeds from `(master_seed, candidate_label)`.
6. Record master/candidate RNG metadata in `ledgr_sweep_results`.
7. Add preflight detection for ambient RNG calls.
8. Remove or scope the current unconditional `set.seed(1)` side effect.

This is smaller than full stochastic strategy support, but it makes the
contract explicit before sweep and parallelism make RNG ambiguity more
expensive.

## Open Questions

1. Should ledgr fix `RNGkind()` as CausalStress does, or is stable seed
   derivation plus scoped base R RNG enough?
2. Should `ctx$seed()` be the only v0.1.8 strategy RNG surface, or should
   `ctx$sample()` / `ctx$random_uniform()` ship at the same time?
3. Should ambient RNG calls be Tier 3 hard failures or Tier 2 warnings?
4. Should `seed = NULL` produce no candidate seed, or should ledgr derive a
   deterministic default candidate seed for sweep?
5. Should the derivation salt include instrument ID automatically, or should
   users include instrument IDs in stream labels when needed?
