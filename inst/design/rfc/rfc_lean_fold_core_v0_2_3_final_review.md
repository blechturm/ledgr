# Lean Fold Core: Type 1 Final Review

- Mode: Type 1, RFC cycle stage 8; independent Codex session; 2026-11-03.
- Verdict: **PASS_AFTER_PATCHES**, conditional on P1 below. Patch not applied.
- Reviewed: `release/v0.2.3`, `75551dac38c841976ac77810f66b6a46eaf9fad7`.
  The working tree was clean before review. The synthesis's cited baseline is
  `df7ad1aeac0d0a939b19310b092e9282b6635ada`; no `R/`, test, contract,
  spike or macro-plan changes separate those two commits.
- Brief: drafted by Claude and instructed to be run by the maintainer.
  Under `inst/design/rfc_cycle.md:344`, acceptance of the framing remains the
  maintainer's responsibility. This session authored none of the inputs.
- Scope: the synthesis including A1-A4 and Q5, its four cycle inputs, named
  binding syntheses, WS14 FIFO amendment, repository rules, source and spike
  evidence. Verification only (`inst/design/rfc_cycle.md:238`, `:274`).
- Citation aliases: **S**, **V1**, **R**, **RR**, **V2** are respectively
  `inst/design/rfc/rfc_lean_fold_core_v0_2_3_synthesis.md`, `_seed.md`,
  `_response.md`, `_response_review.md`, `_seed_v2.md` with the same prefix.
  Other paths are repository-relative. Lines refer to the reviewed head.

The synthesis faithfully settles the inputs with explicit, reasoned corrections.
The amendment supplies additional maintainability constraints and the maintainer's
no-cap decision. Its precedence sentence resolves the substantive differences;
the remaining defect is the missing local supersession record. No design problem
was found and no decision is reopened. This is not acceptance of implementation,
switch parity, private-data evidence or performance results.

## Numbered findings

1. **Patch required: mark the amendment's affected sections and enumerate its
   supersession.** S:358-396 has acceptance provenance and explicit precedence,
   and S:4-7 links it from the header. However, Sections 1, 4, 7 and 8 still
   present the superseded cap/escalation language without local notices
   (S:23, :169, :273-288, :307-308); Sections 4-7 also receive A1-A4 additions.
   There is no addressed supersession table. The standing rule explicitly
   requires the table and affected-section notices
   (`inst/design/rfc_cycle.md:77-82`;
   `inst/design/rfc/rfc_governance_lifecycle_v0_2_2_synthesis.md:71-76`,
   `:118-131`). This is a document-consistency correction, not an objection to
   no cap. P1 preserves the accepted text and makes the operative reading local.

2. **Verified: the settlements preserve the consequential disagreements.**
   R:53-115 challenges mixed clocks, architectural causation, simplified context
   and incomplete WS15 evidence; RR:27-36 adopts those challenges, but V2:48-63
   retains overbroad timing and equity descriptions. S:25-57 correctly qualifies
   them instead of promoting them into production proof. R:117-152 and
   V2:103-129 require full ordered parity, interacting failures and independent
   witnesses; S:181-219 retains those requirements and pins the accepted
   WS7/WS8/WS15 close rather than a moving oracle. V2's Q1-Q4 (V2:172-180)
   receive explicit answers in S:122-130, :134-177, :181-190, :223-241.
   S:251-259 rejects automatic hybrid fallback while preserving a maintainer
   route for current-core A work. S:292-312 records why the other directions
   were rejected. Q5's earlier pending cap is expressly replaced by S:390-396;
   its memory/kernel and correction-round quality escalations survive. A1's
   skeleton, A2's baseline-derived budgets, A3's rule disposition and A4's
   subtraction review add requirements without weakening Sections 2-6.
   A3 is read with S:188-192: a deliberate oracle difference still requires the
   explicit decision and affected proof reruns there; it is not an independent
   permission to change public semantics.

3. **Verified: the named authorities and current code support the boundaries.**
   S:61-89 preserves typed-carrier Sections 3.1-3.6 (axes, ownership, producer
   validation, P1/P2 separation, ordered accounting and failure boundaries),
   durable-records Sections 2-7 (exact logical rows/sequence, irreducible sizing,
   filtered read-only decoding, resume retirement and publication recovery),
   and strategy-authoring D2's event-derived position facts. Direct source
   witnesses are `R/fold-engine.R:1884`, `:1917`,
   `R/position-facts.R:197`, `:216`, `:240`, and
   `R/lot-accounting.R:278`, `:323`, `:525`, `:549`, `:706`.
   The cited structural tests exist and protect meaningful guarantees
   (`tests/testthat/test-ws4a-carrier.R:413`,
   `tests/testthat/test-fold-phase-contract.R:113`,
   `tests/testthat/test-execution-spec.R:942`); S:223-241 does not waive them.
   S:93-120 faithfully adopts the macro FIFO/dependency amendment
   (`inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md:832-850`).
   Isolation and atomic replacement preserve `AGENTS.md:9-25`, and `dev/` is
   excluded at `.Rbuildignore:4`. The preparation proposal preserves
   `inst/design/contracts.md#contract-execution-fold-core` (:124-140),
   `#contract-execution-window-start` (:353-370), and
   `#contract-verification-release-gates` (:3351-3373).
   Its ordered scalar accounting exception is consistent with the carrier
   synthesis's Section 3.4 and the optimization manual's sequential-semantic
   exception; no alternative execution-mode branch is authorized.

4. **Verified: these are the right decision inputs, independently of their
   authors, within their stated limits.** I checked the actual public contract
   groups above, the existing stage routing, FIFO validators/arithmetic, position
   fact implementation and registered negative tests, rather than inferring
   authority from the seeds' descriptions. The independently located stage
   profile records an existing optimization problem
   (`dev/bench/v0_2_3_fill_heavy_profile/evidence/stages.csv:2-15`), but also
   labels its clock and host limits (`dev/bench/v0_2_3_fill_heavy_profile/README.md:36-42`,
   `:63-68`); it corroborates relevance, not a current speedup claim.
   The runners expose the mixed timing boundary and narrow comparators directly
   (`dev/spikes/r_floor/run.R:39-61`, `run3.R:26-30`,
   `seam_p35.R:90-98`). I executed the synthesis's entire reproduction block
   against this head, including its negative control, and separately probed
   opening compensation, event-derived position facts and SMA overlap below.
   Thus the spike evidence is useful evidence about feasible subsets, not an
   author's assertion of complete-engine equivalence. Memory and omitted
   interactions are correctly retained as future proof gates (S:155-177,
   :194-219). The private Sharadar gate is actually still open in the current
   packet (`inst/design/ledgr_v0_2_3_spec_packet/close_review_23_rereview_2.md:101-126`);
   S:181-186 correctly does not inherit a PASS. These inputs are appropriate
   for settling the route; they are not sufficient switch-entry evidence.

## P1: exact proposed patch to the synthesis

Apply only after maintainer disposition of this review. The following text
changes no decision, budget, proof gate or no-cap outcome.

```text
*** Begin Patch
*** Update File: inst/design/rfc/rfc_lean_fold_core_v0_2_3_synthesis.md
@@
   Other R paths are repository-relative. Source citations use this baseline.
+- Final-review revision (2026-11-03): added the acceptance amendment's
+  addressed supersession table and local notices; decisions unchanged.
 
 ## 1. Decision And Its Evidence
 
+**Amended 2026-11-03:** the [acceptance amendment](#amendment-maintainer-2026-11-03-acceptance-conditions)
+retains family-sized reviewed growth and replaces this section's aggregate-cap
+qualification with Q5's no-cap decision.
+
 **ADOPT bounded B with the constraints below:** grow a lean R core under
@@
 ## 4. Memory And Family Order (D3; Q1)
 
+**Amended 2026-11-03:** [A1 and Q5](#amendment-maintainer-2026-11-03-acceptance-conditions)
+add the maintainer-reviewed skeleton/first-family prerequisite and replace
+the cap reference below. Memory and kernel prerequisites remain gates.
+
 **Q1: the first growth checkpoint has separate memory-preparation and complete
@@
 ## 5. Reference And Switch Proof (D4; Q2)
 
+**Amended 2026-11-03:** [A3](#amendment-maintainer-2026-11-03-acceptance-conditions)
+adds the rules ledger and its pre-switch disposition requirement; the
+reference-pin and correctness-change rules below remain binding.
+
 **Q2: pin the accepted WS7/WS8/WS15 close**, including its complete evidence gates,
@@
 ## 6. Tests, Plan Amendment And Promotion (D5; Q3)
 
+**Amended 2026-11-03:** [A4](#amendment-maintainer-2026-11-03-acceptance-conditions)
+adds subtraction review and same-workstream correction at every family close.
+The remap, isolation and atomic-promotion constraints below remain binding.
+
 **Q3: no blanket test-file exemption.** Only references to retired private
@@
 ## 7. Objectives, Cap And Escalation (D6; Q5)
 
+**Amended 2026-11-03:** [A2 and Q5](#amendment-maintainer-2026-11-03-acceptance-conditions)
+add per-family speed/line budgets and supersede the Q5 paragraphs below:
+there is no aggregate cap or current-core release alternative. Record "none"
+under macro WS14 as decided by the maintainer. The initial re-estimate is a
+progress report; memory/kernel failures and a third correction round still
+stop the affected work for maintainer disposition. The aspirations and
+baseline-derived measurement requirements below remain binding.
+
 Adopt 50/150 us quiet-pulse, 100 ms outside-loop and PMwR 1.5x narrow/parity-wide
@@
 ## 8. Rejections And Remaining Routing
 
+**Amended 2026-11-03:** [Q5](#amendment-maintainer-2026-11-03-acceptance-conditions)
+is decided as no cap. References below to its pending escalation or a bounded
+aggregate plan are historical; the rejection reasons and other routing remain.
+
 | Rejected direction | Consequential reason |
@@
 The maintainer accepted this synthesis on 2026-11-03, choosing "correct and
 fast" over an earlier release, with the conditions below. They bind with
 Sections 1 to 8; where they differ, they prevail.
 
+| Target artifact | Addressed section / group | Disposition | Replacement or retained authority |
+| --- | --- | --- | --- |
+| This synthesis | Section 1, aggregate-cap qualification | Amended | This amendment, Q5; family-sized reviewed growth retained |
+| This synthesis | Sections 2-3, binding boundaries and FIFO | Unchanged | Sections 2-3 |
+| This synthesis | Section 4, growth prerequisites and cap reference | Amended | This amendment, A1 and Q5; Section 4 memory/kernel gates retained |
+| This synthesis | Section 5, correctness-rule disposition | Amended | This amendment, A3, together with Section 5's pin/change rules |
+| This synthesis | Section 6, family-close review | Amended | This amendment, A4; Section 6 test/promotion rules retained |
+| This synthesis | Section 7, family budgets | Amended | This amendment, A2, together with Section 7's measurement requirements |
+| This synthesis | Section 7, Q5 cap, cap-stop and release alternatives | Superseded | This amendment, Q5; memory/kernel and correction-round escalations retained |
+| This synthesis | Section 8, Q5 pending routing and aggregate-bound framing | Amended | This amendment, Q5; other Section 8 rejections/routing retained |
+
 **A1. A deliberately written skeleton.** The lean core's skeleton and its
*** End Patch
```

## Executed evidence and reproduction

Windows; R 4.6.1 (2026-06-24 ucrt), collapse 2.1.8, DuckDB 2.0.0, TTR 0.24.4.
Source loaded with `pkgload::load_all(compile = FALSE)`. No compilation or timing
gate ran. Both processes exited zero; startup emitted locale-setting warnings.
TMP, TEMP and TMPDIR were set before R startup to
`C:/Users/maxth/ledgr-wt/final-review-tmp`; the second process printed a
`tempdir()` beneath that directory. All disposable stores stayed there.

This PowerShell command ran S:321-355 verbatim:

```powershell
$scratch = 'C:/Users/maxth/ledgr-wt/final-review-tmp'
$env:TMP = $scratch; $env:TEMP = $scratch; $env:TMPDIR = $scratch
$lines = Get-Content -LiteralPath 'C:/Users/maxth/Documents/GitHub/ledgr/inst/design/rfc/rfc_lean_fold_core_v0_2_3_synthesis.md'
$code = $lines[320..354] -join "`n"
$code | & 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe' -
```

Observed output, agreeing with S:42-54:

```text
1 0 0 395
2 0 0 397
3 0 0 399
4 0 0 399
5 0 0 398
FALSE 250 0 TRUE
TRUE 250 0 TRUE
fills = 2717; fills_equal = 1; equity_projection_equal = 1
public equity columns: ts_utc, equity, cash, positions_value, running_max, drawdown
```

The FIFO columns are seed, differing intact blocks, canonical fallbacks,
differing gutted blocks. The P2 columns are history flag, pulse count,
selected-field differences and retained serialized-view equality.
The un-naming and selected-equity qualifications are therefore necessary and
accurate. The reported FIFO 2.2-2.5x range agrees with the recorded canonical/R
rows in `dev/spikes/lean_fifo/evidence/cost_quickr.csv:2-6` and
`dev/spikes/lean_fifo/evidence/cost.csv:2-3`; those timings and quickr
compilation were not rerun.

Additional independent probes used the same environment and R invocation.
After the same source load, this reproduces their arithmetic and checks:

```r
ns <- asNamespace("ledgr")
b <- ns$ledgr_lot_book(2L); b$realized_pnl <- 5; b$realized_comp <- 1e-13
z <- ns$ledgr_lot_opening(b, c(1L,2L), c(3,-1.5), c(10,-2))
stopifnot(identical(z$book$realized_comp,b$realized_comp),
          identical(z$book$realized_pnl,b$realized_pnl))
f <- ns$ledgr_position_facts_apply(
  list(entry_bar=2L,exit_bar=NA_integer_),1L,10,5,3L,TRUE)
stopifnot(identical(f$entry_bar,2L),is.na(f$exit_bar))
f <- ns$ledgr_position_facts_apply(f,1L,5,0,4L,FALSE)
stopifnot(is.na(f$entry_bar),is.na(f$exit_bar))
set.seed(42); x <- 50*exp(cumsum(rnorm(250,0,.02)))
a <- TTR::SMA(x,10)[101:250]
b <- TTR::SMA(x[92:250],10)[10:159]
print(c(identical=identical(a,b),different=sum(a!=b),max_diff=max(abs(a-b))))
```

Opening compensation and realized PnL were unchanged; a partial sale retained
entry bar 2 with unknown exit; a non-fill close cleared entry without inventing
exit. The fixed-overlap SMA differed on all 150 compared values, maximum
absolute difference `4.973799e-14`. This independently supports S:147-153's
warning about exact history across preparation tiles; it does not prove bounded
preparation or restrict existing valid feature requests.

The macro-plan/AGENTS amendments and owner/review routing described by S:243-259,
:309-313, :390-392 have not landed at this head. They remain explicit follow-up
work before implementation; this review does not edit or implicitly satisfy
them. No package-wide test/check PASS is claimed. Only this requested review
file was written; no tracked input, registered test, fixture or oracle was changed.
