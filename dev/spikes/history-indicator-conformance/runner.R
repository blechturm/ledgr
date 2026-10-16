# H2 Session D indicator-history evidence runner.
#
# Usage:
#   Rscript runner.R <ledgr_repo> <out_dir> [--gut]
#
# This is a no-product-change probe. It inventories every built-in indicator
# and every function/output admitted by ledgr_ind_ttr_warmup_rules(), then
# records prefix causality, finite-window restart evidence, raw-backend versus
# declared warmup, current ragged availability behavior, and fixture-local
# post-gap convergence evidence.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) stop("usage: runner.R <ledgr_repo> <out_dir> [--gut]")
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
out_dir <- normalizePath(args[[2L]], winslash = "/", mustWork = FALSE)
gut <- "--gut" %in% args
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressPackageStartupMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))

`%or%` <- function(x, y) if (is.null(x)) y else x
iso <- function(x) format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
write_csv <- function(x, name) {
  utils::write.csv(x, file.path(out_dir, name), row.names = FALSE, na = "")
}
condition_label <- function(expr) {
  tryCatch(
    {
      force(expr)
      "ok"
    },
    error = function(cnd) {
      classes <- setdiff(class(cnd), c("rlang_error", "error", "condition"))
      if (length(classes)) classes[[1L]] else "error"
    }
  )
}

day0 <- as.POSIXct("2020-01-01 00:00:00", tz = "UTC")
bars_for <- function(close) {
  n <- length(close)
  spread <- pmax(abs(close) * 1e-4, 0.25)
  data.frame(
    instrument_id = "AAA",
    ts_utc = day0 + 86400 * (seq_len(n) - 1L),
    open = close + 0.10 * spread * sin(seq_len(n) / 3),
    high = close + spread,
    low = close - spread,
    close = close,
    volume = 100000 + 1000 * (seq_len(n) %% 17L),
    stringsAsFactors = FALSE
  )
}

n_bars <- 420L
set.seed(20261016L)
fixtures <- list(
  smooth = bars_for(100 + 0.025 * seq_len(n_bars) +
                      4 * sin(seq_len(n_bars) / 9) +
                      1.2 * cos(seq_len(n_bars) / 17)),
  volatile = bars_for(150 + cumsum(stats::rnorm(n_bars, 0.02, 1.8)) +
                        rep(c(0, 6, -5, 2), length.out = n_bars)),
  large_scale = bars_for(1e9 + cumsum(stats::rnorm(n_bars, 10, 2500)) +
                           50000 * sin(seq_len(n_bars) / 11)),
  level_shift = bars_for(c(
    1e6 + 100 * sin(seq_len(n_bars / 2L) / 7),
    1 + 0.01 * sin(seq_len(n_bars / 2L) / 5)
  ))
)

specs <- list()
add_spec <- function(name,
                     indicator,
                     family,
                     output = "value",
                     input = "close",
                     history_class,
                     algorithm = "default",
                     census_role = "default_arguments") {
  specs[[name]] <<- list(
    name = name,
    indicator = indicator,
    source = indicator$source %or% "custom",
    family = family,
    output = output,
    input = input,
    history_class = history_class,
    algorithm = algorithm,
    census_role = census_role
  )
}

add_spec("builtin_sma", ledgr_ind_sma(10L), "SMA", history_class = "bounded")
add_spec("builtin_ema", ledgr_ind_ema(10L), "EMA_bounded", history_class = "bounded")
add_spec("builtin_rsi", ledgr_ind_rsi(10L), "RSI_simple", history_class = "bounded")
add_spec("builtin_returns", ledgr_ind_returns(10L), "returns", history_class = "bounded")

rules <- ledgr_ind_ttr_warmup_rules()
multi <- c("ATR", "MACD", "BBands", "aroon", "DonchianChannel")
rule_args <- function(family) {
  if (identical(family, "MACD")) {
    return(list(nFast = 5L, nSlow = 10L, nSig = 4L, percent = FALSE))
  }
  list(n = if (identical(family, "RSI")) 14L else 10L)
}

for (i in seq_len(nrow(rules))) {
  family <- rules$ttr_fn[[i]]
  input <- rules$input[[i]]
  constructor_args <- c(list(ttr_fn = family, input = input), rule_args(family))
  if (family %in% multi) {
    bundle <- do.call(ledgr_ind_ttr_outputs, constructor_args)
    indicators <- ledgr:::ledgr_indicator_bundle_indicators(bundle)
    for (indicator in indicators) {
      output <- indicator$params$output
      name <- paste("ttr", tolower(family), tolower(output), sep = "_")
      history_class <- if (
        identical(family, "MACD") ||
          (identical(family, "ATR") && identical(output, "atr"))
      ) "history_dependent" else "bounded"
      add_spec(name, indicator, family, output, input, history_class)
    }
  } else {
    indicator <- do.call(ledgr_ind_ttr, constructor_args)
    name <- paste("ttr", tolower(family), "value", sep = "_")
    history_class <- if (family %in% c("RSI", "EMA")) {
      "history_dependent"
    } else {
      "bounded"
    }
    add_spec(name, indicator, family, "value", input, history_class)
  }
}

# Algorithm-changing arguments are separate evidence rows. A function name is
# not a history class: changing maType can change the dependency structure.
add_variant <- function(spec_name, family, input, output = NULL, history_class, ...) {
  indicator <- ledgr_ind_ttr(
    family,
    input = input,
    output = output,
    ...
  )
  add_spec(
    spec_name,
    indicator,
    family,
    output %or% "value",
    input,
    history_class,
    algorithm = paste(names(list(...)), unlist(list(...)), sep = "=", collapse = ";"),
    census_role = "algorithm_variant"
  )
}
add_variant(
  "variant_bbands_mavg_ema", "BBands", "close", "mavg",
  "history_dependent", n = 10L, maType = "EMA"
)
add_variant(
  "variant_cci_ema", "CCI", "hlc", NULL,
  "history_dependent", n = 10L, maType = "EMA"
)
add_variant(
  "variant_rsi_sma", "RSI", "close", NULL,
  "bounded", n = 14L, maType = "SMA"
)
add_variant(
  "variant_atr_atr_sma", "ATR", "hlc", "atr",
  "bounded", n = 10L, maType = "SMA"
)
for (output in c("macd", "signal", "histogram")) {
  add_variant(
    paste("variant_macd", output, "sma", sep = "_"),
    "MACD", "close", output, "bounded",
    nFast = 5L, nSlow = 10L, nSig = 4L, percent = FALSE, maType = "SMA"
  )
}
add_variant(
  "variant_ema_wilder", "EMA", "close", NULL,
  "history_dependent", n = 10L, wilder = TRUE
)

raw_ttr_first_finite <- function(spec, bars) {
  if (!identical(spec$source, "TTR")) return(NA_integer_)
  raw <- ledgr:::ledgr_ttr_call(bars, spec$indicator$params)
  idx <- which(is.finite(raw))
  if (length(idx)) idx[[1L]] else NA_integer_
}

inventory <- do.call(rbind, lapply(specs, function(spec) {
  ind <- spec$indicator
  data.frame(
    indicator = spec$name,
    source = spec$source,
    family = spec$family,
    output = spec$output,
    input = spec$input,
    algorithm = spec$algorithm,
    census_role = spec$census_role,
    requires_bars = as.integer(ind$requires_bars),
    stable_after = as.integer(ind$stable_after),
    raw_ttr_first_finite = raw_ttr_first_finite(spec, fixtures$smooth),
    gap_contract = ind$gap_contract %or% "none",
    history_class = spec$history_class,
    observed_upper_bound_witness_bars = if (identical(spec$family, "aroon")) {
      as.integer(ind$stable_after) + 1L
    } else {
      NA_integer_
    },
    width_witness = if (identical(spec$family, "aroon")) {
      "stable_after and stable_after+1 executed; latter is an observed upper bound, not a minimum"
    } else {
      "stable_after and stable_after+1 executed; no minimum dependency inferred"
    },
    classification_basis = if (spec$history_class == "bounded") {
      "current family/output/algorithm has finite dependence; restart evidence recorded"
    } else {
      "current family/output/algorithm carries earlier state; restart evidence recorded"
    },
    stringsAsFactors = FALSE
  )
}))
rownames(inventory) <- NULL

engine <- ledgr:::ledgr_compute_feature_series
scalar_value <- function(indicator, window, full_value) {
  # The gut erases the restart comparison. It is deliberately wrong and lets
  # the checker demonstrate that the bounded/history-dependent split matters.
  if (gut) return(full_value)
  ledgr:::ledgr_normalize_feature_scalar_output(
    ledgr:::ledgr_call_feature_fn(
      indicator$fn,
      window,
      indicator$params %or% list()
    ),
    indicator$id
  )
}
same_number <- function(a, b) {
  (is.na(a) && is.na(b)) || identical(a, b)
}

raw_samples <- list()
derived <- list()
width_witness <- list()
for (fixture_name in names(fixtures)) {
  bars <- fixtures[[fixture_name]]
  for (spec in specs) {
    ind <- spec$indicator
    full <- engine(bars, ind)
    engine_first_finite <- which(is.finite(full))
    engine_first_finite <- if (length(engine_first_finite)) {
      engine_first_finite[[1L]]
    } else {
      NA_integer_
    }
    raw_first_finite <- raw_ttr_first_finite(spec, bars)
    positions <- unique(as.integer(round(seq(
      max(ind$stable_after + 1L, 2L), nrow(bars), length.out = 24L
    ))))
    rows <- lapply(positions, function(position) {
      prefix <- engine(bars[seq_len(position), , drop = FALSE], ind)[[position]]
      widths <- c(
        stable_after = as.integer(ind$stable_after),
        stable_after_plus_one = as.integer(ind$stable_after) + 1L
      )
      do.call(rbind, lapply(names(widths), function(width_rule) {
        width <- widths[[width_rule]]
        window <- bars[seq.int(position - width + 1L, position), , drop = FALSE]
        scalar <- scalar_value(ind, window, full[[position]])
        data.frame(
          fixture = fixture_name,
          indicator = spec$name,
          position = position,
          window_rule = width_rule,
          window_bars = width,
          full_value = full[[position]],
          scalar_value = scalar,
          prefix_value = prefix,
          scalar_abs_delta = abs(full[[position]] - scalar),
          scalar_scaled_delta = abs(full[[position]] - scalar) /
            max(1, abs(full[[position]])),
          prefix_abs_delta = abs(full[[position]] - prefix),
          prefix_scaled_delta = abs(full[[position]] - prefix) /
            max(1, abs(full[[position]])),
          prefix_identical = same_number(full[[position]], prefix),
          stringsAsFactors = FALSE
        )
      }))
    })
    rows <- do.call(rbind, rows)
    raw_samples[[length(raw_samples) + 1L]] <- rows
    stable_rows <- rows$window_rule == "stable_after"
    plus_one_rows <- rows$window_rule == "stable_after_plus_one"
    derived[[length(derived) + 1L]] <- data.frame(
      fixture = fixture_name,
      indicator = spec$name,
      history_class = spec$history_class,
      declared_stable_after = as.integer(ind$stable_after),
      raw_ttr_first_finite = raw_first_finite,
      engine_first_finite = engine_first_finite,
      prefix_all_identical = all(rows$prefix_identical),
      prefix_max_abs_delta = max(rows$prefix_abs_delta, na.rm = TRUE),
      prefix_max_scaled_delta = max(rows$prefix_scaled_delta, na.rm = TRUE),
      stable_window_max_abs_delta = max(rows$scalar_abs_delta[stable_rows], na.rm = TRUE),
      stable_window_max_scaled_delta = max(rows$scalar_scaled_delta[stable_rows], na.rm = TRUE),
      plus_one_window_max_abs_delta = max(rows$scalar_abs_delta[plus_one_rows], na.rm = TRUE),
      plus_one_window_max_scaled_delta = max(rows$scalar_scaled_delta[plus_one_rows], na.rm = TRUE),
      stringsAsFactors = FALSE
    )

    # A small-width witness prevents stable_after from being misreported as a
    # minimum dependency. ATR's range outputs are the motivating examples.
    if (identical(spec$family, "ATR") &&
        spec$output %in% c("tr", "trueHigh", "trueLow")) {
      width <- 2L
      witness_rows <- lapply(positions, function(position) {
        window <- bars[seq.int(position - width + 1L, position), , drop = FALSE]
        probe <- tryCatch(
          list(
            status = "ok",
            value = scalar_value(ind, window, full[[position]])
          ),
          error = function(cnd) list(
            status = class(cnd)[[1L]],
            value = NA_real_
          )
        )
        scalar <- probe$value
        data.frame(
          fixture = fixture_name,
          indicator = spec$name,
          tested_window_bars = width,
          position = position,
          full_value = full[[position]],
          scalar_value = scalar,
          probe_status = probe$status,
          abs_delta = abs(full[[position]] - scalar),
          scaled_delta = abs(full[[position]] - scalar) /
            max(1, abs(full[[position]])),
          stringsAsFactors = FALSE
        )
      })
      width_witness[[length(width_witness) + 1L]] <- do.call(rbind, witness_rows)
    }
  }
}
raw_samples <- do.call(rbind, raw_samples)
derived <- do.call(rbind, derived)
width_witness <- do.call(rbind, width_witness)

# Gap probes retain the expected-session rows and mark all bar fields missing.
# The segment arm is a candidate execution shape used only to expose the
# difference between finite-window recovery and recursive re-warm/convergence.
split_segments <- function(bars, gap_idx, indicator) {
  keep <- setdiff(seq_len(nrow(bars)), gap_idx)
  groups <- cumsum(c(TRUE, diff(keep) != 1L))
  out <- rep(NA_real_, nrow(bars))
  for (group in unique(groups)) {
    idx <- keep[groups == group]
    out[idx] <- engine(bars[idx, , drop = FALSE], indicator)
  }
  out
}
convergence_lag <- function(delta, finite_idx, gap_end, threshold) {
  if (!length(finite_idx)) return(NA_integer_)
  for (position in finite_idx) {
    tail_idx <- finite_idx[finite_idx >= position]
    if (length(tail_idx) && all(delta[tail_idx] <= threshold)) {
      return(as.integer(position - gap_end))
    }
  }
  NA_integer_
}

gap_samples <- list()
recovery <- list()
gap_bars_complete <- fixtures$smooth
gap_starts <- c(61L, 141L, 201L)
for (gap_start in gap_starts) for (gap_sessions in c(1L, 5L)) {
  gap_idx <- seq.int(gap_start, length.out = gap_sessions)
  gap_end <- max(gap_idx)
  aligned <- gap_bars_complete
  aligned[gap_idx, c("open", "high", "low", "close", "volume")] <- NA_real_
  for (spec in specs) {
    ind <- spec$indicator
    full <- engine(gap_bars_complete, ind)
    segment <- split_segments(gap_bars_complete, gap_idx, ind)
    finite <- which(seq_len(nrow(aligned)) > gap_end &
                      is.finite(full) & is.finite(segment))
    scaled_delta <- rep(NA_real_, nrow(aligned))
    scaled_delta[finite] <- abs(full[finite] - segment[finite]) /
      pmax(1, abs(full[finite]))
    first <- if (length(finite)) finite[[1L]] else NA_integer_
    sample_positions <- unique(c(
      first,
      first + c(1L, 5L, 20L, 60L),
      nrow(aligned)
    ))
    sample_positions <- sample_positions[
      !is.na(sample_positions) & sample_positions <= nrow(aligned)
    ]
    gap_samples[[length(gap_samples) + 1L]] <- data.frame(
      counterfactual = "segment restart omits gap; uninterrupted full series retains gap observations",
      gap_start = gap_start,
      gap_end = gap_end,
      gap_sessions = gap_sessions,
      indicator = spec$name,
      position = sample_positions,
      complete_value = full[sample_positions],
      restarted_value = segment[sample_positions],
      scaled_delta = scaled_delta[sample_positions],
      stringsAsFactors = FALSE
    )

    availability_status <- condition_label(
      ledgr:::ledgr_availability_validate_features(list(ind), "list")
    )
    strict_status <- if (identical(ind$gap_contract, "strict_window")) {
      condition_label(ledgr:::ledgr_compute_feature_series_strict(aligned, ind))
    } else {
      "not_admitted"
    }
    direct_status <- condition_label(engine(aligned, ind))
    recovery[[length(recovery) + 1L]] <- data.frame(
      counterfactual = "segment restart omits gap; uninterrupted full series retains gap observations",
      gap_start = gap_start,
      gap_end = gap_end,
      gap_sessions = gap_sessions,
      indicator = spec$name,
      history_class = spec$history_class,
      gap_contract = ind$gap_contract %or% "none",
      current_availability_status = availability_status,
      current_strict_series_status = strict_status,
      direct_aligned_series_status = direct_status,
      declared_first_valid_lag = as.integer(ind$stable_after),
      observed_first_valid_lag = if (is.na(first)) NA_integer_ else first - gap_end,
      scaled_delta_at_first_valid = if (is.na(first)) NA_real_ else scaled_delta[[first]],
      scaled_delta_at_end = scaled_delta[[length(scaled_delta)]],
      lag_until_1e_6 = convergence_lag(scaled_delta, finite, gap_end, 1e-6),
      lag_until_1e_9 = convergence_lag(scaled_delta, finite, gap_end, 1e-9),
      lag_until_1e_12 = convergence_lag(scaled_delta, finite, gap_end, 1e-12),
      lag_until_exact = convergence_lag(scaled_delta, finite, gap_end, 0),
      stringsAsFactors = FALSE
    )
  }
}
gap_samples <- do.call(rbind, gap_samples)
recovery <- do.call(rbind, recovery)

# Prerequisite/path plumbing: compare values seen by public runs with the same
# current engine over the exact stored bars. This catches integration drift;
# it is not an independent validation of the engine algorithm.
dense_bars <- fixtures$smooth[seq_len(120L), , drop = FALSE]
strategy <- function(ctx, params) {
  values <- vapply(params$ids, function(id) {
    sprintf("%.17g", ctx$feature("AAA", id))
  }, character(1))
  list(
    targets = ctx$flat(),
    state_update = list(
      seen = c(ctx$state_prev$seen, list(stats::setNames(as.list(values), params$ids)))
    )
  )
}
run_plumbing <- function(snapshot,
                         selected_specs,
                         run_id,
                         execution_path,
                         universe = NULL) {
  snapshot_id <- ledgr_snapshot_info(snapshot)$snapshot_id[[1L]]
  stored_bars <- DBI::dbGetQuery(
    ledgr:::get_connection(snapshot),
    paste0(
      "SELECT instrument_id, ts_utc, open, high, low, close, volume ",
      "FROM snapshot_bars WHERE snapshot_id = ? ORDER BY ts_utc, instrument_id"
    ),
    params = list(snapshot_id)
  )
  ids <- vapply(selected_specs, function(spec) spec$indicator$id, character(1))
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    features = lapply(selected_specs, `[[`, "indicator"),
    opening = ledgr_opening(cash = 1000),
    universe = universe,
    cost_model = ledgr_cost_zero()
  )
  run <- ledgr_run(experiment, params = list(ids = unname(ids)), run_id = run_id)
  state_json <- DBI::dbGetQuery(
    ledgr:::get_connection(snapshot),
    "SELECT state_json FROM strategy_state WHERE run_id = ? ORDER BY ts_utc DESC LIMIT 1",
    params = list(run$run_id)
  )$state_json[[1L]]
  close(run)
  seen <- ledgr:::ledgr_json_read_nested(state_json)$seen
  do.call(rbind, lapply(selected_specs, function(spec) {
    run_values <- vapply(seen, function(row) {
      suppressWarnings(as.numeric(row[[spec$indicator$id]]))
    }, numeric(1))
    engine_values <- engine(stored_bars, spec$indicator)
    same_na <- identical(is.na(run_values), is.na(engine_values))
    finite <- is.finite(run_values) & is.finite(engine_values)
    delta <- abs(run_values[finite] - engine_values[finite])
    scaled <- delta / pmax(1, abs(engine_values[finite]))
    data.frame(
      execution_path = execution_path,
      indicator = spec$name,
      pulses = length(run_values),
      na_pattern_equal = same_na,
      finite_values_identical = same_na &&
        identical(run_values[!is.na(run_values)], engine_values[!is.na(engine_values)]),
      finite_mismatch_count = if (same_na) {
        sum(run_values[finite] != engine_values[finite])
      } else {
        NA_integer_
      },
      max_abs_delta = if (length(delta)) max(delta) else 0,
      max_scaled_delta = if (length(scaled)) max(scaled) else 0,
      stringsAsFactors = FALSE
    )
  }))
}

dense_path <- tempfile("history-d-dense-path-", fileext = ".duckdb")
dense_snapshot <- ledgr_snapshot_from_df(dense_bars, db_path = dense_path)
path_plumbing <- run_plumbing(
  dense_snapshot,
  specs,
  "h2-d-dense-path",
  "dense"
)
ledgr_snapshot_close(dense_snapshot)
unlink(dense_path)

# A full-observation session calendar activates the availability path without
# adding a gap. Only the three outputs admitted by the current implementation
# are run here; this remains path-plumbing parity, not an independent oracle.
availability_bars <- dense_bars
availability_bars$ts_utc <- as.POSIXct(
  as.Date(availability_bars$ts_utc),
  tz = "UTC"
) + 16 * 3600
session_dates <- as.Date(availability_bars$ts_utc)
session_rows <- data.frame(
  session_date = session_dates,
  status = "open",
  session_open = as.POSIXct(session_dates, tz = "UTC") + 9 * 3600,
  session_close = availability_bars$ts_utc,
  source = "h2-d-fixture",
  stringsAsFactors = FALSE
)
sessions <- ledgr_facts_sessions(
  session_rows,
  venue_id = "H2D",
  knowledge = "assume_effective",
  timezone = "UTC"
)
membership <- ledgr_facts_membership_snapshots(
  data.frame(
    effective_from = min(availability_bars$ts_utc),
    instrument_id = "AAA",
    source = "h2-d-fixture",
    stringsAsFactors = FALSE
  ),
  universe_id = "H2D_FULL",
  complete = TRUE,
  knowledge = "assume_effective"
)
availability_path <- tempfile("history-d-availability-path-", fileext = ".duckdb")
availability_snapshot <- ledgr_snapshot_from_df(
  availability_bars,
  instruments_df = data.frame(instrument_id = "AAA"),
  facts = ledgr_facts(sessions, membership),
  price_basis = "split_adjusted",
  db_path = availability_path
)
admitted_names <- c("builtin_sma", "builtin_returns", "ttr_sma_value")
path_plumbing <- rbind(
  path_plumbing,
  run_plumbing(
    availability_snapshot,
    specs[admitted_names],
    "h2-d-availability-path",
    "availability_full_membership",
    universe = ledgr_universe_members("H2D_FULL")
  )
)
ledgr_snapshot_close(availability_snapshot)
unlink(availability_path)

package_baseline_commit <- "a4fdce08a3269c75da11792754560055f5d6de9b"
metadata <- data.frame(
  key = c(
    "package_baseline_commit", "ledgr_version", "R_version", "platform", "TTR_version",
    "pkgload_version", "DBI_version", "duckdb_version", "gut_mode",
    "complete_fixture_count", "gap_position_count", "indicator_output_count",
    "default_output_count", "algorithm_variant_output_count"
  ),
  value = c(
    package_baseline_commit, as.character(utils::packageVersion("ledgr")),
    R.version.string, R.version$platform,
    as.character(utils::packageVersion("TTR")),
    as.character(utils::packageVersion("pkgload")),
    as.character(utils::packageVersion("DBI")),
    as.character(utils::packageVersion("duckdb")),
    as.character(gut), as.character(length(fixtures)), as.character(length(gap_starts)),
    as.character(length(specs)),
    as.character(sum(inventory$census_role == "default_arguments")),
    as.character(sum(inventory$census_role == "algorithm_variant"))
  ),
  stringsAsFactors = FALSE
)

write_csv(metadata, "metadata.csv")
write_csv(inventory, "inventory.csv")
write_csv(raw_samples, "raw_samples.csv")
write_csv(derived, "conformance.csv")
write_csv(width_witness, "width_witness.csv")
write_csv(gap_samples, "gap_samples.csv")
write_csv(recovery, "gap_recovery.csv")
write_csv(path_plumbing, "path_plumbing.csv")

cat(sprintf(
  "H2_D_RUN_OK outputs=%d fixtures=%d prefix_failures=%d path_failures=%d gut=%s\n",
  nrow(inventory), length(fixtures), sum(!derived$prefix_all_identical),
  sum(
    path_plumbing$execution_path == "dense" &
      !path_plumbing$finite_values_identical
  ),
  gut
))
