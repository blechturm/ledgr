args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
  stop("usage: check_record.R <pre.csv> <post.csv>")
}
pre <- utils::read.csv(args[[1L]], stringsAsFactors = FALSE)
post <- utils::read.csv(args[[2L]], stringsAsFactors = FALSE)
value <- function(x, field) x$value[match(field, x$field)]

stable <- c(
  "run_id", "config_hash", "metric_context_hash", "ledger_hash",
  "fills_hash", "equity_cash_hash", "metrics_value_hash", "explicit_calendar_label",
  "default_metric_hash", "explicit_metric_hash"
)
for (field in stable) {
  if (!identical(value(pre, field), value(post, field))) {
    stop(sprintf("stable field changed: %s", field))
  }
}
equity_delta <- abs(
  as.numeric(value(pre, "equity_final")) -
    as.numeric(value(post, "equity_final"))
)
if (!is.finite(equity_delta) || equity_delta > 1e-12) {
  stop("the derived-position correction materially changed equity")
}
if (!identical(value(pre, "position_after"), "1.1102230246251565e-16") ||
    !identical(value(post, "position_after"), "0e+00")) {
  stop("the fractional-position correction was not isolated")
}
if (!identical(value(pre, "default_calendar_label"), "US equity daily") ||
    !identical(value(post, "default_calendar_label"), "US equity daily (default)")) {
  stop("the default-calendar disclosure did not change exactly once")
}
if (!startsWith(value(pre, "headline"), "Corporate actions: NOT SUPPLIED") ||
    !startsWith(value(post, "headline"), "Economic events: NOT SUPPLIED")) {
  stop("the asset-neutral headline did not change exactly once")
}
if (!identical(value(post, "default_metric_hash"), value(post, "explicit_metric_hash"))) {
  stop("the default marker entered metric identity")
}
cat(sprintf(
  "LEDGR_WS59_RECORD_OK stable=10 corrected=3 equity_delta=%.17g\n",
  equity_delta
))
