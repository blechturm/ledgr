# Terminal outcomes for held instruments (terminal-outcomes synthesis,
# sections 3.1, 3.2 and 3.4). A scheduled corporate-action row and a sealed
# known_inactive lifetime row both end a holding; both resolve through the
# version-2 corporate-action policy and post one atomic DISPOSITION.

ledgr_disposition_sources <- function() {
  c("corporate_action_disposition", "lifetime_terminal_disposition")
}

# Resolves each terminal holding to a disposition price or a typed outcome.
# Labels are exact sealed terminal_event values; scheduled corporate-action
# rows carry none and therefore take the map's default entry. A choice that
# needs a currently permissible mark falls back to frozen_terminal_position
# when the holding is frozen. A NULL policy (a historical config without a
# policy identity) refuses every terminal.
ledgr_terminal_resolve <- function(policy, ids, labels, valuation) {
  ids <- as.character(ids)
  labels <- as.character(labels)
  labels[is.na(labels)] <- ""
  if (is.null(policy)) {
    map <- c(default = "refuse")
    frozen_choice <- "refuse"
    haircut <- NA_real_
  } else {
    map <- policy$held_terminal_position
    frozen_choice <- policy$frozen_terminal_position
    haircut <- policy$haircut %||% NA_real_
  }
  matched <- ledgr_corporate_action_resolve_terminal(map, labels)
  choice <- unname(matched)
  matched_label <- names(matched)
  basis <- ifelse(matched_label == "default", "default", "label")

  permissible <- as.logical(valuation$permissible[ids])
  permissible[is.na(permissible)] <- FALSE
  frozen <- as.logical(valuation$frozen[ids] %||% rep(FALSE, length(ids)))
  frozen[is.na(frozen)] <- FALSE
  reference <- as.numeric(valuation$reference[ids])
  permissible_mark <- ifelse(permissible, as.numeric(valuation$mark[ids]), NA_real_)

  fallback <- choice %in% c("last_permissible", "haircut") & frozen
  choice[fallback] <- frozen_choice
  basis[fallback] <- "frozen_fallback"

  price <- rep(NA_real_, length(ids))
  take <- choice == "last_permissible"
  price[take] <- permissible_mark[take]
  take <- choice == "haircut"
  price[take] <- (1 - haircut) * permissible_mark[take]
  take <- choice == "last_mark"
  price[take] <- reference[take]
  price[choice == "write_off"] <- 0

  outcome <- rep("dispose", length(ids))
  outcome[!is.finite(price) | price < 0] <- "no_mark"
  outcome[choice == "refuse"] <- "refuse"

  held_ids <- ledgr_corporate_action_policy_ids()$held_terminal_position
  frozen_ids <- ledgr_corporate_action_policy_ids()$frozen_terminal_position
  policy_id <- unname(held_ids[choice])
  policy_id[fallback] <- unname(frozen_ids[choice[fallback]])

  list(
    ids = ids,
    label = labels,
    matched_label = matched_label,
    choice = choice,
    basis = basis,
    price = price,
    reference = reference,
    outcome = outcome,
    policy_id = policy_id,
    haircut = haircut
  )
}

# A scheduled corporate-action row is settlement evidence, not a modeled loss
# (synthesis section 3.2, maintainer amendment 2026-10-05). It disposes at the
# evidenced mark: the permissible mark, or the frozen last close when the
# holding is frozen. Only an explicit last_mark default or refuse changes that;
# haircut, write_off and frozen_terminal_position never apply here.
ledgr_terminal_resolve_scheduled <- function(policy, ids, valuation) {
  ids <- as.character(ids)
  default <- if (is.null(policy)) {
    "refuse"
  } else {
    unname(policy$held_terminal_position[["default"]])
  }
  choice <- if (identical(default, "last_mark")) "last_mark" else "last_permissible"
  permissible <- as.logical(valuation$permissible[ids])
  permissible[is.na(permissible)] <- FALSE
  frozen <- as.logical(valuation$frozen[ids] %||% rep(FALSE, length(ids)))
  frozen[is.na(frozen)] <- FALSE
  reference <- as.numeric(valuation$reference[ids])
  price <- if (identical(choice, "last_mark")) {
    reference
  } else {
    ifelse(permissible | frozen, as.numeric(valuation$mark[ids]), NA_real_)
  }
  outcome <- ifelse(is.finite(price) & price > 0, "dispose", "no_mark")
  if (identical(default, "refuse")) outcome[] <- "refuse"
  list(
    ids = ids,
    label = rep("", length(ids)),
    matched_label = rep("default", length(ids)),
    choice = rep(choice, length(ids)),
    basis = rep("evidence", length(ids)),
    price = price,
    reference = reference,
    outcome = outcome,
    policy_id = rep(
      unname(ledgr_corporate_action_policy_ids()$held_terminal_position[[choice]]),
      length(ids)
    ),
    haircut = NA_real_
  )
}

# Mark provenance recorded on a disposition. A write-off uses no mark, so it
# records the assumption itself at the disposition pulse.
ledgr_terminal_mark_meta <- function(resolved, valuation, ts) {
  ids <- resolved$ids
  write_off <- resolved$choice == "write_off"
  source <- as.character(valuation$source[ids])
  source[write_off] <- "write_off"
  iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  source_ts <- iso(valuation$source_ts[ids])
  source_ts[write_off | is.na(source_ts)] <- iso(ts)
  age <- as.integer(valuation$age[ids])
  age[write_off | is.na(age)] <- 0L
  list(source = source, source_ts = source_ts, age = age)
}

# Applies one atomic block of dispositions. State, lots and the event sequence
# change only after the event rows validate and append; any failure before the
# append leaves the caller's state untouched.
ledgr_disposition_post <- function(ids,
                                   price,
                                   meta,
                                   ts,
                                   run_id,
                                   event_seq,
                                   output_handler,
                                   state_value,
                                   instrument_ids,
                                   exposure_mark = price) {
  position_names <- names(state_value$positions)
  if (is.null(position_names) &&
      length(state_value$positions) == length(instrument_ids)) {
    position_names <- instrument_ids
  }
  position_index <- match(ids, position_names)
  before <- as.numeric(state_value$positions[position_index])
  if (anyNA(position_index) || any(!is.finite(before)) || any(before == 0)) {
    rlang::abort(
      "A disposition requires a live held position.",
      class = c("ledgr_lot_state_invariant", "ledgr_invalid_state")
    )
  }
  if (anyDuplicated(ids)) {
    rlang::abort(
      "One pulse cannot dispose the same parent instrument more than once.",
      class = c("ledgr_duplicate_corporate_action_event", "ledgr_invalid_fold_execution")
    )
  }

  candidate <- state_value
  realized <- numeric(length(ids))
  for (k in seq_along(ids)) {
    lot_result <- ledgr_lot_apply_fill(
      candidate$lot_state,
      instrument_id = ids[[k]],
      side = if (before[[k]] > 0) "SELL" else "BUY",
      qty = abs(before[[k]]),
      price = price[[k]],
      fee = 0,
      allow_zero_price = TRUE
    )
    candidate$lot_state <- lot_result$state
    realized[[k]] <- as.numeric(lot_result$realized_delta)
    candidate$positions[[position_index[[k]]]] <- 0
    candidate$cash <- as.numeric(candidate$cash) + before[[k]] * price[[k]]
  }
  remaining_lots <- vapply(
    ids,
    function(id) ledgr_lot_count(candidate$lot_state, id),
    integer(1)
  )
  if (any(remaining_lots != 0L)) {
    rlang::abort(
      "Disposition left live lots after reaching zero position.",
      class = c("ledgr_lot_state_invariant", "ledgr_invalid_state")
    )
  }

  cash_delta <- before * price
  exposure <- abs(before * ifelse(is.finite(exposure_mark), exposure_mark, price))
  meta_json <- vapply(seq_along(ids), function(k) {
    canonical_json(c(meta[[k]], list(
      quantity = abs(before[[k]]),
      mark = price[[k]],
      position_before = before[[k]],
      position_after = 0,
      position_delta = -before[[k]],
      cash_delta = cash_delta[[k]],
      realized_model_pnl = realized[[k]],
      affected_marked_exposure = exposure[[k]]
    )))
  }, character(1))
  seq_value <- as.integer(event_seq) + seq_along(ids) - 1L
  event_rows <- data.frame(
    event_id = paste0(run_id, "_", sprintf("%08d", seq_value)),
    run_id = rep(run_id, length(ids)),
    ts_utc = rep(ts, length(ids)),
    event_type = rep("DISPOSITION", length(ids)),
    instrument_id = ids,
    side = rep(NA_character_, length(ids)),
    qty = abs(before),
    price = price,
    fee = rep(0, length(ids)),
    meta_json = meta_json,
    event_seq = seq_value,
    stringsAsFactors = FALSE
  )
  ledgr_prepare_accounting_events(event_rows, instrument_ids)
  output_handler$append_event_rows(event_rows)
  list(
    state = candidate,
    next_event_seq = as.integer(event_seq) + nrow(event_rows),
    dispositions = as.integer(nrow(event_rows)),
    before = before,
    realized = realized,
    event_seq = seq_value
  )
}

# Summary key for every recorded disposition policy id: held-terminal choices
# (v002 and the historical v001) and frozen-terminal fallbacks.
ledgr_terminal_policy_id_keys <- function() {
  ids <- ledgr_corporate_action_policy_ids()
  held <- c(ids$held_terminal_position, ledgr_corporate_action_policy_ids_v1()$held_terminal_position)
  frozen <- ids$frozen_terminal_position
  stats::setNames(
    c(paste0("held_terminal_position.", names(held)), paste0("frozen_terminal_position.", names(frozen))),
    c(unname(held), unname(frozen))
  )
}

# Plain-language status of one terminal outcome. Settlement evidence is
# "evidence"; an exact sealed label match is "declared"; the map's default
# entry and the frozen fallback are "default".
ledgr_terminal_assumption_label <- function(choice, assumption, haircut = NA_real_) {
  describe <- c(
    last_permissible = "last permissible mark",
    last_mark = "last observed mark",
    write_off = "assumed worthless"
  )
  text <- unname(describe[choice])
  is_haircut <- choice == "haircut"
  text[is_haircut] <- sprintf(
    "%s%% haircut of the permissible mark",
    format(100 * haircut[is_haircut], trim = TRUE)
  )
  paste0(assumption, ": ", text)
}

ledgr_terminal_outcome_rows <- function(events, meta) {
  empty <- tibble::tibble(
    ts_utc = as.POSIXct(character(), tz = "UTC"),
    instrument_id = character(),
    source = character(),
    source_fact_id = character(),
    terminal_event = character(),
    matched_label = character(),
    choice = character(),
    basis = character(),
    assumption = character(),
    assumption_label = character(),
    disposition_policy_id = character(),
    quantity = numeric(),
    price = numeric(),
    proceeds = numeric(),
    realized_model_pnl = numeric(),
    haircut_fraction = numeric()
  )
  if (length(meta) == 0L) return(empty)
  field <- function(name, default, type) {
    vapply(meta, function(m) {
      value <- m[[name]]
      if (is.null(value) || length(value) != 1L) default else type(value)
    }, type(default))
  }
  keys <- ledgr_terminal_policy_id_keys()
  policy_id <- field("disposition_policy_id", NA_character_, as.character)
  # Events recorded before choice and basis were persisted derive the choice
  # from the policy id; a scheduled row is always settlement evidence.
  key_choice <- sub("^[a-z_]+[.]", "", unname(keys[policy_id]))
  choice <- field("disposition_choice", NA_character_, as.character)
  choice[is.na(choice)] <- key_choice[is.na(choice)]
  source <- field("source", NA_character_, as.character)
  basis <- field("disposition_basis", NA_character_, as.character)
  basis[is.na(basis) & source == "corporate_action_disposition"] <- "evidence"
  basis[is.na(basis)] <- "default"
  assumption <- ifelse(
    basis == "evidence",
    "evidence",
    ifelse(basis == "label", "declared", "default")
  )
  haircut <- field("haircut_fraction", NA_real_, as.numeric)
  tibble::tibble(
    ts_utc = as.POSIXct(events$ts_utc, tz = "UTC"),
    instrument_id = as.character(events$instrument_id),
    source = ifelse(source == "corporate_action_disposition", "scheduled_evidence", "lifetime_terminal"),
    source_fact_id = field("source_fact_id", NA_character_, as.character),
    terminal_event = field("terminal_event", NA_character_, as.character),
    matched_label = field("matched_label", NA_character_, as.character),
    choice = choice,
    basis = basis,
    assumption = assumption,
    assumption_label = ledgr_terminal_assumption_label(choice, assumption, haircut),
    disposition_policy_id = policy_id,
    quantity = as.numeric(events$qty),
    price = as.numeric(events$price),
    proceeds = field("cash_delta", NA_real_, as.numeric),
    realized_model_pnl = field("realized_model_pnl", NA_real_, as.numeric),
    haircut_fraction = haircut
  )
}

# The argument that produced an assumed terminal outcome, named for warnings.
ledgr_terminal_assumption_argument <- function(choice, basis, matched_label) {
  ifelse(
    basis == "frozen_fallback",
    sprintf(
      "frozen_terminal_position = \"%s\"%s",
      choice,
      ifelse(choice == "write_off", ", the research default", "")
    ),
    ifelse(
      basis == "label",
      sprintf("held_terminal_position[\"%s\"] = \"%s\"", matched_label, choice),
      sprintf(
        "held_terminal_position default \"%s\"%s",
        choice,
        ifelse(choice == "last_permissible", ", the research default", "")
      )
    )
  )
}
