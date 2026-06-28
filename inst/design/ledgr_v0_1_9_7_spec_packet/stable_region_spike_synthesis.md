# ledgr v0.1.9.7 stable_region Spike Synthesis

Status: Implementation complete; awaiting Claude review and maintainer acceptance.
Ticket: LDG-2660
Date: 2026-06-28

## Verdict

Gate verdict: green for implementing `stable_region` in v0.1.9.7 as a native,
strict-lattice business-objective criterion after this synthesis passes review
and maintainer acceptance.

Scope verdict: narrow. The detector is a deterministic implementation of one
specific topology:

- full-factorial candidate parameter lattice;
- ordered axes only;
- Manhattan-distance-1 neighbors in level-index space;
- data-derived adjacent-score tolerance `tau`;
- `min_neighbors` as the public pass/fail control;
- support ratio and local smoothness as audit-only diagnostics.

No public API, criterion implementation, result class, or package dependency is
included in LDG-2660.

## Research Input

Primary input:

```text
inst/design/research/Stable-Parameter-Region-Detection.md
```

The research pass found strong support for Pardo's qualitative plateau
principle: prefer broad, smooth regions of acceptable parameter values over a
single sharp optimum. It did not find a Pardo-authored formula that uniquely
specifies a neighbor count, tolerance band, or local statistic.

The resulting ledgr design is therefore an interpretive operationalization of
Pardo's plateau idea, not a transcription of a Pardo formula. This attribution
must be preserved in docs and release surfaces.

## Accepted Detector Shape

Input:

- candidate parameter grid;
- one scalar metric per candidate;
- metric direction, normalized so larger score means better evidence;
- `min_neighbors`, a positive integer.

The detector consumes no fills, trades, equity reconstruction, walk-forward
sessions, or diagnostic recomputation. It consumes only the candidate grid plus
one already-computed candidate metric.

Topology validation:

- every declared criterion axis must be ordered and must have at least two
  levels;
- admissible axis types are numeric, integer, date-like, logical, and
  explicitly `ordered` factor;
- plain `factor`, character, list, and other unordered axes fail closed;
- every parameter tuple must be unique;
- every Cartesian combination of the declared axis levels must be present;
- duplicate, sparse, non-factorial, or collapsed grids fail closed.

Constant parameters are not silently treated as hold-fixed dimensions in v1. If
a parameter is meant to be metadata rather than part of the stable-region
topology, the future implementation must exclude it from the declared criterion
axes before invoking the detector. Broader hold-fixed and mixed-topology support
remains deferred.

Neighbor rule:

- convert each candidate to level indices on each declared axis;
- two candidates are neighbors when they differ by exactly one level index on
  exactly one axis and match on all other axes;
- raw numeric spacing does not enter the distance calculation.

Tolerance:

```text
tau = median(abs(score[u] - score[v])) over all adjacent unordered pairs
```

`tau` is data-derived from already-computed evidence. It is not a user-facing
second knob. `tau = 0` is valid and means only equally good adjacent evidence
supports a candidate.

Decision:

```text
good_neighbor(i, v) = score[v] >= score[i] - tau
eligible(i) = count(good_neighbor(i, v) for v in neighbors(i)) >= min_neighbors
```

Audit-only diagnostics:

- available neighbor count;
- good neighbor count;
- support ratio;
- local smoothness range;
- derived `tau`;
- level sets and verified grid shape.

These diagnostics explain the decision but do not add additional pass/fail
criteria in v1.

## Known-Direction Fixture

Reference script:

```text
inst/design/ledgr_v0_1_9_7_spec_packet/stable_region_spike_reference.R
```

Local verification command:

```text
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" inst/design/ledgr_v0_1_9_7_spec_packet/stable_region_spike_reference.R
```

Result:

```text
stable_region spike reference checks passed
plateau_tau: 0.01
plateau_center_good_neighbors: 4
spike_tau: 0
spike_center_good_neighbors: 0
```

The script implements the accepted detector shape in base R and verifies:

- broad plateau passes: a 3 x 3 full-factorial grid with scores declining by
  one adjacent step around the center gives `tau = 0.01`; with
  `min_neighbors = 4`, the center has four good neighbors and is eligible;
- isolated spike fails: a 3 x 3 full-factorial grid with one center spike and
  flat surrounding scores gives `tau = 0`; the center has zero good neighbors
  and is not eligible;
- sparse / non-factorial grids fail closed;
- plain unordered factors fail closed;
- duplicate parameter tuples fail closed;
- collapsed declared axes fail closed.

This fixture is a known-direction design check, not a package implementation
test. The LDG-2666 implementation ticket should turn these cases into package
tests with ledgr-style classed conditions and stable result schemas.

## Fail-Closed Conditions To Preserve

The implementation ticket should expose classed conditions for at least:

- invalid `min_neighbors`;
- invalid or non-finite metric values;
- unsupported axis type;
- unordered factor axis;
- collapsed declared axis;
- duplicate parameter tuple;
- sparse or non-factorial grid;
- no adjacent pairs after topology validation.

All conditions should carry enough data for review: affected axis where
available, expected grid size, observed candidate count, duplicate keys or
missing combinations where feasible, and the declared parameter columns.

## Dependency And Package Posture

The strict-lattice detector should be native. The research pass identified
nearest-neighbor, mixed-distance, response-surface, and density packages as
useful for broader future modes, but those packages solve different problems:
k-nearest-neighbor search, generic mixed-type distance, surface modeling, or
clustering. They are not needed for Manhattan-1 adjacency on a verified
full-factorial lattice.

Do not add `FNN`, `RANN`, `gower`, `cluster`, `rsm`, `proxy`, or `dbscan` as
runtime dependencies for v1.

## Deferred Boundaries

Not in v1:

- plain nominal factors;
- hold-fixed nominal-axis handling;
- sparse-grid rescue;
- k-nearest-neighbor neighborhoods;
- Gower or other mixed-distance neighborhoods;
- smoothed response-surface or curvature models;
- density clustering;
- visual parameter-surface tooling;
- using `stable_region` as a ranking or promotion rule.

Those are separate robustness-family designs, not silent extensions of this
criterion.

## Release And Documentation Language

Allowed language:

- "ledgr operationalizes stable parameter regions as strict lattice support";
- "the detector asks whether a candidate is locally supported by enough
  adjacent parameter settings";
- "this is inspired by Pardo's broad-plateau robustness idea."

Forbidden language:

- "Pardo's formula";
- "proves the candidate is robust";
- "guarantees future profitability";
- "selects the best candidate";
- "handles arbitrary parameter spaces."

## Gate For LDG-2666

LDG-2666 may implement `stable_region` if this spike is accepted. Its
implementation gate should include:

- the accepted topology and decision rule above;
- package tests for the known-direction fixtures;
- classed fail-closed conditions;
- evidence-only output integrated into the business-objective criterion
  tear-down table;
- no candidate selection, promotion, ranking-to-pick, or walk-forward identity
  participation.

If review rejects the strict-lattice detector, `stable_region` should defer
without blocking the other business-objective criteria.
