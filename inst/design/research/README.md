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

When the next deep-research-informed RFC cycle opens, add a new file here and a new row to the table.

## Process placement

Per `inst/design/rfc_cycle.md`, the research input is stage 1 of the RFC cycle: optional, non-binding, fed to the seed. The seed and (later) the synthesis are the binding artifacts.

## Retention policy

Preserve indefinitely. These files are small, self-contained, and useful for future adjacent cycles (e.g., the selection-integrity diagnostics RFC will likely revisit material in `Walk-Forward.md`). There is no scheduled cleanup.

If a future RFC cycle re-researches the same topic with a different model, write a new file alongside the existing one rather than overwriting; the diff between two passes is itself useful evidence.
