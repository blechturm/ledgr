# Pulse inspection materialization probe

**Question:** can the two accepted current-pulse inspection helpers retain
their exact outputs while constructing them materially faster and with no more
allocation from the prepared pulse lookup?

**Prerequisite:** Cut 9 already prepares aligned bar and feature primitives,
the resolved feature-name state and the numeric cutoff once. The probe does
not change that carrier.

**Kill condition:** stop if exact output requires a manifested frame, a new
cache or a change to alias, ordering, empty-axis or refusal semantics.

The probe ran the public helpers on a real 600-instrument, three-feature pulse.
The registered shared timing protocol compares `04fac1bf` with `68799f1b` in
eight alternating fresh-process pairs. Its median candidate/base ratios are
0.0797 for long inspection and 0.0617 for wide inspection. The separate
Rprofmem record reports 168,482 to 167,618 bytes per long call and 1,341,018
to 726,690 bytes per wide call. Output dimensions and numeric summaries are
equal.

Direct typed construction wins. `collapse::pivot()` was also tested and was
fast, but remained slower and allocated more because the source is already in
the final aligned vectors; a generic reshape adds grouping and name work.

**Disposition:** GREEN. Cut 10 may consume direct construction. The result
does not create a public helper-speed promise. The allocation checker detects
an inflated candidate arm, and registered LTB-0549 detects restoration of the
long-then-wide product path.
