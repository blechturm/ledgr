# M4 brief: measured minimum-environment manifest

**Brief drafted by Claude, 2026-10-28; the maintainer authorized running it
the same day.** Measurement step M4 of the accepted
[v0.2.3 macro plan](macro_plan.md) (WS13), under
`inst/design/spike_protocol.md`. It implements the input that the accepted
[release-candidate synthesis](../rfc/rfc_release_candidate_ci_evidence_v0_2_3_synthesis.md)
D4 requires before the minimum-dependency CI lane (G3) can exist.

## 1. Why

v0.2.2's release found its dependency floors late: local Ubuntu could not
supply the declared R and DuckDB floors, and DuckDB 2.0.0 reached CI while a
catalogue still named 1.5.6. D4 binds a complete, exact minimum environment
that G3 installs and checks, instead of guessing one from `DESCRIPTION`.
Today only `collapse (>= 2.1.8)`, `duckdb (>= 2.0.0)` and
`yyjsonr (>= 0.1.22)` carry floors; `codetools`, `DBI`, `digest`, `rlang`,
`tibble` and `cpp11` (LinkingTo) do not, and transitive dependencies are not
listed anywhere. R itself is `>= 4.6.0`.

## 2. Question

What is the oldest coherent CRAN environment that satisfies ledgr's declared
requirements, on which ledgr installs and passes its floor checks, recorded
as an exact manifest that G3 can restore?

## 3. Method (propose a better one in the closeout if you find it)

1. **Minimum coherent snapshot.** Find the earliest Posit Package Manager
   (P3M) dated CRAN snapshot, on or after the R 4.6.0 release date, in which
   every declared `DESCRIPTION` floor is satisfied. All direct and transitive
   versions come from that one snapshot, so the set is coherent by
   construction. Record the date as provenance, not as identity.
2. **Floors for unfloored dependencies.** The snapshot's versions of
   `codetools`, `DBI`, `digest`, `rlang`, `tibble` and `cpp11` become the
   **proposed** floors. Do not lower existing floors (the DuckDB 2.0.0 floor
   was a deliberate release decision); if an earlier snapshot would pass
   without one of them, report it as information only.
3. **Install and prove.** Into a fresh library outside the repository
   (`C:/Users/maxth/ledgr-wt/m4-libs/`), install exactly the manifest's
   versions (Imports, LinkingTo and their transitive dependencies; plus the
   Suggests needed by the floor checks, marked `check_only`). Install ledgr
   from the worktree into that library. Then run, with `.libPaths()` limited
   to that library and the R base library:
   - `R CMD INSTALL` of ledgr (must succeed, compiles `src/`);
   - the ordinary fast test profile:
     `Rscript --vanilla tools/run-test-profile.R --profile=fast --mode=ordinary`
     (read the script for the exact arguments the CI uses);
   - the README cold-start check: `Rscript --vanilla tools/check-readme-example.R`.
   Record each command, its exit code and any failure.
4. **Verify the manifest.** A small script (`verify.R`) compares the
   installed versions in that library with the manifest and fails on any
   difference. Gut it: change one version in a copy of the manifest and show
   that `verify.R` fails.
5. **Platform note.** This runs on Windows (R 4.6.1 locally). G3 itself runs
   on Ubuntu in CI; state what of the Windows proof carries over (versions,
   coherence) and what does not (binary builds, system libraries), and what
   the WS13 cut must re-prove on Ubuntu.

## 4. Where to work

- Worktree `C:/Users/maxth/ledgr-wt/m4-install-floor`, branch
  `claude/m4-install-floor` (from `release/v0.2.3` at `20034e00`).
- Deliverables under `dev/bench/v0_2_3_install_floor/`: `manifest.csv`
  (package, version, source or snapshot URL, role: `import` / `linking_to` /
  `transitive` / `check_only`), `build_library.R`, `verify.R`,
  `floor_checks.log` (or a CSV of commands and exit codes),
  `proposed_description_floors.md` (the exact `DESCRIPTION` diff you
  propose, with the reason per floor), and a one-page `closeout.md`.
- **Do not edit `DESCRIPTION`, `R/`, `src/`, `tests/`, `man/`, `vignettes/`
  or `NAMESPACE`.** The floor change is a proposal for the maintainer at the
  WS13 cut. Ignore line-ending churn in `R/cpp11.R` and `src/cpp11.cpp`.
- Never install into the user's normal R library.

## 5. Stop conditions

Stop and report if: no snapshot on or after R 4.6.0 satisfies the declared
floors; ledgr fails the floor checks in the minimum environment (report the
failure, do not raise floors to hide it without saying so); a package needs a
source build that fails for toolchain reasons; or the work needs more than
about two hours of package installation.

## 6. Rules

- Commit only your own paths on `claude/m4-install-floor` with
  `git -C C:/Users/maxth/ledgr-wt/m4-install-floor commit --only <paths>`.
  Do not merge, do not push.
- Shell: one simple command per call, absolute paths, `git -C` instead of
  `cd`, plain `Rscript`, script files for probes, no `rm -rf`, no sleep or
  polling loops.
- UTF-8 or ASCII only.
- Report: commit SHA, snapshot date and why, manifest summary (counts by
  role), proposed floors, floor-check results, verify gut result, platform
  caveats, open points for the WS13 cut.
