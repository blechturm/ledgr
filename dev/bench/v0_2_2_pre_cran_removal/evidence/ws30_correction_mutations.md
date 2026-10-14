# WS30 Focused-Correction Mutation Results

Date: 2026-10-14  
Implementation: `46a761be`  
Claim-profile correction: `c566e433`

Each mutation was applied alone in the implementation worktree, its owning
block or checker was run, and the original file was restored content-identical
before the next mutation.

| Finding | Smallest restored defect | Detecting result |
| --- | --- | --- |
| N1 | Let `ledgr_metric_kernel()` infer cadence from the two weekly pulses instead of using the recorded 252 periods | LTB-0265 failed once because the restored path inferred 52. |
| N2 | Run the current valuation-policy schema guard through the full shape parser before ordinary validation | LTB-0264 errored on the malformed schema-2 policy instead of preserving its original shape condition. |
| N3 | Add one literal `availability_close_v1` source arm | `check-codebase-contracts.R --mode=check` exited nonzero with one current-only version violation. |
| N4 | Force `telemetry_missing <- FALSE` after deleting the run's telemetry row | LTB-0264 failed once on the missing-row flag. |
| Locale identity | Restore ordinary `order(nm)` in both canonical named-key branches | LTB-0266 failed twice: canonical JSON and config hash differed across the two proven-different collation orders. |
| Identity type | Restore numeric acceptance/coercion in config validation and stored registration | LTB-0264 failed three assertions across double, character and resume witnesses. |

The registered test and checker commands, final gate records and source census
are cited from LDG-3028, LDG-3029 and LDG-3036 in `tickets.yml`.
