# Final Review: Authority And Lifecycle Of Governance Documents

- Role: record; Type 1 final review of the synthesis, verification only
- Status: complete; verdict `PASS_AFTER_PATCHES`
- Reviewer: Claude (Fable 5.1). Seed and response are Claude; the response
  review and the synthesis are Codex. This review is the fourth model
  session on the cycle, not the seed's or the response's.
- Date: 2026-10-13
- Baseline: HEAD is `ea10ab72` ("Schedule the governance overhaul as its own
  cut"). The synthesis cites `ce32c0d7`; `ea10ab72` is one commit later and
  changes only `macro_plan.md` (29 insertions, 13 deletions). Uncommitted
  inputs: the maintainer decisions file (SHA-256 `ac62b1fc...`, matching the
  synthesis's line 11), the synthesis itself (348 lines, SHA-256
  `b28ba8c4...`) and the governance row of `rfc/README.md`. No other
  tracked file differs from HEAD.
- Citation key: the synthesis's (S, M, R, V, G, P, I, B, C, Q, A, J, E).
  "Syn" is the synthesis file; a bare line number is a line in it.

## 1. Inputs and how they were checked

The inputs are the right ones. Independently of the author: the census was
rerun at HEAD with the repository Rscript (6 s, exit 0) into a scratch
directory and diffed against `E/records/`; M1, M2 and both directions were
read from the decisions file and mapped line by line (M:15-34, 47-54,
66-71 as cited); every P, I, A, B, C, G, J and V citation was opened; the
`ea10ab72` diff was read in full; the pipeline row was diffed against HEAD.

Census rerun: `bridge_backlinks`, `cut_reviews` and `synthesis_headers`
are byte-identical. `summary.csv` differs in two populations: files 300
versus 299 (governance) and links 888 versus 886, because the committed
records were generated before `seed_v2.md` was itself tracked. The
counts the synthesis cites (14 pairs in 3 rows, 47 syntheses, 9
superseded, 19/169/63/1 claims, 6 anchors, 45 missing-file occurrences
over 12 targets, 81/98, 11 of 13) all reproduce. `links_broken.csv` gains
two rows at `rfc/README.md:42`: the uncommitted row's links to the
decisions file and to the synthesis, both untracked. See finding 4.

Accounting for the seed: R1 to R9, Section 4 and Section 5 of S each have
a disposition (Syn Sections 2 to 7). Deliberate changes are named: the
`rejected` state (96-99), the `mixed` role (60), activation tied to header
normalization and reviewed fixtures (249-251), fail-on-malformed-inputs
(231), and contested revisions as versions (83). None reopens M1 or M2.

M1 (181-200) matches M:15-34 without exception: gate retired; one
invocation is one independent verdict from a session other than the
implementing agent's; own-session reviews labelled and counted apart;
completed tickets as denominator, dropped excluded from both counts; ratio
once at cut close and once at closeout, not in ticket or workstream
fields; the other D8 counters at the same points; third-round escalation;
reassessment owner, trigger, inputs and dispositions recorded in P at the
pilot passage. M2 (173-179) matches M:47-54: file for findings, one line
for a clean `PASS`, prospective, no rewriting. Direction 1 is met at
205-207 (census scope, historical records included). Direction 2 is met at
249-251, subject to finding 1.

Authority per section, promoted references with their accepting section
(67-69, preserving C:443-450 under the WS5-A synthesis D1), both role
conflicts (72-76) and the record/living split (78-92) are present and
consistent with S R1-R2 and with I:32-48 and P:59-65 as they stand.

Supersession, bridge and obligations (Section 4): the triangle, the
stage-aware expectations, the ordinary exit at B:14-16, the sweep exit
with proof, stubs, superseded versions in place, and the P:172-180 and
209-214 obligation rule are all carried. No seed obligation is lost.

Process wording (Section 7): the P:3 and P:338 replacement removes the
non-binding disclaimer; the P:249-251 and 274-278 replacement removes the
only operative 0.5-gate text and keeps modes, routes and briefs; P's
revision history (349-355) and G D8 remain as records, so no historical
fact is erased. The I:32-48 wording resolves the roadmap conflict in the
direction S R1 chose. Whether the applied wording "preserves modes, routes
and briefs" can only be verified when it is written; it is authorized, not
drafted, here.

Scope: only the synthesis and the governance pipeline row differ from HEAD
among files this stage may touch. The synthesis is ASCII, 79 columns, 348
lines, and claims neither final review nor acceptance (4, 6).

## 2. Required corrections

Numbered by severity. Each names the failure and the smallest correction.
None requires a new design decision.

1. **Stale application vehicle and citations after `ea10ab72`.** The
   synthesis binds the "sweep" chore (255-262) and cites Q:792-853,
   Q:825-839 (153-154) and Q:840-846 (119). At HEAD the maintainer turned
   the chore into "one governance cut" with four workstreams, each with a
   Type 1 close review (Q:792-811), the amendment runs to Q:869, the
   governance-file sweep bullet is Q:840-854 and the present-tense pass is
   Q:855-862. Q:805 also says the guard's "check mode follows one cut
   later", while 249-251 says activation needs header normalization and
   reviewed fixtures, "not a cut elapsed". Failure: a reader applying
   Section 7 looks for a chore that no longer exists, Q:825-839 now lands
   inside the horizon-scan bullet, and the reader cannot tell whether the
   plan's "one cut later" or the synthesis's condition binds. Correction:
   rebase the baseline line to `ea10ab72`; name the governance cut and its
   workstreams (rules and guard; contracts; planning documents; records)
   as the application vehicle and the owner of guard delivery; update the
   three Q citations; state activation as "no earlier than the cut after
   the governance cut, and only once workstream 4's header normalization
   and the reviewed baseline and fixtures exist", which satisfies both
   M:70-71 and Q:805; and change the pipeline row's "scheduled sweep ...
   applies the rules" to the governance cut.

2. **Replacement map incomplete against its own rule.** Section 4 (131)
   requires an unchanged entry to name its retained address, and Section 8
   lists G D5 and D6 as unchanged, but G D1, D2, D3, D7 and D9 and P's
   untouched sections (stages, naming beyond 59-65, rotation, final review
   scope, briefs, spikes) do not appear. Failure: the first table written
   under R5 cannot show whether D3, whose closeout-counter codification at
   P:274-278 is amended, was considered as a source, so a reviewer cannot
   distinguish omission from "unchanged". Correction: one row per omitted G
   section as `unchanged` with its retained address, and one sentence that
   P sections not listed are unchanged.

3. **Baseline identity is ambiguous.** 215-218 lists "source file, line
   locator, target/rule, and occurrence identity" as the baseline record,
   then says unrelated line movement may relocate an unchanged occurrence.
   Failure: an implementer who keys on the line turns every edit above a
   baselined link into a new failure; one who drops the line has no
   locator. Correction: "Identity is source file, target and occurrence
   index; the line is a locator the tool refreshes."

4. **Target resolution is stated three ways.** 205 scans "tracked"
   sources, 208 resolves "against the repository", 212-213 says the check
   "uses the current source tree". The census resolves against tracked
   paths only, so the rerun reports the uncommitted pipeline row's two
   links to the decisions file and the synthesis as missing. Failure: in
   check mode, every link to a new file fails until the file is staged, or
   passes if the guard silently switches to the working tree. Correction:
   one sentence choosing the rule, for example "targets resolve against
   the working tree; an untracked target is reported in its own advisory
   class, never as missing", or "the check runs on staged content", and
   the fixtures in 236-238 gain that case.

5. **The authorized `AGENTS.md` wording has no line budget.** A is 145
   lines and binds itself to stay under 150 (A:56-58); 289-293 adds about
   four lines of new text. Failure: the cut applies the wording as written
   and breaches a size rule the guard is told to report. Correction: say
   the wording replaces words in the existing governance bullet and the
   Current State lines rather than adding lines, or that the cut trims
   elsewhere so A stays under 150.

## 3. Record-only notes

- The census is deterministic for a given tree, and the two-population
  drift above is explained by the commit order; no correction is needed
  beyond knowing that `summary.csv` predates `seed_v2.md`'s tracking.
- The `rejected` state is a vocabulary completion. The governance v1
  synthesis is both rejected and superseded (its header says so); the
  state carries the rejection, the header text carries the replacement.
- 91-92 is right that a passed final review is not acceptance. The three
  "pending final review" syntheses the census lists need acceptance
  evidence from their consuming ticket cuts in workstream 4, or a
  maintainer decision; two are cited by the pipeline as accepted sources.
- 46 correctly flags S:64's 297 files against the recorded 299; S is a
  record and keeps its number.
- The pipeline row's phrase "Check mode follows header normalization, not
  elapsed cuts" is consistent with finding 1's correction once "one cut
  later" is also named.
- 332-333's rotation statement is accurate and does not claim independence.

## 4. Not verified

- The guard's tests, witnesses and lane placement: nothing is implemented,
  and nothing here reports them as run. The 6 s figure is the census, not
  the check.
- The applied process wording for P, I and A: only its authorization and
  its fit against current text were checked.
- The census's link parser against a second parser at HEAD; the earlier
  review's independent totals (V:42-45) were not re-derived.

## 5. Verdict

`PASS_AFTER_PATCHES`. Apply corrections 1 to 5 in place with a revision
note; none opens design space. After the patches, the synthesis is ready
for maintainer acceptance; this review does not claim it.
