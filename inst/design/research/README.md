# Research inputs to RFC seeds

This directory holds deep-research LLM outputs that were fed to RFC seeds as design-space context. Each file corresponds to one RFC cycle.

**Status:** non-binding inputs. Preserve indefinitely as audit trail. Do not promote to a user-facing docs surface.

---

## What these files are

For each RFC cycle that needed broad prior-art coverage, the maintainer prompted a deep-research LLM (typically ChatGPT Deep Research) with a structured request: literature foundations, competitor implementations, design-pattern survey, ledgr-specific design questions, plus a "strongest single influence" verdict. The model produced a single dense markdown document. That document is what lives here.

These artifacts informed the seed RFC. The seed cites the file by path. The synthesis lifts whichever framings and references it found load-bearing.

## What these files are NOT

- **Not canonical literature reviews.** One model's pass through the literature, with citation precision that varies. Some treatments are cursory; some are misattributed in subtle ways; cross-check against primary sources before quoting in a binding artifact.
- **Not authoritative.** A different deep-research run (different model, different prompt, different day) would produce overlapping but not identical output.
- **Not citable as ledgr policy.** The synthesis is the binding artifact. The research file is what informed the synthesis author's design space, nothing more.
- **Not user-facing.** Do not link to these from README.Rmd, pkgdown, vignettes, or any other surface a ledgr user would discover.

## Citation format limitation

The `citeturnXsearchY` references in these files are ChatGPT Deep Research's internal turn-based source markers. They do not resolve to URLs and cannot be clicked through. They tie to real sources the model retrieved, but verification requires either querying the same session or independently finding the cited work.

For any claim that becomes load-bearing in a synthesis, look up the primary source yourself. Do not treat the deep-research model as a quote-precise oracle.

## Current files

| File | Fed which RFC seed | Durable artifact |
|---|---|---|
| `Walk-Forward.md` | `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_seed.md` | `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` |
| `Transaction-Cost-Models.md` | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_seed.md` | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md` |
| `Validation-Toolkit.md` | `inst/design/rfc/rfc_validation_toolkit_v0_1_9_x_seed.md` (seed v1 authored 2026-06-11; cycle opened on the recorded trigger after v0.1.9.4 closed; bundling rationale in the 2026-06-07 horizon entry "Validation toolkit -- bundling selection-integrity diagnostics with the business-objective constructor under an adapter-first posture"). | Pending (synthesis not yet written; response stage next). |
| `Reproducible-Leakage-Safe-ML.md` | Informs the 2026-06-14 horizon entry "General ML-strategy preparedness (QRF ranking as the motivating spike)"; the dedicated ML-architecture RFC is parked at v0.2.x and not yet opened. | Pending (conducted ahead of the RFC cycle to seed the architectural requirements; synthesis deferred to v0.2.x). |

`Reproducible-Leakage-Safe-ML.md` was conducted ahead of its RFC cycle to inform the parked horizon seed rather than at stage 1 of an open cycle; when the v0.2.x ML-architecture RFC opens, its seed should cite this file by path per the normal convention.

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
