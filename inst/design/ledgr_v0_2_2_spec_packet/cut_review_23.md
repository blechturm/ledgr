# Cut 23 review: Release coherence and publication

Mode: independent cut review; Type 1 ownership and input check plus Type 2
challenge of necessity and workstream grain.

Baseline: product tree `cab682e8` on `codex/cut23-release-closeout` (same
commit as `v0.2.2`), with the uncommitted Cut 23 draft in `tickets.yml` and
`macro_plan.md`.

Verdict: **PASS_AFTER_PATCHES**.

A release cut is necessary: `DESCRIPTION` still reports `0.2.1.0`, `NEWS.md`
opens with `# ledgr (development version)`, and no gate has run on a frozen
v0.2.2 candidate. The three serial workstreams are an honest grain: the gate
must run on a frozen tree, and the freeze must follow the accepted reader
story. No Type 2 product decision is needed. Five patches are required because
two release duties have no owner and three gate terms can be satisfied by
evidence that does not prove the claim.

## Required patches

### F1 - High - The v0.2.2-closeout M1 reassessment has no owner

**Where:** `tickets.yml:358` (Cut 23 decisions), `:362` (closeout), `:2947`
(`LDG-3117.scope`), `:2957-2958` (`LDG-3118`); `rfc/README.md:78`;
`rfc/rfc_governance_lifecycle_v0_2_2_synthesis.md:185-189`.

**Concrete failure:** the governance-lifecycle synthesis names the maintainer
as owner of an M1 keep/revise/drop reassessment, triggered at v0.2.2
closeout, with M1 counts for every v0.2.2 cut as inputs and the disposition
recorded in the pilot passage. `rfc/README.md` keeps that row under
`Obligations open` with the same trigger. Cut 23 assigns only "the final Cut
23 M1 accounting". LDG-3117 must clear ticket-owned `Obligations open` rows
before the freeze, but this row cannot be closed then: Cut 23's own count only
exists when LDG-3118 finishes. As drafted, LDG-3117 either deletes the row
without the decision or leaves it, and the release closes with its one
closeout-triggered governance duty unperformed.

**Minimal patch text:** add to LDG-3118 scope: "After recording the Cut 23 M1
accounting, assemble the M1 counts for Cuts 1 through 23 from tickets.yml
without rewriting records. Present them to the maintainer for the
keep/revise/drop decision the governance-lifecycle synthesis Section 5
requires. Record the decision at the pilot passage and move the
`governance-lifecycle` row in rfc/README.md out of Obligations open." Add a
matching acceptance item. In LDG-3117, exempt this one row from the
pre-freeze obligation sweep and name LDG-3118 as its owner in
`release_memory_closeout.md`.

### F2 - High - The gated commit and the tagged commit may differ without a rule

**Where:** `tickets.yml:359` (sequencing), `:939-945` (Workstream 67 claim
"the exact frozen candidate passes every applicable local and remote release
gate"), `:2957-2958` (`LDG-3118`).

**Concrete failure:** LDG-3118 runs the local gates on the frozen candidate.
It then still has to write `release_gate_closeout.md`, record wall times and
CI run IDs, set Cut 23 statuses and M1 accounting in `tickets.yml`, and
(after publication) switch navigation. Every one of those edits lands after
the local gates. They are under `inst/design/**`, so a branch push of them
starts no CI run (playbook, CI Tiers). But `inst/` ships in the tarball, so
the merged and tagged tree is not the tree that passed the local build/check.
The cut does not say which post-gate delta is allowed, whether tag CI must
cover it, or where the post-publication navigation commit goes. One reading
merges an untested delta under the "exact frozen candidate" claim. The
other reading can never finish, because the closeout has to cite the run IDs
of the CI that ran on it.

**Minimal patch text:** add to Cut 23 sequencing and LDG-3118 scope: "The
locally gated candidate is commit C. Before merge, the only permitted change
after C is evidence and status records under
inst/design/ledgr_v0_2_2_spec_packet/. Any other change, including
NEWS, README, R, tests, vignettes, DESCRIPTION, AGENTS.md or
inst/design/README.md, reruns the local gates. The release-branch full-tier
run, main runs and tag run cover the final merged commit, and the closeout
records both C and that commit. Remote run IDs and final statuses that arise
after the tag are recorded in a post-publication commit to main, together
with the navigation switch. That commit is not tagged, and its main CI is
recorded but is not a release gate." Rephrase the Workstream 67 claim to
"commit C passes every applicable local gate, and the tagged commit differs
from C only by packet evidence records and passes every remote gate".

### F3 - Medium - The long-window rerun names no accepted baseline

**Where:** `tickets.yml:2957` (`LDG-3118.scope`, "Rerun the maintained
long-window ordinary and release-only checkers"), `:2958` acceptance item 3;
`dev/bench/v0_2_2_long_window_regression/run_suite.R:4`;
`integrated_release_closeout.md:28-30`.

**Concrete failure:** `run_suite.R` requires `<accepted_repo>
<candidate_repo>`, and its record is a paired comparison. The retained
integrated record compares against the accepted Workstream 52 product, which
predates the Cut 21 and Cut 22 scheduler changes. The ticket says to rerun
"checkers", but `check_record.R` validates an existing record and executes no
candidate code. An implementer can therefore pass acceptance item 3 by
re-checking the WS54 record, or by pairing the candidate with itself. Neither
shows whether the scheduler cuts moved unscheduled long-window identities or
clocks.

**Minimal patch text:** replace with: "Run `run_suite.R` ordinary (at least
five pairs) and release (`--release`) with the accepted repo at the WS54
integrated candidate commit recorded in integrated_release_closeout.md and the
candidate at commit C. Then run `check_record.R` and `check_record.R
--self-test` on the new records. Stable native identities and economic
hashes for unscheduled shapes must equal the accepted side. Clocks are
characterized under the record's declared boundary." Also name the
host-control requirement from the benchmark methodology manual (power plan
and core affinity, with arms alternating) for the ordinary pairs.

### F4 - Medium - The documentation pass has no rule for registered pins

**Where:** `tickets.yml:2937-2938` (`LDG-3116` scope and acceptance item 6);
`rfc/README.md:79` (documentation roles and pin reset, Due at the first cut
after v0.2.2); `AGENTS.md` test-change rule;
`audits/v0_2_2_teaching_reference_audit.md` TR-1/TR-5.

**Concrete failure:** the point-in-time teaching cluster alone carries about
179 documentation-contract pin sites (audit TR-5). Correcting stale wording
in those articles breaks the pins, and LDG-3116 must keep
`test-documentation-contracts.R` green. It does not say whether a pin may be
edited, removed or retyped. Two bad outcomes follow. The pass may avoid
pinned prose to keep tests green, so stale pinned wording survives a
"coherence" acceptance. Or it may rewrite pins in bulk, which pulls in the
deferred page-role and pin reset and edits registered oracles without the
stated reason AGENTS.md requires.

**Minimal patch text:** add to LDG-3116 scope: "A pin changes only in the
same commit as the prose correction it pins, with one stated reason per pin
in the closeout. The pin must still assert the corrected shipped behavior.
LTB-0181, LTB-0060 and LTB-0073 and the claim-boundary pins are not weakened
or removed. Page roles, pin types, pin retirement and the ttr-indicators
TR-1 contradiction stay with the next release's documentation-roles route.
Where that contradiction is visible to a reader, LDG-3116 records it as a
routed gap rather than resolving it."

### F5 - Medium - NEWS claim parity is owned before NEWS is written

**Where:** `tickets.yml:2938` (`LDG-3116` acceptance item 4, "README, NEWS
draft, articles and reached help pages make the same supported and
unsupported claims"), `:2947-2948` (`LDG-3117` scope and acceptance item 2).

**Concrete failure:** LDG-3117 rewrites NEWS after LDG-3116 is accepted, so
3116's NEWS check certifies a text that is then replaced. LDG-3117's
acceptance checks user-language completeness but not claim parity with the
accepted surfaces. LTB-0181 only enforces the Sharadar sentence once the
first heading names 0.2.2. The other boundaries 3116 lists (terminal
assumptions, current-only formats, one pulse per session, long-only scope,
parallel memory) have no NEWS check after the rewrite.

**Minimal patch text:** remove "NEWS draft" from LDG-3116 acceptance item 4.
Add to LDG-3117 acceptance: "the 0.2.2 NEWS section makes no claim stronger
than the LDG-3116-accepted README, articles and help. It states the same
unsupported boundaries: the Sharadar carried-bar sentence verbatim, terminal
assumptions, current-only formats, one pulse per session, long-only estimator
scope and the accepted parallel-memory limit."

## Should-fix

1. **Low - push explicit refs.** Decision 3 again gives the branch and tag
   the same name, `v0.2.2`, as happened at v0.2.1.0. The playbook's Tag
   Handling commands (`git push --force origin vX.Y.Z`) are then ambiguous.
   Add to LDG-3118: "Push with explicit `refs/heads/v0.2.2` and
   `refs/tags/v0.2.2` refspecs. Each tag movement and force-push needs its
   own maintainer authorization."
2. **Low - name the accepted check residue.** LDG-3116 asks for "no
   documentation error or warning" from R CMD check, and LDG-3118 asks for
   check to "pass". The registered evidence (LDG-3115) reports known
   no-built-vignette warnings and a pre-existing head NOTE under
   `--no-build-vignettes`. Name exactly that accepted residue. Otherwise one
   criterion cannot be met and the other can be read loosely.
3. **Low - check the GitHub Release body.** LTB-0181 covers NEWS but not the
   curated release text, which is written last. Add to LDG-3118: "the
   GitHub Release body makes no claim beyond NEWS and either carries the
   Sharadar sentence or links the NEWS section that does."
4. **Low - trim the matrix to what is read.** The six-column matrix over
   "every public help topic reached by visible examples" turns an editorial
   pass into an inventory. Keep one row per README/article source, checked
   against `_pkgdown.yml`. List help topics only where a correction or a
   contradiction touches them.
5. **Low - one journey list.** LDG-3116's scope names six journeys, and its
   acceptance item 2 names five, under different labels ("strategy and
   indicators" has no acceptance counterpart). Use one list.

## Nits

- The draft already corrects the macro-plan header, yet the source table
  says it "still says Cuts 1 through 18" and LDG-3117 is assigned to correct
  it. Either drop the header edit from the cut draft, or drop it from
  LDG-3117's scope and acceptance item 4 and say the source table describes
  `cab682e8`.

## Necessity and grain

- Release cut: necessary. Version, NEWS, gates and publication are real
  unperformed duties, with no workaround.
- WS65: justified. Cuts 17-22 changed the estimator, scheduler and
  cross-asset wording after the last editorial pass. It is held to
  current-behavior fidelity, and F4 and should-fix 4 keep it from absorbing
  the deferred documentation-roles work.
- WS66 apart from WS67: justified. The gates are expensive and must run
  on a tree that will not change (F2 makes that true).
- No new manifest, validator or peer suite is introduced. Decision 4 and the
  out-of-scope list keep peer redesign, export tiering and next-release
  product work out, consistent with `rfc/README.md` (benchmark-methodology,
  asset-precision and spot-crypto rows) and roadmap lines 168-173.

## Independently checked and clean

- Source table: `DESCRIPTION` 0.2.1.0; NEWS development heading; 26
  top-level vignette `.qmd` sources plus `vignettes/articles/who-ledgr-is-for`
  and `why-r` (28 total, with tracked `.md` renders); 181 `export(` lines.
- All named tools exist: `tools/check-readme-example.R`,
  `render-vignettes-gfm.R`, `check-coverage.R`, `check-codebase-contracts.R`,
  `check-fold-phase-contract.R`, `dev/build-site.R`, and
  `dev/bench/v0_2_2_long_window_regression/run_release.R` with its
  `--release terminal` path and checkers with `--self-test`.
- The release profile requirement (`fast` and `review`,
  `tests/test-control-plane.R:114-127`) matches LDG-3118. `heavy_protocol`
  is not a release-gate profile.
- The fast-profile bound (`tests/test-gates.yml`, 112 s) is cited as
  unchanged. The playbook's Release-Gate Ticket Requirements are met: the
  playbook is in authority and scope, a read-first task is present, and the
  local checklist names every required gate, including WSL/Ubuntu.
- Playbook Release Order steps 5-11 map one-to-one onto LDG-3118, including
  the separate full-tier dispatch and three distinct main/tag runs. Step 12
  (win-builder) is correctly out of scope under decision 6.
- Release-closeout design-memory duties 2-4 are owned by LDG-3117. Duty 1 is
  owned by LDG-3118 after publication, which is consistent with What Counts
  as Green ("the release or the next prep cycle"), subject to F2's commit
  placement.
- Standing release-claim gates: the Sharadar sentence is enforced by
  LTB-0181, which activates on a 0.2.2 NEWS heading. The terminal fixture is
  named with `LEDGR_TERMINAL_RELEASE_OK` and the expected-evidence rule.
- Macro-plan Section 6 items 1-10 are verified in LDG-3118 acceptance item 4.
  Item 10's accepted parallel-memory limit is recorded in
  `integrated_release_closeout.md:187`.
- `tickets.yml` parses: 196 unique ticket IDs, 67 workstreams and 23 cuts.
  All dependencies and workstream references resolve. Cut 23 is the only
  non-closed cut. LDG-3116 to LDG-3118 form a serial chain from LDG-3115,
  and Workstreams 65 to 67 a serial chain from 64. The only other
  non-complete ticket is LDG-3008, which is `dropped`.

## Governance record

This is one independent cut-review invocation under M1. It found five
required cut findings that change ownership or evidence, and no maintainer
decision turn has happened yet. Under M2 this file is the single packet home
for these findings. After patching, `cuts[23].cut_review` records the
verdict, links this file and summarizes the corrections. Applying the patch
text as written needs no re-review. A material deviation from it gets a
focused re-review, which is a separate invocation.
