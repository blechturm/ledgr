# Current-tree gate for LDG-2939. The candidate changes only the run-local
# bundled feature accessor: validate a concrete feature map once, then reuse
# the last successful lookup only when the next map is identical().

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])
repo <- normalizePath(file.path(dirname(script), "..", "..", ".."), winslash = "/")
out <- arg_value("--out", file.path(dirname(script), "evidence"))
reps <- as.integer(arg_value("--reps", "3"))
stopifnot(reps >= 3L)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")

with_bindings <- function(bindings, code) {
  if (is.null(bindings)) return(force(code))
  old <- lapply(names(bindings), get, envir = ns)
  names(old) <- names(bindings)
  for (name in names(bindings)) {
    unlockBinding(name, ns)
    assign(name, bindings[[name]], envir = ns)
  }
  on.exit(for (name in names(old)) {
    assign(name, old[[name]], envir = ns)
    lockBinding(name, ns)
  }, add = TRUE)
  force(code)
}

lookup_once <- function(feature_map = NULL, active_alias_map = NULL) {
  if (missing(feature_map) || is.null(feature_map)) {
    alias_map <- ledgr_normalize_alias_map(active_alias_map)
    if (is.null(alias_map)) {
      rlang::abort(
        "`ctx$features(instrument_id)` requires an active alias map. Use `ctx$features(instrument_id, feature_map)` or `ctx$feature(instrument_id, feature_id)` for exact-ID lookup.",
        class = c("ledgr_no_active_alias_map", "ledgr_invalid_pulse_context")
      )
    }
    return(alias_map)
  }
  if (is.character(feature_map)) return(ledgr_normalize_alias_map(feature_map))
  ledgr_validate_feature_map_object(feature_map)
  if (any(vapply(
    feature_map$indicators,
    ledgr_feature_declaration_is_unresolved,
    logical(1)
  ))) {
    ledgr_abort_unresolved_feature_id()
  }
  feature_ids <- feature_map$feature_ids
  if (!is.character(feature_ids) || is.null(names(feature_ids)) ||
      anyNA(feature_ids) || any(!nzchar(feature_ids)) ||
      anyNA(names(feature_ids)) || any(!nzchar(names(feature_ids)))) {
    rlang::abort(
      "`feature_map` must resolve to a named character vector of concrete feature IDs.",
      class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
    )
  }
  stats::setNames(unname(feature_ids), names(feature_ids))
}
environment(lookup_once) <- ns

candidate_bundle <- function(projection,
                             state,
                             universe,
                             feature_ids = NULL,
                             active_alias_map = NULL,
                             prepared = NULL) {
  force(projection)
  force(state)
  if (is.null(prepared)) {
    prepared <- ledgr_projection_feature_lookup_state(
      projection,
      feature_ids = feature_ids,
      universe = universe,
      active_alias_map = active_alias_map
    )
  }
  feature <- ledgr_projection_feature_accessor_state(
    projection, state, feature_ids, prepared = prepared
  )
  universe <- prepared$universe
  members <- prepared$universe_members
  active_lookup <- prepared$active_lookup
  last_map <- NULL
  last_lookup <- NULL
  has_last <- FALSE
  function(instrument_id, feature_map = NULL) {
    if (!is.character(instrument_id) || length(instrument_id) != 1L ||
        is.na(instrument_id) || !nzchar(instrument_id)) {
      rlang::abort(
        "`instrument_id` must be a non-empty character scalar.",
        class = "ledgr_invalid_args"
      )
    }
    if (is.null(members[[instrument_id]])) {
      rlang::abort(
        sprintf(
          "Unknown instrument_id '%s'. Available ctx$universe: %s.",
          instrument_id,
          ledgr_pulse_context_universe_message(universe)
        ),
        class = "ledgr_invalid_pulse_context"
      )
    }
    lookup_map <- if (is.null(feature_map) && isTRUE(active_lookup$valid)) {
      active_lookup$value
    } else if (inherits(feature_map, "ledgr_feature_map") &&
               has_last && identical(feature_map, last_map)) {
      last_lookup
    } else {
      value <- lookup_once(feature_map, active_alias_map = active_alias_map)
      if (inherits(feature_map, "ledgr_feature_map")) {
        last_map <<- feature_map
        last_lookup <<- value
        has_last <<- TRUE
      }
      value
    }
    values <- vapply(lookup_map, function(feature_id) {
      value <- feature(instrument_id, feature_id)
      if (!is.numeric(value) || length(value) != 1L) {
        rlang::abort(
          sprintf(
            "Feature `%s` for instrument_id `%s` must be a scalar numeric value.",
            feature_id, instrument_id
          ),
          class = "ledgr_invalid_feature_value"
        )
      }
      as.numeric(value)
    }, numeric(1))
    stats::setNames(unname(values), names(lookup_map))
  }
}
environment(candidate_bundle) <- ns
candidate_bundle <- compiler::cmpfun(candidate_bundle)
arms <- list(
  production = NULL,
  candidate = list(
    ledgr_projection_feature_bundle_accessor_state = candidate_bundle
  )
)

bars <- as.data.frame(ledgr_sim_bars(
  n_instruments = 500L,
  n_days = 1260L,
  seed = 20260530L
))
source_path <- tempfile(fileext = ".duckdb")
snapshot <- ledgr_snapshot_from_df(
  bars,
  db_path = source_path,
  snapshot_id = "ws7-explicit"
)
ledgr_snapshot_close(snapshot)
rm(bars)
feature_map <- ledgr_feature_map(
  fast = ledgr_ind_sma(5L),
  slow = ledgr_ind_sma(10L)
)
strategy <- local({
  map <- feature_map
  function(ctx, params) {
    targets <- ctx$flat()
    for (id in ctx$universe) {
      values <- ctx$features(id, map)
      if (all(is.finite(values)) && values[["fast"]] > values[["slow"]]) {
        targets[[id]] <- 1
      }
    }
    targets
  }
})
make_experiment <- function(x) ledgr_experiment(
  x,
  strategy,
  features = feature_map,
  opening = ledgr_opening(cash = 1e7),
  cost_model = ledgr_cost_zero()
)
grid <- ledgr_param_grid(list(unused = 1))
copy_store <- function() {
  path <- tempfile(fileext = ".duckdb")
  stopifnot(file.copy(source_path, path))
  path
}
semantic <- function(x) {
  if (inherits(x, "ledgr_backtest")) {
    out <- list(
      fills = ledgr_results(x, what = "fills"),
      equity = ledgr_results(x, what = "equity"),
      trades = ledgr_results(x, what = "trades")
    )
    close(x)
    return(out)
  }
  attrs <- attributes(x)
  drop_sweep_id <- function(value) {
    if (is.data.frame(value)) {
      return(value[setdiff(names(value), "sweep_id")])
    }
    value
  }
  keep <- names(x)[!grepl("^t_", names(x))]
  list(
    columns = stats::setNames(lapply(keep, function(name) x[[name]]), keep),
    returns = drop_sweep_id(attrs$sweep_returns),
    trades = drop_sweep_id(attrs$sweep_trades),
    attributes = attrs[setdiff(
      names(attrs),
      c(
        "names", "row.names", "class", "sweep_id", "sweep_returns",
        "sweep_trades", "t_prepare", "t_engine", "t_results"
      )
    )]
  )
}
run_arm <- function(workflow, bindings) {
  path <- copy_store()
  on.exit(unlink(path), add = TRUE)
  snapshot <- ledgr_snapshot_open(path, "ws7-explicit")
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  invisible(gc())
  g0 <- gc.time()[[3L]]
  t0 <- Sys.time()
  value <- with_bindings(bindings, {
    if (identical(workflow, "ledgr_run")) {
      ledgr_run(make_experiment(snapshot), run_id = "ws7", seed = 1L)
    } else {
      ledgr_sweep(make_experiment(snapshot), grid, seed = 1L)
    }
  })
  elapsed <- as.numeric(Sys.time() - t0, units = "secs")
  gc_s <- gc.time()[[3L]] - g0
  list(elapsed = elapsed, gc_s = gc_s, value = semantic(value))
}
other_r <- function() {
  rows <- suppressWarnings(system2(
    "tasklist", c("/FO", "CSV", "/NH"), stdout = TRUE, stderr = FALSE
  ))
  tasks <- utils::read.csv(text = rows, header = FALSE, stringsAsFactors = FALSE)
  sum(tasks$V1 %in% c("Rscript.exe", "Rterm.exe", "R.exe") &
        tasks$V2 != Sys.getpid())
}

timing <- list()
parity <- list()
for (workflow in c("ledgr_run", "ledgr_sweep")) {
  reference <- run_arm(workflow, arms$production)$value
  for (rep in seq_len(reps)) {
    order <- if (rep %% 2L) names(arms) else rev(names(arms))
    for (position in seq_along(order)) {
      arm <- order[[position]]
      result <- run_arm(workflow, arms[[arm]])
      timing[[length(timing) + 1L]] <- data.frame(
        workflow = workflow,
        rep = rep,
        position = position,
        arm = arm,
        elapsed_s = result$elapsed,
        gc_s = result$gc_s,
        other_r_processes = other_r()
      )
      parity[[length(parity) + 1L]] <- data.frame(
        workflow = workflow,
        rep = rep,
        arm = arm,
        identical = identical(result$value, reference)
      )
    }
  }
}
timing <- do.call(rbind, timing)
parity <- do.call(rbind, parity)
summary <- do.call(rbind, lapply(split(timing, timing$workflow), function(x) {
  base <- stats::median(x$elapsed_s[x$arm == "production"])
  candidate <- stats::median(x$elapsed_s[x$arm == "candidate"])
  data.frame(
    workflow = x$workflow[[1L]],
    production_median_s = base,
    candidate_median_s = candidate,
    gain_fraction = (base - candidate) / base
  )
}))
utils::write.csv(timing, file.path(out, "timing.csv"), row.names = FALSE)
utils::write.csv(summary, file.path(out, "timing_summary.csv"), row.names = FALSE)
utils::write.csv(parity, file.path(out, "parity.csv"), row.names = FALSE)
utils::write.csv(data.frame(
  key = c("r_version", "collapse", "duckdb", "git_head"),
  value = c(
    R.version.string,
    as.character(packageVersion("collapse")),
    as.character(packageVersion("duckdb")),
    system2("git", c("-C", shQuote(repo), "rev-parse", "HEAD"), stdout = TRUE)
  )
), file.path(out, "environment.csv"), row.names = FALSE)
unlink(source_path)
print(summary, row.names = FALSE)
stopifnot(all(parity$identical), all(summary$gain_fraction > 0.05))
