# Synthesis: Release Candidate Certification and Evidence Reuse

Role: record; RFC-cycle synthesis and durable decision record.
Status: accepted
Authority: accepted synthesis; binds only its stated scope.

**Accepted by the maintainer on 2026-10-28** after the Type 1
[final review](rfc_release_candidate_ci_evidence_v0_2_3_final_review.md)
(PASS_AFTER_PATCHES, then PASS_AFTER_ONE_RECORD_PATCH on focused
confirmation, record patch applied). Acceptance does not claim implementation;
the WS13 cut owns it.

**Date:** 2026-10-28
**Author:** Claude, who did not write seed v2.
**Synthesizes:** [seed v2](rfc_release_candidate_ci_evidence_v0_2_3_seed_v2.md),
[seed v1](rfc_release_candidate_ci_evidence_v0_2_3_seed.md), the
[Type 2 response](rfc_release_candidate_ci_evidence_v0_2_3_response.md) and the
[response review](rfc_release_candidate_ci_evidence_v0_2_3_response_review.md).
**Checked against:** `.github/workflows/R-CMD-check.yaml`,
`.github/workflows/pkgdown.yaml`, the [release playbook](../release_ci_playbook.md),
the [release-gates contract group](../contracts.md#contract-verification-release-gates)
and the live repository settings (public; `main` unprotected).
**Macro-plan owner:** WS13 of the accepted
[v0.2.3 macro plan](../ledgr_v0_2_3_spec_packet/macro_plan.md).
**Revision note (2026-10-28):** patched in place after the Type 1
[final review](rfc_release_candidate_ci_evidence_v0_2_3_final_review.md)
(PASS_AFTER_PATCHES): F1 binds credential separation in D10 and Section 5
item 6; F2 pins publication-workflow provenance and the Pages ref in D9; F3
extends Section 5 item 5 to all six ruleset outcomes; F4 makes Section 5
item 8 prove that the publication path ran. The review's note on item 1
(independent source inventory) is applied too. No design changed.
**Second revision (maintainer, 2026-10-28):** the maintainer clarified
decision 2 and replaced F1's separate agent credential with
prompt-confirmed approval (D10, Section 5 item 6), and chose a one-time
setup verification of the ruleset instead of a registered disposable-repository
fixture (D11, Section 5 item 5).

## 1. Decision

Adopt seed v2. ledgr certifies one exact commit once, in one parallel
certification run that builds the source tarball and site bundle once, and
publishes those certified outputs through one manually approved publication
workflow. Moving a ref never repeats certification. The evidentiary standard
of v0.2.2 is unchanged: no correctness, coverage, platform, documentation or
registered-record gate is removed.

The response review's corrections to the response stand: the source tarball
already builds vignettes (response R9 withdrawn), and `DESCRIPTION` cannot
define an exact minimum environment (response R6 revised). This synthesis adds
three items neither seed nor response carried (D9, D10 and Section 4):
publication bootstrap, approval by credential rather than by actor type, and a
conflicting contract sentence.

## 2. Maintainer decisions (2026-10-28)

1. **Ref protection:** a minimal repository ruleset. `refs/heads/main` cannot
   be force-pushed or deleted; an existing `refs/tags/v*` cannot be updated or
   deleted; creating a new `v*` tag remains possible. No required status check
   on `main`.
2. **Publication approval:** a protected environment with the maintainer as
   required reviewer; self-approval allowed ("prevent self-review" off).
   Agents may dispatch publication but must not approve it on their own.
   Clarified the same day: the intent is that a release happens only by the
   maintainer's conscious act, not a security boundary against the
   maintainer's own agents. An approval the maintainer confirms in an agent's
   permission prompt is the maintainer's approval (D10).
3. **Ruleset verification:** the six ruleset outcomes are verified once at
   setup and again whenever the ruleset changes, not by a registered fixture
   on every release.

## 3. Bound design

### D1. Candidate and certificate

The candidate is one commit of `blechturm/ledgr`; its full SHA is the key.
Package version, workflow definitions and the gate catalogue derive from it.
Resolved toolchains, gate outcomes and build products belong to a
**certificate**: one certification run over the candidate. One candidate may
have several certificates (for example after upstream drift); publication
names exactly one by its workflow run ID.

The certificate records: repository and commit; package version; source
tarball and site bundle SHA-256; every gate's ID, class, outcome and owner;
workflow, run, attempt and job IDs; each job's environment manifest; named
evidence-bundle hashes; any authorized advisory miss or skipped conditional
gate with its reason; and its schema version. It does not restate ledgr's
snapshot, configuration, run or store identity, and the candidate commit never
contains its own future workflow IDs.

### D2. One build; the CRAN rule

G0 runs `R CMD build` once on the candidate, on the normal path that builds
vignettes. The tarball is immutable input to every package-check job.
Rebuilding is not a way to recover certified bytes, because the build stamps
metadata. If a release goes to CRAN, the exact G0 tarball is checked on
win-builder and submitted; there is no second, CRAN-specific build.
`--no-build-vignettes` stays a check option only.

### D3. Gate census and DAG

The DAG is seed v2 Section 4.3: G0 identity and build; G1 lint; G2 Ubuntu
current; G3 Ubuntu minimum; G4 Windows CRAN-style check; G5 isolated CRAN;
G6 coverage; G7 articles, documentation, governance and pkgdown; G8 review
profile and profile completeness; G9 registered-record validation; G10
aggregate certificate. Independent jobs do not cancel each other; G10 waits
for every applicable gate and refuses any unexplained binding failure.

Seed v2's census table (Section 4.2) is binding as the initial mapping. The
implementation cut regenerates it from both workflows, the playbook and the
release-gates contract group; every existing step, prerequisite, standing
claim and conditional external check has an owner or a retirement reason. A
step missing from the final census is a defect, and the census is checked
mechanically at the cut (Section 5, item 1).

Pre-candidate local evidence stays local: registered-host timing, private
Sharadar records and the conditional WSL gate. They run when their declared
inputs change; certification finds a current accepted record or requires a
rerun; hosted CI validates their committed records, never their clocks or
data.

### D4. Isolation and the minimum environment

Every gate is a clean job with its own library and environment manifest
(OS image, R, direct and transitive package versions and sources,
Quarto/Pandoc where used, compiler where relevant, exact command). Isolated
CRAN preparation and coverage are separate jobs. Caches change download cost,
never the declared environment. Failed setup is reported as unavailable or
infrastructure failure, never as a pass.

M4 precedes G3 and produces a complete minimum-environment manifest: measured
floors for every hard direct dependency (new floors written to
`DESCRIPTION`), a coherent set of exact direct and transitive versions, and
the sources needed to recover them, with proof that ledgr installs and passes
its floor checks on it. G3 installs that manifest into a clean library and
fails if any installed version differs. If the manifest cannot be installed,
G3 reports unavailable and blocks certification; it never substitutes current
versions. G3 runs nightly as well as per candidate, beside the existing
nightly current-dependency matrix.

### D5. Evidence reuse

A certificate is reusable across a release branch, `main`, a tag and
publication only when all resolve to the certified commit and tarball. Any
other commit needs a new certificate. There is no cross-commit evidence cache
and no path-filter inference.

Registered-host timing and private real-data records may cross commits only
with a named owner, a declared invalidation set, source commit, environment
and reproduction command, a corruption-detecting checker, and an explicit
disposition at the owning workstream close. An undeclared dependency means
rerun.

The only new ticket convention is `release_evidence`, on workstreams that own
such a record:

```yaml
release_evidence:
  - id: fast-profile-reference
    action: rerun        # rerun | reuse | not_applicable
    reason: fold hot path changed
```

Absence means no named heavyweight record applies; `reuse` and
`not_applicable` need a reason. G9 validates committed records regardless.
The `release_impact` class taxonomy is not adopted.

### D6. Gate classes

**Binding remote:** candidate identity, lint, current and minimum package
checks, Windows check, test-profile completeness, isolated CRAN, the coverage
threshold, documentation freshness, the pkgdown build, and every registered
record checker the release requires.
**Conditionally binding local or external:** registered-host timing, private
real-data records, the WSL gate and win-builder, when their triggers fire.
**Advisory:** hosted wall clocks and unregistered characterization; an overrun
is recorded as an overrun.

The registered local host owns the fast-profile budget in
`tests/test-gates.yml`; hosted runners do not. The workflow comment that also
calls ubuntu-latest "the registered runner" (`R-CMD-check.yaml`, above the
fast-profile run-2 step) is corrected. A maintainer exception records the
failed bound and its reason without relabelling the measurement.

### D7. Diagnostics

Each gate summary records gate ID, owner, class, candidate commit, tarball
hash, command, environment manifest, outcome, duration, the smallest failing
block the owning tool exposes, and links to native logs. G10 shows one status
table distinguishing product, test and infrastructure failure, unavailable
environment, advisory miss and authorized exception. Outputs come from the
existing owners (testthat, `R CMD check`, the test control plane, registered
checkers, GitHub job summaries). No log parser and no second evidence store.

### D8. Retry and stop

One retry, in a new clean job on the same candidate, only for a declared
transient class: runner loss, network or mirror failure, or an accepted
native-abort signature. Both attempts are recorded. The coverage-only native
abort keeps its retry through the first rehearsal; later evidence may retire
it. Deterministic failures get no retry; a second occurrence of an alleged
transient failure blocks publication.

The release stops when a fix would change the candidate, a fix spreads beyond
the failing subsystem, a floor or format decision is open, binding local
evidence is missing, artifact bytes disagree with the certificate, or
publication would move or delete a published tag. Product corrections return
to ordinary tickets.

### D9. Publication workflow

One `workflow_dispatch` workflow; input = the certification run ID. After
approval it:
1. downloads certificate, tarball and site bundle from that run;
2. verifies repository, candidate, run and a successful G10;
3. computes SHA-256 over the downloads and **fails** on any mismatch with the
   certificate (GitHub's own digest check only warns);
4. verifies that `refs/heads/main` can fast-forward to the candidate and that
   the new tag does not exist;
5. fast-forwards `refs/heads/main`;
6. creates `refs/tags/vX.Y.Z` at the candidate;
7. re-uploads the verified site bundle as this run's Pages artifact and
   deploys it unchanged;
8. creates the curated GitHub Release with the certificate and tarball
   attached, so durable copies outlive workflow-artifact expiry;
9. emits the URLs and hashes for the post-publication closeout.

The tag-triggered full tier and the main-push pkgdown build are removed; a
manual site-only pkgdown dispatch remains. All ref reads and writes use full
names. Release branches are renamed `release/vX.Y.Z`.

**Bootstrap.** GitHub runs `workflow_dispatch` only for workflow files present
on the default branch, and the Pages environment admits deployments only from
the refs its branch policy allows. The first use therefore needs the
publication workflow on `main` before the publication run, and a Pages
environment policy that admits the dispatch ref. The cut chooses the
bootstrap (for example a workflow-only commit on `main` merged back into the
release branch, keeping the fast-forward possible) and proves it in the
rehearsal. Both behaviours are confirmed (final review 1.1): the
`github-pages` environment currently admits only `main`.

**Workflow provenance (final review F2).** Whichever bootstrap the cut
chooses, publication proves three things before any mutation:
1. the publication workflow is present on the default branch;
2. the workflow file the run executes is byte-identical to the candidate's
   publication workflow (or carries its certified hash), so an older or
   edited publisher on `main` cannot promote a candidate; and
3. the Pages environment policy admits the run's exact `GITHUB_REF`.

Mutating the default-branch publisher or the Pages branch policy makes the
rehearsal fail.

### D10. Approval is the maintainer's confirmed act

The publication job runs in a protected environment whose required reviewer is
the maintainer, with self-approval allowed. GitHub ties approval to a
credential, and agent sessions here run with the maintainer's login (a classic
OAuth token with `repo` and `workflow` scopes, final review 1.2), so an agent
can technically submit an approval. Under clarified decision 2 that is
acceptable when the maintainer confirms it:

- the maintainer approves either in the GitHub web interface or by
  explicitly confirming an agent's approval command in a permission prompt;
- release-relevant agent commands are configured to **always ask**, never
  auto-allowed, including under auto mode or allowlists: approving a pending
  deployment (`gh api ... pending_deployments`), pushing a tag
  (`git push ... refs/tags/...`) and creating a release (`gh release create`).
  Claude Code uses an `ask` permission rule; Codex sessions use the
  equivalent approval setting;
- agent briefs forbid approving or publishing without that confirmation.

This is deliberately process enforcement, not a security boundary against a
misbehaving agent holding the maintainer's token; it matches the trust model
of every other outward action agents take. A separate agent credential is not
adopted (Section 6).

### D11. Ruleset

The ruleset of decision 1 is configured and recorded in the playbook. Its six
outcomes are verified once at setup and again whenever the ruleset changes
(maintainer decision 3): a fast-forward of `main` and creation of a new `v*`
tag succeed; a force-push or deletion of `main` and an update or deletion of
an existing `v*` tag are refused. The verification record names the ruleset
configuration it checked. The publish workflow is the only release path by
governance and approval authority, not by a required check on `main`.

### D12. Rehearsal, targets and practice

One complete rehearsal before the publication cut records: remote critical
path and total time, maintainer-attended time, queue time, cold and warm cache
setup, the Windows check, artifact transfer, a non-public publication dry
run, rejection of a deliberately altered artifact, approval behaviour
including the D10 prompt-confirmation boundary, the bootstrap of D9, and diagnostic usefulness under
a deliberately failing gate. Service targets bind only after it; the planning
hypotheses stay 45 minutes for certification and 30 minutes of attended
release-day work.

Every cut updates `NEWS.md`, documentation, examples and help with its own
product change (macro-plan rule 6); M6's CRAN-only NEWS collapse is separate.
Release day contains verification, approval, promotion and a smoke check,
and nothing else.

## 4. Contract and governance changes

The implementation cut amends these, without editing shipped contracts in
advance:

| Target | Change |
| --- | --- |
| [Release gates](../contracts.md#contract-verification-release-gates) | Replace "Main-branch CI and tag-triggered CI are separate gates; a release tag is not valid until the tag workflow is green" with: a release tag is valid when it names a commit with a successful certificate and was created by the approved publication workflow. Keep the package-check, coverage and Ubuntu/Windows requirements; restate acceptance-before-check as G2's internal order. Point "release-ticket execution" to the replaced playbook. |
| [Release playbook](../release_ci_playbook.md) | Replace "Release Order" and "What Counts as Green"; reconcile "CI Tiers", "Tag Handling" and "GitHub Release Entry" with D9-D11; keep the Ubuntu/DuckDB, surgery, coverage-triage and standing-claim lessons through their census owners. |
| Workflows | Split `R-CMD-check.yaml`'s serial matrix into the DAG; add certification and publication workflows; make `pkgdown.yaml` dispatch-only; add the nightly G3 lane. |
| Ticket convention | Add `release_evidence` (D5) to the v0.2.3 `tickets.yml` convention. |
| Repository settings | Ruleset (D11) and protected publication environment (D10). |

## 5. Detecting evidence required by the cut

Registered before coding, each able to fail:
1. a census check that fails when a workflow step, playbook prerequisite or
   release-gate contract sentence has no census row. The source inventory
   (workflow job and step IDs, playbook requirement IDs, contract clause IDs)
   is enumerated independently and then compared with the literal census; a
   checker deriving both sides from the census does not qualify;
2. a certificate whose tarball or site digest is altered is refused by
   publication;
3. a non-successful or foreign certification run ID is refused;
4. G3 fails when one installed package differs from the manifest, and
   reports unavailable when the manifest cannot be installed;
5. a one-time setup record shows all six ruleset outcomes of D11 against the
   named configuration (final review F3, maintainer decision 3); the
   publication workflow compares the live ruleset with that recorded
   configuration before mutating refs and fails on any difference, so a
   changed ruleset needs a fresh record;
6. in the rehearsal (D10): an agent dispatches publication and the run
   reaches the pending environment approval; the agent's approval command
   stops at a permission prompt rather than running, including under auto
   mode; approval confirmed by the maintainer releases the job; and removing
   the `ask` rule makes this evidence fail;
7. a failing gate shows one row in G10's table, siblings complete, and G10
   refuses certification;
8. the publication rehearsal proves the real path ran, not merely that
   nothing was published (final review F4). It executes the certificate
   lookup, artifact download and hash checks; reaches the protected-environment
   wait; exercises the chosen D9 bootstrap, provenance and Pages-policy
   checks; records the exact ref, Pages and Release mutations it would
   request, or performs them against a disposable target; asserts identical
   pre- and post-run inventories of production refs, Pages deployments and
   Releases; and fails when any D12 measurement or expected mutation record
   is missing. It may reuse items 2, 3, 6 and 7's outputs but not replace
   execution with a static summary.

## 6. Rejected alternatives

Seed v2 Section 13 stands in full. In addition:
- **No seed v2 (response):** rejected by the review; the identity, publication
  and ticket-field changes were material.
- **`release/` naming as the safety rule:** rejected; full refs are the rule,
  the rename is clarity.
- **Second-person publication review:** rejected by maintainer decision 2;
  there is one maintainer and agents may not approve.
- **A separate agent credential without `Deployments: write` (final review
  F1):** rejected by the maintainer's clarification of decision 2. It closes
  only the approval endpoint while the same agents push tags, create releases
  and push `main`; closing all of those would move every outward action to
  the maintainer by hand. Approval is a confirmed human act (D10), not a
  credential boundary.
- **A registered disposable-repository ruleset fixture on every release
  (final review F3):** replaced by a one-time setup record, refreshed when the
  ruleset changes (maintainer decision 3).

## 7. Open questions promoted to the WS13 cut

1. Workflow file layout, job names and the certificate schema fields.
2. M4's manifest format and tooling (for example a lockfile with sources) and
   how G3 restores it.
3. Cache keys per lane.
4. The bootstrap path of D9 and the Pages environment branch policy.
5. The exact `ask` rule patterns for D10 in Claude Code settings and the
   equivalent Codex approval configuration.
6. The accepted native-abort signature for the coverage retry.

These are implementation choices within the bound design, not new RFC work.

## 8. Future obligations and speculation

- **Obligation:** if a co-maintainer joins, revisit decision 2's self-approval
  and decision 1's absence of a required check on `main`.
- **Speculation (horizon if useful):** a cross-commit evidence cache with
  declared invalidation; automated CRAN submission from the certified tarball.

## 9. Sequence

1. Type 1 final review by Codex, who did not write this synthesis (rotation
   in `rfc_cycle.md`; seed v2's "author of neither" is not satisfiable with
   two authors and is superseded here): done, PASS_AFTER_PATCHES, patches
   applied, then D10 and D11 revised by the maintainer; a focused Type 1
   confirmation of F2, F4 and the revised D10, D11 and items 5 and 6 follows.
2. Maintainer acceptance: the pipeline row moves to `Obligations open`; the
   decisions bridge gains a row naming Section 4's targets.
3. The WS13 cut resolves Section 7 and registers Section 5 before coding.
4. The rehearsal runs before the v0.2.3 publication cut.

No workflow, contract, playbook, ticket or repository setting is changed by
writing this synthesis.
