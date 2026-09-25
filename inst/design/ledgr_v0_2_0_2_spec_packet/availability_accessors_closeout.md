# Cut 9 Closeout: Availability And Evidence Accessors

**Status:** Agent-provisional and ready for Type 1 close review. Implementation
and the registered fast timing gate are complete; independent close review has
not run.

**Implementation range:** `5373433..058d569` on
`codex/ws16-v0.2.1.0`. The range contains one commit per ticket plus three
corrections found by the full gate and its anti-pattern audit:

| Ticket | Commit | Claim and detector |
| --- | --- | --- |
| LDG-2826 | `ca3f8a9` | LCL-0061 / LTB-0061 |
| LDG-2827 | `6fe0283` | LCL-0062 / LTB-0062 |
| LDG-2828 | `11cb5fb` | LCL-0063 / LTB-0063 |
| LDG-2829 | `658e2b8`, `874bc3a` | LCL-0064 and LCL-0068 / LTB-0063 through LTB-0065 |
| LDG-2831 | `bb9c7e2` | LCL-0065 / LTB-0066 |
| LDG-2832 | `3457ce7`, `ea11db4`, `058d569` | LCL-0066 / LTB-0067 |
| LDG-2844 | `fdbbcce` | LCL-0067 / LTB-0068 |

## What Shipped

- `ctx$tradable()` returns the current sizing axis. Availability-aware
  contexts select ids whose existing admissible and priced planes are both
  true. Dense contexts select finite positive current closes. No private
  eligibility calculation is duplicated.
- `ledgr_snapshot_quarantine()` exposes the exact sealed quarantine rows with
  a typed empty result. It derives no quality judgement.
- Omitting `ts_utc` from `ledgr_run_explain()` returns the persisted history
  for one instrument in pulse order. A scalar query for any returned timestamp
  remains identical.
- `ledgr_run_completion()` gives complete, incomplete and evidence-absent runs
  one typed answer, including the persisted exposure fields. It does not alter
  the fifty-two-field `ledgr_run_info()` surface.
- The signal and rebalance helpers now require the shipped vector planes.
  Their unreachable scalar fallbacks are gone. This is hygiene, not a speed
  claim.
- A strategy that calls one scalar accessor across at least 100 instruments in
  one pulse receives one `ledgr_scalar_accessor_loop` warning per run. Small
  universes retain the original untracked closures, and the diagnostic changes
  no result or identity.
- The composition report queries only the position-changing event kinds for
  affected parent instruments, decodes the selected metadata once, reuses it
  for entitlement, and aggregates modeled cash once by source fact.

## Failure-Sensitive Evidence

LTB-0061 derives `ctx$tradable()` independently from the public planes in both
context modes and exercises the empty axis. LTB-0062 compares the public
quarantine reader with a direct persisted-row query. LTB-0063 compares every
history row with a separate scalar explanation and also carries the completed
completion branch. LTB-0064 and LTB-0065 compare incomplete and absent
completion evidence with their independent persistence states.

LTB-0066 poisons the obsolete scalar helper paths. LTB-0067 observes the
warning through a public run, compares warned and suppressed outputs and
hashes, checks plane-only and fixed-small access, and poisons the tracking
function below the universe threshold. LTB-0068 observes one metadata decode
over selected events, includes an unrelated held instrument, asserts literal
composition values, and rejects the old per-fact `which()` scan.

The LDG-2844 gut pass produced the intended failures independently:

- removing metadata reuse produced two decode-count failures;
- removing the parent predicate exposed the unrelated instrument and caused
  the unheld-parent path to decode events; and
- restoring `which(source_fact_id == fact_id)` produced two structural
  failures.

The first full fast run also rejected one mixed-profile registry claim before
closeout. LCL-0064 now owns the heavy incomplete and absent branches; LCL-0068
owns the review-profile completed branch. A later full-gate run exposed an
unnecessary tracking call below 100 instruments. The helper bundle now installs
the original closures there, and LTB-0067 fails if the tracker returns. The
follow-up anti-pattern audit found the same impossible path one level higher:
the fold still allocated mutable tracking state and advanced it every pulse for
small universes. Those runs now carry no tracking state. LTB-0067 asserts the
absence, and its public run fixture uses the minimum two pulses needed to
distinguish once-per-run from once-per-pulse behavior.

## Documentation Result

The source and rendered missing-data article now use `ctx$tradable()`,
`ledgr_snapshot_quarantine()`, full-history and scalar forms of
`ledgr_run_explain()`, and `ledgr_run_completion()`. The direct SQL and manual
completion-field assembly that triggered the cut are gone. The strategy
authoring and development articles document the scalar-access warning and its
vector remedy; the obsolete scalar-fallback sentence was removed.

## Performance Records

The scalar warning's preregistered plane-only clock used 2,000 instruments and
30 pulses. Alternating before runs were 3.38, 3.33 and 3.44 seconds; after runs
were 3.58, 3.39 and 3.41. Medians 3.38 and 3.41 differ by 0.03 seconds, less
than both observed ranges. This is no distinguishable plane-path regression.

The LDG-2844 same-session clock used 40 relevant corporate-action events:

| Ledger events | Arm | Selected | Query | Decode | Group | Total report |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 100,000 | before | 100,000 | 0.05 | 0.89 | 0.09 | 1.15 |
| 100,000 | after | 41 | 0.01 | <0.01 | <0.01 | 0.01 |
| 300,000 | before | 300,000 | 0.08 | 2.97 | 0.29 | 4.14 |
| 300,000 | after | 41 | 0.02 | <0.01 | <0.01 | 0.02 |

Values are three-run medians in seconds. Zeros were below elapsed-clock
resolution. These are composition-report gains and are not extrapolated to
`ledgr_run()`.

The first anti-pattern correction still left the registered fast gate red:
`.tmp/ws16-fast-corrected` recorded 101.83, 101.00 and 103.07 seconds, median
101.83. A same-host run of the exact pre-workstream commit `5373433` took 98.46
seconds. Inspection then found the impossible state allocation and per-pulse
advance described above, plus one redundant detector pulse. After both were
removed, `.tmp/ws16-fast-final` passed all 456 blocks with no skips or failures
in 83.61 seconds. The independent checker reported
`LEDGR_TEST_GATE_OK mode=ordinary runs=1 median=83.610 bound=90.000`; the
one-run rule therefore applies and no favorable median was selected.

The test audit did not remove or move any oracle. LTB-0067's four public runs
cover distinct claims: warning multiplicity, output identity, plane-only
silence and fixed-small-access silence. Two pulses are the minimum for the
first claim. The remaining longest fast blocks predate this cut and protect
schema migration, fixed-work hashing, compiled parity and walk-forward error
recovery; they were not weakened under cover of this timing correction.

## Boundaries And Declined Additions

No database schema, persisted row, configuration or strategy hash, error
class, economic policy, event vocabulary, or existing result column changed.
The only new condition class is the documented diagnostic warning. No existing
contract was weakened; the public surface is additive except for deletion of
unreachable internal fallbacks.

The cut declined a second eligibility computation, a derived quarantine
quality score, a replacement for `ledgr_run_info()`, a configurable warning
threshold, a new public composition-report API, and the separate deferred
resume-path optimization LDG-2820.

## Governance

No review invocation has run yet. The requested close review is one invocation
over eight completed tickets, 0.125 against the 0.5 gate.
