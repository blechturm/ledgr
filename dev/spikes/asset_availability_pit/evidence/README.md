# Retained Evidence

This directory holds branch-tracked evidence required to reproduce or audit
the spike:

- `frozen_hashes.csv`, the exact LF-normalized Stage 2 SHA-256 freeze set;
- `preprototype_code.csv`, the only executable files allowed before the gate;
- package base and spike commit IDs;
- fixture-generator source;
- dependency and environment records;
- conformance and checker-mutation tables;
- Stage 4 shared-fork conformance, one-pass checker mutations, and structural
  provider memory accounting;
- measurement summaries and failure attribution; and
- the reviewed green, red, or inconclusive report.

The Stage 2 freeze and Stage 3 review records remain committed history. The
frozen witness registry is unchanged. Stage 4 owns its executable versus
policy-example classification in `stage4/fixtures.R`.

Large raw or replaceable outputs stay in `../scratch/` and are referenced by
content hash when they matter to a conclusion.
