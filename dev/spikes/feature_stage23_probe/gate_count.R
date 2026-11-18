# How many (definition, instrument) cells would a stage-3 gate admit on public
# substrates, and is every admitted cell identical to the general path?
# (CHARTER.md). Structural counts from synthetic fixtures; not a ranking.
#
# Substrates: the crossover fixtures (bar-native, dense); the seven oracle
# corpus substrates (dev/feature_parity/corpus.R: hostile prices and carry,
# panels, short and empty histories); a simulated point-in-time panel
# (ledgr_sim_pit_inputs(), declared sessions, with its venue closure, missing
# observation, delisting and halt). Definitions per substrate: TTR SMA 3
# (catalogue row), built-in SMA 3 (built-in) and one custom definition.
#
#   Rscript gate_count.R --lib=<installed ledgr> --out=results/gate_count.csv [--no-gate-clause=full]
# --no-gate-clause=full drops the full-coverage clause from the conservative
# gate: the gut demonstration (check.R expects differing cells).
source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                       winslash = "/")), "common.R"))
source(file.path(repo, "dev/feature_parity/corpus.R"))
gut <- arg("no-gate-clause", "")

sim_pit_substrate <- function(n_inst, from, to) {
  pit <- ledgr::ledgr_sim_pit_inputs(sprintf("S%03d", seq_len(n_inst)), from, to, seed = 20261118L)
  facts <- ledgr::ledgr_facts(
    ledgr::ledgr_facts_sessions(pit$sessions, venue_id = pit$recipe$venue_id %||% "DEMO_VENUE", knowledge = "evidenced"),
    ledgr::ledgr_facts_membership_snapshots(pit$membership, universe_id = pit$recipe$universe_id %||% "DEMO_UNIVERSE",
                                             complete = TRUE, knowledge = "evidenced"),
    ledgr::ledgr_facts_trading_status(pit$trading_status, knowledge = "evidenced"),
    ledgr::ledgr_facts_lifetime(pit$lifetime, knowledge = "evidenced"))
  db <- file.path(work, sprintf("sim_pit_%d.duckdb", n_inst))
  if (file.exists(db)) unlink(db)
  snapshot <- ledgr::ledgr_snapshot_from_df(pit$bars, pit$instruments, db_path = db, facts = facts,
                                            price_basis = "split_adjusted")
  exp <- ledgr::ledgr_experiment(snapshot, function(ctx, params) ctx$hold(),
    universe = ledgr::ledgr_universe_members(pit$recipe$universe_id %||% "DEMO_UNIVERSE"),
    features = list(ledgr::ledgr_ind_sma(3)), valuation_policy = ledgr::ledgr_valuation_stale(3),
    cost_model = ledgr::ledgr_cost_zero(), opening = ledgr::ledgr_opening(cash = 1e6),
    history_policy = ledgr::ledgr_history_policy(price_carry = 2L, output_carry = 2L))
  list(substrate = ns$ledgr_history_substrate_for_experiment(exp), snapshot = snapshot)
}

custom_def <- function() fx_def(ledgr::ledgr_indicator("custom_last", fn = function(w) as.numeric(utils::tail(w$close, 1L)),
                                                       requires_bars = 2L, required_fields = "close"))

check_cells <- function(substrate, certified, bounds, cells, rule) {
  d_out <- direct_compute(substrate, certified, bounds, cells, rule)
  bad <- list()
  for (d in seq_along(certified)) {
    adm <- cells$instrument[cells$def == names(certified)[[d]] & cells[[rule]]]
    for (i in adm) {
      g <- general_cell(substrate, certified[[d]], i, bounds)
      seg <- d_out$segments[d_out$segments[, "def"] == d & d_out$segments[, "instrument"] == i, , drop = FALSE]
      ex <- g$exceptions
      same_value <- identical(g$value, d_out$values[[d]][i, seq_len(bounds$to)])
      same_seg <- if (!nrow(seg)) !length(ex$segment_start) else
        length(ex$segment_start) == 1L && ex$segment_start == seg[1L, "start"] &&
          ex$segment_end == seg[1L, "end"] && identical(as.integer(ex$segment_ready), as.integer(seg[1L, "ready"]))
      extra <- setdiff(names(ex), c("segment_start", "segment_ready", "segment_end"))
      if (!(same_value && same_seg && !length(extra))) {
        bad[[length(bad) + 1L]] <- data.frame(def = names(certified)[[d]], instrument = i, value = same_value,
          segment = same_seg, exceptions = paste(extra, collapse = "+"), stringsAsFactors = FALSE)
      }
    }
  }
  if (length(bad)) do.call(rbind, bad) else NULL
}

substrates <- list()
for (shape in c("crossover_10x7200", "crossover_500x1260", "crossover_1166x252")) {
  snap <- crossover_snapshot(shape)
  substrates[[shape]] <- ns$ledgr_history_substrate_for_experiment(crossover_exp(snap, c(5, 10)))
  ledgr::ledgr_snapshot_close(snap)
}
substrates <- c(substrates, stats::setNames(fx_substrates(), paste0("corpus_", names(fx_substrates()))))
sim <- sim_pit_substrate(200L, "2019-01-01", "2020-12-31")
substrates$sim_pit_200x2y <- sim$substrate

rows <- list(); diffs <- list()
for (k in names(substrates)) {
  substrate <- substrates[[k]]
  # IDs are set at construction: an edited ID would no longer carry its
  # catalogue or built-in identity and would certify as custom.
  defs <- list(ttr_sma_3 = fx_def(ledgr::ledgr_ind_ttr("SMA", input = "close", id = "ttr_sma_3", n = 3L)),
               sma_3 = fx_def(ledgr::ledgr_ind_sma(3)), custom = custom_def())
  certified <- lapply(defs, ns$ledgr_feature_certify)
  bounds <- ns$ledgr_history_feature_bounds(substrate, ns$ledgr_history_calculation_start(substrate), NULL)
  cells <- gate_cells(substrate, certified, bounds)
  if (identical(gut, "full")) cells$conservative <- cells$certification %in% c("builtin", "catalogue") &
    cells$one_range & cells$no_terminal
  for (rule in c("conservative", "relaxed")) {
    bad <- check_cells(substrate, certified, bounds, cells, rule)
    if (!is.null(bad)) diffs[[paste(k, rule)]] <- cbind(substrate = k, rule = rule, bad)
    for (d in names(defs)) {
      cd <- cells[cells$def == d, ]
      rows[[paste(k, rule, d)]] <- data.frame(substrate = k, rule = rule, def = d,
        certification = cd$certification[[1L]], instruments = nrow(cd), admitted = sum(cd[[rule]]),
        fail_one_range = sum(!cd$one_range), fail_terminal = sum(!cd$no_terminal),
        fail_full = sum(!cd$full), fail_block = sum(!cd$block),
        admitted_differing = if (is.null(bad)) 0L else sum(bad$def == d), stringsAsFactors = FALSE)
    }
  }
}
ledgr::ledgr_snapshot_close(sim$snapshot)
out <- do.call(rbind, rows); rownames(out) <- NULL
utils::write.csv(out, arg("out"), row.names = FALSE)
d <- if (length(diffs)) do.call(rbind, diffs) else data.frame(substrate = character(), rule = character(), def = character(),
  instrument = integer(), value = logical(), segment = logical(), exceptions = character())
rownames(d) <- NULL
utils::write.csv(d, sub("\\.csv$", "_differing.csv", arg("out")), row.names = FALSE)
tot <- aggregate(cbind(instruments, admitted, admitted_differing) ~ rule + certification, out, sum)
print(tot)
