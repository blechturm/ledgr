## Spike 9 (LDG-2513) - active_alias_map One-Time Normalization
##
## Question: measure the per-pulse cost of `active_alias_map` normalization
## and decide whether lifting it outside the loop saves wall time
## (inventory A7).
##
## Mechanism re-spike: the spike spec hypothesises that the alias_map is
## "currently re-normalized per pulse inside R/fold-engine.R:61, 204-218".
## Production code review shows the picture is more nuanced:
##
##   - R/fold-engine.R:61 normalizes ONCE before the loop:
##       active_alias_map <- ledgr_normalize_alias_map(execution$active_alias_map)
##
##   - The per-pulse pulse-context-helpers (R/fold-engine.R:196-221) pass
##     the already-normalized map through to
##     ledgr_update_fast_pulse_context_helpers /
##     ledgr_update_pulse_context_helpers.
##
##   - INSIDE those helpers, ledgr_feature_lookup_map() (R/feature-alias-
##     map.R:90) calls ledgr_alias_map_storage(active_alias_map) which
##     re-normalizes per call. If a strategy callback invokes
##     ctx$features(id) N times per pulse, the normalize fires N times
##     per pulse.
##
## So the real cost lever is "lift normalize into the accessor cache",
## not "lift outside the fold loop" -- it's already lifted. This spike
## measures the standalone normalize cost so the disposition can be
## evidence-based.

suppressPackageStartupMessages({
  pkgload::load_all("c:/Users/maxth/Documents/GitHub/ledgr", quiet = TRUE)
})

set.seed(20260601L)

bench_repeated <- function(expr_fn, n_reps = 5L) {
  reps <- replicate(n_reps, {
    gc(FALSE)
    t0 <- proc.time()[["elapsed"]]
    expr_fn()
    proc.time()[["elapsed"]] - t0
  })
  list(median = median(reps), min = min(reps), max = max(reps), reps = reps)
}

## ---- Variant A: production per-call normalize ----
##
## Mirrors what happens inside ledgr_feature_lookup_map / ledgr_alias_map_storage
## when the strategy callback invokes ctx$features(id). Each call re-normalizes
## the alias_map.

variant_a_per_call_normalize <- function(alias_map, n_calls) {
  for (k in seq_len(n_calls)) {
    normalized <- ledgr_normalize_alias_map(alias_map)
    ## simulate the downstream lookup that uses the normalized map; just
    ## a single name lookup so the loop body has realistic shape
    val <- normalized[[1L]]
  }
  invisible(NULL)
}

## ---- Variant B: one-time normalize, lookup-only per call ----
##
## What the lifted-cache variant would pay: normalize once at fold-engine
## entry (already happens at R/fold-engine.R:61), then per-call work is
## just a list/env lookup, no re-normalize.

variant_b_one_time_normalize <- function(alias_map, n_calls) {
  normalized <- ledgr_normalize_alias_map(alias_map)
  for (k in seq_len(n_calls)) {
    val <- normalized[[1L]]
  }
  invisible(NULL)
}

## ---- Variant C: pre-resolved alias index at execution-spec build ----
##
## Even cheaper: pre-resolve aliases at execution-spec construction time,
## then the per-call cost is a single integer index lookup. This is the
## natural shape if the strategy callback accesses features via the
## ctx$vec$feature(feature_id) bulk-read path bound by the accessor RFC
## synthesis.

variant_c_preresolved_index <- function(alias_map, n_calls) {
  normalized <- ledgr_normalize_alias_map(alias_map)
  idx_map <- stats::setNames(seq_along(normalized), names(normalized))
  for (k in seq_len(n_calls)) {
    val <- idx_map[[1L]]
  }
  invisible(NULL)
}

## ---- Fixture ----

make_alias_map <- function(n_aliases) {
  setNames(
    sprintf("concrete_feature_%04d", seq_len(n_aliases)),
    sprintf("alias_%02d", seq_len(n_aliases))
  )
}

## ---- Sweep ----
##
## n_calls = n_pulses * accessor_calls_per_pulse. For a feature-heavy
## strategy that calls ctx$features(id) once per instrument per pulse on
## a 1000-inst universe over 1260 pulses, that's 1.26M calls. For a
## modest strategy that calls ctx$features once per pulse, it's 1260
## calls. Sweep across the spectrum.

scales <- list(
  list(n_aliases = 10L,   n_calls = 1260L,    label = "10alias_1260p"),
  list(n_aliases = 100L,  n_calls = 1260L,    label = "100alias_1260p"),
  list(n_aliases = 100L,  n_calls = 100000L,  label = "100alias_100kcalls"),
  list(n_aliases = 100L,  n_calls = 1260000L, label = "100alias_1.26Mcalls")
)

results <- vector("list", length(scales))
for (k in seq_along(scales)) {
  sc <- scales[[k]]
  alias_map <- make_alias_map(sc$n_aliases)
  cat(sprintf("\n[%s] n_aliases=%d n_calls=%d\n",
              sc$label, sc$n_aliases, sc$n_calls))

  a <- bench_repeated(function() variant_a_per_call_normalize(alias_map, sc$n_calls))
  b <- bench_repeated(function() variant_b_one_time_normalize(alias_map, sc$n_calls))
  c <- bench_repeated(function() variant_c_preresolved_index(alias_map, sc$n_calls))

  cat(sprintf("  VarA (per-call normalize)  : %.4fs (%.3f us/call)\n",
              a$median, a$median * 1e6 / sc$n_calls))
  cat(sprintf("  VarB (one-time normalize)  : %.4fs (%.2fx)\n",
              b$median, a$median / max(b$median, 1e-6)))
  cat(sprintf("  VarC (pre-resolved index)  : %.4fs (%.2fx)\n",
              c$median, a$median / max(c$median, 1e-6)))

  results[[k]] <- list(
    scale = sc$label, n_aliases = sc$n_aliases, n_calls = sc$n_calls,
    a_median = a$median, b_median = b$median, c_median = c$median,
    a_us_per_call = a$median * 1e6 / sc$n_calls,
    speedup_b = a$median / max(b$median, 1e-6),
    speedup_c = a$median / max(c$median, 1e-6)
  )
}

cat("\n========== SPIKE 9 SUMMARY ==========\n")
cat(sprintf("%-22s %10s %10s %10s %10s %10s %10s %8s %8s\n",
            "scale", "n_alias", "n_calls",
            "VarA_s", "VarB_s", "VarC_s",
            "A_us/call", "B_sp", "C_sp"))
for (r in results) {
  cat(sprintf("%-22s %10d %10d %10.4f %10.4f %10.4f %10.3f %7.2fx %7.2fx\n",
              r$scale, r$n_aliases, r$n_calls,
              r$a_median, r$b_median, r$c_median,
              r$a_us_per_call,
              r$speedup_b, r$speedup_c))
}

## Decision rule from spike spec: isolated cost < 0.5s at 1260 pulses x
## 100-alias map => park.
cat(sprintf("\nDecision rule: if VarA at 1260 calls x 100 aliases < 0.5s => park\n"))
target_row <- results[[which(vapply(results,
                                    function(r) r$scale == "100alias_1260p",
                                    logical(1)))]]
cat(sprintf("VarA at that shape: %.4fs => %s\n",
            target_row$a_median,
            if (target_row$a_median < 0.5) "PARK (below threshold)"
            else "TICKET (above threshold)"))

res_df <- do.call(rbind, lapply(results, function(r) data.frame(
  scale = r$scale, n_aliases = r$n_aliases, n_calls = r$n_calls,
  variant_a_s = r$a_median, variant_b_s = r$b_median, variant_c_s = r$c_median,
  a_us_per_call = r$a_us_per_call,
  speedup_b = r$speedup_b, speedup_c = r$speedup_c,
  stringsAsFactors = FALSE
)))
out_csv <- "c:/Users/maxth/Documents/GitHub/ledgr/dev/bench/results/spike_alias_map_normalize.csv"
write.csv(res_df, out_csv, row.names = FALSE)
cat(sprintf("\nResults written to %s\n", out_csv))
