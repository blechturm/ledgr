# Pre-WS4a real-data controls (LDG-3163 scope e)

Value-free summary. The private evidence record, with paths, commits,
adapter identities, the installation commands and the full comparator
commands, is `E:/ledgr-data/reference/v0.2.3-base-953338df/EVIDENCE.md`
(outside every Git tree). No vendor rows, tickers, instrument identifiers,
prices or credentials appear here.

Base: ledgr `953338df`, installed library
`E:/ledgr-data/r-lib/ledgr-v0.2.3-base-953338df`
(`LEDGR_INSTALLED_FROM_COMMIT` = 953338df); the installed ledgr.universe and
ledgr.sharadar functions are identical to their clean source trees in
ledgr-research `3e3e175`. Comparator:
`ledgr-research/experiments/v0_2_2-reference/compare.R` at `3e3e175`, unchanged.
Environment: `SHARADAR_DATA_ROOT=E:/ledgr-data/sharadar`. Run 2026-10-30;
other agents' R processes were running on the host (a correctness oracle,
not a timing record).

## Unchanged rerun (must be IDENTICAL)

```
Rscript compare.R <base lib> <ref_dir> w2_minvar <state_json> C:/Users/maxth/ledgr-wt/ws4a-base
```

Exit 0.

```
snapshot_hash      IDENTICAL
equity             IDENTICAL
fills              IDENTICAL
ledger             IDENTICAL
COMPARE_IDENTICAL
```

## Cost mutant (must DIFFER)

A scratch copy of `worker.R` outside any Git tree, with one changed line:
`ledgr_cost_zero()` to `ledgr_cost_notional_bps_fee(1)` in the shared
experiment helper.

```
Rscript <scratch>/worker.R <base lib> <state_json> w2_minvar <private out_dir> C:/Users/maxth/ledgr-wt/ws4a-base
Rscript compare.R <base lib> <ref_dir> w2_minvar <state_json> C:/Users/maxth/ledgr-wt/ws4a-base <private out_dir>
```

Worker exit 0 (WORKER_DONE). Compare exit 1.

```
snapshot_hash      IDENTICAL
equity             DIFFERS: rows 7213 vs 7213; first differing row 254
fills              DIFFERS: rows 28609 vs 28611; first differing row 1
ledger             DIFFERS: rows 35264 vs 35266; first differing row 1
COMPARE_DIFFERS
```

The differing-column lists are in the private record. The shape matches the
v0.2.2 reference's own gut demonstration, so the pre-WS4a reference passes
its positive and negative controls and is ready to gate a fresh candidate.
