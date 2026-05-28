# Research To Production Boundaries


ledgr is designed so research evidence can survive later production
review. A promoted backtest is not production approval, broker
readiness, or proof of generalization. It is a durable research artifact
that tells you exactly what was selected and what evidence was attached
to that selection.

This article sets that boundary. For the actual research loop, start
with `vignette("research-workflow", package = "ledgr")`.

> [!WARNING]
>
> ### Promotion is not deployment
>
> Promotion records a selected research candidate as a committed run. It
> does not authorize capital, create broker orders, prove out-of-sample
> performance, or replace operational review.

## The Boundary

> [!NOTE]
>
> ### Definition
>
> The research-to-production boundary is the handoff from a durable
> research artifact to a separate production-review process. ledgr
> preserves the research evidence; it does not turn that evidence into a
> live trading system.

The useful mental model is:

<div class="ledgr-diagram ledgr-research-production-boundary">

``` mermaid

flowchart LR
  research["research workflow"]
  artifact["promoted artifact"]
  review["production review"]
  future["future paper live adapters"]

  research --> artifact --> review --> future
```

</div>

The arrow into the promoted artifact is ledgr’s current strength: sealed
data, declared experiments, reproducible execution, provenance,
promotion notes, and stored result artifacts. The arrows after that are
explicit boundaries. They require statistical validation, risk review,
operational controls, and future adapter work.

## What Carries Forward

The production review starts with evidence that can be reopened:

| Carry-forward evidence | Canonical home |
|----|----|
| selected run, promotion note, and source sweep context | `vignette("research-workflow", package = "ledgr")` |
| sealed snapshot identity and durable store layout | `vignette("experiment-store", package = "ledgr")` |
| strategy source, params, feature params, and reproducibility tier | `vignette("reproducibility", package = "ledgr")` |
| target holdings and next-open fill semantics | `vignette("execution-semantics", package = "ledgr")` |
| ledger events, fills, trades, equity, and metrics | `vignette("metrics-and-accounting", package = "ledgr")` |

That evidence is useful because it narrows the production-review
question. You are not asking “what did this notebook happen to do?” You
are asking whether a named, reopenable artifact deserves further
validation and operational work.

## What Does Not Carry Forward Automatically

Do not treat research provenance as an operational system. ledgr’s
public research layer does not provide:

- paper or live broker adapters;
- an OMS lifecycle with submissions, acknowledgments, partial fills,
  cancels, rejections, and reconciliation;
- live data logs or point-in-time external regressors;
- automatic target-risk constraints such as long-only, max-weight, or
  capital floor enforcement;
- public liquidity, borrow, margin, or financing models;
- walk-forward proof of generalization unless you add that evaluation
  layer.

The ledger reconstructs ledgr’s expected state from recorded events. In
paper and live modes, that expected state must still be reconciled
against broker-reported orders, positions, cash, and fills before
trading resumes.

> [!IMPORTANT]
>
> ### Roadmap boundary
>
> Paper/live adapters are v0.3.0+ roadmap scope. Research-mode artifacts
> should be shaped so they can support that later work, but this article
> does not pull broker, OMS, or live-data behavior into the current
> research workflow.

## Production Review Checklist

Before a promoted run becomes a production candidate, write down:

- the promoted `run_id` and promotion note;
- whether the result has walk-forward or held-out evidence;
- the ranking rule that selected the candidate;
- the risk, cost, capital, and liquidity assumptions that are not
  enforced by the research run;
- the data-source limitations, timestamp assumptions, and survivorship
  assumptions;
- the operational dependencies that live outside ledgr’s research
  artifacts.

The checklist is intentionally human-readable. ledgr keeps the
machine-readable artifact trail; production review still needs a person
to state the assumptions.

## Related Articles

- `vignette("research-workflow", package = "ledgr")` for the canonical
  research loop.
- `vignette("experiment-store", package = "ledgr")` for durable
  artifacts and reopening stored runs.
- `vignette("reproducibility", package = "ledgr")` for provenance and
  replay boundaries.
- `vignette("execution-semantics", package = "ledgr")` for target
  holdings and fill timing.
