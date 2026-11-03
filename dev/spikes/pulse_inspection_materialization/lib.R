cut10_allocation_problems <- function(record) {
  problems <- character()
  expected <- expand.grid(
    label = c("base", "candidate"),
    helper = c("long", "wide"),
    stringsAsFactors = FALSE
  )
  key <- paste(record$label, record$helper)
  expected_key <- paste(expected$label, expected$helper)
  if (!setequal(key, expected_key) || anyDuplicated(key)) {
    return("record must contain exactly base/candidate x long/wide")
  }
  record <- record[match(expected_key, key), , drop = FALSE]
  for (helper in c("long", "wide")) {
    base <- record$bytes_per_call[record$label == "base" & record$helper == helper]
    candidate <- record$bytes_per_call[record$label == "candidate" & record$helper == helper]
    if (!is.finite(base) || !is.finite(candidate) || candidate > base) {
      problems <- c(problems, sprintf("%s allocation did not improve", helper))
    }
    semantic <- record[record$helper == helper, c("rows", "columns", "numeric_sum")]
    same <- vapply(
      semantic,
      function(column) identical(column[[1L]], column[[2L]]),
      logical(1)
    )
    if (!all(same)) {
      problems <- c(problems, sprintf("%s output summary changed", helper))
    }
  }
  problems
}
