# Probe Findings

**Question:** can maintained R-to-native compilers correctly execute small
numerical, stateful, batched, and explicitly masked kernels on the maintainer
Windows toolchain?

**Result:** GREEN for quickr and ast2ast; inconclusive for nCompiler.

- quickr 0.3.0 and ast2ast 1.1.1 compiled all five serial functions. quickr
  also compiled the independent-configuration loop with OpenMP.
- Rcpp 1.1.2 compiled the handwritten bundle used as the native reference.
- The ten-case correctness record has no supported failure. The only
  unsupported row is quickr's direct `NA_real_` path; the explicit validity
  mask passes for all primary variants.
- nCompiler 0.1 installed, but its generated stateful kernel failed in the
  current Eigen tensor support on Windows/R 4.6.1. The primary experiments
  continued as chartered.
- The gutted Rcpp stateful result fails C03, C04, and C10. The harness therefore
  detects a real wrong native result rather than merely compiling code.

The smoke run justified the full grid. It did not show uncontrolled memory or
runtime growth; the largest record input was 1,260 sessions by 10,000
configurations and completed without parallelizing dependent time steps.
