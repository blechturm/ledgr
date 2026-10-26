# Workstream 62 focused final confirmation

**Mode:** Focused Type 1 confirmation

**Range:** `6faecbaa..762b551d`

**Reviewer:** fresh-context Claude Opus, high effort

**Verdict:** `CHANGES_REQUIRED`

## Result

The product correction is sound. Schedule identity rejects incomplete or
mismatched current records, accepts authored-only identity only when a failed
candidate's parameterized schedule cannot resolve, and preserves strict
successful-candidate behavior. Matching scheduled promotion is warning-free;
schedule presence and rule differences still warn through the registered
identity-mismatch path. The four focused suites, YAML and diff checks passed.

Two low detector gaps remained:

1. LTB-0508 recursed through lists but skipped data-frame columns, so a nested
   `decision_due` field could pass the no-transport assertion.
2. The widened FAILED-row reader had no witness whose non-schedule failure
   class accompanied an unresolvable schedule, and no opposite witness that a
   resolvable FAILED row with authored-only provenance still refuses.

The correction includes data-frame columns in the recursive transport scan and
adds both persistence-boundary witnesses. It also promotes the separately
reported WS62 identity-build and reopen-validation cost from LDG-3114 scope to
an acceptance item. These are test and record changes only; no further product
change is authorized.
