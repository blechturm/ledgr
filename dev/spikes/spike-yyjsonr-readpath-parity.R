# Spike 13: yyjsonr read-path parity and recovery measurement
#
# Context: Codex peer review identified ~15s of jsonlite::fromJSON cost in
# the chunked extractor at 130k events (Spike 12 Rprof). yyjsonr claims
# 2-10x speedup over jsonlite. This spike tests whether yyjsonr can be
# a drop-in replacement for `jsonlite::fromJSON(meta_json, simplifyVector
# = FALSE)` in ledgr's hot read paths.
#
# SCOPE: Class A (read paths only). The 8 production fromJSON call sites
# parse ledger meta_json to extract cash_delta, position_delta, and
# realized_pnl. The parsed R object is consumed for computation and
# discarded — byte-identity of the parser output doesn't matter, only
# structural equivalence.
#
# OUT OF SCOPE: Class B (canonical_json write path). Covered by Spike 14.
#
# FAITHFULNESS: uses representative meta_json shapes covering all
# production patterns (FILL with deltas, CASHFLOW with opening cost
# basis, etc.). Calls the actual production parsing options at each
# call site.
#
# Decision rule:
#   PROCEED   : parity holds (identical()) AND speedup gives 5s+ recovery
#   PARK      : parity fails on >5% of fixtures OR speedup < 2x
#   DEFER     : parity holds via wrapper, switch cost > recovery

suppressWarnings(suppressMessages({
  library(jsonlite)
  library(yyjsonr)
}))

# Construct 200 representative meta_json strings covering production patterns.
mk_fixtures <- function(seed = 42L) {
  set.seed(seed)

  # Pattern 1: standard FILL events
  pattern_fill <- vapply(seq_len(80L), function(i) {
    sprintf('{"cash_delta":%g,"position_delta":%g,"realized_pnl":null}',
            runif(1L, -1000, 1000),
            sample(c(-1L, 1L), 1L))
  }, character(1))

  # Pattern 2: FILL events with realized_pnl populated (close trades)
  pattern_fill_realized <- vapply(seq_len(40L), function(i) {
    sprintf('{"cash_delta":%g,"position_delta":%g,"realized_pnl":%g}',
            runif(1L, -1000, 1000),
            sample(c(-1L, 1L), 1L),
            runif(1L, -500, 500))
  }, character(1))

  # Pattern 3: CASHFLOW opening positions (from
  # R/fold-event-buffer.R:ledgr_opening_position_event_rows)
  pattern_opening <- vapply(seq_len(40L), function(i) {
    sprintf('{"source":"opening_position","cash_delta":0,"position_delta":%g,"cost_basis":%g,"opening_position":true}',
            runif(1L, 1, 1000),
            runif(1L, 50, 200))
  }, character(1))

  # Pattern 4: small commission fee values
  pattern_with_commission <- vapply(seq_len(20L), function(i) {
    sprintf('{"commission_fixed":%g,"cash_delta":%g,"position_delta":%g,"realized_pnl":null}',
            runif(1L, 0, 5),
            runif(1L, -1000, 1000),
            sample(c(-1L, 1L), 1L))
  }, character(1))

  # Pattern 5: edge cases — null fields, escapes, unicode
  pattern_edge <- c(
    '{"cash_delta":0,"position_delta":0,"realized_pnl":null}',
    '{"cash_delta":1e-12,"position_delta":1,"realized_pnl":null}',
    '{"cash_delta":1e10,"position_delta":-1,"realized_pnl":1234.5678901234567}',
    '{"cash_delta":-1.7976931348623157e+308,"position_delta":1,"realized_pnl":null}',
    '{"comment":"with quote\\"inside","cash_delta":0,"position_delta":0,"realized_pnl":null}'
  )

  c(pattern_fill, pattern_fill_realized, pattern_opening,
    pattern_with_commission, pattern_edge)
}

# yyjsonr options to match jsonlite::fromJSON(..., simplifyVector = FALSE)
yyjsonr_readopts <- function() {
  yyjsonr::opts_read_json(
    obj_of_arrs_to_df = FALSE,
    arr_of_objs_to_df = FALSE,
    arr_of_arrs_to_matrix = FALSE,
    length1_array_asis = TRUE
  )
}

# Parity check: parse with both, compare with identical()
check_parity <- function(fixtures) {
  opts <- yyjsonr_readopts()
  results <- data.frame(
    idx = integer(),
    pattern = character(),
    identical = logical(),
    structurally_equal = logical(),
    same_values = logical(),
    diff_summary = character(),
    stringsAsFactors = FALSE
  )
  for (i in seq_along(fixtures)) {
    s <- fixtures[[i]]
    json_obj <- jsonlite::fromJSON(s, simplifyVector = FALSE)
    yy_obj <- yyjsonr::read_json_str(s, opts = opts)

    ident <- identical(json_obj, yy_obj)
    # Structural equality: same names, same depth, same types at each leaf
    struct <- isTRUE(all.equal(json_obj, yy_obj))
    # Same values: extract the scalar values both objects have
    same_values <- tryCatch({
      json_keys <- sort(names(json_obj))
      yy_keys <- sort(names(yy_obj))
      identical(json_keys, yy_keys) &&
        all(vapply(json_keys, function(k) {
          a <- json_obj[[k]]
          b <- yy_obj[[k]]
          if (is.null(a) && is.null(b)) return(TRUE)
          if (is.null(a) || is.null(b)) return(FALSE)
          isTRUE(all.equal(a, b))
        }, logical(1)))
    }, error = function(e) NA)

    diff_summary <- if (ident) {
      "identical"
    } else if (isTRUE(same_values)) {
      "same values, different R representation"
    } else if (is.na(same_values)) {
      "comparison error"
    } else {
      "values differ"
    }

    pattern <- if (i <= 80L) "fill" else if (i <= 120L) "fill_realized" else if (i <= 160L) "opening" else if (i <= 180L) "commission" else "edge"
    results <- rbind(results, data.frame(
      idx = i, pattern = pattern,
      identical = ident, structurally_equal = struct,
      same_values = isTRUE(same_values),
      diff_summary = diff_summary,
      stringsAsFactors = FALSE
    ))
  }
  results
}

# Timing at production scale: ~133k events
measure_timing <- function(fixtures, n_iterations) {
  opts <- yyjsonr_readopts()

  cat(sprintf("  jsonlite parsing %d events...\n", n_iterations))
  t_jsonlite <- system.time({
    for (k in seq_len(n_iterations)) {
      s <- fixtures[[((k - 1L) %% length(fixtures)) + 1L]]
      invisible(jsonlite::fromJSON(s, simplifyVector = FALSE))
    }
  })[["elapsed"]]

  cat(sprintf("  yyjsonr parsing %d events...\n", n_iterations))
  t_yyjsonr <- system.time({
    for (k in seq_len(n_iterations)) {
      s <- fixtures[[((k - 1L) %% length(fixtures)) + 1L]]
      invisible(yyjsonr::read_json_str(s, opts = opts))
    }
  })[["elapsed"]]

  list(t_jsonlite = t_jsonlite, t_yyjsonr = t_yyjsonr)
}

cat("=== yyjsonr read-path parity and recovery spike ===\n")
cat(sprintf("jsonlite version: %s\n", as.character(packageVersion("jsonlite"))))
cat(sprintf("yyjsonr version : %s\n\n", as.character(packageVersion("yyjsonr"))))

fixtures <- mk_fixtures()
cat(sprintf("Generated %d fixture strings across 5 patterns.\n\n", length(fixtures)))

cat("=== parity check ===\n")
parity <- check_parity(fixtures)

by_pattern <- aggregate(parity[, c("identical", "structurally_equal", "same_values")],
                        by = list(pattern = parity$pattern),
                        FUN = function(x) sum(x, na.rm = TRUE))
n_per <- table(parity$pattern)
by_pattern$total <- n_per[by_pattern$pattern]
by_pattern$pct_identical <- 100 * by_pattern$identical / by_pattern$total
by_pattern$pct_same_values <- 100 * by_pattern$same_values / by_pattern$total
cat("\nPer-pattern parity:\n")
print(by_pattern[, c("pattern", "total", "identical", "same_values",
                     "pct_identical", "pct_same_values")])

n_total <- nrow(parity)
n_ident <- sum(parity$identical)
n_same <- sum(parity$same_values, na.rm = TRUE)
cat(sprintf("\nOverall:  %d/%d identical (%.1f%%), %d/%d same values (%.1f%%)\n",
            n_ident, n_total, 100 * n_ident / n_total,
            n_same, n_total, 100 * n_same / n_total))

# Show 3 examples of non-identical cases for inspection
non_ident <- parity[!parity$identical, ]
if (nrow(non_ident) > 0) {
  cat("\n=== example non-identical cases (first 3) ===\n")
  show_ids <- non_ident$idx[seq_len(min(3L, nrow(non_ident)))]
  opts <- yyjsonr_readopts()
  for (k in show_ids) {
    cat(sprintf("\n--- fixture %d (%s) ---\n", k, parity$pattern[k]))
    cat(sprintf("Input: %s\n", fixtures[[k]]))
    jl <- jsonlite::fromJSON(fixtures[[k]], simplifyVector = FALSE)
    yy <- yyjsonr::read_json_str(fixtures[[k]], opts = opts)
    cat("jsonlite output:\n"); str(jl)
    cat("yyjsonr output:\n"); str(yy)
  }
}

cat("\n=== timing at 133k events ===\n")
n_iter <- 133000L
timing <- measure_timing(fixtures, n_iter)
cat(sprintf("\njsonlite: %.3fs  (%.2f us/event)\n",
            timing$t_jsonlite, timing$t_jsonlite / n_iter * 1e6))
cat(sprintf("yyjsonr : %.3fs  (%.2f us/event)\n",
            timing$t_yyjsonr, timing$t_yyjsonr / n_iter * 1e6))
speedup <- timing$t_jsonlite / pmax(timing$t_yyjsonr, 0.001)
recovery <- timing$t_jsonlite - timing$t_yyjsonr
cat(sprintf("Speedup : %.2fx\n", speedup))
cat(sprintf("Recovery: %.3fs at 133k events (isolated)\n", recovery))

cat("\n=== decision ===\n")
parity_pct <- 100 * n_ident / n_total
same_values_pct <- 100 * n_same / n_total
if (parity_pct >= 95 && recovery >= 5) {
  decision <- "PROCEED"
  rationale <- sprintf("identical() parity %.1f%% >= 95%% AND recovery %.2fs >= 5s",
                       parity_pct, recovery)
} else if (same_values_pct >= 95 && recovery >= 5) {
  decision <- "PROCEED-WITH-WRAPPER"
  rationale <- sprintf("same-values parity %.1f%% >= 95%% but identical() %.1f%%; wrapper needed; recovery %.2fs",
                       same_values_pct, parity_pct, recovery)
} else if (recovery < 5) {
  decision <- "PARK"
  rationale <- sprintf("recovery %.2fs < 5s; speedup is real but Amdahl too small",
                       recovery)
} else {
  decision <- "DEFER"
  rationale <- sprintf("parity %.1f%% < 95%%; switch cost > recovery; defer to v0.1.8.10",
                       parity_pct)
}
cat(sprintf("Decision: %s\n", decision))
cat(sprintf("Rationale: %s\n", rationale))

# Save
out <- "dev/bench/results/spike_yyjsonr_readpath_parity.csv"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
summary_df <- data.frame(
  metric = c("n_fixtures", "n_identical", "n_same_values",
             "parity_identical_pct", "parity_same_values_pct",
             "jsonlite_us_per_event", "yyjsonr_us_per_event",
             "speedup", "recovery_s_133k", "decision"),
  value = c(as.character(n_total), as.character(n_ident),
            as.character(n_same),
            sprintf("%.2f", parity_pct),
            sprintf("%.2f", same_values_pct),
            sprintf("%.2f", timing$t_jsonlite / n_iter * 1e6),
            sprintf("%.2f", timing$t_yyjsonr / n_iter * 1e6),
            sprintf("%.2fx", speedup),
            sprintf("%.3f", recovery),
            decision),
  stringsAsFactors = FALSE
)
utils::write.csv(summary_df, out, row.names = FALSE)
cat(sprintf("\nWROTE %s\n", out))
