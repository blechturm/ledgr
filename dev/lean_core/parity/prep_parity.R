# LDG-3216 parity runner: lean preparation (dev/lean_core/prepare.R) against
# the pinned captures of one workload, at one hydration chunk width and one
# debug setting.
#
#   Rscript dev/lean_core/parity/prep_parity.R --lib=<pinned library>
#     --capture=<workload capture .rds> --chunk=<sessions|run> --debug=<0|1>
#     --out=<csv> [--mutation=<name>] [--private]
#
# Checks: lean builds the pin's axis; hydration fetches the pin's rows; the
# substrate (without
# history_memo and feature_projection, Section 14) is identical; duplicate
# bars inside a chunk refuse as the pin's long frame does; every captured bar
# packet, feature series, projection, fold-reader column, packet and view
# cutoff, and every history read, frame and matrix equals the pin's.
# --private writes counts and pass flags only (no difference text).

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "(=|$)"), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) return(default %||% stop("--", name, "= is required", call. = FALSE))
  sub(paste0("^--", name, "=?"), "", hit[[1L]])
}
source(file.path(here, "..", "load.R"))
lean <- lean_core_load(arg("lib"), debug = identical(arg("debug", "0"), "1"))
lean_core_source(lean, c(file.path(lean_core_home, "..", "bench", "v0_2_3_ws16_entry", "common.R"),
                         file.path(lean_core_home, "recorder", c("fields.R", "capture.R", "compare.R", "replay.R"))))
# The registered hydration mutations (LDG-3216 acceptance, whole-planes W5):
# one textual change to prepare.R each, evaluated over the loaded lean
# environment; each must fail.
mutations <- list(
  chunk_edge_bar_dropped = c(
    "    keep <- !is.na(c)",
    "    keep <- !is.na(c) & !(c == 1L & c0 > 1L)"),
  chunk_edge_bar_fetched_twice = c(
    "    to <- if (c1 == t) end else axis[[c1 + 1L]] - 1",
    "    to <- if (c1 == t) end else axis[[c1 + 1L]]"),
  duplicate_within_chunk_not_refused = c(
    "    if (anyDuplicated(lin)) duplicate <- TRUE",
    "    if (FALSE) duplicate <- TRUE"),
  # Bar-native captures only: on declared sessions the axis is the pinned calendar.
  axis_last_session_dropped = c(
    "  as.POSIXct(rows$ts_utc, tz = \"UTC\")",
    "  utils::head(as.POSIXct(rows$ts_utc, tz = \"UTC\"), -1L)")
)
mutation <- arg("mutation", "none")
if (!identical(mutation, "none")) {
  mu <- mutations[[mutation]] %||% stop("unknown mutation ", mutation, call. = FALSE)
  src <- readLines(file.path(lean_core_home, "prepare.R"))
  hit <- which(src == mu[[1L]])
  if (length(hit) != 1L) stop("mutation ", mutation, " matches ", length(hit), " lines", call. = FALSE)
  src[hit] <- mu[[2L]]
  eval(parse(text = src, keep.source = FALSE), envir = lean)
}
chunk <- arg("chunk", "run")
lean$lean_prep$chunk <- if (identical(chunk, "run")) NULL else as.integer(chunk)
private <- "--private" %in% commandArgs(TRUE)
# Lean definitions first, then the pinned namespace (the lean environment's parent).
fn <- function(name) get(name, envir = lean, mode = "function")

cap <- lean$lc_read_capture(arg("capture"))
recs <- split(seq_along(cap$records), vapply(cap$records, `[[`, "", "boundary"))
input <- function(i) lean$lc_part(lean$lc_thaw(cap$records[[i]]$input, cap$store), "arg:")
output <- function(i) lean$lc_thaw(cap$records[[i]]$output, cap$store)$value
cmp <- function(x, y) lean$lc_compare(x, y, character())
rows <- list()
note <- function(check, n, diffs) {
  bad <- Filter(Negate(is.null), diffs)
  rows[[length(rows) + 1L]] <<- data.frame(check = check, n = n, pass = n - length(bad),
                                           first_difference = if (length(bad) && !private) bad[[1L]] else "")
}
refusal <- function(expr) tryCatch({ expr; "no refusal" }, error = function(e) list(class = class(e), message = conditionMessage(e)))
t0 <- proc.time()[["elapsed"]]
finish <- function() {
  res <- do.call(rbind, rows)
  res <- cbind(workload = sub("\\.rds$", "", basename(arg("capture"))), chunk = chunk,
               debug = arg("debug", "0"), mutation = mutation, res, seconds = round(proc.time()[["elapsed"]] - t0, 1))
  utils::write.csv(res, arg("out"), row.names = FALSE)
  print(res[, c("check", "n", "pass", "first_difference")], right = FALSE)
  quit(save = "no", status = if (any(res$pass < res$n)) 1L else 0L)
}

# Hydration and substrate (one each per run).
h <- input(recs$hydrate[[1L]])
s <- input(recs$substrate[[1L]])
pin_frame <- output(recs$hydrate[[1L]])
# Lean builds its own axis (bar-native: distinct bar times through the handle;
# declared sessions: the captured pinned calendar); the substrate below is
# built on that axis, so a wrong axis fails here and downstream.
prepare <- function() fn("lean_prepare_bars")(h$snapshot, h$universe, h$start, h$end, s$clock_kind, function() s$axis)
prepared <- prepare()
bars <- prepared$bars
note("axis", 1L, list(cmp(prepared$axis, s$axis)))
# Every later check is built on the axis; a differing axis is recorded and ends the run.
if (rows[[1L]]$pass < 1L) finish()
note("hydrate_rows", 1L, list(if (bars$fetched != nrow(pin_frame)) {
  sprintf("fetched %d rows, pin %d", bars$fetched, nrow(pin_frame))
}))
s_lean <- s
s_lean$axis <- prepared$axis
build <- function(b) do.call(fn("ledgr_history_substrate"), c(list(bars = b), s_lean[setdiff(names(s_lean), "bars")]))
sub <- build(bars)
strip <- function(x) x[setdiff(names(x), c("history_memo", "feature_projection"))]
note("substrate", 1L, list(cmp(strip(sub), strip(output(recs$substrate[[1L]])))))

# Duplicate bars: every chunk's rows fetched twice must refuse with the
# pin's class and message, as the pin's constructor refuses its long frame
# with every row twice.
local({
  fetch <- get("ledgr_precompute_fetch_bars_frame", envir = asNamespace("ledgr"))
  assign("ledgr_precompute_fetch_bars_frame", function(...) { x <- fetch(...); rbind(x, x) }, envir = lean)
  on.exit(rm("ledgr_precompute_fetch_bars_frame", envir = lean))
  got <- refusal(build(prepare()$bars))
  pin <- refusal(do.call(get("ledgr_history_substrate", envir = asNamespace("ledgr")),
                         c(list(bars = rbind(pin_frame, pin_frame)), s[setdiff(names(s), "bars")])))
  note("duplicate_refused", 1L, list(
    if (identical(pin, "no refusal")) "pin did not refuse duplicate bars" else cmp(got, pin)))
})

# Packets: every captured call, on the lean substrate.
note("packet", length(recs$packet), lapply(recs$packet, function(i) {
  a <- input(i)
  cmp(fn("ledgr_history_substrate_bar_packet")(sub, a$pulse_idx), output(i))
}))

# Features, then the projection built as the runner builds it, against the
# projection the pinned reader received.
series <- list()
for (i in recs$features) {
  a <- input(i)
  series <- fn("ledgr_history_compute_feature_series")(sub, a$definitions, a$calculation_start, a$calculation_end)
  note("features", 1L, list(cmp(series, output(i))))
}
projection <- NULL
for (i in recs$reader) {
  pin_projection <- input(i)$substrate$feature_projection
  projection <- fn("ledgr_projection_from_feature_matrix")(
    series, s$instrument_ids, s$axis, pin_projection$feature_engine_version, NULL)
  note("projection", 1L, list(cmp(projection, pin_projection)))
}

# Fold reader: pulse columns, then each pulse's packets and view cutoff
# against the pinned reader rebuilt from the same captured input.
for (i in recs$reader) {
  a <- input(i)
  bound <- fn("ledgr_history_substrate_bind_features")(sub, projection)
  lean_reader <- fn("ledgr_history_substrate_fold_reader")(bound, a$pulses_posix, a$feature_defs, a$active_alias_map)
  pin_reader <- output(i)
  pulses <- seq_along(pin_reader$pulse_columns)
  note("reader_columns", 1L, list(cmp(lean_reader$pulse_columns, pin_reader$pulse_columns)))
  note("reader_packets", length(pulses), lapply(pulses, function(p) cmp(lean_reader$bars(p), pin_reader$bars(p))))
  note("reader_views", length(pulses), lapply(pulses, function(p) {
    cmp(lean_reader$view(p)$cutoff_col, pin_reader$view(p)$cutoff_col)
  }))
}

# History reads, in capture order: each read plan on a view of the lean
# substrate with the captured service's features and names; each frame or
# matrix from the lean plan of the read before it.
if (length(recs$history_read)) {
  lean_sub <- fn("ledgr_history_substrate_bind_features")(sub, projection)
  services <- list()
  service_for <- function(pin) {
    key <- digest::digest(list(names(pin$feature_defs), pin$feature_names))
    if (is.null(services[[key]])) {
      e <- new.env(parent = emptyenv())
      e$substrate <- lean_sub
      e$feature_defs <- pin$feature_defs
      e$feature_names <- pin$feature_names
      class(e) <- "ledgr_history_read_service"
      lockEnvironment(e, bindings = TRUE)
      services[[key]] <<- e
    }
    services[[key]]
  }
  plan <- NULL
  diffs <- list(history_read = list(), history_frame = list(), history_matrix = list())
  for (i in sort(unlist(recs[c("history_read", "history_frame", "history_matrix")]))) {
    b <- cap$records[[i]]$boundary
    a <- input(i)
    got <- tryCatch({
      if (b == "history_read") {
        a$view <- fn("ledgr_history_view")(service_for(a$view$service), a$view$cutoff_col)
        plan <- do.call(fn("ledgr_history_read_plan"), a)
      } else if (b == "history_frame") {
        fn("ledgr_history_plan_frame")(plan, a$layout)
      } else {
        fn("ledgr_history_matrix_from_plan")(plan)
      }
    }, error = function(e) structure(list(conditionMessage(e)), class = "lean_error"))
    want <- tryCatch(output(i), error = function(e) NULL)
    diffs[[b]][length(diffs[[b]]) + 1L] <- list(if (inherits(got, "lean_error")) {
      paste("lean refused:", got[[1L]])
    } else {
      cmp(got, want)
    })
  }
  for (b in names(diffs)) note(b, length(diffs[[b]]), diffs[[b]])
}

finish()
