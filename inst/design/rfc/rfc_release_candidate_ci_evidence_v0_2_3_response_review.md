# Review Of The Type 2 Response: Release Candidate CI Evidence

**Date:** 2026-10-28.
**Mode:** response review under the RFC cycle.
**Reviewer:** Codex, author of seed v1 but not of the Type 2 response.
**Disposition:** REVISE_SEED.

The response improves the proposal materially. Its central direction is right:
one commit identifies the candidate, one build produces the source artifact,
one certification run records the resolved environments and gate outcomes, and
one manually authorized publication workflow promotes those exact outputs.

The response's conclusion that no seed v2 is needed does not follow. R1 changes
candidate identity, R3 replaces the tag-check and site-promotion architecture,
and R5 removes most of the proposed ticket field. Those are material changes
under seed Section 15, not wording patches for synthesis. Codex should write
seed v2 after this review. The response remains the challenge input; it should
not be rewritten.

Two factual corrections are also required:

1. R6 cannot derive an exact minimum environment from `DESCRIPTION` alone.
   Most direct dependencies have no version floor, and transitive dependencies
   are not listed there.
2. R9 mistakes a check option for a build option. The v0.2.2 source tarball was
   built with vignettes. `R CMD check --no-build-vignettes` did not create or
   select a different tarball.

No product-semantics question was found.

## 1. What was verified

### 1.1 Repository and current workflows

The live GitHub API reports that `blechturm/ledgr` is public and that `main`
is not protected. These two facts in the response are correct.

The local ref inventory has `refs/heads/v0.2.3`. A future
`refs/tags/v0.2.3` would therefore share its short name. Full ref names are
required for mutating operations unless the branch is renamed.

The current workflows support the response's other baseline claims:

- `R-CMD-check.yaml` schedules the full matrix nightly at 04:17 UTC;
- that matrix is Ubuntu current R, Windows current R, and Ubuntu R 4.6, with
  current dependency resolution in all three jobs;
- a `v*` tag push selects the full tier, review profile and
  profile-completeness check;
- the hosted fast-profile clock is advisory, although its comment incorrectly
  also calls `ubuntu-latest` the registered runner; and
- `pkgdown.yaml` builds and deploys one Pages artifact in the same workflow on
  `main`.

### 1.2 GitHub Actions behavior

The response is correct that an ordinary push or tag created with the
workflow's `GITHUB_TOKEN` does not start another workflow. GitHub documents
`workflow_dispatch` and `repository_dispatch` as the relevant exceptions.

It is also correct that a publication workflow can retrieve an artifact from
another run only by supplying a token and run identifier, and that a Pages
deployment consumes a Pages artifact in its own workflow. The certification
artifact therefore has to be downloaded, checked and uploaded as the Pages
artifact of the publication run before `actions/deploy-pages` consumes it.

One important detail is missing. `actions/download-artifact` recalculates the
upload digest, but GitHub documents a digest mismatch as a warning. The
publication gate must independently compare the downloaded bytes with the
certificate's expected SHA-256 and fail on inequality. The automatic warning
is not a binding integrity gate.

Workflow artifacts also expire, by default after 90 days. The publication
step must attach the certificate and source tarball, or an equivalently durable
copy, to the GitHub Release. The certificate must retain the site-artifact
digest even though Pages owns the deployed copy.

GitHub environments and required reviewers are available for this public
repository. Only one listed reviewer must approve. Preventing self-review is
optional; if enabled, the person who dispatches publication cannot approve it.
That approval topology is a maintainer choice, not an incidental workflow
default.

Sources checked:

- [GitHub workflow triggering](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow)
- [GitHub workflow artifacts](https://docs.github.com/en/actions/tutorials/store-and-share-data)
- [GitHub artifact retention](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts)
- [GitHub deployment environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)
- [GitHub Pages custom workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)

### 1.3 R package build behavior

The response's build-once conclusion is sound. `R CMD build` creates the
source tarball and adds build metadata, so rebuilding is not a safe way to
recover the certified bytes.

The response's CRAN explanation is not sound. R's package manual states that
`R CMD build` builds vignettes by default unless build-time vignette generation
is explicitly disabled. The v0.2.2 closeout records exactly that sequence:

- `R CMD build .`, with all 26 installed vignettes; then
- `R CMD check --no-manual --no-build-vignettes` on that built tarball.

The check flag avoids rebuilding vignettes during the check. It does not make
the already-built tarball a non-CRAN artifact. The durable rule should be that
the exact certified tarball is the tarball submitted to CRAN, if this release
is submitted, with default vignette building enabled at G0.

Source checked:

- [Writing R Extensions: checking and building packages](https://stat.ethz.ch/R-manual/R-devel/doc/manual/R-exts.html)

## 2. Disposition of R1-R9

### R1: ACCEPT WITH CLARIFICATION

The candidate is the repository commit SHA. Package version and gate
definitions are derived from that commit. Resolved toolchains and gate
outcomes belong to a certificate. The source tarball and site artifact are
build products whose hashes the certificate binds.

This distinction is better than seed v1's tuple. Re-certifying one commit
after current-dependency drift produces another certificate for the same
candidate. It does not create another candidate.

Seed v2 should say "commit in this repository" where repository scope might
otherwise be ambiguous, and should make the one-build rule binding.

### R2: ACCEPT WITH A WIDER CENSUS

The synthesis needs a disposition for every existing gate, but the response
understates the playbook. The playbook adds more than full local tests and
article freshness. The census must also route or retire, at minimum:

- README cold-start and v0.1.x acceptance checks;
- rule-4 root reproduction;
- ordinary and isolated-CRAN fast profiles;
- review-profile and profile-completeness checks;
- coverage, package checks, article freshness and pkgdown;
- agent-context and design-memory release checks;
- the conditional local WSL gate;
- the standing Sharadar claim boundary and terminal release fixture; and
- win-builder for a CRAN submission.

Not all of these become remote DAG jobs. Each row may name a pre-candidate
local owner, a remote gate, a conditional publication prerequisite, or an
explicit retirement. An absent row is a design defect.

### R3: ACCEPT WITH THREE PATCHES

The single manually dispatched publication workflow is the correct shape.
The `GITHUB_TOKEN` trigger behavior, cross-run artifact handoff and current
absence of branch protection all support it.

Seed v2 must additionally bind:

1. explicit SHA-256 comparison that fails, rather than relying on GitHub's
   artifact-digest warning;
2. durable publication of the certificate and certified source tarball before
   workflow-artifact expiry; and
3. fully qualified refs for all branch and tag reads or writes.

Using `release/v0.2.3` is clearer and is recommended, but ref qualification is
the safety rule. Branch naming itself does not need a maintainer decision.

The environment approval is manual authorization. It is not automatically a
second-person review. Whether self-approval is allowed is a maintainer choice.

### R4: ACCEPT IN PART

The registered local host owns the binding fast-profile budget. Hosted-runner
wall clocks remain advisory. This is already the accepted policy and is not an
open maintainer choice. The misleading `ubuntu-latest` comment should be
corrected during implementation.

Separating coverage from isolated-CRAN setup removes the known cross-job
contamination route. It does not by itself prove that every future
coverage-only native abort is deterministic. Keep the single declared retry
until rehearsal evidence either identifies a stable product defect or shows
that the transient class no longer occurs. Isolation alone is not evidence for
retiring it.

### R5: ACCEPT

The `release_impact.classes` taxonomy is anticipatory bookkeeping. Keep only a
small `release_evidence` list on a workstream that owns a named heavyweight
record. Absence means that no named heavyweight record applies.

The candidate DAG still validates every committed registered record assigned
to G9. The field controls rerun or reuse of external or registered-host work;
it does not control whether committed evidence is checked.

### R6: REVISE

Installing every `Imports` and `LinkingTo` floor from `DESCRIPTION` is not a
complete algorithm. Only `collapse`, `duckdb` and `yyjsonr` currently have
explicit package floors. `codetools`, `DBI`, `digest`, `rlang`, `tibble` and
`cpp11` do not. Transitive dependency versions are not declared there either.

M4 must produce a complete, coherent minimum-environment manifest after
measurement. The manifest records exact package versions and sources for all
resolved direct and transitive dependencies. G3 installs that manifest in a
clean library and then asserts the installed versions. It separately checks
that every declared direct floor is met exactly where an exact floor was
chosen.

A dated package-repository snapshot may help make that environment
installable, but it is not equivalent to exact floor installation. The lane
must fail as unavailable when an exact recorded environment cannot be
reconstructed; it may not silently substitute current versions.

Running this lane nightly is useful and accepted.

### R7: ACCEPT WITH NARROWER CAUSAL WORDING

Measure queue delay, cold and warm cache setup, the Windows critical path,
artifact transfer, a non-public publication dry run and deliberate artifact
tampering. Record observed queue behavior without attributing it to one global
public-repository concurrency rule; limits depend on the account and plan.

The tamper rehearsal must fail the explicit certificate-hash comparison from
R3.

### R8: ACCEPT THE PRINCIPLE, NOT A JUNIT MANDATE

Do not build a log parser or a second evidence store. The current test-profile
runner already accepts a testthat reporter and produces control-plane records.
`R CMD check`, testthat and GitHub job summaries should remain the native
owners.

JUnit is one possible presentation adapter, not a required architecture. G10
should consume stable native outputs and links. "First package stack frame"
remains best-effort where the owning tool exposes it.

### R9: CORRECT THE RECORD

Reject the claim that today's release tarball omits built vignettes. The
recorded v0.2.2 tarball included them. Replace R9 with this conditional rule:

> If the release is submitted to CRAN, submit the exact certified source
> tarball produced once at G0. G0 uses the normal vignette-building path, and
> all CRAN and win-builder checks identify that tarball hash.

No second CRAN-specific source build is allowed.

## 3. Maintainer choices

Two choices require maintainer authority before synthesis:

1. **Protection of `main`.** The minimum architecture works with today's
   unprotected branch. Enabling a ruleset that admits only the certification
   or publication path is stronger, but it changes ordinary merge authority
   and the token or bypass rules the publisher needs.
2. **Publication approval topology.** Decide whether the maintainer who
   dispatches publication may approve the protected environment, or whether
   publication requires a distinct second reviewer through "prevent
   self-review".

The following are not open maintainer choices:

- hosted fast-profile timing remains advisory and the local registered host
  remains binding;
- fully qualified refs are mandatory even if the release branch is renamed;
- exact artifact hash comparison is binding; and
- coverage retry disposition follows evidence, not preference.

Whether v0.2.3 is submitted to CRAN may remain conditional. It does not block
this RFC.

## 4. Required next stage

Codex writes seed v2. It should retain the seed's evidentiary standard and
incorporate:

1. commit-only candidate identity and certificate-bound outputs;
2. a complete census of workflow, playbook, standing and conditional gates;
3. the dispatched publication workflow with explicit hash failure, durable
   release assets and qualified refs;
4. the existing fast-profile owner and an evidence-based retry rule;
5. the reduced `release_evidence` field;
6. an M4-produced exact minimum-environment manifest;
7. the expanded rehearsal measurements;
8. native diagnostic outputs without a custom parser; and
9. the corrected single-tarball CRAN rule.

After the maintainer resolves the two publication-authority choices, Claude
writes the synthesis under the author rotation. A Type 1 final review then
checks the resulting workflow claims and failure-sensitive implementation
gates.
