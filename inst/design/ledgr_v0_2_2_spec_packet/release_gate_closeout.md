# v0.2.2 Release-Gate Closeout

**Role:** durable release-gate and publication record.
**Status:** published; all binding remote publication gates complete.
**Authority:** `tickets.yml` LDG-3118. This record reports evidence and does
not replace the release playbook.
**Date:** 2026-10-27.

## Candidate

The frozen product candidate is commit
`5fb8aad8dc8d0fcc1bb3f6c3a86266c334dbc585`. Release-branch run
`40503819339` then found one blocking brace-style lint in LTB-0204. Commit
`7e93e9c4` wraps the one multi-line local helper expression without changing
its value, assertions or product code and records LDG-3123. The focused
brace linter and complete owning test file pass. The final release commit C is
therefore `7e93e9c4`; every product gate below applies unchanged because its
diff from `5fb8aad8` contains no package source, API, generated help, schema,
identity or benchmark code. The replacement branch CI is the complete test
confirmation. Further changes before merge are confined to this packet's
evidence and status records. The accepted comparison arm is
`0ffaaa0f5c9b913a45b09c935f7110f3c6d11396`.

Two release-harness corrections and two test-harness corrections were required
before C froze. LDG-3120 isolates coverage subprocess traces. LDG-3121 makes
the long-window oracle compare two current-format stores and separates stable
economic identity from release-versioned walk-forward labels. LDG-3122 gives
the terminal fixture a deterministic public snapshot ID. LDG-3123 closes the
single formatting lint. None changes product behavior, a public API, a stored
format or an identity rule.

## Local gates

Commands used R 4.6.1 with the local R 4.6 library. Times are wall times unless
the record itself supplies a subprocess total.

| Gate | Command or record | Result | Time |
| --- | --- | --- | ---: |
| Full package tests | `testthat::test_local()` under the release library | PASS; one established optional `quantmod` skip | 895.33 s |
| Coverage | `Rscript --vanilla tools/check-coverage.R` | PASS, 89.19% against the unchanged 80% threshold | 1,014.88 s |
| README cold start | `Rscript --vanilla tools/check-readme-example.R` | PASS | 24.43 s |
| Article freshness | `Rscript tools/render-vignettes-gfm.R --check --all` | PASS, all 28 tracked articles | 209.58 s |
| Source build | `R CMD build .` with the registered Quarto/Pandoc path | PASS; all 26 installed vignettes | 287.12 s |
| Source check | `R CMD check --no-manual --no-build-vignettes C:/tmp/ledgr_0.2.2.tar.gz` | PASS; no errors or warnings and only the established unqualified-`head` NOTE | 350.25 s |
| pkgdown | `Rscript --vanilla dev/build-site.R` | PASS, 30 articles and the full reference index | 411.22 s |
| Review profile | `tools/run-test-profile.R --profile=review --mode=ordinary` | PASS, 450/450 blocks with one established optional skip | 516.62 s |
| Codebase census | `tools/check-codebase-contracts.R --mode=check` | PASS | 48.88 s |
| Census self-test | `tools/check-codebase-contracts.R --self-test-mode-branches` | PASS | 0.22 s |
| Fold-phase contract | `tools/check-fold-phase-contract.R .` | PASS | 0.45 s |
| YAML and diff | parse `tickets.yml` and `tests/claims.yml`; `git diff --check` | PASS | below timer resolution |

The first build attempt lacked the Quarto executable on `PATH`. The second
found Quarto but the sandbox denied its AppData cache. The same command passed
outside that sandbox with the registered RStudio Quarto/Pandoc path. These are
environment failures, not package failures; both failed attempts are retained
in the session record rather than described as passing gates.

The available Ubuntu 24.04 WSL installation does not meet the candidate's
declared toolchain: it has R 4.5.2 while ledgr requires R 4.6.0, and its
initial `collapse` 2.1.7 and DuckDB 1.5.2 were below the candidate's 2.1.8
and 1.5.6 floors. `collapse` upgraded successfully. Building a current DuckDB
from source exceeded 30 minutes, and the available binary-repository attempt
also timed out. The package gate is therefore **unavailable, not passed or
not applicable**. The dispatched full release-branch workflow must supply the
binding Ubuntu and DuckDB proof before merge.

## Fast-profile adjudication

The profile, its 577 blocks and its 112-second threshold were not changed.
The contaminated record contains one 111.71-second run followed by 115.03-
and 114.40-second runs that overlapped the ordinary long-window benchmark. It
is retained only as a failed attempt. The first uncontaminated record took
114.68, 116.00 and 115.11 seconds (median 115.11). A final quiet-host retry on
the registered P-core mask took 114.98, 113.35 and 113.17 seconds (median
113.35) while sampled background CPU stayed between 3 and 10 percent.

Every run executed all 577 blocks without a failure or skip. Per-file deltas
against the retained Workstream 68 P-core record are distributed across the
lane rather than concentrated in changed code, and that same product lineage
previously passed at a 111.74-second median. Nevertheless, the binding final
record exceeds the unchanged 112-second threshold by 1.35 seconds. It is a
**timing miss**, not a pass. No threshold or profile membership changed.
The maintainer accepted this 1.2-percent miss on 2026-10-27 as a
release-specific host-timing exception. The record remains a timing miss,
not a pass; the threshold and profile remain unchanged.

## Long-window and terminal records

The ordinary record is
`dev/bench/v0_2_2_release_closeout/evidence/release_gate_long_window_5fb8aad8`.
It contains five alternating accepted/candidate pairs for each of three
shapes. `check_record.R` and its corruption self-test pass. Candidate/accepted
median ratios are 1.007 for availability-sweep cold, 0.985 for feature-gaps
cold, 0.996 for fact-churn cold, 1.000 for availability-sweep warm, 1.016 for
feature-gaps warm and 1.060 for fact-churn warm. Clocks are characterization;
the registered stable identities and economic values are exact. The 39
subprocesses total 549.33 seconds.

The release-scale record is
`dev/bench/v0_2_2_release_closeout/evidence/release_gate_scale_5fb8aad8`.
Both registered shapes pass the checker and corruption self-test against the
same named arms. Its eight subprocesses total 844.59 seconds. Peak RSS remains
workload-specific and the accepted parallel-memory limitation is unchanged.

The terminal record is
`dev/bench/v0_2_2_release_closeout/evidence/release_gate_terminal_5fb8aad8`.
The runner prints `LEDGR_TERMINAL_RELEASE_OK`; the normal checker and
corruption self-test pass. Straight, reopened and interrupted/resumed results
retain exact economics and native identities under the fixed
`terminal-release-v1` snapshot ID.

The retained integrated, scheduler and peer records remain characterization
under their recorded workload boundaries. No new peer ranking or public
performance generalization is introduced. The registered Sharadar boundary
remains verbatim in NEWS and the documentation-contract detector passes:
zero-volume carried-close bars are still observed prices that can fill and do
not age or freeze.

## Release definition of done

1. Contract, decision, RFC, roadmap and parking-space roles are discoverable;
   `horizon.md` is not authority.
2. The terminal and integrated records cross lifetime terminals and supplied
   corporate actions under disclosed policies without ambiguous completion.
3. Run, sweep and walk-forward share the accepted point-in-time substrate.
4. Bounded and recursive indicators carry explicit readiness and gap rules;
   the registered strict path is practical.
5. The taught long-only minimum-variance strategy consumes causal history on
   declared monthly decision dates through public APIs.
6. Rule-4 snapshot verification and current-only configuration/result formats
   remain fail-closed and reproducible.
7. Early interruption and resume have registered exactness evidence.
8. Integrated evidence names workload, clocks, exclusions and boundaries.
9. The Sharadar carried-bar limitation remains explicit.
10. One- and two-worker memory evidence remains disclosed as workload-specific:
    approximately 1.89 GiB and 4.46 GiB respectively. Shared-memory and worker
    transport improvements remain next-release work rather than a hidden
    v0.2.2 claim.

## Remote publication

The release branch was pushed explicitly through `refs/heads/v0.2.2` at
packet-only commit `90e82c49`; quick workflow 40503819339 started from that
commit and exposed the LDG-3123 formatting-lint blocker. Exact-head quick
workflow 40506282632 then passed at `c94dd587`. Dispatched full workflow
40510197118 passed both lints, Windows, Ubuntu R 4.6 and every package-check
cell, but its Ubuntu release coverage step failed twice after the preceding
isolated-CRAN profile. LDG-3124 owns that release-harness blocker. No merge,
tag or GitHub Release has occurred. The maintainer's 2026-10-27 release-recovery
decision validates the bounded correction through its focused detector and one
replacement full-tier workflow. It explicitly skips another local coverage
run, another quick workflow and the separate pre-tag main R-CMD-check and
pkgdown workflows; none is recorded as passed. This section will record the
replacement full workflow ID, the tagged commit, the explicit
`refs/tags/v0.2.2` push, tag workflow and GitHub Release URL. The later
post-publication commit records navigation to v0.2.3 and is deliberately not
part of the tag.

Exact-candidate full workflow 40530236830 ran commit `922e6717`. Both blocking
linters, the Windows release job and the Ubuntu R 4.6 package check passed.
The ordinary Ubuntu coverage cell reached the full test suite, confirming the
LDG-3124 environment isolation, then failed only LTB-0258's two exact-version
assertions: ordinary dependencies supplied DuckDB 2.0.0 while the schema-124
golden still named 1.5.6. Every normalized catalogue row and all four digests
matched. The remaining Ubuntu job was cancelled after this decisive failure;
the workflow is recorded as failed/cancelled, never as a pass. Maintainer
decision (12) adopts DuckDB 2.0.0 as the release floor, and LDG-3125 owns the
deliberate equivalent-catalogue re-pin. No merge, tag or GitHub Release has yet
occurred at that checkpoint.

The deliberate DuckDB 2.0.0 catalogue re-pin landed at `070e0e4d`; the
pragmatic publication-gate record landed at `7539be45`. Branch
`refs/heads/v0.2.2` and `refs/heads/main` were fast-forwarded to
`7539be452ad15f5ee39e408d14c25f83aa58389b`. Their automatically triggered
duplicate workflows 40542199229, 40542330468 and 40542330103 were cancelled
under Cut 23 decision (13) and are not cited as passes.

Lightweight tag `refs/tags/v0.2.2` names that same commit. Its mandatory full
workflow 40542364504 passed the plan, semantic lint, formatting lint, Windows
release, Ubuntu R 4.6, Ubuntu release, R CMD checks, fast, review,
isolated-CRAN and coverage jobs. This is the sole final integrated
confirmation authorized by decision (13). The curated GitHub Release was
published only after that green result:
<https://github.com/blechturm/ledgr/releases/tag/v0.2.2>.

## Final M1 accounting and reassessment

The table applies the accepted M1 definition: independent verdicts at cut,
workstream-close, focused-re-review or final-review points over completed
tickets. The dropped LDG-3008 enters neither the Cut 12 nor packet ticket
count. Pre-M1 cuts retain their historical records; this table reconstructs
their final count without rewriting them.

| Cut | Independent verdicts | Completed tickets |
| ---: | ---: | ---: |
| 1 | 8 | 12 |
| 2 | 8 | 11 |
| 3 | 2 | 4 |
| 4 | 3 | 1 |
| 5 | 4 | 2 |
| 6 | 6 | 9 |
| 7 | 3 | 4 |
| 8 | 2 | 2 |
| 9 | 5 | 4 |
| 10 | 5 | 4 |
| 11 | 9 | 17 |
| 12 | 21 | 25 |
| 13 | 6 | 3 |
| 14 | 8 | 19 |
| 15 | 25 | 16 |
| 16 | 23 | 25 |
| 17 | 9 | 10 |
| 18 | 9 | 7 |
| 19 | 15 | 7 |
| 20 | 5 | 3 |
| 21 | 16 | 6 |
| 22 | 3 | 1 |
| 23 | 7 | 10 |
| **Packet** | **202** | **202** |

Cut 23's seven independent Type 1 verdicts comprise the cut review and the
initial and focused verdicts for Workstreams 68, 65 and 66. Four verdicts
returned findings and changed ticket ownership, product correctness,
teaching, detectors or release records; three focused confirmations were
finding-free PASS results. Workstream 67 did not receive an independent close
verdict: the maintainer's pragmatic-publication decision closed it on the
green mandatory tag workflow after the preceding independent cut review and
all registered product gates. Maintainer review-disposition turns were the
patched cut acceptance; Workstream 68 and 65 acceptance; Workstream 66
acceptance; the fast-gate timing exception; the release-recovery and DuckDB
baseline decisions; and authorization to publish on the tag workflow.

The closeout reassessment keeps M1 unchanged: verdict and finding accounting
remains report-only, and a third correction round still escalates. The exact
packet total of 202 verdicts over 202 completed tickets is descriptive, not a
quality score or target. The costly failure was instead the serial release
process: repeated environment preparation, overlapping local and hosted
gates, late dependency-baseline discovery and unclear evidence reuse turned
publication into an eight-hour procedure. A focused v0.2.3 RFC now owns the
release-candidate, CI-gate and evidence-reuse architecture; M1 is not made a
proxy for that separate problem.
