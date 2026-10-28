# Type 1 Final Review: Release Candidate CI Evidence

**Date:** 2026-10-28.
**Reviewer:** Codex.
**Mode:** Type 1 final design review; verification, not redesign.
**Artifact:**
[release-candidate CI synthesis](rfc_release_candidate_ci_evidence_v0_2_3_synthesis.md).
**Verdict:** PASS_AFTER_PATCHES.

The synthesis is faithful to seed v2, the Type 2 response, the response
review and both maintainer decisions. D1-D8 and D11-D12 preserve the accepted
architecture and evidentiary standard. D9's GitHub bootstrap diagnosis and
D10's credential diagnosis are factually correct.

Four patches are required before acceptance. They do not reopen design. They
make the maintainer's publication-authority decision enforceable and make all
of Section 5's evidence capable of detecting the failures it names.

## 1. External and repository verification

### 1.1 `workflow_dispatch` and Pages

GitHub documents that a `workflow_dispatch` workflow must exist on the default
branch before it can receive a manual dispatch. Once it exists there, a run
may be dispatched against another branch or tag.

GitHub also documents that an environment's selected branch and tag rules are
matched against the workflow run's `GITHUB_REF`.

The live ledgr settings agree with D9:

- the default branch is `main`;
- the `github-pages` environment uses custom deployment branch policies; and
- its only current policy is branch `main`.

Therefore a publication run dispatched against `release/vX.Y.Z` cannot deploy
Pages under the current policy. A run dispatched against `main` can, but it
uses the publication-workflow version present on `main` when the run starts.
D9 correctly routes this bootstrap to the implementation cut. Finding F2
below supplies the missing detecting evidence.

Sources checked:

- [GitHub workflow dispatch](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow)
- [GitHub deployment branches and tags](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)
- live environment and branch-policy REST responses for
  `blechturm/ledgr` on 2026-10-28.

### 1.2 Deployment approval

D10 is correct that GitHub authenticates an approval by credential, not by
whether the credential is being driven by a human or an agent. The REST
endpoint for reviewing pending deployments accepts a required reviewer's
credential with `Deployments: write`; a classic token with `repo` scope also
qualifies.

The active GitHub CLI session used by agents is logged in as `blechturm` with
a classic OAuth token carrying `repo` and `workflow`. It can therefore approve
a waiting deployment while self-approval is allowed. A prose rule does not
change that GitHub authorization result.

Sources checked:

- [GitHub REST: review pending deployments](https://docs.github.com/en/rest/actions/workflow-runs#review-pending-deployments-for-a-workflow-run)
- the active `gh auth status` output, inspected without exposing the token.

### 1.3 Contract amendment

Section 4 identifies the correct standing clause. The current Release Gates
contract says that main and tag CI are separate and that a release tag is not
valid until tag CI is green. Replacing that sentence with certificate plus
approved-publication validity is the accepted change.

The synthesis correctly retains:

- full regression tests;
- the source-package check;
- the coverage threshold;
- Ubuntu and Windows coverage;
- the conditional WSL gate; and
- release-ticket execution through the revised playbook.

Restating the separate acceptance check as G2's internal order matches seed
v2's gate census. No unrelated contract clause is changed.

## 2. Findings

### F1 (High): D10 permits a non-enforcing substitute for credential isolation

D10 allows either a deny rule in agent permission settings and briefs **or**
an agent credential without deployment-approval permission. The first option
does not establish the maintainer decision that agents cannot approve.

An agent holding the maintainer's current token can call the approval endpoint
through `gh api`, another HTTP client or code. A command-pattern deny and an
agent brief are useful defense in depth, but they do not alter the token's
GitHub permissions and are not an authorization boundary.

**Required patch:** bind credential separation. Agent automation receives a
distinct fine-grained token or GitHub App credential with `Actions: write` so
it can dispatch the workflow, and without `Deployments: write` so it cannot
approve. The maintainer's approval credential is unavailable to agent
sessions. Local deny rules and briefs may remain additional controls, not the
sole control.

Section 5 item 6 must exercise the actual agent credential:

1. dispatch succeeds;
2. the run reaches pending environment approval;
3. an approval POST made with the agent credential receives an authorization
   refusal; and
4. approval through the maintainer's web session releases the job.

This implements maintainer decision 2; it does not revise it.

### F2 (Medium): D9 bootstrap does not pin workflow provenance

D1 says workflow definitions derive from the candidate. D9 permits a dispatch
from a workflow bootstrapped on `main`, but does not require the running
publication workflow to equal the candidate's publication workflow.

If `main` carries an older or locally changed publisher, a run dispatched on
`main` can promote a candidate using workflow logic not derived from that
candidate. Conversely, dispatching the candidate's release branch uses its
workflow but currently fails the Pages environment's main-only branch policy.

**Required patch:** D9 and Section 5 must require the cut to choose and pin one
bootstrap with three checks:

1. the publication workflow is present on the default branch;
2. the workflow version used by the dispatch is byte-identical to, or has the
   certified hash of, the candidate's publication workflow; and
3. the Pages environment policy admits the exact dispatch `GITHUB_REF`.

The synthesis may continue to leave the choice between a `main` dispatch and a
`release/vX.Y.Z` dispatch to the cut. The evidence, not prose, must prove the
chosen route. A mutation to the default-branch publisher or to the Pages
branch policy must make the rehearsal fail.

### F3 (Medium): the ruleset detector omits half of the bound behavior

Maintainer decision 1 and D11 bind six relevant outcomes:

- an ordinary fast-forward of `main` is allowed;
- creation of a new `v*` tag is allowed;
- a force-push of `main` is refused;
- deletion of `main` is refused;
- update of an existing `v*` tag is refused; and
- deletion of an existing `v*` tag is refused.

Section 5 item 5 checks only the force-push and tag-move refusals. It does not
detect a ruleset that blocks legitimate publication or permits either deletion.

**Required patch:** item 5 must cover all six outcomes against the actual
configured ruleset, using a disposable repository or another non-destructive
fixture for mutation attempts where necessary. Removing any one rule or
blocking either allowed operation must fail the registered evidence.

### F4 (Medium): Section 5 item 8 admits a no-op dry run

"The dry run publishes nothing public" can pass if the dry-run path simply
does nothing. Recording fields can likewise pass without exercising artifact
handoff, bootstrap, approval or intended mutations.

**Required patch:** item 8 must prove path execution, not only absence of a
public release. The registered rehearsal must:

- execute the real certificate lookup, artifact download and hash checks;
- reach the protected-environment wait;
- exercise the selected D9 bootstrap and Pages-policy check;
- capture the exact ref, Pages and Release mutations it would request, or run
  them against a disposable target;
- assert that production refs, Pages deployment and Releases have identical
  pre- and post-run inventories; and
- fail when any required D12 measurement or expected mutation record is
  removed.

Items 2, 3, 6 and 7 remain independent failure witnesses; item 8 may reuse
their recorded outputs but may not replace execution with a static summary.

## 3. Section 5 failure-sensitivity check

| Item | Result | Reason |
| --- | --- | --- |
| 1. Gate census | PASS | It names the three independently scanned sources and requires an unmapped source item to fail. The implementation cut must freeze source identifiers before writing the mapping. |
| 2. Artifact tamper | PASS | Altering either certified digest has a direct refusal oracle. |
| 3. Foreign or failed run | PASS | Repository, run and G10 status are independent inputs with refusal outcomes. |
| 4. Minimum environment | PASS | Version mismatch and unavailable restoration are separate failing arms. |
| 5. Ruleset | PATCH | It checks only two of six bound outcomes; F3 closes it. |
| 6. Agent approval | PATCH | The current token can approve; credential-level refusal is required by F1. |
| 7. Failed sibling gate | PASS | Missing G10 row, sibling cancellation or a green G10 each contradicts an exact assertion. |
| 8. Dry run and rehearsal | PATCH | Absence of publication does not prove the publication path ran; F2 and F4 close it. |

For item 1, the source-side inventory must be independent of the mapping table.
For example, workflow step or job IDs, playbook requirement IDs and contract
clause IDs are enumerated first, then compared with the literal census. A
checker that derives both sides from the census would not satisfy the item.

## 4. Decisions and evidence found clean

- D1-D2 correctly separate candidate identity, certificate inputs and the one
  vignette-building source tarball.
- D3 carries every seed-v2 gate family and requires a regenerated census.
- D4 uses the measured full dependency manifest rather than pretending that
  `DESCRIPTION` contains every exact floor.
- D5 removes the unused `release_impact` taxonomy without weakening G9.
- D6 preserves the registered local timing owner and hosted-clock advisory
  status.
- D7 composes native evidence and does not require a log parser.
- D8 keeps one classified retry and the accepted stop rules.
- D9 correctly requires explicit downloaded-byte hashes, durable release
  assets, full ref names and no tag-triggered recertification.
- D10 correctly diagnoses the current credential risk; only its accepted
  enforcement alternatives need narrowing under F1.
- D11 faithfully records the minimal ruleset and no required status check on
  `main`.
- D12 keeps the service targets provisional until rehearsal.
- Section 4 amends the correct contract sentence and preserves the remaining
  Release Gates obligations.
- Section 6 rejects only alternatives already disposed of by seed v2 or the
  maintainer.
- Section 7 contains implementation questions rather than unresolved product
  semantics.

## 5. Verdict and next step

**PASS_AFTER_PATCHES.** Apply F1-F4 in place to the synthesis and add a
revision-history note. No seed v3, new Type 2 response or maintainer decision
is required.

A focused Type 1 confirmation should check only:

1. credential-level separation in D10 and evidence item 6;
2. D9 workflow provenance and Pages-policy evidence;
3. all six ruleset outcomes; and
4. the non-no-op rehearsal oracle.

On confirmation, the synthesis is ready for maintainer acceptance and routing
to the bounded WS13 cut.

## 6. Focused confirmation after maintainer revision

**Date:** 2026-10-28.
**Scope:** revised D9-D11 and Section 5 items 1, 5, 6 and 8 only.
**Focused verdict:** PASS_AFTER_ONE_RECORD_PATCH.

The maintainer's clarification supersedes F1's credential-separation remedy.
The revised D10 faithfully binds the chosen process boundary: release-relevant
agent commands always ask, approval after an explicit permission confirmation
is the maintainer's act, and an unconfirmed agent cannot proceed. Section 5
item 6 is failure-sensitive: it exercises auto mode, requires the command to
stop at the prompt, and requires removal of the `ask` rule to make the evidence
fail.

D11 and item 5 faithfully apply maintainer decision 3. The one-time setup
record covers all six allowed and refused ruleset outcomes, identifies the
configuration it tested, and the publication workflow compares the live
ruleset with that record before mutating refs. A ruleset change therefore
invalidates the record instead of silently changing release authority.

D9 closes F2. It requires the workflow on the default branch, proves that the
executed publisher equals the candidate's publisher, and checks that the
Pages environment admits the exact dispatch ref. Mutating either publisher
provenance or the Pages policy fails the rehearsal.

Section 5 item 8 closes F4. It executes the real verification and approval
path, records or performs every intended mutation, checks production state
before and after, and fails on a missing measurement or mutation record. A
no-op dry run cannot satisfy it.

Section 5 item 1 now builds its source inventory independently from the
literal census and expressly rejects deriving both sides from the mapping.
It can detect an unowned workflow step, playbook requirement or contract
clause.

One record-only inconsistency remains. D12 still asks the rehearsal to record
"D10's refusal". Under clarified decision 2 there is no categorical approval
refusal: the unconfirmed command stops at an always-ask prompt, and confirmed
approval releases the job.

**Required patch:** replace "approval behaviour including D10's refusal" in
D12 with "approval behaviour including the D10 prompt-confirmation boundary".
No other text or evidence changes, and no further review round is needed.
