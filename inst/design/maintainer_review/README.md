# Maintainer Review Notes

Status: Internal maintainer workspace.  
Authority: Review aid only; not a package contract, spec, ADR, or user-facing
article.

This directory holds executable or semi-executable notebooks for maintainer code
reviews of load-bearing paths. The goal is not to generate polished
documentation first. The goal is to preserve direct ownership of the code paths
that specs and agent-written patches depend on.

Current notebooks:

- `feature_value_path_workbook.qmd` - trace how a declared feature becomes a value
  returned by `ctx$feature()` inside a strategy.
- `fold_core_workbook.qmd` - grounded trace of `R/fold-core.R`: the shared
  execution engine, the data structures it consumes and produces, the
  event-to-derived-view reconstruction, and the reserved insertion points for
  the v0.1.9 risk layer, intraday fill timing, the public cost API, and OMS.

Review workflow:

1. Open the notebook.
2. Run or copy the search commands.
3. Read the code yourself.
4. Fill the "maintainer notes" sections in rough language.
5. Let an agent clean up your notes only after you have written the first-pass
   explanation.

Do not treat these notebooks as installed vignettes. They are intentionally
inside `inst/design/` rather than `vignettes/`.
