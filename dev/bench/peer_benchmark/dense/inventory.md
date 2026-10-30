# Dense native oracle inventory (workstream 2)

Candidate oracle freeze: **cbf25359**, product/recorder source **328998db**
(R/src identical to release/v0.2.3 at **145cc93b**). Intended independent
reviewer: **clean-context Claude CLI; acceptance pending**. No C1 consumption
until its Type 1 review accepts this immutable commit. Expected bytes have
not changed since the freeze. [Protocol](protocol.md) owns inputs/projections.

| Native arm | Fills | Exits | Diagnostic rows | State rows |
| --- | ---: | ---: | ---: | ---: |
| Historical start, dense | 121 | 57 | 0 | 90 |
| Historical start, facts | 121 | 57 | 1291 | 90 |
| Transition | 109 | 51 | 0 | 90 |
| Positive return | 155 | 74 | 0 | 0 |
| Mean reversion | 119 | 57 | 0 | 0 |
| Recursive EMA | 288 | 140 | 0 | 0 |
| Historical late, dense | 87 | 40 | 0 | 61 |
| Historical late, facts | 89 | 41 | 882 | 61 |
| Cost/final pulse | 1 | 0 | 0 | 0 |

The [native summary](oracles/20261030-pre-ws4/summary.csv) carries hashes/balances;
native.rds retains complete types, precision, missingness, attributes and
metadata, plus native config/strategy source, actual source and environment.
All nine arms reproduced exactly into fresh scratch; [differences](evidence/differences.csv)
is empty. Public native reconstruction owns positions/cash/pnl; no harness
accounting. Native final quantities include zero IDs. Opening holdings and
corporate actions are additionally protected by the independent A0 controls.

[First divergences](evidence/first_divergences.csv): the start arms' economic
fill projection agrees, but the first execution stamps are Jan 15 at 21:00
versus 14:30 UTC. Late-opening first fill/recording pulse is Feb 25 (dense)
versus Feb 12 (facts), preserving the history difference. No equivalence is
claimed between the arms; diagnostics and native states stay checked too.

[Six gut results](evidence/gut_differences.csv) name native fields/keys: fill
qty with equity unchanged; one-ULP cash (10000000 -> 10000000.000000002);
asset quantity with aggregate value unchanged; economic event order;
required final-pulse warning removed; prior usability removed from an
actually executed transition rule. Control passes; all corruptions fail.
There are six detectors here, four reserved for timing, no additional cases.

A0 remains separate: [reference pointers](oracles/20261030-pre-ws4/a0_references.csv)
name 39 existing tables across dense_risk_features/run (opening/risk/features),
dense_dividend_state/run (opening/dividend/state), failures/run_abort
(refusal). [Standalone implementer command/result](evidence/a0_implementer.txt)
records the later Cut 4 boundary. The original checker on the current tree
fails the 52 files that Cut 4 intentionally changed. At its pre-Cut-4 pinned
revision it has only the already identified `selected_at_utc` wall-clock
difference. Cut 4's accepted successor recorder/comparator is therefore the
current executable gate: [its 295 checks](evidence/a0_successor_compare.csv)
all pass from scratch. The reviewer must rerun that whole successor gate;
no new dense driver invokes or imports A0.

Reproduce from any cwd (use a new scratch --out each time):

```powershell
Rscript --vanilla dev/bench/peer_benchmark/dense/check.R --pkg=. --records=dev/bench/peer_benchmark/dense/oracles/20261030-pre-ws4 --out=<fresh-scratch>
Rscript --vanilla dev/bench/peer_benchmark/dense/gut.R --pkg=. --records=dev/bench/peer_benchmark/dense/oracles/20261030-pre-ws4 --out=<fresh-scratch>
Rscript --vanilla dev/bench/v0_2_3_cut3_successors/a0/record.R --pkg=. --out=<fresh-scratch>
Rscript --vanilla dev/bench/v0_2_3_cut3_successors/a0/compare.R --pkg=. --original=dev/bench/v0_2_3_output_freeze/records --successor=<same-scratch> --model=dev/bench/v0_2_3_cut3_successors/a0/model --result=<fresh-result.csv>
```

Scope: package/test/design diff and new-file inventory unchanged across runs.
LDG-3138's focused full test file passes; reverting the selector fails the
lower-cut witnesses. Both prerequisite probes/RFC inputs survive unchanged at
5d28db40 from source commit 7879e8ba.
Fresh R size: **519 lines** (check.R 22, gut.R 64, native.R 249, recipes.R 173, record.R 11);
400 timing lines planned, still below 1500. No product/API/schema/identity
change, no timing or peer result. No old harness infrastructure imported.

Rejected attempts: first scratch cost setup used NULL features and refused;
fixed to the public empty list before the freeze. First checker attempt
reproduced all native arms but rejected incidental A0 pointer row names;
fixed to explicit row.names=NULL with identical file/count columns and no
oracle-byte edit. Neither failed attempt is presented as accepted evidence.

Nothing retired: legacy peer commands stay maintained by WS1 until the final
replacement cut; A0 is never their retirement target. WS4 owns every proposed
calendar/stamp/diagnostic/history change and M8b final-bar disclosure. These
are unresolved receiving-cut duties, not oracle exemptions. Workstream 3
owns the later baseline; remaining peer lanes/report/retirement remain uncut.
