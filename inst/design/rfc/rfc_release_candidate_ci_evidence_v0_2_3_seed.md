# RFC Seed: Release Candidate Certification and Evidence Reuse

**Status:** Seed v1; awaiting Type 2 response.
**Author:** Codex, 2026-10-28.
**Window:** v0.2.3, before the next publication cut.
**Question:** how should ledgr certify one exact release candidate once, reuse
that evidence safely, and promote the candidate to `main`, a release tag, the
site and a GitHub Release without rebuilding or weakening the release gates?

This seed is non-binding. It starts the focused cycle registered as WS13 in
the accepted [v0.2.3 macro plan](../ledgr_v0_2_3_spec_packet/macro_plan.md).
It redesigns the release process, not the evidentiary standard.

This RFC uses "first implementation" for the first implementation of this
candidate-certification design. It does not mean ledgr v1.0.0.

## 1. Inputs and observed failure

The primary evidence is:

- the [v0.2.2 release-gate closeout](../ledgr_v0_2_2_spec_packet/release_gate_closeout.md);
- the current [release CI playbook](../release_ci_playbook.md);
- `.github/workflows/R-CMD-check.yaml` and `.github/workflows/pkgdown.yaml`;
- the accepted [v0.2.3 macro plan](../ledgr_v0_2_3_spec_packet/macro_plan.md);
- the RFC pipeline row that triggered this cycle.

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

The observed failure is duplication, late discovery and environment coupling.
Removing tests or accepting unexplained failures would not fix it.

## 2. Goals and non-negotiables

The first implementation should provide:

1. one exact candidate identity;
2. a parallel gate graph with named owners;
3. evidence reuse only where inputs are proven unchanged;
4. isolated toolchain variants;
5. explicit binding, advisory and conditionally binding gates;
6. actionable diagnostics;
7. finite retry and stop rules; and
8. promotion of the certified artifact without another build.

The following are non-negotiable:

- correctness, coverage, platform, documentation and registered-record gates
  are not removed merely to shorten publication;
- the maintainer explicitly authorizes publication;
- a changed source commit is a new candidate;
- deterministic failure is not infrastructure noise;
- registered-host clocks are not inferred from hosted-runner clocks; and
- private Sharadar data never enters hosted CI.

## 3. Candidate identity

### 3.1 Candidate tuple

A candidate is the tuple:

```text
candidate = (
  commit_sha,
  package_version,
  source_tarball_sha256,
  gate_spec_version,
  declared_toolchain_matrix
)
```

The commit is frozen before certification. It already contains the intended
version, current `NEWS.md`, generated documentation, examples, metadata and
release-note source. The source tarball is built once from that commit. Every
package-check job consumes the same tarball. Source-only checks inspect the
same checked-out commit.

The toolchain matrix identifies the R, OS and dependency policy of every
gate. It is certification input, not a claim that all jobs use identical
binaries.

Any repository change creates a new commit and therefore a new candidate.
Release closeout edits happen after publication and never alter the tag.

### 3.2 Candidate certificate

The certification workflow emits one machine-readable certificate and one
human-readable summary. The certificate contains:

- the candidate tuple;
- every gate ID, classification, outcome and owner;
- workflow and job identifiers;
- hashes of the tarball, site artifact and named evidence bundles;
- the environment manifest for every job; and
- any authorized advisory miss or skipped conditional gate, with its reason.

This is a release-engineering record. It does not reproduce ledgr snapshot,
configuration, run or store identity.

During certification it is a workflow artifact. At publication it is attached
to, or linked durably from, the GitHub Release and summarized by the
post-publication closeout. The candidate commit does not contain its own future
workflow IDs.

## 4. Gate graph and ownership

### 4.1 Pre-candidate local evidence

Two evidence families cannot honestly move to generic hosted runners:

- registered-host timing gates; and
- private Sharadar real-data checks.

They run when their declared inputs change, normally at workstream close.
Before certification, the process either finds a current accepted record or
requires a rerun. Hosted CI validates committed records and their corruption
or self-checks; it does not pretend to reproduce the clock or private data.

M4 install-floor measurement precedes the minimum-dependency job. That job
tests measured floors, not merely the oldest R with current packages.

### 4.2 Remote candidate DAG

```text
G0 candidate identity and one source build
 |
 +-- G1 formatting and semantic lint
 +-- G2 Ubuntu, current R and current dependencies
 +-- G3 Ubuntu, minimum R and measured minimum dependencies
 +-- G4 Windows CRAN-style check
 +-- G5 isolated-CRAN test profile
 +-- G6 coverage
 +-- G7 article freshness, documentation and pkgdown build
 +-- G8 review profile and release-profile completeness
 +-- G9 registered-record validation
 |
 `-- G10 aggregate certificate
```

G1 inspects the checkout. G2-G6 consume the source tarball. G7 builds the site
from the exact candidate and emits the deployable artifact. G8 and G9 may use
the checkout where existing runners require it, but record the same commit and
toolchain input.

Logical independence, not the old checklist order, controls dependencies.

### 4.3 Ownership

The release workflow owns candidate identity, artifact handoff and G10. The
existing tools continue to own their results: linters own lint, `R CMD check`
owns package checks, the test control plane owns profile completeness, and
registered checkers own their records. The release workflow composes those
outcomes; it does not reinterpret red as green.

Pkgdown build and deployment separate. G7 builds once during certification.
Publication deploys that artifact. A push to `main` does not replace it with a
new build for the same release.

## 5. Toolchain isolation

Every gate job receives a clean process, its own R library and its own
environment manifest. In particular:

- isolated-CRAN preparation and coverage are separate jobs;
- environment variables and library paths do not flow between gates;
- caches are keyed by OS, R version, dependency policy and dependency files;
- a cache hit changes download cost, not the declared environment;
- minimum dependencies install measured floors explicitly; and
- current dependencies discover upstream drift before release day.

The manifest records OS image, R version, gate-relevant package versions,
Quarto/Pandoc versions where used and the exact command. Failed setup is
reported as unavailable or infrastructure failure, never as a pass.

Local WSL remains early warning. It is not a publication prerequisite when
the binding hosted Ubuntu jobs cover the declared matrix.

## 6. Evidence reuse and invalidation

### 6.1 Safe default

Certificate evidence is reusable across a release branch, `main`, a tag and
publication only when all resolve to the exact certified commit and tarball.

A changed commit invalidates the certificate by default. The first
implementation does not build a generic cross-commit cache or infer safety
from a broad path filter. This captures the largest saving: moving references
no longer repeats certification.

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

### 6.3 `tickets.yml` release-impact field

Each implementation workstream gets one field in the sole ticket authority:

```yaml
release_impact:
  classes: [runtime, performance]
  evidence:
    - id: fast-profile-ordinary
      action: rerun
      reason: fold hot path changed
```

Allowed classes are `runtime`, `persistence_identity`, `dependencies`,
`documentation`, `performance`, `ci_release` and `none`; `none` may not appear
with another class.

Evidence entries are required only for named local or heavyweight records.
Actions are `rerun`, `reuse`, `validate` or `not_applicable`; `reuse` and
`not_applicable` require a reason. This field schedules and explains evidence.
It never authorizes skipping the candidate DAG.

## 7. Binding and advisory gates

**Binding remote gates:** candidate identity; lint; current and minimum
package checks; Windows CRAN-style check; test-profile completeness; isolated
CRAN; coverage threshold; documentation freshness; pkgdown build; and every
registered record checker required by the release.

**Conditionally binding local gates:** registered-host timing and private
real-data records when their declared inputs changed or the release definition
of done names them. Their accepted records must exist before G10.

**Advisory measurements:** hosted-runner wall clocks and unregistered
characterization. They remain visible. An overrun is recorded as an overrun,
not as a pass.

The synthesis may adjust individual classifications, but no gate remains
implicit. A maintainer exception records the failed bound and release-scoped
reason; it does not relabel the measurement.

## 8. Diagnostics

Every gate summary records:

- gate ID, owner and binding class;
- candidate commit and tarball hash;
- exact command and toolchain manifest;
- outcome and duration;
- first package stack frame or smallest named failing block where available;
  and
- links to logs and uploaded evidence.

G10 presents the matrix on one page and distinguishes product failure, test
failure, infrastructure failure, unavailable environment, advisory miss and
authorized exception. Independent jobs finish even when one fails. A job stops
after its first decisive failure unless its owning tool requires a complete
registered report.

## 9. Retry and stop rules

One retry is allowed only for a declared transient class such as runner loss,
network or mirror failure, or the recorded coverage-only native abort after
preceding checks passed. It reuses the same candidate in a clean environment.

A deterministic assertion, lint, documentation, identity or record-checker
failure gets no blind retry. A second occurrence of alleged transient failure
blocks publication pending investigation.

The release stops when:

- a fix changes the candidate commit;
- the suspected fix expands beyond the failing subsystem;
- a dependency floor or format decision remains open;
- binding local evidence is missing; or
- publication would move a tag from a published release.

Product corrections return to ordinary tickets and review. Release day does
not create an exemption.

## 10. Promotion without rebuilding

After G10 is green, a manually authorized publication action:

1. verifies that the release branch, intended `main` head and tag can name the
   certified commit;
2. fast-forwards `main` where necessary;
3. creates the tag at that exact commit;
4. verifies certificate and artifact hashes;
5. deploys the certified site artifact;
6. creates the curated GitHub Release and attaches or links the certificate;
   and
7. records URLs in a post-publication closeout commit.

The tag-triggered action is an identity and authorization check, not another
full build. If branch protection prevents exact promotion, it stops rather
than creating a different merge candidate.

Publication retains explicit maintainer approval, preferably through a
protected GitHub environment. Green CI alone never publishes.

## 11. Development and release practice

User-visible work updates the current release's `NEWS.md` section in its own
cut. This is separate from M6's historical NEWS collapse for the first CRAN
release.

Documentation, examples and generated help change with their owning product
work. Release closeout checks coherence; it is not the first author of the
release's teaching.

At least one full candidate rehearsal runs before the publication cut. It
measures remote critical-path time, maintainer-attended time, setup/cache time,
artifact handoff, promotion dry-run time and diagnostic usefulness under at
least one deliberate failing gate.

Only after that rehearsal are service targets bound. Planning hypotheses are
at most 45 minutes for certification and at most 30 minutes of attended
release-day work. A miss changes implementation or the consciously chosen
target, not correctness evidence.

Release day contains verification, authorization, promotion and smoke
confirmation. It contains no dependency upgrade, product fix, documentation
rewrite, local toolchain installation or broad benchmark generation.

## 12. Playbook and workflow impact

This RFC changes release governance and CI evidence boundaries, not ledgr's
execution, accounting, persistence or research semantics.

If accepted, implementation must:

1. replace the release-order and green-definition sections of the playbook;
2. split the serial matrix work into the accepted DAG;
3. add certificate and promotion actions;
4. separate pkgdown build from deployment and reuse the candidate artifact;
5. implement the measured minimum-dependency lane after M4;
6. add `release_impact` to the v0.2.3 workstream convention;
7. record a rehearsal and failure injection before publication; and
8. retain the applicable Ubuntu/DuckDB, coverage and surgery lessons.

At acceptance the pipeline row moves to `Obligations open`. It leaves only
when an implementation cut owns these obligations.

## 13. Rejected alternatives

**Keep the current sequence and document it better.** Rejected: it repeats
evidence and discovers drift late.

**Run the full suite on branch, `main` and tag.** Rejected: reference movement
is not a source change; exact identity plus a certificate is stronger than
three rebuilds.

**Reuse evidence automatically across changed commits.** Rejected for the
first implementation: a general invalidation engine is larger than the
observed problem.

**Make the maintainer workstation the orchestrator.** Rejected: local
registered-host evidence stays local, but publication must not depend on
release-day WSL or dependency installation.

**Treat hosted timing as binding.** Rejected: registered-host records own
performance bounds.

**Build pkgdown again after merge.** Rejected for the release artifact: deploy
the certified site unchanged.

## 14. Questions for the Type 2 response

1. Is the candidate tuple sufficient, or does it conflate certificate input
   with candidate identity?
2. Does the DAG preserve every useful gate, and are jobs still coupled?
3. Is exact-SHA reuse plus named heavyweight exceptions the smallest safe
   invalidation policy?
4. Is `release_impact` useful enough to justify its cost? If not, what smaller
   existing record carries the same information?
5. Can `main`, tag and site promotion safely rely on the certificate under
   GitHub Actions and branch protection, or is a narrow fresh proof required?
6. Are the minimum/current toolchain lanes specified strongly enough to avoid
   the v0.2.2 dependency-floor failure?
7. Are the binding/advisory and retry rules too broad or permissive?
8. Do diagnostics expose enough without creating a second evidence system?
9. What else must the first rehearsal measure before targets become binding?
10. Which proposal adds more machinery than the observed failure warrants?

## 15. Proposed cycle sequence

1. Claude writes the Type 2 response and checks the current workflows and
   GitHub constraints, not this document only in prose.
2. Codex reviews the response and separates factual corrections from
   maintainer choices.
3. Codex writes seed v2 if the architecture changes materially.
4. The maintainer resolves any publication-authority choices.
5. Claude writes synthesis if Codex writes v2; otherwise the maintainer assigns
   a synthesis author different from the last seed author.
6. Type 1 final review checks workflow claims and implementation gates.
7. Acceptance routes the playbook, workflow, field and rehearsal obligations
   to a bounded WS13 cut.
