# WS41 second-correction profile records

Tree: the uncommitted second correction on `38219a66`, identified by the
SHA-256 prefix `7cd738aaf3d0d12e` of `git diff 38219a66 -- R tests`. Replace
that label with the correction commit when it lands.

## Host condition

All records here were measured while the maintainer reported the host as
busy. A Defender performance recording during the same session attributed
most real-time scanning to an open DAW session (Nuendo) and ASUS Armoury
Crate log churn, not to R. These timings are therefore neither a pass nor a
miss of the 112-second fast gate, and they are not evidence for or against a
product regression. The fast-profile gate needs a rerun on a quiet host.

## Fast profile (this directory)

All three runs execute 565 of 565 registered blocks at 137.94, 131.57 and
132.77 seconds. Each run records the same two blocks with status `warning`:
LTB-0154 and LTB-0182 in `test-long-window-regression-control.R`. Both scan
every file under `tests/` and `.github/workflows` as text and run a
release-only script under `suppressWarnings()`; neither exercises the changed
code. The census records only the status, not the warning text. The
registered gate checker therefore reports these runs as non-passing, and they
are retained as such.

`../ws41_second_correction_fast_diagnostic/` holds one later full fast pass
with complete reporter output captured: 565 of 565 blocks pass with no
warning, at 176.03 seconds on the still-loaded host. Before that pass an
untracked `tests/testthat/_problems/` directory, left by an earlier failing
full-suite run during the correction, was removed. Whether it, or another
transient file under `tests/`, caused the warnings could not be established.

## Review and heavy profiles

`../ws41_second_correction_review/`: 357 of 357 blocks, one pre-existing
optional-package skip, no failure, 389.11 seconds.
`../ws41_second_correction_heavy/`: 192 of 192 blocks, no failure or skip,
255.08 seconds. Both timings are host-loaded as above.

Commands:

```text
Rscript --vanilla tools/run-test-profile.R --profile=fast --mode=ordinary --records=<dir> --run-index=<1|2|3>
Rscript --vanilla tools/check-test-gate.R --profile=fast --mode=ordinary --records=<dir>
Rscript --vanilla tools/run-test-profile.R --profile=review --mode=ordinary --records=<dir> --run-index=1
Rscript --vanilla tools/run-test-profile.R --profile=heavy_protocol --mode=ordinary --records=<dir> --run-index=1
```
