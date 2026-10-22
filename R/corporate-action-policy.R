#' Corporate-action settlement policy
#'
#' Corporate-action policy is part of experiment identity. The research preset
#' permits the bounded modeled behavior supported by ledgr; the strict preset
#' refuses every corporate-action settlement choice.
#'
#' Sealed facts are evidence; every choice below is a declared model of what
#' happened to the money. Supported settlement evidence, such as a complete
#' acquisition or distribution fact, is applied as recorded and always outranks
#' a modeled terminal outcome. The modeled choices only decide what ledgr
#' assumes when a held instrument ends without that evidence:
#'
#' - `"last_permissible"` disposes at the mark that is permissible at the
#'   terminal pulse.
#' - `"last_mark"` disposes at the last observed mark, however old. This is an
#'   explicit unbounded last-observation assumption.
#' - `"haircut"` disposes at `(1 - haircut)` times the permissible mark.
#' - `"write_off"` disposes for zero proceeds. It is a conservative assumption,
#'   not evidence that the security was worthless.
#' - `"refuse"` models nothing and stops the run `INCOMPLETE`.
#'
#' `held_terminal_position` accepts either one choice, which applies to every
#' terminal, or an ordered named character map such as
#' `c(bankruptcy = "write_off", default = "last_permissible")`. Names other
#' than `default` match exact sealed `terminal_event` labels byte for byte;
#' an unmatched label takes the required `default` entry. ledgr does not trim,
#' case-fold or interpret vendor synonyms, so exact label normalization belongs
#' upstream in the adapter that seals the facts. Map order, labels, choices and
#' the haircut fraction all enter identity.
#'
#' `frozen_terminal_position` is consulted only when the selected terminal
#' choice needs a currently permissible mark and the holding is already frozen
#' beyond its valuation horizon. Its research default `"write_off"` is reported
#' as an assumption; the strict preset refuses.
#'
#' The policy object and its stored identity use `policy_schema_version` 2.
#'
#' @param cash_amount One of `"gross"` or `"refuse"`.
#' @param cash_posting One of `"effective_close"`, `"next_open"`, or
#'   `"refuse"`.
#' @param held_terminal_position One of `"last_permissible"`, `"last_mark"`,
#'   `"haircut"`, `"write_off"`, or `"refuse"`, or an ordered named character
#'   map of exact terminal labels to those choices with a required `default`
#'   entry.
#' @param unsupported_quantity One of `"report_only"` or `"refuse"`. Applies
#'   to held quantity legs (stock and mixed acquisitions, spin-offs), to held
#'   facts ledgr does not model (a subtype outside the supported set, or an
#'   acquisition in a dense run) and to held refused facts (`complete =
#'   FALSE`), whose parent was held when the fact was entitled.
#' @param frozen_terminal_position One of `"write_off"`, `"last_mark"`, or
#'   `"refuse"`. Applies to a terminal reached while the holding is frozen.
#' @param haircut One finite fraction in `[0, 1]`, required when and only when
#'   `held_terminal_position` selects `"haircut"`.
#'
#' @return A validated `ledgr_corporate_action_policy` object.
#' @name ledgr_corporate_action_policy
NULL

ledgr_corporate_action_policy_schema_version <- 2L

ledgr_corporate_action_policy_choices <- function() {
  list(
    cash_amount = c("gross", "refuse"),
    cash_posting = c("effective_close", "next_open", "refuse"),
    held_terminal_position = c(
      "last_permissible", "last_mark", "haircut", "write_off", "refuse"
    ),
    unsupported_quantity = c("report_only", "refuse"),
    frozen_terminal_position = c("write_off", "last_mark", "refuse")
  )
}

# Held-terminal choices are v002 because their trigger widens from scheduled
# corporate-action rows to sealed lifetime terminals. Unsupported-quantity
# choices are v002 because their trigger widens to held refused
# (complete = FALSE) facts (Cut 17 LDG-3089). The other fields keep their
# v001 meaning.
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
      last_permissible = "ledgr.corporate_action.held_terminal_position.last_permissible.v002",
      last_mark = "ledgr.corporate_action.held_terminal_position.last_mark.v002",
      haircut = "ledgr.corporate_action.held_terminal_position.haircut.v002",
      write_off = "ledgr.corporate_action.held_terminal_position.write_off.v002",
      refuse = "ledgr.corporate_action.held_terminal_position.refuse.v002"
    ),
    unsupported_quantity = c(
      report_only = "ledgr.corporate_action.unsupported_quantity.report_only.v002",
      refuse = "ledgr.corporate_action.unsupported_quantity.refuse.v002"
    ),
    frozen_terminal_position = c(
      write_off = "ledgr.corporate_action.frozen_terminal_position.write_off.v001",
      last_mark = "ledgr.corporate_action.frozen_terminal_position.last_mark.v001",
      refuse = "ledgr.corporate_action.frozen_terminal_position.refuse.v001"
    )
  )
}

ledgr_corporate_action_policy_abort <- function(message) {
  rlang::abort(
    message,
    class = c("ledgr_invalid_corporate_action_policy", "ledgr_invalid_args")
  )
}

ledgr_corporate_action_choice <- function(value, field) {
  allowed <- ledgr_corporate_action_policy_choices()[[field]]
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !is.null(names(value)) || !value %in% allowed) {
    ledgr_corporate_action_policy_abort(sprintf(
      "Corporate-action policy `%s` must be exactly one of: %s.",
      field,
      paste(sprintf('"%s"', allowed), collapse = ", ")
    ))
  }
  value
}

ledgr_corporate_action_terminal_map <- function(value) {
  allowed <- ledgr_corporate_action_policy_choices()$held_terminal_position
  if (!is.character(value) || length(value) < 1L || anyNA(value)) {
    ledgr_corporate_action_policy_abort(paste0(
      "Corporate-action policy `held_terminal_position` must be one choice ",
      "or a named character map of exact terminal labels to choices."
    ))
  }
  labels <- names(value)
  if (is.null(labels)) {
    if (length(value) != 1L) {
      ledgr_corporate_action_policy_abort(paste0(
        "A `held_terminal_position` map must name every entry with an exact ",
        "terminal label or `default`."
      ))
    }
    labels <- "default"
  }
  if (anyNA(labels) || !all(nzchar(labels))) {
    ledgr_corporate_action_policy_abort(paste0(
      "A `held_terminal_position` map must name every entry with an exact ",
      "terminal label or `default`."
    ))
  }
  if (anyDuplicated(labels)) {
    ledgr_corporate_action_policy_abort(sprintf(
      "A `held_terminal_position` map repeats label(s): %s.",
      paste(sprintf('"%s"', unique(labels[duplicated(labels)])), collapse = ", ")
    ))
  }
  if (!"default" %in% labels) {
    ledgr_corporate_action_policy_abort(paste0(
      "A `held_terminal_position` map requires a `default` entry. Labels are ",
      "matched exactly; ledgr does not treat any other label as the default."
    ))
  }
  unknown <- !value %in% allowed
  if (any(unknown)) {
    ledgr_corporate_action_policy_abort(sprintf(
      "Corporate-action policy `held_terminal_position` must map each label to exactly one of: %s.",
      paste(sprintf('"%s"', allowed), collapse = ", ")
    ))
  }
  stats::setNames(unname(value), labels)
}

ledgr_corporate_action_haircut <- function(haircut, map) {
  if (!any(map == "haircut")) {
    if (!is.null(haircut)) {
      ledgr_corporate_action_policy_abort(
        '`haircut` is supplied, but no `held_terminal_position` entry selects "haircut".'
      )
    }
    return(NULL)
  }
  if (!is.numeric(haircut) || length(haircut) != 1L || is.na(haircut) ||
      !is.finite(haircut) || haircut < 0 || haircut > 1 ||
      !is.null(names(haircut))) {
    ledgr_corporate_action_policy_abort(paste0(
      '`haircut` must be one finite fraction in [0, 1] when ',
      '`held_terminal_position` selects "haircut".'
    ))
  }
  as.numeric(haircut)
}

#' @rdname ledgr_corporate_action_policy
#' @export
ledgr_corporate_actions <- function(cash_amount = "gross",
                                    cash_posting = "effective_close",
                                    held_terminal_position = "last_permissible",
                                    unsupported_quantity = "report_only",
                                    frozen_terminal_position = "write_off",
                                    haircut = NULL) {
  map <- ledgr_corporate_action_terminal_map(held_terminal_position)
  values <- list(
    cash_amount = ledgr_corporate_action_choice(cash_amount, "cash_amount"),
    cash_posting = ledgr_corporate_action_choice(cash_posting, "cash_posting"),
    held_terminal_position = map,
    unsupported_quantity = ledgr_corporate_action_choice(
      unsupported_quantity,
      "unsupported_quantity"
    ),
    frozen_terminal_position = ledgr_corporate_action_choice(
      frozen_terminal_position,
      "frozen_terminal_position"
    )
  )
  haircut <- ledgr_corporate_action_haircut(haircut, map)
  ids <- ledgr_corporate_action_policy_ids()
  identity <- list(
    cash_amount = unname(ids$cash_amount[[values$cash_amount]]),
    cash_posting = unname(ids$cash_posting[[values$cash_posting]]),
    held_terminal_position = list(
      labels = names(map),
      policy_ids = unname(ids$held_terminal_position[map])
    ),
    unsupported_quantity = unname(
      ids$unsupported_quantity[[values$unsupported_quantity]]
    ),
    frozen_terminal_position = unname(
      ids$frozen_terminal_position[[values$frozen_terminal_position]]
    )
  )
  if (!is.null(haircut)) {
    identity$haircut_fraction <- haircut
  }
  structure(
    c(
      list(policy_schema_version = ledgr_corporate_action_policy_schema_version),
      values,
      list(haircut = haircut, identity = identity)
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
    unsupported_quantity = "refuse",
    frozen_terminal_position = "refuse"
  )
}

ledgr_validate_corporate_action_policy <- function(policy) {
  if (!inherits(policy, "ledgr_corporate_action_policy") ||
      !identical(
        policy$policy_schema_version,
        ledgr_corporate_action_policy_schema_version
      )) {
    ledgr_corporate_action_policy_abort(
      "`corporate_action_policy` must be created by a ledgr corporate-action policy constructor."
    )
  }
  expected <- ledgr_corporate_actions(
    cash_amount = policy$cash_amount,
    cash_posting = policy$cash_posting,
    held_terminal_position = policy$held_terminal_position,
    unsupported_quantity = policy$unsupported_quantity,
    frozen_terminal_position = policy$frozen_terminal_position,
    haircut = policy$haircut
  )
  if (!identical(unclass(policy), unclass(expected))) {
    ledgr_corporate_action_policy_abort(
      "Corporate-action policy identity does not match its declared choices."
    )
  }
  invisible(TRUE)
}

ledgr_corporate_action_policy_identity <- function(policy) {
  ledgr_validate_corporate_action_policy(policy)
  c(
    list(policy_schema_version = policy$policy_schema_version),
    policy$identity
  )
}

# Rebuilds the schema-2 policy that a stored identity names. Any unknown id,
# malformed map or misplaced field fails rather than being interpreted.
ledgr_corporate_action_policy_from_identity <- function(identity) {
  ids <- ledgr_corporate_action_policy_ids()
  decode <- function(field) {
    value <- identity[[field]]
    if (!is.character(value) || length(value) != 1L || is.na(value) ||
        !value %in% ids[[field]]) {
      stop("unknown policy id", call. = FALSE)
    }
    names(ids[[field]])[[match(value, ids[[field]])]]
  }
  held <- identity$held_terminal_position
  if (!is.list(held) ||
      !identical(sort(names(held)), c("labels", "policy_ids")) ||
      !is.character(held$labels) || !is.character(held$policy_ids) ||
      length(held$labels) != length(held$policy_ids) ||
      anyNA(held$policy_ids) ||
      !all(held$policy_ids %in% ids$held_terminal_position)) {
    stop("malformed held-terminal map", call. = FALSE)
  }
  map <- stats::setNames(
    names(ids$held_terminal_position)[
      match(held$policy_ids, ids$held_terminal_position)
    ],
    held$labels
  )
  ledgr_corporate_actions(
    cash_amount = decode("cash_amount"),
    cash_posting = decode("cash_posting"),
    held_terminal_position = map,
    unsupported_quantity = decode("unsupported_quantity"),
    frozen_terminal_position = decode("frozen_terminal_position"),
    haircut = if (is.null(identity$haircut_fraction)) {
      NULL
    } else {
      as.numeric(identity$haircut_fraction)
    }
  )
}

# Validates a stored corporate-action identity once and returns its policy.
ledgr_corporate_action_identity_decode <- function(identity) {
  if (!is.list(identity) ||
      !identical(
        identity$policy_schema_version,
        ledgr_corporate_action_policy_schema_version
      )) {
    rlang::abort(
      "Config field corporate_actions must contain a versioned policy identity.",
      class = "ledgr_invalid_config"
    )
  }
  invalid <- function() {
    rlang::abort(
      "Config field corporate_actions contains an unknown or incomplete policy identity.",
      class = "ledgr_invalid_config"
    )
  }
  policy <- tryCatch(
    ledgr_corporate_action_policy_from_identity(identity),
    error = function(e) NULL
  )
  if (is.null(policy)) invalid()
  # The constructor just built `policy`, so its identity needs no revalidation.
  expected <- c(
    list(policy_schema_version = policy$policy_schema_version),
    policy$identity
  )
  observed <- identity[names(expected)]
  if ("haircut_fraction" %in% names(observed)) {
    observed$haircut_fraction <- as.numeric(observed$haircut_fraction)
  }
  if (!identical(sort(names(identity)), sort(names(expected))) ||
      !identical(observed, expected)) {
    invalid()
  }
  list(schema = ledgr_corporate_action_policy_schema_version, policy = policy)
}

ledgr_corporate_action_identity_schema <- function(identity) {
  ledgr_corporate_action_identity_decode(identity)$schema
}

ledgr_validate_corporate_action_policy_identity <- function(identity) {
  ledgr_corporate_action_identity_decode(identity)
  invisible(TRUE)
}

# Resolves exact sealed terminal labels through the held-terminal map. Labels
# are matched byte for byte; unmatched or missing labels take `default`.
ledgr_corporate_action_resolve_terminal <- function(map, labels) {
  idx <- match(as.character(labels), names(map))
  idx[is.na(idx)] <- match("default", names(map))
  map[idx]
}
