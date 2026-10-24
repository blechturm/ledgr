# Workstream 52 close review

**Mode:** Type 1 close review
**Reviewed range:** `0fd89a23..3187645b`
**Verdict:** CHANGES_REQUIRED

The implementation direction, output parity and H1 measurements hold. The
review found two evidence defects, not a product defect.

1. LTB-0484 through LTB-0487 and the filtering part of LTB-0063 guarded the
   new wrapper calls and returned rows, but did not guard the expensive
   operation inside each wrapper. Restoring the old scan, query, scalar
   formatter or full reader inside the wrapper left the owning block green.
2. The closeout's seven-shape walk did not use the seven exact shapes from the
   optimization manual. It omitted explicit dispositions for per-row JSON,
   quadratic validators and scalar writes into environment-held vectors.

The correction moves the detectors to the operation boundary: the grouped
helpers pin their one split and indexed lookup, the latest-bar helper pins one
set query with no iterator, the timestamp helper refuses the former scalar
loop, and the explanation test forbids the full readers while capturing the
instrument/time filters passed to active availability reconstruction. The
closeout now walks the manual's seven shapes verbatim. A focused Type 1
confirmation owns the correction verdict.

The review also found three older per-run subsets in `R/run-store.R` outside
the named equity-statistics target. They are inputs to Workstream 53's current
profile, not a Workstream 52 blocker.
