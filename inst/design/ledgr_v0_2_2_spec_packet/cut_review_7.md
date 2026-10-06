# Cut 7 Review: Feature-Map Read Surface

**Mode:** Type 1, then Type 2; independent ticket-cut review.
**Reviewer:** Claude, 2026-10-06. I wrote seeds v1 and v2 and the synthesis
final review, so this review stays on ownership, grain and evidence and does
not reopen the accepted design.
**Tree:** `83e8376` plus the uncommitted accepted synthesis, `tickets.yml`,
packet README, `decisions.md` and `rfc/README.md` edits.

## Question 1: Type 1, ownership

| Requirement | Owner | Note |
| --- | --- | --- |
| D1 resolver, scalar widening, unknown-name message | LDG-2962 | AC1, AC2 |
| D2 no plural, subset or alias accessor | LDG-2962 | AC5 |
| D3 explicit-map refusal, three consumers, memo | LDG-2963 | AC1, AC2 |
| D4 mapped wide aliases, unmapped IDs, long view | LDG-2963 | AC3 |
| D5 signal values, `eligible`, origin | LDG-2962 | AC2 |
| D5 `ledgr_signal_return()` help routes to an alias | **unowned** | P3 |
| D6 parameterized inspection | LDG-2964 | AC1-AC3 |
| D7 warnings and threshold | LDG-2962 | AC4 |
| D8 prepared candidate-local lookup, availability | LDG-2962 | AC1, AC3 |
| Section 3 contract changes 1-7 | LDG-2965 | scope, AC2 |
| 4.1 parity matrix and isolation mutation | LDG-2962 | AC1 (LDG-2965 AC4 re-lists; R2) |
| 4.2 refusal per consumer, wide identity | LDG-2963 | AC1, AC3 |
| 4.3 signals and errors / inspection / warnings | 2962 / 2964 / 2962 | AC2 / AC1 / AC4 |
| 4.4 structural counter / clocks | 2962 / 2965 | AC3 / AC3, see P4 |
| Section 7 callback obligation | LDG-2965 | AC5 overclaims; P1 |
| Section 8 step 1 acceptance routing | done | verified in the diffs |
| Section 8 step 4 bridge timing | contradicted | P2 |
| Teaching that says no alias-aware read exists | **partly owned** | P3 |

**Independent checks.** 500 x 1,260 = 630,000. Dependencies form the stated
serial chain: LDG-2962 has none and each later ticket depends on the one
before. The cut is `review_pending` with exactly one `pending` workstream (16)
and four `pending` tickets; nothing else in `tickets.yml` is pending. One cut
review plus one close review over four tickets is 0.500, which holds only if
the close review passes without a re-review. The synthesis is marked
accepted, the bridge row links Sections 1-3 to the Strategy and Context
contracts, the pipeline row moved to `Obligations open`, and the ctx-frame
row now names the singular resolver and D4; only removal timing disagrees
(P2). Historical projection, `ctx$window()`, recursive indicators,
missingness, scheduling and frame retirement appear only in `out_of_scope`.

## Question 2: Type 2, grain

**LDG-2962 is one runtime boundary.** Resolver, signal route and prepared
ownership share one table and fail together. D7 lets a loop warn only once
the plane replacement exists, so splitting warnings out would open a window
where they name a missing read. The riskiest independent failure, threading
the prepared table into availability's per-pulse rebuild, has its own
detectors (after-restriction mutation, structural counter). Effort L is honest.

**LDG-2963's common boundary is real.** `ledgr_pulse_wide()` calls
`ledgr_pulse_features()`, and both share the lookup builder with
`ctx$features()` (`R/feature-inspection.R:287-307`, `:480-504`;
`R/feature-alias-map.R:177-211`). The known-name set is D1's table, so the
dependency on LDG-2962 is real; a pulse supplies that set from its own state.
AC1 forces a detector per consumer.

**LDG-2964 is real but not truly serial.** Inspection disagreeing with a run
is an independent failure with its own public surface, so it is not padding.
It needs nothing from LDG-2963 and could depend on `[]`. Each ticket
reconciles before the next, so the chain delays this fix but hides nothing.
No change required.

**LDG-2965 is real work:** seven contract clauses, the wide-key amendment, the
demo, articles and their pins, clocks and reconciliation. Its teaching list
is incomplete (P3).

**Gates.** Three alternating pairs at a 0.90 plane/loop median is an honest,
deliberately lenient materiality bar: at 630,000 calls near 7.4 us each the
loop alone costs seconds, and no speed claim is made. The comparison is
meaningful only if both arms trade identically, which AC3 does not require
(P4). The ordinary Workstream 11 suite gates availability plane reads and
candidate-local preparation (`feature_gaps` and `availability_sweep` read
through the plane every pulse). Nothing gates the dense path, where the scalar
widening adds a lookup to every `ctx$feature()` call (P4).

## Patches

**P1. The obligation is broader than Section 7 disposes.** The Strategy
Callback Addendum also defers "any `ctx$feature_at(feature_id, idx)` public
scalar shortcut". Synthesis Section 7 (lines 285-289) disposes of the other
four items only, yet LDG-2965 AC5 claims full discharge. Either keep a
pipeline item for `ctx$feature_at` with its trigger, or have the maintainer
drop it with a recorded reason. Then let AC5 discharge only the four items.

**P2. Removal timing contradicts the accepted routes.** LDG-2965 removes the
`decisions.md` bridge in-ticket. Synthesis Section 8 step 4 (line 310) and
`decisions.md` (line 14) keep it until release closeout. `rfc/README.md`
(line 65) removes a newly owned obligation at ticket cut, not after
consolidation. Align LDG-2965: the bridge leaves at release closeout, and at
cut acceptance the feature-map row points to Cut 7, keeping only the P1
residual.

**P3. Name every teaching surface LDG-2962 makes false.** "ledgr has no
alias-aware whole-universe feature read yet" appears in `indicators.qmd:480`,
`sweeps.qmd:200`, `strategy-authoring-tools.qmd:184` and
`missing-data-and-sessions.qmd:255`, and is pinned at
`test-documentation-contracts.R:1908` and `:2027` and in LCL-0103. LDG-2965
names only Indicators and strategy-authoring. Add the other articles, those
pins, the demo strategy and the `ledgr_signal_return()` help, which still says
to register every lookback (`R/strategy-helpers.R:113-115`; synthesis D5).
Article prose keeps the maintainer's per-article sign-off.

**P4. Make the clock comparable and gate the dense path.** Add to LDG-2965
AC3: the loop and plane strategies produce identical fills, equity and
strategy state; and the loop arm, run on the pre-cut commit and on the
candidate under the same three-pair protocol, stays within 1.10, or the
record says why the dense scalar path needs no regression gate.

## Record-only

- **R1.** Synthesis Section 3 (line 194) still says "the implementation also
  corrects" the ctx-frame wording, which acceptance has already done.
- **R2.** LDG-2965 AC4 re-lists LDG-2962's witnesses. Reword it as a
  regression rerun so ownership stays with LDG-2962.

PASS_AFTER_PATCHES
