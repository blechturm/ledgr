# RFC Seed v2: A Lean Fold Core For v0.2.3, Bounded

- Status: Seed v2; synthesis by a different author is next
- Author: Claude
- Date: 2026-11-03
- Target window: v0.2.3 (maintainer, 2026-11-03)
- Inputs: seed v1, the Codex Type 2 response (REVISE), the response review,
  `dev/spikes/r_floor/` stages 1 to 3, `dev/spikes/lean_fifo/`, and the
  maintainer's FIFO and dependency decisions (macro plan WS14, "FIFO kernel
  and dependencies")

Changes from v1: the bounded probe the response asked for has run; ratios
are matched stage costs, not bounds; option A stays the per-family
fallback; the switch gate is full public parity with interaction and
failure families; the carrier's ownership rules bind the lean core; the
FIFO kernel and dependency questions are decided; memory is an explicit
open requirement; the maintainer sets a cap.

## 1. Question

How should v0.2.3 replace the current fold with a lean core whose results
are bit-identical, without a second engine in the package, an unbounded
rewrite or a moving oracle?

"Core" is the per-pulse fold (E, P1 to P5), its run preparation and its
publication. Snapshots, features, registration, the strategy API, result
readers and orchestration stay, except where the WS7/WS8/WS15 cut changes
them. No public semantics change.

## 2. Accepted Inputs That Bind This Cycle

- One engine (AGENTS.md); canonical R is the oracle; a compiled path needs
  its own Type 2 decision (macro plan WS14).
- Typed-fold-carrier synthesis Sections 3.1 to 3.6: exclusive buffers,
  P1-only substrate access, no execution packet in P2, lot-derived
  positions, ordered accounting and publication, frozen public views.
- Per-pulse durable records synthesis (WS15): exact logical trace, physical
  compression by exact rebuild, irreducible sizing evidence.
- Strategy-authoring synthesis D2: position facts (`entry_price` and its
  siblings) follow the canonical FIFO book, maintained at the accounting
  boundary.
- Maintainer, 2026-11-03: a lean R FIFO kernel with a typed book inside the
  fold; no new dependency; a compiled FIFO, if ever needed, is C++ through
  cpp11 and retires `spot_fifo.cpp`.

## 3. Evidence

Spike clocks on one host, matched stage against stage; not bounds and not
claims.

| | lean | ledgr | parity |
| --- | ---: | ---: | --- |
| floor plus priced guarantees, fixed basket, per pulse | 26 to 103 us | 2.8 to 8.3 ms | fills, equity, cash, full diagnostics |
| P2 strategy context, changing axis | 14 to 50 us | 664 to 1,479 us (decide) | everything the strategy reads, and its targets |
| P1 and P3 to P5 with ledgr's own lot kernel | 268 to 472 us | 3.0 to 6.0 ms | every fills and equity column, partial FIFO |
| lot kernel per fill block | 92 to 190 us (lean R) | 223 to 417 us | book and all applied rows, random edge streams |

The fixed-basket floor omits FIFO accounting; stage 3 reuses ledgr's
kernel, so its figures carry today's kernel cost. Parity found eleven ledgr
rules first wrong in the seams (`dev/spikes/r_floor/README.md`). Not
probed: restrictions and terminals, schedules, corporate actions, sizing
helpers, costs, risk, RNG, openings and dispositions in the lean kernel,
sweeps and walk-forward, memory-bounded preparation.

## 4. Proposed Decision

**Bounded B.** A lean core grows under `dev/lean_core/` against the current
core as the oracle and replaces it in one atomic switch cut. It grows family
by family in reviewed workstreams; a family that cannot reach parity after
two correction rounds goes to the maintainer, who may assign it option A
(stage-by-stage replacement in the current fold) instead.

The reason for B is not that stage structure causes today's cost; that was
not shown. It is that a core built from prepared planes and fresh views can
be measured and proven family by family against an oracle, without
temporary adapters in the production fold.

## 5. Design Constraints

- **Location and isolation.** `dev/lean_core/` is excluded from the package
  (`.Rbuildignore`). Nothing in `R/` imports, calls, dispatches to or falls
  back to it before the switch: no option, hook or worker path.
- **Services reused, not rebuilt.** Snapshot reads, feature computation,
  registration, the strategy preflight, the WS15 codec and the accounting
  services are called as they are; the lean core does not grow a second
  preparation or publication architecture.
- **Carrier rules.** The lean core keeps one common substrate and its
  ownership: P2 never sees the next bar; views a strategy can retain are
  fresh; mutable buffers have one owner; positions come from lots. Removing
  repeated validation requires a named trusted producer boundary, and
  callback outputs are still checked every pulse. No fixed-basket
  execution-mode fork.
- **FIFO.** The lean R kernel from the spike, extended to openings and
  dispositions and proven bit-identical on the kernel's registered tests and
  random streams. The lot book stays typed inside the fold.
- **Memory.** Prepared planes are built per time window with state carried
  across windows, so peak memory is bounded by the window, not the run. The
  first growth step proves this on a Sharadar-scale shape.
- **Position facts.** Maintained as today, through the kernel, every fill.
  Lazy lots (bringing an instrument's lots up to date only when a reader
  needs them) is an open option, not part of the plan (Q4).

## 6. The Switch Gate

The switch cut requires, against a pinned clean reference build of the
current core:

- **Full public parity**, exact, with no sorting, rounding or column
  stripping beyond explicitly variable clock metadata: ordered ledger
  events; fees, lots, realized and unrealized P&L; every logical diagnostic
  column and sequence position; point and history explanations; summaries;
  completion and stop evidence; seeds and identity; persistence and reopen;
  sweep selection and promotion.
- **Proof families** (response F6): reordered, changing and empty axes with
  held former members; restrictions with permitted exits; stale, frozen and
  terminal valuation and corporate-action barriers; sells funding buys;
  chained costs, rounding and dust, repeated carried openings, FIFO and
  compensated realized P&L; continued final decisions; scheduled skips with
  settlement; seeded and unseeded callbacks, caller RNG restoration and
  worker-count equivalence; late-known facts and pre-scoring history; stops
  at P1, P2 and P3, first-pulse stops, strategy errors, append and flush
  failures and post-fold publication recovery; WS15's seven families; the
  repaired A0 fixtures; the private Sharadar reference.
- **Witnesses while both cores exist:** retained-view aliasing, no-lookahead
  under future perturbation, conservation, and recorded mutations.
- **Resources:** parent and worker peak memory measured before the switch.
- **Tests:** every registered test passes with the suite frozen for the
  cut; internal structural tests that only detect old helper shapes may be
  remapped mechanically with a stated reason, never their oracles.

## 7. Plan Changes (explicit macro amendment at acceptance)

- WS7/WS8/WS15 land first; lean-core evidence before that interface is
  provisional until rebased.
- The lean core grows in reviewed workstreams under `dev/lean_core/`,
  starting with the memory-bounded preparation and the lean kernel's
  openings and dispositions, then the unprobed families in Section 3.
- WS14a keeps both independent holistic reviews, now of the integrated
  path including the lean core before the switch. Its product subtraction
  cut becomes the switch cut, run with the test suite frozen; the
  contract-based test rebuild follows it.
- WS9b measures memory and worker boundaries on the lean core before the
  switch. Execution-sensitive WS10 cuts wait for the switch or rebase the
  lean core after each accepted change.
- AGENTS.md gains, while the work is open: "A lean fold core may be
  developed under `dev/lean_core/` as a parity harness against the current
  core (lean-fold-core synthesis). Nothing in `R/` calls it; the switch cut
  that moves it into `R/` deletes the current fold in the same cut." The
  switch cut removes the note.

## 8. Objectives And Cap

The WS14 objectives become aspirations, measured with the shared timing
harness and per-function sample counts: a fixed-basket quiet pulse near
50 us on narrow books and 150 us at 500 instruments; per-run work outside
the loop near 100 ms; an ephemeral lane within about 1.5 times PMwR on
narrow books and at parity on wide ones.

The release slips by an amount nobody can estimate yet. The maintainer sets
a cap in effort or calendar time at acceptance. After the first growth step
the effort is re-estimated against the cap; reaching the cap returns the
plan to the maintainer, who chooses between finishing, switching the
remaining families to option A, or shipping v0.2.3 on the current core.

## 9. Not In Scope

Compiled stages and new dependencies; new public semantics; reviving the
dense path; changing WS15 or the carrier synthesis; performance claims.

## 10. Open Questions For Synthesis

- **Q1.** Is the family order in Section 7 right, and which family should
  the first workstream take after memory and the kernel?
- **Q2.** What is the pinned reference build: the WS7/WS8/WS15 close, or a
  later accepted commit?
- **Q3.** Which internal structural tests may be remapped at the switch, and
  who approves each remap?
- **Q4.** Should lazy lots be probed before the switch, given position
  facts, lot-derived positions with dust rules, and corporate actions on
  lots?
- **Q5.** What form does the maintainer's cap take, and where is it
  recorded?
