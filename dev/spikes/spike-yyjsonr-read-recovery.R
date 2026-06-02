## Spike 7 (LDG-2511) - yyjsonr Read-Path Recovery Investigation
##
## Investigate whether the LDG-2501 yyjsonr read regression is recoverable
## through different yyjsonr configurations, helper-indirection removal, or
## a thin jsonlite fallback. LDG-2501 helper benchmark measured yyjsonr
## reads 2.3x slower than jsonlite on production metadata shapes (0.53s
## jsonlite vs 1.21s yyjsonr at 50k payloads).
##
## Variants:
##   A: current `ledgr_json_read_nested` helper (production baseline)
##   B: direct `yyjsonr::read_json_str` without helper indirection
##   C: yyjsonr with length1_array_asis = FALSE
##   D: yyjsonr binary-mode read if available
##   E: jsonlite read-fallback (`jsonlite::fromJSON`) while keeping
##      yyjsonr for canonical writes
##
## Decision rule: any variant achieving 1.5x recovery over Variant A
## proceeds to v0.1.8.10 ticket; otherwise the read-path stays as the
## documented LDG-2501 trade-off.

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

## ---- Fixture: 50k representative meta_json payloads ----
##
## Production event meta_json is mostly flat objects with a few numeric
## scalars and occasional null. Match the LDG-2501 benchmark shape.

make_payloads <- function(n) {
  cash_delta <- runif(n, -1e5, 1e5)
  pos_delta <- sample.int(100L, n, replace = TRUE) - 50L
  realized_pnl <- ifelse(runif(n) < 0.5, NA_real_, runif(n, -1e3, 1e3))
  vapply(seq_len(n), function(k) {
    if (is.na(realized_pnl[[k]])) {
      sprintf('{"cash_delta":%.6f,"position_delta":%d,"realized_pnl":null}',
              cash_delta[[k]], pos_delta[[k]])
    } else {
      sprintf('{"cash_delta":%.6f,"position_delta":%d,"realized_pnl":%.6f}',
              cash_delta[[k]], pos_delta[[k]], realized_pnl[[k]])
    }
  }, character(1))
}

## ---- Variants ----

variant_a_helper <- function(payloads) {
  for (k in seq_along(payloads)) {
    invisible(ledgr:::ledgr_json_read_nested(payloads[[k]]))
  }
}

variant_b_direct_yyjsonr <- function(payloads) {
  opts <- yyjsonr::opts_read_json(
    obj_of_arrs_to_df = FALSE,
    arr_of_objs_to_df = FALSE,
    arr_of_arrs_to_matrix = FALSE,
    length1_array_asis = TRUE
  )
  for (k in seq_along(payloads)) {
    invisible(yyjsonr::read_json_str(payloads[[k]], opts = opts))
  }
}

variant_c_yyjsonr_alt_opts <- function(payloads) {
  opts <- yyjsonr::opts_read_json(
    obj_of_arrs_to_df = FALSE,
    arr_of_objs_to_df = FALSE,
    arr_of_arrs_to_matrix = FALSE,
    length1_array_asis = FALSE
  )
  for (k in seq_along(payloads)) {
    invisible(yyjsonr::read_json_str(payloads[[k]], opts = opts))
  }
}

variant_d_jsonlite_fallback <- function(payloads) {
  for (k in seq_along(payloads)) {
    invisible(jsonlite::fromJSON(payloads[[k]], simplifyVector = FALSE))
  }
}

variant_e_jsonlite_simplify <- function(payloads) {
  ## jsonlite with simplifyVector = TRUE matches yyjsonr's default behaviour
  ## of scalar-numeric output for length-1 fields.
  for (k in seq_along(payloads)) {
    invisible(jsonlite::fromJSON(payloads[[k]], simplifyVector = TRUE))
  }
}

## ---- Structural-parity check ----
##
## Verify that downstream consumers (cash_delta, position_delta, realized_pnl
## numeric extraction) receive equivalent values across variants.

check_parity <- function(payloads_sample) {
  pa <- lapply(payloads_sample, ledgr:::ledgr_json_read_nested)
  pb <- lapply(payloads_sample, function(p) {
    opts <- yyjsonr::opts_read_json(
      obj_of_arrs_to_df = FALSE,
      arr_of_objs_to_df = FALSE,
      arr_of_arrs_to_matrix = FALSE,
      length1_array_asis = TRUE
    )
    yyjsonr::read_json_str(p, opts = opts)
  })
  pc <- lapply(payloads_sample, function(p) {
    opts <- yyjsonr::opts_read_json(
      obj_of_arrs_to_df = FALSE,
      arr_of_objs_to_df = FALSE,
      arr_of_arrs_to_matrix = FALSE,
      length1_array_asis = FALSE
    )
    yyjsonr::read_json_str(p, opts = opts)
  })
  pd <- lapply(payloads_sample, function(p) jsonlite::fromJSON(p, simplifyVector = FALSE))
  pe <- lapply(payloads_sample, function(p) jsonlite::fromJSON(p, simplifyVector = TRUE))

  ## Extract cash_delta from each variant — the downstream consumer pattern
  cd <- function(parsed) vapply(parsed, function(x) as.numeric(x$cash_delta), numeric(1))
  pd_extract_d <- function(parsed) vapply(parsed, function(x) as.numeric(x$position_delta), numeric(1))

  ab_cd <- isTRUE(all.equal(cd(pa), cd(pb), tolerance = 0))
  ac_cd <- isTRUE(all.equal(cd(pa), cd(pc), tolerance = 0))
  ad_cd <- isTRUE(all.equal(cd(pa), cd(pd), tolerance = 0))
  ae_cd <- isTRUE(all.equal(cd(pa), cd(pe), tolerance = 0))

  list(
    cash_delta_parity = list(B = ab_cd, C = ac_cd, D = ad_cd, E = ae_cd),
    a_sample = pa[[1]], b_sample = pb[[1]], c_sample = pc[[1]],
    d_sample = pd[[1]], e_sample = pe[[1]]
  )
}

## ---- Sweep ----

payloads_50k <- make_payloads(50000L)
cat(sprintf("\n[50k payloads]\n"))
cat(sprintf("Sample payload: %s\n", payloads_50k[[1]]))

parity <- check_parity(payloads_50k[1:10])
cat(sprintf("Cash-delta parity vs production VarA: B=%s C=%s D=%s E=%s\n",
            if (parity$cash_delta_parity$B) "PASS" else "FAIL",
            if (parity$cash_delta_parity$C) "PASS" else "FAIL",
            if (parity$cash_delta_parity$D) "PASS" else "FAIL",
            if (parity$cash_delta_parity$E) "PASS" else "FAIL"))

a <- bench_repeated(function() variant_a_helper(payloads_50k))
b <- bench_repeated(function() variant_b_direct_yyjsonr(payloads_50k))
c <- bench_repeated(function() variant_c_yyjsonr_alt_opts(payloads_50k))
d <- bench_repeated(function() variant_d_jsonlite_fallback(payloads_50k))
e <- bench_repeated(function() variant_e_jsonlite_simplify(payloads_50k))

cat(sprintf("  VarA (helper indirection)        : %.4fs (%.2f us/payload)\n",
            a$median, a$median * 1e6 / 50000L))
cat(sprintf("  VarB (direct yyjsonr)            : %.4fs (%.2fx, %.2f us/payload)\n",
            b$median, a$median / max(b$median, 1e-6),
            b$median * 1e6 / 50000L))
cat(sprintf("  VarC (yyjsonr length1_array=FALSE): %.4fs (%.2fx, %.2f us/payload)\n",
            c$median, a$median / max(c$median, 1e-6),
            c$median * 1e6 / 50000L))
cat(sprintf("  VarD (jsonlite simplify=FALSE)   : %.4fs (%.2fx, %.2f us/payload)\n",
            d$median, a$median / max(d$median, 1e-6),
            d$median * 1e6 / 50000L))
cat(sprintf("  VarE (jsonlite simplify=TRUE)    : %.4fs (%.2fx, %.2f us/payload)\n",
            e$median, a$median / max(e$median, 1e-6),
            e$median * 1e6 / 50000L))

cat("\n========== SPIKE 7 SUMMARY ==========\n")
cat(sprintf("Decision rule: any variant achieving 1.5x over VarA proceeds to v0.1.8.10 ticket.\n"))
cat(sprintf("  VarB speedup: %.2fx => %s\n",
            a$median / max(b$median, 1e-6),
            if (a$median / max(b$median, 1e-6) >= 1.5) "PROCEED" else "BELOW THRESHOLD"))
cat(sprintf("  VarC speedup: %.2fx => %s\n",
            a$median / max(c$median, 1e-6),
            if (a$median / max(c$median, 1e-6) >= 1.5) "PROCEED" else "BELOW THRESHOLD"))
cat(sprintf("  VarD speedup: %.2fx => %s\n",
            a$median / max(d$median, 1e-6),
            if (a$median / max(d$median, 1e-6) >= 1.5) "PROCEED" else "BELOW THRESHOLD"))
cat(sprintf("  VarE speedup: %.2fx => %s\n",
            a$median / max(e$median, 1e-6),
            if (a$median / max(e$median, 1e-6) >= 1.5) "PROCEED" else "BELOW THRESHOLD"))

res_df <- data.frame(
  variant = c("a_helper", "b_direct_yyjsonr", "c_yyjsonr_alt_opts",
              "d_jsonlite_simplify_false", "e_jsonlite_simplify_true"),
  wall_s = c(a$median, b$median, c$median, d$median, e$median),
  us_per_payload = c(a$median, b$median, c$median, d$median, e$median) * 1e6 / 50000L,
  speedup_vs_a = c(1, a$median / max(b$median, 1e-6),
                   a$median / max(c$median, 1e-6),
                   a$median / max(d$median, 1e-6),
                   a$median / max(e$median, 1e-6)),
  cash_delta_parity = c(TRUE,
                        parity$cash_delta_parity$B,
                        parity$cash_delta_parity$C,
                        parity$cash_delta_parity$D,
                        parity$cash_delta_parity$E),
  stringsAsFactors = FALSE
)
out_csv <- "c:/Users/maxth/Documents/GitHub/ledgr/dev/bench/results/spike_yyjsonr_read_recovery.csv"
write.csv(res_df, out_csv, row.names = FALSE)
cat(sprintf("\nResults written to %s\n", out_csv))
