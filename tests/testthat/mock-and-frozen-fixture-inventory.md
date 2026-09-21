# Mock And Frozen-Fixture Inventory

This is the bounded v0.2.0.2 Workstream 1 inventory. A mock isolates a
dependency or records a call; the asserted value is produced by the real code
outside that seam. Spies call the original implementation.

At the ticket cut, 12 files used mocked bindings. One circular clock mock was
removed. Oracle repair added non-circular spies in four further files, leaving
23 mock calls in 15 files. Finalizer repair added one close-method probe,
leaving 24 mock calls in 16 files; every current call is listed below (the two plot
calls and two runner calls each share one row).

| File and block | Isolated dependency | Independently asserted value |
| --- | --- | --- |
| `test-availability-finalization-prefix.R`, dense resume | Equity-prefix commit spy | Dense status, full equity, and zero prefix-merge calls |
| `test-availability-execution-timing.R`, timing identity | Retained-trades input capture | Real run/sweep timing provenance and captured-versus-durable fills |
| `test-availability-economics.R`, eventful fold | Small initial buffer and growth spy | Persisted completion, fills, diagnostics, reopen parity, and growth count |
| `test-availability-provider-production.R`, active boundaries | Prepared-builder spy; public resolvers abort | Real run, result, explain, and reopen surfaces plus build counts |
| `test-availability-provider-production.R`, incomplete reopen | Prepared-builder spy; public resolvers abort | Real incomplete run/reopen plus build counts |
| `test-availability-validator-sweeps.R`, seal sweep | Membership-sweep spy | A real sealed snapshot and one observed sweep call |
| `test-availability-parity.R`, incomplete finalization recovery | One finalization transaction failure | Stored failure evidence and exact clean-versus-recovered tables |
| `test-availability-parity.R`, complete finalization recovery | One finalization transaction failure | Stored failure evidence and exact clean-versus-recovered tables |
| `test-availability-parity.R`, read-only availability view | Diagnostics reader replaced with altered rows | Previously read availability evidence remains identical |
| `test-availability-parity.R`, incomplete metric prefix | Metric calculation fails | Real terminal status and completion evidence remain authoritative |
| `test-availability-state.R`, dense valuation bypass | Availability valuation constructor aborts | A real dense run reaches `DONE` |
| `test-availability-production-retirement.R`, provider bypass | Public membership inspection aborts | A real production run emits diagnostics |
| `test-execution-spec.R`, shared constructor | Execution-spec constructor spy | Real run and sweep results plus exactly two constructor calls |
| `test-dense-timestamp-validation.R`, vector conversion | Timestamp-key and formatter spies | Real coverage validation, vector lengths, and no formatter calls |
| `test-dense-timestamp-validation.R`, availability bypass | Dense validator aborts | Real availability sweep and window construction succeed |
| `test-ledger-writer.R`, failed write | One event-buffer write failure | No partial row and successful retry in both handlers |
| `test-ledger-writer.R`, collapse route | `collapse::setv()` spy | Real in-place character write and one observed call |
| `test-plot.R`, dependency fallbacks | `gridExtra`, then all plotting dependencies absent | Real fallback plot/message and classed missing-package error |
| `test-runner.R`, post-fold recovery | Telemetry and finalization failures | Persisted prefix, rollback state, and exact resumed-versus-clean tables |
| `test-snapshot-hash-deduplication.R`, formatter gate | Timestamp formatter spy | Byte-identical tokens and bounded formatter inputs |
| `test-walk-forward-folds.R`, shared fold route | Fold-core spy | Real walk-forward result and three observed fold calls |
| `test-walk-forward-orchestrator.R`, terminal cleanup | Close-method probe closes the real handle and then fails | The original interrupt remains authoritative and the captured handle state is closed |

The former `Sys.time()` mock in `test-walk-forward-schema.R` supplied the
timestamp that the same block asserted. It was removed. The replacement
brackets the production timestamp between two real clock reads.

The frozen fixture directory contains seven CSVs. Its `README.md` names one
immutable-closeout regeneration command per file. Those commands copy
historical blobs and do not execute the current guarded implementation.
