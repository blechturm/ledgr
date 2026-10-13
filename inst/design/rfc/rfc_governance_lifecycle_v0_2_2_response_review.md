# Governance lifecycle response review

Mode: Type 1 evidence review, then Type 2 challenge.
Reviewer: Codex, independent of the Claude seed/response model family.
Date: 2026-10-13.

Baseline: 3a939f8ab2e5465cf8e4fbb68d6269671df4eedf.
There is no "commit with the response": it is untracked. This review reads
that response, SHA-256:
2881f27664872233fa9f8ecc37e6fb963982732ad3a961fa84b7dfb44d9fc4e1
Counts use committed baseline blobs, excluding concurrent pipeline edits.

Citation aliases (relative to inst/design/ unless prefixed root/):
R = rfc/rfc_governance_lifecycle_v0_2_2_response.md
S = rfc/rfc_governance_lifecycle_v0_2_2_seed.md
G = rfc/rfc_governance_review_post_v0_2_0_1_synthesis_v2.md
V = rfc/rfc_snapshot_verification_policy_v0_2_2_synthesis.md
W = rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md
Z = rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md
H = rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis
P = ledgr_v0_2_0_2_spec_packet/
Q = ledgr_v0_2_2_spec_packet/
T = Q/tickets.yml; C = contracts.md; I = README.md.
L = ledgr_roadmap.md; M = manual/optimization_coding_style.qmd.
An alias followed by :line identifies that file and line at the baseline.

## Type 1: inputs and independently measured evidence

The documents are appropriate inputs, but the response's census is not a
reliable replacement for the seed's census. I parsed YAML, enumerated Git
blobs, resolved Markdown links, and inspected cited sections and decisions.
I did not treat either author's totals or passing reviews as an oracle.

Measurement                         Independent result
Missing bridge-to-heading links     14 across 3 rows, not 15 across 4
Synthesis filenames                 47, including 11 history versions
History versions marked superseded  9; v10 still says ACCEPTED
Claim source populations            19 + 169 + 63 + 1 = 252
Ratio expressions n/m = decimal     21 occurrences on 15 lines
Standalone numeric 0.5 occurrences   14; raw substring 0.5 occurs 55 times
Whole-word breach occurrences       12
Scoped Markdown link occurrences    884; 45 missing-file occurrences
All-design Markdown links           918; 50 missing-file occurrences
Missing distinct file targets       12 scoped, 14 all-design
Broken design-document anchors      6 in either scope

Methods: synthesis names match _synthesis(_vN)?.md under rfc/. The link
population is tracked .md/.qmd files, parsed with markdown-it-py 2.2.0,
CommonMark: link/image usages including resolved references; no code,
external URLs or root-absolute URLs. Targets resolve relative to the source
against tracked files/directories. Heading slugs and explicit IDs resolve
design-document fragments. Scope is top-level inst/design files plus rfc/,
manual/ and Q/ (297 files); all-design is 637 files. Counts are occurrences,
not unique files. R:146-149's 905/977 and 66/109 are not reproduced by this
defined Markdown census; no resolver or inventory accompanies its numbers.

Claims: 19 sources name only contracts.md headings; 169 cite tickets/cuts/
batches without a contract or RFC/synthesis; 63 cite an RFC/synthesis.
LCL-0093 adds the mixed ticket/contract source (root/tests/claims.yml:987).
R:140-141's three counts are correct but not exhaustive. The missing-link
count compares each decisions.md row's receiving heading with its
reciprocal link, not clauses.

Recorded final cut ratios, in cut order (T:16-204):
8/12, 8/11, 2/4, 3/1, 4/2, 6/9, 3/4, 2/2, 5/4, 5/4, 8/17, 21/26, 6/3.
Eleven of thirteen exceed 0.5. Cut 11 ends at 8/17, not 7/17 (T:174).
Cut 12 completed 25 tickets and dropped one (T:189): D8's completed-ticket
denominator gives 21/25 = 0.840, not 0.808. The recorded invocations sum to
81 over 98 completed tickets, 0.827. This is a documentary count, not proof
of reviewer independence: Cuts 9-10 explicitly include agent reviews.
R:127-133 mixes interim and final counts. Its 15 and 38 are reproducible
as matching-line counts (ratios and substring 0.5), not occurrences.

Growth is reproduced: macro plan 3,387 -> 7,112 whitespace words, 12 dated
Section 7 amendments; tickets 17,762 -> 74,254, evidence 5,404 -> 29,950.
Acceptance and scope are 12,957 and 9,632 words; cut-review/close-review
fields total 4,060. R:90-97,134-139,174-177 mostly hold. Its 191 "commit"
tokens count only 7/8-digit hex strings containing letters: 202 short hex
tokens exist, 199 resolve locally to commits, including 11 numeric-only
ones. Of three unresolved tokens, 6755d2f1 is an equity digest (T:1351).

The three load-bearing claims:

- Pilot ran and was decided: TRUE. P/test_cleanup_closeout.md:119-142
  records reviews and outcomes; :198-205 records the reassessment obligation
  and promotion decision. P/README.md:322-329 and P/tickets.yml:891-900
  independently corroborate the routing. The pilot was Cut 1, not the whole
  eventual packet. No later reassessment was found in the named packets.
- Clause-level anchors absent: TRUE in the relevant sense. C has 13 H2s,
  one H3 at :1104 and no explicit anchor IDs; most clauses are bullets.
  This does not prove that an anchor on every bullet is necessary.
- Appended amendments exist: TRUE. Z:578-643 and W:589-610,744-761,989-1005
  preserve dated amendments and replacement relationships. This is not the
  only permitted amendment mechanism: rfc_cycle.md:59-65 permits narrow
  in-place corrections, and Z:7-17 records their use.

Wrong or unsupported findings in the response:

1. R:98-103,165 is wrong. Accounting consolidation is already linked at
   C:76; the cited excerpt stops at :74. The 14 unmatched destinations are
   feature-map 2, snapshot verification 5 and legacy removal 7
   (decisions.md:31-33). These are topic-heading mismatches, not a proven
   census of unimplemented clauses. Some receiving rules already shipped;
   reconcile stale bridge rows before adding "pending" links.

2. R:44-49 overstates the historical-header precedent. H.md and H_v2.md
   through H_v9.md have superseded headers at :3; H_v10.md:3 still says
   ACCEPTED although H_v11.md:3-5 replaces it. There are nine such notices,
   not ten. The 47-file total and three pending/two draft/one Stage headers
   do reproduce; the three cited final reviews approve their syntheses.

3. R:250-253 wrongly treats the hash-rule reference as unauthorized.
   I:46-48 expressly allows promotion from evidence. V:21-29,93-94,214-220
   expressly binds seed v2 Section 5, including use by reference. C:443-450
   follows that decision. Improve discoverability if wanted; do not label
   this an authority violation or silently withdraw that incorporation.

4. R:205-217 overclaims the gate diagnosis. D8 is per packet, but 11/31 was
   expressly a Cut 1 pilot (P/README.md:324), so "measured it that way" is
   inaccurate. G:186-188 rejects a yield quota, not counting correction
   reviews. A breach proves a threshold was exceeded, not why, nor that
   deleting the cost gate is preferable. R also misses the dropped-ticket
   denominator and the final Cut 11 record.

5. R:80-89,124-126 conflates delegation with conflict. L:4-7 separates
   cross-version, within-release and cut authority. M:8-12
   locates binding sources; root/AGENTS.md:47-55 adopts its review criteria.
   Neither establishes an incompatible rule by itself. Stale cut progress
   is real (I:66; Q/macro_plan.md:3; Q/README.md:3), as is rfc_cycle.md's
   nonbinding disclaimer versus I:42-44. Keep those concrete conflicts.

6. R:219-228 overgeneralizes evidence retention. .gitignore:112-115
   (root) ignores named raw clock/ladder directories, not all dev/bench
   records. A tracked summary is not automatically sufficient evidence:
   G:110-115 requires identity, environment, commit, command, result, clock
   and consequential rejection reasons. "Every review with findings gets
   a file" is a new obligation, not D4 restored.

Other sound corrections: no codebase-hygiene census tool exists in tools/;
Q/macro_plan.md:734-752 schedules it. Partial supersession discipline exists
(I:55-57; decisions.md:14-16; rfc_cycle.md:237). The six dead pipeline anchors
are real: horizon.md:4184,4200; Q/horizon_migration_reconciliation.md:21,26;
rfc/rfc_terminal_outcomes_v0_2_2_seed.md:6 and its _seed_v2.md:10.
Git 4f2d6c74 removes the terminal bridge row at Cut 6, before release close.
The cited metadata/documentation tests pin text, not this governance graph.

## Type 2: disposition of the ten requested changes

1. KEEP: correct the pilot history and obtain an explicit maintainer gate
   decision; retain the reassessment within this RFC (R:273; G:181-204).
2. REVISE: give affected rule groups stable addresses; do not require an
   anchor on every bullet before any supersession can work (R:275; S:156).
3. REVISE: permit dated amendments and working registers, while preserving
   narrow in-place correction exceptions and acceptance evidence (R:277).
4. DROP: the blanket ban on seed/response/review references contradicts
   explicit incorporation; forbid only unpromoted authority (R:279; V:21).
5. REVISE: check source/bridge/contract consistency, but derive a bridge
   only from a declared single source of section-level mappings (R:281).
6. REVISE: build the standalone scoped guard; baseline specific old defects,
   not whole historical directories with still-operative rules (R:282).
7. REVISE: preserve consequential findings and reviewed ranges wherever
   durable; neither one file per finding review nor summaries only (R:284).
8. KEEP: name v11 as the first scheduled application or record an explicit
   transition exception; cite the already-decided cleanup (R:286).
9. REVISE: use the reproducible populations above, not a new set of
   unexplained exact counts; separate discrepancies from defects (R:288).
10. KEEP: record the shared model family and this independent review;
    rotation disclosure does not itself establish independence (R:291).

Seed v2 must also take these missing requirements:

- Define authority per section and effective implementation boundary.
  Acceptance, partial consolidation and open obligations can coexist;
  one whole-file status cannot express V:53-55 and decisions.md:24-33.
- Keep promoted-by-reference rules traceable to their acceptance source.
  File kind or a newly corrected header must never confer authority alone.
- Define the guard's own acceptance and failure cases: broken references,
  duplicate IDs, partial replacements and new links to allowlisted debt.
  Passing it proves consistency, not independent judgment (G:130-136).
  Do not invent the response's unmeasured sub-second lane threshold;
  use the existing test control plane and measured cost.
- Require a bounded human semantic reconciliation for authority conflicts
  and consolidation; word matches cannot decide that two rules are equal.
  The scheduled clause comparison is a useful start (Q/macro_plan.md:840).
- Before replacing D8, classify invocations consistently, exclude dropped
  tickets, separate missing evidence from zero cost, and inspect outcome
  changes and maintainer effort. Specify a prospective reassessment owner,
  trigger and disposition; neither author has measured total current cost.
- Carry D4's reproducibility fields and decision-changing failure reasons
  through any cleanup. Preserve accepted obligations until a ticket owns
  them or the maintainer drops them (rfc_cycle.md:172-180,209-214).

REVISE_SEED is the right verdict. The findability/decay problem and overdue
reassessment are real. The response improves the pilot history but needs
the factual corrections and narrower requirements above before synthesis.
