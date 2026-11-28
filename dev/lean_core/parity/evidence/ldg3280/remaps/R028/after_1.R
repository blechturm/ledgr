testthat::test_that("[LTB-0026] accounting refuses every unhandled pulse event kind", {
  # LR-29: the pulse planner declares its kinds only from a literal (no kind,
  # or FILL when the plan has fills), so no public input reaches an
  # unsupported pulse-plan kind, and the fold does not check it in
  # production. This block guards that premise: a planner that declares any
  # other kind fails here, and must bring the production refusal back.
  kinds <- character()
  returns <- character()
  walk <- function(e) {
    if (!is.call(e)) return(invisible(NULL))
    if (identical(e[[1L]], as.name("lean_plan_result"))) kinds <<- c(kinds, paste(deparse(e[[3L]]), collapse = " "))
    if (identical(e[[1L]], as.name("return"))) returns <<- c(returns, paste(deparse(e[[2L]][[1L]]), collapse = " "))
    for (a in as.list(e)[-1L]) if (!missing(a)) walk(a)
  }
  planner <- body(eval(str2lang(ledgr_test_candidate_source("lean_plan_pulse"))))
  walk(planner)
  testthat::expect_gte(length(kinds), 2L)
  testthat::expect_setequal(kinds, c("none", "if (length(fills) > 0L) 1L else none"))
  # Every exit goes through lean_plan_result, which passes the kinds on
  # unchanged, and `none` is the empty integer.
  testthat::expect_setequal(returns, "lean_plan_result")
  testthat::expect_identical(planner[[length(planner)]][[1L]], as.name("lean_plan_result"))
  testthat::expect_match(ledgr_test_candidate_source("lean_plan_result"), "economic_event_kinds = kinds", fixed = TRUE)
  testthat::expect_true(any(vapply(as.list(planner), function(e) identical(e, quote(none <- integer())), logical(1))))

  # The spot_fifo selector's FILL-only check stays in production at fold
  # entry, on the corporate-action plan's kinds (LR-25). test-corporate-action-cash.R
  # reaches it publicly with CASHFLOW; this table keeps every non-FILL kind.
  testthat::expect_true(ledgr:::ledgr_require_compiled_spot_fifo_event_kinds("FILL"))
  for (kind in c("CASHFLOW", "DISPOSITION", "SYNTHETIC_UNKNOWN")) {
    testthat::expect_error(
      ledgr:::ledgr_require_compiled_spot_fifo_event_kinds(c("FILL", kind)),
      class = "ledgr_compiled_spot_fifo_unavailable",
      info = paste("compiled envelope must reject", kind)
    )
  }

  # covr rewrites function bodies, so the source text holds only in ordinary runs.
  # P4 consumes the plan's fill columns.
  if (!(requireNamespace("covr", quietly = TRUE) && covr::in_covr())) {
    fold_source <- ledgr_test_candidate_source("lean_p4_apply")
    testthat::expect_match(fold_source, "fill <- batch$fill", fixed = TRUE)
    # LDG-3167 (category 3): the canonical path consumes the fill columns as
    # one batch, not one row at a time.
    testthat::expect_match(fold_source, "applied <- lean_lot_fill_checked(book, fill)", fixed = TRUE)
    testthat::expect_false(grepl("for (i in seq_along(fill$k))", fold_source, fixed = TRUE))
  }
})
