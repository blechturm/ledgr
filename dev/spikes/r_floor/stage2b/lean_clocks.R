# R-floor stage 2b: the lean loop with clocks at its stage boundaries.
# dev/lean_core/loop.R is read as text, clock statements are inserted at
# fixed anchors (each must match exactly once), and the result is parsed
# into the lean environment in place of the plain loop. Nothing on disk in
# dev/lean_core changes. With clocks = FALSE the loop is the plain one and
# only the end-of-loop frame capture is added.
#
# Clock cells (nanoseconds, summed over pulses), .spk$c_<cell>; spk_clocks() returns seconds:
#   p1, p2, p3, p4, p5, e                     the stage calls of run_loop
#   p2_context, p2_strategy, p2_sizing, p2_risk  inside P2
#   p3_plan                                    lean_plan_pulse() inside P3
#   p4_fifo, p4_facts                          lot kernel, position facts
#   p5_state                                   declared-state update
# The strategy cell includes the helper; the helper's own time is taken by
# wrapping its namespace binding (spk_wrap_helper()).

spk_cells <- c("p1", "p2", "p3", "p4", "p5", "e", "p2_context", "p2_strategy", "p2_sizing", "p2_risk", "p3_plan",
               "p4_fifo", "p4_facts", "p5_state", "helper")

spk_anchor <- function(src, old, new) {
  hit <- gregexpr(old, src, fixed = TRUE)[[1L]]
  if (length(hit) != 1L || hit[[1L]] < 0L) stop("anchor must match once: ", substr(old, 1L, 60L), call. = FALSE)
  sub(old, new, src, fixed = TRUE)
}

spk_tick <- function(cell, expr) sprintf(".spk_t <- .spk_now(); %s; .spk$c_%s <- .spk$c_%s + (.spk_now() - .spk_t)", expr, cell, cell)

spk_loop_source <- function(repo, clocks = TRUE, text = NULL) {
  src <- paste(if (is.null(text)) readLines(file.path(repo, "dev/lean_core/loop.R"), warn = FALSE) else text, collapse = "\n")
  # the fold frame, for the compact records at the end of the loop
  src <- spk_anchor(src, "    live$in_pulses <- FALSE\n    live$t_pulses <- ",
                    "    live$in_pulses <- FALSE\n    .spk$frame <- parent.env(environment())\n    live$t_pulses <- ")
  if (!clocks) return(src)
  stage <- function(src, call, cell) spk_anchor(src, paste0("      ", call, "\n"), paste0("      ", spk_tick(cell, call), "\n"))
  src <- stage(src, "v1 <- lean_p1_value(i)", "p1")
  src <- stage(src, "v2 <- lean_p2_decide(i, v1)", "p2")
  src <- stage(src, "v3 <- lean_p3_plan(i, v1, v2)", "p3")
  src <- stage(src, "n_fill <- lean_p4_apply(i, v1, v2, v3$batch)", "p4")
  src <- stage(src, "lean_p5_commit(i, v1, v2, v3$batch, n_fill)", "p5")
  src <- spk_anchor(src, "      if (!lean_e_advance()) break\n",
                    paste0("      ", spk_tick("e", ".spk_adv <- lean_e_advance()"), "\n      if (!.spk_adv) break\n"))
  src <- spk_anchor(src, "    ctx <- lean_context(i, col, close, pv, positions_snapshot, view, counts)\n",
                    paste0("    ", spk_tick("p2_context", "ctx <- lean_context(i, col, close, pv, positions_snapshot, view, counts)"), "\n"))
  src <- spk_anchor(src, "    result <- tryCatch({\n      live$cur_stage <- \"strategy\"",
                    "    .spk_s <- .spk_now()\n    result <- tryCatch({\n      live$cur_stage <- \"strategy\"")
  src <- spk_anchor(src, "    check_uncovered()\n    if (is.object(result)",
                    "    check_uncovered()\n    .spk$c_p2_strategy <- .spk$c_p2_strategy + (.spk_now() - .spk_s)\n    if (is.object(result)")
  # Cut 18 crosswalk (crosswalk.csv): the sizing and risk cells clock the
  # production branch of their lean-owned call; the risk cell now holds the
  # post-risk and short checks too (merged).
  src <- spk_anchor(src, "    } else lean_sizing_evidence(sizing_evidence, targets, ids, pos, close)\n",
                    paste0("    } else { ", spk_tick("p2_sizing", ".spk_v <- lean_sizing_evidence(sizing_evidence, targets, ids, pos, close)"),
                           "; .spk_v }\n"))
  src <- spk_anchor(src, "        } else lean_risk_targets(sq, targets, pos, positions_snapshot, risk_steps, cash + pv, close, ids, risk_plan, ctx)\n",
                    paste0("        } else { ", spk_tick("p2_risk", ".spk_v <- lean_risk_targets(sq, targets, pos, positions_snapshot, risk_steps, cash + pv, close, ids, risk_plan, ctx)"),
                           "; .spk_v }\n"))
  src <- spk_anchor(src, "      batch <- lean_plan_pulse(",
                    "      .spk_p <- .spk_now()\n      batch <- lean_plan_pulse(")
  src <- spk_anchor(src, "        cost_resolver = cost_resolver, cash = cash, instrument_ids = ids, cost_steps = cost_steps)\n",
                    "        cost_resolver = cost_resolver, cash = cash, instrument_ids = ids, cost_steps = cost_steps)\n      .spk$c_p3_plan <- .spk$c_p3_plan + (.spk_now() - .spk_p)\n")
  src <- spk_anchor(src, "      applied <- lean_lot_fill(book, fill$pos, fill$side, fill$qty, fill$price, fill$fee)\n",
                    paste0("      ", spk_tick("p4_fifo", "applied <- lean_lot_fill(book, fill$pos, fill$side, fill$qty, fill$price, fill$fee)"), "\n"))
  src <- spk_anchor(src, "      position_facts <<- ledgr_position_facts_apply(position_facts, fill$pos, fill$position_before,\n        fill$planned_position_after, fill_bar, TRUE)\n",
                    paste0("      ", spk_tick("p4_facts", "position_facts <<- ledgr_position_facts_apply(position_facts, fill$pos, fill$position_before, fill$planned_position_after, fill_bar, TRUE)"), "\n"))
  src <- spk_anchor(src, "    state_update <- v2$result$state_update\n", "    .spk_u <- .spk_now()\n    state_update <- v2$result$state_update\n")
  src <- spk_anchor(src, "    invisible(NULL)\n  }\n\n  # E: counts the pulse",
                    "    .spk$c_p5_state <- .spk$c_p5_state + (.spk_now() - .spk_u)\n    invisible(NULL)\n  }\n\n  # E: counts the pulse")
  src
}

# The cut16-loop-1 loading (dev/spikes/lean_fifo_cpp/lean_env.R) with the
# clocked or plain loop; returns list(ns, defs, lean).
spk_lean_env <- function(lib, repo, clocks = TRUE) {
  suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
  ns <- asNamespace("ledgr")
  defs <- new.env(parent = ns)
  sys.source(file.path(repo, "dev/spikes/r_floor/fixture.R"), envir = defs, keep.source = FALSE)
  sys.source(file.path(repo, "dev/bench/v0_2_3_lean_tuning_profile/descriptors.R"), envir = defs, keep.source = FALSE)
  lean <- new.env(parent = ns)
  lean$.lean_debug <- FALSE
  lean$.spk <- new.env(parent = emptyenv())
  lean$.spk_now <- microbenchmark::get_nanotime   # nanoseconds, about 0.2 us per read
  # every lean execution source but load.R and prepare.R (preparation stays
  # the pin's); an unlisted one refuses
  srcs <- c("checks.R", "fifo.R", "plan.R", "loop.R", "loop_harness.R")
  present <- setdiff(list.files(file.path(repo, "dev/lean_core"), pattern = "[.]R$"), c("load.R", "prepare.R"))
  if (!setequal(present, srcs)) stop("stage 2b: lean execution sources changed: ", paste(sort(present), collapse = ", "))
  for (f in c("checks.R", "fifo.R", "plan.R")) sys.source(file.path(repo, "dev/lean_core", f), envir = lean, keep.source = FALSE)
  eval(parse(text = spk_loop_source(repo, clocks), keep.source = FALSE), envir = lean)
  sys.source(file.path(repo, "dev/lean_core/loop_harness.R"), envir = lean, keep.source = FALSE)
  for (f in ls(lean, all.names = TRUE)) if (is.function(lean[[f]])) assign(f, compiler::cmpfun(lean[[f]]), envir = lean)
  hashes <- vapply(srcs, function(f) rlang::hash(readLines(file.path(repo, "dev/lean_core", f))), "")
  list(ns = ns, defs = defs, lean = lean, hashes = hashes)
}

spk_reset <- function(env) {
  for (cell in spk_cells) assign(paste0("c_", cell), 0, envir = env$lean$.spk)
  env$lean$.spk$frame <- NULL
}

spk_clocks <- function(env) vapply(spk_cells, function(cell) 1e-9 * get(paste0("c_", cell), envir = env$lean$.spk), 0)

# Times ledgr_target_rebalance() calls into .spk$c_helper; returns the restore.
spk_wrap_helper <- function(env) {
  ns <- env$ns; spk <- env$lean$.spk; now <- env$lean$.spk_now
  f <- get("ledgr_target_rebalance", envir = ns)
  unlockBinding("ledgr_target_rebalance", ns)
  assign("ledgr_target_rebalance", function(...) {
    t0 <- now(); on.exit(spk$c_helper <- spk$c_helper + (now() - t0)); f(...)
  }, envir = ns)
  lockBinding("ledgr_target_rebalance", ns)
  function() { unlockBinding("ledgr_target_rebalance", ns); assign("ledgr_target_rebalance", f, envir = ns)
               lockBinding("ledgr_target_rebalance", ns) }
}
