# Core Extension Architecture: Type 1 Final Review

- Mode: **Type 1 final review** (RFC cycle stage 8), 2026-11-04. Verification,
  not design. Maintainer-approved brief, drafted by Claude.
- Verified: the [synthesis](rfc_core_extension_architecture_v0_2_3_synthesis.md)
  against [seed v1](rfc_core_extension_architecture_v0_2_3_seed.md), the
  [response](rfc_core_extension_architecture_v0_2_3_response.md), the
  [response review](rfc_core_extension_architecture_v0_2_3_response_review.md)
  and [seed v2](rfc_core_extension_architecture_v0_2_3_seed_v2.md); its
  file:line citations and contract anchors; its Section 5 OMS table against
  `rfc_ledgr_oms_seed_synthesis.md`; its Section 6 text against the skeleton
  synthesis, maintainer decisions D1-D2 and macro WS16.
- Commit: `579c418b` (detached worktree `extension-final-review`).
  `git diff ad28374a 579c418b --stat` touches only `inst/design/rfc/README.md`
  and adds the synthesis, so every citation resolves as at the stated baseline.
- Ran: `git log`, `git diff --stat`, and `sed`/`grep` reads of every cited
  range. No R, probes, tests or package check.
- Independence: an independent Claude session that wrote no artifact in this
  cycle. Claude co-authored both seeds and drafted the briefs, so this is a
  same-model check, not a different-model one.
- Aliases as in the synthesis: **S** = the synthesis; **OMS**, **Skeleton**,
  **D**, **Macro**, **C** as defined at `S:22-28`.

## Verdict

**PASS_AFTER_PATCHES.** Five findings: one moderate, four minor. None opens
design. The synthesis is consistent with its inputs, its source and contract
citations resolve, and Section 6 matches seed v2's intent and the skeleton's
structure. P1 restores one binding skeleton guard the replacement block drops
without saying so. P2 and P3 make the OMS table exact. P4 and P5 are wording
fixes.

## Findings

### P1. Moderate: the Skeleton 2.1 replacement block drops a binding guard

Evidence: `Skeleton:137-142` says "Bind D1 as a constraint on the skeleton and
its first checkpoint ... The interface table must preserve the following
change boundaries; preparation and the FIFO family must not bake future policy
into storage or arithmetic." It also links D1. The replacement block
(`S:232-235`) binds "the skeleton and every family close". It drops the first
checkpoint, the interface-table duty and the no-baked-policy rule for
preparation and the FIFO family, along with the D1 link. Nothing at
`S:217-254`, seed v2 Section 8 (`seed_v2:162-176`) or the response
(`response:96-101`, `:145-147`) asks for those removals. The first checkpoint
is memory preparation plus the FIFO kernel (`Macro:659-661`), so the dropped
sentence guards exactly the code written first. The old asset-classes row's
"Terms and event interpretation stay with their named consumers, rather than
becoming constants or generic metadata spread through the fold"
(`Skeleton:149`) is also lost. D1's own table (`D:25`) still keeps it, but the
skeleton no longer does.

Patch (S:232-235), replace

> Bind D1 as a constraint on the skeleton and every family close, not a request
> for unused code. Preserve the fixed boundaries in the core extension
> architecture synthesis Section 2. The four scenarios below name affected
> owners; they do not freeze every future stage or the current event grammar.

with

> Bind [D1](rfc_lean_core_skeleton_v0_2_3_maintainer_decisions.md#d1-built-for-what-comes-next-without-building-it)
> as a constraint on the skeleton, its first checkpoint and every family
> close, not a request for unused code. The interface table preserves the
> fixed boundaries in the core extension architecture synthesis Section 2;
> preparation and the FIFO family must not bake future policy into storage or
> arithmetic. The four scenarios below name affected owners; they do not
> freeze every future stage or the current event grammar.

and in the "Other asset classes" row (`S:242`), replace "Any necessary kernel
change takes its own contract and parity route." with "Any necessary kernel
change takes its own contract and parity route. Terms and event interpretation
stay with their named consumers, not constants or generic metadata spread
through the fold."

### P2. Minor: the OMS table misses two repeated clauses

Evidence: S says Q2 adopts the supersessions "including their repeated
clauses" (`S:184-185`). A census of OMS for `diagnostic`, `mode`, `replay`,
`json` and `flag` finds two repeats the table does not list:

- `OMS:594`, open question 14: "Should the current final-bar no-fill behavior
  emit any OMS lifecycle row in OMS diagnostic mode?" This repeats the
  diagnostic-mode execution meaning of 6.2 (`OMS:359`), which row 3 supersedes
  (`S:193`). `OMS:601` authorizes the spec cut to resolve these questions, so
  without a marker a cut writer could settle it as a mode-dependent emission
  branch.
- `OMS:569`, minimum-scope item 10: "replay tests". This repeats 10.2's replay
  tests (`OMS:516`), which row 5 clarifies (`S:195`).

Patch, at `S:193`, replace "OMS 12 item 7 (`:566`); execution-enable meaning
of diagnostic mode in 6.2 (`:359`)" with "OMS 12 item 7 (`:566`);
execution-enable meaning of diagnostic mode in 6.2 (`:359`) and 13 item 14
(`:594`)". At `S:195`, replace "9.1 replay (`:475`) and 10.2 replay tests
(`:516`)" with "9.1 replay (`:475`), 10.2 replay tests (`:516`) and 12 item 10
(`:569`)". At `S:208-209`, replace "6.1-6.2, 7.4, 11, 12 and 14" with "6.1-6.2,
7.4, 11, 12, 13 and 14". At `S:209`, replace "Add clarifying markers at 7.1,
9.1 and 10.2" with "Add clarifying markers at 7.1, 9.1, 10.2 and 12 item 10".

### P3. Minor: the 7.1 citation pulls 7.2 into the interpretation row

Evidence: `OMS:373-381` is 7.1 ("Mode is the execution context").
`OMS:383-389` is 7.2 ("Retention is a separate concept"). The row labels its
target "7.1 context" (`S:195`) and places markers only at 7.1 (`S:209`), but
cites `:373-389`, which also covers 7.2. 7.2 is not in conflict, and the
"Unchanged" row (`S:196`) does not name it, so the range sweeps in an
unrelated clause.

Patch: at `S:195` and `S:198`, replace "`:373-389`" and "`OMS:373-389`" with
"`:373-381`" and "`OMS:373-381`". At `S:196`, replace "7.3 retention boundary"
with "7.2-7.3 retention concept and boundary".

### P4. Minor: the Section 6 "Unchanged" row omits Skeleton Sections 6-7 and D1's other text

Evidence: `S:228` keeps "Skeleton Sections 1, 2 outside that block, 3-5; D2".
The skeleton also has Section 6 (`Skeleton:374-409`) and Section 7
(`Skeleton:411-443`). Neither is superseded or named as unchanged. Section 6
still holds the D1 rejection "Keep only the four named change boundaries"
(`Skeleton:408`), which survives the amendment. The governance-lifecycle rule
requires unchanged rows to name the retained address
(`rfc_governance_lifecycle_v0_2_2_synthesis.md:120-122`). D1's statement and
table (`D:8-14`, `:20-25`) are kept only in prose.

Patch (S:228), replace "Skeleton Sections 1, 2 outside that block, 3-5; D2"
with "Skeleton Sections 1, 2 outside that block, 3-7; D1 statement and table
(`D:8-14`, `:20-25`); D2".

### P5. Minor: the D1 wording still treats the decision as open

Evidence: the pipeline row records that "the maintainer accepted the synthesis
Section 6 amendment of skeleton D1 and Section 2.1 on 2026-11-04; its text, as
patched by the final review, is installed as dated amendments to both records
at acceptance" (`README.md:111`, added by `579c418b`). S still says the
maintainer will decide: `S:5-6`, `:11-12`, `:113`, `:162-163`, `:215`,
`:217-218`, `:223`, `:253-254`, `:260`, `:277`. Once accepted, the record
would contradict itself.

Patch (apply at acceptance at the latest):

- `S:5-6`: replace "Recommend narrowing skeleton D1; that amendment remains
  for the maintainer to decide at acceptance." with "Narrow skeleton D1; the
  maintainer accepted that amendment on 2026-11-04."
- `S:11-12`: replace "Section 6 is an explicit amendment recommendation, not a
  decided maintainer choice." with "Section 6 is the D1 and skeleton amendment
  the maintainer accepted on 2026-11-04."
- `S:113`: replace "Section 6's recommendation" with "Section 6's amendment".
- `S:162-163`: replace "subject to the maintainer's Section 6 disposition" with
  "as amended by Section 6".
- `S:215`: replace "## 6. Recommended D1 And Skeleton Amendment" with
  "## 6. D1 And Skeleton Amendment".
- `S:217-218`: replace "**Q1: recommend the amendment, with a complete
  owner-map check. The maintainer decides it at acceptance.**" with "**Q1:
  adopt the amendment, with a complete owner-map check (maintainer decision,
  2026-11-04).**"
- `S:223`: replace "Recommended disposition" with "Disposition".
- `S:253-254`: delete "If the maintainer rejects the recommendation, resolve
  the remaining D1/kernel conflict before declaring the extension gate
  satisfied."
- `S:260`: replace "Section 6 recommendation" with "Section 6 amendment".
- `S:277`: replace "D1 is a maintainer acceptance choice, not a cut question."
  with "D1's disposition is the maintainer's 2026-11-04 decision, not a cut
  question."

## Inputs: are they the right ones?

Yes. The synthesis cites all four cycle artifacts (`S:14-17`), and I read each
in full. Its answers cover seed v2's Q1-Q4 (`seed_v2:207-212`): Q1 in Section
6, Q2 in Section 5, Q3 in 3.1 and Q4 at `S:269-271`. It covers seed v1's
questions through the response's corrections. I also checked the inputs from
outside the author's framing. A grep of the neighbouring binding OMS
predecessor (`rfc_chainable_risk_oms_policy_boundary_synthesis.md`, binding
for v0.1.9) and the non-binding north star finds no conflicting `meta_json`,
feature-flag or regeneration clause. The README's corpus inputs (`README.md:111`)
and routing anchors exist: `execution-policy` (`README.md:98`),
`oms-order-lifecycle` (`:118`), `shorting-leverage-contract` (`:89`),
`cross-asset-accounting-events` (`:90`) and `asset-precision-tradability`
(`:92`). The OMS table was reconciled against my own census of
`rfc_ledgr_oms_seed_synthesis.md`, not against the synthesis's list, which is
how P2 and P3 were found. Response and response review match their recorded
roles (`response_review:9-31`).

## Checks that passed

- Code citations resolve at `579c418b` and support their claims:
  `R/fold-engine.R:1013-1016` (risk, post-risk, short exposure in P2);
  `R/availability-economics.R:425-436` (P3 short refusal);
  `R/backtest-runner.R:939`, `R/sweep.R:1827` (one fold);
  `R/fold-engine.R:1117-1128` (P3 plan), `:1915-1927` (scheduled-skip plan),
  `:610-625` (private next-bar OHLC), `:1878-1889` (P2 sees the observation
  only), `:1229-1242` (distinct-position conflict-free batch);
  `R/lot-accounting.R:323-331` (distinct positions, positive fill price);
  `R/ledger-writer.R:7-16` (spot principal exchange); `R/cost-model.R:421-426`
  (fixed versus notional fee).
- Contract ranges and anchors resolve: C:88-123, :135-184, :141-156,
  :284-305, :525-563, :545-548, :568-576, :884-904, :1257-1274, :1749-1768,
  :2914-2926; all nine `contract-*` anchors used in Section 2 and mechanism 3
  exist.
- RFC and plan ranges resolve: OMS:77-83, :85-91, :103-113, :156-161, :193,
  :202-216, :352, :359, :406, :411, :442-460, :475, :516, :547-552, :566, :610;
  Core:204-208, :413-431 (A2-A4); Records:63-69, :73-90, :141-148, :189-198;
  Skeleton:93-99, :137-157, :269-281; D:15-18, :27-30, :39-43, :46-48;
  Macro:574-580, :674-680; typed accounting :362-364; horizon:1517-1537;
  roadmap:185-194; optimization manual :77, :132-136; rfc_cycle.md:77-82;
  governance lifecycle :118-141. The Core and typed-accounting heading anchors
  match their headings.
- OMS table, apart from P2 and P3: every `meta_json` occurrence (`OMS:36`,
  `:44`, `:47`, `:156`, `:161`, `:193`, `:212`, `:216`, `:352`, `:552`, `:610`)
  is covered. The specific `*_json` fields and payload hashes in 4.2/9.2/9.3
  (`OMS:186`, `:191-192`, `:481`, `:485`) are correctly left as contracted
  representations (`S:89`, `:202-205`), not swept in. The heading-marker list
  matches the rows. The dispositions use the governance vocabulary.
- Section 6 D replacements are exact in scope. `D:15-18` from "It must not
  foreclose" and `D:27-30` are the locality claim and the Check, and the new
  Check carries seed v2's last-sentence text (`seed_v2:170-173`). The skeleton
  OMS row adds the scheduled-skip and P4 batching owners seed v2 asked for
  (`seed_v2:175-176`). The replacement keeps the order-shaped handoff, scalar
  cash, FIFO checkpoint, stage recorder and D2 gate (`Skeleton:93-99`;
  `Macro:659-680`). It does not conflict with WS16's skeleton-first,
  stage-parity, extension-first, one-family-per-cut or A2/A4 bullets.
- Synthesis and seeds agree: v1's one-place test is rejected on the response's
  evidence; v2's boundaries, mechanisms, scenarios, procedure and
  rule-outs carry through with only clarifications (wrappers, snapshot trust,
  read-only reads). The synthesis adds no capability, column or public
  behavior.
