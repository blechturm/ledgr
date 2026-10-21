# ledgr-test-file-profile: review

# R chunks of a Quarto source: label, whether the chunk is shown, and its code.
ws44_qmd_chunks <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  opens <- grep("^```\\{r\\}\\s*$", lines)
  closes <- grep("^```\\s*$", lines)
  lapply(opens, function(open) {
    close <- closes[closes > open][1L]
    body <- if (close > open + 1L) lines[(open + 1L):(close - 1L)] else character()
    options <- body[startsWith(body, "#|")]
    label <- sub("^#\\|\\s*label:\\s*", "", grep("^#\\|\\s*label:", options, value = TRUE))
    list(
      label = if (length(label)) label[[1L]] else NA_character_,
      shown = !any(grepl("^#\\|\\s*include:\\s*false", options)),
      options = options,
      code = body[!startsWith(body, "#|")],
      line = open
    )
  })
}

testthat::test_that("[LTB-0414] the causal-history article teaches the history flow with executed output", {
  root <- ledgr_test_source_root()
  source <- file.path(root, "vignettes", "causal-history.qmd")
  rendered <- file.path(root, "vignettes", "causal-history.md")
  testthat::skip_if_not(file.exists(source), "article sources not available during installed-package tests")
  chunks <- ws44_qmd_chunks(source)
  shown <- Filter(function(x) x$shown, chunks)
  code <- function(label) {
    hit <- Filter(function(x) identical(x$label, label), chunks)
    testthat::expect_length(hit, 1L)
    paste(hit[[1L]]$code, collapse = "\n")
  }
  all_code <- paste(unlist(lapply(shown, `[[`, "code")), collapse = "\n")
  text <- paste(readLines(source, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  # Every chunk executes: no chunk opts out of evaluation or hides an error.
  options <- unlist(lapply(chunks, `[[`, "options"))
  testthat::expect_false(any(grepl("eval:\\s*false|error:\\s*true", options)))
  testthat::expect_false(grepl("eval\\s*=\\s*FALSE", text))

  # Hello world first: the first shown chunk opens an existing snapshot and
  # completes a run, and no shown chunk before the late-fact section ingests
  # point-in-time facts or builds a snapshot.
  testthat::expect_identical(shown[[1L]]$label, "hello-world")
  hello <- code("hello-world")
  testthat::expect_match(hello, "ledgr_snapshot_open(", fixed = TRUE)
  testthat::expect_match(hello, "ledgr_run(", fixed = TRUE)
  ingest <- vapply(shown, function(x) any(grepl("ledgr_facts|ledgr_snapshot_from_", x$code)), TRUE)
  first_ingest <- which(ingest)[1L]
  testthat::expect_true(!is.na(first_ingest) && first_ingest > 1L)
  testthat::expect_identical(shown[[first_ingest]]$label, "late-fact")

  # Defaults first, explicit choices second.
  testthat::expect_match(code("default-read"), "ledgr_history_frame(bar = \"close\")", fixed = TRUE)
  explicit <- code("explicit-choices")
  testthat::expect_lt(
    match("default-read", vapply(shown, `[[`, "", "label")),
    match("explicit-choices", vapply(shown, `[[`, "", "label"))
  )
  testthat::expect_match(explicit, "instruments = \"decision_axis\"", fixed = TRUE)
  testthat::expect_match(explicit, "na_action = \"drop_instruments\"", fixed = TRUE)
  testthat::expect_match(code("long-layout"), "layout = \"long\"", fixed = TRUE)
  testthat::expect_match(code("matrix"), "ledgr_history_matrix(", fixed = TRUE)
  testthat::expect_match(code("info"), "ledgr_history_info(", fixed = TRUE)
  testthat::expect_match(code("sufficiency"), "ledgr_history_sufficient(", fixed = TRUE)
  testthat::expect_match(code("indicator-classes"), "ledgr_ind_ttr(", fixed = TRUE)
  testthat::expect_match(code("carried-share"), "carried_input_share", fixed = TRUE)
  testthat::expect_match(code("returns-not-diff"), "feature = \"return_1\"", fixed = TRUE)
  # The late fact is read after it is known, once as restated bars and once
  # as vintage features (close review 44b F5).
  late <- code("late-fact")
  testthat::expect_match(late, "read_ddd(days[[7L]], bar = \"close\")", fixed = TRUE)
  testthat::expect_match(late, "read_ddd(days[[7L]], feature = \"sma\")", fixed = TRUE)
  # The walk-forward chunk reads history from the strategy's own context
  # inside the test runs and shows what each test window read.
  walk <- code("walk-forward")
  testthat::expect_match(walk, "ledgr_walk_forward(", fixed = TRUE)
  testthat::expect_match(walk, "nrow(ledgr_history_frame(ctx", fixed = TRUE)
  testthat::expect_match(walk, "wf$test_runs", fixed = TRUE)
  testthat::expect_match(code("finite-lookback"), "lookback", fixed = TRUE)
  testthat::expect_match(code("preflight"), "ledgr_strategy_preflight(", fixed = TRUE)

  # The portfolio example reaches targets from one history read, without
  # rebuilding timestamps or names and without a second reader, and keeps
  # held instruments the estimate dropped.
  portfolio <- code("portfolio")
  for (call in c("ledgr_history_frame(", "ledgr_history_matrix(", "ledgr_history_weights(",
                 "ledgr_history_info(", "ledgr_target_rebalance(", "keep = keep")) {
    testthat::expect_match(portfolio, call, fixed = TRUE, info = call)
  }
  # Whitespace is removed before the scan, so spacing cannot hide a forbidden
  # call or a names assignment (close review 44b F5).
  compact <- gsub("[[:space:]]+", "", portfolio)
  for (forbidden in c("colnames(", "rownames(", "setNames(", "ts_utc",
                      "[,-1", "ledgr_results(", "ctx$bars", "ctx$feature_table",
                      "ledgr_pulse_features(", "ctx$vec$feature(")) {
    testthat::expect_false(grepl(forbidden, compact, fixed = TRUE), info = forbidden)
  }
  testthat::expect_false(grepl("(^|[^[:alnum:]_.])(dim)?names\\(", compact), info = "names(")
  testthat::expect_identical(lengths(regmatches(portfolio, gregexpr("ledgr_history_frame(", portfolio,
                                                                      fixed = TRUE))), 1L)

  # The rendered article holds the executed output of those chunks.
  testthat::skip_if_not(file.exists(rendered), "rendered article not available")
  md <- paste(readLines(rendered, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  for (output in c("Window start:", "Used before window:", "carried_input_share",
                   "input_carried", "History class: bounded", "History class: history_dependent", "tier_3", "history-estimate", "Selection, exclusions and window")) {
    testthat::expect_match(md, output, fixed = TRUE, info = output)
  }
  testthat::expect_false(grepl("#> Error", md, fixed = TRUE))

  # Executed effects, not only calls (close review 44b F3 and F5). Output of
  # a chunk call: the text between that call's code block and the next one.
  output_after <- function(call) {
    at <- regexpr(call, md, fixed = TRUE)
    testthat::expect_true(at > 0L, info = call)
    rest <- substring(md, at + nchar(call))
    rest <- sub("^[^`]*```", "", rest)
    sub("``` r.*$", "", rest)
  }
  # Late fact: the restated bar read marks sessions 5 and 6 as inactive
  # prints; the vintage feature read keeps their at-pulse values 52.5 and 58.
  bars_late <- output_after("read_ddd(days[[7L]], bar = \"close\")")
  testthat::expect_match(bars_late, "inactive_interval_print", fixed = TRUE)
  features_late <- output_after("read_ddd(days[[7L]], feature = \"sma\")")
  testthat::expect_match(features_late, "52.5", fixed = TRUE)
  testthat::expect_match(features_late, "58.0", fixed = TRUE)
  testthat::expect_false(grepl("inactive_interval_print", features_late, fixed = TRUE))
  # Walk-forward: each test window's first fill is the session count its
  # strategy read; both exceed a test window's length (about 64 sessions),
  # and the later window read more.
  fills <- output_after("do.call(rbind, first_fills)")
  quantities <- as.numeric(sub(".*DEMO_05[[:space:]]+([0-9]+).*", "\\1",
                               regmatches(fills, gregexpr("DEMO_05[[:space:]]+[0-9]+", fills))[[1L]]))
  testthat::expect_length(quantities, 2L)
  testthat::expect_true(all(quantities > 64), info = "test windows read from the data start")
  testthat::expect_gt(quantities[[2L]], quantities[[1L]])
  # keep: the held DEMO_04 is not sold at the gap with keep, and is sold on
  # 10 January without it.
  with_keep <- output_after("demo_04_fills(estimated)")
  without <- output_after("demo_04_fills(without_keep)")
  testthat::expect_false(grepl("2020-01-10", with_keep, fixed = TRUE))
  testthat::expect_match(without, "2020-01-10 09:30:00 SELL", fixed = TRUE)
  # Help pages point to the article with a browser-free path.
  for (page in c("ledgr_history_frame", "ledgr_history_matrix", "ledgr_history_info",
                 "ledgr_history_weights", "ledgr_history_sufficient", "ledgr_history_policy")) {
    rd <- paste(readLines(file.path(root, "man", paste0(page, ".Rd")), warn = FALSE), collapse = "\n")
    testthat::expect_match(rd, "vignette(\"causal-history\", package = \"ledgr\")", fixed = TRUE, info = page)
    testthat::expect_match(rd, "system.file(\"doc\", \"causal-history.html\", package = \"ledgr\")",
                           fixed = TRUE, info = page)
  }
})

# Sentences of contracts.md that state rule 3 or schema 120/121 without
# marking them as superseded, older or retained by the current rule.
ws44_current_rule3_statements <- function(contracts) {
  text <- gsub("\\s+", " ", paste(contracts, collapse = " "))
  sentences <- strsplit(text, "(?<=[.;])\\s+", perl = TRUE)[[1L]]
  old <- grepl("(?i)\\b(hash |identity )?rule[- ]3\\b|\\bschema[- ]12[01]\\b", sentences, perl = TRUE)
  marked <- grepl("(?i)older|retains?|superseded|refus|rule[- ]4|\\bpre-", sentences, perl = TRUE)
  sentences[old & !marked]
}

testthat::test_that("[LTB-0415] Cut 16 contract receivers are present tense and no v12 pending link remains", {
  root <- ledgr_test_source_root()
  if (!ledgr_test_design_source_context(root)) return(invisible(NULL))
  design <- file.path(root, "inst", "design")
  contracts <- readLines(file.path(design, "contracts.md"), warn = FALSE, encoding = "UTF-8")
  joined <- gsub("\\s+", " ", paste(contracts, collapse = " "))

  # Every receiver anchor in the v12 receiver map resolves in contracts.md.
  v12 <- readLines(file.path(design, "rfc",
    "rfc_point_in_time_historical_projection_v0_2_x_synthesis_v12.md"), warn = FALSE)
  table <- v12[grepl("^\\| \\[", v12) & grepl("contracts.md#contract-", v12, fixed = TRUE)]
  anchors <- unique(unlist(regmatches(table, gregexpr("contract-[a-z0-9-]+", table))))
  testthat::expect_gte(length(anchors), 28L)
  for (anchor in anchors) {
    testthat::expect_true(any(grepl(sprintf("<a id=\"%s\"></a>", anchor), contracts, fixed = TRUE)),
                          info = anchor)
  }

  # No receiver still carries a v12 pending back-link.
  for (target in c("point-in-time-historical-projection", "recursive-indicator-boundary")) {
    pattern <- sprintf("Accepted change pending: \\[[^]]+\\]\\(decisions[.]md#%s\\)", target)
    testthat::expect_false(grepl(pattern, joined, perl = TRUE), info = target)
  }

  # No current-tense rule-3 snapshot-hash or schema-120/121 statement remains.
  testthat::expect_identical(ws44_current_rule3_statements(contracts), character())
  testthat::expect_length(
    ws44_current_rule3_statements("Snapshot hash rule 3 is the sole executable content-identity rule."),
    1L
  )

  # The decisions bridge rows stay until release closeout and the three RFC
  # redirect anchors resolve.
  decisions <- paste(readLines(file.path(design, "decisions.md"), warn = FALSE), collapse = "\n")
  for (row in c("point-in-time-historical-projection", "recursive-indicator-boundary")) {
    testthat::expect_match(decisions, sprintf("<a id=\"%s\"></a>", row), fixed = TRUE, info = row)
  }
  rfc <- paste(readLines(file.path(design, "rfc", "README.md"), warn = FALSE), collapse = "\n")
  for (anchor in c("point-in-time-historical-projection", "recursive-indicator-semantics",
                   "instrument-specific-session-axis")) {
    testthat::expect_match(rfc, sprintf("<a id=\"%s\"></a>", anchor), fixed = TRUE, info = anchor)
  }
})
