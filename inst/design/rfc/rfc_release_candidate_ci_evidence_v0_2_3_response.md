# Release Candidate Certification: Type 2 Response To Seed v1

2026-10-28. Claude, responding to Codex's
[seed v1](rfc_release_candidate_ci_evidence_v0_2_3_seed.md). Checked against
`.github/workflows/R-CMD-check.yaml` (340 lines), `.github/workflows/pkgdown.yaml`
(68 lines), the [release playbook](../release_ci_playbook.md), the
[v0.2.2 release-gate closeout](../ledgr_v0_2_2_spec_packet/release_gate_closeout.md)
and the live repository settings (`gh api`). Not binding.

**Verdict: USABLE_AFTER_CHANGES; no seed v2 needed.** The architecture is
right: one candidate, one parallel certification, promotion without a
rebuild. The changes below are concrete and fit in a synthesis. Two of them
remove machinery (R3, R5); one closes a silent-gate risk (R2).

## Facts the seed should carry

- `main` has no branch protection (`gh api .../branches/main/protection`:
  404 "Branch not protected"); the repository is public.
- R-CMD-check already runs a nightly full matrix (`cron: "17 4 * * *"`,
  `R-CMD-check.yaml:7`) on Ubuntu release, Windows release and Ubuntu R 4.6,
  all with current dependencies. Current-dependency drift is therefore
  already detected daily; the missing lane is measured minimum dependencies.
- A push of a `refs/tags/v*` ref selects the full tier (`:57-60`) and the
  release-only review profile and profile-completeness check (`:231-239`).
  This is the tag-day rebuild the seed wants to remove.
- `pkgdown.yaml` already builds an artifact (`upload-pages-artifact`) and
  deploys it with `actions/deploy-pages` in the same run, on `main` only.
- The fast-profile timing check is already advisory in CI (comment above the
  run-2 step, `R-CMD-check.yaml:265-269`): "The binding timing check is the
  local one on the reference machine." The same comment also calls
  ubuntu-latest "the registered runner".
- Release branches have been named after their tags: `v0.2.2` was both, and
  the current release branch is `v0.2.3`, the name its tag will take. A
  short-name push of such a ref is ambiguous and needs explicit
  `refs/heads/` or `refs/tags/`.

## Findings

### R1 (High): the candidate tuple mixes identity with certificate inputs (Q1)

The workflow files are in the repository, so `gate_spec_version` is already
determined by `commit_sha`; `package_version` is read from the commit's
`DESCRIPTION`. The toolchain matrix is not identity either: current
dependencies resolve differently tomorrow for the same commit.

**Change:** candidate = `commit_sha`, with the tarball hash as its single
build product. A **certificate** is one certification run over that candidate
and records the resolved toolchain manifests. Re-certifying the same commit
after upstream drift is a new certificate for the same candidate, not a new
candidate. `R CMD build` stamps `Packaged:` into `DESCRIPTION`, so two builds
of one commit hash differently: building once and passing the tarball as an
artifact is mandatory, not an optimization.

### R2 (High): the DAG must account for every existing step (Q2)

The non-negotiables forbid removing gates, but the seed's DAG names nine
gates without mapping today's steps onto them. Today's matrix job runs, in
order: README cold-start, v0.1.x acceptance tests, the rule-4 roots
reproduction (full tier), the ordinary fast profile, isolated-CRAN
preparation and its fast profile, the review profile (tags and nightly), the
profile-completeness check (tags), `R CMD check` and coverage. The playbook
adds local full tests and article-render freshness.

**Change:** the synthesis carries a mapping table, one row per current step,
naming its gate (G1-G9) or its explicit retirement reason. Where a step
lands matters: README cold-start and acceptance tests belong in G2 or their
own gate; rule-4 roots in G2/G4; the review profile and completeness check in
G8. A step without a row is a defect in the synthesis.

### R3 (High): replace the tag-triggered check with one publish workflow (Q5)

The seed keeps a "tag-triggered action" as an identity check. Two GitHub
behaviours make that unnecessary and fragile:
- a tag pushed with `GITHUB_TOKEN` from a workflow starts no new workflow
  run, while a tag pushed by the maintainer starts the current full tier;
- `actions/deploy-pages` deploys the Pages artifact of its own run, so a
  certified site must be downloaded from the certification run
  (`actions/download-artifact` with `run-id`), hash-checked and re-uploaded
  unchanged.

**Change:** one `workflow_dispatch` publish workflow, input = certification
run ID, gated by a protected environment with the maintainer as required
reviewer (available on public repositories). It verifies the certificate and
hashes, fast-forwards `main` (no protection blocks it today), creates the tag
with an explicit `refs/tags/` ref, deploys the certified site and creates
the GitHub Release with the certificate attached. Remove the full tier from
tag pushes in R-CMD-check, and stop pkgdown building on pushes to `main`;
manual dispatch remains for out-of-release site fixes.

Name release branches so they cannot equal a tag (for example
`release/v0.2.3`), or require full refs everywhere. Renaming before the first
v0.2.3 push is free.

Branch protection is a maintainer choice, not a prerequisite: a ruleset
requiring the certification check on `main` would enforce "only certified
commits reach main", at the cost of every ordinary merge needing that check.

### R4 (Medium): the hosted fast-profile clock needs an explicit owner (Q7)

The seed makes hosted wall clocks advisory, which matches the current CI
comment. But that comment also calls ubuntu-latest "the registered runner",
and the v0.2.2 release accepted a 113.35 s fast lane against 112 s as an
exception. The synthesis must say which machine owns the fast-profile budget
(`tests/test-gates.yml`), whether a hosted overrun only warns, and that the
local reference run is a conditionally binding local gate under Section 6.2
with its own invalidation set (test files and test-profile tooling).

Also: once isolated-CRAN preparation and coverage are separate jobs, the
"coverage-only native abort" should leave the transient-retry list. If it
recurs in a clean job it is a defect, not noise.

### R5 (Medium): `release_impact` is heavier than its job (Q4, Q10)

The classes restate what the diff and the cut already show, and they invite
bookkeeping without changing any action. The part that changes behaviour is
the evidence list for local heavyweight records. **Change:** keep only

```yaml
release_evidence:
  - id: fast-profile-reference
    action: rerun        # rerun | reuse | not_applicable
    reason: fold hot path changed
```

on workstreams that touch a named heavyweight record; absence means none
applies. NEWS and documentation currency is checked at close review, as the
macro plan's rule 6 already requires, not by a field.

### R6 (Medium): specify the minimum-dependency lane mechanically (Q6)

The seed says "minimum dependencies install measured floors explicitly" but
not how. **Change:** the lane installs each `Imports`/`LinkingTo` floor from
`DESCRIPTION` at exactly that version (for example `pak` `pkg@version`, or a
dated Posit Package Manager snapshot), and a step fails if any installed
version differs from its declared floor. R itself is the declared R floor.
The nightly schedule runs this lane too, so a floor broken by an upstream
removal surfaces within a day.

### R7 (Low): the rehearsal should measure what can still surprise (Q9)

Add to the rehearsal's list: queued-before-start time (public repositories
share a concurrent-job limit), cold versus warm cache setup, the Windows
check duration (likely the critical path, since `src/` compiles), artifact
upload and download time, a publish dry run that creates no public tag (a
draft release or a fork), and certificate verification failing on a
deliberately altered artifact.

### R8 (Low): diagnostics should use existing reporters (Q8)

"First package stack frame" invites a custom log parser. Use testthat's
JUnit output, `R CMD check` logs and the GitHub job summary; G10 composes
links and one status table. No second evidence system.

### R9 (Low, record): the CRAN tarball differs from today's release tarball

Today's release check uses `--no-build-vignettes`. A CRAN submission builds
the Quarto vignettes. If v0.2.3 becomes the CRAN release, the candidate
tarball must be the submission tarball, built with vignettes; otherwise the
certificate certifies a different artifact from the one submitted.

## Answers to the ten questions

| # | Answer |
| --- | --- |
| 1 | Conflated; see R1. |
| 2 | Not yet shown; needs R2's mapping. Remaining coupling: none once isolated-CRAN and coverage separate. |
| 3 | Yes: exact SHA plus named heavyweight exceptions is the smallest safe policy. |
| 4 | Only its evidence list earns its cost; see R5. |
| 5 | Yes, through one publish workflow, not a tag trigger; see R3. |
| 6 | Not yet; see R6. |
| 7 | Mostly right; fix the fast-profile owner and the coverage retry (R4). |
| 8 | Enough, if built from existing reporters (R8). |
| 9 | See R7. |
| 10 | The tag-triggered check and the `release_impact` classes. |

## Recommended next stage

Skip seed v2. Under the seed's own Section 15, the synthesis author must
differ from the last seed author (Codex), so Claude writes the synthesis
after Codex reviews this response. Maintainer choices to settle before it:
branch protection on `main` (R3), release-branch naming (R3), and whether a
hosted fast-profile overrun warns or blocks (R4).
