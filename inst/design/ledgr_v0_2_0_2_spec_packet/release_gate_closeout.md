# v0.2.1.0 Release Gate Closeout

**Status:** Agent-provisional draft. The local gates, the peer record and the
dispatched full-tier run on the release branch are recorded below. The
Workstream 15 close review, the merge to `main`, `main` CI, the tag, tag CI
and the GitHub Release follow, each after the maintainer's go-ahead.
**Date:** 2026-10-01
**Cut:** 8
**Workstream:** 15
**Authority:** `inst/design/release_ci_playbook.md`

## Preconditions

The maintainer accepted Workstream 28 and Workstream 29 before any gate ran
(`tickets.yml`, Cuts 19 and 21). Cut 23, the per-call store overhead, was
accepted on 2026-09-30 at `1b22990`.

Version consistency, checked before the first gate at `791060e`: `DESCRIPTION`
reports 0.2.1.0, NEWS opens with `# ledgr 0.2.1.0`, the checked-out branch and
`origin` both have `v0.2.1.0` (with `v0.2.0.2` deleted from `origin` at the
maintainer's go-ahead), and AGENTS.md and `inst/design/README.md` name
v0.2.1.0. The intended tag is `v0.2.1.0`. The 98 tracked files that keep
`v0.2.0.2` are historical artifact names or narrative, classified in the
LDG-2824 evidence; neither AGENTS.md nor the design index needed a further
correction at the gate.

## Local Gates

Windows 11, R 4.6.1, at `791060e` unless noted. Release-gate timeouts were used.

| Gate | Command | Result | Wall time |
| --- | --- | --- | ---: |
| Full package tests, one process | command 1 below | 972 tests, 0 failures | 568 s |
| README cold start | `Rscript --vanilla tools/check-readme-example.R` | passed | 22 s |
| Article freshness, run 1 | `Rscript tools/render-vignettes-gfm.R --check --all` | failed: `vignettes/walk-forward.md` stale | 154 s |
| Article freshness, run 2 | the same, at `a3517c6` | all 26 verified | 154 s |
| `R CMD build` | `R CMD build .` | built `ledgr_0.2.1.0.tar.gz` | 222 s |
| `R CMD check` | `R CMD check --no-manual --no-build-vignettes ledgr_0.2.1.0.tar.gz` | Status: OK | 252 s |
| Coverage | `Rscript tools/check-coverage.R`, at `76dc0e9` | 85.94 percent against 80 | about 15 min |
| pkgdown build | `Rscript dev/build-site.R` | built; no DuckDB notices across 28 rendered articles | 327 s |
| WSL/Ubuntu DuckDB gate | command 2 below, R 4.6.0, duckdb 1.5.6 | 24 tests, 0 failures | 11 s |

Command 1 is `"C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" -e <expr>` from
the package root, with this expression as one argument
(`testthat::test_local()` loads the package through `pkgload::load_all()` with
its defaults):

```r
options(testthat.progress.max_fails = Inf); res <- as.data.frame(testthat::test_local('.', reporter = 'summary', stop_on_failure = FALSE)); bad <- sum(res$failed > 0 | res$error); cat('TESTS', nrow(res), 'BAD', bad, '\n'); quit(status = as.integer(bad > 0))
```

Command 2 is `Rscript /mnt/c/tmp/ledgr-wsl-gate.R`, run inside WSL from the
exported tree's root. The script, verbatim:

```r
# WSL/Ubuntu DuckDB gate for the v0.2.1.0 release (release_ci_playbook.md).
.libPaths(c(path.expand("~/R/gate-lib"), .libPaths()))
Sys.setenv(NOT_CRAN = "true")
suppressMessages(pkgload::load_all(".", quiet = TRUE))
cat("R", as.character(getRversion()), "duckdb", as.character(packageVersion("duckdb")), "\n")
files <- c(
  "test-schema-validator-side-effects.R", "test-schema-snapshots.R",
  "test-schema.R", "test-persistence-fresh-connection.R"
)
start <- proc.time()[["elapsed"]]
bad_total <- 0L
for (f in files) {
  r <- as.data.frame(testthat::test_file(file.path("tests/testthat", f), reporter = "silent"))
  bad <- sum(r$failed > 0 | r$error)
  bad_total <- bad_total + bad
  cat(sprintf("%-42s %3d tests %d bad\n", f, nrow(r), bad))
}
cat(sprintf("WSL GATE %s in %.0f s\n", if (bad_total == 0L) "PASS" else "FAIL", proc.time()[["elapsed"]] - start))
```

Walk-Forward went stale because its printed session ID hashes the package
version, which the promotion changed; it was re-rendered in `cfa8c67`, where
only that line moved. The pkgdown build's two tracked `docs/` files were
committed in the same commit, as earlier gates did. The WSL gate ran on an
exported copy of `791060e` inside WSL, with duckdb 1.5.6 installed from Posit's
Ubuntu binaries, because WSL's own library held duckdb 1.5.2.

## Peer Record

Two runs from the release commit `cfa8c67` with the registered 500-instrument,
1,260-session, fixed-seed all-engine command and a release R profile that puts
CRAN's duckdb 1.5.6 first; the second run,
`dev/bench/results/peer_benchmark_record_20261001T055357Z`, is promoted and
renders the tracked report (`a3517c6`). Correctness, canonical-versus-compiled
differential parity, surface retention and peer parity pass in both runs;
LEAN was unavailable (obsolete local CLI root) and is reported as such. The
first run's durable public TTR row took 64.89 seconds against 60.94 in the
promoted 2026-09-26 record, while every other row was as fast or faster; the
maintainer asked for the repeat, which measured 57.94, showing host variance
rather than a package change. Against the 2026-09-26 record, which ran on
duckdb 1.5.2, every ledgr row is as fast or faster, but the unchanged peer
engines were also 5 to 22 percent faster, so no ledgr speedup is claimed. The
sampled process tree peaked at 2,284.1 MiB. Details: the peer README's
"v0.2.1.0 Release Record".

## Continuous Integration

The release branch's full tier had not run since v0.2.0.1 when the gate began;
its first dispatches failed only on gates added since then, which windows and
CRAN mode had never passed. Fixed in LDG-2917 and LDG-2919, with maintainer
decisions recorded there:

- the duckdb 1.5.6 join for stores a user holds open, and LTB-0132 that forces
  the refusal on every platform;
- CI timing is advisory (maintainer, 2026-09-30): hosted runners measured 103
  and 135 seconds on identical code against a 112-second bound. The bound is
  unchanged and still binding locally (82.86 seconds at the gate); CI records
  the time and warns. This changes where the gate binds, not its threshold;
- the isolated CRAN profile runs on ubuntu, and windows runs
  `R CMD check --as-cran`, as CRAN does there;
- the CRAN test library is kept out of the package build;
- coverage measures the fast and review profiles together, as it did before
  the test lanes split them (maintainer, 2026-09-30), with the 80 percent
  threshold unchanged; coverage runs find the source tree, start no worker
  daemons, and skip only checks of live function bodies.

Release-branch full tier, dispatched: run `36776852759` at `76dc0e9` was the
first fully green full-tier run since v0.2.0.1. The merge gate is full-tier run
`36822363938`, dispatched on `v0.2.1.0` at `a3517c6`, conclusion success:
Ubuntu release passed `R CMD check` with Status OK and coverage at 85.94
percent; Ubuntu R 4.6 passed; Windows passed `R CMD check --as-cran` with 4
NOTEs (CRAN incoming feasibility, top-level files, Rd line widths, relative
URL paths), the same four as run `36776852759`. The advisory timing gates warned
at medians of 134.97 seconds (ordinary, bound 112) and 133.75 seconds (CRAN
mode, bound 105) on the hosted runner, as the advisory decision anticipated.
Commits after `a3517c6` change only design records. Still to record, as
three separate run ids: `main` R-CMD-check, `main` pkgdown, and the `v0.2.1.0`
tag R-CMD-check.

## Production Code

The gate's brief predates four tickets that joined the workstream; the
review reason was amended on 2026-10-01. LDG-2918 is the only production change:
one Tier 1 resolver shared by preflight and trusted recovery. Its loops run over
a strategy's free symbols and the fixed list of recommended packages; neither
grows with bars, facts, instrument-pulses, events, diagnostics or candidates,
and none of the seven named shapes appears. Its preflight cost is a warm clock,
interleaved against `8a6fd38`: 2.8 to 2.9 ms for the helper strategy and 1.75
to 1.85 ms for a plain one, within the clock's noise. LDG-2913, LDG-2914 and
LDG-2919 change tests, test tooling, CI and the R floor only.

## Release Notes

NEWS opens with `# ledgr 0.2.1.0`, starts with what an upgrading user must
change, and states the non-claims in their own paragraph: corporate actions are
not complete, exact quantity settlement is not modeled, and bars declared
distribution-adjusted are refused as execution bars. The README states the R
4.6.0 requirement and agrees with the notes.

## Documentation Patch

The tag was pushed at `207e760` and tag CI passed (run `36832236507`), but
before the GitHub Release an outside reader's review of the README and all
articles arrived. The maintainer decided that no version is tagged with known
defects. Its findings were verified and routed
(`external_review_2026_10_01.md`): documentation errors and the run list's
`tags` type became Cut 24, Workstream 32 (LDG-2920 to LDG-2922); behaviour
changes went to design sessions of the next version. The patch corrects the
articles, states shipped behaviour where the documentation over-claimed, and
makes `tags` character from the start. Its local checks: all 26 articles fresh,
the README example passing, the full suite in one process failing only on the
two declared test pins it then updated, and the binding fast-profile gate
passing at 495 blocks. Two reviews (0.667 over three tickets, an accepted
breach) passed it at `a8059f3`. The release tag moves to the patched commit
after `main` is green, as the playbook's release order allows; tag CI and the
GitHub Release are recorded on the moved tag.

## Review Count

Workstream 15 holds six tickets: LDG-2824, LDG-2825, LDG-2913, LDG-2914,
LDG-2918 and LDG-2919. The first Type 1 close review, at `6cdaa7b`, returned
CHANGES_REQUIRED on three record findings and no code or design finding: the
merge-gate result was unrecorded, two gate commands were described rather
than recorded, and the review reason still exempted the workstream from the
code-review obligations although LDG-2918 changes production code. All three
are answered in `e7c83ef` and `63d9826`. The focused re-review at `63d9826`
returned CHANGES_REQUIRED on one finding the correction introduced: the
amendment to the Workstream 15 review reason was also appended to Workstream
22's, which shares the sentence it followed. It is removed there in this commit.
Two invocations over six tickets is 0.333.
