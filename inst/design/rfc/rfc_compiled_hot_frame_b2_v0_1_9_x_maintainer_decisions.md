# RFC Maintainer Decisions: Compiled Hot Frame B2 (v0.1.9.x)

**Status:** Maintainer decision recorded. Binding input to synthesis.
**Cycle:** Architecture B2 measurement gate / v0.1.9.x promotion scoping.
**Relates to:** `rfc_compiled_hot_frame_b2_v0_1_9_x_seed_v2.md` and
`rfc_compiled_hot_frame_b2_v0_1_9_x_seed_v2_review.md`.
**Authored:** Maintainer decision recorded by Codex on 2026-06-02.

## Decision 1: B2-first sequencing override

The maintainer accepts the B2-first sequencing override requested in
seed v2.

Rationale:

- The Rust/C infrastructure already exists in the external
  `ledgrcore-spike` repo.
- The time required to build a detailed R fold-core attribution harness
  can instead be spent building the compiled core components that the
  project actually wants to measure.
- This is a more direct test of the proposed solution than first
  building a redundant R telemetry path that may be abandoned after the
  compiled-path decision.

This decision does **not** authorize promotion of compiled code into
ledgr. The compiled path must still earn its keep.

Promotion remains gated on:

- production-faithful parity;
- measured wall recovery;
- acceptable integration and toolchain cost;
- no regression of ledgr's existing event, fill, equity, lot-accounting,
  and strategy contracts.

If the compiled core components do not meet those gates, they are parked
and the ephemeral xlarge wall attribution spike becomes the next
diagnostic path.

## Synthesis consequence

Synthesis should treat the sequencing question as resolved:

- B2 measurement runs before the ephemeral attribution spike.
- The attribution spike remains fallback / follow-up if B2 fails or
  produces an ambiguous result.
- The decision-bearing B2 measurement must use the compiled path that is
  actually under consideration, not a handler-preserving approximation
  that leaves the hot work in R.

The remaining seed-v2 review findings still need synthesis or seed-v3
treatment:

- the first-cut recoverable-slice table must match the actual compiled
  scope;
- Pattern A is not K1-equivalent inline output and cannot be the only
  promotion gate;
- the production Sub-B swap mechanism must be decision-bearing rather
  than a prototype-only instrumented copy.

## Decision 2: B2 spot-FIFO public opt-in promotion in v0.1.8.10

The maintainer authorizes B2 spot-FIFO to ship as a public opt-in in
v0.1.8.10, narrowing synthesis D10's "no public compiled-mode flag
ships in this RFC" for the scoped spot-FIFO case.

Rationale:

- Sub-A measurement completed (`ledgrcore-spike` Stage 5 plus Stage 6
  verdict): C++ cpp11 selected, three-way parity smoke on Windows and
  Ubuntu 24.04 WSL, build-flag caveat documented (effective `-O2 -flto`
  on Windows Rtools rather than declared `-O3 -flto`).
- Sub-B production gate passed in Batch 5 / LDG-2522: the
  `density_high_xlarge_ephemeral` workload-grid cell measured 65.86s
  wall under `compiled_accounting_model = "spot_fifo"` versus 327.02s
  canonical R on the same seed and 66,280-fill count, a 79.9% wall
  reduction with zero failures and identical event/equity/fill outputs.
  The later release-closeout rerun on seed `20260531` measured 67.32s
  versus 375.14s canonical R on the same 66,419-fill count, an 82.1%
  wall reduction.
- Peer benchmark validation in Batch 7 / LDG-2524: on the v0.1.8.9
  closeout peer SMA fixture (500 instruments, 1260 daily bars, SMA 5/10),
  B2 measured 37.09s core wall and 15.77s engine versus Backtrader 79.36s
  core wall and 78.54s engine. Wall ratio 0.47x; engine ratio 0.20x.
  Equity correlation against canonical ledgr ephemeral 1.0; max absolute
  diffs on equity, cash, and position proxy all 0.
- All four promotion gates from Decision 1 are closed for the scoped
  case:
  - production-faithful parity: byte-identical to canonical ledgr
    ephemeral on the peer fixture;
  - measured wall recovery: 79.9-82.1% on the internal xlarge cells and
    53% on the peer fixture, both well above the 30s pass threshold the
    B2 RFC bound;
  - acceptable integration cost: cpp11 LinkingTo plus a single
    eighteen-argument registered function, no runtime dependency on an
    external system;
  - no regression of existing contracts: event-stream identity, fill
    table, equity reconstruction, lot-state, and the no-strategy-lookahead
    invariant all preserved per the LDG-2522 parity test suite.

Scope of the override:

- Public opt-in only. Default execution remains canonical R
  (`compiled_accounting_model = NULL`).
- Spot-FIFO scope guard intact. The closed enum stays
  `NULL | "spot_fifo"`. Unsupported values still fail closed with named
  error `ledgr_unsupported_accounting_model`.
- Ephemeral only. Durable compiled integration remains deferred to a
  separate gate, per the original D10 framing.
- Single accounting model. Derivatives, margin, options, and any other
  non-spot accounting model remain deferred to separate RFC scope and
  parity gates, per the 2026-06-02 horizon spot-FIFO scope-guard entry.

This decision does **not** authorize:

- Default promotion of the compiled path. The compiled path becoming the
  default execution mode for `ledgr_run` and `ledgr_sweep` requires a
  separate decision after field testing of the public opt-in.
- CRAN submission. v0.1.8.10 is not a CRAN release; CRAN-readiness
  remains a v0.1.9.x cycle item.
- Non-spot accounting models. The `compiled_accounting_model` enum
  remains closed; any future value must come with its own RFC scope
  and parity gates.
- Durable compiled integration. Sealed event log and ledger persistence
  remain R-side; D10's durable deferral stands.

Subsequent gates for future default promotion:

- Public opt-in user feedback in the field beyond the peer benchmark
  fixture;
- macOS parity verified on Apple hardware (Stage 6 verdict left this
  obligation to Sub-B; if not closed in LDG-2526 it routes to a
  v0.1.9.x verification follow-up);
- CRAN-ready package builds, including source tarball plus binary
  builds for Windows and macOS;
- Comprehensive parity expansion: multi-instrument, semantic-violation
  fixtures, durable readback round-trip;
- Failure UX validated in real install scenarios (missing toolchain,
  R version mismatch, platform without a usable C++ compiler).

Synthesis consequence:

- Synthesis D10's "No public compiled-mode flag ships in this RFC" is
  narrowed, not retracted. B2 spot-FIFO public opt-in is authorized
  for v0.1.8.10; broader-scope public compiled execution (default
  promotion, non-spot accounting models, durable compiled integration)
  remains deferred per the original D10 framing and per Decision 1's
  promotion gates.
- The spec packet patch routing B2 to a future v0.1.9.x ticket
  (currently in review) is revised: the routing target shifts from
  "promotion deferred to v0.1.9.x ticket" to "public opt-in ships in
  v0.1.8.10; default promotion deferred to a future cycle after
  broader-platform testing."
- LDG-2526 is added to the v0.1.8.10 spec packet between LDG-2524
  (measurement closeout) and LDG-2525 (release gate) to implement the
  public-opt-in surface.
- The v0.1.8.10 release closeout language is allowed to describe the
  scoped spot-FIFO accelerator as a public opt-in option. Closeout
  language must still avoid "compiled fold core" framing per the
  2026-06-02 horizon scope-guard entry; must still describe ledgr's
  default execution as canonical R; and must not imply default
  promotion or CRAN readiness.

**Authored:** Maintainer decision recorded on 2026-06-02.
