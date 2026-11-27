ws4a_d3_whole <- c(
  ws4a_kernel_names, "ledgr_lot_apply_blocks", "ledgr_lot_book", "ledgr_lot_book_live", "ledgr_lot_book_live_count",
  "ledgr_lot_book_problem", "ledgr_lot_book_validate", "ledgr_lot_book_extend", "ledgr_lot_book_restrict",
  "ledgr_lot_book_from_opening", "ledgr_lot_book_from_events", "ledgr_lot_book_asof", "ledgr_prepare_accounting_events",
  "ledgr_replay_accounting_events", "ledgr_carrier_import_state", "ledgr_fold_positions_to_vec",
  "ledgr_carrier_settlement_state", "ledgr_carrier_settlement_install",
  "ledgr_carrier_compiled_pack", "ledgr_carrier_compiled_unpack", "ledgr_run_compiled_spot_fifo_batch",
  "ledgr_disposition_post", "ledgr_walk_forward_opening_from_run",
  "ledgr_walk_forward_carried_opening", "ledgr_state_asof", "ledgr_extract_fills_impl", "ledgr_run_terminal_recovery_equity",
  # The lean fold's lot kernel (fifo.R) and its P4.
  "lean_lot_tol", "lean_lot_head_sign", "lean_lot_input", "lean_lot_opening", "lean_lot_fill", "lean_lot_disposition",
  "lean_lot_first_failure", "lean_lot_fill_checked", "lean_lot_apply", "lean_lot_simple", "lean_lot_general",
  "lean_lot_apply_blocks", "lean_p4_apply"
)
ws4a_d3_region <- c("ledgr_run_fold_impl", "ledgr_sweep_candidate_execution", "ledgr_output_handler", "lean_fold_envelope_plain")
ws4a_d3_census <- c(
  # E opening import: opening positions, basis and carried lots onto the run axis.
  ledgr_lot_book_from_opening = "match(ids, basis_ids)",
  ledgr_lot_book_from_opening = "match(ids, instrument_ids)",
  ledgr_fold_positions_to_vec = "intersect(names(positions), instrument_ids)",
  ledgr_fold_positions_to_vec = "match(matched, instrument_ids)",
  ledgr_fold_positions_to_vec = "positions[matched]",
  # Replay import: ledger rows onto the replay axis.
  ledgr_prepare_accounting_events = "match(instrument_id, ids)",
  # Replay initial positions (imported as given) and its named result.
  ledgr_replay_accounting_events = "stats::setNames(rep(0, length(ids)), ids)",
  ledgr_replay_accounting_events = "intersect(names(initial_positions), ids)",
  ledgr_replay_accounting_events = "positions[matched]",
  ledgr_replay_accounting_events = "initial_positions[matched]",
  # Settlement: named state out; disposition parent IDs to book positions.
  ledgr_carrier_settlement_state = "stats::setNames(fold_state$positions, instrument_ids)",
  ledgr_disposition_post = "match(ids, position_names)",
  # Result: replayed state valued and recovered by ID.
  ledgr_state_asof = "stats::setNames(as.numeric(bars$close), bars$instrument_id)",
  ledgr_state_asof = "close_by_id[held_ids]",
  ledgr_run_terminal_recovery_equity = "match(held, instrument_ids)",
  # Walk-forward: as-of book and carried lots to the next window's opening.
  ledgr_walk_forward_opening_from_run = "stats::setNames(timeline$position[, 1L], timeline$ids)",
  ledgr_walk_forward_opening_from_run = "names(held) <- positions$instrument_id",
  ledgr_walk_forward_opening_from_run = "match(names(held), exp$universe)",
  ledgr_walk_forward_opening_from_run = "names(cost_basis) <- names(held)",
  ledgr_walk_forward_carried_opening = "match(ids, axis)",
  ledgr_walk_forward_carried_opening = "held[ids]",
  ledgr_walk_forward_carried_opening = "stats::setNames(basis, ids)",
  # Lean P4: the explicit decision rows less the clean fills (integer
  # ordinals matched to ordinals, not names).
  lean_p4_apply = "match(differs, clean_k, 0L)",
  # Lean envelope book region (its statements that touch the book, nested
  # stages included): P2's named positions snapshot and the debug-only
  # setNames(tq, ids) and execution-view field comparison, P4's ordinal
  # match, and the named result state out.
  lean_fold_envelope_plain = "names(positions_snapshot) <- ids",
  lean_fold_envelope_plain = "stats::setNames(tq, ids)",
  lean_fold_envelope_plain = "unclass(pv_view)[names(view)]",
  lean_fold_envelope_plain = "match(differs, clean_k, 0L)",
  lean_fold_envelope_plain = "stats::setNames(pos, ids)"
  # LDG-3167: the handler's accounting fact splits leg fees by row position;
  # its former close/open name pair is gone.
)
