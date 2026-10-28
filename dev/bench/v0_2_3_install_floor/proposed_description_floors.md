# Proposed DESCRIPTION floors (M4, for the WS13 cut)

Proposal only. `DESCRIPTION` is not edited by M4. Every proposed floor is the
version in the minimum coherent snapshot, P3M CRAN `2026-10-24`
(`find_snapshot.R`, `snapshot_search.csv`), on which ledgr installed and passed
its floor checks (`floor_checks.csv`). Existing floors are unchanged.

```diff
 Imports:
     collapse (>= 2.1.8),
-    codetools,
-    DBI,
-    digest,
+    codetools (>= 0.2-20),
+    DBI (>= 1.3.0),
+    digest (>= 0.6.39),
     duckdb (>= 2.0.0),
-    rlang,
-    tibble,
+    rlang (>= 1.3.0),
+    tibble (>= 3.3.1),
     yyjsonr (>= 0.1.22)
 LinkingTo:
-    cpp11
+    cpp11 (>= 0.5.5)
```

## Reason per floor

| Package | Proposed floor | Reason |
| --- | --- | --- |
| codetools | 0.2-20 | Snapshot version. It is the recommended-package version bundled with R 4.6.1 here, and 0.2-20 itself declares `R (>= 4.6)`, so the floor costs an R >= 4.6.0 user nothing. Unchanged since the R 4.6.0 snapshot (2026-04-25). |
| DBI | 1.3.0 | Snapshot version; also the version on 2026-04-25. duckdb 2.0.0 imports DBI without a version, so nothing above forces it. |
| digest | 0.6.39 | Snapshot version; also the version on 2026-04-25. |
| rlang | 1.3.0 | Snapshot version. Inside the set, the highest declared need is `vctrs: rlang (>= 1.1.7)`; on 2026-04-25 CRAN had 1.2.0. 1.3.0 is proven, not necessary: no environment older than 2026-10-24 was installed. |
| tibble | 3.3.1 | Snapshot version; also the version on 2026-04-25. |
| cpp11 | 0.5.5 | Snapshot version; `src/` compiled against its headers in `R CMD INSTALL`. On 2026-04-25 CRAN had 0.5.4. As with rlang, proven rather than necessary. |

Unchanged: `collapse (>= 2.1.8)`, `duckdb (>= 2.0.0)`, `yyjsonr (>= 0.1.22)`,
`R (>= 4.6.0)`.

## Information only (brief Section 3, step 2)

Per-floor earliest snapshot (`snapshot_search.csv`):

- `yyjsonr (>= 0.1.22)`: 2026-04-25, the first snapshot after the R 4.6.0
  release (2026-04-24).
- `collapse (>= 2.1.8)`: 2026-08-31.
- `duckdb (>= 2.0.0)`: 2026-10-24. This floor alone sets the minimum date.

Without the DuckDB floor the minimum snapshot would be 2026-08-31, where the
six unfloored packages have the same versions as in 2026-10-24. Without the
DuckDB and collapse floors it would be 2026-04-25, where `rlang` is 1.2.0 and
`cpp11` is 0.5.4; all others are the same. That earlier environment was not
installed or tested.

The floors above are sufficient as measured; none is shown to be necessary.
Because the minimum date is four days before this measurement, the
"minimum" environment is close to current CRAN for every package.
