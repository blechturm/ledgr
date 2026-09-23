# v0.2.0.2 Packet

**Status:** Four cuts. Cut 1, the test-suite cleanup, is closed: five
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
`8747c64` and was patched in place. Cuts are independent of one another;
workstreams are serial within a cut.

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
