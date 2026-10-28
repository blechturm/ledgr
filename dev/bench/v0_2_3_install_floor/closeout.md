# M4 closeout: measured minimum-environment manifest

**Outcome: green.** Brief Section 2 asks for the oldest coherent CRAN
environment that satisfies ledgr's declared requirements and on which ledgr
installs and passes its floor checks. That environment is P3M CRAN snapshot
`2026-10-24`, 108 packages, and every floor check exited 0 in it. No stop
condition in brief Section 5 fired.

## What ran (Windows 11, R 4.6.1, Rtools45 GCC 14.2.0)

1. `find_snapshot.R` read the floors from `DESCRIPTION`. It then binary-searched
   P3M's 174 snapshots from 2026-04-25 onward (R 4.6.0 was released
   2026-04-24), one floor at a time, and evaluated the joint minimum and the
   snapshot before it (`snapshot_search.csv`). The first snapshots that meet
   each floor are yyjsonr 0.1.22 on 2026-04-25, collapse 2.1.8 on 2026-08-31
   and duckdb 2.0.0 on 2026-10-24. 2026-10-24 passes and 2026-10-23
   (duckdb 1.5.6) fails, so the DuckDB floor alone sets the date. The dates
   match CRAN's publication times for those versions.
2. `build_library.R --snapshot=2026-10-24` resolved the closure of ledgr's
   Imports and LinkingTo over Depends, Imports and LinkingTo, with each
   version taken from that snapshot's source index. It then resolved the
   Suggests closure the same way. The result is `manifest.csv`: 8 `import`,
   1 `linking_to`, 9 `transitive` and 90 `check_only` packages. It checked
   all 216 version constraints inside the set, plus every `R (>= x)`
   requirement against R 4.6.0. None is unmet (`coherence.csv`). It then
   installed into `C:/Users/maxth/ledgr-wt/m4-libs/lib-min`: 105 Windows
   binaries and 3 source builds.
3. `run_floor_checks.R` ran four steps, with R_LIBS set to that library and
   the user and site libraries pointed at a path that does not exist
   (`floor_checks.csv`, full output in `floor_checks.log`):

| Step | Command | Exit |
| --- | --- | --- |
| 0 | child `.libPaths()` = `lib-min`, `R-4.6.1/library` | 0 |
| 1 | `R CMD INSTALL --preclean -l <lib-min> .` (compiles `src/`) | 0 |
| 2 | `Rscript --vanilla tools/run-test-profile.R --profile=fast --mode=ordinary` | 0 |
| 3 | `Rscript --vanilla tools/check-readme-example.R` | 0 |

   In step 2, all 578 blocks executed, none was skipped and none failed
   (`fast_profile_summary.csv`, testthat 3.3.2).
4. `verify.R` passes on `lib-min`. `gut_verify.R` changes duckdb from 2.0.0
   to 1.5.6 in a copy of the manifest, and `verify.R` exits 1 with one
   difference (`verify_gut.csv`). It also caught a real defect. The first
   build reported success while three packages were missing; `verify.R`
   exits 1 on that library (`m4-libs/lib`), naming codetools, lattice and
   MASS.

## What was learned about the package and its environment

- The minimum environment is effectively current CRAN. The DuckDB 2.0.0 floor
  (2026-10-23) is four days before this measurement, so "minimum" and
  "current" share almost every version. As a result, G3 adds little test
  coverage until the snapshot falls behind current CRAN.
- P3M's Windows index lists recommended packages (codetools, lattice, MASS)
  under `4.6.2/Recommended/`, and those downloads return 404 for this
  snapshot. `install.packages()` only warns about this and does not fail. The
  builder now installs those packages from the snapshot's source tarball, and
  it fails if any installed version differs from the manifest. G3 needs the
  same fail-closed check, which is what `verify.R` provides.
- codetools 0.2-20 is a recommended package bundled with R. The manifest pins
  it in the library anyway, so the library's copy shadows the one in
  `.Library`.
- The test control plane calls unexported testthat internals
  (`testthat:::test_files_setup_env` and others). It was proven with
  testthat 3.3.2 only; the declared Suggests floor `testthat (>= 3.0.0)` is
  untested.

## What the WS13 cut may consume

- `manifest.csv` (exact versions and sources) and `verify.R` (fails closed on
  missing, different or extra packages), to restore and gate G3.
- `proposed_description_floors.md`: the `DESCRIPTION` diff for codetools,
  DBI, digest, rlang, tibble and cpp11, with the reason for each.

## Platform caveats (Windows proof versus Ubuntu G3)

What carries over is everything that does not depend on the platform: the
snapshot date, the package set, the versions, the coherence check, and the
source URLs. What does not carry over is everything platform-specific:
binaries (P3M builds Linux binaries separately, at
`https://packagemanager.posit.co/cran/__linux__/<distro>/2026-10-24`), system
libraries (for example libcurl and libssl for the `check_only` curl, openssl
and httr), the compiler (GCC on Ubuntu instead of Rtools45), and the 404 on
recommended packages, which is specific to Windows. `build_library.R` is
proven on Windows only. On Linux it would build every package from source
unless the repository URL is changed to the `__linux__` form.

## Open points for the WS13 cut

1. **R version.** This proof ran on R 4.6.1, not on the declared floor R 4.6.0.
   G3 should run R 4.6.0 to test the R floor itself.
2. **Ubuntu.** G3 must re-prove installation (Linux binaries or source builds,
   system libraries) and all three floor checks on Ubuntu with this manifest.
3. **Suggests scope.** The ordinary profile ran with all Suggests present,
   matching CI's ordinary lane, which accounts for the 90 `check_only`
   packages. Whether G3 should also run the CRAN-mode profile in this
   environment is undecided.
4. **The snapshot will become stale relative to current CRAN.** Decide whether
   G3's manifest is regenerated when a floor changes and nothing else. The
   brief's rule is that the date is provenance, not identity.
5. **Timing is not evidence.** The fast profile took 140.9 s against the
   112 s advisory bound (`GATE_HINT exceeded=true`). The machine was shared
   with another R job, and timing is not part of the floor check.
6. **Cleanup.** `C:/Users/maxth/ledgr-wt/m4-libs/lib` is the partial first
   build, kept as the real-world `verify.R` failure. It is safe to delete.

## Reproduce

```text
Rscript --vanilla dev/bench/v0_2_3_install_floor/find_snapshot.R
Rscript --vanilla dev/bench/v0_2_3_install_floor/build_library.R --snapshot=2026-10-24 --lib=<new lib>
Rscript --vanilla dev/bench/v0_2_3_install_floor/verify.R --lib=<new lib>
Rscript --vanilla dev/bench/v0_2_3_install_floor/run_floor_checks.R --lib=<new lib>
Rscript --vanilla dev/bench/v0_2_3_install_floor/gut_verify.R --lib=<new lib>
```
