# Cut 7 final timing records

These are the registered `ws5-timing-1` records for the Workstream 18
candidate `e04786ef`. Each comparison contains eight alternating pairs across
nine cells (144 fresh-process slots), and every slot completed with identical
economic controls.

## Release comparison

`cut7-final-v022-fixed/attempt-1` compares the candidate with the v0.2.2
release base `14252ffb`. The registered checker passes every 1.10 disposition
threshold.

| cell | candidate/base |
| --- | ---: |
| fixed no-fill | 0.973 |
| declared no-fill | 0.982 |
| fixed sparse | 0.955 |
| declared sparse | 0.955 |
| fixed wide | 1.002 |
| declared wide | 1.024 |
| fixed state change | 0.959 |
| fixed state unchanged | 0.926 |
| experiment construction | 1.003 |

## Post-WS4a attribution comparison

`cut7-final-ws4a-fixed/attempt-1` compares the candidate with the
post-WS4a attribution base `b5622f09`. The registered checker returns `FAIL`
for the five fixed-basket cells shown below. This is a descriptive disposition
trigger, not a Workstream 18 acceptance clock. Declared-session cells improve
and construction is neutral; the remaining fixed-basket premium stays owned by
macro WS14's performance-convergence checkpoint. No second execution path is
restored.

| cell | candidate/base |
| --- | ---: |
| fixed no-fill | 2.762 |
| declared no-fill | 0.747 |
| fixed sparse | 2.758 |
| declared sparse | 0.929 |
| fixed wide | 1.600 |
| declared wide | 0.869 |
| fixed state change | 2.068 |
| fixed state unchanged | 2.039 |
| experiment construction | 1.000 |

Reproduce either result with:

```text
Rscript dev/bench/timing/check.R \
  --protocol=dev/bench/timing/protocols/ws5-timing-1 \
  --record=dev/bench/timing/records/ws5-timing-1/<label>/attempt-1
```
