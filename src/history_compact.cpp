#include <cpp11.hpp>
#include <Rinternals.h>

#include <algorithm>
#include <vector>

static void ledgr_history_cpp_check(bool ok, const char* message) {
  if (!ok) cpp11::stop("%s", message);
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
                                   SEXP max_carry_sessions_sxp,
                                   SEXP axis_names_sxp,
                                   SEXP instrument_ids_sxp,
                                   SEXP wide_sxp) {
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

  SEXP stored_dim = Rf_getAttrib(stored_sxp, R_DimSymbol);
  const int source_nrow = INTEGER(stored_dim)[0];
  const int source_ncol = INTEGER(stored_dim)[1];
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
  const bool wide = Rf_asLogical(wide_sxp) == TRUE;
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

  const double* stored = REAL(stored_sxp);
  double* matrix_value = wide ? nullptr : REAL(value_sxp);
  const int* rows = INTEGER(rows_sxp);
  const int* expected = LOGICAL(expected_sxp);
  const int* terminal_first = INTEGER(terminal_first_sxp);
  const int* override_row = INTEGER(override_row_sxp);
  const int* override_expected = LOGICAL(override_expected_sxp);
  const int* override_terminal = INTEGER(override_terminal_sxp);
  int* finite = INTEGER(finite_sxp);
  int* carried = INTEGER(carried_sxp);
  int* used_before = LOGICAL(used_before_sxp);

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

  for (int instrument = 0; instrument < n_instrument; ++instrument) {
    finite[instrument] = 0;
    carried[instrument] = 0;
    used_before[instrument] = FALSE;
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

    for (int time = 0; time < n_time; ++time) {
      const int source_column = columns[time] - 1;
      const double cell = stored[
          source_row + static_cast<R_xlen_t>(source_column) * source_nrow];
      target[time] = cell;
      if (R_FINITE(cell)) {
        finite[instrument] += 1;
        continue;
      }

      const int dependency_column = source_column + 1 - dependency_first;
      const bool current_expected = override_at >= 0
          ? override_expected[
              override_at + static_cast<R_xlen_t>(dependency_column) * n_override]
          : expected[source_row + static_cast<R_xlen_t>(source_column) * source_nrow];
      if (!current_expected || source_column + 1 >= terminal_at) continue;

      const int lower = std::max(0, source_column - max_carry_sessions);
      for (int candidate = source_column - 1; candidate >= lower; --candidate) {
        const int dependency_candidate = candidate + 1 - dependency_first;
        const bool candidate_expected = override_at >= 0
            ? override_expected[
                override_at + static_cast<R_xlen_t>(dependency_candidate) * n_override]
            : expected[source_row + static_cast<R_xlen_t>(candidate) * source_nrow];
        if (!candidate_expected || candidate + 1 >= terminal_at) break;
        const double carried_value = stored[
            source_row + static_cast<R_xlen_t>(candidate) * source_nrow];
        if (R_FINITE(carried_value)) {
          target[time] = carried_value;
          finite[instrument] += 1;
          carried[instrument] += 1;
          if (candidate + 1 < columns[0]) used_before[instrument] = TRUE;
          break;
        }
      }
    }
  }

  SEXP out_sxp = PROTECT(Rf_allocVector(VECSXP, 4));
  SET_VECTOR_ELT(out_sxp, 0, value_sxp);
  SET_VECTOR_ELT(out_sxp, 1, finite_sxp);
  SET_VECTOR_ELT(out_sxp, 2, carried_sxp);
  SET_VECTOR_ELT(out_sxp, 3, used_before_sxp);
  SEXP names_sxp = PROTECT(Rf_allocVector(STRSXP, 4));
  SET_STRING_ELT(names_sxp, 0, Rf_mkChar("value"));
  SET_STRING_ELT(names_sxp, 1, Rf_mkChar("finite_observation_count"));
  SET_STRING_ELT(names_sxp, 2, Rf_mkChar("carried_input_count"));
  SET_STRING_ELT(names_sxp, 3, Rf_mkChar("used_before_row"));
  Rf_setAttrib(out_sxp, R_NamesSymbol, names_sxp);
  UNPROTECT(6);
  return out_sxp;
}

#if defined(__GNUC__) && !defined(__clang__)
#pragma GCC pop_options
#endif
