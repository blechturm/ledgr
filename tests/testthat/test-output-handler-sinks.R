# ledgr-test-file-profile: review

# Native-surface witnesses for the one output handler (v0.2.3 cut 1,
# LDG-3131). The memory sink's native output (typed event columns, retained
# diagnostics and their numbering, completion) is observed in-process and,
# through ledgr's own parallel sweep path, inside mirai worker processes.

ledgr_sink_witness_experiment <- function(snapshot) {
  ledgr_experiment(
    snapshot,
    function(ctx, params) {
      target <- ctx$hold()
      target[["AAA"]] <- params$qty
      target
    },
    valuation_policy = ledgr_valuation_stale(0, exhausted = "refuse"),
    cost_model = ledgr_cost_fixed_fee(0.25)
  )
}

ledgr_sink_witness_grid <- function() {
  ledgr_grid_named(one = list(strategy = list(qty = 1)), two = list(strategy = list(qty = 2)))
}

# An observer for the one output handler: every handler built on a memory sink
# saves its native surfaces when the sweep asks for its inline summary. With
# `corrupt = TRUE` it first alters the first buffered event ID, a change no
# public sweep column carries. The expression is evaluated both in the test
# process and inside each worker after ledgr is loaded there.
ledgr_sink_witness_observer_expr <- function(dir, corrupt = FALSE) {
  substitute(
    {
      .witness_ns <- asNamespace("ledgr")
      .witness_original <- get("ledgr_output_handler", envir = .witness_ns)
      .witness_observer <- function(sink, ...) {
        handler <- .witness_original(sink, ...)
        if (!inherits(sink, "ledgr_output_sink_memory")) {
          return(handler)
        }
        summarize <- handler$inline_summary
        handler$inline_summary <- function(...) {
          if (isTRUE(CORRUPT)) {
            buffer <- get("state", envir = environment(handler$events))$event_cols
            buffer$event_id[[1L]] <- "corrupted-in-worker"
          }
          saveRDS(
            list(
              pid = Sys.getpid(),
              events = handler$typed_events(),
              diagnostics = handler$diagnostics(),
              completion = handler$completion()
            ),
            file.path(DIR, paste0(sink$run_id, ".rds"))
          )
          summarize(...)
        }
        handler
      }
      unlockBinding("ledgr_output_handler", .witness_ns)
      assign("ledgr_output_handler", .witness_observer, envir = .witness_ns)
      lockBinding("ledgr_output_handler", .witness_ns)
      TRUE
    },
    list(DIR = dir, CORRUPT = corrupt)
  )
}

ledgr_sink_witness_restore <- function(original) {
  ns <- asNamespace("ledgr")
  unlockBinding("ledgr_output_handler", ns)
  assign("ledgr_output_handler", original, envir = ns)
  lockBinding("ledgr_output_handler", ns)
}

ledgr_sink_witness_parallel <- function(exp, dir, corrupt = FALSE) {
  original_load <- ledgr:::ledgr_parallel_ledgr_load_expr
  observer <- ledgr_sink_witness_observer_expr(dir, corrupt)
  testthat::with_mocked_bindings(
    ledgr_sweep(exp, ledgr_sink_witness_grid(), seed = 31L, workers = 2L),
    ledgr_parallel_ledgr_load_expr = function(source_path) {
      load <- original_load(source_path)
      bquote({
        .(load)
        .(observer)
      })
    },
    .package = "ledgr"
  )
}

ledgr_sink_witness_read <- function(dir) {
  files <- sort(list.files(dir, pattern = "[.]rds$", full.names = TRUE))
  stats::setNames(lapply(files, readRDS), sub("[.]rds$", "", basename(files)))
}

testthat::test_that("[LTB-0519] a worker-executed memory sink delivers the in-process native surfaces", {
  testthat::skip_on_covr()
  testthat::skip_if_not_installed("mirai")
  ledgr_test_skip_workers_in_coverage()
  snapshot <- availability_runtime_fixture(days = 4L, bar_days = c(1L, 2L, 4L))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_sink_witness_experiment(snapshot)

  local_dir <- tempfile("sink-local-")
  worker_dir <- tempfile("sink-worker-")
  corrupt_dir <- tempfile("sink-corrupt-")
  dir.create(local_dir)
  dir.create(worker_dir)
  dir.create(corrupt_dir)
  on.exit(unlink(c(local_dir, worker_dir, corrupt_dir), recursive = TRUE), add = TRUE)

  original <- ledgr:::ledgr_output_handler
  eval(ledgr_sink_witness_observer_expr(local_dir), envir = new.env())
  sequential <- tryCatch(
    ledgr_sweep(exp, ledgr_sink_witness_grid(), seed = 31L),
    finally = ledgr_sink_witness_restore(original)
  )
  parallel <- ledgr_sink_witness_parallel(exp, worker_dir)
  corrupted <- ledgr_sink_witness_parallel(exp, corrupt_dir, corrupt = TRUE)

  local <- ledgr_sink_witness_read(local_dir)
  worker <- ledgr_sink_witness_read(worker_dir)
  bad <- ledgr_sink_witness_read(corrupt_dir)
  testthat::expect_identical(names(local), c("one", "two"))
  testthat::expect_identical(names(worker), names(local))
  testthat::expect_identical(names(bad), names(local))

  # The worker surfaces come from other processes.
  testthat::expect_true(all(vapply(local, `[[`, integer(1), "pid") == Sys.getpid()))
  testthat::expect_true(all(vapply(worker, `[[`, integer(1), "pid") != Sys.getpid()))

  # The declared inputs exercise nonzero fills, retained diagnostics with
  # their numbering, and completion evidence.
  testthat::expect_identical(sequential$status, c("INCOMPLETE", "INCOMPLETE"))
  for (id in names(local)) {
    events <- local[[id]]$events
    testthat::expect_s3_class(events, "ledgr_memory_events")
    testthat::expect_gt(sum(events$event_type == "FILL"), 0L)
    testthat::expect_false(is.null(local[[id]]$diagnostics))
    testthat::expect_gt(nrow(local[[id]]$diagnostics), 0L)
    testthat::expect_false(is.null(local[[id]]$completion))
  }

  # Witness: native event columns, typed attributes, retained diagnostics and
  # numbering, and completion are identical in the worker.
  for (id in names(local)) {
    testthat::expect_identical(worker[[id]]$events, local[[id]]$events, info = id)
    for (attribute in c(
      "ledgr_event_cash_delta", "ledgr_event_position_delta", "ledgr_event_realized",
      "ledgr_event_cost_basis", "ledgr_event_meta"
    )) {
      testthat::expect_identical(
        attr(worker[[id]]$events, attribute),
        attr(local[[id]]$events, attribute),
        info = paste(id, attribute)
      )
    }
    testthat::expect_identical(worker[[id]]$diagnostics, local[[id]]$diagnostics, info = id)
    testthat::expect_identical(
      worker[[id]]$diagnostics$diagnostic_seq,
      local[[id]]$diagnostics$diagnostic_seq,
      info = id
    )
    testthat::expect_identical(worker[[id]]$completion, local[[id]]$completion, info = id)
  }
  testthat::expect_identical(parallel$status, sequential$status)
  testthat::expect_identical(parallel$completion_json, sequential$completion_json)

  # Negative control: a daemon-native event ID change leaves every public
  # status and completion identical but fails the native witness.
  testthat::expect_identical(corrupted$status, sequential$status)
  testthat::expect_identical(corrupted$completion_json, sequential$completion_json)
  testthat::expect_identical(corrupted$final_equity, sequential$final_equity)
  for (id in names(local)) {
    testthat::expect_false(identical(bad[[id]]$events, local[[id]]$events), info = id)
    testthat::expect_identical(bad[[id]]$events$event_id[[1L]], "corrupted-in-worker", info = id)
    testthat::expect_identical(bad[[id]]$completion, local[[id]]$completion, info = id)
  }
})

testthat::test_that("[LTB-0520] a persisted run and a sweep candidate publish the same fill events", {
  snapshot <- availability_runtime_fixture(days = 4L, bar_days = c(1L, 2L, 4L))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_sink_witness_experiment(snapshot)

  local_dir <- tempfile("sink-cross-")
  dir.create(local_dir)
  on.exit(unlink(local_dir, recursive = TRUE), add = TRUE)
  original <- ledgr:::ledgr_output_handler
  eval(ledgr_sink_witness_observer_expr(local_dir), envir = new.env())
  sweep <- tryCatch(
    ledgr_sweep(exp, ledgr_sink_witness_grid(), seed = 31L),
    finally = ledgr_sink_witness_restore(original)
  )
  native <- ledgr_sink_witness_read(local_dir)

  for (id in c("one", "two")) {
    candidate <- sweep[sweep$candidate_id == id, , drop = FALSE]
    bt <- ledgr_run(
      exp,
      params = candidate$params[[1L]],
      run_id = paste0("cross-sink-", id),
      seed = candidate$execution_seed[[1L]]
    )
    ledger <- as.data.frame(ledgr_results(bt, "ledger"))
    close(bt)
    events <- native[[id]]$events
    testthat::expect_gt(sum(ledger$event_type == "FILL"), 0L)
    testthat::expect_identical(nrow(events), nrow(ledger), info = id)
    for (column in c("event_type", "instrument_id", "side", "qty", "price", "fee", "event_seq")) {
      testthat::expect_identical(events[[column]], ledger[[column]], info = paste(id, column))
    }
    testthat::expect_identical(
      as.numeric(events$ts_utc),
      as.numeric(as.POSIXct(ledger$ts_utc, tz = "UTC")),
      info = id
    )
    fill <- ledger$event_type == "FILL"
    meta <- lapply(ledger$meta_json[fill], ledgr:::ledgr_json_read_config)
    testthat::expect_identical(
      attr(events, "ledgr_event_cash_delta")[fill],
      vapply(meta, function(m) as.numeric(m$cash_delta), numeric(1)),
      info = id
    )
    testthat::expect_identical(
      attr(events, "ledgr_event_position_delta")[fill],
      vapply(meta, function(m) as.numeric(m$position_delta), numeric(1)),
      info = id
    )
  }
})
