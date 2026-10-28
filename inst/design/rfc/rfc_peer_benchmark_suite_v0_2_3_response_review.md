# Peer benchmark suite: response review

**Mode:** response review, RFC stage 4; Codex, 2026-10-28.
**Disposition:** incorporate with qualifications into seed v2; no acceptance
or implementation authority is implied. v1 and Claude's response stay intact.

**Verification.** Re-ran `dev/spikes/peer_suite_response/check.R` on this
checkout before drafting v2: every recorded CSV reproduced; removing the
prior-usable-state requirement changed the observations and was detected.
The package/design scope check passed. This supplies neither peer parity nor
performance evidence. The response's four runs compare today's dense and
fact-bearing paths, not an implemented C1 implied-calendar adapter.

| Finding | Disposition and consequential qualification |
| --- | --- |
| F1: exact C1 oracle | Accept the need to separate economic and representation comparisons. Reject the assertion that C1 must change every timestamp: that depends on its as-yet-uncut implied calendar. Preserve full native baseline tables, event order and existing A0 checks. C1 must decide and verify each changed field or behavior before deletion; neither rekeying nor calling something representation is permission to hide a difference. |
| F2: crossover entry | Accept explicit warmup/entry semantics and decision-first attribution. Propose transition-only for the new peer recipe. Reject freezing the historical deletion oracle only after changing its rule: retain the old first-state witness unchanged, with the new recipe as a separate row. Six first-state entries do not establish the cause of the historical 238-trade gap. Retire the classifier's unexplained-residual fallback for new claims. |
| F3: two equivalence levels | Accept separately labelled decision agreement and trade/balance agreement. Treat the proposed native assignments as qualification hypotheses: no new peer was executed. Do not generalize daily adapter limitations into permanent impossibility for a framework. Only executed trade/balance-equivalent rows enter runtime ratios. |
| F4: retained outputs | Accept. Propose public `ledgr_run()` for the headline, with fills, equity, cash and asset holdings materialized for every ranked engine. Minimal sweeps remain separately labelled workflow measurements. |
| F5: reproducible render | Accept committed compact report records and explicit render selection. Preserve complete deletion tables separately; “no raw fills” applies only to compact report inputs. Reuse Git and native identities, without a new digest registry. Historical reports remain evidence. |
| F6: headline predeclaration | Accept, but denominators must include all predeclared required assignments, including unavailable/not-run rows. Attempted-only denominators could conceal missing coverage. Decision-only and full agreement counts must be disjoint or their overlap explicit. |
| F7: provisioning | Accept isolated, pinned, reproducible recipes, including bt. Do not infer a Python environment split solely from overlapping version constraints. A completed informative native row for each selected peer was already required by v1; unavailable peers do not silently discharge suite completion. |
| F8: API generations | Accept declared source/schema generations and unchanged economics. Exclude source/hash fields only from the economic projection, never from stored provenance or unrelated A0 checks. Preserve the old public scripts without adding compatibility readers. |
| F9: geometry | Accept the proposed 20 by 23,400 geometry as a proposal, using exactly 390 minute-end labels per session. Reuse public simulators and small deterministic transformations before inventing a generator. Do not predeclare an unexecuted peer unsupported or replace feasible 1,000-run measurements with projections by default. |
| F10: memory | Accept per-engine process-tree working set/private bytes and separate cold/warm peaks. Shared-page double counting and sampling limitations must be labelled. |
| F11: reuse and budgets | Accept reusing timing protocol, A0 canonicalization and existing adapter/runtime pieces after checking their fit. Budgets apply to each explicitly bounded cut; a whole-suite framework or automatic budget reset per file is not authorized. |

**Routing.** Seed v2 will propose the reporting vocabulary, full-run headline
and new crossover rule for acceptance. C1 timestamp/calendar, history and
diagnostic changes remain WS4 cut decisions under
`contracts.md#contract-execution-window-start` and the macro plan's
“unchanged, or each difference decided” gate. Method parameters belong in
the bounded lane cuts. No new peer installation, speed claim or publication
is authorized by this review.
