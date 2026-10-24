#include <cpp11.hpp>
#include <Rinternals.h>

#include <algorithm>
#include <type_traits>
#include <vector>

static void ledgr_history_cpp_check(bool ok, const char* message) {
  if (!ok) cpp11::stop("%s", message);
}

static SEXP ledgr_history_cpp_run_result(const std::vector<int>& off,
                                         const std::vector<int>& count,
                                         const std::vector<int>& start,
                                         const std::vector<int>& end) {
  SEXP off_sxp = PROTECT(Rf_allocVector(INTSXP, off.size()));
  SEXP count_sxp = PROTECT(Rf_allocVector(INTSXP, count.size()));
  SEXP start_sxp = PROTECT(Rf_allocVector(INTSXP, start.size()));
  SEXP end_sxp = PROTECT(Rf_allocVector(INTSXP, end.size()));
  std::copy(off.begin(), off.end(), INTEGER(off_sxp));
  std::copy(count.begin(), count.end(), INTEGER(count_sxp));
  std::copy(start.begin(), start.end(), INTEGER(start_sxp));
  std::copy(end.begin(), end.end(), INTEGER(end_sxp));
  SEXP out_sxp = PROTECT(Rf_allocVector(VECSXP, 4));
  SET_VECTOR_ELT(out_sxp, 0, off_sxp);
  SET_VECTOR_ELT(out_sxp, 1, count_sxp);
  SET_VECTOR_ELT(out_sxp, 2, start_sxp);
  SET_VECTOR_ELT(out_sxp, 3, end_sxp);
  SEXP names_sxp = PROTECT(Rf_allocVector(STRSXP, 4));
  SET_STRING_ELT(names_sxp, 0, Rf_mkChar("off"));
  SET_STRING_ELT(names_sxp, 1, Rf_mkChar("count"));
  SET_STRING_ELT(names_sxp, 2, Rf_mkChar("start"));
  SET_STRING_ELT(names_sxp, 3, Rf_mkChar("end"));
  Rf_setAttrib(out_sxp, R_NamesSymbol, names_sxp);
  UNPROTECT(6);
  return out_sxp;
}

class ledgr_history_source {
 private:
  const double* data_;
  int nrow_;

 public:
  ledgr_history_source(SEXP source_sxp, int nrow)
      : data_(REAL(source_sxp)), nrow_(nrow) {}

  template <bool trace>
  inline double read(int row, int column, std::vector<int>* access) const {
    const R_xlen_t index = row + static_cast<R_xlen_t>(column) * nrow_;
    if constexpr (trace) access->push_back(static_cast<int>(index + 1));
    return data_[index];
  }
};

// Sparse maximal runs of non-finite cells. They are prepared once with the
// immutable substrate, then let an ordinary read distinguish a leading gap
// from an expired carry without reading any value before its bounded carry
// dependency. Storage is proportional to gap runs, not source cells.
[[cpp11::register]]
SEXP ledgr_cpp_history_gap_runs(SEXP stored_sxp) {
  ledgr_history_cpp_check(TYPEOF(stored_sxp) == REALSXP &&
                              Rf_isMatrix(stored_sxp),
                          "Stored history bars must be a double matrix.");
  SEXP dim_sxp = Rf_getAttrib(stored_sxp, R_DimSymbol);
  const int n_row = INTEGER(dim_sxp)[0];
  const int n_col = INTEGER(dim_sxp)[1];
  const double* stored = REAL(stored_sxp);
  std::vector<int> off(n_row);
  std::vector<int> count(n_row);
  std::vector<int> start;
  std::vector<int> end;

  for (int row = 0; row < n_row; ++row) {
    off[row] = static_cast<int>(start.size()) + 1;
    int column = 0;
    while (column < n_col) {
      while (column < n_col && R_FINITE(
          stored[row + static_cast<R_xlen_t>(column) * n_row])) {
        ++column;
      }
      if (column == n_col) break;
      const int first = column;
      while (column < n_col && !R_FINITE(
          stored[row + static_cast<R_xlen_t>(column) * n_row])) {
        ++column;
      }
      start.push_back(first + 1);
      end.push_back(column);
      count[row] += 1;
    }
  }

  return ledgr_history_cpp_run_result(off, count, start, end);
}

// Sparse maximal FALSE runs for lifetime masks. Prepared once with each
// immutable base/overlay mask, they make restart detection independent of the
// length of a missing price run.
[[cpp11::register]]
SEXP ledgr_cpp_history_false_runs(SEXP expected_sxp) {
  ledgr_history_cpp_check(TYPEOF(expected_sxp) == LGLSXP &&
                              Rf_isMatrix(expected_sxp),
                          "Expected-session history must be a logical matrix.");
  SEXP dim_sxp = Rf_getAttrib(expected_sxp, R_DimSymbol);
  const int n_row = INTEGER(dim_sxp)[0];
  const int n_col = INTEGER(dim_sxp)[1];
  const int* expected = LOGICAL(expected_sxp);
  std::vector<int> off(n_row);
  std::vector<int> count(n_row);
  std::vector<int> start;
  std::vector<int> end;
  for (int row = 0; row < n_row; ++row) {
    off[row] = static_cast<int>(start.size()) + 1;
    int column = 0;
    while (column < n_col) {
      while (column < n_col && expected[
          row + static_cast<R_xlen_t>(column) * n_row] == TRUE) {
        ++column;
      }
      if (column == n_col) break;
      const int first = column;
      while (column < n_col && expected[
          row + static_cast<R_xlen_t>(column) * n_row] == FALSE) {
        ++column;
      }
      start.push_back(first + 1);
      end.push_back(column);
      count[row] += 1;
    }
  }
  return ledgr_history_cpp_run_result(off, count, start, end);
}

#if defined(__GNUC__) && !defined(__clang__)
#pragma GCC push_options
#pragma GCC optimize("O3")
#endif

// Copy one requested window directly into its public sessions x instruments
// orientation. Missing cells inspect at most the declared carry horizon in
// the stored plane, using the already-prepared lifetime and terminal masks.
// This fuses manifestation and compact admission counts without a second
// numeric payload, a full-source scan or another retained treatment index.
[[cpp11::register]]
SEXP ledgr_cpp_history_bar_compact(SEXP stored_sxp,
                                   SEXP rows_sxp,
                                   SEXP columns_sxp,
                                   SEXP expected_sxp,
                                   SEXP terminal_first_sxp,
                                   SEXP dependency_first_sxp,
                                   SEXP override_row_sxp,
                                   SEXP override_expected_sxp,
                                   SEXP override_terminal_sxp,
                                   SEXP barrier_off_sxp,
                                   SEXP barrier_count_sxp,
                                   SEXP barrier_start_sxp,
                                   SEXP barrier_end_sxp,
                                   SEXP override_barrier_off_sxp,
                                   SEXP override_barrier_count_sxp,
                                   SEXP override_barrier_start_sxp,
                                   SEXP override_barrier_end_sxp,
                                   SEXP gap_off_sxp,
                                   SEXP gap_count_sxp,
                                   SEXP gap_start_sxp,
                                   SEXP gap_end_sxp,
                                   SEXP max_carry_sessions_sxp,
                                   SEXP carry_allowed_sxp,
                                   SEXP min_observations_sxp,
                                   SEXP axis_names_sxp,
                                   SEXP instrument_ids_sxp,
                                   SEXP wide_sxp,
                                   SEXP trace_access_sxp) {
  ledgr_history_cpp_check(TYPEOF(stored_sxp) == REALSXP &&
                              Rf_isMatrix(stored_sxp),
                          "Stored history bars must be a double matrix.");
  ledgr_history_cpp_check(TYPEOF(rows_sxp) == INTSXP &&
                              TYPEOF(columns_sxp) == INTSXP,
                          "History rows and columns must be integer.");
  ledgr_history_cpp_check(TYPEOF(expected_sxp) == LGLSXP &&
                              Rf_isMatrix(expected_sxp) &&
                              TYPEOF(terminal_first_sxp) == INTSXP,
                          "History masks have invalid types.");
  ledgr_history_cpp_check(TYPEOF(override_row_sxp) == INTSXP &&
                              TYPEOF(override_expected_sxp) == LGLSXP &&
                              Rf_isMatrix(override_expected_sxp) &&
                              TYPEOF(override_terminal_sxp) == INTSXP,
                          "History mask overrides have invalid types.");
  ledgr_history_cpp_check(TYPEOF(gap_off_sxp) == INTSXP &&
                              TYPEOF(gap_count_sxp) == INTSXP &&
                              TYPEOF(gap_start_sxp) == INTSXP &&
                              TYPEOF(gap_end_sxp) == INTSXP,
                          "History gap summaries have invalid types.");
  ledgr_history_cpp_check(TYPEOF(barrier_off_sxp) == INTSXP &&
                              TYPEOF(barrier_count_sxp) == INTSXP &&
                              TYPEOF(barrier_start_sxp) == INTSXP &&
                              TYPEOF(barrier_end_sxp) == INTSXP &&
                              TYPEOF(override_barrier_off_sxp) == INTSXP &&
                              TYPEOF(override_barrier_count_sxp) == INTSXP &&
                              TYPEOF(override_barrier_start_sxp) == INTSXP &&
                              TYPEOF(override_barrier_end_sxp) == INTSXP,
                          "History barrier summaries have invalid types.");

  SEXP stored_dim = Rf_getAttrib(stored_sxp, R_DimSymbol);
  const int source_nrow = INTEGER(stored_dim)[0];
  const int source_ncol = INTEGER(stored_dim)[1];
  const ledgr_history_source source(stored_sxp, source_nrow);
  const int n_instrument = static_cast<int>(XLENGTH(rows_sxp));
  const int n_time = static_cast<int>(XLENGTH(columns_sxp));
  SEXP expected_dim = Rf_getAttrib(expected_sxp, R_DimSymbol);
  ledgr_history_cpp_check(INTEGER(expected_dim)[0] == source_nrow &&
                              INTEGER(expected_dim)[1] == source_ncol &&
                              XLENGTH(terminal_first_sxp) == source_nrow,
                          "History masks must align with the stored bars.");

  const int dependency_first = Rf_asInteger(dependency_first_sxp);
  const int max_carry_sessions = Rf_asInteger(max_carry_sessions_sxp);
  ledgr_history_cpp_check(dependency_first > 0 && max_carry_sessions >= 0,
                          "History carry bounds are invalid.");
  const int* columns = INTEGER(columns_sxp);
  const int dependency_width = n_time == 0
      ? 0
      : columns[n_time - 1] - dependency_first + 1;
  const int n_override = static_cast<int>(XLENGTH(override_row_sxp));
  SEXP override_dim = Rf_getAttrib(override_expected_sxp, R_DimSymbol);
  ledgr_history_cpp_check(INTEGER(override_dim)[0] == n_override &&
                              INTEGER(override_dim)[1] == dependency_width &&
                              XLENGTH(override_terminal_sxp) == n_override,
                          "History mask overrides must align with the request.");
  ledgr_history_cpp_check(XLENGTH(gap_off_sxp) == source_nrow &&
                              XLENGTH(gap_count_sxp) == source_nrow &&
                              XLENGTH(gap_start_sxp) == XLENGTH(gap_end_sxp),
                          "History gap summaries must align with the stored bars.");
  ledgr_history_cpp_check(XLENGTH(barrier_off_sxp) == source_nrow &&
                              XLENGTH(barrier_count_sxp) == source_nrow &&
                              XLENGTH(barrier_start_sxp) == XLENGTH(barrier_end_sxp) &&
                              XLENGTH(override_barrier_off_sxp) == n_override &&
                              XLENGTH(override_barrier_count_sxp) == n_override &&
                              XLENGTH(override_barrier_start_sxp) ==
                                XLENGTH(override_barrier_end_sxp),
                          "History barrier summaries must align with their masks.");
  const bool wide = Rf_asLogical(wide_sxp) == TRUE;
  const bool carry_allowed = Rf_asLogical(carry_allowed_sxp) == TRUE;
  const bool trace_access = Rf_asLogical(trace_access_sxp) == TRUE;
  const int min_observations = Rf_asInteger(min_observations_sxp);
  ledgr_history_cpp_check(min_observations >= 0,
                          "History observation requirement is invalid.");
  ledgr_history_cpp_check(TYPEOF(axis_names_sxp) == STRSXP &&
                              TYPEOF(instrument_ids_sxp) == STRSXP &&
                              XLENGTH(axis_names_sxp) == n_time &&
                              XLENGTH(instrument_ids_sxp) == n_instrument,
                          "History manifestation names must align with the request.");

  SEXP value_sxp = PROTECT(
      wide ? Rf_allocVector(VECSXP, n_instrument)
           : Rf_allocMatrix(REALSXP, n_time, n_instrument));
  if (wide) {
    for (int instrument = 0; instrument < n_instrument; ++instrument) {
      SEXP column_sxp = PROTECT(Rf_allocVector(REALSXP, n_time));
      SET_VECTOR_ELT(value_sxp, instrument, column_sxp);
      UNPROTECT(1);
    }
  }
  if (!wide) {
    SEXP dimnames_sxp = PROTECT(Rf_allocVector(VECSXP, 2));
    SET_VECTOR_ELT(dimnames_sxp, 0, axis_names_sxp);
    SET_VECTOR_ELT(dimnames_sxp, 1, instrument_ids_sxp);
    Rf_setAttrib(value_sxp, R_DimNamesSymbol, dimnames_sxp);
    UNPROTECT(1);
  }
  SEXP finite_sxp = PROTECT(Rf_allocVector(INTSXP, n_instrument));
  SEXP carried_sxp = PROTECT(Rf_allocVector(INTSXP, n_instrument));
  SEXP used_before_sxp = PROTECT(Rf_allocVector(LGLSXP, n_instrument));
  SEXP structural_sxp = PROTECT(Rf_allocVector(LGLSXP, n_instrument));
  SEXP expired_sxp = PROTECT(Rf_allocVector(LGLSXP, n_instrument));

  double* matrix_value = wide ? nullptr : REAL(value_sxp);
  const int* rows = INTEGER(rows_sxp);
  const int* expected = LOGICAL(expected_sxp);
  const int* terminal_first = INTEGER(terminal_first_sxp);
  const int* override_row = INTEGER(override_row_sxp);
  const int* override_expected = LOGICAL(override_expected_sxp);
  const int* override_terminal = INTEGER(override_terminal_sxp);
  const int* barrier_off = INTEGER(barrier_off_sxp);
  const int* barrier_count = INTEGER(barrier_count_sxp);
  const int* barrier_start = INTEGER(barrier_start_sxp);
  const int* barrier_end = INTEGER(barrier_end_sxp);
  const int* override_barrier_off = INTEGER(override_barrier_off_sxp);
  const int* override_barrier_count = INTEGER(override_barrier_count_sxp);
  const int* override_barrier_start = INTEGER(override_barrier_start_sxp);
  const int* override_barrier_end = INTEGER(override_barrier_end_sxp);
  const int* gap_off = INTEGER(gap_off_sxp);
  const int* gap_count = INTEGER(gap_count_sxp);
  const int* gap_start = INTEGER(gap_start_sxp);
  const int* gap_end = INTEGER(gap_end_sxp);
  int* finite = INTEGER(finite_sxp);
  int* carried = INTEGER(carried_sxp);
  int* used_before = LOGICAL(used_before_sxp);
  int* structural = LOGICAL(structural_sxp);
  int* expired = LOGICAL(expired_sxp);
  std::vector<int> source_access;
  if (trace_access) {
    source_access.reserve(static_cast<size_t>(n_instrument) * n_time);
  }

  std::vector<int> override_map(n_instrument, -1);
  for (int at = 0; at < n_override; ++at) {
    const int local_row = override_row[at] - 1;
    ledgr_history_cpp_check(local_row >= 0 && local_row < n_instrument,
                            "History mask override row is outside the request.");
    override_map[local_row] = at;
  }

  for (int time = 0; time < n_time; ++time) {
    const int source_column = columns[time] - 1;
    ledgr_history_cpp_check(source_column >= 0 && source_column < source_ncol,
                            "History column is outside the stored bar matrix.");
  }

  // Compile distinct traced and ordinary loops. The exact review oracle can
  // observe every source access, while the production hot path contains no
  // per-cell tracing branch.
  auto process = [&](auto trace_tag) {
  constexpr bool trace = decltype(trace_tag)::value;
  auto read_source = [&](int row, int column) {
    return source.read<trace>(row, column, &source_access);
  };
  for (int instrument = 0; instrument < n_instrument; ++instrument) {
    finite[instrument] = 0;
    carried[instrument] = 0;
    used_before[instrument] = FALSE;
    structural[instrument] = FALSE;
    expired[instrument] = FALSE;
    const int source_row = rows[instrument] - 1;
    ledgr_history_cpp_check(source_row >= 0 && source_row < source_nrow,
                            "History row is outside the stored bar matrix.");
    const int override_at = override_map[instrument];
    const int terminal_at = override_at >= 0
        ? override_terminal[override_at]
        : terminal_first[source_row];
    double* target = wide
        ? REAL(VECTOR_ELT(value_sxp, instrument))
        : matrix_value + static_cast<R_xlen_t>(instrument) * n_time;
    auto is_expected = [&](int column) {
      return override_at >= 0
          ? override_expected[
              override_at + static_cast<R_xlen_t>(
                column + 1 - dependency_first) * n_override] == TRUE
          : expected[source_row + static_cast<R_xlen_t>(column) * source_nrow] == TRUE;
    };
    auto has_lifetime_barrier = [&](int first_column, int last_column) {
      const int* run_off = override_at >= 0
          ? override_barrier_off : barrier_off;
      const int* run_count = override_at >= 0
          ? override_barrier_count : barrier_count;
      const int* run_start = override_at >= 0
          ? override_barrier_start : barrier_start;
      const int* run_end = override_at >= 0
          ? override_barrier_end : barrier_end;
      const int run_row = override_at >= 0 ? override_at : source_row;
      int low = run_off[run_row] - 1;
      int high = low + run_count[run_row];
      while (low < high) {
        const int middle = low + (high - low) / 2;
        if (run_end[middle] < first_column + 1) {
          low = middle + 1;
        } else {
          high = middle;
        }
      }
      const int limit = run_off[run_row] - 1 + run_count[run_row];
      return low < limit && run_start[low] <= last_column + 1;
    };

    const int first_gap = gap_off[source_row] - 1;
    const int n_gap = gap_count[source_row];
    int gap_at = first_gap;

    for (int time = 0; time < n_time; ++time) {
      const int source_column = columns[time] - 1;
      const double cell = read_source(source_row, source_column);
      target[time] = cell;
      if (R_FINITE(cell)) {
        finite[instrument] += 1;
        continue;
      }
      const bool current_expected = is_expected(source_column);
      const bool current_terminal = source_column + 1 >= terminal_at;
      if (!current_expected || current_terminal) {
        structural[instrument] = TRUE;
        continue;
      }

      while (gap_at < first_gap + n_gap && gap_end[gap_at] < source_column + 1) {
        ++gap_at;
      }
      ledgr_history_cpp_check(gap_at < first_gap + n_gap &&
                                  gap_start[gap_at] <= source_column + 1 &&
                                  source_column + 1 <= gap_end[gap_at],
                              "History gap summary does not cover a missing cell.");
      const int candidate = gap_start[gap_at] - 2;
      // A gap can cross an inactive interval and then re-enter an expected
      // lifetime. That restart remains structural even when the returned
      // window begins after the interval, and even when this field cannot be
      // carried. Inspect mask state only; source values still pass solely
      // through read_source().
      const bool barrier = has_lifetime_barrier(
        std::max(0, candidate), source_column);
      if (barrier) {
        structural[instrument] = TRUE;
        continue;
      }
      if (!carry_allowed || candidate < 0) continue;
      const int age = source_column - candidate;
      if (age > max_carry_sessions) {
        expired[instrument] = TRUE;
        continue;
      }
      ledgr_history_cpp_check(candidate + 1 >= dependency_first,
                              "History carry source is outside its declared dependency.");
      const double carried_value = read_source(source_row, candidate);
      ledgr_history_cpp_check(R_FINITE(carried_value),
                              "History gap summary names a non-finite carry source.");
      target[time] = carried_value;
      finite[instrument] += 1;
      carried[instrument] += 1;
      if (candidate + 1 < columns[0]) used_before[instrument] = TRUE;
    }
    if (finite[instrument] < min_observations) {
      for (int time = 0; time < n_time; ++time) {
        const int source_column = columns[time] - 1;
        if (!is_expected(source_column) || source_column + 1 >= terminal_at) {
          structural[instrument] = TRUE;
          break;
        }
      }
    }
  }
  };
  if (trace_access) {
    process(std::true_type{});
  } else {
    process(std::false_type{});
  }

  SEXP access_sxp = PROTECT(Rf_allocVector(INTSXP, source_access.size()));
  std::copy(source_access.begin(), source_access.end(), INTEGER(access_sxp));
  SEXP out_sxp = PROTECT(Rf_allocVector(VECSXP, 7));
  SET_VECTOR_ELT(out_sxp, 0, value_sxp);
  SET_VECTOR_ELT(out_sxp, 1, finite_sxp);
  SET_VECTOR_ELT(out_sxp, 2, carried_sxp);
  SET_VECTOR_ELT(out_sxp, 3, used_before_sxp);
  SET_VECTOR_ELT(out_sxp, 4, structural_sxp);
  SET_VECTOR_ELT(out_sxp, 5, expired_sxp);
  SET_VECTOR_ELT(out_sxp, 6, access_sxp);
  SEXP names_sxp = PROTECT(Rf_allocVector(STRSXP, 7));
  SET_STRING_ELT(names_sxp, 0, Rf_mkChar("value"));
  SET_STRING_ELT(names_sxp, 1, Rf_mkChar("finite_observation_count"));
  SET_STRING_ELT(names_sxp, 2, Rf_mkChar("carried_input_count"));
  SET_STRING_ELT(names_sxp, 3, Rf_mkChar("used_before_row"));
  SET_STRING_ELT(names_sxp, 4, Rf_mkChar("structural"));
  SET_STRING_ELT(names_sxp, 5, Rf_mkChar("expired"));
  SET_STRING_ELT(names_sxp, 6, Rf_mkChar("source_access"));
  Rf_setAttrib(out_sxp, R_NamesSymbol, names_sxp);
  UNPROTECT(9);
  return out_sxp;
}

#if defined(__GNUC__) && !defined(__clang__)
#pragma GCC pop_options
#endif
