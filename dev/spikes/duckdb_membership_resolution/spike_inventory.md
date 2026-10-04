# DuckDB membership-resolution spike inventory

## Demoted

- Moving in-memory fact families through a temporary DuckDB database was
  demoted. It adds serialization to a path that already owns typed R columns.
- A second SQL membership resolver was demoted. The candidate only prunes
  persisted history and calls the retained R resolver on the reduced input.

## Deleted

- No schema, index, component hash, stored cache, alternate evidence format or
  provider path was added.

## Learned

- SQL pushdown is conditional on a late complete-set boundary. With only an
  initial complete set, all history remains relevant and the database adds no
  speed.
- With 600 sets and the last complete set at 501, only the final 100 sets need
  cross the R boundary. Set-less assertions still have to be loaded because
  the existing contract applies every applicable one after set processing.
- Full-universe and explicit-instrument inspection can share the same pruning
  rule and retained R resolver.
- The pruning boundary must be selected after ordering eligible headers with
  the retained R resolver's own `order()` rule. DuckDB byte collation is not an
  exact substitute for locale-sensitive R ordering when set IDs tie on both
  clocks.

## Gut

The gut chooses a boundary one header after the last eligible complete set.
That is the dangerous direction: it drops the reset header rather than loading
a harmless superset. The changing-composition fixture and the tied mixed-case
fixture then change deterministic membership or evidence.
