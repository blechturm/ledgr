#include "cpp11.hpp"

#include <Rinternals.h>

#include <cmath>
#include <deque>
#include <iomanip>
#include <sstream>
#include <string>
#include <vector>

struct ledgr_spot_lot {
  double qty;
  double price;
};

static double ledgr_spot_lot_basis(const std::deque<ledgr_spot_lot>& lots) {
  double out = 0.0;
  for (const auto& lot : lots) {
    out += lot.qty * lot.price;
  }
  return out;
}

static double ledgr_spot_lot_net(const std::deque<ledgr_spot_lot>& lots) {
  double out = 0.0;
  for (const auto& lot : lots) {
    out += lot.qty;
  }
  return out;
}

static std::string ledgr_spot_event_id(const std::string& run_id, int event_seq) {
  std::ostringstream out;
  out << run_id << "_" << std::setw(8) << std::setfill('0') << event_seq;
  return out.str();
}

static int ledgr_spot_direction(const char* side) {
  if (side == nullptr) return 0;
  std::string value(side);
  if (value == "BUY") return 1;
  if (value == "SELL") return -1;
  return 0;
}

static void ledgr_spot_check(bool ok, const char* message) {
  if (!ok) {
    cpp11::stop("%s", message);
  }
}

[[cpp11::register]]
SEXP ledgr_cpp_spot_fifo_batch(SEXP run_id_sxp,
                               SEXP fill_inst_idx_sxp,
                               SEXP fill_instrument_id_sxp,
                               SEXP fill_side_sxp,
                               SEXP fill_qty_sxp,
                               SEXP fill_price_sxp,
                               SEXP fill_fee_sxp,
                               SEXP fill_ts_utc_sxp,
                               SEXP event_seq_start_sxp,
                               SEXP positions_sxp,
                               SEXP cash_sxp,
                               SEXP lot_inst_idx_sxp,
                               SEXP lot_qty_sxp,
                               SEXP lot_price_sxp,
                               SEXP cost_basis_by_inst_sxp,
                               SEXP total_cost_basis_sxp,
                               SEXP realized_pnl_sxp,
                               SEXP realized_comp_sxp) {
  ledgr_spot_check(TYPEOF(run_id_sxp) == STRSXP && XLENGTH(run_id_sxp) == 1,
                   "`run_id` must be a character scalar.");
  std::string run_id = CHAR(STRING_ELT(run_id_sxp, 0));

  const R_xlen_t n_fills = XLENGTH(fill_inst_idx_sxp);
  const R_xlen_t n_inst = XLENGTH(positions_sxp);
  ledgr_spot_check(TYPEOF(fill_inst_idx_sxp) == INTSXP, "`fill_inst_idx` must be integer.");
  ledgr_spot_check(TYPEOF(fill_instrument_id_sxp) == STRSXP &&
                     XLENGTH(fill_instrument_id_sxp) == n_fills,
                   "`fill_instrument_id` must align with fills.");
  ledgr_spot_check(TYPEOF(fill_side_sxp) == STRSXP && XLENGTH(fill_side_sxp) == n_fills,
                   "`fill_side` must align with fills.");
  ledgr_spot_check(TYPEOF(fill_qty_sxp) == REALSXP && XLENGTH(fill_qty_sxp) == n_fills,
                   "`fill_qty` must align with fills.");
  ledgr_spot_check(TYPEOF(fill_price_sxp) == REALSXP && XLENGTH(fill_price_sxp) == n_fills,
                   "`fill_price` must align with fills.");
  ledgr_spot_check(TYPEOF(fill_fee_sxp) == REALSXP && XLENGTH(fill_fee_sxp) == n_fills,
                   "`fill_fee` must align with fills.");
  ledgr_spot_check(TYPEOF(fill_ts_utc_sxp) == REALSXP && XLENGTH(fill_ts_utc_sxp) == n_fills,
                   "`fill_ts_utc` must align with fills.");
  ledgr_spot_check(TYPEOF(positions_sxp) == REALSXP, "`positions` must be numeric.");
  ledgr_spot_check(TYPEOF(cash_sxp) == REALSXP && XLENGTH(cash_sxp) == 1,
                   "`cash` must be a numeric scalar.");
  ledgr_spot_check(TYPEOF(total_cost_basis_sxp) == REALSXP && XLENGTH(total_cost_basis_sxp) == 1,
                   "`total_cost_basis` must be a numeric scalar.");
  ledgr_spot_check(TYPEOF(realized_pnl_sxp) == REALSXP && XLENGTH(realized_pnl_sxp) == 1,
                   "`realized_pnl` must be a numeric scalar.");
  ledgr_spot_check(TYPEOF(realized_comp_sxp) == REALSXP && XLENGTH(realized_comp_sxp) == 1,
                   "`realized_comp` must be a numeric scalar.");
  ledgr_spot_check(TYPEOF(event_seq_start_sxp) == INTSXP && XLENGTH(event_seq_start_sxp) == 1,
                   "`event_seq_start` must be an integer scalar.");
  ledgr_spot_check(TYPEOF(cost_basis_by_inst_sxp) == REALSXP &&
                     XLENGTH(cost_basis_by_inst_sxp) == n_inst,
                   "`cost_basis_by_inst` must align with positions.");

  std::vector<double> positions(n_inst);
  for (R_xlen_t i = 0; i < n_inst; ++i) {
    positions[static_cast<size_t>(i)] = REAL(positions_sxp)[i];
  }

  std::vector<std::deque<ledgr_spot_lot>> lots(static_cast<size_t>(n_inst));
  const R_xlen_t n_lots = XLENGTH(lot_inst_idx_sxp);
  ledgr_spot_check(TYPEOF(lot_inst_idx_sxp) == INTSXP, "`lot_inst_idx` must be integer.");
  ledgr_spot_check(TYPEOF(lot_qty_sxp) == REALSXP && XLENGTH(lot_qty_sxp) == n_lots,
                   "`lot_qty` must align with lots.");
  ledgr_spot_check(TYPEOF(lot_price_sxp) == REALSXP && XLENGTH(lot_price_sxp) == n_lots,
                   "`lot_price` must align with lots.");
  for (R_xlen_t i = 0; i < n_lots; ++i) {
    int idx = INTEGER(lot_inst_idx_sxp)[i] - 1;
    ledgr_spot_check(idx >= 0 && idx < n_inst, "`lot_inst_idx` is out of range.");
    lots[static_cast<size_t>(idx)].push_back(
      ledgr_spot_lot{REAL(lot_qty_sxp)[i], REAL(lot_price_sxp)[i]}
    );
  }

  std::vector<double> cost_basis_by_inst(n_inst);
  for (R_xlen_t i = 0; i < n_inst; ++i) {
    cost_basis_by_inst[static_cast<size_t>(i)] = REAL(cost_basis_by_inst_sxp)[i];
  }
  double total_cost_basis = REAL(total_cost_basis_sxp)[0];
  double realized_pnl = REAL(realized_pnl_sxp)[0];
  double realized_comp = REAL(realized_comp_sxp)[0];
  double cash = REAL(cash_sxp)[0];
  int event_seq = INTEGER(event_seq_start_sxp)[0];

  std::vector<std::string> event_id;
  std::vector<std::string> event_instrument_id;
  std::vector<std::string> event_side;
  std::vector<double> event_qty;
  std::vector<double> event_price;
  std::vector<double> event_fee;
  std::vector<double> event_ts_utc;
  std::vector<int> event_seq_vec;
  std::vector<double> cash_delta_vec;
  std::vector<double> position_delta_vec;
  std::vector<double> event_realized_vec;
  std::vector<double> event_cost_basis_vec;

  std::vector<int> fill_event_seq;
  std::vector<double> fill_ts_utc;
  std::vector<std::string> fill_instrument_id;
  std::vector<std::string> fill_side;
  std::vector<double> fill_qty;
  std::vector<double> fill_price;
  std::vector<double> fill_fee;
  std::vector<double> fill_realized_pnl;
  std::vector<std::string> fill_action;

  event_id.reserve(static_cast<size_t>(n_fills));
  event_instrument_id.reserve(static_cast<size_t>(n_fills));
  event_side.reserve(static_cast<size_t>(n_fills));
  event_qty.reserve(static_cast<size_t>(n_fills));
  event_price.reserve(static_cast<size_t>(n_fills));
  event_fee.reserve(static_cast<size_t>(n_fills));
  event_ts_utc.reserve(static_cast<size_t>(n_fills));
  event_seq_vec.reserve(static_cast<size_t>(n_fills));
  cash_delta_vec.reserve(static_cast<size_t>(n_fills));
  position_delta_vec.reserve(static_cast<size_t>(n_fills));
  event_realized_vec.reserve(static_cast<size_t>(n_fills));
  event_cost_basis_vec.reserve(static_cast<size_t>(n_fills));

  for (R_xlen_t j = 0; j < n_fills; ++j) {
    int inst_idx = INTEGER(fill_inst_idx_sxp)[j] - 1;
    ledgr_spot_check(inst_idx >= 0 && inst_idx < n_inst, "`fill_inst_idx` is out of range.");
    const char* side_c = CHAR(STRING_ELT(fill_side_sxp, j));
    int direction = ledgr_spot_direction(side_c);
    ledgr_spot_check(direction != 0, "`fill_side` must be BUY or SELL.");

    double qty = REAL(fill_qty_sxp)[j];
    double price = REAL(fill_price_sxp)[j];
    double fee = REAL(fill_fee_sxp)[j];
    double ts = REAL(fill_ts_utc_sxp)[j];
    ledgr_spot_check(std::isfinite(qty) && qty > 0, "`fill_qty` must be finite > 0.");
    ledgr_spot_check(std::isfinite(price) && price > 0, "`fill_price` must be finite > 0.");
    ledgr_spot_check(std::isfinite(fee) && fee >= 0, "`fill_fee` must be finite >= 0.");
    ledgr_spot_check(std::isfinite(ts), "`fill_ts_utc` must be finite.");

    auto& inst_lots = lots[static_cast<size_t>(inst_idx)];
    double net_pos = ledgr_spot_lot_net(inst_lots);
    double close_qty = 0.0;
    if (direction > 0 && net_pos < 0) {
      close_qty = std::min(qty, std::abs(net_pos));
    } else if (direction < 0 && net_pos > 0) {
      close_qty = std::min(qty, net_pos);
    }
    double open_qty = qty - close_qty;

    double remaining_close = close_qty;
    double realized_close = 0.0;
    if (remaining_close > 0) {
      if (direction > 0) {
        while (remaining_close > 0 && !inst_lots.empty() && inst_lots.front().qty < 0) {
          double lot_qty = std::abs(inst_lots.front().qty);
          double lot_price = inst_lots.front().price;
          double take = std::min(lot_qty, remaining_close);
          realized_close += (lot_price - price) * take;
          lot_qty -= take;
          remaining_close -= take;
          if (lot_qty <= 0) {
            inst_lots.pop_front();
          } else {
            inst_lots.front().qty = -lot_qty;
          }
        }
      } else {
        while (remaining_close > 0 && !inst_lots.empty() && inst_lots.front().qty > 0) {
          double lot_qty = inst_lots.front().qty;
          double lot_price = inst_lots.front().price;
          double take = std::min(lot_qty, remaining_close);
          realized_close += (price - lot_price) * take;
          lot_qty -= take;
          remaining_close -= take;
          if (lot_qty <= 0) {
            inst_lots.pop_front();
          } else {
            inst_lots.front().qty = lot_qty;
          }
        }
      }
    }

    if (open_qty > 0) {
      inst_lots.push_back(ledgr_spot_lot{
        direction > 0 ? open_qty : -open_qty,
        price
      });
    }

    double old_basis = cost_basis_by_inst[static_cast<size_t>(inst_idx)];
    double new_basis = ledgr_spot_lot_basis(inst_lots);
    cost_basis_by_inst[static_cast<size_t>(inst_idx)] = new_basis;
    total_cost_basis = total_cost_basis - old_basis + new_basis;

    double realized_delta = realized_close - fee;
    double y = realized_delta - realized_comp;
    double t = realized_pnl + y;
    realized_comp = (t - realized_pnl) - y;
    realized_pnl = t;

    double signed_qty = direction > 0 ? qty : -qty;
    double cash_delta = direction > 0 ? -(qty * price + fee) : (qty * price - fee);
    positions[static_cast<size_t>(inst_idx)] += signed_qty;
    cash += cash_delta;

    std::string inst_id = CHAR(STRING_ELT(fill_instrument_id_sxp, j));
    std::string side = side_c;
    event_id.push_back(ledgr_spot_event_id(run_id, event_seq));
    event_instrument_id.push_back(inst_id);
    event_side.push_back(side);
    event_qty.push_back(qty);
    event_price.push_back(price);
    event_fee.push_back(fee);
    event_ts_utc.push_back(ts);
    event_seq_vec.push_back(event_seq);
    cash_delta_vec.push_back(cash_delta);
    position_delta_vec.push_back(signed_qty);
    event_realized_vec.push_back(realized_pnl);
    event_cost_basis_vec.push_back(total_cost_basis);

    if (close_qty > 0) {
      fill_event_seq.push_back(event_seq);
      fill_ts_utc.push_back(ts);
      fill_instrument_id.push_back(inst_id);
      fill_side.push_back(side);
      fill_qty.push_back(close_qty);
      fill_price.push_back(price);
      fill_fee.push_back(fee);
      fill_realized_pnl.push_back(realized_close);
      fill_action.push_back("CLOSE");
    }
    if (open_qty > 0) {
      fill_event_seq.push_back(event_seq);
      fill_ts_utc.push_back(ts);
      fill_instrument_id.push_back(inst_id);
      fill_side.push_back(side);
      fill_qty.push_back(open_qty);
      fill_price.push_back(price);
      fill_fee.push_back(fee);
      fill_realized_pnl.push_back(0.0);
      fill_action.push_back("OPEN");
    }

    ++event_seq;
  }

  std::vector<int> out_lot_inst_idx;
  std::vector<double> out_lot_qty;
  std::vector<double> out_lot_price;
  for (R_xlen_t i = 0; i < n_inst; ++i) {
    for (const auto& lot : lots[static_cast<size_t>(i)]) {
      out_lot_inst_idx.push_back(static_cast<int>(i) + 1);
      out_lot_qty.push_back(lot.qty);
      out_lot_price.push_back(lot.price);
    }
  }

  const int n_out = 33;
  SEXP out = PROTECT(Rf_allocVector(VECSXP, n_out));
  SEXP names = PROTECT(Rf_allocVector(STRSXP, n_out));
  int k = 0;
  auto set_name = [&](const char* name) {
    SET_STRING_ELT(names, k, Rf_mkChar(name));
  };
  auto set_string_vec = [&](const std::vector<std::string>& values) {
    SEXP x = Rf_allocVector(STRSXP, static_cast<R_xlen_t>(values.size()));
    SET_VECTOR_ELT(out, k, x);
    for (R_xlen_t i = 0; i < static_cast<R_xlen_t>(values.size()); ++i) {
      SET_STRING_ELT(x, i, Rf_mkChar(values[static_cast<size_t>(i)].c_str()));
    }
    ++k;
  };
  auto set_double_vec = [&](const std::vector<double>& values) {
    SEXP x = Rf_allocVector(REALSXP, static_cast<R_xlen_t>(values.size()));
    for (R_xlen_t i = 0; i < static_cast<R_xlen_t>(values.size()); ++i) {
      REAL(x)[i] = values[static_cast<size_t>(i)];
    }
    SET_VECTOR_ELT(out, k, x);
    ++k;
  };
  auto set_int_vec = [&](const std::vector<int>& values) {
    SEXP x = Rf_allocVector(INTSXP, static_cast<R_xlen_t>(values.size()));
    for (R_xlen_t i = 0; i < static_cast<R_xlen_t>(values.size()); ++i) {
      INTEGER(x)[i] = values[static_cast<size_t>(i)];
    }
    SET_VECTOR_ELT(out, k, x);
    ++k;
  };

  set_name("event_id"); set_string_vec(event_id);
  set_name("event_run_id");
  {
    SEXP x = Rf_allocVector(STRSXP, static_cast<R_xlen_t>(event_id.size()));
    SET_VECTOR_ELT(out, k, x);
    for (R_xlen_t i = 0; i < static_cast<R_xlen_t>(event_id.size()); ++i) {
      SET_STRING_ELT(x, i, Rf_mkChar(run_id.c_str()));
    }
    ++k;
  }
  set_name("event_ts_utc"); set_double_vec(event_ts_utc);
  set_name("event_type");
  {
    SEXP x = Rf_allocVector(STRSXP, static_cast<R_xlen_t>(event_id.size()));
    SET_VECTOR_ELT(out, k, x);
    for (R_xlen_t i = 0; i < static_cast<R_xlen_t>(event_id.size()); ++i) {
      SET_STRING_ELT(x, i, Rf_mkChar("FILL"));
    }
    ++k;
  }
  set_name("event_instrument_id"); set_string_vec(event_instrument_id);
  set_name("event_side"); set_string_vec(event_side);
  set_name("event_qty"); set_double_vec(event_qty);
  set_name("event_price"); set_double_vec(event_price);
  set_name("event_fee"); set_double_vec(event_fee);
  set_name("event_seq"); set_int_vec(event_seq_vec);
  set_name("cash_delta"); set_double_vec(cash_delta_vec);
  set_name("position_delta"); set_double_vec(position_delta_vec);
  set_name("event_realized"); set_double_vec(event_realized_vec);
  set_name("event_cost_basis"); set_double_vec(event_cost_basis_vec);
  set_name("fill_event_seq"); set_int_vec(fill_event_seq);
  set_name("fill_ts_utc"); set_double_vec(fill_ts_utc);
  set_name("fill_instrument_id"); set_string_vec(fill_instrument_id);
  set_name("fill_side"); set_string_vec(fill_side);
  set_name("fill_qty"); set_double_vec(fill_qty);
  set_name("fill_price"); set_double_vec(fill_price);
  set_name("fill_fee"); set_double_vec(fill_fee);
  set_name("fill_realized_pnl"); set_double_vec(fill_realized_pnl);
  set_name("fill_action"); set_string_vec(fill_action);
  set_name("positions");
  {
    SEXP x = Rf_allocVector(REALSXP, n_inst);
    for (R_xlen_t i = 0; i < n_inst; ++i) {
      REAL(x)[i] = positions[static_cast<size_t>(i)];
    }
    SET_VECTOR_ELT(out, k, x);
    ++k;
  }
  set_name("cash");
  {
    SEXP x = Rf_allocVector(REALSXP, 1);
    REAL(x)[0] = cash;
    SET_VECTOR_ELT(out, k, x);
    ++k;
  }
  set_name("lot_inst_idx"); set_int_vec(out_lot_inst_idx);
  set_name("lot_qty"); set_double_vec(out_lot_qty);
  set_name("lot_price"); set_double_vec(out_lot_price);
  set_name("cost_basis_by_inst");
  {
    SEXP x = Rf_allocVector(REALSXP, n_inst);
    for (R_xlen_t i = 0; i < n_inst; ++i) {
      REAL(x)[i] = cost_basis_by_inst[static_cast<size_t>(i)];
    }
    SET_VECTOR_ELT(out, k, x);
    ++k;
  }
  set_name("total_cost_basis");
  {
    SEXP x = Rf_allocVector(REALSXP, 1);
    REAL(x)[0] = total_cost_basis;
    SET_VECTOR_ELT(out, k, x);
    ++k;
  }
  set_name("realized_pnl");
  {
    SEXP x = Rf_allocVector(REALSXP, 1);
    REAL(x)[0] = realized_pnl;
    SET_VECTOR_ELT(out, k, x);
    ++k;
  }
  set_name("realized_comp");
  {
    SEXP x = Rf_allocVector(REALSXP, 1);
    REAL(x)[0] = realized_comp;
    SET_VECTOR_ELT(out, k, x);
    ++k;
  }
  set_name("next_event_seq");
  {
    SEXP x = Rf_allocVector(INTSXP, 1);
    INTEGER(x)[0] = event_seq;
    SET_VECTOR_ELT(out, k, x);
    ++k;
  }

  Rf_setAttrib(out, R_NamesSymbol, names);
  UNPROTECT(2);
  return out;
}
