# v0.2.2 Release-Gate Closeout

**Role:** durable release-gate and publication record.
**Status:** local gates complete; remote publication gates pending.
**Authority:** `tickets.yml` LDG-3118. This record reports evidence and does
not replace the release playbook.
**Date:** 2026-10-27.

## Candidate

The frozen product candidate is commit
`5fb8aad8dc8d0fcc1bb3f6c3a86266c334dbc585` (commit C). Changes after C and
before merge are confined to this packet's evidence and status records. The
accepted comparison arm is
`0ffaaa0f5c9b913a45b09c935f7110f3c6d11396`.

Two release-harness corrections and one test-harness correction were required
before C froze. LDG-3120 isolates coverage subprocess traces. LDG-3121 makes
the long-window oracle compare two current-format stores and separates stable
economic identity from release-versioned walk-forward labels. LDG-3122 gives
the terminal fixture a deterministic public snapshot ID. None changes product
behavior, a public API, a stored format or an identity rule.

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

The local WSL installation has R 4.5.2 while ledgr 0.2.2 requires R 4.6.0, so
the local WSL package gate is not applicable. The release-branch full workflow
therefore remains the binding Ubuntu and DuckDB proof.

## Fast-profile adjudication

The profile, its 577 blocks and its 112-second threshold were not changed.
The first record contained one valid 111.71-second run followed by two runs
overlapped by the ordinary long-window benchmark. The replacement record took
114.68, 115.35 and 120.73 seconds (median 115.35). After that record completed,
the still-running release-scale process was discovered: its orchestrator had
started at 13:08 and overlapped all three replacement runs. Block-level deltas
were distributed across the lane rather than concentrated in changed code.

As an independent control, the exact earlier commit that had passed the same
577-block lane at a 111.74-second median took 121.21 seconds under the current
host conditions. No product code changed between that passing record and C
apart from the already accepted Workstream 68 correction that the earlier
record included. On 2026-10-27 the maintainer therefore overruled this local
wall-clock miss as a host-load exception. Every block passed, and the threshold
and membership remain unchanged. This is not recorded as a gate pass.

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

Pending. This section will record the explicit `refs/heads/v0.2.2` push, quick
and dispatched full branch workflow IDs, the green main R-CMD-check and pkgdown
runs, the tagged commit, the explicit `refs/tags/v0.2.2` push, tag workflow and
GitHub Release URL. The later post-publication commit records navigation to
v0.2.3 and is deliberately not part of the tag.
