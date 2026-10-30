#include <Rcpp.h>
#include <algorithm>
#include <cmath>
#include <cfloat>
using namespace Rcpp;
// A pulse has distinct instruments. FIFO is sequential within each book;
// totals and compensated realized P&L retain canonical event order.
// This probe does not edit or call the compiled spot-FIFO envelope.
// [[Rcpp::export]]
List carrier_lots(List input, IntegerVector ix, NumericVector quantity,
                  NumericVector price, NumericVector fee, IntegerVector direction,
                  double cash) {
  List s = clone(input);
  List quantities = s["lot_qty"], prices = s["lot_price"];
  IntegerVector heads = s["lot_head"], tails = s["lot_tail"];
  NumericVector net = s["net_by_inst"], bases = s["cost_basis_by_inst"];
  double total = as<double>(s["total_cost_basis"]);
  double realized = as<double>(s["realized_pnl"]), comp = as<double>(s["realized_comp"]);
  int n = ix.size();
  NumericVector closed(n), opened(n), close_pnl(n), event_realized(n), event_basis(n);
  for (int k = 0; k < n; ++k) {
    int j = ix[k] - 1, h = heads[j] - 1, t = tails[j] - 1, d = direction[k];
    NumericVector q = clone(as<NumericVector>(quantities[j]));
    NumericVector p = clone(as<NumericVector>(prices[j]));
    double qty = quantity[k], px = price[k], old_basis = bases[j];
    double after = net[j], basis_delta = 0, remaining = qty, close = 0, pnl = 0;
    while (remaining > 0 && t >= h && q[h] * d < 0) {
      double old_signed = q[h], current = std::abs(old_signed), old_px = p[h];
      double take = std::min(current, remaining);
      pnl = pnl + (d > 0 ? old_px - px : px - old_px) * take;
      basis_delta = basis_delta + (d > 0 ? take * old_px : -take * old_px);
      current = current - take; remaining = remaining - take; close = close + take;
      double tol = DBL_EPSILON * std::max({1.0, qty, take, std::abs(current), std::abs(remaining)});
      if (std::abs(remaining) <= tol) remaining = 0;
      double next_signed;
      if (current <= tol) { q[h] = NA_REAL; p[h] = NA_REAL; ++h; next_signed = 0; }
      else { next_signed = d > 0 ? -current : current; q[h] = next_signed; }
      after = (after - old_signed) + next_signed;
    }
    if (h > t) { h = 0; t = -1; }
    else if (h > t - h + 1) {
      int live = t - h + 1;
      for (int a = 0; a < live; ++a) { q[a] = q[h+a]; p[a] = p[h+a]; }
      for (int a = live; a < q.size(); ++a) { q[a] = NA_REAL; p[a] = NA_REAL; }
      h = 0; t = live - 1;
    }
    if (remaining > 0) {
      if (t >= q.size() - 1 && h > 0) {
        int live = t - h + 1;
        for (int a = 0; a < live; ++a) { q[a] = q[h+a]; p[a] = p[h+a]; }
        for (int a = live; a < q.size(); ++a) { q[a] = NA_REAL; p[a] = NA_REAL; }
        h = 0; t = live - 1;
      }
      if (t >= q.size() - 1) {
        int capacity = std::max(4, static_cast<int>(q.size()) * 2);
        NumericVector nq(capacity, NA_REAL), np(capacity, NA_REAL);
        std::copy(q.begin(), q.end(), nq.begin()); std::copy(p.begin(), p.end(), np.begin());
        q = nq; p = np;
      }
      ++t; double signed_open = d > 0 ? remaining : -remaining;
      q[t] = signed_open; p[t] = px;
      basis_delta = basis_delta + signed_open * px; after = after + signed_open;
    }
    double basis = old_basis + basis_delta;
    double new_net = h > t ? 0 : after;
    double tol = DBL_EPSILON * std::max({1.0, std::abs(basis), std::abs(new_net), qty, px});
    if (std::abs(basis) <= tol) basis = 0;
    quantities[j] = q; prices[j] = p; heads[j] = h + 1; tails[j] = t + 1;
    net[j] = new_net; bases[j] = basis; total = total - old_basis + basis;
    double delta = pnl - fee[k], y = delta - comp, next = realized + y;
    comp = (next - realized) - y; realized = next;
    double cd = d > 0 ? -(qty * px + fee[k]) : qty * px - fee[k];
    cash = cash + cd;
    closed[k] = close; opened[k] = remaining; close_pnl[k] = pnl;
    event_realized[k] = realized; event_basis[k] = total;
  }
  s["total_cost_basis"] = total; s["realized_pnl"] = realized; s["realized_comp"] = comp;
  return List::create(_["state"] = s, _["cash"] = cash, _["close_qty"] = closed,
    _["open_qty"] = opened, _["realized_close"] = close_pnl,
    _["event_realized"] = event_realized, _["event_basis"] = event_basis);
}
// [[Rcpp::export]]
List carrier_afford(NumericVector delta, IntegerVector order, LogicalVector blocked, double cash, double tolerance) {
  LogicalVector accepted(delta.size());
  for (int i : order) {
    int k = i - 1; double next = cash + delta[k];
    bool affordable = delta[k] >= 0 || next >= -tolerance;
    if (!blocked[k] && affordable) { accepted[k] = true; cash = next; }
  }
  return List::create(_["accepted"] = accepted, _["cash"] = cash);
}
