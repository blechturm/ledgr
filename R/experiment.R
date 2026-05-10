#' Define an opening portfolio state
#'
#' `ledgr_opening()` creates the explicit starting state used by the v0.1.7
#' experiment-first workflow. It records starting cash and, optionally, existing
#' long positions and cost basis.
#'
#' @param cash Finite non-negative cash balance.
#' @param date Optional opening timestamp. `NULL` lets ledgr choose the first
#'   valid pulse after indicator warmup.
#' @param positions Optional named numeric vector of starting long positions.
#' @param cost_basis Optional named numeric vector with the same names as
#'   `positions`.
#' @return A `ledgr_opening` object.
#' @examples
#' ledgr_opening(cash = 100000)
#' ledgr_opening(
#'   cash = 25000,
#'   positions = c(AAA = 10, BBB = 5),
#'   cost_basis = c(AAA = 101.25, BBB = 98.50)
#' )
#' @export
ledgr_opening <- function(cash,
                          date = NULL,
                          positions = NULL,
                          cost_basis = NULL) {
  if (!is.numeric(cash) || length(cash) != 1L || is.na(cash) || !is.finite(cash)) {
    rlang::abort("`cash` must be a finite numeric scalar.", class = "ledgr_invalid_opening")
  }
  if (cash < 0) {
    rlang::abort("`cash` must be >= 0.", class = "ledgr_invalid_opening")
  }

  date_iso <- NULL
  if (!is.null(date)) {
    date_iso <- tryCatch(
      iso_utc(date),
      error = function(e) {
        rlang::abort("`date` must be a parseable timestamp.", class = "ledgr_invalid_opening", parent = e)
      }
    )
  }

  positions <- ledgr_opening_normalize_positions(positions)
  cost_basis <- ledgr_opening_normalize_cost_basis(cost_basis, positions)

  structure(
    list(
      cash = as.numeric(cash),
      date = date_iso,
      positions = positions,
      cost_basis = cost_basis
    ),
    class = "ledgr_opening"
  )
}

ledgr_opening_normalize_positions <- function(positions) {
  if (is.null(positions)) {
    return(stats::setNames(numeric(), character()))
  }
  if (!is.numeric(positions) || length(positions) < 1L) {
    rlang::abort("`positions` must be NULL or a named numeric vector.", class = "ledgr_invalid_opening")
  }
  position_names <- names(positions)
  if (is.null(position_names) ||
      length(position_names) != length(positions) ||
      anyNA(position_names) ||
      any(!nzchar(position_names)) ||
      anyDuplicated(position_names)) {
    rlang::abort(
      "`positions` must have unique non-empty instrument names.",
      class = "ledgr_invalid_opening"
    )
  }
  if (anyNA(positions) || any(!is.finite(positions))) {
    rlang::abort("`positions` must contain finite numeric quantities.", class = "ledgr_invalid_opening")
  }
  if (any(positions < 0)) {
    rlang::abort("Negative opening positions are not supported in v0.1.7.", class = "ledgr_invalid_opening")
  }
  as.numeric(positions) |>
    stats::setNames(position_names)
}

ledgr_opening_normalize_cost_basis <- function(cost_basis, positions) {
  if (is.null(cost_basis)) {
    return(NULL)
  }
  if (length(positions) < 1L) {
    rlang::abort("`cost_basis` requires non-empty `positions`.", class = "ledgr_invalid_opening")
  }
  if (!is.numeric(cost_basis) || length(cost_basis) != length(positions)) {
    rlang::abort(
      "`cost_basis` must be a numeric vector with one value per opening position.",
      class = "ledgr_invalid_opening"
    )
  }
  basis_names <- names(cost_basis)
  if (is.null(basis_names) ||
      length(basis_names) != length(cost_basis) ||
      anyNA(basis_names) ||
      any(!nzchar(basis_names)) ||
      anyDuplicated(basis_names)) {
    rlang::abort("`cost_basis` must have unique non-empty instrument names.", class = "ledgr_invalid_opening")
  }
  if (!setequal(basis_names, names(positions))) {
    rlang::abort("`cost_basis` names must match `positions` names.", class = "ledgr_invalid_opening")
  }
  if (anyNA(cost_basis) || any(!is.finite(cost_basis))) {
    rlang::abort("`cost_basis` must contain finite numeric values.", class = "ledgr_invalid_opening")
  }
  as.numeric(cost_basis[names(positions)]) |>
    stats::setNames(names(positions))
}

#' Print an opening portfolio state
#'
#' @param x A `ledgr_opening` object.
#' @param ... Unused.
#' @return The input object, invisibly.
#' @export
print.ledgr_opening <- function(x, ...) {
  if (!inherits(x, "ledgr_opening")) {
    rlang::abort("`x` must be a ledgr_opening object.", class = "ledgr_invalid_opening")
  }
  n_positions <- length(x$positions)
  cat("ledgr_opening\n")
  cat("==============\n")
  cat("Cash:       ", format(x$cash, scientific = FALSE, trim = TRUE), "\n", sep = "")
  cat("Date:       ", if (is.null(x$date)) "<auto>" else x$date, "\n", sep = "")
  cat("Positions:  ", n_positions, "\n", sep = "")
  if (n_positions > 0L) {
    shown <- paste(utils::head(names(x$positions), 5L), collapse = ", ")
    if (n_positions > 5L) shown <- paste0(shown, ", ...")
    cat("Instruments:", shown, "\n")
  }
  invisible(x)
}

#' Define a reusable ledgr experiment
#'
#' `ledgr_experiment()` bundles a sealed snapshot, strategy, features, opening
#' state, and execution options into the experiment-first public object used by
#' the v0.1.7 workflow. The constructor validates shape only; it does not run a
#' strategy or write run artifacts.
#'
#' @param snapshot A sealed `ledgr_snapshot`.
#' @param strategy A function with signature `function(ctx, params)`.
#' @param features List of `ledgr_indicator` objects, a `ledgr_feature_map`, or
#'   a function with signature `function(params)` returning one of those forms
#'   at run time.
#' @param opening A `ledgr_opening` object.
#' @param universe Character vector of instrument IDs, or `NULL` for all
#'   instruments in the snapshot.
#' @param fill_model Fill model config. `NULL` uses ledgr's default next-open
#'   model with zero spread and zero fixed commission.
#' @param persist_features Logical scalar.
#' @param execution_mode Execution mode (`"audit_log"` or `"db_live"`).
#' @return A `ledgr_experiment` object.
#' @section Articles:
#' Strategy authoring:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#'
#' Durable experiment stores:
#' `vignette("experiment-store", package = "ledgr")`
#' `system.file("doc", "experiment-store.html", package = "ledgr")`
#'
#' Reproducibility model:
#' `vignette("reproducibility", package = "ledgr")`
#' `system.file("doc", "reproducibility.html", package = "ledgr")`
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102),
#'   high = c(101, 102, 103),
#'   low = c(99, 100, 101),
#'   close = c(100, 101, 102),
#'   volume = 1000
#' )
#' snapshot <- ledgr_snapshot_from_df(bars)
#' strategy <- function(ctx, params) {
#'   stats::setNames(rep(0, length(ctx$universe)), ctx$universe)
#' }
#' exp <- ledgr_experiment(snapshot, strategy)
#' print(exp)
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_experiment <- function(snapshot,
                             strategy,
                             features = list(),
                             opening = ledgr_opening(cash = 100000),
                             universe = NULL,
                             fill_model = NULL,
                             persist_features = TRUE,
                             execution_mode = "audit_log") {
  if (!inherits(snapshot, "ledgr_snapshot")) {
    rlang::abort("`snapshot` must be a ledgr_snapshot object.", class = "ledgr_invalid_experiment")
  }
  ledgr_experiment_validate_snapshot(snapshot)

  universe_all <- ledgr_experiment_snapshot_universe(snapshot)
  universe <- ledgr_experiment_normalize_universe(universe, universe_all)
  ledgr_experiment_validate_strategy(strategy)
  features_mode <- ledgr_experiment_validate_features(features)
  features <- ledgr_experiment_copy_features(features, features_mode)

  if (!inherits(opening, "ledgr_opening")) {
    rlang::abort("`opening` must be a ledgr_opening object.", class = "ledgr_invalid_experiment")
  }
  ledgr_experiment_validate_opening(opening, universe)

  fill_model <- ledgr_experiment_normalize_fill_model(fill_model)

  if (!is.logical(persist_features) || length(persist_features) != 1L || is.na(persist_features)) {
    rlang::abort("`persist_features` must be TRUE or FALSE.", class = "ledgr_invalid_experiment")
  }
  if (!is.character(execution_mode) || length(execution_mode) != 1L || is.na(execution_mode) || !nzchar(execution_mode)) {
    rlang::abort("`execution_mode` must be a non-empty character scalar.", class = "ledgr_invalid_experiment")
  }
  if (!execution_mode %in% c("audit_log", "db_live")) {
    rlang::abort("`execution_mode` must be \"audit_log\" or \"db_live\".", class = "ledgr_invalid_experiment")
  }

  structure(
    list(
      snapshot = snapshot,
      strategy = strategy,
      features = features,
      features_mode = features_mode,
      opening = opening,
      universe = universe,
      fill_model = fill_model,
      persist_features = isTRUE(persist_features),
      execution_mode = execution_mode
    ),
    class = "ledgr_experiment"
  )
}

ledgr_experiment_validate_snapshot <- function(snapshot) {
  opened <- ledgr_snapshot_open(snapshot)
  if (isTRUE(opened$opened_new)) {
    on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  }
  info <- ledgr_snapshot_info(opened$con, snapshot$snapshot_id)
  if (!identical(info$status[[1]], "SEALED")) {
    rlang::abort(
      sprintf("`snapshot` must be SEALED; current status is %s.", info$status[[1]]),
      class = "ledgr_invalid_experiment"
    )
  }
  invisible(TRUE)
}

ledgr_experiment_snapshot_universe <- function(snapshot) {
  opened <- ledgr_snapshot_open(snapshot)
  if (isTRUE(opened$opened_new)) {
    on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  }
  universe <- DBI::dbGetQuery(
    opened$con,
    "SELECT instrument_id FROM snapshot_instruments WHERE snapshot_id = ? ORDER BY instrument_id",
    params = list(snapshot$snapshot_id)
  )$instrument_id
  universe <- as.character(universe)
  universe <- universe[!is.na(universe) & nzchar(universe)]
  if (length(universe) < 1L) {
    rlang::abort("`snapshot` contains no instruments.", class = "ledgr_invalid_experiment")
  }
  universe
}

ledgr_experiment_normalize_universe <- function(universe, universe_all) {
  if (is.null(universe)) {
    return(universe_all)
  }
  if (!is.character(universe) || length(universe) < 1L || anyNA(universe) || any(!nzchar(universe))) {
    rlang::abort("`universe` must be NULL or a non-empty character vector.", class = "ledgr_invalid_experiment")
  }
  if (anyDuplicated(universe)) {
    rlang::abort("`universe` must not contain duplicates.", class = "ledgr_invalid_experiment")
  }
  missing <- setdiff(universe, universe_all)
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf(
        "`universe` contains instruments not present in the snapshot: %s. Available instruments: %s.",
        paste(missing, collapse = ", "),
        paste(universe_all, collapse = ", ")
      ),
      class = "ledgr_invalid_experiment"
    )
  }
  universe
}

ledgr_experiment_validate_strategy <- function(strategy) {
  if (!is.function(strategy)) {
    rlang::abort(
      "`strategy` must be a function with signature function(ctx, params).",
      class = "ledgr_invalid_experiment_strategy"
    )
  }
  args <- names(formals(strategy))
  if (is.null(args)) args <- character()
  if (!identical(args, c("ctx", "params"))) {
    rlang::abort(
      paste0(
        "`strategy` must use signature function(ctx, params) in the v0.1.7 experiment workflow. ",
        "Unsupported signature: function(",
        paste(args, collapse = ", "),
        ")."
      ),
      class = "ledgr_invalid_experiment_strategy"
    )
  }
  invisible(TRUE)
}

ledgr_experiment_validate_features <- function(features) {
  if (is.function(features)) {
    args <- names(formals(features))
    if (is.null(args)) args <- character()
    if (!identical(args, "params")) {
      rlang::abort(
        "`features` functions must have signature function(params).",
        class = "ledgr_invalid_experiment_features"
      )
    }
    return("function")
  }
  if (inherits(features, "ledgr_feature_map")) {
    ledgr_validate_feature_map_object(features)
    return("feature_map")
  }
  if (!is.list(features)) {
    rlang::abort(
      "`features` must be a list of ledgr_indicator objects, a ledgr_feature_map, or function(params).",
      class = "ledgr_invalid_experiment_features"
    )
  }
  bad <- which(!vapply(features, inherits, logical(1), what = "ledgr_indicator"))
  if (length(bad) > 0L) {
    rlang::abort(
      sprintf("`features` list entries must be ledgr_indicator objects; invalid index: %s.", bad[[1]]),
      class = "ledgr_invalid_experiment_features"
    )
  }
  "list"
}

ledgr_experiment_copy_features <- function(features, features_mode) {
  if (identical(features_mode, "function")) {
    return(features)
  }
  if (identical(features_mode, "feature_map")) {
    return(do.call(ledgr_feature_map, ledgr_feature_map_indicators(features, named = TRUE)))
  }
  if (identical(features_mode, "list")) {
    return(as.list(features))
  }
  rlang::abort("Unknown experiment feature mode.", class = "ledgr_invalid_experiment_features")
}

ledgr_experiment_materialize_features <- function(exp, params) {
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("`exp` must be a ledgr_experiment object.", class = "ledgr_invalid_experiment")
  }
  features <- exp$features
  if (identical(exp$features_mode, "function")) {
    features <- features(params)
  }
  mode <- ledgr_experiment_validate_features(features)
  if (identical(mode, "feature_map")) {
    return(ledgr_feature_map_indicators(features))
  }
  if (!identical(mode, "list")) {
    rlang::abort(
      "`features` must resolve to a list of ledgr_indicator objects.",
      class = "ledgr_invalid_experiment_features"
    )
  }
  features
}

ledgr_experiment_validate_opening <- function(opening, universe) {
  if (length(opening$positions) > 0L) {
    missing <- setdiff(names(opening$positions), universe)
    if (length(missing) > 0L) {
      rlang::abort(
        sprintf("`opening` positions contain instruments outside `universe`: %s.", paste(missing, collapse = ", ")),
        class = "ledgr_invalid_experiment"
      )
    }
  }
  invisible(TRUE)
}

ledgr_experiment_normalize_fill_model <- function(fill_model) {
  if (is.null(fill_model)) {
    fill_model <- ledgr_fill_model_instant()
  }
  if (!is.list(fill_model)) {
    rlang::abort("`fill_model` must be a list.", class = "ledgr_invalid_experiment")
  }
  required <- c("type", "spread_bps", "commission_fixed")
  missing <- setdiff(required, names(fill_model))
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf("`fill_model` missing required field(s): %s.", paste(missing, collapse = ", ")),
      class = "ledgr_invalid_experiment"
    )
  }
  if (!identical(fill_model$type, "next_open")) {
    rlang::abort("`fill_model$type` must be \"next_open\".", class = "ledgr_invalid_experiment")
  }
  for (field in c("spread_bps", "commission_fixed")) {
    value <- fill_model[[field]]
    if (!is.numeric(value) || length(value) != 1L || is.na(value) || !is.finite(value) || value < 0) {
      rlang::abort(
        sprintf("`fill_model$%s` must be a finite numeric scalar >= 0.", field),
        class = "ledgr_invalid_experiment"
      )
    }
  }
  list(
    type = "next_open",
    spread_bps = as.numeric(fill_model$spread_bps),
    commission_fixed = as.numeric(fill_model$commission_fixed)
  )
}

#' Print a ledgr experiment
#'
#' @param x A `ledgr_experiment` object.
#' @param ... Unused.
#' @return The input object, invisibly.
#' @export
print.ledgr_experiment <- function(x, ...) {
  if (!inherits(x, "ledgr_experiment")) {
    rlang::abort("`x` must be a ledgr_experiment object.", class = "ledgr_invalid_experiment")
  }
  feature_desc <- if (identical(x$features_mode, "function")) {
    "function(params)"
  } else if (identical(x$features_mode, "feature_map")) {
    paste0(length(x$features$aliases), " mapped")
  } else {
    paste0(length(x$features), " fixed")
  }
  cat("ledgr_experiment\n")
  cat("================\n")
  cat("Snapshot ID: ", x$snapshot$snapshot_id, "\n", sep = "")
  cat("Database:    ", x$snapshot$db_path, "\n", sep = "")
  cat("Universe:    ", length(x$universe), " instrument", if (length(x$universe) == 1L) "" else "s", "\n", sep = "")
  cat("Features:    ", feature_desc, "\n", sep = "")
  cat("Opening:     cash=", format(x$opening$cash, scientific = FALSE, trim = TRUE),
      ", positions=", length(x$opening$positions), "\n", sep = "")
  cat("Mode:        ", x$execution_mode, "\n", sep = "")
  invisible(x)
}

#' Create opening state from a broker adapter
#'
#' This is a reserved adapter hook for the experiment-first workflow. v0.1.7
#' does not ship broker integrations; unsupported objects fail clearly instead
#' of opening network connections or guessing adapter semantics.
#'
#' @param x Broker adapter object.
#' @param ... Reserved for future adapter methods.
#' @return A `ledgr_opening` object for supported adapters.
#' @examples
#' try(ledgr_opening_from_broker(list()), silent = TRUE)
#' @export
ledgr_opening_from_broker <- function(x, ...) {
  rlang::abort(
    "`ledgr_opening_from_broker()` is a reserved adapter hook. v0.1.7 does not ship built-in broker adapters; use `ledgr_opening()` for explicit opening state.",
    class = "ledgr_broker_adapter_not_supported"
  )
}
