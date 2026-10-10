# Stage 1 probe B: ledgr_select_top_n() tie order under two collation
# locales (subsystem 7). Description only; no database.
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/B_helper_ties.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE)

ids <- c("b2", "B1", "a3", "A4")
sig <- ledgr_signal(stats::setNames(rep(1, 4), ids), origin = "tie")
for (loc in c("C", "English_United States.1252")) {
  old <- Sys.getlocale("LC_COLLATE")
  ok <- suppressWarnings(Sys.setlocale("LC_COLLATE", loc))
  sel <- ledgr_select_top_n(sig, 2)
  cat(sprintf("LC_COLLATE=%s (set=%s): selected=%s | provider stable order=%s\n",
              loc, nzchar(ok), paste(names(sel)[sel], collapse = ","),
              paste(ledgr_availability_stable_ids(ids), collapse = ",")))
  Sys.setlocale("LC_COLLATE", old)
}
