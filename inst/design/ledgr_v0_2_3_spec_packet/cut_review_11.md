# Cut 11 Review: Typed Accounting And Exact Durable Evidence

- Date: 2026-11-03
- Reviewer: independent clean-context Claude CLI, Opus
- Mode: Type 1 cut review with adversarial input and ticket-grain check
- Baseline: `0371f936` on `release/v0.2.3` (draft cut, unaccepted)
- Verdict: **CHANGES_REQUIRED**

## Answer

The cut translates both accepted syntheses faithfully at the level of
decisions. The WS23 -> WS24 -> WS25 order, the one wide typed ledger, the
bounded WS23 extraction, the `inline_summary()` exception, the untouched
compiled envelope, the retained full logical trace and the no-migration
boundary all match their authorities. No finding needs Type 2: every
correction below stays inside Sections 2-8 of the typed-accounting synthesis
and Sections 2-7 of the per-pulse synthesis.

The cut is not ready to accept for four structural reasons and nine smaller
ones:

- two ticket splits leave a red or semantically wrong tree between tickets
  (R1, R2);
- the "one final fingerprint" language assumes the store fingerprint covers
  table definitions, but it does not (R3);
- the measurement wording contradicts the cut's own rule-16 decision (R4);
- a contract release gate that this cut triggers has no owner (R5).

One choice needs the maintainer at acceptance: the exact value of the
INCOMPLETE `annualized_return` correction (R13).

## Input Check

Read: AGENTS.md; both syntheses and their final reviews; macro plan rules
1-17, WS3, WS7, WS8, WS15, WS14 and Section 4; the Cut 11 entries, workstreams
23-25 and LDG-3200-LDG-3209 in `tickets.yml`; the cut diff to `decisions.md`,
the packet README and the macro plan; `contracts.md` (release gates,
strategy reproducibility, resume text); prior cut reviews 7 and 9 for format.
Code read at `0371f936`: `R/store-gate.R`, `R/run-resume.R`,
`R/backtest-runner.R` (resume, opening append, recovery, partial run),
`R/run-finalize.R:150-185`, `R/execution-timing.R:215-245`,
`R/corporate-action-settlement.R` (existing events, dedupe, past
quantities), `R/fold-engine.R:1495-1580`, `R/fold-event-buffer.R:110-155`,
`R/backtest-config.R`, plus repository-wide searches for `meta_json`,
`ledger_events`, `run_diagnostics`, `strategy_state`, `ledgr.interrupt`,
`checkpoint_every`, `max_pulses`, the memory-sink attributes and every
`*_(schema|rule)_version` binding. No private data, benchmark or full suite
was run.

The inputs are the right ones. One controlling input outside the cut's
authority list matters: `contracts.md:3351-3372`
(`contract-verification-release-gates`), which the per-pulse synthesis
Section 6 invokes ("retain the existing paired history memory gate where
triggered") and which the cut does not cite (R5).

## Required Patches

### R1. LDG-3203 leaves a red tree

LDG-3203 removes `meta_json` from `ledger_events` while every producer
(`R/backtest-runner.R:98-143`, `R/ledger-writer.R:91-140`,
`R/fold-event-buffer.R:144`, `R/corporate-action-settlement.R:553-578`,
`R/terminal-outcomes.R:176-199`) still appends it, and the WS23 preparer
still extracts evidence from stored JSON (LDG-3201 scope). Every durable run
fails until LDG-3204 lands. The synthesis rejects keeping JSON beside typed
columns, so no interim dual write can bridge the two tickets.

**Patch.** Merge LDG-3203 into LDG-3204, so that one ticket owns the DDL,
schema 125, refusal, every producer, all three write paths and deletion of
the extraction. Keep one ID (either one) and retire the other, as Cut 9 did.
Carry LDG-3203's acceptance items 1-3 into the merged ticket and drop item 4
(R3 replaces it). Set the merged ticket's `dependencies` to `["LDG-3202"]`
and its effort to `L`. Then update three places: workstream 24's `review.point`
and `reason` ("LDG-3203 through LDG-3205" becomes the two surviving IDs), the
Cut 11 `sequencing` text ("ten serial tickets" becomes nine) and the README
paragraph.

### R2. LDG-3207 drops clean-fill rows before LDG-3208 breaks the circular dependency

The per-pulse synthesis Section 4 and macro WS15 both say: break the
fills-to-diagnostics association dependency *before* omitting clean-fill
rows. Today `ledgr_run_fill_recording_pulses()` reads physical
`execution/filled` rows (`R/execution-timing.R:224-232`). LDG-3207's
acceptance item 3 allows omitting those rows. The fix to the fills reader is
in LDG-3208, which comes after it. Between the two tickets, the fills reader
and every SQL consumer of `run_diagnostics` (sizing, valuation, completion,
corporate-action bounds, explain) would read a sparse table as if it were the
logical trace. That is the exact failure the synthesis forbids.

**Patch.** Split by layer, readers first (the same pattern as WS23 before
WS24):

- **LDG-3207, "Decode the logical trace and route every diagnostic
  consumer":**
  - add the codec's logical decoder over an all-explicit encoding;
  - move every consumer onto that decoder or onto exact summaries: today's
    LDG-3208 scope and acceptance, the fills association derived from typed
    event sequence and calendars, and the R7 census rows;
  - forbid any physical omission in this ticket;
  - parity against LDG-3200 must hold with full physical rows still written.
- **LDG-3208, "Select implicit forms before row expansion":**
  - today's LDG-3207 writer scope and acceptance (implicit forms, residuals,
    sizing, clean-trade omission, scheduled skips, writer-side counters);
  - repeat the full/filtered parity, close/reopen and corruption-refusal
    items.

Swap the two tickets' `title`, `scope` and `acceptance` to match, keep
`dependencies` serial, and update workstream 25's review reason, which lists
the claims in the old order.

### R3. The store fingerprint does not cover table definitions

`ledgr_store_current_fingerprint()` is the canonical JSON of the
`ledgr_*_(schema|rule)_version` constants (`R/store-gate.R:3-41`). It is not
a DDL hash, and `ledgr_store_assert_current()` reads only the two markers. So
when WS25 changes the DDL without changing a constant (dropping
`strategy_state`, adding codec, residual, association or summary storage),
the fingerprint stays the same. A schema-125 store created at the WS24 close
then passes the gate on WS25 code.

The cut assumes otherwise in three places:

- LDG-3203 calls schema 125 "the cut's only version number";
- LDG-3203 acceptance item 4 relies on a final-fingerprint owner;
- LDG-3209 asks to "regenerate the schema-125 golden catalogue and
  fingerprint including all WS24/WS25 DDL".

The golden catalogue is a test-side pin, not a runtime refusal. The per-pulse
synthesis Section 6 requires the one fingerprint to cover codec rules.
`ledgr_strategy_state_rule_version` cannot carry this change, because it is
also the declaration-identity rule (`R/strategy-state.R:81`).

**Patch.**

- **Encoding ticket (R2's LDG-3208):** add one store-format binding for the
  diagnostic codec. Either add a new `ledgr_diagnostic_codec_rule_version`,
  or bump `ledgr_sizing_evidence_rule_version` if its meaning changes. The
  ticket must say which; the binding must not be a run-identity input.
- **Wording:** replace "the cut's only version number" with "the cut's only
  schema-version number; WS25 adds one store-format rule binding". Restate
  decision (4) and `identity_and_release_impact` the same way.
- **LDG-3209 acceptance:** add an item: "a schema-125 store whose
  fingerprint is the WS24-close value refuses with
  `ledgr_store_rebuild_required` cause `fingerprint_mismatch`; the
  golden-catalogue test and the binding list both change at the
  DDL-changing tickets, so every intermediate commit is green".

### R4. Measurement placement contradicts decision (8) and rule 16

Decision (8) puts clocks and memory at "the completed-cut milestone". Yet
LDG-3202 acceptance item 4 requires an "attributed milestone record" at the
WS23 close, and LDG-3205 acceptance item 4 requires a hotspot milestone record
at the WS24 close. Those are per-workstream records of states that the next
workstream replaces, which is the waste rule 16 removed. Meanwhile LDG-3209,
the real milestone, leaves out the macro WS8 amendment's four hotspots and
the no-fill, sparse-rebalance and wide all-fill cells (macro `:470`, `:474-491`).
It also leaves out the WS15 per-function sample counts against the 10 x 7,200
profile (`:523-528`), the helper-sizing watch item ("the cut measures this
case", `:519-522`) and the v0.2.2 base that rule 16 names.

**Patch.**

- **Decision (8):** add one sentence: "This supersedes the 'no-regression
  gates' of typed-accounting synthesis Section 6 item 11 and the 'allocation
  gate named at the cut' of macro WS8."
- **LDG-3202 item 4:** strike "and attributed milestone record". The
  terminal-recovery item stays as a complexity detector (count replay calls),
  not a clock.
- **LDG-3205:** replace item 4 with: "the batching decision cites the
  measurement that settled it (a rule-16 design measurement, not a gate)".
  Strike "Record attributed ... results against LDG-3200" from its scope.
- **LDG-3209:** make it the single milestone record. It compares against
  both LDG-3200 and v0.2.2, following the WS4b precedent of two named bases.
  It reports:
  - each of the four WS8 hotspots next to the fill-heavy profile;
  - the no-fill, sparse-rebalance and wide all-fill cells;
  - per-function sample counts against the 10 x 7,200 quiet profile;
  - helper-sizing storage rows and bytes.
- **LDG-3200:** register one protocol folder under
  `dev/bench/timing/protocols/` for the cut (AGENTS.md: one folder per cut,
  never a copy).

### R5. The paired history resource gate is triggered and has no owner

`contracts.md:3351-3372` says a change to fold memory is measured with the
paired history resource protocol: a 1.10x pass, or an explicit maintainer
exception. The same section records the read-side peak of the full decision
trace through `ledgr_results(bt, "diagnostics")` and `ledgr_run_explain()`.
WS24 changes fold publication buffers, and WS25 removes cursor staging and
rewrites diagnostic staging, so the protocol is triggered. The per-pulse
synthesis Section 6 retains it. Rule 16 is a macro-plan rule; it does not
amend a contract release gate.

**Patch.** LDG-3209 owns the protocol on the registered H1 workload. The
baseline arm is built fresh from the LDG-3200 base commit, and either the
1.10x rule passes or the maintainer grants an explicit exception. Add an
acceptance item and name the gate in decision (8) and `authority` as the one
memory pass/fail that rule 16 leaves standing.

### R6. The private reference cannot run on schema 125 without a rebuild

LDG-3209 requires private Sharadar parity on the final candidate. But the
identity record says the private lake is rebuilt only at the later freeze,
LDG-3205 forbids a rebuild, and schema 125 refuses the existing private
store. WS4b handled the same conflict with a disposable candidate-format
rebuild that reproduced the snapshot hash and fact digests (LDG-3178
evidence, `tickets.yml:2751`). The private record also has to be
aggregate-only, so as written "exact trace parity" on family 7 cannot be
checked.

**Patch.**

- **`identity_and_release_impact` and LDG-3209 scope:** say that the private
  reference runs on a disposable candidate-format rebuild, which first
  reproduces the registered snapshot hash and fact digests, and that this is
  not the final lake rebuild.
- **LDG-3200 acceptance item 3:** the private record is checked-in
  aggregates. It holds per-table canonical digests and row counts for full
  and filtered diagnostics, point/history explanations, D8/valuation
  summaries and economics, not public economics only.

### R7. The diagnostic, cursor and recovery seams have no census

LDG-3200's census covers accounting producers, writers and readers only. The
per-pulse synthesis lists consumers as "include", not as a closed set, and
the cut copies that list. Unnamed seams at `0371f936`:

- `ledgr_next_diagnostic_seq()` (`R/backtest-runner.R:208-217`, seeded at
  `R/output-handler.R:131`) takes `MAX(diagnostic_seq)` over physical rows,
  which is wrong once trailing rows can be implicit;
- the resume-only raw-sizing-notice query (`R/backtest-runner.R:845-850`);
- stopped-outcome readers (`R/availability-results.R:23`, `:117`, `:167`;
  `R/corporate-action-results.R:167`), which are correct only while stop rows
  stay physical;
- `R/valuation-summary.R:82`, `:113`, `:121`, `:506`, `:640`, `:667`;
  `R/sizing-evidence.R:134`, `:142`; `R/run-finalize.R:129`;
- the finalization-only resume branch (`R/run-resume.R:59`) and
  `resume_state` (`R/backtest-runner.R:643`);
- the `start_idx > 1` past-quantity path in
  `R/corporate-action-settlement.R:415-437`, which walk-forward also uses
  (`R/walk-forward.R:1368`), so it is not purely resume code;
- `control$max_pulses` (`R/fold-engine.R:1574`, `R/backtest-runner.R:945`),
  which commits a partial prefix and leaves a nonterminal run that rerun used
  to resume;
- the `ledgr_strategy_ambient_rng_resume` condition class;
- `ledgr.interrupt` in a helper and about ten registered test files.

**Patch.**

- **LDG-3200:** extend the census to every `run_diagnostics`,
  `strategy_state` and `run_completion` reader, writer and deleter, every
  resume or cursor branch, every `ledgr.interrupt` and `max_pulses` user,
  resume conditions and resume documentation.
- **LDG-3206 and R2's LDG-3207 acceptance:** each must exhaust its part of
  the census. Classify every physical-row reader as either a decoder/summary
  consumer, or a reader of an always-physical row class (stop/error,
  scheduled skip) with a detector that fails if that class becomes implicit.
- **LDG-3206 scope:** state that `max_pulses` partial runs stay nonterminal
  and restart at pulse one, and that the finalization-only branch is deleted.
  Such runs restart unless committed completion evidence permits publication
  recovery.

### R8. `checkpoint_every` is a configuration field

LDG-3206 removes "intermediate durable checkpoints". `checkpoint_every` sits
in the run configuration's `engine` list (`R/backtest-config.R:188-193`) and
drives the buffer flush (`R/fold-engine.R:1565-1571`). Removing it changes
run-configuration identity, which contradicts the cut's identity record. The
synthesis Section 5 also keeps a still-used flush control.

**Patch.** Add to LDG-3206 scope: "`checkpoint_every` remains the
buffer-flush control and configuration field; a flush carries no
pulse-durability promise." Add to acceptance: the configuration hash of a
fixed experiment equals its LDG-3200 value.

### R9. WS25 documentation is deferred past acceptance

LDG-3209 says "Reconcile contracts/docs/NEWS ... only after independent
review and maintainer acceptance". That breaks rules 6 and 7 and leaves the
WS25 close review without the contract text it has to check. Resume is taught
in many places:

- the `ledgr_run()` "Early exit" section (`R/backtest.R:46-51`);
- `man/ledgr_walk_forward.Rd`, `man/ledgr_strategy_preflight.Rd` and the
  condition reference;
- `vignettes/experiment-store.qmd`, `reproducibility.qmd` and
  `strategy-development.qmd`;
- `contracts.md:444-450`, `:1327-1330`, `:1514-1539`, `:1553-1574` and
  `:2101-2145`.

**Patch.**

- **LDG-3206:** owns resume retirement across contracts, help, vignettes,
  NEWS and the condition reference, with exact-name searches that detect
  restoration.
- **R2's LDG-3207:** owns the fold-evidence and completion-evidence contract
  text for the decoder.
- **LDG-3209:** keeps only the governance links (RFC pipeline, decisions
  bridge, macro plan, packet status) after acceptance.

### R10. The restart oracle and resume-test migration are unstated

LDG-3206 acceptance item 2 can pass when a restart reproduces *something* at
pulse one. Synthesis Section 6 requires registered tests to stay unchanged
"except for separately justified removal of retired resume semantics", and
AGENTS.md requires a stated reason for each test change.

**Patch.**

- **LDG-3206 item 2:** add "and the restarted output equals the LDG-3200
  record of the same configuration run uninterrupted".
- **LDG-3206 acceptance:** add a new item: "every registered test that is
  removed or migrated is listed in evidence with its retired-resume reason;
  no other fixture or oracle changes".

### R11. Retention selection has no no-lookahead witness

The per-pulse synthesis Sections 4 and 6 let retention use the next-open
outcome only after strategy and risk decisions, and they require a
no-lookahead witness. No ticket has one.

**Patch.** Add to the encoding ticket (R2's LDG-3208): "a mutation that
exposes the next-bar outcome to P2 or risk before retention fails a
registered no-lookahead witness; fill timing is unchanged against LDG-3200".

### R12. The A0 harness migration is not settled

`dev/bench/v0_2_3_output_freeze/lib.R:405-407` reads the memory attributes
that LDG-3204 deletes. Typed-accounting synthesis Section 8 promoted "which
A0 attachment points migrate" to this cut, and the cut does not answer it.

**Patch.** LDG-3204 scope names the A0 `lib.R` attachment point and the five
test files (`test-accounting-core-consolidation.R`,
`test-execution-spec.R`, `test-ledger-writer.R`,
`test-output-handler-sinks.R`, `test-sweep.R`) as attachment-point
migrations under Cut 1 decision (1) wording. Acceptance: the migrated harness
reproduces the frozen A0 records except one recorded change to the
memory-event columns.

### R13. The INCOMPLETE correction is not pinned (maintainer)

Decision (3) and LDG-3202 item 1 accept "the explicitly recorded" correction
but never state its value. That acceptance passes for whatever difference
happens to appear. Cut 1 decision (2) records the difference: the sweep row
reports 0 where run metrics report NA, with NA recommended. Separately,
audit S2-014 says `ledgr_compute_metrics()` and `summary()` disagree, so "the
run-reader authority" is ambiguous.

**Patch (maintainer confirms at acceptance).** Decision (3): "for an
INCOMPLETE run the sweep/candidate `annualized_return` becomes `NA_real_`,
equal to the run reader; no other surface changes; S2-014 stays out of
scope." LDG-3202 item 1 names the A0 record row and that value.

## Should-Fix

1. **LDG-3201 acceptance lists are incomplete.** List synthesis Section 6
   item 2's fixtures literally: partial close, reversal, cash with and
   without a mark, haircut. List item 4's five split positions instead of
   "every registered split". Add the replay mutations: disposition `qty` or
   `price` disagreeing with `position_before` or the mark, `realized_model_pnl`
   outside dust tolerance, and a disposition that leaves a live lot.
2. **LDG-3204 has no append-boundary detector.** Add one: a wrong-effect
   producer block refuses before any durable write (synthesis Section 10, row
   1), and removing the call fails. After LDG-3206 a durable run's existing
   events are only openings, so say that typed dedupe keeps its walk-forward
   consumer (`R/walk-forward.R:1368`) and is not vacuous.
3. **Unexplained move of sink auxiliaries.** Synthesis Section 5 puts their
   deletion in WS7; the cut moves it to LDG-3204. Record the reason (the
   memory producer changes in WS24) in decision (2).
4. **Rule 11.** `measured_input` cites prior records but does not say the
   existing A0, dense and real-data checkers ran on the base. State it, or
   state that LDG-3200 discharges rule 11 for this cut.
5. **Candidate evidence.** Add to the decoder or encoder acceptance
   (synthesis Section 5): sweep candidates keep their retained evidence,
   numbering and metrics, and gain no full-trace or D8 claim.
6. **One batching path.** LDG-3204's batching decision covers the
   diagnostic-flush mechanism, and WS25 reuses it without a second batching
   path (macro WS15, "Order inside the cut").
7. **Governance nits.** The packet README says "macro plan revision 9" while
   the macro plan now carries revision 10. Revision 10 records a draft,
   non-maintainer routing in an accepted document; label it as a routing
   note or keep only the Section 4 bullet until acceptance.

## Checked Clean

- **Decision ownership.** D1-D8 of the typed-accounting synthesis and D1-D6
  of the per-pulse synthesis each have one owner; no ticket invents a public
  sparse API, compatibility path, alias or second accounting authority.
  `position_delta` is never a position source.
- **WS23 boundary.** The temporary extraction is confined to preparation
  (LDG-3201) and deleted with a source detector (LDG-3204 item 2).
- **Reader census.** The `inline_summary()` exception, the raw `SELECT *`
  ledger (`R/backtest-results.R:1290-1300`), typed dedupe and bookkeeping
  exemptions match synthesis 3.5 and P5. Every current `ledger_events`
  reader found by search either is named or falls under LDG-3200's literal
  census.
- **Terminal recovery.** The per-pulse `ledgr_state_asof()` loop
  (`R/run-finalize.R:164-172`) is correctly owned by LDG-3202.
- **Opening append.** The write at `R/backtest-runner.R:243-261` serves every
  durable run, not only resume, so LDG-3204 typing it is not wasted work
  that LDG-3206 then deletes.
- **Compiled envelope.** It is untouched, and parity moves to typed columns.
- **Identity.** Snapshot content and run-configuration identity are
  unchanged (subject to R8). There is no dependency change, no migration and
  no old reader, and refusal goes through the existing classed gate.
- **Governance routing.** `decisions.md` and the RFC pipeline route
  correctly. The horizon progress/state split is already closed with the
  synthesis reason.
- **Close-review claims.** Each workstream claim names failure-sensitive
  checks; WS25's private-reference wording is consistent once R6 lands.

## Next Step

Apply R1-R12 to `tickets.yml` and the three governance files, take the
maintainer's answer on R13, then run a focused re-review of the re-grained
tickets (merged WS24 ticket, swapped LDG-3207/3208) and of the R3/R5
wording.
