# Native Compilation Technical Report

## Executive result

The spike is **GREEN for further bounded quickr experiments**, **GREEN with a
licensing condition for specialized ast2ast experiments**, and **inconclusive
for nCompiler on this host**.

Generated native code is technically credible for typed, reusable numerical
and batch kernels. It is not evidence for compiling ledgr's production fold
core, and it does not justify a generic compiler abstraction. Handwritten Rcpp
remains the production default until one selected generated kernel passes
cross-platform package-build, correctness, maintenance, and licensing review.

## What ran

The recorded Windows result contains:

- 36 numerical shapes: 252, 1,260, and 2,520 sessions; 10, 100, and 500
  instruments; lookbacks 5, 20, 63, and 252;
- three sequential stateful shapes;
- ten batch shapes: 252 and 1,260 sessions crossed with 1, 10, 100, 1,000,
  and 10,000 configurations;
- three explicit-validity-mask shapes;
- 264 warm benchmark rows in total;
- ten correctness cases, expanded across available implementations.

The loop kernels, quickr, ast2ast, and Rcpp use the same O(sessions x items)
rolling-sum or state-transition algorithm. The idiomatic R numerical baseline
uses vectorized cumulative sums with the same asymptotic complexity but a
different allocation strategy. The matrix-oriented R batch executes one R
loop over sessions and vectorizes across configurations.

The benchmark host, compiler versions, flags, package versions, and OpenMP
thread count are in `results/windows-r4.6.1/environment.csv`. These are local
engineering measurements, not public cross-package claims.

## Correctness

After the final rerun, every supported case passes. The only unsupported case
is direct `NA_real_` input to quickr, matching quickr's documented restriction.

| Area | Result |
| --- | --- |
| Rolling variance | quickr, ast2ast, vectorized R, and Rcpp agree with the loop oracle within `1e-10` |
| Stateful simulation | all available native variants agree on no-trade and transaction-cost paths |
| Parameter batch | serial and OpenMP results agree with repeated authoritative calls |
| Repeated execution | every supported stateful variant is byte-identical on repeat |
| `NA_real_` | R, Rcpp, and ast2ast preserve it; quickr is recorded unsupported |
| `NaN`, `Inf` | observed round trips agree for all primary variants |
| Explicit validity mask | all primary variants ignore non-zero sentinels only where the mask says invalid |

The mask result matters: a quickr path is feasible without inventing zero or
forward-fill semantics, but every input would need a separate validity plane
and every output contract would need to say how validity is returned.

The deliberate gut subtracts from the Rcpp stateful result. C03, C04, and C10
turn red, demonstrating that the oracle detects a wrong native state machine.

## Warm performance

Representative largest rows are below. Speedup is against the corresponding
base R loop, not against vectorized R or Rcpp.

| Workload | Shape | Variant | Median | Speedup vs base R | R-visible allocation |
| --- | --- | ---: | ---: | ---: | ---: |
| Rolling variance | 2,520 x 500, lookback 252 | base R | 194.30 ms | 1.0x | 10.08 MB |
| | | vectorized R | 137.93 ms | 1.41x | 231.09 MB |
| | | Rcpp | 3.71 ms | 52.43x | 10.08 MB |
| | | quickr | 3.39 ms | 57.36x | 10.08 MB |
| | | ast2ast | 10.41 ms | 18.66x | 10.08 MB |
| Stateful | 2,520 sessions | base R | 433.9 us | 1.0x | 20.23 KB |
| | | Rcpp | 21.0 us | 20.66x | 20.23 KB |
| | | quickr | 17.5 us | 24.79x | 20.23 KB |
| | | ast2ast | 24.9 us | 17.43x | 20.23 KB |
| Batch | 1,260 x 10,000 | repeated R | 2.334 s | 1.0x | 557.52 MB |
| | | matrix-oriented R | 606.75 ms | 3.85x | 1.508 GB |
| | | Rcpp | 99.56 ms | 23.45x | 100.80 MB |
| | | quickr | 89.72 ms | 26.02x | 100.80 MB |
| | | quickr OpenMP, 4 threads | 88.72 ms | 26.31x | 100.80 MB |
| | | ast2ast | 155.90 ms | 14.97x | 100.80 MB |
| Masked mean | 2,520 x 500 | base R | 60.88 ms | 1.0x | 40.37 KB |
| | | Rcpp | 2.82 ms | 21.61x | 40.37 KB |
| | | quickr | 1.31 ms | 46.41x | 40.37 KB |
| | | ast2ast | 7.69 ms | 7.92x | 40.37 KB |

`bench` reports allocations visible to R. It is not a process-RSS profiler and
can miss temporary native allocations. These kernels preallocate their output
and use scalar native state, so the large allocation differences are primarily
the R implementations' intermediates and repeated results. They still need a
process-memory check before a product decision.

### Scaling

All compiled variants scaled approximately linearly over the requested grid.
Lookback length barely affects the rolling kernel because it maintains running
sums rather than rescanning each window. At 1,260 sessions, quickr batch time
grew from 11.5 us for one configuration to 100.1 ms for 10,000.

OpenMP was not free. It was slower at 10 and 100 configurations and effectively
tied at 1,000 and 10,000; the largest row was only 1.01x faster than serial
quickr. This does not support parallelizing by default. Dependent time steps
remained serial inside each configuration.

### Compilation and break-even

Rcpp compiled all five entry points as one bundle in 3.21 seconds. quickr took
5.10 to 5.58 seconds per serial function and 7.19 seconds for the OpenMP batch.
ast2ast took 5.10 to 6.06 seconds per function. Most first calls were below the
clock resolution after compilation; the record retains the two measurable
first-call values.

Approximate call counts needed to recover compilation cost on the largest row
of each workload are:

| Kernel | quickr | ast2ast |
| --- | ---: | ---: |
| Rolling variance | 30 calls | 33 calls |
| Stateful, 2,520 pulses | about 12,300 calls | about 13,000 calls |
| Batch, 10,000 configurations | 3 calls | 3 calls |
| Explicit mask | 92 calls | 97 calls |

These are measured-component calculations, not separately timed workflows.
Package AOT moves compilation to installation and changes the user-facing
break-even, but it does not erase build time, binary portability, or dependency
cost. Runtime compilation is a poor default for one-off short state machines.

## Missing values and financial semantics

quickr's NA restriction is material. A safe design would have to:

1. replace missing numeric payloads with an arbitrary, ignored sentinel;
2. pass a separate integer/logical validity array;
3. branch on validity before reading the payload;
4. return validity separately when the output can itself be unavailable.

The passing mask probe proves feasibility, not that this representation should
enter ledgr. It increases API width and the chance of value/mask drift.

ast2ast preserved NA, NaN, and signed Inf in the direct probe. That does not
prove every reduction, comparison, or linear-algebra routine matches R's
missing-value behavior. Each selected kernel still needs a canonical R oracle.

No implementation silently zeroed, dropped, or carried a missing value.

## Developer ergonomics

### quickr

The source remains recognizably R, but every argument needs a type and shape,
returns must be atomic, named variables need stable shapes, and only a subset
of R is legal. The same source can usually execute in R because `declare()` is
a declaration, which is useful for oracle-first development. Translation
errors were compact. Package AOT is directly supported, while direct calls
from existing Rcpp code have no documented public pointer route.

### ast2ast

Types are explicit but local inference is effective. Compiler errors and bounds
errors retain source context, generated C++ is readable, and the XPtr route is
documented. The `argtypes()` statement means the exact compiler source is not
an ordinary base-R function without a small wrapper or stripped declaration.
`make_package()` is the strongest AOT story of the candidates. The GPL license
is a hard review item for an MIT package.

### nCompiler

`nFunction` is designed to run uncompiled and compiled, and its class,
automatic-differentiation, serialization, and mixed C++ ambitions are broad.
In practice it required the largest dependency stack, an undeclared `inline`
package at runtime compilation, and emitted a very large compile log before the
minimal stateful kernel failed in generated Eigen tensor code. Debugging was
the least approachable of the three in this run.

## Can the conceptual API work?

An interface resembling:

```r
compiled_kernel <- compile_kernel(kernel)
```

is technically possible only with a restrictive contract:

- numeric/logical scalar, vector, matrix, or fixed-rank array arguments;
- explicit stable types and shapes;
- no captured mutable environment, S3/S4 dispatch, arbitrary lists, or dynamic
  callbacks inside the kernel;
- one canonical R implementation and selected boundary cases;
- explicit missing-value policy, especially for quickr;
- compilation cached by source, types, compiler, package, and platform;
- compilation outside the pulse loop and preferably at package build time;
- atomic outputs or a deliberately typed output struct;
- fail-closed behavior on any parity mismatch.

Building that generic API now would violate the complexity gate. The smallest
next step is one named kernel whose repeated use already justifies compilation.

## Integration assessment

### Ahead-of-time compilation

Both primary candidates support a package-build path. quickr generates package
sources from named `quick()` calls. ast2ast `make_package()` generates package
C++ from dedicated R files. AOT is practical experimentally, but generated
source must be deterministic, reviewable, rebuilt per platform, and validated
in the minimum-R and CRAN-like toolchains.

### Calling from existing native code

ast2ast's XPtr can genuinely remove repeated R/native crossings when an
existing C++ owner calls a generated typed function. It also exposes ABI and
lifetime risks: exact ETR types, header versions, compiler compatibility, and
process-local pointer ownership. quickr exposes an R wrapper but no documented
public pointer ABI. nCompiler did not reach this question in execution.

The strongest architecture is a whole numerical or batch loop per native call,
not one call per pulse or scalar operation.

### Maintenance complexity

For a stable, small kernel, handwritten Rcpp remains simpler to package and
debug. A compiler becomes attractive when the source changes often, researchers
need to keep the algorithm in typed R, or many related parameter configurations
benefit from one compiled batch. A generic compiler layer would add more
maintenance than it removes today.

## Decision table

| Candidate | Category | Reason |
| --- | --- | --- |
| quickr | Promising for further experiments; useful for specialized numerical and batch functions | Best warm results here, package AOT, OpenMP, MIT; NA and pointer limitations remain |
| ast2ast | Useful for specialized numerical functions; promising only after license review | Correct stateful and batch kernels, package generation and XPtr; slower than quickr here and GPL-coupled |
| nCompiler | Inconclusive due to technical limitations | Active and ambitious, but the minimal generated kernel did not build on the recorded host |
| handwritten Rcpp | Continue as production reference | Stable native baseline, smallest known package risk, and already part of ledgr |

## Recommendation

- **A. Continue handwritten Rcpp:** yes, as the default production mechanism
  for performance-critical kernels.
- **B. Adopt a compiler for selected numerical functions:** do not adopt yet;
  run one package-built quickr experiment with cross-platform correctness and
  process-memory evidence.
- **C. Explore generated stateful kernels:** yes only as an isolated prototype
  over a deliberately small typed stage, not as a replacement fold engine.
- **D. Explore generated batch execution:** yes. This is the strongest result;
  compilation amortized in about three large calls and quickr beat the simple
  Rcpp reference on the 10,000-configuration row.
- **E. Defer general integration:** yes, until AOT portability, NA semantics,
  licensing, generated-source review, and one real ledgr-owned seam are settled.

The immediate usable conclusion is not "compile R automatically." It is:
typed R-to-native generation is credible enough to challenge handwritten Rcpp
for selected reusable batch kernels, while remaining too constrained and too
toolchain-sensitive for a general ledgr execution path today.
