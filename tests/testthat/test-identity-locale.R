# ledgr-test-file-profile: review

testthat::test_that("[LTB-0266] identity JSON is locale-independent across processes", {
  testthat::skip_if_not_installed("pkgload")
  testthat::expect_identical(
    as.character(ledgr:::canonical_json(list(
      strategy_params = list(lookback = 60L, n = 20L)
    ))),
    '{"strategy_params":{"lookback":60,"n":20}}'
  )
  root <- normalizePath(testthat::test_path("..", ".."), winslash = "/")
  script <- tempfile(fileext = ".R")
  on.exit(unlink(script), add = TRUE)
  writeLines(c(
    ".libPaths(c(Sys.getenv('R_LIBS_USER'), .libPaths()))",
    "pkgload::load_all(commandArgs(TRUE)[[1L]], quiet = TRUE)",
    "active <- suppressWarnings(Sys.setlocale('LC_COLLATE', commandArgs(TRUE)[[2L]]))",
    "if (is.na(active) || !nzchar(active)) { cat('LEDGR_LOCALE_UNAVAILABLE\\n'); quit(save = 'no') }",
    "keys <- c('a_key', 'B_key', '_key')",
    "params <- stats::setNames(list(1L, 2L, 3L), keys)",
    "config <- list(identity_rule_version = 4L, data = list(snapshot_id = 'local', snapshot_hash = 'hash'), risk_chain = list(risk_chain_hash = 'risk', risk_plan_json = '{}'), history = ledgr:::ledgr_history_policy_identity(ledgr_history_policy()), strategy = list(params = params))",
    "cat(paste0('LEDGR_ACTIVE=', active, '\\n'))",
    "cat(paste0('LEDGR_ORDER=', paste(order(keys), collapse = ','), '\\n'))",
    "cat(paste0('LEDGR_JSON=', unname(ledgr:::canonical_json(list(strategy_params = params))), '\\n'))",
    "cat(paste0('LEDGR_HASH=', ledgr:::config_hash(config), '\\n'))"
  ), script, useBytes = TRUE)
  run_locale <- function(locale) {
    output <- suppressWarnings(ledgr_test_system2(
      file.path(R.home("bin"), "Rscript"),
      c("--vanilla", shQuote(script), shQuote(root), shQuote(locale)),
      stdout = TRUE,
      stderr = TRUE
    ))
    if (any(output == "LEDGR_LOCALE_UNAVAILABLE")) return(NULL)
    field <- function(prefix) {
      hit <- output[startsWith(output, prefix)]
      if (length(hit) != 1L) return(NA_character_)
      substring(hit, nchar(prefix) + 1L)
    }
    list(
      active = field("LEDGR_ACTIVE="),
      order = field("LEDGR_ORDER="),
      json = field("LEDGR_JSON="),
      hash = field("LEDGR_HASH=")
    )
  }
  c_result <- run_locale("C")
  testthat::expect_false(is.null(c_result))
  candidates <- c(
    "en_US.UTF-8", "English_United States.1252",
    "English_United States.utf8", "de_AT.UTF-8",
    "German_Germany.1252"
  )
  other <- NULL
  for (candidate in candidates) {
    result <- run_locale(candidate)
    if (!is.null(result) && !identical(result$order, c_result$order)) {
      other <- result
      break
    }
  }
  testthat::expect_false(is.null(other))
  testthat::expect_identical(other$json, c_result$json)
  testthat::expect_identical(other$hash, c_result$hash)
})
