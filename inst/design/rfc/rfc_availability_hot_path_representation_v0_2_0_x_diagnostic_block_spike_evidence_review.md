# Availability Hot-Path Representation - Diagnostic Block Spike Evidence Review

**Status:** Independent post-execution review under `spike_protocol.md`
Section 7. **Reviewer:** Codex; not the spike executor or Charter author.

## Reviewed source state

- Branch `v0.2.0.1`; HEAD
  `b0fe6b8fb8c44981ad9fc6f8692ce076be72e764`.
- Reviewed the uncommitted two-file diagnostic seam, runner, checker,
  inventory, and twelve evidence CSVs. Nothing was staged or pushed, and the
  RFC index remained untouched.
- The runner and checker total 890 lines. With 275 added seam lines, the
  Charter-counted total is 1,165 R lines, inside the 1,500-line budget.

## Verdict

**PASS_WITH_LOW_OBSERVATIONS.** The evidence supports the Charter's **GREEN**
answer. Building one typed diagnostic block per pulse preserves the registered
semantics, meets the absolute and relative envelopes, and removes diagnostic
writing as the leading in-loop lane. No correction round is required.

This verdict closes only the diagnostic-block question. It does not adopt the
spike seam, make a peer-performance claim, or complete the RFC.

## Section 7 actions

1. **Rerun and exact diff.** The independent checker completed in 539.2
   seconds under R 4.5.2 and collapse 2.1.8. It regenerated all six
   deterministic CSVs byte-for-byte and passed all 54 checks. The regression
   net ran 85 deterministic tests plus the optional mirai test under each arm,
   with no failure, error, or skip on this host.
2. **Gut the deciding mechanism.** I temporarily replaced `append_block()`
   with a row loop that called the existing scalar writer once per diagnostic.
   All sixteen semantic scenario rows still agreed, but the block-path call
   count exceeded its registered bound and the checker revoked GREEN with a
   nonzero exit. The production files were then restored to their exact
   pre-gut SHA-256 values.
3. **Inspect semantic and persisted parity.** Both arms agree on diagnostics,
   events, equity, strategy state, completion, and normalized run identity in
   every semantic scenario. The non-measured 757-pulse pair also agrees by
   DuckDB multiset comparison across all six persisted tables: 383,042
   diagnostics, zero events, 757 equity rows, and 757 state rows.
4. **Recompute the decision.** Current-arm wall times are 94.36, 93.71, and
   94.50 seconds; block-arm times are 25.11, 24.93, and 24.88 seconds. The
   24.93-second block median is 69.43 seconds below the current median, well
   beyond the current arm's 0.79-second spread and below the 60-second ceiling.
   All block peaks, 745.4 to 799.5 MiB, are below 1,024 MiB.
5. **Verify containment.** `git diff --check` is clean. The index is empty.
   The only package-code changes attributed to this spike are the two declared
   seam files, at +275/-35. Reviewer scratch evidence and environment files
   were kept outside the repository and removed after verification.

## What the evidence establishes

- The alternative constructs one typed block per pulse: 757 block
  constructions and zero scalar diagnostic constructions in every measured
  run, versus 383,042 scalar constructions under the current arm.
- Full semantic coverage includes restrictions, stale-mark risk, missing and
  final-pulse no-fills, a fill, affordability reconciliation, rollback, resume,
  and DONE, INCOMPLETE, and FAILED outcomes. The opening-halt case is covered
  by the regression net as authorized by the final Charter review.
- The optimized warm fold is 3.79 times as fast as the current arm on the
  registered workload, a 73.6 percent wall-time reduction.
- Valuation is now the largest captured in-loop lane at 67.6 percent;
  diagnostics fell to 10.3 percent and the prepared provider to 1.4 percent.
  That is the correct routing signal for any further performance spike.

## Low observations and RFC routing

The registered 757-pulse performance fixture is deliberately flat and creates
no fills. The semantic suite covers eventful behavior, but 24.93 seconds is a
warm research-iteration result for this fixture, not an eventful-population or
peer-engine benchmark.

Cold sealing took 748 seconds and remains outside this comparison. The separate
seal probe attributes that cost to the quadratic fact-conflict validator; the
RFC synthesis should retain that work as a distinct bounded correction rather
than dilute this warm-fold result.

The review also reproduced the pre-existing package defect in both arms:
reopening an interrupted-then-resumed INCOMPLETE run fails terminal-evidence
validation because finalization does not retain the full equity prefix. Carry
it into release planning; it is not caused by the diagnostic block.

The diagnostic-block result is accepted input to RFC synthesis. If the RFC
opens one more performance question, the evidence now makes valuation the
only justified next lane; it should be a separately chartered spike rather
than an extension of this one.

DIAGNOSTIC_BLOCK_SPIKE_EVIDENCE_REVIEW_DISPOSITION: PASS_WITH_LOW_OBSERVATIONS
