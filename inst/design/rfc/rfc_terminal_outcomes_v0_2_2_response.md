# Response: Terminal Outcomes for Untradable Holdings

**Status:** Type 2 adversarial response; input to seed v2.
**Respondent:** Codex
**Date:** 2026-10-04
**Responds to:** `rfc_terminal_outcomes_v0_2_2_seed.md`

## Verdict

The seed identifies two real product problems and proposes several good
controls, but its central abstraction is wrong. A known terminal event without
settlement terms and an exhausted valuation horizon are not two triggers for
one economic condition. The first is evidence that a security changed state;
the second says only that ledgr can no longer value a holding under the
declared rule. A halt may end, and an unexplained gap may be bad input.

Applying one default disposition policy to both would turn a data or valuation
failure into cash and a closed position. That makes more runs finish by
fabricating an economic event. The direction therefore needs one revision
before synthesis: keep modeled terminal outcomes, keep generic visibility for
incomplete candidates, and remove horizon exhaustion from the disposition
policy.

## Reviewer Bias And Method

I have repeatedly preferred reuse of existing ledgr mechanisms over new public
surface. That biases me toward extending the corporate-action policy even if a
new concept might read more neatly. I checked that preference against the
current tree: the existing policy already owns held-terminal disposition and
identity, and the existing corporate-action summary already counts disposition
choices and reports modeled fidelity.

I reused the executed terminal-outcomes probe rather than rerunning it. I
inspected the fold boundary, lifetime-fact constructor, corporate-action
policy, disposition writer, result summary and DSR implementation. I also
checked the current QuantConnect documentation: LEAN warns on the final
trading day and automatically liquidates later; that is evidence of a peer
assumption, not evidence that a generic missing-data horizon is a delisting.

## Direction Worth Keeping

The following parts should survive:

- supported settlement evidence always outranks an assumption;
- refusal remains available and is the strict preset;
- assumption-backed terminal outcomes use a closed policy menu, enter run and
  experiment identity, and are visible in ordinary results;
- a modeled close is a `DISPOSITION`, not a fill;
- separate runs compare alternative assumptions;
- incomplete candidates remain in inventories and review evidence, while
  ranking, extraction and promotion continue to exclude them; and
- `last_permissible` is safer than unbounded `last_mark` as the opinionated
  default for a known terminal event.

The probe establishes the reporting defect independently of the policy
choice. An incomplete candidate is persisted but disappears or loses its stop
reason on several selection surfaces. Fixing that is worthwhile even when the
run correctly remains incomplete.

## Blocking Findings

### F1. The single abstraction conflates evidence with ignorance

The fold computes the cases separately. `terminal_ids` come from held
instruments with a nonempty sealed terminal event, while `expired_ids` come
from impermissible marks; it then assigns two different stop reasons
(`R/fold-engine.R:492-523`). The probe's R3 and R5 happen to stop identically
because current valuation cannot distinguish a halt from missing bars. That is
an observability limit, not proof that both represent a disposal.

Under the seed, a temporary halt exceeding the researcher's horizon, a vendor
outage, a truncated file and an actual disappearance all free cash and erase
the position at a modeled price. If bars resume later, the run has spent cash
that no transaction produced. The policy would also make a bad-data run look
complete.

Smallest correction: scope the modeled policy to a sealed terminal event.
Leave `valuation_horizon_exhausted` fail-closed and make its exclusion visible.
A later fair-value or gap-continuation design may allow a held, modeled value;
it must not arrive disguised as a sale. This also keeps ordinary within-horizon
gaps unchanged.

This is the finding that requires seed v2 rather than synthesis.

### F2. A new combined policy argument duplicates an existing authority

`ledgr_corporate_actions()` already declares
`held_terminal_position = last_permissible | last_mark | refuse`, assigns a
versioned identity to the choice and carries it into config identity
(`R/corporate-action-policy.R:18-46`, `:68-147`). The production disposition
path already applies that choice and emits one typed `DISPOSITION`
(`R/corporate-action-settlement.R:391-548`).

The seed would add `untradable_policy` while moving or aliasing the same
accepted field. It would then have two plausible homes for terminal behavior,
or require a migration whose only benefit is grouping terminal facts with the
unrelated horizon case rejected in F1.

Smallest correction: extend the existing held-terminal choice with `haircut`
and `write_off`, reason overrides and the broader lifetime-fact trigger. Mint a
new versioned identity because the scope changes. Do not add a second public
policy argument. If modeled continuation after horizon exhaustion is ever
accepted, it belongs to valuation policy and a separate design.

### F3. Per-reason overrides currently depend on untyped free text

The lifetime constructor accepts `terminal_event` as an optional character
column and imposes no reason vocabulary
(`R/availability-facts.R:306-344`). The seed's examples treat values such as
`acquired` and `delisted` as if ledgr defined their meaning. It does not.

The least new mechanism is to make override keys exact sealed
`terminal_event` labels. Vendor adapters and data preparation own any
normalization; ledgr performs no synonym or vendor interpretation. The policy
identity must preserve the exact ordered mapping, unmatched labels use the
declared fallback, and results show the matched label. Seed v2 must state this
boundary. A built-in semantic reason taxonomy would be a larger schema and
adapter decision, not an incidental part of this RFC.

### F4. Incomplete trials cannot be inserted into effective-trial or DSR math

The seed correctly observes that silently disappearing trials are misleading,
but its Section 8 goes too far. `ledgr_effective_trials()` clusters comparable
retained return columns. `ledgr_dsr()` computes moments and Sharpe variance
from that completed matrix, and explicitly requires `effective_trials` not to
exceed its completed candidate count (`R/validation-dsr.R:155-200`,
`:420-436`). An incomplete prefix is neither a full return panel nor an
independent cluster member.

The prior-art record itself says no source establishes how truncated trials
enter multiple-testing corrections. A floor based on attempts, or retaining
prefix returns for this purpose, would invent statistical semantics in a
reporting RFC.

Smallest correction: report `attempted`, `done`, `incomplete` and `failed`
counts separately wherever selection is summarized. Effective trials and DSR
continue to use completed comparable panels and must disclose the excluded
candidate IDs and reasons. Do not alter their numerical input count here.

### F5. The headline field duplicates corporate-action reporting

`ledgr_corporate_action_summary()` already reads `CASHFLOW` and `DISPOSITION`
events, counts the held-terminal policy identities and marks exercised effects
as `corporate_action_fidelity = modeled`
(`R/corporate-action-results.R:275-380`). A second headline
`untradable-outcome` field would make users reconcile two summaries of the
same modeled disposition.

Extend the existing summary with assumed-terminal count, modeled proceeds,
reason label and default-versus-declared status. Generic incomplete reporting
should read the canonical completion payload. This uses the two existing
records for their existing jobs instead of adding another provenance surface.

## Answers To The Seed's Decisions

**D1, default.** Keep bounded `last_permissible` for known terminal events.
It matches the accepted equity-settlement direction and approximates the
default of peers without suspending ledgr's stale-mark bound. Do not use it for
horizon exhaustion, and do not supersede Section 3.3 with unbounded
`last_mark`.

**D2, policy home.** Extend `corporate_action_policy`'s existing
held-terminal field. Do not create `untradable_policy`. Horizon behavior stays
in valuation policy and remains refusal in this cycle.

**D3, timing.** Post an assumed terminal `DISPOSITION` at the terminal's
effective pulse, before that pulse's strategy decision, like the existing
disposition boundary. It is an accounting convention, not an execution fill.
`next_open` is not a coherent default for an instrument declared inactive and
may have no opening bar to name.

**D4, no mark ever.** Refuse. Falling back from `last_permissible` or
`haircut` to `write_off` silently changes the selected model. Users who want a
zero outcome can select `write_off` explicitly.

**D5, trial counting.** Add separate attempted and incomplete counts. Preserve
completed-panel effective-trial and DSR mathematics. Show excluded IDs and
completion reasons beside those diagnostics.

**D6, staleness interaction.** Once F1 is applied, it is a reporting question,
not a disposition question. Preserve distinct known-halt and unexplained-gap
detail where evidence permits; neither becomes a modeled sale.

## Failure Scenarios For The Revised Direction

| Scenario | Revised outcome | Where it still fails |
| --- | --- | --- |
| Supported settlement fact | Existing evidenced/modelled settlement path | Exact-quantity limitations remain separate |
| Known terminal, qualifying mark | Declared terminal `DISPOSITION`; run continues | Recovery value is still an assumption |
| Known terminal, strict policy | `INCOMPLETE`, visibly counted with reason | The unaffected future path is not simulated |
| Known terminal, no prior mark | `INCOMPLETE`; no hidden write-off | Quick-path usability is intentionally limited |
| Halt or unexplained gap within horizon | Existing hold/valuation behavior | No standing exit is queued |
| Horizon exhausted | `INCOMPLETE`, visibly counted; no cash invented | Long suspensions still stop the portfolio |
| Reason override | Exact sealed label selects override | Poor upstream normalization remains visible |
| Sweep with incomplete candidates | Selection uses `DONE`; attempted and exclusions print | DSR cannot quantify the missing full return path |

The important admitted failure is the long suspension. Solving it honestly
requires a valuation/continuation model, not a disposition shortcut. The seed
should say that plainly rather than claim the single policy solves every
untradable holding.

## Required Revision

Write seed v2 with these changes:

1. limit modeled dispositions to sealed terminal events;
2. extend and version the existing held-terminal corporate-action policy
   instead of adding `untradable_policy`;
3. bind reason overrides to exact sealed labels and leave normalization
   upstream;
4. reuse corporate-action fidelity and summary for modeled terminal outcomes;
5. make incomplete-candidate visibility generic, while leaving effective
   trials and DSR on completed comparable panels; and
6. resolve posting at the effective pulse and no-mark behavior as above.

No new spike is needed for those decisions. The public probe already
establishes current behavior; the remaining disagreement is economic meaning.
Seed v2 should preserve v1 as the historical artifact.

TYPE_2_DISPOSITION: REVISE_SEED
