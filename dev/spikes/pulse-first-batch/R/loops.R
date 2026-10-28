pfb_run_strategy_first <- function(prepared, params, retention = "summary") {
  param_list <- pfb_prepare_params(params)
  counter <- pfb_counter()
  results <- vector("list", nrow(params))
  last_state <- NULL
  initialization_sec <- 0
  result_collection_sec <- 0
  started <- proc.time()[[3L]]
  for (j in seq_len(nrow(params))) {
    init_started <- proc.time()[[3L]]
    state <- pfb_state_new(prepared, retention = retention)
    initialization_sec <- initialization_sec + proc.time()[[3L]] - init_started
    param <- param_list[[j]]
    for (pulse in seq_len(prepared$n_sessions)) {
      context <- pfb_candidate_context(prepared, pulse, param, counter = counter)
      pfb_execute_pulse(param, context, state)
    }
    result_started <- proc.time()[[3L]]
    results[[j]] <- pfb_summarize_state(state, params$candidate_id[[j]])
    result_collection_sec <- result_collection_sec +
      proc.time()[[3L]] - result_started
    last_state <- state
  }
  elapsed_sec <- proc.time()[[3L]] - started
  live_state_bytes <- if (is.null(last_state)) 0 else pfb_serialized_bytes(last_state)
  list(
    variant = "strategy_first",
    results = results,
    elapsed_sec = elapsed_sec,
    initialization_sec = initialization_sec,
    pulse_loop_sec = elapsed_sec - initialization_sec - result_collection_sec,
    result_collection_sec = result_collection_sec,
    counters = pfb_counter_values(counter),
    state_bytes = live_state_bytes
  )
}

pfb_run_pulse_first <- function(prepared,
                                params,
                                retention = "summary",
                                share_pulse = TRUE,
                                gut = FALSE) {
  param_list <- pfb_prepare_params(params)
  counter <- pfb_counter()
  init_started <- proc.time()[[3L]]
  states <- lapply(seq_len(nrow(params)), function(i) {
    pfb_state_new(prepared, retention = retention)
  })
  initialization_sec <- proc.time()[[3L]] - init_started
  started <- proc.time()[[3L]]
  for (pulse in seq_len(prepared$n_sessions)) {
    shared <- if (share_pulse) pfb_shared_pulse(prepared, pulse, counter) else NULL
    for (j in seq_len(nrow(params))) {
      param <- param_list[[j]]
      context <- pfb_candidate_context(prepared, pulse, param, shared, counter)
      pfb_execute_pulse(param, context, states[[j]])
    }
  }
  result_started <- proc.time()[[3L]]
  results <- lapply(seq_len(nrow(params)), function(j) {
    pfb_summarize_state(states[[j]], params$candidate_id[[j]])
  })
  result_collection_sec <- proc.time()[[3L]] - result_started
  if (isTRUE(gut) && share_pulse && length(results) > 0L) {
    results[[1L]]$cash <- results[[1L]]$cash + 1
  }
  loop_and_results_sec <- proc.time()[[3L]] - started
  live_state_bytes <- pfb_serialized_bytes(states)
  list(
    variant = if (share_pulse) "pulse_first_shared" else "pulse_first_naive",
    results = results,
    elapsed_sec = initialization_sec + loop_and_results_sec,
    initialization_sec = initialization_sec,
    pulse_loop_sec = loop_and_results_sec - result_collection_sec,
    result_collection_sec = result_collection_sec,
    counters = pfb_counter_values(counter),
    state_bytes = live_state_bytes
  )
}

pfb_order_results <- function(x) {
  unname(x[order(vapply(x, `[[`, character(1), "candidate_id"), method = "radix")])
}

pfb_results_identical <- function(a, b) {
  identical(pfb_order_results(a), pfb_order_results(b))
}

pfb_flatten_results <- function(results) {
  data.frame(
    candidate_id = vapply(results, `[[`, character(1), "candidate_id"),
    cash = vapply(results, `[[`, numeric(1), "cash"),
    equity = vapply(results, `[[`, numeric(1), "equity"),
    fill_count = vapply(results, `[[`, integer(1), "fill_count"),
    turnover = vapply(results, `[[`, numeric(1), "turnover"),
    stringsAsFactors = FALSE
  )
}
