# Spike Inventory: Compiled Availability Accounting

Executor inventory for LDG-2992. The runnable fork is based on accepted
Workstream 24 at `437b73d3`; it is evidence only and is not merged by Cut 11.

## What Ran

| Artifact | Role | Evidence |
| --- | --- | --- |
| `probe.R` | Prerequisite fold-share measurement, run before fork code | `prerequisite.csv` |
| `spike_runner.R` | Three public one-candidate sweeps, each through canonical R and the hybrid fork; captures the emitted in-memory ledger and final fold state | `evidence/cases.csv`, `evidence/clocks.csv` |
| `spike_checker.R` | Clean-tree rerun, deterministic CSV diff, arm parity, gut, size and scope guards | Prints `SPIKE CHECK OK` |

The retained cases came after the fork first ran: an availability-aware fill
round trip; an availability-active cash dividend alongside a sale; and a
frozen terminal write-off alongside a sale. Each evidence row contains the
economic sweep result, ordered events and their accounting attributes,
retained returns and trades, diagnostics, completion and final lot state.
The same runner has an optional aggregate-only Sharadar clock mode. It writes
no source row, identifier, price or action value.

## One Seam

`ledgr.spike.compiled_availability` is the only injection switch. It lifts the
public availability refusal and the up-front corporate-action-kind refusal.
The ordinary pulse-plan guard remains FILL-only. The existing fold therefore
sends fills through `ledgr_run_compiled_spot_fifo_batch()` while its existing
corporate-action and terminal code posts non-FILL events through canonical R
before the strategy/fill accounting step. No second engine exists.

The fork changes only `R/compiled-spot-fifo.R`, `R/fold-engine.R` and
`R/sweep.R`. The switch defaults off, so the released refusal remains intact.

## Gutted Path

The checker wraps the compiled batch and adds one unit to its first emitted
event quantity without changing canonical R. All three hybrid `events_json`
rows then differ while every canonical row remains exact. The gut proves the
record is sensitive to a corrupted compiled event; counts of passes are not
used as evidence.

## Demoted

- Dense compiled arithmetic is already owned by LCL-0006 and is not rebuilt
  here. This spike tests the availability/non-FILL composition boundary.
- Synthetic clocks locate harness overhead only. They are not a package
  ranking or the answer to the performance question.
- Compiled durable `ledgr_run()` remains out of scope. The question is the
  memory-backed one-candidate sweep named by the ticket.

## Deleted

- No new public option, accounting model, fold engine, snapshot manifest,
  registry or expected-value table.
- No package test or release-branch source change.
- No private identifier, price, action value or Sharadar row enters Git.

## Learned About the Package

- The shared state already exists. Corporate-action cash and lifetime
  disposition mutate the same `state` and lot state used by the later compiled
  fill batch.
- The FILL-only guard is broader than the kernel boundary: it rejects a plan
  whose non-FILL events are already executed by canonical R outside the batch.
- On all three retained cases, canonical and hybrid economic results, events,
  event accounting attributes, returns, trades, diagnostics, completion and
  final state are exact after removing run/sweep identity and clocks.
- The remaining empirical question is effect size on the registered Sharadar
  momentum and equal-weight workloads. Only aggregate paired clocks may be
  recorded from those private inputs.
