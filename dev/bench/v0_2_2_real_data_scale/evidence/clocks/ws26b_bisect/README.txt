Workstream 26 equal-weight isolation (close review F1).

For four WS26 code commits (7c86514c contains 5dc47b3d, LDG-3006),
run_pair.R compared each with 01acd4cd (WS25
accepted) over three alternating pairs, phases build and run_equal_weight
(readers is recorded too), with R_VSIZE=4Gb R_NSIZE=20M:

  R_VSIZE=4Gb R_NSIZE=20M Rscript run_pair.R <01acd4cd tree> <commit tree> <out> 3 --phases=build,run_equal_weight

<commit>/summary.csv holds the median ratios, <commit>/phases.csv the per-pair rows.
