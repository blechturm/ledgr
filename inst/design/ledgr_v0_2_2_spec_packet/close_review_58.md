# Workstream 58 close review

**Mode:** Type 1, independent clean-context close review  
**Range:** `25631b55..bfbcea8c`  
**Verdict:** `CHANGES_REQUIRED`

The compact rewrite is justified and uses existing public APIs without
inventing an optimizer, scheduler, manifest or orchestration layer. No Type 2
decision is required. The implementation, teaching path and economic evidence
are sound, but two correction items remain.

1. **The compact-path source oracle is not failure-sensitive.** LTB-0437
   counts only the exact text `feature = "return_1"` and does not reject raw
   `attr()` or `attributes()` access. A parse-valid mutation added a second
   executed return-matrix read with single quotes plus raw history-attribute
   access; the compact-path scans still passed. Make the check syntax-aware,
   require exactly one direct `ledgr_history_matrix()` call in the strategy
   independently of quoting and formatting, reject raw attribute access, and
   record both negative witnesses.
2. **The current private evidence runner commits a user-specific library
   path.** `experiments/minimum-variance-current-v001/run.R` prepends a local
   Windows package library, contradicting the evidence package's portability
   boundary. Remove it and let the invoking R environment use its normal
   library configuration.

## Acceptance assessment

- The clean executable article, eight visible parameters, compact strategy
  path, scheduling boundary, factor-evidence routing and integrated records
  pass review.
- The registered behavioral evidence passes, but the source detector fails
  acceptance until finding 1 is corrected.
- The current private estimator was rerun from current source and its aggregate
  checker passes, but the runner is not portable until finding 2 is corrected.

The review found no defect in the strategy economics, partial-history
admission, keep/liquidate behavior, durable intent reasons, covariance repair,
peer-harness correction, documentation agreement, optimization shapes or
identity-preserving package behavior. The pre-existing `head()` check NOTE and
the advisory fast-profile timing exceedance are recorded honestly.
