typed_accounting_columns <- function() {
  c(
    "event_seq", "event_id", "run_id", "ts_utc", "event_type",
    "instrument_id", "side", "qty", "price", "fee", "cash_delta",
    "position_delta", "source", "source_fact_id", "cost_basis",
    "entitled_quantity", "gross_cash_per_parent_unit", "amount_policy_id",
    "posting_policy_id", "late_arrival", "affected_marked_exposure",
    "terminal_event", "matched_label", "disposition_policy_id",
    "disposition_choice", "disposition_basis", "mark_source",
    "mark_source_ts_utc", "mark_age", "haircut_fraction",
    "position_before", "realized_model_pnl"
  )
}

typed_accounting_case <- function(n_fill = 70000L, n_each = 500L) {
  stopifnot(n_fill > 0L, n_each > 0L)
  n <- n_fill + 3L * n_each
  kind <- c(
    rep("FILL", n_fill), rep("CASHFLOW", n_each),
    rep("CASHFLOW", n_each), rep("DISPOSITION", n_each)
  )
  is_fill <- kind == "FILL"
  is_open <- seq_len(n) > n_fill & seq_len(n) <= n_fill + n_each
  is_cash <- seq_len(n) > n_fill + n_each & seq_len(n) <= n_fill + 2L * n_each
  is_disp <- kind == "DISPOSITION"
  instrument <- sprintf("I%04d", (seq_len(n) - 1L) %% 1200L + 1L)
  side <- rep(NA_character_, n)
  side[is_fill] <- ifelse(seq_len(n_fill) %% 2L == 0L, "SELL", "BUY")
  qty <- rep(NA_real_, n)
  qty[is_fill] <- 1 + (seq_len(n_fill) %% 17L)
  qty[is_open] <- 10 + (seq_len(n_each) %% 5L)
  qty[is_disp] <- 10 + (seq_len(n_each) %% 5L)
  price <- rep(NA_real_, n)
  price[is_fill] <- 20 + (seq_len(n_fill) %% 1000L) / 10
  price[is_open] <- 40 + (seq_len(n_each) %% 100L) / 10
  price[is_disp] <- 15 + (seq_len(n_each) %% 100L) / 10
  fee <- rep(0, n)
  fee[is_fill] <- qty[is_fill] * price[is_fill] * 0.0005
  direction <- rep(0, n)
  direction[is_fill] <- ifelse(side[is_fill] == "BUY", 1, -1)
  position_delta <- rep(0, n)
  position_delta[is_fill] <- direction[is_fill] * qty[is_fill]
  position_delta[is_open] <- qty[is_open]
  position_before <- rep(NA_real_, n)
  position_before[is_disp] <- qty[is_disp]
  position_delta[is_disp] <- -position_before[is_disp]
  cash_delta <- rep(0, n)
  cash_delta[is_fill] <- -direction[is_fill] * qty[is_fill] * price[is_fill] - fee[is_fill]
  entitled <- 25 + (seq_len(n_each) %% 11L)
  gross <- 0.05 + (seq_len(n_each) %% 7L) / 100
  cash_delta[is_cash] <- entitled * gross
  cash_delta[is_disp] <- position_before[is_disp] * price[is_disp]
  source <- rep(NA_character_, n)
  source[is_open] <- "opening_position"
  source[is_cash] <- "corporate_action_cash"
  source[is_disp] <- ifelse(
    seq_len(n_each) %% 2L == 0L,
    "corporate_action_disposition",
    "lifetime_terminal_disposition"
  )
  source_fact_id <- rep(NA_character_, n)
  source_fact_id[is_cash | is_disp] <- sprintf("fact_%06d", seq_len(sum(is_cash | is_disp)))
  ts <- as.POSIXct("2020-01-01 21:00:00", tz = "UTC") + seq_len(n) * 86400
  mark_source_ts <- rep(as.POSIXct(NA, tz = "UTC"), n)
  mark_source_ts[is_disp] <- ts[is_disp] - 86400
  out <- data.frame(
    event_seq = seq_len(n),
    event_id = sprintf("run_1_%08d", seq_len(n)),
    run_id = rep("run_1", n),
    ts_utc = ts,
    event_type = kind,
    instrument_id = instrument,
    side = side,
    qty = qty,
    price = price,
    fee = fee,
    cash_delta = cash_delta,
    position_delta = position_delta,
    source = source,
    source_fact_id = source_fact_id,
    cost_basis = ifelse(is_open, price, NA_real_),
    entitled_quantity = replace(rep(NA_real_, n), is_cash, entitled),
    gross_cash_per_parent_unit = replace(rep(NA_real_, n), is_cash, gross),
    amount_policy_id = replace(rep(NA_character_, n), is_cash, "cash_amount.v1"),
    posting_policy_id = replace(rep(NA_character_, n), is_cash, "cash_posting.v1"),
    late_arrival = replace(rep(NA, n), is_cash, seq_len(n_each) %% 10L == 0L),
    affected_marked_exposure = replace(
      rep(NA_real_, n), is_cash | is_disp,
      c(entitled * 50, position_before[is_disp] * price[is_disp])
    ),
    terminal_event = replace(
      rep(NA_character_, n),
      is_disp & source == "lifetime_terminal_disposition",
      "delisting"
    ),
    matched_label = replace(
      rep(NA_character_, n),
      is_disp & source == "lifetime_terminal_disposition",
      "delisting"
    ),
    disposition_policy_id = replace(rep(NA_character_, n), is_disp, "last_permissible.v2"),
    disposition_choice = replace(rep(NA_character_, n), is_disp, "last_permissible"),
    disposition_basis = replace(rep(NA_character_, n), is_disp, "evidence"),
    mark_source = replace(rep(NA_character_, n), is_disp, "last_close"),
    mark_source_ts_utc = mark_source_ts,
    mark_age = replace(rep(NA_integer_, n), is_disp, 1L),
    haircut_fraction = replace(
      rep(NA_real_, n),
      is_disp & seq_len(n) %% 20L == 0L,
      0.5
    ),
    position_before = position_before,
    realized_model_pnl = replace(rep(NA_real_, n), is_disp, price[is_disp] * 0.1),
    stringsAsFactors = FALSE
  )
  stopifnot(identical(names(out), typed_accounting_columns()))
  out
}

typed_accounting_common_columns <- function() {
  typed_accounting_columns()[seq_len(13L)]
}

typed_accounting_opening_columns <- function() c("event_seq", "cost_basis")

typed_accounting_cash_columns <- function() {
  c(
    "event_seq", "source_fact_id", "entitled_quantity",
    "gross_cash_per_parent_unit", "amount_policy_id", "posting_policy_id",
    "late_arrival", "affected_marked_exposure"
  )
}

typed_accounting_disposition_columns <- function() {
  c(
    "event_seq", "source_fact_id", "affected_marked_exposure",
    "terminal_event", "matched_label", "disposition_policy_id",
    "disposition_choice", "disposition_basis", "mark_source",
    "mark_source_ts_utc", "mark_age", "haircut_fraction",
    "position_before", "realized_model_pnl"
  )
}

typed_accounting_normalize <- function(x) {
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  x <- x[order(x$event_seq), typed_accounting_columns(), drop = FALSE]
  rownames(x) <- NULL
  for (name in c("ts_utc", "mark_source_ts_utc")) {
    x[[name]] <- as.POSIXct(x[[name]], origin = "1970-01-01", tz = "UTC")
  }
  x$event_seq <- as.integer(x$event_seq)
  x$mark_age <- as.integer(x$mark_age)
  x$late_arrival <- as.logical(x$late_arrival)
  x
}

typed_accounting_mismatches <- function(expected, actual) {
  expected <- typed_accounting_normalize(expected)
  actual <- typed_accounting_normalize(actual)
  vapply(names(expected), function(name) {
    lhs <- expected[[name]]
    rhs <- actual[[name]]
    if (inherits(lhs, "POSIXt")) {
      lhs <- as.numeric(lhs)
      rhs <- as.numeric(rhs)
    }
    same_na <- is.na(lhs) == is.na(rhs)
    same_value <- rep(FALSE, length(lhs))
    same_value[is.na(lhs) & is.na(rhs)] <- TRUE
    present <- !is.na(lhs) & !is.na(rhs)
    same_value[present] <- lhs[present] == rhs[present]
    sum(!same_na | !same_value)
  }, integer(1))
}
