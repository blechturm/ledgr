# Type 1 Final Review: Typed Fold Carrier

- Status: PASS_AFTER_PATCHES
- Reviewer: Claude, author of seed v1 and seed v2 but not the synthesis
- Date: 2026-10-30
- Mode: Type 1 final review; verification, not design
- Synthesis: `rfc_typed_fold_carrier_v0_2_3_synthesis.md`
- Baseline checked: `a86dbc22`; `R/` unchanged since seed v2
- Closure: P1, P2 and the recommended P3 were applied in place to the
  synthesis on 2026-10-30 (see its Revision History).

## 1. Verdict

**PASS_AFTER_PATCHES.** The synthesis faithfully adopts seed v2, its Section 1
rulings, the Type 2 response and both maintainer decisions (Q1, Q6). Its
architecture is coherent and matches the current seams:

- the run axis plus context ordinals;
- one typed lot implementation with opening, fill and disposition operations,
  used by the fold, replay, resume and compiled pack/unpack;
- cash outside the kernel;
- publication in decision order;
- bounded pulse staging into the existing diagnostic writer;
- a block-level failure boundary.

Two patches are required and one is recommended. They complete rules the
synthesis already chose. None needs a Type 2 round or a new maintainer
decision.

**The inputs are right.** The synthesis keeps the probe's limits: one
zero-cost shape, cumulative Rprofmem rather than peak memory, only LIFO
mutated through the typed arm, and no typed non-fill operation. It routes
each limit to a cut gate rather than treating it as settled (Synthesis:310-345).
The macro plan's WS4a boundary and Q1 support the scope. Nothing here
returns `NEEDS_TYPE_2`.

## 2. Corrections Verified

| Synthesis correction | Check | Result |
| --- | --- | --- |
| 1. Context-axis targets | `R/strategy-contracts.R:55-100` reorders to the context; `R/fold-engine.R:1063-1068` indexes it | holds |
| 2. P1 is the sole substrate reader; next bars go only to P3 | `inst/design/contracts.md:135-140`; `R/history-substrate.R:394-413` returns `next_bar` from P1; P3 reads it at `R/fold-engine.R:1094` | holds; seed v2's "P3 reads them through its own locator" was wrong |
| 3. No in-memory rollback in Phase | Phase 4.5 lists per-fill install, write, then cash, with no restore (Phase:197-206) | holds; the block boundary in 3.5 is a real tightening, not a restatement |
| 4. Unpriced provenance | `R/availability-economics.R:110-144` keeps `reference`, `age`, `source_ts` and `expired_close` / `missing` when the mark is `NA` | holds; seed v2's blanket `NA` was wrong |
| 5. Final pulse versus absent execution | `R/history-substrate.R:400-412`: a continued carry window executes at the next prepared session | holds |
| 6. No equity slot in the live census | `R/fold-phase-contract.R:1-21` lacks `equity_facts`, although Phase 5.1 lists it | holds; the synthesis adds it explicitly |

Also verified:

- The positions value is a run-order `sum` over active positions
  (`R/fold-engine.R:557-573`), so "preserve run-order valuation reductions"
  (3.2) is needed for byte identity.
- Both reconciliation calculations are `sum(vapply(...))` expressions
  (`R/fold-engine.R:1140-1144`, `:1463-1467`), as 3.3 says.
- Leg order is CLOSE then OPEN, and an opening leg has zero P&L
  (`R/output-handler.R:809-814`), as the table says.

## 3. Required Patches

### P1. The equity record must not switch dense finalization

Section 3.6 binds one fold-owned equity record per valued pulse that
"replaces both current accumulators". The dense producer reaches it, because
equity is recorded in shared P1 code (`R/fold-engine.R:574-591`): today the
memory sink's `record_equity_fact()` runs on both producers.

Finalization chooses its equity source by
`use_fold_equity <- isTRUE(run$availability_active) || length(fold_equity) > 0L`
(`R/run-finalize.R:449-453`). Today dense never fills `fold$equity_facts`:
the accumulator's capacity is zero (`R/fold-engine.R:1752-1754`). A record
populated on both producers would therefore silently move durable dense runs
from event replay (`R/run-finalize.R:526-530`) to fold equity. That is a
path change on the frozen dense producer, and its bytes are not guaranteed
equal.

**Patch:** state the producer scope.

- Both producers populate the record. It replaces the memory sink's
  growable vectors, so dense sweeps keep their inline summary.
- Finalization selects its source by producer, exactly as today:
  availability uses the fold record, dense uses event replay.
- Rewrite the predicate to key on the producer, not on record length.
- Add one Section 5 row: a durable dense run still finalizes through replay,
  and its equity is byte-identical.

### P2. Mark which groups each producer emits

Q1 freezes dense observation and context construction (Section 2). But the
Section 4 table lists the decision packet, decision data and execution packet
groups with no producer scope. A cut reader could take them as dense
obligations.

**Patch:** add one line under the table:

- Dense emits the `decision` group onward, plus `state`, `book`, `equity`,
  `diagnostics`, `publication` and `leg`.
- Dense does not emit the `decision packet`, `decision data`,
  `execution packet` or `execution view` groups.
- Dense P3 keeps reading next-bar values from `bars_mat` at `pulse_idx + 1`
  (`R/fold-engine.R:150-156`) until WS4b removes the dense path.

## 4. Recommended Patch

### P3. Detect a next-bar leak into P2

Today P2 receives the whole observation, including
`history_bars$next_bar` (`R/fold-engine.R:281-289`, `:1936-1942`), and
relies on discipline not to expose it. Section 3.2 now binds that P2 receives
no next bars. Section 5's "Representation" row has no structural detector for
this.

**Recommended:** add a structural detector. It asserts that P2's input carries
no execution-packet field, and a mutation that passes one must fail. This is a
no-lookahead property, cheap to check, and worth more than the cold read
alone.

## 5. Notes, No Patch Needed

- **Phase 4.5's title** reads "apply economic events atomically", while its
  body defines no rollback. Section 3.5 resolves this correctly. Acceptance
  could record that the synthesis narrows the word "atomically" to
  candidate-calculation failures.
- **Section 4's table** packs several columns per row with semicolons. It is
  complete but dense. The WS4a cut's contract text may unpack it for the cold
  read (macro rule 15) without changing any meaning.
- **Section 2's "one NEWS entry"** fits macro rule 6. The P1 predicate change
  is internal and needs no extra entry.

## 6. Acceptance

After P1 and P2 (and P3 if adopted), the synthesis is ready for maintainer
acceptance. Acceptance:

- corrects the macro plan's WS4b amendment for P4 (Q6);
- records the synthesis as binding pending WS4a scope, not shipped behavior;
- moves the RFC index row to "Obligations open" with the Section 8 routes.

Because the synthesis brief was drafted by Claude, acceptance also confirms
that the maintainer has reread the brief and the synthesis together.
