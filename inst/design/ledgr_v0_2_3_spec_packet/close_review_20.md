# Workstream 20 Close Review

**Mode:** Type 1 close review  
**Verdict:** CHANGES_REQUIRED  
**Range reviewed:** `bfd34ef1..fc9cf955`

The primitive-only direction is accepted and no Type 2 issue was found. The
implementation removes the eager frames and preserves the public results, but
the evidence did not yet detect all load-bearing claims.

## Findings

1. **F1, high:** readable feature names were rebuilt on every field read.
   Prepare their ordered enumeration and hashed membership once per run or
   sweep candidate and reuse them. Bind the ticketed projection ordinal and
   numeric cutoff in the private lookup as well.
2. **F2, high:** only 6 of 14 review mutations were detected. Add registered,
   smallest witnesses for recursive frame capture, per-read name rebuilding,
   explicit-map memo reuse, mapped and unmapped order, retired alias metadata,
   print/error frame construction and row-wise timestamp normalization. Pin a
   real missing bar, exact error feature IDs and the printed Daxis.
3. **F3, medium:** the retained-close assertion compared a post-run value with
   itself. Compare the retained context with an independent input oracle so a
   live fold-buffer capture fails.
4. **F4, medium:** the fixture adapter no longer rejected foreign instruments
   or mismatched feature timestamps. Restore both checks with one vectorized
   timestamp normalization.
5. **F5, low:** explain the fixture timestamp assignment and give LDG-3196
   explicit ownership of removing LTB-0091's temporary four-row exclusion and
   restoring LCL-0091.
6. **F6, low:** delete the unreachable active-alias branch that can retain the
   context and obsolete frames through a closure.

The committed fast and review records are useful correctness records, but they
do not identify the exact candidate tree. Any successor record must do so. The
fast timing miss remains advisory and is not a correctness finding.
