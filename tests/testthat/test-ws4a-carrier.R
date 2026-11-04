# ledgr-test-file-profile: review
#
# WS4a typed fold carrier: the LDG-3164 to LDG-3167 detectors and
# validators (inst/design/ledgr_v0_2_3_spec_packet/ws4a_carrier_design.md
# Section 6 and Section 3.2, rows owned by those tickets). Each predicate
# runs on production code and must pass there; each also shows its own
# compliant control passing and its own violating control failing.

ws4a_ns <- function() asNamespace("ledgr")

# Attachment adapter for Cut 5 planner oracles. Workstream 14 deleted the
# second (dense) planner; these inherited tests now drive the one canonical
# planner with fixed-basket values expressed through its typed execution
# packet and unrestricted execution view.
ws4b_test_build_pulse_plan <- function(context_pos,
                                       target_qty,
                                       position,
                                       actionable_k,
                                       pulse_idx,
                                       has_next,
                                       exec_ts,
                                       epoch_valid,
                                       bars_mat,
                                       cost_resolver,
                                       n_run) {
  ns <- ws4a_ns()
  open <- if (isTRUE(has_next)) {
    as.numeric(bars_mat$open[, pulse_idx + 1L])
  } else {
    rep(NA_real_, n_run)
  }
  n <- length(actionable_k)
  ns$ledgr_fold_build_availability_pulse_plan(
    context_pos = context_pos,
    target_qty = target_qty,
    position = position,
    actionable_k = actionable_k,
    member = rep(TRUE, length(context_pos)),
    execution = list(
      exec_ts = if (isTRUE(has_next)) exec_ts else NA_real_,
      has_next = isTRUE(has_next),
      open = open
    ),
    execution_view = list(
      member = rep(TRUE, n),
      restricted = rep(FALSE, n),
      reason_offset = rep(0L, n),
      reason_count = rep(0L, n),
      reason_code = integer()
    ),
    epoch_valid = epoch_valid,
    cost_resolver = cost_resolver,
    cash = 1e300,
    instrument_ids = paste0("I", seq_len(n_run))
  )
}

# A small typed book: AAA holds two lots, BBB is short one lot, CCC is empty.
ws4a_book <- function() {
  ns <- ws4a_ns()
  book <- ns$ledgr_lot_book(3L)
  book <- ns$ledgr_lot_fill(book, 1L, 1L, 2, 100, 0.5)$book
  book <- ns$ledgr_lot_fill(book, 1L, 1L, 1.5, 102, 0)$book
  ns$ledgr_lot_fill(book, 2L, -1L, 3, 50, 0.25)$book
}

ws4a_refused <- function(expr) {
  inherits(tryCatch({
    force(expr)
    NULL
  }, error = identity), "error")
}

# Schema 125 stores fill effects in typed columns. Hand-built ledger fixtures
# state the independently expected publication values instead of calling the
# product formula whose behavior they are meant to expose.
ws4a_fill_effects <- function(side, qty, price, fee) {
  cash <- ifelse(side == "BUY", -(qty * price + fee), qty * price - fee)
  position <- ifelse(side == "BUY", qty, -qty)
  list(cash_delta = cash, position_delta = position)
}

# Static helpers over the package's R/ sources (the fold phase checker's
# parser is reused, not copied).
ws4a_sources <- function() {
  root <- ledgr_test_source_root()
  checker <- new.env(parent = baseenv())
  sys.source(file.path(root, "tools", "check-fold-phase-contract.R"), envir = checker)
  files <- list.files(file.path(root, "R"), "\\.R$", full.names = TRUE)
  checker$ledgr_fold_phase_function_sources(files)
}
ws4a_calls <- function(e) {
  if (is.call(e)) c(list(e), unlist(lapply(as.list(e), ws4a_calls), recursive = FALSE))
}
ws4a_head <- function(e) {
  h <- if (is.call(e[[1L]]) && as.character(e[[1L]][[1L]]) %in% c("::", ":::")) e[[1L]][[3L]] else e[[1L]]
  if (is.symbol(h)) as.character(h) else ""
}
ws4a_heads <- function(e) vapply(ws4a_calls(e), ws4a_head, "")
ws4a_txt <- function(e) paste(deparse(e, width.cutoff = 500L), collapse = " ")
ws4a_assigns <- function(e) Filter(function(x) ws4a_head(x) %in% c("<-", "<<-", "="), ws4a_calls(e))
ws4a_loop_bodies <- function(e) {
  unlist(lapply(ws4a_calls(e), function(x) switch(ws4a_head(x),
    `for` = list(x[[4L]]), `while` = list(x[[3L]]), `repeat` = list(x[[2L]]),
    lapply = , vapply = , sapply = , Map = , mapply = Filter(function(y) {
      is.call(y) && identical(y[[1L]], as.name("function"))
    }, as.list(x)[-1L]),
    NULL
  )), recursive = FALSE)
}
# Adds one statement at the start of a function definition's body.
ws4a_inject <- function(e, stmt) {
  e[[3L]] <- as.call(c(as.list(e[[3L]])[1L], list(str2lang(stmt)), as.list(e[[3L]])[-1L]))
  e
}
ws4a_hits <- function(fns, check) {
  unlist(Map(function(nm, e) {
    h <- unique(check(e))
    if (length(h)) paste0(nm, ": ", h)
  }, names(fns), fns))
}

# The typed lot kernel: the operations and their shared implementation.
ws4a_kernel_names <- c(
  "ledgr_lot_apply", "ledgr_lot_opening", "ledgr_lot_fill",
  "ledgr_lot_disposition", "ledgr_lot_input", "ledgr_lot_applied",
  "ledgr_lot_blocks", "ledgr_lot_add_realized", "ledgr_lot_dust_tolerance_rows"
)

testthat::test_that("[WS4a V-book] the typed book group refuses the construction controls", {
  ns <- ws4a_ns()
  book <- ws4a_book()
  testthat::expect_null(ns$ledgr_lot_book_problem(book, 3L))
  testthat::expect_null(ns$ledgr_lot_book_problem(ns$ledgr_lot_book(0L), 0L))
  testthat::expect_identical(ns$ledgr_lot_book_validate(book, 3L), book)

  refused <- function(mutate) !is.null(ns$ledgr_lot_book_problem(mutate(book)))
  controls <- list(
    storage_type = function(b) { b$offset <- as.numeric(b$offset); b },
    shortened_column = function(b) { b$net_by_inst <- b$net_by_inst[-1L]; b },
    bound = function(b) { b$tail[[1L]] <- b$capacity[[1L]] + 1L; b },
    untyped_empty = function(b) { b$lot_qty <- list(); b },
    overlapping_segments = function(b) { b$offset[[2L]] <- b$offset[[2L]] - 1L; b },
    live_slot_na = function(b) { b$lot_qty[[b$offset[[1L]] + b$head[[1L]]]] <- NA_real_; b },
    net_not_lot_derived = function(b) { b$net_by_inst[[1L]] <- b$net_by_inst[[1L]] + 1; b },
    total_nan = function(b) { b$realized_comp <- NaN; b },
    empty_head_tail = function(b) { b$head[[3L]] <- 2L; b$tail[[3L]] <- 1L; b }
  )
  for (name in names(controls)) {
    testthat::expect_true(refused(controls[[name]]), info = name)
  }
  testthat::expect_error(
    ns$ledgr_lot_book_validate(controls$bound(book)),
    class = "ledgr_lot_state_invariant"
  )
  testthat::expect_false(is.null(ns$ledgr_lot_book_problem(book, 2L)))
})

testthat::test_that("[WS4a V-lot-input] lot input rows are typed, distinct and bounded per operation", {
  ns <- ws4a_ns()
  fill <- ns$.ledgr_lot_fill
  ok <- ns$ledgr_lot_input(fill, c(1L, 2L), c(1L, -1L), c(1, 2), c(10, 20), 0.5)
  testthat::expect_identical(ok$fee, c(0.5, 0.5))
  testthat::expect_identical(length(ns$ledgr_lot_input(fill, integer(), integer(), numeric(), numeric())$pos), 0L)
  invalid <- list(
    storage_type = quote(ns$ledgr_lot_input(fill, 1L, "BUY", 1, 10)),
    shortened_column = quote(ns$ledgr_lot_input(fill, c(1L, 2L), c(1L, 1L), 1, c(10, 20))),
    bound = quote(ns$ledgr_lot_input(fill, 0L, 1L, 1, 10)),
    untyped_empty = quote(ns$ledgr_lot_input(fill, integer(), integer(), list(), numeric())),
    duplicate_instrument = quote(ns$ledgr_lot_input(fill, c(1L, 1L), c(1L, 1L), c(1, 1), c(10, 10))),
    opening_zero = quote(ns$ledgr_lot_input(ns$.ledgr_lot_opening, 1L, 0L, 0, 10)),
    opening_side = quote(ns$ledgr_lot_input(ns$.ledgr_lot_opening, 1L, 1L, 2, 10)),
    disposition_fee = quote(ns$ledgr_lot_input(ns$.ledgr_lot_disposition, 1L, -1L, 2, 10, 1)),
    disposition_negative_price = quote(ns$ledgr_lot_input(ns$.ledgr_lot_disposition, 1L, -1L, 2, -1))
  )
  for (name in names(invalid)) {
    testthat::expect_error(eval(invalid[[name]]), class = "ledgr_invalid_lot_fill", info = name)
  }
  # Openings accept a signed quantity and a basis of either sign; a
  # disposition may close at zero price.
  testthat::expect_silent(ns$ledgr_lot_input(ns$.ledgr_lot_opening, c(1L, 2L), c(0L, 0L), c(-2, 3), c(-4, 0)))
  testthat::expect_silent(ns$ledgr_lot_input(ns$.ledgr_lot_disposition, 1L, -1L, 2, 0))
})

testthat::test_that("[WS4a V-applied-row] applied rows carry actual lot facts and refuse the controls", {
  ns <- ws4a_ns()
  book <- ws4a_book()
  input <- ns$ledgr_lot_input(ns$.ledgr_lot_fill, 1L, -1L, 2, 105, 0)
  applied <- ns$ledgr_lot_apply(book, input)$applied
  testthat::expect_identical(applied$position_before, 3.5)
  testthat::expect_identical(applied$position_after, 1.5)
  testthat::expect_identical(applied$close_qty, 2)
  testthat::expect_identical(applied$open_qty, 0)
  args <- applied
  build <- function(values) do.call(ns$ledgr_lot_applied, c(list(input), values))
  testthat::expect_identical(build(args), applied)
  controls <- list(
    storage_type = function(a) { a$close_qty <- 2L; a },
    shortened_column = function(a) { a$event_realized <- numeric(); a },
    bound = function(a) { a$close_qty <- -1; a },
    untyped_empty = function(a) { a$open_qty <- list(); a },
    open_on_pure_close = function(a) { a$open_qty <- 1; a }
  )
  for (name in names(controls)) {
    testthat::expect_error(build(controls[[name]](args)), class = "ledgr_lot_state_invariant", info = name)
  }
  opening <- ns$ledgr_lot_input(ns$.ledgr_lot_opening, 3L, 0L, 1, 7)
  opened <- ns$ledgr_lot_apply(book, opening)$applied
  testthat::expect_identical(c(opened$close_qty, opened$open_qty, opened$realized_delta), c(0, 0, 0))
  testthat::expect_error(
    do.call(ns$ledgr_lot_applied, c(list(opening), utils::modifyList(opened, list(open_qty = 1)))),
    class = "ledgr_lot_state_invariant"
  )
})

testthat::test_that("[WS4a V-state] the fold state holds run-axis positions and a typed book", {
  ns <- ws4a_ns()
  book <- ws4a_book()
  new_state <- function(...) {
    args <- list(cash = 100, positions = book$net_by_inst, lot_state = book, state_axis = c("AAA", "BBB"))
    override <- list(...)
    args[names(override)] <- override
    do.call(ns$ledgr_fold_state_new, args)
  }
  state <- new_state()
  testthat::expect_true(environmentIsLocked(state))
  testthat::expect_setequal(ls(state, all.names = TRUE), ns$.ledgr_fold_state_slots)
  testthat::expect_error(assign("undeclared", 1, envir = state), "locked")
  controls <- list(
    storage_type = list(positions = as.integer(c(3, -3, 0))),
    shortened_column = list(positions = c(3.5, -3)),
    named_positions = list(positions = c(AAA = 3.5, BBB = -3, CCC = 0)),
    bound = list(event_seq = 0L),
    untyped_empty = list(lot_state = list()),
    nan_cash = list(cash = NaN),
    numeric_state_axis = list(state_axis = 1),
    na_status = list(status = NA_character_),
    missing_specified = list(affected_exposure = list(value = NA_real_, details = list(), ts_utc = as.POSIXct(NA))),
    na_full_run = list(full_run = NA),
    numeric_last_executed = list(last_executed = 1),
    na_frozen_set = list(frozen_set = NA_character_),
    corrupt_book = list(lot_state = utils::modifyList(book, list(tail = book$tail + 4L)))
  )
  for (name in names(controls)) {
    testthat::expect_error(
      do.call(new_state, controls[[name]]),
      class = "ledgr_internal_error",
      info = name
    )
  }
})

testthat::test_that("[WS4a import] E import maps openings onto the run axis and refuses corrupt books", {
  ns <- ws4a_ns()
  ids <- c("AAA", "BBB", "CCC")
  opening <- ns$ledgr_lot_book_from_opening(ids, c(CCC = 2, AAA = -1), c(CCC = 10, AAA = 5))
  imported <- ns$ledgr_carrier_import_state(
    list(cash = 100, positions = c(CCC = 2, AAA = -1), lot_state = opening),
    ids
  )
  testthat::expect_identical(imported$positions, c(-1, 0, 2))
  testthat::expect_identical(imported$lot_state$net_by_inst, c(-1, 0, 2))
  testthat::expect_identical(imported$cash, 100)
  empty <- ns$ledgr_carrier_import_state(list(cash = 1, positions = NULL), ids)
  testthat::expect_identical(empty$lot_state, ns$ledgr_lot_book(3L))
  # A replayed book may extend the axis with entries that hold nothing.
  extended <- ns$ledgr_lot_book_extend(opening, 4L)
  testthat::expect_identical(
    ns$ledgr_carrier_import_state(list(cash = 1, positions = NULL, lot_state = extended), ids)$lot_state,
    opening
  )
  corrupt <- opening
  corrupt$lot_qty[[1L]] <- NA_real_
  testthat::expect_error(
    ns$ledgr_carrier_import_state(list(cash = 1, positions = NULL, lot_state = corrupt), ids),
    class = "ledgr_lot_state_invariant"
  )
  held_outside <- ns$ledgr_lot_fill(extended, 4L, 1L, 1, 1)$book
  testthat::expect_error(
    ns$ledgr_carrier_import_state(list(cash = 1, positions = NULL, lot_state = held_outside), ids),
    class = "ledgr_lot_state_invariant"
  )
  testthat::expect_error(
    ns$ledgr_lot_book_from_opening(ids, c(ZZZ = 1), c(ZZZ = 1)),
    class = "ledgr_lot_state_invariant"
  )
})

# D3's name-keyed lookups: match()-family calls, setNames(), intersect(),
# names<- and `[`/`[[` with a character index (a string, an ID-named symbol,
# or a names()/as.character()/paste() call).
ws4a_name_keyed <- function(e) {
  id_like <- function(i) is.character(i) || (is.symbol(i) && grepl("(^|_)(ids?|names?)$|^matched$", as.character(i))) ||
    (is.call(i) && ws4a_head(i) %in% c("names", "as.character", "paste", "paste0"))
  unlist(lapply(ws4a_calls(e), function(x) {
    h <- ws4a_head(x)
    if (h %in% c("match", "fmatch", "chmatch", "setNames", "intersect") ||
        (h %in% c("<-", "=") && is.call(x[[2L]]) && ws4a_head(x[[2L]]) == "names") ||
        (h %in% c("[", "[[") && length(x) >= 3L && any(vapply(as.list(x)[-(1:2)], id_like, logical(1))))) {
      substr(ws4a_txt(x), 1L, 70L)
    }
  }))
}
# Statements of a function body, descending through blocks, branches and loops.
ws4a_statements <- function(e) {
  if (!is.call(e)) return(list())
  h <- ws4a_head(e)
  if (h == "{") return(unlist(lapply(as.list(e)[-1L], ws4a_statements), recursive = FALSE))
  if (h == "if") return(c(list(e[[2L]]), unlist(lapply(as.list(e)[-(1:2)], ws4a_statements), recursive = FALSE)))
  if (h %in% c("for", "while")) return(ws4a_statements(e[[length(e)]]))
  if (h == "function") return(ws4a_statements(e[[3L]]))
  list(e)
}
# The book region of a large function: its statements that touch the book.
ws4a_book_region <- function(e) {
  as.call(c(as.name("{"), Filter(function(s) {
    n <- all.names(s)
    any(n %in% c("lot_state", "initial_lot_state", "book", "net_by_inst", "cost_basis_by_inst", "lot_res", "lot_result", "applied")) ||
      any(grepl("^ledgr_(lot_(book|apply|opening|fill|disposition)|carrier_)", n))
  }, ws4a_statements(e))))
}

# The name-keyed boundary census of LDG-3164 (ws4a_carrier_design.md
# Section 1.6): every name-keyed lookup in the lot kernel, the migrated book
# consumers and the book regions of the run, sweep, handler and envelope
# functions, each with its boundary role. Anything else is a D3 hit.
ws4a_d3_whole <- c(
  ws4a_kernel_names, "ledgr_lot_apply_blocks", "ledgr_lot_book", "ledgr_lot_book_live", "ledgr_lot_book_live_count",
  "ledgr_lot_book_problem", "ledgr_lot_book_validate", "ledgr_lot_book_extend", "ledgr_lot_book_restrict",
  "ledgr_lot_book_from_opening", "ledgr_lot_book_from_events", "ledgr_lot_book_asof", "ledgr_prepare_accounting_events",
  "ledgr_replay_accounting_events", "ledgr_carrier_import_state", "ledgr_fold_positions_to_vec",
  "ledgr_carrier_settlement_state", "ledgr_carrier_settlement_install", "ledgr_carrier_result_state",
  "ledgr_carrier_compiled_pack", "ledgr_carrier_compiled_unpack", "ledgr_run_compiled_spot_fifo_batch",
  "ledgr_fold_stage_apply", "ledgr_disposition_post", "ledgr_walk_forward_opening_from_run",
  "ledgr_walk_forward_carried_opening", "ledgr_state_asof", "ledgr_extract_fills_impl", "ledgr_run_terminal_recovery_equity"
)
ws4a_d3_region <- c("ledgr_run_fold_impl", "ledgr_sweep_candidate_execution", "ledgr_output_handler", "ledgr_fold_envelope")
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
  # Result: named fold state; replayed state valued and recovered by ID.
  ledgr_carrier_result_state = "stats::setNames(fold_state$positions, instrument_ids)",
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
  ledgr_walk_forward_carried_opening = "stats::setNames(basis, ids)"
  # LDG-3167: the handler's accounting fact splits leg fees by row position;
  # its former close/open name pair is gone.
)
ws4a_d3_hits <- function(fns) {
  unlist(lapply(names(fns), function(nm) {
    e <- if (nm %in% ws4a_d3_region) ws4a_book_region(fns[[nm]]) else fns[[nm]]
    h <- setdiff(unique(ws4a_name_keyed(e)), ws4a_d3_census[names(ws4a_d3_census) == nm])
    if (length(h)) paste0(nm, ": ", h)
  }))
}

testthat::test_that("[WS4a D3] the lot kernel and migrated book consumers index by position outside the census", {
  fns <- ws4a_sources()
  examined <- c(ws4a_d3_whole, ws4a_d3_region)
  testthat::expect_true(all(examined %in% names(fns)))
  testthat::expect_length(ws4a_d3_hits(fns[examined]), 0L)
  # Every census entry is still present: the census is exact, not a superset.
  found <- unlist(lapply(unique(names(ws4a_d3_census)), function(nm) {
    e <- if (nm %in% ws4a_d3_region) ws4a_book_region(fns[[nm]]) else fns[[nm]]
    paste(nm, unique(ws4a_name_keyed(e)))
  }))
  testthat::expect_setequal(paste(names(ws4a_d3_census), ws4a_d3_census), found)
  # Each large function's book region is found and non-empty.
  for (nm in ws4a_d3_region) testthat::expect_gt(length(ws4a_book_region(fns[[nm]])), 1L)
  testthat::expect_length(ws4a_hits(list(good = str2lang("function(b, pos) b$net_by_inst[[pos]]")), ws4a_name_keyed), 0L)
  testthat::expect_gt(length(ws4a_hits(list(bad = str2lang("function(b, id) b$net_by_inst[[id]]")), ws4a_name_keyed)), 0L)
  # Violating controls on production regions: a literal instrument index and a
  # match() lookup in the kernel; a new name-keyed site in a census boundary;
  # a name lookup in the run's book region.
  inject_hits <- function(nm, stmt) {
    bad <- fns[nm]
    bad[[nm]] <- ws4a_inject(bad[[nm]], stmt)
    ws4a_d3_hits(bad)
  }
  testthat::expect_gt(length(inject_hits("ledgr_lot_apply", "net <- book$net_by_inst[[\"synthetic\"]]")), 0L)
  testthat::expect_gt(length(inject_hits("ledgr_lot_apply", "pos <- match(input$instrument_id, book$ids)")), 0L)
  testthat::expect_gt(length(inject_hits("ledgr_disposition_post", "before <- state_value$positions[ids]")), 0L)
  testthat::expect_gt(length(inject_hits("ledgr_run_fold_impl", "initial_lot_state$net_by_inst <- opening_positions[instrument_ids]")), 0L)
})

testthat::test_that("[WS4a D7] openings take no Kahan step and keep a nonzero compensation", {
  ns <- ws4a_ns()
  calls <- 0L
  kahan <- ns$ledgr_lot_add_realized
  testthat::local_mocked_bindings(
    ledgr_lot_add_realized = function(realized, comp, delta) {
      calls <<- calls + 1L
      kahan(realized, comp, delta)
    },
    .package = "ledgr"
  )
  start <- ns$ledgr_lot_book(2L)
  start$realized_pnl <- 5
  start$realized_comp <- 1e-13
  no_kahan <- function(opening) {
    calls <<- 0L
    after <- opening(start, c(1L, 2L), c(3, -1.5), c(10, -2))$book
    calls == 0L && identical(after$realized_comp, start$realized_comp) &&
      identical(after$realized_pnl, start$realized_pnl)
  }
  testthat::expect_true(no_kahan(ns$ledgr_lot_opening))
  # M6: an opening that takes a Kahan step, with or without keeping its result.
  m6 <- function(book, pos, qty, price) {
    out <- ns$ledgr_lot_opening(book, pos, qty, price)
    step <- ns$ledgr_lot_add_realized(out$book$realized_pnl, out$book$realized_comp, 0)
    out$book$realized_pnl <- step[[1L]]
    out$book$realized_comp <- step[[2L]]
    out
  }
  m6_discarded <- function(book, pos, qty, price) {
    ns$ledgr_lot_add_realized(0, 0, 0)
    ns$ledgr_lot_opening(book, pos, qty, price)
  }
  testthat::expect_false(no_kahan(m6))
  testthat::expect_false(no_kahan(m6_discarded))
  # A fill takes exactly one step.
  calls <- 0L
  ns$ledgr_lot_fill(start, 1L, 1L, 1, 10)
  testthat::expect_identical(calls, 1L)
})

# D11: every write of a position in P4, replay, dispositions and the
# settlement install reads the lot-derived net (net_by_inst, no arithmetic),
# or is one of these named sources.
ws4a_d11_sources <- c(
  # P4: the pulse's working copy, the compiled batch's positions (the C++
  # writes each touched position from its lot net) and the install.
  ledgr_fold_stage_apply = "positions <- fold_state$positions",
  ledgr_fold_stage_apply = "positions <- as.numeric(batch$positions)",
  ledgr_fold_stage_apply = "fold_state$positions <- positions",
  # Replay: initial positions imported as given (cut 5 amendment); each
  # touched instrument's position_after from its applied rows (lot net).
  ledgr_replay_accounting_events = "positions <- stats::setNames(rep(0, length(ids)), ids)",
  ledgr_replay_accounting_events = "positions[matched] <- as.numeric(initial_positions[matched])",
  ledgr_replay_accounting_events = "positions[idx[last]] <- position_after[last]",
  # Settlement install: positions returned by the settlement boundary.
  ledgr_carrier_settlement_install = "positions <- value$positions",
  ledgr_carrier_settlement_install = "positions <- as.numeric(positions)",
  ledgr_carrier_settlement_install = "fold_state$positions <- positions"
)
ws4a_d11_hits <- function(fns) {
  unlist(lapply(names(fns), function(nm) {
    unlist(lapply(ws4a_assigns(fns[[nm]]), function(x) {
      if (!"positions" %in% all.names(x[[2L]])) return(NULL)
      rhs <- all.names(x[[3L]])
      from_net <- "net_by_inst" %in% rhs && !any(c("+", "-", "*", "/") %in% rhs)
      if (!from_net && !ws4a_txt(x) %in% ws4a_d11_sources[names(ws4a_d11_sources) == nm]) paste0(nm, ": ", ws4a_txt(x))
    }))
  }))
}

testthat::test_that("[WS4a D11] P4 and replay read positions from the lot-derived net", {
  fns <- ws4a_sources()
  examined <- fns[c("ledgr_fold_stage_apply", "ledgr_replay_accounting_events", "ledgr_disposition_post",
    "ledgr_carrier_settlement_install")]
  testthat::expect_length(ws4a_d11_hits(examined), 0L)
  testthat::expect_true(any(grepl("net_by_inst", vapply(examined, ws4a_txt, ""))))
  # Every named source is still a write in its function.
  writes <- unlist(lapply(names(examined), function(nm) paste(nm, vapply(ws4a_assigns(examined[[nm]]), ws4a_txt, ""))))
  testthat::expect_true(all(paste(names(ws4a_d11_sources), ws4a_d11_sources) %in% writes))
  p4 <- function(stmt) list(ledgr_fold_stage_apply = ws4a_inject(fns$ledgr_fold_stage_apply, stmt))
  testthat::expect_gt(length(ws4a_d11_hits(p4("positions[[inst_idx]] <- positions[[inst_idx]] + qty"))), 0L)
  testthat::expect_gt(length(ws4a_d11_hits(p4("fold_state$positions <- planned"))), 0L)
  testthat::expect_gt(length(ws4a_d11_hits(p4("positions[[inst_idx]] <- lot_res$book$net_by_inst[[inst_idx]] + qty"))), 0L)
})

testthat::test_that("[WS4a D12a-c D12e] identity, dependency, export and compiled-default boundaries are unchanged", {
  root <- ledgr_test_source_root()
  records <- file.path(root, "dev", "bench", "v0_2_3_ws4a", "records")
  testthat::skip_if_not(dir.exists(records), "WS4a frozen detector records are in the source checkout only")
  frozen <- utils::read.csv(file.path(records, "detectors", "frozen.csv"), colClasses = "character")
  frozen <- stats::setNames(frozen$value, frozen$id)
  desc <- read.dcf(file.path(root, "DESCRIPTION"))
  deps <- function(d) {
    paste(gsub("\\s+", "", d[, intersect(c("Depends", "Imports", "LinkingTo", "Suggests"), colnames(d))]), collapse = ";")
  }
  ns_lines <- readLines(file.path(root, "NAMESPACE"))
  exports <- function(lines) {
    paste(sort(grep("^(export|S3method)\\(", lines, value = TRUE), method = "radix"), collapse = ";")
  }
  default_model <- function(f) deparse(formals(f)$compiled_accounting_model)
  testthat::expect_identical(deps(desc), frozen[["D12b"]])
  frozen_exports <- strsplit(frozen[["D12c"]], ";", fixed = TRUE)[[1L]]
  expected_exports <- paste(sort(c(
    setdiff(frozen_exports, c(
      "export(ledgr_backtest)", "export(ledgr_select_top_n)",
      "export(ledgr_signal_feature)", "export(ledgr_strategy_schedule)"
    )),
    'S3method("$",ledgr_pulse_context)',
    'S3method("$",ledgr_strategy_state_view)',
    'S3method("[[",ledgr_pulse_context)',
    'S3method("[[",ledgr_strategy_state_view)',
    "S3method(names,ledgr_pulse_context)",
    "S3method(str,ledgr_pulse_context)",
    "export(ledgr_schedule_due)", "export(ledgr_select_lowest)",
    "export(ledgr_select_top)", "export(ledgr_strategy_result)",
    "export(ledgr_target_adjust)"
  ), method = "radix"), collapse = ";")
  testthat::expect_identical(exports(ns_lines), expected_exports)
  testthat::expect_identical(default_model(ledgr_run), frozen[["D12e"]])
  changed <- desc
  changed[, "Imports"] <- paste0(changed[, "Imports"], ", newpkg")
  testthat::expect_false(identical(deps(changed), frozen[["D12b"]]))
  testthat::expect_false(identical(exports(c(ns_lines, "export(ledgr_new)")), expected_exports))
  flipped <- ledgr_run
  formals(flipped)$compiled_accounting_model <- "spot_fifo"
  testthat::expect_false(identical(default_model(flipped), frozen[["D12e"]]))

  # D12a: C1's recorded configuration hash is still config_hash() of its
  # recorded configuration; one changed configuration field breaks it.
  c1 <- utils::read.csv(file.path(records, "C1", "run.runs.csv"), colClasses = "character", check.names = FALSE)
  c1_hash <- function(json) {
    ledgr:::config_hash(yyjsonr::read_json_str(
      gsub("\\\\", "\\", json, fixed = TRUE),
      opts = yyjsonr::opts_read_json(arr_of_objs_to_df = FALSE, obj_of_arrs_to_df = FALSE, length1_array_asis = TRUE)
    ))
  }
  config_json <- c1[["config_json:character"]]
  config <- yyjsonr::read_json_str(
    gsub("\\\\", "\\", config_json, fixed = TRUE),
    opts = yyjsonr::opts_read_json(
      arr_of_objs_to_df = FALSE,
      obj_of_arrs_to_df = FALSE,
      length1_array_asis = TRUE
    )
  )
  testthat::expect_error(
    ledgr:::config_hash(config),
    class = "ledgr_invalid_config"
  )
  config$identity_rule_version <- 5L
  current_hash <- ledgr:::config_hash(config)
  edited <- config
  edited$initial_cash <- edited$initial_cash + 1
  testthat::expect_false(identical(ledgr:::config_hash(edited), current_hash))

  # D12a production predicate: a run built now by the production configuration
  # constructor and run store binds the runs table as C1's base record does
  # (A0's wall-clock and version exclusions aside), records C1's configuration
  # fields to two levels (strategy parameters are the run's own), and stores
  # config_hash() of its stored configuration. Control: one added field.
  db <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(ledgr_test_compact_bars(), db_path = db)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, function(ctx, params) ctx$hold(), cost_model = ledgr_cost_zero())
  close(ledgr_run(exp, run_id = "d12a", seed = 1L))
  h <- ledgr_test_open_duckdb(db)
  runs <- DBI::dbGetQuery(h$con, "SELECT * FROM runs WHERE run_id = 'd12a'")
  ledgr_test_close_duckdb(h$con, h$drv)
  runs <- runs[setdiff(names(runs), c("created_at_utc", "engine_version"))]
  testthat::expect_identical(paste0(names(runs), ":", vapply(runs, function(x) paste(class(x), collapse = "/"), "")), names(c1))
  read <- function(json) yyjsonr::read_json_str(json, opts = yyjsonr::opts_read_json(
    arr_of_objs_to_df = FALSE, obj_of_arrs_to_df = FALSE, length1_array_asis = TRUE))
  fields <- function(cfg) sort(c(names(cfg), unlist(lapply(setdiff(names(cfg), c("strategy", "strategy_params")), function(k) {
    if (is.list(cfg[[k]]) && !is.null(names(cfg[[k]]))) paste0(k, "/", names(cfg[[k]]))
  }))))
  stored <- read(runs$config_json)
  testthat::expect_identical(ledgr:::config_hash(stored), runs$config_hash)
  recorded_fields <- fields(read(gsub("\\\\", "\\", config_json, fixed = TRUE)))
  testthat::expect_identical(
    fields(stored),
    sort(c(
      recorded_fields,
      "strategy_state", "strategy_state/fields", "strategy_state/rule_version"
    ), method = "radix")
  )
  added <- utils::modifyList(stored, list(engine = list(added_field = 1)))
  testthat::expect_false(identical(fields(added), fields(stored)))
  testthat::expect_false(identical(ledgr:::config_hash(added), runs$config_hash))
})

testthat::test_that("[WS4a D15] the lot kernel never writes a book column by reference", {
  fns <- ws4a_sources()
  lot <- fns[grepl("^ledgr_lot_", names(fns))]
  check <- function(e) intersect(ws4a_heads(e), c("setv", "set", "setattr", ":=", "setDT"))
  testthat::expect_length(ws4a_hits(lot, check), 0L)
  bad <- ws4a_inject(fns$ledgr_lot_apply, "collapse::setv(book$lot_qty, 1L, 0)")
  testthat::expect_gt(length(ws4a_hits(list(kernel = bad), check)), 0L)

  # Runtime: a kernel call leaves its input book untouched.
  ns <- ws4a_ns()
  book <- ws4a_book()
  before <- unserialize(serialize(book, NULL))
  ns$ledgr_lot_fill(book, c(1L, 2L, 3L), c(-1L, 1L, 1L), c(2.5, 4, 1), c(99, 49, 10), c(0, 0.1, 0))
  testthat::expect_identical(book, before)
  by_reference <- function(b) {
    out <- ns$ledgr_lot_fill(b, 1L, 1L, 1, 101)
    collapse::setv(b$lot_qty, seq_along(out$book$lot_qty), out$book$lot_qty, vind1 = TRUE)
    out
  }
  shared <- unserialize(serialize(book, NULL))
  by_reference(shared)
  testthat::expect_false(identical(shared, before))
})

testthat::test_that("[WS4a D17 F4.35] the lot kernel computes no cash and openings move no cash", {
  fns <- ws4a_sources()
  kernel <- fns[intersect(ws4a_kernel_names, names(fns))]
  testthat::expect_length(kernel, length(ws4a_kernel_names))
  check <- function(e) grep("cash", all.names(e), value = TRUE)
  testthat::expect_length(ws4a_hits(kernel, check), 0L)
  bad <- ws4a_inject(fns$ledgr_lot_apply, "cash <- cash - qty * price")
  testthat::expect_gt(length(ws4a_hits(list(kernel = bad), check)), 0L)

  # Opening caller witness: an opening event replays with its published zero
  # cash effect and leaves cash unchanged.
  ns <- ws4a_ns()
  rows <- ns$ledgr_accounting_rows(
    event_id = "o1", run_id = "r", ts_utc = as.POSIXct("2020-01-02", tz = "UTC"),
    event_type = "CASHFLOW", instrument_id = "AAA", side = NA_character_, qty = 3,
    price = 12, fee = 0, event_seq = 1L,
    source = "opening_position", cash_delta = 0, position_delta = 3
  )
  prepared <- ns$ledgr_prepare_accounting_events(rows, "AAA")
  cash_after <- function(replay) replay(prepared, initial_cash = 100)$cash_after
  testthat::expect_identical(cash_after(ns$ledgr_replay_accounting_events), 100)
  mutant <- ns$ledgr_replay_accounting_events
  body(mutant) <- str2lang(sub(
    "ledgr_cash_scan(initial_cash, prepared$cash_delta)",
    "ledgr_cash_scan(initial_cash, prepared$cash_delta - prepared$lot_qty * prepared$lot_price)",
    paste(deparse(body(mutant), width.cutoff = 500L), collapse = "\n"),
    fixed = TRUE
  ))
  testthat::expect_false(identical(cash_after(mutant), 100))
})

testthat::test_that("[WS4a D18] a kernel call refuses duplicate instruments", {
  ns <- ws4a_ns()
  refuses <- function(kernel) ws4a_refused(kernel(ns$ledgr_lot_book(2L), c(1L, 1L), c(1L, 1L), c(1, 2), c(10, 11)))
  testthat::expect_true(refuses(ns$ledgr_lot_fill))
  testthat::expect_error(
    ns$ledgr_lot_fill(ns$ledgr_lot_book(2L), c(1L, 1L), c(1L, 1L), c(1, 2), c(10, 11)),
    class = "ledgr_invalid_lot_fill"
  )
  accepting <- function(book, pos, side, qty, price) {
    input <- list(operation = rep(ns$.ledgr_lot_fill, length(pos)), pos = pos, side = side, qty = qty,
      price = price, fee = numeric(length(pos)), position_before = rep(NA_real_, length(pos)),
      realized_model_pnl = rep(NA_real_, length(pos)))
    ns$ledgr_lot_apply(book, input)
  }
  testthat::expect_false(refuses(accepting))
})

testthat::test_that("[WS4a D19] no named-list FIFO implementation is defined", {
  fns <- ws4a_sources()
  fifo <- c(
    "ledgr_lot_state", "ledgr_lot_apply_fill", "ledgr_position_from_lots",
    "ledgr_lot_ensure_instrument", "ledgr_lot_values", "ledgr_lot_count",
    "ledgr_lot_apply_opening", "ledgr_lot_apply_event", "ledgr_lot_compact",
    "ledgr_lot_append_vectors", "ledgr_lot_direction", "ledgr_lot_state_from_opening",
    "ledgr_lot_state_from_events", "ledgr_lot_state_asof",
    "ledgr_compiled_spot_fifo_pack_lots", "ledgr_compiled_spot_fifo_unpack_lots"
  )
  testthat::expect_length(intersect(names(fns), fifo), 0L)
  testthat::expect_true("ledgr_lot_apply" %in% names(fns))
  with_old <- c(names(fns), "ledgr_lot_apply_fill")
  testthat::expect_gt(length(intersect(with_old, fifo)), 0L)
})

testthat::test_that("[WS4a D23] replay adds each published cash effect exactly once", {
  ns <- ws4a_ns()
  effects <- ws4a_fill_effects(c("BUY", "SELL"), c(2, 1), c(10, 12), c(1, 1))
  ev <- ns$ledgr_accounting_rows(
    event_id = c("e1", "e2"), run_id = c("r", "r"),
    ts_utc = as.POSIXct(c("2020-01-02 21:00:00", "2020-01-03 21:00:00"), tz = "UTC"),
    event_type = c("FILL", "FILL"), instrument_id = c("A", "A"), side = c("BUY", "SELL"),
    qty = c(2, 1), price = c(10, 12), fee = c(1, 1),
    cash_delta = effects$cash_delta, position_delta = effects$position_delta,
    event_seq = 1:2
  )
  cash_ok <- function(replay) {
    isTRUE(all.equal(replay(ns$ledgr_prepare_accounting_events(ev, "A"), initial_cash = 100)$cash, 100 - 21 + 11))
  }
  testthat::expect_true(cash_ok(ns$ledgr_replay_accounting_events))
  twice <- ns$ledgr_replay_accounting_events
  body(twice) <- str2lang(sub(
    "ledgr_cash_scan(initial_cash, prepared$cash_delta)",
    "ledgr_cash_scan(initial_cash, 2 * prepared$cash_delta)",
    paste(deparse(body(twice), width.cutoff = 500L), collapse = "\n"),
    fixed = TRUE
  ))
  testthat::expect_false(cash_ok(twice))
})

testthat::test_that("[WS4a D25] independent lot work is vectorized; replay applies whole blocks", {
  fns <- ws4a_sources()
  ops <- c("ledgr_lot_apply", "ledgr_lot_opening", "ledgr_lot_fill", "ledgr_lot_disposition", "ledgr_lot_input")
  # Lot work: a lot operation call, or a write to the book or to the kernel's
  # per-instrument lot and consumption vectors.
  lot_names <- c("book", "lot_qty", "lot_price", "offset", "capacity", "head", "tail", "net_by_inst", "cost_basis_by_inst",
    "q", "p", "off", "cap", "net", "remaining", "close_qty", "open_qty", "realized_close", "basis_delta", "new_basis", "steps")
  lot_work <- function(b) {
    c(intersect(ws4a_heads(b), ops),
      unlist(lapply(ws4a_assigns(b), function(x) intersect(all.names(x[[2L]]), lot_names))))
  }
  # The explicitly identified loops: the FIFO depth loop of the kernel; the
  # ordered aggregate scan, which may write only the totals and per-event
  # aggregate facts; and replay's consecutive conflict-free block loop
  # (decision 6), which applies one whole block per operation call.
  depth <- "while (length(active) > 0L)"
  scan <- "for (k in seq_len(m))"
  scan_writes <- c("total", "realized", "comp", "step", "event_cost_basis", "event_realized")
  block <- "for (b in seq_along(starts))"
  # Callback loops (lapply and friends) may do no lot work at all.
  callback_check <- function(e) {
    callbacks <- Filter(function(x) ws4a_head(x) %in%
      c("lapply", "vapply", "sapply", "Map", "mapply"), ws4a_calls(e))
    unlist(lapply(callbacks, function(x)
      unlist(lapply(ws4a_loop_bodies(x), lot_work))))
  }
  check <- function(e) {
    c(callback_check(e), unlist(lapply(Filter(function(x) ws4a_head(x) %in% c("for", "while", "repeat"), ws4a_calls(e)), function(x) {
      header <- sub(" \\{.*$", "", ws4a_txt(x))
      body <- x[[length(x)]]
      if (header %in% c(depth, block)) return(NULL)
      if (header == scan) {
        targets <- vapply(ws4a_assigns(body), function(a) {
          v <- a[[2L]]
          while (is.call(v)) v <- v[[2L]]
          as.character(v)
        }, "")
        return(if (!all(targets %in% scan_writes)) paste("aggregate scan writes", setdiff(targets, scan_writes)))
      }
      if (length(lot_work(body))) paste(header, "does lot work:", paste(unique(lot_work(body)), collapse = ","))
    })))
  }
  # LDG-3167: P4 applies the pulse's fills as one candidate block, so P4 and
  # its candidate join the examined functions.
  kernel <- fns[c(intersect(ws4a_kernel_names, names(fns)), "ledgr_lot_apply_blocks", "ledgr_fold_stage_apply",
    "ledgr_fold_fill_candidate")]
  testthat::expect_length(ws4a_hits(kernel, check), 0L)
  p4_loop <- paste("for (i in seq_along(fill$k)) fold_state$lot_state <- ledgr_lot_fill(fold_state$lot_state,",
    "fill$pos[[i]], fill$side[[i]], fill$qty[[i]], fill$price[[i]], fill$fee[[i]])$book")
  testthat::expect_gt(length(ws4a_hits(list(p4 = ws4a_inject(fns$ledgr_fold_stage_apply, p4_loop)), check)), 0L)
  headers <- function(f) vapply(Filter(function(x) ws4a_head(x) %in% c("for", "while"), ws4a_calls(f)), function(x) sub(" \\{.*$", "", ws4a_txt(x)), "")
  testthat::expect_true(all(c(depth, scan) %in% headers(fns$ledgr_lot_apply)))
  testthat::expect_true(block %in% headers(fns$ledgr_lot_apply_blocks))
  scan_txt <- grep("^for \\(k in seq_len\\(m\\)\\)", vapply(Filter(function(x) ws4a_head(x) == "for",
    ws4a_calls(fns$ledgr_lot_apply)), ws4a_txt, ""), value = TRUE)
  testthat::expect_length(scan_txt, 1L)
  testthat::expect_true(grepl("ledgr_lot_add_realized", scan_txt))
  permitted <- str2lang("function(b, pos, q, basis) { b <- ledgr_lot_apply(b, pos); s <- 0; for (i in seq_along(basis)) s <- s + basis[[i]]; b }")
  per_instrument <- str2lang("function(b, pos, q) { for (k in seq_along(pos)) b <- ledgr_lot_fill(b, pos[k], 1L, q[k], 1); b }")
  testthat::expect_length(ws4a_hits(list(ok = permitted), check), 0L)
  testthat::expect_gt(length(ws4a_hits(list(bad = per_instrument), check)), 0L)
  # Violating controls on the kernel: an inline per-instrument segment write
  # in a loop, and lot work moved into the ordered aggregate scan.
  inline <- "for (k in seq_along(pos)) book$lot_qty[book$offset[pos[k]] + 1L] <- quantity[k]"
  testthat::expect_gt(length(ws4a_hits(list(kernel = ws4a_inject(fns$ledgr_lot_apply, inline)), check)), 0L)
  # Callback controls: per-instrument dispatch through lapply (close review
  # re-review 1, N2).
  for (stmt in c(
    "lapply(seq_along(pos), function(k) ledgr_lot_fill(book, pos[k], 1L, quantity[k], 1))",
    "lapply(seq_along(pos), function(k) book$lot_qty[book$offset[pos[k]] + 1L] <- quantity[k])"
  )) testthat::expect_gt(length(ws4a_hits(
    list(kernel = ws4a_inject(fns$ledgr_lot_apply, stmt)), check)), 0L)
  in_scan <- str2lang(sub("event_realized[[k]] <- realized", "event_realized[[k]] <- realized; q[[k]] <- NA_real_",
    paste(deparse(fns$ledgr_lot_apply, width.cutoff = 500L), collapse = "\n"), fixed = TRUE))
  testthat::expect_false(identical(in_scan, fns$ledgr_lot_apply))
  testthat::expect_gt(length(ws4a_hits(list(kernel = in_scan), check)), 0L)

  # Runtime: replaying one pulse's fills on distinct instruments is one
  # fill-operation call (blocks), not one call per instrument.
  ns <- ws4a_ns()
  effects <- ws4a_fill_effects(
    c("BUY", "BUY", "SELL", "SELL"), c(2, 1, 3, 1),
    c(10, 12, 9, 11), c(1, 0, 0.5, 0)
  )
  ev <- ns$ledgr_accounting_rows(
    event_id = paste0("e", 1:4), run_id = rep("r", 4),
    ts_utc = as.POSIXct("2020-01-02 21:00:00", tz = "UTC") + c(0, 0, 0, 86400),
    event_type = rep("FILL", 4), instrument_id = c("A", "B", "C", "A"), side = c("BUY", "BUY", "SELL", "SELL"),
    qty = c(2, 1, 3, 1), price = c(10, 12, 9, 11), fee = c(1, 0, 0.5, 0),
    cash_delta = effects$cash_delta, position_delta = effects$position_delta,
    event_seq = 1:4
  )
  prepared <- ns$ledgr_prepare_accounting_events(ev, c("A", "B", "C"))
  calls <- 0L
  fill <- ns$ledgr_lot_fill
  testthat::local_mocked_bindings(
    ledgr_lot_fill = function(...) {
      calls <<- calls + 1L
      fill(...)
    },
    .package = "ledgr"
  )
  ns$ledgr_replay_accounting_events(prepared)
  testthat::expect_identical(calls, 2L)
})

testthat::test_that("[WS4a replay blocks] block replay equals one operation per event", {
  ns <- ws4a_ns()
  ts <- as.POSIXct("2020-01-02 21:00:00", tz = "UTC")
  sell <- ws4a_fill_effects(c("SELL", "SELL"), c(2.5, 1.25), c(11.37, 20.11), c(0.4, 0.2))
  buy <- ws4a_fill_effects(c("BUY", "BUY"), c(3, 0.75), c(19.5, 33.3), c(0, 0.1))
  source <- rep(NA_character_, 9L)
  source[1:4] <- "opening_position"
  source[[7L]] <- "corporate_action_cash"
  source_fact_id <- rep(NA_character_, 9L)
  source_fact_id[[7L]] <- "cash-7"
  ev <- ns$ledgr_accounting_rows(
    event_id = paste0("e", 1:9), run_id = "r",
    ts_utc = ts + c(0, 0, 0, 0, 86400, 86400, 86400, 172800, 172800),
    event_type = c("CASHFLOW", "CASHFLOW", "CASHFLOW", "CASHFLOW", "FILL", "FILL", "CASHFLOW", "FILL", "FILL"),
    instrument_id = c("A", "A", "B", "C", "A", "B", "A", "B", "C"),
    side = c(NA, NA, NA, NA, "SELL", "SELL", NA, "BUY", "BUY"),
    qty = c(1.5, 1.75, 0.5, -2, 2.5, 1.25, NA, 3, 0.75),
    price = c(10.25, 10.5, 21, 30, 11.37, 20.11, NA, 19.5, 33.3),
    fee = c(0, 0, 0, 0, 0.4, 0.2, 0, 0, 0.1),
    cash_delta = c(0, 0, 0, 0, sell$cash_delta, 3.5, buy$cash_delta),
    position_delta = c(1.5, 1.75, 0.5, -2, sell$position_delta, 0, buy$position_delta),
    source = source, source_fact_id = source_fact_id,
    entitled_quantity = c(rep(NA_real_, 6L), 1, NA_real_, NA_real_),
    gross_cash_per_parent_unit = c(rep(NA_real_, 6L), 3.5, NA_real_, NA_real_),
    amount_policy_id = c(rep(NA_character_, 6L), "gross", NA_character_, NA_character_),
    posting_policy_id = c(rep(NA_character_, 6L), "effective_close", NA_character_, NA_character_),
    late_arrival = c(rep(NA, 6L), FALSE, NA, NA),
    affected_marked_exposure = c(rep(NA_real_, 6L), 0, NA_real_, NA_real_),
    event_seq = 1:9
  )
  prepared <- ns$ledgr_prepare_accounting_events(ev, c("A", "B", "C"))
  replay <- ns$ledgr_replay_accounting_events(prepared, initial_cash = 50)
  book <- ns$ledgr_lot_book(3L)
  rows <- which(prepared$operation != 2L)
  for (i in rows) {
    res <- if (prepared$operation[[i]] == 3L) {
      ns$ledgr_lot_opening(book, prepared$instrument_index[[i]], prepared$lot_qty[[i]], prepared$lot_price[[i]])
    } else {
      ns$ledgr_lot_fill(book, prepared$instrument_index[[i]], prepared$lot_side[[i]],
        prepared$lot_qty[[i]], prepared$lot_price[[i]], prepared$fee[[i]])
    }
    book <- res$book
    testthat::expect_identical(replay$event_realized[[i]], res$applied$event_realized)
    testthat::expect_identical(replay$event_cost_basis[[i]], res$applied$event_cost_basis)
    testthat::expect_identical(replay$position_after[[i]], res$applied$position_after)
    testthat::expect_identical(replay$close_qty[[i]], res$applied$close_qty)
    testthat::expect_identical(replay$open_qty[[i]], res$applied$open_qty)
  }
  testthat::expect_identical(replay$lot_state, book)
  testthat::expect_identical(replay$position_after[[7L]], book$net_by_inst[[1L]])
  # Cash adds each published effect once, in event order.
  effects <- c(0, 0, 0, 0, 2.5 * 11.37 - 0.4, 1.25 * 20.11 - 0.2, 3.5, -(3 * 19.5), -(0.75 * 33.3 + 0.1))
  testthat::expect_identical(replay$cash, Reduce(`+`, effects, 50))
  testthat::expect_identical(unname(replay$positions), book$net_by_inst)
})

testthat::test_that("[WS4a compiled boundary] pack and unpack gather typed lots and keep the Kahan state", {
  ns <- ws4a_ns()
  book <- ws4a_book()
  book$realized_comp <- -1.5 * 2^-52
  pack <- ns$ledgr_carrier_compiled_pack(book)
  testthat::expect_identical(pack$lot_inst_idx, c(1L, 1L, 2L))
  testthat::expect_identical(pack$lot_qty, c(2, 1.5, -3))
  batch <- c(pack, list(
    net_by_inst = book$net_by_inst, cost_basis_by_inst = book$cost_basis_by_inst,
    total_cost_basis = book$total_cost_basis, realized_pnl = book$realized_pnl,
    realized_comp = book$realized_comp
  ))
  unpacked <- ns$ledgr_carrier_compiled_unpack(batch, 3L)
  live <- function(b) ns$ledgr_lot_book_live(b)[c("pos", "qty", "price")]
  testthat::expect_identical(live(unpacked), live(book))
  testthat::expect_identical(unpacked[c("net_by_inst", "cost_basis_by_inst", "total_cost_basis", "realized_pnl", "realized_comp")],
    book[c("net_by_inst", "cost_basis_by_inst", "total_cost_basis", "realized_pnl", "realized_comp")])
  shuffled <- batch
  shuffled[c("lot_inst_idx", "lot_qty", "lot_price")] <- lapply(batch[c("lot_inst_idx", "lot_qty", "lot_price")], `[`, c(3L, 1L, 2L))
  testthat::expect_identical(live(ns$ledgr_carrier_compiled_unpack(shuffled, 3L)), live(book))
  dropped <- batch
  dropped$realized_comp <- 0
  testthat::expect_false(identical(ns$ledgr_carrier_compiled_unpack(dropped, 3L)$realized_comp, book$realized_comp))
})

testthat::test_that("[WS4a U-3164] book totals are typed scalars; empty operations keep the book and type their rows", {
  ns <- ws4a_ns()
  book <- ws4a_book()
  for (field in c("total_cost_basis", "realized_pnl", "realized_comp")) {
    controls <- list(integer = 0L, two = c(book[[field]], 1), empty = numeric(), na = NA_real_)
    for (name in names(controls)) {
      bad <- book
      bad[[field]] <- controls[[name]]
      testthat::expect_false(is.null(ns$ledgr_lot_book_problem(bad)), info = paste(field, name))
    }
  }
  # The review's control: a length-2 and a length-0 total that concatenate to three.
  bad <- book
  bad$total_cost_basis <- c(0, 1)
  bad$realized_pnl <- numeric()
  testthat::expect_false(is.null(ns$ledgr_lot_book_problem(bad)))
  typed_empty <- function(applied) {
    identical(names(applied), c("position_before", "position_after", "close_qty", "open_qty", "realized_close",
      "realized_delta", "event_realized", "event_cost_basis")) &&
      all(vapply(applied, function(v) is.double(v) && length(v) == 0L, logical(1)))
  }
  empty <- list(
    opening = ns$ledgr_lot_opening(book, integer(), numeric(), numeric()),
    fill = ns$ledgr_lot_fill(book, integer(), integer(), numeric(), numeric()),
    disposition = ns$ledgr_lot_disposition(book, integer(), integer(), numeric(), numeric())
  )
  for (name in names(empty)) {
    testthat::expect_identical(empty[[name]]$book, book, info = name)
    testthat::expect_true(typed_empty(empty[[name]]$applied), info = name)
  }
})

testthat::test_that("[WS4a V-book F4.12] aggregates are exact reductions at construction and exact zero when flat", {
  ns <- ws4a_ns()
  # The review's control: one lot of 1e9 whose cached net is corrupted to 1e9 + 1.
  big <- ns$ledgr_lot_book_from_opening("AAA", c(AAA = 1e9), c(AAA = 3.25))
  testthat::expect_null(ns$ledgr_lot_book_problem(big))
  corrupt <- big
  corrupt$net_by_inst[[1L]] <- 1e9 + 1
  testthat::expect_false(is.null(ns$ledgr_lot_book_problem(corrupt)))
  basis <- big
  basis$cost_basis_by_inst[[1L]] <- 42
  testthat::expect_false(is.null(ns$ledgr_lot_book_problem(basis)))
  # A book reached by fills: buy 1e9, buy 0.1, sell 1e9 leaves a 0.1 lot under
  # a cached net of 0.10000002384, as on the base. No bound in terms of the
  # live lots admits it and refuses the corruption above, so books reached by
  # transitions are checked only where the arithmetic is exact.
  drift <- ns$ledgr_lot_book(1L)
  drift <- ns$ledgr_lot_fill(drift, 1L, 1L, 1e9, 1)$book
  drift <- ns$ledgr_lot_fill(drift, 1L, 1L, 0.1, 1)$book
  drift <- ns$ledgr_lot_fill(drift, 1L, -1L, 1e9, 1)$book
  testthat::expect_identical(ns$ledgr_lot_book_live(drift)$qty, 0.1)
  testthat::expect_false(identical(drift$net_by_inst, 0.1))
  testthat::expect_null(ns$ledgr_lot_book_problem(drift, reduction = FALSE))
  testthat::expect_false(is.null(ns$ledgr_lot_book_problem(drift)))
  flat <- ws4a_book()
  flat$net_by_inst[[3L]] <- 1e-300
  testthat::expect_false(is.null(ns$ledgr_lot_book_problem(flat, reduction = FALSE)))
  # Production boundaries: fold entry and the compiled unpack accept the
  # drifted book; the opening construction refuses a corrupted opening.
  imported <- ns$ledgr_carrier_import_state(list(cash = 1, positions = NULL, lot_state = drift), "AAA")
  testthat::expect_identical(imported$lot_state, drift)
  batch <- c(ns$ledgr_carrier_compiled_pack(drift),
    drift[c("net_by_inst", "cost_basis_by_inst", "total_cost_basis", "realized_pnl", "realized_comp")])
  testthat::expect_identical(ns$ledgr_carrier_compiled_unpack(batch, 1L)$net_by_inst, drift$net_by_inst)
  opening <- ns$ledgr_lot_opening
  for (field in c("net_by_inst", "cost_basis_by_inst")) {
    testthat::local_mocked_bindings(
      ledgr_lot_opening = function(book, pos, qty, price) {
        out <- opening(book, pos, qty, price)
        out$book[[field]][pos] <- out$book[[field]][pos] * (1 + 1e-12)
        out
      },
      .package = "ledgr"
    )
    testthat::expect_error(
      ns$ledgr_lot_book_from_opening(c("AAA", "BBB"), c(AAA = 2, BBB = -1), c(AAA = 10, BBB = 5)),
      class = "ledgr_lot_state_invariant", info = field
    )
  }
})

testthat::test_that("[WS4a V-applied-row] the close/open split is checked against the lots before and after", {
  ns <- ws4a_ns()
  book <- ws4a_book()
  applied <- ns$ledgr_lot_applied
  seen <- NULL
  testthat::local_mocked_bindings(
    ledgr_lot_applied = function(...) {
      seen <<- list(...)
      applied(...)
    },
    .package = "ledgr"
  )
  # A pure close of 2 from the 3.5 AAA holding: closes 2, opens nothing.
  out <- ns$ledgr_lot_fill(book, 1L, -1L, 2, 105)
  testthat::expect_identical(c(out$applied$close_qty, out$applied$open_qty), c(2, 0))
  testthat::expect_identical(c(seen$lots$before, seen$lots$after), c(1, 1))
  testthat::expect_identical(do.call(applied, seen), out$applied)
  split <- function(close, open) do.call(applied, utils::modifyList(seen, list(close_qty = close, open_qty = open)))
  testthat::expect_error(split(1, 1), class = "ledgr_lot_state_invariant")
  testthat::expect_error(split(0, 2), class = "ledgr_lot_state_invariant")
  testthat::expect_error(split(1.5, 0), class = "ledgr_lot_state_invariant")
  testthat::expect_error(split(2, 1), class = "ledgr_lot_state_invariant")
  # A reversal: selling 5 from 3.5 closes 3.5 and opens 1.5; reported as a
  # pure close it is refused.
  out <- ns$ledgr_lot_fill(book, 1L, -1L, 5, 105)
  testthat::expect_identical(c(out$applied$close_qty, out$applied$open_qty), c(3.5, 1.5))
  testthat::expect_identical(c(seen$lots$before, seen$lots$after, seen$lots$steps), c(1, -1, 2))
  testthat::expect_error(split(5, 0), class = "ledgr_lot_state_invariant")
  # Signed openings: a sell of 2 against +2 then -1 closes 2 and opens nothing,
  # as on the base (re-review 1, N1).
  b <- ns$ledgr_lot_book_from_opening("S", lots = list(
    instrument_id = c("S", "S"), qty = c(2, -1), price = c(10, 10)))
  out <- ns$ledgr_lot_fill(b, 1L, -1L, 2, 10)
  testthat::expect_identical(out$book$net_by_inst, -1)
  testthat::expect_identical(c(out$applied$close_qty, out$applied$open_qty), c(2, 0))
})

# The two multi-error controls of the workstream 12 close review (F1), and
# their reversals. Each expects the base 953338df condition class and message,
# confirmed by running the same ledgers against the base library.
testthat::test_that("[WS4a F1] replay refuses the earliest failing event with the base precedence", {
  ns <- ws4a_ns()
  d1 <- as.POSIXct("2020-01-02 21:00:00", tz = "UTC")
  disp <- function(x, event_seq) ns$ledgr_accounting_rows(
    event_id = paste0("e", event_seq), run_id = "r",
    ts_utc = d1 + 86400 * x$day, event_type = "DISPOSITION",
    instrument_id = x$id, side = NA_character_, qty = x$quantity,
    price = x$mark, fee = 0, event_seq = event_seq,
    cash_delta = x$before * x$mark, position_delta = -x$before,
    source = "corporate_action_disposition", source_fact_id = paste0("f-", x$id),
    disposition_policy_id = "p", disposition_choice = "last_mark",
    disposition_basis = "evidence", mark_source = "current_close",
    mark_source_ts_utc = as.POSIXct("2020-01-03 21:00:00", tz = "UTC"),
    mark_age = 0L, affected_marked_exposure = abs(x$before * x$mark),
    position_before = x$before, realized_model_pnl = x$pnl
  )
  # Buys AAA 2 at 10 and BBB 3 at 20, then the given dispositions.
  replay <- function(...) {
    d <- list(...)
    fills <- ledgr_test_complete_fill_rows(data.frame(
      event_id = c("e1", "e2"), run_id = "r", ts_utc = d1,
      event_type = "FILL", instrument_id = c("AAA", "BBB"),
      side = "BUY", qty = c(2, 3), price = c(10, 20), fee = 0,
      event_seq = 1:2, stringsAsFactors = FALSE
    ))
    dispositions <- Map(disp, d, seq_along(d) + 2L)
    ev <- do.call(rbind, c(list(fills), dispositions))
    ns$ledgr_replay_accounting_events(ns$ledgr_prepare_accounting_events(ev, c("AAA", "BBB")))
  }
  witness_a <- list(id = "AAA", before = 2, quantity = 2, mark = 12, pnl = 999, day = 1)
  malformed_b <- list(id = "BBB", before = 2, quantity = 2.5, mark = 25, pnl = 10, day = 1)
  live_b <- list(id = "BBB", before = 2, quantity = 2, mark = 25, pnl = 10, day = 1)
  witness <- "^DISPOSITION realized model PnL does not match canonical FIFO realization[.]$"
  exhaust <- "^DISPOSITION must consume the position and every live lot exactly[.]$"
  malformed <- "^DISPOSITION lot metadata is malformed[.]$"
  testthat::expect_identical(replay(utils::modifyList(witness_a, list(pnl = 4)))$realized_delta[[3L]], 4)
  # A witness error followed by a malformed quantity; then by a leftover live lot.
  testthat::expect_error(replay(witness_a, malformed_b), witness, class = "ledgr_invalid_ledger_meta")
  testthat::expect_error(replay(witness_a, live_b), witness, class = "ledgr_invalid_ledger_meta")
  # The same pairs a day apart (separate blocks), and reversed.
  later <- function(x) utils::modifyList(x, list(day = 2))
  testthat::expect_error(replay(witness_a, later(malformed_b)), witness, class = "ledgr_invalid_ledger_meta")
  testthat::expect_error(replay(witness_a, later(live_b)), witness, class = "ledgr_invalid_ledger_meta")
  testthat::expect_error(replay(malformed_b, witness_a), malformed, class = "ledgr_invalid_ledger_meta")
  testthat::expect_error(replay(live_b, witness_a), exhaust, class = "ledgr_lot_state_invariant")
  # Within one event, exhaustion precedes the witness.
  testthat::expect_error(replay(utils::modifyList(live_b, list(pnl = 999))), exhaust, class = "ledgr_lot_state_invariant")
})

# --- LDG-3165: typed observation and decision -------------------------------

# The v0.2.0.1 availability witness (helper-availability-v0-2-0-1-witnesses.R,
# unchanged): a changing context with held nonmembers, halted (restricted)
# instruments, a stale mark and an early stop. Returns the run's handle or
# its error.
ws4a_v201_run <- function(run_id = "ws4a-3165") {
  f <- availability_v201_fold_fixture()
  snap <- ledgr_snapshot_from_df(f$bars, instruments_df = f$instruments,
    db_path = tempfile(fileext = ".duckdb"), snapshot_id = "witness", facts = f$facts,
    price_basis = "split_adjusted")
  withr::defer(ledgr_snapshot_close(snap), envir = parent.frame())
  withr::local_options(list(ledgr.v201.interrupt_at = "", ledgr.v201.fail_at = "",
    ledgr.v201.increase_nonmember_at = "", ledgr.v201.exit_eee_from = ""))
  exp <- ledgr_experiment(snap, availability_v201_fold_strategy, universe = ledgr_universe_members("U"),
    valuation_policy = ledgr_valuation_stale(max_sessions = 2L, exhausted = "refuse"),
    corporate_action_policy = ledgr_corporate_actions(held_terminal_position = "refuse"),
    cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e6))
  out <- tryCatch(ledgr_run(exp, run_id = run_id), error = identity)
  if (!inherits(out, "error")) close(out)
  out
}

# One production instance of each P1 group, captured at the constructor.
# Takes the first packet with a restricted instrument and a held nonmember,
# its pulse's decision data, and the first execution packet with a next bar.
ws4a_v201_groups <- function() {
  ns <- ws4a_ns()
  seen <- list()
  packet <- ns$ledgr_carrier_packet
  testthat::local_mocked_bindings(
    ledgr_carrier_packet = function(x, group, n_run) {
      wanted <- switch(group,
        decision_packet = any(x$restriction_count > 0L) && any(!x$member),
        decision_data = !is.null(seen$decision_packet) && length(x$open) == length(seen$decision_packet$x$context_pos),
        execution_packet = isTRUE(x$has_next))
      if (is.null(seen[[group]]) && wanted) seen[[group]] <<- list(x = x, n = n_run)
      packet(x, group, n_run)
    },
    .package = "ledgr"
  )
  ws4a_v201_run()
  seen
}

ws4a_refuses_group <- function(x, group, n_run) {
  ns <- ws4a_ns()
  inherits(tryCatch(ns$ledgr_carrier_new(x, group, n_run), error = identity), "ledgr_internal_error")
}

testthat::test_that("[WS4a V-packet U-3165] the three P1 groups are typed, aligned and refuse the controls", {
  ns <- ws4a_ns()
  g <- ws4a_v201_groups()
  testthat::expect_setequal(names(g), c("decision_packet", "decision_data", "execution_packet"))
  for (group in names(g)) {
    testthat::expect_null(ns$ledgr_carrier_problem(g[[group]]$x, group, g[[group]]$n), info = group)
  }
  p <- g$decision_packet$x
  n_run <- g$decision_packet$n
  testthat::expect_true(any(p$restriction_count > 0L) && any(!p$member))
  # Empty context: typed zero-length columns are accepted (n = 0).
  empty <- p
  for (f in setdiff(names(p), c("pulse_idx", "ts", "cash", "positions_value"))) empty[[f]] <- p[[f]][0L]
  testthat::expect_null(ns$ledgr_carrier_problem(empty, "decision_packet", n_run))
  edit <- function(x, ...) utils::modifyList(x, list(...))
  packet_controls <- list(
    storage_type = edit(p, context_pos = as.numeric(p$context_pos)),
    shortened_column = edit(p, position = p$position[-1L]),
    bound = edit(p, context_pos = replace(p$context_pos, 1L, n_run + 1L)),
    untyped_empty = edit(empty, member = list()),
    F4.14_duplicate_context_pos = edit(p, context_pos = replace(p$context_pos, 2L, p$context_pos[[1L]])),
    F4.15_nan_position = edit(p, position = replace(p$position, 1L, NaN)),
    F4.16_buyable_nonmember = edit(p, buyable = p$buyable | !p$member),
    F4.17_code_7 = edit(p, restriction_code = replace(p$restriction_code, 1L, 7L)),
    F4.17_detached_segment = edit(p, restriction_offset = p$restriction_offset + 1L),
    F4.18_na_terminal_event = edit(p, terminal_event = replace(p$terminal_event, 1L, NA_character_)),
    F4.18_status_code = edit(p, status = replace(p$status, 1L, 6L)),
    F4.20_na_permissible = edit(p, permissible = replace(p$permissible, 1L, NA)),
    named_column = edit(p, mark = stats::setNames(p$mark, seq_along(p$mark))),
    extra_field = c(p, list(next_open = 1))
  )
  for (name in names(packet_controls)) {
    testthat::expect_true(ws4a_refuses_group(packet_controls[[name]], "decision_packet", n_run), info = name)
  }
  d <- g$decision_data$x
  empty_d <- d
  for (f in c("open", "high", "low", "close", "volume", "observed", "source_row")) empty_d[[f]] <- d[[f]][0L]
  testthat::expect_null(ns$ledgr_carrier_problem(empty_d, "decision_data", n_run))
  data_controls <- list(
    storage_type = edit(d, observed = as.integer(d$observed)),
    shortened_column = edit(d, open = d$open[-1L]),
    bound = edit(d, source_column = 0L),
    untyped_empty = edit(empty_d, open = list()),
    F4.21_next_bar_column = c(d, list(next_open = d$open)),
    F4.22_row_without_column = edit(d, source_column = NA_integer_)
  )
  for (name in names(data_controls)) {
    testthat::expect_true(ws4a_refuses_group(data_controls[[name]], "decision_data", n_run), info = name)
  }
  e <- g$execution_packet$x
  exec_controls <- list(
    storage_type = edit(e, has_next = 1L),
    shortened_column = edit(e, open = e$open[-1L]),
    bound = edit(e, open = replace(e$open, 1L, Inf)),
    untyped_empty = edit(e, close = list()),
    F4.23_has_next_na = edit(e, has_next = NA),
    absent_next_with_values = edit(e, has_next = FALSE)
  )
  for (name in names(exec_controls)) {
    testthat::expect_true(ws4a_refuses_group(exec_controls[[name]], "execution_packet", n_run), info = name)
  }
  testthat::expect_error(ns$ledgr_carrier_packet(packet_controls$bound, "decision_packet", n_run),
    class = "ledgr_internal_error")
})

testthat::test_that("[WS4a V-decision U-3165] the decision group is typed, finite and ordered", {
  ns <- ws4a_ns()
  ok <- list(context_pos = c(3L, 1L, 2L), strategy_qty = c(1, 0, -2), target_qty = c(1, 0, -1),
    actionable_k = c(1L, 3L), state_update = list(a = 1), intent_reason = "why")
  testthat::expect_identical(ns$ledgr_carrier_decision(ok, 3L), ok)
  empty <- list(context_pos = integer(), strategy_qty = numeric(), target_qty = numeric(),
    actionable_k = integer(), state_update = NULL, intent_reason = NULL)
  testthat::expect_null(ns$ledgr_carrier_problem(empty, "decision", 3L))
  edit <- function(x, ...) utils::modifyList(x, list(...))
  controls <- list(
    storage_type = edit(ok, strategy_qty = c(1L, 0L, -2L)),
    shortened_column = edit(ok, target_qty = c(1, 0)),
    bound = edit(ok, actionable_k = c(1L, 4L)),
    untyped_empty = edit(empty, target_qty = list()),
    F4.25_na_target = edit(ok, target_qty = c(1, NA, -1)),
    F4.25_unordered_actionable = edit(ok, actionable_k = c(3L, 1L)),
    F4.26_non_character_intent = edit(ok, intent_reason = 1),
    duplicate_context_pos = edit(ok, context_pos = c(1L, 1L, 2L))
  )
  for (name in names(controls)) {
    testthat::expect_error(ns$ledgr_carrier_decision(controls[[name]], 3L), class = "ledgr_internal_error", info = name)
  }
})

# F4.19: the adapter's packet columns against its provider and valuation
# inputs, field by field; returns the fields that differ.
ws4a_f419 <- function(view, valuation, cols) {
  ns <- ws4a_ns()
  plain <- function(x) unname(x)
  text <- ns$ledgr_carrier_restriction_text(list(restriction_count = cols$restriction_count,
    restriction_offset = cols$restriction_offset, restriction_code = cols$restriction_code))
  ok <- c(
    context_pos = identical(cols$context_pos, as.integer(plain(valuation$source_row))),
    mark = identical(cols$mark, plain(valuation$mark)),
    reference = identical(cols$reference, plain(valuation$reference)),
    source_ts = identical(cols$source_ts, as.numeric(plain(valuation$source_ts))),
    mark_age = identical(cols$mark_age, plain(valuation$age)),
    mark_source = identical(ns$ledgr_carrier_mark_source_text(cols$mark_source), plain(valuation$source)),
    priced = identical(cols$priced, plain(valuation$priced)),
    permissible = identical(cols$permissible, plain(valuation$permissible)),
    frozen = identical(cols$frozen, plain(valuation$frozen)),
    member = identical(cols$member, plain(view$member)),
    held = identical(cols$held, plain(view$held)),
    target_restricted = identical(cols$target_restricted, plain(view$target_restricted)),
    restriction_reason = identical(text$reason, plain(view$target_restriction_reason)),
    restriction_reasons = identical(text$reasons, plain(view$target_restriction_reasons)),
    status = identical(ns$.ledgr_carrier_status_levels[cols$status], plain(view$status)),
    lifetime = identical(ns$.ledgr_carrier_lifetime_levels[cols$lifetime], plain(view$lifetime)),
    terminal_event = identical(cols$terminal_event, plain(view$terminal_event)),
    lifetime_fact_id = identical(cols$lifetime_fact_id, plain(view$lifetime_fact_id))
  )
  names(ok)[!ok]
}

testthat::test_that("[WS4a F4.19] the provider adapter keeps unpriced provenance field by field", {
  ns <- ws4a_ns()
  ids <- c("AAA", "BBB", "CCC")
  pulses <- as.POSIXct("2021-01-04 21:00:00", tz = "UTC") + 86400 * 0:4
  close <- rbind(AAA = c(10, 11, 12, 13, 14), BBB = c(20, NA, NA, NA, NA), CCC = c(30, 31, 32, NA, NA))
  # BBB's last close is four sessions old: expired and unpriced under a
  # one-session limit, its reference, source time and age retained; CCC is
  # stale; under "freeze" the held BBB is frozen at its reference.
  valuation_at <- function(exhausted) {
    ns$ledgr_availability_valuation_state(list(close = close), ids, pulses, 2L, exhausted)$advance(
      5L, c("CCC", "BBB", "AAA"), held = c(TRUE, TRUE, FALSE))
  }
  status <- stats::setNames(c("active", "halted", "active"), c("CCC", "BBB", "AAA"))
  lifetime <- stats::setNames(c("known_active", "known_inactive", "unknown"), names(status))
  restrictions <- ns$ledgr_availability_restrictions(status, lifetime, TRUE, TRUE)
  axis <- names(status)
  view <- c(list(axis = axis, members = c("CCC", "AAA"),
    member = stats::setNames(c(TRUE, FALSE, TRUE), axis), held = stats::setNames(c(TRUE, TRUE, FALSE), axis),
    target_restricted = restrictions$restricted, target_restriction_reason = restrictions$reason,
    target_restriction_reasons = restrictions$reasons, status = status, lifetime = lifetime,
    terminal_event = stats::setNames(c("", "delisted", ""), axis),
    lifetime_fact_id = stats::setNames(c("", "f-1", ""), axis)))
  for (exhausted in c("refuse", "freeze")) {
    valuation <- valuation_at(exhausted)
    v <- ns$ledgr_availability_restrict_frozen(view, valuation)
    cols <- ns$ledgr_carrier_provider_view(v, valuation)
    testthat::expect_identical(ws4a_f419(v, valuation, cols), character(), info = exhausted)
    # The expired holding: no mark, its provenance kept.
    testthat::expect_true(is.na(cols$mark[[2L]]) || exhausted == "freeze")
    testthat::expect_identical(c(cols$reference[[2L]], cols$mark_age[[2L]]), c(20, 4))
    testthat::expect_false(is.na(cols$source_ts[[2L]]))
  }
  testthat::expect_identical(ns$ledgr_carrier_mark_source_text(cols$mark_source), c("stale_close", "frozen_close", "current_close"))
  # Controls: an adapter that erases the age, the source or the reference of
  # an unpriced mark fails the check.
  valuation <- valuation_at("refuse")
  cols <- ns$ledgr_carrier_provider_view(view, valuation)
  unpriced <- !cols$priced
  erased <- list(mark_age = replace(cols$mark_age, unpriced, NA_integer_),
    mark_source = replace(cols$mark_source, unpriced, 1L), reference = replace(cols$reference, unpriced, NA_real_))
  for (field in names(erased)) {
    bad <- cols
    bad[[field]] <- erased[[field]]
    testthat::expect_identical(ws4a_f419(view, valuation, bad), field, info = field)
  }

  # Production: every adapter call of the witness run keeps every field.
  diffs <- character()
  calls <- 0L
  adapter <- ns$ledgr_carrier_provider_view
  testthat::local_mocked_bindings(
    ledgr_carrier_provider_view = function(view, valuation) {
      out <- adapter(view, valuation)
      calls <<- calls + 1L
      diffs <<- c(diffs, ws4a_f419(view, valuation, out))
      out
    },
    .package = "ledgr"
  )
  ws4a_v201_run()
  testthat::expect_gt(calls, 5L)
  testthat::expect_identical(diffs, character())
})

testthat::test_that("[WS4a D16] the provider adapter converts each produced view once", {
  ns <- ws4a_ns()
  count_views <- function(second = FALSE) {
    n <- c(adapter = 0L, views = 0L)
    adapter <- ns$ledgr_carrier_provider_view
    valuation_state <- ns$ledgr_availability_valuation_state
    restrict <- ns$ledgr_availability_restrict_frozen
    testthat::local_mocked_bindings(
      ledgr_carrier_provider_view = function(...) {
        n[["adapter"]] <<- n[["adapter"]] + 1L
        adapter(...)
      },
      # Each produced view advances the valuation state exactly once.
      ledgr_availability_valuation_state = function(...) {
        s <- valuation_state(...)
        advance <- s$advance
        s$advance <- function(...) {
          n[["views"]] <<- n[["views"]] + 1L
          advance(...)
        }
        s
      },
      # Control: a second conversion of the same view.
      ledgr_availability_restrict_frozen = function(view, valuation) {
        out <- restrict(view, valuation)
        if (second) ns$ledgr_carrier_provider_view(out, valuation)
        out
      },
      .package = "ledgr"
    )
    ws4a_v201_run()
    n
  }
  once <- function(n) n[["views"]] > 0L && identical(n[["adapter"]], n[["views"]])
  testthat::expect_true(once(count_views()))
  testthat::expect_false(once(count_views(second = TRUE)))
})

# D5: names that only the execution packet carries.
ws4a_execution_names <- c("execution", "exec_ts", "has_next", "next_bar", "next_bars")
# D5's predicate: an execution-only name, the execution packet object, or one
# of its next-bar price columns under any name, anywhere in `x`.
ws4a_p2_leaks <- function(x, execution, depth = 0L) {
  if (!is.list(x) || depth > 4L) return(character())
  carried <- if (is.null(execution)) list() else {
    c(list(execution), if (isTRUE(execution$has_next)) execution[c("open", "high", "low", "close")])
  }
  same <- vapply(x, function(v) any(vapply(carried, identical, logical(1), v)), logical(1))
  hits <- c(intersect(names(x), ws4a_execution_names), if (any(same)) "execution packet value")
  unname(c(hits, unlist(lapply(x, ws4a_p2_leaks, execution = execution, depth = depth + 1L))))
}

testthat::test_that("[WS4a D5 D21] P2's input carries no execution-packet field; P3-P5 read no history", {
  ns <- ws4a_ns()
  observe <- ns$ledgr_fold_stage_observe_settle
  decide <- ns$ledgr_fold_stage_decide
  plan <- ns$ledgr_fold_stage_plan
  leak_run <- function(leak) {
    state <- new.env()
    state$hits <- character()
    state$p2 <- 0L
    state$p3_data <- 0L
    testthat::local_mocked_bindings(
      ledgr_fold_stage_observe_settle = function(...) {
        out <- observe(...)
        if (!ledgr_is_fold_stop_result(out)) {
          state$execution <- out$execution
          # Controls: pass the next bar to P2 inside its observation, as the
          # packet or as one unlabeled price column.
          if (leak == "packet") out$observation$execution <- out$execution
          if (leak == "column" && out$execution$has_next) out$observation$extra <- out$execution$open
        }
        out
      },
      ledgr_fold_stage_decide = function(fold_state, services, observation, ...) {
        state$p2 <- state$p2 + 1L
        state$hits <- c(state$hits, ws4a_p2_leaks(list(observation = observation, services = services), state$execution))
        decide(fold_state, services, observation, ...)
      },
      ledgr_fold_stage_plan = function(fold_state, services, observation, decision, execution, ...) {
        state$p3_data <- state$p3_data + !is.null(observation$data)
        plan(fold_state, services, observation, decision, execution, ...)
      },
      .package = "ledgr"
    )
    ws4a_v201_run()
    state
  }
  clean <- leak_run("none")
  testthat::expect_gt(clean$p2, 0L)
  testthat::expect_identical(clean$hits, character())
  testthat::expect_identical(clean$p3_data, 0L)
  testthat::expect_true(all(c("execution", "execution packet value") %in% leak_run("packet")$hits))
  testthat::expect_identical(unique(leak_run("column")$hits), "execution packet value")
  testthat::expect_identical(ws4a_p2_leaks(list(history_bars = list(next_bar = 1)), NULL), "next_bar")

  # D21: the phase checker finds no history or substrate access in P3-P5;
  # an injected P3 history read is a finding.
  root <- ledgr_test_source_root()
  checker <- new.env(parent = baseenv())
  sys.source(file.path(root, "tools", "check-fold-phase-contract.R"), envir = checker)
  files <- list.files(file.path(root, "R"), "\\.R$", full.names = TRUE)
  rx <- "^substrate_reference:ledgr_fold_stage_(plan|apply|commit)|^service_owner:ledgr_fold_stage_(plan|apply|commit):.*history_reader"
  testthat::expect_length(grep(rx, checker$ledgr_fold_phase_source_findings(files), value = TRUE), 0L)
  fns <- ws4a_sources()
  bad <- tempfile(fileext = ".R")
  writeLines(c("ledgr_fold_stage_plan <-",
    deparse(ws4a_inject(fns$ledgr_fold_stage_plan, "services$history_substrate$read(1L)"), width.cutoff = 500L)), bad)
  testthat::expect_gt(length(grep(rx, checker$ledgr_fold_phase_source_findings(c(files, bad)), value = TRUE)), 0L)
})

testthat::test_that("[WS4a D4] the strategy return is normalized once per decided pulse", {
  ns <- ws4a_ns()
  normalize <- ns$ledgr_validate_strategy_targets
  decide <- ns$ledgr_fold_stage_decide
  risk <- ns$ledgr_apply_risk_plan
  counts <- function(run, second = FALSE) {
    n <- c(normalize = 0L, decide = 0L)
    testthat::local_mocked_bindings(
      ledgr_validate_strategy_targets = function(...) {
        n[["normalize"]] <<- n[["normalize"]] + 1L
        normalize(...)
      },
      ledgr_fold_stage_decide = function(...) {
        n[["decide"]] <<- n[["decide"]] + 1L
        decide(...)
      },
      # Control: the removed post-risk shape and name revalidation.
      ledgr_apply_risk_plan = function(targets, risk_plan, ctx) {
        out <- risk(targets, risk_plan, ctx)
        if (second) ns$ledgr_validate_strategy_targets(out, names(targets))
        out
      },
      .package = "ledgr"
    )
    run()
    n
  }
  once <- function(n) n[["decide"]] > 0L && identical(n[["normalize"]], n[["decide"]])
  dense <- function() {
    snapshot <- ledgr_snapshot_from_df(ledgr_test_compact_bars(), db_path = tempfile(fileext = ".duckdb"))
    on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
    exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, function(ctx, params) {
      target <- ctx$hold()
      target[[1L]] <- 1
      target
    }, cost_model = ledgr_cost_zero())
    close(ledgr_run(exp, run_id = "d4-dense"))
  }
  testthat::expect_true(once(counts(ws4a_v201_run)))
  testthat::expect_true(once(counts(dense)))
  testthat::expect_false(once(counts(ws4a_v201_run, second = TRUE)))
  testthat::expect_false(once(counts(dense, second = TRUE)))
  # Static: P2 calls the normalizer once and no longer calls the deleted
  # post-risk revalidation; an injected second call is found.
  fns <- ws4a_sources()
  calls <- function(f) sum(ws4a_heads(f) %in% c("ledgr_validate_strategy_targets", "ledgr_validate_post_risk_targets"))
  testthat::expect_identical(calls(fns$ledgr_fold_stage_decide), 1L)
  testthat::expect_false("ledgr_validate_post_risk_targets" %in% names(fns))
  testthat::expect_identical(calls(ws4a_inject(fns$ledgr_fold_stage_decide, "ledgr_validate_strategy_targets(x, ids)")), 2L)
})

testthat::test_that("[WS4a missing targets] a missing target is refused on both producers, never zero-filled", {
  drop_first <- function(ctx, params) {
    target <- ctx$hold()
    target[-1L]
  }
  snapshot <- ledgr_snapshot_from_df(ledgr_test_compact_bars(), db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  dense <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, drop_first, cost_model = ledgr_cost_zero())
  testthat::expect_error(ledgr_run(dense, run_id = "missing-dense"), "missing instruments",
    class = "ledgr_invalid_strategy_result")
  f <- availability_v201_fold_fixture()
  snap <- ledgr_snapshot_from_df(f$bars, instruments_df = f$instruments, db_path = tempfile(fileext = ".duckdb"),
    snapshot_id = "witness", facts = f$facts, price_basis = "split_adjusted")
  on.exit(ledgr_snapshot_close(snap), add = TRUE)
  avail <- ledgr_experiment(snap, drop_first, universe = ledgr_universe_members("U"),
    valuation_policy = ledgr_valuation_stale(max_sessions = 2L, exhausted = "refuse"),
    cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e6))
  testthat::expect_error(ledgr_run(avail, run_id = "missing-avail"), "missing instruments",
    class = "ledgr_invalid_strategy_result")
  # Past normalization, a missing post-risk quantity or decision target is
  # refused, not replaced by zero.
  ns <- ws4a_ns()
  testthat::expect_error(ns$ledgr_validate_post_risk_quantities(c(A = 1, B = NA), 2L),
    class = "ledgr_invalid_post_risk_targets")
  testthat::expect_error(ns$ledgr_carrier_decision(list(context_pos = 1:2, strategy_qty = c(1, NA),
    target_qty = c(1, 0), actionable_k = 1L, state_update = NULL, intent_reason = NULL), 2L), class = "ledgr_internal_error")
})

testthat::test_that("[WS4a O3.28] the compiled risk plan is validated in E, not per pulse", {
  ns <- ws4a_ns()
  validate <- ns$ledgr_risk_validate_compiled_plan
  decide <- ns$ledgr_fold_stage_decide
  in_pulse <- 0L
  inside <- FALSE
  testthat::local_mocked_bindings(
    ledgr_risk_validate_compiled_plan = function(...) {
      if (inside) in_pulse <<- in_pulse + 1L
      validate(...)
    },
    ledgr_fold_stage_decide = function(...) {
      inside <<- TRUE
      on.exit(inside <<- FALSE)
      decide(...)
    },
    .package = "ledgr"
  )
  snapshot <- ledgr_snapshot_from_df(ledgr_test_compact_bars(), db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(opening = ledgr_opening(cash = 100000), snapshot, function(ctx, params) {
    target <- ctx$hold()
    target[[1L]] <- 2
    target
  }, cost_model = ledgr_cost_zero(), risk_chain = ledgr_risk_max_weight(0.5))
  close(ledgr_run(exp, run_id = "o328"))
  testthat::expect_identical(in_pulse, 0L)
  # The short-exposure check stays: an availability target opening a short
  # position is refused.
  testthat::expect_error(ns$ledgr_availability_validate_short_exposure(c(A = -1), c(A = 0)),
    class = "ledgr_short_exposure_unsupported")
})

# D3 for the LDG-3165 regions: P2's decision logic, P3's decision and packet
# reads, P5 and the scheduled skip use positions on the context axis. The
# shared name-keyed predicate also flags %in% here; the census lists the P2
# input and return boundaries that name instruments.
ws4a_d3_3165 <- c(
  # LDG-3195 removed the P2 frame/table input and its three membership scans.
  # P2 return still notes skipped sizing by instrument ID.
  ledgr_fold_stage_decide = "context_ids %in% services$pulse_notes$sizing_skipped",
  # Mark-source tokens of the decoded dictionary, not instruments.
  ledgr_fold_scheduled_skip_decision = "mark_source %in% c(\"stale_close\", \"frozen_close\")"
)
ws4a_d3_3165_hits <- function(fns) {
  unlist(lapply(names(fns), function(nm) {
    e <- fns[[nm]]
    found <- c(ws4a_name_keyed(e), vapply(Filter(function(x) ws4a_head(x) == "%in%", ws4a_calls(e)),
      function(x) substr(ws4a_txt(x), 1L, 70L), ""))
    h <- setdiff(unique(found), ws4a_d3_3165[names(ws4a_d3_3165) == nm])
    if (length(h)) paste0(nm, ": ", h)
  }))
}

testthat::test_that("[WS4a D3 3165] P2, P3, P5 and the skip read the decision by position", {
  fns <- ws4a_sources()
  examined <- c("ledgr_fold_stage_decide", "ledgr_fold_stage_plan", "ledgr_fold_stage_commit",
    "ledgr_fold_scheduled_skip_decision")
  testthat::expect_length(ws4a_d3_3165_hits(fns[examined]), 0L)
  # The census is exact: every entry is still present.
  found <- unlist(lapply(unique(names(ws4a_d3_3165)), function(nm) paste(nm, vapply(Filter(function(x)
    ws4a_head(x) == "%in%", ws4a_calls(fns[[nm]])), function(x) substr(ws4a_txt(x), 1L, 70L), ""))))
  testthat::expect_setequal(found, paste(names(ws4a_d3_3165), ws4a_d3_3165))
  inject <- function(nm, stmt) {
    bad <- fns[nm]
    bad[[nm]] <- ws4a_inject(bad[[nm]], stmt)
    ws4a_d3_3165_hits(bad)
  }
  testthat::expect_gt(length(inject("ledgr_fold_stage_decide", "k <- match(id, context_ids)")), 0L)
  testthat::expect_gt(length(inject("ledgr_fold_stage_decide", "m <- packet$mark[context_ids]")), 0L)
  testthat::expect_gt(length(inject("ledgr_fold_stage_plan", "idx <- services$id_to_idx[target_names]")), 0L)
  testthat::expect_gt(length(inject("ledgr_fold_stage_commit", "keep <- context_ids %in% held")), 0L)
})

testthat::test_that("[WS4b D12d D13 successor] the fold has one substrate and one planner", {
  fns <- ws4a_sources()
  retired <- c(
    "ledgr_fold_build_pulse_plan",
    "ledgr_dense_eligibility_planes",
    "ledgr_bars_pulse_views",
    "ledgr_projection_pulse_views",
    "ledgr_fast_context_state",
    "ledgr_update_fast_pulse_context_helpers"
  )
  testthat::expect_length(intersect(retired, names(fns)), 0L)
  testthat::expect_true("ledgr_fold_build_availability_pulse_plan" %in% names(fns))

  hot <- c(
    "ledgr_execute_fold",
    "ledgr_fold_stage_observe_settle",
    "ledgr_fold_stage_decide",
    "ledgr_fold_stage_plan",
    "ledgr_fold_stage_apply",
    "ledgr_fold_stage_commit",
    "ledgr_pulse_context"
  )
  mode_hits <- function(x) {
    grep(
      "availability_active|fast_context|dense_eligibility|bars_pulse_views|projection_pulse_views",
      vapply(x, ws4a_txt, ""),
      value = TRUE
    )
  }
  testthat::expect_length(mode_hits(fns[hot]), 0L)
  changed <- fns["ledgr_fold_stage_commit"]
  changed[[1L]] <- ws4a_inject(
    changed[[1L]],
    "if (services$availability_active) NULL"
  )
  testthat::expect_length(mode_hits(changed), 1L)
})

# --- LDG-3166: typed plan batch ---------------------------------------------

# Fixed-basket and declared-session snapshots of AAA and BBB over five
# sessions, chained costs (spread, fixed, notional) and a long-only strategy
# that buys and sells, so plans hold both sides and fee splits.
ws4a_3166_fixture <- function(avail) {
  pulses <- as.POSIXct("2024-01-01 16:00:00", tz = "UTC") + 86400 * 0:4
  open <- list(AAA = c(100, 101.37, 103.11, 99.73, 102.29), BBB = 50 + 0:4 / 3)
  bars <- do.call(rbind, lapply(names(open), function(id) data.frame(ts_utc = pulses, instrument_id = id,
    open = open[[id]], high = open[[id]] + 1, low = open[[id]] - 1, close = open[[id]] + 0.5, volume = 1000,
    stringsAsFactors = FALSE)))
  db <- tempfile(fileext = ".duckdb")
  snap <- if (avail) {
    sessions <- ledgr_facts_sessions(data.frame(session_date = as.Date(pulses), status = "open",
      session_open = "09:30:00", session_close = "16:00:00", knowledge_time = pulses - 86400,
      stringsAsFactors = FALSE), venue_id = "XNYS")
    ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = names(open)),
      facts = ledgr_facts(sessions), price_basis = "split_adjusted", db_path = db)
  } else {
    ledgr_snapshot_from_df(bars, db_path = db)
  }
  plan <- list(c(AAA = 3, BBB = 2), c(AAA = 5), c(AAA = 1, BBB = 0), c(AAA = 0), c(AAA = 0))
  strategy <- function(ctx, params) {
    target <- ctx$hold()
    set <- params$plan[[match(substr(ctx$ts_utc, 1L, 10L), params$days)]]
    target[names(set)] <- set
    target
  }
  exp <- function(...) ledgr_experiment(snap, strategy, opening = ledgr_opening(cash = 1e5),
    cost_model = ledgr_cost_chain(ledgr_cost_spread_bps(7), ledgr_cost_fixed_fee(1.25), ledgr_cost_notional_bps_fee(3)), ...)
  list(snap = snap, exp = exp, params = list(plan = plan, days = format(as.Date(pulses))))
}
# Runs a dense audit-log run, a dense db_live run and an availability sweep.
ws4a_3166_runs <- function() {
  dense <- ws4a_3166_fixture(FALSE)
  withr::defer(ledgr_snapshot_close(dense$snap), envir = parent.frame())
  close(ledgr_run(dense$exp(), params = dense$params, run_id = "ws4a-3166-dense", seed = 1L))
  close(ledgr_run(dense$exp(execution_mode = "db_live"), params = dense$params, run_id = "ws4a-3166-live", seed = 1L))
  avail <- ws4a_3166_fixture(TRUE)
  withr::defer(ledgr_snapshot_close(avail$snap), envir = parent.frame())
  ledgr_sweep(avail$exp(), ledgr_grid_named(a = list(strategy = avail$params)), seed = 1L)
}

# A plan of the availability planner on decision order D, A, C, B over the
# run axis A, B, C, D: D sells (a funding reduction), A buys with a changed
# membership, C has no execution bar, B is restricted (trading_halted).
ws4a_3166_plan <- function(cash = 0) {
  ns <- ws4a_ns()
  view <- ns$ledgr_carrier_segments(4L, 4L, 5L)
  ns$ledgr_fold_build_availability_pulse_plan(
    context_pos = c(4L, 1L, 3L, 2L), target_qty = c(0, 2, 1, 1), position = c(5, 0, 0, 0),
    actionable_k = 1:4, member = rep(TRUE, 4L),
    execution = list(exec_ts = 1704292200, has_next = TRUE, open = c(10, 10, NA, 10)),
    execution_view = list(member = c(TRUE, FALSE, TRUE, TRUE), restricted = c(FALSE, FALSE, FALSE, TRUE),
      reason_offset = view$offset, reason_count = view$count, reason_code = view$code),
    epoch_valid = TRUE,
    cost_resolver = ns$ledgr_cost_resolver_from_model(ledgr_cost_fixed_fee(0.5)),
    cash = cash, instrument_ids = c("A", "B", "C", "D")
  )
}
ws4a_refuses_plan <- function(x, axis = list(context_pos = c(4L, 1L, 3L, 2L), actionable_k = 1:4), n_run = 4L) {
  inherits(tryCatch(ws4a_ns()$ledgr_carrier_new(x, "plan", n_run, axis), error = identity), "ledgr_invalid_pulse_plan")
}

testthat::test_that("[WS4a V-execution-view V-plan V-fill V-rejection U-3166] the P3 groups are typed and refuse the controls", {
  ns <- ws4a_ns()
  p <- ws4a_3166_plan()
  # The planner's rows: fills D and A in decision order, early rejection C,
  # affordability rejection B; A carries membership_changed_before_execution.
  testthat::expect_identical(p$fill$k, 1:2)
  testthat::expect_identical(p$fill$pos, c(4L, 1L))
  testthat::expect_identical(p$fill$info_code, 4L)
  testthat::expect_identical(p$rejection$k, 3:4)
  testthat::expect_identical(p$rejection$emit, 1:2)
  testthat::expect_identical(ns$.ledgr_plan_reason_levels[p$rejection$primary], c("execution_bar_missing", "trading_halted"))
  testthat::expect_identical(p$economic_event_kinds, 1L)
  testthat::expect_false(ws4a_refuses_plan(p))
  # Typed empty groups (n = 0) are accepted; a plan without rows declares no kind.
  empty <- p
  empty$fill <- lapply(p$fill, `[`, 0L)
  empty$rejection <- lapply(p$rejection, `[`, 0L)
  empty$economic_event_kinds <- integer()
  no_rows <- list(context_pos = c(4L, 1L, 3L, 2L), actionable_k = integer())
  testthat::expect_false(ws4a_refuses_plan(empty, no_rows))
  edit <- function(x, part, ...) {
    x[[part]] <- utils::modifyList(x[[part]], list(...))
    x
  }
  controls <- list(
    fill_storage_type = edit(p, "fill", k = as.numeric(p$fill$k)),
    fill_shortened_column = edit(p, "fill", qty = p$fill$qty[-1L]),
    fill_bound = edit(p, "fill", pos = c(4L, 9L)),
    rejection_storage_type = edit(p, "rejection", emit = as.numeric(p$rejection$emit)),
    rejection_shortened_column = edit(p, "rejection", position = p$rejection$position[-1L]),
    rejection_bound = edit(p, "rejection", reason_code = c(2L, 10L)),
    plan_storage_type = utils::modifyList(p, list(expected_final_cash = 1L)),
    plan_shortened_column = utils::modifyList(p, list(expected_final_cash = numeric())),
    O3.03_pos_not_context_pos = edit(p, "fill", pos = c(4L, 2L)),
    O3.33_duplicate_row = edit(p, "rejection", k = c(1L, 4L), pos = c(4L, 2L)),
    O3.40_permutation_returned = c(p, list(afford_order = 2:1)),
    F4.28_unsupported_code = utils::modifyList(p, list(economic_event_kinds = c(1L, 7L))),
    F4.29_side_0 = edit(p, "fill", side = c(-1L, 0L)),
    F4.30_negative_fee = edit(p, "fill", fee = c(0.5, -0.5)),
    F4.31_na_planned = edit(p, "fill", planned_position_after = c(0, NA)),
    F4.32_duplicate_code = edit(p, "fill", info_offset = c(0L, 0L), info_count = c(0L, 2L), info_code = c(4L, 4L)),
    F4.33_emit_out_of_order = edit(p, "rejection", emit = 2:1),
    F4.34_na_position = edit(p, "rejection", position = c(0, NA)),
    primary_not_first = edit(p, "rejection", primary = c(5L, 2L)),
    fills_without_fill_kind = utils::modifyList(p, list(economic_event_kinds = integer())),
    # Correction round 1 (ws13_checkpoint_review.md F3): only an early row
    # lacks a resolved price; only a row without an opportunity lacks an epoch.
    F4.34_late_rejection_na_price = edit(p, "rejection", resolved_price = c(NA, NA)),
    F4.34_late_rejection_na_epoch = edit(p, "rejection", exec_ts = c(1704292200, NA))
  )
  for (name in names(controls)) testthat::expect_true(ws4a_refuses_plan(controls[[name]]), info = name)
  # A final-pulse plan: every row rejected without an opportunity (primary
  # final_pulse_no_execution, no price, no epoch); present values are refused.
  final <- ws4a_ns()$ledgr_fold_build_availability_pulse_plan(
    context_pos = c(4L, 1L, 3L, 2L), target_qty = c(0, 2, 1, 1), position = c(5, 0, 0, 0), actionable_k = 1:4,
    member = rep(TRUE, 4L), execution = list(exec_ts = NA_real_, has_next = FALSE, open = rep(NA_real_, 4L)),
    execution_view = NULL, epoch_valid = TRUE, cost_resolver = ledgr_test_cost_resolver(), cash = 0,
    instrument_ids = c("A", "B", "C", "D"))
  testthat::expect_identical(final$rejection$primary, rep(1L, 4L))
  testthat::expect_false(ws4a_refuses_plan(final))
  testthat::expect_true(ws4a_refuses_plan(edit(final, "rejection", exec_ts = c(1704292200, NA, NA, NA))))
  testthat::expect_true(ws4a_refuses_plan(edit(final, "rejection", resolved_price = c(10, NA, NA, NA))))
  empty_controls <- list(
    fill_kind_on_empty_plan = utils::modifyList(empty, list(economic_event_kinds = 1L)),
    cashflow_kind_on_empty_plan = utils::modifyList(empty, list(economic_event_kinds = 2L)),
    disposition_kind_on_empty_plan = utils::modifyList(empty, list(economic_event_kinds = 3L)),
    fill_untyped_empty = edit(empty, "fill", qty = list()),
    rejection_untyped_empty = edit(empty, "rejection", exec_ts = list())
  )
  for (name in names(empty_controls)) testthat::expect_true(ws4a_refuses_plan(empty_controls[[name]], no_rows), info = name)
  # The execution view group (V-execution-view).
  v <- list(member = c(TRUE, FALSE), restricted = c(FALSE, TRUE), reason_offset = c(0L, 0L), reason_count = c(0L, 2L),
    reason_code = c(5L, 9L))
  view_refused <- function(x) inherits(tryCatch(ns$ledgr_carrier_new(x, "execution_view", NA_integer_), error = identity),
    "ledgr_invalid_pulse_plan")
  testthat::expect_false(view_refused(v))
  testthat::expect_false(view_refused(lapply(v, `[`, 0L)))
  view_controls <- list(
    storage_type = utils::modifyList(v, list(member = c(1L, 0L))),
    shortened_column = utils::modifyList(v, list(restricted = TRUE)),
    bound = utils::modifyList(v, list(reason_code = c(5L, 10L))),
    untyped_empty = utils::modifyList(lapply(v, `[`, 0L), list(member = list())),
    F4.24_unequal_segment_lengths = utils::modifyList(v, list(reason_code = 5L)),
    restricted_without_reasons = utils::modifyList(v, list(restricted = c(TRUE, TRUE)))
  )
  for (name in names(view_controls)) testthat::expect_true(view_refused(view_controls[[name]]), info = name)
  # The adapter: a token outside the dictionary refuses with the pulse-plan
  # class; a repeated token keeps its first occurrence.
  provider <- list(execution_view = function(cutoff, ids) list(member = stats::setNames(TRUE, ids),
    restricted = stats::setNames(TRUE, ids), reasons = stats::setNames("trading_halted|valuation_frozen", ids)))
  testthat::expect_error(ns$ledgr_carrier_execution_view(provider, 1704292200, "A"), class = "ledgr_invalid_pulse_plan")
  provider$execution_view <- function(cutoff, ids) list(member = stats::setNames(TRUE, ids),
    restricted = stats::setNames(TRUE, ids), reasons = stats::setNames("lifetime_inactive|trading_halted|lifetime_inactive", ids))
  testthat::expect_identical(ns$ledgr_carrier_execution_view(provider, 1704292200, "A")$reason_code, c(9L, 5L))
})

testthat::test_that("[WS4a F4.27 empty plan] skip plans plan nothing at the fold cash; empty plans declare no kind", {
  ns <- ws4a_ns()
  fold_state <- list(cash = 1234.5, positions = c(0, 2, 0))
  skip_ok <- function(s) identical(s$batch$expected_final_cash, fold_state$cash) &&
    identical(s$batch$economic_event_kinds, integer()) && length(s$batch$fill$k) == 0L && length(s$batch$rejection$k) == 0L
  testthat::expect_true(skip_ok(ns$ledgr_fold_scheduled_skip_plan(fold_state, list(context_pos = c(2L, 3L)))))
  # Control: a skip plan whose expected cash differs from the fold cash.
  mutant <- ns$ledgr_fold_scheduled_skip_plan
  body(mutant) <- str2lang(sub("expected_final_cash = fold_state$cash", "expected_final_cash = fold_state$cash + 1",
    paste(deparse(body(mutant), width.cutoff = 500L), collapse = "\n"), fixed = TRUE))
  testthat::expect_false(skip_ok(mutant(fold_state, list(context_pos = c(2L, 3L)))))
  # An empty production plan (no actionable ordinal) declares no kind; the
  # constructor refuses an empty plan declaring FILL.
  empty <- ws4b_test_build_pulse_plan(1L, 0, 0, integer(), 1L, TRUE, 1704292200, TRUE,
    list(open = matrix(10, 1L, 2L)), ledgr_test_cost_resolver(), 1L)
  testthat::expect_identical(empty$economic_event_kinds, integer())
  testthat::expect_true(ws4a_refuses_plan(utils::modifyList(empty, list(economic_event_kinds = 1L)),
    list(context_pos = 1L, actionable_k = integer()), 1L))
})

testthat::test_that("[WS4a 3166 precedence] batched planning refuses in the base order", {
  ns <- ws4a_ns()
  # An invalid epoch is a sub-second one, as E flags it.
  short <- function(order, epoch_valid = TRUE, open = c(10, 10)) {
    ns$ledgr_fold_build_availability_pulse_plan(
      context_pos = order, target_qty = c(-1, -2), position = c(0, 0), actionable_k = 1:2, member = c(TRUE, TRUE),
      execution = list(exec_ts = if (epoch_valid) 1704292200 else 1704292200.25, has_next = TRUE, open = open),
      execution_view = list(member = c(TRUE, TRUE), restricted = c(FALSE, FALSE), reason_offset = c(0L, 0L),
        reason_count = c(0L, 0L), reason_code = integer()),
      epoch_valid = epoch_valid, cost_resolver = ledgr_test_cost_resolver(), cash = 100, instrument_ids = c("A", "B"))
  }
  # Two short-exposure violations: the first in decision order refuses alone.
  first <- tryCatch(short(1:2), error = identity)
  testthat::expect_s3_class(first, "ledgr_short_exposure_unsupported")
  testthat::expect_identical(first$instrument_ids, "A")
  testthat::expect_identical(tryCatch(short(2:1), error = identity)$instrument_ids, "B")
  # An invalid execution epoch refuses before any short-exposure check; with
  # no execution bar it is never needed.
  testthat::expect_error(short(1:2, epoch_valid = FALSE), class = "LEDGR_SUBSECOND_TIMESTAMP")
  testthat::expect_length(short(1:2, epoch_valid = FALSE, open = c(NA, NA))$rejection$k, 2L)
})

# D1 for the planners: no proposal, fill-context or fill-intent object, no
# S3 constructor and no POSIXct conversion; no per-row list or apply-family
# callback; the only loops are the identified ones below (the affordability
# scan, the cost-step loop and the per-target final-bar warning), and none of
# them builds a list.
ws4a_d1_planners <- c("ledgr_fold_stage_plan", "ledgr_fold_build_availability_pulse_plan",
  "ledgr_plan_affordability", "ledgr_plan_groups", "ledgr_plan_resolve", "ledgr_plan_side", "ledgr_carrier_segments",
  "ledgr_carrier_segment_rows", "ledgr_carrier_execution_view", "ledgr_cost_model_resolve", "ledgr_fill_publication_deltas",
  "ledgr_plan_refuse_first", "ledgr_plan_refuse_inputs")
ws4a_d1_loops <- c(
  ledgr_plan_refuse_first = "for (j in seq_along(fails))",
  ledgr_plan_affordability = "for (idx in priority)",
  ledgr_cost_model_resolve = "for (step in steps)"
)
# The execution-view adapter is the provider boundary: one cutoff per pulse.
ws4a_d1_allowed <- c(ledgr_carrier_execution_view = ".POSIXct")
ws4a_d1_hits <- function(fns) {
  banned <- c("structure", "class<-", "oldClass<-", "as.POSIXct", ".POSIXct", "as.POSIXlt", "strptime",
    "ledgr_ts_utc_posix", "ledgr_normalize_ts_utc", "ledgr_next_open_fill_proposal", "ledgr_resolve_fill_proposal",
    "ledgr_fill_context", "lapply", "vapply", "sapply", "Map", "mapply")
  unlist(lapply(names(fns), function(nm) {
    calls <- ws4a_calls(fns[[nm]])
    heads <- vapply(calls, ws4a_head, "")
    hits <- setdiff(intersect(heads, banned), ws4a_d1_allowed[names(ws4a_d1_allowed) == nm])
    lists <- Filter(function(x) ws4a_head(x) == "vector" && "\"list\"" %in% vapply(as.list(x)[-1L], ws4a_txt, ""), calls)
    loops <- vapply(Filter(function(x) ws4a_head(x) %in% c("for", "while", "repeat"), calls), function(x) {
      if (ws4a_head(x) == "for") paste0("for (", ws4a_txt(x[[2L]]), " in ", ws4a_txt(x[[3L]]), ")") else ws4a_head(x)
    }, "")
    loops <- setdiff(loops, ws4a_d1_loops[names(ws4a_d1_loops) == nm])
    in_loops <- unlist(lapply(ws4a_loop_bodies(fns[[nm]]), function(b) intersect(ws4a_heads(b), c("list", "vector"))))
    h <- c(hits, if (length(lists)) "vector(\"list\")", loops, in_loops)
    if (length(h)) paste0(nm, ": ", h)
  }))
}

testthat::test_that("[WS4a D1 planners] no per-fill list, S3 object or timestamp parse in either planner", {
  fns <- ws4a_sources()
  testthat::expect_true(all(ws4a_d1_planners %in% names(fns)))
  testthat::expect_length(ws4a_d1_hits(fns[ws4a_d1_planners]), 0L)
  # The retired per-fill objects and helpers are gone.
  testthat::expect_length(intersect(names(fns), c("ledgr_next_open_fill_proposal", "ledgr_resolve_fill_proposal",
    "ledgr_fill_context", "ledgr_availability_apply_affordability", "ledgr_fold_pulse_plan_fill_intents")), 0L)
  inject <- function(nm, stmt) {
    bad <- fns[nm]
    bad[[nm]] <- ws4a_inject(bad[[nm]], stmt)
    ws4a_d1_hits(bad)
  }
  testthat::expect_gt(length(inject("ledgr_fold_build_availability_pulse_plan", "rows <- vector(\"list\", n)")), 0L)
  testthat::expect_gt(length(inject("ledgr_fold_build_availability_pulse_plan", "ts <- as.POSIXct(exec_ts, tz = \"UTC\")")), 0L)
  testthat::expect_gt(length(inject("ledgr_fold_build_availability_pulse_plan",
    "for (i in seq_len(n)) rows[[i]] <- list(k = k[[i]])")), 0L)
  testthat::expect_gt(length(inject("ledgr_fold_build_availability_pulse_plan",
    "fill <- structure(list(qty = qty), class = \"ledgr_fill_intent\")")), 0L)
  testthat::expect_gt(length(inject("ledgr_fold_build_availability_pulse_plan", "qty <- vapply(seq_len(n), function(i) qty[[i]], 0)")), 0L)
  # A list built inside the identified scan fails.
  testthat::expect_gt(length(inject("ledgr_plan_affordability", "for (idx in priority) seen <- list(idx)")), 0L)
  # P3 itself is in scope (ws13_checkpoint_review.md F4): a per-row callback there fails.
  testthat::expect_gt(length(inject("ledgr_fold_stage_plan", "rows <- vapply(seq_along(fill$k), function(i) fill$qty[[i]], 0)")), 0L)
})

# D3 for the LDG-3166 regions: the planners, P3's plan helpers, the
# execution-view adapter and the publication input boundaries, with the
# name-keyed predicate plus %in%. Census: the short-exposure refusal names its
# instrument; the rest test dictionary tokens, codes or field names.
ws4a_d3_3166_fns <- c("ledgr_fold_build_availability_pulse_plan", "ledgr_plan_affordability",
  "ledgr_plan_groups", "ledgr_carrier_segments", "ledgr_carrier_segment_rows", "ledgr_carrier_execution_view",
  "ledgr_cost_model_resolve", "ledgr_fill_publication_deltas", "ledgr_fold_plan_event_kinds", "ledgr_fold_scheduled_skip_plan",
  "ledgr_fill_event_payload", "ledgr_write_fill_events", "ledgr_fill_input_check")
ws4a_d3_3166 <- c(
  ledgr_fold_build_availability_pulse_plan = "stats::setNames(resulting[[i]], id)",
  ledgr_fold_build_availability_pulse_plan = "stats::setNames(before[[i]], id)",
  ledgr_carrier_execution_view = "match(unlist(tokens, use.names = FALSE), .ledgr_plan_reason_levels)",
  ledgr_fold_plan_event_kinds = "1L %in% kinds",
  ledgr_write_fill_events = "side %in% c(1L, -1L)",
  ledgr_fill_input_check = "columns %in% names(fill)"
)
ws4a_d3_3166_found <- function(e) {
  c(ws4a_name_keyed(e), vapply(Filter(function(x) ws4a_head(x) == "%in%", ws4a_calls(e)),
    function(x) substr(ws4a_txt(x), 1L, 70L), ""))
}

testthat::test_that("[WS4a D3 3166] the planners and publication inputs index by position", {
  fns <- ws4a_sources()
  hits <- function(f) {
    unlist(lapply(names(f), function(nm) {
      h <- setdiff(unique(ws4a_d3_3166_found(f[[nm]])), ws4a_d3_3166[names(ws4a_d3_3166) == nm])
      if (length(h)) paste0(nm, ": ", h)
    }))
  }
  testthat::expect_true(all(ws4a_d3_3166_fns %in% names(fns)))
  testthat::expect_length(hits(fns[ws4a_d3_3166_fns]), 0L)
  found <- unlist(lapply(unique(names(ws4a_d3_3166)), function(nm) paste(nm, ws4a_d3_3166_found(fns[[nm]]))))
  testthat::expect_setequal(found, paste(names(ws4a_d3_3166), ws4a_d3_3166))
  inject <- function(nm, stmt) {
    bad <- fns[nm]
    bad[[nm]] <- ws4a_inject(bad[[nm]], stmt)
    hits(bad)
  }
  testthat::expect_gt(length(inject("ledgr_fold_build_availability_pulse_plan", "open <- execution$open[instrument_ids]")), 0L)
  testthat::expect_gt(length(inject("ledgr_fold_build_availability_pulse_plan", "pos <- match(ids, rownames(execution$open))")), 0L)
  testthat::expect_gt(length(inject("ledgr_fill_event_payload", "keep <- instrument_id %in% held")), 0L)
})

# D8: the fold and the sinks hold no fill-intent object and never recompute
# publication effects: ledgr_fill_publication_deltas() is called by the
# planners only.
ws4a_d8_regions <- c("ledgr_fold_stage_plan", "ledgr_fold_stage_apply", "ledgr_fold_stage_commit", "ledgr_fold_scheduled_skip_plan",
  "ledgr_output_handler", "ledgr_output_sink_duckdb", "ledgr_output_sink_memory", "ledgr_fill_event_payload",
  "ledgr_fill_leg_block", "ledgr_write_fill_events", "ledgr_write_fill_publication_row",
  "ledgr_run_compiled_spot_fifo_batch")
ws4a_d8_hits <- function(fns) {
  intent <- c("ledgr_fill_intent", "ledgr_fill_none", "ledgr_fill_proposal", "ledgr_fill_context")
  unlist(lapply(names(fns), function(nm) {
    calls <- ws4a_calls(fns[[nm]])
    strings <- unlist(lapply(calls, function(x) Filter(is.character, as.list(x)[-1L])))
    # Inline effect arithmetic (correction round 1, F4): a quantity times a
    # price is a cash effect, a negated quantity a position effect; consumers
    # read P3's columns instead, whatever the numbers.
    arith <- Filter(function(x) {
      h <- ws4a_head(x)
      (h == "*" && "qty" %in% all.names(x) && any(c("price", "fill_price") %in% all.names(x))) ||
        (h == "-" && length(x) == 2L && "qty" %in% all.names(x[[2L]]))
    }, calls)
    h <- c(intersect(strings, intent), intersect(vapply(calls, ws4a_head, ""),
      c(
        "ledgr_fill_publication_deltas", ".ledgr_fill_publication_formula",
        "ledgr_next_open_fill_proposal", "ledgr_resolve_fill_proposal",
        "ledgr_fill_context"
      )),
      vapply(arith, function(x) substr(ws4a_txt(x), 1L, 60L), ""))
    if (length(h)) paste0(nm, ": ", h)
  }))
}

testthat::test_that("[WS4a D8] no fill-intent object in the fold or sinks; effects are computed once, in P3", {
  fns <- ws4a_sources()
  testthat::expect_true(all(ws4a_d8_regions %in% names(fns)))
  testthat::expect_length(ws4a_d8_hits(fns[ws4a_d8_regions]), 0L)
  inject <- function(nm, stmt) {
    bad <- fns[nm]
    bad[[nm]] <- ws4a_inject(bad[[nm]], stmt)
    ws4a_d8_hits(bad)
  }
  testthat::expect_gt(length(inject("ledgr_fill_event_payload", "intent <- structure(list(), class = \"ledgr_fill_intent\")")), 0L)
  testthat::expect_gt(length(inject("ledgr_write_fill_events", "fx <- ledgr_fill_publication_deltas(side, qty, fill_price, fee)")), 0L)
  testthat::expect_gt(length(inject("ledgr_write_fill_events", "fx <- .ledgr_fill_publication_formula(side, qty, fill_price, fee)")), 0L)
  testthat::expect_gt(length(inject("ledgr_write_fill_publication_row", "fx <- ledgr_fill_publication_deltas(side, qty, fill_price, fee)")), 0L)
  # Inline recomputation is caught even though it yields identical numbers.
  testthat::expect_gt(length(inject("ledgr_fill_event_payload", "cash_delta <- -(fill$qty[[i]] * fill$price[[i]] + fill$fee[[i]])")), 0L)
  testthat::expect_gt(length(inject("ledgr_write_fill_events", "signed_qty <- -fill$qty[[i]]")), 0L)
  testthat::expect_gt(length(inject("ledgr_run_compiled_spot_fifo_batch", "batch$cash_delta <- -(fills$qty * fills$price + fills$fee)")), 0L)
  testthat::expect_gt(length(inject("ledgr_fold_stage_apply", "cash <- cash - fill$qty[[i]] * fill$price[[i]]")), 0L)

  # Runtime: every computation happens inside P3, at most once per P3 call,
  # and covers every published fill, on durable, db_live and memory sinks.
  ns <- ws4a_ns()
  count <- function(recompute = FALSE, twice = FALSE) {
    n <- new.env()
    n$inside <- FALSE
    n$here <- 0L
    n$outside <- 0L
    n$max_per_p3 <- 0L
    n$rows <- 0L
    n$fills <- 0L
    deltas <- ns$ledgr_fill_publication_deltas
    plan <- ns$ledgr_fold_stage_plan
    payload <- ns$ledgr_fill_event_payload
    writer <- ns$ledgr_write_fill_events
    build <- ns$ledgr_fold_build_availability_pulse_plan
    testthat::local_mocked_bindings(
      ledgr_fill_publication_deltas = function(side, qty, fill_price, fee) {
        if (n$inside) {
          n$here <- n$here + 1L
          n$max_per_p3 <- max(n$max_per_p3, n$here)
          n$rows <- n$rows + length(qty)
        } else {
          n$outside <- n$outside + 1L
        }
        deltas(side, qty, fill_price, fee)
      },
      ledgr_fold_stage_plan = function(...) {
        n$inside <- TRUE
        n$here <- 0L
        on.exit(n$inside <- FALSE)
        out <- plan(...)
        n$fills <- n$fills + length(out$batch$fill$k)
        out
      },
      # Controls: a sink recomputing the effects; a planner computing twice.
      ledgr_fill_event_payload = function(run_id, fill, i, ...) {
        if (recompute && length(i)) ns$ledgr_fill_publication_deltas(fill$side[i], fill$qty[i], fill$price[i], fill$fee[i])
        payload(run_id, fill, i, ...)
      },
      ledgr_write_fill_events = function(con, run_id, fill, i, ...) {
        if (recompute && length(i)) ns$ledgr_fill_publication_deltas(fill$side[i], fill$qty[i], fill$price[i], fill$fee[i])
        writer(con, run_id, fill, i, ...)
      },
      ledgr_fold_build_availability_pulse_plan = function(...) {
        out <- build(...)
        if (twice) ns$ledgr_fill_publication_deltas(out$fill$side, out$fill$qty, out$fill$price, out$fill$fee)
        out
      },
      .package = "ledgr"
    )
    ws4a_3166_runs()
    as.list(n)
  }
  ok <- function(n) n$fills > 0L && n$outside == 0L && n$max_per_p3 == 1L && n$rows >= n$fills
  testthat::expect_true(ok(count()))
  testthat::expect_false(ok(count(recompute = TRUE)))
  testthat::expect_false(ok(count(twice = TRUE)))
})

testthat::test_that("[WS4a 2.5] reused effects equal both base formulas on every fill", {
  ns <- ws4a_ns()
  fills <- list()
  plan <- ns$ledgr_fold_stage_plan
  testthat::local_mocked_bindings(
    ledgr_fold_stage_plan = function(...) {
      out <- plan(...)
      if (!is.null(out$batch) && length(out$batch$fill$k)) fills[[length(fills) + 1L]] <<- out$batch$fill
      out
    },
    .package = "ledgr"
  )
  ws4a_3166_runs()
  # The base scalar formulas: ledgr_fill_publication_deltas() and
  # ledgr_availability_fill_cash_delta() at 953338df.
  base_publication <- function(side, qty, price, fee) {
    list(cash_delta = if (side == "BUY") -(qty * price + fee) else +(qty * price - fee),
      position_delta = if (side == "BUY") qty else -qty)
  }
  base_affordability <- function(side, qty, price, fee) if (identical(side, "BUY")) -(qty * price + fee) else qty * price - fee
  same <- function(f) {
    all(vapply(seq_along(f$k), function(i) {
      side <- if (f$side[[i]] > 0L) "BUY" else "SELL"
      b <- base_publication(side, f$qty[[i]], f$price[[i]], f$fee[[i]])
      identical(f$cash_delta[[i]], b$cash_delta) && identical(f$position_delta[[i]], b$position_delta) &&
        identical(f$cash_delta[[i]], base_affordability(side, f$qty[[i]], f$price[[i]], f$fee[[i]]))
    }, logical(1)))
  }
  testthat::expect_gt(length(fills), 5L)
  testthat::expect_true(any(vapply(fills, function(f) any(f$side < 0L), logical(1))))
  testthat::expect_true(all(vapply(fills, same, logical(1))))
  bad <- fills[[1L]]
  bad$cash_delta[[1L]] <- bad$cash_delta[[1L]] + 1e-9
  testthat::expect_false(same(bad))
})

testthat::test_that("[WS4a D22] the P3, restriction, mark-source, kind and side dictionaries match their literal fixtures", {
  ns <- ws4a_ns()
  fixtures <- list(
    plan_reason = c("final_pulse_no_execution", "execution_bar_missing", "insufficient_cash",
      "membership_changed_before_execution", "trading_halted", "quotation_only", "status_unknown",
      "status_unknown_or_conflicting", "lifetime_inactive"),
    restriction = c("trading_halted", "quotation_only", "status_unknown", "status_unknown_or_conflicting",
      "lifetime_inactive", "valuation_frozen"),
    mark_source = c("missing", "expired_close", "current_close", "stale_close", "frozen_close"),
    kind = c("FILL", "CASHFLOW", "DISPOSITION")
  )
  levels <- list(plan_reason = ns$.ledgr_plan_reason_levels, restriction = ns$.ledgr_carrier_restriction_levels,
    mark_source = ns$.ledgr_carrier_mark_source_levels, kind = ns$.ledgr_plan_kind_levels)
  for (name in names(fixtures)) testthat::expect_identical(levels[[name]], fixtures[[name]], info = name)
  # Code 0 is the empty string, never an index; kinds decode by code.
  testthat::expect_identical(ns$ledgr_carrier_segment_text(0L, 0L, integer(), fixtures$plan_reason)$reasons, "")
  testthat::expect_identical(ns$ledgr_plan_kind_text(c(1L, 3L, 99L)), c("FILL", "DISPOSITION", "99"))
  # Side: +1 BUY, -1 SELL in the carrier; tokens at publication.
  testthat::expect_identical(ns$ledgr_plan_side(c(2, -0.5)), c(1L, -1L))
  buy <- ledgr_test_next_open_fill(1, list(instrument_id = "A", ts_utc = "2020-01-02T00:00:00Z", open = 10))
  sell <- ledgr_test_next_open_fill(-1, list(instrument_id = "A", ts_utc = "2020-01-02T00:00:00Z", open = 10))
  testthat::expect_identical(c(ns$ledgr_fill_event_payload("r", buy$fill, 1L, "A", 1L)$side,
    ns$ledgr_fill_event_payload("r", sell$fill, 1L, "A", 1L)$side), c("BUY", "SELL"))
  # Control: a renumbered token fails the fixture comparison.
  renumbered <- replace(levels$plan_reason, 2:3, levels$plan_reason[3:2])
  testthat::expect_false(identical(renumbered, fixtures$plan_reason))
})

testthat::test_that("[WS4a D24] the execution view is called only from P3", {
  root <- ledgr_test_source_root()
  checker <- new.env(parent = baseenv())
  sys.source(file.path(root, "tools", "check-fold-phase-contract.R"), envir = checker)
  files <- list.files(file.path(root, "R"), "\\.R$", full.names = TRUE)
  rx <- "ledgr_carrier_execution_view"
  testthat::expect_length(grep(rx, checker$ledgr_fold_phase_source_findings(files), value = TRUE), 0L)
  fns <- ws4a_sources()
  testthat::expect_true("ledgr_carrier_execution_view" %in% ws4a_heads(fns$ledgr_fold_stage_plan))
  bad <- tempfile(fileext = ".R")
  writeLines(c("ledgr_fold_stage_apply <-", deparse(ws4a_inject(fns$ledgr_fold_stage_apply,
    "view <- ledgr_carrier_execution_view(services$availability_provider, 1, \"A\")"), width.cutoff = 500L)), bad)
  testthat::expect_gt(length(grep(rx, checker$ledgr_fold_phase_source_findings(c(files, bad)), value = TRUE)), 0L)
})

# --- LDG-3166 correction round 1 (ws13_checkpoint_review.md) ----------------

# D8 production handoff: every published fill's cash and position effects are
# P3's validated carried columns. The former +0.5 inconsistent-effect arm is
# superseded by the typed-accounting boundary: an effect that disagrees with
# quantity, price and fee must now refuse before publication. Paths: durable
# and db_live dense runs, a canonical availability sweep and a compiled dense
# sweep.
ws4a_handoff <- function(wrong_effect = FALSE) {
  ns <- ws4a_ns()
  seen <- new.env()
  seen$carried <- list()
  seen$handlers <- list()
  add <- function(fill) {
    key <- seen$key
    seen$carried[[key]] <- c(seen$carried[[key]], fill$cash_delta)
  }
  shift <- function(plan) {
    if (wrong_effect && length(plan$fill$k)) {
      plan$fill$cash_delta <- plan$fill$cash_delta + 0.5
      if (!is.na(plan$expected_final_cash)) {
        plan$expected_final_cash <- plan$expected_final_cash + 0.5 * length(plan$fill$k)
      }
    }
    add(plan$fill)
    plan
  }
  avail_plan <- ns$ledgr_fold_build_availability_pulse_plan
  handler <- ns$ledgr_output_handler
  testthat::local_mocked_bindings(
    ledgr_fold_build_availability_pulse_plan = function(...) shift(avail_plan(...)),
    ledgr_output_handler = function(sink, ...) {
      seen$key <- sink$run_id
      h <- handler(sink, ...)
      seen$handlers[[sink$run_id]] <- h
      h
    },
    .package = "ledgr"
  )
  dense <- ws4a_3166_fixture(FALSE)
  withr::defer(ledgr_snapshot_close(dense$snap))
  close(ledgr_run(dense$exp(), params = dense$params, run_id = "ws4a-handoff-dense", seed = 1L))
  close(ledgr_run(dense$exp(execution_mode = "db_live"), params = dense$params, run_id = "ws4a-handoff-live", seed = 1L))
  ledgr_sweep(dense$exp(), ledgr_grid_named(c = list(strategy = dense$params)), seed = 1L, compiled_accounting_model = "spot_fifo")
  avail <- ws4a_3166_fixture(TRUE)
  withr::defer(ledgr_snapshot_close(avail$snap))
  ledgr_sweep(avail$exp(), ledgr_grid_named(a = list(strategy = avail$params)), seed = 1L)
  opened <- ledgr_test_open_duckdb(dense$snap$db_path)
  rows <- DBI::dbGetQuery(opened$con, paste("SELECT run_id, cash_delta FROM ledger_events",
    "WHERE event_type = 'FILL' ORDER BY run_id, event_seq"))
  ledgr_test_close_duckdb(opened$con, opened$drv)
  published <- split(as.numeric(rows$cash_delta), rows$run_id)
  for (key in setdiff(names(seen$carried), names(published))) {
    events <- seen$handlers[[key]]$typed_events()
    published[[key]] <- events$cash_delta[events$event_type == "FILL"]
  }
  keys <- names(seen$carried)
  list(keys = keys, same = vapply(keys, function(k) identical(unname(published[[k]]), seen$carried[[k]]), logical(1)))
}

testthat::test_that("[WS4a D8 handoff] durable, db_live, memory and compiled publication publish P3's carried effects", {
  clean <- ws4a_handoff()
  # Four paths, each with fills: dense durable, dense db_live, compiled dense
  # sweep candidate, canonical availability sweep candidate.
  testthat::expect_length(clean$keys, 4L)
  testthat::expect_true(all(clean$same))
  # The accepted typed boundary supersedes the old inconsistent-effect
  # transport arm. Removing formula validation makes this mutation run.
  testthat::expect_error(
    ws4a_handoff(wrong_effect = TRUE),
    class = "ledgr_invalid_ledger_meta"
  )
})

# F1 successor: Workstream 14 deleted the dense planner. Its inherited
# multi-error controls now pin the one canonical planner's order.
testthat::test_that("[WS4b F1 canonical refusals] the planner refuses with the canonical class, message and order", {
  ns <- ws4a_ns()
  t1 <- 1704292200
  big <- 1e308
  base <- list(
    delta = c("ledgr_invalid_fill_input", "`desired_qty_delta` must be a finite numeric scalar."),
    open = c("ledgr_invalid_fill_input", "`next_open_price` must be a finite numeric scalar > 0."),
    epoch = c("LEDGR_SUBSECOND_TIMESTAMP", paste("`next_bar$ts_utc` must use whole-second UTC timestamps;",
      "sub-second timestamps are out of scope.")),
    short_a = c("ledgr_short_exposure_unsupported", "Availability-aware execution cannot open or enlarge short exposure: A."),
    short_b = c("ledgr_short_exposure_unsupported", "Availability-aware execution cannot open or enlarge short exposure: B.")
  )
  overflow <- ns$ledgr_cost_resolver_from_model(ledgr_cost_chain(ledgr_cost_fixed_fee(1e308), ledgr_cost_notional_bps_fee(1e308)))
  avail <- function(position, target, open = c(10, 10), sub = FALSE, cost = ledgr_test_cost_resolver()) {
    ts <- t1 + if (sub) 0.25 else 0
    ns$ledgr_fold_build_availability_pulse_plan(1:2, target, position, 1:2, c(TRUE, TRUE),
      list(exec_ts = ts, has_next = TRUE, open = open),
      list(member = c(TRUE, TRUE), restricted = c(FALSE, FALSE), reason_offset = c(0L, 0L), reason_count = c(0L, 0L),
        reason_code = integer()), ns$ledgr_plan_epoch_valid(ts), cost, 1000, c("A", "B"))
  }
  refusal <- function(expr) {
    warnings <- 0L
    e <- withCallingHandlers(tryCatch({ force(expr); NULL }, error = identity),
      warning = function(w) { warnings <<- warnings + 1L; invokeRestart("muffleWarning") })
    if (is.null(e)) return(c("none", "", warnings))
    c(class(e)[[1L]], conditionMessage(e), warnings)
  }
  cases <- list(
    avail_short1_delta2 = list(function() avail(c(0, -big), c(-1, big)), c(base$short_a, 0)),
    avail_delta1_short2 = list(function() avail(c(-big, 0), c(big, -1)), c(base$delta, 0)),
    avail_nobar_delta1_short2 = list(function() avail(c(-big, 0), c(big, -1), open = c(NA, 10)), c(base$short_b, 0)),
    avail_nobar1_delta2_sub = list(function() avail(c(0, -big), c(1, big), open = c(NA, 10), sub = TRUE), c(base$delta, 0)),
    avail_ok1_sub = list(function() avail(c(0, 0), c(1, 1), sub = TRUE), c(base$epoch, 0)),
    avail_short1_sub = list(function() avail(c(0, 0), c(-1, 1), sub = TRUE), c(base$epoch, 0))
  )
  for (name in names(cases)) {
    testthat::expect_identical(refusal(cases[[name]][[1L]]()), as.character(cases[[name]][[2L]]), info = name)
  }
  # Without an execution bar the epoch is never needed (base: two rejections).
  testthat::expect_length(avail(c(0, 0), c(1, 1), open = c(NA, NA), sub = TRUE)$rejection$k, 2L)
  # Fee overflow is rejected by the canonical affordability path.
  ovf_avail <- avail(c(0, 0), c(2, 1), cost = overflow)
  testthat::expect_identical(ns$.ledgr_plan_reason_levels[ovf_avail$rejection$primary], rep("insufficient_cash", 2L))
})

# Checkpoint re-review 1, N1: finite public cost inputs that produce an
# arithmetic NaN fee or cash effect keep the base accounting refusal, and the
# plan still refuses an ordinary NA or a NaN cash effect with a finite fee.
testthat::test_that("[WS4b F1 arithmetic NaN] typed plan validation keeps accounting refusals", {
  for (field in c("fee", "cash_delta")) {
    p <- ws4a_3166_plan(); p$fill[[field]][1L] <- NA_real_
    testthat::expect_true(ws4a_refuses_plan(p))
  }
  p <- ws4a_3166_plan(); p$fill$fee[1L] <- 0; p$fill$cash_delta[1L] <- NaN
  testthat::expect_true(ws4a_refuses_plan(p))
})

# --- LDG-3167: batched application and indexed publication -------------------

# The publication path: P4 and its candidate, the block, leg and routed
# metadata builders, the leg-fee split, the result-buffer writer, and the
# handler and sink closures that publish fills, keyed "<function>/<assigned
# name>" for a closure (two definitions of one name are joined).
ws4a_pub_fns <- c("ledgr_fold_stage_apply", "ledgr_fold_fill_candidate", "ledgr_fill_event_payload",
  "ledgr_fill_leg_block", "ledgr_fill_leg_fees", "ledgr_fill_row_buffer_add_many",
  "ledgr_write_fill_publication_row")
ws4a_pub_closures <- c(
  ledgr_output_handler = "stage_fill_block", ledgr_output_handler = "handler$write_fill_events",
  ledgr_output_handler = "handler$flush_pulse_events", ledgr_output_handler = "handler$record_accounting_fact",
  ledgr_output_handler = "handler$append_event_rows", ledgr_output_sink_memory = "sink$stage_legs",
  ledgr_output_sink_memory = "add_legs", ledgr_output_sink_memory = "sink$flush_legs",
  ledgr_output_sink_duckdb = "sink$write_fill_live"
)
ws4a_publication <- function(fns) {
  out <- fns[ws4a_pub_fns]
  for (parent in unique(names(ws4a_pub_closures))) {
    for (a in ws4a_assigns(fns[[parent]])) {
      lhs <- ws4a_txt(a[[2L]])
      key <- paste0(parent, "/", lhs)
      if (lhs %in% ws4a_pub_closures[names(ws4a_pub_closures) == parent] && is.call(a[[3L]]) &&
          ws4a_head(a[[3L]]) == "function") {
        out[[key]] <- if (is.null(out[[key]])) a[[3L]] else call("function", NULL, call("{", out[[key]], a[[3L]]))
      }
    }
  }
  out
}
ws4a_inject_into <- function(fns, nm, stmt) {
  fns[[nm]] <- ws4a_inject(fns[[nm]], stmt)
  fns[nm]
}

# D1 (publication): no S3 object, POSIXct conversion, list staging or
# apply-family recovery per fill. The identified exceptions: the boundary
# conversions (epochs validated once per block, POSIXct where a buffer is
# written); the routed metadata (one list per row, its JSON and the non-fill
# rows' parsed metadata; WS7/WS8); field-name loops over a block's fixed
# columns; db_live's one INSERT per fill; the refusal path's bisection.
ws4a_d1_pub_allowed <- c(
  ledgr_fill_event_payload = ".POSIXct", "ledgr_output_handler/handler$flush_pulse_events" = ".POSIXct",
  "ledgr_output_handler/handler$write_fill_events" = ".POSIXct",
  "ledgr_output_handler/handler$write_fill_events" = "as.POSIXct",
  ledgr_write_fill_publication_row = ".POSIXct", ledgr_write_fill_publication_row = "as.POSIXct",
  ledgr_write_fill_publication_row = "lapply", ledgr_write_fill_publication_row = "structure",
  ledgr_fill_row_buffer_add_many = "as.POSIXct", ledgr_fill_meta_rows = "Map", ledgr_fill_meta_rows = "list",
  ledgr_fill_event_payload = "vapply", "ledgr_output_handler/handler$append_event_rows" = "lapply",
  "ledgr_output_handler/handler$append_event_rows" = "vapply",
  "ledgr_output_sink_duckdb/sink$write_fill_live" = "structure"
)
ws4a_d1_pub_loops <- c(
  ledgr_fold_fill_candidate = "while (failed - ok > 1L)",
  "ledgr_output_handler/stage_fill_block" = "for (name in setdiff(names(block), c(\"status\", \"next_event_seq\")))",
  "ledgr_output_handler/handler$flush_pulse_events" = "for (name in setdiff(ledgr_output_event_columns, \"ts_utc\"))",
  "ledgr_output_sink_memory/sink$stage_legs" = "for (name in names(legs))",
  "ledgr_output_handler/handler$append_event_rows" = "for (name in ledgr_output_event_columns)",
  "ledgr_output_sink_duckdb/sink$write_fill_live" = "for (k in seq_along(publication$event_seq))"
)
ws4a_d1_pub_hits <- function(fns) {
  banned <- c("structure", "class<-", "oldClass<-", "as.POSIXct", ".POSIXct", "as.POSIXlt", "strptime",
    "ledgr_normalize_ts_utc", "lapply", "vapply", "sapply", "Map", "mapply")
  unlist(lapply(names(fns), function(nm) {
    allowed <- ws4a_d1_pub_allowed[names(ws4a_d1_pub_allowed) == nm]
    calls <- ws4a_calls(fns[[nm]])
    hits <- setdiff(intersect(vapply(calls, ws4a_head, ""), banned), allowed)
    lists <- Filter(function(x) ws4a_head(x) == "vector" && "\"list\"" %in% vapply(as.list(x)[-1L], ws4a_txt, ""), calls)
    loops <- vapply(Filter(function(x) ws4a_head(x) %in% c("for", "while", "repeat"), calls), function(x) {
      switch(ws4a_head(x), `for` = paste0("for (", ws4a_txt(x[[2L]]), " in ", ws4a_txt(x[[3L]]), ")"),
        `while` = paste0("while (", ws4a_txt(x[[2L]]), ")"), "repeat")
    }, "")
    loops <- setdiff(loops, ws4a_d1_pub_loops[names(ws4a_d1_pub_loops) == nm])
    in_loops <- setdiff(unlist(lapply(ws4a_loop_bodies(fns[[nm]]), function(b) {
      intersect(ws4a_heads(b), c("list", "vector"))
    })), allowed)
    h <- c(hits, if (length(lists)) "vector(\"list\")", loops, in_loops)
    if (length(h)) paste0(nm, ": ", h)
  }))
}

testthat::test_that("[WS4a D1 publication] P4 and publication build no per-fill object, list or timestamp", {
  fns <- ws4a_sources()
  pub <- ws4a_publication(fns)
  testthat::expect_true(all(c(ws4a_pub_fns, paste0(names(ws4a_pub_closures), "/", ws4a_pub_closures)) %in% names(pub)))
  testthat::expect_length(ws4a_d1_pub_hits(pub), 0L)
  # The retired per-fill publication helpers are gone.
  testthat::expect_length(intersect(names(fns), c("ledgr_fill_event_row", "ledgr_event_buffer_write_rows")), 0L)
  hit <- function(nm, stmt) length(ws4a_d1_pub_hits(ws4a_inject_into(pub, nm, stmt))) > 0L
  testthat::expect_true(hit("ledgr_output_handler/handler$write_fill_events", "pulse_fill_rows <- vector(\"list\", 256L)"))
  testthat::expect_true(hit("ledgr_fill_event_payload", "for (k in seq_along(i)) row <- list(qty = fill$qty[[k]])"))
  testthat::expect_true(hit("ledgr_fill_event_payload", "res <- structure(list(), class = \"ledgr_ledger_write_result\")"))
  testthat::expect_true(hit("ledgr_output_handler/handler$flush_pulse_events", "cash <- vapply(staged, `[[`, numeric(1), \"cash_delta\")"))
  testthat::expect_true(hit("ledgr_output_handler/handler$record_accounting_fact", "ts <- as.POSIXct(block$ts_utc, tz = \"UTC\")"))
  testthat::expect_true(hit("ledgr_fold_stage_apply", paste("for (i in seq_along(fill$k)) lot_res <- ledgr_lot_fill(",
    "fold_state$lot_state, fill$pos[[i]], fill$side[[i]], fill$qty[[i]], fill$price[[i]], fill$fee[[i]])")))
})

# D9: no per-fill economic staging list and no per-leg staging list in the
# handler, the sinks or the block builders. The retained, routed
# representations pass: fixed-column materialization and retained diagnostic
# chunks.
ws4a_d9_allowed <- c(
  "diagnostic_parts <- vector(\"list\", 64L)",
  "diagnostic_parts <<- c(diagnostic_parts, vector(\"list\", length(diagnostic_parts)))",
  "lapply(ledgr_output_event_columns, function(name) cols[[name]][keep])",
  "lapply(ledgr_output_event_columns, function(name) cols[[name]][idx])"
)
ws4a_d9_hits <- function(fns) {
  unlist(lapply(names(fns), function(nm) {
    assigns <- ws4a_assigns(fns[[nm]])
    alloc <- vapply(Filter(function(a) is.call(a[[3L]]) && ws4a_head(a[[3L]]) %in% c("vector", "c") &&
      grepl("vector(\"list\"", ws4a_txt(a[[3L]]), fixed = TRUE), assigns), ws4a_txt, "")
    entries <- vapply(Filter(function(a) is.call(a[[2L]]) && ws4a_head(a[[2L]]) == "[[" &&
      is.call(a[[3L]]) && ws4a_head(a[[3L]]) == "list", assigns), ws4a_txt, "")
    recover <- vapply(Filter(function(x) ws4a_head(x) %in% c("lapply", "vapply", "sapply", "Map", "mapply") &&
      any(vapply(as.list(x)[-1L], function(y) identical(y, as.name("[[")) || identical(y, "[["), NA)),
      ws4a_calls(fns[[nm]])), ws4a_txt, "")
    h <- setdiff(c(alloc, entries, recover, ws4a_d9_iterated(fns[[nm]])), ws4a_d9_allowed)
    if (length(h)) paste0(nm, ": ", substr(h, 1L, 80L))
  }))
}
# The operation, whatever the names (WS13 close review F4): a list built by
# iteration. A list-returning apply call, an apply call whose inline function
# or FUN.VALUE builds a list, or a loop body that builds one. The routed
# metadata is the identified exception: a per-row record of exactly the
# routed fields, and the metadata parser over the routed JSON (WS7/WS8).
# Field-name loops build no list and pass.
ws4a_d9_meta_fields <- c("fee", "cash_delta", "position_delta", "realized_pnl")
ws4a_d9_iterated <- function(e) {
  inline <- function(x) Filter(function(y) is.call(y) && identical(y[[1L]], as.name("function")), as.list(x)[-1L])
  lists <- function(b) Filter(function(y) ws4a_head(y) == "list", ws4a_calls(b))
  routed <- function(l) identical(sort(names(l)[-1L]), sort(ws4a_d9_meta_fields))
  hits <- lapply(ws4a_calls(e), function(x) {
    h <- ws4a_head(x)
    if (h %in% c("for", "while", "repeat")) {
      body <- switch(h, `for` = x[[4L]], `while` = x[[3L]], x[[2L]])
      return(if (length(lists(body))) ws4a_txt(x))
    }
    if (!h %in% c("lapply", "vapply", "sapply", "Map", "mapply", "rapply", "Reduce", "split")) return(NULL)
    built <- unlist(lapply(inline(x), lists), recursive = FALSE)
    value <- if (h == "vapply") as.list(x)[-(1:3)] else list()
    built <- c(built, Filter(function(y) is.call(y) && ws4a_head(y) == "list", value))
    returns_list <- h %in% c("lapply", "Map", "mapply", "sapply", "rapply", "split")
    if (!returns_list && !length(built)) return(NULL)
    ws4a_txt(x)
  })
  unlist(hits)
}

testthat::test_that("[WS4a D9] publication stages no per-fill or per-leg list; the routed metadata is retained", {
  fns <- ws4a_sources()
  examined <- c("ledgr_output_handler", "ledgr_output_sink_memory", "ledgr_output_sink_duckdb",
    "ledgr_fill_event_payload", "ledgr_fill_leg_block")
  testthat::expect_length(ws4a_d9_hits(fns[examined]), 0L)
  # Typed accounting columns are atomic; no per-event metadata list remains.
  testthat::expect_false(any(vapply(ledgr:::ledgr_accounting_empty_columns(2L), is.list, FALSE)))
  # Injected economic staging fails: a staged per-fill list, a per-fill
  # entry write, a per-leg entry write and a column recovered from entries.
  hit <- function(nm, stmt) length(ws4a_d9_hits(ws4a_inject_into(fns, nm, stmt))) > 0L
  testthat::expect_true(hit("ledgr_output_handler", "pulse_fill_rows <- vector(\"list\", 256L)"))
  testthat::expect_true(hit("ledgr_output_handler", "pulse_fill_rows[[i]] <<- list(row = row, cash_delta = cash_delta)"))
  testthat::expect_true(hit("ledgr_output_sink_memory", "pulse_fill_legs[[i]] <<- list(qty = qty, fee = fee, action = action)"))
  testthat::expect_true(hit("ledgr_output_handler", "cash <- vapply(staged, `[[`, numeric(1), \"cash_delta\")"))
  # WS13 close review F4: economic lists built through iteration fail,
  # whatever their names; the routed metadata and field-name loops pass.
  testthat::expect_true(hit("ledgr_fill_event_payload",
    "staged <- lapply(seq_along(i), function(k) list(qty = fill$qty[[k]], fee = fill$fee[[k]]))"))
  testthat::expect_true(hit("ledgr_output_handler",
    "staged <- lapply(seq_len(nrow(rows)), function(k) list(qty = rows$qty[[k]], price = rows$price[[k]]))"))
  testthat::expect_true(hit("ledgr_fill_leg_block", "legs <- Map(function(q, f) list(qty = q, fee = f), block$qty, block$fee)"))
  testthat::expect_true(hit("ledgr_fill_event_payload",
    "staged <- vapply(seq_along(i), function(k) fill$qty[[k]], list(1))"))
  testthat::expect_true(hit("ledgr_fill_event_payload", "for (k in seq_along(i)) rows <- c(rows, list(list(qty = fill$qty[[k]])))"))
  testthat::expect_true(hit("ledgr_fill_event_payload", "staged <- lapply(seq_along(i), make_row)"))
  pass <- function(nm, stmt) length(ws4a_d9_hits(ws4a_inject_into(fns, nm, stmt))) == 0L
  testthat::expect_true(pass("ledgr_fill_event_payload", "for (name in names(fill)) out[[name]] <- fill[[name]][i]"))
  testthat::expect_true(pass("ledgr_fill_event_payload", "q <- vapply(seq_along(i), function(k) fill$qty[[k]] * 2, numeric(1))"))
  testthat::expect_true(hit("ledgr_fill_event_payload", paste("staged <- Map(function(fee, cash_delta, position_delta)",
    "list(fee = fee, cash_delta = cash_delta, position_delta = position_delta, realized_pnl = NULL), fee, cash_delta, position_delta)")))
  testthat::expect_true(hit("ledgr_output_handler", "staged <- lapply(seq_len(nrow(rows)), function(k) as.list(rows[k, ]))"))
})

# D3 for the LDG-3167 regions: P4, its candidate and the publication path,
# with the name-keyed predicate plus %in%. Census: the field-name loops over
# a block's own columns (names of fields, not instruments).
ws4a_d3_3167 <- c(
  "ledgr_write_fill_publication_row" = "publication[[name]]",
  "ledgr_write_fill_publication_row" = "names(values) <- columns",
  "ledgr_output_handler/stage_fill_block" = "pending_fills[[name]]",
  "ledgr_output_handler/stage_fill_block" = "block[[name]]",
  "ledgr_output_handler/handler$flush_pulse_events" = "block[[name]]",
  "ledgr_output_handler/handler$append_event_rows" = "rows[[name]]",
  "ledgr_output_sink_memory/sink$stage_legs" = "pending_legs[[name]]",
  "ledgr_output_sink_memory/sink$stage_legs" = "legs[[name]]"
)

testthat::test_that("[WS4a D3 3167] P4 and publication index instruments by position", {
  pub <- ws4a_publication(ws4a_sources())
  found <- function(e) {
    c(ws4a_name_keyed(e), vapply(Filter(function(x) ws4a_head(x) == "%in%", ws4a_calls(e)),
      function(x) substr(ws4a_txt(x), 1L, 70L), ""))
  }
  hits <- function(f) {
    unlist(lapply(names(f), function(nm) {
      h <- setdiff(unique(found(f[[nm]])), ws4a_d3_3167[names(ws4a_d3_3167) == nm])
      if (length(h)) paste0(nm, ": ", h)
    }))
  }
  testthat::expect_length(hits(pub), 0L)
  census <- unlist(lapply(unique(names(ws4a_d3_3167)), function(nm) paste(nm, unique(found(pub[[nm]])))))
  testthat::expect_setequal(census, paste(names(ws4a_d3_3167), ws4a_d3_3167))
  inject <- function(nm, stmt) hits(ws4a_inject_into(pub, nm, stmt))
  testthat::expect_gt(length(inject("ledgr_fold_stage_apply", "net <- candidate$book$net_by_inst[instrument_id]")), 0L)
  testthat::expect_gt(length(inject("ledgr_fill_leg_block", "row <- match(block$instrument_id, names(applied$close_qty))")), 0L)
  testthat::expect_gt(length(inject("ledgr_output_handler/handler$record_accounting_fact", "keep <- block$instrument_id %in% held_ids")), 0L)
})

# D6: JSON encodes and parses in the fold stages only at their routed sites,
# keyed by owning stage and call shape; P4 and its candidate have none.
ws4a_json_shapes <- function(e) {
  shape <- function(x) paste0(ws4a_head(x), "(", paste(vapply(as.list(x)[-1L], function(y) {
    if (is.call(y) && ws4a_head(y) == "list") paste0("list(", paste(names(y)[-1L], collapse = ","), ")") else ws4a_txt(y)
  }, ""), collapse = "; "), ")")
  vapply(Filter(function(x) {
    grepl("json|JSON", ws4a_head(x)) || identical(ws4a_head(x), "ledgr_strategy_state_encode")
  }, ws4a_calls(e)), shape, "")
}
ws4a_d6_routed <- c(
  ledgr_fold_stage_observe_settle = "ledgr_availability_detail_json(affected$details[[k]])",
  ledgr_fold_stage_decide = "canonical_json(list(intent_reason))",
  ledgr_fold_stage_decide = "canonical_json(list(risk_step))",
  ledgr_fold_stage_plan = "canonical_json(list(cash_before,virtual_final_cash,recorded_final_cash))",
  ledgr_fold_stage_commit = paste0("canonical_json(list(cash_before,virtual_final_cash,recorded_final_cash,intended_gross_exposure,",
    "post_risk_gross_exposure,actual_gross_exposure,exposure_basis))"),
  ledgr_fold_stage_commit = "ledgr_strategy_state_encode(next_state; services$strategy_state_declaration; context_ids)"
)
ws4a_d6_hits <- function(fns) {
  unlist(lapply(names(fns), function(nm) {
    s <- ws4a_json_shapes(fns[[nm]])
    u <- unique(s)
    n <- vapply(u, function(v) sum(s == v) - sum(ws4a_d6_routed[names(ws4a_d6_routed) == nm] == v), 0)
    if (any(n > 0)) paste0(nm, ": ", u[n > 0])
  }))
}

testthat::test_that("[WS4a D6] the fold stages encode JSON only at the routed sites; P4 encodes none", {
  fns <- ws4a_sources()
  stages <- c(paste0("ledgr_fold_stage_", c("observe_settle", "decide", "plan", "apply", "commit")), "ledgr_fold_fill_candidate")
  testthat::expect_length(ws4a_d6_hits(fns[stages]), 0L)
  testthat::expect_length(ws4a_json_shapes(fns$ledgr_fold_stage_apply), 0L)
  hit <- function(nm, stmt) length(ws4a_d6_hits(ws4a_inject_into(fns, nm, stmt))) > 0L
  testthat::expect_true(hit("ledgr_fold_stage_apply", "encoded <- canonical_json(list(fee = fill$fee))"))
  testthat::expect_true(hit("ledgr_fold_stage_plan", "canonical_json(list(intent_reason = x))"))
  testthat::expect_true(hit(
    "ledgr_fold_stage_commit",
    "ledgr_strategy_state_encode(state_update, services$strategy_state_declaration, context_ids)"
  ))
})

# The published blocks and legs of the dense fixture: its durable run
# (serialized metadata) and a memory sweep (legs, with the reversal's CLOSE
# and OPEN legs). The final pulse's unfillable change warns, as it should.
ws4a_3167_capture <- function() {
  ns <- ws4a_ns()
  seen <- new.env()
  seen$blocks <- list()
  seen$legs <- list()
  payload <- ns$ledgr_fill_event_payload
  leg <- ns$ledgr_fill_leg_block
  testthat::local_mocked_bindings(
    ledgr_fill_event_payload = function(...) {
      out <- payload(...)
      seen$blocks[[length(seen$blocks) + 1L]] <- out
      out
    },
    ledgr_fill_leg_block = function(...) {
      out <- leg(...)
      seen$legs[[length(seen$legs) + 1L]] <- out
      out
    },
    .package = "ledgr"
  )
  dense <- ws4a_3166_fixture(FALSE)
  on.exit(ledgr_snapshot_close(dense$snap), add = TRUE)
  suppressWarnings({
    close(ledgr_run(dense$exp(), params = dense$params, run_id = "ws4a-3167-dense", seed = 1L))
    ledgr_sweep(dense$exp(), ledgr_grid_named(c = list(strategy = dense$params)), seed = 1L)
  })
  as.list(seen)
}

testthat::test_that("[WS4a V-publication V-leg U-3167] published blocks and legs are typed and refuse the controls", {
  ns <- ws4a_ns()
  got <- ws4a_3167_capture()
  ok <- function(x, group) is.null(ns$ledgr_carrier_problem(x, group, NA_integer_))
  refuses <- function(x, group) {
    inherits(tryCatch(ns$ledgr_carrier_new(x, group, NA_integer_), error = identity), "ledgr_internal_error")
  }
  blocks <- Filter(function(b) identical(b$status, "WROTE"), got$blocks)
  testthat::expect_gt(length(blocks), 3L)
  testthat::expect_true(all(vapply(blocks, ok, NA, group = "publication")))
  testthat::expect_true(all(vapply(got$legs, ok, NA, group = "leg")))
  # Pulse one publishes both buys as one block. A direct typed lot operation
  # supplies the two-leg reversal validator fixture now that public fixed
  # baskets follow the canonical long-only target rule.
  b <- blocks[[1L]]
  testthat::expect_identical(b$side, c("BUY", "BUY"))
  testthat::expect_false(anyNA(b$cash_delta))
  testthat::expect_false(anyNA(b$position_delta))
  testthat::expect_true(all(is.na(b$source)))
  b1 <- lapply(b, function(x) x[1L])
  b1$side <- "SELL"
  b1$qty <- 2
  book <- ns$ledgr_lot_book(1L)
  book <- ns$ledgr_lot_fill(book, 1L, 1L, 1, b1$price, 0)$book
  applied <- ns$ledgr_lot_fill(book, 1L, -1L, 2, b1$price, b1$fee)$applied
  l <- ns$ledgr_fill_leg_block(b1, applied)
  testthat::expect_identical(l$action, c("CLOSE", "OPEN"))
  # Typed empty groups are accepted; the universal controls are refused:
  # storage type, a shortened column, a bound, an untyped empty column.
  empty <- lapply(b, function(v) v[0L])
  empty$status <- "NO_OP"
  empty$next_event_seq <- 4L
  testthat::expect_true(ok(empty, "publication"))
  empty_leg <- lapply(l, function(v) v[0L])
  testthat::expect_true(ok(empty_leg, "leg"))
  set <- function(x, field, value) {
    x[[field]] <- value
    x
  }
  testthat::expect_true(refuses(set(b, "event_seq", as.numeric(b$event_seq)), "publication"))
  testthat::expect_true(refuses(set(b, "qty", b$qty[-1L]), "publication"))
  testthat::expect_true(refuses(set(b, "fee", c(-1, b$fee[-1L])), "publication"))
  testthat::expect_true(refuses(set(empty, "event_id", list()), "publication"))
  testthat::expect_true(refuses(set(l, "qty", as.integer(ceiling(l$qty))), "leg"))
  testthat::expect_true(refuses(set(l, "price", l$price[-1L]), "leg"))
  testthat::expect_true(refuses(set(l, "qty", c(0, l$qty[-1L])), "leg"))
  testthat::expect_true(refuses(set(empty_leg, "fee", list()), "leg"))
  # Section 3.2 rows: F4.38 NA instrument on a FILL; F4.39 a gap in the fill
  # sequence; O3.08 a duplicate sequence; F4.40 forbidden fill evidence;
  # F4.41 OPEN before CLOSE; F4.42 an OPEN leg with P&L; and bad tokens.
  testthat::expect_true(refuses(set(b, "instrument_id", c(NA, b$instrument_id[-1L])), "publication"))
  testthat::expect_true(refuses(set(b, "event_seq", b$event_seq + c(0L, 1L)), "publication"))
  testthat::expect_true(refuses(set(b, "event_seq", rep(b$event_seq[[1L]], 2L)), "publication"))
  testthat::expect_true(refuses(set(b, "source", c("unexpected", b$source[-1L])), "publication"))
  testthat::expect_true(refuses(set(b, "source", b$source[1L]), "publication"))
  testthat::expect_true(refuses(set(b, "side", c("HOLD", "BUY")), "publication"))
  testthat::expect_true(refuses(set(b, "status", "NO_OP"), "publication"))
  testthat::expect_true(refuses(lapply(l, rev), "leg"))
  testthat::expect_true(refuses(set(l, "realized_pnl", l$realized_pnl + c(0, 1)), "leg"))
  testthat::expect_true(refuses(set(l, "action", c("CLOSE", "HOLD")), "leg"))
})

# C13b (Synthesis 3.5): a failure while the candidate is computed leaves the
# book, cash, positions, event_seq and the publication buffers exactly as
# they were at P4 entry, on durable, db_live and memory sinks. Pulse one's
# second row gets a NaN fee inside the batch's typed fill operation, a
# genuine second-row lot refusal.
ws4a_buffers <- function(handler) {
  h <- environment(handler$flush_pulse_events)
  s <- environment(Filter(is.function, h$sink)[[1L]])
  snapshot <- function(e) if (is.environment(e)) mget(sort(ls(e, all.names = TRUE)), e)
  list(count = h$state$event_count, cols = snapshot(h$state$event_cols), pending = h$pending_fills,
    legs = s$pending_legs, inline = snapshot(s$inline_fills),
    ledger = if (!is.null(s$con)) DBI::dbGetQuery(s$con, "SELECT COUNT(*) AS n FROM ledger_events")$n)
}
ws4a_c13b <- function(apply_impl = NULL, paths = c("durable", "live", "memory")) {
  ns <- ws4a_ns()
  seen <- new.env()
  seen$pairs <- list()
  lot_fill <- ns$ledgr_lot_fill
  apply <- apply_impl %||% ns$ledgr_fold_stage_apply
  # Deep copies: a by-reference buffer write would otherwise reach both.
  snap <- function(fs, services) {
    unserialize(serialize(list(book = fs$lot_state, cash = fs$cash, positions = fs$positions,
      event_seq = fs$event_seq, buffers = ws4a_buffers(services$output_handler)), NULL))
  }
  testthat::local_mocked_bindings(
    ledgr_lot_fill = function(book, pos, side, qty, price, fee = 0) {
      if (length(pos) >= 2L) fee[[2L]] <- NaN
      lot_fill(book, pos, side, qty, price, fee)
    },
    ledgr_fold_stage_apply = function(fold_state, services, ...) {
      before <- snap(fold_state, services)
      withCallingHandlers(apply(fold_state, services, ...), error = function(e) {
        seen$pairs[[length(seen$pairs) + 1L]] <- list(class = class(e)[[1L]], before = before,
          after = snap(fold_state, services))
      })
    },
    .package = "ledgr"
  )
  dense <- ws4a_3166_fixture(FALSE)
  on.exit(ledgr_snapshot_close(dense$snap), add = TRUE)
  out <- list()
  if ("durable" %in% paths) {
    out$durable <- tryCatch(ledgr_run(dense$exp(), params = dense$params, run_id = "c13b-durable", seed = 1L), error = identity)
  }
  if ("live" %in% paths) {
    out$live <- tryCatch(ledgr_run(dense$exp(execution_mode = "db_live"), params = dense$params, run_id = "c13b-live",
      seed = 1L), error = identity)
  }
  if ("memory" %in% paths) {
    out$memory <- ledgr_sweep(dense$exp(), ledgr_grid_named(c = list(strategy = dense$params)), seed = 1L)
  }
  c(out, list(pairs = seen$pairs))
}
ws4a_unchanged <- function(pair) {
  fields <- c("book", "cash", "positions", "event_seq", "buffers")
  identical(pair$before[fields], pair$after[fields])
}

testthat::test_that("[WS4a C13b] a candidate-calculation error leaves state and buffers unchanged", {
  got <- ws4a_c13b()
  testthat::expect_s3_class(got$durable, "ledgr_invalid_lot_fill")
  testthat::expect_s3_class(got$live, "ledgr_invalid_lot_fill")
  testthat::expect_identical(got$memory$status, "FAILED")
  testthat::expect_identical(got$memory$error_class[[1L]], "ledgr_invalid_lot_fill")
  testthat::expect_length(got$pairs, 3L)
  testthat::expect_identical(vapply(got$pairs, `[[`, "", "class"), rep("ledgr_invalid_lot_fill", 3L))
  testthat::expect_true(all(vapply(got$pairs, ws4a_unchanged, NA)))
  # Controls: installing or publishing row one before the candidate is
  # computed (the per-fill order) changes the snapshot.
  ns <- ws4a_ns()
  fns <- ws4a_sources()
  mutant <- function(stmt) eval(ws4a_inject(fns$ledgr_fold_stage_apply, stmt), ns)
  f <- "plan$batch$fill"
  installed <- mutant(sprintf(paste0("if (length(%1$s$k) > 1L) fold_state$lot_state <- ledgr_lot_fill(fold_state$lot_state,",
    " %1$s$pos[1L], %1$s$side[1L], %1$s$qty[1L], %1$s$price[1L], %1$s$fee[1L])$book"), f))
  published <- mutant(sprintf(paste0("if (length(%1$s$k) > 1L) services$output_handler$write_fill_events(%1$s, 1L,",
    " services$instrument_ids[%1$s$pos[1L]], fold_state$event_seq)"), f))
  for (impl in list(installed, published)) {
    bad <- ws4a_c13b(impl, paths = "memory")
    testthat::expect_identical(bad$memory$status, "FAILED")
    testthat::expect_false(all(vapply(bad$pairs, ws4a_unchanged, NA)))
  }
})

# Refusal order (Synthesis 3.5 keeps classes, messages and precedence): a
# batch refuses with its earliest failing fill, as one typed fill operation
# per fill did; a fill's publication refusal precedes a later fill's lot
# refusal. Unit cases compare with the per-fill sequence; public cases are
# the base 953338df outcomes of records/ldg3167/probe_multi.R.
testthat::test_that("[WS4a 3167 precedence] a batch refuses in the per-fill order with the base conditions", {
  ns <- ws4a_ns()
  book <- ns$ledgr_lot_book(3L)
  group <- function(qty, fee) list(k = 1:3, pos = 1:3, side = rep(1L, 3L), qty = qty, price = rep(10, 3L), fee = fee)
  condition <- function(e) c(class(e)[[1L]], conditionMessage(e))
  sequential <- function(f) {
    b <- book
    for (r in seq_along(f$pos)) {
      out <- tryCatch(ns$ledgr_lot_fill(b, f$pos[r], f$side[r], f$qty[r], f$price[r], f$fee[r]), error = identity)
      if (inherits(out, "error")) return(c(r, condition(out)))
      b <- out$book
    }
    "none"
  }
  batched <- function(f) {
    out <- ns$ledgr_fold_fill_candidate(book, f)
    if (is.null(out$failed)) "none" else c(out$failed, condition(out$error))
  }
  applied <- c("ledgr_lot_state_invariant", "Invalid applied lot rows.")
  input <- c("ledgr_invalid_lot_fill", "Invalid fill input for lot accounting.")
  # The 1e308 rows overflow the lot basis; cut 5 amendment_overflow refuses
  # them as invalid fill input (they were ledgr_lot_state_invariant).
  cases <- list(
    applied1_input2 = list(group(c(1e308, 1, 1), c(0, NaN, 0)), c(1, input)),
    input2_applied3 = list(group(c(1, 1, 1e308), c(0, NaN, 0)), c(2, input)),
    applied2_input3 = list(group(c(1, 1e308, 1), c(0, 0, Inf)), c(2, input)),
    input3 = list(group(c(1, 1, 1), c(0, 0, NaN)), c(3, input)),
    none = list(group(c(1, 2, 3), c(0, 0.5, 1)), "none")
  )
  for (name in names(cases)) {
    f <- cases[[name]][[1L]]
    testthat::expect_identical(batched(f), as.character(cases[[name]][[2L]]), info = name)
    testthat::expect_identical(batched(f), sequential(f), info = name)
  }
  # Control: the batch operation alone reports a later row's input refusal.
  plain <- tryCatch(ns$ledgr_lot_fill(book, 1:3, rep(1L, 3L), c(1e308, 1, 1), rep(10, 3L), c(0, NaN, 0)), error = identity)
  testthat::expect_false(identical(condition(plain), applied))

})

# Cut 5 amendment_overflow (maintainer, 2026-10-31): a fill whose lot
# accounting overflows to a non-finite value from finite inputs is refused at
# the fill as invalid fill input, on runs and sweeps and on both producers.
# The base accepted it (a durable run failed later at metadata encoding or
# completed, a sweep completed with infinite values). A corrupt book keeps
# the applied-row invariant.
testthat::test_that("[WS4a overflow refusal] a fill whose lot accounting overflows is refused as invalid fill input", {
  ns <- ws4a_ns()
  input <- c("ledgr_invalid_lot_fill", "Invalid fill input for lot accounting.")
  applied <- c("ledgr_lot_state_invariant", "Invalid applied lot rows.")
  through <- c("ledgr_lot_state_invariant", "Lot accounting cannot open through an unconsumed opposing lot.")
  condition <- function(expr) {
    e <- tryCatch({ force(expr); NULL }, error = identity)
    if (is.null(e)) "none" else c(class(e)[[1L]], conditionMessage(e))
  }
  # A two-instrument book whose first instrument holds the given lots. The
  # cached basis may differ from the lots (V-book checks it only on openings).
  lots <- function(qty, price, basis = sum(qty * price), realized = 0) {
    b <- ns$ledgr_lot_book(2L)
    n <- length(qty)
    b$capacity <- c(n, 0L); b$offset <- c(0L, n); b$tail <- c(n, 0L)
    b$lot_qty <- qty; b$lot_price <- price
    b$net_by_inst <- c(sum(qty), 0); b$cost_basis_by_inst <- c(basis, 0)
    b$total_cost_basis <- basis; b$realized_pnl <- realized
    b
  }
  # The rows and book the kernel computes with the refusal taken away: the
  # book reported corrupt and the applied-row check removed.
  unchecked <- function(b, ...) testthat::with_mocked_bindings(
    ledgr_lot_book_problem = function(...) "reported corrupt",
    ledgr_lot_applied = function(input, ...) list(...),
    ns$ledgr_lot_fill(b, ...),
    .package = "ledgr"
  )
  # Unit controls, one per overflowing field: each refuses, and without the
  # refusal the named field is non-finite while the fill inputs are finite.
  fields <- list(
    opened_basis = list(ns$ledgr_lot_book(2L), 1L, 1L, 1e308, 10, 0, function(o) o$book$cost_basis_by_inst[[1L]]),
    realized_close = list(lots(-1e308, 1), 1L, 1L, 1e308, 10, 0, function(o) o$applied$realized_close),
    closing_basis = list(lots(c(-1e300, -1e300), c(1e8, 1e8), basis = -1.7e308), 1L, 1L, 2e300, 1e8, 0,
      function(o) o$book$cost_basis_by_inst[[1L]]),
    position = list(lots(1e308, 1e-10), 1L, 1L, 1e308, 1e-10, 0, function(o) o$applied$position_after),
    realized_after_fee = list(lots(-1e308, 1), 1L, 1L, 1e308, 2, 1e308, function(o) o$applied$realized_delta),
    realized_total = list(lots(-1, 1, realized = -1.7e308), 1L, 1L, 1, 5e307, 0, function(o) o$applied$event_realized),
    basis_total = list(ns$ledgr_lot_book(2L), 1:2, c(1L, 1L), c(1e307, 1e307), c(10, 10), 0,
      function(o) o$applied$event_cost_basis[[2L]])
  )
  for (name in names(fields)) {
    a <- fields[[name]]
    testthat::expect_null(ns$ledgr_lot_book_problem(a[[1L]], reduction = FALSE), info = name)
    testthat::expect_identical(condition(ns$ledgr_lot_fill(a[[1L]], a[[2L]], a[[3L]], a[[4L]], a[[5L]], a[[6L]])),
      input, info = name)
    o <- unchecked(a[[1L]], a[[2L]], a[[3L]], a[[4L]], a[[5L]], a[[6L]])
    testthat::expect_false(is.finite(a[[7L]](o)), info = name)
  }
  # Only the field named fails in the row-level controls.
  o <- unchecked(lots(-1e308, 1), 1L, 1L, 1e308, 2, 1e308)
  testthat::expect_true(is.finite(o$applied$realized_close))
  o <- unchecked(lots(-1, 1, realized = -1.7e308), 1L, 1L, 1, 5e307)
  testthat::expect_true(is.finite(o$applied$realized_delta))
  o <- unchecked(ns$ledgr_lot_book(2L), 1:2, c(1L, 1L), c(1e307, 1e307), c(10, 10))
  testthat::expect_true(all(is.finite(o$book$cost_basis_by_inst)))
  # Control: a corrupt book keeps the applied-row invariant (a live lot
  # without a price; an infinite total), and a valid book reported corrupt
  # falls back to it too.
  corrupt <- lots(-1, NA_real_, basis = -1)
  testthat::expect_false(is.null(ns$ledgr_lot_book_problem(corrupt, reduction = FALSE)))
  testthat::expect_identical(condition(ns$ledgr_lot_fill(corrupt, 1L, 1L, 1, 10)), applied)
  infinite <- ns$ledgr_lot_book(2L)
  infinite$total_cost_basis <- Inf
  testthat::expect_identical(condition(ns$ledgr_lot_fill(infinite, 1L, 1L, 1, 10)), applied)
  testthat::with_mocked_bindings(
    ledgr_lot_book_problem = function(...) "reported corrupt",
    testthat::expect_identical(condition(ns$ledgr_lot_fill(ns$ledgr_lot_book(2L), 1L, 1L, 1e308, 10)), applied),
    .package = "ledgr"
  )

  # Precedence. A zero live lot passes V-book and refuses as an opening
  # through an opposing lot. Within a row a closing overflow comes before
  # that check and an opened-basis overflow after it; across rows the
  # earliest failing row refuses, in the kernel and in P4's candidate.
  zero <- lots(0, 1, basis = 0)
  testthat::expect_identical(condition(ns$ledgr_lot_fill(zero, 1L, 1L, 1e308, 10)), through)
  testthat::expect_identical(condition(ns$ledgr_lot_fill(lots(c(-1e308, 0), c(1, 1), basis = -1e308), 1L, 1L, 1.5e308, 10)),
    input)
  testthat::expect_identical(condition(ns$ledgr_lot_fill(zero, 1:2, c(1L, 1L), c(1, 1e308), c(10, 10))), through)
  testthat::expect_identical(condition(ns$ledgr_lot_fill(zero, 2:1, c(1L, 1L), c(1e308, 1), c(10, 10))), input)
  batch <- function(pos, qty, fee = c(0, 0)) {
    out <- ns$ledgr_fold_fill_candidate(zero, list(k = 1:2, pos = pos, side = c(1L, 1L), qty = qty, price = c(10, 10), fee = fee))
    c(out$failed, condition(stop(out$error)))
  }
  testthat::expect_identical(batch(1:2, c(1, 1e308)), c("1", through))
  testthat::expect_identical(batch(2:1, c(1e308, 1)), c("1", input))
  testthat::expect_identical(batch(c(2L, 1L), c(1, 1e308), c(NaN, 0)), c("1", input))
  testthat::expect_identical(batch(c(2L, 1L), c(1, 1), c(0, 0)), c("2", through))

})

# Public runs and sweeps for the WS13 close review's F1 and F2 (correction
# round 1): one instrument S, four daily pulses, no costs; "none" for a run
# that returns, the sweep's status, condition and final equity otherwise.
ws4a_public_ovf <- function(avail, price, opening, targets, compiled = FALSE) {
  pulses <- as.POSIXct("2024-01-01 16:00:00", tz = "UTC") + 86400 * 0:3
  bars <- data.frame(ts_utc = pulses, instrument_id = "S", open = price, high = price, low = price,
    close = price, volume = 1000, stringsAsFactors = FALSE)
  db <- tempfile(fileext = ".duckdb")
  snap <- if (avail) {
    sessions <- ledgr_facts_sessions(data.frame(session_date = as.Date(pulses), status = "open",
      session_open = "09:30:00", session_close = "16:00:00", knowledge_time = pulses - 86400,
      stringsAsFactors = FALSE), venue_id = "XNYS")
    ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = "S"),
      facts = ledgr_facts(sessions), price_basis = "split_adjusted", db_path = db)
  } else {
    ledgr_snapshot_from_df(bars, db_path = db)
  }
  on.exit(ledgr_snapshot_close(snap))
  exp <- ledgr_experiment(snap, function(ctx, params) {
    t <- ctx$hold()
    if (identical(substr(ctx$ts_utc, 1L, 10L), "2024-01-01")) t[names(params$t)] <- unlist(params$t)
    t
  }, cost_model = ledgr_cost_zero(), opening = opening)
  condition <- function(e) c(class(e)[[1L]], conditionMessage(e))
  run <- if (!compiled) {
    e <- tryCatch({
      close(suppressWarnings(ledgr_run(exp, params = list(t = targets), run_id = "ovf", seed = 1L)))
      NULL
    }, error = identity)
    if (is.null(e)) "none" else condition(e)
  }
  s <- suppressWarnings(ledgr_sweep(exp, ledgr_grid_named(c = list(strategy = list(t = targets))), seed = 1L,
    compiled_accounting_model = if (compiled) "spot_fifo" else NULL))
  sweep <- if (identical(s$status[[1L]], "DONE")) c("DONE", s$final_equity[[1L]]) else c(s$error_class[[1L]], s$error_msg[[1L]])
  list(run = run, sweep = sweep)
}

# Cut 5 amendment_valuation (maintainer, 2026-10-31; ws13_close_review.md F1):
# a non-finite run-order valuation of finite admitted holdings is carried by
# the decision packet, and the run reaches the base refusal point and
# condition. Base outcomes (953338df) are in the comments.
testthat::test_that("[WS4a valuation overflow] a non-finite valuation reaches the base refusal point", {
  ns <- ws4a_ns()
  non_finite <- c("ledgr_config_non_finite",
    "canonical_json() does not allow non-finite numeric values in config (Inf/-Inf/NaN).")
  invalid_effect <- c("ledgr_invalid_accounting_event",
    "Accounting event metadata must provide finite cash_delta and position_delta values.")
  input <- c("ledgr_invalid_lot_fill", "Invalid fill input for lot accounting.")
  long <- ledgr_opening(cash = 1000, positions = c(S = 1e308), cost_basis = c(S = 1))
  # Holding 1e308 marked at 10 (and at 1.9) values to Inf; the base and the
  # candidate both refuse at P5's reconciliation detail on the run and the
  # sweep. Before the amendment the packet refused as ledgr_internal_error.
  testthat::expect_identical(ws4a_public_ovf(TRUE, 10, long, list()), list(run = non_finite, sweep = non_finite))
  testthat::expect_identical(ws4a_public_ovf(TRUE, 1.9, long, list()), list(run = non_finite, sweep = non_finite))
  # Selling it at 1.9: the proceeds are infinite but the lot accounting is
  # finite. The run refuses at the fill's metadata (P4), the sweep at P5, as
  # on the base (P3's expected final cash carries the Inf).
  testthat::expect_identical(ws4a_public_ovf(TRUE, 1.9, long, list(S = 0)), list(run = invalid_effect, sweep = invalid_effect))
  # The review's case, selling it at 10: valued without refusal, the sale's
  # realized P&L (10 - 1) * 1e308 overflows, so amendment_overflow refuses the
  # fill (base: ledgr_config_non_finite later, at P4's metadata on the run
  # and at P5 on the sweep).
  testthat::expect_identical(ws4a_public_ovf(TRUE, 10, long, list(S = 0)), list(run = input, sweep = input))
  # A fixed basket now follows the same canonical valuation rule.
  testthat::expect_identical(ws4a_public_ovf(FALSE, 1.9, long, list()), list(run = non_finite, sweep = non_finite))
  # The derived valuation admits Inf and arithmetic NaN but never NA; the
  # primitive cash, positions and marks stay finite (F4.15 as amended).
  p <- ws4a_v201_groups()$decision_packet
  edit <- function(...) utils::modifyList(p$x, list(...))
  testthat::expect_null(ns$ledgr_carrier_problem(edit(positions_value = Inf), "decision_packet", p$n))
  testthat::expect_null(ns$ledgr_carrier_problem(edit(positions_value = NaN), "decision_packet", p$n))
  for (x in list(edit(positions_value = NA_real_), edit(cash = Inf), edit(position = replace(p$x$position, 1L, Inf)),
    edit(mark = replace(p$x$mark, which(p$x$priced)[[1L]], Inf)))) {
    testthat::expect_true(ws4a_refuses_group(x, "decision_packet", p$n))
  }
  # Control: the pre-amendment token refuses the derived Inf.
  fields <- ns$.ledgr_carrier_fields
  fields$decision_packet[["positions_value"]] <- "double:scalar:none"
  testthat::with_mocked_bindings(
    .ledgr_carrier_field_parts = lapply(fields, strsplit, split = ":", fixed = TRUE),
    testthat::expect_identical(ws4a_public_ovf(TRUE, 10, long, list())$sweep,
      c("ledgr_internal_error", "Invalid internal decision packet: `positions_value` contains a non-finite value.")),
    .package = "ledgr"
  )
})

# Cut 5 amendment_overflow on the compiled spot_fifo path (ws13_close_review.md
# F2): the C++ batch is unchanged; its R wrapper refuses a fill whose lot
# accounting overflows with the canonical condition at the earliest row, and
# installs and publishes nothing for the refused batch.
testthat::test_that("[WS4a compiled overflow] the compiled path refuses an overflowing fill as invalid fill input", {
  ns <- ws4a_ns()
  input <- c("ledgr_invalid_lot_fill", "Invalid fill input for lot accounting.")
  cash <- ledgr_opening(cash = 1000)
  negative <- ledgr_opening(cash = 1000, positions = c(S = 1e308), cost_basis = c(S = -1))
  appended <- 0L
  handler <- ns$ledgr_output_handler
  counted <- function(expr) testthat::with_mocked_bindings(
    ledgr_output_handler = function(sink, ...) {
      h <- handler(sink, ...)
      append <- h$append_compiled_spot_batch
      h$append_compiled_spot_batch <- function(batch) {
        appended <<- appended + 1L
        append(batch)
      }
      h
    },
    expr,
    .package = "ledgr"
  )
  # Ordinary compiled fills are appended and unchanged.
  testthat::expect_identical(counted(ws4a_public_ovf(FALSE, 10, cash, list(S = 5), compiled = TRUE))$sweep,
    c("DONE", "1000"))
  testthat::expect_gt(appended, 0L)
  # Earliest-row precedence at the wrapper: row 1 overflows its opened basis,
  # row 2 has an infinite fee, which the native batch refuses with its own
  # input message. Row 1 refuses first, as in the canonical candidate;
  # reversed, the native input refusal of row 1 keeps its condition.
  condition <- function(expr) {
    e <- tryCatch({ force(expr); NULL }, error = identity)
    if (is.null(e)) "none" else conditionMessage(e)
  }
  state <- list(cash = 1000, positions = c(0, 0), lot_state = ns$ledgr_lot_book(2L))
  fills <- function(qty, fee) list(k = 1:2, pos = 1:2, side = c(1L, 1L), qty = qty, price = c(10, 10), fee = fee,
    exec_ts = c(86400, 86400), cash_delta = -(qty * 10 + fee), position_delta = qty)
  wrapper <- function(f) condition(ns$ledgr_run_compiled_spot_fifo_batch("w", f, state, c("A", "B"), 1L))
  testthat::expect_identical(wrapper(fills(c(1e308, 1), c(0, Inf))), input[[2L]])
  testthat::expect_identical(ns$ledgr_fold_fill_candidate(state$lot_state, fills(c(1e308, 1), c(0, Inf)))$failed, 1L)
  testthat::expect_identical(wrapper(fills(c(1, 1e308), c(Inf, 0))), "`fill_fee` must be finite >= 0.")
  testthat::expect_identical(wrapper(fills(c(1, 1e308), c(0, 0))), input[[2L]])
  testthat::expect_identical(wrapper(fills(c(1, 2), c(0, 0))), "none")
  # Close re-review 1, N2: on suspicion an earlier canonical transition
  # refusal keeps its condition instead of being discarded.
  z <- ns$ledgr_lot_book(2L)
  z$capacity <- c(1L, 0L); z$offset <- c(0L, 1L); z$tail <- c(1L, 0L)
  z$lot_qty <- 0; z$lot_price <- 1
  testthat::expect_null(ns$ledgr_lot_book_problem(z, reduction = FALSE))
  state$lot_state <- z
  testthat::expect_error(
    ns$ledgr_run_compiled_spot_fifo_batch("w", fills(c(1, 1e308), c(0, 0)), state, c("A", "B"), 1L),
    "Lot accounting cannot open through an unconsumed opposing lot.",
    fixed = TRUE, class = "ledgr_lot_state_invariant"
  )
})

# U-3168 and U-3167 at construction (ws13_close_review.md F3): a diagnostic
# segment is validated where it enters production, and the empty publication
# block is validated like a written one.
testthat::test_that("[WS4a U-3168 U-3167 construction] staging segments and empty blocks are validated where built", {
  ns <- ws4a_ns()
  state <- ns$ledgr_fold_state_new(cash = 100, positions = 0, lot_state = ns$ledgr_lot_book(1L),
    pending_segments = ns$ledgr_fold_diagnostic_staging(4L))
  ns$ledgr_fold_staging_add(state, list(n = 1L, instrument_id = "A", reason_code = "ok"), 86400)
  testthat::expect_identical(state$pending_segments$n, 1L)
  bad <- list(
    na_reason = list(n = 1L, reason_code = NA_character_),
    na_decision_time = list(n = 1L, reason_code = "ok", decision_ts_utc = NA_real_),
    negative_mark_age = list(n = 1L, reason_code = "ok", mark_age = -1L)
  )
  for (name in names(bad)) {
    testthat::expect_error(ns$ledgr_fold_staging_add(state, bad[[name]], 86400), class = "ledgr_internal_error",
      info = name)
    testthat::expect_identical(state$pending_segments$n, 1L, info = name)
  }
  # A typed empty segment passes and stages nothing.
  ns$ledgr_fold_staging_add(state, list(n = 0L), 86400)
  testthat::expect_identical(state$pending_segments$n, 1L)
  # Control: the unvalidated row builder (the pre-correction final
  # expression) stages the NA reason code.
  raw <- ns$ledgr_fold_diagnostic_rows
  b <- body(raw)
  b[[length(b)]] <- quote(out)
  body(raw) <- b
  testthat::with_mocked_bindings(
    ledgr_fold_diagnostic_rows = raw,
    ns$ledgr_fold_staging_add(state, bad$na_reason, 86400),
    .package = "ledgr"
  )
  testthat::expect_identical(state$pending_segments$n, 2L)

  # The empty publication: an event sequence of 0 is the argument refusal
  # (before: a NO_OP block with next_event_seq 0, which the publication
  # validator refuses); a numeric sequence is normalized to an integer.
  testthat::expect_error(ns$ledgr_fill_event_payload("review", NULL, integer(), character(), 0L),
    "`event_seq` must be an integer >= 1.", fixed = TRUE, class = "ledgr_invalid_args")
  empty <- ns$ledgr_fill_event_payload("review", NULL, integer(), character(), 3)
  testthat::expect_identical(empty$status, "NO_OP")
  testthat::expect_identical(empty$next_event_seq, 3L)
  testthat::expect_null(ns$ledgr_carrier_problem(empty, "publication", NA_integer_))
  old <- utils::modifyList(empty, list(next_event_seq = 0L))
  testthat::expect_false(is.null(ns$ledgr_carrier_problem(old, "publication", NA_integer_)))
})

# W1: the observed application order. Probes, in time order: the canonical
# publication entry (1), the accounting-fact entry (2) and exit (3), and P4's
# exit (4). Each step is first seen done at its own probe: the candidate book
# at 1, the advanced sequence at 2, the legs at 3, positions and cash at 4.
# A durable run has no leg method (probes 1 and 4). At the compiled append
# entry the compiled lot state and next sequence are installed.
ws4a_w1_order <- c("candidate_book_installed", "sequence_advanced", "legs_recorded", "positions_cash_installed")
ws4a_w1 <- function(apply_impl = NULL) {
  ns <- ws4a_ns()
  w <- new.env()
  w$orders <- list()
  w$compiled <- list()
  apply <- apply_impl %||% ns$ledgr_fold_stage_apply
  candidate <- ns$ledgr_fold_fill_candidate
  handler <- ns$ledgr_output_handler
  probe <- function(k) {
    fs <- w$fs
    done <- c(candidate_book_installed = identical(fs$lot_state, w$cand$book),
      sequence_advanced = identical(fs$event_seq, w$seq0 + length(w$fill$k)),
      legs_recorded = isTRUE(w$legs), positions_cash_installed = !identical(fs$positions, w$pos0))
    new <- done & is.na(w$first)
    w$first[new] <- k
  }
  testthat::local_mocked_bindings(
    ledgr_fold_fill_candidate = function(...) {
      w$cand <- candidate(...)
      w$cand
    },
    ledgr_fold_stage_apply = function(fold_state, services, observation, plan, ...) {
      w$fs <- fold_state
      w$fill <- plan$batch$fill
      w$seq0 <- fold_state$event_seq
      w$pos0 <- fold_state$positions
      w$legs <- FALSE
      w$first <- stats::setNames(rep(NA_integer_, 4L), ws4a_w1_order)
      out <- apply(fold_state, services, observation, plan, ...)
      if (length(w$fill$k) > 0L && !services$use_compiled_spot_fifo) {
        probe(4L)
        w$orders[[length(w$orders) + 1L]] <- w$first
      }
      out
    },
    ledgr_output_handler = function(sink, ...) {
      h <- handler(sink, ...)
      write <- h$write_fill_events
      fact <- h$record_accounting_fact
      append <- h$append_compiled_spot_batch
      h$write_fill_events <- function(..., stage = TRUE) {
        if (isTRUE(stage)) probe(1L)
        write(..., stage = stage)
      }
      if (is.function(fact)) {
        h$record_accounting_fact <- function(block, applied) {
          probe(2L)
          out <- fact(block, applied)
          w$legs <- TRUE
          probe(3L)
          out
        }
      }
      if (is.function(append)) {
        h$append_compiled_spot_batch <- function(batch) {
          w$compiled[[length(w$compiled) + 1L]] <- c(compiled_lot_state_installed = identical(w$fs$lot_state, batch$lot_state),
            next_sequence_installed = identical(w$fs$event_seq, batch$next_event_seq))
          append(batch)
        }
      }
      h
    },
    .package = "ledgr"
  )
  dense <- ws4a_3166_fixture(FALSE)
  on.exit(ledgr_snapshot_close(dense$snap), add = TRUE)
  suppressWarnings({
    close(ledgr_run(dense$exp(), params = dense$params, run_id = "w1-durable", seed = 1L))
    ledgr_sweep(dense$exp(), ledgr_grid_named(c = list(strategy = dense$params)), seed = 1L)
    ledgr_sweep(dense$exp(), ledgr_grid_named(c = list(strategy = dense$params)), seed = 1L,
      compiled_accounting_model = "spot_fifo")
  })
  list(orders = w$orders, compiled = w$compiled)
}
ws4a_w1_ok <- function(first, legs = TRUE) {
  want <- if (legs) 1:4 else c(1L, NA, NA, 4L)
  want[[2L]] <- if (legs) 2L else 4L
  identical(unname(first), want)
}

testthat::test_that("[WS4a W1] P4 installs the book, publishes, advances, records legs, then installs positions and cash", {
  got <- ws4a_w1()
  legs <- vapply(got$orders, function(f) !is.na(f[["legs_recorded"]]), NA)
  testthat::expect_true(any(legs) && any(!legs))
  testthat::expect_true(all(mapply(ws4a_w1_ok, got$orders, legs)))
  testthat::expect_gt(length(got$compiled), 0L)
  testthat::expect_true(all(unlist(got$compiled)))
  # The comparator fails every swapped pair of the declared order.
  first <- stats::setNames(1:4, ws4a_w1_order)
  for (p in utils::combn(4L, 2L, simplify = FALSE)) {
    swapped <- first
    swapped[p] <- swapped[rev(p)]
    testthat::expect_false(ws4a_w1_ok(swapped))
  }
  # Production mutations: the sequence advanced before publication; positions
  # installed before the legs.
  ns <- ws4a_ns()
  mutant <- function(new) {
    f <- ns$ledgr_fold_stage_apply
    body(f) <- str2lang(sub("fold_state$lot_state <- candidate$book", paste("fold_state$lot_state <- candidate$book;", new),
      paste(deparse(body(f), width.cutoff = 500L), collapse = "\n"), fixed = TRUE))
    f
  }
  for (new in c("fold_state$event_seq <- fold_state$event_seq + length(rows)",
    "fold_state$positions[fill$pos] <- candidate$book$net_by_inst[fill$pos]")) {
    bad <- ws4a_w1(mutant(new))
    legs <- vapply(bad$orders, function(f) !is.na(f[["legs_recorded"]]), NA)
    testthat::expect_false(all(mapply(ws4a_w1_ok, bad$orders, legs)), info = new)
  }
})

# --- LDG-3168: diagnostics staging, equity record, stop results ------------

# Runs the 3166 fixture (availability or dense; durable run and memory sweep)
# and observes the fold's typed carrier at its boundaries: at every P1 call
# the staged rows on entry and the equity rows written; at every drain the
# staged rows, the rows handed to the writer (and how many are stopped
# rows), the rows left after and the staging's validity; every stop E
# applies, with the processed count it adds; every frozen equity prefix.
# `stop_at` perturbs the availability plan's expected cash on that pulse (a
# P3 affordability stop, as C8a). `mutate` replaces a carrier function by a
# mutant of the original.
ws4a_3168_capture <- function(avail, paths = c("run", "sweep"), stop_at = NA_integer_, mutate = list()) {
  ns <- ws4a_ns()
  seen <- new.env()
  for (f in c("p1", "drains", "stops", "prefixes")) seen[[f]] <- list()
  add <- function(field, x) seen[[field]][[length(seen[[field]]) + 1L]] <- x
  impl <- function(name) {
    original <- ns[[name]]
    if (is.null(mutate[[name]])) original else mutate[[name]](original)
  }
  plan <- ns$ledgr_fold_build_availability_pulse_plan
  observe <- impl("ledgr_fold_stage_observe_settle")
  flush <- impl("ledgr_fold_flush_pulse_block")
  apply_stop <- impl("ledgr_fold_apply_stop")
  prefix <- ns$ledgr_fold_equity_prefix
  pulse <- 0L
  testthat::local_mocked_bindings(
    ledgr_fold_build_availability_pulse_plan = function(...) {
      out <- plan(...)
      if (identical(pulse, stop_at)) out$expected_final_cash <- out$expected_final_cash + 1
      out
    },
    ledgr_fold_stage_observe_settle = function(fold_state, services, pulse_idx, ...) {
      pulse <<- pulse_idx
      staged <- fold_state$pending_segments$n
      rows <- fold_state$equity_facts$n
      out <- observe(fold_state, services, pulse_idx, ...)
      add("p1", list(staged = staged, written = fold_state$equity_facts$n - rows,
        stopped = ns$ledgr_is_fold_stop_result(out), services = names(services)))
      out
    },
    ledgr_fold_flush_pulse_block = function(fold_state, diagnostic_writer, ...) {
      staged <- fold_state$pending_segments$n
      sequence_before <- fold_state$diagnostic_seq
      problem <- ns$ledgr_carrier_problem(fold_state$pending_segments, "diagnostics", NA_integer_)
      handed <- c(rows = 0L, stopped = 0L)
      writer <- list(
        keep = diagnostic_writer$keep,
        append_block = function(block) {
          handed <<- c(rows = length(block$diagnostic_seq), stopped = sum(block$outcome %in% "stopped"))
          diagnostic_writer$append_block(block)
        }
      )
      flush(fold_state, writer, ...)
      add("drains", list(staged = staged, handed = handed, after = fold_state$pending_segments$n,
        advanced = fold_state$diagnostic_seq - sequence_before,
        capacity = fold_state$pending_segments$capacity, problem = problem))
    },
    ledgr_fold_apply_stop = function(fold_state, stop) {
      processed <- fold_state$processed
      apply_stop(fold_state, stop)
      add("stops", list(n = stop$diagnostics$n, problem = ns$ledgr_carrier_problem(stop, "stop", NA_integer_),
        counted = fold_state$processed - processed))
    },
    ledgr_fold_equity_prefix = function(record) {
      out <- prefix(record)
      add("prefixes", out)
      out
    },
    ledgr_fold_equity_append = impl("ledgr_fold_equity_append"),
    .package = "ledgr"
  )
  fx <- ws4a_3166_fixture(avail)
  on.exit(ledgr_snapshot_close(fx$snap), add = TRUE)
  out <- list()
  if ("run" %in% paths) {
    out$run <- tryCatch({
      close(suppressWarnings(ledgr_run(fx$exp(), params = fx$params, run_id = "ws4a-3168-run", seed = 1L)))
      "returned"
    }, error = identity)
  }
  if ("sweep" %in% paths) {
    out$sweep <- suppressWarnings(ledgr_sweep(fx$exp(), ledgr_grid_named(c = list(strategy = fx$params)), seed = 1L))
  }
  c(out, as.list(seen))
}

# D2 (runtime): every pulse starts with an empty staging; every drain hands
# the writer exactly its used rows and leaves none; capacity never changes.
ws4a_d2_runtime <- function(got) {
  staged <- vapply(got$p1, `[[`, 0L, "staged")
  c(sprintf("a pulse starts with %d staged rows", staged[staged != 0L]),
    unlist(lapply(got$drains, function(d) {
      if (d$handed[["rows"]] > d$staged || d$after != 0L || d$advanced != d$staged) {
        sprintf("a drain of %d rows hands %d, advances %d and keeps %d", d$staged, d$handed[["rows"]], d$advanced, d$after)
      }
    })),
    if (length(unique(vapply(got$drains, `[[`, 0L, "capacity"))) > 1L) "the staging capacity changed")
}
# D10 (runtime): P1 writes exactly one equity row on every valued pulse and
# none on a stop; no service slot holds equity; the frozen prefixes hold
# exactly the valued rows.
ws4a_d10_runtime <- function(got) {
  written <- vapply(got$p1, `[[`, 0L, "written")
  valued <- !vapply(got$p1, `[[`, NA, "stopped")
  c(if (!identical(written, as.integer(valued))) paste("P1 equity writes per call:", paste(written, collapse = ",")),
    if (any(grepl("equity", unlist(lapply(got$p1, `[[`, "services"))))) "a service slot holds equity",
    if (sum(vapply(got$prefixes, `[[`, 0L, "n")) != sum(valued)) "the frozen prefixes do not hold the valued rows")
}

testthat::test_that("[WS4a V-diagnostics V-equity V-stop U-3168] staging, equity and stop payloads are typed and refuse the controls", {
  ns <- ws4a_ns()
  got <- ws4a_3168_capture(TRUE, stop_at = 3L)
  # Production: every drained staging, stop payload and frozen prefix validates.
  testthat::expect_gt(length(got$drains), 4L)
  testthat::expect_true(all(vapply(got$drains, function(d) is.null(d$problem), NA)))
  testthat::expect_length(got$stops, 2L)
  testthat::expect_true(all(vapply(got$stops, function(s) is.null(s$problem) && s$n == 1L, NA)))
  testthat::expect_true(all(vapply(got$prefixes, function(p) is.null(ns$ledgr_carrier_problem(p, "equity", NA_integer_)), NA)))
  ok <- function(x, group) is.null(ns$ledgr_carrier_problem(x, group, NA_integer_))
  set <- function(x, field, value) {
    x[[field]] <- value
    x
  }
  # A staging with two used rows of capacity four, a two-row record of
  # capacity three, a stop carrying one row; and their typed empty forms.
  state <- ns$ledgr_fold_state_new(cash = 100, positions = 0, lot_state = ns$ledgr_lot_book(1L),
    pending_segments = ns$ledgr_fold_diagnostic_staging(4L), equity_facts = ns$ledgr_fold_equity_record(3L))
  ns$ledgr_fold_staging_add(state, list(n = 2L, instrument_id = c("A", "B"), stage = "decision", outcome = "recorded",
    reason_code = "decision_recorded", quantity = c(1, 2), mark_age = c(0L, NA)), 86400)
  staging <- state$pending_segments
  equity <- ns$ledgr_fold_equity_append(ns$ledgr_fold_equity_record(3L), 1, 100, 5, 0, 4)
  equity <- ns$ledgr_fold_equity_append(equity, 2, 101, 6, 0, 4)
  stop <- ns$ledgr_fold_stop_result("INCOMPLETE", "risk_mark_unavailable", "A", list(value = 1),
    ns$ledgr_fold_diagnostic_rows(list(n = 1L, instrument_id = "A", stage = "risk", outcome = "stopped",
      reason_code = "risk_mark_unavailable"), 86400), TRUE)
  testthat::expect_identical(staging$n, 2L)
  testthat::expect_identical(staging$reasons[1:2], c("decision_recorded", "decision_recorded"))
  testthat::expect_identical(staging$decision_ts_utc[1:2], c(86400, 86400))
  for (x in list(list(staging, "diagnostics"), list(equity, "equity"), list(stop, "stop"),
    list(ns$ledgr_fold_diagnostic_staging(0L), "diagnostics"), list(ns$ledgr_fold_equity_record(0L), "equity"),
    list(ns$ledgr_fold_stop_result("INCOMPLETE", "x"), "stop"))) {
    testthat::expect_true(ok(x[[1L]], x[[2L]]))
  }
  # The four universal controls per group: storage type, a shortened column,
  # a bound, an untyped empty column.
  empty_staging <- ns$ledgr_fold_diagnostic_staging(0L)
  empty_equity <- ns$ledgr_fold_equity_record(0L)
  refused <- list(
    diagnostics_storage = list(set(staging, "mark_age", as.numeric(staging$mark_age)), "diagnostics"),
    diagnostics_shortened = list(set(staging, "stage", staging$stage[-1L]), "diagnostics"),
    diagnostics_bound = list(set(staging, "n", 5L), "diagnostics"),
    diagnostics_untyped_empty = list(set(empty_staging, "reasons", list()), "diagnostics"),
    equity_storage = list(set(equity, "ts", as.integer(equity$ts)), "equity"),
    equity_shortened = list(set(equity, "cash", equity$cash[-1L]), "equity"),
    equity_bound = list(set(equity, "n", 4L), "equity"),
    equity_untyped_empty = list(set(empty_equity, "cost_basis", list()), "equity"),
    stop_storage = list(set(stop, "counts_processed", 1L), "stop"),
    stop_shortened = list(set(stop, "status", c("INCOMPLETE", "INCOMPLETE")), "stop"),
    stop_bound = list(set(stop, "diagnostics", set(stop$diagnostics, "n", 0L)), "stop"),
    stop_untyped_empty = list(set(stop, "affected_instrument_ids", list()), "stop"),
    # Section 3.2: F4.43 an NA reason code; F4.45 an NA decision time; F4.48
    # n beyond capacity; out-of-order valued pulses; a negative mark age.
    f4_43_na_reason = list(set(staging, "reason_code", replace(staging$reason_code, 2L, NA)), "diagnostics"),
    f4_45_na_decision_time = list(set(staging, "decision_ts_utc", replace(staging$decision_ts_utc, 1L, NA)), "diagnostics"),
    f4_48_beyond_capacity = list(set(equity, "n", 9L), "equity"),
    equity_order = list(set(equity, "ts", c(2, 1, 0)), "equity"),
    negative_age = list(set(staging, "mark_age", replace(staging$mark_age, 1L, -1L)), "diagnostics")
  )
  for (name in names(refused)) {
    testthat::expect_false(ok(refused[[name]][[1L]], refused[[name]][[2L]]), info = name)
  }
  # Only the used prefix is checked: an NA reason code in an unused row passes.
  testthat::expect_true(ok(set(staging, "reason_code", replace(staging$reason_code, 3L, NA)), "diagnostics"))
  # V-stop refuses at construction (F4.49: a non-logical counts_processed).
  testthat::expect_error(ns$ledgr_fold_stop_result("INCOMPLETE", "x", counts_processed = 1L), class = "ledgr_internal_error")
  # The E and stop validator refuses a wrong-length diagnostic staging column
  # and a wrong-type equity column (acceptance 3).
  testthat::expect_no_error(ns$ledgr_fold_state_validate(state))
  state$pending_segments <- refused$diagnostics_shortened[[1L]]
  testthat::expect_error(ns$ledgr_fold_state_validate(state), "pending diagnostics", class = "ledgr_internal_error")
  state$pending_segments <- staging
  state$equity_facts <- refused$equity_storage[[1L]]
  testthat::expect_error(ns$ledgr_fold_state_validate(state), "equity record", class = "ledgr_internal_error")
  state$equity_facts <- equity
  # The pinned capacity (design note 2.4), its overflow refusal and the
  # existing segment-length refusal.
  testthat::expect_identical(ns$ledgr_fold_diagnostic_capacity(4L, NULL), 28L)
  plan <- list(state = list(disposition_due_by_pulse = list(`2` = 1:9, `5` = 1:40)))
  testthat::expect_identical(ns$ledgr_fold_diagnostic_capacity(4L, plan), 40L)
  testthat::expect_error(
    ns$ledgr_fold_staging_add(state, list(n = 3L, stage = "risk"), 86400),
    "exceeded its capacity", class = "ledgr_invalid_fold_execution"
  )
  testthat::expect_error(
    ns$ledgr_fold_diagnostic_rows(list(n = 2L, stage = c("a", "b", "c")), 0),
    "Diagnostic block field `stage` has length 3 for a segment of 2 rows.", fixed = TRUE,
    class = "ledgr_invalid_fold_execution"
  )
})

# D2 (static): no list-segment staging in the stages, E, the skip helpers
# and the staging functions: no list append (`x[[length(x) + 1L]] <-`), no
# `c(x, list(...))` growth, no staging slot reset to a list. The bounded
# writer and the memory sink's filtered retained chunks are accepted.
ws4a_d2_examined <- c(paste0("ledgr_fold_stage_", c("observe_settle", "decide", "plan", "apply", "commit")),
  "ledgr_fold_envelope", "ledgr_fold_scheduled_skip_decision", "ledgr_fold_scheduled_skip_plan",
  "ledgr_fold_staging_add", "ledgr_fold_staging_write", "ledgr_fold_diagnostic_rows",
  "ledgr_fold_diagnostic_block", "ledgr_fold_flush_pulse_block", "ledgr_fold_apply_stop",
  "ledgr_columnar_diagnostic_writer", "ledgr_output_handler", "ledgr_output_sink_memory")
# A `list(...)` call with an unnamed element: a list of segments or rows,
# not a record of named fields.
ws4a_unnamed_list <- function(e) {
  any(vapply(Filter(function(x) ws4a_head(x) == "list", ws4a_calls(e)), function(x) {
    length(x) > 1L && (is.null(names(x)) || any(!nzchar(names(x)[-1L])))
  }, NA))
}
ws4a_d2_hits <- function(fns) {
  unlist(lapply(names(fns), function(nm) {
    h <- vapply(Filter(function(a) {
      lhs <- a[[2L]]
      rhs <- a[[3L]]
      (is.call(lhs) && ws4a_head(lhs) == "[[" && length(lhs) >= 3L && "length" %in% all.names(lhs[[3L]])) ||
        (is.call(rhs) && ws4a_head(rhs) %in% c("c", "append") && ws4a_unnamed_list(rhs)) ||
        (grepl("pending_segments", ws4a_txt(lhs), fixed = TRUE) && is.call(rhs) && ws4a_head(rhs) == "list")
    }, ws4a_assigns(fns[[nm]])), ws4a_txt, "")
    if (length(h)) paste0(nm, ": ", substr(h, 1L, 80L))
  }))
}

testthat::test_that("[WS4a D2] the pulse staging is typed, drained whole and never retained across pulses", {
  fns <- ws4a_sources()
  testthat::expect_true(all(ws4a_d2_examined %in% names(fns)))
  testthat::expect_length(ws4a_d2_hits(fns[ws4a_d2_examined]), 0L)
  # The retired list-of-segments block builder is gone.
  testthat::expect_false("ledgr_availability_diagnostic_block" %in% names(fns))
  hit <- function(nm, stmt) length(ws4a_d2_hits(ws4a_inject_into(fns, nm, stmt))) > 0L
  testthat::expect_true(hit("ledgr_fold_stage_observe_settle",
    "fold_state$pending_segments[[length(fold_state$pending_segments) + 1L]] <- segment"))
  testthat::expect_true(hit("ledgr_fold_stage_plan", "segments[[length(segments) + 1L]] <<- segment"))
  testthat::expect_true(hit("ledgr_fold_envelope", "fold_state$pending_segments <- list()"))
  testthat::expect_true(hit("ledgr_fold_staging_write", "pending <- c(pending, list(rows))"))
  # Runtime, both producers, durable run and memory sweep.
  for (avail in c(TRUE, FALSE)) {
    got <- ws4a_3168_capture(avail, stop_at = if (avail) 3L else NA_integer_)
    testthat::expect_gt(length(got$drains), 0L)
    testthat::expect_length(ws4a_d2_runtime(got), 0L)
  }
  # Controls: a drain that keeps a row for the next pulse, and one that hands
  # out the unused capacity, each fail the runtime predicate.
  retain <- function(original) function(fold_state, ...) {
    kept <- fold_state$pending_segments$n
    original(fold_state, ...)
    fold_state$pending_segments$n <- min(1L, kept)
  }
  whole <- function(original) function(fold_state, ...) {
    if (fold_state$pending_segments$n > 0L) fold_state$pending_segments$n <- fold_state$pending_segments$capacity
    original(fold_state, ...)
  }
  for (mutant in list(retain, whole)) {
    got <- ws4a_3168_capture(TRUE, paths = "sweep", mutate = list(ledgr_fold_flush_pulse_block = mutant))
    testthat::expect_gt(length(ws4a_d2_runtime(got)), 0L)
  }
})

# D10 (static): one equity writer site, P1's write of the fold-owned record;
# no accumulator, sink equity method or sink-held equity buffer.
ws4a_d10_examined <- c(paste0("ledgr_fold_stage_", c("observe_settle", "decide", "plan", "apply", "commit")),
  "ledgr_fold_envelope", "ledgr_output_handler", "ledgr_output_sink_memory", "ledgr_output_sink_duckdb")
ws4a_d10_hits <- function(fns, all = NULL) {
  targets <- lapply(fns, function(e) vapply(ws4a_assigns(e), function(a) ws4a_txt(a[[2L]]), ""))
  writers <- unlist(Map(function(nm, t) rep(nm, sum(startsWith(t, "fold_state$equity_facts"))), names(fns), targets))
  c(if (!identical(unname(writers), "ledgr_fold_stage_observe_settle")) paste("equity writers:", paste(writers, collapse = ", ")),
    unlist(lapply(names(fns), function(nm) {
      h <- c(intersect(all.names(fns[[nm]]), c("equity_fact_accumulator", "record_equity_fact")),
        grep("^equity(\\$| *$)", targets[[nm]], value = TRUE))
      if (length(h)) paste0(nm, ": ", h)
    })),
    ws4a_d10_storage_hits(fns, all))
}
# The operation, whatever the names (WS13 close review F4). Storage: every
# column allocation (a typed vector, list vector or environment, outside a
# vapply template) and every self-growth (`x <- c(x, ...)`) that the sinks or
# the handler hold is one of the census below; extra storage, such as a
# sink-held equity record, fails under any name. Ownership: across the whole
# package, only P1 appends to the fold's equity record and only E (and the
# routed terminal recovery, WS7) allocate one.
ws4a_d10_storage <- c(
  ledgr_output_handler = "state", ledgr_output_handler = "cols",
  ledgr_output_handler = "cols$qty", ledgr_output_handler = "pending_fills[[name]]",
  ledgr_output_sink_memory = "diagnostic_parts",
  ledgr_output_sink_memory = "pending_legs[[name]]",
  ledgr_output_sink_duckdb = "state", ledgr_output_sink_duckdb = "state$state_ts",
  ledgr_output_sink_duckdb = "state$state_json",
  ledgr_output_sink_duckdb = "grown_ts", ledgr_output_sink_duckdb = "grown_json"
)
ws4a_d10_storage_targets <- function(e) {
  strip <- function(x) {
    if (!is.call(x)) return(x)
    h <- ws4a_head(x)
    if (h == "function") return(NULL)
    if (h == "vapply") x <- x[seq_len(min(length(x), 3L))]
    as.call(lapply(as.list(x), strip))
  }
  alloc <- c("numeric", "double", "integer", "character", "logical", "vector", "new.env", "matrix", "array")
  held <- Filter(function(a) {
    rhs <- a[[3L]]
    if (is.call(rhs) && ws4a_head(rhs) == "function") return(FALSE)
    grow <- is.call(rhs) && ws4a_head(rhs) %in% c("c", "append") && length(rhs) > 1L &&
      identical(ws4a_txt(rhs[[2L]]), ws4a_txt(a[[2L]]))
    grow || length(intersect(ws4a_heads(strip(rhs)), alloc)) > 0L
  }, ws4a_assigns(e))
  unique(vapply(held, function(a) ws4a_txt(a[[2L]]), ""))
}
ws4a_d10_storage_hits <- function(fns, all = NULL) {
  if (is.null(all)) all <- ws4a_sources()
  sinks <- intersect(names(fns), unique(names(ws4a_d10_storage)))
  extra <- unlist(lapply(sinks, function(nm) {
    h <- setdiff(ws4a_d10_storage_targets(fns[[nm]]), ws4a_d10_storage[names(ws4a_d10_storage) == nm])
    if (length(h)) paste0(nm, ": holds ", h)
  }))
  all[names(fns)] <- fns
  callers <- function(f) names(Filter(function(e) f %in% ws4a_heads(e), all))
  c(extra,
    if (!identical(callers("ledgr_fold_equity_append"), "ledgr_fold_stage_observe_settle")) {
      paste("equity appenders:", paste(callers("ledgr_fold_equity_append"), collapse = ", "))
    },
    if (!all(callers("ledgr_fold_equity_record") %in% c("ledgr_fold_envelope", "ledgr_run_terminal_recovery_equity"))) {
      paste("equity record owners:", paste(callers("ledgr_fold_equity_record"), collapse = ", "))
    })
}

testthat::test_that("[WS4a D10] P1 writes one fold-owned equity row per valued pulse on both producers", {
  src <- ws4a_sources()
  fns <- src[ws4a_d10_examined]
  testthat::expect_length(ws4a_d10_hits(fns, all = src), 0L)
  inject <- function(nm, stmt) {
    candidate <- fns
    candidate[[nm]] <- ws4a_inject(candidate[[nm]], stmt)
    length(ws4a_d10_hits(candidate, all = src)) > 0L
  }
  testthat::expect_true(inject("ledgr_fold_stage_observe_settle", "services$equity_fact_accumulator$append(x)"))
  testthat::expect_true(inject("ledgr_output_sink_memory", "equity <- new.env(parent = emptyenv())"))
  testthat::expect_true(inject("ledgr_fold_stage_commit",
    "fold_state$equity_facts <- ledgr_fold_equity_append(fold_state$equity_facts, ts, 0, 0, 0, 0)"))
  # WS13 close review F4: extra equity storage and writer ownership fail
  # whatever their names; a sink-held record (the review's exact control),
  # renamed, grown by c(), or a second appender or record owner elsewhere.
  testthat::expect_true(inject("ledgr_output_sink_memory",
    "sink$equity <- list(n = 0L, ts = numeric(1024L), cash = numeric(1024L))"))
  testthat::expect_true(inject("ledgr_output_sink_memory", "sink$vals <- list(n = 0L, a = numeric(1024L))"))
  testthat::expect_true(inject("ledgr_output_handler", "kept <<- c(kept, fold_cash)"))
  testthat::expect_true(inject("ledgr_output_sink_duckdb", "series <- new.env(parent = emptyenv())"))
  other <- function(nm, stmt) {
    src[[nm]] <- ws4a_inject(src[[nm]], stmt)
    length(ws4a_d10_hits(fns, all = src)) > 0L
  }
  testthat::expect_true(other("ledgr_run_finalize",
    "rec <- ledgr_fold_equity_append(rec, 1, 0, 0, 0, 0)"))
  testthat::expect_true(other("ledgr_sweep_candidate_execution", "rec <- ledgr_fold_equity_record(10L)"))
  # Passing controls: a local temporary that is not held, a vapply template,
  # and the census's own event column.
  testthat::expect_false(inject("ledgr_output_handler", "x <- vapply(meta, length, integer(1))"))
  testthat::expect_false(inject("ledgr_output_handler", "cols$qty <- numeric(capacity)"))
  testthat::expect_false(inject("ledgr_output_sink_memory", "rows <- nrow(block)"))
  # Runtime: availability (with a stop) and dense, durable run and sweep.
  for (avail in c(TRUE, FALSE)) {
    got <- ws4a_3168_capture(avail, stop_at = if (avail) 3L else NA_integer_)
    testthat::expect_length(ws4a_d10_runtime(got), 0L)
    testthat::expect_true(all(vapply(got$prefixes, `[[`, 0L, "n") > 0L))
  }
  # Controls: a duplicate and a missing writer fail the runtime predicate.
  twice <- function(original) function(record, ...) original(original(record, ...), ...)
  never <- function(original) function(record, ...) record
  for (mutant in list(twice, never)) {
    got <- ws4a_3168_capture(FALSE, paths = "sweep", mutate = list(ledgr_fold_equity_append = mutant))
    testthat::expect_gt(length(ws4a_d10_runtime(got)), 0L)
  }
})

testthat::test_that("[WS4a F4.49 O3.78] E applies each stop result once; its rows and count are installed once", {
  callers <- names(Filter(function(e) "ledgr_fold_apply_stop" %in% ws4a_heads(e), ws4a_sources()))
  testthat::expect_identical(callers, "ledgr_fold_envelope")
  # The application counter: per stopped fold one application, whose
  # stopped rows reach the writer once and whose pulse counts once.
  counter <- function(got) {
    c(applications = length(got$stops),
      stopped_rows = sum(vapply(got$drains, function(d) d$handed[["stopped"]], 0L)),
      counted = sum(vapply(got$stops, `[[`, 0L, "counted")))
  }
  got <- ws4a_3168_capture(TRUE, stop_at = 3L)
  testthat::expect_identical(got$run, "returned")
  testthat::expect_identical(counter(got), c(applications = 2L, stopped_rows = 2L, counted = 2L))
  # Control: E invoking the stop application twice.
  twice <- function(original) function(fold_state, stop) {
    original(fold_state, stop)
    original(fold_state, stop)
  }
  bad <- ws4a_3168_capture(TRUE, stop_at = 3L, mutate = list(ledgr_fold_apply_stop = twice))
  testthat::expect_identical(counter(bad), c(applications = 2L, stopped_rows = 4L, counted = 4L))
  # A full run applies none.
  testthat::expect_length(ws4a_3168_capture(FALSE, paths = "sweep")$stops, 0L)
})

# Close re-review 1, N1: the P3 expected-cash domain is finite, NA or +Inf.
testthat::test_that("[WS4a expected cash domain] only finite, NA and positive infinity pass", {
  p <- ws4a_3166_plan()
  for (v in list(NA_real_, Inf, -1, 0, 1, NaN, -Inf)) {
    p$expected_final_cash <- v
    testthat::expect_identical(ws4a_refuses_plan(p), is.nan(v) || identical(v, -Inf))
  }
})
