# v0.2.0.2 Packet

**Status:** Two cuts. Cut 1, the test-suite cleanup, is closed: five
workstreams complete, eleven reviews over thirty-one tickets, and the
governance loop promoted for v0.2.0.2 with mandatory reassessment before the
next version inherits it. Cut 2, the accounting-core consolidation, was cut
on 2026-09-22 and awaits its cut review. Nothing in cut 2 opens until that
review is accepted.

**Source of truth:** `tickets.yml` in this directory is the only ticket,
cut, and sequencing authority. Each cut names its own RFC authority there;
each workstream names its cut. The tables below are rendered views and are
not separately edited. There is no batch plan and no batch evidence essay.

**The loop:**
`inst/design/rfc/rfc_governance_review_post_v0_2_0_1_synthesis_v2.md` — D1
briefs, D2 modes, D3 workstreams, D4 artifacts, D8 gate — piloted on cut 1
and promoted for the rest of this release.

## Cut 1: Test-suite cleanup (closed)

The five workstreams the accepted testing-architecture synthesis
(`inst/design/rfc/rfc_testing_architecture_v0_2_0_2_synthesis.md`) binds,
in its order: oracle repair, control plane, shrink, merge, delete. Source
table: the 930-row audit at `788bd92`. Tickets LDG-2745 through LDG-2775.
Cut review `cut_review.md`, `PASS_AFTER_PATCHES` at `6d37eeb`, patched in
place. Closeout and pilot record: `test_cleanup_closeout.md`.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 1 Oracle repair | 2745–2750, 2773 | 21 oracle repairs including the `engine_version` witness; the four graphics blocks; the warning muffle; the finalizer advisory; the eight red governance pins deleted with reasons; the four bound rules applied to the twelve mock files and seven frozen fixtures | every repaired block fails on its stated defect; no mock supplies what its block asserts; the suite is green |
| 2 Control plane | 2751–2760 | one runner with fail-closed selection and named heavy protocols with owners; the two-sided census; profile tags for 23 homogeneous and 76 mixed files; the claims registry and checker; the canonical core into `fast` and extended parity registered in `review`; CRAN mode; both gates with `review` unconditional at release; the control-plane mutation proof; `tests/README.md` | `fast` and CRAN run clean under budget with a reconciled census; gutted selection fails the gate; no registered claim rests only on optional-dependency skips |
| 3 Shrink | 2761–2765 | 134 fixture reductions across 50 files, cut by fixture family: sweep; experiment and run; availability; walk-forward and metrics; features, strategy, and cost | each reduced block's failure condition still fails under deliberate perturbation |
| 4 Merge | 2766–2770, 2774 | 126 merges: 77 across 37 files by claim family — metrics; public behavior; identity and configuration; snapshot, features, and execution; determinism — and the 49 documentation-surface blocks, each merged into its claim family with an executable oracle or deleted with its own reason | no declared claim loses its detecting block; the overlap question answered per merge; every one of the 49 has a named outcome |
| 5 Delete and closeout | 2771, 2772, 2775 | the 17 remaining replace-then-delete pins: one current-state artifact, link, logo, and optional-dependency check built in a bound lane, then the pins deleted; the packet closeout with the pilot counters and clocks | the checker passes; the replacement runs where the census sees it; the closeout states the ratio and the maintainer's decision on the loop |

Two departures from the audit's disposition column, both recorded in the
cut review and the closeout: the `engine_version` witness got its own
ticket so the historical-field rule is visible, and the 49
documentation-surface merges were returned from a render-step reroute to
claim-family adjudication under LDG-2774. The cut review added owners for
the 2.5 rules, the D5 review questions, heavy-protocol ownership,
optional-dependency coverage, the unconditional release run of extended
parity, the closeout, and workstream gating in the YAML itself.

## Cut 2: Accounting-core consolidation (cut review pending)

The one workstream the accepted accounting-core synthesis
(`inst/design/rfc/rfc_accounting_core_consolidation_v0_2_0_2_synthesis.md`)
binds in its section 5, implementing directly without a further RFC. Source
table: `inst/design/audits/post_v0_2_0_1_accounting_core_inventory_sites.csv`,
twelve sites. Tickets LDG-2776 through LDG-2785. It opens after cut 1's
closeout, which is accepted, and after its own cut review.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 6 Accounting core | 2776–2785 | the flat per-instrument lot carrier with running net and the two per-fill scans removed; the D5 depth detector with its mutation proof; one preparer over the eleven shared event columns; one prepared-event replay with five drivers and two consumers redirected; removal of the superseded loops, the basis walk, the pack/unpack allocation, and the ignored fallthrough; FEE and dead-vocabulary cleanup; optional per-call overhead; claims registration; closeout | exact parity on every surface the synthesis's section 6 lists; block equality across sources; the D5 detector fails on a reintroduced scan; no cash or position write inside the lot kernel; the registry holds the new claims |

Ticket order follows synthesis section 5: kernel first (2776, with 2777
proving the detector on it), then preparer (2778) and replay (2779), then
removals (2780), cleanup (2781, 2782), the optional overhead ticket (2783),
registration (2784), and closeout (2785). The synthesis's step 6 also named
the roadmap correction of the eight-replay premise; that landed with the
RFC's acceptance at `688ae0b` and is not a ticket here.

Two reviews over ten tickets — the cut review and one Type 1 at close —
give 2 / 10 = 0.20 against the 0.5 gate. The workstream's review reason in
`tickets.yml` records that the maintainer may call one extra check after
LDG-2776, before the replay is built on the new carrier; that would be
3 / 10 = 0.30.

**Where the cut departs from the synthesis:** nowhere on substance. The
synthesis's six numbered steps became ten tickets because the D5 detector
(step 1), the preparer and the replay (step 2), and FEE and dead branches
(step 4) each carry a distinct acceptance criterion and a distinct
detecting witness.

**The cut review** asks, in order: does every requirement the synthesis
binds — sections 3.1 through 3.5, D1 through D6, and every bullet of
section 6 — have exactly one owning ticket (Type 1); and is one workstream
of ten tickets with a single close review the honest grain, or should the
carrier be reviewed before the replay is built on it (Type 2).

**Not in this cut:** no equity-settlement ticket; no C++ change beyond
removing the per-lot list allocation in pack/unpack; no runtime-default
decision; no compiled-execution RFC work. Nothing is edited before the cut
review is accepted.

## Pilot

Cut 1 was the pilot. `test_cleanup_closeout.md` records the counters: 11
reviews over 31 tickets, 0.35 against the 0.5 gate; correction rounds on
three of five workstreams; the runtime, rejected records, retained surface,
and disputed classifications. The maintainer's decision: promote for
v0.2.0.2, reassess before the next version. Cut 2 runs under the loop as
piloted, and its closeout adds its own counters to that record.
