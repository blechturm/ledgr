# ledgr-test-file-profile: review
#
# WS4a typed fold carrier: the LDG-3164 and LDG-3165 detectors and
# validators (inst/design/ledgr_v0_2_3_spec_packet/ws4a_carrier_design.md
# Section 6 and Section 3.2, rows owned by those tickets). Each predicate
# runs on production code and must pass there; each also shows its own
# compliant control passing and its own violating control failing.

ws4a_ns <- function() asNamespace("ledgr")

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
  # Replay import: ledger rows onto the replay axis; metadata fields by name.
  ledgr_prepare_accounting_events = "value[[name]]",
  ledgr_prepare_accounting_events = "intersect(names(meta[[i]]), c(\"subtype\", \"equity_subtype\", \"vendor_sub",
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
  ledgr_run_terminal_recovery_equity = "stats::setNames(rep(0, length(instrument_ids)), instrument_ids)",
  ledgr_run_terminal_recovery_equity = "intersect(names(state$positions), instrument_ids)",
  # Walk-forward: as-of book and carried lots to the next window's opening.
  ledgr_walk_forward_opening_from_run = "names(held) <- positions$instrument_id",
  ledgr_walk_forward_opening_from_run = "match(names(held), exp$universe)",
  ledgr_walk_forward_opening_from_run = "names(cost_basis) <- names(held)",
  ledgr_walk_forward_carried_opening = "match(ids, axis)",
  ledgr_walk_forward_carried_opening = "held[ids]",
  ledgr_walk_forward_carried_opening = "stats::setNames(basis, ids)",
  # Handler accounting fact: the close/open leg fee pair, not an instrument axis.
  ledgr_output_handler = "leg_fees[[\"close\"]]",
  ledgr_output_handler = "leg_fees[[\"open\"]]"
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
  ledgr_carrier_settlement_install = "fold_state$positions <- as.numeric(positions)"
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
  testthat::expect_identical(exports(ns_lines), frozen[["D12c"]])
  testthat::expect_identical(default_model(ledgr_run), frozen[["D12e"]])
  changed <- desc
  changed[, "Imports"] <- paste0(changed[, "Imports"], ", newpkg")
  testthat::expect_false(identical(deps(changed), frozen[["D12b"]]))
  testthat::expect_false(identical(exports(c(ns_lines, "export(ledgr_new)")), frozen[["D12c"]]))
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
  testthat::expect_identical(c1_hash(config_json), c1[["config_hash:character"]])
  edited <- sub('"initial_cash":100000.0', '"initial_cash":100001.0', config_json, fixed = TRUE)
  testthat::expect_false(identical(c1_hash(edited), c1[["config_hash:character"]]))

  # D12a production predicate: a run built now by the production configuration
  # constructor and run store binds the runs table as C1's base record does
  # (A0's wall-clock and version exclusions aside), records C1's configuration
  # fields to two levels (strategy parameters are the run's own), and stores
  # config_hash() of its stored configuration. Control: one added field.
  db <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(ledgr_test_compact_bars(), db_path = db)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(snapshot, function(ctx, params) ctx$hold(), cost_model = ledgr_cost_zero())
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
  testthat::expect_identical(fields(stored), fields(read(gsub("\\\\", "\\", config_json, fixed = TRUE))))
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
  rows <- data.frame(
    event_id = "o1", run_id = "r", ts_utc = as.POSIXct("2020-01-02", tz = "UTC"),
    event_type = "CASHFLOW", instrument_id = "AAA", side = NA_character_, qty = NA_real_,
    price = NA_real_, fee = NA_real_, event_seq = 1L, stringsAsFactors = FALSE,
    meta_json = as.character(canonical_json(list(
      source = "opening_position", cash_delta = 0, position_delta = 3, cost_basis = 12
    )))
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
  ev <- list(
    event_id = c("e1", "e2"), run_id = c("r", "r"),
    ts_utc = as.POSIXct(c("2020-01-02 21:00:00", "2020-01-03 21:00:00"), tz = "UTC"),
    event_type = c("FILL", "FILL"), instrument_id = c("A", "A"), side = c("BUY", "SELL"),
    qty = c(2, 1), price = c(10, 12), fee = c(1, 1), meta_json = c(NA_character_, NA_character_),
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
  kernel <- fns[c(intersect(ws4a_kernel_names, names(fns)), "ledgr_lot_apply_blocks")]
  testthat::expect_length(ws4a_hits(kernel, check), 0L)
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
  ev <- list(
    event_id = paste0("e", 1:4), run_id = rep("r", 4),
    ts_utc = as.POSIXct("2020-01-02 21:00:00", tz = "UTC") + c(0, 0, 0, 86400),
    event_type = rep("FILL", 4), instrument_id = c("A", "B", "C", "A"), side = c("BUY", "BUY", "SELL", "SELL"),
    qty = c(2, 1, 3, 1), price = c(10, 12, 9, 11), fee = c(1, 0, 0.5, 0), meta_json = rep(NA_character_, 4),
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
  meta <- function(...) as.character(canonical_json(list(...)))
  ev <- data.frame(
    event_id = paste0("e", 1:9), run_id = "r",
    ts_utc = ts + c(0, 0, 0, 0, 86400, 86400, 86400, 172800, 172800),
    event_type = c("CASHFLOW", "CASHFLOW", "CASHFLOW", "CASHFLOW", "FILL", "FILL", "CASHFLOW", "FILL", "FILL"),
    instrument_id = c("A", "A", "B", "C", "A", "B", "A", "B", "C"),
    side = c(NA, NA, NA, NA, "SELL", "SELL", NA, "BUY", "BUY"),
    qty = c(NA, NA, NA, NA, 2.5, 1.25, NA, 3, 0.75),
    price = c(NA, NA, NA, NA, 11.37, 20.11, NA, 19.5, 33.3),
    fee = c(NA, NA, NA, NA, 0.4, 0.2, NA, 0, 0.1),
    meta_json = c(
      meta(source = "opening_position", cash_delta = 0, position_delta = 1.5, cost_basis = 10.25),
      meta(source = "opening_position", cash_delta = 0, position_delta = 1.75, cost_basis = 10.5),
      meta(source = "opening_position", cash_delta = 0, position_delta = 0.5, cost_basis = 21),
      meta(source = "opening_position", cash_delta = 0, position_delta = -2, cost_basis = 30),
      NA, NA, meta(cash_delta = 3.5, position_delta = 0), NA, NA
    ),
    event_seq = 1:9, stringsAsFactors = FALSE
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
  disp <- function(x) as.character(canonical_json(list(
    source = "corporate_action_disposition", source_fact_id = paste0("f-", x$id), position_delta = -x$before,
    cash_delta = x$before * x$mark, quantity = x$quantity, mark = x$mark, mark_source_ts_utc = "2020-01-03T21:00:00Z",
    mark_age = 0, position_before = x$before, position_after = 0, realized_model_pnl = x$pnl, disposition_policy_id = "p")))
  # Buys AAA 2 at 10 and BBB 3 at 20, then the given dispositions.
  replay <- function(...) {
    d <- list(...)
    n <- 2L + length(d)
    ev <- data.frame(event_id = paste0("e", seq_len(n)), run_id = "r",
      ts_utc = c(d1, d1, d1 + 86400 * vapply(d, `[[`, 0, "day")),
      event_type = c("FILL", "FILL", rep("DISPOSITION", length(d))),
      instrument_id = c("AAA", "BBB", vapply(d, `[[`, "", "id")), side = c("BUY", "BUY", rep(NA, length(d))),
      qty = c(2, 3, vapply(d, `[[`, 0, "quantity")), price = c(10, 20, vapply(d, `[[`, 0, "mark")), fee = 0,
      meta_json = c(NA, NA, vapply(d, disp, "")), event_seq = seq_len(n), stringsAsFactors = FALSE)
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
ws4a_p2_leaks <- function(x, execution, depth = 0L) {
  if (!is.list(x) || depth > 4L) return(character())
  hits <- c(intersect(names(x), ws4a_execution_names),
    if (!is.null(execution) && any(vapply(x, identical, logical(1), execution))) "execution packet object")
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
          # Control: pass the next bar to P2 inside its observation.
          if (leak) out$observation$execution <- out$execution
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
  clean <- leak_run(FALSE)
  testthat::expect_gt(clean$p2, 0L)
  testthat::expect_identical(clean$hits, character())
  testthat::expect_identical(clean$p3_data, 0L)
  testthat::expect_gt(length(leak_run(TRUE)$hits), 0L)
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
    exp <- ledgr_experiment(snapshot, function(ctx, params) {
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
  dense <- ledgr_experiment(snapshot, drop_first, cost_model = ledgr_cost_zero())
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
  exp <- ledgr_experiment(snapshot, function(ctx, params) {
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
  # P2 input: the feature tables of the public context are filtered to the
  # context IDs (a column-name test and two ID filters).
  ledgr_fold_stage_decide = "as.character(features_current$instrument_id) %in% context_ids",
  ledgr_fold_stage_decide = "\"instrument_id\" %in% names(features_wide_current)",
  ledgr_fold_stage_decide = "as.character(features_wide_current$instrument_id) %in% context_ids",
  # P2 return: the strategy helpers note skipped sizing by instrument ID.
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

testthat::test_that("[WS4a D12d D13] no new mode branch; the dense observe and context builders are frozen", {
  root <- ledgr_test_source_root()
  records <- file.path(root, "dev", "bench", "v0_2_3_ws4a", "records")
  testthat::skip_if_not(dir.exists(records), "WS4a frozen detector records are in the source checkout only")
  frozen <- utils::read.csv(file.path(records, "detectors", "frozen.csv"), colClasses = "character")
  frozen <- stats::setNames(frozen$value, frozen$id)
  # D12d: every mode-branch site of the source is in the committed census
  # record (LTB-0331's comparison; LDG-3165 only deleted two P1 rows), and
  # no R/ file has more availability_active tokens than its frozen base
  # count (a new file has none).
  scanner <- new.env(parent = globalenv())
  sys.source(file.path(root, "tools", "codebase-structure.R"), envir = scanner)
  record <- utils::read.csv(file.path(root, "dev", "bench", "v0_2_2_pre_cran_removal", "census", "mode_branches.csv"),
    colClasses = "character", na.strings = character(), encoding = "UTF-8")
  record$occurrence <- as.integer(record$occurrence)
  unrecorded <- function(dir) nrow(scanner$ledgr_mode_branch_compare(scanner$ledgr_mode_branch_scan(dir), record)$unrecorded)
  testthat::expect_identical(unrecorded(root), 0L)
  parse_census <- function(s) {
    parts <- strsplit(strsplit(s, ";", fixed = TRUE)[[1L]], " ", fixed = TRUE)
    stats::setNames(as.integer(vapply(parts, `[[`, "", 2L)), vapply(parts, `[[`, "", 1L))
  }
  count <- function(lines) sum(lengths(regmatches(lines, gregexpr("availability_active", lines, fixed = TRUE))))
  files <- list.files(file.path(root, "R"), "\\.R$", full.names = TRUE)
  now <- stats::setNames(vapply(files, function(f) count(readLines(f)), 0), basename(files))
  base <- parse_census(frozen[["D12d"]])
  over <- function(now) names(now)[now > ifelse(is.na(base[names(now)]), 0, base[names(now)])]
  testthat::expect_identical(over(now), character())
  # Controls: a branch added to P5 is an unrecorded site; a new file with a
  # branch exceeds the base count.
  probe <- withr::local_tempdir("ws4a-d12d-")
  dir.create(file.path(probe, "R"))
  writeLines(c("ledgr_fold_stage_commit <- ",
    deparse(ws4a_inject(ws4a_sources()$ledgr_fold_stage_commit, "if (services$availability_active) NULL"), width.cutoff = 500L)),
    file.path(probe, "R", "fold-engine.R"))
  testthat::expect_gt(unrecorded(probe), 0L)
  testthat::expect_identical(over(c(now, new.R = 1)), "new.R")
  # D13: the dense observe and context builders hash equal to the base.
  fns <- ws4a_sources()
  dense <- c("ledgr_pulse_context", "ledgr_update_pulse_context_helpers", "ledgr_dense_eligibility_planes", "ledgr_fold_build_pulse_plan")
  dhash <- function(f) digest::digest(vapply(f, ws4a_txt, ""), algo = "sha256")
  testthat::expect_identical(dhash(fns[dense]), frozen[["D13"]])
  edited <- fns[dense]
  edited$ledgr_update_pulse_context_helpers <- ws4a_inject(edited$ledgr_update_pulse_context_helpers, "NULL")
  testthat::expect_false(identical(dhash(edited), frozen[["D13"]]))
})
