# Stage 5 closeout

**GREEN: the view stays within 5% on all four workloads (brief Section 6).** Context construction uses a prepared service and cutoff-bound view inside the existing fold. This is prototype evidence, not API acceptance.

| Workload | Current (s) | View (s) | Change |
| --- | ---: | ---: | ---: |
| 01_momentum_12_1.R | 2.840 | 2.805 | -1.23% |
| 02_momentr_funnel.R | 3.945 | 3.865 | -2.03% |
| 08_connors_rsi2.R | 10.820 | 9.765 | -9.75% |
| 09_turtle_donchian.R | 14.795 | 14.500 | -1.99% |

Stage 4's fixture, host and ordering were reused: 300 stocks plus SPY/BIL, 2017–2021, High performance, parent P-core mask 0xFFFF. Three alternating repetitions retain both former candidate slots (now the same view): six current/view pairs per workload, medians pooled by variant. Clock: `ledgr_run()` through native fills from a sealed snapshot. Snapshot preparation is separate; experiment-object construction is outside the clock, so this is an incomplete warm research-iteration clock. Every measured fill table equals current. The incomplete first attempt (missing Turtle `vec$id`) remains in `evidence/construction/`; ID and equal-weight NA handling were corrected before the complete gate.

**Fills (baseline/view):** 60/40 **91/91**, trend **47/47**, momentum **90/90**, gold sleeves **91/91**, Connors **2031/2031**, trailing stop **58/58**. All ten native columns equal exactly. Baselines match recorded stage 4 CSVs byte for byte. One portfolio-state peak restores the trailing stop's original entry-decision peak; cooldown uses bar age. No fill definition difference remains. The stage 3 regression checker also passed all sixteen strategies.

**Facts:** `entry_price` = remaining ledger basis / held quantity; FIFO partial sales can change it, and flat means NA. Entry bar records an observed flat-to-held fill and clears on full exit. Exit bar records the last held-to-flat fill and survives re-entry. `entry_at`/`exit_at` use those run-calendar bar timestamps (recording-pulse labels, not opening execution timestamps). Ages = current bar index minus recorded index, zero on that bar; skipped decisions count. Missing facts are NA. Inherited holdings have unknown entry time/age but a known supplied basis. Two integer vectors update by index without instrument loops or future data.

**Rebuild/isolation:** one pass over native fills reconstructs both vectors: at bar 639, entry **639**, exit **637**, exactly matching the view. All 1,045 decisions match independent position, FIFO basis, time and age arithmetic. Repeated reads cache once; saved views preserve positions and previously unread basis. `names()`/`str()` list columns. Scratch rerun CSVs reproduce exactly. Each gut fails its intended assertion: later-position leak, wrong entry bar, reserved name.

**Open points:** full resume/sweep/walk-forward plumbing remains outside the probe. Current error reporting still needs shared schema-only legacy fields. Internal target helpers use a lazy `vec` manifestation. The maintainer must accept the inherited-entry and timestamp definitions above. Cold read: [cold_read_v3.md](cold_read_v3.md).
