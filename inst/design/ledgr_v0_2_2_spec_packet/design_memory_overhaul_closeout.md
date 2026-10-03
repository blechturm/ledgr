# Design-Memory Overhaul Closeout

**Status:** Agent-provisional closeout for Cut 1, Workstream 5.
**Implementation range:** `a93e7e3..8c05e6e`; twelve tickets in five serial
workstreams. The focused correction after that range changes records only.
**Behavior:** Documentation and process routing only. No package behavior,
public API or semantic contract changed.

## Outcome

The repository now has one short front door, one normative current-behavior
contract, one temporary exact-source decision bridge, one current RFC pipeline,
one committed roadmap sequence and one non-binding parking lot. Historical
bodies remain at stable paths or behind exact-heading redirects.

The migration deliberately did not add a database, generated registry, audit
ledger, spike index or semantic governance checker. The design system remains
Markdown maintained at the lifecycle gates that already exist.

## Root Design-Document Classification

Every Markdown file directly under `inst/design/` has one declared role. This
classification prevents a historical plan from looking current without
renaming historical paths.

| File | Current role |
| --- | --- |
| `collapse_optimization_map.md` | Historical v0.1.8.7 optimization input; non-binding evidence. |
| `contracts.md` | Normative current-release behavior and internal invariants. |
| `decisions.md` | Temporary exact-source bridge to accepted pending decisions; not a second authority. |
| `exact_parity_internal_optimization_proof_template.md` | Accepted evidence template; it authorizes no optimization by itself. |
| `horizon.md` | Active non-binding parking space. |
| `horizon_archive.md` | Historical bodies displaced from active parking. |
| `ledgr_design_document.md` | Historical superseded proposal; no current authority. |
| `ledgr_design_philosophy.md` | Non-enforceable design guidance. |
| `ledgr_roadmap.md` | Compact committed cross-version sequence. |
| `ledgr_ux_decisions.md` | Historical v0.1.7 proposal; no current API authority. |
| `methodology_references.md` | Non-binding index of external design priors. |
| `model_routing.md` | Historical superseded workflow proposal; no current authority. |
| `planning_context_history.md` | Historical planning narrative. |
| `README.md` | Current routing front door. |
| `release_ci_playbook.md` | Binding release and release-closeout process. |
| `rfc_cycle.md` | Current RFC-cycle reference and accepted review discipline. |
| `roadmap_history.md` | Historical displaced roadmap detail. |
| `spike_protocol.md` | Binding protocol for spikes and prototypes. |
| `vignette_styleguide.md` | Accepted user-facing article standard. |

## Bounded Evidence Population

The reconciliation baseline is commit `57ea840`, after LDG-2933. The population
is the union of:

1. thirteen evidence targets cited from `AGENTS.md`, the design front door,
   contracts, the decision bridge, the RFC pipeline, the roadmap and the active
   packet at that commit; and
2. forty closed Markdown evidence records changed between `v0.2.0.0` and that
   commit: research evidence notes, every audit record, and spike findings,
   inventories, reports, summaries or closeouts. Charters, harness prose and
   raw CSV evidence are not separate population units.

Five cited targets overlap the closed-record set, leaving 48 population units:
five research routes, eight audits and 35 spike records or cited spike
directories. The protected untracked availability spike is outside the tracked
population and was not read.

The deterministic sample is the first and last path under case-insensitive
ordinal path ordering in each category, plus every record declaring a
top-level RED, inconclusive or other non-binary outcome. `NEITHER` and
`partly` were included conservatively as non-binary outcomes.

| Sample | Route or disposition |
| --- | --- |
| `research/Cross-Asset-Accounting-Critical-Events.md` | Consumed by the cross-asset RFC-pipeline route and the equity-settlement evidence chain. |
| `research/Sharadar-Workflow-Improvement-Evidence.md` | Consumed by the released v0.2.1 packet's workflow and optimization tickets. |
| `audits/post_v0_2_0_1_accounting_core_inventory.md` | Consumed by the accepted accounting-core synthesis and its released implementation packet. |
| `audits/v0_2_0_2_vignette_audit.md` | Consumed by the v0.2.1 vignette-correction closeout and retained as input to the active feature-map RFC. |
| `dev/spikes/availability-diagnostic-block-write/probe_findings.md` | Consumed by the accepted availability-hot-path synthesis and v0.2.1 implementation. |
| `spikes/terminal_disposition_policy_spike/closeout.md` | Consumed by the accepted equity-settlement synthesis and corporate-action packet. |
| `dev/spikes/availability-hot-path-representation/probe_findings.md` (RED component) | The rejected representation and green prerequisite are recorded in the availability-hot-path RFC cycle; neither is open work. |
| `dev/spikes/collapse-preparation/findings.md` (RED) | The rejected `collapse::rsplit()` route is recorded in `collapse_optimization_map.md` and the fold-writer/accessor summary. |
| `dev/spikes/v0_2_0_1_availability_timestamp_prerequisite/probe_findings.md` (`NEITHER`) | Consumed and explicitly closed without ingestion work in the v0.2.1 packet and release closeout. |
| `dev/spikes/strategy-context-surface/probe_findings.md` (`partly`) | Consumed by the accepted strategy-context synthesis and the v0.2.1 Cut 13 closeout; the implementation packet recorded warm microbenchmarks only, and full-run performance remains unmeasured. |
| `spikes/settlement_quantity_primitive_spike/closeout.md` (RED) | Consumed by equity-settlement seed v3 and the accepted synthesis's exact-quantity boundary. |

The terminal-disposition row is both the final spike path and a consumed green
closeout. No sampled material finding lacked a consumer, so this workstream did
not add another horizon entry.

## Optional Link Check

No checker was retained. The migration did not reveal a recurring failure in
the four proposed files that justifies a parser or another maintained command.
A one-off local-target pass over `inst/design/README.md`, `decisions.md`,
`rfc/README.md` and `AGENTS.md` checked 143 Markdown targets and found zero
missing files. Existing review, `git diff --check` and ordinary Markdown link
inspection supply the needed evidence without entering package tests, CI or
the release gate.

## Lifecycle Duties Added

`release_ci_playbook.md` now binds two existing gates:

- ticket cut archives a promoted horizon body and leaves its exact heading as
  a redirect to the owning packet or ticket; and
- release closeout updates the front door and AGENTS, removes a decision-bridge
  row only after an exact standing replacement exists, checks that ticketed
  obligations left the RFC pipeline, and reconciles packet horizon references.

The change adds duties to existing gates; it creates no new review stage.

## Scenario Walk

Starting at `inst/design/README.md`, the six accepted scenarios resolve as
follows:

| Need | Route | Links |
| --- | --- | ---: |
| Current behavior | front door -> `contracts.md` -> named H2 contract | 1 |
| Accepted pending change | front door -> `decisions.md` -> exact accepted source section | 2 |
| Active RFC | front door -> RFC pipeline -> feature-map seed | 2 |
| Executable ticket | front door -> v0.2.2 packet -> `tickets.yml` | 2 |
| Parked idea | front door -> `horizon.md` -> active parking body | 1 |
| Historical evidence | front door -> roadmap or evidence route -> packet, archive or cited record | 2 |

The horizon headings `Dependency order for the next version` and `Binding
decisions must be discoverable` are no longer active parking prose. They are
exact-heading redirects to the macro plan and design-memory plan. No Cut 1
ticket is duplicated in `Obligations open`.

## Verification

- YAML reconciliation: `PACKET_RECONCILIATION_OK tickets=12 workstreams=5`.
- Focused `test-documentation-contracts.R`: passed under R 4.6.1 with DuckDB
  1.5.6.9000 first on the library path.
- Roadmap archive comparison: the historical tail matches `dd72434` after
  newline normalization.
- Four-file local Markdown targets: 143 checked, zero missing.
- `git diff --check`: clean.

## Final Reconciliation

- Tickets LDG-2923 through LDG-2934: twelve complete.
- Workstreams 1 through 4: accepted; Workstream 5: corrected after its Type 1
  close review and focused re-review, and awaiting maintainer acceptance.
- Review count: the Workstream 5 close review was invocation seven and its
  focused re-review was invocation eight. The cut therefore stands at 8/12 =
  0.667, above the 0.500 gate. The breach is historical; the cut is not padded
  and reviews are not merged to repair the ratio.
- RFC pipeline: no Cut 1 obligation remains open after ticket ownership.
- Horizon: promoted Cut 1 sources are redirects; no ticketed Cut 1 body remains
  active parking.
- Concurrent maintainer research routes in roadmap, horizon and research files
  remain unstaged and are not claimed by this workstream.

The semantic findings named above are routed or consumed. This closeout does
not claim that a spike finding was fixed merely because its evidence is
discoverable.
