# Count test blocks using each control/identity helper (fork part_controls).
b <- utils::read.csv("C:/Users/maxth/ledgr-wt/cut27-scratch/out/ldg3280/census_hits.csv", stringsAsFactors = FALSE)
tdir <- "C:/Users/maxth/ledgr-wt/pin-src-7f65733f/tests/testthat"
src <- list()
helpers <- list(
  "helper-fixtures.R ledgr_test_run" = list(pat = "\\bledgr_test_run\\(", files = NULL),
  "helper-fixtures.R ledgr_test_snapshot_backed_config" = list(pat = "\\bledgr_test_snapshot_backed_config\\(", files = NULL),
  "helper-fixtures.R ledgr_test_modernize_config" = list(pat = "\\bledgr_test_modernize_config\\(", files = NULL),
  "helper-history-fixtures.R ws42_with_schedule" = list(pat = "\\bws42_with_schedule\\(", files = NULL),
  "test-config.R ledgr_test_current_config" = list(pat = "\\bledgr_test_current_config\\(", files = "test-config.R"),
  "test-acceptance-v0.1.1.R v011_make_runner_cfg" = list(pat = "\\bv011_make_runner_cfg\\(", files = "test-acceptance-v0.1.1.R"),
  "test-runner-snapshots.R runner_snapshot_config" = list(pat = "\\brunner_snapshot_config\\(", files = "test-runner-snapshots.R"),
  "test-terminal-policy-identity.R terminal_policy_hash" = list(pat = "\\bterminal_policy_hash\\(", files = "test-terminal-policy-identity.R"),
  "test-fifo-opening-positions.R fifo_opening_config" = list(pat = "\\bfifo_opening_config\\(", files = "test-fifo-opening-positions.R"),
  "test-fifo-opening-positions.R fifo_opening_run" = list(pat = "\\bfifo_opening_run\\(", files = "test-fifo-opening-positions.R")
)
own <- "execution_mode|checkpoint_every|db_live"
out <- character()
for (h in names(helpers)) {
  sel <- seq_len(nrow(b))
  if (!is.null(helpers[[h]]$files)) sel <- which(b$file %in% helpers[[h]]$files)
  hit <- character(); own_hit <- character()
  for (i in sel) {
    f <- b$file[i]
    if (is.null(src[[f]])) src[[f]] <- readLines(file.path(tdir, f), warn = FALSE)
    l <- src[[f]][b$first[i]:b$last[i]]
    if (any(grepl(helpers[[h]]$pat, l, perl = TRUE))) {
      if (any(grepl(own, l))) own_hit <- c(own_hit, paste0(f, ":", b$first[i])) else hit <- c(hit, f)
    }
  }
  tab <- table(hit)
  out <- c(out, sprintf("%s: %d blocks (without own control) in %d files; %d blocks pass a control themselves (own rows: %s)",
    h, length(hit), length(tab), length(own_hit), paste(own_hit, collapse = ", ")),
    paste0("  ", names(tab), " (", as.integer(tab), ")"), "")
}
writeLines(out, "C:/Users/maxth/ledgr-wt/cut27-scratch/out/ldg3280/part_controls_helper_users.txt")
cat(out[!grepl("^  ", out)], sep = "\n")
