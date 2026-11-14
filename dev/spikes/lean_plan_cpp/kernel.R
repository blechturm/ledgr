# Spike lean_plan_cpp: compile kernel.cpp and install it at one seam,
# lean_plan_pulse() in a lean environment: the compiled planner first, the R
# planner when it declines (returns NULL) or in debug.

spike_plan_compile <- function(file) {
  env <- new.env()
  cpp11::cpp_source(file, env = env, quiet = TRUE)
  env$spike_plan_pulse
}

spike_plan_install <- function(lean, kernel) {
  r_plan <- lean$lean_plan_pulse
  stats <- new.env(); stats$compiled <- 0L; stats$declined <- 0L
  resolve <- get("ledgr_plan_resolve", envir = asNamespace("ledgr"))
  lean$lean_plan_pulse <- function(context_pos, target_qty, position, actionable_k, member, execution,
                                   execution_view, epoch_valid, cost_resolver, cash, instrument_ids) {
    if (!.lean_debug) {
      r <- kernel(context_pos, target_qty, position, actionable_k, member, execution, execution_view, epoch_valid,
                  cost_resolver, cash, lean_plan_id_rank(instrument_ids), resolve)
      if (!is.null(r)) { stats$compiled <- stats$compiled + 1L; return(r) }
    }
    stats$declined <- stats$declined + 1L
    r_plan(context_pos, target_qty, position, actionable_k, member, execution, execution_view, epoch_valid,
           cost_resolver, cash, instrument_ids)
  }
  environment(lean$lean_plan_pulse) <- list2env(list(kernel = kernel, r_plan = r_plan, stats = stats, resolve = resolve),
                                                parent = lean)
  list(r_plan = r_plan, stats = stats)
}
