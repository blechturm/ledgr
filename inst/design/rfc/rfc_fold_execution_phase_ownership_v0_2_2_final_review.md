# Final Review: Fold Execution Phases And State Ownership, v0.2.2

**Verdict:** CHANGES_REQUIRED
**Mode:** Type 1 final review. Provisional until the maintainer rereads the
brief and review together.
**Author/date:** Codex, 2026-10-15; wrote neither seed v2 nor the synthesis.
**Record note:** text supplied by the maintainer from the review session and
saved by the synthesis author. Wording is unchanged; formatting is normalized
to ASCII markdown (the review's table and typographic characters). Section
numbering follows the brief. The synthesis and seed v2 were patched in place
against F1 to F8 on the same day; see their revision notes.

Reviewed the uncommitted RFC artifacts in
C:\Users\maxth\ledgr-research\.worktrees\ws38. HEAD is
fbd05c5639f89b2ab49f2dd2ed5d3ecd5581912c; its difference from executable
baseline 07f91bcfa9455d5eafa5ef4c1712f0ccd7b6fee3 is confined to tickets.yml.
The reviewed production, test and recorder sources match the baseline.

The five-stage direction is supported by seed v2 and the response. Several
acceptance claims are false or incomplete, however. These findings concern
verification and document consistency; they do not require reopening the
taxonomy.

No files were changed, no production execution or recorder run was performed,
and no other agent was invoked.

## 1. Findings, most severe first

### F1. The return-field consumer census is not empty

Artifact: Synthesis Sections 5.5, 8 Gate A and 13.

Code: tests/testthat/test-execution-spec.R:604, assertions at 604-610 and
751-757; ledgr_compiled_spot_fifo_test_run() and
ledgr_compiled_spot_fifo_multi_test_run() return the actual fold result.

Registered blocks LTB-0006 and LTB-0013 read fold$state and
fold$next_event_seq. Both are detecting blocks in tests/claims.yml. Therefore,
the proposed census over R/, tests/ and dev/ cannot establish "no reader."

The narrower production claim holds: ledgr_run_fold_impl() assigns all three
fields without subsequently consuming those assignments; sweep consumes none
of those three fields. But there are three, not two, dead runner stores:
state_env$current, state_prev_mem and next_event_seq at
R/backtest-runner.R:1268-1270.

The assignment inventory is also incomplete. Parsing run_loop() independently
found 16 assignment sites rooted at these bindings:

- Nine assignments to state or its components.
- Five assignments to event_seq.
- Two assignments to state_prev_mem.

The synthesis omits state_prev_mem normalization at :753, compiled
position/cash assignments at :1168-1169, and canonical position/cash
assignments at :1230-1231. The stale outer-return diagnosis remains correct.

Smallest patch: Correct the assignment census and store count. Replace the
empty-reader gate with an explicit consumer disposition distinguishing dead
production stores from registered test consumers. Name LTB-0006 and LTB-0013
and require a stated test-change reason before any deletion affecting their
oracle. Do not delete or weaken those assertions merely to obtain an empty
census.

### F2. The recorder acceptance comparison cannot produce the stated result

Artifact: Synthesis Section 7 and Section 8 Gate A; inherited from seed v2
Section 8 and response R13.

Code: dev/bench/v0_2_2_real_data_scale/check_record.R:15, compare();
dev/bench/v0_2_2_real_data_scale/run_record.R:135, run_families().

compare() takes the union of family filenames and reports a family missing
when absent on either side. The repaired recorder is required to add a new
feature-hash family. Compared with the old record, that new family is also
missing, on the old side.

An in-memory execution of the unchanged parsed compare() body, with only the
directory-existence boundary supplied in memory, confirmed three missing
families: the two removed feature families and the added witness family. This
was not a production or recorder run.

Furthermore, a historical pre-schema-120 comparison is not automatically
byte-identical elsewhere. run_families() retains schema_version in both
run-info families; ledgr_run_info_from_row() preserves it. The synthesis
identifies neither the exact historical record nor its expected transition
differences.

Smallest patch: Separate the removed-family inventory assertion from the
complete comparison. Declare the added witness explicitly, pin the historical
record and reproduction command, and enumerate authorized schema/identity
differences. Keep the complete new manifest as the immediate-parent extraction
oracle. Apply the same correction to seed v2.

### F3. The claimed complete ownership and service inventories omit reachable state

Artifact: Synthesis Sections 5.1-5.2 and 13.

Code: ledgr_execute_fold(); R/availability-diagnostic-writer.R:155,
ledgr_columnar_diagnostic_writer(); R/runtime-projection.R:574, feature-bundle
accessor constructors; R/config-canonical-json.R:51, .ledgr_json_cache_set().

The independent census found:

- diagnostic_seq persists across pulse flushes and mutates in
  flush_pulse_block() at R/fold-engine.R:400. Section 5.1 does not assign it
  an owner.
- telemetry_idx persists across pulses, mutates at :1325, and is consumed at
  :1414. Its ownership is likewise unstated.
- Diagnostic append_block() can invoke its internal flush(), which calls
  output_handler$write_run_diagnostics(). Consequently, that handler mutator
  is reachable from P5, not only E.
- flush_pending() also runs during E finalization at :1362, although the
  handler row assigns it to P5.
- Both projection feature-bundle accessor constructors mutate cached explicit
  feature-map bindings. The non-fast accessor is also used by availability
  contexts. The fast-context/scalar-tracker row does not explicitly enumerate
  these mutations.
- canonical_json() reaches the process-global JSON cache, including
  assignment and reset. That state is outside the declared run-service
  census, despite Section 13 demanding coverage of every reachable
  environment write.
- The handler's state-sensitive pending_event_count() and
  pending_state_count() calls are omitted.

The scalar-tracker citation in the service table is ambiguous: :443-447
belongs to R/fold-engine.R, not the preceding R/pulse-context.R path.

Smallest patch: Assign the missing counters, enumerate the callback-helper
caches, correct the handler stage sets, and explicitly distinguish
process-global utility state from run services. State the census boundary
rather than claiming unrestricted completeness. Fully qualify the
scalar-tracker citation.

### F4. The bound stop procedure reverses the existing count/flush order

Artifact: Synthesis Section 5.4.

Code: R/fold-engine.R:982 and :1106-1107, inside ledgr_execute_fold().

Section 5.4 says E flushes the diagnostic block and then increments processed
when required. Both existing counted stops increment processed before
flushing. The count asymmetry is described correctly, but the bound sequence
is not.

Smallest patch: Specify application of the processed-count effect before the
existing diagnostic flush for the P2 and P3 stops. Preserve the uncounted P1
paths.

### F5. The fault-injection matrix assumes effects absent from the baseline

Artifact: Synthesis Section 7 witness 4 and Section 8 Gate C; partly inherited
from the earlier artifacts.

Code: R/backtest-runner.R:246, ledgr_persistent_output_handler();
ledgr_memory_output_handler(); ledgr_execute_fold() at :1211 and :1394.

The persistent handler has no record_accounting_fact() method. The fold
conditionally calls that method; the memory handler supplies it. Requiring an
Nth accounting-fact failure around each real handler therefore does not
describe an existing persistent-handler path.

Likewise, the fold writes an exception diagnostic only when availability is
active. Requiring that diagnostic for durable execution "in both modes"
introduces an effect absent from dense execution.

Smallest patch: State the matrix accurately: fill-write injection for both
handlers; accounting-fact injection where the real method exists; rollback for
durable failures; post-rollback exception diagnostics for availability
failures. Preserve dense failure behavior.

### F6. The "no contract change" claim needs an explicit existing-mismatch disposition

Artifact: Synthesis Sections 3, 5.6 and 8 Gate C.

Contract: Execution, Cost Resolution And Accounting Events prohibits output
handlers from computing fill cash deltas.

Code: ledgr_fill_event_payload(), ledgr_write_fill_events(), and both handler
constructors.

Section 5.6 correctly discovers existing handler-side cash-delta computation.
Preserving it during extraction does not introduce that mismatch, but the
synthesis cannot treat the baseline as proof of compliance with the normative
clause.

Its arithmetic description is also inaccurate: persistent live mode bypasses
ledgr_fill_event_payload() and directly calls ledgr_write_fill_events(). It
does not execute the payload calculation and then recompute it "again."
Buffered persistent and memory paths use the payload helper.

Smallest patch: Correct the branch description. Explicitly record the
pre-existing code/contract discrepancy and route its disposition through the
existing Workstream 33 boundary. State that preservation during WS38 neither
amends nor creates an exemption from the contract.

### F7. The supersession table does not cover every affected ticket field

Artifact: Synthesis Sections 3, 8 and 11.

Authority: inst/design/ledgr_v0_2_2_spec_packet/tickets.yml:1917,
LDG-3052-LDG-3054.

All three ticket titles mention phases, but the table addresses only scope
and acceptance. In particular:

- LDG-3053's title still names input, decision, context and strategy phases.
- LDG-3054's title still names fill, accounting, event and valuation phases.

Those titles describe the superseded partition. Section 11's "four ticket
fields" also fails to identify the actual YAML addresses being rewritten.

Smallest patch: Include each ticket title with an explicit disposition,
alongside each scope and acceptance field, plus
workstreams[id=38].review.reason. Replace the ambiguous field count with exact
addresses. Generic phase wording can be marked unchanged.

### F8. Departures and remaining seed disagreements are incompletely disclosed

Artifact: Synthesis Sections 1-2, 4, 9 and 13; seed v2 Sections 4 and 10-11.

The synthesis says one choice goes beyond seed v2, but it also fixes top-level
functions where seed v2 expressly leaves top-level functions versus nested
closures open. Existing LDG-3053 supports the choice; the departure should
still be stated.

The environment choice is expressly disclosed, but its justification
overclaims. A locked environment fixes the binding-name set; it does not
itself validate types, prevent another carrier, or guarantee that shared
vector values never copy. The stale-return defect is demonstrated by local
binding shadowing, not by evidence that list-and-return plumbing necessarily
causes it.

There is also an unacknowledged ordering disagreement: seed v2's P5
description puts ordinary processed-count increment after telemetry/checkpoint
work. The synthesis correctly places it before those operations, matching
R/fold-engine.R:1322-1347.

Smallest patch: Add these departures to the correction record. Narrow the
environment rationale to what it establishes and retain constructor, detector
and performance obligations separately. Correct seed v2's P5 ordering. The
sequence reversal is already disclosed and grounded in the stated maintainer
instruction and RFC cycle.

## 2. Claims verified

Every line anchor in synthesis Sections 3-5 was checked in its enclosing
function. The principal results are:

| Claim | Functions read and result |
| --- | --- |
| One production fold core | ledgr_run_fold_impl() and ledgr_sweep_run_candidate() both invoke ledgr_execute_fold(). |
| Equity precedes strategy and fills | ledgr_execute_fold(): valuation and equity recording at 769-795 precede strategy invocation at 882-897. |
| P1 needs re-observation | ledgr_execute_fold() and nested availability_decision(): initial observation, post-scheduled-disposition observation and post-terminal observation are present. |
| Three economic write orders differ | ledgr_corporate_action_plan()/post_cash() append before cash mutation; ledgr_disposition_post() mutates candidate state before append and caller installation; canonical fold fills follow lot/write/fact/cash-position order. |
| Context, validation and risk ordering | ledgr_execute_fold(), ledgr_update_pulse_context_helpers(), ledgr_update_fast_pulse_context_helpers() and feature-filter helpers support the described sequence. |
| Dense and availability planning differ | ledgr_fold_build_pulse_plan(), ledgr_fold_warn_final_bar_no_fill(), ledgr_fold_build_availability_pulse_plan() and ledgr_availability_apply_affordability() preserve the stated timing and rejection distinctions. |
| Compiled batch order differs from canonical | ledgr_execute_fold() installs compiled state before batch append. Declared-kind checks precede application. |
| Reconciliation and state-update order | ledgr_execute_fold() flushes fills, reconciles, then normalizes and serializes the state update. Post-fill cash mismatch aborts. |
| Stop count asymmetry | stop_valuation() leaves processed unchanged; risk-mark and affordability stops increment it. F4 corrects the procedural ordering. |
| Transaction and interruption boundaries | ledgr_persistent_output_handler() wraps the invocation and rethrows interrupts after rollback; ledgr_memory_output_handler() executes the loop directly. |
| Conditional RNG restoration | ledgr_execute_fold(), ledgr_run_fold_impl() and ledgr_sweep_impl() condition their RNG restoration scopes on a supplied seed. |
| Stale outer return | ledgr_execute_fold() returns outer bindings while loop assignments are local. The diagnosis holds; the claimed complete inventory and empty consumer census do not. |
| Obsolete feature-table query | run_families() contains one query executed under the momentum and equal-weight tags. The proposed full comparison needs F2's correction. |

The independently traced fold-result consumers are: runner
control/telemetry/equity/status uses; three dead runner stores; sweep's status
use; registered compiled-parity test reads; and development probes using
status or processed counts. I found no live production consumer of the three
proposed deleted fields.

The bound execution direction preserves the reviewed Execution and
Availability semantics. F6 prevents an unqualified contract-compliance
finding.

## 3. Bindings not established by seed v2 or the response

The following additions or resolutions should be distinguished from inherited
direction:

- Mandatory locked environment: selects an implementation option previously
  left open; disclosed, but its supporting claims need F8's qualification.
- Mandatory top-level functions: previously open in the RFC inputs, although
  supported by the existing ticket. earlier broad consolidation route.
- Explicit permission to move telemetry sample points: resolves an
  implementation choice the inputs left open.
- R6 exclusion: introduced here as an external project-stance justification,
  rather than a conclusion discussed by these RFC inputs.

The five stages, three state classes, P5 normalization, stop-result direction,
proposed return cleanup, preservation of handler arithmetic, vector feature
witness, and downstream history/compiled seams were discussed in the earlier
artifacts.

The response's claimed fidelity to an earlier verbatim review cannot be
independently established from the paraphrase alone.

## 4. Recommended next step

Return the synthesis for a bounded correction addressing F1-F8, with
corresponding seed-v2 corrections and a revision note. In particular, resolve
the registered test consumers and make the recorder transition comparison
reproducible before presenting Gate A as executable.

Then perform a focused Type 1 re-review before maintainer acceptance or any
ticket, recorder or production change.
