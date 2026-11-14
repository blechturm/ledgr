// Spike lean_plan_cpp: a compiled port of dev/lean_core/plan.R's
// lean_plan_pulse() for the common path. It performs the R planner's
// floating-point operations in the R planner's order and builds the same
// plan (expected_final_cash, economic_event_kinds, fill and rejection
// groups, reason segments). The cost resolver is the pin's
// ledgr_plan_resolve(), called back into R once per pulse with the same
// arguments (Cut 16 decision 2). It returns R_NilValue, and the R planner
// runs instead, for anything outside the common path: an empty or missing
// execution, a non-finite target delta, an invalid epoch, a short-exposure
// refusal, an undefined cash effect, or an input vector with attributes.

#include "cpp11.hpp"
#include <Rinternals.h>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <numeric>
#include <unordered_set>
#include <vector>

namespace {

SEXP field(SEXP list, const char* name) {
  SEXP names = Rf_getAttrib(list, R_NamesSymbol);
  if (names == R_NilValue) return R_NilValue;
  for (R_xlen_t i = 0; i < Rf_xlength(list); ++i) {
    if (std::strcmp(CHAR(STRING_ELT(names, i)), name) == 0) return VECTOR_ELT(list, i);
  }
  return R_NilValue;
}

bool plain(SEXP x, int type) { return TYPEOF(x) == type && !ANY_ATTRIB(x); }

SEXP ivec(const std::vector<int>& v) {
  SEXP x = PROTECT(Rf_allocVector(INTSXP, v.size()));
  std::copy(v.begin(), v.end(), INTEGER(x));
  UNPROTECT(1);
  return x;
}
SEXP dvec(const std::vector<double>& v) {
  SEXP x = PROTECT(Rf_allocVector(REALSXP, v.size()));
  std::copy(v.begin(), v.end(), REAL(x));
  UNPROTECT(1);
  return x;
}

// A named list from parallel name and value arrays.
SEXP named_list(const std::vector<const char*>& names, const std::vector<SEXP>& values) {
  const int n = static_cast<int>(names.size());
  SEXP out = PROTECT(Rf_allocVector(VECSXP, n)), nm = PROTECT(Rf_allocVector(STRSXP, n));
  for (int i = 0; i < n; ++i) {
    SET_VECTOR_ELT(out, i, values[i]);
    SET_STRING_ELT(nm, i, Rf_mkChar(names[i]));
  }
  Rf_setAttrib(out, R_NamesSymbol, nm);
  UNPROTECT(2);
  return out;
}

struct Segment {
  std::vector<int> offset, count, code;
};

// ledgr_carrier_segments(n, row, code): rows ordered stably, (row, code)
// pairs kept at first occurrence of row * 16 + code, counts per row.
Segment segments(int n, const std::vector<int>& row, const std::vector<int>& code) {
  Segment s;
  s.offset.assign(n, 0);
  s.count.assign(n, 0);
  if (row.empty()) return s;  // lean_plan_empty_segments(n)
  std::vector<int> ord(row.size());
  std::iota(ord.begin(), ord.end(), 0);
  std::stable_sort(ord.begin(), ord.end(), [&](int a, int b) { return row[a] < row[b]; });
  std::unordered_set<long long> seen;
  for (int o : ord) {
    const long long key = static_cast<long long>(row[o]) * 16LL + code[o];
    if (!seen.insert(key).second) continue;
    s.count[row[o] - 1] += 1;
    s.code.push_back(code[o]);
  }
  int run = 0;
  for (int i = 0; i < n; ++i) { s.offset[i] = run; run += s.count[i]; }
  return s;
}

// lean_plan_segment_rows(segment, idx) (1-based idx).
Segment segment_rows(const Segment& s, const std::vector<int>& idx) {
  Segment r;
  r.offset.assign(idx.size(), 0);
  r.count.assign(idx.size(), 0);
  if (s.code.empty()) return r;
  int run = 0;
  for (size_t j = 0; j < idx.size(); ++j) {
    const int i = idx[j] - 1;
    r.count[j] = s.count[i];
    r.offset[j] = run;
    run += s.count[i];
    for (int c = 0; c < s.count[i]; ++c) r.code.push_back(s.code[s.offset[i] + c]);
  }
  return r;
}

template <typename T, typename F>
std::vector<T> gather(const std::vector<int>& idx, F get) {
  std::vector<T> out;
  out.reserve(idx.size());
  for (int i : idx) out.push_back(get(i - 1));
  return out;
}

}  // namespace

[[cpp11::register]]
SEXP spike_plan_pulse(SEXP context_pos_s, SEXP target_qty_s, SEXP position_s, SEXP k_s, SEXP member_s,
                      SEXP execution, SEXP view, SEXP epoch_valid_s, SEXP cost_resolver, SEXP cash_s,
                      SEXP id_rank_s, SEXP resolve_fn) {
  const R_xlen_t n = Rf_xlength(k_s);
  SEXP exec_ts_s = field(execution, "exec_ts"), open_s = field(execution, "open");
  if (n == 0 || !plain(context_pos_s, INTSXP) || !plain(target_qty_s, REALSXP) || !plain(position_s, REALSXP) ||
      !plain(k_s, INTSXP) || !plain(member_s, LGLSXP) || !plain(cash_s, REALSXP) || Rf_xlength(cash_s) != 1 ||
      TYPEOF(exec_ts_s) != REALSXP || Rf_xlength(exec_ts_s) != 1 || std::isnan(REAL(exec_ts_s)[0]) ||
      !plain(open_s, REALSXP) || TYPEOF(epoch_valid_s) != LGLSXP || Rf_xlength(epoch_valid_s) != 1 ||
      LOGICAL(epoch_valid_s)[0] != TRUE || TYPEOF(view) != VECSXP || !plain(id_rank_s, INTSXP)) return R_NilValue;
  SEXP vm_s = field(view, "member"), vc_s = field(view, "reason_count"), vcode_s = field(view, "reason_code");
  if (!plain(vm_s, LGLSXP) || !plain(vc_s, INTSXP) || !plain(vcode_s, INTSXP) || Rf_xlength(vm_s) != n ||
      Rf_xlength(vc_s) != n) return R_NilValue;
  const int* cp = INTEGER(context_pos_s); const double* tq = REAL(target_qty_s); const double* position = REAL(position_s);
  const int* k = INTEGER(k_s); const int* member = LOGICAL(member_s); const double* open_all = REAL(open_s);
  const int* vm = LOGICAL(vm_s); const int* vc = INTEGER(vc_s); const int* vcode = INTEGER(vcode_s);
  const int* id_rank = INTEGER(id_rank_s);
  const double exec_ts = REAL(exec_ts_s)[0];
  const double cash = REAL(cash_s)[0];

  std::vector<int> pos(n), side(n);
  std::vector<double> before(n), delta(n), qty(n), open(n);
  std::vector<char> bad_open(n);
  std::vector<int> informational;
  for (R_xlen_t i = 0; i < n; ++i) {
    pos[i] = cp[k[i] - 1];
    before[i] = position[k[i] - 1];
    delta[i] = tq[k[i] - 1] - before[i];
    if (!std::isfinite(delta[i])) return R_NilValue;  // bad delta: the R planner decides
    side[i] = delta[i] > 0 ? 1 : -1;
    qty[i] = std::fabs(delta[i]);
    const int a = member[k[i] - 1], b = vm[i];
    if (a != NA_LOGICAL && b != NA_LOGICAL && a != b) informational.push_back(static_cast<int>(i) + 1);
    open[i] = open_all[pos[i] - 1];
    bad_open[i] = !std::isfinite(open[i]) || open[i] <= 0;
  }
  std::vector<int> passed;
  for (R_xlen_t i = 0; i < n; ++i) if (!bad_open[i]) passed.push_back(static_cast<int>(i) + 1);

  // the pin's resolver, one call per pulse
  SEXP rs = PROTECT(ivec(gather<int>(passed, [&](int i) { return side[i]; })));
  SEXP rq = PROTECT(dvec(gather<double>(passed, [&](int i) { return qty[i]; })));
  SEXP ro = PROTECT(dvec(gather<double>(passed, [&](int i) { return open[i]; })));
  SEXP call = PROTECT(Rf_lang5(resolve_fn, cost_resolver, rs, rq, ro));
  SEXP resolved = PROTECT(cpp11::safe[Rf_eval](call, R_GlobalEnv));
  SEXP rp_s = field(resolved, "price"), rf_s = field(resolved, "fee");
  std::vector<double> price(n, NA_REAL), fee(n, NA_REAL);
  for (size_t j = 0; j < passed.size(); ++j) {
    price[passed[j] - 1] = REAL(rp_s)[j];
    fee[passed[j] - 1] = REAL(rf_s)[j];
  }
  UNPROTECT(5);

  std::vector<char> bad_price(n);
  std::vector<int> cand;
  for (R_xlen_t i = 0; i < n; ++i) {
    bad_price[i] = !bad_open[i] && !(std::isfinite(price[i]) && price[i] > 0);
    if (!bad_open[i] && !bad_price[i]) cand.push_back(static_cast<int>(i) + 1);
  }
  const size_t nc = cand.size();
  std::vector<double> cash_delta(nc), position_delta(nc);
  std::vector<char> blocked(nc), generator(nc);
  for (size_t j = 0; j < nc; ++j) {
    const int i = cand[j] - 1;
    const bool buy = side[i] > 0;
    cash_delta[j] = buy ? -(qty[i] * price[i] + fee[i]) : +(qty[i] * price[i] - fee[i]);
    position_delta[j] = buy ? qty[i] : -qty[i];
    if (std::isnan(cash_delta[j])) return R_NilValue;  // undefined cash effect: the R planner decides
    const double resulting = before[i] + position_delta[j];
    const double floor_qty = before[i] > 0 ? 0.0 : before[i];
    if (std::isnan(resulting) || resulting < floor_qty) return R_NilValue;  // short exposure refusal
    blocked[j] = vc[i] > 0;
    generator[j] = side[i] == -1 && before[i] > 0 && delta[i] < 0 && cash_delta[j] >= 0 && !blocked[j];
  }
  std::vector<int> early;
  for (R_xlen_t i = 0; i < n; ++i) if (bad_open[i] || bad_price[i]) early.push_back(static_cast<int>(i) + 1);

  // affordability scan: generators first, then the stable-ID rank
  std::vector<int> priority(nc);
  std::iota(priority.begin(), priority.end(), 0);
  if (nc > 1) {
    std::sort(priority.begin(), priority.end(), [&](int a, int b) {
      const int ga = !generator[a], gb = !generator[b];
      if (ga != gb) return ga < gb;
      return id_rank[pos[cand[a] - 1] - 1] < id_rank[pos[cand[b] - 1] - 1];
    });
  }
  std::vector<char> accepted(nc, 0), insufficient(nc, 0);
  double virtual_cash = cash;
  const double tolerance = 1e-8;  // ledgr_availability_cash_tolerance
  for (int idx : priority) {
    const double next_cash = virtual_cash + cash_delta[idx];
    const bool affordable = cash_delta[idx] >= 0 || next_cash >= -tolerance;
    if (!blocked[idx] && affordable) {
      accepted[idx] = 1;
      virtual_cash = next_cash;
    } else if (!affordable) {
      insufficient[idx] = 1;
    }
  }
  std::vector<int> fills, late, short_cash;
  std::vector<double> fill_cash, fill_pos;
  for (size_t j = 0; j < nc; ++j) {
    if (accepted[j]) { fills.push_back(cand[j]); fill_cash.push_back(cash_delta[j]); fill_pos.push_back(position_delta[j]); }
    else late.push_back(cand[j]);
    if (insufficient[j]) short_cash.push_back(cand[j]);
  }

  // reason segments: view reasons, early (2), short cash (3), informational (4)
  std::vector<int> rows, codes;
  for (R_xlen_t i = 0; i < n; ++i) for (int c = 0; c < vc[i]; ++c) rows.push_back(static_cast<int>(i) + 1);
  for (R_xlen_t j = 0; j < Rf_xlength(vcode_s); ++j) codes.push_back(vcode[j]);
  if (rows.size() != codes.size()) return R_NilValue;
  for (int i : early) { rows.push_back(i); codes.push_back(2); }
  for (int i : short_cash) { rows.push_back(i); codes.push_back(3); }
  for (int i : informational) { rows.push_back(i); codes.push_back(4); }
  const Segment seg = segments(static_cast<int>(n), rows, codes);

  std::vector<int> rejected(early);
  rejected.insert(rejected.end(), late.begin(), late.end());
  const Segment info = segment_rows(seg, fills), reasons = segment_rows(seg, rejected);
  std::vector<int> emit(early.size(), 1);
  emit.insert(emit.end(), late.size(), 2);
  std::vector<double> resolved_price(early.size(), NA_REAL);
  for (int i : late) resolved_price.push_back(price[i - 1]);
  std::vector<int> primary;
  for (size_t j = 0; j < rejected.size(); ++j) {
    const size_t at = static_cast<size_t>(reasons.offset[j]);  // code[offset + 1] in R
    primary.push_back(at < reasons.code.size() ? reasons.code[at] : NA_INTEGER);
  }
  auto exec_rep = [&](size_t len) {
    SEXP x = PROTECT(Rf_allocVector(REALSXP, len));
    for (size_t j = 0; j < len; ++j) REAL(x)[j] = exec_ts;
    DUPLICATE_ATTRIB(x, exec_ts_s);
    UNPROTECT(1);
    return x;
  };
  std::vector<double> planned(fills.size());
  for (size_t j = 0; j < fills.size(); ++j) planned[j] = before[fills[j] - 1] + fill_pos[j];

  int nprot = 0;
  auto keep = [&](SEXP x) { PROTECT(x); ++nprot; return x; };
  SEXP fill = keep(named_list(
    {"k", "pos", "side", "qty", "price", "fee", "cash_delta", "position_delta", "exec_ts", "position_before",
     "planned_position_after", "info_offset", "info_count", "info_code"},
    {keep(ivec(gather<int>(fills, [&](int i) { return k[i]; }))), keep(ivec(gather<int>(fills, [&](int i) { return pos[i]; }))),
     keep(ivec(gather<int>(fills, [&](int i) { return side[i]; }))), keep(dvec(gather<double>(fills, [&](int i) { return qty[i]; }))),
     keep(dvec(gather<double>(fills, [&](int i) { return price[i]; }))), keep(dvec(gather<double>(fills, [&](int i) { return fee[i]; }))),
     keep(dvec(fill_cash)), keep(dvec(fill_pos)), keep(exec_rep(fills.size())),
     keep(dvec(gather<double>(fills, [&](int i) { return before[i]; }))), keep(dvec(planned)),
     keep(ivec(info.offset)), keep(ivec(info.count)), keep(ivec(info.code))}));
  SEXP rejection = keep(named_list(
    {"k", "pos", "emit", "primary", "reason_offset", "reason_count", "reason_code", "resolved_price", "exec_ts", "position"},
    {keep(ivec(gather<int>(rejected, [&](int i) { return k[i]; }))), keep(ivec(gather<int>(rejected, [&](int i) { return pos[i]; }))),
     keep(ivec(emit)), keep(ivec(primary)), keep(ivec(reasons.offset)), keep(ivec(reasons.count)), keep(ivec(reasons.code)),
     keep(dvec(resolved_price)), keep(exec_rep(rejected.size())),
     keep(dvec(gather<double>(rejected, [&](int i) { return before[i]; })))}));
  SEXP kinds = keep(fills.empty() ? Rf_allocVector(INTSXP, 0) : Rf_ScalarInteger(1));
  SEXP out = named_list({"expected_final_cash", "economic_event_kinds", "fill", "rejection"},
                        {keep(Rf_ScalarReal(virtual_cash)), kinds, fill, rejection});
  UNPROTECT(nprot);
  return out;
}
