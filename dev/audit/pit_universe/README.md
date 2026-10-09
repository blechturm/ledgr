# Point-in-time universe audit: fixture and schema

Preparation for the audit chartered in
`inst/design/audits/v0_2_2_pit_universe_audit/charter.md`. Built while Cut 11
Workstream 22 runs; Stages 1 to 3 run later on one frozen commit.

```sh
Rscript dev/audit/pit_universe/smoke.R <repo>
```

- `fixture.R`: `pit_audit_fixture(knowledge = "announcement" | "effective_only")`
  builds the shared semantic fixture through ledgr's public fact constructors;
  `pit_audit_snapshot()` seals it. It follows the frozen yardstick's section B
  dataset: 40 New York sessions from 2021-03-01 (crossing the March DST
  change), two ad hoc closed weekdays between s20 and s21, an early close on
  s30, and fifteen instruments in the yardstick's roles (seventeen IDs, since
  ticker reuse and redomicile become separate permanent IDs). Inputs only: no
  strategies, expected values or observations.
- `smoke.R`: checks that both knowledge variants build, seal and run a
  holding strategy to `DONE`. It asserts nothing about behavior.
- `coverage.csv`: every yardstick scenario (S01 to S41) with its guarantees,
  the yardstick's owner, whether ledgr's inputs can express it (`yes`,
  `partial`, `no`), the fixture elements and the paths Stage 1 should run.
  Input expressibility only; whether ledgr behaves correctly is Stage 1 to 3.

Observed while building (inputs to Stage 1, not findings yet): corporate-action
clocks that fall between run pulses refuse the run with
`ledgr_corporate_action_clock_mismatch`; the fixture places them on session
closes. A dividend with subtype `cash_dividend` seals but never posts;
only `ordinary_cash_dividend` posts (found while building the Cut 11 LDG-2982
scale fixture), so the fixture uses `ordinary_cash_dividend`. A bar on a session
the sealed session facts mark closed seals with no refusal and no quarantine
row (LDG-2982 recorder, `refusals` family).

## Inventory schema (Stage 1)

`inventory.csv`, one row per audit rule (charter, Scope):

| Column | Meaning |
| --- | --- |
| `rule_id` | `PIT-<subsystem number>-<sequence>`, e.g. `PIT-09-003` |
| `subsystem` | 1 to 14, as in the charter |
| `owner` | `adapter`, `ledgr`, `research` or `unclear` |
| `statement` | the observable semantic choice, in one sentence |
| `applies_to_paths` | subset of `run sweep promote walk_forward reconstruct readers ingest` |
| `code_location` | `R/file.R:function` at the frozen commit |
| `detecting_tests` | LTB IDs or `none` |
| `contract_heading` | contracts.md heading or `none` |
| `design_source` | accepted design document section or `none` |
| `evidence` | `read` or `probed` |
| `probe` | probe script and case, when probed |
| `yardstick` | related yardstick IDs, filled in Stage 3 only |
| `oddity` | `yes` when something looks wrong (not judged in Stage 1) |
| `notes` | free text |

`path_matrix.csv`, one row per public point-in-time entry point and path:
`entry_point, path, availability_active, rules (rule_id list),
intended_differences, evidence`.
