# Architecture Decision Records

**Status:** Wound down as a recurring artifact (2026-06-04). ADR-0001 through
ADR-0003 have been migrated into maintainer manual articles and deleted.
ADR-0004 remains temporarily until LDG-2544 splits its residual rationale into
the manual.

**Authority:** ADRs in this directory are historical. New binding constraints
land in `../contracts.md` (the WHAT) and accepted RFC syntheses (the decision
history). New rationale lives in maintainer manual articles under
`../manual/` (the WHY). Forward direction and scope guards live as horizon
entries in `../horizon.md`.

## Why This Pattern Is Wound Down

ADRs are an enterprise-software pattern from large teams where institutional
memory leaks across staff turnover, new contributors need rationale for
decisions made before their time, and constraints get accidentally overturned
because rationale is lost. None of those conditions apply here:

- Single maintainer; institutional memory is the maintainer's.
- No team onboarding to serve.
- Pre-release with zero strategy/API consumers; contracts can be broken freely
  when the project posture says so.
- The RFC cycle already produces the legislative history that ADRs would carry.
- `contracts.md` already does the current-law work.

A 2026-06-04 structural review found that ADR-0005 (B2 spot-FIFO scope guard)
was shape-wise a horizon scope-guard entry mis-shelved as an ADR: it had no
"Decision" section in imperative voice, no alternatives, no consequences with
named tradeoffs, just a reportorial constraint summary pointing at upstream
binding artifacts. That is the horizon-entry shape, not the ADR shape.

ADR-0005 was deprecated on 2026-06-04. The constraint it carried is bound by:

- the horizon entry `2026-06-02 [architecture] B2 spot-FIFO accelerator is
  not a derivatives accounting model`;
- the maintainer-decisions narrowing
  `../rfc/rfc_compiled_hot_frame_b2_v0_1_9_x_maintainer_decisions.md`
  (Decision 2);
- `../contracts.md` (the closed `compiled_accounting_model` enum).

ADRs 0001 through 0004 had genuine ADR shape (forces in tension, explicit
decision in imperative voice, consequences with named tradeoffs). ADR-0001
through ADR-0003 have now been migrated and deleted:

- ADR-0001 split DB semantics -> `../manual/snapshots_data.qmd`.
- ADR-0002 registry fingerprint policy -> `../manual/observability_determinism.qmd`.
- ADR-0003 closure fingerprinting -> `../manual/observability_determinism.qmd`.
- ADR-0004 dependency footprint and function-only strategy interface remains
  temporarily pending LDG-2544, then splits into `execution_fold_core`
  (function-only strategy contract) and `performance_arc_v0_1_8_x`
  (dependency posture, collapse adoption).

## When To Author A New ADR

The bar is three conditions, all required:

1. **Forces in tension** that produced a real choice (not just "we shipped
   X"). Context should name the alternatives that were considered.
2. **Alternatives considered**, with explicit rationale for rejection. A
   Decision section in imperative voice ("ledgr does X over Y because Z").
3. **Consequences with named tradeoffs**. What it costs as well as what it
   gains.

If a constraint does not meet all three, it goes in a horizon entry or in
`contracts.md`, not a new ADR. "We shipped a scoped X" is horizon-shaped.
"We deliberately chose X over Y after considering Z" is ADR-shaped, and even
then only when defending the choice against a future PR will plausibly require
the rationale narrative.

The default expectation is that the next new ADR is unlikely. The cycles are
expected to deposit decisions into `contracts.md` + manual articles + horizon
entries + RFC syntheses, not new ADRs.

## Existing Records

| File | Topic | Status | Migration target |
| --- | --- | --- | --- |
| `0001-split-db-semantics.md` | Snapshot/run database split | Migrated and deleted in LDG-2541 | `../manual/snapshots_data.qmd` |
| `0002-registry-fingerprint-policy.md` | Registry fingerprint policy | Migrated and deleted in LDG-2540 | `../manual/observability_determinism.qmd` |
| `0003-closure-fingerprinting.md` | Functional strategy closure fingerprinting | Migrated and deleted in LDG-2540 | `../manual/observability_determinism.qmd` |
| `0004-dependency-footprint-and-strategy-interface.md` | Lean deps and function-only strategy interface | Historical; pending LDG-2544 migration | `execution_fold_core` + `performance_arc_v0_1_8_x` manual articles |
| `0005-b2-spot-fifo-scope-guard.md` | B2 spot-FIFO scope guard | Deprecated 2026-06-04; file removed | n/a; content was horizon-shaped and is bound by horizon entry + maintainer-decisions + contracts |

## Related References

- `../contracts.md` - current binding contracts.
- `../horizon.md` - forward direction and scope guards.
- `../manual/` - maintainer manual articles (the WHY).
- `../rfc/README.md` - RFC decision index.
- `../rfc_cycle.md` - RFC cycle process reference.
