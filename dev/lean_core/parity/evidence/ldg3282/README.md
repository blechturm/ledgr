# LDG-3282: the recorded oracle

Cut 27 decision 7 (macro WS14a obligation 4; deletion-readiness Q1): the
new pin's oracle outcomes, recorded while both cores exist, a pin-free
checker, and the coverage matrix (`coverage_matrix.md`).

## Where the records are

- **Retrieval location:** `C:/Users/maxth/ledgr-wt/pin-outcomes-7f65733f`,
  outside the tree, every file read-only, 236 files, 71,164,890 bytes.
  - `gate/<workload>.rds`: 235 files.
  - `cut18/cut18_pin.rds`.
- **Manifest (committed here):**
  - `oracle_records.csv`: per file, its kind, key, path, bytes and sha256.
  - `oracle_tables.csv`: 3,730 rows, one per recorded table or case:
    path, table, row count, column names in order, column types, sha256.
  Written by `../../oracle_manifest.R --records=<location> --out=<here>`.

## What was recorded, and how

- **Build:** the pin 7f65733f, installed library
  `C:/Users/maxth/ledgr-wt/pin-lib-7f65733f` (`LEDGR_INSTALLED_FROM_COMMIT`
  7f65733f). Toolchain: R 4.6.1 (2026-06-24 ucrt), duckdb 2.0.1, collapse
  2.1.9, DBI 1.3.0, mirai 2.7.4, nanonext 1.10.4, TTR 0.24.4, cpp11 0.5.5,
  digest 0.6.39.
- **Corpus inputs:**
  - the gate's workloads as defined in `loop_parity.R` and the
    `loop_workloads*.R` files;
  - the A0 fixtures in `dev/bench/v0_2_3_output_freeze`;
  - the feature oracle's corpus in `dev/feature_parity/corpus.R`;
  - the cut18 cases of `cut18_witness.R` and `cut18_witness_cases.csv`;
  all at branch cut27-dev, with lean code unchanged since 268bcd90.
- **Commands:**
  - `loop_parity.R --lib=<pin library> --debug=0 --freeze=loop_freeze.csv
    --dump=<location>/gate --dump-lean=1`: the pin arm is the record. The
    same run is LDG-3283's debug-0 gate: 3,585 tables, 0 different,
    PASS 229 and PASS* 6, every frozen path checked
    (`../ldg3283/gate_debug0.*`).
  - `cut18_witness.R --lib=<pin library> --dump=<location>/cut18`: 145 cases
    at both debug settings, 0 differ.
  The lean arm's dumps are the candidate outputs below; they are not
  records.
- **Canonical form (gate):** A0's (`dev/bench/v0_2_3_output_freeze/lib.R`).
  Every cell is a string or NA, doubles are written `%.17g`, whole-second
  times as ISO UTC, and rows are in each table's declared key order. Column
  classes are kept in the attribute `a0_types`. Paths and source references
  are tokenized (`<DB_PATH>`, `<SRCREF>`). An error that escapes a workload
  is the table `escaped/error` (class, message); none did.
- **Clock and environment exclusions:** `a0_exclusions` drops only
  registration and telemetry wall clocks, version strings, R and dependency
  versions, the random sweep id and serialized payload sizes. Section 19's
  clock fields are not in run tables.
- **Cut18 records:** each case's outcome as compared there. A value is
  `list(value = ...)` (84 cases). A refusal (61 cases) is
  `list(error = <class, fields without trace or parent, call name, and the
  parent condition the same way, recursively>)`.
- **Sizes:** 3,585 gate tables with 4,440,523 rows in all.

## The checker

`../../oracle_check.R --records --manifest --candidate --out [--accepted]`
loads no ledgr; it asserts this at the end.
1. It checks every record against the manifest: missing, extra and
   corrupt files fail.
2. It compares each candidate output (`gate/<workload>_lean.rds`,
   `cut18/cut18_lean_d0.rds` and `_d1.rds`) with its record by
   `identical()`, path by path and table by table.
3. A difference passes only when `--accepted` lists it with its authority
   and the candidate table's exact sha256. A listed difference that no
   comparison shows also fails.

On the full corpus with the candidate's own outputs (the lean arm of the
recording run, the cut18 lean outcomes): `check_full.csv`, `.log`:
IDENTICAL 3,875 (3,585 gate tables, and 145 cases at two debug settings),
ORACLE CHECK PASS.

## Controls

`../../oracle_controls.R` runs the checker on scratch copies
(`controls.csv`, `.log`). Every scenario gives its expected result:

| Scenario | Expected and observed |
| --- | --- |
| full | PASS |
| missing_record, extra_record, corrupt_record (one byte) | FAIL, each with its message |
| missing_output | FAIL |
| changed_gate (one digit of one cell), changed_cut18 (one value) | FAIL |
| accepted (the changed cell listed with its digest) | PASS, ACCEPTED 1 |
| accepted_wrong_digest, accepted_unused | FAIL |
| mutated: a real lean variant (`fill_price_ulp` on crossover_3x40, loop_parity.R --mutation --dump-lean) | FAIL |

## The coverage matrix

`coverage_matrix.md` maps every Section 5 family and every merge witness to
its recording and checker, or to a named obligation (O1 to O8).
`matrix_check.R` checks it against the records (`matrix_check.txt`): no
cited workload is unknown, and every recorded workload is in some family
row.

## Found on the way

loop_parity.R saved a workload's worker table as `<id>_workers.rds`, and
two workload names end in `_workers`. witness_sweep has no worker table, so
nothing was overwritten in this recording. The worker table is now
`<id>__workers.rds`.
