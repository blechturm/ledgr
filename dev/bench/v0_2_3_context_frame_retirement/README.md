# Context-frame retirement evidence

This directory records the Workstream 20 correctness profiles for LDG-3195.
The implementation removes eager pulse-context frames and materializes the two
inspection views from frozen primitives only on request.

Final reviewed-candidate records:

- `evidence/fast_profile_correction_376ae796`: ordinary fast profile, 635/635
  blocks, 362.27 seconds. The advisory 112-second timing hint was exceeded; the
  maintainer has made correctness the measure while the test suite is being
  redesigned.
- `evidence/review_profile_correction_376ae796`: ordinary review profile,
  524/524 blocks, 1513.06 seconds, with one registered optional-package skip.

The earlier `fast_profile_exact` and `review_profile_exact` directories record
the pre-correction `fc9cf955` candidate and are retained as superseded review
evidence.

A bounded post-review timing on the registered Windows host compared 10,000
calls in five pairs. Reparsing one ISO timestamp through `ledgr_utc()` took a
median 2.400 seconds (about 240 microseconds per call); reading the already
prepared numeric `POSIXct` value was below the timer's resolution. This is
diagnostic evidence for removing the reparse, not a package performance gate.

Reproduction:

```text
Rscript tools/run-test-profile.R --profile=fast --mode=ordinary --records=dev/bench/v0_2_3_context_frame_retirement/evidence/fast_profile_correction_376ae796 --run-index=1
Rscript tools/run-test-profile.R --profile=review --mode=ordinary --records=dev/bench/v0_2_3_context_frame_retirement/evidence/review_profile_correction_376ae796 --run-index=1
```

## Workstream 21 migration and closure

The durable WS21 profile records are:

- `evidence/fast-ws21-ae289ce0-{census,summary}.csv`: 635/635 blocks,
  zero skips and zero failures in 364.830 seconds;
- `evidence/review-ws21-ae289ce0-{census,summary}.csv`: 524/524 blocks,
  one registered optional-package skip and zero failures in 780.030 seconds.

Both passing records used the explicit supported Windows locale
`English_United States.utf8`. The first review-profile attempt under the
process's default locale passed 520 blocks, failed three inherited UTF-8
decoding blocks and skipped one optional-package block. It is retained as an
environmental observation, not reported as a passing profile.

The exact commands, locale and source identities are in
`evidence/ws21-provenance.yml`. The response probe's after-clock calls the
small list construction the **hand-copied primitive list bind**. It is a
descriptive comparison, not a P2 implementation or a timing gate.
