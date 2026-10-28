# Peer-suite seed prerequisite

2026-10-28. **Answer: the existing peer Tier 1 label is not a deletion oracle.**
This is a small correctness probe, not a timing or peer-performance record.

`probe.R` loads the current package, seals a simulated two-instrument,
120-bar snapshot, runs the existing public TTR SMA 5/10 crossover recipe
through `ledgr_run()`, and reads native equity, fills and diagnostics. It
produced 22 fills. The experiment supplies capital and zero costs explicitly.

The probe changes the quantity of one published fill while leaving the
equity output untouched, modelling a publication error rather than changing
the strategy's rule. The existing `peer_parity()` still returns “passes Tier 1
tolerance”; its equity comparison remains unchanged. Exact comparison of the
native fill tables returns FALSE. Identical native tables compare TRUE.
This does not show that the old report promised exact fill parity: it shows
why its classified economic comparison cannot serve as C1's deletion gate.

The seed may consume two requirements: freeze native ledgr results before
handler/engine changes, and keep exact internal regression separate from
cross-framework semantic/float residual classification. It may not infer
anything about peer runtime, memory, availability or the rest of the suite.

The checker reproduces the recorded CSVs in scratch. Gutting the exact-fill
detector changes `observations.csv` and is detected. Environment, source and
native snapshot/config identity are recorded in `evidence/environment.txt`.
No product source or existing benchmark implementation was changed.
