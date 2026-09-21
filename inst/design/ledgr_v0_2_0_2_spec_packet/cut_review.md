# v0.2.0.2 Ticket-Cut Review

**Reviewed cut:** `6d37eeb`
**Mode:** Type 1 coverage review and Type 2 grouping review
**Date:** 2026-09-21

## 1. Type 1: Coverage And Recomputed Counts

The numerical inventory is reproducible from the CSV at `788bd92`:

| Population | Recomputed result |
| --- | ---: |
| blocks / files | 930 / 134 |
| fast / review / heavy | 461 / 277 / 192 |
| fast attributed seconds | 70.80 |
| canonical differential core | 3 blocks, 6.16 seconds |
| fast plus canonical core | 76.96 seconds |
| failed blocks / failing assertions | 9 / 23 |
| dispositions | 21 fix, 35 move, 134 shrink, 126 merge, 26 delete, 588 keep |
| mixed files / their non-fast blocks | 76 / 333 |
| homogeneous non-fast files | 23 |

The ticket arithmetic also reproduces where it follows the table. Oracle
repair is 15 + 1 engine witness + 4 graphics + 1 warning = 21. The eight
red governance blocks plus the fold witness are the nine failed blocks.
Shrink is exactly 134 blocks across 50 files: 29/89.39 s, 35/79.80 s,
13/44.86 s, 15/47.41 s, and 42/76.10 s. Merge excluding the documentation
file is exactly 77 blocks across 37 files: 17/1.38 s, 24/2.04 s,
10/1.06 s, 20/3.43 s, and 6/0.14 s. All 28 tickets are pending.

The principal synthesis mechanisms have identifiable owners: LDG-2751 owns
the runner and profile authority; 2752 the independent census; 2755 D1/D3
and the registry; 2756 the canonical core and release overlay; 2757 CRAN
mode; 2758 D2 and the gates; 2759 Section 6; and 2761-2772 the three cleanup
workstreams. The split between 2752, 2758, and 2759 is construction, gate,
and failure-sensitivity evidence, not duplicate ownership.

### Blocking coverage defects

1. **The 49 documentation merges are reclassified without authority.** The
   table has 75 `test-documentation-contracts.R` blocks: 26
   `delete_after_replacement` and 49 `merge`. The synthesis binds 126 merges
   and 26 deletions. LDG-2772 instead deletes the remaining 67 blocks after
   Workstream 1 removes eight. LDG-2771 replaces only the rendered-artifact
   check. The other 48 include runnable examples, installed help paths,
   public result semantics, timing contracts, lifecycle boundaries, and
   public availability journeys. The README assertion that the synthesis
   routes these pins to the render step is false. Return the 49 to Merge,
   grouped by their audit claim family; delete only the 26 nominated rows
   after their replacements or reasons exist.

2. **Section 2.5 and D5 have no implementation owner.** No ticket audits the
   twelve files using mocks against the non-circular-oracle rule, gives each
   frozen fixture a regeneration command independent of its guarded code,
   or establishes the bound teardown/temp-directory and deterministic-value
   rules beyond the few named CRAN repairs. LDG-2763 protects frozen fixtures
   only while shrinking them, and LDG-2760 merely documents four rules.
   The five D5 review questions and the prohibition on mandatory inline
   Oracle notes are also absent from ticket acceptance. Add one bounded
   rule-enforcement ticket and put the D5 review obligation in the
   workstream review metadata or LDG-2760 acceptance, not in per-block prose.

3. **Several smaller bound obligations lack a unique acceptance owner.** Add
   explicit acceptance for: named heavy protocols having an owner and
   diff-based checker (LDG-2751); no load-bearing claim depending only on an
   optional-package block (LDG-2755 or 2757); unconditional release execution
   of extended parity (LDG-2756); and the synthesis's closeout clocks and
   counters (a closeout ticket or one named final-ticket owner). These are
   presently narrative scope, or absent, rather than falsifiable ownership.

4. **The authoritative YAML does not enforce workstream order or review
   stops.** LDG-2751 can start before five of six Oracle tickets finish;
   Shrink depends on LDG-2758 but not LDG-2756, 2759, or 2760; every Merge
   ticket depends only on LDG-2765, not the other four Shrink tickets; and
   Delete begins from LDG-2770 while four Merge tickets may remain open.
   Add workstream-level `depends_on` and `requires_review_acceptance` fields
   to `tickets.yml`, or an equivalent explicit gate. README prose cannot
   carry sequencing when YAML is declared the sole authority.

Apart from these items, Sections 2, 4, 5, 6 and D1-D4 are faithfully cut.
D5 becomes faithful after finding 2. I found no contradictory implementation
ticket and no ticket that authorizes the rejected v1/v2 mechanisms.

## 2. Type 2: Is The Grouping Sensible?

The five workstreams are the right units and the close-only review points are
well placed, once the YAML actually gates them. Oracle repair establishes a
trustworthy baseline; Control plane proves routing before bulk edits; Shrink
and Merge each expose one coherent loss-of-evidence risk; Delete is safely
last. Per-ticket review would add ceremony without a distinct decision.

The Shrink cut is especially defensible. Its five fixture families partition
all 134 rows with no overlap or omission, and their measured costs are
balanced enough that none is a disguised one-line ticket. The five Merge
tickets likewise partition all 77 non-documentation rows by recognizable
claim families. I would preserve both cuts.

I would not accept the documentation reroute. Forty-nine heterogeneous
surface guarantees do not become one render-freshness invariant because they
share a file. Keep them in Merge and require a current executable replacement
or an individually justified deletion. This is the exact overlap judgment
the Merge review exists to make.

Twenty-eight is an honest grain, not gate padding. The six planned reviews
give 0.21 per ticket, but even collapsing the obvious small neighbors to only
12 tickets would still meet the 0.5 gate exactly. The denominator therefore
does not need 28 to pass. Runner, census, registry, CRAN isolation, canonical
parity, and mutation proof are separate failure surfaces; the fixture and
claim-family tickets are material bodies of work. I might combine the gate
and its mutation proof, and absorb the short README into the Control-plane
closeout, but that is a maintainability preference, not a finding.

My corrected cut would restore the 49 rows to Merge, add the bounded rules
ticket and a closeout owner, and encode workstream gates in YAML. Ticket count
may move slightly; it should be an output of those real units, not preserved
to keep the ratio attractive. These are bounded ticket-cut patches. The
five-workstream direction does not need another RFC or Type 2 cycle.

PASS_AFTER_PATCHES

## Patch record

Applied by Claude in place, 2026-09-21, same commit as this file. Finding 1:
the 49 rows return to Merge as LDG-2774 with a per-row outcome; Workstream 5
holds the 18 remaining DELETE-01 rows and their one replacement check.
Finding 2: LDG-2773 owns the 2.5 rules over the named inventory; D5 is a
`review_obligations` field on every workstream review and an LDG-2760
acceptance line. Finding 3: acceptance lines added to LDG-2751, 2755, 2756,
2757, 2758; LDG-2775 owns the closeout. Finding 4: `sequencing`,
`depends_on_workstream`, and `requires_review_acceptance` in `tickets.yml`;
cross-workstream ticket dependencies removed. Thirty-one tickets; 6 / 31.
The two Type 2 preferences are recorded in the README and not taken.
