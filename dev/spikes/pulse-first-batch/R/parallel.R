pfb_batches <- function(n, batch_size) {
  batch_size <- if (identical(batch_size, "all")) n else as.integer(batch_size)
  stopifnot(batch_size >= 1L)
  split(seq_len(n), ceiling(seq_len(n) / batch_size))
}

pfb_process_rss <- function() {
  if (!requireNamespace("ps", quietly = TRUE)) return(c(total = NA_real_, child = NA_real_))
  parent <- ps::ps_handle(Sys.getpid())
  handles <- c(list(parent), ps::ps_children(parent, recursive = TRUE))
  rss <- vapply(handles, function(x) {
    tryCatch(as.numeric(ps::ps_memory_info(x)[["rss"]]), error = function(e) 0)
  }, numeric(1))
  c(total = sum(rss), child = if (length(rss) > 1L) max(rss[-1L]) else 0)
}

pfb_run_parallel <- function(prepared,
                             params,
                             workers,
                             batch_size,
                             spike_root,
                             loop = c("pulse_first", "strategy_first"),
                             retention = "summary") {
  loop <- match.arg(loop)
  workers <- as.integer(workers)
  batches <- pfb_batches(nrow(params), batch_size)
  if (workers == 1L) {
    started <- proc.time()[[3L]]
    pieces <- lapply(batches, function(idx) {
      if (identical(loop, "pulse_first")) {
        pfb_run_pulse_first(prepared, params[idx, , drop = FALSE], retention, TRUE)
      } else {
        pfb_run_strategy_first(prepared, params[idx, , drop = FALSE], retention)
      }
    })
    results <- unlist(lapply(pieces, `[[`, "results"), recursive = FALSE)
    return(list(
      results = pfb_order_results(results),
      elapsed_sec = proc.time()[[3L]] - started,
      worker_init_sec = 0,
      dispatch_sec = 0,
      collect_sec = 0,
      merge_sec = 0,
      worker_max_sec = max(vapply(pieces, `[[`, numeric(1), "elapsed_sec")),
      peak_total_rss_bytes = NA_real_,
      peak_child_rss_bytes = NA_real_,
      staged_bytes = as.numeric(object.size(prepared)),
      serialized_staged_bytes = length(serialize(prepared, NULL)),
      n_batches = length(batches)
    ))
  }
  if (!requireNamespace("mirai", quietly = TRUE)) stop("mirai is required")
  core_path <- normalizePath(file.path(spike_root, "R", "core.R"), winslash = "/")
  loops_path <- normalizePath(file.path(spike_root, "R", "loops.R"), winslash = "/")
  total_start <- proc.time()[[3L]]
  mirai::daemons(workers)
  on.exit(mirai::daemons(0), add = TRUE)
  mirai::everywhere(
    {
      source(core_path)
      source(loops_path)
      assign(".pfb_prepared", prepared, envir = .GlobalEnv)
      TRUE
    },
    core_path = core_path,
    loops_path = loops_path,
    prepared = prepared,
    .min = workers
  )
  init_end <- proc.time()[[3L]]
  promises <- lapply(batches, function(idx) {
    batch_params <- params[idx, , drop = FALSE]
    mirai::mirai(
      {
        gc(reset = TRUE)
        started <- proc.time()[[3L]]
        out <- if (identical(loop, "pulse_first")) {
          pfb_run_pulse_first(.pfb_prepared, batch_params, retention, TRUE)
        } else {
          pfb_run_strategy_first(.pfb_prepared, batch_params, retention)
        }
        list(
          results = out$results,
          elapsed_sec = proc.time()[[3L]] - started,
          peak_r_heap_mb = sum(gc()[, 6L])
        )
      },
      batch_params = batch_params,
      loop = loop,
      retention = retention
    )
  })
  dispatch_end <- proc.time()[[3L]]
  peak <- pfb_process_rss()
  while (mirai::unresolved(promises) > 0L) {
    sample <- pfb_process_rss()
    peak <- pmax(peak, sample, na.rm = TRUE)
    Sys.sleep(0.02)
  }
  pieces <- lapply(promises, function(x) x[])
  collect_end <- proc.time()[[3L]]
  merged <- pfb_order_results(unlist(lapply(pieces, `[[`, "results"), recursive = FALSE))
  merge_end <- proc.time()[[3L]]
  list(
    results = merged,
    elapsed_sec = merge_end - total_start,
    worker_init_sec = init_end - total_start,
    dispatch_sec = dispatch_end - init_end,
    collect_sec = collect_end - dispatch_end,
    merge_sec = merge_end - collect_end,
    worker_max_sec = max(vapply(pieces, `[[`, numeric(1), "elapsed_sec")),
    worker_peak_r_heap_mb = max(vapply(pieces, `[[`, numeric(1), "peak_r_heap_mb")),
    peak_total_rss_bytes = unname(peak[["total"]]),
    peak_child_rss_bytes = unname(peak[["child"]]),
    staged_bytes = as.numeric(object.size(prepared)),
    serialized_staged_bytes = length(serialize(prepared, NULL)),
    n_batches = length(batches)
  )
}
