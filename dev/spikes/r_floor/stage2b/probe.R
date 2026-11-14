# R-floor stage 2b probe (spike protocol section 1): what the lean loop does
# on the two workloads before any reference is written.
#
#   Rscript dev/spikes/r_floor/stage2b/probe.R --lib=<pin library> --out=<dir>
# One arm (internal): --mode=arm --arm=plain|clocked|reads|counts --shape=<id> --rds=<file>
#
# plain: the unmodified loop (frame capture only), its pulse-loop seconds and
#   its compact records; clocked: the stage clocks (lean_clocks.R) and the
#   loop seconds with them, so the clocks' own cost is visible; reads: every
#   context field the strategy and the sizing helper read; counts: calls per
#   run of the package functions the loop reaches per pulse.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", "..", ".."), winslash = "/")
lib <- normalizePath(opt("lib"), winslash = "/", mustWork = TRUE)
counted <- c("ledgr_call_strategy_fn", "ledgr_validate_strategy_targets", "ledgr_validate_sizing_evidence",
             "ledgr_apply_risk_plan", "ledgr_availability_validate_post_risk", "ledgr_availability_validate_short_exposure",
             "ledgr_position_facts_apply", "ledgr_cash_scan", "ledgr_carrier_segment_text", "ledgr_fold_reconciliation_check",
             "ledgr_strategy_state_validate_value", "ledgr_strategy_state_apply_values", "ledgr_target_rebalance",
             "ledgr_target", "ledgr_strategy_result", "ledgr_validate_strategy_intent_reason")

if (identical(opt("mode"), "arm")) {
  source(file.path(here, "lean_clocks.R"))
  arm <- opt("arm"); shape <- opt("shape")
  env <- spk_lean_env(lib, repo, clocks = identical(arm, "clocked"))
  spk_reset(env)
  ns <- env$ns; lean <- env$lean
  restores <- list()
  wrap <- function(name, make) {
    f <- get(name, envir = ns); unlockBinding(name, ns); assign(name, make(f), envir = ns); lockBinding(name, ns)
    restores[[length(restores) + 1L]] <<- function() { unlockBinding(name, ns); assign(name, f, envir = ns); lockBinding(name, ns) }
  }
  if (arm == "clocked" && shape == "slice2_10x7200") restores[[1L]] <- spk_wrap_helper(env)
  reads <- new.env(); reads$log <- character(); reads$in_helper <- FALSE
  if (arm == "reads") {
    dollar <- lean$lean_ctx_dollar
    lean$lean_ctx_dollar <- function(x, name) {
      reads$log <- c(reads$log, paste0(if (reads$in_helper) "helper:" else "strategy:", name)); dollar(x, name)
    }
    if (shape == "slice2_10x7200") wrap("ledgr_target_rebalance", function(f) function(...) {
      reads$in_helper <- TRUE; on.exit(reads$in_helper <- FALSE); f(...) })
  }
  calls <- new.env()
  if (arm == "counts") for (nm in counted) {
    calls[[nm]] <- 0L
    local({ nm <- nm; wrap(nm, function(f) { force(f); function(...) { calls[[nm]] <- calls[[nm]] + 1L; f(...) } }) })
  }
  desc <- env$defs$bench_descriptor(shape)
  store <- tempfile(fileext = ".duckdb")
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(desc$bars(), db_path = store, snapshot_id = "s2b",
                                                            price_basis = "split_adjusted"))
  snapshot <- ledgr::ledgr_snapshot_open(store, "s2b", verify = TRUE)
  exp <- desc$experiment(snapshot)
  restore <- lean$lean_loop_install()
  folds0 <- lean$lean_entry$lean_folds %||% 0L
  invisible(gc(FALSE))
  bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = "s2b", seed = 20260530L))
  if (lean$lean_entry$lean_folds - folds0 != 1L) stop("the lean loop did not run once")
  fr <- lean$.spk$frame
  keep <- function(x, n) lapply(x, function(v) v[seq_len(n)])
  records <- list(fills = keep(fr$fl, fr$nf), equity = keep(fr$eq, fr$n_eq), decisions = keep(fr$dr, fr$nd),
                  sizing = keep(fr$szr, fr$nsz), rejections = fr$rj, recon = fr$hd_recon, pre = fr$hd_pre,
                  sizing_notice = fr$hd_sizing, strategy_state = fr$strategy_state, cash = fr$cash, pos = fr$pos,
                  book = fr$book, status = fr$status, stop_reason = fr$stop_reason)
  tables <- lapply(stats::setNames(nm = c("fills", "equity", "diagnostics")), function(t) as.data.frame(ledgr::ledgr_results(bt, t)))
  close(bt); restore(); for (r in rev(restores)) r(); ledgr::ledgr_snapshot_close(snapshot)
  saveRDS(list(shape = shape, arm = arm, loop_s = lean$lean_loop_last_times$pulses, clk = spk_clocks(env),
               records = records, tables = tables, reads = table(reads$log), calls = unlist(as.list(calls))),
          opt("rds"))
  quit(status = 0L)
}

out <- opt("out"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
rscript <- file.path(R.home("bin"), "Rscript.exe")
res <- list()
for (shape in strsplit(opt("shapes", "10x7200,slice2_10x7200"), ",")[[1L]]) for (arm in c("plain", "clocked", "reads", "counts")) {
  rds <- file.path(out, sprintf("probe_%s_%s.rds", shape, arm))
  st <- system2(rscript, c(file.path(here, "probe.R"), paste0("--lib=", lib), "--mode=arm", paste0("--arm=", arm),
                           paste0("--shape=", shape), paste0("--rds=", rds)))
  if (st != 0L) stop("arm ", arm, " on ", shape, " failed")
  res[[paste(shape, arm)]] <- readRDS(rds)
  cat(sprintf("%-15s %-8s loop %.2f s\n", shape, arm, res[[paste(shape, arm)]]$loop_s))
}
for (shape in unique(vapply(res, `[[`, "", "shape"))) {
  p <- res[[paste(shape, "plain")]]; k <- res[[paste(shape, "clocked")]]
  pulses <- length(p$records$equity$ts)
  cat(sprintf("\n== %s: %d pulses, %d fills, %d decision rows, %d sizing rows, %d rejections, status %s\n", shape, pulses,
              length(p$records$fills$qty), length(p$records$decisions$k), length(p$records$sizing$id),
              length(p$records$rejections$k), p$records$status))
  cat(sprintf("loop us/pulse: plain %.0f, clocked %.0f (clock cost %.0f)\n", 1e6 * p$loop_s / pulses, 1e6 * k$loop_s / pulses,
              1e6 * (k$loop_s - p$loop_s) / pulses))
  cat("stage clocks, us/pulse:\n"); print(round(1e6 * k$clk / pulses, 1))
  cat("records identical plain vs clocked:", identical(p$records, k$records), "\n")
  cat("context reads (reads arm):\n"); print(res[[paste(shape, "reads")]]$reads)
  cat("package calls per run (counts arm):\n"); print(res[[paste(shape, "counts")]]$calls)
}
