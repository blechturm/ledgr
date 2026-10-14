# Feature-keeping spike closeout

**Date:** 2026-10-14  
**Base:** `f262e77a`  
**Verdict:** RED

## Answer

Delete both current computed-feature retention mechanisms before the WS3/WS4
history implementation cut:

- the process-local feature cache; and
- `persist_features` plus the durable run-table writes it controls.

This does not reject future factor or prediction evidence. LFB-028 already
owns that product question after the history surface exists. The current
`features` table is not that evidence chain and should not be kept in
anticipation of a different design.

## Evidence

The cache has one real best case. On three alternating fresh-process pairs,
the median second identical run fell from 2.36 s without the cache to 1.45 s
with it, a 38.6 percent saving. A cold run was unchanged within noise: 2.06 s
with the cache and 2.05 s without it. Economic outputs were identical in all
timing arms.

The cache fails the mandatory correctness gate. Its feature fingerprint does
not include captured values. After a captured value changed from 1 to 2, the
warm run reported three hits and kept the old result (zero fills); clearing
the cache produced the current result (three fills). Engine-version isolation
and reuse across equal-content snapshots behaved as intended, but one silent
stale-result path is sufficient for RED.

Walk-forward supplies no compensating use case. Repeating the registered
five-fold session made 960 feature calls both times, with zero cache entries
and zero retained values after either pass.

At the registered Sharadar shape, one feature populated 8,410,358 numeric
values in 1,166 registry entries. The cache object retained 67,749,472 bytes
(8.06 bytes per value). Whole-process RSS after the run was 1.27 GB; that is
reported as context, not attributed wholly to the cache.

Persistence also fails its necessity gate. `ledgr_results(bt, "features")`
refuses with `ledgr_invalid_result_table`; pulse readers recompute and do not
consume these rows. On the 80 by 500 timing fixture, persistence wrote 40,000
rows. The median run moved from 3.52 s to 3.56 s and median finalization from
0.05 s to 0.11 s. Outputs remained identical. A small cost is not a reason to
keep a durable surface with no named consumer.

## Verification

`spike_checker.R` passed a fresh-process quick rerun and recomputed RED. Its
gut mode clears the cache before the capture-change run; the checker rejects
that altered evidence at the correctness comparison. No package production
file was changed.

## Routing

The combined pre-history cut gets one pure-deletion workstream. It removes the
cache, cache telemetry, persistence writes and the `persist_features` option,
with byte-identical economic-result gates and targeted removal detectors.
WS5-B has no surviving current artifact for which to design reuse keys. The
later LFB-028 factor-evidence design remains separate and follows the history
wave.
