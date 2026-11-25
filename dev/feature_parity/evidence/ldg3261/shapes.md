# LDG-3261: the seven optimization shapes on the changed code

Walked against inst/design/manual/optimization_coding_style.qmd, "The Seven
Shapes And Their Replacements". Changed production code (R/ at 9ac80163,
equal at the final commit, against the cut base ea580bc6): the new
R/feature-adapters.R; the two adapter descriptions appended to
R/indicator-builtins.R and R/indicator-ttr.R; certification, its candidate
list and the segment dispatch in R/history-features.R; the catalogue rows
(R/indicator-history.R), the source values (R/indicator.R,
R/feature-inspection.R), the parameter registry (R/feature-parameters.R),
dependency provenance (R/strategy-provenance.R) and the engine version's bind
list (R/features-engine.R).

Where the changed code runs and on what collection:
- `ledgr_feature_adapters()` builds two small lists of function references.
  It is called per certified definition (certify, candidates), per indicator
  construction (source validation), once per engine-version computation,
  once per parameter-registry or provenance read, and once per R session for
  the catalogue (the existing catalogue cache). These are collections that
  grow with definitions and constructors, not with bars, fact rows,
  instruments x pulses, events, diagnostics or candidates.
- The segment dispatch runs once per (instrument, knowledge range,
  definition, segment), as before: `ledgr_history_feature_segment()` now
  calls the certified adapter's `segment` (one function call) where it ran an
  if-chain on `cert$kind`; the per-segment work inside is unchanged.

1. One-row frame per element, bound at the end: none added. The catalogue
   was and is one `data.frame` per row bound with `do.call(rbind)`, once per
   session behind the cache; its rows only moved into the adapters.
2. Full-table subset inside a loop over ids: none.
3. Per-element parsing or formatting where a vectorised call exists: none
   added. Width discovery per definition is unchanged code moved into the
   ledgr adapter.
4. Per-row JSON on repetitive strings: none added. The TTR raw-call key's
   `canonical_json()` per certified definition is unchanged code moved into
   the TTR adapter.
5. Work computed and discarded, or recomputed on every call: the adapter list
   is rebuilt on each call instead of being cached. It holds no computed
   value (only function references and constant vectors) and is called per
   definition or constructor, not per bar; caching it would add a mutable
   session state the synthesis rules out (no mutable hooks). Certification
   still constructs every candidate eagerly: lazy construction was measured
   and gave no saving (LDG-3260), so it was reverted.
6. Quadratic validators: none.
7. Scalar writes into an environment-held vector: none.

Helper criterion: the new helpers are the registry, the source-value list,
the general segment path (split out of the old dispatcher unchanged) and four
or five named members per adapter, each bound by the engine version through
its adapter's `bind` and proved by the census. No new loop over a growing
collection.
