testthat::test_that("[LTB-0026] accounting refuses every unhandled pulse event kind", {
  # LR-29: the pulse planner declares its kinds only from a literal (no kind,
  # or FILL when the plan has fills), so no public input reaches an
  # unsupported pulse-plan kind, and the refusal is checked only in debug.
  # This block guards that premise: a planner that declares any other kind
  # fails here, and must bring the production refusal back. Corporate-action
  # kinds are refused at fold entry for spot_fifo (test-corporate-action-cash.R).
  kinds <- character()
  walk <- function(e) {
    if (!is.call(e)) return(invisible(NULL))
    if (identical(e[[1L]], as.name("lean_plan_result"))) kinds <<- c(kinds, paste(deparse(e[[3L]]), collapse = " "))
    for (a in as.list(e)[-1L]) if (!missing(a)) walk(a)
  }
  walk(body(eval(str2lang(ledgr_test_candidate_source("lean_plan_pulse")))))
  testthat::expect_gte(length(kinds), 2L)
  testthat::expect_setequal(kinds, c("none", "if (length(fills) > 0L) 1L else none"))

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
