# LDG-3216 parity runner: lean preparation (dev/lean_core/prepare.R) against
# the pinned captures of one workload, at one tile width, one orientation and
# one debug setting.
#
#   Rscript dev/lean_core/parity/prep_parity.R --lib=<pinned library>
#     --capture=<workload capture .rds> --width=<sessions|run> --orient=<time|inst>
#     --debug=<0|1> --out=<csv> [--private]
#
# Checks: hydration fetches the pin's rows; the substrate, gathered whole and
# without history_memo and feature_projection (Section 14), is identical;
# every captured bar packet is identical; the fold reader's pulse columns,
# packets per pulse and view cutoffs equal the pinned reader's. --private
# writes counts and pass flags only (no difference text).

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
# The registered mutations (LDG-3216 acceptance): one textual change to
# prepare.R each, evaluated over the loaded lean environment; each must fail.
mutations <- list(
  features_restarted_at_edge = c(
    "      inputs <- ledgr_history_feature_inputs(substrate, i, range_end, substrate$axis[[range_end]])",
    "      inputs <- ledgr_history_feature_inputs(substrate, i, range_end, substrate$axis[[range_end]]); inputs$treated <- lapply(inputs$treated, function(v) { v[seq_len(((range_end - 1L) %/% w) * w)] <- NA_real_; v })"),
  admission_from_current_membership = c(
    "    stored <- sort(unique(r))",
    "    drop <- !(r %in% r[c == max(c)]); keep[which(keep)[drop]] <- FALSE; r <- r[!drop]; c <- c[!drop]; stored <- sort(unique(r))"),
  cutoff_overlay_dropped = c(
    "lean_pinned_ns(\"ledgr_history_prepare_masks\")(substrate, knowledge, instrument_idx, block)",
    "lean_pinned_ns(\"ledgr_history_prepare_masks\")(substrate, as.POSIXct(Inf, tz = \"UTC\"), instrument_idx, block)"),
  retained_view_aliasing_recycled_tile = c(
    "    p$tiles[[as.character(old)]] <- NULL",
    "    p$tiles[[as.character(old)]] <- p$tiles[[as.character(k)]]; next"),
  finite_request_truncated_at_edge = c(
    "  for (at in split(seq_along(j), tile)) {",
    "  for (at in utils::tail(split(seq_along(j), tile), 1L)) {")
)
mutation <- arg("mutation", "none")
if (!identical(mutation, "none")) {
  mu <- mutations[[mutation]] %||% stop("unknown mutation ", mutation, call. = FALSE)
  src <- readLines(file.path(lean_core_home, "prepare.R"))
  hit <- which(startsWith(src, mu[[1L]]) | grepl(mu[[1L]], src, fixed = TRUE))
  if (length(hit) != 1L) stop("mutation ", mutation, " matches ", length(hit), " lines", call. = FALSE)
  src[hit] <- sub(mu[[1L]], mu[[2L]], src[hit], fixed = TRUE)
  eval(parse(text = src, keep.source = FALSE), envir = lean)
}
width <- arg("width", "run")
lean$lean_prep$width <- if (identical(width, "run")) NULL else as.integer(width)
lean$lean_prep$orient <- arg("orient", "time")
private <- "--private" %in% commandArgs(TRUE)
# Lean copies first, then the pinned namespace (the lean environment's parent).
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
t0 <- proc.time()[["elapsed"]]

# Hydration and substrate (one each per run).
h <- input(recs$hydrate[[1L]])
s <- input(recs$substrate[[1L]])
bars <- lean$lean_hydrate(h$snapshot, h$universe, h$start, h$end, s$instrument_ids, s$axis)
note("hydrate_rows", 1L, list(if (bars$fetched != nrow(output(recs$hydrate[[1L]]))) {
  sprintf("fetched %d rows, pin %d", bars$fetched, nrow(output(recs$hydrate[[1L]])))
}))
sub <- do.call(fn("ledgr_history_substrate"), c(list(bars = bars), s[setdiff(names(s), "bars")]))
strip <- function(x) x[setdiff(names(x), c("history_memo", "feature_projection"))]
note("substrate", 1L, list(cmp(strip(lean$lean_substrate_full(sub)), strip(output(recs$substrate[[1L]])))))

# Packets: every captured call, on the lean substrate.
note("packet", length(recs$packet), lapply(recs$packet, function(i) {
  a <- input(i)
  cmp(fn("ledgr_history_substrate_bar_packet")(sub, a$pulse_idx), output(i))
}))

# Features: the series gathered whole with its evidence attribute, then the
# projection built as the runner builds it, against the projection the
# pinned reader received.
projection <- NULL
for (i in recs$features) {
  a <- input(i)
  series <- fn("ledgr_history_compute_feature_series")(sub, a$definitions, a$calculation_start, a$calculation_end)
  full <- lapply(series, lean$lean_plane_full)
  attr(full, "ledgr_feature_planes") <- attr(series, "ledgr_feature_planes")
  note("features", 1L, list(cmp(full, output(i))))
}
for (i in recs$reader) {
  pin_projection <- input(i)$substrate$feature_projection
  projection <- fn("ledgr_projection_from_feature_matrix")(
    if (length(recs$features)) series else list(), s$instrument_ids, s$axis,
    pin_projection$feature_engine_version, NULL)
  note("projection", 1L, list(cmp(lean$lean_projection_full(projection), pin_projection)))
}

# Fold reader: pulse columns, then each pulse's packets and view cutoff
# against the pinned reader rebuilt from the same captured input.
retained_packet <- NULL
for (i in recs$reader) {
  a <- input(i)
  bound <- fn("ledgr_history_substrate_bind_features")(sub, projection)
  lean_reader <- fn("ledgr_history_substrate_fold_reader")(bound, a$pulses_posix, a$feature_defs, a$active_alias_map)
  pin_reader <- output(i)
  pulses <- seq_along(pin_reader$pulse_columns)
  # The first pulse's public columns are kept and re-checked after every
  # later packet and history read has recycled the working tiles.
  if (length(pulses) && is.null(retained_packet)) {
    first <- lean_reader$bars(1L)
    retained_packet <- list(reader = lean_reader, pin = pin_reader$bars(1L), value = first, bytes = serialize(first, NULL))
  }
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
  retained <- list()
  diffs <- list(history_read = list(), history_frame = list(), history_matrix = list())
  for (i in sort(unlist(recs[c("history_read", "history_frame", "history_matrix")]))) {
    b <- cap$records[[i]]$boundary
    a <- input(i)
    got <- tryCatch({
      if (b == "history_read") {
        a$view <- fn("ledgr_history_view")(service_for(a$view$service), a$view$cutoff_col)
        plan <- do.call(fn("ledgr_history_read_plan"), a)
        # The first pulse's reads are kept and re-read after every later
        # read has recycled the working tiles.
        if (length(retained) < 8L) {
          retained[[length(retained) + 1L]] <- list(args = a, plan = plan, bytes = serialize(plan, NULL))
        }
        plan
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
  memo <- lean_sub$history_memo
  working <- Filter(function(p) inherits(p, "lean_plane"), unlist(lapply(as.list(memo), function(x) {
    if (inherits(x, "lean_plane")) list(x) else if (is.list(x)) Filter(function(y) inherits(y, "lean_plane"), x)
  }), recursive = FALSE))
  builds <- sum(vapply(working, function(p) p$builds, 0L))
  tiles <- sum(vapply(working, function(p) p$nt, 0L))
  note("retained", length(retained), lapply(retained, function(r) {
    if (!identical(serialize(r$plan, NULL), r$bytes)) return("retained result changed after recycling")
    again <- tryCatch(do.call(fn("ledgr_history_read_plan"), r$args), error = function(e) conditionMessage(e))
    cmp(again, r$plan)
  }))
  note("recycling_exercised", 1L, list(if (builds <= tiles) {
    sprintf("%d working planes built %d tiles for %d slots: no tile was rebuilt", length(working), builds, tiles)
  }))
}
if (!is.null(retained_packet)) {
  note("retained_packet", 1L, list(
    if (!identical(serialize(retained_packet$value, NULL), retained_packet$bytes)) {
      "retained packet changed after recycling"
    } else {
      cmp(retained_packet$reader$bars(1L), retained_packet$pin)
    }))
}

res <- do.call(rbind, rows)
res <- cbind(workload = sub("\\.rds$", "", basename(arg("capture"))), width = width, orient = lean$lean_prep$orient,
             debug = arg("debug", "0"), res, seconds = round(proc.time()[["elapsed"]] - t0, 1))
utils::write.csv(res, arg("out"), row.names = FALSE)
print(res[, c("check", "n", "pass", "first_difference")], right = FALSE)
if (any(res$pass < res$n)) quit(save = "no", status = 1L)
