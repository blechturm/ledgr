# Writes loop_freeze_changes.csv: the recorded changes to the 4a3e08b8
# freeze (loop_freeze.csv, which stays as loop_freeze.R generated it).
# loop_parity.R --freeze applies them: an `update` must name an existing
# (mode, workload, debug) row, an `add` a new one; anything else stops.
#
#   Rscript dev/lean_core/parity/loop_freeze_changes.R

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
row <- function(action, mode, workload, debug, lean_folds, refused, backstop, reason) {
  data.frame(action = action, mode = mode, workload = workload, debug = debug, lean_folds = lean_folds,
             refused = refused, backstop = backstop, reason = reason, stringsAsFactors = FALSE)
}
both <- function(...) rbind(row(..., debug = 0L), row(..., debug = 1L))
rows <- list()
add <- function(x) rows[[length(rows) + 1L]] <<- x

# Workstream 32: the five witnesses it added, from its committed gate
# records (evidence/loop_gate_debug0.csv, loop_gate_debug1.csv at 27747ab0).
for (w in c("witness_retained_context", "witness_error_cleanup", "witness_error_cleanup_error",
            "witness_error_custom", "witness_error_cleanup_seeded")) {
  add(both(action = "add", mode = "gate", workload = w, lean_folds = 1L, refused = "", backstop = "",
           reason = "Workstream 32 witness, path as its committed gate records"))
}

# Batch one and inert at debug 0: the 4a3e08b8 freeze holds them at debug 1
# only; a debug setting does not choose the execution path (the 106 frozen
# tuples match across debug settings, workstream 32 close review round 1),
# so each debug-0 row repeats its debug-1 row.
base <- utils::read.csv(file.path(here, "loop_freeze.csv"), stringsAsFactors = FALSE, na.strings = character(),
                        colClasses = c(refused = "character", backstop = "character"))
d1 <- base[base$mode %in% c("batch1", "inert") & base$debug == 1L, ]
for (i in seq_len(nrow(d1))) {
  add(row("add", d1$mode[[i]], d1$workload[[i]], 0L, d1$lean_folds[[i]], d1$refused[[i]], d1$backstop[[i]],
          "debug-0 row repeating the frozen debug-1 path (Cut 16 R4)"))
}

# Cut 16 decision 4: the two gate rows slice 2 moves, as the probe found.
add(both(action = "update", mode = "gate", workload = "dense_cost", lean_folds = 6L,
         refused = "sweep workers; compiled FIFO", backstop = "",
         reason = "Cut 16 decision 4: costs covered; its one-worker sweep candidates run lean"))
add(both(action = "update", mode = "gate", workload = "dense_risk_features", lean_folds = 0L,
         refused = "opening positions and imports; sweep workers", backstop = "",
         reason = "Cut 16 decision 4: costs and risk covered; next uncovered feature named"))

# Cut 16 slice-2 workloads: one lean fold, no refusal, no backstop
# (declared expected paths, LDG-3226 and LDG-3227).
slice2 <- c("s2_cost_fixed", "s2_cost_notional", "s2_cost_spread", "s2_cost_chain", "s2_risk_nonbinding",
            "s2_risk_bind", "s2_risk_long_only", "s2_risk_chain", "s2_risk_equity_refusal", "s2_risk_short_refusal",
            "s2_cost_insufficient", "s2_cost_sale_consumes", "s2_cost_nonpositive_price")
for (w in slice2) {
  add(both(action = "add", mode = "gate", workload = w, lean_folds = 1L, refused = "", backstop = "",
           reason = "Cut 16 slice-2 workload, declared path"))
}

out <- do.call(rbind, rows)
utils::write.csv(out, file.path(here, "loop_freeze_changes.csv"), row.names = FALSE)
cat(nrow(out), "changes:", paste(names(table(out$action)), table(out$action), collapse = ", "), "\n")
