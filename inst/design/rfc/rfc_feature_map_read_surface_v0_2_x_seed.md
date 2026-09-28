# RFC Seed: Feature-Map Read Surface

**Status:** Seed v1, a request for response-stage review. Nothing in this
document binds until a synthesis is accepted. No implementation has started.
**Date:** 2026-09-28
**Author:** Claude (seed v1). Per `../rfc_cycle.md`, a different model writes
the response, and the synthesis is written by whoever did not write the final
seed. The maintainer writes the response brief.
**Route:** full RFC. The work changes the public strategy read surface and the
validity of feature maps (`../rfc_cycle.md`, "Routes"). The response stage is
`Type 2`.
**Window:** design may run now; implementation lands after the v0.2.1.1
fold-writer and accessor optimization (`../ledgr_roadmap.md`), which changes
the accessor internals this RFC builds on.
**Source baseline:** `v0.2.0.2` at `c06e2e4`. Line numbers below refer to it.
**Name:** earlier artifacts call this the "feature-engine RFC". It does not
change how features are computed. It changes how strategies, helpers and
inspection address features by name, so this cycle uses the narrower name.

**Trigger.** Two accepted syntheses recorded this cycle as conditional:

- The accessor addendum bound only `ctx$vec$feature(feature_id)` and deferred
  "bulk multi-feature reads, feature-map vector output, lookback-window vector
  access, alias-map vector interactions" to "a later feature-engine RFC if they
  become necessary"
  (`rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md:265-272`).
- The strategy-authoring-helpers synthesis deferred feature-map vector helpers
  to the same RFC "if the single-feature vector surface proves insufficient"
  (`rfc_strategy_authoring_helpers_v0_1_8_x_synthesis.md:281-287`).

The v0.2.0.2 vignette audit (`../audits/v0_2_0_2_vignette_audit.md`, section 4)
shows that condition has been met. It routes three product findings here: P3
(no whole-universe read for active aliases), the capability half of P4
(inspection of parameterized maps) and the long-term half of P6 (what an outer
name on a bundle means).

**Context files:**
- `../contracts.md:682-699`, `:804-811`, `:821-857`: signal masking, feature
  maps, context and inspection contracts;
- `rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md`: alias
  resolution, identity and flat bundle aliases (sections 3, 4 and 6);
- `rfc_strategy_context_surface_v0_2_x_synthesis.md:35`: retained scalar
  accessors, feature planes and alias bundles;
- `R/pulse-context.R:545-560`, `:779-798`; `R/runtime-projection.R:402`,
  `:510`; `R/feature-alias-map.R:77`, `:177`; `R/feature-map.R:52-129`;
  `R/strategy-helpers.R:49-160`; `R/feature-inspection.R:28-174`;
- `../manual/optimization_coding_style.qmd`: every proposal must read
  primitives by index from prepared state, with no per-pulse frames.

---

## 1. Problem

A feature has two names. The engine ID (`sma_5`) identifies a computed series.
The alias (`fast`) is what a strategy author writes in a feature map. With
`ledgr_param()`, aliases are active: each sweep candidate resolves `fast` to
its own engine ID. Strategy code stays the same while the features vary, and
that is the point of active aliases.

The read surface covers only three of the four combinations:

| Read | One instrument | Whole universe |
| --- | --- | --- |
| by engine ID | `ctx$feature(id, feature_id)` | `ctx$vec$feature(feature_id)` |
| by alias | `ctx$features(id)`, `ctx$features(id, map)` | **none** |

The package, its style guide and the audit all teach whole-universe reads as
the canonical strategy idiom. An alias-based strategy cannot follow it. It must
loop over `ctx$universe` and call `ctx$features(id)` once per instrument. The
demo strategy (`ledgr_demo_sma_crossover_strategy()`) and the central
strategies in Sweeps and Research Workflow are written that way. The audit
records the consequence as SWEEP-C, FLOW-C, MISS-S and IND-S: the
documentation must teach an exception precisely where it teaches sweeps.

This has three costs:

1. **Teaching.** The canonical idiom and the sweep idiom conflict.
2. **Speed, silently.** At 500 instruments by 1,260 pulses, a per-instrument
   loop makes 630,000 `ctx$features()` calls per run, multiplied by the
   candidate count in a sweep. At `b14579f` a call cost 17.6 µs, and the
   v0.2.1.1 prepared accessors bring it to about 7.4 µs. An explicit-map call
   cost about 165 µs before the v0.2.1.1 memo
   (`../spikes/fold_writer_accessor_levers_spike/summary_report.md`). A plane
   read is one column extraction per alias per pulse. LDG-2877 deliberately
   leaves `ctx$features()` loops unwarned because no replacement exists
   (`R/pulse-context.R:545`).
3. **Helpers.** `ledgr_signal_feature()` accepts engine IDs only, so the
   signal, selection, weights and target pipeline is closed to alias-based
   sweeps. `ledgr_signal_return(ctx, lookback)` builds the engine ID
   `return_<lookback>` from a parameter, and its help tells users to register
   every concrete variant across the grid (`R/strategy-helpers.R:111-144`).
   The helper pipeline works around active aliases rather than with them.

## 2. Current state, executed

A scratch probe at `c06e2e4` ran active-alias maps through a run and a
two-candidate sweep, using Tier 1 probe strategies. It found:

1. **No alias vector read.** In a run with `fast = sma(fast_n = 5)` and
   `slow = sma(slow_n = 20)`, `ctx$features(id)` returns names `fast, slow`.
   `ctx$vec$feature("fast")` and `ledgr_signal_feature(ctx, "fast")` both fail
   with `ledgr_unknown_feature_id`: "Unknown feature ID `fast`. Available
   feature IDs: sma_20, sma_5."
2. **Candidate-scoped engine IDs.** In a sweep over `fast_n` in {5, 10}, the
   first candidate can read `sma_5` but not `sma_10`; the second can read
   `sma_10` but not `sma_5`. A strategy therefore cannot name a fixed engine
   ID, and building one from parameters is the anti-pattern the audit records
   in Research To Production.
3. **One name, two series.** `ledgr_feature_map(sma_10 = ledgr_ind_sma(5),
   sma_5 = ledgr_ind_sma(10))` is accepted. In that run,
   `ctx$features(id)[["sma_10"]]` is the 5-bar SMA (58.0809) while
   `ctx$feature(id, "sma_10")` and `ctx$vec$feature("sma_10")[1]` are the
   10-bar SMA (56.8916). `ledgr_validate_feature_map_aliases()` checks only
   that aliases are non-empty and unique (`R/feature-map.R:129-150`). Aliases
   and engine IDs share one namespace without a rule, which is a defect today,
   before any new accessor exists.
4. **Inspection of parameterized maps fails.** `ledgr_feature_contracts()` on
   `fast = sma(ledgr_param("fast_n"))` fails with an unclassed `simpleError`:
   "values must be length 1". Its sibling documents a classed refusal for
   feature factories (`ledgr_feature_factory_requires_params`,
   `R/feature-inspection.R:44-54`) but not for parameterized declarations. A
   pre-tag guard is proposed to restore the refusal. The capability to inspect
   such a map is this RFC's question.
5. **A bundle's outer name is dropped.** `bands = ledgr_ind_ttr_outputs("BBands",
   input = "close", n = 20)` produces aliases `bbands_dn, bbands_mavg,
   bbands_up, bbands_pctb`; `bands` disappears without a message
   (`R/feature-map.R:85-91`). The bundle constructor already has a `prefix`
   argument (`R/indicator-ttr.R:328`). A pre-tag guard is proposed to refuse
   the outer name.

## 3. Binding constraints

These come from accepted syntheses and the contracts. The seed treats them as
fixed. The response may challenge any of them, but only explicitly.

- **One feature engine.** Feature computation, feature IDs, fingerprints,
  warmup and no-lookahead are unchanged
  (`rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md`, section
  8; `../contracts.md:798-800`). This RFC changes only how existing values are
  addressed.
- **Alias identity.** A resolved alias map is per run or per candidate and is
  part of execution identity (`config_hash`, `alias_map_hash`). The runtime
  projection "may carry a derived alias-to-index map for cheap pulse access,
  but it is not the storage layer for alias maps and it has no hash"
  (active-aliases synthesis, sections 3 and 4).
- **Engine-ID plane semantics.** `ctx$vec$feature(feature_id)` is
  universe-aligned. Unknown IDs fail loudly with scalar-parity class and
  message, warmup is `NA_real_`, and the order is `ctx$universe`
  (addendum synthesis, Q4; `../contracts.md:804-807`).
- **Decision axis.** Availability contexts restrict every feature read to the
  current decision axis (`../contracts.md:808-811`).
  `ledgr_signal_feature()` masks inadmissible member scores, and a raw
  `values` entrance does not inherit that mask (`../contracts.md:682-686`).
- **Names.** Aliases are readable names, not roles, selectors or execution
  instructions (`../contracts.md:697-699`). Wide inspection names keep engine
  IDs (`../contracts.md:852-855`).
- **Flat bundles.** Bundles expose flat generated aliases. Nested namespaces
  belong to a separate bundle-namespace RFC (active-aliases synthesis, section
  6).
- **The retained surface.** Scalar accessors, feature planes and alias bundles
  stay (`rfc_strategy_context_surface_v0_2_x_synthesis.md:35`). This RFC adds
  to that surface. It does not remove from it.
- **Shape.** No per-pulse data frame, no per-instrument R loop inside an
  accessor, and no history query inside a callback
  (`../manual/optimization_coding_style.qmd`).

## 4. Questions and seed positions

### Q1. What is the whole-universe read by alias?

- **A. Widen `ctx$vec$feature()` to accept an alias or an engine ID.** One
  accessor, but two namespaces behind one argument. It depends entirely on Q2,
  and it blurs a contract that currently says "one engine feature ID".
- **B. Add `ctx$vec$features(feature_map = NULL)`.** It returns a named list of
  universe-aligned numeric vectors, one per alias, from the active map or an
  explicit map. It is the plane counterpart of `ctx$features(id, feature_map)`
  and completes the table in section 1. Engine-ID reads keep their own
  accessor.
- **C. Add a single-alias read, such as `ctx$vec$alias("fast")`.** It is
  explicit, but it adds a third spelling for one concept.

**Seed position: B.** It keeps the two namespaces in separate accessors and
mirrors an existing shape, so users learn a symmetry rather than an exception.
A strategy reads `f <- ctx$vec$features(); up <- f$fast > f$slow`. The oracle
is exact: for every alias `a` and universe ID `id`,
`ctx$vec$features()[[a]][ctx$idx(id)]` must equal `ctx$features(id)[[a]]`,
including warmup `NA` and availability restriction. The response should test
this against real strategies, including whether building a named list per call
matters. Callers normally read two to five aliases.

### Q2. What is the namespace rule for aliases and engine IDs?

Section 2 item 3 shows one string naming two series.

- **A. Refuse any alias that equals the engine ID of a different entry.** An
  alias equal to its own entry's engine ID (`sma_10 = ledgr_ind_sma(10)`)
  stays valid because it names the same series. Concrete maps are checked at
  construction; parameterized maps at resolution, since engine IDs exist only
  then (active-aliases synthesis, section 2).
- **B. Refuse every alias that looks like any engine ID.** This needs a
  grammar for engine IDs that the package does not have.
- **C. Keep the namespaces separate and document the ambiguity.** This fails
  the "readable names" contract.

**Seed position: A.** It fails closed with a classed error and leaves valid
maps' hashes unchanged, because a refused map never gets an identity. Some
maps accepted today will be refused. ledgr is pre-CRAN, so the cost is only
internal examples and tests; the response should count those. Check sweeps
specifically: a collision may exist in one candidate and not another.

### Q3. How do helpers read by alias?

`ledgr_signal_feature(ctx, feature_id)` is the helper pipeline's entrance and
carries the availability mask. Options: an `alias =` argument, a separate
`ledgr_signal_alias()`, or a rule that resolves aliases (which requires Q1 A).

**Seed position:** an explicit `alias` argument, mutually exclusive with
`feature_id`, with identical masking. A raw `values` entrance fed from
`ctx$vec$features()` must stay available but must not inherit the mask
(`../contracts.md:682-686`). The response should also decide whether
`ledgr_signal_return(lookback)` should keep building `return_<lookback>`, or
whether the documented route for parameterized lookbacks becomes an active
alias read.

### Q4. Can inspection helpers accept a parameterized map?

**Seed position:** `ledgr_feature_contracts()` and
`ledgr_feature_contract_check()` gain `feature_params = NULL`. With concrete
values they resolve the map exactly as `ledgr_run()` does, then inspect it.
Without them they keep the pre-tag classed refusal. Grid-level inspection
(the union of resolved contracts over a grid) is a separate helper, not part
of this cycle.

### Q5. What does an outer name on a bundle mean?

The pre-tag guard refuses it. Two long-term readings are possible: refusal
stays; or the outer name becomes the bundle's `prefix`, so `bands =` yields
`bands_dn`. Nested namespaces are excluded by the flat-bundle binding.

**Seed position:** keep the refusal and leave naming to the bundle-namespace
RFC. Q1 B does not need bundle prefixes: flat aliases already work as plane
names. The response should reject this position if prefix inference would
remove a real authoring trap at no identity cost.

### Q6. Where does the loop warning end?

LDG-2877 leaves `ctx$features()` loops unwarned "until an alias-aware vector
read exists".

**Seed position:** when Q1 ships, a loop of `ctx$features(id)` over at least
100 instruments warns through the same per-pulse mechanism, naming the new
plane read. Explicit-map loops warn the same way. The warning changes no
result.

## 5. Identity and evidence

A valid map's identity does not change. No proposal alters `config_hash`,
`alias_map_hash`, `feature_set_hash` or feature fingerprints. Q2 changes only
which maps are valid. The synthesis should bind detecting checks. Candidates:

- plane-scalar parity for every alias on dense and availability runs,
  including warmup and a held nonmember;
- a two-candidate sweep in which each candidate's `ctx$vec$features()$fast`
  equals its own resolved series;
- construction-time and resolution-time refusal of a colliding alias, with a
  mutation that removes the check;
- helper masking parity between `feature_id` and `alias` reads;
- inspection with `feature_params` equal to the run's resolved contracts;
- the loop warning at 100 instruments and not at 99, with results unchanged;
- an interleaved clock of the demo strategy's alias loop against the plane
  read at the registered release shape, as the review obligations require.

No spike is proposed. The pre-seed probe answered the open behavioural
questions, and a plane read's cost follows from the existing prepared state.
The response may propose one if it finds a question only execution can answer.

## 6. Out of scope

- how features are computed, including the cold availability strict-window
  path, which has its own cost question;
- lookback-window vector reads, which touch the accepted historical-projection
  synthesis's window design and belong there;
- nested bundle namespaces and conditional feature families;
- cross-sectional or layered features (the ML cluster);
- removing any existing accessor;
- the explicit-map double validation, which v0.2.1.1 fixes.

## 7. Sequencing

1. Pre-tag, outside this cycle: the classed refusals for P4 and P6, as proposed
   to the maintainer on 2026-09-28.
2. Workstream 26 documents the forced loop honestly until this RFC ships.
3. The v0.2.1.1 accessor optimization lands first. Q1's plane read reuses its
   prepared alias map and index.
4. This cycle: response (Type 2), seed v2, synthesis, final review. Then a
   direct ticket cut. Documentation changes to Sweeps, Research Workflow,
   Indicators, Missing Data and the demo strategy follow the implementation;
   they are not part of this cycle.

This seed uses no internal "v1" shorthand. The window names are roadmap
windows.
