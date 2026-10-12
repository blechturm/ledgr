# LDG-3020 process-local verification record

Recorded on 2026-10-12 from accepted rule-3 commit `028a3c57` and candidate
commit `7367d28c`. The candidate adds no stored proof, migration, legacy
reader or missing-marker fallback. Rule 1, rule 2 and missing markers still
refuse every complete verification with `ledgr_snapshot_rebuild_required`.

## Vendor-neutral fixture

The registered 50-instrument, 1,260-session fixture was run in three
alternating fresh-process pairs. All 30 gated result families and the
informational identity family were byte-identical in every pair.

| Phase | Accepted median | Candidate median | Ratio |
| --- | ---: | ---: | ---: |
| build and seal | 2.125 s | 2.173 s | 1.023 |
| result readers | 3.327 s | 3.179 s | 0.956 |
| momentum run | 6.112 s | 5.672 s | 0.928 |
| three-candidate sweep | 14.376 s | 13.821 s | 0.961 |
| walk-forward | 11.076 s | 10.076 s | 0.910 |

Peak-RSS ratios were 0.978 to 1.002. Build does not benefit from reuse: its
successful seal establishes the process proof after COMMIT. The other phases
exercise repeated content use in the same process.

`fixture_families.csv` and `fixture_families_phases.csv` are a separate
single-arm reproduction of the exact LDG-3019 fixture shape. All 31 families
match the LDG-3019 record. The paired record is the effect estimate;
single-arm clocks are orientation only.

The private Sharadar lake remains rule 2 and correctly refuses. Cut 13 does
not migrate, reseal or read it through an old encoder. Its one rule-3 rebuild
and aggregate post clock remain with the owning ledgr-research WS7 cut, as
the accepted Cut 13 routing requires.

## Long-window regression

The registered ordinary suite completed in 554.60 seconds and its checker
returned `LWREG_CHECK_OK`. All cold and warm semantic hashes match. Median
candidate/accepted ratios were:

| Shape | Cold | Warm |
| --- | ---: | ---: |
| availability sweep | 0.960 | 0.968 |
| fact churn and terminal handling | 0.941 | 0.904 |
| feature gaps | 0.918 | 0.944 |

No retry was triggered and every ratio is below the 1.10 gate.

## Failure sensitivity

The owning blocks were run after each smallest mutation:

- forcing every ensure to miss the set fails LTB-0252 and LTB-0254;
- omitting the PID comparison fails LTB-0252;
- keying split reconstruction from the run connection fails LTB-0252;
- retaining an entry after a root mismatch fails LTB-0253 twice;
- registering before COMMIT fails LTB-0252 after an injected commit failure;
- a serialized handle in a real subprocess starts cold and becomes warm only
  after `summary()` performs a complete verification (LTB-0256).

LTB-0254 counts one complete hash for a fresh run, a three-candidate sweep,
walk-forward, fact inspection and derived-state reconstruction. LTB-0255
derives every R source file naming a snapshot content table and requires an
exact row in the checked-in consumer census.

## Seven-shape walk

1. No row-wise frame construction or row binding was added.
2. No full snapshot table is subset inside an instrument or pulse loop.
3. No timestamp or JSON formatting was added inside an element loop.
4. The verified set holds one scalar tuple per proven snapshot, not data rows.
5. Complete hashing is skipped only after the exact tuple is already proven;
   explicit validation still recomputes.
6. Each ensure reads one scalar envelope. It does not scan prior runs,
   candidates, folds, bars or facts.
7. The private environment grows by one bounded tuple per verified snapshot;
   PID change replaces the environment, and failure removes the matching
   tuple. No caller-owned object is mutated.

The ordinary fast-profile result is recorded in the Workstream 27 closeout,
because its fixed wall-time gate applies to the complete workstream rather
than this benchmark alone.
