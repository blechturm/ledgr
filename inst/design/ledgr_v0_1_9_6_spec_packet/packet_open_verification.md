# v0.1.9.6 Packet-Open Verification

Status: Batch 1 complete after Claude review.
Date: 2026-06-14
Ticket: LDG-2646

## Purpose

This note closes the packet-open verification gate before v0.1.9.6 validation
implementation starts. It records current package facts, optional dependency
posture, and the Methodological Diagnostics gate.

## Package Facts

Sources were checked against official CRAN package pages and reference manuals
on 2026-06-14. These facts are implementation inputs for v0.1.9.6, not
permanent authority for later packets.

| Package | Current CRAN facts | API / usage relevance | ledgr disposition |
| --- | --- | --- | --- |
| PerformanceAnalytics | Version 2.1.0, published 2026-04-11, license GPL-2 or GPL-3, needs compilation, depends on `xts >= 0.10.0`, imports `methods`, `quadprog`, and `zoo`. Source: <https://CRAN.R-project.org/package=PerformanceAnalytics>. | Reference/reporting package for return, risk, and performance analysis. Its own description says it is primarily tested on return data. | Already in ledgr `Suggests`. Keep optional. Do not import in `NAMESPACE`. Suitable first reporting/evidence adapter family after ledgr return projections exist. |
| xts | Version 0.14.2, published 2026-02-28, license GPL >= 2, needs compilation, depends on `zoo >= 1.7-12`, imports `methods`, links to `zoo`. Source: <https://CRAN.R-project.org/package=xts>. | Time-series projection class. Relevant API surface is `xts()` / `as.xts()` style construction over ordered return matrices with POSIXct index. | Already in ledgr `Suggests`. Keep optional. Use only behind package-availability checks. Matrix/data-frame projections remain the package-free baseline. |
| RPESE | Version 1.2.7, published 2026-01-08, license GPL >= 2, no compilation, imports `xts`, `zoo`, `boot`, `RPEIF`, `RPEGLMEN`, and `RobStatTM`. Source: <https://CRAN.R-project.org/package=RPESE>. | Estimates standard errors for risk and performance measures. Relevant as a later optional diagnostic adapter, not as a substrate requirement. | Not currently in ledgr `Suggests`. Do not add in Batch 1. Revisit only if a later ticket implements an RPESE-backed adapter and accepts its dependency fan-in. |
| pbo | Version 1.3.5, published 2022-05-26, license MIT + file LICENSE, no compilation, imports `utils`, `lattice`, `latticeExtra`, and `foreach`. Source: <https://CRAN.R-project.org/package=pbo>. | The reference manual exposes `pbo(m, s = 4, f = NA, threshold = 0, inf_sub = 6, allow_parallel = FALSE)`, where `m` is a `T x N` returns data frame and `s` must evenly divide rows. It computes PBO, performance degradation, probability of loss, and stochastic dominance following Bailey et al. Source: <https://cran.r-project.org/web/packages/pbo/pbo.pdf>. | Not currently in ledgr `Suggests`. Do not add in Batch 1. LDG-2650 must decide adapter-vs-native and whether adding `pbo` to `Suggests` is justified. |

## Dependency Posture

Current ledgr `DESCRIPTION` already lists `PerformanceAnalytics` and `xts` in
`Suggests`. It does not list `RPESE` or `pbo`.

Current `NAMESPACE` contains no imports or S3 registrations for
`PerformanceAnalytics`, `xts`, `RPESE`, or `pbo`.

Batch 1 decision:

- no optional package moves to `Imports`;
- no `NAMESPACE` import is added;
- `PerformanceAnalytics` and `xts` remain optional candidates already present
  in `Suggests`;
- `RPESE` and `pbo` remain unlisted until a later ticket provides a concrete
  adapter need and review accepts the dependency surface;
- matrix/data-frame return projections remain the package-free baseline;
- package-backed paths must skip cleanly when optional packages are absent.

## Methodological Diagnostics Gate

The Methodological Diagnostics rule is present in
`inst/design/vignette_styleguide.md` and locked by
`tests/testthat/test-documentation-contracts.R`.

The current doc-contract test verifies the rule itself and does not assert on
future validation articles. Per-method assertions must land with the method
article or section they cover.

Required verification command:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-documentation-contracts.R', reporter='summary')"
```

Result on 2026-06-14: documentation-contracts completed with all assertions
passing.

## Batch 1 Decision

Batch 1 unlocks Batch 2 implementation. It does not authorize:

- public PBO/CSCV implementation;
- RPESE-backed diagnostics;
- adding `pbo` or `RPESE` to `Suggests`;
- adding optional-package imports;
- validation-method documentation without per-article doc-contract assertions.
