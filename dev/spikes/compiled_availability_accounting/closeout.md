# Compiled Availability Accounting Spike Closeout

**GREEN.** LDG-2992's kill condition did not fire: Workstream 22 measured
accounting at 17.95 percent of pulse time for momentum and 41.59 percent for
equal weight, and the single-seam hybrid produced exact economic parity with
canonical R on all retained synthetic cases and all four private-data clock
pairs.

## Answer

An availability-aware one-candidate sweep can send fills through the compiled
spot-FIFO batch while cash distributions and terminal dispositions post
through canonical R on the same lot state. The existing fold already owns the
required ordering and shared state. The only fork changes lift the public
availability refusal and the over-broad up-front event-kind refusal; the
compiled batch itself remains FILL-only.

Three retained public-API cases compare a fill round trip, a cash dividend
beside a sale, and a frozen terminal write-off beside a sale. After removing
run/sweep identity and clocks, every pair is exact for the economic summary,
ordered ledger events and accounting attributes, retained returns and trades,
diagnostics and completion. The spike makes no separate final-state claim:
the first review found that the fold return exposes the unchanged outer-state
shell rather than the state mutated inside the run loop. The checker reruns
from a clean archive and a gut that changes one compiled event quantity changes
all three hybrid event records while leaving canonical records unchanged.

## Effect Size

The authorized private-data arm used the registered 1998-2026 Sharadar
snapshot through an explicit DuckDB read-only connection. It ran two
alternating-order pairs for each registered workload. Only aggregate clocks
entered Git.

| Workload | Hybrid / canonical elapsed | Elapsed saving | Hybrid / canonical engine |
| --- | ---: | ---: | ---: |
| Momentum, median of two pairs | 0.9769 | 2.31% | 0.9772 |
| Equal weight, median of two pairs | 0.7086 | 29.14% | 0.6942 |

Momentum's pairs straddled parity: 0.9395 when canonical ran first and 1.0143
when hybrid ran first. Equal weight was stable at 0.7093 and 0.7078. The
result is therefore workload-dependent and consistent with the prerequisite's
different accounting shares; it is not evidence for a universal speedup.

## Containment

The fork changes only `R/compiled-spot-fifo.R`, `R/fold-engine.R` and
`R/sweep.R`, behind an internal switch that defaults off. It adds no public
API, second engine, package test, contract or release-branch behavior. The
private snapshot stayed read-only, and no source row, identifier, price or
action value entered Git. This spike establishes feasibility and effect size;
shipping the hybrid remains a later design and ticket decision.
