# Cut 6 Focused Re-review 1: One Execution Path

Role: finding-bearing focused cut re-review; evidence, not authority.
Reviewer: Claude (clean-context CLI session), 2026-11-01.
Mode: Type 1 with an input check, after `cut_review_6.md`
(`NEEDS_TYPE_2`) and the maintainer's choice of Option B.
Base: `b5622f09`; draft branch: `codex/cut6-ws4b`.

## Verdict: PASS_AFTER_PATCHES

Option B is now bound in decision (9), the identity and release-impact
statement, and the WS4b macro amendment. The draft chooses one execution
model and does not rename the dense profile. Most of the first review's
required and should-fix patches hold.

Twelve corrections remain. Eleven are mechanical consequences of Option B.
One public-surface consequence needs maintainer confirmation: whether the now
constant `ctx$availability_active` field is removed or retained as `TRUE`.
The reviewer recommends removal under the pre-CRAN policy.

After P1-P12 are applied verbatim, no further cut-review round is required.
The cut is then ready for maintainer acceptance subject to the amended
pre-acceptance evidence gate, whose results must be recorded first under
macro rule 11.

## Required patches

### P1. Out-of-scope contradiction

The cut cannot forbid the fixed-basket affordability, corporate-action,
valuation and supported-target changes that decision (9) requires. Limit the
prohibition to changing canonical declared-session rules and admit only the
fixed-basket changes named in decision (9)'s difference record.

### P2. Stale parity claims

The workstream review, LDG-3172 and LDG-3176 still describe only the four
earlier decisions. They must name decisions (1)-(5) and decision (9), including
the fixed-basket carry target that fills on the next window's first pulse.

### P3. Positive owners for every Option B row

Subset-only “differs only in” assertions can pass when a required difference
is absent. Require exact differences and assign positive witnesses:

- history and continuous carry: LDG-3172;
- context, empty targets, eligible helpers and short refusal: LDG-3173;
- affordability, decision/reconciliation/completion evidence,
  corporate-action INCOMPLETE, fold equity and non-finite refusal: LDG-3174.

LDG-3174 therefore owns P3-P5 and finalisation adoption as well as the final
pulse and identity rule, and becomes effort L.

### P4. Registered-oracle migration

Decision (8) must authorize an oracle change only for a named row of the
frozen difference record, in the owning ticket, with a stated reason. Retire
LCL-0300/LTB-0306 under LDG-3172 in favour of LCL-0298's common data-start
rule; update overlapping claim notes. Move short-admission tests to the
refusal oracle under LDG-3173. Census every other flipped claim in LDG-3170.

### P5. Timing protocol validity

The shared loader refuses infinite thresholds. Use a finite disposition
trigger per cell (proposed 1.10). A checker failure requires an attributed
milestone disposition but is not a ticket/workstream failure under macro rule
16. Do not edit the shared harness.

### P6. Memory-sink evidence

Do not require the memory sink to retain the full N-by-T decision trace. It
must retain the final-pulse rows and sequence values that a durable run records;
all other retained rows remain governed by its existing predicate.

### P7. Public context field

`ctx$availability_active` no longer distinguishes execution modes under Option
B. Recommended maintainer disposition: remove it from the public context and
update helpers, the context contract, first-pulse state wording and examples.
The alternative is documenting it as constant `TRUE` on every run.

### P8. Non-finite refusal timing

Deferred reconciliation formatting must not move the accepted
`ledgr_config_non_finite` refusal. Add an explicit typed finiteness check at
the same pulse and precedence, keeping the accepted prefix and diagnostic.

### P9. Predictive pre-acceptance gate

The base cannot directly produce candidate-minus-base differences. Before
acceptance, run every fixed-basket frozen fixture through an availability twin
with implied sessions, full membership, never-stale valuation and next-bar
timestamp remapping. Record every twin difference and cause. Include the
fixed-basket real-data workloads, strict-TTR preparation measurement and the
v0.2.2 timing-arm check in `cut_6_base_run.md`. Any unexplained difference is
settled in the cut before acceptance.

### P10. Maintained harness consumers

Migrate or explicitly retire the peer driver's internal-oracle lane when its
private dense helpers disappear. The RNG baseline probe remains historical
and is not rerun.

### P11. Constant-plane specialization

A specialization keyed on a prepared constant must be byte-identical to the
general path on the same input. LDG-3173 needs a force-general-path witness;
a specialization that skips a canonical rule or evidence row must fail it.

### P12. Review record

Advance the cut revision, add the two review rounds and links, and update the
opening and packet README. This finding-bearing review is the second round.

## Should-fix items carried into the exact patches

1. LDG-3172 adds terminal recovery, removes the pulse-snapshot
   availability-only refusal, and records clock kind and feature-engine
   version in precomputed payloads.
2. The implied/declared clock disclosure appears on plan, experiment, result
   summary and result print surfaces.
3. Rule-4 external objects refuse through the exact existing classes:
   `ledgr_invalid_config`, `ledgr_sweep_schema_incompatible` and
   `ledgr_walk_forward_invalid_session`.
4. The peer milestone covers all lanes, reusing unchanged peer records only
   when the protocol's host-drift control permits it.
5. A non-positive resolved price follows canonical behaviour; an existing
   `execution_bar_missing` row discovered by the twin is not suppressed.
6. The 140 `availability_active` occurrences are described across all 14
   production files without calling `run-snapshot.R` a largest owner.
7. The macro-plan header and WS4b change-control row name Option B.

## Checked and found clean

- The identity-rule binding changes the store fingerprint, so older stores,
  including snapshot stores, refuse and must be resealed; content hashes stay
  pinned.
- The final-pulse diagnostic is in the typed vocabulary and has a named memory
  retention owner.
- Constructor removal preserves the result class, result methods,
  `ledgr_backtest_bench()` and exact-name S3 exemptions.
- Strict coverage, implied-clock refusals, boundary fixtures,
  corporate-action-only preparation and per-fold build counts are owned.
- JSON routing and the `all.equal.numeric` boundary are explicit.
- Macro rule 16 supersedes the old per-workstream timing gate.

No product, timing or private-data workload was run in this review.

## Maintainer disposition after review

On 2026-11-01 the maintainer accepted removal of
`ctx$availability_active`, closing P7 as recommended. The maintainer narrowed
P9 after noting that dozens of accepted evidence scripts had already measured
the relevant inputs. `cut_6_evidence_reconciliation.md` now maps each decision
to that evidence and leaves candidate-only checks to LDG-3170 through
LDG-3178. This changes no product decision or evidentiary standard; it removes
an unnecessary replay before a candidate exists. P1-P8 and P10-P12 are applied
as reviewed.
