# Evidence checker for the v0.2.0.1 hot-path complexity audit.

options(warn = 2)

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script <- if (length(script_arg)) sub("^--file=", "", script_arg[[1L]]) else {
  "dev/spikes/v0_2_0_1_hot_path_complexity_audit/checker.R"
}
root <- dirname(normalizePath(script, winslash = "/", mustWork = TRUE))

read_evidence <- function(name) {
  path <- file.path(root, name)
  if (!file.exists(path)) stop("Missing evidence file: ", name, call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

checks <- character()
check <- function(ok, label) {
  if (!isTRUE(ok)) stop("CHECK FAILED: ", label, call. = FALSE)
  checks <<- c(checks, label)
}

env <- read_evidence("environment.csv")
events <- read_evidence("eventful_scaling.csv")
profiles <- read_evidence("eventful_profile_top.csv")
valuation <- read_evidence("valuation_scaling.csv")
lots <- read_evidence("lot_scaling.csv")
availability <- read_evidence("availability_record_extract.csv")
inventory <- read_evidence("complexity_inventory.csv")

check(nrow(env) == 1L && nzchar(env$source_commit[[1L]]), "environment provenance")
check(
  identical(events$instruments[events$engine_kind == "memory"], c(50L, 100L, 200L, 350L)),
  "memory instrument grid"
)
check(
  identical(events$instruments[events$engine_kind == "durable"], c(50L, 100L, 200L)),
  "durable instrument grid"
)

shared <- merge(
  events[events$engine_kind == "memory", c("instruments", "fills", "final_equity")],
  events[events$engine_kind == "durable", c("instruments", "fills", "final_equity")],
  by = "instruments",
  suffixes = c("_memory", "_durable")
)
check(all(shared$fills_memory == shared$fills_durable), "shared fill-count parity")
relative_equity <- abs(shared$final_equity_memory - shared$final_equity_durable) /
  pmax(1, abs(shared$final_equity_memory))
check(all(relative_equity < 1e-12), "shared final-equity parity")

memory <- events[events$engine_kind == "memory", ]
check(
  utils::tail(memory$microseconds_per_fill, 1L) > 1.8 * min(memory$microseconds_per_fill),
  "memory per-fill cliff"
)
check(
  any(profiles$engine_kind == "memory" & profiles$function_name == '"set_event_value"' &
      profiles$self_percent >= 20),
  "memory writer materiality"
)
check(
  any(profiles$engine_kind == "durable" & profiles$function_name == '"set_pending_value"' &
      profiles$self_percent >= 20),
  "durable writer materiality"
)

expected_scans <- with(
  valuation,
  as.double(instruments) * as.double(pulses) * as.double(pulses + 1L) / 2
)
check(all(valuation$cells_scanned == expected_scans), "valuation exact prefix work")
check(all(valuation$output_cells == valuation$instruments * valuation$pulses), "valuation output cells")
check(
  nrow(availability) == 1L && availability$event_count[[1L]] == 0L &&
    availability$valuation_profile_share[[1L]] >= 0.2,
  "registered zero-fill valuation materiality"
)

check(all(lots$final_lot_count == lots$lots), "lot stress shape")
check(
  utils::tail(lots$microseconds_per_added_lot, 1L) >
    4 * lots$microseconds_per_added_lot[[1L]],
  "open-lot nonlinear stress"
)
check(
  all(c("include in v0.2.0.1 amendment", "later roadmap; not exercised by release records") %in%
      inventory$classification),
  "inventory release classifications"
)

cat(sprintf("COMPLEXITY_AUDIT_CHECKS_OK: %d checks\n", length(checks)))
