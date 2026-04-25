testthat::test_that("LDG-507 full v0.1.2 workflow completes without warnings", {
  testthat::skip_if_not_installed("ggplot2")

  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  dates <- seq.Date(as.Date("2020-01-02"), as.Date("2020-01-15"), by = "day")
  dates <- dates[!weekdays(dates) %in% c("Saturday", "Sunday")]
  instruments <- c("AAA", "BBB")

  bars <- do.call(
    rbind,
    lapply(seq_along(instruments), function(i) {
      instrument_id <- instruments[[i]]
      base <- 100 + i * 10
      idx <- seq_along(dates)
      close <- base + cumsum(c(0, 1, -0.5, 1.5, 0.5, -1, 1, 0.5, -0.25, 1))[idx]
      open <- close - 0.25
      data.frame(
        instrument_id = instrument_id,
        ts_utc = as.POSIXct(dates, tz = "UTC"),
        open = open,
        high = pmax(open, close) + 0.5,
        low = pmin(open, close) - 0.5,
        close = close,
        volume = 1000 + idx,
        stringsAsFactors = FALSE
      )
    })
  )

  features <- list(ledgr_ind_sma(3), ledgr_ind_ema(3))
  final_pulse <- iso_utc(dates[[length(dates) - 1L]])
  strategy <- function(ctx) {
    targets <- stats::setNames(rep(0, length(ctx$universe)), ctx$universe)
    current_names <- intersect(names(ctx$positions), ctx$universe)
    if (length(current_names) > 0L) {
      targets[current_names] <- ctx$positions[current_names]
    }
    if (identical(ctx$ts_utc, final_pulse)) {
      return(targets)
    }

    targets[] <- 0
    for (instrument_id in ctx$universe) {
      bar <- ctx$bars[ctx$bars$instrument_id == instrument_id, , drop = FALSE]
      sma_3 <- ctx$feature(instrument_id, "sma_3")
      ema_3 <- ctx$feature(instrument_id, "ema_3")
      if (nrow(bar) == 1L && is.finite(sma_3) && is.finite(ema_3) && bar$close[[1]] > sma_3 && bar$close[[1]] > ema_3) {
        targets[[instrument_id]] <- 2
      }
    }
    targets
  }

  bt <- testthat::expect_no_warning(ledgr_backtest(
    data = bars,
    strategy = strategy,
    start = as.character(dates[[1]]),
    end = as.character(dates[[length(dates) - 1L]]),
    initial_cash = 10000,
    features = features,
    db_path = db_path
  ))
  on.exit(close(bt), add = TRUE)

  testthat::expect_s3_class(bt, "ledgr_backtest")

  con <- get_connection(bt)
  snapshots <- DBI::dbGetQuery(
    con,
    "SELECT status, snapshot_hash FROM snapshots WHERE snapshot_id = ?",
    params = list(bt$config$data$snapshot_id)
  )
  testthat::expect_equal(nrow(snapshots), 1L)
  testthat::expect_identical(snapshots$status[[1]], "SEALED")
  testthat::expect_true(is.character(snapshots$snapshot_hash[[1]]) && nzchar(snapshots$snapshot_hash[[1]]))

  legacy_bars <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM bars")$n[[1]]
  testthat::expect_identical(as.integer(legacy_bars), 0L)

  metrics <- testthat::expect_no_warning(ledgr_compute_metrics(bt))
  testthat::expect_true(is.list(metrics))
  testthat::expect_true(is.finite(metrics$total_return))

  equity <- tibble::as_tibble(bt, what = "equity")
  fills <- tibble::as_tibble(bt, what = "fills")
  ledger <- tibble::as_tibble(bt, what = "ledger")
  testthat::expect_true(nrow(equity) > 1L)
  testthat::expect_true(all(c("equity", "drawdown") %in% names(equity)))
  testthat::expect_true(nrow(fills) > 0L)
  testthat::expect_equal(nrow(ledger), nrow(fills))

  plot_obj <- testthat::expect_no_warning(suppressMessages(plot(bt)))
  testthat::expect_true(inherits(plot_obj, "ggplot") || inherits(plot_obj, "gtable"))

  close(bt)
  testthat::expect_equal(unlink(db_path), 0L)
})
