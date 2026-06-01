# Spike: state$positions named-vector copy-on-write under refcount-elevated
# conditions vs candidate representation fixes
#
# Context: R/fold-engine.R:354-355 mutates state$positions[[id]] per fill.
# The pulse-context constructor a few lines earlier puts
# `positions = state$positions` in ctx, holding a reference. R's
# copy-on-modify semantics may copy the whole positions vector when one
# element is mutated under refcount > 1.
#
# FAITHFULNESS: replicates the closure-capture pattern from fold-engine.R: a
# ctx-like list holds `positions = state$positions` BEFORE mutation. tracemem
# detects copies. Timing then measures the throughput cost of each
# representation candidate.
#
# Variants:
#   current             : list state, named-numeric positions, ctx holds ref
#   env_state           : env-based state, named-numeric positions, ctx holds ref
#   env_positions       : list state, env-based positions, ctx holds env ref
#   intvec_id_map       : list state, bare numeric + id->idx map, ctx holds ref
#   collapse_setv       : intvec + id->idx, mutate via collapse::setv() (in-place by ref)
#   collapse_setop      : intvec + id->idx, mutate via collapse::setv(..., op="+")
#                         (in-place increment, bypasses the read-then-write pattern)
#
# What tracemem tells us:
# - A line printed per write means R copied the vector under that write.
# - No line means the write was in-place.
#
# CAVEAT: env_state may NOT fix the copy because state$positions itself is
# still a vector and ctx still captures it by value (refcount-elevated). The
# spike confirms or rejects this. env_positions (positions IS an environment)
# should be copy-free because environments are reference semantics. The
# intvec variant tests whether an integer-indexed bare vector helps when ctx
# still captures it. The collapse variants test in-place mutation by C
# reference; v0.1.8.7 buffer spike confirmed these are tracemem-copy-free
# even under refcount-elevated conditions.
#
# collapse::setv is VALUE-NEUTRAL (a write, not a reduction) so it does NOT
# need the ledgr_with_collapse_deterministic() wrapper per
# inst/design/collapse_optimization_map.md.
#
# SEMANTIC NOTE: collapse_setv and collapse_setop mutate the underlying
# memory in place. ctx$positions (which references the same memory) would see
# subsequent mutations — same semantic concern as env_positions. The
# intvec_id_map variant (without collapse) preserves snapshot semantics by
# letting R's copy-on-modify fire (just with a cheaper bare-vector copy).

suppressWarnings(suppressMessages(library(collapse)))

`%||%` <- function(x, y) if (is.null(x)) y else x

mk_ids <- function(n) sprintf("INST_%05d", seq_len(n))

# Variant (a): current pattern
build_current <- function(n_inst) {
  ids <- mk_ids(n_inst)
  list(
    positions = stats::setNames(rep(0, n_inst), ids),
    cash = 1e7
  )
}

mutate_current <- function(state, ids, n_mutations) {
  for (k in seq_len(n_mutations)) {
    ctx <- list(positions = state$positions, cash = state$cash)
    id <- ids[[((k - 1L) %% length(ids)) + 1L]]
    cur <- state$positions[[id]] %||% 0
    state$positions[[id]] <- cur + 1
    state$cash <- state$cash - 100
  }
  state
}

# Variant (b): env state, named-numeric positions
build_env_state <- function(n_inst) {
  ids <- mk_ids(n_inst)
  state <- new.env(parent = emptyenv())
  state$positions <- stats::setNames(rep(0, n_inst), ids)
  state$cash <- 1e7
  state
}

mutate_env_state <- function(state, ids, n_mutations) {
  for (k in seq_len(n_mutations)) {
    ctx <- list(positions = state$positions, cash = state$cash)
    id <- ids[[((k - 1L) %% length(ids)) + 1L]]
    cur <- state$positions[[id]] %||% 0
    state$positions[[id]] <- cur + 1
    state$cash <- state$cash - 100
  }
  state
}

# Variant (c): list state, env-based positions
build_env_positions <- function(n_inst) {
  ids <- mk_ids(n_inst)
  pos_env <- new.env(parent = emptyenv())
  for (id in ids) assign(id, 0, envir = pos_env)
  list(positions = pos_env, cash = 1e7)
}

mutate_env_positions <- function(state, ids, n_mutations) {
  for (k in seq_len(n_mutations)) {
    ctx <- list(positions = state$positions, cash = state$cash)
    id <- ids[[((k - 1L) %% length(ids)) + 1L]]
    cur <- get0(id, envir = state$positions, ifnotfound = 0)
    assign(id, cur + 1, envir = state$positions)
    state$cash <- state$cash - 100
  }
  state
}

# Variant (d): list state, integer-indexed positions + id->idx map
build_intvec <- function(n_inst) {
  ids <- mk_ids(n_inst)
  list(
    positions = rep(0, n_inst),
    positions_idx = stats::setNames(seq_len(n_inst), ids),
    cash = 1e7
  )
}

mutate_intvec <- function(state, ids, n_mutations) {
  for (k in seq_len(n_mutations)) {
    ctx <- list(positions = state$positions, cash = state$cash)
    id <- ids[[((k - 1L) %% length(ids)) + 1L]]
    idx <- state$positions_idx[[id]]
    cur <- state$positions[[idx]]
    state$positions[[idx]] <- cur + 1
    state$cash <- state$cash - 100
  }
  state
}

# Variant (e): list state, bare numeric + id->idx map, collapse::setv writes
# (in-place by C reference, bypassing R copy-on-modify)
build_collapse_setv <- function(n_inst) {
  build_intvec(n_inst)
}

mutate_collapse_setv <- function(state, ids, n_mutations) {
  for (k in seq_len(n_mutations)) {
    ctx <- list(positions = state$positions, cash = state$cash)
    id <- ids[[((k - 1L) %% length(ids)) + 1L]]
    idx <- state$positions_idx[[id]]
    cur <- state$positions[[idx]]
    collapse::setv(state$positions, idx, cur + 1, vind1 = TRUE)
    state$cash <- state$cash - 100
  }
  state
}


cat("=== tracemem evidence (3 mutations per variant) ===\n")
cat("(each printed line indicates R copied the vector for that write)\n\n")

cat("current        : ")
s_a <- build_current(100); tracemem(s_a$positions)
invisible(mutate_current(s_a, mk_ids(100), 3))
untracemem(s_a$positions); cat("\n")

cat("env_state      : ")
s_b <- build_env_state(100); tracemem(s_b$positions)
invisible(mutate_env_state(s_b, mk_ids(100), 3))
untracemem(s_b$positions); cat("\n")

cat("env_positions  : (environment slots have reference semantics; no tracemem)\n")

cat("intvec_id_map  : ")
s_d <- build_intvec(100); tracemem(s_d$positions)
invisible(mutate_intvec(s_d, mk_ids(100), 3))
untracemem(s_d$positions); cat("\n")

cat("collapse_setv  : ")
s_e <- build_collapse_setv(100); tracemem(s_e$positions)
invisible(mutate_collapse_setv(s_e, mk_ids(100), 3))
untracemem(s_e$positions); cat("\n")

cat("\n=== timing ===\n")

shapes <- list(
  list(n_inst = 100,  n_mutations = 10000),
  list(n_inst = 1000, n_mutations = 10000),
  list(n_inst = 1000, n_mutations = 100000)
)

cat(sprintf("%-6s %-9s | %7s %7s %7s %7s %7s | %7s %7s\n",
            "inst", "mut", "curr", "env_st", "env_pos", "intvec", "setv",
            "cur/eP", "cur/sv"))

res <- list()
for (s in shapes) {
  ids <- mk_ids(s$n_inst)

  state <- build_current(s$n_inst)
  t_current <- system.time(mutate_current(state, ids, s$n_mutations))[["elapsed"]]

  state <- build_env_state(s$n_inst)
  t_env_st <- system.time(mutate_env_state(state, ids, s$n_mutations))[["elapsed"]]

  state <- build_env_positions(s$n_inst)
  t_env_pos <- system.time(mutate_env_positions(state, ids, s$n_mutations))[["elapsed"]]

  state <- build_intvec(s$n_inst)
  t_intvec <- system.time(mutate_intvec(state, ids, s$n_mutations))[["elapsed"]]

  state <- build_collapse_setv(s$n_inst)
  t_setv <- system.time(mutate_collapse_setv(state, ids, s$n_mutations))[["elapsed"]]

  cat(sprintf("%-6d %-9d | %6.3fs %6.3fs %6.3fs %6.3fs %6.3fs | %6.1fx %6.1fx\n",
              s$n_inst, s$n_mutations,
              t_current, t_env_st, t_env_pos, t_intvec, t_setv,
              t_current / pmax(t_env_pos, 0.001),
              t_current / pmax(t_setv, 0.001)))

  res[[length(res) + 1L]] <- data.frame(
    n_inst = s$n_inst, n_mutations = s$n_mutations,
    current_s = t_current, env_state_s = t_env_st,
    env_positions_s = t_env_pos, intvec_id_map_s = t_intvec,
    collapse_setv_s = t_setv,
    speedup_env_positions = t_current / pmax(t_env_pos, 0.001),
    speedup_intvec = t_current / pmax(t_intvec, 0.001),
    speedup_setv = t_current / pmax(t_setv, 0.001)
  )
}

out <- "dev/bench/results/spike_state_positions_representation.csv"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(do.call(rbind, res), out, row.names = FALSE)
cat(sprintf("\nWROTE %s\n", out))
