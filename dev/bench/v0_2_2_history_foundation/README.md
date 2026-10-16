# Workstream 40 verification record

This directory records the bounded public verification for Cut 16 Workstream
40 at implementation commit `80c86012`.

## Test profiles

`evidence/fast_profile/` contains three ordinary fast-profile runs made one at
a time on the quiet post-reboot host. All 565 registered blocks passed in
112.02, 110.50 and 107.41 seconds. `gate-record.csv` records the 110.50-second
median against the unchanged 112-second bound and passes.

`evidence/review_profile/` contains the ordinary review-profile run. All 353
registered blocks executed with no failure; the one skip is the pre-existing
optional-package path. Elapsed time was 396.39 seconds.

The focused history-foundation and codebase-contract suites were repeated
after the implementation commit was prepared. They passed 88 and 16
expectations respectively. The source-derived codebase census also passed in
check mode after adding history policy to the current-only version families.

## Package check

The package was built and the resulting tarball was checked with R 4.6.1:

```text
R CMD build .
R CMD check --no-manual --no-build-vignettes ledgr_0.2.1.0.tar.gz
```

Code, tests, examples and vignette execution passed. The two warnings are the
expected consequence of `--no-build-vignettes`: source vignettes exist while
`inst/doc` is absent. There was no code, test or Rd warning.

## Platform boundary

The rule-4 golden-root block passes locally on Windows. The dedicated workflow
step was renamed from rule 3 to rule 4 in this workstream. Ubuntu reproduction
requires the first hosted run of the committed branch and is not claimed by
this local record.
