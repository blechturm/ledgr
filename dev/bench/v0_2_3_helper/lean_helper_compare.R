# Cut 17 (LDG-3233): the lean loop on slice2_10x7200 with the pin's sizing
# helper against the rewritten one. The lean execution sources are the same
# in both arms (dev/lean_core at this commit); only the installed package
# differs: --base-lib (pin d5b3a151) and --cand-lib (the rewrite, whose R/
# differs from the pin only in R/strategy-helpers.R and R/strategy-types.R).
# The lean files are sourced over the arm's namespace and installed as in the
# cut16-loop-1 workload (lean_core_load() accepts only the pin, so it is not
# used). Each observation is one fresh process; arms alternate, base first in
# odd rounds. Run under the host policy (pcore.ps1, High performance).
#
#   Rscript dev/bench/v0_2_3_helper/lean_helper_compare.R --base-lib=<lib> --cand-lib=<lib>
#     --out=<dir> [--rounds=7] [--shape=slice2_10x7200]
# One arm (internal): --arm-lib=<lib> --arm=<name> --shape=<id> --row=<file>

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
shape <- opt("shape", "slice2_10x7200")

if (!is.null(opt("arm-lib"))) {
  lib <- normalizePath(opt("arm-lib"), winslash = "/", mustWork = TRUE)
  suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
  ns <- asNamespace("ledgr")
  if (!identical(dirname(normalizePath(getNamespaceInfo(ns, "path"), winslash = "/")), lib)) stop("ledgr not loaded from ", lib)
  defs <- new.env(parent = ns)
  sys.source(file.path(repo, "dev/spikes/r_floor/fixture.R"), envir = defs, keep.source = FALSE)
  sys.source(file.path(repo, "dev/bench/v0_2_3_lean_tuning_profile/descriptors.R"), envir = defs, keep.source = FALSE)
  desc <- defs$bench_descriptor(shape)
  store <- tempfile(fileext = ".duckdb")
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(desc$bars(), db_path = store, snapshot_id = "lh",
    price_basis = "split_adjusted"))
  snapshot <- ledgr::ledgr_snapshot_open(store, "lh", verify = TRUE)
  exp <- desc$experiment(snapshot)
  lean <- new.env(parent = ns)
  lean$.lean_debug <- FALSE
  for (f in c("fifo.R", "plan.R", "loop.R", "loop_harness.R")) {
    sys.source(file.path(repo, "dev/lean_core", f), envir = lean, keep.source = FALSE)
  }
  for (f in ls(lean, all.names = TRUE)) if (is.function(lean[[f]])) assign(f, compiler::cmpfun(lean[[f]]), envir = lean)
  restore <- lean$lean_loop_install()
  now <- function() as.numeric(Sys.time())
  clk <- new.env(); clk$fold <- 0
  inner <- get("ledgr_fold_envelope", envir = ns)
  unlockBinding("ledgr_fold_envelope", ns)
  assign("ledgr_fold_envelope", function(execution, output_handler) {
    t0 <- now(); on.exit(clk$fold <- clk$fold + (now() - t0)); inner(execution, output_handler)
  }, envir = ns)
  lockBinding("ledgr_fold_envelope", ns)
  invisible(gc(FALSE))
  t0 <- now()
  bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = "lh", seed = 20260530L))
  run_s <- now() - t0
  unlockBinding("ledgr_fold_envelope", ns); assign("ledgr_fold_envelope", inner, envir = ns); lockBinding("ledgr_fold_envelope", ns)
  if (lean$lean_entry$lean_folds != 1L) stop("the lean loop did not run")
  reach <- desc$reach(bt)
  fills <- as.data.frame(ledgr::ledgr_results(bt, "fills"))
  eq <- ledgr::ledgr_results(bt, "equity")
  diag <- as.data.frame(ledgr::ledgr_results(bt, "diagnostics"))
  sizing <- diag[!is.na(diag$stage) & diag$stage == "sizing", , drop = FALSE]
  close(bt); restore(); ledgr::ledgr_snapshot_close(snapshot)
  sha <- function(x) substr(digest::digest(serialize(x, NULL, version = 2L), algo = "sha256", serialize = FALSE), 1L, 16L)
  work <- paste(shape, nrow(fills), format(eq$equity[nrow(eq)], digits = 17), sha(fills), nrow(sizing), sha(sizing),
                paste(names(reach), reach, sep = "=", collapse = ","), sep = "|")
  utils::write.csv(data.frame(arm = opt("arm"), lib = lib, run_s = run_s, fold_s = clk$fold, work = work), opt("row"), row.names = FALSE)
  quit(status = 0L)
}

out <- opt("out"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
rounds <- as.integer(opt("rounds", "7"))
libs <- c(base = opt("base-lib"), candidate = opt("cand-lib"))
rscript <- file.path(R.home("bin"), "Rscript.exe")
self <- file.path(here, "lean_helper_compare.R")
rows <- list()
for (r in seq_len(rounds)) {
  order <- if (r %% 2L) c("base", "candidate") else c("candidate", "base")
  for (a in order) {
    row <- tempfile(fileext = ".csv")
    st <- system2(rscript, c(self, paste0("--arm-lib=", libs[[a]]), paste0("--arm=", a), paste0("--shape=", shape), paste0("--row=", row)),
                  stdout = FALSE, stderr = FALSE)
    if (st != 0L || !file.exists(row)) stop("arm ", a, " round ", r, " failed")
    x <- utils::read.csv(row, stringsAsFactors = FALSE); x$round <- r
    rows[[length(rows) + 1L]] <- x
    cat(sprintf("round %d %-9s run %.2f s fold %.2f s\n", r, a, x$run_s, x$fold_s))
  }
}
raw <- do.call(rbind, rows)
if (length(unique(raw$work)) != 1L) stop("work strings differ between runs: ", paste(unique(raw$work), collapse = " / "))
utils::write.csv(raw, file.path(out, "lean_helper_raw.csv"), row.names = FALSE)
p <- merge(raw[raw$arm == "base", c("round", "run_s", "fold_s")], raw[raw$arm == "candidate", c("round", "run_s", "fold_s")],
           by = "round", suffixes = c("_base", "_cand"))
s <- data.frame(shape = shape, rounds = rounds,
  base_run_median = stats::median(p$run_s_base), cand_run_median = stats::median(p$run_s_cand),
  base_fold_median = stats::median(p$fold_s_base), cand_fold_median = stats::median(p$fold_s_cand),
  run_saving_median = stats::median(1 - p$run_s_cand / p$run_s_base),
  fold_saving_median = stats::median(1 - p$fold_s_cand / p$fold_s_base),
  fold_us_per_pulse_base = 1e6 * stats::median(p$fold_s_base) / 7200, fold_us_per_pulse_cand = 1e6 * stats::median(p$fold_s_cand) / 7200)
utils::write.csv(s, file.path(out, "lean_helper_summary.csv"), row.names = FALSE)
writeLines(c(paste("power plan:", paste(system2("powercfg", "/getactivescheme", stdout = TRUE), collapse = " ")),
             paste("base lib installed from:", readLines(file.path(libs[["base"]], "LEDGR_INSTALLED_FROM_COMMIT"), warn = FALSE)[[1L]]),
             paste("candidate lib installed from:", readLines(file.path(libs[["candidate"]], "LEDGR_INSTALLED_FROM_COMMIT"), warn = FALSE)[[1L]]),
             paste("lean sources:", system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE)), paste("work:", raw$work[[1L]])),
           file.path(out, "lean_helper_host.txt"))
print(s, row.names = FALSE)
