.libPaths(c("E:/ledgr-data/r-lib/ledgr-0.2.1.0", .libPaths()))
ns <- asNamespace("ledgr.sharadar")
for (f in c("sharadar_ledgr_membership_facts", "sharadar_ledgr_membership_intervals", "sharadar_membership_representation_limit", "sharadar_validate_membership_fact_clocks")) {
  cat("\n#####", f, "\n"); print(get(f, ns))
}
