#' Corporate-action settlement policy
#'
#' Corporate-action policy is part of experiment identity. The research preset
#' permits the bounded modeled behavior supported by ledgr; the strict preset
#' refuses every corporate-action settlement choice.
#'
#' @param cash_amount One of `"gross"` or `"refuse"`.
#' @param cash_posting One of `"effective_close"`, `"next_open"`, or
#'   `"refuse"`.
#' @param held_terminal_position One of `"last_permissible"`, `"last_mark"`,
#'   or `"refuse"`.
#' @param unsupported_quantity One of `"report_only"` or `"refuse"`.
#'
#' @return A validated `ledgr_corporate_action_policy` object.
#' @name ledgr_corporate_action_policy
NULL

ledgr_corporate_action_policy_choices <- function() {
  list(
    cash_amount = c("gross", "refuse"),
    cash_posting = c("effective_close", "next_open", "refuse"),
    held_terminal_position = c("last_permissible", "last_mark", "refuse"),
    unsupported_quantity = c("report_only", "refuse")
  )
}

ledgr_corporate_action_policy_ids <- function() {
  list(
    cash_amount = c(
      gross = "ledgr.corporate_action.cash_amount.gross.v001",
      refuse = "ledgr.corporate_action.cash_amount.refuse.v001"
    ),
    cash_posting = c(
      effective_close = "ledgr.corporate_action.cash_posting.effective_close.v001",
      next_open = "ledgr.corporate_action.cash_posting.next_open.v001",
      refuse = "ledgr.corporate_action.cash_posting.refuse.v001"
    ),
    held_terminal_position = c(
      last_permissible = "ledgr.corporate_action.held_terminal_position.last_permissible.v001",
      last_mark = "ledgr.corporate_action.held_terminal_position.last_mark.v001",
      refuse = "ledgr.corporate_action.held_terminal_position.refuse.v001"
    ),
    unsupported_quantity = c(
      report_only = "ledgr.corporate_action.unsupported_quantity.report_only.v001",
      refuse = "ledgr.corporate_action.unsupported_quantity.refuse.v001"
    )
  )
}

ledgr_corporate_action_choice <- function(value, field) {
  allowed <- ledgr_corporate_action_policy_choices()[[field]]
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !value %in% allowed) {
    rlang::abort(
      sprintf(
        "Corporate-action policy `%s` must be exactly one of: %s.",
        field,
        paste(sprintf('"%s"', allowed), collapse = ", ")
      ),
      class = c("ledgr_invalid_corporate_action_policy", "ledgr_invalid_args")
    )
  }
  value
}

#' @rdname ledgr_corporate_action_policy
#' @export
ledgr_corporate_actions <- function(cash_amount = "gross",
                                    cash_posting = "effective_close",
                                    held_terminal_position = "last_permissible",
                                    unsupported_quantity = "report_only") {
  values <- list(
    cash_amount = ledgr_corporate_action_choice(cash_amount, "cash_amount"),
    cash_posting = ledgr_corporate_action_choice(cash_posting, "cash_posting"),
    held_terminal_position = ledgr_corporate_action_choice(
      held_terminal_position,
      "held_terminal_position"
    ),
    unsupported_quantity = ledgr_corporate_action_choice(
      unsupported_quantity,
      "unsupported_quantity"
    )
  )
  ids <- ledgr_corporate_action_policy_ids()
  identity <- lapply(names(values), function(field) {
    unname(ids[[field]][[values[[field]]]])
  })
  names(identity) <- names(values)
  structure(
    c(
      list(policy_schema_version = 1L),
      values,
      list(identity = identity)
    ),
    class = c("ledgr_corporate_action_policy", "list")
  )
}

#' @rdname ledgr_corporate_action_policy
#' @export
ledgr_corporate_actions_research <- function() {
  ledgr_corporate_actions()
}

#' @rdname ledgr_corporate_action_policy
#' @export
ledgr_corporate_actions_strict <- function() {
  ledgr_corporate_actions(
    cash_amount = "refuse",
    cash_posting = "refuse",
    held_terminal_position = "refuse",
    unsupported_quantity = "refuse"
  )
}

ledgr_validate_corporate_action_policy <- function(policy) {
  if (!inherits(policy, "ledgr_corporate_action_policy") ||
      !identical(policy$policy_schema_version, 1L)) {
    rlang::abort(
      "`corporate_action_policy` must be created by a ledgr corporate-action policy constructor.",
      class = c("ledgr_invalid_corporate_action_policy", "ledgr_invalid_args")
    )
  }
  expected <- ledgr_corporate_actions(
    cash_amount = policy$cash_amount,
    cash_posting = policy$cash_posting,
    held_terminal_position = policy$held_terminal_position,
    unsupported_quantity = policy$unsupported_quantity
  )
  if (!identical(policy$identity, expected$identity)) {
    rlang::abort(
      "Corporate-action policy identity does not match its declared choices.",
      class = c("ledgr_invalid_corporate_action_policy", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_corporate_action_policy_identity <- function(policy) {
  ledgr_validate_corporate_action_policy(policy)
  list(
    policy_schema_version = policy$policy_schema_version,
    cash_amount = policy$identity$cash_amount,
    cash_posting = policy$identity$cash_posting,
    held_terminal_position = policy$identity$held_terminal_position,
    unsupported_quantity = policy$identity$unsupported_quantity
  )
}

ledgr_validate_corporate_action_policy_identity <- function(identity) {
  if (!is.list(identity) || !identical(identity$policy_schema_version, 1L)) {
    rlang::abort(
      "Config field corporate_actions must contain a versioned policy identity.",
      class = "ledgr_invalid_config"
    )
  }
  fields <- names(ledgr_corporate_action_policy_choices())
  valid <- vapply(fields, function(field) {
    value <- identity[[field]]
    is.character(value) && length(value) == 1L && !is.na(value) &&
      value %in% ledgr_corporate_action_policy_ids()[[field]]
  }, logical(1))
  if (!all(valid) || !identical(sort(names(identity)), sort(c("policy_schema_version", fields)))) {
    rlang::abort(
      "Config field corporate_actions contains an unknown or incomplete policy identity.",
      class = "ledgr_invalid_config"
    )
  }
  invisible(TRUE)
}
