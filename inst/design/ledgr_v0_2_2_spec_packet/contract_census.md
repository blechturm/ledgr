# Contract Authority Census

**Status:** LDG-2923 migration input; not a replacement contract.

**Baseline:** `a3100d7`, 2026-10-03.

**Scope:** `inst/design/contracts.md`, the strategy-preflight boundary in
`ledgr_v0_1_8_0_spec_packet/v0_1_8_spec.md`, the v0.1.9.5 packet, and the
released v0.2.0.0, v0.2.0.1 and v0.2.1.0 packets.

This census does not authorize a semantic edit. A disagreement between code
and a contract is routed as a defect; it is not permission to rewrite the
contract to match the code.

## 1. Method And Baseline

The current file has thirteen H2 sections and 1,487 lines. The census used
four bounded passes:

1. enumerate H2 sections, header handoffs and explicit design-file links;
2. inspect future and conditional language for hidden authority;
3. sample two non-adjacent clauses in every H2 against existing tests or
   record that no direct detector exists; and
4. reconcile the two sources named by the old header and contract changes in
   the three later released packets.

The samples are evidence about consolidation safety, not a clause-by-clause
behavioral audit. Test names below are stable descriptions; line numbers refer
to the baseline and are allowed to move during later work.

## 2. H2 Clause Samples

| Contract section | Sampled clause | Existing evidence | Result |
| --- | --- | --- | --- |
| Public Naming | line 13: exported helpers use `ledgr_` prefixes | `test-api-exports.R`, "exported API surface is locked" | Present; the exact export set is locked. |
| Public Naming | line 41: internals are not exported to avoid a narrow wrapper | `test-api-exports.R`; namespace inspection | No detector distinguishes the reason for an export. Structural evidence only. |
| Execution | line 46: `ledgr_run()` is the public experiment run path | `test-experiment-run.R`; `test-api-exports.R` | Present. |
| Execution | line 190: R and compiled FIFO pop fractional dust | `test-lot-accounting.R`, "lot accounting pops fractional dust lots"; `test-execution-spec.R`, compiled equivalent | Present on both arms. |
| Sweep Promotion | line 199: compact sweep rows carry promotable candidate identity | `test-sweep.R`, result-column and candidate tests; `test-sweep-parity.R` | Present. |
| Sweep Promotion | line 226: direct runs have no promotion context | `test-promotion-context.R`, "direct runs return NULL promotion context" | Present. |
| Config | line 234: internal `ledgr_config` is validated S3 | `test-config-object.R` | Present. |
| Config | line 240: direct config construction is not exported | `test-api-exports.R`; public `ledgr_experiment()` and `ledgr_run()` tests | Present; no independent semantic detector is needed beyond export and workflow tests. |
| Snapshot | line 245: runs require sealed snapshots | `test-experiment.R`, "rejects unsealed snapshots"; `test-runner-snapshots.R` | Present. |
| Snapshot | line 297: run windows are not rehashed as bar subsets | `test-runner-snapshots.R`; `test-snapshots-hash.R`; API export lock | Present indirectly; no single detector is phrased as this whole clause. |
| Availability | line 304: facts or valuation policy activate availability without a mode flag | `test-availability-workflow.R`; `test-availability-causality.R` | Present. |
| Availability | line 432: closed reason tokens have fixed stage meaning | `test-availability-economics.R`, `test-availability-workflow.R`, `test-corporate-action-disposition.R` | Token families are exercised; no single test independently enumerates the entire table. |
| Persistence | line 465: ledgr-owned DuckDB drivers use session-local storage without suppressing conditions | `test-connection-lifecycle.R`, LTB-0132 | Present, including the non-suppression control. |
| Persistence | line 591: archive and tags exist; hard delete does not | `test-run-metadata.R`, `test-run-tags.R`, `test-api-exports.R` | Positive surfaces are tested; absence of a delete export is covered by the export lock. |
| Canonical JSON | line 596: `canonical_json()` owns canonical serialization | `test-canonical-json-byte-format.R`; `test-config.R` | Present and byte-pinned. |
| Canonical JSON | line 614: equivalent maps and lists preserve feature identity | `test-feature-map.R`, "feature maps preserve concrete feature-set identity" | Present. |
| Strategy | line 621: strategies return complete targets or the accepted wrappers | `test-backtest-wrapper.R`, "functional strategies must return targets for the full universe"; `test-strategy-contracts.R` | Present. |
| Strategy | line 910: canonical JSON cannot distinguish `NULL` and `NA` parameters | `test-canonical-json-byte-format.R` pins `NULL` as JSON null | No direct `NULL` versus `NA` detector. The limitation is stated but weakly protected. |
| Context | line 916: runtime and interactive contexts expose data-frame-compatible bars and feature tables | `test-backtest-wrapper.R`, context-compatibility block; `test-indicator-tools.R` | Present. |
| Context | line 1060: interactive tools are read-only | `test-indicator-tools.R`; `test-feature-inspection.R` | Read surfaces are exercised; no general before/after persistent-table detector covers every interactive tool. |
| Result | line 1065: equity and results derive from persisted event evidence | `test-accounting-consistency.R`, "equity curve state is reconstructed from ledger fills" | Present. |
| Result | line 1399: `time_in_market` uses `abs(positions_value) > 1e-6` | `test-metric-oracles.R` independent formula and comparison | Present. |
| Documentation | line 1404: canonical examples use the base pipe | `test-documentation-contracts.R` pins representative helper pipelines | Present for the teaching set; not a parser over every prose file. |
| Documentation | line 1459: teaching covers allocation and hold-and-edit semantics | `test-documentation-contracts.R`; availability economics tests | Present through executed article pins and product tests. |
| Verification | line 1469: full regression passes before release completion | `release_ci_playbook.md`; released closeouts | Process gate, not sensibly self-tested by the package suite. |
| Verification | line 1484: production fold entry is guarded by sealed-snapshot verification | `test-runner-snapshots.R`, LTB-0001; `test-execution-spec.R`, LTB-0015; sweep boundary tests | Present and failure-sensitive. |

No sampled clause contradicted the current code or tests. The three weakly
protected samples are recorded as evidence quality, not new test obligations:
export rationale, JSON `NULL` versus `NA`, and the universal read-only claim.

## 3. Authority And External-Reference Inventory

| Location | Current role | Classification | Proposed disposition |
| --- | --- | --- | --- |
| header lines 3-7, `README.md` and v0.1.9.5 packet | delegates current authority to an old packet | stale authority text | LDG-2924 replaces it with the normative-current-release role. |
| header lines 8-9, nonexistent `ledgr_v0_1_8_spec_packet/` | says the preflight boundary remains binding | stale and broken handoff | The rule is already consolidated; remove the handoff under LDG-2924. |
| Strategy line 761, 2026-09-29 `horizon.md` entry | makes current literal-target behavior depend on parking prose | operative dependency on a non-binding file | Record now; LDG-2931 re-points it after classifying the entry. |
| Strategy line 802, strategy-helper-axis audit | provenance for the domain table | evidence citation, not delegated authority | Retain as explanatory evidence. |
| Verification line 1481, release playbook | assigns release execution to its native gate | correct process reference | Retain. |

No synthesis or current spec packet is otherwise cited as the authority for a
current contract clause. The header is therefore the stale global handoff;
the 2026-09-29 horizon reference is the only sampled body-level binding
dependency that must be re-pointed.

## 4. Future And Conditional Language

The following groups do not change current behavior. Their later-work meaning
must be classified by the decision bridge or RFC pipeline rather than left to
filename proximity.

| Contract lines | Deferred subject | Census disposition |
| --- | --- | --- |
| 68, 91, 113 | future in-memory output; partial parallel recovery; durable compiled integration | Current exclusions. Check accepted sources for any unscheduled obligation during LDG-2925/2929. |
| 130, 149 | cost-grid composition; optimization, margin, shorting, liquidity and OMS layers | Current exclusions, not implementation promises. |
| 227-229, 240 | full sweep artifacts and direct public config construction | Sweep persistence later narrowed part of the gap; keep current clauses and route only accepted remainder. |
| 617, 656, 822 | future identity change and short/leverage semantics | Current exclusions. Short/leverage already has an RFC trigger; link rather than duplicate. |
| 851, 861 | possible Tier 3 override and dependency declaration | Conditional examples, not accepted obligations. |
| 1005 | recursive and other TTR availability support | Accepted design question in the indicator RFC pipeline; bridge to its exact source later. |
| 1206-1211, 1227 | time-varying risk-free providers and additional risk metrics | Deferred capabilities, not current release promises. |
| 1439 | future indicator adapters | Extension statement only. |

## 5. v0.1.8 Strategy-Preflight Reconciliation

The old header intended Section R3 of
`ledgr_v0_1_8_0_spec_packet/v0_1_8_spec.md`, lines 601-620. Its complete
normative content is:

1. preflight is a pre-fold classification gate whose result reaches the output
   handler;
2. the strategy function is fixed across sweep candidates while params vary;
3. one preflight per sweep is allowed only while classification depends on the
   strategy body and non-candidate-specific referenced symbols;
4. inspection of candidate-varying feature state requires per-candidate
   preflight;
5. `package_dependencies` is informative but not a complete worker setup
   contract; and
6. v0.1.8 exports neither `worker_packages` nor a public parallel dependency
   API.

Reconciliation:

- Strategy Contract lines 838-904 now carry the tiering, pre-fold refusal,
  result shape, worker-dependency metadata and sweep inheritance in greater
  detail.
- Execution Contract lines 181-185 state that preflight precedes the fold and
  Tier 3 produces no fold or handler side effect.
- `test-strategy-preflight.R` covers classification and artifact-free refusal;
  `test-sweep.R` covers sweep refusal and candidate execution.
- Later parallel work deliberately extended worker metadata beyond the old
  v0.1.8 non-capability statement. That sentence is historically superseded,
  not missing.

All six source statements are therefore present, explicitly extended or
historical. No current rule depends on the old packet.

## 6. v0.1.9.5 Packet Reconciliation

The authoritative narrative was
`ledgr_v0_1_9_5_spec_packet/v0_1_9_5_spec.md`; its ticket and batch files add
historical sequencing and acceptance detail but do not outrank that spec for
semantic rules. The packet's normative groups reconcile as follows.

| v0.1.9.5 rule group | Current disposition |
| --- | --- |
| exact naming-synthesis scope, hard renames, unexports and no aliases | Public Naming Contract lines 13-41; export lock. Present. |
| M-8 eager readers that never retain borrowed connections | Persistence lines 514-518 and Result lines 1153-1158. Present. |
| H-1: execution windows contain at least two pulses and fail classed | Implemented and tested, but no current contract clause found. Route to the decision bridge; LDG-2924 must not invent it. |
| H-3: elapsed telemetry is seconds without magnitude inference | Persistence telemetry identifies elapsed seconds; implementation detail about the removed heuristic need not remain normative. Present at the required level. |
| B-1 C++ protection mechanics | Implementation safety detail, deliberately not a standing behavioral contract. Historical. |
| H-2 fill transition validity: side known; quantity and price finite positive; fee finite nonnegative | Current code/tests validate it, but no complete standing clause was found. Route for consolidation as an internal invariant. |
| M-1 through M-3 internal legacy resolver and C++ error hygiene | Historical implementation work; current behavior is covered by Execution and compiled parity rules. |
| M-7 rounding before fee and fees on adjusted notional | Implemented and documented at the cost surface, but no standing contract clause found. Route for consolidation. |
| M-5 db-live count optimization deferral and N-series nits | Historical scheduling, not current behavior. Deliberately absent. |
| candidate generic, locator attributes, resolve-at-call and override rule requiring both snapshot ID and hash | Naming and Execution lines 31 and 164-169 cover the generic, locators and identity exclusion. The exact two-field override rule is absent; route for consolidation. |
| M-4 fractional dust | Execution line 190; R and compiled tests. Present. |
| M-6 POSIXct-only snapshot-hash timestamps | Snapshot lines 254-256; hash tests. Present. |
| vignette split, manual structure and release sequence | Historical release process; deliberately absent from current behavior contract. |
| release gates imported from the playbook | Verification lines 1469-1485 and the playbook. Present in their native gate. |

Four accepted and shipped rules are not consolidated strongly enough for the
new normative role: H-1, H-2, M-7 and the candidate override rule. They are
not code-versus-contract disagreements because sampled implementation evidence
agrees with the packet. They are stale authority handoffs: LDG-2925 must add
exact-source bridge rows, and a later authorized packet must decide whether
and where to consolidate them. LDG-2924 does not add their semantics.

## 7. Later Released Packets

| Release | Check | Result |
| --- | --- | --- |
| v0.2.0.0 | Its spec Section 3 maps every behavior-changing area to same-release contract edits. The release history contains contract commits for public hardening, risk/selection metrics and availability. | Recorded. Current Snapshot, Availability, Persistence, Strategy, Context, Result and Verification sections carry the shipped rules. |
| v0.2.0.1 | The release optimized internal representation and set `collapse >= 2.1.8`. The tag range changes `DESCRIPTION`, not `contracts.md`. | No missing public-behavior contract found. The dependency floor belongs in `DESCRIPTION`; accepted exact-parity and fail-closed behavior reuse existing contracts. |
| v0.2.1.0 | The tag range contains eighteen contract commits, including the event envelope, TTR SMA availability support, context surface, session axis and strategy helper semantics. It also shipped equity corporate actions, accounting-core consolidation and the testing control plane without consolidating all of their accepted rules into a standing contract or process document. | Partly recorded. `git diff` from v0.2.0.1 to v0.2.1.0 changes 284 contract lines, but the three unconsolidated topic groups are routed through LDG-2925 and LDG-2927 rather than treated as standing. |

The later-release check found no rule that conflicts with the current contract.
It exposed three accepted and shipped topic groups that are not consolidated
strongly enough for the new normative role: equity corporate actions, testing
architecture and accounting-core internal invariants. LDG-2925 and LDG-2927
must bridge them and add their pending links. This is in addition to the four
older v0.1.9.5 consolidation gaps above.

## 8. Routed Findings And LDG-2924 Input

| Finding | Classification | Owner / route |
| --- | --- | --- |
| global v0.1.9.5 authority delegation | stale authority text | LDG-2924 header correction |
| broken v0.1.8 packet path | stale authority text | LDG-2924 header correction |
| H-1, H-2, M-7 and candidate override semantics live only in accepted historical authority | stale authority handoff; shipped but unconsolidated | LDG-2925 exact-source bridge; later authorized consolidation |
| equity corporate-action semantics shipped without standing Availability, Execution and Result clauses | stale authority handoff; shipped but unconsolidated | LDG-2925 exact-source bridge and LDG-2927 pending links; later authorized consolidation |
| testing-architecture decisions live in the accepted synthesis while the control plane and claims registry are evidence | stale authority handoff; shipped but unconsolidated | LDG-2925 exact-source bridge and LDG-2927 Verification pending link; later authorized consolidation |
| accounting-core internal invariants are only partly represented by current Execution clauses | partial stale authority handoff | LDG-2925 exact-source bridge and LDG-2927 Execution pending link; later authorized consolidation |
| Strategy line 761 binds to a horizon entry | conflict with the accepted horizon role, not a product-rule conflict | LDG-2931 citation routing; preserve current clause until then |
| recursive-indicator availability support is still future-facing | accepted but unimplemented direction | LDG-2925/2929 exact-source bridge and pipeline classification |

No sampled code-versus-contract disagreement was found. No conflict between
two semantic binding documents was found. The one role conflict is structural:
current contract prose points to a parking document. It remains visible and is
routed rather than silently repaired in Workstream 1.

LDG-2924 may therefore change only the global authority header, add the H2
navigation table and state the pending-link lifecycle. It must not add the
four unconsolidated v0.1.9.5 rules or re-point the 2026-09-29 horizon citation;
those actions belong to later tickets named above.

## 9. LDG-2924 Reconciliation

LDG-2924 applied the two safe stale-text corrections: it replaced both global
packet handoffs with the normative-current-release role and added navigation
to the thirteen unchanged H2 headings. The header now assigns removal of an
`Accepted change pending` link to the implementing packet that rewrites the
clause.

The other census findings remain routed rather than edited:

- H-1, H-2, M-7 and the walk-forward override rule go to LDG-2925 and
  LDG-2927 for exact-source bridge entries and pending links;
- equity corporate actions, testing architecture and accounting-core internal
  invariants go to LDG-2925 and LDG-2927 for exact-source bridge entries and
  pending links;
- the 2026-09-29 horizon dependency goes to LDG-2931; and
- recursive-indicator direction goes to the bridge and RFC pipeline under
  LDG-2925 and LDG-2929.

The diff under LDG-2924 changes only the header and navigation. It changes no
existing H2 heading and no semantic clause.
