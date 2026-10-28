# RFC Seed v2: Release Candidate Certification and Evidence Reuse

**Status:** Seed v2; maintainer decisions incorporated; awaiting decision
synthesis.
**Author:** Codex, 2026-10-28.
**Window:** v0.2.3, before the next publication cut.
**Question:** how should ledgr certify one exact release candidate once, reuse
that evidence safely, and promote the candidate to `main`, a release tag, the
site and a GitHub Release without rebuilding or weakening the release gates?

This seed is non-binding. It revises
[seed v1](rfc_release_candidate_ci_evidence_v0_2_3_seed.md) after Claude's
[Type 2 response](rfc_release_candidate_ci_evidence_v0_2_3_response.md),
Codex's
[response review](rfc_release_candidate_ci_evidence_v0_2_3_response_review.md)
and the maintainer decisions of 2026-10-28.

The RFC remains the focused cycle registered as WS13 in the accepted
[v0.2.3 macro plan](../ledgr_v0_2_3_spec_packet/macro_plan.md). It redesigns
the release process, not the evidentiary standard. "First implementation"
means the first implementation of this certification design, not ledgr
v1.0.0.

## 1. Inputs and observed failure

The primary evidence is:

- the [v0.2.2 release-gate closeout](../ledgr_v0_2_2_spec_packet/release_gate_closeout.md);
- the current [release CI playbook](../release_ci_playbook.md);
- `.github/workflows/R-CMD-check.yaml` and `.github/workflows/pkgdown.yaml`;
- the accepted [v0.2.3 macro plan](../ledgr_v0_2_3_spec_packet/macro_plan.md);
- seed v1, the Type 2 response and the response review; and
- the live public repository settings checked on 2026-10-28.

v0.2.2 did not take about eight hours because one correctness gate was too
strict. It took that long because release engineering happened serially after
the product was believed finished:

1. recorded local gates consumed at least 5,153 seconds, about 85.9 minutes,
   before failed setup attempts, terminal evidence and remote CI;
2. overlapping checks then ran on a release branch, a dispatched full tier,
   `main` and the release tag;
3. local Ubuntu could not supply the declared R and DuckDB floors;
4. the isolated-CRAN environment affected the later coverage process;
5. DuckDB 2.0.0 reached ordinary CI while the golden catalogue still named
   1.5.6; and
6. the evidence needed to promote an already-tested commit was decided while
   the release was in progress.

The current full workflow has planning, two lint jobs and one matrix job.
Inside each matrix cell, README checks, acceptance tests, the fast profile,
isolated-CRAN preparation where selected, `R CMD check` and coverage where
selected run serially. `pkgdown` is a separate main-only build and deploy
workflow. The playbook then asks for local, branch, full-branch, main and tag
evidence in sequence.

The live repository is public and `main` is unprotected. The current release
branch is `refs/heads/v0.2.3`, the short name intended for the eventual tag.
The current nightly full matrix uses current dependencies on Ubuntu current R,
Windows current R and Ubuntu R 4.6. It does not measure a coherent minimum
dependency environment.

The observed failure is duplication, late discovery and environment coupling.
Removing tests or accepting unexplained failures would not fix it.

## 2. Goals and non-negotiables

The first implementation provides:

1. one exact candidate identity;
2. one build of the source tarball;
3. a parallel gate graph with named owners;
4. evidence reuse only where inputs are proven unchanged;
5. isolated toolchain variants;
6. explicit binding, advisory and conditionally binding gates;
7. actionable diagnostics from existing evidence owners;
8. finite retry and stop rules; and
9. promotion of the certified outputs without another build.

The following are non-negotiable:

- correctness, coverage, platform, documentation and registered-record gates
  are not removed merely to shorten publication;
- the maintainer explicitly authorizes publication;
- a changed source commit is a new candidate;
- deterministic failure is not infrastructure noise;
- registered-host clocks are not inferred from hosted-runner clocks;
- private Sharadar data never enters hosted CI;
- a downloaded artifact is verified by a failing hash comparison, not a
  warning; and
- neither `main` nor a published release tag is force-moved to escape a gate.

## 3. Candidate, build products and certificate

### 3.1 Candidate identity

The candidate is one commit in the ledgr repository:

```text
candidate_id = (repository = "blechturm/ledgr", commit_sha)
```

Within a workflow for this repository, the full commit SHA is sufficient as
the candidate key. The package version, workflow definitions, gate catalogue,
source and generated files are derived from that commit. There is no separate
`gate_spec_version` in candidate identity.

Resolved dependencies are not candidate identity. Current dependencies may
resolve differently tomorrow for the same commit. Re-certifying the same
commit after upstream drift creates a new certificate for the same candidate,
not a new candidate.

### 3.2 One source build

G0 checks out the exact candidate and runs `R CMD build` once. The normal build
path builds the package vignettes. The resulting source tarball is immutable
input to every package-check job.

The tarball SHA-256 is a certified build output, not part of candidate
identity. `R CMD build` adds build metadata, so rebuilding the same commit is
not an accepted way to recover the certified bytes.

If a release is submitted to CRAN, the exact G0 tarball is checked by
win-builder and submitted to CRAN. There is no CRAN-specific second build.
`R CMD check --no-build-vignettes` may avoid rebuilding vignettes during a
check; it does not define a different source tarball.

### 3.3 Candidate certificate

One certification workflow run emits one machine-readable certificate and one
human-readable summary. The certificate contains:

- repository and candidate commit;
- package version derived from the candidate;
- source-tarball SHA-256 and site-bundle SHA-256;
- every gate ID, classification, outcome and owner;
- workflow, run, attempt and job identifiers;
- the exact environment manifest for every job;
- hashes of named evidence bundles;
- any authorized advisory miss or skipped conditional gate, with its reason;
  and
- the certificate schema version.

Multiple certificates may name one candidate. Publication selects exactly one
successful certificate and records its workflow run ID.

During certification the tarball, site bundle, certificate and evidence are
workflow artifacts. GitHub artifacts expire. Publication therefore attaches
the certificate and certified source tarball to the GitHub Release before
expiry and retains the site-bundle digest in the certificate. The release
closeout links those durable assets.

The certificate does not reproduce ledgr snapshot, configuration, run or store
identity. The candidate commit does not contain its own future workflow IDs.

## 4. Gate census, graph and ownership

### 4.1 Pre-candidate local evidence

Two evidence families cannot honestly move to generic hosted runners:

- registered-host timing gates; and
- private Sharadar real-data checks.

They run when their declared inputs change, normally at workstream close.
Before certification, the process either finds a current accepted record or
requires a rerun. Hosted CI validates committed records and their corruption or
self-checks; it does not pretend to reproduce the clock or private data.

The conditional local WSL gate is also pre-candidate evidence. It runs when the
playbook's OS-sensitive trigger fires. It is early warning, not a substitute
for the binding hosted Ubuntu jobs.

M4 install-floor measurement precedes the minimum-dependency job. Section 5.2
defines its output.

### 4.2 Complete disposition of current release gates

The implementation cut carries a source-derived census. Every current workflow
step, playbook prerequisite, standing release claim and conditional external
check gets one owner or one explicit retirement reason. The initial mapping is:

| Current evidence or step | New owner | Disposition |
| --- | --- | --- |
| Candidate checkout and version | G0 | Replaced by exact-SHA identity check. |
| Source build | G0 | Build once; upload certified tarball. |
| Formatting and semantic lint | G1 | Parallel source checks. |
| README installed cold-start | G2 | Binding current-environment check. |
| v0.1.x acceptance tests | G2 | Binding current-environment check. |
| Full package tests | G2 and G4 | Native package/test owners; no release-day duplicate. |
| Ubuntu current `R CMD check` | G2 | Binding. |
| Ubuntu minimum environment | G3 | New measured-floor lane. |
| Windows CRAN-style check | G4 | Binding. |
| Ordinary fast profile | G2 and G9 | Test outcomes bind; hosted time advises; local record binds conditionally. |
| Isolated-CRAN preparation/profile | G5 | Separate clean job. |
| Coverage | G6 | Separate clean job. |
| Article freshness | G7 | Binding documentation check. |
| Pkgdown build | G7 | Build certified site bundle once. |
| Agent-context and design-index close checks | G7 | Binding source-governance checks. |
| Review profile | G8 | Binding. |
| Profile completeness | G8 | Binding. |
| Rule-4 golden-root reproduction | G9 | Registered-record validation. |
| Standing Sharadar claim boundary | G7 and G9 | Documentation pin plus registered detector. |
| Terminal-outcome release fixture | G9 | Binding registered release fixture. |
| Private Sharadar records | Pre-candidate plus G9 | Rerun conditionally; validate committed aggregate evidence. |
| Registered-host clocks | Pre-candidate plus G9 | Rerun conditionally; hosted clocks do not substitute. |
| Conditional WSL gate | Pre-candidate | Retained under the existing trigger. |
| Win-builder | Conditional publication prerequisite | Exact G0 tarball, only for CRAN submission. |
| Branch, `main` and tag rebuilds | Retired | Exact candidate certificate replaces ref-movement rebuilds. |
| Main-push pkgdown rebuild | Retired for releases | Deploy G7 bundle; manual site-only dispatch remains. |

This table is an initial binding census, not permission to omit a step found by
implementation. The cut regenerates it from both workflows and the playbook.
An existing gate absent from the final census is a defect.

### 4.3 Remote candidate DAG

```text
G0 candidate identity and one source build
 |
 +-- G1 formatting and semantic lint
 +-- G2 Ubuntu, current R and current dependencies
 +-- G3 Ubuntu, minimum R and measured minimum environment
 +-- G4 Windows CRAN-style check
 +-- G5 isolated-CRAN test profile
 +-- G6 coverage
 +-- G7 article, documentation, governance and pkgdown build
 +-- G8 review profile and release-profile completeness
 +-- G9 registered-record validation
 |
 `-- G10 aggregate certificate
```

G1 inspects the exact checkout. G2-G6 consume the G0 source tarball. G7 builds
the site from the exact candidate and emits one deployable bundle. G8 and G9
may use the checkout where existing runners require it, but record the same
candidate and declared environment.

Logical independence controls dependencies. A failed independent job does not
cancel siblings whose evidence remains useful. G10 waits for every applicable
gate and refuses any unexplained binding failure.

### 4.4 Ownership

The certification workflow owns candidate identity, artifact handoff and G10.
Existing tools continue to own their results: linters own lint, `R CMD check`
owns package checks, the test control plane owns test-profile selection and
completeness, and registered checkers own their records.

G10 composes native outcomes. It does not reinterpret red as green and does
not introduce another test or evidence system.

## 5. Toolchain isolation

### 5.1 Job isolation

Every gate job receives a clean process, its own R library and its own
environment manifest. In particular:

- isolated-CRAN preparation and coverage are separate jobs;
- environment variables and library paths do not flow between gates;
- caches are keyed by OS, R version, dependency policy and dependency files;
- a cache hit changes download cost, not the declared environment; and
- current dependencies discover upstream drift before release day.

The manifest records OS image, R version, direct and transitive package
versions and sources, Quarto/Pandoc versions where used, compiler information
where relevant and the exact command. Failed setup is unavailable or
infrastructure failure, never a pass.

### 5.2 Measured minimum environment

`DESCRIPTION` alone cannot define an exact minimum environment. Several hard
dependencies have no declared version floor, and transitive dependencies are
not listed there.

M4 produces a complete coherent minimum-environment manifest before G3 is
implemented. It:

1. measures the supported minimum version of every hard direct dependency;
2. records any new supported direct floor in `DESCRIPTION`;
3. resolves a coherent set of exact direct and transitive versions;
4. records package sources or repository snapshot needed to recover them; and
5. proves the package can install and pass the owning floor checks.

G3 creates a clean library from that exact manifest and fails if any installed
version differs. R itself uses the declared R floor. A dated package-repository
snapshot may supply archived packages, but the snapshot date is not the
minimum-environment identity and may not silently substitute current versions.

If an exact recorded environment cannot be installed, G3 reports unavailable
and blocks certification until the support floor is deliberately changed or
the environment is restored. The minimum lane runs nightly as well as for a
candidate.

## 6. Evidence reuse and invalidation

### 6.1 Safe default

Certificate evidence is reusable across a release branch, `main`, a tag and
publication only when all resolve to the exact candidate commit and certified
tarball.

A changed commit requires a new certificate by default. The first
implementation does not infer safety from a broad path filter or build a
generic cross-commit evidence cache. This captures the largest saving: moving
references no longer repeats certification.

### 6.2 Named heavyweight evidence

Registered-host timing and private real-data records may cross commits only
when the record has:

- a named owner and declared invalidation set;
- source commit, environment and reproduction command;
- a checker that detects changed or corrupted evidence; and
- an explicit `rerun`, `reuse` or `not_applicable` disposition at the latest
  owning workstream close.

The default for an undeclared dependency is rerun. Governance-only changes do
not automatically grant reuse; the declared input set does.

### 6.3 Small ticket field

The first implementation does not add a `release_impact` classification
taxonomy. A workstream that owns a named heavyweight record uses only:

```yaml
release_evidence:
  - id: fast-profile-reference
    action: rerun        # rerun | reuse | not_applicable
    reason: fold hot path changed
```

Absence means no named heavyweight record applies. `reuse` and
`not_applicable` require a reason. Committed registered records are still
validated by G9 whether or not this field appears. NEWS and documentation
currency remain close-review duties under the macro plan.

## 7. Binding, advisory and conditional gates

**Binding remote gates:** candidate identity; lint; current and minimum
package checks; Windows CRAN-style check; test-profile completeness; isolated
CRAN; coverage threshold; documentation freshness; pkgdown build; and every
registered record checker required by the release.

**Conditionally binding local or external gates:** registered-host timing,
private real-data records, the local WSL gate and win-builder when their
declared triggers fire. Their accepted records or results must exist before
G10 or publication, as the census specifies.

**Advisory measurements:** hosted-runner wall clocks and unregistered
characterization. They remain visible. An overrun is recorded as an overrun,
not as a pass.

The registered local host owns the fast-profile budget in
`tests/test-gates.yml`. `ubuntu-latest` does not. Implementation corrects the
current workflow comment that calls both the hosted runner and the local
reference machine the registered runner.

A maintainer exception records a failed bound and release-scoped reason. It
does not relabel the measurement.

## 8. Diagnostics

Every gate summary records:

- gate ID, owner and binding class;
- candidate commit and tarball hash;
- exact command and environment manifest;
- outcome and duration;
- the smallest named failing block or package frame exposed by the owning
  tool; and
- links to native logs and uploaded evidence.

G10 presents one status table and distinguishes product failure, test failure,
infrastructure failure, unavailable environment, advisory miss and authorized
exception.

The implementation uses existing outputs from testthat, `R CMD check`, the
test control plane, registered checkers and GitHub job summaries. JUnit may be
used as a presentation adapter where useful; it is not required and does not
become a second source of truth. No custom stack-frame log parser is required.

## 9. Retry and stop rules

One retry is allowed only for a declared transient class such as runner loss,
network or mirror failure, or an accepted native-abort signature. It reuses the
same candidate in a new clean job and records both attempts.

Separating coverage from isolated-CRAN setup removes one known contamination
route. That architectural change alone does not prove the existing
coverage-only native-abort class deterministic. The first rehearsal keeps its
single retry. Later evidence may retire or narrow the class.

A deterministic assertion, lint, documentation, identity or record-checker
failure gets no blind retry. A second occurrence of an alleged transient
failure blocks publication pending investigation.

The release stops when:

- a fix changes the candidate commit;
- the suspected fix expands beyond the failing subsystem;
- a dependency floor or format decision remains open;
- binding local evidence is missing;
- artifact bytes disagree with the certificate; or
- publication would move or delete a published release tag.

Product corrections return to ordinary tickets and review. Release day does
not create an exemption.

## 10. Publication without rebuilding

### 10.1 Publication workflow

Publication is one `workflow_dispatch` workflow. Its input is the successful
certification workflow run ID. Dispatch starts verification but does not grant
publication authority.

The mutating publication job uses a protected GitHub environment. The
maintainer is its required reviewer. "Prevent self-review" is off: the
maintainer may dispatch and approve the job. Agents may dispatch the workflow,
but they cannot approve the protected environment and therefore cannot publish
on their own.

After approval, the workflow:

1. downloads the certificate, tarball and site bundle from the named run using
   a token and run ID;
2. verifies that the run, repository, candidate and successful G10 outcome
   match the certificate;
3. computes SHA-256 over the downloaded tarball and site bundle and fails on
   any mismatch with the certificate, independently of GitHub's artifact
   warning;
4. verifies that the intended `main` and new tag will name the candidate;
5. fast-forwards `refs/heads/main` to the candidate where necessary;
6. creates `refs/tags/vX.Y.Z` at that exact commit;
7. uploads the verified site bundle as the Pages artifact of the publication
   run and deploys it unchanged;
8. creates the curated GitHub Release and attaches the certificate and source
   tarball; and
9. emits the URLs and hashes needed by the post-publication closeout.

A tag created with `GITHUB_TOKEN` does not start a second certification run.
The tag-triggered full tier is removed. A push to `main` does not rebuild the
release site. Manual pkgdown dispatch remains available for deliberate
out-of-release site-only work.

All ref reads and writes use full names. Renaming release branches to
`release/vX.Y.Z` is recommended for clarity, but safety does not depend on the
short name.

### 10.2 Minimal repository ruleset

The v0.2.3 implementation adds only the maintainer-approved ref protections:

- `refs/heads/main` cannot be force-pushed or deleted;
- an existing `refs/tags/v*` cannot be updated or deleted; and
- creation of a new `refs/tags/v*` remains possible through publication.

No required status check is added to `main`. The publish workflow is the sole
release path by governance and protected-environment authority, not by making
every ordinary merge wait for release certification.

The implementation records the exact ruleset configuration and proves in the
publication dry run that the workflow can fast-forward `main` and create a new
tag but cannot rewrite either protected ref.

## 11. Rehearsal and release practice

At least one complete candidate rehearsal runs before the publication cut. It
records:

- remote critical-path and total time;
- maintainer-attended time;
- queued-before-start time without assuming one universal cause;
- cold- and warm-cache setup time;
- Windows check duration;
- artifact upload and cross-run download time;
- a non-public publication dry run;
- explicit certificate rejection of a deliberately altered artifact;
- protected-environment approval behavior; and
- diagnostic usefulness under at least one deliberate failing gate.

Only after the rehearsal are service targets bound. Planning hypotheses remain
at most 45 minutes for certification and at most 30 minutes of attended
release-day work. A miss changes implementation or the consciously chosen
target, not correctness evidence.

User-visible work updates the current release's `NEWS.md` section in its own
cut. This is separate from M6's historical NEWS collapse for the first CRAN
release. Documentation, examples and generated help change with their owning
product work. Release closeout checks coherence; it is not the first author of
the release's teaching.

Release day contains verification, authorization, promotion and smoke
confirmation. It contains no dependency upgrade, product fix, documentation
rewrite, local toolchain installation or broad benchmark generation.

## 12. Playbook, workflow and packet impact

This RFC changes release governance and CI evidence boundaries, not ledgr's
execution, accounting, persistence or research semantics.

If accepted, the bounded WS13 implementation cut must:

1. replace the release-order and green-definition sections of the playbook;
2. add and maintain the complete gate census;
3. split the serial matrix work into the accepted DAG;
4. add the candidate certificate and protected publication workflow;
5. separate pkgdown build from deployment and reuse the candidate site bundle;
6. implement M4 and the exact minimum-environment lane;
7. replace `release_impact` with the smaller `release_evidence` convention;
8. configure and verify the minimal ref ruleset and publication environment;
9. record the rehearsal and failure injections before publication; and
10. retain applicable Ubuntu/DuckDB, coverage, standing-claim and surgery
    lessons through their mapped owners.

At acceptance the pipeline row moves to `Obligations open` and the decisions
bridge records the pending change. The row leaves only when the implementation
cut owns all obligations.

## 13. Rejected alternatives

**Keep the current sequence and document it better.** Rejected: it repeats
evidence and discovers drift late.

**Run the full suite on branch, `main` and tag.** Rejected: reference movement
is not a source change; exact identity plus a certificate is stronger than
three rebuilds.

**Put tarball and toolchain into candidate identity.** Rejected: they are
certificate inputs and outputs. One commit can have later certificates after
dependency drift without becoming another candidate.

**Reuse evidence automatically across changed commits.** Rejected for the
first implementation: a general invalidation engine is larger than the
observed problem.

**Classify every workstream by release impact.** Rejected: the classes do not
change an action. Only named heavyweight evidence needs a disposition.

**Derive minimum dependencies from `DESCRIPTION` alone.** Rejected: unbounded
direct and transitive dependencies make that incomplete.

**Make the maintainer workstation the orchestrator.** Rejected: local
registered-host evidence stays local, but publication must not depend on
release-day WSL or dependency installation.

**Treat hosted timing as binding.** Rejected: registered-host records own
performance bounds.

**Trust GitHub's artifact-digest warning.** Rejected: a binding integrity gate
must fail on mismatch.

**Build pkgdown or a CRAN tarball again after certification.** Rejected: deploy
and submit the certified outputs unchanged.

**Require release certification on every update to `main`.** Rejected for the
first implementation: the maintainer chose minimal ref protection and one
authorized publication path without changing ordinary merge workflow.

## 14. Changes from seed v1

Seed v2 makes these material changes:

1. Candidate identity is repository plus commit SHA. Package version and gate
   definitions derive from the commit; tarball, site and environments belong
   to the certificate.
2. The gate graph now carries an initial complete mapping of workflow,
   playbook, standing and conditional gates, including WSL, terminal fixture,
   Sharadar boundary and win-builder.
3. Tag-triggered recertification is replaced by one protected, manually
   dispatched publication workflow that reuses the certified outputs.
4. Publication performs its own failing SHA-256 comparison, publishes durable
   release assets and uses fully qualified refs.
5. The local registered host remains the timing owner. Hosted timing is
   advisory, and coverage retry changes only on evidence rather than job
   isolation alone.
6. `release_impact` is removed. A smaller `release_evidence` list exists only
   where a named heavyweight record needs rerun or reuse disposition.
7. M4 produces a full exact direct-and-transitive minimum-environment manifest;
   G3 does not infer one from `DESCRIPTION`.
8. Rehearsal adds queue, cache, Windows, transfer, dry-run, approval and tamper
   measurements.
9. Diagnostics compose native outputs; JUnit is optional and no stack-log
   parser is introduced.
10. The CRAN rule now submits the exact G0 tarball, whose normal build includes
    vignettes. `--no-build-vignettes` is recognized as a check option.
11. The maintainer chose minimal protection for `main` and `v*` tags, without
    a required status check on `main`.
12. The maintainer chose a protected publication environment with self-approval
    allowed; agents may dispatch but cannot approve publication.

The correctness, coverage, platform, documentation, registered-record and
explicit-authorization standards from seed v1 are unchanged.

## 15. Next RFC stage

Claude writes the decision synthesis, weighing seed v2 against the response
and response review. The synthesis must preserve the two maintainer decisions,
name any rejected response alternative, and promote implementation questions
to the bounded WS13 cut rather than redesigning release evidence again.

A Type 1 final review by an author of neither seed v2 nor the synthesis then
checks the workflow claims, gate census, failure-sensitive integrity checks,
minimum-environment mechanism and publication authority. Maintainer acceptance
routes the playbook, workflows, packet convention, repository settings and
rehearsal obligations to implementation.
