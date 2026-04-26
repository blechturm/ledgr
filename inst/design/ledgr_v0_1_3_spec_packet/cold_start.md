# ledgr v0.1.3 Cold-Start Verification

This is the release-gate sequence for a fresh checkout on a machine with R and
system build tools already installed.

Run from the repository root.

On Windows, install the Rtools version matching your R release before running
the `rcmdcheck` gate. The plain `R CMD check` path can work for this pure-R
package without Rtools, but `rcmdcheck` checks for build tools first.

Pandoc is required for the pkgdown gate.

## 1. Install Check Dependencies

```r
install.packages(c(
  "rcmdcheck",
  "pkgdown",
  "covr",
  "pkgload",
  "testthat",
  "knitr",
  "rmarkdown",
  "ggplot2",
  "gridExtra",
  "microbenchmark",
  "nanotime",
  "TTR",
  "withr",
  "quantmod",
  "xts",
  "zoo",
  "DT",
  "htmltools"
), repos = "https://cloud.r-project.org")
```

## 2. Run The README Cold-Start Check

```sh
R --vanilla -f tools/check-readme-example.R
```

This installs the current checkout into a temporary library, executes the
executable `README.Rmd` chunks, and verifies the README determinism check.

## 3. Run Acceptance Tests

```sh
Rscript -e "pkgload::load_all('.', quiet = TRUE); testthat::test_local('.', filter = 'acceptance-v0.1', reporter = 'summary', load_package = 'none')"
```

## 4. Run Package Check

```sh
Rscript -e "rcmdcheck::rcmdcheck(args = c('--no-manual', '--no-build-vignettes'), error_on = 'warning', check_dir = 'check')"
```

## 5. Build The pkgdown Site

```sh
Rscript -e "pkgdown::build_site(new_process = FALSE, install = FALSE)"
```

The deployment workflow is `.github/workflows/pkgdown.yaml`. It publishes to
GitHub Pages after the repository is public and GitHub Pages is configured with
source **GitHub Actions**.

## 6. Run Coverage Gate

```sh
Rscript tools/check-coverage.R
```

The coverage threshold defaults to 80 percent and can be overridden with
`LEDGR_COVERAGE_THRESHOLD`.
