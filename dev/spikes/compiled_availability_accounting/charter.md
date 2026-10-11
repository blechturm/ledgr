# Compiled Availability Accounting Spike

**Ticket:** LDG-2992. **Status:** executing. **Branch:**
`spike/compiled-availability-accounting-ws24`, forked from accepted Workstream
24 at `437b73d3`. This branch is evidence only and is not merged by Cut 11.

## Question

With the availability refusal lifted through one spike-only switch, can an
availability-aware, one-candidate sweep send fills through the compiled
spot-FIFO batch while terminal dispositions and corporate actions continue
through canonical R on the same lot state, with outputs equal to canonical R
under LCL-0006? If so, how much faster is the accounting path?

The spike compares only canonical R and this hybrid fork. It binds no public
API, default, contract, or release decision.

## Prerequisite

Workstream 22 fold telemetry had to show accounting at or above 10 percent of
pulse time. `prerequisite.csv`, produced before fork code, records 17.95
percent for Sharadar momentum and 41.59 percent for equal weight. The
prerequisite therefore passes.

## Fork

The fork may add one internal, spike-only switch. When off, package behavior
must remain unchanged. When on, it may bypass only the availability refusal
and the compiled FILL-only guard needed to leave non-FILL events on canonical
R. It must not create a second fold engine, change event order, bypass sealing
or verification, or alter canonical R.

The first runnable comparison precedes any frozen expected CSV, checker, or
witness list. Failures from that run determine the retained cases, capped at
ten.

## Kill Condition

Stop RED on either condition:

- accounting is below 10 percent of pulse time; or
- canonical and hybrid outputs diverge and the divergence cannot be explained
  within the single injection seam.

A missing shared-state capability or need for a second engine is an
unexplained divergence, not permission to enlarge the fork.

## Deliverables

Exactly three executor artifacts:

1. a runner that derives evidence CSV rows from actual one-candidate sweep
   outputs and writes paired clocks;
2. a checker that reruns into scratch space, diffs the recorded CSVs, guards
   `R`, `src`, `tests`, `NAMESPACE`, `DESCRIPTION`, `man`, and `inst/design`,
   and demonstrates one gutted path;
3. an inventory naming what was demoted, deleted, and learned, including the
   gutted-path result.

The one-page closeout states GREEN, RED, or INCONCLUSIVE against this charter.
Private Sharadar inputs never enter Git; only aggregate paired clocks may.

## Budgets

The R harness stays at or below 1,500 lines, the retained comparison at or
below ten cases, any correction below 500 lines, and the closeout at one page.
