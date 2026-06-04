# Architecture Decision Records

**Status:** Wound down as a recurring artifact (2026-06-04). The existing
records remain as historical entries until their rationale migrates into the
appropriate maintainer manual article.

**Authority:** ADRs in this directory are historical. New binding constraints
land in `../contracts.md` (the WHAT) and accepted RFC syntheses (the decision
history). New rationale lives in maintainer manual articles under
`../manual/` (the WHY). Forward direction and scope guards live as horizon
entries in `../horizon.md`.

## Why this pattern is wound down

ADRs are an enterprise-software pattern from large teams where institutional
memory leaks across staff turnover, new contributors need rationale for
decisions made before their time, and constraints get accidentally overturned
because rationale is lost. None of those conditions apply here:

- Single maintainer; institutional memory is the maintainer's.
- No team onboarding to serve.
- Pre-release with zero strategy/API consumers; contracts can be broken
  freely when the project posture says so.
- The RFC cycle (seed → response → synthesis → final review) already produces
  the legislative history that ADRs would carry.
- `contracts.md` already does the current-law work.

A 2026-06-04 structural review found that ADR-0005 (B2 spot-FIFO scope guard)
was shape-wise a horizon scope-guard entry mis-shelved as an ADR — it had no
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

ADRs 0001 through 0004 have genuine ADR shape (forces in tension, explicit
decision in imperative voice, consequences with named tradeoffs) and are kept
as historical records. Their rationale will migrate into manual articles as
those articles are authored:

- ADR-0001 split DB semantics → snapshots/data manual article.
- ADR-0002 registry fingerprint policy → observability/determinism manual
  article.
- ADR-0003 closure fingerprinting → observability/determinism manual article.
- ADR-0004 dependency footprint and function-only strategy interface →
  `execution_fold_core` (function-only strategy contract) and
  `performance_arc_v0_1_8_x` (dependency posture, collapse adoption) manual
  articles.

When each manual article lands carrying the migrated rationale, the
corresponding ADR is deleted.

## When to author a new ADR

The bar is three conditions, all required:

1. **Forces in tension** that produced a real choice (not just "we shipped
   X"). Context should name the alternatives that were considered.
2. **Alternatives considered**, with explicit rationale for rejection. A
   Decision section in imperative voice ("ledgr does X over Y because Z").
3. **Consequences with named tradeoffs**. What it costs as well as what it
   gains.

If a constraint does not meet all three, it goes in a horizon entry or in
`contracts.md`, not a new ADR. "We shipped a scoped X" is horizon-shaped.
"We deliberately chose X over Y after considering Z" is ADR-shaped — and
even then, only when defending the choice against a future PR will plausibly
require the rationale narrative.

The default expectation is that the next new ADR is unlikely. The cycles are
expected to deposit decisions into `contracts.md` + manual articles +
horizon entries + RFC syntheses, not new ADRs.

## Existing records

| File | Topic | Status | Migration target |
| --- | --- | --- | --- |
| `0001-split-db-semantics.md` | Snapshot/run database split | Historical | snapshots/data manual article |
| `0002-registry-fingerprint-policy.md` | Registry fingerprint policy | Historical | observability/determinism manual article |
| `0003-closure-fingerprinting.md` | Functional strategy closure fingerprinting | Historical | observability/determinism manual article |
| `0004-dependency-footprint-and-strategy-interface.md` | Lean deps and function-only strategy interface | Historical | `execution_fold_core` + `performance_arc_v0_1_8_x` manual articles |
| `0005-b2-spot-fifo-scope-guard.md` | B2 spot-FIFO scope guard | Deprecated 2026-06-04; file removed | n/a — content was horizon-shaped; bound by horizon entry + maintainer-decisions + contracts |

## Related references

- `../contracts.md` — current binding contracts.
- `../horizon.md` — forward direction and scope guards.
- `../manual/` — maintainer manual articles (the WHY).
- `../rfc/README.md` — RFC decision index (topic → binding artifact).
- `../rfc_cycle.md` — RFC cycle process reference.
