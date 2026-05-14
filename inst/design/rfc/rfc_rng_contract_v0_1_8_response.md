# RFC Response: RNG Contract For v0.1.8 Sweep And Fold Core

**Status:** Reviewer response.
**Date:** 2026-05-13
**RFC:** `inst/design/rfc/rfc_rng_contract_v0_1_8.md`
**Reviewer:** Claude (Sonnet 4.6)

---

## Overall Assessment

The RFC correctly diagnoses the problem and proposes the right structural
direction. The existing `set.seed(runtime_seed)` at runner level and the
sequential sweep RNG leakage that follows are real. The proposed contract —
seed as explicit fold-core input, per-candidate derivation from master seed
and candidate label — is the right long-term shape.

Two corrections before implementation begins:

1. The internal infrastructure is significantly more complete than the RFC
   implies. This simplifies implementation.
2. The eight proposed items span two different scopes. They should be split
   before ticket cut to avoid pulling stochastic workflow support into the
   fold-core/sweep release.

---

## Correction 1: The Internal Plumbing Already Exists

The RFC states: "store seed in `config_json`" and treats this as new work.

It already happens. `R/backtest-runner.R:347–348` reads `cfg$engine$seed`.
`R/backtest.R:851–852` stores `seed` into `engine.seed` in the config list
before serialization. `R/config-validate.R:71–75` validates `engine.seed`.
`R/config-hash.R` hashes the full canonical config, which includes
`engine.seed`.

The consequence is that `engine.seed: null` is already in every
null-seed run's `config_json` and `config_hash`. Enabling public seed
support does not change `config_hash` for existing runs. It only adds a
valid non-null path that was previously blocked at the public API layer.

The actual blocking point is `ledgr_run_experiment()` at line 335, which
aborts for any non-`NULL` public seed before the seed reaches the config.
The lower-level `ledgr_backtest_run_internal()` at line 777 already handles
seed validation and wires the validated integer into `engine.seed`.

Implementation consequence: RFC item 2 ("store seed in config identity and
run metadata") is already implemented at the internal level. The v0.1.8
ticket for seed acceptance is narrower than it appears — the work is
removing the early abort in `ledgr_run_experiment()` and threading the
public seed through to the existing internal path.

---

## Correction 2: The `set.seed()` Problem Is At The Runner Boundary, Not Inside The Fold Core

`backtest-runner.R:384`:

```r
set.seed(runtime_seed)
```

This call is at the runner boundary, before DuckDB opens, before any fold
execution begins. For `ledgr_run()`, this is the right level — it is called
once per run. The problem is what happens when the fold core is extracted
for sweep: if the `set.seed()` is not moved into the fold core, sequential
sweep candidates will inherit RNG state from the previous candidate's
execution. That is the sequential sweep leakage the RFC correctly describes.

The fix is not to remove `set.seed()`. It is to move it inside the fold core
so it fires once per candidate evaluation using the candidate seed derived
by the sweep dispatcher. For `ledgr_run()`, the fold core receives the
public seed directly. For sequential sweep, the fold core receives a derived
per-candidate seed. The runner-level call is superseded by the fold-core
call.

For `seed = NULL`, the correct v0.1.8 behavior is: no `set.seed()` at fold
entry. Deterministic strategies do not touch `.Random.seed` and are
unaffected. Strategies using ambient RNG with `seed = NULL` were never
ledgr-reproducible; removing the `set.seed(1L)` default clarifies that
rather than breaking it.

---

## Scope Split

The RFC's eight recommended items span two different concerns. Conflating
them risks pulling stochastic workflow support into the fold-core/sweep
release.

### v0.1.8 Must-Have

These items are required for the parity contract and the parallel-ready
fold-core boundary. They do not require stochastic strategy support.

**1. Accept public non-`NULL` seed in `ledgr_run()` and `ledgr_sweep()`.**
Remove the early abort in `ledgr_run_experiment()`. Wire the public seed
through to `engine.seed`. The internal machinery already handles it.

**2. Move `set.seed()` into the fold core.**
Remove `set.seed(runtime_seed)` from the runner boundary.
The fold core applies `set.seed(candidate_seed)` once at fold entry when
a seed is supplied, and does not call `set.seed()` at all when `seed = NULL`.
This removes the `set.seed(1L)` default side effect and makes the fold-core
boundary seed-explicit.

**3. Add a deterministic seed derivation helper.**
Implement `ledgr_derive_seed(base_seed, salt)` as a stable internal helper.
Use `canonical_json()` for the salt string, then SHA-256 via
`digest::digest()`, converted to a valid R integer seed `[1, 2^31 - 1]`.
Test against fixed fixtures. This helper must be independent of R's current
RNG state.

**4. Derive per-candidate seeds in the sweep dispatcher.**
For `seed = NULL` sweep: no candidate seed is derived; fold core receives
`seed = NULL`.
For `seed = integer` sweep: each candidate receives
`ledgr_derive_seed(master_seed, paste("candidate", candidate_label, sep = "::"))`.
The derivation happens in the sweep dispatcher before candidate dispatch,
not inside the fold core. The derived seed is passed as an explicit fold-core
input.

**5. Store seed in candidate metadata.**
Sweep candidates should record `master_seed` and `derived_seed` (or `NULL`)
in result attributes or as metadata columns. This is identity metadata, not
durable provenance.

### v0.1.8 Recommended But Separable

**6. `ctx$seed(stream = "default")`.**
This is needed only if stochastic strategies are part of the v0.1.8 test
surface. If v0.1.8 sweep is tested only against deterministic strategies,
`ctx$seed()` can be deferred to v0.1.8.x. The fold-core seed threading
(items 1–4) is sufficient to make the contract sound without a user-facing
`ctx$seed()` accessor.

If `ctx$seed()` ships in v0.1.8, the contract requires specifying:
- return type: integer scalar derived from `(candidate_seed, ts_utc, stream)`;
- behavior when `seed = NULL`: error or `NULL`? The RFC does not resolve this;
- availability in interactive modes: `ledgr_pulse_snapshot()` must also
  expose `ctx$seed()` or document the absence explicitly;
- stream label constraints: any string, or a constrained vocabulary?

Stream derivation: `ledgr_derive_seed(candidate_seed, paste("pulse", ts_utc, stream, sep = "::"))`.

### v0.1.8.x Deferred

**7. Preflight detection of ambient RNG calls.**
Valuable but not blocking for v0.1.8. The fold-core boundary is correct
whether or not preflight classifies `runif()` inside strategies. Defer to
v0.1.8.x to avoid widening the v0.1.8 preflight contract change surface.

**8. RNG contract version in run metadata.**
Record `rng_contract_version` as a named metadata field so future derivation
changes are traceable. Implement alongside or after the first stochastic runs
in v0.1.8.x.

---

## Responses To Open Questions

### 1. Should ledgr fix `RNGkind()` as CausalStress does?

No. CausalStress is a simulation framework where full RNG control is a
correctness requirement. ledgr is a backtesting framework where most
strategies are deterministic and user RNG kind choices are not ledgr's
business.

Fixing RNG kind globally would surprise users who set it explicitly and has
no user-visible benefit for deterministic strategies. Instead, ledgr should
record the active `RNGkind()` in run metadata at execution time so users
can identify cross-session reproducibility gaps.

If a future stochastic strategy contract requires a fixed RNG kind, that
should be an explicit opt-in tied to a specific RNG contract version, not
a package-global side effect.

### 2. Should `ctx$sample()` / `ctx$random_uniform()` ship with `ctx$seed()`?

No. Ship `ctx$seed()` first and observe how strategy authors use it. The
stream model needs real usage before convenience helpers are added on top.
Premature helpers that don't match actual patterns create dead API surface
under the strategy context contract.

### 3. Should ambient RNG calls be Tier 3 hard failures or Tier 2 warnings?

Split by call type.

`set.seed()` inside a strategy body: Tier 3, hard failure. This is global
state mutation that is already inconsistent with the contracts. The contracts
state that Tier 1 requires no hidden mutable state. `.Random.seed` is hidden
mutable state. `set.seed()` inside a strategy is structurally incompatible
with parallel sweep regardless of whether parallel sweep exists yet. Note:
this is a contract clarification, not a contract change — the contracts
already imply this but the current preflight does not detect it.

`runif()`, `rnorm()`, `sample()` (without `ctx$seed()` setup): Tier 2
with a loud note. These are reproducible under deterministic session
conditions if `set.seed()` is called at fold entry. Classifying them Tier 3
would reject many legitimate existing strategies that use `sample()` for
tie-breaking or portfolio shuffling. The note should say:

> Strategy uses ambient R RNG (`runif`, `sample`, etc.) without ledgr seed
> helpers. Results are reproducible on the same platform if `seed` is
> supplied, but are not guaranteed stable across parallel workers or R
> sessions without careful seed management.

`RNGkind()` inside a strategy body: Tier 3. Same reasoning as `set.seed()`.

### 4. Should `seed = NULL` produce no candidate seed or a deterministic default?

No candidate seed for `seed = NULL`. Deriving a deterministic default seed
for `seed = NULL` would change the execution identity of existing
deterministic workflows even though they produce the same results. It is
also misleading: users who omit `seed` should not get covert seeding.

`seed = NULL` is the explicit "I am not claiming stochastic reproducibility"
path. Keep it that way.

### 5. Should derivation include instrument ID automatically?

No. The conservative default is correct: instrument ID must be included by
the user in the stream label when needed.

Implicit instrument ID inclusion would change results when a strategy changes
its loop structure or instrument ordering without changing any explicit seed
argument. Explicit inclusion — `ctx$seed(paste0("stream:", id))` — is self-
documenting and avoids hidden coupling between loop structure and RNG stream.

---

## Additional Findings

### The RFC's related documents include a path from another repository

`CausalStress/inst/design/CAUSAL_STRESS_CONSTITUTION.md` is listed as a
related document. This is in a separate repository and cannot be navigated
or read as part of the ledgr design system. The CausalStress RNG patterns
are relevant as design inspiration and are correctly credited in the RFC
body, but the file reference should be removed from the related-documents
list or replaced with a prose acknowledgement.

### `ctx$seed()` with `seed = NULL` needs an explicit contract

The RFC does not specify what `ctx$seed()` returns when the fold is running
with `seed = NULL`. Two options:

1. Error loudly: "seed must be supplied to use ctx$seed()." This is clean
   but breaks Tier 2 strategies that call `ctx$seed()` defensively.
2. Return `NULL` silently, leaving seed management to the caller.

Option 1 is safer and consistent with ledgr's "strict contracts beat silent
convenience" principle. If a strategy calls `ctx$seed()` and `seed = NULL`,
that is a strategy contract error: the strategy requires a seed but none was
supplied.

### Parity test requirement

The fold-core/output-handler extraction ticket must include a parity test
that proves deterministic strategies produce identical results before and
after the `set.seed(1L)` call is removed from the runner. This test is the
evidence that removing the unconditional seed does not break deterministic
strategy behavior.

---

## Proposed Spec Update

The v0.1.8 spec should replace the current R6 section with:

```text
R6. RNG Contract

v0.1.8 makes seed an explicit first-class execution input.

For ledgr_run():
- seed = NULL: no set.seed() at fold entry; no stochastic reproducibility
  claim; deterministic strategies unaffected;
- seed = integer: applied via set.seed() inside the fold core at fold entry;
  stored in config_json and config_hash; appears in run provenance.

For ledgr_sweep():
- seed = NULL: no candidate seed derived; fold core receives seed = NULL;
- seed = integer: sweep dispatcher derives per-candidate seeds via
  ledgr_derive_seed(master_seed, paste("candidate", label, sep = "::"))
  before dispatch; fold core receives the derived seed as explicit input.

The fold core must not read .Random.seed, daemon RNG state, or ambient
session state to determine its seed. The derived seed is the only source
of truth.

Candidate result metadata records master_seed and derived_seed.

The ledgr_derive_seed() helper is deterministic, platform-stable, and
independent of R's current RNG state.

set.seed() inside a strategy body is Tier 3. runif(), rnorm(), sample()
without ctx$seed() setup are Tier 2 with a loud note.

ctx$seed(stream = "default") is recommended but separable: it may be
deferred to v0.1.8.x if stochastic strategies are not tested in v0.1.8.
The fold-core seed threading must be designed to support ctx$seed() later
without interface changes.
```

---

## Summary

Accept the RFC's core direction with the following adjustments:

- Acknowledge that `engine.seed` and config_json storage already exist;
  the ticket is narrower than the RFC implies.
- Move `set.seed()` into the fold core rather than removing it.
- Split the eight items into three tiers: must-have for v0.1.8 (items 1–5),
  separable (item 6 / `ctx$seed()`), and deferred to v0.1.8.x (items 7–8).
- Resolve open questions as above: no fixed RNGkind, no convenience helpers
  yet, split ambient RNG classification, no implicit seed for `seed = NULL`,
  no automatic instrument ID in stream derivation.
- Remove the CausalStress file reference from related documents.
- Add a parity test for the `set.seed(1L)` removal to the fold-core
  extraction ticket.
