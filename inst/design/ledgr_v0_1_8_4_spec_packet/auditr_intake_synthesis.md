# auditr Intake Synthesis: v0.1.8.3 Report For v0.1.8.4

**Status:** Accepted routing input for v0.1.8.4 ticket cut.
**Date:** 2026-05-26
**Source artifacts:**

- `inst/design/ledgr_v0_1_8_4_spec_packet/ledgr_triage_report.md`
- `inst/design/ledgr_v0_1_8_4_spec_packet/categorized_feedback.yml`
- `inst/design/ledgr_v0_1_8_4_spec_packet/cycle_retrospective.md`

---

## 1. Headline

The v0.1.8.3 auditr report is healthy. It reviewed 22 episodes and 56
feedback rows. All 22 episodes completed. There are no high-severity findings.
The report is documentation-shaped, not correctness-shaped:

```text
0 high severity
10 medium severity
46 low severity
31 docs_gap rows
5 bad_example rows
5 missing_api rows
4 unclear rows
3 expected_user_error rows
3 ledgr_bug rows
```

The sealed-snapshot, hash, accounting, preflight, and promotion contracts held.
The primary package signal is that users can complete tasks, but they often
assemble the workflow from scattered documentation.

The report has parsing uncertainty recorded in `categorized_feedback.yml`.
Treat rows as evidence, not automatic defect truth.

---

## 2. Accepted v0.1.8.4 Fixes

### AUD-184-01: Sweep Print Footer After Reordering

Source:

- `2026-05-26_005_sweep_basic_candidate_promotion/FB-002`

Finding: sorted sweep tables can still print a footer saying rows are in
parameter-grid order.

Route: accepted low-severity UX fix.

Expected resolution: either track reorder state in the print method or replace
the footer with neutral guidance that does not claim a specific ordering after
users reorder or subset results.

### AUD-184-02: Parameterized Bundle Output Identity

Source:

- `2026-05-26_011_multi_output_indicator_bundles/FB-001`
- related: `2026-05-26_011_multi_output_indicator_bundles/FB-002`
- related: `2026-05-26_014_adversarial_inputs_csv_bundle_registration/FB-004`

Finding: parameterized bundle factories can produce duplicate default concrete
feature IDs such as `bbands_up` for different parameter values. The runtime
projection cannot safely represent two different concrete features with the
same concrete ID.

Route: accepted v0.1.8.4 design constraint because active aliases and
parameterized bundles are in scope.

Expected resolution:

- strategy-facing bundle aliases may remain flat (`bbands_dn`, `bbands_up`);
- resolved concrete feature IDs must be parameter-distinct when parameterized
  bundle declarations materialize different concrete features;
- candidate alias maps may map the same strategy-facing alias to different
  concrete IDs per candidate;
- duplicate generated concrete IDs must fail with an action-oriented classed
  error if they cannot be safely disambiguated;
- documentation must show safe parameterized bundle identity and clarify that
  bundle flat aliases are not necessarily the same as concrete feature IDs.

Verification should include at least two candidates that use the same bundle
outputs with different bundle parameters in one sweep.

### AUD-184-03: Preflight Global-Assignment Message Ordering

Source:

- `2026-05-26_022_adversarial_preflight_indirection_bypass/FB-001`

Finding: a strategy rejected for `<<-` global assignment can also report the
left-hand-side assignment target as unresolved before the mutation reason.

Route: accepted low-severity message fix.

Expected resolution: suppress unresolved-symbol reporting for `<<-`
left-hand-side names, or prioritize the mutation violation above the unresolved
symbol detail. The strategy remains rejected.

---

## 3. v0.1.8.4 Documentation And Message Polish

These items are accepted only where they can be handled in bounded changes
around active aliases, sweeps, and release docs. They must not grow into the
v0.1.8.5 canonical workflow cycle.

### AUD-184-04: Runnable Sweep Script Listing

Source:

- `2026-05-26_005_sweep_basic_candidate_promotion/FB-004`
- duplicate: `2026-05-26_006_sweep_train_test_discipline/FB-001`
- duplicate: `2026-05-26_016_inspection_surfaces_map/FB-003`

Route: accepted docs/discovery fix.

Expected resolution: do not list empty or near-empty prepared vignette scripts
as runnable. Either populate the sweeps script with useful executable workflow
code after v0.1.8.4 docs update, or remove it from runnable-script discovery.

### AUD-184-05: Sweep Candidate Inspection Recipe

Source theme:

- THEME-002: sweep ranking, promotion, and provenance inspection

Route: partial v0.1.8.4 docs scope, with broad workflow treatment deferred to
v0.1.8.5.

Expected v0.1.8.4 resolution: active-alias and sweep docs should show a
metadata-preserving ranking/promotion pattern. Do not add automatic ranking,
winner selection, or tuning objective semantics.

v0.1.8.5 will own the broader canonical report/review walkthrough.

### AUD-184-06: Error Message Actionability

Source theme:

- THEME-008: error message actionability

Route: accepted opportunistic message polish for surfaces touched by v0.1.8.4.

Expected resolution: new and touched errors should name the parameter, alias,
feature, grid label, or artifact state involved, and should suggest a next
action where unambiguous.

Do not open a package-wide error-message rewrite in v0.1.8.4.

### AUD-184-07: Bounded Yahoo / Real-Data Notes

Source theme:

- THEME-006: Yahoo and real-data workflow clarity

Route: bounded v0.1.8.4 docs note only if it fits the active docs pass; broader
real-data workflow guidance moves to v0.1.8.5.

Allowed v0.1.8.4 additions:

- Yahoo helper creation/sealing semantics;
- optional `TTR` dependency callout where examples use TTR indicators;
- price-adjustment policy pointer if already known;
- buy-and-hold baseline sizing warning where examples compare strategies.

Do not add a full real-data workflow article in v0.1.8.4.

---

## 4. Explicit v0.1.8.5 Deferrals

These findings are real but belong to the accepted v0.1.8.5 canonical workflow
cycle:

- THEME-001 broader runnable examples and doc-routing gaps;
- THEME-002 residual sweep inspection and report patterns;
- THEME-005 metric context runnable lifecycle and comparison-context surprise;
- THEME-006 full Yahoo / real-data troubleshooting and baseline-comparison
  narrative;
- THEME-010 accounting and metric surface semantics;
- canonical "where do I look for X?" guidance across snapshot, run, sweep,
  equity, fills, metrics, promotion, and replay.

The v0.1.8.5 workflow article should directly use these auditr findings as
source evidence for its end-to-end example and report outline.

---

## 5. Backlog Or Future Design Requests

These findings should not be pulled into v0.1.8.4:

- public causal validator for arbitrary vectorized `series_fn` output;
- series-fn-only indicators;
- TTR-free Bollinger helper;
- exported flat sweep-provenance accessor;
- public risk-free scalar accessor, unless the metric-context docs update
  chooses to document the existing nested field instead;
- cross-project snapshot reuse;
- point-in-time regressors;
- live production data logs.

They may be reconsidered through future RFCs or spec packets.

---

## 6. auditr-Side Or Task-Brief Routing

Do not treat these as ledgr runtime defects:

- THEME-009 PowerShell range syntax, dollar-sign quoting, and saved-help
  filename guessability;
- task examples that expected resolved global scalars to be Tier 3 when ledgr
  classifies them as Tier 2;
- task examples that expected `stats::median` to be Tier 2 even though
  recommended R packages remain Tier 1.

The ledgr docs may clarify current behavior where useful, but the primary
repair is auditr task/instruction alignment.

---

## 7. Ticket-Cut Implication

v0.1.8.4 ticket cut should include:

1. The existing active-alias and grid-helper implementation tickets.
2. A parameterized bundle output identity ticket or explicit acceptance
   criterion inside the resolution/alias-map ticket.
3. A small sweep print-footer UX ticket.
4. A small preflight message-ordering ticket.
5. A bounded docs/discovery ticket for runnable sweep scripts and
   metadata-preserving sweep candidate inspection.
6. Optional bounded Yahoo/real-data notes if docs bandwidth allows.
7. Explicit deferrals to v0.1.8.5 in release notes or cycle-close notes.

No auditr finding blocks v0.1.8.4 design work from starting.

