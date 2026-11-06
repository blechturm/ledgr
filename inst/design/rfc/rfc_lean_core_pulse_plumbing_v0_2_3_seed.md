# Proposed Amendment: Lean Core Pulse Plumbing (v0.2.3), Seed v1

- Status: **proposed amendment** to the accepted lean core skeleton
  synthesis, seed v1 ([pipeline](README.md#lean-core-pulse-plumbing)). Not
  binding. It goes through the review steps an amendment needs (a Type 2
  response, a synthesis and a final review). On acceptance its Section 4 text
  is appended to the skeleton synthesis as a dated amendment, as the
  observable-data amendment was.
- Authors: maintainer with Claude, 2026-11-06.
- Parent: the accepted [lean core skeleton synthesis](rfc_lean_core_skeleton_v0_2_3_synthesis.md),
  which this seed proposes to amend. The rules it touches come from the
  [Typed Fold Carrier contract](../contracts.md#contract-execution-fold-carrier)
  (**C**) and the accepted
  [typed accounting synthesis](rfc_typed_accounting_event_boundary_v0_2_3_synthesis.md)
  Section 3.4.
- Evidence: the fold plumbing spike, `dev/spikes/fold_plumbing/` (commit
  `d8aeb04c`), on the pinned reference `d5b3a151`.
- Scope: the lean core only. The old fold core stays the frozen oracle and
  is not changed.

## 1. The Question

The spike ran the fold with stages that do no work. Each stub passed on its
real stage's outputs and wrote that pulse's events, diagnostics and equity
row through the real code. Both workloads of the interface table were used.
Every output matched the real run exactly. The plumbing alone cost:

| microseconds per pulse | momentum 40 x 504 | fill-heavy 500 x 1,260 |
| --- | ---: | ---: |
| real ledgr loop | 1,925 | 6,087 |
| plumbing, as today | 1,190 | 1,976 |
| saved by dropping per-pulse carrier and append checks | 476 | 825 |
| saved by dropping diagnostic staging | 714 | 445 |
| fill publication as today / written into reserved rows | 60 / 20 | 929 / 119 |
| handing outputs between stages, `services` reads | under 40 | under 40 |

Handing data between stages is nearly free, and building stage outputs
fresh costs less than overwriting preallocated ones. The cost is fixed R
work on every pulse: about 9 carrier checks, about 275 us per diagnostic
staging call, and a fill block that is built, checked, held and copied.

> Where should the lean core check and write its per-pulse data, so that it
> keeps every guarantee without paying for the same guarantee on every
> pulse?

## 2. What The Accepted Records Already Say

- The skeleton synthesis says validation "belongs at the boundary that
  establishes or changes a guarantee. Trusted consumers do not repeat it"
  (Section 2). It leaves "validation placement" open for the first
  checkpoint (Section 7).
- The lean fold core synthesis says "trusted inputs may avoid duplicate
  checks, but mutable/new inputs are checked at their introducing boundary"
  (Section 2). Its amendment A4 asks every family close to remove
  "validation repeated after a trusted boundary".
- The skeleton synthesis binds the publication order: P4 installs the book,
  publishes and advances the sequence, and P5 flushes the pulse's events
  (Section 4).
- The typed accounting synthesis binds one append validator at two
  boundaries, append and read (Section 3.4). Its rejected list rules out
  validation at only one of them.

These records do not decide two things the spike exposes:
- **C says "each group is validated once where it is constructed".** In
  today's fold, every stage output is constructed anew on every pulse, so
  every group is checked on every pulse.
- **C says P4 "publishes the event block".** Today that block is a separate
  object that is checked, held by the handler and copied into the event
  buffer at P5.

## 3. Proposal

### 3.1 Checks: by construction inside the core, at runtime at the edges

A group that core code builds from inputs that are already checked does
not run its structural check on every pulse. Checked inputs are the
prepared data checked once in E, or an earlier stage's output in the same
pulse. The structural check covers the field set, storage types, axis
lengths and invariants that hold by how the group is built: for example
`priced == is.finite(mark)`, or offsets made by
`ledgr_carrier_segments()`. Those properties come from the code that builds
the group.

Runtime checks stay where a value can actually be wrong:
- every boundary that takes untrusted values, unchanged: the strategy
  return, post-risk quantities, imports, deserialized state, user callbacks
  and public requests;
- every check that depends on the data, unchanged, with the same condition
  class and precedence: overflow, lot invariants, prices, fees and
  quantities in range, affordability, staging capacity;
- E's checks of prepared inputs and the fold state, once per fold;
- the append validator at both boundaries (typed accounting Section 3.4),
  unchanged.

The full structural check of every group stays available for one internal
mode, a debug switch. The stage recorder, the parity harness and the test
suite run with it on. It is not a public option.

The interface table's validator column
(`ledgr_v0_2_3_spec_packet/lean_core_interface.md`) records, field by
field, which check is by construction and which runs at runtime. The
reviewer of each family close checks that column against the code.

### 3.2 Fills: written once into reserved rows

P4 asks the output handler to reserve the batch's rows and writes the
events into them by index. The append validator runs once over those rows.
The handler still owns the buffer. P5's flush commits the row count instead
of copying a held block. The order stays the same: book installed, events
published, sequence advanced, legs recorded, positions and cash installed.
The failure prefix and condition precedence stay the same too. An append
failure leaves reserved but uncommitted rows, which no reader sees. There
is no separate publication object; whatever that group checks today and the
append validator does not must move into the append validator (Q3).

### 3.3 Diagnostics: direct typed writes

Stages write their diagnostic rows straight into the typed staging columns
by index, in emission order. The logical sequence, the codec, the capacity
rule, the keep rules and the drain at P5 or at a stop do not change. Only
the three column-by-column passes per staging call go away. This changes no
contract text and is listed so that the cut owns it.

### 3.4 Stage outputs stay fresh

Stage outputs are built fresh each pulse, as today. The spike measured
overwriting preallocated outputs as slower in R: 258 against 198 us per
pulse on momentum and 333 against 286 on fill-heavy. The stage recorder
copies at each stage boundary only if a later family chooses in-place
buffers; held references to in-place buffers recorded the wrong values on
500 of 504 and 1,259 of 1,260 pulses.

## 4. Proposed Amendment Text

For the skeleton synthesis, Section 2, after "Trusted consumers do not repeat
it":

> In the lean core, a carrier group built by core code from checked inputs
> (E's prepared data or an earlier stage's output in the same pulse) is
> correct by construction and is not structurally re-checked per pulse.
> Boundaries that take untrusted values and checks that depend on the data
> keep their runtime checks, classes and precedence. An internal debug
> switch runs every group's full structural check; the stage recorder, the
> parity harness and the test suite run with it on. The interface table's
> validator column assigns each field to construction or runtime.

For the skeleton synthesis, Section 4, after "P5 flushes pulse events":

> In the lean core, P4 writes its fill events into rows the handler
> reserves and the append validator checks them there; P5 commits the
> count. No held copy of the block exists. Order, failure prefixes and
> handler ownership are unchanged.

For C, at the switch cut: replace "Each group is validated once where it is
constructed" with the construction/runtime rule above, and "publishes the
event block" with "writes and validates the event rows in place".

## 5. What Could Go Wrong

- A construction bug in a stage no longer fails the production run at
  once. It is caught by the parity harness, the recorder and the tests,
  which all run with checks on. The ledger stream stays guarded at append
  and at read.
- A field might belong in the runtime column but be marked "by
  construction". The family-close review owns that column.
- Reserved rows that are never committed must stay invisible on every
  failure path, including memory sweeps.

## 6. Questions For The Response

1. Is "correct by construction plus a debug switch" an acceptable guarantee
   for internal groups, or must a production run keep a cheaper sampled or
   end-of-fold structural check?
2. Which of today's per-pulse checks depend on data and must stay? A first
   list: affordability, lot invariants, positive prices and quantities,
   non-negative fees, staging capacity, the scheduled-skip plan.
3. Does the append validator cover everything the publication group check
   covers (status, event ID format, contiguous sequence, `next_event_seq`)?
   Anything it misses must move into it, or stay as a runtime check.
4. Is the reserve-and-commit write consistent with durable `live` mode,
   where the sink writes each block inside a transaction?
5. Should the spike's measured savings set the family budgets, or are they
   only evidence?
