# LDG-3052 closeout: typed fold phase contract

**Status:** Complete; Workstream 38 implementation continues with LDG-3053.
**Date:** 2026-10-15
**Implementation commits:** `574a9702`, `61fd6774`
**Authority:** accepted fold-execution phase synthesis, Sections 4 to 8

## Outcome and necessity

The package now has one internal, typed fold-state constructor with a fixed
locked binding set and one typed stop-result constructor. The current fold body
is still inline and its control flow is unchanged. The checked-in inventory
maps its reads, writes, services and observable effects to E or P1-P5 before
any extraction, including the sixteen shadowing assignments and three dead
runner stores behind the accepted live-return repair.

This is the smallest useful contract layer for the refactor. The existing
locals cannot safely be moved piecemeal without first naming ownership, and
the old scale recorder was already broken because it queried the deleted
`features` table. No general orchestration system, public phase API or second
execution engine was introduced. The carrier and stop result can be removed if
the fold extraction is abandoned; the recorder manifest remains useful for
any later exactness work.

The maintainer resolved the spec-cut question by keeping the recorder repair
inside LDG-3052 as its first isolated commit. No additional ticket was added.

## Acceptance results

1. **Inventory: PASS.**
   [`fold_execution_phase_inventory.md`](fold_execution_phase_inventory.md)
   covers every baseline source range, all carrier slots and their last reads,
   the sixteen loop-local assignments, the three unread runner stores, the
   complete stateful-service census, the dense-only final-bar warning and
   dense/availability fill-stamping difference. It records the decision (11)
   supersession and the one decision (7) exception.
2. **Typed state and stop result: PASS.** `ledgr_fold_state_new()` creates an
   empty-parent environment with exactly twenty typed slots, validates their
   scalar/vector/list shapes, rejects top-level data-frame slots and locks the
   environment against new bindings. `ledgr_fold_stop_result()` carries the six
   accepted fields. LTB-0278 directly exercises valid mutation plus hostile
   binding, table, unnamed-vector and stop shapes.
3. **Services: PASS.** The inventory declares every stateful service and
   mutating or cursor-bearing call. The parsed detector rejects a valuation,
   provider, corporate-action, diagnostic or output-handler call from an
   undeclared stage. Its independent service-owner mutation fails LTB-0279.
4. **Stage boundary: PASS.** The inventory fixes the future signatures to the
   carrier, declared services and typed primitives. Public frames remain P2
   locals. No export, public class, public condition, store row, result or
   current fold statement changed under this ticket.
5. **Structural failure sensitivity: PASS.** LTB-0279 independently introduces
   and catches: a data-frame argument; data-frame carrier slot; copied carrier;
   `ctx` retaining the carrier; wrong slot owner; wrong service owner; and an
   inline stage body left in the envelope. The checker also passes against the
   current source and will begin scanning each top-level stage as it lands.
6. **Recorder and parent baseline: PASS.** The manifest refuses both a missing
   and an undeclared family. The full fixture record at `61fd6774` has 50 gated
   families plus informational identity, and its self-test detects all 51
   one-family mutations. `momentum_feature_plane` has one real
   `ctx$vec$feature("return_60")` hash per pulse. LTB-0277 pins the exact
   two-out/one-in family transition and proves the schema has no `features`
   table. The historical comparison and every difference are recorded under
   [`evidence/fold_refactor_parent/`](../../../dev/bench/v0_2_2_real_data_scale/evidence/fold_refactor_parent/).

## Recorder evidence

The registered default fixture ran from clean commit `61fd6774` on Windows
x64 with R 4.6.1 and wrote 51 family files in about 180 seconds. Phase clocks
and all hashes are in `summary.csv` and `summary_phases.csv`. The full family
files remain scratch evidence. The checker mutated every family independently:
51 of 51 were detected alone.

Two further 20-instrument, 100-session records used different output
directories and compared 25/25 gated families plus identity byte-identically.
This catches output-path leakage from the recording wrapper. The strategy
params remain the original `lookback` and `n`, and preflight remains tier 1.

Against the last accepted 52-family record at `3ab97b33`, 44 common families
are byte-identical. The two removed feature families, one added callback-time
family, schema-120 run-info changes and identity-rule-3 ordering/identity
changes are enumerated in `transition.csv`. Walk-forward metric and trade-count
multisets are exact after identity-key reordering.

## Verification and test ledger

- LCL-0275/LTB-0277: new review-profile recorder/schema contract;
- LCL-0276/LTB-0278: new review-profile carrier/stop runtime contract;
- LCL-0277/LTB-0279: new review-profile parsed ownership contract;
- test-codebase-contracts, test-control-plane and the two new files: pass;
- compiled test-execution-spec, including unchanged LTB-0006 and LTB-0013:
  pass;
- test-availability-provider-production: pass;
- `tools/check-fold-phase-contract.R .`: pass;
- `git diff --check`: clean.

The first source-only execution-spec run lacked the compiled DLL and is not a
product result. Reloading the same tree with compilation exercised the
supported path and passed; generated cpp11 line-ending churn was restored.

## Seven-shape walk

The production additions are fixed-size constructors over twenty and six
fields. They do not bind per-row frames, subset a full table in an id loop,
parse or format per observation, write JSON, recompute data-dependent work,
perform pairwise validation or grow an environment-held vector. The recorder
does one fixed-width feature-plane digest per pulse because the pulse is the
evidence unit; it writes one row directly and never accumulates a growing list
or restores feature persistence. The source checker parses each file once and
operates only in the review lane.

No performance claim is made before extraction. The full parent record is the
byte oracle for each LDG-3053 and LDG-3054 stage commit.
