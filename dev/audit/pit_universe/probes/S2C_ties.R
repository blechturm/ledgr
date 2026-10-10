# Stage 2 challenger probe (S2-013): does the collation dependence of
# ledgr_select_top_n() ties need mixed-case IDs, or does it also hit
# uppercase ticker-style IDs with punctuation or digits? No database.
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/S2C_ties.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
sets <- list(
  punct = c("BRKB", "BRK.B", "BRK-A", "BRKA"),
  digits = c("A10", "A9", "A_1", "A1")
)
for (nm in names(sets)) {
  ids <- sets[[nm]]
  sig <- ledgr_signal(stats::setNames(rep(1, length(ids)), ids), origin = "tie")
  for (loc in c("C", "English_United States.1252")) {
    old <- Sys.getlocale("LC_COLLATE")
    ok <- suppressWarnings(Sys.setlocale("LC_COLLATE", loc))
    sel <- ledgr_select_top_n(sig, 2)
    cat(sprintf("[%s] LC_COLLATE=%s (set=%s): selected=%s | provider order=%s\n", nm, loc, nzchar(ok),
                paste(sort(names(sel)[sel], method = "radix"), collapse = ","),
                paste(ledgr_availability_stable_ids(ids), collapse = ",")))
    Sys.setlocale("LC_COLLATE", old)
  }
}
