# Advisory lint baseline

This is the corrected LDG-3023 advisory baseline from clean commit
`a8416492`.

```text
Rscript --vanilla tools/run-advisory-lint.R \
  --output=dev/bench/v0_2_2_pre_cran_removal/lint \
  --source-commit=a8416492
```

The runner used `lintr` 3.4.0 and recorded `styler` 1.11.0 for the later
whole-tree formatting pass. It scanned 329 `.R` files under `R/`, `tests/`
and `tools/`. The exclusions in `.lintr` and `metadata.csv` name generated,
archived, vendored, library and local-evidence paths explicitly.

The baseline contains 39 style findings:

- 23 from `brace_linter`;
- three from `infix_spaces_linter`; and
- 13 from `semicolon_linter`.

The remaining configured formatter-only linters found nothing.
`indentation_linter` is deliberately absent: on a styled whole-tree copy it
retained 327 disagreements with styler's multiline-condition layout. On a
fresh scratch copy, one styler 1.11.0 pass over the 18 files containing the
39 actionable findings, with `include_roxygen_examples = FALSE`, reduced the
full 329-file lint record to zero. No formatter was run on the package tree.
A second complete baseline pass produced byte-identical records.

The CI job is separately named `Lint (advisory through LDG-3031)`. It pins
lintr 3.4.0 and styler 1.11.0. The tool step exits zero when findings exist;
a separate classification step reports findings with exit 1 and a tool error
with exit 2. Both remain non-blocking. The job has no dependency edge to the
package-check job and cannot replace or mask tests, checks or coverage.

## Failure sensitivity

A scratch root containing `f<-function(x){x+1}; f(1)` produced seven findings.
Normal advisory mode exited zero; `--fail-on-findings=true` exited one after
writing the same record. A clean-commit run also refuses a source hash that
does not resolve to clean `HEAD`. LDG-3032 removes the continuation and runs
styler with roxygen examples disabled unless roxygen2 is installed.
