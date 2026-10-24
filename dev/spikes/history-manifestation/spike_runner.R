# Bounded history-manifestation v2 spike. No product code is changed.

args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args)) args[[1L]] else file.path(
  "dev", "spikes", "history-manifestation", "evidence"
)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
pkgload::load_all(".", quiet = TRUE)

affinity <- system2(
  "powershell",
  c("-NoProfile", "-Command", shQuote(sprintf(
    "$p = Get-Process -Id %d; $p.ProcessorAffinity = 0xFFFF; [string]$p.ProcessorAffinity",
    Sys.getpid()
  ), type = "cmd")),
  stdout = TRUE,
  stderr = TRUE
)
power <- system2("powercfg", "/getactivescheme", stdout = TRUE, stderr = TRUE)
if (!identical(trimws(tail(affinity, 1L)), "65535") ||
    !any(grepl("High performance", power, fixed = TRUE))) {
  stop("The spike requires the registered High-performance/0xFFFF host setup.")
}

gut_hash <- identical(Sys.getenv("LEDGR_HISTORY_SPIKE_GUT"), "hash")
n_inst_total <- 1166L
n_time_total <- 1260L
calendar <- seq(as.Date("2018-01-01"), by = "day", length.out = 1800L)
days <- calendar[as.integer(format(calendar, "%u")) <= 5L][seq_len(n_time_total)]
pulses <- as.POSIXct(paste(days, "21:00:00"), tz = "UTC")
ids <- sprintf("I%04d", seq_len(n_inst_total))

instrument <- rep(seq_len(n_inst_total), each = n_time_total)
session <- rep(seq_len(n_time_total), times = n_inst_total)
close <- 50 + instrument / 100 + session / 1000
# Sparse single-session gaps after each instrument has an observed source.
keep <- session <= 5L | ((instrument * 131L + session * 17L) %% 997L != 0L)
bars <- data.frame(
  instrument_id = ids[instrument[keep]],
  ts_utc = pulses[session[keep]],
  open = close[keep],
  high = close[keep],
  low = close[keep],
  close = close[keep],
  volume = 1000,
  stringsAsFactors = FALSE
)
rm(instrument, session, close, keep)

all_days <- seq(min(days), max(days), by = "day")
is_open <- all_days %in% days
sessions <- ledgr_facts_sessions(
  data.frame(
    session_date = all_days,
    status = ifelse(is_open, "open", "closed"),
    session_open = ifelse(is_open, "14:30:00", NA),
    session_close = ifelse(is_open, "21:00:00", NA),
    stringsAsFactors = FALSE
  ),
  venue_id = "XNYS",
  knowledge = "assume_effective"
)
members <- data.frame(
  effective_from = pulses[[1L]] - 3600,
  knowledge_time = pulses[[1L]] - 3600,
  source = "history_manifestation_spike",
  stringsAsFactors = FALSE
)
members$members <- I(list(ids))
membership <- ledgr_facts_membership_snapshots(
  members, universe_id = "U", complete = TRUE
)

db_path <- tempfile(fileext = ".duckdb")
snapshot <- ledgr_snapshot_from_df(
  bars,
  data.frame(instrument_id = ids),
  db_path = db_path,
  snapshot_id = "history-manifestation-spike",
  facts = ledgr_facts(sessions, membership),
  price_basis = "split_adjusted"
)
experiment <- ledgr_experiment(
  snapshot,
  function(ctx, params) ctx$hold(),
  universe = ledgr_universe_members("U"),
  cost_model = ledgr_cost_zero()
)
ctx <- ledgr_pulse_snapshot(experiment, ts_utc = days[[n_time_total]])
on.exit(close(ctx), add = TRUE)

view <- ledgr:::ledgr_history_context_view(ctx)
substrate <- view$service$substrate
stored <- substrate$bars$close
native_stored <- t(stored) # diagnostic only; not a proposed duplicate plane
cutoff_col <- view$cutoff_col

shapes <- data.frame(
  case = c("j50_l252", "j500_l252", "j1166_l252", "j500_full"),
  instruments = c(50L, 500L, 1166L, 500L),
  lookback = c(252L, 252L, 252L, n_time_total),
  stringsAsFactors = FALSE
)

clock_us <- function(fn, times) {
  timing <- microbenchmark::microbenchmark(fn(), times = times, unit = "us")
  c(
    median_us = stats::median(timing$time) / 1000,
    p95_us = unname(stats::quantile(timing$time, 0.95)) / 1000
  )
}

allocated_bytes <- function(fn) {
  path <- tempfile(fileext = ".mem")
  on.exit(unlink(path), add = TRUE)
  utils::Rprofmem(path)
  value <- fn()
  utils::Rprofmem(NULL)
  lines <- readLines(path, warn = FALSE)
  bytes <- suppressWarnings(as.numeric(sub(" .*", "", lines)))
  list(bytes = sum(bytes, na.rm = TRUE), value = value)
}

compact_meta <- function(axis, selected_ids, finite_count, excluded_ids,
                         lookback) {
  list(
    source = list(kind = "bar", name = "close", id = "close"),
    snapshot_hash = substrate$snapshot_hash,
    substrate_version = substrate$substrate_version,
    policy_identity = substrate$policy_identity,
    cutoff_utc = substrate$axis[[cutoff_col]],
    requested_lookback = lookback,
    available_lookback = length(axis),
    axis = axis,
    instrument_ids = selected_ids,
    finite_observation_count = as.integer(finite_count),
    excluded_ids = excluded_ids
  )
}

prepare_case <- function(n_inst, lookback) {
  requested_ids <- ids[seq_len(n_inst)]
  rows <- unname(substrate$instrument_index[requested_ids])
  first <- max(1L, cutoff_col - lookback + 1L)
  columns <- seq.int(first, cutoff_col)
  evidence <- ledgr:::ledgr_history_bar_evidence(
    substrate, "close", rows, columns, cutoff_col
  )
  raw <- stored[rows, columns, drop = FALSE]
  treated <- evidence$value
  changed <- which(
    xor(is.na(raw), is.na(treated)) |
      (!is.na(raw) & !is.na(treated) & raw != treated)
  )
  list(
    ids = requested_ids,
    rows = rows,
    columns = columns,
    axis = substrate$axis[columns],
    time_names = ledgr:::ledgr_history_time_names(substrate$axis[columns]),
    treated = treated,
    # Simulates the answer supplied by a prepared cumulative or sparse
    # completeness index. representation_probe.R measures the query itself;
    # the spike deliberately does not choose the index's storage form.
    finite_count = as.integer(rowSums(is.finite(treated))),
    patch_index = changed,
    patch_value = treated[changed],
    lookback = lookback
  )
}

candidate_values <- function(case) {
  value <- stored[case$rows, case$columns, drop = FALSE]
  if (length(case$patch_index)) {
    value[case$patch_index] <- case$patch_value
  }
  value
}

candidate_matrix <- function(case) {
  value <- candidate_values(case)
  out <- t(value)
  finite_count <- case$finite_count
  keep <- finite_count >= length(case$columns)
  selected_ids <- case$ids[keep]
  if (!all(keep)) out <- out[, keep, drop = FALSE]
  dim(out) <- c(length(case$axis), length(selected_ids))
  dimnames(out) <- list(case$time_names, selected_ids)
  meta <- compact_meta(
    case$axis, selected_ids, finite_count[keep], case$ids[!keep], case$lookback
  )
  if (gut_hash) {
    meta$value_sha256 <- digest::digest(as.double(out), algo = "sha256")
  }
  structure(
    out,
    class = c("ledgr_history_matrix_candidate", "matrix", "array"),
    ledgr_history = meta,
    digest_calls = as.integer(gut_hash)
  )
}

candidate_frame <- function(case) {
  value <- candidate_values(case)
  finite_count <- case$finite_count
  keep <- finite_count >= length(case$columns)
  selected_ids <- case$ids[keep]
  if (!all(keep)) value <- value[keep, , drop = FALSE]
  # Stored history is instruments x sessions. `mrtl()` manifests those rows
  # directly as frame columns; transposing and then splitting repeats the
  # same movement and adds a temporary full matrix.
  columns <- if (length(selected_ids)) collapse::mrtl(value) else list()
  names(columns) <- selected_ids
  meta <- compact_meta(
    case$axis, selected_ids, finite_count[keep], case$ids[!keep], case$lookback
  )
  if (gut_hash) {
    meta$value_sha256 <- digest::digest(as.double(t(value)), algo = "sha256")
  }
  structure(
    c(list(ts_utc = case$axis), columns),
    names = c("ts_utc", selected_ids),
    row.names = .set_row_names(length(case$axis)),
    class = c("ledgr_history_candidate", "data.frame"),
    ledgr_history = meta,
    digest_calls = as.integer(gut_hash)
  )
}

current_matrix <- function(case) {
  ledgr_history_matrix(
    ctx,
    bar = "close",
    lookback = case$lookback,
    instruments = case$ids
  )
}

records <- list()
components <- list()
parity <- list()
for (i in seq_len(nrow(shapes))) {
  shape <- shapes[i, ]
  case <- prepare_case(shape$instruments, shape$lookback)
  invisible(current_matrix(case))
  invisible(candidate_matrix(case))
  invisible(candidate_frame(case))

  paths <- list(
    current = list(fn = function() current_matrix(case), times = 10L),
    matrix = list(fn = function() candidate_matrix(case), times = 100L),
    frame = list(fn = function() candidate_frame(case), times = 100L)
  )
  values <- lapply(paths, function(path) allocated_bytes(path$fn))
  for (path_name in names(paths)) {
    timing <- clock_us(paths[[path_name]]$fn, paths[[path_name]]$times)
    value <- values[[path_name]]$value
    records[[length(records) + 1L]] <- data.frame(
      case = shape$case,
      path = path_name,
      rows = shape$lookback,
      columns = shape$instruments,
      returned_cells = shape$lookback * shape$instruments,
      median_us = timing[["median_us"]],
      p95_us = timing[["p95_us"]],
      allocated_bytes = values[[path_name]]$bytes,
      retained_bytes = as.numeric(object.size(value)),
      digest_calls = as.integer(if (is.null(attr(value, "digest_calls", exact = TRUE))) {
        0L
      } else {
        attr(value, "digest_calls", exact = TRUE)
      }),
      patch_cells = length(case$patch_index),
      stringsAsFactors = FALSE
    )
  }

  current <- values$current$value
  matrix_value <- values$matrix$value
  frame_value <- values$frame$value
  frame_matrix <- as.matrix(frame_value[attr(matrix_value, "ledgr_history")$instrument_ids])
  parity[[length(parity) + 1L]] <- data.frame(
    case = shape$case,
    matrix_current_identical = identical(
      as.double(matrix_value), as.double(unclass(current))
    ),
    frame_matrix_identical = identical(
      as.double(matrix_value), as.double(frame_matrix)
    ),
    dimensions_identical = identical(dim(matrix_value), dim(current)),
    names_identical = identical(dimnames(matrix_value), dimnames(current)),
    selected_ids_identical = identical(
      attr(matrix_value, "ledgr_history")$instrument_ids,
      ledgr_history_info(current)$included_ids
    ),
    stringsAsFactors = FALSE
  )

  raw_window <- stored[case$rows, case$columns, drop = FALSE]
  native_rows <- case$columns
  component_fns <- list(
    current_orientation_slice = function() {
      stored[case$rows, case$columns, drop = FALSE]
    },
    transpose = function() t(raw_window),
    native_orientation_slice = function() {
      native_stored[native_rows, case$rows, drop = FALSE]
    },
    sparse_patch = function() candidate_values(case),
    complete_selection_base = function() {
      rowSums(is.finite(case$treated)) >= length(case$columns)
    },
    complete_selection_collapse = function() {
      collapse::fnobs(t(case$treated)) >= length(case$columns)
    },
    sha256_excluded = function() {
      digest::digest(as.double(t(case$treated)), algo = "sha256")
    }
  )
  for (component in names(component_fns)) {
    timing <- clock_us(component_fns[[component]], 100L)
    components[[length(components) + 1L]] <- data.frame(
      case = shape$case,
      component = component,
      rows = shape$lookback,
      columns = shape$instruments,
      median_us = timing[["median_us"]],
      p95_us = timing[["p95_us"]],
      stringsAsFactors = FALSE
    )
  }
}

record <- do.call(rbind, records)
component_record <- do.call(rbind, components)
parity_record <- do.call(rbind, parity)

# A fixed 500 x 252 request from the complete source and an otherwise equal
# short source demonstrates that the candidate touches the requested window,
# not every unrequested session. This is a diagnostic, not a second design.
scale_case <- prepare_case(500L, 252L)
short_stored <- stored[, scale_case$columns, drop = FALSE]
full_source <- function() stored[scale_case$rows, scale_case$columns, drop = FALSE]
short_source <- function() short_stored[scale_case$rows,
                                        seq_len(ncol(short_stored)), drop = FALSE]
full_clock <- clock_us(full_source, 200L)
short_clock <- clock_us(short_source, 200L)
source_scale <- data.frame(
  requested_rows = 252L,
  requested_columns = 500L,
  full_source_rows = ncol(stored),
  short_source_rows = ncol(short_stored),
  full_median_us = full_clock[["median_us"]],
  short_median_us = short_clock[["median_us"]],
  ratio = full_clock[["median_us"]] / short_clock[["median_us"]],
  stringsAsFactors = FALSE
)

product_commit <- Sys.getenv("LEDGR_PRODUCT_COMMIT")
if (!nzchar(product_commit)) {
  stop("Set LEDGR_PRODUCT_COMMIT to the product commit before running the spike.")
}
environment <- data.frame(
  product_commit = product_commit,
  r_version = R.version.string,
  platform = R.version$platform,
  collapse_version = as.character(utils::packageVersion("collapse")),
  microbenchmark_version = as.character(utils::packageVersion("microbenchmark")),
  gut_hash = gut_hash,
  snapshot_sessions = n_time_total,
  snapshot_instruments = n_inst_total,
  power_plan = "High performance",
  process_affinity = "0xFFFF",
  stringsAsFactors = FALSE
)

utils::write.csv(record, file.path(out_dir, "measurements.csv"), row.names = FALSE)
utils::write.csv(component_record, file.path(out_dir, "components.csv"), row.names = FALSE)
utils::write.csv(parity_record, file.path(out_dir, "parity.csv"), row.names = FALSE)
utils::write.csv(source_scale, file.path(out_dir, "source_scale.csv"), row.names = FALSE)
utils::write.csv(environment, file.path(out_dir, "environment.csv"), row.names = FALSE)

print(record)
print(component_record)
print(parity_record)
print(source_scale)
