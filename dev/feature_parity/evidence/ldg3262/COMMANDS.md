# LDG-3262 evidence: the internal debug flag

Code at 015546c3 (branch ws44, from release/v0.2.3 0ef76b77, which is the
workstream-43 close 2dee0f98 plus one macro-plan line).

## The flag

`R/debug.R`: `.ledgr_debug_state` (package-local environment, `on = FALSE`),
read by `ledgr_debug()`, set only by `local_ledgr_debug(on, frame =
parent.frame())`, which registers its restore with `on.exit(add = TRUE,
after = FALSE)` in `frame`, so nested settings unwind last in, first out to
the outermost prior value on normal or error exit. Neither function is
exported; neither reads an option or environment variable.

Witness: `tests/testthat/test-debug-flag.R` (default off as the setup file
found it, suite on, normal/error/nested restore, invalid values refused, no
public surface).

    Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-debug-flag.R', reporter='summary', load_package='none')"
    -> debug-flag: ................... DONE, 0 failures

## The suite and the tools

- `tests/testthat/setup-debug.R` turns the flag on for the suite. testthat
  sources setup files inside `eval()`, whose exit would restore at once (a
  first version as a helper file did exactly that and the witness caught
  it); the setter is given `testthat::teardown_env()`, which is no function
  frame, so the flag stays on until the test process ends.
- `dev/feature_parity/runner.R` requires `--debug=0|1`, sets the flag
  through the setter for the whole run (checked: the setter holds inside the
  runner's `local()` block and restores after it) and records `debug` in
  `provenance.csv`; an arm without the flag (the pin, the cut base) accepts
  only 0. Without `--debug` the runner stops with its usage line.
- `dev/feature_parity/faults.R` passes `--debug=0` (its arms are the pin).
- `dev/feature_parity/identity.R` takes `--debug=0|1` (default 0).
- The cut24-feature-1 workloads and `dev/bench/v0_2_3_cut24_feature/memory.R`
  already call `local_ledgr_debug(value, frame =)` (frozen in LDG-3258).

## Where sweep preparation runs

`R/sweep.R:279` prepares the sweep's features in the calling process
(`ledgr_history_precompute_payload()`), builds the projection and only then
stages workers; workers (`R/parallel-workers.R`, `ledgr_parallel_worker_setup`)
load ledgr and the declared packages and receive the staged projection.
Runs (`R/backtest-runner.R:668`), explicit precompute
(`R/precompute-features.R:91`) and pulse inspection
(`R/pulse-snapshot.R:395`) prepare in the calling process too. No
preparation runs on a mirai worker, so the flag is not forwarded.

## Identities with debug on and off

    Rscript dev/feature_parity/install_arm.R --repo=C:/Users/maxth/ledgr-wt/ws44 --commit=015546c3 --lib=C:/Users/maxth/ledgr-wt/cut24-scratch/libs/ldg3262-015546c3
    Rscript dev/feature_parity/identity.R --lib=<that library> --out=<scratch>/identity-debug0 --save-store=1 --debug=0
    Rscript dev/feature_parity/identity.R --lib=<that library> --out=<scratch>/identity-debug1 --old=<scratch>/identity-debug0 --debug=1
    Rscript dev/feature_parity/identity_check.R --base=<scratch>/identity-debug0 --candidate=<scratch>/identity-debug1 --mode=unchanged-engine --engine-prefix=88b4237e

Result (`identity_check_debug.txt`; the two records are
`identities_debug0.csv` and `identities_debug1.csv`): 156 of 156 expected
identities equal, engine version 88b4237e on both, the debug-off arm's
explicit precompute reused by the debug-on arm with the same result table as
fresh preparation, the stored run and sweep readable. IDENTITY CHECK PASS.
The flag is bound by no identity; LDG-3266 repeats this on the final code.
