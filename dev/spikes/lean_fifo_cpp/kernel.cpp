// Spike lean_fifo_cpp: a compiled port of dev/lean_core/fifo.R's
// lean_lot_general() for fill blocks. It performs the R kernel's
// floating-point operations in the R kernel's order, row by row (rows of one
// block touch distinct instruments, so the R kernel's vector lockstep and
// this row loop compute the same values). It returns R_NilValue, and the R
// kernel runs instead, for anything outside the common path: a non-fill
// operation, an empty block, a position outside the axis or repeated, any
// non-finite value on the way, an opening through an opposing lot, or a
// capacity that would overflow. Refusals therefore stay the R kernel's.
//
// Compiled without FMA contraction (Rtools' default -msse2 target has no FMA
// instruction; no -ffast-math).

#include "cpp11.hpp"
#include <Rinternals.h>
#include <algorithm>
#include <cfloat>
#include <climits>
#include <cmath>
#include <cstring>
#include <vector>

namespace {

SEXP field(SEXP list, const char* name) {
  SEXP names = Rf_getAttrib(list, R_NamesSymbol);
  for (R_xlen_t i = 0; i < Rf_xlength(list); ++i) {
    if (std::strcmp(CHAR(STRING_ELT(names, i)), name) == 0) return VECTOR_ELT(list, i);
  }
  return R_NilValue;
}

R_xlen_t field_index(SEXP list, const char* name) {
  SEXP names = Rf_getAttrib(list, R_NamesSymbol);
  for (R_xlen_t i = 0; i < Rf_xlength(list); ++i) {
    if (std::strcmp(CHAR(STRING_ELT(names, i)), name) == 0) return i;
  }
  return -1;
}

inline bool fin(double x) { return std::isfinite(x); }

// eps * max(1, |a|, |b|, |c|, |d|), the R kernel's lean_lot_tol() on finite values.
inline double tol4(double a, double b, double c, double d) {
  double s = 1.0;
  s = std::max(s, std::fabs(a)); s = std::max(s, std::fabs(b));
  s = std::max(s, std::fabs(c)); s = std::max(s, std::fabs(d));
  return DBL_EPSILON * s;
}

SEXP dbl(R_xlen_t n) { return Rf_allocVector(REALSXP, n); }

}  // namespace

[[cpp11::register]]
SEXP spike_lot_fill(SEXP book, SEXP input) {
  SEXP op_s = field(input, "operation"), pos_s = field(input, "pos"), side_s = field(input, "side");
  SEXP qty_s = field(input, "qty"), price_s = field(input, "price"), fee_s = field(input, "fee");
  const R_xlen_t m = Rf_xlength(pos_s);
  if (m == 0 || TYPEOF(pos_s) != INTSXP || TYPEOF(side_s) != INTSXP || TYPEOF(op_s) != INTSXP ||
      TYPEOF(qty_s) != REALSXP || TYPEOF(price_s) != REALSXP || TYPEOF(fee_s) != REALSXP) return R_NilValue;
  const int* op = INTEGER(op_s); const int* pos = INTEGER(pos_s); const int* side = INTEGER(side_s);
  const double* quantity = REAL(qty_s); const double* price = REAL(price_s); const double* fee = REAL(fee_s);

  SEXP off_s = field(book, "offset"), cap_s = field(book, "capacity"), head_s = field(book, "head");
  SEXP tail_s = field(book, "tail"), q_s = field(book, "lot_qty"), p_s = field(book, "lot_price");
  SEXP net_s = field(book, "net_by_inst"), basis_s = field(book, "cost_basis_by_inst");
  if (TYPEOF(off_s) != INTSXP || TYPEOF(cap_s) != INTSXP || TYPEOF(head_s) != INTSXP || TYPEOF(tail_s) != INTSXP ||
      TYPEOF(q_s) != REALSXP || TYPEOF(p_s) != REALSXP) return R_NilValue;
  const R_xlen_t n_inst = Rf_xlength(off_s);
  const int* off0 = INTEGER(off_s); const int* cap0 = INTEGER(cap_s);

  // admission: fills only, positions on the axis and distinct
  std::vector<char> seen(n_inst + 1, 0);
  for (R_xlen_t k = 0; k < m; ++k) {
    if (op[k] != 1 || pos[k] == NA_INTEGER || pos[k] < 1 || pos[k] > n_inst || seen[pos[k]]) return R_NilValue;
    if (side[k] != 1 && side[k] != -1) return R_NilValue;
    seen[pos[k]] = 1;
  }

  // working copies (the R kernel works on copies; the input book is untouched)
  const R_xlen_t n_slot = Rf_xlength(q_s);
  std::vector<double> q(REAL(q_s), REAL(q_s) + n_slot), p(REAL(p_s), REAL(p_s) + n_slot);
  std::vector<int> base(m), head(m), tail(m);
  std::vector<double> net(m), old_basis(m), position_before(m);
  for (R_xlen_t k = 0; k < m; ++k) {
    int i = pos[k] - 1;
    base[k] = off0[i]; head[k] = INTEGER(head_s)[i]; tail[k] = INTEGER(tail_s)[i];
    net[k] = REAL(net_s)[i]; old_basis[k] = REAL(basis_s)[i]; position_before[k] = net[k];
  }
  // slots are 1-based in R: q[base + head] is q_c[base + head - 1]
  auto Q = [&](int slot) -> double& { return q[slot - 1]; };
  auto P = [&](int slot) -> double& { return p[slot - 1]; };

  std::vector<double> remaining(quantity, quantity + m), close_qty(m, 0.0), realized_close(m, 0.0), basis_delta(m, 0.0);
  for (R_xlen_t a = 0; a < m; ++a) {
    const double s = static_cast<double>(side[a]);
    const double neg_s = static_cast<double>(-side[a]);
    while (head[a] <= tail[a] && Q(base[a] + head[a]) * s < 0) {
      const int slot = base[a] + head[a];
      const double old = Q(slot), old_price = P(slot);
      double current = std::fabs(old);
      // pmin(current, remaining): the smaller; equal values are the same number
      const double take = remaining[a] < current ? remaining[a] : current;
      realized_close[a] = realized_close[a] + ((price[a] - old_price) * neg_s) * take;
      basis_delta[a] = basis_delta[a] + s * (take * old_price);
      current = current - take;
      double left = remaining[a] - take;
      close_qty[a] = close_qty[a] + take;
      if (!fin(quantity[a]) || !fin(current) || !fin(left)) return R_NilValue;
      const double tol = tol4(quantity[a], current, 0.0, 0.0);
      if (std::fabs(left) <= tol) left = 0.0;
      remaining[a] = left;
      const bool consumed = current <= tol;
      const double new_signed = consumed ? 0.0 : neg_s * current;
      Q(slot) = consumed ? NA_REAL : new_signed;
      if (consumed) P(slot) = NA_REAL;
      net[a] = (net[a] - old) + new_signed;
      head[a] = head[a] + (consumed ? 1 : 0);
      if (!(remaining[a] > 0)) break;
    }
  }
  std::vector<double> open_qty(remaining);
  std::vector<int> live(m);
  for (R_xlen_t k = 0; k < m; ++k) {
    if (head[k] > tail[k]) { head[k] = 1; tail[k] = 0; }
    live[k] = tail[k] - head[k] + 1;
  }
  std::vector<double> realized_delta(m);
  for (R_xlen_t k = 0; k < m; ++k) realized_delta[k] = realized_close[k] - fee[k];
  {  // closing_nonfinite: R's sum() accumulates in long double
    long double acc = 0;
    for (R_xlen_t k = 0; k < m; ++k) acc += realized_delta[k];
    for (R_xlen_t k = 0; k < m; ++k) acc += basis_delta[k];
    for (R_xlen_t k = 0; k < m; ++k) acc += net[k];
    if (!std::isfinite(static_cast<double>(acc)) || !std::isfinite(acc)) return R_NilValue;
  }
  std::vector<char> appending(m);
  std::vector<double> signed_q(m, 0.0);
  for (R_xlen_t a = 0; a < m; ++a) {
    appending[a] = open_qty[a] > 0;
    if (!appending[a]) continue;
    signed_q[a] = static_cast<double>(side[a]) * open_qty[a];
    const double bd = signed_q[a] * price[a];
    basis_delta[a] = basis_delta[a] + bd;
    net[a] = net[a] + signed_q[a];
  }
  std::vector<double> new_basis(m);
  for (R_xlen_t k = 0; k < m; ++k) new_basis[k] = old_basis[k] + basis_delta[k];
  for (R_xlen_t k = 0; k < m; ++k) if (head[k] > tail[k] && !appending[k]) net[k] = 0.0;
  for (R_xlen_t k = 0; k < m; ++k) {
    if (!fin(new_basis[k]) || !fin(net[k]) || !fin(price[k])) return R_NilValue;
    const double tol = tol4(new_basis[k], net[k], quantity[k], price[k]);
    if (std::fabs(new_basis[k]) <= tol) new_basis[k] = 0.0;
  }
  // event-order totals: one scalar scan, compensated realized step per fill
  double total = REAL(field(book, "total_cost_basis"))[0];
  double realized = REAL(field(book, "realized_pnl"))[0];
  double comp = REAL(field(book, "realized_comp"))[0];
  std::vector<double> event_cost_basis(m), event_realized(m);
  for (R_xlen_t k = 0; k < m; ++k) {
    total = total - old_basis[k] + new_basis[k];
    const double y = realized_delta[k] - comp;
    const double t = realized + y;
    comp = (t - realized) - y;
    realized = t;
    event_cost_basis[k] = total;
    event_realized[k] = realized;
  }
  {  // nonfinite: the second sum() of the R kernel
    long double acc = 0;
    const std::vector<double>* parts[] = {&position_before, &net, &close_qty, &open_qty, &realized_close,
                                          &realized_delta, &event_realized, &event_cost_basis, &new_basis};
    for (auto v : parts) for (double x : *v) acc += x;
    acc += comp;
    if (!std::isfinite(acc)) return R_NilValue;
  }
  // opening through an unconsumed opposing lot: the R kernel refuses
  for (R_xlen_t k = 0; k < m; ++k) {
    if (open_qty[k] > 0 && live[k] > 0) {
      const double front = Q(base[k] + head[k]);
      if (std::isnan(front)) return R_NilValue;
      const double sg = front > 0 ? 1.0 : (front < 0 ? -1.0 : 0.0);
      if (sg != static_cast<double>(side[k])) return R_NilValue;
    }
  }
  // compaction (cap and base before growth)
  for (R_xlen_t k = 0; k < m; ++k) {
    const int c = cap0[pos[k] - 1];
    if (!(live[k] > 0 && ((head[k] - 1 > live[k]) || (appending[k] && tail[k] >= c && head[k] > 1)))) continue;
    for (int j = 1; j <= live[k]; ++j) {
      Q(base[k] + j) = Q(base[k] + head[k] + j - 1);
      P(base[k] + j) = P(base[k] + head[k] + j - 1);
    }
    for (int j = 1; j <= c - live[k]; ++j) { Q(base[k] + live[k] + j) = NA_REAL; P(base[k] + live[k] + j) = NA_REAL; }
    head[k] = 1; tail[k] = live[k];
  }
  // growth
  std::vector<int> cap(cap0, cap0 + n_inst), off(off0, off0 + n_inst);
  bool grew = false;
  for (R_xlen_t k = 0; k < m; ++k) {
    if (appending[k] && tail[k] >= cap0[pos[k] - 1]) { cap[pos[k] - 1] = std::max(4, 2 * cap0[pos[k] - 1]); grew = true; }
  }
  if (grew) {
    double total_cap = 0;
    for (int c : cap) total_cap += c;
    if (total_cap > INT_MAX) return R_NilValue;
    std::vector<int> new_off(n_inst);
    int run = 0;
    for (R_xlen_t i = 0; i < n_inst; ++i) { new_off[i] = run; run += cap[i]; }
    std::vector<double> nq(static_cast<size_t>(total_cap), NA_REAL), np(static_cast<size_t>(total_cap), NA_REAL);
    for (R_xlen_t i = 0; i < n_inst; ++i) {
      for (int j = 0; j < cap0[i]; ++j) { nq[new_off[i] + j] = q[off0[i] + j]; np[new_off[i] + j] = p[off0[i] + j]; }
    }
    q.swap(nq); p.swap(np); off.swap(new_off);
  }
  for (R_xlen_t a = 0; a < m; ++a) {
    if (!appending[a]) continue;
    const int slot = off[pos[a] - 1] + tail[a] + 1;
    Q(slot) = signed_q[a]; P(slot) = price[a];
    tail[a] = tail[a] + 1;
  }

  // the new book: the input list shallow-copied, changed fields replaced
  SEXP out = PROTECT(Rf_shallow_duplicate(book));
  auto put_int = [&](const char* name, const std::vector<int>& v) {
    SEXP x = PROTECT(Rf_allocVector(INTSXP, v.size())); std::copy(v.begin(), v.end(), INTEGER(x));
    SET_VECTOR_ELT(out, field_index(out, name), x); UNPROTECT(1);
  };
  auto put_dbl = [&](const char* name, const std::vector<double>& v) {
    SEXP x = PROTECT(dbl(v.size())); std::copy(v.begin(), v.end(), REAL(x));
    SET_VECTOR_ELT(out, field_index(out, name), x); UNPROTECT(1);
  };
  auto scatter_int = [&](const char* name, SEXP src, const std::vector<int>& v) {
    SEXP x = PROTECT(Rf_duplicate(src));
    for (R_xlen_t k = 0; k < m; ++k) INTEGER(x)[pos[k] - 1] = v[k];
    SET_VECTOR_ELT(out, field_index(out, name), x); UNPROTECT(1);
  };
  auto scatter_dbl = [&](const char* name, SEXP src, const std::vector<double>& v) {
    SEXP x = PROTECT(Rf_duplicate(src));
    for (R_xlen_t k = 0; k < m; ++k) REAL(x)[pos[k] - 1] = v[k];
    SET_VECTOR_ELT(out, field_index(out, name), x); UNPROTECT(1);
  };
  if (grew) { put_int("offset", off); put_int("capacity", cap); }
  scatter_int("head", head_s, head);
  scatter_int("tail", tail_s, tail);
  put_dbl("lot_qty", q);
  put_dbl("lot_price", p);
  scatter_dbl("net_by_inst", net_s, net);
  scatter_dbl("cost_basis_by_inst", basis_s, new_basis);
  SET_VECTOR_ELT(out, field_index(out, "total_cost_basis"), Rf_ScalarReal(total));
  SET_VECTOR_ELT(out, field_index(out, "realized_pnl"), Rf_ScalarReal(realized));
  SET_VECTOR_ELT(out, field_index(out, "realized_comp"), Rf_ScalarReal(comp));

  const char* an[] = {"position_before", "position_after", "close_qty", "open_qty", "realized_close",
                      "realized_delta", "event_realized", "event_cost_basis"};
  const std::vector<double>* av[] = {&position_before, &net, &close_qty, &open_qty, &realized_close,
                                     &realized_delta, &event_realized, &event_cost_basis};
  SEXP applied = PROTECT(Rf_allocVector(VECSXP, 8)), anames = PROTECT(Rf_allocVector(STRSXP, 8));
  for (int i = 0; i < 8; ++i) {
    SEXP x = PROTECT(dbl(m)); std::copy(av[i]->begin(), av[i]->end(), REAL(x));
    SET_VECTOR_ELT(applied, i, x); SET_STRING_ELT(anames, i, Rf_mkChar(an[i])); UNPROTECT(1);
  }
  Rf_setAttrib(applied, R_NamesSymbol, anames);
  SEXP res = PROTECT(Rf_allocVector(VECSXP, 2)), rnames = PROTECT(Rf_allocVector(STRSXP, 2));
  SET_VECTOR_ELT(res, 0, out); SET_VECTOR_ELT(res, 1, applied);
  SET_STRING_ELT(rnames, 0, Rf_mkChar("book")); SET_STRING_ELT(rnames, 1, Rf_mkChar("applied"));
  Rf_setAttrib(res, R_NamesSymbol, rnames);
  UNPROTECT(5);
  return res;
}
