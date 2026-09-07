# Retained Evidence

This directory holds branch-tracked evidence required to reproduce or audit
the spike:

- `frozen_hashes.csv`, the exact LF-normalized Stage 2 SHA-256 freeze set;
- `preprototype_code.csv`, the only executable files allowed before the gate;
- package base and spike commit IDs;
- fixture-generator source;
- dependency and environment records;
- conformance and checker-mutation tables;
- measurement summaries and failure attribution; and
- the reviewed green, red, or inconclusive report.

The freeze metadata does not approve itself. The maintainer and independent
review fields in the witness registry must be complete before the Stage 2 gate
can pass.

Large raw or replaceable outputs stay in `../scratch/` and are referenced by
content hash when they matter to a conclusion.
