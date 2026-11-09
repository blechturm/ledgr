CHANGES_REQUIRED

1. **[P2] Step 4 reports candidate-derived limits as the frozen LDG-3215 budgets.** [tickets.yml:4347](C:/Users/maxth/ledgr-wt/ldg3217-review/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:4347) reports 24,946.6 and 258.4 us as the LDG-3215 budgets. Recomputing `1.15 * median(total_us)` from the committed pinned `prep_read_budget_raw.csv` gives **25,319.8 and 262.7 us**, respectively; the pinned `prep_read_budget.csv` agrees.

   | Workload | Frozen pinned budget (us) | Reported budget (us) | Lean median (us) |
   | --- | ---: | ---: | ---: |
   | 500 x 1,260 | 25,319.8 | 24,946.6 | 21,692.7 |
   | 40 x 504 | 262.7 | 258.4 | 224.7 |

   The reported limits instead equal 115% of the **lean** medians: [prep_read_probe.R:181](C:/Users/maxth/ledgr-wt/ldg3217-review/dev/bench/v0_2_3_cut12_floor_budget/prep_read_probe.R:181) recomputes `budget_us` from whichever arm is running. Correct the evidence to use the frozen pinned limits and distinguish those from candidate-derived limits in the candidate output. The conclusion that both measured workloads pass remains correct.

   Reproduced with [recompute_budget.R](C:/Users/maxth/ledgr-wt/ldg3217-review-out/recompute_budget.R); results: [recomputed_budget.csv](C:/Users/maxth/ledgr-wt/ldg3217-review-out/recomputed_budget.csv).

   ```powershell
   & "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" C:/Users/maxth/ledgr-wt/ldg3217-review-out/recompute_budget.R
   ```
