# Spike Inventory

## Runnable paths

- Base R loop references: numerical, stateful, repeated batch, masked mean.
- Idiomatic R alternatives: cumulative-sum rolling variance and matrix batch.
- quickr: five serial functions plus one OpenMP batch function.
- ast2ast: five serial functions.
- Rcpp: one bundle containing all five native references.
- nCompiler: installation and opt-in compile diagnostic only.

## Gutted path

`--verify-gut` subtracts one from the Rcpp stateful result after execution.
The correctness oracle records failures in the no-trade, trading-cost, and
repeat cases. The checker refuses a run in which this gut is not detected.

## Demoted or stopped

- nCompiler performance rows: stopped after the minimal generated stateful
  function failed to build.
- ast2ast parallel batch: not added; proving its `pmap` representation would
  expand the spike without changing the primary serial feasibility answer.
- Direct quickr NA arithmetic: demoted to unsupported by upstream contract.
- Empty matrices: not forced through compilers whose static loop syntax does
  not promise R's zero-length iteration. Product admission rules would own it.
- Package integration, caching, and cross-platform binaries: assessed from
  public facilities, not implemented.
- ledgr execution semantics: never imported into the harness.

## Learned

Generated code can match or beat a straightforward Rcpp implementation for
typed loops, especially batched independent simulations. Compilation takes
seconds, and the supported-R subset is narrow. The likely next useful result
is one selected, reusable package-built numerical kernel with cross-platform
parity - not a generic `compile_kernel()` layer and not a compiled second fold
engine.
