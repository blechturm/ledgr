ledgr_result_table <- function(x, what) {
  out <- tibble::as_tibble(x)
  class_name <- paste0("ledgr_result_", what)
  class(out) <- c(class_name, "ledgr_result_table", setdiff(class(out), c(class_name, "ledgr_result_table")))
  attr(out, "ledgr_result_type") <- what
  out
}

ledgr_result_table_base <- function(x) {
  class(x) <- setdiff(class(x), grep("^ledgr_result_", class(x), value = TRUE))
  attr(x, "ledgr_result_type") <- NULL
  tibble::as_tibble(x)
}

ledgr_print_ts_utc_mode <- function() {
  mode <- getOption("ledgr.print_ts_utc", "auto")
  if (!is.character(mode) || length(mode) != 1L || is.na(mode) || !mode %in% c("auto", "datetime")) {
    rlang::abort(
      "`options(ledgr.print_ts_utc)` must be \"auto\" or \"datetime\".",
      class = "ledgr_invalid_option"
    )
  }
  mode
}

ledgr_ts_utc_all_midnight <- function(x) {
  if (!inherits(x, "POSIXt")) return(FALSE)
  ok <- !is.na(x)
  if (!any(ok)) return(TRUE)
  all(format(as.POSIXct(x[ok], tz = "UTC"), "%H:%M:%S", tz = "UTC") == "00:00:00")
}

ledgr_format_ts_utc_for_display <- function(x, mode = ledgr_print_ts_utc_mode()) {
  if (!inherits(x, "POSIXt")) return(x)
  out <- as.POSIXct(x, tz = "UTC")
  attr(out, "tzone") <- "UTC"
  if (identical(mode, "auto") && ledgr_ts_utc_all_midnight(out)) {
    return(as.Date(out, tz = "UTC"))
  }
  out
}

#' Convert a ledgr result table to a tibble
#'
#' Drops the ledgr display subclass and returns the raw result table. This is a
#' programmatic access path: `ts_utc` remains POSIXct UTC and is not display
#' formatted.
#'
#' @param x A ledgr result table returned by [ledgr_results()].
#' @param ... Unused.
#' @return A tibble with raw result columns.
#' @export
as_tibble.ledgr_result_table <- function(x, ...) {
  ledgr_result_table_base(x)
}

#' Print a ledgr result table
#'
#' Prints a display copy of a ledgr result table. When
#' `options(ledgr.print_ts_utc = "auto")`, all-midnight UTC timestamp columns are
#' displayed as dates to keep EOD output compact. The underlying `ts_utc` column
#' remains POSIXct UTC. Use `options(ledgr.print_ts_utc = "datetime")` to always
#' display full datetimes.
#'
#' @param x A ledgr result table returned by [ledgr_results()].
#' @param ... Passed to the tibble print method.
#' @return The input object, invisibly.
#' @export
print.ledgr_result_table <- function(x, ...) {
  view <- ledgr_result_table_base(x)
  if ("ts_utc" %in% names(view)) {
    view$ts_utc <- ledgr_format_ts_utc_for_display(view$ts_utc)
  }
  print(view, ...)
  invisible(x)
}
