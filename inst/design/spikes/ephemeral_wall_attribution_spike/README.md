# Ephemeral Xlarge Wall Attribution Spike

**Status:** Spec drafted; pre-Codex review.
**Target window:** v0.1.9.
**Single-spike investigation, not a spike round.**

## What this is

ledgr's compiled-core direction (Architecture A via `ledgrcore`;
Architecture B2 via cpp11 hot frames) addresses approximately 15% of
xlarge ephemeral wall (the fold-loop slice: FIFO lots + position /
cash updates + event emission + per-pulse equity). The K1
measurement-spike verdict (2026-06-01, `ledgrcore-spike` repo)
confirmed compiled fold loops are fast on that slice; it did not
address the remaining ~85% of xlarge ephemeral wall.

This spike attributes that ~85%. It runs against ledgr's
post-v0.1.8.10 production R baseline on the LDG-2479
`density_high_xlarge_ephemeral` workload-grid cell and produces a
Pareto: which 3-5 sub-frames account for 80% of wall?

The output gates ledgr's v0.1.9 optimization direction. Three-branch
decision rule per the 2026-06-01 ephemeral attribution horizon entry:

- **Fold-loop slice < 15%**: pivot away from compiled cores entirely;
  attack the dominant non-fold-loop sub-frame instead.
- **Fold-loop slice 30-50%+**: Architecture B2 spike runs next; K1 +
  B2 + attribution combine into the A-vs-B2 decision.
- **Single non-fold-loop sub-frame dominates**: that ticket takes
  v0.1.9 precedence; A and B2 defer.

## Files

- `spec.md` — the binding spec for the attribution methodology and
  measurement protocol. Pre-Codex review.
- `attribution_synthesis.md` — the verdict-shaped output document,
  authored after measurement. NOT YET WRITTEN.

## Sequencing

- **Now**: spec drafting + Codex adversarial review (pre-measurement).
- **After Codex review**: spec patches landing per findings.
- **After v0.1.8.10 ships**: measurement runs (cannot run pre-v0.1.8.10
  because the substrate-decision shape changes the sub-frames being
  attributed).
- **After measurement**: synthesis authoring + ledgr horizon update.

## Authority

- 2026-06-01 [optimization] Ephemeral-mode xlarge wall attribution
  as gate for ledgrcore / Architecture B2 commit (horizon entry,
  scope-binding).
- 2026-06-01 [architecture] K1 measurement-spike verdict (horizon
  entry, establishes that K1 only addresses ~15% of wall).
- 2026-06-01 [architecture] Architecture B: in-place hot-frame
  compilation as alternative to ledgrcore (horizon entry, B2
  pathway).
- v0.1.8.10 architecture_synthesis.md Round 3 (the substrate-decision
  shape this attribution measures against).

## Why this is a single-spike investigation rather than a spike round

The v0.1.8.10 spike round had 11+ spikes because the round was
hunting across many candidate optimization lanes. This investigation
has one question (Pareto attribution of one workload-grid cell) and
one output (the attribution synthesis). A multi-spike round would
add coordination overhead without adding measurement value.

The investigation's parallel-method discipline (Method A targeted
instrumentation + Method B Rprof + cross-validation) provides the
adversarial rigor a multi-spike round would provide via diversity.

## Out of scope

See `spec.md` § Out of Scope. Summary: this spike attributes wall
share. It does not implement optimizations, run cross-platform, use
production strategy workloads beyond LDG-2479, or attribute the
durable path.
