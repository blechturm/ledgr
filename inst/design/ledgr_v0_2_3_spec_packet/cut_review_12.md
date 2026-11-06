Verdict: CHANGES_REQUIRED

1. **R1 - Required. The old-kernel ban also bans the recorder's reference arm.** LDG-3213 acceptance 4 (`tickets.yml:4152`) prohibits calls from all of `dev/lean_core/`, although LDG-3211 names `ledgr_lot_apply` as a recorded boundary and LDG-3212 must replay that pinned function (`tickets.yml:4071`, `4105-4112`). The check cannot honestly pass alongside the required recorder.

   Replace acceptance 4 with: "The lean FIFO kernel and its candidate-side helpers never call ledgr_lot_apply, the old operation wrappers or other old arithmetic; the recorder's pinned reference capture and replay calls are exempt."

2. **R2 - Required. The no-alias requirement forbids accepted copy-on-modify sharing.** LDG-3213 acceptance 3 (`tickets.yml:4151`) requires more than input preservation. `contracts.md:325-329` (`contract-execution-fold-carrier`) permits ordinary copy-on-modify; the pinned probe shares an unchanged offset vector while a returned-book edit preserves the input (`review_probe.R:20-26`, output in `review_probe.txt`). Requiring physical separation would add needless copying.

   Replace acceptance 3 with: "Kernel calls preserve all input values; later ordinary edits to returned books or applied vectors preserve retained inputs, and later input edits preserve retained results. Ordinary R copy-on-modify sharing is permitted; no shared column is written by reference."

3. **R3 - Required. Whole-context serialization measures private caches as well as frozen public values.** LDG-3216 acceptance 2 (`tickets.yml:4226`) would reject the pinned implementation: a later context's history read changes an earlier context's serialized bytes while its public history remains identical (`review_probe.R:27-48`, `review_probe.txt`). Owner-local memo writes explain this (`R/history-frame.R:151-158`); frozen public views are the contract (`contract-context-pulse-data`, `contracts.md:2258-2260`).

   Replace acceptance 2 with: "A retained history result remains identical after tile recycling. Re-reading the retained context's public columns and registered history requests after recycling reproduces the frozen values, names, types, classes and metadata from before recycling; private cache serialization is not compared."

4. **R4 - Required. Service reuse is presented as an unrestricted implementation choice.** LDG-3211's "need a lean implementation" and LDG-3216's conditional reuse (`tickets.yml:4076-4078`, `4220-4222`) could authorize replacing causal or feature semantics. The accepted parent requires existing services (`rfc_lean_fold_core_v0_2_3_synthesis.md:82-85`); the skeleton specifically permits input-access/output-allocation adaptation (`rfc_lean_core_skeleton_v0_2_3_synthesis.md:238-252`).

   Replace the reuse question and its acceptance with: "Probe the pinned history-read and feature-input services and record the storage-access and output-allocation adaptations needed for tiles, preserving their existing semantic services. If this cannot satisfy the accepted boundaries, return NEEDS_TYPE_2 before implementation." Replace LDG-3216's conditional reuse with: "serve reads through those existing semantic services with the accepted tile-access adaptations."

5. **R5 - Required. The timing gates omit the mandatory shared protocol, and preparation has no measured numerical budget yet.** LDG-3214 names the standalone FIFO method; LDG-3217 compares against earlier clocks without requiring alternating matched arms (`tickets.yml:4165-4168`, `4244-4246`). AGENTS.md:117 and `benchmark_methodology.qmd:213-224` require the shared harness; the parent synthesis:295-298 requires baseline-derived budgets/noise before scoring. Entry memory clocks are explicitly descriptive, not preparation/request baselines (`dev/bench/v0_2_3_ws16_entry/README.md:23-25`).

   Replace those timing directions with "Use the timing protocol in Cut 12 decision (5)." Append to decision (5): "All timing gates use dev/bench/timing/ through one Cut 12 protocol, reusing the entry workload methods. LDG-3215 freezes matched preparation and full public-request clock endpoints, pinned microsecond budgets and baseline noise before LDG-3216 code. Preparation includes tile hydration and allocation. LDG-3214 and LDG-3217 compare alternating pinned/candidate arms through that protocol. The 123/134 us figures are rounded illustrations; FIFO gates use the caller/bucket ratios."

Checked and correct:

- Scope and order cover skeleton 5.1-5.3: accepted interfaces before code, recorder before both families, independent family reviews, cross-edge reads, refusals, mutations, subtraction, ledger and re-estimate. No additional execution family is needed.
- CSV aggregates reproduce 256/135,450/159,635 FIFO rows, 38 refusals and P1-P5 service counts 13/22/8/8/11. Half-costs are 122.922/134.255 us for fold and 122.245/134.054 us for replay; the proposed rounded FIFO figures are sound. Line ceilings are proposed maintainer choices, not measurements derived from those clocks.
- Public memory ranges agree with the CSVs. Private H1 figures are reported in the README; their underlying private CSVs are outside this review's permitted sources.
- Tile-range hydration addresses the measured long-frame allocation. Harness-launched workers can measure checkpoint allocations without adding product transport. The unchanged paired H1 run/sweep gate remains due at switch, when integration exists; checkpoint measurements cannot close it.
- No production, format or compatibility change is authorized; the old core stays frozen, `R/` cannot call the dev core, and `.Rbuildignore` already excludes it. The four-file routing diff claims no implementation. After the patches above, the recorder and family tooling are proportionate; no further hardening is requested.
