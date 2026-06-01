# Spike 14: yyjsonr canonical_json write byte-identity test
#
# Context: LDG-2493's read-path spike was conservative; LDG-2494 takes the
# next step. Empirically test whether yyjsonr::write_json_str produces
# byte-identical output to jsonlite::toJSON for the input shapes
# canonical_json accepts in production.
#
# Production options: jsonlite::toJSON(payload, auto_unbox = TRUE,
# null = "null", na = "null", digits = NA, pretty = FALSE) from
# R/config-canonical-json.R:115-122.
#
# Pre-CRAN blast radius is small per the audit (no hard-coded hash
# literals in tests; parity history gitignored). If yyjsonr can produce
# byte-identical output (or consistently different output), the
# canonical_json switch is a v0.1.8.9 line item.

suppressWarnings(suppressMessages({
  library(jsonlite)
  library(yyjsonr)
}))

# Replicate ledgr's canonicalize() pre-step from R/config-canonical-json.R
canonicalize <- function(obj) {
  if (is.null(obj)) return(NULL)
  if (inherits(obj, "POSIXt")) {
    obj <- as.POSIXct(obj, tz = "UTC")
    return(format(obj, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  }
  if (is.factor(obj)) return(as.character(obj))
  if (is.atomic(obj)) {
    if (!is.null(names(obj)) && length(obj) > 0) {
      nm <- names(obj)
      ord <- order(nm)
      obj <- as.list(obj)
      names(obj) <- nm
      obj <- obj[ord]
      return(lapply(obj, canonicalize))
    }
    return(obj)
  }
  if (is.list(obj)) {
    nm <- names(obj)
    if (!is.null(nm)) {
      ord <- order(nm)
      obj <- obj[ord]
      nm <- nm[ord]
      names(obj) <- nm
    }
    return(lapply(obj, canonicalize))
  }
  obj
}

# Production jsonlite call from R/config-canonical-json.R:115-122
jsonlite_canonical <- function(payload) {
  jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null",
                   na = "null", digits = NA, pretty = FALSE)
}

# yyjsonr equivalent — try to match as closely as possible
yyjsonr_canonical <- function(payload, opts = NULL) {
  if (is.null(opts)) {
    opts <- yyjsonr::opts_write_json(
      pretty = FALSE,
      auto_unbox = TRUE,
      digits = -1L,
      null = "null",
      num_specials = "null"
    )
  }
  yyjsonr::write_json_str(payload, opts = opts)
}

# Test fixtures spanning all canonical_json input shapes
fixtures <- list(
  scalar_int = 42L,
  scalar_double = 3.14,
  scalar_string = "hello",
  scalar_logical = TRUE,
  empty_named_list = setNames(list(), character()),
  empty_unnamed_list = list(),
  simple_list = list(a = 1L, b = 2.5, c = "three"),
  nested_list = list(outer = list(inner = list(deep = 42L)), sibling = "value"),
  null_value = list(x = NULL, y = 1L),
  na_value = list(x = NA, y = 1L),
  posixt = list(ts = as.POSIXct("2026-01-01 12:34:56", tz = "UTC")),
  numeric_precision_tiny = list(x = 1e-12),
  numeric_precision_huge = list(x = 1e10),
  numeric_precision_max = list(x = .Machine$double.xmax / 1e10),
  numeric_integer_lookalike = list(x = 1.0),
  numeric_irrational = list(x = pi),
  string_with_quote = list(x = 'has "quote"'),
  string_with_backslash = list(x = "has \\ backslash"),
  string_with_newline = list(x = "line1\nline2"),
  string_unicode = list(x = "é 中"),
  bool_true = list(x = TRUE),
  bool_false = list(x = FALSE),
  meta_fill = list(cash_delta = -100, position_delta = 1, realized_pnl = NULL),
  meta_realized = list(cash_delta = 100, position_delta = -1,
                      realized_pnl = 50.75),
  opening_position = list(source = "opening_position", cash_delta = 0,
                          position_delta = 100, cost_basis = 50.5,
                          opening_position = TRUE)
)

cat("=== yyjsonr canonical_json write byte-identity spike ===\n")
cat(sprintf("jsonlite version: %s\n", as.character(packageVersion("jsonlite"))))
cat(sprintf("yyjsonr version : %s\n\n", as.character(packageVersion("yyjsonr"))))

cat("=== per-fixture byte comparison ===\n")
results <- data.frame(
  fixture = character(),
  jsonlite_bytes = character(),
  yyjsonr_bytes = character(),
  identical = logical(),
  diff_summary = character(),
  stringsAsFactors = FALSE
)
for (name in names(fixtures)) {
  payload <- canonicalize(fixtures[[name]])
  jl <- as.character(jsonlite_canonical(payload))
  yy <- tryCatch(as.character(yyjsonr_canonical(payload)),
                 error = function(e) paste0("ERROR: ", conditionMessage(e)))

  ident <- identical(jl, yy)
  # Characterize differences
  if (ident) {
    diff <- "identical"
  } else if (grepl("^ERROR", yy)) {
    diff <- yy
  } else {
    jl_len <- nchar(jl)
    yy_len <- nchar(yy)
    len_diff <- yy_len - jl_len
    # Find first differing character
    same_prefix <- 0L
    for (i in seq_len(min(jl_len, yy_len))) {
      if (substr(jl, i, i) == substr(yy, i, i)) {
        same_prefix <- i
      } else {
        break
      }
    }
    diff <- sprintf("differ at char %d (len jl=%d yy=%d, delta=%d)",
                    same_prefix + 1L, jl_len, yy_len, len_diff)
  }

  results <- rbind(results, data.frame(
    fixture = name,
    jsonlite_bytes = jl,
    yyjsonr_bytes = if (nchar(yy) <= 80) yy else paste0(substr(yy, 1, 77), "..."),
    identical = ident,
    diff_summary = diff,
    stringsAsFactors = FALSE
  ))

  status <- if (ident) "OK" else "DIFFER"
  cat(sprintf("  [%-6s] %-30s : %s\n", status, name, diff))
}

n_total <- nrow(results)
n_ident <- sum(results$identical)
cat(sprintf("\nOverall: %d/%d byte-identical (%.1f%%)\n",
            n_ident, n_total, 100 * n_ident / n_total))

# Show the actual byte output of all non-identical cases for inspection
non_ident <- results[!results$identical, ]
if (nrow(non_ident) > 0) {
  cat("\n=== detailed byte diff for non-identical cases ===\n")
  for (i in seq_len(nrow(non_ident))) {
    r <- non_ident[i, ]
    cat(sprintf("\n--- fixture: %s ---\n", r$fixture))
    cat(sprintf("jsonlite (%d chars): %s\n", nchar(r$jsonlite_bytes), r$jsonlite_bytes))
    cat(sprintf("yyjsonr  (%d chars): %s\n", nchar(r$yyjsonr_bytes), r$yyjsonr_bytes))
  }
}

# Timing at production scale: state_update strategies write canonical_json
# per pulse. ~1260 pulses per run.
cat("\n=== timing canonical_json writes ===\n")
# Pick a representative payload: opening_position is one of the more complex
payload <- canonicalize(list(commission_fixed = 0.5, cash_delta = -100.5,
                              position_delta = 1, realized_pnl = NULL))
n_iter <- 130000L

cat(sprintf("  jsonlite serializing %d payloads...\n", n_iter))
t_jsonlite <- system.time({
  for (k in seq_len(n_iter)) {
    invisible(jsonlite_canonical(payload))
  }
})[["elapsed"]]

cat(sprintf("  yyjsonr serializing %d payloads...\n", n_iter))
t_yyjsonr <- system.time({
  for (k in seq_len(n_iter)) {
    invisible(yyjsonr_canonical(payload))
  }
})[["elapsed"]]

cat(sprintf("\njsonlite: %.3fs  (%.2f us/payload)\n",
            t_jsonlite, t_jsonlite / n_iter * 1e6))
cat(sprintf("yyjsonr : %.3fs  (%.2f us/payload)\n",
            t_yyjsonr, t_yyjsonr / n_iter * 1e6))
speedup <- t_jsonlite / pmax(t_yyjsonr, 0.001)
recovery <- t_jsonlite - t_yyjsonr
cat(sprintf("Speedup : %.2fx\n", speedup))
cat(sprintf("Recovery: %.3fs at %d serializations (isolated)\n", recovery, n_iter))

cat("\n=== decision ===\n")
pct <- 100 * n_ident / n_total
if (pct == 100 && recovery >= 5) {
  decision <- "PROCEED"
  rationale <- sprintf("byte-identical on all %d fixtures AND recovery %.2fs >= 5s",
                       n_total, recovery)
} else if (pct == 100 && recovery < 5) {
  decision <- "PROCEED-LOW-IMPACT"
  rationale <- sprintf("byte-identical (parity safe) but recovery %.2fs < 5s; tiny win",
                       recovery)
} else if (recovery >= 5) {
  decision <- "PROCEED-WITH-BUMP"
  rationale <- sprintf("parity %.0f%%; bytes differ predictably; pre-CRAN bump cost ~hours; recovery %.2fs >= 5s",
                       pct, recovery)
} else if (pct < 100 && recovery < 5) {
  decision <- "PARK"
  rationale <- sprintf("parity %.0f%% AND recovery %.2fs < 5s; not worth the byte-format bump",
                       pct, recovery)
} else {
  decision <- "DEFER"
  rationale <- sprintf("parity %.0f%%; investigate options further", pct)
}
cat(sprintf("Decision: %s\n", decision))
cat(sprintf("Rationale: %s\n", rationale))

# Save
out <- "dev/bench/results/spike_yyjsonr_write_byte_identity.csv"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(results, out, row.names = FALSE)
cat(sprintf("\nWROTE %s\n", out))
