# LDG-2951 candidate record

This record compares the committed pre-production baseline
`55e817d27dcb6a5f3dbcaa959b8b039e3d24819a` with production candidate
`f8080a7ac5252eb2ce7febb7c3628d11f61f4101`. The checker at `9cce23d`
passed the complete record without invoking the registered retry.

The registered fixture contains 1,514 sessions, 600 physical instruments,
500 members, 12 membership sets, 908,400 bars and three returns features.
The independent persistence variants both passed their unmarked gates:

| persistence | peak RSS ratio | elapsed ratio |
| --- | ---: | ---: |
| off | 0.8566 | 0.9981 |
| on | 0.8683 | 0.9991 |

Peak child RSS therefore fell 14.3% with persistence off and 13.2% with
persistence on. Elapsed time was unchanged within 0.2%. All five alternating
pairs are retained in `measurements.csv`.

Separate marked runs attribute the reduction without using their `gc()`
measurements as a gate. Live memory at the feature boundary fell from 483.8
MiB to 361.9 MiB. At fold entry it fell from 526.7 MiB to 352.2 MiB, and at
finalization from 531.4 MiB to 356.9 MiB, in both persistence variants.
The fold interval set the marked peak in every arm: 775.6 and 776.1 MiB in
the accepted persistence-off and persistence-on arms, and 603.6 MiB in both
candidate arms. The feature interval was lower in every arm.

Separate oracle runs compare completion, equity, fills, trades, diagnostics,
decoded strategy state, persisted feature rows and availability output
exactly. The dense witness also matches exactly. The mutation self-test
changes the normalized equity hash and is rejected.

The record used R 4.6.1, DuckDB 1.5.6.9000 and collapse 2.1.8. Two attempted
launches ended before fixture construction because sandboxed R children could
not create the `C:/tmp` output directory; neither produced a measured row and
neither is evidence. The successful run used the same registered command with
the required filesystem permission.

The compact checked-in record excludes the generated DuckDB fixtures and
child stdout and stderr files. Its CSV and JSON files contain every measured
row and every value consumed by the checker.
