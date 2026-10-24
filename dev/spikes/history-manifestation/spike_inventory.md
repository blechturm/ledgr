# History manifestation spike inventory

**Outcome:** GREEN under charter v2  
**Product changes:** none

## Smallest viable direction

The ordinary reader needs one prepared read description, not another evidence
object. At a pulse it should receive:

- the already verified snapshot and owner-validated substrate identity;
- requested row and session positions;
- a memory-bounded way to answer finite-observation counts for that window;
- sparse value replacements already derived by the canonical carry policy;
- the compact selection and request metadata the public object discloses.

It then performs one value slice. The matrix transposes that slice once. The
wide frame uses `collapse::mrtl()` to turn the stored instrument rows directly
into frame columns, avoiding both a full transpose and a second split. The
outputs are siblings; neither adapts through the other.

The spike does not select the production representation of the count summary.
`representation_probe.R` used a dense prefix plane only as a cost oracle: its
500-instrument window query was about 0.006 ms. A focused design amendment must
either bind a memory-bounded sparse/cumulative summary or fuse finite counting
into the one manifestation pass. It may not add a dense plane per field merely
to win this clock.

## Gutted path

`gut_demo.R` restores one SHA-256 digest of each transient result. The checker
rejects it because `digest_calls` becomes one. The 500 by 252 component clock
for that excluded digest is 3.151 ms, before any rich evidence is manifested;
the negative control prints `HISTORY_MANIFESTATION_GUT_DETECTED`.

## Demoted or rejected

- transient value hashes and seals after the verified-substrate boundary;
- eager cell-aligned evidence in every ordinary matrix or wide-frame read;
- frame-through-matrix or matrix-through-frame construction;
- a duplicate history plane kept in the opposite orientation;
- whole-result caches or preparation proportional to prior pulses;
- a dense finite-count prefix plane as the assumed production solution.

## Learned

- At 500 by 252 the current rich reader was 24.198 ms. The v2 matrix was
  0.427 ms and the frame 0.405 ms; both reproduced the current numeric values,
  dimensions, names and selected IDs exactly.
- Matrix and frame allocated 2.02 and 2.06 times the returned double payload,
  compared with 69.10 times on the current path. Neither retained both forms.
- The observed log-log growth exponents were 0.861 and 0.849 across the four
  registered shapes. A fixed 500 by 252 raw slice differed by 0.037 ms between
  252- and 1,260-session source planes.
- Direct row-to-column frame manifestation is both faster and leaner than
  `mctl(t(x))` for the substrate's instrument-by-session orientation.
- Prepared finite counts remove the avoidable full value rescan. The v1
  candidate without them stopped at about 0.490 ms matrix and 0.619 ms frame.

## Still open for the focused amendment

- the memory-bounded production shape for finite counts;
- which compact exclusion-reason and `used_before_window` summaries remain on
  ordinary results, and which diagnostics are reproducible only on demand;
- proof that the same plan covers feature values and late-known overlays, not
  only the recorded bar fixture;
- mutation gates that prevent a future rich-evidence rebuild, transient hash,
  whole-snapshot scan or divergent frame/matrix selection rule.
