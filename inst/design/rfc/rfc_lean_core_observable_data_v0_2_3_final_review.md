# Lean Core Observable Data: Type 1 Final Review

**Verdict: ACCEPT_AFTER_PATCHES**

- Mode: Type 1 final review, RFC cycle stage 8. Verification, not design.
  Independent Claude session, 2026-11-04. Brief drafted by Claude (a seed v2
  co-author) and approved by the maintainer. This session did not write the
  seed, the response or the synthesis.
- Reviewed head: detached `044193dc` in
  `C:/Users/maxth/ledgr-wt/observable-data-synthesis`. The synthesis cites
  its own baseline `37100e54`. Between the two, only seed v2 line 42, the
  pipeline row at `inst/design/rfc/README.md:112` and the synthesis itself
  changed (`git diff 37100e54 044193dc --stat`), so every other line
  citation below holds at both heads.
- Aliases follow the synthesis: **S** = the synthesis; **V2** = seed v2;
  **R** = response; **RR** = response review; **C** = `inst/design/contracts.md`;
  **K**, **D**, **X**, **M**, **Pipeline** as in S:17-22.

The synthesis decides inside the framing the maintainer accepted (RR:9-32).
It adopts the written guard, the fifth scenario with all four data subcases,
the seven-responsibility owner check by intended use, no third clock, no new
absence semantics, the named amendment targets, and the active partial gate
cleared at acceptance. Its narrowings of V2 (no "only further coordinate"
claim, stable versus dynamic name resolution, "subject to separately accepted
decisions" for the NA ruling, a sharper pseudo-instrument clause) remove
claims or restate accepted rules; none opens new design. Its code and
contract citations check out (see the list at the end). No design problem
was found, so this is not NEEDS_TYPE_2.

The findings are about the record and its installation: one remark made
stale by `044193dc`, a missing supersession table, notice wording, routing
rows left stale, a thin pipeline replacement row and one citation.

## Findings

### 1. The seed v2 line 42 remark is stale at the reviewed head

**Claim.** S says V2's Section 2 calls the post-warmup NA decision pending
and that this is stale. After `044193dc`, V2 line 42 reads "accepted, pending
implementation". The remark now describes text that no longer exists. Section
6 repeats it.

**Evidence.** S:56-57 ("Seed v2's Section 2 description of that decision as
pending is stale"); S:322 ("Seed v2's stale pending label"); V2:42 at
`044193dc`; `git show 044193dc` changes that line only, from "is pending" to
"is accepted, pending implementation". `inst/design/decisions.md:34` and
`M:1095` confirm the decision is accepted and routed to WS12.

**Consequence.** The accepted record would make a false statement about its
own input. It is a small fidelity error, not a design error. The underlying
judgment holds: the old word "pending" could be read as "undecided", and the
synthesis correctly refused to reopen the decision on that basis. The seed
edit itself was an in-place patch after synthesis with no in-file revision
note (`inst/design/rfc_cycle.md:71-74`); the commit message is its only
record. Recording it in S covers that.

**Patch (S:56-57).** Replace

> Seed v2's Section 2 description of
> that decision as pending is stale; its Section 8 correctly excludes it.

with

> At this synthesis's baseline, seed v2's
> Section 2 called that decision "pending", which could be read as undecided.
> Commit `044193dc` reworded it in place to "accepted, pending
> implementation". Its Section 8 correctly excludes it.

**Patch (S:322, last cell).** Replace "Seed v2's stale pending label supplies
no authority to reopen it." with "Seed v2's former \"pending\" wording,
corrected in `044193dc`, supplied no authority to reopen it."

**Patch (S header, after S:16).** Add the bullet:

> - Final review at `044193dc`: the only intervening change to a cited input
>   is seed v2 line 42 (see Section 1).

### 2. Section 4 has no supersession table

**Claim.** The amendments change accepted text in D, K, X and M but give no
supersession table. The governance rule requires one, and both sibling
amendments used one.

**Evidence.** `inst/design/rfc/rfc_governance_lifecycle_v0_2_2_synthesis.md:120-123`
("A change to accepted text carries a table with target artifact, addressed
section/group, disposition ... and replacement section"); `inst/design/rfc_cycle.md:77-80`;
precedent at D:65-68, K:458-461 and X:233-238. S:135-291 states each
replacement in prose only. K:456 and K:461 still declare "Sections 1, 2
outside 2.1, and 3 to 7 ... unchanged", which S's Section 2 insertion now
partly contradicts unless a table says so.

**Consequence.** The installer has to infer the dispositions. A reader of K
sees two dated amendments with overlapping "unchanged" claims and no single
place that reconciles them. It is installable, but not in the required form.

**Patch.** Insert after S:142 ("... not competing instructions."):

> | Target artifact and addressed section | Disposition | Replacement |
> | --- | --- | --- |
> | D, D1 scenario table (`D:26-31`) | Amended | Section 4.1 fifth row; the four existing rows are unchanged |
> | D, operative D1 Check in the core-extension amendment (`D:68`) | Superseded | Section 4.1 replacement Check |
> | K Section 2, interface-table rule (`K:105-113`) | Amended | Section 4.2 guard and extension-point notes, added after the rule |
> | K amended Section 2.1 (`K:463-485`) | Amended | Section 4.2 "five scenarios" sentence and fifth row |
> | K, core-extension amendment's "Sections 1, 2 outside 2.1, and 3 to 7 are unchanged" (`K:456`, `:461`) | Amended | Section 2 is amended as above; Sections 1 and 3 to 7 remain unchanged |
> | X Section 4 step 2 (`X:168-172`) | Superseded | Section 4.3 replacement step |
> | X Section 6, embedded four-scenario text (`X:233-262`) | Superseded in part | Scenario count only, through Sections 4.1-4.3; otherwise historical accepted text |
> | M WS16 "Observable data guard" bullet (`M:702-709`) | Superseded | Section 4.4 bullet |
> | D1 statement and locality amendment (`D:67`), D2; K original 2.1, K Section 2 outside the interface-table rule, K Sections 3-7; X Sections 1-3, 4 outside step 2, 5 and 7 | Unchanged | Those sections |

### 3. The exact header notice reads as still conditional after installation

**Claim.** The notice text S fixes as "exact" says the passages "are amended
... upon its acceptance". It is only installed at acceptance, so in the
installed file it reads as pending. It also points to the synthesis rather
than to the in-file amendment, unlike the sibling notices.

**Evidence.** S:147-150; S:139 (installed at acceptance). Sibling notices:
D:4-6 and K:10-13 ("amended ... by the accepted ...; see the amendment
below", linking the in-file heading). The governance rule asks for a marker
"linking to the replacing section/table"
(`rfc_governance_lifecycle_v0_2_2_synthesis.md:125-127`).

**Consequence.** Cosmetic but misleading: a cut writer could read the
amendment as not yet in force.

**Patch (S:147-150).** Replace the quoted notice with:

> Observable-data amendment (2026-11-04): the addressed passages below are
> amended by the accepted
> [lean core observable data synthesis](rfc_lean_core_observable_data_v0_2_3_synthesis.md#4-exact-amendments-for-acceptance);
> see the [amendment](#amendment-2026-11-04-observable-data) in this record
> for the exact replacement scope. Other accepted rules remain in force.

The anchor is the GitHub slug of the heading S prescribes for D, K and X,
`## Amendment (2026-11-04): observable data`. D, K and X are all in
`inst/design/rfc/`, so the relative link resolves from each.

### 4. Routing leaves the amended records' own rows stale

**Claim.** S:266-291 adds a decisions row and edits two pipeline rows, but
does not touch the existing decisions and pipeline rows of the two records
it amends. Both of those rows already record the earlier core-extension
amendment, so after acceptance they would list only the older one.

**Evidence.** `inst/design/decisions.md:32` ("Section 2.1 amended 2026-11-04
by the core extension architecture synthesis"); `decisions.md:33`;
Pipeline:110 ("amended Section 2.1, clearing the D2 coding gate");
Pipeline:111 ("Acceptance installed the D1, skeleton 2.1 and OMS
amendments"). The governance rule checks source notice, bridge mapping and
receiver as a triangle (`rfc_governance_lifecycle_v0_2_2_synthesis.md:136-138`).

**Consequence.** Low. The in-file notices still catch a reader of K or X.
But the bridge and pipeline, which are the entry points the AGENTS.md table
sends people to, would under-report the amendments on those records.

**Patch.** Add to S Section 4.5, before S:289:

> Append to the "Current owner" cell of `decisions.md` row `lean-core-skeleton`:
>
> > ; D1, Section 2 and amended Section 2.1 further amended by the
> > [lean core observable data](#lean-core-observable-data) synthesis
>
> Append to the "Current owner" cell of `decisions.md` row
> `core-extension-architecture`:
>
> > ; Section 4 step 2 amended by the
> > [lean core observable data](#lean-core-observable-data) synthesis (five scenarios)
>
> Append to the route cell of Pipeline row `lean-core-skeleton`:
>
> > Acceptance of the [lean core observable data](#lean-core-observable-data)
> > synthesis amended D1, Section 2 and amended Section 2.1.
>
> Append to the route cell of Pipeline row `core-extension-architecture`:
>
> > Acceptance of the [lean core observable data](#lean-core-observable-data)
> > synthesis amended Section 4 step 2.

### 5. The replacement pipeline row drops the cycle's provenance

**Claim.** The Pipeline:112 replacement keeps only the synthesis link in its
source cell. Sibling accepted rows keep the final review, the inputs and the
historical seed v1, and the current row names its inputs.

**Evidence.** S:275; current Pipeline:112; sibling rows Pipeline:110-111
(synthesis, Type 1 final review with verdict, seed v2, response, response
review, seed v1). The pipeline header relies on consumers for discoverability
of historical artifacts (Pipeline:10-12).

**Consequence.** After acceptance this final review and the response trail
would be linked from nowhere in the routing index. Low severity.

**Patch (S:275, third cell).** Replace "[Accepted synthesis](rfc_lean_core_observable_data_v0_2_3_synthesis.md) Sections 1-5 and 8" with:

> [Accepted synthesis](rfc_lean_core_observable_data_v0_2_3_synthesis.md)
> Sections 1-5 and 8 (Codex, gpt-6.1-sol; maintainer acceptance on the
> recorded date); [Type 1 final review](rfc_lean_core_observable_data_v0_2_3_final_review.md)
> (independent Claude session, ACCEPT_AFTER_PATCHES); inputs:
> [seed v2](rfc_lean_core_observable_data_v0_2_3_seed_v2.md) (maintainer with
> Claude), [response](rfc_lean_core_observable_data_v0_2_3_response.md)
> (Codex, Type 2, REVISE), [response review](rfc_lean_core_observable_data_v0_2_3_response_review.md)
> (maintainer, framing accepted); [seed v1](rfc_lean_core_observable_data_v0_2_3_seed.md) historical

Replace "on the recorded date" with the actual acceptance date when
installing, as S:139-140 already requires for the header.

### 6. One citation points at the wrong step

**Claim.** S says a change to an accepted boundary needs an explicit contract
and supersession before code, "as X Section 4 already requires (`X:168`)".
`X:168` is step 2 (name all owners). The contract-before-code rule is step 3.

**Evidence.** S:130-131; X:168-172 (step 2); X:173-175 (step 3, "Contract
before code. Resolve conflicts and exact supersessions first.").

**Consequence.** Citation only; the claim is true.

**Patch (S:131).** Replace "(`X:168`)" with "(`X:173`)".

### 7. Input check: the after-CRAN placement has an in-repo authority S does not cite

**Claim.** S places the External Data RFC "after CRAN" throughout and
installs that phrase into D1, M and the pipeline. S cites only the pipeline
route and V2's maintainer attribution, and S:392-394 marks maintainer
quotations outside the repository as unverified. The placement is in fact
bound in the accepted macro plan.

**Evidence.** `M:1027-1029` (Section 5, explicit non-goals: "PIT fundamentals
(after CRAN)"); V2:13-16; S:44-46.

**Consequence.** None for the decision. This independently confirms one of
the synthesis's inputs; citing it makes the installed text checkable without
the SF1 findings.

**Patch (optional, S:46).** After "route." add "The macro plan already lists
PIT fundamentals as an explicit non-goal, after CRAN (`M:1029`)."

## What I checked

- Read S, V2, R and RR in full; diffed V2 and Pipeline between `37100e54`
  and `044193dc`.
- Framing fidelity against RR:12-32, item by item, and V2 Section 9 answers
  against S:331-345.
- Every amendment target and quoted passage: D:26-31, D:59-68; K:88-122,
  K:139-189, K:191-247, K:452-485 (the quoted "four scenarios" sentence at
  K:470-471 matches S:209-212 exactly); X:62-89, X:161-189, X:225-266;
  M:681-709 and M:1095; `decisions.md` table header and rows 26-35;
  Pipeline:14-27, :99, :110-112.
- Code citations, reading the enclosing function each time:
  `R/history-substrate.R:422` (OHLCV double matrices plus logical
  `observed`), `:465`, `:488`, `:1499` (ID and axis validation), `:1599`;
  `R/history-features.R:169`, `:230`; `R/history-frame.R:207`, `:257`,
  `:461`, `:483`, `:770`, `:991`, `:1069`; `R/pulse-context.R:1`, `:100`,
  `:153` (`as.numeric` feature coercion), `:166`; `R/fold-engine.R` stage
  order P1 `:296`, P2 `:729`, P3 `:1086`, P4 `:1382`, P5 `:1520`, and the
  cited lines `:1155`, `:1568`, `:1598`.
- Contract citations and anchors: C:282-284 (decision packet and decision
  data `history`, owner P1, P2 only), C:958, C:1315, C:2253, C:2286, C:2313,
  C:2380; anchors at C:100, :242, :951, :1309, :2243.
- Other cited records: `optimization_coding_style.qmd:140`;
  `horizon.md:2491-2525`; `horizon_archive.md:5889-5907`;
  `rfc_cycle.md:163`, `:192`; R:35, R:97; RR:9, RR:28.
- Link targets and slugs in S's amendment texts, relative to each target
  file's directory.
- Governance rules on supersession tables, notices and the bridge triangle
  (`rfc_governance_lifecycle_v0_2_2_synthesis.md:118-141`).
- Checked without a finding: K:297 still says "four-row check" in Section 5;
  it was already loose after the core-extension amendment and is a
  descriptive pointer, not an instruction. Sibling rows `lean-core-skeleton`
  and `core-extension-architecture` list affected contract groups without
  `Accepted change pending` back-links in `contracts.md`; S follows that
  precedent and states that no shipped rule changes (S:289). M:692-700
  appended a "Cleared" note to its gate bullet, while S:254 replaces the
  observable-data bullet whole; both forms are within the macro plan's
  practice.

## What I did not check

- No R, test, package check or probe was run. No claim here rests on
  execution.
- The SF1 findings, vendor data, `af261e9`/`fa49d62` and ledgr-research were
  not opened. The SF1 numbers in V2 Section 2 are **unverified** here; S does
  not rely on them.
- The maintainer quotations in V2 Section 1 and V2:16 are **unverified**
  beyond the in-repo M:1029 placement noted in finding 7.
- Whether the six extension points are sufficient for an actual future data
  kind is **unverified** and out of scope; S claims no such sufficiency.
- The rendered GitHub anchor for the prescribed amendment heading is derived
  from the slug rule, not checked on a rendered page.
