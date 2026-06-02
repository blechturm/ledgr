## Spike 3 (LDG-2507) - state$positions Primitive Representation Re-Spike
##
## Re-measure the state$positions write candidates at post-v0.1.8.9 production
## shape. The v0.1.8.9 Spike 3 measured this with modest wins (intvec_id_map
## 1.9x, env_positions 4.6x at 100k mutations); disposition was defer to
## v0.1.8.10+ per LDG-2502 triage.
##
## v0.1.8.10 re-spike question: post-Batches 4/5 (per-pulse vectorize), the
## read-side cost is gone. The residual is the per-fill write at
## R/fold-engine.R:354-360 (state$positions[[instrument_id]] <- cur_qty + qty).
## At 130k fills xlarge that's 130k named-vector write operations.
##
## Two questions:
##   1. Does it deliver measurable R-side wins at the post-v0.1.8.9 shape?
##   2. Does it serve as substrate for compiled-core boundary cost reduction?
##      The Spike 12 K1 measurement spike (separate ledgrcore-spike repo)
##      needs a substrate-emulated R baseline. Variant B (intvec_id_map) is
##      the natural pre-compile shape: contiguous numeric vector with an O(1)
##      idx lookup, identical to how a compiled core would represent state.

suppressPackageStartupMessages({
  pkgload::load_all("c:/Users/maxth/Documents/GitHub/ledgr", quiet = TRUE)
})

set.seed(20260601L)

bench_repeated <- function(expr_fn, n_reps = 3L) {
  reps <- replicate(n_reps, {
    gc(FALSE)
    t0 <- proc.time()[["elapsed"]]
    expr_fn()
    proc.time()[["elapsed"]] - t0
  })
  list(median = median(reps), min = min(reps), max = max(reps), reps = reps)
}

## Faithful replica of production pattern:
##   ctx <- list(positions = state$positions, ...)
##   state$positions[[id]] <- new_value
## the ctx-list construction at pulse start elevates refcount so the next
## mutation triggers copy-on-write.

variant_a_current <- function(n_inst, n_writes, ids) {
  state <- list(
    positions = stats::setNames(numeric(n_inst), ids),
    cash = 1e6
  )
  for (k in seq_len(n_writes)) {
    id <- ids[[((k - 1L) %% n_inst) + 1L]]
    ctx <- list(positions = state$positions, cash = state$cash)
    cur <- state$positions[[id]]
    state$positions[[id]] <- cur + 1
  }
  state$positions
}

variant_b_intvec_id_map <- function(n_inst, n_writes, ids) {
  id_to_idx <- stats::setNames(seq_len(n_inst), ids)
  state <- list(
    positions = numeric(n_inst),
    cash = 1e6
  )
  for (k in seq_len(n_writes)) {
    id <- ids[[((k - 1L) %% n_inst) + 1L]]
    idx <- id_to_idx[[id]]
    ctx <- list(positions = state$positions, cash = state$cash)
    cur <- state$positions[[idx]]
    state$positions[[idx]] <- cur + 1
  }
  state$positions
}

variant_c_env_positions <- function(n_inst, n_writes, ids) {
  positions_env <- new.env(parent = emptyenv())
  for (id in ids) positions_env[[id]] <- 0
  state <- list(positions = positions_env, cash = 1e6)
  for (k in seq_len(n_writes)) {
    id <- ids[[((k - 1L) %% n_inst) + 1L]]
    ctx <- list(positions = state$positions, cash = state$cash)
    cur <- state$positions[[id]]
    state$positions[[id]] <- cur + 1
  }
  ## reconstruct named-numeric view for parity gate
  out <- vapply(ids, function(id) state$positions[[id]], numeric(1))
  stats::setNames(out, ids)
}

variant_d_collapse_setv <- function(n_inst, n_writes, ids) {
  id_to_idx <- stats::setNames(seq_len(n_inst), ids)
  state <- list(
    positions = numeric(n_inst),
    cash = 1e6
  )
  for (k in seq_len(n_writes)) {
    id <- ids[[((k - 1L) %% n_inst) + 1L]]
    idx <- id_to_idx[[id]]
    ctx <- list(positions = state$positions, cash = state$cash)
    cur <- state$positions[[idx]]
    collapse::setv(state$positions, idx, cur + 1, vind1 = TRUE)
  }
  state$positions
}

## ---- tracemem evidence (3 mutations per variant) ----

tracemem_evidence <- function(n_inst = 1000L) {
  ids <- sprintf("INST%04d", seq_len(n_inst))
  con <- file(tempfile(), open = "w+")
  sink(con, type = "message")
  on.exit({ sink(NULL, type = "message"); close(con) }, add = TRUE)

  results <- list()
  for (variant in c("a", "b", "c", "d")) {
    if (variant == "a") {
      state <- list(positions = stats::setNames(numeric(n_inst), ids), cash = 1e6)
      tracemem(state$positions)
      for (k in 1:3) {
        ctx <- list(positions = state$positions, cash = state$cash)
        state$positions[[ids[[k]]]] <- k
      }
      untracemem(state$positions)
    } else if (variant == "b") {
      id_to_idx <- stats::setNames(seq_len(n_inst), ids)
      state <- list(positions = numeric(n_inst), cash = 1e6)
      tracemem(state$positions)
      for (k in 1:3) {
        ctx <- list(positions = state$positions, cash = state$cash)
        state$positions[[id_to_idx[[ids[[k]]]]]] <- k
      }
      untracemem(state$positions)
    } else if (variant == "c") {
      positions_env <- new.env(parent = emptyenv())
      for (id in ids) positions_env[[id]] <- 0
      state <- list(positions = positions_env, cash = 1e6)
      ## envs can't be traced same way; their reference semantics mean
      ## no copy occurs by construction.
      for (k in 1:3) {
        ctx <- list(positions = state$positions, cash = state$cash)
        state$positions[[ids[[k]]]] <- k
      }
    } else if (variant == "d") {
      id_to_idx <- stats::setNames(seq_len(n_inst), ids)
      state <- list(positions = numeric(n_inst), cash = 1e6)
      tracemem(state$positions)
      for (k in 1:3) {
        ctx <- list(positions = state$positions, cash = state$cash)
        collapse::setv(state$positions, id_to_idx[[ids[[k]]]], as.numeric(k),
                       vind1 = TRUE)
      }
      untracemem(state$positions)
    }
  }
  sink(NULL, type = "message")
  close(con)
  on.exit()
  readLines(summary(con)$description %||% "")
}

## ---- Sweep ----

scales <- list(
  list(n_inst = 500L,  n_writes = 100000L, label = "500"),
  list(n_inst = 1000L, n_writes = 100000L, label = "1000"),
  list(n_inst = 2000L, n_writes = 100000L, label = "2000")
)

results <- vector("list", length(scales))
for (k in seq_along(scales)) {
  sc <- scales[[k]]
  ids <- sprintf("INST%04d", seq_len(sc$n_inst))
  cat(sprintf("\n[n_inst=%d, n_writes=%d]\n", sc$n_inst, sc$n_writes))

  a <- bench_repeated(function() variant_a_current(sc$n_inst, sc$n_writes, ids))
  b <- bench_repeated(function() variant_b_intvec_id_map(sc$n_inst, sc$n_writes, ids))
  c <- bench_repeated(function() variant_c_env_positions(sc$n_inst, sc$n_writes, ids))
  d <- bench_repeated(function() variant_d_collapse_setv(sc$n_inst, sc$n_writes, ids))

  ## Parity gate: final positions byte-identical across variants
  va <- variant_a_current(sc$n_inst, sc$n_writes, ids)
  vb <- variant_b_intvec_id_map(sc$n_inst, sc$n_writes, ids)
  vc <- variant_c_env_positions(sc$n_inst, sc$n_writes, ids)
  vd <- variant_d_collapse_setv(sc$n_inst, sc$n_writes, ids)
  par_ab <- identical(as.numeric(va), as.numeric(vb))
  par_ac <- identical(as.numeric(va), as.numeric(vc))
  par_ad <- identical(as.numeric(va), as.numeric(vd))

  cat(sprintf("  VarA (current named)        : %.3fs\n", a$median))
  cat(sprintf("  VarB (intvec_id_map)        : %.3fs (%.2fx)\n",
              b$median, a$median / max(b$median, 1e-6)))
  cat(sprintf("  VarC (env_positions)        : %.3fs (%.2fx)\n",
              c$median, a$median / max(c$median, 1e-6)))
  cat(sprintf("  VarD (collapse::setv)       : %.3fs (%.2fx)\n",
              d$median, a$median / max(d$median, 1e-6)))
  cat(sprintf("  Parity A==B: %s, A==C: %s, A==D: %s\n",
              if (par_ab) "PASS" else "FAIL",
              if (par_ac) "PASS" else "FAIL",
              if (par_ad) "PASS" else "FAIL"))

  results[[k]] <- list(
    scale = sc$label, n_inst = sc$n_inst, n_writes = sc$n_writes,
    a_median = a$median, b_median = b$median,
    c_median = c$median, d_median = d$median,
    speedup_b = a$median / max(b$median, 1e-6),
    speedup_c = a$median / max(c$median, 1e-6),
    speedup_d = a$median / max(d$median, 1e-6),
    parity_ab = par_ab, parity_ac = par_ac, parity_ad = par_ad
  )
}

cat("\n========== SPIKE 3 SUMMARY ==========\n")
cat(sprintf("%-6s %8s %10s %10s %10s %10s %8s %8s %8s\n",
            "scale", "n_inst",
            "VarA_s", "VarB_s", "VarC_s", "VarD_s",
            "B_sp", "C_sp", "D_sp"))
for (r in results) {
  cat(sprintf("%-6s %8d %10.3f %10.3f %10.3f %10.3f %7.2fx %7.2fx %7.2fx\n",
              r$scale, r$n_inst,
              r$a_median, r$b_median, r$c_median, r$d_median,
              r$speedup_b, r$speedup_c, r$speedup_d))
}

res_df <- do.call(rbind, lapply(results, function(r) data.frame(
  scale = r$scale, n_inst = r$n_inst, n_writes = r$n_writes,
  variant_a_s = r$a_median, variant_b_s = r$b_median,
  variant_c_s = r$c_median, variant_d_s = r$d_median,
  speedup_b = r$speedup_b, speedup_c = r$speedup_c, speedup_d = r$speedup_d,
  parity_ab = r$parity_ab, parity_ac = r$parity_ac, parity_ad = r$parity_ad,
  stringsAsFactors = FALSE
)))
out_csv <- "c:/Users/maxth/Documents/GitHub/ledgr/dev/bench/results/spike_state_positions_primitive.csv"
write.csv(res_df, out_csv, row.names = FALSE)
cat(sprintf("\nResults written to %s\n", out_csv))
