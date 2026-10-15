# Workstream 38 close review

**Mode:** Type 1 close review
**Range:** `0d86608a..6594b6fe`
**Verdict:** CHANGES_REQUIRED
**Date:** 2026-10-15

The accepted envelope plus P1-P5 architecture is sound, but the extraction
changed cost and behavior in three places and left several detector and record
gaps. LDG-3053 and LDG-3054 return to `in_progress` until the corrections are
verified.

## Blocking findings

### F1. Environment-held mutations changed growth shape

P4 writes one position element and cash through the shared fold-state
environment for every fill. R copies a vector held in an environment on the
element write, so fill cost now grows with universe width. At 12,000
instruments and eight all-fill pulses the candidate measured 1.43 times the
pre-cut median, 72 seconds against 50.5 seconds. P1 likewise appends one entry
per pulse to the environment-held `equity_facts` list, making that accumulator
quadratic in pulse count.

Required correction: use P4-local positions and cash and install them once,
without changing the per-fill lot, event, fact and mutation order. Move equity
fact accumulation to one declared closure-owned service. Add a scaled all-fill
clock at 5,000 or more instruments and correct the seven-shape record.

### F2. Persisted diagnostic stage labels changed

The new `decision` and `commit` current-stage values reach availability
exception diagnostics. One reproduced row changed from `accounting` to
`commit`. Workstream 38 is a refactor and does not own that stored behavior.

Required correction: restore the baseline label sequence, keeping `valuation`
until the strategy call and `accounting` through commit. Add availability
witnesses for a P2 context-build error and a P5 state error.

### F3. Dense resume rejects scalar strategy state

The carrier validator incorrectly types `state_prev` as a list. A dense
strategy returning `state_update = 5` used to resume and now raises an
internal error.

Required correction: permit any non-data-frame state value, correct the
inventory and add a dense scalar-state resume witness.

## Maintainer disposition

### F4. Compiled positions naming

The compiled kernel returns unnamed positions. The live fold return exposed
that pre-existing divergence, and the extraction added names before returning
the state. The maintainer accepts this as necessary live-return plumbing:
positions without instrument names were never intended to leave the fold.
The closeout must record the cause and stop claiming that no other defect was
fixed.

## Detector and record findings

### F5. Structural detector coverage

The checker does not detect removed or duplicated stage calls, envelope-owned
slot writes, or data frames nested in returned lists. The current behavior is
clean, but the claims exceed the registered detector.

Required correction: extend the structural checker or add an equivalent
registered runtime probe, then narrow any remaining claim to detected changes.

### F6. RNG claim wording

LCL-0266 overstates the mutation its witness detects. Add a fold-level witness
or narrow `smallest_failing_change` to the actual restoration boundary.

### F7. Evidence disclosure

The record does not explain the LTB-0026 source-pin retargets, disclose
`--allow-dirty`, or map each ledger row to its record directory. Correct the
closeout and ticket evidence.

## Verified clean

- E and all five stages occur in the accepted order and use one carrier.
- All eight adjacent recorder comparisons are exact across 50 gated families
  and identity.
- The final self-test catches 51 of 51 isolated family mutations.
- Published paired-clock ratios recompute exactly.
- Transaction and accounting-fact mutations fail their owning detector.
- The installed-context correction in `47554620` is not weaker.
- The full package check passes with 24 built vignettes.

No Type 2 question remains. The corrections retain the accepted architecture
and return for one focused Type 1 re-review.
