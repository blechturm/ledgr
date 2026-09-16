# ledgr v0.2.0.1 Batch Plan

Status: Batch 0 implementation complete and awaiting review. Batches 1-8 are
pending.

Spec: `inst/design/ledgr_v0_2_0_1_spec_packet/v0_2_0_1_spec.md`
Tickets: `inst/design/ledgr_v0_2_0_1_spec_packet/v0_2_0_1_tickets.md`

## Review Protocol

A batch is the independent review unit. Ticket dependencies are the hard
readiness gate; numeric batch order is the default sequence. Batches 5 and 6
are independent of the warm seams and may run beside Batches 2 to 4; Batch 7
cannot start until Batches 4, 5, and 6 have closed, and Batch 8 cannot start
until Batch 7 has closed, because the hard edges say so. If a batch lands out
of order, status text must name the completed and blocked batches rather than
implying linear progress.

For implementation batches:

- implement only the listed tickets;
- add detecting assertions before correctness fixes;
- run targeted verification and the named regression net;
- update this plan, the ticket Markdown, `tickets.yml`, and the packet README;
- stop for independent review before commit unless the maintainer directs
  otherwise.

The spike protocol's correction budgets are stop signals. Batch 4 cannot retire
the old paths before its two-arm parity record exists. No benchmark number can
unlock a failed correctness stage. Batch 8 starts by reading
`inst/design/release_ci_playbook.md`.

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

## Batch 0 - Packet Alignment And Ticket Cut

Status: Review Pending.

Tickets:

- LDG-2719

Scope:

- record maintainer acceptance and apply the N1 spec patch;
- allocate LDG-2719 through LDG-2735;
- record baseline `f0b847d02c2cf66a9871fdda119f55e0ccfd7e42`, package
  `0.2.0.1`, R 4.5.2 ucrt on `x86_64-w64-mingw32`, duckdb 1.4.3, testthat
  3.3.1, collapse 2.1.7 default and 2.1.8 isolated;
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

## Batch 1 - Witnesses And Test-Only References

Status: Pending.

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

## Batch 2 - Prepared Provider

Status: Pending.

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

## Batch 3 - Diagnostic Writer And Block

Status: Pending.

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

## Batch 4 - Production Parity And Retirement

Status: Pending.

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
- no fallback, stamp, or option survives in installed code.

Exit criteria:

- parity record exists; source guard passes; regression net green.

## Batch 5 - Resumed-Run Finalization

Status: Pending.

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

## Batch 6 - Seal Validators

Status: Pending.

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

- independent review accepts the validators before closeout records.

## Batch 7 - Benchmark Phases And Manuals

Status: Pending.

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

## Batch 8 - Release Closeout

Status: Pending.

Tickets:

- LDG-2733
- LDG-2734
- LDG-2735

Scope:

- availability warm record and the single registered cold seal record; the
  explicit peer record with the peer README and tracked report updated from
  it; the Section 9 release gate and closeout, including the unchanged
  telemetry-name check.

Review focus:

- comparable host and cited pre-retirement pair;
- three separate clocks, three record prefixes, and the five peer-report
  fields;
- gates 1 through 10 hold and no benchmark waives gates 1 to 6.

Exit criteria:

- release closeout written; branch ready for remote branch CI.
