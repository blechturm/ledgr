#!/usr/bin/env Rscript

options(warn = 1)
Sys.setlocale("LC_COLLATE", "C")

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(prefix, default = NULL) {
  hit <- args[startsWith(args, paste0(prefix, "="))]
  if (length(hit) == 0L) return(default)
  substring(hit[[1L]], nchar(prefix) + 2L)
}

package_root <- normalizePath(arg_value("--package-root", "."), winslash = "/", mustWork = TRUE)
output_dir <- arg_value("--output", file.path(tempdir(), "history-correction-chain"))
gut <- arg_value("--gut", "none")
if (!gut %in% c("none", "drop_private_supersession")) {
  stop("Unknown --gut value: ", gut, call. = FALSE)
}
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)

suppressPackageStartupMessages(pkgload::load_all(package_root, quiet = TRUE, compile = FALSE))

day <- function(index, hour = 0L) {
  as.POSIXct(as.Date("2020-01-01") + index - 1L, tz = "UTC") + hour * 3600
}

na_time <- function(n = 1L) {
  as.POSIXct(rep(NA_real_, n), origin = "1970-01-01", tz = "UTC")
}

status_rows <- function(ids, from, to, known, status, supersedes,
                        precedence = 1L) {
  n <- length(ids)
  if (length(from) == 1L) from <- rep(from, n)
  if (length(to) == 1L) to <- rep(to, n)
  if (length(known) == 1L) known <- rep(known, n)
  if (length(precedence) == 1L) precedence <- rep(precedence, n)
  data.frame(
    instrument_id = rep("AAA", n),
    effective_from = as.POSIXct(from, origin = "1970-01-01", tz = "UTC"),
    effective_to = as.POSIXct(to, origin = "1970-01-01", tz = "UTC"),
    knowledge_time = as.POSIXct(known, origin = "1970-01-01", tz = "UTC"),
    status = status,
    source = rep("synthetic", n),
    precedence = as.integer(precedence),
    fact_id = ids,
    supersedes_fact_id = supersedes,
    stringsAsFactors = FALSE
  )
}

cases <- list(
  direct_full = status_rows(
    c("f1", "f2"), day(2), day(7), day(c(2, 3)),
    c("halted", "active"), c(NA, "f1")
  ),
  linear_monotone = status_rows(
    c("f1", "f2", "f3"), day(2), day(7), day(c(2, 3, 4)),
    c("halted", "active", "quotation_only"), c(NA, "f1", "f2")
  ),
  linear_out_of_order = status_rows(
    c("f1", "f2", "f3"), day(2), day(7), day(c(2, 5, 3)),
    c("halted", "active", "quotation_only"), c(NA, "f1", "f2")
  ),
  competing_descendants = status_rows(
    c("f1", "f2", "f3"), day(2), day(7), day(c(2, 3, 4)),
    c("halted", "active", "quotation_only"), c(NA, "f1", "f1")
  ),
  partial_coverage = status_rows(
    c("f1", "f2"), c(day(2), day(3)), c(day(7), day(5)), day(c(2, 3)),
    c("halted", "active"), c(NA, "f1")
  ),
  overextended_coverage = status_rows(
    c("f1", "f2"), c(day(2), day(3)), c(day(5), day(7)), day(c(2, 3)),
    c("halted", "active"), c(NA, "f1")
  ),
  dangling_reference = status_rows(
    "f1", day(2), day(7), day(2), "active", "missing"
  ),
  cycle = status_rows(
    c("f1", "f2"), day(2), day(7), day(c(2, 3)),
    c("halted", "active"), c("f2", "f1")
  ),
  ancestor_and_sibling = status_rows(
    c("f1", "f2", "f3", "f4"), day(2), day(7), day(c(2, 3, 4, 5)),
    c("halted", "active", "quotation_only", "active"),
    c(NA, "f1", "f2", "f1")
  )
)

session_family <- ledgr_facts_sessions(
  data.frame(
    session_date = as.Date("2020-01-01") + 0:6,
    status = "open",
    session_open = "09:30:00",
    session_close = "16:00:00",
    knowledge_time = day(1) - 1,
    stringsAsFactors = FALSE
  ),
  venue_id = "UTCX",
  timezone = "UTC"
)

bars <- data.frame(
  instrument_id = "AAA",
  ts_utc = day(1:7, 16L),
  open = 100 + 0:6,
  high = 101 + 0:6,
  low = 99 + 0:6,
  close = 100 + 0:6,
  volume = 1000,
  stringsAsFactors = FALSE
)

condition_record <- function(expr) {
  tryCatch(
    list(value = expr, outcome = "accepted", condition_class = "", message = ""),
    error = function(e) list(
      value = NULL,
      outcome = "refused",
      condition_class = class(e)[[1L]],
      message = conditionMessage(e)
    )
  )
}

private_rows <- function(input) {
  out <- data.frame(
    fact_id = input$fact_id,
    instrument_id = input$instrument_id,
    effective_from = input$effective_from,
    effective_to = input$effective_to,
    knowledge_time = input$knowledge_time,
    status = input$status,
    source = input$source,
    precedence = input$precedence,
    revision_id = rep(NA_character_, nrow(input)),
    supersedes_fact_id = input$supersedes_fact_id,
    provenance_json = rep("{}", nrow(input)),
    stringsAsFactors = FALSE
  )
  if (identical(gut, "drop_private_supersession")) {
    out$supersedes_fact_id[] <- NA_character_
  }
  out
}

private_timeline <- function(rows) {
  data <- list(
    families = data.frame(
      family = "trading_status", scope_id = "instrument",
      stringsAsFactors = FALSE
    ),
    status = rows,
    lifetime = data.frame(),
    membership = data.frame(),
    membership_sets = data.frame(),
    sessions = NULL
  )
  config <- list(
    universe = list(instrument_ids = "AAA"),
    availability = list(universe_rule = NULL)
  )
  provider <- ledgr:::ledgr_availability_provider_build_prepared(
    data, config, "history-correction-chain-spike", function(...) NULL
  )
  vapply(1:7, function(index) {
    unname(provider$facts(day(index, 16L), ids = "AAA")$status[[1L]])
  }, character(1))
}

public_runtime <- function(family, case_id) {
  facts <- ledgr_facts(session_family, family)
  validation <- ledgr_facts_validate(facts, bars)
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = "AAA", stringsAsFactors = FALSE),
    facts = facts,
    price_basis = "split_adjusted"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$hold(),
    valuation_policy = ledgr_valuation_stale(5L),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(experiment, run_id = paste0("correction-chain-", case_id))
  on.exit(close(bt), add = TRUE)
  availability <- as.data.frame(ledgr_results(bt, "availability"))
  availability <- availability[availability$instrument_id == "AAA", , drop = FALSE]
  availability <- availability[order(availability$ts_utc), , drop = FALSE]
  list(
    validation = validation,
    snapshot_hash = ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]],
    availability = availability
  )
}

case_records <- list()
timeline_records <- list()
classifier_records <- list()

for (case_id in names(cases)) {
  input <- cases[[case_id]]
  constructed <- condition_record(ledgr_facts_trading_status(input))
  raw <- private_rows(input)
  private_status <- private_timeline(raw)
  conflicts <- sort(ledgr:::ledgr_status_runtime_conflicts(raw), method = "radix")

  public <- NULL
  seal_outcome <- "not_reached"
  validation_outcomes <- "not_reached"
  if (identical(constructed$outcome, "accepted")) {
    public_attempt <- condition_record(public_runtime(constructed$value, case_id))
    seal_outcome <- public_attempt$outcome
    if (identical(public_attempt$outcome, "accepted")) {
      public <- public_attempt$value
      validation_outcomes <- paste(
        sort(unique(public$validation$facts$outcome), method = "radix"),
        collapse = "|"
      )
    } else {
      constructed$condition_class <- public_attempt$condition_class
      constructed$message <- public_attempt$message
    }
  }

  case_records[[case_id]] <- data.frame(
    case_id = case_id,
    fact_count = nrow(input),
    constructor_outcome = constructed$outcome,
    constructor_class = constructed$condition_class,
    constructor_message = constructed$message,
    public_seal_run_outcome = seal_outcome,
    public_validation_outcomes = validation_outcomes,
    private_classifier_conflict_count = length(conflicts),
    stringsAsFactors = FALSE
  )

  classifier_records[[case_id]] <- data.frame(
    case_id = case_id,
    conflicting_fact_ids = paste(conflicts, collapse = "|"),
    stringsAsFactors = FALSE
  )

  private_frame <- data.frame(
    case_id = case_id,
    observation_layer = "private_prepared_resolver",
    day = 1:7,
    state = private_status,
    stringsAsFactors = FALSE
  )
  if (is.null(public)) {
    public_frame <- data.frame(
      case_id = character(), observation_layer = character(), day = integer(),
      state = character(), stringsAsFactors = FALSE
    )
  } else {
    public_state <- ifelse(
      public$availability$target_restricted,
      public$availability$target_restriction_reason,
      "active"
    )
    public_frame <- data.frame(
      case_id = case_id,
      observation_layer = "public_run_availability",
      day = seq_along(public_state),
      state = as.character(public_state),
      stringsAsFactors = FALSE
    )
  }
  timeline_records[[case_id]] <- rbind(private_frame, public_frame)
}

cases_out <- do.call(rbind, case_records)
rownames(cases_out) <- NULL
timeline_out <- do.call(rbind, timeline_records)
rownames(timeline_out) <- NULL
classifier_out <- do.call(rbind, classifier_records)
rownames(classifier_out) <- NULL

state_at <- function(case_id, day_index, layer = "private_prepared_resolver") {
  hit <- timeline_out$case_id == case_id &
    timeline_out$observation_layer == layer &
    timeline_out$day == day_index
  if (sum(hit) != 1L) return(NA_character_)
  timeline_out$state[hit]
}

case_value <- function(case_id, column) {
  cases_out[cases_out$case_id == case_id, column][[1L]]
}

derived <- data.frame(
  finding = c(
    "direct_full_public_path",
    "accepted_public_private_parity",
    "monotone_ancestor_pair_refused",
    "out_of_order_gap_conflicts",
    "competing_descendants_conflict",
    "partial_replacement_revives",
    "partial_classifier_misses_revival",
    "overextended_successor_survives",
    "dangling_reference_fails_closed",
    "cycle_fails_closed",
    "ancestor_sibling_fork_conflicts"
  ),
  observed = c(
    case_value("direct_full", "public_seal_run_outcome") == "accepted",
    all(vapply(c("direct_full", "partial_coverage", "overextended_coverage"), function(case_id) {
      private <- timeline_out[
        timeline_out$case_id == case_id &
          timeline_out$observation_layer == "private_prepared_resolver",
        "state"
      ]
      public <- timeline_out[
        timeline_out$case_id == case_id &
          timeline_out$observation_layer == "public_run_availability",
        "state"
      ]
      translated <- c(
        unknown = "status_unknown",
        conflicting = "status_conflicting",
        active = "active",
        halted = "trading_halted",
        quotation_only = "quotation_only"
      )[private]
      identical(unname(translated), unname(public))
    }, logical(1))),
    case_value("linear_monotone", "constructor_outcome") == "refused" &&
      state_at("linear_monotone", 4L) == "quotation_only",
    state_at("linear_out_of_order", 3L) == "conflicting",
    state_at("competing_descendants", 4L) == "conflicting",
    state_at("partial_coverage", 6L) == "halted",
    case_value("partial_coverage", "private_classifier_conflict_count") == 0L &&
      state_at("partial_coverage", 6L) == "halted",
    state_at("overextended_coverage", 6L) == "active",
    case_value("dangling_reference", "constructor_class") == "ledgr_fact_invalid_supersession",
    case_value("cycle", "constructor_class") == "ledgr_fact_invalid_supersession",
    state_at("ancestor_and_sibling", 5L) == "conflicting"
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(cases_out, file.path(output_dir, "case_results.csv"), row.names = FALSE, na = "")
utils::write.csv(timeline_out, file.path(output_dir, "timeline.csv"), row.names = FALSE, na = "")
utils::write.csv(classifier_out, file.path(output_dir, "classifier.csv"), row.names = FALSE, na = "")
utils::write.csv(derived, file.path(output_dir, "derived_findings.csv"), row.names = FALSE, na = "")

cat(sprintf(
  "HISTORY_CORRECTION_CHAIN_SPIKE cases=%d derived=%d observed=%d gut=%s\n",
  nrow(cases_out), nrow(derived), sum(derived$observed), gut
))
