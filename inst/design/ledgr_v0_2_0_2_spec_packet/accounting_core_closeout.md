# Cut 2 Closeout: Accounting Core

**Status:** Accepted by the maintainer on 2026-09-22; Workstream 6 closed.

**Accepted implementation:** commit
`6d1b39bf0d2ad087da4b26b62481c2461a79165b` on branch
`codex/cut2-accounting-core`, based on
`f63d2f506235a0059edc7ab26c9b9a7d3ff39d4f`. None of the clocks below may be
silently relabelled as a different tree.

The integration merge mechanically shifted the accounting-core claim IDs from
`LCL-0015`-`LCL-0020` to `LCL-0016`-`LCL-0021` and their detecting block IDs
from `LTB-0018`-`LTB-0024` to `LTB-0019`-`LTB-0025`, because accepted Cut 3
already occupied `LCL-0015` and `LTB-0018`. Only identifiers changed.

## What Shipped

- The canonical R lot carrier is now per-instrument primitive quantity and
  price vectors with head and tail indices, geometric growth, bounded
  compaction, running net, and delta-maintained basis. The two per-fill scans
  and the nested lot getter/setter are gone. Cash and positions remain outside
  the lot kernel.
- One preparer validates and normalizes the eleven-column event contract. One
  replay owns accounting transitions and returns per-event facts and final
  state. Equity, fills, trades, state-as-of, resume, availability, finalization,
  and run comparison consume that replay or its facts.
- The compiled boundary now concatenates and splits primitive lot segments;
  it no longer constructs one R list per lot. C++ remains optional, fill-only,
  memory-sweep-only, and off by default.
- Fresh and observed zero-FEE stores admit only `FILL` and `CASHFLOW`. Migration
  preserves a historical `FEE` row rather than deleting evidence, but readers
  reject it and the operator must remediate the store before use. No FEE
  economics were added.
- `FILL_PARTIAL`, four unreachable side aliases, the ignored-event return,
  three dead readers, the derived-state basis walk, and the superseded replay
  loops were removed.

LDG-2783, optional per-call validation/coercion work, is deferred. The carrier
and consolidation do not depend on it, and this workstream did not weaken any
kernel validation to chase the remaining shallow-depth floor.

## Registered Claims

| Claim | Detector | Profile | Result |
| --- | --- | --- | --- |
| LCL-0016 transition arithmetic | LTB-0019 | review | pass |
| LCL-0017 source-block identity | LTB-0020 | review | pass |
| LCL-0018 real 50,000-row boundary | LTB-0021 | heavy | pass, 50,002 events |
| LCL-0019 resume and walk-forward carry | LTB-0023, LTB-0024 | heavy | pass |
| LCL-0020 no depth-dependent write scan | LTB-0022 | review | pass; mutant fails |
| LCL-0021 parallel opening state | LTB-0025 | heavy | pass with mirai 2.7.2 |
| LCL-0006 canonical R / C++ parity | LTB-0006, LTB-0013, LTB-0014 | review | retained; fractional reversal and two-way dust-scale states added |

LTB-0006 carries fractional witnesses in both directions. The seven-fill
reversal checks ordinary lots, realized PnL, and basis. Two four-lot states
exercise the BUY and SELL consumption loops separately; each leaves an
opposite-sign residual if that loop omits the full fill quantity from its dust
scale. They compare lot quantities, prices, realized PnL, and basis within the
existing tight parity tolerance and assert that the resulting lots have one
sign. The sign assertion, not final-bit numerical identity, is the mutation
detector.

The old availability artifact is unchanged, but its assertion is not described
as unchanged. Delta maintenance changes only `unrealized_pnl`: its measured
maximum absolute residual is `1.819e-12` (`1.016e-13` relative). The candidate
therefore keeps exact identity for cash, positions value, equity, realized PnL,
identity, and every non-numeric field, and applies LDG-2403's existing `1e-10`
tolerance only to `unrealized_pnl`. This explicit witness change requires
maintainer acceptance with the workstream; it does not widen a product
tolerance. Event order, positions, lots, fills, trades, fees, opening state,
and event sequence remain exact.

## Performance And Transfer Inputs

All component clocks used R 4.6.1 on Windows, duckdb 1.5.2, testthat 3.3.2,
collapse 2.1.8, and the installed source build in
`C:/tmp/ledgr-cut2-lib-latest`.

The D5 detector used depths 25, 100, 400, and 800, 1,500 calls per depth, and
three repetitions. Production measured 20, 20, 20, and 20 microseconds per
event; log-log slope was effectively 0.000. The injected basis rescan measured
40, 73.3, 226.7, and 440 microseconds; slope 0.695, above the preregistered
0.30 allowance. The mutation fails for the intended reason.

At the inventory's 1,600-lot registered depth, five medians of 10,000 calls
measured 19 microseconds at depth 2 and 24 microseconds at depth 1,600. The
observed list-held-vector copy increment was about 5 microseconds per call
(1.26x), recorded rather than hidden.

At 1,600 lots, five medians of 2,000 calls measured primitive compiled-state
packing at 25 microseconds and unpacking at 40 microseconds: 65 microseconds
round trip. This and the D5 curve are the two named inputs for the later
compiled-execution RFC. They are observations, not runtime-default thresholds.

The persisted-run FEE census used:

```sql
SELECT COUNT(*) AS n
FROM ledger_events
WHERE event_type = 'FEE';
```

Eight local benchmark stores were opened read-only. All had `ledger_events`;
the total was zero FEE rows. The migration suite separately constructs a
historical FEE row, proves migration preserves it, and proves the accounting
reader fails closed. Such a store needs explicit operator remediation; FEE is
not a readable reserved operation.

## Production Validation

The command shape for each profile was:

```powershell
Rscript -e ".libPaths(c('<installed-candidate>', '<R-4.6-library>',
  '<optional-library>', .Library)); library(ledgr);
  source('tests/test-control-plane.R');
  ledgr_test_run_profile(root='.', profile='<profile>', mode='ordinary',
  reporter='summary', census_path=NULL, load_package='none')"
```

| Profile | Blocks | Seconds | Result |
| --- | ---: | ---: | --- |
| fast | 443 | 85.080 | pass |
| review | 219 | 335.100 | pass; one declared optional-path skip |
| heavy_protocol | 192 | 506.250 | pass; no skips |

The installed source build completed successfully. Focused compiled execution,
FIFO torture, opening positions, schema convergence, durable fills, resume,
availability, finalization, public sweep, and mirai parallel-sweep tests also
passed. The actual 50,000-row fetch boundary is exercised by 50,002 persisted
events, not by a toy logical split.

`R CMD check --no-tests --no-manual --no-build-vignettes` completed with all
code, namespace, installation, compiled-code, documentation and examples checks
OK. Its two warnings are the expected missing rendered vignette outputs under
`--no-build-vignettes`; its note is the isolated Git-worktree `.git` pointer.
The three control-plane profiles above are the test record.

## Rejected Or Superseded Records

- The inventory's 3.23 microseconds and 28x prototype multiple are not gates;
  the production D5 curve above is the record.
- The first review-profile attempt was rejected after it exposed the frozen
  unrealized-PnL ordering residual. The artifact was not regenerated; the
  corrected gate keeps four equity columns exact and applies the existing
  numeric tolerance only to `unrealized_pnl`.
- A fast run whose optional census path was refused by the sandbox was not used
  as a clock, even though its tests and claim checks had completed. The clean
  85.080-second run above is the record.
- Source-specific preparers, trusting the memory-only parsed metadata, adding
  FEE semantics, or expanding compiled execution were rejected as duplicate or
  out of scope.

## Governance Counters And Open Work

Cut 2 has nine completed tickets and one explicitly deferred optional ticket.
It has one accepted cut review, one workstream-close review that found the
fractional reversal defect, one focused correction review that found the
compiled dust-scale residual, one focused review that found the first dust
witness was not mutation-sensitive, and one confirming review that passed the
two-way replacement: five review invocations over nine completed tickets, ratio
`0.56`, above the `0.5` gate. The code review passed, but the workstream cannot
claim that it met the governance gate. On 2026-09-22 the maintainer accepted
the workstream and adjudicated the historical breach as warranted by the real
correctness defects those reviews found. The `0.56` result remains recorded;
the threshold was not rewritten. No optional mid-workstream review was invoked.

The acceptance commit must name the deleted superseded replay loops, derived
basis walk, per-lot compiled allocation, ignored fallthrough, three dead
readers, dead side and partial-fill vocabulary, and the old `FIFO Mismatch` and
`Malformed meta_json` warnings. The two warnings had no production witness:
the writer never emitted `meta.realized_pnl`, while malformed JSON now fails
closed in the shared preparer.

The future compiled-execution RFC may consume the recorded transfer and D5
inputs. Equity settlement remains outside this cut and may now open under its
own accepted authority.
