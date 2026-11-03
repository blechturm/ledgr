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

Reproduction:

```text
Rscript tools/run-test-profile.R --profile=fast --mode=ordinary --records=dev/bench/v0_2_3_context_frame_retirement/evidence/fast_profile_correction_376ae796 --run-index=1
Rscript tools/run-test-profile.R --profile=review --mode=ordinary --records=dev/bench/v0_2_3_context_frame_retirement/evidence/review_profile_correction_376ae796 --run-index=1
```
