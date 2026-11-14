# Spike lean_plan_cpp, runner (spike protocol section 6).
#
#   Rscript dev/spikes/lean_plan_cpp/run.R --lib=<pin library> --out=<dir> --mode=equivalence
#       [--shapes=slice2_10x7200,10x7200,500x1260] [--kernel=<cpp file>]
#   Rscript dev/spikes/lean_plan_cpp/run.R --lib=<pin library> --out=<dir> --mode=runs [--rounds=7]
#
# equivalence: runs the lean loop on each shape with the R planner, keeping
# every lean_plan_pulse() call's arguments and result, then sends each call
# to the compiled planner. "identical": identical() to the R planner's plan;
# "declined": the compiled planner returned NULL; "different" otherwise.
# Writes plan_equivalence.csv.
# runs: alternating fresh processes, four arms per round in rotating order:
# the R loop, the compiled planner, the compiled FIFO kernel
# (dev/spikes/lean_fifo_cpp) and both; per run the fold and run clocks and a
# digest of the fills, equity, ledger and diagnostics tables. Writes
# runs_raw.csv and runs_summary.csv (timings are host observations).

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
fifo_dir <- file.path(repo, "dev/spikes/lean_fifo_cpp")
lib <- normalizePath(opt("lib"), winslash = "/", mustWork = TRUE)
out <- opt("out", tempdir()); dir.create(out, recursive = TRUE, showWarnings = FALSE)
mode <- opt("mode", "")
source(file.path(fifo_dir, "lean_env.R"))
source(file.path(fifo_dir, "kernel.R"))
source(file.path(here, "kernel.R"))
sha <- function(x) substr(digest::digest(serialize(x, NULL, version = 2L), algo = "sha256", serialize = FALSE), 1L, 16L)

if (mode == "equivalence") {
  shapes <- strsplit(opt("shapes", "slice2_10x7200,10x7200,500x1260"), ",")[[1L]]
  env <- spike_lean_env(lib, repo)
  kernel <- spike_plan_compile(opt("kernel", file.path(here, "kernel.cpp")))
  resolve <- get("ledgr_plan_resolve", envir = env$ns)
  r_plan <- env$lean$lean_plan_pulse
  rows <- list()
  for (s in shapes) {
    calls <- list()
    env$lean$lean_plan_pulse <- function(...) { r <- r_plan(...); calls[[length(calls) + 1L]] <<- list(args = list(...), result = r); r }
    invisible(spike_run(env, s))
    env$lean$lean_plan_pulse <- r_plan
    n <- c(calls = 0L, identical = 0L, declined = 0L, different = 0L, with_rejections = 0L)
    first_diff <- NA_integer_
    for (i in seq_along(calls)) {
      a <- calls[[i]]$args
      b <- kernel(a$context_pos, a$target_qty, a$position, a$actionable_k, a$member, a$execution, a$execution_view,
                  a$epoch_valid, a$cost_resolver, a$cash, env$lean$lean_plan_id_rank(a$instrument_ids), resolve)
      n[["calls"]] <- n[["calls"]] + 1L
      if (length(calls[[i]]$result$rejection$k) > 0L) n[["with_rejections"]] <- n[["with_rejections"]] + 1L
      if (is.null(b)) n[["declined"]] <- n[["declined"]] + 1L
      else if (identical(b, calls[[i]]$result)) n[["identical"]] <- n[["identical"]] + 1L
      else { n[["different"]] <- n[["different"]] + 1L; if (is.na(first_diff)) first_diff <- i }
    }
    rows[[s]] <- data.frame(shape = s, t(n), first_bad_call = first_diff)
    cat(sprintf("%-15s %s\n", s, paste(names(n), n, sep = "=", collapse = " ")))
  }
  res <- do.call(rbind, rows)
  utils::write.csv(res, file.path(out, "plan_equivalence.csv"), row.names = FALSE)
  quit(status = if (any(res$different > 0L)) 1L else 0L)
}

# fuzz: the planner's rejection paths are rare in the workloads (the final
# pulse only, which the compiled planner declines), so captured calls are
# perturbed into them: cash squeezed (insufficient cash, the affordability
# order), opening prices broken (early rejections), execution-view
# restrictions with dictionary reasons 5-9 (blocked candidates), membership
# flipped (informational reasons), and all four together. Each perturbed call
# goes to both planners: "identical", "declined" (R refused, or the compiled
# planner declined), "accepted_refusal" (R refused, compiled answered) or
# "different". Seeded; writes plan_fuzz.csv.
if (mode == "fuzz") {
  shapes <- strsplit(opt("shapes", "slice2_10x7200,500x1260"), ",")[[1L]]
  per_shape <- as.integer(opt("per-shape", "1500"))
  env <- spike_lean_env(lib, repo)
  kernel <- spike_plan_compile(opt("kernel", file.path(here, "kernel.cpp")))
  resolve <- get("ledgr_plan_resolve", envir = env$ns)
  r_plan <- env$lean$lean_plan_pulse
  set.seed(20261114L)
  perturb <- function(a, what) {
    n <- length(a$actionable_k)
    pick <- function() sort(sample.int(n, max(1L, floor(n * stats::runif(1, 0.1, 0.6)))))
    if (what %in% c("cash", "all")) a$cash <- a$cash * stats::runif(1, 0, 0.3)
    if (what %in% c("open", "all")) {
      p <- a$context_pos[a$actionable_k[pick()]]
      a$execution$open[p] <- sample(c(NA_real_, 0, -1, Inf), length(p), replace = TRUE)
    }
    if (what %in% c("view", "all")) {
      cnt <- integer(n); rows <- pick(); cnt[rows] <- sample(1:2, length(rows), replace = TRUE)
      a$execution_view$reason_count <- cnt
      a$execution_view$reason_offset <- c(0L, cumsum(cnt))[seq_len(n)]
      a$execution_view$reason_code <- as.integer(unlist(lapply(cnt, function(c) sort(sample(5:9, c)))))
      a$execution_view$restricted <- cnt > 0L
    }
    if (what %in% c("member", "all")) a$member[a$actionable_k[pick()]] <- FALSE
    a
  }
  rows <- list()
  for (s in shapes) {
    calls <- list()
    env$lean$lean_plan_pulse <- function(...) { r <- r_plan(...); calls[[length(calls) + 1L]] <<- list(...); r }
    invisible(spike_run(env, s))
    env$lean$lean_plan_pulse <- r_plan
    calls <- calls[vapply(calls, function(a) !is.na(a$execution$exec_ts), TRUE)]
    use <- calls[sort(sample.int(length(calls), min(per_shape, length(calls))))]
    for (what in c("cash", "open", "view", "member", "all")) {
      n <- c(calls = 0L, identical = 0L, declined = 0L, accepted_refusal = 0L, different = 0L, r_refused = 0L,
             with_rejections = 0L)
      for (a0 in use) {
        a <- perturb(a0, what)
        ra <- tryCatch(do.call(r_plan, a), error = function(e) e)
        b <- kernel(a$context_pos, a$target_qty, a$position, a$actionable_k, a$member, a$execution, a$execution_view,
                    a$epoch_valid, a$cost_resolver, a$cash, env$lean$lean_plan_id_rank(a$instrument_ids), resolve)
        n[["calls"]] <- n[["calls"]] + 1L
        refused <- inherits(ra, "error")
        if (refused) n[["r_refused"]] <- n[["r_refused"]] + 1L
        else if (length(ra$rejection$k) > 0L) n[["with_rejections"]] <- n[["with_rejections"]] + 1L
        if (is.null(b)) n[["declined"]] <- n[["declined"]] + 1L
        else if (refused) n[["accepted_refusal"]] <- n[["accepted_refusal"]] + 1L
        else if (identical(b, ra)) n[["identical"]] <- n[["identical"]] + 1L
        else n[["different"]] <- n[["different"]] + 1L
      }
      rows[[paste(s, what)]] <- data.frame(shape = s, perturbation = what, t(n))
      cat(sprintf("%-15s %-7s %s\n", s, what, paste(names(n), n, sep = "=", collapse = " ")))
    }
  }
  res <- do.call(rbind, rows)
  utils::write.csv(res, file.path(out, "plan_fuzz.csv"), row.names = FALSE)
  quit(status = if (any(res$different > 0L | res$accepted_refusal > 0L)) 1L else 0L)
}

if (mode == "arm") {
  env <- spike_lean_env(lib, repo)
  arm <- opt("arm")
  plan_stats <- fifo_stats <- NULL
  if (arm %in% c("plan", "both")) plan_stats <- spike_plan_install(env$lean, spike_plan_compile(file.path(here, "kernel.cpp")))$stats
  if (arm %in% c("fifo", "both")) fifo_stats <- spike_install(env$lean, spike_compile(fifo_dir))$stats
  r <- spike_run(env, opt("shape"))
  utils::write.csv(data.frame(shape = opt("shape"), arm = arm, run_s = r$run_s, fold_s = r$fold_s, pulses = r$pulses,
    fills = r$fills, tables = sha(r$tables),
    plan_compiled = if (is.null(plan_stats)) NA_integer_ else plan_stats$compiled,
    plan_declined = if (is.null(plan_stats)) NA_integer_ else plan_stats$declined,
    fifo_compiled = if (is.null(fifo_stats)) NA_integer_ else fifo_stats$compiled,
    fifo_declined = if (is.null(fifo_stats)) NA_integer_ else fifo_stats$declined), opt("row"), row.names = FALSE)
  quit(status = 0L)
}

if (mode == "runs") {
  rounds <- as.integer(opt("rounds", "7"))
  shapes <- strsplit(opt("shapes", "slice2_10x7200,10x7200,500x1260"), ",")[[1L]]
  arms <- c("r", "plan", "fifo", "both")
  rscript <- file.path(R.home("bin"), "Rscript.exe")
  rows <- list()
  for (s in shapes) for (k in seq_len(rounds)) {
    for (a in arms[(seq_along(arms) + k - 2L) %% length(arms) + 1L]) {
      row <- tempfile(fileext = ".csv")
      st <- system2(rscript, c(file.path(here, "run.R"), paste0("--lib=", lib), "--mode=arm", paste0("--arm=", a),
                               paste0("--shape=", s), paste0("--row=", row)), stdout = FALSE, stderr = FALSE)
      if (st != 0L) stop("arm ", a, " on ", s, " round ", k, " failed")
      x <- utils::read.csv(row, stringsAsFactors = FALSE); x$round <- k
      rows[[length(rows) + 1L]] <- x
      cat(sprintf("%-15s round %d %-5s fold %.2f s run %.2f s\n", s, k, a, x$fold_s, x$run_s))
    }
  }
  raw <- do.call(rbind, rows)
  utils::write.csv(raw, file.path(out, "runs_raw.csv"), row.names = FALSE)
  summ <- do.call(rbind, lapply(split(raw, raw$shape), function(x) {
    base <- x[x$arm == "r", c("round", "fold_s", "run_s")]
    do.call(rbind, lapply(c("plan", "fifo", "both"), function(a) {
      y <- x[x$arm == a, ]
      p <- merge(base, y[, c("round", "fold_s", "run_s")], by = "round", suffixes = c("_r", "_a"))
      data.frame(shape = x$shape[[1L]], arm = a, rounds = nrow(p), tables_identical = length(unique(x$tables)) == 1L,
        declined = sum(c(y$plan_declined[[1L]], y$fifo_declined[[1L]]), na.rm = TRUE),
        fold_r_us_per_pulse = 1e6 * stats::median(p$fold_s_r) / x$pulses[[1L]],
        fold_a_us_per_pulse = 1e6 * stats::median(p$fold_s_a) / x$pulses[[1L]],
        fold_saving = stats::median(1 - p$fold_s_a / p$fold_s_r), run_saving = stats::median(1 - p$run_s_a / p$run_s_r),
        rounds_faster = sum(p$fold_s_a < p$fold_s_r))
    }))
  }))
  utils::write.csv(summ, file.path(out, "runs_summary.csv"), row.names = FALSE)
  writeLines(c(paste("power plan:", paste(system2("powercfg", "/getactivescheme", stdout = TRUE), collapse = " ")),
               paste("library:", lib), paste("head:", system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE))),
             file.path(out, "runs_host.txt"))
  print(summ, row.names = FALSE, digits = 3)
  quit(status = if (all(summ$tables_identical)) 0L else 1L)
}
stop("--mode must be equivalence or runs")
