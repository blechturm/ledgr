# Snapshot Hash Rule-3 Spike Inventory

## Outcome

The exact seed-v2 rule-3 candidate is portable and block-bounded at the
registered shapes. Ten deterministic cases produced identical roots on
Windows and Ubuntu. The independent checker reran both systems and passed.

## What Was Built

- One standalone R-owned encoder for the seed-v2 bytes.
- Fixed 10,000-row, column-major logical blocks.
- DuckDB retrieval used only to test insertion, fetch-size and thread
  invariance. DuckDB did not define or encode identity.
- An encoder-only cost ladder at 0.5, 1, 2 and 5 million rows.
- Whole-process RSS measurements for five million bars and a retained
  300,000-row membership fact projection.

The harness does not modify or call production hashing code.

## What Was Demoted

- Row-major binary and DuckDB typed-text encodings remain rejected
  alternatives; neither was needed to answer the question.
- End-to-end snapshot-open and run clocks remain ticket evidence. A
  no-product-change spike cannot measure their implementation effect.
- The process-local verified-set policy was not prototyped. This spike only
  establishes the bytes, portability and cost on which that policy depends.

## What Was Deleted From the Working Theory

- R ownership does not require materializing all bars in R.
- Fetch size, insertion order and DuckDB thread count do not need to enter
  snapshot identity.
- The one-microsecond gate does not require a second canonicalizer.
- Ignored vendor columns in a quarantined original row do not need to enter
  the fact projection.

## What Was Learned

- The candidate needed byte-preserving fast paths for common non-missing
  columns and small non-negative 64-bit values. These changed allocation,
  not the root.
- Recorded five-million-row encoder medians were 0.676 microseconds per bar
  on Windows and 0.999 on Ubuntu. Endpoint exponents were 1.038 and 1.001.
- The five-million-bar path peaked at about 149 MB on Windows and 130 MB on
  Ubuntu while retaining no more than one logical bar block in R.
- The retained 300,000-row fact projection produced 65.7 MB of JSON and
  peaked at about 418 MB on Windows and 474 MB on Ubuntu. This is the
  candidate's material residual memory cost and belongs in the ticket
  evidence; it is not hidden by the bar result.
- Synthetic coverage includes every current fact family, but the spike does
  not claim production integration or a full-population fact-memory result.

## Failure Sensitivity

The checker replaces the byte-order assertion with a gut that accepts its
input order. The hostile instrument case then changes from a typed refusal to
`accepted`, so the rerun no longer matches the recorded deterministic CSV.
That is the one gutted path required by the charter.
