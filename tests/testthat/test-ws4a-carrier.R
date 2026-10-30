# ledgr-test-file-profile: review
#
# WS4a typed fold carrier: the LDG-3164 detectors and validators
# (inst/design/ledgr_v0_2_3_spec_packet/ws4a_carrier_design.md Section 6 and
# Section 3.2, rows owned by LDG-3164). Each predicate runs on production
# code and must pass there; each also shows its own compliant control
# passing and its own violating control failing.

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
  # A carried window enters with its predecessor's net, which may differ from
  # the re-summed carried lots in the last bits.
  testthat::expect_no_error(new_state(positions = book$net_by_inst + c(4 * .Machine$double.eps, 0, 0)))
  testthat::expect_true(environmentIsLocked(state))
  testthat::expect_setequal(ls(state, all.names = TRUE), ns$.ledgr_fold_state_slots)
  testthat::expect_error(assign("undeclared", 1, envir = state), "locked")
  controls <- list(
    storage_type = list(positions = as.integer(c(3, -3, 0))),
    shortened_column = list(positions = c(3.5, -3)),
    named_positions = list(positions = c(AAA = 3.5, BBB = -3, CCC = 0)),
    positions_not_lot_net = list(positions = c(4.5, -3, 0)),
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

testthat::test_that("[WS4a D3] the lot kernel and migrated book consumers index by position", {
  fns <- ws4a_sources()
  char_index <- function(i) {
    (is.symbol(i) && grepl("^(id|ids|inst_id|instrument_id|instrument_ids|context_ids|target_names)$", as.character(i))) ||
      (is.call(i) && ws4a_head(i) %in% c("names", "as.character"))
  }
  check <- function(e) {
    unlist(lapply(ws4a_calls(e), function(x) {
      if (ws4a_head(x) %in% c("[", "[[") && length(x) >= 3L && char_index(x[[3L]])) substr(ws4a_txt(x), 1L, 60L)
    }))
  }
  examined <- c(
    ws4a_kernel_names, "ledgr_lot_apply_blocks", "ledgr_lot_book_live",
    "ledgr_lot_book_problem", "ledgr_replay_accounting_events", "ledgr_fold_stage_apply",
    "ledgr_carrier_compiled_pack", "ledgr_carrier_compiled_unpack", "ledgr_disposition_post"
  )
  testthat::expect_true(all(examined %in% names(fns)))
  testthat::expect_length(ws4a_hits(fns[examined], check), 0L)
  testthat::expect_length(ws4a_hits(list(good = str2lang("function(b, pos) b$net_by_inst[[pos]]")), check), 0L)
  testthat::expect_gt(length(ws4a_hits(list(bad = str2lang("function(b, id) b$net_by_inst[[id]]")), check)), 0L)
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

testthat::test_that("[WS4a D11] P4 and replay read positions from the lot-derived net", {
  fns <- ws4a_sources()
  check <- function(e) {
    unlist(lapply(ws4a_assigns(e), function(x) {
      if ("positions" %in% all.names(x[[2L]]) && any(c("+", "-") %in% all.names(x[[3L]])) &&
          any(grepl("position|qty|delta", setdiff(all.names(x[[3L]]), c("+", "-"))))) ws4a_txt(x)
    }))
  }
  examined <- fns[c("ledgr_fold_stage_apply", "ledgr_replay_accounting_events", "ledgr_disposition_post")]
  testthat::expect_length(ws4a_hits(examined, check), 0L)
  testthat::expect_true(any(grepl("net_by_inst", vapply(examined, ws4a_txt, ""))))
  bad <- ws4a_inject(fns$ledgr_fold_stage_apply, "positions[[inst_idx]] <- positions[[inst_idx]] + qty")
  testthat::expect_gt(length(ws4a_hits(list(p4 = bad), check)), 0L)
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
  check <- function(e) unlist(lapply(ws4a_loop_bodies(e), function(b) intersect(ws4a_heads(b), ops)))
  # The kernel's own loops are the FIFO depth loop and the ordered
  # aggregate scan; neither dispatches a lot operation.
  testthat::expect_length(ws4a_hits(fns[intersect(ws4a_kernel_names, names(fns))], check), 0L)
  scan <- grep("^for \\(k in seq_len\\(m\\)\\)", vapply(Filter(function(x) ws4a_head(x) == "for",
    ws4a_calls(fns$ledgr_lot_apply)), ws4a_txt, ""), value = TRUE)
  testthat::expect_length(scan, 1L)
  testthat::expect_true(grepl("ledgr_lot_add_realized", scan))
  permitted <- str2lang("function(b, pos, q, basis) { b <- ledgr_lot_apply(b, pos); s <- 0; for (i in seq_along(basis)) s <- s + basis[[i]]; b }")
  per_instrument <- str2lang("function(b, pos, q) { for (k in seq_along(pos)) b <- ledgr_lot_fill(b, pos[k], 1L, q[k], 1); b }")
  testthat::expect_length(ws4a_hits(list(ok = permitted), check), 0L)
  testthat::expect_gt(length(ws4a_hits(list(bad = per_instrument), check)), 0L)

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
