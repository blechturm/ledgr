# ledgr v0.2.0.1 Batch Plan

Status: Batches 0 through 9 complete after review and maintainer acceptance.
Batch 10 is retained as diagnostic history and does not satisfy final
evidence. The timestamp/benchmark amendment ticket cut passed independent
review. Batches 11 and 12 are complete after review; Batches 13 through 15 are
pending.

Spec: `inst/design/ledgr_v0_2_0_1_spec_packet/v0_2_0_1_spec.md`
Tickets: `inst/design/ledgr_v0_2_0_1_spec_packet/v0_2_0_1_tickets.md`

## Review Protocol

A batch is the independent review unit. Ticket dependencies are the hard
readiness gate; numeric batch order is the default sequence. Batches 5 and 6
were independent of the warm seams and could run beside Batches 2 to 4; Batch 7
could not start until Batches 4, 5, and 6 closed. Amendment Batch 8 depends on
Batch 7, Batch 9 depends on Batch 8, and Batch 10 is diagnostic history from
the first closeout attempt. Amendment Batches 11 through 13 run sequentially,
Batch 14 is the only final measurement checkpoint, and Batch 15 is the release
gate. Batch 15 remains blocked until Batch 14 is independently reviewed and
the maintainer explicitly elects to proceed. If a batch lands out of order,
status text must name the completed and blocked batches rather than implying
linear progress.

For implementation batches:

- implement only the listed tickets;
- add detecting assertions before correctness fixes;
- run targeted verification and the named regression net;
- update this plan, the ticket Markdown, `tickets.yml`, and the packet README;
- stop for independent review before commit unless the maintainer directs
  otherwise.

The spike protocol's correction budgets are stop signals. Batch 4 could not
retire its old paths before the two-arm parity record existed. The new event
and valuation oracles likewise survive only until their exact paired records
exist. No benchmark number can unlock a failed correctness stage. Batch 15
starts by reading `inst/design/release_ci_playbook.md`.

## Ticket-Cut Decisions

- The maintainer accepted the spec on 2026-09-16 after two independent reviews;
  the re-review's N1 patch keys the status default on row presence.
- The old runtime paths ship in no form: they exist only until the Batch 4
  parity record and then only as test-only references outside installed code.
- `ledgr_facts_resolve()` and `ledgr_facts_history()` keep their direct engine;
  the source guard removes the retired builder, view assembly, members wrapper,
  and unused family resolvers, not the public inspection helpers.
- The diagnostic chunk capacity is 4,096 in production and injectable only
  through the unexported constructor or a mocked internal binding.
- The equity-prefix merge applies only to availability-aware runs whose
  invocation equity does not cover the achieved prefix; dense runs keep full
  recomputation.
- The status validator is a pairwise-exact hybrid; membership and lifetime are
  plain state-aware sweeps.
- The peer `record` preset defaults are unchanged; the release command pins
  500 by 1,260, SMA 5/10, seed 20260530, and `--engine-set all`.
- Cold seal, warm availability, and peer records are three separate clocks;
  none is a public ranking and the seal estimate stays a forecast.
- The maintainer accepted the reviewed hot-path complexity amendment on
  2026-09-17. It raises the floor to collapse 2.1.8, adds only linear event
  writes and prepared fold-time valuation, and leaves every other audit
  finding outside this release.
- The records first run from `6b09a1b` are provisional diagnostic evidence.
  They cannot satisfy closeout and are rerun from accepted final source.
- Existing tail IDs LDG-2733 through LDG-2735 are preserved. Amendment
  work uses LDG-2736 through LDG-2740 and becomes their hard prerequisite.
- LDG-2733 and LDG-2734 form a separate final-measurement checkpoint. Their
  reviewed results and an explicit maintainer go-ahead are prerequisites for
  the LDG-2735 release gate, even though no new ticket ID is required.
- The maintainer accepted the trusted-timestamp and benchmark-boundary
  amendment on 2026-09-18 after independent review and focused re-review.
- The required pre-cut probe is committed at `9686229`. All ten semantic
  comparisons were exact, but the session-close candidate ratio was 0.763561
  against the preregistered 0.20 ceiling. Its binding outcome is `NEITHER`:
  no availability-ingestion optimization enters this release.
- LDG-2741 through LDG-2744 implement only the public benchmark correction,
  dense validation, snapshot-hash deduplication, and proof-template
  finalization. Existing final-record and release IDs remain LDG-2733 through
  LDG-2735.
- The first Batch 10 record and corrected working-tree figures remain
  diagnostic history. Only Batch 14 may create the final accepted-source
  records, and Batch 15 remains blocked on their independent review and
  explicit maintainer acceptance.

## Batch 0 - Packet Alignment And Ticket Cut

Status: Complete After Review.

Tickets:

- LDG-2719

Scope:

- record maintainer acceptance and apply the N1 spec patch;
- allocate LDG-2719 through LDG-2735;
- record historical ticket-cut baseline
  `f0b847d02c2cf66a9871fdda119f55e0ccfd7e42`, package `0.2.0.1`, R 4.5.2 ucrt
  on `x86_64-w64-mingw32`, duckdb 1.4.3, testthat 3.3.1, collapse 2.1.7
  default and 2.1.8 isolated, without changing the `DESCRIPTION` support floor;
- create packet README, tickets, YAML, and this plan;
- align design index, roadmap, horizon, AGENTS, NEWS, and doc-contract
  pointers;
- make no runtime or public-API implementation change.

Review focus:

- every spec section, matrix row, release gate, and the N1 patch has a ticket
  owner;
- Markdown and YAML agree on IDs, statuses, dependencies, and batches;
- no implementation or test result is claimed.

Exit criteria:

- independent ticket-cut review accepts the packet.

Closeout: accepted by the maintainer on 2026-09-16 after the independent
ticket-cut corrections landed in `e1ae717`; an additional Claude review was
explicitly waived for this planning-only batch.

## Batch 1 - Witnesses And Test-Only References

Status: Complete After Review.

Tickets:

- LDG-2720
- LDG-2721

Scope:

- port the spike scenarios and provider-parity coverage into durable tests
  with frozen expected rows;
- retain the pairwise validators and old provider and writer logic as
  test-only references;
- rerun the three spike checkers against the baseline and record results.

Review focus:

- each ported test fails on a perturbed value;
- no retained reference is reachable from installed code;
- the frozen rows carry the named reviewer.

Exit criteria:

- ported tests pass against the baseline under both arms; checker results are
  recorded.

Implementation evidence: `batch1-baseline-evidence.md`.

Closeout: accepted by the maintainer after the independent re-review passed
the option-containment correction at `bdcab66` with no new findings.

## Batch 2 - Prepared Provider

Status: Complete After Review.

Tickets:

- LDG-2722
- LDG-2723

Scope:

- productionize the two measured membership shapes, the CSR family planes,
  cursors, and the tie and default rules;
- route the fold, `availability` result view, and `ledgr_run_open()` through
  the production build; keep the public inspection path independent.

Review focus:

- membership headers keep processing order with a separate eligibility cursor;
- no CSR membership design or unmeasured cursor is introduced;
- provider-only, fold-scenario, and result/reopen parity hold.

Exit criteria:

- independent review accepts the provider boundary before Batch 4.

Implementation evidence: `batch2-provider-evidence.md`.

Closeout: accepted by the maintainer after independent review passed the
production default, consumer boundaries, provider parity, public-inspection
independence, and the honestly retained resumed-reopen limitation. The review
artifact remains inline rather than in this packet.

## Batch 3 - Diagnostic Writer And Block

Status: Complete After Review.

Tickets:

- LDG-2724

Scope:

- productionize the typed writer with production capacity 4,096 and the
  internal test-only capacity;
- construct one ordinary diagnostic block per pulse; keep the error row
  outside the block-writer path;
- cover chunks, rollback, interruption, resume, and both collapse versions.

Review focus:

- exact row order, sequence, and schema on every case;
- committed prefix plus one error row after every failure;
- no option, public argument, or identity input for capacity.

Exit criteria:

- independent review accepts the writer boundary before Batch 4.

Implementation evidence: `batch3-diagnostic-evidence.md`.

Closeout: accepted by the maintainer after independent review passed the
production default, constructor-only capacity, chunk lifecycle, rollback and
resume witnesses, dual-collapse evidence, and deterministic replay. The
review's one Low observation is a Batch 4 pre-retirement condition: exercise
failed-append retention directly through `append_block()` before removing the
scalar reference arm. The review remains inline rather than in this packet.

## Batch 4 - Production Parity And Retirement

Status: Complete After Review.

Tickets:

- LDG-2725
- LDG-2726

Scope:

- run the two-arm checkers and the six-table persisted parity against the
  production candidate; record the paired same-session warm measurement;
- retire the old paths and spike options; activate the source guard; keep the
  public inspection engine.

Review focus:

- every persisted table identical with exactly three exclusions;
- the relative-spread criterion recorded by prefix before retirement;
- the production `append_block()` path directly retains its full chunk after
  an injected durable-append failure;
- no fallback, stamp, or option survives in installed code.

Exit criteria:

- parity record exists; source guard passes; regression net green.

Implementation evidence: `batch4-parity-evidence.md`.

Closeout: accepted by the maintainer after independent review passed the
pre-retirement record, six-table persisted parity, installed-path retirement,
public inspection separation, source guard, and direct production
`append_block()` failure witness. Three non-blocking review observations carry
into the Batch 5 preflight without widening its scope: remove the unused
`pulses_posix` writer parameter, make the installed-package guard scan
deparsed namespace bodies for retired spike tokens, and directly pin the two
diagnostic schema name vectors to each other. The retired provider and writer
spike runners are historical evidence and must not be planned for rerun. The
review remains inline rather than in this packet.

## Batch 5 - Resumed-Run Finalization

Status: Complete After Review.

Tickets:

- LDG-2727

Scope:

- merge the complete equity prefix for resumed availability-aware runs under
  the strict validator; keep dense runs on full recomputation.

Review focus:

- the merge is scoped to the fold-supplied equity path;
- every invalid merge fails before status changes and leaves prior rows
  recoverable;
- resumed `DONE` and `INCOMPLETE` runs reopen.

Exit criteria:

- independent correctness review accepts the repair.

Implementation evidence: `batch5-finalization-evidence.md`.

Closeout: accepted by the maintainer after independent review passed the
scope boundary, strict exact-prefix validation, atomic replacement and status
transition, dense-path exclusion, resumed-run reopen, and Batch 4
carry-forwards. Two non-blocking test observations carry into the Batch 6
preflight without widening its seal-validator scope: assert the distinct
failure messages for the malformed-prefix matrix and add the direct foreign
run-ID rejection witness. A zero-pulse finalization-only availability resume
continues to use event replay because that invocation supplies no fold equity;
the reviewer found no semantic divergence and accepted that behavior under
the spec's fold-supplied-equity boundary. The review remains inline rather
than in this packet.

## Batch 6 - Seal Validators

Status: Complete After Review.

Tickets:

- LDG-2728
- LDG-2729
- LDG-2730

Scope:

- equivalence harness; membership and lifetime sweeps; the status
  supersession-exact hybrid; complete-set setwise validation and bypass.

Review focus:

- agreement with the retained pairwise references on random and adversarial
  sets, including the X/Y/J and Y/Z shapes;
- no malformed set row is silently exempted;
- targeted seal fixtures pass and the structural check proves production no
  longer calls the pairwise validators; the registered full-scale seal is
  measured once, in Batch 8.

Exit criteria:

- independent review accepts the validators before final benchmark records.

Implementation evidence: `batch6-seal-validator-evidence.md`.

Closeout: accepted by the maintainer after independent review replayed all
6,000 randomized comparisons with zero mismatches and passed the focused
regression net. The review found three non-blocking edge and test-hardening
observations. The accepted correction grouped scope identity on its real
columns, classed missing states, and replaced the literal loop guard with
syntax-tree checks.
The registered full-scale cold seal remains owned by Batch 8. The review
remains inline rather than in this packet.

## Batch 7 - Benchmark Phases And Manuals

Status: Complete After Review.

Tickets:

- LDG-2731
- LDG-2732

Scope:

- split the peer ingestion phase and reconcile clocks;
- refresh the optimization and benchmark manuals; the record-specific peer
  README and tracked-report update waits for the Batch 8 record.

Review focus:

- per-engine phase definitions with honest unavailability;
- every anchor resolves; no forecast, ranking, or unrecorded record prefix
  appears as a claim.

Exit criteria:

- renders reproduce; documentation-contract tests pass.

Implementation evidence: `batch7-benchmark-manual-evidence.md`.

Closeout: accepted by the maintainer after the initial review and focused
correction review both passed. The phase labels, Zipline teardown attribution,
availability-provider boundary, rendered manuals, and documentation contracts
were independently verified. The release-sized records remain owned by Batch
10. Reviews remain inline rather than in this packet.

## Batch 8 - Linear Event Buffers

Status: Complete After Review.

Tickets:

- LDG-2736
- LDG-2737
- LDG-2738

Scope:

- freeze both current event writers as test-only oracles;
- compare the corrected collapse 2.1.8 direct route with the temporary
  unbind/rebind control and raise the package floor only after it passes;
- make the direct linear route production for memory and durable handlers;
- prove the complete semantic, failure, capacity, scaling, and memory gates;
- preserve the accepted evidence prefix, retire every old/control path, and
  activate the source guard.

Review focus:

- exact full-schema and persisted-output parity under forced GC, failures,
  interruption, resume, and reopen;
- both handlers meet the 0.60 wall and 1.35 normalized-cost gates without
  exceeding the paired peak-memory allowance;
- collapse 2.1.8 is the real minimum and no control, old writer, fallback,
  option, stamp, or 2.1.7 branch survives.

Exit criteria:

- immutable paired event evidence exists, the retirement commit cites it, the
  source guard passes, and independent review accepts Batch 8.

Implementation handoff: the production route, dependency floor, semantic and
failure matrix, five-point scaling curves, paired 500-instrument record, and
source guard are complete in
`batch8-event-buffer-evidence.md`. Independent review passed and the maintainer
accepted Batch 8.

## Batch 9 - Prepared Availability Valuation

Status: Complete After Review.

Tickets:

- LDG-2739
- LDG-2740

Scope:

- prepare the instrument-row map, last finite close, source position/time, and
  staleness age once per run;
- replace repeated matching and price-prefix rescans with monotone `O(N*P)`
  fold state while retaining the old function as a temporary test oracle;
- prove the semantic and structural matrices, the paired 757-pulse gate, and
  the combined eventful availability case;
- preserve the accepted evidence prefix, retire the oracle and selector, and
  extend the source guard.

Review focus:

- exact gaps, staleness, membership, held-former-member, terminal, stop,
  resume, reopen, dense-path, persistence, and identity behavior;
- `wall_seconds` at most 0.80 of the paired current arm, spread and memory
  gates, and no hidden matching or prefix scan;
- both amendment corrections operate together under non-zero fills and cost.

Exit criteria:

- immutable valuation and combined-case evidence exists, the retirement
  commit cites it, the source guard passes, and independent review accepts
  Batch 9.

Implementation handoff: the transient production state, observed-work gate,
paired 757-pulse gate, combined eventful case, oracle-retirement history, and
source guard are complete in `batch9-valuation-evidence.md`. Independent review
passed and the maintainer accepted Batch 9.

## Batch 10 - First Closeout Attempt

Status: Diagnostic History.

Tickets completed: None. LDG-2733 and LDG-2734 remain Pending.

The record from source `400a3e5` correctly exposed the benchmark-boundary
defect and additional bounded costs, but it cannot satisfy final evidence. Its
artifacts keep their original identities and roles. They may be cited as
diagnostic history only; they are not independently promoted, relabelled, or
used as release claims.

## Batch 11 - Public Boundary And Oracle Freeze

Status: Complete After Review.

Tickets:

- LDG-2741

Scope:

- make public one-candidate `ledgr_sweep()` the two peer-comparable memory
  methods and retain private-fold rows as internal diagnostics only;
- freeze compensated production-inline equity, exact fills/trades, the
  existing equity tolerance, phase order, and missing-peer rendering;
- freeze dense and hash current-arm oracles and timing prefixes; and
- bind prerequisite commit `9686229` and prove no availability-ingestion
  source change under `NEITHER`.

Review focus:

- public method and complete public-call clock;
- authoritative parity reference and no tolerance widening;
- historical rows are not renamed or promoted; and
- all next-stage oracles and prefixes predate production changes.

Exit criteria:

- LDG-2741 passes an independent review; no dense or hash implementation has
  started before that review.

## Batch 12 - Dense Timestamp Validation

Status: Complete After Review.

Tickets:

- LDG-2742

Scope:

- replace per-bar timestamp formatting with one primitive conversion per
  instrument axis while preserving the dense rectangle proof;
- implement the accepted missing, non-finite, and sub-second failure rules;
- prove the complete semantic and consumer matrix; and
- pass the mutation-sensitive structural gate and paired public canonical and
  compiled performance record before retiring the old production path.

Review focus:

- exact supported semantics and deliberate unsupported-input tightening;
- zero per-bar formatting and a mutant that fails the structural gate;
- same-session 0.10, 10-second, spread, and peak-memory gates; and
- singular production source with unchanged public, identity, and
  availability surfaces.

Exit criteria:

- LDG-2742 passes independent Stage M code review before Batch 13 begins.

## Batch 13 - Snapshot-Hash Timestamp Deduplication

Status: Pending.

Tickets:

- LDG-2743

Scope:

- format each distinct timestamp once within each existing hash chunk and map
  it back without changing emitted row order or any byte;
- prove all registered rules, chunk boundaries, old snapshots, reopen, run
  guard, tamper, formatter-count, wall, and peak-memory cases; and
- remove OPT-L01 rather than change a hash or version if identity fails, while
  retaining the `NEITHER` availability branch without source changes.

Review focus:

- byte and hash identity is absolute;
- no cross-chunk cache, fallback, selector, or hash-rule change;
- performance gates are same-session and follow identity; and
- the exact-parity proof template is used as evidence, not authority.

Exit criteria:

- LDG-2743 passes independent Stage N code review before final evidence.

## Batch 14 - Proof Template And Final Evidence

Status: Pending.

Tickets:

- LDG-2744
- LDG-2733
- LDG-2734

Scope:

- independently review, finalize, index, and contract-lock the exact-parity
  proof template;
- freeze one exact accepted-source commit after all code and template work;
- from that commit rerun availability warm, cold seal, snapshot-hash paired,
  final profile, and peer records under new immutable prefixes; and
- render the corrected public-workflow report with explicit phase order and
  missing unavailable times.

Review focus:

- the proof template cannot authorize implementation by itself;
- all final records share the accepted source commit and declare clocks,
  environment, load, parity, spread, and peak memory;
- compensated production-inline equity is the new stated reference; and
- diagnostic records are retained but not promoted.

Exit criteria:

- Stage O evidence passes independent review; execution stops for an explicit
  maintainer decision. Batch 15 remains unauthorized until that acceptance.

## Batch 15 - Release Gate

Status: Pending.

Tickets:

- LDG-2735

Scope:

- after explicit maintainer authorization, run every base-spec, hot-path
  amendment, and timestamp-amendment release gate;
- run the full suite, source build/check, documentation rendering, governance
  reconciliation, compatibility/source guards, and artifact review; and
- write the closeout citing only accepted Batch 14 final record prefixes.

Review focus:

- Batch 14 was independently reviewed and explicitly accepted first;
- `NEITHER` caused no availability-ingestion source change;
- no benchmark waives correctness, identity, hash, quarantine, rollback,
  resume, reopen, dependency, retirement, or authority boundaries; and
- local, branch, main, and tag evidence remain distinct.

Exit criteria:

- release closeout written; branch ready for remote branch CI.
