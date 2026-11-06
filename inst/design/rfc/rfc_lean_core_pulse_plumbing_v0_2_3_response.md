# Lean Core Pulse Plumbing: Type 2 Response

REVISE

The direction is useful, but seed v1 does not yet establish preservation of every current refusal.
It errs both ways: checked inputs do not establish all properties of newly derived outputs, while moving every publication-only check into the append validator would preserve avoidable work.
Reserved writes can preserve the contracts, but their failure timing, visibility and live-sink rules need substantive decisions before acceptance.

Mode: Type 2, RFC response, Codex, 2026-11-06; maintainer-approved brief, drafted by Claude.
Reviewed head: `13ee8d30f64bde2098292b879cc5b1166c2abbbc`; recommendations are non-binding.
Evidence used: source inspection, all seven spike evidence CSVs, and small R probes described below; nothing else.
Git inspection confirmed no `R/` difference from `d5b3a151` and resolved spike commit `d8aeb04c`.
No timing rerun, full test suite, package check, worker run or durable/live execution was performed.
Probes used R 4.6.1 and `pkgload::load_all(..., compile = FALSE, quiet = TRUE)`; locale/DLL-registration warnings were emitted, but the pure-R probes completed. Native behavior is unverified.

Citation aliases (repository-relative unless absolute; `alias:line` addresses the reviewed source):

- **S**: `inst/design/rfc/rfc_lean_core_pulse_plumbing_v0_2_3_seed.md`.
- **K**: `inst/design/rfc/rfc_lean_core_skeleton_v0_2_3_synthesis.md`.
- **L**: `inst/design/rfc/rfc_lean_fold_core_v0_2_3_synthesis.md`.
- **T**: `inst/design/rfc/rfc_typed_fold_carrier_v0_2_3_synthesis.md`.
- **A**: `inst/design/rfc/rfc_typed_accounting_event_boundary_v0_2_3_synthesis.md`.
- **C**: `inst/design/contracts.md`; stable rule groups are linked where used.
- **Style**: `inst/design/manual/optimization_coding_style.qmd`.
- **F**, **E**, **H**, **B**, **V**, **D**: respectively `R/fold-carrier.R`, `R/fold-engine.R`, `R/output-handler.R`, `R/backtest-runner.R`, `R/accounting-replay.R`, `R/availability-diagnostic-writer.R`.
- **SP**: `dev/spikes/fold_plumbing/`; **EV**: its `evidence/` directory.
- **P**: `C:/Users/maxth/ledgr-wt/pulse-plumbing-probes/pulse_plumbing_review.R`; **PO**: the adjacent `pulse_plumbing_review.out`.

1. **A construction proof must establish the output property; checked inputs alone do not.**

   Claim: S:75-82 and S:138-145 grant trust to any group core code builds from checked inputs, including an earlier stage's output.
   Evidence: K:136-141 explicitly retains checks for new alignment/transformation, applied rows and dynamic overflow; L:78-80 and L:116-120 agree.
   Finite inputs can yield an infinite difference/product, an invalid integer counter, or a failed mapping. Earlier-stage provenance establishes none of those new properties.
   Conversely, a literal field set, `which()` over a checked mask, or `priced <- is.finite(mark)` need not be scanned again merely to test their defining expression.
   Style:184-201 and Style:481-494 require the dependency and transformation to be named, rather than caller-asserted trust.

   Consequence: the generic rule can remove a necessary dynamic guard; treating every derived property as untrusted would instead retain the measured overhead.
   Recommendation: replace it with a per-property rule: omit a check only when an identified checked boundary plus the actual construction operation establishes it for all admitted inputs, including empty, missing and overflow cases.
   Keep only the residual new-property checks at their introducing boundary, with existing refusal classes and precedence.
   The interface table should name the establishing operation and inherited preconditions as well as the validator; its unavailable draft is unverified here.
   Preserve the import/cached-total limits in [Typed Fold Carrier](../contracts.md#contract-execution-fold-carrier) (C:331-342); do not add stronger recomputation checks.
   E also validates state after installing a stop (C:167-176,237-240); the seed's once-per-fold shorthand must not remove that boundary.

2. **The check census needs a property-level split, including missingness and derived values.**

   Claim: "structural" is not a sufficient classification. Below, **runtime** means a condition can fail on new data or untrusted input; **construction** means it follows from the cited construction after its preconditions hold, so violation then requires a core defect.
   A bad import/callback can violate shape too: these labels describe the trusted production path, not arbitrary calls to `ledgr_carrier_problem()`.
   At an untrusted introducing boundary, keep its complete required validation.

   The common checks are exact list field names/order; plain declared storage with no object/attributes; scalar/context/run/row/segment lengths; declared NA/NaN policy; and infinity refusal for doubles except `inf`/`any` fields (F:207-254).
   For diagnostics, `n` must first be a plain nonnegative scalar integer within the allocated row length, and value checks use only that prefix (F:220-229).
   Fixed schema/storage and lengths produced by valid indexed construction are construction properties. Missingness/finiteness of new arithmetic, callback values and unresolved mappings need runtime proof; they are not automatically schema properties.

   | Per-pulse group; complete group-specific conditions | Runtime/data or untrusted origin | Construction after the boundary |
   | --- | --- | --- |
   | Decision packet (F:46-65,257-282): pulse >=1; unique in-range context positions; buyable implies member; nonnegative contiguous restriction counts/offsets; restricted iff count >0; restriction/status/lifetime/mark-source dictionary bounds; nonnegative present age; priced iff finite mark | Cash/positions after settlement; present mark/reference/source-time finiteness; age arithmetic/conversion; failed provider vocabulary/axis mapping unless preparation has established it. `positions_value` permits Inf/arithmetic NaN but refuses ordinary NA. | E's loop supplies pulse/time; checked context selection supplies positions; `member & !restricted` implies member; segment constructor supplies offsets/counts; dictionary membership follows checked code selection; `priced` can be derived directly from the same marks. Today's adapter copies provider `priced` (F:549-587), so that relationship is not established merely by entering the adapter. |
   | Decision data (F:66-72,284-287): unique in-range source rows; source column >=1 | Bar missingness/finiteness and observed flags can be trusted only after prepared data validation; a new gather needs established valid indexes. New locators are not proved by sealing bars. | Checked gather and prepared pulse map establish lengths, row bounds/uniqueness and positive column. `history` is opaque: this checker does not verify cutoff/no-lookahead or column upper bound (E:599-612). |
   | Execution packet (F:73-77,289-294): no OHLCV values when `has_next` is false | Present OHLCV and epoch finiteness unless prepared; missing execution opportunity is legitimate. Actual price/epoch admissibility is checked when a fill needs it. | Prepared next-bar gather supplies the run axis; absent branch explicitly creates all-NA vectors (E:613-628). This checker does not enforce `has_next`/epoch equivalence, whole seconds or positive OHLCV. |
   | Decision (F:78-83,296-307): unique in-range context positions; actionable ordinals in range and strictly ordered; intent NULL or one nonempty nonmissing character string | Full strategy target shape/finiteness, intent, transformed target properties and risk/admissibility belong at the callback/risk boundaries (E:844-891,967-1022). `state_update` is opaque and remains validated at P5. | Copying checked context positions and targets, then `which(abs(target-position)>sqrt(eps))`, establishes carrier ordering/range (E:1068-1075). It does not prove a finite subtraction: the planner retains its delta check. Rechecking already validated intent/targets here adds no guarantee. |
   | Plan (F:108-113,362-383): expected cash not NaN/-Inf; distinct valid economic-kind codes; recursively checked fills/rejections; no kinds on an empty plan; FILL iff fills exist; exact partition of actionable ordinals | Expected cash comes from a dynamic ordered affordability scan. Keep its admitted values, event-kind support gate and both cash reconciliations. | Kinds selected from literals and complementary, ordered row masks can establish the partition/declaration invariants. An arbitrary supplied plan cannot inherit that proof. Scheduled skip's literal empty groups and cash copy need no repeated full-plan scan (E:704-720). |
   | Fill (F:91-99,317-334,460-483): distinct in-range k; pos=context_pos[k] within run; decision order; side +/-1; qty/price >0 and fee >=0; NaN cash only with nonfinite fee; signed position delta; planned after=before+delta; contiguous, dictionary-bounded, deduplicated info segments | Resolved qty/price/fee, cash-effect arithmetic and planned-position arithmetic can overflow or be invalid. `fee`/`cash_delta` admit Inf and arithmetic NaN, never ordinary NA; other doubles here must be finite. Do not move the later accounting refusal earlier by strengthening P3. | Ordered gathers from a checked decision establish k/pos/order; side and signed delta follow the defining expressions; planned-after identity is definitional, its finiteness is not. Segment helpers establish offsets/order/deduplication given valid row/code inputs. |
   | Rejection (F:100-107,336-360,460-483): distinct valid k/pos; emit 1 before 2, each in decision order; contiguous/deduplicated dictionary reasons; at least one reason, primary first; price NA iff early; epoch NA iff primary is final-pulse; positive resolved price | Resolved price/epoch/position finiteness and positive resolved price require a proof at resolution or selection. Incorrect external execution-view codes/flags require validation before use. | Complementary early/late masks, literal phases, first-reason extraction and explicit NA assignment establish order, reason presence/primary and phase missingness when their predicates are correct (F:709-730; R/availability-economics.R:391-461). |
   | Publication (F:117-133,385-421): WROTE iff nonempty; positive contiguous event sequences, matching next; ID=run/formatted sequence; FILL only; nonempty instrument; BUY/SELL; qty/price >0, fee >=0; signed delta; every evidence field missing | Sequence arithmetic can overflow; identities may be untrusted at another entry; qty/price/fee/effects and execution time retain their introducing guards. See finding 3 for what append does and misses. | Literal status/type, generated IDs/sequences after checked bounds, side mapping, checked ID gather, and typed-NA defaults establish the rest. Neither status nor next sequence is stored in ledger rows. |
   | Diagnostic staging (F:146-166,437-441): used count within rows; capacity equals row length; present age >=0 and event sequence >=1 | New diagnostic numerics/times must obey the declared finiteness/missingness; new age/sequence arithmetic can overflow; capacity exhaustion is runtime. Segment field length/coercion checks occur before these checks (F:821-847). | E allocation, indexed writes, defaults and count updates establish storage, lengths and prefix shape if the write boundary is correct. Logical offsets/`logical_n` semantics are contracted but not checked for uniqueness/range here: do not claim this checker proves them. |

   P3's internal execution view is another current per-pulse checked group, omitted by the skeleton: contiguous/deduplicated valid reason segments and `restricted == (reason_count>0)` (F:86-90,309-315,622-650).
   Its checked provider boundary must survive too. Leg construction also checks order/tokens/ranges/OPEN P&L (F:423-435; H:44-70), although the spike omits legs.
   Consequence: removing the common field loop wholesale can remove data checks along with redundant shape checks.
   Recommendation: use this census to populate the real interface table; identify where each runtime residual already runs before adding another scan.
   The governing groups are [Typed Fold Carrier](../contracts.md#contract-execution-fold-carrier) and [Fold Core And Output Handlers](../contracts.md#contract-execution-fold-core).

3. **Publication validation and accounting append overlap, but neither subsumes the other.**

   Claim: S:113-114 and Q3 require every publication-only condition to move into append or remain runtime. That is too broad and conflicts with S:92-93's "unchanged".
   Evidence: append delegates to the accounting preparer (V:88-98); the following compares its actual checks with F:207-254,385-421.

   | Fields/property | Publication group | Append/preparer |
   | --- | --- | --- |
   | Schema, lengths, storage | Exact ordered plain list, declared bare types, every axis | Required/unknown names and equal column lengths; accepts frames and coercible storage; does not require exact order/plain vectors (V:104-132). Empty blocks return before value checks. |
   | `status`, `next_event_seq` | Checks row-dependent status and positive next; for nonempty blocks next=last+1 | Neither field is supplied; supplying it would be an unknown-column error. |
   | `event_seq` | Plain integer, first >=1, contiguous within block | Coerces numeric, integral within integer range, strictly increasing within/across blocks. Allows gaps and nonpositive values absent a conflicting prior boundary (V:135-146). |
   | `event_id`, `run_id` | Nonmissing character; exact formatted relationship | Both must be nonempty; no ID-format or ID-uniqueness proof, and no single-run/handler-run equality check (V:158-169). Publication itself also does not independently require nonempty run_id. |
   | `ts_utc` | Bare finite, nonmissing double | POSIXct coercion, no NA, nondecreasing within/across blocks (V:148-156); no explicit infinity or whole-second check. Whole seconds are separately guarded by B:114-118. |
   | `event_type`, `instrument_id`, `side` | FILL only; nonempty instrument; exact uppercase BUY/SELL | Multiple supported kinds; nonempty instrument; side is uppercased before validation (V:158-201). |
   | `qty`, `price`, `fee` | Finite bare doubles, qty/price positive, fee nonnegative | Coerced doubles with the same FILL value ranges; finite fee for every kind. |
   | `cash_delta` | Allows Inf/arithmetic NaN, not ordinary NA; no formula check | Finite and nonmissing; exact side/qty/price/fee formula (V:170-225). |
   | `position_delta` | Finite; exact signed quantity | Finite; exact signed quantity, alongside cash reconciliation. |
   | `source`, `source_fact_id` | Missing on fills | Same FILL prohibition; other kinds have required source/evidence rules. |
   | `entitled_quantity`, `gross_cash_per_parent_unit`, `amount_policy_id`, `posting_policy_id`, `late_arrival` | Missing on fills | Same prohibition via `cash_only` (V:298-317). |
   | `affected_marked_exposure`, `terminal_event`, `matched_label`, `haircut_fraction` | Missing on fills | Same prohibition via affected/lifetime groups. |
   | `disposition_policy_id`, `disposition_choice`, `disposition_basis`, `mark_source`, `mark_source_ts_utc`, `position_before`, `realized_model_pnl` | Missing on fills | Same prohibition via disposition group. |
   | `mark_age` | Missing on fills, with integer storage | **Gap:** validates only disposition rows, replaces every other row with NA, then checks forbidden evidence using that replacement (V:259-274,300-317). A supplied fill age disappears. |

   P/PO:16-35 reproduce sequence gaps, arbitrary IDs, invalid next/status, fill age, lowercase side, nonpositive sequence and infinite-time acceptance at append versus publication refusal; wrong cash shows the reverse.
   These are direct internal-boundary probes, not claims that ordinary public runs currently generate such rows.
   Consequence: removing publication validation without assigning the residuals loses coverage; adding all residuals to the general preparer repeats construction checks and changes its accepted multi-kind/read input contract.
   Recommendation: derive status/next from count and checked counter arithmetic; generate IDs once; prove literal tokens/defaults at the fill writer. Keep dynamic sequence bounds and any unproved mapping checks at their introducing boundary.
   Preserve append/read economic and cross-block checks under [Cost Resolution And Accounting Events](../contracts.md#contract-execution-accounting-events) and A:145-163,340.
   Record the existing fill-`mark_age` gap explicitly. Either preserve its exclusion by the trusted typed-NA writer or separately authorize a shared-validator correction; do not assume current append already enforces it.
   Preserve existing condition selection: a publication failure currently raises `ledgr_internal_error`; append raises `ledgr_invalid_accounting_event` (often also `ledgr_invalid_ledger_meta`). Moving a runtime refusal between them is observable.

4. **Reserve/write/validate/commit is viable, but "unchanged failure prefix" is not yet specified.**

   Claim: S:106-114 and S:149-152 assert preservation without defining reservations, failure cleanup or sink-specific visibility.
   Evidence: [Fold Core And Output Handlers](../contracts.md#contract-execution-fold-core) (C:205-219), T:194-211 and K:300-307 distinguish calculation failure from later handler failure; they promise no blanket private-state rollback.
   Current behavior and the decisions seed v2 must bind are:

   | Path | Current behavior / required reservation rule |
   | --- | --- |
   | Candidate lot failure at row j | E:1454-1468 validates earlier publications with `stage=FALSE`, then signals the lot error. No staging, event-sequence or handler-append-boundary advancement, or output-buffer mutation. P/PO:36-37 demonstrate an earlier append refusal winning over a later invalid fee with book/sequence unchanged and zero visible events. Define an equivalent nonpublishing check path; reserve must not mutate handler output on this path. |
   | Successful candidate, append failure | Book and position facts are already installed; publication validation precedes sequence advancement, legs, positions and cash (E:1476-1506). Failed reservation must not advance committed count or successful append-boundary metadata. Discard the failed memory candidate; durable invocation rolls back. Do not add a promise to restore the installed private book. |
   | Capacity refusal | Today capacity is checked while copying at P5 (H:571-585), after P4 append validation, sequence, legs, cash and positions. P/PO:38-40 publish two rows into a one-row maximum successfully at P4, then receive `ledgr_event_buffer_capacity_exceeded` at P5. Running that logical capacity guard at P4 reserve changes both precedence and failure prefix, including versus a leg failure. Preserve its P5 refusal point, or explicitly propose and justify a contract/oracle change; a claim that order is unchanged is insufficient. |
   | Buffered/memory success | Keep separate committed, reserved and validated extents, including multiple handler-level fill blocks before one flush (H:513-528). P5 exposes only complete validated batches and flushes legs in the same order. Append validation in P4 must advance its accepted sequence/time boundary as today, independently of the visible event count (H:466-477,559-565). |
   | Memory legs | `record_accounting_fact()` may inspect the same validated pending batch before P5; it stages legs, which P5 releases (H:761-770,223-276). Replace the block argument with a handler-owned range/token or equivalent access, preserving this exception and avoiding a copied publication block. |
   | Durable `live` | H:545-557,154-175 writes each fill during P4, one insert per fill, inside E's invocation transaction (E:2056-2063; H:93-103). It does not wait for P5 and is visible inside that transaction. Preserve this path and its writer result/last boundary; do not also count it for a later buffered insert. "P5 commits count" is a buffer rule, not a new database transaction boundary. |
   | Other producers/readers | P1/opening/non-fill and compiled paths use `buffer_event`, `append_event_rows`, or `append_compiled_spot_batch`. They cannot overlap outstanding reserved indexes or implicitly commit a reservation (H:498-508,666-710,715-758). Keep their existing publication timing. |

   Uncommitted bytes may legitimately survive in an abandoned private buffer after a handler error; the current contract does not require erasure.
   Escape paths to guard are `events()`/`typed_events()` (H:774-787), `flush_pending()` and checkpoint/final flush (H:673-682; E:1651-1655,2033-2035), growth (H:415-434), pending legs, recorder capture and any handler reuse.
   Today these public/materializing paths use committed count; keep that property. Growth must preserve outstanding validated ranges, and reuse must reset reservation state or discard the failed handler.
   Every reserved row must initialize all evidence/default columns, even when reusing a dirty suffix; do not rely on the buffer's original all-NA allocation.
   Validation must target exactly the new range, not unused capacity or the whole retained prefix. V:126-132 currently takes complete equal-length columns: define an indexed boundary without reintroducing a held block or repeated history scan.
   Workers remain candidate-local: each creates its own handler and summarizes only after fold success (`R/sweep.R:1656,1827-1836`); preserve discard-all interruption and no worker writes under [Event Staging And Parallel Sweeps](../contracts.md#contract-execution-event-staging).
   Recommendation: bind this state/visibility protocol, dry validation, live exception and failure timing, then demonstrate growth, append/leg/flush errors, interrupts, stop/skip, multiple batches and candidate isolation. These proposed paths are otherwise unverified.

5. **Direct diagnostic writes must retain deferred certification and current refusal placement.**

   Claim: S:118-122 can be read as writing every stage's diagnostic rows immediately and deleting three passes without replacing their guarantees.
   Evidence: E:927-965,1025-1055 carries decision/risk segments to P3; E:1254-1335 certifies clean forms, reserves every logical position and expands only residuals. This is binding in [Fold Core And Output Handlers](../contracts.md#contract-execution-fold-core) (C:220-240).
   F:821-871 supplies defaults, scalar expansion, coercion, length and value checks before staging; F:876-906 checks capacity and advances counts after writes.
   P5 reconciliation has its own finite-value refusal before staging (E:1584-1596). The writer freezes flushed chunks by replacement (D:104-116).
   Consequence: eager full-row writing can restore the expensive expansion the codec removed, expose invalid partially written values, or change stop/refusal behavior.
   Recommendation: say "write only certified residual rows directly into typed staging"; keep P2's fresh deferred typed values until P3 knows the outcome.
   Prove scalar/default behavior, used/logical counts, offsets, keep gaps, bounds, coercion effects and rejection precedence at the fused write boundary; retain necessary dynamic checks there, without normalizing already checked fields again.
   Reset counts on P5/E-stop drainage and freeze handed-out chunks as today. The staging checker does not validate JSON content or reason vocabulary; do not invent new diagnostic guarantees.

6. **A debug switch is useful development instrumentation, not an equivalent production refusal guarantee.**

   Claim: S:160-163 says construction bugs are caught by the harness, recorder and tests. That is true only for exercised inputs.
   Evidence: K:387-397 requires whole semantic boundaries, including side effects/refusals, frozen records and complete mappings; finite successful tapes cannot cover every user's branches.
   A rare context permutation producing a wrong restriction offset or a `priced`/mark mismatch is refused by today's carrier checker. With debug off, if no other guard covers it, it can affect decisions or diagnostics silently; a valid ledger formula does not detect it.
   Conversely, a semantically wrong but well-typed mark/order can already pass today's structural checks: do not claim those checks prove all economics.
   Consequence: debug-only checking deliberately removes those production bug detectors unless the new construction eliminates the failure mechanism. Sampling can miss the pulse; end-of-fold checking cannot recover discarded fresh groups.
   Recommendation: accept debug for proved construction properties, not as the proof. State each removed detector honestly and retain unproved/data-sensitive residuals in production; seek explicit disposition for any remaining lost refusal.
   Run representative positive/refusal parity with debug both on and off: all-tests-on alone never exercises the shipped bypass path. Test that debug adds assertions only, without changing writes, sequencing or retained values.
   If implemented as a process option, set it explicitly in recorder/parity workers: existing worker initialization propagates source path and libraries, not arbitrary parent options (`R/parallel-workers.R:293-312`). Worker execution was not probed.

7. **The recorded numbers are mostly accurate ablations, not candidate savings or budgets.**

   Claim: S:23-40 and S:126-131 compress distinct measurements into a proposed production design.
   Evidence and audit of every quantitative claim:

   | Seed claim | Checked result and qualification |
   | --- | --- |
   | Commit/pin and workloads | `d8aeb04c` resolves; `R/` equals `d5b3a151`. SP/run.R:24-45 constructs 40 x 504 momentum and 500 x 1,260 fill-heavy. Correspondence to the unavailable interface-table draft is unverified. |
   | Real loop 1,925 / 6,087 us; plumbing 1,190 / 1,976 | Correct rounded EV/timing.csv:2,9,17,24. Ratios are 61.86% / 32.46%, supporting the quoted 32-62% range. Real-loop raw repetitions are not saved by run.R:60-65,222-228; those medians cannot be independently recomputed from the CSVs. |
   | Checks 476 / 825 us | Correct marginal deltas: 476.2 / 825.4. SP/sim.R:190-202 disables BOTH carrier and append validators, including diagnostic carrier checks. The proposal retains append and dynamic checks; this is not its achievable saving. P confirms all skeleton summary medians against EV/timing_raw.csv. |
   | Diagnostics 714 / 445 us | Correct rounded deltas: 714.3 / 444.5. This ablation removes staging AND pulse drain/flush (SP/sim.R:226,247,262,299-302), not merely three staging passes. It also removes their carrier checks, overlapping the check row. |
   | Fill publication 60/20 and 929/119 us | Correct rounded marginal deltas (59.5/19.8; 928.6/119.0). Today's arm includes payload checks/append; prealloc uses a separate unchecked buffer, bypassing handler publication (SP/sim.R:101-143,267-297). The 7.8x fill-heavy ratio does not price validated production reserve/write/commit. |
   | Hand-offs and services under 40 us | Supported for these stubs: empty loop/calls 0/15.9; list service reads 19.9/15.9 us (EV/timing.csv:10,15,25,30). Mean reads are rounded and generated (SP/sim.R:23-47); this is not actual stage computation. Clock-resolution caveat remains SP/README.md:54-56. |
   | Fresh 198/286 versus overwrite 258/333 us | Correct rounded group-ablation deltas. The fresh arm copies taped results with `fp_snap`; prealloc loops over fields with get/setv/assign and omits the plan wrapper (SP/sim.R:68-94,180-187,215-260). It supports fresh outputs as a reasonable default, not a universal allocation/overwrite result. |
   | Reference errors 500/504 and 1,259/1,260 | Correct EV/parity.csv:11,21; SP/run.R:105-114 compares retained `target_qty`, not every recorded field. The trap supports copying mutable boundary records when needed. |
   | About nine carrier checks/pulse | About nine in the skeleton; real fill-heavy is about ten because P3 execution-view checks are omitted (EV/check_census.csv:27). Check census also distinguishes fold-entry/exit checks. Do not present the skeleton as every check in the real fold. |
   | About 275 us/staging call | Traceable only to SP/README.md:99-103's approximate Rprof-share calculation: 1,190 x 46% / 2. No profile CSV/raw samples or Rprof runner establish that attribution here. Unverified beyond the README assertion; not a directly measured per-call cost. |

   EV/alloc.csv, sizes.csv and reads_per_call.csv were also inspected: allocation is cumulative R allocation including setup, sizes describe the taped groups, and service counts use the generated read plan. None establishes peak memory or a constant cost independent of data volume.
   Output parity is exactly the compared event columns, diagnostic writer blocks and six equity fields (SP/run.R:73-97; EV/parity.csv); the tape's events come from captured publication blocks, not a durable-store read (SP/tape.R:212-218,242-252).
   The skeleton leaves out stage computation, execution-view construction/checking, legs, durable writes, telemetry sampling and stop pulses (SP/README.md:122-128). It reuses pinned diagnostic staging, so it does not implement or test direct diagnostic writes.
   Its prealloc buffer grows by reserved count, commits blindly and has no append validation/failure protocol; successful parity proves correct replay on two tapes, not reserved-row failure/live/worker parity.
   SP/README.md:36's claim that prealloc has no per-pulse checks is too broad: it still invokes pinned diagnostic staging and its carrier checks (SP/sim.R:57-64,190-203). Only the main output-group checks and fill append validation disappear there.
   Consequence: no recorded arithmetic number is materially wrong, but "every output", guaranteed bug detection and production savings are overbroad descriptions.
   Recommendation: label all deltas as overlapping component-removal evidence; remove any implication that the savings add or set budgets. Measure the implemented retained-check design at matched complete boundaries under L:291-299 and A2 (L:413-418).
   The seed's accepted-record citations resolve: K:136-141,436-443; L:78-80,428-431; K:300-307; A:152-163,340; C:250-262,292. Those records support subtraction of duplicate checks, not blanket trust of every transformation.

8. **The amendment's supersession map is incomplete.**

   Claim: S:154-156 changes two phrases in C and says diagnostics needs no contract amendment, but the bound text has more affected rules.
   Evidence: [Fold Core And Output Handlers](../contracts.md#contract-execution-fold-core) says P3 plans are validated once (C:193-204); [Typed Fold Carrier](../contracts.md#contract-execution-fold-carrier) binds refusal classes and a retained publication group (C:255-262,292); [Event Staging And Parallel Sweeps](../contracts.md#contract-execution-event-staging) expressly binds a held block, preflush access exception, complete-pulse publication and live writes (C:471-485).
   T:90-107,192-218 and K:294-307 also bind these owners/failure boundaries; parent L:69-80 incorporates T.
   Consequence: acceptance of the two replacements alone leaves contradictory operative representations and can silently change the class/timing of a refused run.
   Recommendation: give a target/section/disposition table covering those rule groups and inherited passages, with exact replacement scope at the switch. Preserve the frozen oracle and distinguish construction-check removal from any authorized behavioral difference.
   Direct diagnostic writes can remain an implementation change if finding 5's semantics hold; the reserved-row publication representation does require the broader contract disposition.

Answers to questions 1-10:

1. Correct construction is acceptable for a specifically established property; tests/debug alone are not equivalent guarantees. No generic sampled/end check substitutes for missing runtime guards (findings 1, 6).
2. Keep dynamic arithmetic/mapping, callbacks/risk, lot/applied-row, prices/fees/quantities, sequence bounds, capacity, affordability and reconciliation checks at their present semantic boundaries. Skip's literal empty plan needs no repeated full structural check (findings 1-2, 4-5).
3. No. Status/next are absent from append input; contiguity, format, strict storage/tokens, finite publication time and fill age exclusion differ. Prove construction-only residuals instead of moving every check (finding 3).
4. Yes in principle, with P4 immediate per-fill inserts inside the existing invocation transaction and no duplicate P5 append. This was not execution-verified (finding 4).
5. Evidence only. Family budgets still require pinned, matched measurements of the design with retained guarantees (finding 7).
6. The census and inherited-versus-new distinction are in finding 2; publication's detailed split is in finding 3.
7. Finding 3 compares every publication field, the two nonledger fields, common structure and cross-block checks. Neither validator subsumes the other.
8. Not yet demonstrated. Dry failure-prefix validation, P5 capacity timing, preflush leg access, dirty suffix/growth, live inserts and candidate-local ownership need the explicit protocol in finding 4.
9. It misses unexercised, data-triggered construction defects in user runs. Run both debug modes and prove each omitted assertion redundant; sampling cannot guarantee detection (finding 6).
10. Table arithmetic and record citations check out with the qualifications in finding 7. Profile attribution, unpublished interface-table equivalence and unexecuted failure/live/worker behavior remain unverified.

Seed v2 should:

- Add the per-property guarantee census and establishing operations; remove the blanket implication that checked inputs make every new output correct.
- Retain necessary runtime checks with classes and precedence; remove redundant constructor rechecks and the instruction to migrate every publication-only check into append.
- Add the reservation/validation/visibility protocol, dry-run refusal path, unchanged P5 capacity refusal and explicit live/leg exceptions.
- Reword diagnostics around residual-only direct writes and preserved deferred certification; retain fresh outputs and frozen recorder ownership.
- Add debug-off parity and failure/invisibility witnesses; describe finite tests as evidence, not guaranteed discovery of all construction bugs.
- Reword timings as overlapping ablations, qualify the profile assertion, and keep family budgets with the existing matched-measurement authority.
- Add the complete supersession map, leaving the pin and shipped code untouched until the authorized switch.
