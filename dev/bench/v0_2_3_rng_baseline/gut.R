# RNG baseline gut demonstration: runs check.R once as a control and once per
# corruption in rp_guts (probe.R). The control must pass; each corruption must
# make check.R fail and name every table it is expected to change. Writes
# gut_results.csv next to this script.
#
# Usage: Rscript gut.R

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[[1L]])) else getwd()
  assign("gt_here", normalizePath(here, winslash = "/"), envir = globalenv())
})
# Only the gut list is needed; parse probe.R without running it.
local({
  exprs <- as.list(parse(file.path(gt_here, "probe.R"), keep.source = FALSE))
  hit <- Filter(function(x) is.call(x) && identical(x[[1L]], as.name("<-")) && identical(x[[2L]], as.name("rp_guts")), exprs)
  assign("rp_guts", eval(hit[[1L]][[3L]]), envir = globalenv())
})

run_check <- function(gut) {
  args <- c(shQuote(file.path(gt_here, "check.R"), type = "cmd"),
    paste0("--out=", shQuote(file.path(tempdir(), paste0("rng_gut_", gut %||% "control")), type = "cmd")))
  if (!is.null(gut)) args <- c(args, paste0("--gut=", gut))
  out <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), args, stdout = TRUE, stderr = TRUE))
  list(status = as.integer(attr(out, "status") %||% 0L), out = out)
}
failed_tables <- function(out) {
  hits <- regmatches(out, regexpr("^FAIL [a-z_]+:", out))
  sort(unique(sub(":$", "", sub("^FAIL ", "", hits))))
}

control <- run_check(NULL)
cat("control:", tail(control$out, 1L), "\n")
rows <- list(data.frame(gut = "control", what = "no corruption", expected_tables = "", exit_status = control$status,
  failed_tables = paste(failed_tables(control$out), collapse = ","), ok = control$status == 0L, stringsAsFactors = FALSE))
for (name in names(rp_guts)) {
  g <- rp_guts[[name]]
  res <- run_check(name)
  got <- failed_tables(res$out)
  ok <- res$status != 0L && all(g$expect %in% got) && !"probe" %in% got && !"scope" %in% got
  cat(sprintf("%s: exit %d, expected [%s], failed [%s] -> %s\n", name, res$status, paste(g$expect, collapse = ","),
    paste(got, collapse = ","), if (ok) "caught" else "NOT CAUGHT"))
  rows[[length(rows) + 1L]] <- data.frame(gut = name, what = g$what, expected_tables = paste(g$expect, collapse = ","),
    exit_status = res$status, failed_tables = paste(got, collapse = ","), ok = ok, stringsAsFactors = FALSE)
}
results <- do.call(rbind, rows)
utils::write.csv(results, file.path(gt_here, "gut_results.csv"), row.names = FALSE)
pass <- all(results$ok)
cat(sprintf("rng gut: %s\n", if (pass) "PASS (control passes; every corruption fails check.R and names its tables)" else "FAIL"))
quit(status = if (pass) 0L else 1L)
