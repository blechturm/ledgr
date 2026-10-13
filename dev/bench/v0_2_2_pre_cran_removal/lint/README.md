# Advisory lint baseline

This is the LDG-3023 advisory baseline from clean commit `05aa3efd`.

```text
Rscript --vanilla tools/run-advisory-lint.R \
  --output=dev/bench/v0_2_2_pre_cran_removal/lint \
  --source-commit=05aa3efd
```

The runner used `lintr` 3.4.0 and recorded `styler` 1.11.0 for the later
whole-tree formatting pass. It scanned 329 `.R` files under `R/`, `tests/`
and `tools/`. The exclusions in `.lintr` and `metadata.csv` name generated,
archived, vendored, library and local-evidence paths explicitly.

The baseline contains 726 style findings:

- 23 from `brace_linter`;
- 687 from `indentation_linter`;
- three from `infix_spaces_linter`; and
- 13 from `semicolon_linter`.

The remaining configured formatter-only linters found nothing. No formatter
was run and no package or test source was changed. A second complete pass at
the same commit produced byte-identical `findings.csv`, `summary.csv` and
`metadata.csv` records.

The CI job is separately named `Lint (advisory through LDG-3031)`. Its lint
step exposes findings through a nonzero step outcome and uploads this record
shape, but both the step and job are non-blocking. It has no dependency edge
to the package-check job and cannot replace or mask tests, checks or coverage.

## Failure sensitivity

A scratch root containing `f<-function(x){x+1}; f(1)` produced seven findings.
Normal advisory mode exited zero; `--fail-on-findings=true` exited one after
writing the same record. This is the CI signal that stays advisory until
LDG-3032 removes the continuation and applies the separately reviewed style
pass.
