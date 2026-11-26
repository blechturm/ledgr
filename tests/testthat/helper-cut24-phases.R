# Cut 24 decision 9 (LDG-3263): mechanism counts observed by preparation
# phase. Runs `code()` with calls of the ledgr function `target` counted by
# the phase they happen in: certification, production calculation (direct or
# general cells), the debug shadow (the general path recomputed inside the
# debug comparison) or the sampled causality check. The observing mocks live
# only inside this call. Returns code()'s value and the four counts.
cut24_phase_counts <- function(target, code) {
  ns <- asNamespace("ledgr")
  counts <- c(certification = 0L, production = 0L, shadow = 0L, causality = 0L)
  phase <- "production"
  in_debug_comparison <- FALSE
  enter <- function(name, original) {
    force(original)
    function(...) {
      prior <- phase
      phase <<- name
      on.exit(phase <<- prior)
      original(...)
    }
  }
  original_target <- get(target, envir = ns)
  original_checked <- ns$ledgr_history_feature_direct_checked
  original_calculate <- ns$ledgr_history_feature_calculate
  bindings <- list(
    ledgr_feature_certify = enter("certification", ns$ledgr_feature_certify),
    ledgr_history_feature_causality = enter("causality", ns$ledgr_history_feature_causality),
    ledgr_history_feature_direct_checked = function(...) {
      in_debug_comparison <<- TRUE
      on.exit(in_debug_comparison <<- FALSE)
      original_checked(...)
    },
    # Inside the debug comparison the product's own cell runs through the
    # direct calculator; the general calculator there is the shadow.
    ledgr_history_feature_calculate = function(...) {
      if (in_debug_comparison && identical(phase, "production")) {
        phase <<- "shadow"
        on.exit(phase <<- "production")
      }
      original_calculate(...)
    }
  )
  bindings[[target]] <- function(...) {
    counts[[phase]] <<- counts[[phase]] + 1L
    original_target(...)
  }
  do.call(testthat::local_mocked_bindings, c(bindings, list(.package = "ledgr")))
  value <- code()
  list(value = value, counts = counts)
}
