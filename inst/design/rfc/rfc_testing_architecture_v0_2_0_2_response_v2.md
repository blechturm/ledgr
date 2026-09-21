# Response v2: Testing Architecture Seed

**Status:** Second Type 2 response; input to revision or synthesis.
**Respondent:** Codex
**Date:** 2026-09-21
**Responds to:** `inst/design/rfc/rfc_testing_architecture_v0_2_0_2_seed_v2.md`

## Verdict

The direction remains sound, but v2 has over-corrected into mechanism. It
replaces one physical split with four runners, two gates, two tagging forms,
a registry, a checker, a universal comment rule, and a path-triggered
overlay. Several parts are individually reasonable; together they create a
new test control plane whose own silent failure is not detected.

This is not a reason to return to directories. It is a reason to collapse
the design before synthesis. Two factual premises also need correction:
the suite does use mocks, and it does carry frozen reference artifacts.

## My Bias And Where It Distorted The Candidate

I proposed profiles, the two-axis vocabulary, a claims registry, and
maintainer ownership of canonical-R parity in the v1 response. v2 adopted
those ideas more literally than I now would.

Arguing against a directory split made each alternative mechanism look
cheap in isolation. I under-priced their interaction: runner selection,
block tags, registry references, path triggers, and release invocation must
all agree before a claim is actually exercised. I also treated a registry
of declared claims as if it could demonstrate that all load-bearing claims
had been declared. It cannot.

Had I designed from scratch rather than against v1, I would have used one
parameterized runner, two membership profiles, one CRAN execution mode, a
small always-on canonical core, and a registry limited explicitly to
declared load-bearing claims.

## The Six Changed Mechanisms

### 1. Block profiles and the CI drift gate

**What works.** Block routing preserves mixed files and avoids the 76-file
move that v1 implied. The 90-second gate makes the fast promise measurable.

**Why it is not yet the smallest design.** Section 4.1 combines homogeneous
file declarations with per-block skip helpers. Section 4.6 then specifies
four runners. That is two selection systems feeding four entry points. The
seed does not define whether `review` includes `fast`, how unknown tags
fail, or how a runner proves that every selected block actually ran.

The timing gate only detects cost drift. A cheap persistence test, network
test, or optional-dependency test can be routed incorrectly without
breaching 90 seconds. More seriously, a selector bug can skip evidence and
make the gate faster.

**First daily failure.** A block is tagged `review`, but the release runner
or skip helper omits it. The test itself is green when invoked; no gate
proves it was invoked.

**Smallest correction.** Use one parameterized runner with fail-closed
profile names. It must emit a selected/executed block census, and each gate
must reconcile the two. Use one tagging form; a homogeneous file may be a
convenience expansion, not a second authority.

### 2. `cran` as a profile sharing `fast` members

**What works.** v2 correctly separates membership from the claim that code
survives CRAN-like conditions.

**Why the name is misleading.** If `cran` has exactly the same members as
`fast`, it is not another membership profile. It is an execution mode. An
"empty optional dependency set" also requires an isolated library or
equivalent environment; setting an environment variable does not make
installed packages absent.

**First daily failure.** The nominal CRAN runner sees an optional package
from the maintainer library, while CI reports that the empty-dependency
condition passed.

**Smallest correction.** Keep `fast` membership once and execute it in
ordinary and CRAN modes. Record the library isolation method and measure
the CRAN gate on its own clock. Do not maintain a fourth set of membership
metadata merely to state equality.

### 3. Maintainer-owned canonical overlay and release backstop

**What works.** Authority has a durable owner, accounting-core is only the
first consumer, and release cannot rely solely on a path trigger.

**Why the cheap core should not be triggered.** The audited differential
core is three blocks totaling 6.16 seconds
(`test-execution-spec.R:490`, `:542`, and
`test-sweep-persistence-parity.R:209`). The fast candidate is 70.80 seconds.
Even moving all three into every fast run projects about 76.96 seconds,
before any later measurement correction, still below the 90-second gate.
For that core, path detection is more risk than saving.

**First daily failure.** A new compiled consumer is not in the trigger map;
divergence survives until release.

**Smallest correction.** Put the three cheap differential blocks in every
fast run. Keep the public-sweep or full-scale witness as an extended review
overlay with the unconditional release backstop. The maintainer owns both;
only the expensive part needs routing.

### 4. Two-axis taxonomy with rules only where defects were found

**What works.** Scope and oracle answer different questions and are better
review vocabulary than the audit's one dominant-oracle label.

**What is unevaluable.** The seed says every block is classified but gives
the classification no durable home: it is not among the claims-registry
fields, is not part of the `# Oracle:` line, and is not retrofitted. A rule
that exists only in prose cannot route or review 930 blocks.

The stated evidence for omitting rules is also false. A repository search
finds `local_mocked_bindings()` in 12 test files, including availability,
runner, writer, snapshot-hash, plot, and walk-forward tests. Frozen witness
artifacts exist too: `test-availability-fold-witnesses.R:54-97` reads CSV
fixtures and checks a "reviewed baseline" plus a mutation, while provider
and reference-baseline tests call `availability_v201_assert_frozen()`.

**First daily failure.** A mock replaces the supposed independent oracle,
or a frozen artifact is regenerated from the implementation it guards.
The taxonomy names the oracle class but supplies no ownership or
regeneration rule.

**Smallest correction.** Use the axes as review vocabulary and store them
only for registered load-bearing claims; do not classify all 930 blocks as
ceremony. Add bounded rules for the mocks and frozen artifacts that really
exist. This is required by evidence, not a request for a general style
guide.

### 5. Claims registry, structure checker, and `# Oracle:` line

**What works.** A small registry can expose sole guards, owners, and lane
promises better than prose spread across packet history.

**What it cannot prove.** A structure-only checker proves that declared
rows resolve. It cannot prove that every load-bearing claim was declared.
The seed's own incomplete-registry scenario admits this, yet Merge and
Delete would use the checker as assurance. File plus block title is also a
brittle identifier: a harmless title edit can break the registry while a
semantically wrong replacement can retain the title.

The universal `# Oracle:` line is a second, unenforced metadata store. It
will be omitted, copied, or become circular. Requiring it on every new test
regrows the comment burden that this RFC is meant to reduce.

**First daily failure.** The sole guard for an undeclared claim disappears;
the checker stays green. The next likely failure is title drift rather than
semantic drift.

**Smallest correction.** Define the registry honestly as the register of
*declared* load-bearing claims. Give its detecting blocks stable IDs, and
have the runner's execution census prove that each promised block ran in
the claimed profile. Put an oracle source in the registry for those claims;
require an inline Oracle note only when an unregistered test has a
non-obvious oracle. Do not duplicate it universally.

### 6. Skip-with-reason before synthesis

**What works.** A reason is better than an unexplained skip.

**Why this is premature.** Section 5 changes evidence before the
architecture is accepted. Skipping eight obsolete documentation tests does
not preserve their guarantees; it only makes the suite green while the
decision about deletion is pending. More importantly, reading
`engine_version` from the current `DESCRIPTION` makes that witness true by
construction. A historical frozen record should retain its recorded
version; economic equality can exclude or separately compare that field.

**First daily failure.** The temporary skips survive into release, or a
fixture-version regression becomes invisible because expected and actual
both read the current package version.

**Smallest correction.** Make no pre-synthesis test edits. The accepted
implementation packet should delete, replace, or explicitly quarantine
each obsolete oracle. Preserve the historical version and separate it from
the economic comparison rather than making it dynamic.

## Has v2 Over-Corrected Into Mechanism?

Yes. The minimum coherent version is smaller:

1. One parameterized runner, not four implementations.
2. Two membership profiles: `fast` and `review`; named heavy protocols sit
   outside ordinary membership.
3. CRAN as an isolated execution mode over `fast`, with its own gate.
4. The 6.16-second canonical core always in `fast`; only extended parity is
   conditional, with a release backstop.
5. One registry for declared load-bearing claims, joined to an execution
   census; no universal Oracle comment.
6. Scope and oracle as registry/review fields, plus bounded rules for the
   mocks and frozen artifacts the repository demonstrably contains.

This retains v2's useful guarantees while removing a runner matrix, a
stale path trigger for cheap evidence, and duplicated metadata.

## The Missing Scenario: The Test Control Plane Is Wrong

The eleven scenarios test code, evidence, routing choices, and registry
contents. None makes the runner, tag interpreter, or checker itself fail.

Run v2 through this scenario: a refactor makes the `review` runner select
only `fast`, or an unknown profile token is treated as a skip. The same
helper is used in CI and release. The fast and CRAN gates stay green and may
get faster. The unconditional release overlay is documented but not
executed. `tests/claims.yml` still resolves every file and title, so the
structure checker passes. All control-plane signals are green while the
canonical evidence is absent.

The design needs one fail-closed selection authority and an execution
manifest reconciled against selected block IDs and registered profile
promises. This is not a request for a new framework: it is the evidence
that the proposed framework did what it claimed. Keeping the cheap
canonical core in `fast` also reduces the consequence of routing drift.

## Required Revision

Revise v2 once, narrowly:

- collapse runners into a parameterized runner and make CRAN an execution
  mode;
- define fail-closed selection and selected-versus-executed reconciliation;
- run the cheap canonical differential core unconditionally in `fast`;
- correct the false no-mocks/no-golden-files premise and bind only the
  rules those existing mechanisms require;
- limit persistent taxonomy and oracle metadata to declared load-bearing
  claims; and
- remove the pre-synthesis skip/version rewrite.

The basic direction should survive. The revision should subtract control
surfaces, not add another checker for each weakness found here.

revise the seed
