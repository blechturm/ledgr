ledgr_execution_spec_version <- function() {
  "ledgr_execution_spec_v1"
}

ledgr_abort_invalid_execution_spec <- function(message) {
  rlang::abort(
    message,
    class = c("ledgr_invalid_execution_spec", "ledgr_invalid_fold_execution")
  )
}

ledgr_execution_spec_is_character_scalar <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
}

ledgr_execution_spec_is_logical_scalar <- function(x) {
  is.logical(x) && length(x) == 1L && !is.na(x)
}

ledgr_execution_spec_is_integer_like <- function(x,
                                                 allow_infinite = FALSE,
                                                 min = NULL) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x)) {
    return(FALSE)
  }
  if (is.infinite(x)) {
    return(isTRUE(allow_infinite) && x > 0)
  }
  if (!is.finite(x) || x != floor(x)) {
    return(FALSE)
  }
  is.null(min) || x >= min
}

ledgr_execution_spec_check <- function(ok, message) {
  if (!isTRUE(ok)) {
    ledgr_abort_invalid_execution_spec(message)
  }
}

ledgr_execution_spec <- function(run_id,
                                 instrument_ids,
                                 strategy_fn,
                                 strategy_params,
                                 strategy_call_signature,
                                 strategy_is_functional,
                                 pulses_posix,
                                 pulses_iso,
                                 start_idx,
                                 max_pulses,
                                 checkpoint_every,
                                 telemetry_stride,
                                 state,
                                 state_prev = NULL,
                                 bars_by_id,
                                 bars_mat,
                                 static_bars_views = NULL,
                                 static_feature_views = NULL,
                                 feature_defs,
                                 runtime_projection,
                                 active_alias_map = NULL,
                                 cost_resolver,
                                 event_seq_start,
                                 telemetry,
                                 seed = NULL,
                                 event_mode = c("live", "buffered"),
                                 use_fast_context = FALSE) {
  event_mode <- match.arg(event_mode)
  spec <- list(
    spec_version = ledgr_execution_spec_version(),
    run_id = run_id,
    instrument_ids = instrument_ids,
    strategy_fn = strategy_fn,
    strategy_params = strategy_params,
    strategy_call_signature = strategy_call_signature,
    strategy_is_functional = strategy_is_functional,
    pulses_posix = pulses_posix,
    pulses_iso = pulses_iso,
    start_idx = as.integer(start_idx),
    max_pulses = max_pulses,
    checkpoint_every = as.integer(checkpoint_every),
    telemetry_stride = as.integer(telemetry_stride),
    state = state,
    state_prev = state_prev,
    bars_by_id = bars_by_id,
    bars_mat = bars_mat,
    static_bars_views = static_bars_views,
    static_feature_views = static_feature_views,
    feature_defs = feature_defs,
    runtime_projection = runtime_projection,
    active_alias_map = active_alias_map,
    cost_resolver = cost_resolver,
    event_seq_start = as.integer(event_seq_start),
    telemetry = telemetry,
    seed = seed,
    event_mode = event_mode,
    use_fast_context = isTRUE(use_fast_context)
  )
  class(spec) <- c("ledgr_execution_spec", "list")
  ledgr_validate_execution_spec(spec)
}

ledgr_validate_execution_spec <- function(spec) {
  ledgr_execution_spec_check(
    inherits(spec, "ledgr_execution_spec"),
    "`execution` must be a ledgr_execution_spec object."
  )
  ledgr_execution_spec_check(
    identical(spec$spec_version, ledgr_execution_spec_version()),
    "`execution$spec_version` is not supported."
  )
  ledgr_execution_spec_check(
    ledgr_execution_spec_is_character_scalar(spec$run_id),
    "`execution$run_id` must be a non-empty character scalar."
  )
  ledgr_execution_spec_check(
    is.character(spec$instrument_ids) &&
      length(spec$instrument_ids) > 0L &&
      !anyNA(spec$instrument_ids) &&
      all(nzchar(spec$instrument_ids)) &&
      !anyDuplicated(spec$instrument_ids),
    "`execution$instrument_ids` must be unique non-empty character values."
  )
  ledgr_execution_spec_check(
    is.function(spec$strategy_fn),
    "`execution$strategy_fn` must be a function."
  )
  ledgr_execution_spec_check(
    is.list(spec$strategy_params),
    "`execution$strategy_params` must be a list."
  )
  ledgr_execution_spec_check(
    ledgr_execution_spec_is_character_scalar(spec$strategy_call_signature),
    "`execution$strategy_call_signature` must be a non-empty character scalar."
  )
  ledgr_execution_spec_check(
    ledgr_execution_spec_is_logical_scalar(spec$strategy_is_functional),
    "`execution$strategy_is_functional` must be TRUE or FALSE."
  )
  ledgr_execution_spec_check(
    inherits(spec$pulses_posix, "POSIXct"),
    "`execution$pulses_posix` must be POSIXct."
  )
  ledgr_execution_spec_check(
    is.character(spec$pulses_iso) && length(spec$pulses_iso) == length(spec$pulses_posix),
    "`execution$pulses_iso` must align with `execution$pulses_posix`."
  )
  ledgr_execution_spec_check(
    ledgr_execution_spec_is_integer_like(spec$start_idx, min = 1L),
    "`execution$start_idx` must be an integer-like scalar >= 1."
  )
  ledgr_execution_spec_check(
    ledgr_execution_spec_is_integer_like(spec$max_pulses, allow_infinite = TRUE, min = 0L),
    "`execution$max_pulses` must be a non-negative integer-like scalar or Inf."
  )
  ledgr_execution_spec_check(
    ledgr_execution_spec_is_integer_like(spec$checkpoint_every, min = 0L),
    "`execution$checkpoint_every` must be an integer-like scalar >= 0."
  )
  ledgr_execution_spec_check(
    ledgr_execution_spec_is_integer_like(spec$telemetry_stride, min = 0L),
    "`execution$telemetry_stride` must be an integer-like scalar >= 0."
  )
  ledgr_execution_spec_check(
    is.list(spec$state) &&
      is.numeric(spec$state$cash) &&
      length(spec$state$cash) == 1L &&
      is.finite(spec$state$cash) &&
      is.numeric(spec$state$positions) &&
      !is.null(names(spec$state$positions)),
    "`execution$state` must include scalar cash and named numeric positions."
  )
  ledgr_execution_spec_check(
    is.list(spec$bars_by_id),
    "`execution$bars_by_id` must be a list."
  )
  ledgr_execution_spec_check(
    is.list(spec$bars_mat) && is.matrix(spec$bars_mat$close),
    "`execution$bars_mat` must include a close matrix."
  )
  ledgr_execution_spec_check(
    is.null(spec$static_bars_views) || is.list(spec$static_bars_views),
    "`execution$static_bars_views` must be NULL or a list."
  )
  ledgr_execution_spec_check(
    is.null(spec$static_feature_views) || is.list(spec$static_feature_views),
    "`execution$static_feature_views` must be NULL or a list."
  )
  ledgr_execution_spec_check(
    is.list(spec$feature_defs),
    "`execution$feature_defs` must be a list."
  )
  ledgr_execution_spec_check(
    inherits(spec$runtime_projection, "ledgr_runtime_projection"),
    "`execution$runtime_projection` must be a ledgr_runtime_projection object."
  )
  ledgr_execution_spec_check(
    is.function(spec$cost_resolver),
    "`execution$cost_resolver` must be a function."
  )
  ledgr_execution_spec_check(
    ledgr_execution_spec_is_integer_like(spec$event_seq_start, min = 1L),
    "`execution$event_seq_start` must be an integer-like scalar >= 1."
  )
  ledgr_execution_spec_check(
    is.environment(spec$telemetry) || is.list(spec$telemetry),
    "`execution$telemetry` must be an environment or list."
  )
  ledgr_execution_spec_check(
    is.null(spec$seed) ||
      ledgr_execution_spec_is_integer_like(spec$seed),
    "`execution$seed` must be NULL or an integer-like scalar."
  )
  ledgr_execution_spec_check(
    identical(spec$event_mode, "live") || identical(spec$event_mode, "buffered"),
    "`execution$event_mode` must be \"live\" or \"buffered\"."
  )
  ledgr_execution_spec_check(
    ledgr_execution_spec_is_logical_scalar(spec$use_fast_context),
    "`execution$use_fast_context` must be TRUE or FALSE."
  )
  invisible(spec)
}
