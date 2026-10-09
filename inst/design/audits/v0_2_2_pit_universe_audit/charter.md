# Point-in-time universe audit: charter

**Status:** Accepted by the maintainer on 2026-10-09. No stage has started.
The external yardstick brief is `yardstick_brief.md`; its result is stored,
unedited, as `yardstick.md` and frozen before any audit finding is shared.
**Authority:** None over behavior. `inst/design/contracts.md` stays the only
source of current behavior; this audit produces evidence and routed findings.
**Kind:** An audit with its own scope and budgets, not a spike. Bounded spikes
open only for questions the audit cannot answer with existing behavior or a
small probe (`inst/design/spike_protocol.md`).

## Resume here

1. Done 2026-10-09: charter accepted; yardstick brief written
   (`yardstick_brief.md`).
2. While Cut 11 Workstream 22 runs: the maintainer runs the brief in ChatGPT
   Deep Research and the result is committed unedited as `yardstick.md`; build
   the shared semantic fixture and the inventory and path-matrix schema under
   `dev/audit/pit_universe/`.
3. After Workstream 22 closes: freeze one commit and run Stages 1 to 3 against
   it, with a maintainer gate after each stage.
4. The WS3/WS4 history wave resumes only after Gate 3.

## Goals (maintainer, 2026-10-09)

1. Understand how ledgr handles point-in-time universes today, in code, in
   every relevant subsystem.
2. Decide whether that as-is behavior is internally consistent and logically
   sound.
3. Compare the as-is behavior with the design documents and with external
   standards, to judge whether what was designed and built is valid, or
   lacking.

## Scope

**Audit rule:** an externally observable semantic choice whose result can
differ because a point-in-time provider is active, or that a point-in-time run
relies on. This covers eligibility, clocks, missingness, marks, settlements,
stops, identity and recovery, and the snapshot guarantees runtime rules depend
on. Generic mechanics are out unless availability changes or depends on them.

**Owner** (one per rule): `adapter` (data preparation: vendor semantics,
identity, membership construction), `ledgr` (sealed facts, causal execution,
eligibility, valuation, accounting, recovery), `research` (experiment or
strategy policy), or `unclear` (ownership is itself a finding). ledgr is judged
only on guarantees it owns; upstream universe construction is not a missing
ledgr feature.

**Subsystems:** (1) fact model and ingest, (2) adapter boundary, (3) provider
and resolver, (4) calendar, windows and sealed range, (5) strategy context,
(6) features, (7) targets and sizing, (8) execution, (9) valuation, (10)
terminal outcomes and corporate actions, (11) persistence, completion, resume
and reconstruction, (12) results and readers, (13) sweep, walk-forward and
promote, (14) identity.

**Out of scope:** hash computation and verification policy (WS5 verification
session), performance and memory (Workstream 22, history-wave Session E),
adapter internals in ledgr-research beyond the assumptions ledgr makes.

## Stages

### Stage 1: as-is inventory and map (description only)

Question: what does ledgr do today with a point-in-time universe? Agents read
the code at the frozen commit; non-obvious behavior is confirmed by a probe.
No judgments; oddities are flagged, not resolved.

Outputs:
- `inventory.csv`: one row per audit rule (schema below).
- `path_matrix.csv`: every public point-in-time entry point and path, which
  rules apply, and every intended difference.
- `map.md`: a plain-language walk of a point-in-time run through the
  subsystems, linking to inventory rows and contract headings. It stays in
  this directory; promotion to `inst/design/manual/` only after review.

Gate 1 (maintainer): comprehension (the map explains how it works) and
completeness (every public PIT entry point and applicable path appears).

### Stage 2: internal consistency (ledgr against itself)

Checks: (a) the same rule across run, sweep, walk-forward, promote,
reconstruct and readers; (b) clock order and no lookahead (knowledge before
decision before execution before valuation); (c) ingest guarantees against
runtime assumptions; (d) dense versus point-in-time differences are intended,
stated and enforced; (e) stop, skip, refuse and warn choices are principled;
(f) identity and provenance against the contracts; (g) contract text, code and
tests agree.

Each finding is classified: code defect, wrong contract, untested behavior, or
unprincipled inconsistency (design question). Behavioral findings need an
executable probe; wording errors and stale links need only exact citations. A
separate challenger tries to refute every material finding. Every surviving
finding is checked against the ledgr-research feedback register before a new
ID is allocated.

Gate 2 (maintainer): triage. Defects and contract fixes become tickets;
design questions feed Stage 3.

### Stage 3: design validity (against intent and external standards)

Questions: (a) does as-is behavior match the accepted design (availability
and terminal-outcomes syntheses, v11 historical-projection synthesis,
`rfc/rfc_history_wave_v0_2_2_decisions.md`, `decisions.md`), and is each
divergence planned or drift? (b) is the model sound and complete against an
external yardstick of causal point-in-time backtesting?

The yardstick comes from a maintainer-run ChatGPT Deep Research brief, built
before and independently of the audit results: primary sources; causal
point-in-time backtesting for daily equities first; universal correctness
guarantees separated from optional capabilities; adapter responsibilities
separated from engine responsibilities; correctness gaps separated from
capability gaps; it builds on, and does not repeat, ledgr-research
`docs/governance/research/Universe-Construction-Boundaries.md` (an ownership
study, not a correctness yardstick). A clean-context Type 2 reviewer who did
not write the yardstick applies the frozen yardstick to ledgr.

Output: `gap_analysis.md` (defects, design debt, planned capabilities, true
external gaps). Gate 3 (maintainer): which gaps to address, in what order, and
whether the history wave's scope changes.

## Shared semantic fixture

One small vendor-neutral fixture, the audit's spine, covering at least:
membership addition and removal; effective time differing from knowledge
time; a held non-member; missing bars while unheld and while held; a halt and
resumption; a lifetime termination; one corporate action; an interruption and
recovery. Applicable cases run through run, sweep and promote; through
walk-forward; and through run, reconstruct and the results and explain
readers. Every path difference is explicit in the path matrix. Further probes
stay question-specific.

## Inventory schema

`rule_id, subsystem, owner, statement, applies_to_paths, code_location,
detecting_tests, contract_heading, design_source, evidence (read|probed),
probe, oddity, notes`. Code locations cite the frozen commit.

## Roles

Stage 1: three scoped implementation readers plus one cross-path integrator
(owns the fixture, path matrix, terminology and completeness). Stage 2: one
consistency analyst plus a separate challenger. Stage 3: one clean-context
Type 2 reviewer. All work against the same frozen commit. The maintainer owns
every gate.

## Locations

- Charter, inventory, path matrix, map, findings, gap analysis:
  `inst/design/audits/v0_2_2_pit_universe_audit/`.
- Reusable probes and the shared fixture: `dev/audit/pit_universe/`.
- Sharadar data only as aggregates; never `dev/spikes/asset_availability_pit/`.

## Routing of results

Findings never go straight into `decisions.md` or `contracts.md`. Code defects
and contract corrections become tickets (the planned post-Cut-11 maintenance
cut, or a cut of their own if numerous). Design questions become history-wave
register items, horizon entries or RFC questions. `decisions.md` receives only
decisions the maintainer has accepted.

## Ground rules, budgets and stop conditions

- Read-only on `R/`, `src/`, `tests/`, `NAMESPACE`, `DESCRIPTION`, `man/`.
- Stop and talk with the maintainer if: the inventory passes 250 rules (scope
  too wide); a stage would need a product change to answer its question; the
  frozen commit's behavior differs from Workstream 22's accepted
  byte-identity; or a finding needs a design decision before the stage can
  continue.
- Stage documents: map and findings at most 600 lines each; gap analysis at
  most 400 lines.

## Provenance of this plan

Proposed 2026-10-09 in the Cut 11 session; revised after an external review
(audit not spike; do not map code Workstream 22 is rewriting; explicit owner
boundary; a rule definition; a shared semantic fixture; Gate 1 completeness;
probes for behavioral findings only; refute material findings only; check the
ledgr-research feedback register; no raw recommendations into
`decisions.md`; an independent yardstick applied by a different reviewer) and
three refinements (rules a point-in-time run relies on are in scope; owner
value `unclear`; the boundaries study is prior art, not the yardstick).
