# Lean core skeleton brief rereview

> Renamed 2026-11-04 from `inst/design/ledgr_v0_2_3_spec_packet/lean_core_skeleton_brief_rereview_1.md` when the
> skeleton brief became the lean core skeleton RFC. "B" and the brief paths
> below refer to the seed v2 text. The review prompt was drafted by Claude, a seed
> co-author; this review stays provisional until the maintainer rereads prompt
> and review together (`rfc_cycle.md`, Briefs).

- Mode: **Type 2, round 2**, 2026-11-04.
- Reviewed: the complete working-tree revision 2 of `inst/design/ledgr_v0_2_3_spec_packet/lean_core_skeleton_brief.md` against **1b69c7e9**, the round-1 review, WS16, the accepted synthesis/amendment, relevant contracts, enclosing source functions and cited evidence. Brief SHA-256: `A8460B8D744C83F33475A5C2A64FF03A8C5B807EFE5B6D466AE0F80724664423`.
- Ran: read-only Git diff/status, source and evidence checks, and the file hash. No new R probes, benchmarks, compilation, full tests, package check or private-data access. No existing file was changed.

## Verdict: ACCEPT_AFTER_PATCHES

Revision 2 resolves the substantive history, admission, context, execution and checkpoint concerns. One narrow implementation contradiction remains: preserving the feature calculation does not mean changing only output allocation when its input representation also becomes tiled. Apply N1. The memory choices and interface table are now explicit first-checkpoint obligations, not claims of completed proof; their gates must be satisfied before coding or further growth as stated. Referencing WS16 is sufficient and avoids duplicating its rules.

Below, **B** means revision 2 of the brief; all other paths are repository-relative.

## P1-P7 status

| Finding | Status | Assessment / remaining patch |
| --- | --- | --- |
| P1: bounded memory | **Partly closed** | B:191-198 and :254-265 remove the lookback override and false peak claim, account for resident components and require measurement. The output-only restriction at :256-257 and :347-348 still obstructs the chosen representation; apply N1. |
| P2: two-clock history | **Closed** | B:75-83 and :165-189 preserve knowledge ranges, vintage cells, carry dependencies and physical-only tile inclusion. The two named readers support the distinction: `R/history-frame.R:207-284`. |
| P3: admission | **Closed** | B:200-209 preserves finite treated counts, general requests, selection and warmup; the trailing-run shortcut is restricted to its valid case. B:351-355 measures the complete read. |
| P4: repeated intent / non-fill events | **Closed** | B:96-104 compares targets with settled holdings and includes openings and dispositions. |
| P5: public boundary | **Closed** | B:84-89, :118-124 and :219-233 preserve typed state, classed lazy context behavior and recorded public metadata. |
| P6: first checkpoint | **Closed** | B:242-283 supplies coverage, the before-coding interface table, validation ownership, stage isolation and publication ordering. WS16 supplies the workstream gates. Repeat-instrument coverage remains subject to the incorporated synthesis Section 3's distinct-position rule per kernel call. |
| P7: evidence | **Closed** | B:58-92, :111-117, :132-138, :296-311 and :318-355 correct the scopes, units, fractions and obsolete accessor description. No new unsupported number or broken source reference found. |

The WS16 reference leaves no workstream-rule gap. B:244-250 names the rules and requires recording/rerunning provisional evidence; `inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md:649-677` supplies isolation, the accepted-close pin, A1 review, budgets, subtraction, failure stops and escalation. A builder must follow that incorporated authority. The interface table is a required next artifact, not permission to invent semantics while coding.

## New finding

### N1 — Medium: preserve the feature algorithm, not its dense input access

**Evidence:** B:65-79 requires tile storage; B:254-257 and :347-348 permit only output-allocation changes. But the complete input function at `R/history-features.R:169-218` reads `substrate$bars[[field]][instrument_idx, prefix]` (:187). The preparation function also allocates and writes full matrices at :447-504. `R/history-substrate.R:422-460` constructs those dense inputs. The accepted synthesis permits changing storage inside the common substrate while preserving semantics (`inst/design/rfc/rfc_lean_fold_core_v0_2_3_synthesis.md:82-85`).

Taken literally, the output-only instruction leaves the feature service unable to consume the proposed plain tile collection without retaining another dense input representation. Input access must be adaptable too; the indicator calculations, knowledge handling and evidence remain unchanged.

**Exact patch:**

- In principle 5, replace “Features come from the existing service, unchanged” with “Features keep the existing service's calculation semantics”. Replace “and only then cut into tiles” with “with outputs and evidence stored in tiles without changing the calculation sequence”.
- In Section 4 replace “changes only where the output is allocated” with “adapts its input access and output allocation to the tiled substrate without changing calculation semantics or duplicating the feature engine”.
- In Section 7 item 4 replace “The existing feature service stays; only its output allocation changes” with “The existing feature calculation stays; its input access and output allocation adapt to the tiled substrate under Section 4”.

The new two-clock paragraph agrees with the enclosing base/overlay and vintage readers (`R/history-frame.R:162-284`). Revised numerical claims agree with the recorded layout tables and scripts, FIFO/floor tables, scalar cost CSV and final-review SMA record. The 1.10 gate agrees with `inst/design/contracts.md:3351-3373`. These are source checks, not new timing or private-catalog reproductions.
