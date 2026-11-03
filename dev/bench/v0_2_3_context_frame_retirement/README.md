# Context-frame retirement evidence

This directory records the Workstream 20 correctness profiles for LDG-3195.
The implementation removes eager pulse-context frames and materializes the two
inspection views from frozen primitives only on request.

Final candidate records:

- `evidence/fast_profile_exact`: ordinary fast profile, 635/635 blocks,
  218.19 seconds. The advisory 112-second timing hint was exceeded; the
  maintainer has made correctness the measure while the test suite is being
  redesigned.
- `evidence/review_profile_exact`: ordinary review profile, 524/524 blocks,
  951.20 seconds, with one registered optional-package skip.

Reproduction:

```text
Rscript tools/run-test-profile.R --profile=fast --mode=ordinary --records=dev/bench/v0_2_3_context_frame_retirement/evidence/fast_profile_exact --run-index=1
Rscript tools/run-test-profile.R --profile=review --mode=ordinary --records=dev/bench/v0_2_3_context_frame_retirement/evidence/review_profile_exact --run-index=1
```
