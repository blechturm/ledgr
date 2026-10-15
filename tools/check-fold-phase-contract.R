ledgr_fold_phase_function_sources <- function(paths) {
  out <- list()
  for (path in paths) {
    expressions <- parse(path, keep.source = FALSE)
    for (expr in expressions) {
      if (!is.call(expr) || !identical(expr[[1L]], as.name("<-")) ||
          !is.symbol(expr[[2L]]) || !is.call(expr[[3L]]) ||
          !identical(expr[[3L]][[1L]], as.name("function"))) {
        next
      }
      out[[as.character(expr[[2L]])]] <- expr[[3L]]
    }
  }
  out
}

ledgr_fold_phase_stage_name <- function(function_name) {
  stages <- c(
    ledgr_fold_stage_observe_settle = "observe",
    ledgr_fold_stage_decide = "decide",
    ledgr_fold_stage_plan = "plan",
    ledgr_fold_stage_apply = "apply",
    ledgr_fold_stage_commit = "commit",
    ledgr_execute_fold = "envelope"
  )
  unname(stages[[function_name]])
}

ledgr_fold_phase_source_findings <- function(paths) {
  definitions <- ledgr_fold_phase_function_sources(paths)
  stage_names <- names(definitions)[grepl(
    "^ledgr_fold_stage_",
    names(definitions)
  )]
  findings <- character()
  forbidden_formals <- c("ctx", "bars", "feature_table", "features_wide")
  slot_owners <- list(
    cash = c("observe", "apply"),
    positions = c("observe", "apply"),
    lot_state = c("observe", "apply"),
    state_prev = c("observe", "commit"),
    state_axis = c("observe", "commit"),
    event_seq = c("observe", "apply"),
    status = "envelope",
    stop_reason = "envelope",
    affected_exposure = "envelope",
    processed = c("commit", "envelope"),
    full_run = "commit",
    equity_facts = "observe",
    last_fully_valued = "observe",
    last_executed = "commit",
    frozen_set = "observe",
    current_stage = c("observe", "decide", "plan", "apply", "commit", "envelope"),
    current_ts = "envelope",
    pending_segments = c("observe", "decide", "plan", "commit", "envelope"),
    diagnostic_seq = c("commit", "envelope"),
    telemetry_idx = "commit"
  )
  service_rules <- list(
    "valuation_state\\$advance\\s*\\(" = "observe",
    "availability_provider\\$decision_view\\s*\\(" = "observe",
    "availability_provider\\$execution_view\\s*\\(" = "plan",
    "corporate_action_plan\\$(post|post_disposition|check_quantity_effects)\\s*\\(" = "observe",
    "corporate_action_plan\\$bind_boundary\\s*\\(" = c("envelope", "apply"),
    "diagnostic_writer\\$append_block\\s*\\(" = c("commit", "envelope"),
    "diagnostic_writer\\$(drain|release)\\s*\\(" = "envelope",
    "output_handler\\$(append_event_rows|record_equity_fact)\\s*\\(" = "observe",
    "output_handler\\$(write_fill_events|record_accounting_fact|append_compiled_spot_batch)\\s*\\(" = "apply",
    "output_handler\\$(flush_pulse_events|write_strategy_state|buffer_strategy_state)\\s*\\(" = "commit",
    "output_handler\\$(pending_event_count|pending_state_count|flush_pending)\\s*\\(" = c("commit", "envelope"),
    "output_handler\\$(init_buffers|run_transaction|write_run_evidence|write_exception_diagnostic)\\s*\\(" = "envelope",
    "output_handler\\$write_run_diagnostics\\s*\\(" = c("commit", "envelope")
  )

  for (name in stage_names) {
    fn <- definitions[[name]]
    stage <- ledgr_fold_phase_stage_name(name)
    formal_names <- names(as.list(fn[[2L]]))
    body_text <- paste(deparse(fn[[3L]], width.cutoff = 500L), collapse = "\n")
    if (any(forbidden_formals %in% formal_names)) {
      findings <- c(findings, paste0("data_frame_argument:", name))
    }
    if (grepl("fold_state\\$[A-Za-z0-9_]+[^\\n;]*<-\\s*data\\.frame\\s*\\(", body_text, perl = TRUE)) {
      findings <- c(findings, paste0("data_frame_slot:", name))
    }
    if (grepl("new\\.env\\s*\\(", body_text, perl = TRUE) ||
        grepl("\\b[A-Za-z][A-Za-z0-9_.]*\\s*<-\\s*fold_state\\b(?!\\$)", body_text, perl = TRUE)) {
      findings <- c(findings, paste0("second_mutable_aggregate:", name))
    }
    if (grepl("ctx[^\\n;]*fold_state|fold_state[^\\n;]*ctx", body_text, perl = TRUE)) {
      findings <- c(findings, paste0("ctx_references_carrier:", name))
    }
    for (slot in names(slot_owners)) {
      writes <- grepl(
        paste0("fold_state\\$", slot, "[^\\n;]*<-"),
        body_text,
        perl = TRUE
      )
      if (writes && !stage %in% slot_owners[[slot]]) {
        findings <- c(findings, paste0("slot_owner:", name, ":", slot))
      }
    }
    for (pattern in names(service_rules)) {
      if (grepl(pattern, body_text, perl = TRUE) &&
          !stage %in% service_rules[[pattern]]) {
        findings <- c(findings, paste0("service_owner:", name, ":", pattern))
      }
    }
  }

  expected_stages <- c(
    "ledgr_fold_stage_observe_settle", "ledgr_fold_stage_decide",
    "ledgr_fold_stage_plan", "ledgr_fold_stage_apply",
    "ledgr_fold_stage_commit"
  )
  if (all(expected_stages %in% names(definitions)) &&
      "ledgr_execute_fold" %in% names(definitions)) {
    envelope <- paste(deparse(
      definitions$ledgr_execute_fold[[3L]],
      width.cutoff = 500L
    ), collapse = "\n")
    inline_sentinels <- c(
      "availability_provider\\$decision_view\\s*\\(",
      "strategy_fn\\s*\\(",
      "ledgr_fold_build_pulse_plan\\s*\\(",
      "output_handler\\$write_fill_events\\s*\\(",
      "output_handler\\$write_strategy_state\\s*\\("
    )
    if (any(vapply(inline_sentinels, grepl, logical(1L), x = envelope, perl = TRUE))) {
      findings <- c(findings, "duplicated_inline_stage_body:ledgr_execute_fold")
    }
  }
  unique(findings)
}

ledgr_fold_phase_check <- function(root) {
  paths <- list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE)
  findings <- ledgr_fold_phase_source_findings(paths)
  if (length(findings)) {
    stop(
      paste(c("Fold phase contract findings:", findings), collapse = "\n"),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
  ledgr_fold_phase_check(root)
  cat("LEDGR_FOLD_PHASE_CONTRACT_OK\n")
}
