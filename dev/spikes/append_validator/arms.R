# Two candidate append checks for fill blocks. Both must accept and refuse
# exactly what the pinned check (ledgr_validate_accounting_append,
# R/accounting-replay.R:88) accepts and refuses, with the same condition
# class and message, and return what the handler reads from it
# (R/output-handler.R:466-478): `event_seq` and `ts_utc`.
#
#   r     the same rules in R, in the same order, restructured: a typed
#         all-FILL block skips the opening, cash and disposition sections
#         (their masks are all FALSE), skips coercions of columns already of
#         their storage type, and builds no prepared object.
#   cpp   the same fast path with the per-row rules in C++, one pass per
#         rule in the pinned order. A reference measurement only: the lean
#         fold core synthesis adds no compiled stage in v0.2.3.
#
# Any block outside the fast path (not a typed all-FILL block in the
# pinned column order) goes to the pinned check unchanged. In a product
# change the kind guards would live inside the one validator.

av_types <- local({
  t <- vapply(ledgr:::ledgr_accounting_empty_columns(0L), typeof, "")
  t[c("ts_utc", "mark_source_ts_utc")] <- "double"
  t
})
av_required <- ledgr:::ledgr_accounting_event_columns()
# Evidence fields a FILL row must leave missing. `mark_age` is absent on
# purpose: the pinned check replaces it with NA for every non-disposition
# row before this test (R/accounting-replay.R:258-274), so a fill row's
# mark_age is never refused (Type 2 response, finding 3).
av_evidence <- c(
  "source", "source_fact_id", "entitled_quantity", "gross_cash_per_parent_unit",
  "amount_policy_id", "posting_policy_id", "late_arrival", "disposition_policy_id",
  "disposition_choice", "disposition_basis", "mark_source", "mark_source_ts_utc",
  "position_before", "realized_model_pnl", "terminal_event", "matched_label",
  "haircut_fraction", "affected_marked_exposure"
)
av_err <- function(message, class = "ledgr_invalid_ledger_event") {
  ledgr:::ledgr_accounting_event_error(message, class)
}
av_pinned <- function(columns, prior_event_seq, prior_ts_utc) {
  ledgr_validate_accounting_append(columns, prior_event_seq = prior_event_seq,
                                   prior_ts_utc = prior_ts_utc)
}

# TRUE when the block may take the fast path.
av_fast <- function(columns) {
  is.list(columns) && length(columns) > 0L && identical(names(columns), av_required) &&
    length(columns$event_seq) > 0L &&
    identical(vapply(columns, typeof, "", USE.NAMES = FALSE), unname(av_types)) &&
    is.null(attributes(columns$ts_utc)) && !anyNA(columns$event_type) &&
    all(columns$event_type == "FILL")
}

av_prior_num <- function(prior_ts_utc) {
  if (is.null(prior_ts_utc)) NA_real_ else as.numeric(as.POSIXct(prior_ts_utc, tz = "UTC"))
}

av_check_r <- function(columns, prior_event_seq = NULL, prior_ts_utc = NULL, gut = FALSE) {
  if (!av_fast(columns)) return(av_pinned(columns, prior_event_seq, prior_ts_utc))
  n <- length(columns$event_seq)
  if (any(lengths(columns) != n)) {
    av_err("Accounting event columns must have equal lengths.")
  }
  seq <- columns$event_seq
  if (anyNA(seq) || (n > 1L && any(diff(as.numeric(seq)) <= 0)) ||
      (!is.null(prior_event_seq) && seq[[1L]] <= as.numeric(prior_event_seq))) {
    av_err("Accounting event_seq values must be integral and strictly increasing across blocks.")
  }
  ts <- columns$ts_utc
  prior_num <- av_prior_num(prior_ts_utc)
  if (anyNA(ts) || is.unsorted(ts) || (!is.na(prior_num) && ts[[1L]] < prior_num)) {
    av_err("Accounting event timestamps must be valid and nondecreasing across blocks.")
  }
  event_id <- columns$event_id
  run_id <- columns$run_id
  instrument_id <- columns$instrument_id
  fee <- columns$fee
  if (anyNA(event_id) || any(!nzchar(event_id)) || anyNA(run_id) || any(!nzchar(run_id)) ||
      anyNA(instrument_id) || any(!nzchar(instrument_id)) || anyNA(fee) || any(!is.finite(fee))) {
    av_err("Accounting events require non-empty identities and finite fees.")
  }
  cash_delta <- columns$cash_delta
  position_delta <- columns$position_delta
  if (anyNA(cash_delta) || any(!is.finite(cash_delta)) ||
      anyNA(position_delta) || any(!is.finite(position_delta))) {
    av_err("Accounting event metadata must provide finite cash_delta and position_delta values.",
           "ledgr_invalid_ledger_meta")
  }
  side <- toupper(columns$side)
  qty <- columns$qty
  price <- columns$price
  if (any(!(side %in% c("BUY", "SELL")) | !is.finite(qty) | qty <= 0 |
          !is.finite(price) | price <= 0 | !is.finite(fee) | fee < 0 |
          is.na(instrument_id) | !nzchar(instrument_id))) {
    av_err("FILL requires BUY or SELL, a non-empty instrument, positive qty and price, and non-negative fee.")
  }
  effects <- ledgr_fill_publication_deltas(c(-1L, 1L)[(side == "BUY") + 1L], qty, price, fee)
  if (any(cash_delta != effects$cash_delta | position_delta != effects$position_delta, na.rm = TRUE)) {
    av_err("FILL cash and position deltas do not reconcile to side, quantity, price and fee.",
           "ledgr_invalid_ledger_meta")
  }
  if (!gut && !all(vapply(columns[av_evidence], collapse::allNA, NA))) {
    av_err("Accounting event metadata contains fields forbidden for its event kind.",
           "ledgr_invalid_ledger_meta")
  }
  list(event_seq = seq, ts_utc = .POSIXct(ts, tz = "UTC"))
}

av_cpp_source <- '
#include <cpp11.hpp>
#include <cmath>
#include <cstring>
using namespace cpp11;

static bool empty_or_na(SEXP s) { return s == NA_STRING || CHAR(s)[0] == 0; }

// The first failing rule of a typed all-FILL block, in the pinned order;
// 0 when every rule holds.
[[cpp11::register]]
int av_fill_rules(SEXP event_id, SEXP run_id, SEXP instrument_id, SEXP fee,
                  SEXP cash_delta, SEXP position_delta, SEXP side, SEXP qty, SEXP price) {
  R_xlen_t n = Rf_xlength(fee);
  const double *f = REAL(fee), *c = REAL(cash_delta), *p = REAL(position_delta),
               *q = REAL(qty), *pr = REAL(price);
  for (R_xlen_t i = 0; i < n; ++i) {
    if (empty_or_na(STRING_ELT(event_id, i)) || empty_or_na(STRING_ELT(run_id, i)) ||
        empty_or_na(STRING_ELT(instrument_id, i)) || !std::isfinite(f[i])) return 1;
  }
  for (R_xlen_t i = 0; i < n; ++i) {
    if (!std::isfinite(c[i]) || !std::isfinite(p[i])) return 2;
  }
  for (R_xlen_t i = 0; i < n; ++i) {
    SEXP s = STRING_ELT(side, i);
    bool ok_side = false;
    if (s != NA_STRING) {
      const char *t = CHAR(s);
      ok_side = (std::strlen(t) == 3 && (t[0] | 32) == 98 && (t[1] | 32) == 117 && (t[2] | 32) == 121) ||
                (std::strlen(t) == 4 && (t[0] | 32) == 115 && (t[1] | 32) == 101 &&
                 (t[2] | 32) == 108 && (t[3] | 32) == 108);
    }
    if (!ok_side || !std::isfinite(q[i]) || q[i] <= 0 || !std::isfinite(pr[i]) || pr[i] <= 0 ||
        !std::isfinite(f[i]) || f[i] < 0) return 3;
  }
  for (R_xlen_t i = 0; i < n; ++i) {
    const char *t = CHAR(STRING_ELT(side, i));
    bool buy = (t[0] | 32) == 98;
    volatile double gross = q[i] * pr[i];
    double cash = buy ? -(gross + f[i]) : +(gross - f[i]);
    double pos = buy ? q[i] : -q[i];
    if (c[i] != cash || p[i] != pos) return 4;
  }
  return 0;
}
'

av_compile_cpp <- function(dir) {
  # No contraction: the reconciliation compares exact doubles with R.
  Sys.setenv(PKG_CXXFLAGS = "-ffp-contract=off")
  file <- file.path(dir, "av_fill_rules.cpp")
  writeLines(av_cpp_source, file)
  cpp11::cpp_source(file, quiet = TRUE, env = globalenv())
}

av_cpp_messages <- list(
  c("Accounting events require non-empty identities and finite fees.", "ledgr_invalid_ledger_event"),
  c("Accounting event metadata must provide finite cash_delta and position_delta values.", "ledgr_invalid_ledger_meta"),
  c("FILL requires BUY or SELL, a non-empty instrument, positive qty and price, and non-negative fee.",
    "ledgr_invalid_ledger_event"),
  c("FILL cash and position deltas do not reconcile to side, quantity, price and fee.", "ledgr_invalid_ledger_meta")
)

av_check_cpp <- function(columns, prior_event_seq = NULL, prior_ts_utc = NULL) {
  if (!av_fast(columns)) return(av_pinned(columns, prior_event_seq, prior_ts_utc))
  n <- length(columns$event_seq)
  if (any(lengths(columns) != n)) {
    av_err("Accounting event columns must have equal lengths.")
  }
  seq <- columns$event_seq
  if (anyNA(seq) || (n > 1L && any(diff(as.numeric(seq)) <= 0)) ||
      (!is.null(prior_event_seq) && seq[[1L]] <= as.numeric(prior_event_seq))) {
    av_err("Accounting event_seq values must be integral and strictly increasing across blocks.")
  }
  ts <- columns$ts_utc
  prior_num <- av_prior_num(prior_ts_utc)
  if (anyNA(ts) || is.unsorted(ts) || (!is.na(prior_num) && ts[[1L]] < prior_num)) {
    av_err("Accounting event timestamps must be valid and nondecreasing across blocks.")
  }
  code <- av_fill_rules(columns$event_id, columns$run_id, columns$instrument_id, columns$fee,
                        columns$cash_delta, columns$position_delta, columns$side,
                        columns$qty, columns$price)
  if (code > 0L) av_err(av_cpp_messages[[code]][[1L]], av_cpp_messages[[code]][[2L]])
  if (!all(vapply(columns[av_evidence], collapse::allNA, NA))) {
    av_err("Accounting event metadata contains fields forbidden for its event kind.",
           "ledgr_invalid_ledger_meta")
  }
  list(event_seq = seq, ts_utc = .POSIXct(ts, tz = "UTC"))
}
