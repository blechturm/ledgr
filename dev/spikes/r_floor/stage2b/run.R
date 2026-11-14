# R-floor stage 2b runner (CHARTER_stage2b.md, deliverable 1).
#
#   Rscript dev/spikes/r_floor/stage2b/run.R --lib=<pin library> --out=<dir> [--rounds=7]
#     [--shapes=10x7200,slice2_10x7200]
# Internal: --mode=arm --arm=ref|lean|clocked --shape=<id> --row=<csv> [--records=<rds>] [--gut=<name>]
#
# Per round and workload, three fresh processes in alternating order:
#   lean     the plain lean loop in a committed run: loop, publish and fold seconds;
#   clocked  the lean loop with stage clocks (lean_clocks.R): the attribution cells;
#   ref      the reference (reference.R): floor, each guarantee standalone, the
#            accumulated sequence (its last step is the full reference), each
#            loop timed alone after one warm-up, and the full reference's
#            after-run batched write of its records.
# Round 1's lean arm saves its compact records; parity compares the full
# reference to them and to ledgr_results(); fixtures.R then writes
# contract.csv. Writes runs_raw.csv,
# summary.csv, attribution.csv, parity.csv and host.txt.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", "..", ".."), winslash = "/")
lib <- normalizePath(opt("lib"), winslash = "/", mustWork = TRUE)
guarantees <- c("cost", "risk", "sizing", "fifo", "state", "rng")
configs <- c(list(floor = character()), stats::setNames(as.list(guarantees), paste0("alone_", guarantees)),
             stats::setNames(lapply(seq_along(guarantees), function(j) guarantees[seq_len(j)]), paste0("acc_", seq_along(guarantees))))
cell_map <- list(cost = "p3_plan", risk = "p2_risk", sizing = "p2_sizing", fifo = c("p4_fifo", "p4_facts"), state = "p5_state", rng = character())

s2b_ref_env <- function() {
  suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
  ns <- asNamespace("ledgr")
  defs <- new.env(parent = ns)
  for (f in c("dev/spikes/r_floor/fixture.R", "dev/spikes/r_floor/floor.R", "dev/bench/v0_2_3_lean_tuning_profile/descriptors.R"))
    sys.source(file.path(repo, f), envir = defs, keep.source = FALSE)
  ref <- new.env(parent = ns); ref$.lean_debug <- FALSE
  sys.source(file.path(repo, "dev/lean_core/fifo.R"), envir = ref, keep.source = FALSE)
  sys.source(file.path(here, "reference.R"), envir = ref, keep.source = FALSE)
  for (f in ls(ref, all.names = TRUE)) if (is.function(ref[[f]])) assign(f, compiler::cmpfun(ref[[f]]), envir = ref)
  list(defs = defs, ref = ref)
}

if (identical(opt("mode"), "arm")) {
  arm <- opt("arm"); shape <- opt("shape"); now <- microbenchmark::get_nanotime
  if (arm == "ref") {
    e <- s2b_ref_env(); ref <- e$ref
    t0 <- now(); w <- ref$s2b_workload(shape, e$defs); prep_s <- 1e-9 * (now() - t0)
    flags <- function(on) { g <- ref$s2b_all; g[] <- FALSE; g[on] <- TRUE; g }
    invisible(ref$s2b_run(w, flags(guarantees)))                  # warm-up
    rows <- lapply(names(configs), function(cf) {
      invisible(gc(FALSE)); t0 <- now(); out <- ref$s2b_run(w, flags(configs[[cf]]), gut = opt("gut", "")); loop_s <- 1e-9 * (now() - t0)
      write_s <- NA_real_
      if (cf == "acc_6") {
        con <- DBI::dbConnect(duckdb::duckdb(), tempfile(fileext = ".duckdb"))
        t0 <- now()
        for (part in c("fills", "equity", "decisions", "sizing", "rejections")) DBI::dbWriteTable(con, part, as.data.frame(out[[part]]))
        DBI::dbWriteTable(con, "recon", as.data.frame(out$recon))
        write_s <- 1e-9 * (now() - t0)
        DBI::dbDisconnect(con, shutdown = TRUE)
        if (!is.null(opt("records"))) saveRDS(out, opt("records"))
      }
      data.frame(config = cf, loop_s = loop_s, write_s = write_s, prep_s = prep_s, fold_s = NA_real_, run_s = NA_real_)
    })
    utils::write.csv(do.call(rbind, rows), opt("row"), row.names = FALSE)
    quit(status = 0L)
  }
  source(file.path(here, "lean_clocks.R"))
  env <- spk_lean_env(lib, repo, clocks = arm == "clocked")
  spk_reset(env); ns <- env$ns; lean <- env$lean
  unhelper <- if (arm == "clocked" && shape == "slice2_10x7200") spk_wrap_helper(env) else function() NULL
  desc <- env$defs$bench_descriptor(shape)
  store <- tempfile(fileext = ".duckdb")
  ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(desc$bars(), db_path = store, snapshot_id = "s2b", price_basis = "split_adjusted"))
  snapshot <- ledgr::ledgr_snapshot_open(store, "s2b", verify = TRUE)
  exp <- desc$experiment(snapshot)
  restore <- lean$lean_loop_install()
  fold <- new.env(); fold$s <- 0
  inner <- get("ledgr_fold_envelope", envir = ns)
  unlockBinding("ledgr_fold_envelope", ns)
  assign("ledgr_fold_envelope", function(execution, output_handler) {
    t0 <- now(); on.exit(fold$s <- fold$s + 1e-9 * (now() - t0)); inner(execution, output_handler) }, envir = ns)
  lockBinding("ledgr_fold_envelope", ns)
  folds0 <- lean$lean_entry$lean_folds %||% 0L
  invisible(gc(FALSE))
  t0 <- now(); bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = "s2b", seed = 20260530L)); run_s <- 1e-9 * (now() - t0)
  if (lean$lean_entry$lean_folds - folds0 != 1L) stop("the lean loop did not run once")
  if (!is.null(opt("records"))) {
    fr <- lean$.spk$frame
    keep <- function(x, n) lapply(x, function(v) v[seq_len(n)])
    rec <- list(fills = keep(fr$fl, fr$nf), equity = keep(fr$eq, fr$n_eq), decisions = keep(fr$dr, fr$nd), sizing = keep(fr$szr, fr$nsz),
                rejections = fr$rj, recon = fr$hd_recon, pre = fr$hd_pre, sizing_notice = fr$hd_sizing,
                strategy_state = fr$strategy_state, cash = fr$cash, pos = fr$pos, book = fr$book, status = fr$status,
                stop_reason = fr$stop_reason,
                results = lapply(stats::setNames(nm = c("fills", "equity")), function(t) as.data.frame(ledgr::ledgr_results(bt, t))))
    # check.R's corruption demonstration: a clocked record altered after the run
    if (identical(opt("corrupt"), "1")) rec$fills$qty[[1L]] <- rec$fills$qty[[1L]] + 1
    saveRDS(rec, opt("records"))
  }
  close(bt); restore(); unhelper(); ledgr::ledgr_snapshot_close(snapshot)
  clk <- if (arm == "clocked") spk_clocks(env) else stats::setNames(numeric(0), character(0))
  row <- data.frame(config = arm, loop_s = lean$lean_loop_last_times$pulses, write_s = lean$lean_loop_last_times$publish,
                    prep_s = NA_real_, fold_s = fold$s, run_s = run_s,
                    sources = paste(paste0(names(env$hashes), "=", substr(env$hashes, 1L, 12L)), collapse = ";"))
  for (cell in names(clk)) row[[cell]] <- clk[[cell]]
  utils::write.csv(row, opt("row"), row.names = FALSE)
  quit(status = 0L)
}

out <- opt("out"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
rounds <- as.integer(opt("rounds", "7"))
shapes <- strsplit(opt("shapes", "10x7200,slice2_10x7200"), ",")[[1L]]
rscript <- file.path(R.home("bin"), "Rscript.exe")
raw <- list()
arms <- c("lean", "clocked", "ref")
for (s in shapes) for (k in seq_len(rounds)) for (arm in if (k %% 2L) arms else rev(arms)) {
  row <- tempfile(fileext = ".csv")
  rec <- if (k == 1L) file.path(out, sprintf("records_%s_%s.rds", s, arm))
  st <- system2(rscript, c(file.path(here, "run.R"), paste0("--lib=", lib), "--mode=arm", paste0("--arm=", arm),
                           paste0("--shape=", s), paste0("--row=", row), if (!is.null(rec)) paste0("--records=", rec),
                           if (arm == "clocked" && identical(opt("corrupt"), "1")) "--corrupt=1"))
  if (st != 0L) stop("arm ", arm, " on ", s, " round ", k, " failed")
  x <- utils::read.csv(row, stringsAsFactors = FALSE); x$shape <- s; x$round <- k; x$arm <- arm
  raw[[length(raw) + 1L]] <- x
  cat(sprintf("%-15s round %d %-7s loop %s\n", s, k, arm, paste(sprintf("%.2f", x$loop_s), collapse = " ")))
}
cols <- unique(unlist(lapply(raw, names)))
raw <- do.call(rbind, lapply(raw, function(x) { for (c in setdiff(cols, names(x))) x[[c]] <- NA_real_; x[cols] }))
utils::write.csv(raw, file.path(out, "runs_raw.csv"), row.names = FALSE)
# Identities (cut review 18, R6): commit, pin library, versions, command, plan, affinity.
host <- c(paste("head:", system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE)),
  paste("pin library:", lib, "marker", paste(readLines(file.path(lib, "LEDGR_INSTALLED_FROM_COMMIT"), warn = FALSE), collapse = " ")),
  paste("versions:", R.version.string, paste(vapply(c("collapse", "duckdb", "microbenchmark", "rlang"), function(p)
    paste(p, as.character(utils::packageVersion(p))), ""), collapse = ", ")),
  paste("command: Rscript", paste(c("dev/spikes/r_floor/stage2b/run.R", args), collapse = " ")),
  paste("power plan:", paste(system2("powercfg", "/getactivescheme", stdout = TRUE), collapse = " ")),
  # a child process inherits the runner's affinity, so the child reports it
  paste("process affinity:", paste(system2("powershell", c("-NoProfile", "-Command",
    "[System.Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity"), stdout = TRUE, stderr = FALSE), collapse = " ")))
writeLines(host, file.path(out, "host_identity.txt"))
source(file.path(here, "summarise.R"))
ok <- s2b_summarise(out, raw, configs, cell_map, guarantees)
fx <- system2(rscript, c(file.path(here, "fixtures.R"), paste0("--lib=", lib), paste0("--out=", out)))
quit(status = if (isTRUE(ok) && fx == 0L) 0L else 1L)
