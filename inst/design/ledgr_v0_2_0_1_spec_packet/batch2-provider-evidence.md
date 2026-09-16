# Batch 2 Prepared Provider Evidence

**Tickets:** LDG-2722 and LDG-2723
**Implementation base:** `93b627cabe6b450cc6549dffbc35c048f0cdbc5f`
**Runtime:** R 4.6.1, duckdb 1.5.2, testthat 3.3.2, collapse 2.1.8
**Status:** Implemented; awaiting independent review.

## Production boundary

The reviewed prepared provider is now the ordinary runtime default. Canonical
sparse fact tables remain the durable truth; each provider instance compiles
its own membership state and status, lifetime, and terminal-event segment
tables before serving views. The temporary option seam, the old provider, and
the `spike_arm` observation remain only until the Batch 4 final parity gate.

The production default requires no process option. The fold, portable sweep
and walk-forward workers, availability result view, and INCOMPLETE reopen path
all reach the shared constructor. Tests observe one prepared build for a fold,
one per public availability or explanation call, no build for a DONE reopen,
and one build for an INCOMPLETE reopen.

The result and reopen tests replace `ledgr_membership_resolve_at()` and
`ledgr_membership_evidence()` with failing sentinels while exercising a dynamic
membership universe. The production consumers still complete, proving those
public inspection helpers remain an independent reference rather than a
provider fallback.

## Durable parity

Package tests cover the production default, provider-instance cursor
isolation, backward and repeated cutoffs, fixed and membership-driven axes,
result and explanation views, direct and resumed folds, reopen behavior, and
the optional mirai availability sweep with no provider-selection option.

The resumed case preserves the known packet input honestly: both provider arms
produce identical active results and both fail reopen with
`ledgr_run_terminal_evidence_invalid` because the finalized store lacks the
exact achieved equity prefix. Batch 5 owns that correctness repair; Batch 2
does not weaken the validator or conceal the failure.

## Registered provider gate

The provider spike's parity phase was rerun in a separate scratch evidence
directory under R 4.6.1. It did not modify the reviewed evidence directory:

- 3,676 of 3,676 provider views were identical between the old and prepared
  arms;
- 1,988 of 1,988 revisited cutoffs returned identical prepared answers;
- 602 of 602 membership cutoffs agreed with `ledgr_facts_resolve()`; and
- regenerated `fixture.csv` and `cutoff_parity.csv` were byte-identical to the
  reviewed evidence files.

The phase took 246 seconds wall. Most of that clock is fixture construction
through the known quadratic cold seal validator; it is not provider-query
performance evidence and makes no speed claim.

## Package verification

The complete `test-availability-*.R` regression net passed under R 4.6.1 in
274.3 seconds with zero failures or warnings. The installed mirai dependency
allowed the optional parallel availability-sweep test to run rather than skip.
Focused provider witness and production-boundary tests also passed separately.

No 757-pulse performance protocol, full package suite, cold-seal benchmark, or
peer benchmark was run in this batch. Those clocks belong to later gates.
