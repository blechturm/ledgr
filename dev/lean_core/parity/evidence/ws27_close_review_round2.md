PASS

The corrected LDG-3213 Acceptance 1 evidence matches `fifo_streams.csv` and the round-one reproduction: 18 streams, 1,560 steps and 181 refusals. All shared columns match `streams_actual.csv` row for row. The committed CSV totals 10,461 rows and 1,560 identical steps in each debug mode, consistent with `probe_evidence.txt`.

No other numerical contradiction was found in the LDG-3213 or LDG-3214 evidence against its cited files. Checked the parity, refusal, mutation and review records, operation-group and per-pulse timing CSVs, profile percentages, and saved gate/smoke records. The gate has eight pairs per cell and median ratios 0.404535, 0.398615, 0.406375 and 0.398960, which round to the ticket's values; the smoke ratio rounds to 0.404.

This was the requested narrow, read-only evidence re-review. No worktree files were edited, and no execution or timing probes were rerun.
