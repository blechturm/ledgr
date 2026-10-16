#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
spike_dir <- dirname(script_path)
package_root <- normalizePath(file.path(spike_dir, "../../.."), winslash = "/")
source(
  file.path(dirname(spike_dir), "history_mirai_payload_attribution", "common.R"),
  local = globalenv()
)
.libPaths(e0_lib_paths())
e0_load_ledgr(package_root)
if (!requireNamespace("mori", quietly = TRUE)) stop("mori is required.")

out_dir <- file.path(spike_dir, "evidence", "probe")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
fixture_scratch <- tempfile("history-e1-probe-")
fixture <- e0_fixture(e0_spec("smoke"), fixture_scratch)
on.exit({
  try(ledgr_snapshot_close(fixture$snapshot), silent = TRUE)
  db_path <- fixture$db_path
  fixture$snapshot <- NULL
  invisible(gc())
  unlink(db_path, force = TRUE)
  unlink(fixture_scratch, recursive = TRUE, force = TRUE)
}, add = TRUE)

captured <- new.env(parent = emptyenv())
ns <- asNamespace("ledgr")
name <- "ledgr_sweep_candidate_tasks"
original <- get(name, envir = ns, inherits = FALSE)
unlockBinding(name, ns)
assign(name, function(...) {
  value <- original(...)
  captured$tasks <- value
  value
}, envir = ns)
lockBinding(name, ns)
on.exit({
  unlockBinding(name, ns)
  assign(name, original, envir = ns)
  lockBinding(name, ns)
}, add = TRUE)

result <- ledgr_sweep(fixture$experiment, fixture$grid, seed = 1601L, workers = 1L)
stopifnot(all(result$status == "DONE"))
tasks <- captured$tasks
split <- e0_task_split(tasks)
candidate_fields <- intersect(
  names(split$shared),
  c(
    "bars_by_id", "bars_mat", "static_bars_views", "pulses_posix",
    "execution_opportunities_posix", "runtime_projection",
    "availability_data", "corporate_action_rows"
  )
)

rows <- lapply(candidate_fields, function(field) {
  value <- split$shared[[field]]
  shared <- mori::share(value)
  mapped <- mori::map_shared(mori::shared_name(shared))
  data.frame(
    field = field,
    regular_serialized_bytes = e0_serialized_bytes(value),
    shared_serialized_bytes = e0_serialized_bytes(shared),
    root_is_shared = mori::is_shared(shared),
    mapped_is_shared = mori::is_shared(mapped),
    value_identical = identical(value, mapped),
    shared_name_nonempty = nzchar(mori::shared_name(shared) %||% ""),
    stringsAsFactors = FALSE
  )
})
rows <- do.call(rbind, rows)
e0_write_csv(rows, file.path(out_dir, "probe.csv"))

# Copy-on-write witness on one large numeric leaf. The mapped source must not
# change when the local object is mutated.
shared_close <- mori::share(split$shared$bars_mat$close)
mapped_close <- mori::map_shared(mori::shared_name(shared_close))
before <- mapped_close[[1L]]
local <- mapped_close
local[[1L]] <- before + 1
cow <- data.frame(
  source_unchanged = identical(mapped_close[[1L]], before),
  local_changed = identical(local[[1L]], before + 1),
  local_still_shared = mori::is_shared(local),
  stringsAsFactors = FALSE
)
e0_write_csv(cow, file.path(out_dir, "copy_on_write.csv"))

# A single-reference shared root list cannot accept the ordinary outer-list
# replacement used by ledgr's evaluator. With an additional reference R may
# duplicate to an ordinary list first, so this witness deliberately keeps one.
root <- mori::share(list(x = 1:3))
root_shared_before <- mori::is_shared(root)
root_error <- tryCatch({
  root[["x"]] <- 4:6
  ""
}, error = function(e) conditionMessage(e))
root_update <- data.frame(
  scenario = "single_reference_root_update",
  root_shared_before = root_shared_before,
  assignment_succeeded = !nzchar(root_error),
  error_contains_set_elt = grepl("Set_elt", root_error, fixed = TRUE),
  error_message = root_error,
  stringsAsFactors = FALSE
)
e0_write_csv(root_update, file.path(out_dir, "root_list_update.csv"))
stopifnot(
  root_update$root_shared_before,
  !root_update$assignment_succeeded,
  root_update$error_contains_set_elt
)

cat(sprintf(
  "HISTORY_E1_PROBE_OK fields=%d compact=%d exact=%d root_set_elt=1\n",
  nrow(rows), sum(rows$shared_serialized_bytes < rows$regular_serialized_bytes),
  sum(rows$value_identical)
))
