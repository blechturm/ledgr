# Workstream 31 focused Type 1 re-review

**Verdict:** CHANGES_REQUIRED for two low record findings only. The five
original findings are closed in the product, and no further review round is
required. The maintainer may verify the two mechanical corrections from the
diff.

## Closed findings

- Seeded runs and sweeps are deterministic and restore the caller's RNG;
  `seed = NULL` continues to use ambient RNG. Removing fold seeding fails
  LTB-0268 ten times.
- Empty census families work, the report and test condition inventories agree
  on 366 public classes, every retained test seam has a contract, and the
  stale condition class is absent.
- The full heavy protocol passes 189/189, and the fixture ladder from
  `0d04f22f` to `4b729300` is 51/51 identical, including identity.

## Record findings

1. GitHub Actions run `38578216775` is green, but its three ordinary fast
   runs took 176.3, 172.6 and 171.7 seconds. Hosted timing is advisory and
   exceeded the 112-second bound; the binding local record has a 105.64-second
   median. Records that called the hosted gate a pass must be corrected.
2. `ledgr_compute_features` is an unused v0.1.0 database-writing engine. Its
   tests exercise only that dead implementation. Delete it and those tests
   rather than retaining a false test-seam contract. Repointing tests at the
   live feature-series path would also have been acceptable if they covered a
   production rule.

Under M1 this is Workstream 31's second review round. The corrections need
focused evidence but no third review invocation.
