# Compiler Landscape

Survey date: 2026-10-28. Execution used R 4.6.1 on Windows. Upstream status
was checked at the repository commits listed below; benchmark versions are the
versions in `results/windows-r4.6.1/environment.csv`.

## Summary

| Candidate | Surveyed upstream | Executed version | Status here | License |
| --- | --- | --- | --- | --- |
| quickr | `edd403766e612ef4867ad817ead3dc366dc15d77` (2026-09-07) | CRAN 0.3.0 | all five serial kernels and one OpenMP kernel compiled | MIT |
| ast2ast | `c1c82cc68d54e9f095f60b8e75bd5479416c1b61` (2026-10-28) | CRAN 1.1.1 | all five kernels compiled | GPL (>= 2) |
| nCompiler | `bf9ae45012c03a6603f1c0e2ff158b10c2a2bdca` (2026-10-27) | source 0.1 | package installed; generated stateful kernel did not build | BSD-3-Clause or GPL (>= 2) |

All three repositories showed recent activity. Maintenance inactivity is not
the reason for any negative result.

## quickr

### Toolchain and language

- CRAN 0.3.0 installed as a Windows binary; generated functions require C and
  Fortran compilers. Upstream recommends the latest Rtools on Windows.
- Arguments require explicit type and shape declarations.
- Atomic logical, integer, double, and complex vectors, matrices, and arrays
  are supported. Returns must also be atomic arrays; lists and dynamic R
  objects are outside the intended model.
- `for`, `while`, `repeat`, conditionals, nested local functions, reductions,
  and common BLAS/LAPACK operations are in the documented subset.
- Variable shapes are static during a function invocation.
- `NA` is explicitly unsupported. This spike therefore treats the direct NA
  round trip as unsupported even though the observed bit pattern survived the
  trivial copy. Observed `NaN` and `Inf` round trips agreed with R, but ledgr
  must not infer broader semantics from a copy probe.
- A numeric array plus an integer validity mask worked and matched R and Rcpp.
  The sentinel value in an invalid cell was deliberately non-zero, proving the
  mask rather than an accidental zero convention controlled the result.

### Compilation and parallelism

- `quick()` compiles eagerly in an interactive session.
- Named `quick()` calls in a package can be generated ahead of time by
  `quickr::compile_package()`; generated R and native sources live in the
  package and are built for the target platform.
- `declare(parallel())` applies OpenMP to the following independent loop.
  quickr does not choose the thread count; the runner set `OMP_NUM_THREADS=4`.
- Related local functions can be compiled inside one quick function. The
  public workflow still presents each top-level `quick()` call separately.

### Integration implications

The returned R function uses quickr's native wrapper. No documented public
function-pointer ABI was found for calling the generated Fortran function
directly from ledgr's existing C++ code. Package AOT is practical if quickr is
accepted as a build-time generator, but generated artifacts must be rebuilt
per platform and reviewed whenever quickr changes.

The MIT license is compatible with ledgr's current MIT license in principle.
That does not replace a dependency, packaging, and generated-code review.

## ast2ast

### Toolchain and language

- CRAN 1.1.1 installed as a Windows binary. The surveyed 1.1.2 source requires
  R >= 4.1, C++20, GNU make, and Rtools >= 4.5 on Windows.
- Scalars, vectors, matrices, multidimensional arrays, loops, conditionals,
  reductions, dense linear algebra, inner typed functions, and custom static
  types are supported.
- Dynamic typing, `NULL`, complex and character data, S3/S4 dispatch, and R's
  general recycling rules are not supported.
- Integer arguments require actual R integer inputs.
- The current differences vignette explicitly describes `NA`, `NaN`, and
  `Inf`; the direct round-trip cases in this spike agreed with R.
- Errors retain source locations and bounds checks, which was materially more
  helpful than debugging generated C++ without the translator context.

### Compilation and native interfaces

- `translate()` compiles at runtime and returns either an R-callable function
  or an external pointer.
- `make_package()` translates one or more R source files into package C++ and
  can expose several entry points. It copies headers into the target package,
  avoiding a runtime ast2ast dependency but not the generated-code obligation.
- `output = "XPtr"` is a documented C++ interface. The consumer must use the
  exact ETR function signature and include ast2ast/RcppThread headers.
- An XPtr is process-local. It is not a portable serialized artifact, and its
  ABI is coupled to generated types, headers, compiler, and library lifetime.

### Integration implications

ast2ast has the clearest path for calling a generated function from existing
C++ and for AOT package generation. It also has the largest licensing issue:
the package declares GPL (>= 2), while ledgr is MIT. Linking to or copying GPL
headers/generated material requires an explicit licensing review before any
product experiment. This report makes no legal conclusion.

## nCompiler

### Capabilities and observed failure

- nCompiler 0.1 requires R >= 4.1 and uses Rcpp, Eigen tensors, cereal, and
  RcppParallel. It provides typed `nFunction` and reference-semantics `nClass`
  constructs, uncompiled R execution, generated C++, automatic
  differentiation, basic TBB support, serialization, and basic package
  integration.
- Numeric scalars, vectors, matrices, higher-dimensional arrays, sparse
  structures, strings, and selected Rcpp types are described by the current
  manual. The API and manual still label several mechanisms as evolving.
- The package itself installed successfully from source. `nCompile()` first
  rejected `seq_len()`, so the probe was reduced to a documented `1:n` loop.
  Generated C++ then failed in `tensorFlex.h` with a request for
  `cast<int>` on a `long long int`. This is a current host/toolchain failure,
  not evidence that every nCompiler workload fails.
- `inline` was required when `nCompile()` ran but was absent from DESCRIPTION.

### Integration implications

nCompiler has ambitious class, serialization, AD, and package-integration
facilities, but it brought the largest dependency and compile surface and did
not produce the minimal stateful function here. It remains a secondary
candidate. Revisit only with a smaller upstream reproducer or after the
current generated-tensor/toolchain issue is resolved.

## Cross-cutting constraints

### Missing values

Compiler support is not a reason to change ledgr missing-data semantics.
quickr kernels would need an explicit value-plus-validity representation.
ast2ast can represent special values, but every actual operation still needs
semantic parity tests. No compiler path may silently zero, forward-fill, or
drop missing inputs.

### Build and artifact portability

Compiled DLLs, external pointers, and runtime compiler caches are not portable
package evidence. A product path would either compile at package build time or
compile on the user's machine with a supported toolchain. Source functions and
golden correctness cases are portable; generated binaries are not.

### Calling from ledgr native code

- quickr: no supported public pointer interface found.
- ast2ast: supported XPtr, with a narrow generated ETR ABI.
- nCompiler: mixed generated/handwritten C++ and generic pointers are design
  goals and work in basic forms, but were not executable for this kernel.

None of these findings authorizes integration into ledgr.

## Primary sources

- <https://github.com/t-kalinowski/quickr>
- <https://github.com/Konrad1991/ast2ast>
- <https://konrad1991.github.io/ast2ast/>
- <https://github.com/nimble-dev/nCompiler>
