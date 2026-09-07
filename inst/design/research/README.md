# Research inputs to RFC seeds

This directory holds non-binding research inputs that are fed to RFC seeds as
design-space or empirical context. Most files are deep-research LLM outputs.
Project-authored empirical syntheses and companion evidence handoffs may also
be preserved here when an external, private, or licensed research workflow has
produced durable, non-reconstructive input for an upstream RFC. Each file
belongs to a named RFC cycle or parked RFC direction.

**Status:** non-binding inputs. Preserve indefinitely as audit trail. Do not
promote to a user-facing docs surface.

---

## Empirical evidence inputs

| File | Evidence source | Intended RFC use |
|---|---|---|
| `Sharadar-Empirical-Evidence.md` | Sharadar Data MVP and Evidence Promotion v0.1.0, private authoritative source commit `e53bda3b108e51ad44720b9812c8072624b8820e` | Asset availability, point-in-time universe, missing-data, valuation, execution, and preprocessing RFC seed |

The Sharadar synthesis contains only non-reconstructive aggregates and
conclusions. It is not vendor data, a canonical schema, or a binding ledgr
decision. The private evidence artifacts remain authoritative for exact audit.

## What the deep-research files are

For each RFC cycle that needed broad prior-art coverage, the maintainer prompted a deep-research LLM (typically ChatGPT Deep Research) with a structured request: literature foundations, competitor implementations, design-pattern survey, ledgr-specific design questions, plus a "strongest single influence" verdict. The model produced a single dense markdown document. That document is what lives here.

These artifacts informed the seed RFC. The seed cites the file by path. The synthesis lifts whichever framings and references it found load-bearing.

## What the deep-research files are NOT

- **Not canonical literature reviews.** One model's pass through the literature, with citation precision that varies. Some treatments are cursory; some are misattributed in subtle ways; cross-check against primary sources before quoting in a binding artifact.
- **Not authoritative.** A different deep-research run (different model, different prompt, different day) would produce overlapping but not identical output.
- **Not citable as ledgr policy.** The synthesis is the binding artifact. The research file is what informed the synthesis author's design space, nothing more.
- **Not user-facing.** Do not link to these from README.Rmd, pkgdown, vignettes, or any other surface a ledgr user would discover.

## Citation format limitation

The `citeturnXsearchY` references and rendered `turnXsearchY` /
`turnXviewY` citation markers in these files are ChatGPT Deep Research's
internal turn-based source markers. They do not resolve to URLs and cannot be
clicked through. They tie to real sources the model retrieved, but verification
requires either querying the same session or independently finding the cited
work.

For any claim that becomes load-bearing in a synthesis, look up the primary source yourself. Do not treat the deep-research model as a quote-precise oracle.

## Current files

| File | Fed which RFC seed | Durable artifact |
|---|---|---|
| `Walk-Forward.md` | `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_seed.md` | `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` |
| `Transaction-Cost-Models.md` | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_seed.md` | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md` |
| `Validation-Toolkit.md` | `inst/design/rfc/rfc_validation_toolkit_v0_1_9_x_seed.md` (seed v1 authored 2026-06-11; cycle opened on the recorded trigger after v0.1.9.4 closed; bundling rationale in the 2026-06-07 horizon entry "Validation toolkit -- bundling selection-integrity diagnostics with the business-objective constructor under an adapter-first posture"). | Pending (synthesis not yet written; response stage next). |
| `Reproducible-Leakage-Safe-ML.md` | Informs the 2026-06-14 horizon entry "General ML-strategy preparedness (QRF ranking as the motivating spike)"; the dedicated ML-architecture RFC is parked at v0.2.x and not yet opened. | Pending (conducted ahead of the RFC cycle to seed the architectural requirements; synthesis deferred to v0.2.x). |
| `Stable-Parameter-Region-Detection.md` | Ad-hoc input resolving the `ledgr_objective_stable_region()` detector methodology that `rfc_validation_toolkit_v0_1_9_x_synthesis.md` section 4.1 left as a spec-cut open question (not a new RFC cycle). | Pending (the v0.1.9.7 spec packet's `stable_region` detector spike). |
| `Cross-Asset-Accounting-Critical-Events.md` | Informs the 2026-06-28 horizon entry "Cross-asset accounting-critical economic events"; the corporate-actions / instrument-master and explicit accounting-critical event-types RFCs are parked at v0.2.x and not yet opened. | Pending (conducted ahead of the RFC cycles after vendor-ingestion work surfaced LFB-001; synthesis deferred to v0.2.x). |
| `ledgr_ragged_universe_prior_art_review.md` | Informs the 2026-09-06 horizon entry "Ragged-universe prior art and RFC evidence handoff" and the future ragged-universe / asset-lifetime RFC. No seed has been opened. | Pending (source-based prior-art input; the future RFC must re-verify any load-bearing claim and run the proposed empirical spike). |
| `rfc-evidence-handoff.md` | Companion empirical handoff for the same future ragged-universe / asset-lifetime RFC. It records the vendor-ingestion pressure result, dense control result, lineage boundary, and unresolved architecture questions without choosing a design. | Pending (evidence handoff only; future seed and synthesis not yet written). |

`Reproducible-Leakage-Safe-ML.md` was conducted ahead of its RFC cycle to inform the parked horizon seed rather than at stage 1 of an open cycle; when the v0.2.x ML-architecture RFC opens, its seed should cite this file by path per the normal convention.

`Stable-Parameter-Region-Detection.md` was conducted ad hoc to resolve a spec-cut open question inside the already-accepted validation-toolkit synthesis (section 4.1), not at stage 1 of a new cycle. It feeds the v0.1.9.7 `stable_region` detector spike; the binding artifact is that spike's accepted design, not this file. Per this directory's policy the file is preserved indefinitely and is not promoted to a user-facing surface.

`Cross-Asset-Accounting-Critical-Events.md` was conducted ahead of the
v0.2.x data/accounting RFC cycles after vendor-ingestion feedback identified
the missing dividend/distribution cashflow event. It feeds the parked
corporate-actions / instrument-master and explicit accounting-critical
event-types work; the binding artifact will be the future accepted synthesis,
not this file. Per this directory's policy the file is preserved indefinitely
and is not promoted to a user-facing surface.

`ledgr_ragged_universe_prior_art_review.md` and `rfc-evidence-handoff.md` are
paired inputs to the parked ragged-universe / asset-lifetime RFC. The first is
external prior-art research; the second is a concise handoff from empirical
vendor-ingestion and strategy-testing work. Neither is an RFC seed or accepted
architecture. The future seed must cite both, verify the handoff against its
source artifacts, and keep the current strict dense mode as the migration and
parity oracle unless a later accepted synthesis explicitly changes that rule.

When the next deep-research-informed RFC cycle opens, add a new file here and a new row to the table.

## Future research slots

The following filenames are reserved for future RFC cycles that are
anticipated by the roadmap or by recorded horizon entries. Listing them
here is a discoverability convention, not authorization to do the
research now. When a slot's RFC cycle opens, the seed author writes the
research file under the matching filename, runs the deep-research pass at
stage 1 of the cycle, and adds a row to the Current files table.

| Anticipated filename | Anticipated RFC cycle | Roadmap window |
|---|---|---|
| `Benchmark-Methodology.md` | Benchmark context RFC (archetypal / alternative indices / tracking portfolios / market observables) | v0.2.x |
| `Trade-Accounting-Definitions.md` | Multi-asset trade-definition RFC (flat-to-reduced vs increased-to-reduced for non-spot accounting) | v0.2.x |
| `Intraday-Pulse-Architecture.md` | Intraday-frequency RFC (sub-daily pulse, whole-second-preserved per the timestamp contract) | v0.2.x |
| `Hypothesis-Recording.md` | Structured sweep notes RFC (hypothesis identity surface per the 2026-06-07 horizon entry) | v0.2.x |
| `Portfolio-Optimization.md` | Portfolio optimization scaffolding RFC, Levels 3 / 4 per the 2026-06-07 horizon entry. Consumes the business-objective constructor from `Validation-Toolkit.md`. | v0.2.x+ |
| `Regime-Detection.md` | Regime detection RFC (Markov-switching / change-point models), if and when the topic is promoted from horizon to active scope | unscheduled |

When the deep-research pass for a slot is conducted, the prompt should
include an explicit "ecosystem citizenship" section: identify candidate
R adapter packages, verify current CRAN / GitHub maintenance status,
note licensing, and surface where adapter-first is preferable to
native implementation. The Validation-Toolkit slot is the explicit
exemplar of this convention -- its 2026-06-07 horizon entry binds the
adapter-first posture as a design stance, not just an implementation
shortcut.

Microstructure / L2 / HFT research slots are deliberately not reserved.
These topics are permanent non-goals per the whole-second timestamp
contract. If a future cycle needs market-microstructure context for a
non-execution purpose, write the file ad hoc rather than reserving a slot
here.

Slot reservation does not imply the RFC cycle will open at a specific
date or that the maintainer has committed to authoring it. The
methodology priors in `inst/design/methodology_references.md` already
cover several of these anticipated cycles' foundational citation needs;
the per-cycle research file picks up the front of the literature at the
time the cycle actually opens.

## Process placement

Per `inst/design/rfc_cycle.md`, the research input is stage 1 of the RFC cycle: optional, non-binding, fed to the seed. The seed and (later) the synthesis are the binding artifacts.

## Retention policy

Preserve indefinitely. These files are small, self-contained, and useful for future adjacent cycles (e.g., the selection-integrity diagnostics RFC will likely revisit material in `Walk-Forward.md`). There is no scheduled cleanup.

If a future RFC cycle re-researches the same topic with a different model, write a new file alongside the existing one rather than overwriting; the diff between two passes is itself useful evidence.
