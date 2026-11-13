# Spike lean_fifo_cpp, runner (spike protocol section 6).
#
#   Rscript dev/spikes/lean_fifo_cpp/run.R --lib=<pin library> --out=<dir> --mode=equivalence
#       --captures=<dir of lot-call captures (tests_*.rds)> [--kernel=<cpp file>]
#   Rscript dev/spikes/lean_fifo_cpp/run.R --lib=<pin library> --out=<dir> --mode=runs [--rounds=7]
#       [--shapes=slice2_10x7200,10x7200,500x1260]
#
# equivalence: every captured call (the lean R kernel's slice2 calls,
# regenerated from a run, and the pinned lot kernel's calls recorded during
# the package test suite) goes to the R kernel and to the compiled kernel.
# A call is "identical" when the compiled result is identical() to the R
# kernel's, "declined" when the compiled kernel returns NULL, "accepted
# refusal" when the R kernel refuses and the compiled kernel returns a
# result, and "different" otherwise. Writes equivalence.csv.
# runs: alternating fresh processes, the lean loop with the R kernel and with
# the compiled kernel installed; per run the fold and run clocks and a digest
# of the fills, equity, ledger and diagnostics tables. Writes runs_raw.csv
# and runs_summary.csv (timings are host observations, not diffed).

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
lib <- normalizePath(opt("lib"), winslash = "/", mustWork = TRUE)
out <- opt("out", tempdir()); dir.create(out, recursive = TRUE, showWarnings = FALSE)
mode <- opt("mode", "")
source(file.path(here, "lean_env.R"))
source(file.path(here, "kernel.R"))
sha <- function(x) substr(digest::digest(serialize(x, NULL, version = 2L), algo = "sha256", serialize = FALSE), 1L, 16L)

if (mode == "equivalence") {
  env <- spike_lean_env(lib, repo)
  kfile <- opt("kernel", file.path(here, "kernel.cpp"))
  kenv <- new.env(); cpp11::cpp_source(kfile, env = kenv, quiet = TRUE); kernel <- kenv$spike_lot_fill
  r_apply <- env$lean$lean_lot_apply
  sources <- list()
  # the lean R kernel's own calls on slice2_10x7200
  slice2 <- list()
  env$lean$lean_lot_apply <- function(book, input) { slice2[[length(slice2) + 1L]] <<- list(book = book, input = input); r_apply(book, input) }
  invisible(spike_run(env, "slice2_10x7200"))
  env$lean$lean_lot_apply <- r_apply
  sources[["slice2_10x7200 lean run"]] <- slice2
  for (f in sort(list.files(opt("captures"), pattern = "^tests_.*[.]rds$", full.names = TRUE))) {
    sources[[paste("package test suite", basename(f))]] <- lapply(readRDS(f), function(x) x[c("book", "input")])
  }
  rows <- list()
  for (s in names(sources)) {
    n <- c(calls = 0L, identical = 0L, declined = 0L, accepted_refusal = 0L, different = 0L, r_refused = 0L)
    first_diff <- NA_integer_
    for (i in seq_along(sources[[s]])) {
      x <- sources[[s]][[i]]
      a <- tryCatch(r_apply(x$book, x$input), error = function(e) e)
      b <- kernel(x$book, x$input)
      n[["calls"]] <- n[["calls"]] + 1L
      refused <- inherits(a, "error")
      if (refused) n[["r_refused"]] <- n[["r_refused"]] + 1L
      if (is.null(b)) n[["declined"]] <- n[["declined"]] + 1L
      else if (refused) { n[["accepted_refusal"]] <- n[["accepted_refusal"]] + 1L; if (is.na(first_diff)) first_diff <- i }
      else if (identical(a, b)) n[["identical"]] <- n[["identical"]] + 1L
      else { n[["different"]] <- n[["different"]] + 1L; if (is.na(first_diff)) first_diff <- i }
    }
    rows[[s]] <- data.frame(source = s, t(n), first_bad_call = first_diff)
    cat(sprintf("%-40s %s\n", s, paste(names(n), n, sep = "=", collapse = " ")))
  }
  res <- do.call(rbind, rows)
  utils::write.csv(res, file.path(out, "equivalence.csv"), row.names = FALSE)
  if (any(res$accepted_refusal > 0L | res$different > 0L)) quit(status = 1L)
  quit(status = 0L)
}

if (mode == "arm") {
  env <- spike_lean_env(lib, repo)
  installed <- NULL
  if (identical(opt("arm"), "compiled")) installed <- spike_install(env$lean, spike_compile(here))
  r <- spike_run(env, opt("shape"))
  utils::write.csv(data.frame(shape = opt("shape"), arm = opt("arm"), run_s = r$run_s, fold_s = r$fold_s, pulses = r$pulses,
    fills = r$fills, tables = sha(r$tables), compiled_calls = if (is.null(installed)) NA_integer_ else installed$stats$compiled,
    declined_calls = if (is.null(installed)) NA_integer_ else installed$stats$declined), opt("row"), row.names = FALSE)
  quit(status = 0L)
}

if (mode == "runs") {
  rounds <- as.integer(opt("rounds", "7"))
  shapes <- strsplit(opt("shapes", "slice2_10x7200,10x7200,500x1260"), ",")[[1L]]
  rscript <- file.path(R.home("bin"), "Rscript.exe")
  rows <- list()
  for (s in shapes) for (k in seq_len(rounds)) {
    for (a in if (k %% 2L) c("r", "compiled") else c("compiled", "r")) {
      row <- tempfile(fileext = ".csv")
      st <- system2(rscript, c(file.path(here, "run.R"), paste0("--lib=", lib), "--mode=arm", paste0("--arm=", a),
                               paste0("--shape=", s), paste0("--row=", row)), stdout = FALSE, stderr = FALSE)
      if (st != 0L) stop("arm ", a, " on ", s, " round ", k, " failed")
      x <- utils::read.csv(row, stringsAsFactors = FALSE); x$round <- k
      rows[[length(rows) + 1L]] <- x
      cat(sprintf("%-15s round %d %-8s fold %.2f s run %.2f s\n", s, k, a, x$fold_s, x$run_s))
    }
  }
  raw <- do.call(rbind, rows)
  utils::write.csv(raw, file.path(out, "runs_raw.csv"), row.names = FALSE)
  summ <- do.call(rbind, lapply(split(raw, raw$shape), function(x) {
    r <- x[x$arm == "r", ]; c <- x[x$arm == "compiled", ]
    p <- merge(r[, c("round", "fold_s", "run_s")], c[, c("round", "fold_s", "run_s")], by = "round", suffixes = c("_r", "_c"))
    data.frame(shape = x$shape[[1L]], rounds = nrow(p), tables_identical = length(unique(x$tables)) == 1L,
      compiled_calls = c$compiled_calls[[1L]], declined_calls = c$declined_calls[[1L]],
      fold_r_us_per_pulse = 1e6 * stats::median(p$fold_s_r) / x$pulses[[1L]],
      fold_c_us_per_pulse = 1e6 * stats::median(p$fold_s_c) / x$pulses[[1L]],
      fold_saving = stats::median(1 - p$fold_s_c / p$fold_s_r), run_saving = stats::median(1 - p$run_s_c / p$run_s_r),
      rounds_compiled_faster = sum(p$fold_s_c < p$fold_s_r))
  }))
  utils::write.csv(summ, file.path(out, "runs_summary.csv"), row.names = FALSE)
  writeLines(c(paste("power plan:", paste(system2("powercfg", "/getactivescheme", stdout = TRUE), collapse = " ")),
               paste("library:", lib), paste("head:", system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE))),
             file.path(out, "runs_host.txt"))
  print(summ, row.names = FALSE, digits = 3)
  if (!all(summ$tables_identical)) quit(status = 1L)
  quit(status = 0L)
}
stop("--mode must be equivalence or runs")
