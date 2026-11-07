# Cut 12 FIFO gate (LDG-3214, Cut 12 decision (5)). Run with
# runner.R --candidate-overlay=dev/lean_core,dev/bench/v0_2_3_ws16_entry and
# one commit (the pin) on both arms.
#
# Each slot captures the registered fill-heavy run's ledgr_lot_apply calls
# of one caller and block bucket, as the entry method did
# (dev/bench/v0_2_3_ws16_entry/fifo_cost.R), then times its arm's kernel plus
# input validation over those calls `reps` times:
#   base      ledgr_lot_apply(book, ledgr_lot_input(...))     the pin
#   candidate lean_lot_apply(book, lean_lot_input(...))       dev/lean_core/fifo.R
# Both arms run byte-compiled with the JIT off. The work string pins the
# captured calls and a digest of the results, so a record whose arms disagree
# on any result fails the checker's invariant-work rule.

fifo_block <- function(args, work_dir) {
  dev <- args$.overlay
  arm <- args$.arm
  if (!is.character(dev) || !isTRUE(arm %in% c("base", "candidate"))) {
    stop("cut12-fifo-1 runs only under runner.R --candidate-overlay")
  }
  callers <- c(fold = "ledgr_fold_fill_candidate", replay = "ledgr_replay_accounting_events")
  caller <- callers[[args$caller]]
  bucket <- args$bucket
  if (!bucket %in% c("10-49", "50+")) stop("bad bucket ", bucket)
  reps <- as.integer(args$reps)
  in_bucket <- function(m) if (bucket == "50+") m >= 50L else m >= 10L && m <= 49L

  # The entry workload and its capture helpers, from the overlay.
  entry <- new.env(parent = globalenv())
  for (f in c("common.R", "workloads.R")) {
    sys.source(file.path(dev, "dev", "bench", "v0_2_3_ws16_entry", f), envir = entry, keep.source = FALSE)
  }
  ns <- asNamespace("ledgr")
  skip <- c("ledgr_lot_apply", "ledgr_lot_fill", "ledgr_lot_opening", "ledgr_lot_disposition",
            "ledgr_lot_apply_blocks")
  calls <- list()
  orig <- entry$ws16_wrap("ledgr_lot_apply", function(orig) {
    force(orig)
    function(book, input) {
      if (in_bucket(length(input$pos)) && identical(entry$ws16_caller(skip), caller)) {
        calls[[length(calls) + 1L]] <<- list(book = book, input = input)
      }
      orig(book, input)
    }
  })
  snap <- ledgr_snapshot_from_df(entry$ws16_fill_heavy_bars(), db_path = file.path(work_dir, "fill.duckdb"),
                                 snapshot_id = "cut12_fifo", price_basis = "split_adjusted")
  bt <- suppressWarnings(ledgr_run(entry$ws16_fill_heavy_experiment(snap), run_id = "cut12-fifo", seed = 20260530L))
  n_fills <- nrow(ledgr_results(bt, "fills"))
  eq <- ledgr_results(bt, "equity")
  close(bt)
  unlockBinding("ledgr_lot_apply", ns)
  assign("ledgr_lot_apply", orig, envir = ns)
  lockBinding("ledgr_lot_apply", ns)
  ledgr_snapshot_close(snap)

  # The arm's kernel plus input validation, byte-compiled.
  if (arm == "base") {
    validate <- ns$ledgr_lot_input
    kernel <- ns$ledgr_lot_apply
  } else {
    lean <- new.env(parent = ns)
    lean$.lean_debug <- FALSE
    sys.source(file.path(dev, "dev", "lean_core", "fifo.R"), envir = lean, keep.source = FALSE)
    for (f in ls(lean, all.names = TRUE)) {
      if (is.function(lean[[f]])) assign(f, compiler::cmpfun(lean[[f]]), envir = lean)
    }
    validate <- lean$lean_lot_input
    kernel <- lean$lean_lot_apply
  }
  one <- compiler::cmpfun(function(k) {
    i <- k$input
    kernel(k$book, validate(i$operation[[1L]], i$pos, i$side, i$qty, i$price, i$fee,
                            i$position_before, i$realized_model_pnl))
  })
  drive <- compiler::cmpfun(function(n) for (r in seq_len(n)) for (k in calls) one(k))
  invisible(compiler::enableJIT(0L))

  sha <- function(x) digest::digest(serialize(x, NULL, version = 2L), algo = "sha256", serialize = FALSE)
  results <- lapply(calls, one)
  rows <- sum(vapply(calls, function(k) length(k$input$pos), integer(1)))
  work <- paste(args$caller, bucket, length(calls), rows, n_fills, format(eq$equity[nrow(eq)], digits = 17),
                substr(sha(calls), 1L, 16L), substr(sha(results), 1L, 16L), reps, sep = "|")
  rm(results)
  invisible(gc())

  t0 <- as.numeric(Sys.time())
  drive(reps)
  elapsed <- as.numeric(Sys.time()) - t0
  list(seconds = c(block = elapsed), work = work, overlay_arm = arm)
}
