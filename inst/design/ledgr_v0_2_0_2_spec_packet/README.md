# v0.2.0.2 Packet

**Status:** Eleven cuts: six closed, one folded, two open, and two awaiting
review acceptance. Cut 1, the
test-suite
cleanup, is closed: five
workstreams complete, eleven reviews over thirty-one tickets, and the
governance loop promoted for v0.2.0.2 with mandatory reassessment before the
next version inherits it. Cut 2's accounting-core workstream is closed at
accepted implementation commit `6d1b39b`; its record is
`accounting_core_closeout.md`. Cut 3, the ingestion
consolidation, is **accepted**: nine tickets over two workstreams, four
review invocations, 0.44 against the gate. One CSV ingestion surface,
DuckDB reads it, and three silent corruptions are fixed. Its second
workstream ran as a separate cut 5 and was folded back into cut 3 after its
re-review; see below. Cut 4 (exact-parity and workflow corrections) is
**accepted** after one corrective review round; its record is
`exact_parity_workflow_closeout.md`. The joint review
(`cut_review_3_4.md`) returned `PASS_AFTER_PATCHES` for both cuts at
`8747c64` and was patched in place. Cut 6, usable equity corporate actions,
is **accepted** under the synthesis accepted 2026-09-24: four serial
workstreams, eighteen completed tickets, and nine review invocations, exactly
0.500 against the gate. Cuts
are independent of one another; workstreams are serial within a cut.

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

## Cut 2: Accounting-core consolidation (closed)

The one workstream the accepted accounting-core synthesis
(`inst/design/rfc/rfc_accounting_core_consolidation_v0_2_0_2_synthesis.md`)
binds in its section 5, implementing directly without a further RFC. Source
table: `inst/design/audits/post_v0_2_0_1_accounting_core_inventory_sites.csv`,
eighteen sites after the 2026-09-22 correction at `b92a45c`. Tickets
LDG-2776 through LDG-2785. It opens after cut 1's
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

The gate is judged on completed tickets at close, not the planned count:
two reviews over ten if LDG-2783 lands (0.20), over nine if it is deferred
(0.22). The maintainer may call one optional check after LDG-2777, so the
carrier and its scaling detector are reviewed together before the preparer
and replay are built on them; that makes 0.30 or 0.33.

Implementation result: nine tickets are complete and optional LDG-2783 is
deferred. The flat carrier and consolidated replay pass 443 fast, 219 review,
and 192 heavy blocks. D5 is flat at the registered depths while its injected
rescan fails; the real 50,000-row fetch boundary is covered with 50,002 events.
The closeout records the small floating-order residual, the copy and compiled
transfer clocks, and the zero-FEE persisted-store census. Workstream 6 is
complete: its first close review found a fractional multi-lot reversal
defect, its first focused review found the matching compiled dust-scale
residual, and its second focused review found that the first dust witness was
not mutation-sensitive. Separate BUY and SELL witnesses now protect the two
compiled consumption sites, and their confirming re-review passed. Five reviews
occurred over nine completed tickets (`0.56`), above the `0.5` gate. The code is
accepted by independent review. On 2026-09-22 the maintainer accepted the
workstream and adjudicated the historical breach as warranted by the defects
those reviews found; the breach remains recorded and the threshold is unchanged.

**Where the cut departs from the synthesis:** nowhere on substance. The
synthesis's six numbered steps became ten tickets because the D5 detector
(step 1), the preparer and the replay (step 2), and FEE and dead branches
(step 4) each carry a distinct acceptance criterion and a distinct
detecting witness.

**What the cut review added.** Three bounded patches, applied in place:
LDG-2778 and LDG-2779 no longer claim deletions that LDG-2782 and LDG-2780
own, and LDG-2778 now rejects invalid quantity, price, fee, and opening
metadata, not only unknown types; LDG-2776 owns the no-persisted-change
prohibition, LDG-2784 owns the compiled boundary, and LDG-2785 states that
prototype multiples are not thresholds; LDG-2785 now depends on both
cleanup tickets and must name LDG-2783 as landed or deferred. Separately,
the inventory correction at `b92a45c` — six `ledger_events` readers the
lot-keyed search missed, three of them dead — widened LDG-2779 and
LDG-2780 after the review; their ownership map still holds.

**The cut review** asked, in order: does every requirement the synthesis
binds — sections 3.1 through 3.5, D1 through D6, and every bullet of
section 6 — have exactly one owning ticket (Type 1); and is one workstream
of ten tickets with a single close review the honest grain, or should the
carrier be reviewed before the replay is built on it (Type 2).

**Not in this cut:** no equity-settlement ticket; no C++ change beyond
removing the per-lot list allocation in pack/unpack; no runtime-default
decision; no compiled-execution RFC work. Nothing is edited before the cut
review is accepted.

## Cut 3: Ingestion consolidation (closed; close review passed after patches)

Authority: the maintainer's decision of 2026-09-22 that
`ledgr_snapshot_from_csv()` and `ledgr_snapshot_from_df()` are the ingestion
surface and the connection-first create/import/seal lifecycle from v0.1.1 is
removed (horizon, `[product] One CSV ingestion surface`), together with the
durable-path note's decisions 1 and 2 and the v0.2.0.1 inventory's OPT-L02
and OPT-L03. No RFC: the 2026-09-17 note reserved exactly this call for the
maintainer. Tickets LDG-2786 through LDG-2791, one workstream.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 7 Ingestion consolidation | 2786–2791 | migrate the strict importer's 27 test call sites; remove `ledgr_snapshot_import_bars_csv()`, `ledgr_snapshot_import_instruments_csv()` and five dead helpers; `from_csv` gains the file-side arguments (`instruments_csv_path`, `facts`, `invalid_observations`); exact-output timestamp handling in `from_df` with a seven-branch identity matrix and a pinned snapshot hash; the peer harness calls `from_csv`; closeout | the pinned hash did not move; every timestamp branch identical before and after; no contract case lost in migration; the harness record discloses its phase change |

Before-state, measured 2026-09-22 at the release shape (500 instruments by
1,260 sessions, 630,000 rows), `pkgload`, R 4.6.1:

| Path | Seconds |
| --- | ---: |
| `ledgr_snapshot_from_df()`, POSIXct input | 10.39 |
| `ledgr_snapshot_from_df()`, ISO-Z character input | 12.09 |
| `ledgr_snapshot_from_csv()` | 20.07 |
| `ledgr_snapshot_import_bars_csv()` (removed) | 13.01 |

Component clocks with an `identical()` alternative: line-104 format 4.32 s
to 0.03; ISO-Z round-trip format 3.23 s to 0; ISO-Z parse 2.02 s to 0.03;
scalar fallback 2.28 s per 20,000 rows. These are component clocks, not an
end-to-end forecast; the closeout records the after-state.

Ticket order: the widened `from_csv` first (2788) so the instruments-file
test has a public contract to land on, then test migration (2786), then
removal (2787), so every commit is green and no commit drops a capability;
the timestamp work (2789) is independent of the removal; the harness switch
(2790) follows it; closeout (2791). Two reviews over six tickets, 0.33.

**Both maintainer-amendable assumptions were taken as written:** straight
removal with no deprecation shim (LDG-2787), and `from_csv` gaining all three
pass-throughs (LDG-2788).

**Closed 2026-09-22** at `c43fe1a`. Closeout and clocks:
`ingestion_consolidation_closeout.md`. Migration detail and the twelve-item
mutation record: `ws7_migration_evidence.md`. At the release shape
`from_csv()` went from 20.07 s to 10.72 s and `from_df()` from 10.39 s to
7.17 s on POSIXct input, with the snapshot hash pinned unchanged as LCL-0015.
Three deliberate contract changes are listed in the closeout, the largest
being that `LEDGR_CSV_FORMAT_ERROR` no longer exists.

**What the cut review added.** Three bounded patches, applied in place.
C3-F1: the census is 27 calls, not 26, and LDG-2786 now lists the cases the
old files actually test; the strict no-Z rejection,
`auto_generate_instruments = FALSE`, and the CREATED/NOT_MUTABLE lifecycle
are named as removed or changed contracts with reasons, and any duplicate-key
or extra-column case is labelled newly added evidence. C3-F2: the order is
2788 then 2786 then 2787, and closeout depends on 2787. C3-F3: the fallback
case carries literal expected outputs rather than a reference call to the
shared scalar helper, and the invalid branch asserts its rejection class,
message, and order. The Type 2 question was answered: one workstream of six
with one close review is the honest grain.

**The cut review** asked, in order: does every contract case the removed
surface tested have either a kept-surface owner in LDG-2786 or a stated
reason for deletion (Type 1); is the hash pin plus seven-branch matrix an
adequate identity witness for LDG-2789, and what smallest change would it
miss (Type 1); and is one workstream of six tickets with one close review
the honest grain (Type 2).

**Not in this cut:** `colClasses` on the CSV reader (0.9 s; changes which
error fires first); hash chunk widening; raw-bytes hashing (own RFC); any
change to the seal, the schema, or snapshot identity.

## Cut 4: Exact-parity and workflow corrections (accepted after patches;
maintainer-amended before implementation)

Authority: horizon entries of 2026-09-18 (per-pulse context and feature
accessor costs; duplicated helper families; peer benchmark session
alignment defect) and 2026-09-19 (availability result reconstruction is
quadratic), OPT-L14, OPT-C03, the reviewed availability timestamp
prerequisite and sealing audit, and LFB-010 from the Sharadar workflow
evidence. Every site was re-verified in the tree on 2026-09-22. No RFC: each ticket
preserves outputs, errors, classes and messages exactly, or is a
public-boundary bug fix. Tickets LDG-2792 through LDG-2799 and LDG-2803,
one workstream.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 8 Exact-parity and workflow corrections | 2792–2799, 2803 | discarded identity work in the per-pulse path (alias-map accessor, `replicate`, `match.arg`); `features_wide` fill by index; a source guard keeping identity helpers out of the pulse loop; forward reconstruction of availability marks (OPT-L14, marks half); prepared availability-ingestion timestamps and session rows with one retained fail-closed facts assertion; zero opening cash rejected at construction (LFB-010); zipline alignment and a retention check; closeout. LDG-2795, the matrix-validator consolidation, is deferred to a maintenance cut | each parity witness fails on its smallest breaking change; the source guard fails on a reintroduced identity call; the availability oracle cases cover point-in-time, terminal-event, reopen and missing-evidence shapes; the ingestion witness detects rowwise parsing and a nested facts assertion; before and after clocks on the profiled sweep shape, the availability read and cold availability validation |

The alias-map item was 56.73 percent of the profiled sweep under the
`ctx$features(id)` idiom and none of the peer benchmark's, which reads
`ctx$features_wide`; the cut states that limit rather than claiming a peer
number. `ledgr_availability_positions_asof()` is excluded: it is inventory
site S15 and becomes a consumer of the accounting-core replay under
LDG-2779. Three review invocations over eight tickets, 0.375: the cut review,
the close review, and its focused re-review.

Workstream 8 has no dependency on workstream 7; staffing decides which
opens first. Its package work stays on measured ingestion, sweep, result and
validation boundaries; one ticket (zipline) corrects peer evidence this
packet already scheduled.

**Implementation state.** Workstream 8 and Cut 4 are accepted and closed.
The closeout records a 2.71x registered sweep improvement, a
68.1x full availability-marks read improvement, a 1.83x cold snapshot
improvement, and a sampled peer record with all 1,260 Zipline rows retained.
The Type 1 review required two record corrections, both passed focused
re-review, and the maintainer accepted the work on 2026-09-23.

**Post-review maintainer amendment.** On 2026-09-22 the maintainer added
LDG-2803 before implementation after reconciling the prior-cycle records with
the unchanged availability-ingest source. The historical timestamp
prerequisite remains `NEITHER`: its primitive session-close candidate missed
the registered speed gate. The new ticket instead retains the initial
fail-closed facts assertion, removes only a nested repeat, parses distinct
observation values under the existing scalar contract, and reuses prepared
timestamp tokens. The old probe measured observation normalization at 16.19
seconds current and 0.03 seconds candidate; a same-shape check measured the
redundant facts assertion at 5.83 seconds. Those are orientation for the new
paired record, not substituted release evidence.

**What the cut review added.** Four bounded patches, applied in place.
C4-F1: LDG-2792, LDG-2793 and LDG-2796 now name the smallest breaking
change per witness (alias normalization bypassed, a schema column altered,
a third `feature_table` value accepted; duplicate feature rows reproducing
last-write; a cutoff-boundary mutation). C4-F2: LDG-2797 is bound to
rejection, since no supported zero-cash opening exists and allowing zero
would widen the public domain. C4-F3: the return-panel validator's
candidate-id rule is recorded on LDG-2795 for whoever picks it up. C4-F4:
workstream 8's dependency on 7 is `null`, matching the independence the
packet claimed. Type 2: LDG-2795 is deferred as unmeasured code health;
LDG-2798 stays because it corrects peer evidence already scheduled here;
the workstream is renamed.

**The cut review** asks, in order: does each ticket name a parity witness
and the smallest change that breaks it (Type 1); is the marks-only scope of
LDG-2796 cleanly separable from the positions half owned by LDG-2779
(Type 1); and should the validator consolidation and the zipline chore be
in this workstream at all, or held for a maintenance cut (Type 2).

**Not in this cut:** the matrix-validator consolidation (LDG-2795,
deferred with its candidate-id note); the derived-context spike; the
feature accessor family; `list.files` in the worker-setup dry run until
confirmed on an installed package; the article's 0.99 weak-return
threshold; global fact-hash caching; and the failed primitive session-close
candidate by itself.

### Cut 3, workstream 9: Ingestion reader (was cut 5; closed after two FAIL reviews)

Authority: the maintainer's decision of 2026-09-22 that DuckDB reads the
ingestion CSV, recorded in the horizon as `[product] DuckDB reads the
ingestion CSV`, together with OPT-L03 and section 7 of cut 3's closeout.
Tickets LDG-2800 through LDG-2802, one workstream.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 9 Ingestion reader | 2800–2802 | register the reader's compatibility matrix as a test; read with `duckdb::read_csv_auto()`, forcing the identity columns to text so ledgr keeps owning instrument ids and every timestamp form; delete the numeric coercion it makes dead; closeout | exactly the matrix rows named in the closeout moved, and each has a reason; the pinned fixture hash is unchanged; a leading-zero instrument id survives to the sealed snapshot |

The reader went from 4.91 s to 0.26 s at the release shape and
`ledgr_snapshot_from_csv()` from 10.72 s to 7.23 s, so across cuts 3 and 5 it
went from 20.07 s to 7.23 s. The correctness fix is larger than speed: an
all-numeric leading-zero value in any persisted text column used to seal
without its zeros, silently, because R's CSV reader inferred a number.
Snapshots sealed from such a file before this cut carry wrong strings and a
hash computed from them.

**The compressed cut review was rejected.** `close_review_7_9.md` returned
FAIL for this workstream and declined the compression, on the ground that the
missing review was a question about the matrix's inputs that had to be asked
before the matrix could be treated as authority. Three of its four findings
are exactly what that question would have caught: the forced-text set covered
three columns where it needed seven, so `symbol`, `currency` and `asset_class`
also moved hashes; a literal `NA` changed from missing to text undeclared; and
the matrix asserted classes loosely. All are patched. Counting the owed cut
review, this cut stands at 2 over 3 tickets, **0.67, above the D8 gate**,
which is recorded in the closeout rather than argued away.

**Not in this cut:** letting DuckDB parse timestamps, which would hand the
accepted-form contract to a dependency; `utils::read.csv()` in the indicator
adapter, a different surface; reading bars straight into the snapshot database.

## Pilot

Cut 1 was the pilot. `test_cleanup_closeout.md` records the counters: 11
reviews over 31 tickets, 0.35 against the 0.5 gate; correction rounds on
three of five workstreams; the runtime, rejected records, retained surface,
and disputed classifications. The maintainer's decision: promote for
v0.2.0.2, reassess before the next version. Cut 2 runs under the loop as
piloted, and its closeout adds its own counters to that record.

## Cut 6: Usable equity corporate actions (closed)

Authority: `../rfc/rfc_equity_settlement_post_v0_2_0_2_synthesis.md`,
accepted 2026-09-24 after seven seeds, seven responses with two addenda,
three bounded spikes, one returned and one passed Type 1 final review, and
three rounds of external product review. Full RFC route: it adds a fact
family, a public policy object, a ledger event type and a headline result
field. The original cut contains LDG-2804 through LDG-2818. A maintainer
amendment adds LDG-2821 through LDG-2823, making eighteen active tickets in
four serial workstreams. Deferred LDG-2820 is not an active cut ticket.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 10 Boundary and sealed facts | 2804–2808 | compiled envelope refusal, first; the `equity_corporate_actions` family with tiered provenance and no guessed leg, excluded from availability activation; the fictional-adapter witness; declared price basis with double-counting refusal; closeout | the compiled arm refuses rather than drops; the constructor decodes no vendor; declaring the family alone compels no session calendar; the witness is executable |
| 11 Policy, fidelity and cash | 2809–2813 | `corporate_action_policy` with research and strict presets entering identity; `corporate_action_fidelity` and the ordinary summary; gross `CASHFLOW` with entitlement fixed before the ex-dividend boundary and credited at the ex-date close; the quick-path vignette; closeout | entitlement uses the entitlement clock and fails on the effective clock; cash is in state before valuation and context; late facts post at knowledge time and are counted; `not_supplied` is distinguishable from `none` |
| 14 Fact-family scaling | 2821–2823 | typed canonical fact preparation; set-wise persisted identity verification that retains the corruption guard; registered 20,000-row and 100,000-row clocks; closeout | all existing hashes, duplicate outcomes and tamper detection remain exact while constructor, seal and run-start row-wise encoding is removed |
| 12 Disposition, composition and gate | 2814–2818 | canonical-R `DISPOSITION` with lot consumption and the schema migration; the composition rule and four-quantity report; durable resume and reopen plus memory failure containment; the fourteen-case gate and the adapter article; cut closeout | zero position means zero live lots; the four-row witness reconciles numerically; durable and memory guarantees are asserted as different things; every gate case names its clause and its smallest breaking change |

All four workstreams are accepted. Workstream 11 passed focused Type 1
re-review at `af5bdc6` after one bounded correction round and was accepted by
the maintainer on 2026-09-24. The subsequent scaling finding inserts
Workstream 14 before Workstream 12. Its ticket review returned
`PASS_AFTER_PATCHES`; the maintainer accepted the patched amendment on
2026-09-24. LDG-2821 and LDG-2822 are implemented at `3d1ffbf` and `d93314e`;
LDG-2823 passed Type 1 close review with three record-only corrections and
Workstream 14 was accepted by the maintainer on 2026-09-25. Workstream 12
implemented LDG-2814 through LDG-2818 and passed independent Type 1 close
review at `3adb8bd`. Its three closeout-only corrections were applied under
the accepted ninth invocation, and the maintainer accepted Workstream 12 and
closed the cut on 2026-09-25. Workstream 13 is an independent Cut 7 chore, not
a prerequisite.
Deferred LDG-2820 records the review's resume-only metadata-parsing
optimization; it remains outside both the original and amended active-ticket
denominators.

The upstream private gate, the Sharadar producer specification and the
corrected census are external dependencies in `ledgr-research`; synthetic
work here does not wait for them and real-data integration cannot precede
an accepted upstream build. The cut review (`cut_review_6.md`) returned
`CHANGES_REQUIRED` at `8a1fb15` with five findings, all patched in place;
the grouping and review points passed unchanged. Six reviews were completed
against the original fifteen tickets. The amendment review and accepted
Workstream 14 close review brought the count to eight; the accepted Workstream
12 close review made nine over the amended eighteen active tickets, 0.500
against the 0.5 gate. Its three record corrections were applied under that
PASS rather than creating a tenth invocation.

The three-ticket split is technical rather than arithmetic padding: LDG-2821
owns in-memory R fact objects, LDG-2822 owns the typed DuckDB round trip and
persisted corruption guard, and LDG-2823 is the packet's standard closeout
unit. Without the closeout unit the projected gate would be 9/17 = 0.529,
which is why the boundary is stated explicitly rather than inferred.

**Pre-ticket note.** `schema_ceremony_note.md` records a measured finding
outside cut 6: every store open pays about 200 catalogue queries in
`ledgr_create_schema()` and `ledgr_validate_schema()`, a shape-5 antipattern
in production code that the test lanes exercise on nearly every block.
Gutting it saved 12 percent of the fast lane and 33 percent of review. It is
cut as LDG-2819 in cut 7, workstream 13, which opens after workstream 10 is
accepted.

`fact_family_scaling_note.md` records the second measured maintenance
finding. At 100,000 complete corporate-action facts, construction took 97.9
seconds, sealing 112.9 seconds and a public run 18.3 seconds against a
1.26-second no-fact control. Workstream 14 owns exact hash and corruption
parity plus the scale correction; it is an output-preserving amendment only
while those identities remain byte-identical. The accepted closeout's
three-run medians are 95.93 to 9.08 seconds for construction, 110.44 to 7.40
for sealing, and 17.18 to 3.26 seconds for fact-attributable public-run
overhead. All registered ceilings passed, and the maintainer accepted
Workstream 14 before Workstream 12 opened.

## Cut 7: Maintenance, schema ceremony (closed)

Authority: `schema_ceremony_note.md` and the review obligations as amended
2026-09-24. No RFC: one healthy-store exact-parity chore on
`ledgr_create_schema()` and `ledgr_validate_schema()`. A current-marker store
missing a create-owned table now fails closed instead of silently recreating
an empty table. One ticket, LDG-2819, one workstream; the cut review is
compressed into the close review. LDG-2795 is the standing candidate to join.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 13 Schema ceremony | 2819 | one catalogue read per call compared in memory; a version-marker fast path for create on reopen only; a DBI-count detector; interleaved clocks on run open, db_init, fast and review lanes | the detector fails on a reintroduced per-table query; the five gut-failure blocks pass; the fast path is keyed on the exact stored version; healthy-store outputs are identical and current-marker damage fails closed |

Implementation and closeout are accepted. The unmatched fast
profile medians are not used as an effect estimate; the matched quiet-end pair
improved from 87.82 to 70.77 seconds, and the ordinary gate passed at 75.73
seconds against the 90-second bound. The initial Type 1 close review required
four bounded corrections; focused re-review returned PASS. The maintainer
accepted the honest historical exception of two review invocations over one
ticket, 2.0, rather than padding the cut with unrelated work.

## Cut 8: Release gate (open; opens after workstream 18)

Authority: `../release_ci_playbook.md`, in particular its Release-Gate Ticket
Requirements and What Counts as Green sections, and its CI Tiers section added
2026-09-25 when `R-CMD-check.yaml` was tiered. No RFC: the playbook already
binds the process and requires that every release-gate ticket name it and the
exact local gates. Two tickets, LDG-2824 and LDG-2825, one workstream; the cut
review is compressed into the close review, so one invocation over two tickets
is 0.500.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 15 Release gate | 2824–2825 | release identity promoted from v0.2.0.2 to v0.2.1.0; `NEWS.md` rewritten for the whole version in user terms with the release's non-claims stated; the playbook's local gates run and recorded; the full tier dispatched on the renamed release branch before the merge; main, pkgdown and tag runs as three separate evidences; the GitHub Release entry | package metadata, branch, active governance pointers and tag agree on v0.2.1.0 before gates run; every named gate was run and recorded rather than asserted; the three CI evidences are distinct run ids; a quick-tier branch run is never cited as the merge gate; skipped gates carry accepted reasons; the notes state what the version does not claim |

The maintainer promoted the release target to v0.2.1.0 on 2026-09-25 because
the accumulated public capability and architecture changes are no longer
patch-sized. The `v0_2_0_2` packet path and historical RFC, audit, spike and
ticket names remain unchanged; LDG-2824 records the promotion and updates only
active release identity. The two tickets are not a split for the ratio.
`NEWS.md` is wrong in the tree today and would need writing even if the release
slipped; the gate execution is separate work with its own evidence. A
correction round would make the cut 2 over 2, 1.00, and is to be recorded rather
than hidden, as cut 7 recorded its own. This workstream ships no production
code, so the amended obligations' seven-shape walk and before-and-after clock
do not apply to its review.

## Cut 9: Availability and evidence accessors (accepted)

Authority: `../horizon.md`, the 2026-09-25 `[ux]` entry,
`../vignette_styleguide.md` section 5, which routes visual clutter in a worked
example to an API gap rather than to boilerplate in the article, and the
accepted Workstream 12 close review's corrected result-boundary observation.
No RFC: additive or simplified readers over evidence the engine already
produces. Tickets LDG-2826 through LDG-2832 and LDG-2844, one workstream; the
cut review is compressed into the close review, so one invocation over eight
tickets is 0.125.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 16 Availability and evidence accessors | 2826–2832, 2844 | `ctx$tradable()` beside `ctx$flat()` and `ctx$hold()`; a reader for quarantined observations; `ledgr_run_explain()` over a whole instrument history; one completion answer per run; removal of the unreachable scalar fallbacks; a warning when a strategy loops a scalar accessor over the universe; one-pass preparation for the corporate-action composition report; closeout | each accessor agrees with or reuses the state the engine already computed rather than recomputing it; an empty axis needs no special case; the composition report decodes selected persisted events at most once and aggregates source facts in one grouped pass; no contract, schema, hash or error class moves; the missing-data article loses the clutter that motivated the cut |

The trigger was writing `missing-data-and-sessions.qmd`. Its strategy needed
four lines to answer "which instruments may I size now", it read quarantined
rows with raw SQL, it asked `ledgr_run_explain()` about one timestamp at a
time, and it printed three completion fields in sequence. Each of those is the
API asking for a reader. Workstream 15, the release gate, now runs after this
workstream so the release ships the articles on the accessors rather than on
the workaround.

A measured scan of the strategy helpers on 2026-09-25 added the last two
tickets. The helper layer itself is 1.3 to 2.8 percent of a run and its share
falls as the universe grows, so there is nothing to optimize there. The cost
that matters is the accessor a strategy author reaches for: at two thousand
instruments, looping a scalar accessor over the universe adds tens of
milliseconds per pulse against effectively nothing for the vector plane, and
nothing warns.

The accepted Workstream 12 review later traced a separate result-reader cost.
`ledgr_corporate_action_composition_report()` decodes an unfiltered ledger
twice and then scans the decoded source ids once per selected fact. At 100,000
events the duplicate parses cost about 0.7 seconds per report; at 300,000 they
cost about 2.4 seconds. LDG-2844 prepares that evidence once and groups the
source attribution. It is in this workstream because the shared claim is the
result boundary: expose or reuse evidence already computed without changing
its meaning. The older LDG-2820 remains a separate deferred resume-path
optimization.

## Cut 10: Indicator source parity and timing attribution (close review pending)

Authority: the maintainer's 2026-09-25 decision that indicator source is not
a semantic axis for missing observations or session calendars, together with
the Availability Contract in `../contracts.md` and the first-party indicator
investigation already registered in `../horizon.md`. Six tickets,
LDG-2833 through LDG-2838, one workstream. The cut receives an independent
Type 1 and Type 2 ticket-cut review before any measurement or implementation,
then one Type 1 close review. Two planned invocations over six tickets is
0.333 against the 0.5 gate; one correction round would make it exactly 0.500.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 17 Indicator source parity and timing attribution | 2833–2838 | order-controlled attribution of the recorded TTR/built-in gap; strict-window propagation through direct, sweep, resume and cache paths; public TTR SMA certification; isolated-process peer boundary; missing-data and indicator documentation; closeout | implementation source does not alter expected sessions, gap NA positions, warmup or recovery, and no TTR performance difference is claimed until fresh-process, order-balanced evidence localizes it |

The measurement is deliberately first. The current record's durable TTR row
is 61.54 seconds against 51.97 for built-in SMA, with 8.71 of the 9.57-second
difference inside `ledgr_run()`. That record cannot attribute the difference:
the TTR row always ran first, earlier releases changed the sign, and the
horizon's 1,000-call primitive comparison explained about 0.04 seconds. The
registered probe compares three arms: native built-in SMA, the private
benchmark wrapper, and public TTR SMA. It runs all six arm-order permutations
in fresh child processes over copied stores with one snapshot identity, so
every arm occupies the first, second, and third position twice. Position cells
remain separate. A pairwise structural finding must keep its direction in all
three positions, exceed one second and five percent, exceed the largest
within-position spread, and be localized. Otherwise no production optimization
is authorized.

The semantic correction is independent of that timing outcome, but is
sequenced after the measurement so it cannot contaminate the baseline. A direct
availability-aware run with `ledgr_ind_sma(2)` currently succeeds while a
one-candidate sweep fails because the precompute conversion drops
`gap_contract`. The workstream fixes that representation loss and proves one
expected-session matrix across direct run, sequential and parallel sweep,
resume and cache. Public `ledgr_ind_ttr("SMA")` becomes the external
strict-window certification case only for the exact post-resolution predicate
in LDG-2835. The output-bundle constructor, EMA, RSI, and all other recursive
or unassessed TTR families remain unsupported in availability mode; similar
names do not establish equivalent mathematics. The same ticket updates the
Availability Contract and checks it against the executable support matrix.

After the semantic work, all six published rows currently fed by the shared
private TTR wrapper must call the public adapter. The public TTR and built-in
rows run in isolated R processes, and cold results are compared only with the
attribution probe's first-position cells. The record and ggplot report are
regenerated, and any change is described as a boundary correction rather than
a package speedup. The missing-data article then documents dense implicit
calendars, declared expected sessions, strict-window contamination and
recovery, late listings, stale valuation separation, and the executable
support matrix. Workstream 17 follows Workstream 16 so both edits to that
article are serial; Workstream 18 follows Workstream 17 for the same reason,
and the release gate follows Workstream 18.

Workstream 17 is implemented through `001ece3`. Its agent-provisional record is
`indicator_source_parity_closeout.md`. The six-permutation attribution found
the historical 9.57-second gap order-confounded and authorized no source-path
optimization. The corrected peer record uses only public indicator
constructors, and the source and rendered articles publish the executable
expected-session and support matrices. The exact LDG-2837 fast record passed
453 of 453 blocks in 76.50 seconds against the unchanged 90-second gate.
Independent Type 1 close review is pending.

## Cut 11: Point-in-time input model (awaiting focused cut re-review; opens
after workstream 17)

Authority: the maintainer's 2026-09-25 decision that the point-in-time input
model needs one checklist of required data and one inspectable demo input set,
with `../vignette_styleguide.md` sections 5, 7 and 12 and the fact-family
constructor contracts in `../contracts.md`. Five tickets, LDG-2839 through
LDG-2843, one workstream. An inline Type 2 cut review returned
`CHANGES_REQUIRED`: a fact-only generator could not own observation gaps or
compose directly with the existing midnight-UTC demo bars, the knowledge rule
was false for late-known facts, and the proposed checklist detector was
circular. The tickets were patched in place and await focused re-review.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 18 Point-in-time input model | 2839–2843 | an exported `ledgr_sim_pit_inputs()` parametrized by instruments, window, seed, calendar convention and teaching cases; one committed plain-data bundle containing matching bars, fact inputs, construction recipe and case manifest; the input checklist and an entity diagram in the data-input article; the specialist articles connected to the shared bundle without sacrificing minimal teaching fixtures; closeout | a user can learn what data ledgr needs, in what form, from one place, can load a working composable example, and can generate one for their own instruments and window; the generator declares a session calendar independently of observations and derives matching bars from that declaration |

The gap this closes is visible in the tree. ledgr ships exactly one dataset,
`ledgr_demo_bars`: ten instruments of OHLCV and nothing else. Every article
that teaches the point-in-time model therefore hand-builds its own fact
fixture on its own universe and its own dates, and a reader has nothing to
load and inspect. `data-input-and-snapshots.qmd`, the canonical article for
what data goes in, has no facts section at all. The required columns live only
in the `ledgr_facts_*` constructor Details, which is the right home for the
contract but leaves someone assembling their own data with no view of the
whole input set, what is optional, or what each part unlocks.

The generator follows the shape ledgr already uses for demo market data while
closing a composability gap in that precedent. `ledgr_sim_pit_inputs()` takes
explicit instrument identifiers, a window and an explicit synthetic calendar
convention; it does not take bars. It returns one ordinary named list with
matching bars, optional instrument metadata, the five constructor-input fact
frames, the explicit scope and knowledge recipe, and a plain case manifest.
This is necessary because a missing observation is a property of bars, not a
fact row, and the existing `ledgr_demo_bars` contains every generated weekday
at midnight UTC. One rule is load-bearing: the generator declares the session
calendar before it creates observations and never infers that calendar from
them, because an open session on which the whole universe is missing is
invisible to an observation-derived calendar.

The committed artifact is one `ledgr_demo_pit_inputs` bundle from a recorded
seeded call. Its bars and facts compose without undocumented filtering or time
rewriting. A shorter teaching window is acceptable only because its matching
bars travel with it; it is not presented as a fact set that users can attach
directly to an arbitrary slice of `ledgr_demo_bars`.

The entity diagram is included because two facts cannot be shown by a column
table: the families have different scope keys, instrument against venue
against universe, and a corporate action references a parent and an optional
recipient that must both resolve in the snapshot's physical instrument master.
That is deliberately not the same claim as membership in a universe.

This cut ships inside v0.2.0.2. The point-in-time model is what this release
adds, and shipping it without one checklist of required inputs and one
inspectable example would leave users to reverse-engineer the model from three
worked examples. Workstream 18 opens after Workstream 17, so the three edits to
the missing-data article stay serial: Workstream 16 puts it on `ctx$tradable()`,
Workstream 17 adds the expected-session and support-matrix material, and
Workstream 18 links it to the shared demo input. Specialist articles may retain
deliberately small local fixtures where those are the clearest behavioral
detectors; each must state why and link to the canonical input article. The
release gate follows, so its local gates and CI tiers cover the shipped bundle
and rendered articles.

The Type 2 cut review plus the planned close review is two invocations over
five completed tickets, 0.400. A focused correction re-review followed by the
close review would make the historical count three over five, 0.600. If that
route is taken, the closeout records the breach honestly rather than merging or
padding tickets to hide it.

## Cut 12: Restore fast-profile headroom (accepted)

Authority: the accepted testing-architecture synthesis and the maintainer's
2026-09-25 decision to recover the fast lane without weakening its 90-second
gate or hiding unrelated test work inside Cut 9. Five tickets, LDG-2845 through
LDG-2849, one test-only workstream. The independent Type 1 then Type 2 review
returned `PASS_AFTER_PATCHES`; its six ticket-text corrections are applied, and
the maintainer accepted the cut.

| Workstream | Tickets | Content | Review claim |
| --- | --- | --- | --- |
| 19 Fast-profile headroom | 2845-2849 | claim-based routing of three rare recovery integrations; scalar-warning evidence split by feedback value; fixture shrinking for expensive core fast gates; exact ordinary and CRAN-mode censuses, mutations, clocks and closeout | fast retains legacy migration plus the smallest failure-sensitive evidence needed on ordinary changes, every moved guarantee runs nightly and at release, core parity and corruption guards remain fast, and measured headroom is recovered without changing production code or either time bound |

The triggering record is not a correctness failure. At `c83e4dc`, all 456
fast blocks pass, but the exact post-correction profile records 102.94, 103.81
and 104.02 seconds, median 103.81. An earlier run of the reviewed tree took
83.61 seconds and the independent reviewer reproduced 86.36, so cross-session
clocks cannot identify one regression. The per-block census does identify the
work: the scalar-warning block is about seven seconds; two rare walk-forward
failure integrations total about six; compiled parity and rule-2 scaling total
about eight and must stay fast but may have smaller fixtures. Legacy metadata
migration stays fast because current-schema evidence cannot replace its upgrade
guarantee.

The cut therefore uses two different tools deliberately. The two rare recovery
integrations move only when the nightly and release review lane demonstrably
executes them with the same mutations. High-feedback core and migration claims
stay fast and lose setup rather than evidence. The scalar-warning claim is
split: ordinary development keeps the warning and false-positive detectors,
while review keeps the full durable non-interference comparison. Slowness alone
authorizes no deletion.

The named savings may land close to, rather than below, the ordinary bound.
LDG-2848 therefore owns both the 90-second ordinary and 105-second isolated
CRAN-mode gates. An ordinary median from 90 through 95 seconds is a stop for an
explicit maintainer decision on a bounded second pass or deferral, never an
excuse to raise the bound or route more tests post hoc. The 75-to-80-second
figure remains a non-binding engineering target.

The first post-implementation CRAN record exposed a separate test-lifecycle
instability: three isolated runs took 108.56, 107.61 and 107.68 seconds, with
about 29 seconds charged to the low-level state-reconstruction integration.
The same block took 0.32 seconds alone and 0.24 seconds when instrumentation
perturbed collector timing. Explicit connection-and-driver cleanup did not
stabilize it and was rejected. The maintainer authorized LDG-2849 as a bounded
second pass; the recovery integration remains executable nightly and at
release, while the failed record remains part of the closeout.

The accepted bounded pass routes only that low-level recovery integration.
Final ordinary runs were 79.46, 79.72 and 79.23 seconds; final isolated
CRAN-mode runs were 78.94, 79.44 and 79.42 seconds. Both independent gate
checkers passed their one-run rule without changing either bound. The review
profile still executed all 270 selected blocks, including the moved recovery
claim.

One cut review and one close review over five real units is 2/5, 0.400. The
workstream opens from completed Workstream 12 and must close before Workstream
16 returns for focused correction review; Workstream 17 remains downstream of
Workstream 16.
