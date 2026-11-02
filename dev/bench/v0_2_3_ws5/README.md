# WS5 implementation evidence

This directory is the bounded LDG-3179 inventory and implementation record for
the flat pulse context and canonical position facts. It reuses the package test
profiles and the shared timing harness; it adds no execution, replay, schema,
or validation layer.

The pre-acceptance public probes established three concrete gaps on the
accepted base: a typed state round trip changed an integer and lost atomic
empty values; a sparse unchanged-tail resume restarted from the last state row;
and a five-pulse run built five contexts and encoded/wrote five state rows.
Those state findings belong to LDG-3185/3186. WS5 records them but does not
implement a state path.

For WS5, `surface_inventory.csv` owns every removed and retained context
surface, `ownership_matrix.csv` maps every accepted detector family and
maintained consumer to a runnable mutation, and `maintained_state_census.csv`
records the release-facing maintained strategies reviewed for the later
declared-state cut. `expected_differences.csv` lists each proposed product
difference explicitly; `base_semantic_record.csv` records the accepted-base
semantic and preparation counts. `check.R` checks the exact inventories,
consumer set, claims, bases, timing cells and product-source prohibitions, so
omitting a named row fails the inventory gate. The semantic evidence is in
`test-flat-lazy-context.R`, `test-position-facts-context.R`, and the migrated
route tests; the ordinary fast profile is the aggregate gate.

The timing preregistration is
`dev/bench/timing/protocols/ws5-timing-1/`. Its 1.10 ratios are disposition
triggers, not correctness gates. Records compare separately with `14252ffb`
and the post-WS4a attribution base when the integrated Cut 7 candidate exists.
