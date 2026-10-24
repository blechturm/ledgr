# Workstream 57 close review

**Mode:** Type 1, independent clean-context close review  
**Range:** `ee7fc5d3..40137092`  
**Verdict:** `CHANGES_REQUIRED`

The accepted rectangular-grid design is necessary and sufficient; no Type 2
decision is required. Public probes confirmed the primitive boundary, early
refusals, save/reopen behavior, candidate identity, promotion, namespace
separation and removal of the old constructor. Six correction items remain.

1. **Two-dimensional parity detector.** LTB-0494 varied only one dimension,
   so `tidyr::crossing()` and `ledgr_strategy_grid()` happened to return the
   same order. Both established orders are valid. The detector must vary two
   dimensions, pin each form's authored order and compare corresponding
   candidates by identity. Durable payload parity excludes only the deliberate
   `candidate_row` difference.
2. **Print namespace detector.** LTB-0495 found both headers and values but did
   not bind a value to its namespace. Swapping strategy and feature summaries
   passed. Live, reopened, candidate and review output must pin exact
   candidate-to-namespace mappings at narrow and ordinary widths.
3. **Structured feature-grid wording.** The contract and closeout said only
   `ledgr_grid_cross()` could introduce feature parameters, but the retained
   `ledgr_grid_named()` surface can do so explicitly. The statement must be
   narrowed to direct rectangular and `ledgr_strategy_grid()` inputs.
4. **Repeated canonical validation.** Instrumenting a two-row rectangular
   normalization counted ten `canonical_json()` calls. The already validated
   rows must pass into executable-grid construction without repeated
   validation, with a count-sensitive detector.
5. **Obsolete conditions.** `ledgr_invalid_param_grid` and
   `ledgr_duplicate_param_grid_labels` remain documented even though the
   removed constructor has no throwing call site. Remove their descriptions,
   aliases and unused helper default.
6. **Diff record.** The closeout itself introduced a blank line at EOF, so the
   recorded clean `git diff --check` result must be made true.

The review found no defect in the implemented primitive restrictions, row-name
independence, zero-column candidate, duplicate/refusal boundaries, strategy
versus feature separation, saved primitive types, promotion identity, current
printing behavior, degraded-tibble fallback or compatibility-surface removal.
The focused correction review should mutate the ordering, namespace swap,
repeated validation and retired-condition boundaries.
