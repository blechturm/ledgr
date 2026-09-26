#' Simulate a composable point-in-time input bundle
#'
#' Creates one deterministic, offline input unit containing a declared session
#' calendar, matching OHLCV observations, instrument metadata, and raw input
#' frames for ledgr's five point-in-time fact constructors. The calendar is
#' created before the observations: sessions are never inferred from bars.
#'
#' @param instrument_ids Unique, non-empty synthetic instrument identifiers.
#' @param from,to Inclusive civil-date bounds.
#' @param seed Integer seed controlling only generated numeric bar content.
#' @param venue_id,universe_id Stable identifiers for the synthetic venue and
#'   membership universe.
#' @param timezone IANA timezone used for the synthetic venue calendar.
#' @param session_open,session_close Local `HH:MM:SS` session times.
#' @param cases Character vector selecting from `"venue_closure"`,
#'   `"missing_observation"`, `"delisting"`, `"halt"`, and
#'   `"cash_dividend"`.
#' @param knowledge Named character vector selecting `"evidenced"` or
#'   `"assume_effective"` separately for sessions, membership, lifetime, and
#'   trading status. Corporate-action rows always carry explicit evidence
#'   clocks.
#' @param include_instruments Whether to include the optional instrument master.
#'
#' @return An ordinary named list. `bars`, `instruments`, `sessions`,
#'   `membership`, `lifetime`, `trading_status`, and `corporate_actions` are
#'   plain data frames; `recipe` records constructor arguments and scope IDs;
#'   and `cases` locates each applied teaching case. When `cash_dividend` is
#'   disabled, `corporate_actions` is an empty data frame and its recipe entry
#'   is marked disabled.
#'
#' @details
#' The default cases require at least four instruments and ten weekdays in the
#' requested window. They add one weekday venue closure, one missing observation
#' on a declared open session, one delisting, one halt whose knowledge arrives
#' after its effective time, and one validated gross cash dividend. Effective
#' intervals are half-open. Missing knowledge stays audit-only under
#' `"evidenced"`; selecting `"assume_effective"` is recorded in the recipe and
#' delegates that substitution to the public fact constructor.
#'
#' A changed seed changes prices and volumes, not calendar, facts, case
#' placement, columns, or scope. The returned facts and bars belong together;
#' they are not a fact overlay for an unrelated observation panel.
#'
#' @examples
#' inputs <- ledgr_sim_pit_inputs(
#'   instrument_ids = paste0("EX", 1:4),
#'   from = "2020-01-01",
#'   to = "2020-01-31",
#'   seed = 7
#' )
#' names(inputs)
#' inputs$cases
#' @export
ledgr_sim_pit_inputs <- function(
    instrument_ids,
    from,
    to,
    seed = 1L,
    venue_id = "DEMO_VENUE",
    universe_id = "DEMO_UNIVERSE",
    timezone = "UTC",
    session_open = "09:30:00",
    session_close = "16:00:00",
    cases = c(
      "venue_closure", "missing_observation", "delisting", "halt",
      "cash_dividend"
    ),
    knowledge = c(
      sessions = "evidenced",
      membership = "evidenced",
      lifetime = "evidenced",
      trading_status = "evidenced"
    ),
    include_instruments = TRUE) {
  instrument_ids <- ledgr_sim_pit_ids(instrument_ids)
  from <- ledgr_sim_pit_date(from, "from")
  to <- ledgr_sim_pit_date(to, "to")
  if (to < from) {
    ledgr_sim_pit_abort("`to` must be on or after `from`.")
  }
  seed <- ledgr_sim_integer_scalar(seed, "seed")
  venue_id <- ledgr_fact_scalar_id(venue_id, "venue_id")
  universe_id <- ledgr_fact_scalar_id(universe_id, "universe_id")
  timezone <- ledgr_fact_timezone(timezone)
  ledgr_sim_pit_session_hour(session_open, "session_open")
  ledgr_sim_pit_session_hour(session_close, "session_close")
  if (!is.logical(include_instruments) || length(include_instruments) != 1L ||
      is.na(include_instruments)) {
    ledgr_sim_pit_abort("`include_instruments` must be TRUE or FALSE.")
  }
  cases <- ledgr_sim_pit_cases(cases)
  knowledge <- ledgr_sim_pit_knowledge(knowledge)

  dates <- seq(from, to, by = "day")
  weekday <- !as.POSIXlt(dates, tz = "UTC")$wday %in% c(0L, 6L)
  weekdays <- dates[weekday]
  required_weekday <- c(
    venue_closure = 4L,
    missing_observation = 7L,
    cash_dividend = 9L,
    delisting = 10L,
    halt = 6L
  )
  required_instrument <- c(
    venue_closure = 0L,
    missing_observation = 4L,
    delisting = 1L,
    halt = 2L,
    cash_dividend = 3L
  )
  needed_days <- if (length(cases) == 0L) 2L else max(required_weekday[cases])
  needed_instruments <- if (length(cases) == 0L) 1L else {
    max(1L, required_instrument[cases])
  }
  if (length(weekdays) < needed_days ||
      length(instrument_ids) < needed_instruments) {
    rlang::abort(
      sprintf(
        paste(
          "Requested cases need at least %d instrument(s) and %d weekdays;",
          "received %d and %d."
        ),
        needed_instruments,
        needed_days,
        length(instrument_ids),
        length(weekdays)
      ),
      class = c("ledgr_sim_pit_insufficient_shape", "ledgr_invalid_args")
    )
  }

  closure_date <- if ("venue_closure" %in% cases) weekdays[[4L]] else as.Date(NA)
  status <- ifelse(weekday & dates != closure_date, "open", "closed")
  sessions <- data.frame(
    session_date = dates,
    status = status,
    session_open = ifelse(status == "open", session_open, NA_character_),
    session_close = ifelse(status == "open", session_close, NA_character_),
    knowledge_time = ledgr_sim_pit_session_knowledge(
      dates,
      timezone,
      knowledge[["sessions"]]
    ),
    source = "ledgr_sim_pit",
    stringsAsFactors = FALSE
  )
  session_close_utc <- ledgr_session_times(
    sessions$session_close,
    sessions$session_date,
    timezone,
    "session_close"
  )
  open_rows <- sessions$status == "open"
  open_dates <- sessions$session_date[open_rows]
  open_closes <- session_close_utc[open_rows]

  bars <- ledgr_sim_pit_bars(instrument_ids, open_closes, seed)
  missing_date <- if ("missing_observation" %in% cases) weekdays[[7L]] else as.Date(NA)
  if (!is.na(missing_date)) {
    missing_close <- session_close_utc[sessions$session_date == missing_date]
    keep <- !(bars$instrument_id == instrument_ids[[4L]] &
      bars$ts_utc == missing_close)
    bars <- bars[keep, , drop = FALSE]
    rownames(bars) <- NULL
  }

  instruments <- if (isTRUE(include_instruments)) {
    data.frame(
      instrument_id = instrument_ids,
      symbol = instrument_ids,
      currency = "USD",
      asset_class = "EQUITY",
      multiplier = 1,
      tick_size = 0.01,
      stringsAsFactors = FALSE
    )
  } else {
    NULL
  }

  first_close <- open_closes[[1L]]
  prior_knowledge <- as.POSIXct(
    paste(from - 1, "00:00:00"),
    tz = timezone
  )
  membership <- data.frame(
    effective_from = rep(first_close, length(instrument_ids)),
    knowledge_time = ledgr_sim_pit_knowledge_column(
      rep(prior_knowledge, length(instrument_ids)),
      knowledge[["membership"]]
    ),
    instrument_id = instrument_ids,
    source = "ledgr_sim_pit",
    stringsAsFactors = FALSE
  )

  lifetime <- ledgr_sim_pit_lifetime(
    instrument_ids,
    first_close,
    prior_knowledge,
    weekdays,
    session_close_utc,
    sessions,
    cases,
    knowledge[["lifetime"]]
  )
  trading_status <- ledgr_sim_pit_status(
    instrument_ids,
    first_close,
    prior_knowledge,
    weekdays,
    session_close_utc,
    sessions,
    cases,
    knowledge[["trading_status"]]
  )
  corporate_actions <- ledgr_sim_pit_corporate_actions(
    instrument_ids,
    weekdays,
    session_close_utc,
    sessions,
    cases
  )
  case_manifest <- ledgr_sim_pit_case_manifest(
    instrument_ids,
    weekdays,
    cases
  )

  constructors <- list(
    sessions = list(
      enabled = TRUE,
      venue_id = venue_id,
      knowledge = knowledge[["sessions"]],
      timezone = timezone
    ),
    membership = list(
      enabled = TRUE,
      universe_id = universe_id,
      complete = TRUE,
      knowledge = knowledge[["membership"]]
    ),
    lifetime = list(
      enabled = TRUE,
      knowledge = knowledge[["lifetime"]]
    ),
    trading_status = list(
      enabled = TRUE,
      knowledge = knowledge[["trading_status"]]
    ),
    corporate_actions = list(
      enabled = nrow(corporate_actions) > 0L
    )
  )
  recipe <- list(
    schema_version = 1L,
    price_basis = "split_adjusted",
    scopes = list(venue_id = venue_id, universe_id = universe_id),
    knowledge = c(knowledge, corporate_actions = "evidenced"),
    constructors = constructors
  )

  list(
    bars = bars,
    instruments = instruments,
    sessions = sessions,
    membership = membership,
    lifetime = lifetime,
    trading_status = trading_status,
    corporate_actions = corporate_actions,
    recipe = recipe,
    cases = case_manifest
  )
}

ledgr_sim_pit_abort <- function(message) {
  rlang::abort(
    message,
    class = c("ledgr_sim_pit_invalid", "ledgr_invalid_args")
  )
}

ledgr_sim_pit_ids <- function(x) {
  if (!is.character(x) || length(x) == 0L || anyNA(x) ||
      any(!nzchar(trimws(x))) || anyDuplicated(x)) {
    ledgr_sim_pit_abort(
      "`instrument_ids` must contain unique, non-empty character values."
    )
  }
  enc2utf8(x)
}

ledgr_sim_pit_date <- function(x, arg) {
  out <- tryCatch(as.Date(x), error = function(error) as.Date(NA))
  if (length(out) != 1L || is.na(out)) {
    ledgr_sim_pit_abort(
      sprintf("`%s` must be coercible to one civil date.", arg)
    )
  }
  out
}

ledgr_sim_pit_session_hour <- function(x, arg) {
  if (!is.character(x) || length(x) != 1L || is.na(x) ||
      !grepl("^([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$", x)) {
    ledgr_sim_pit_abort(
      sprintf("`%s` must use one HH:MM:SS local time.", arg)
    )
  }
  invisible(x)
}

ledgr_sim_pit_cases <- function(x) {
  allowed <- c(
    "venue_closure", "missing_observation", "delisting", "halt",
    "cash_dividend"
  )
  if (!is.character(x) || anyNA(x) || any(!x %in% allowed) ||
      anyDuplicated(x)) {
    ledgr_sim_pit_abort(
      sprintf(
        "`cases` must contain unique values from: %s.",
        paste(allowed, collapse = ", ")
      )
    )
  }
  allowed[allowed %in% x]
}

ledgr_sim_pit_knowledge <- function(x) {
  required <- c("sessions", "membership", "lifetime", "trading_status")
  if (!is.character(x) || is.null(names(x)) || anyDuplicated(names(x)) ||
      !setequal(names(x), required) || anyNA(x) ||
      any(!x %in% c("evidenced", "assume_effective"))) {
    ledgr_sim_pit_abort(
      paste(
        "`knowledge` must name sessions, membership, lifetime, and",
        "trading_status, each as evidenced or assume_effective."
      )
    )
  }
  x[required]
}

ledgr_sim_pit_session_knowledge <- function(dates, timezone, mode) {
  if (identical(mode, "assume_effective")) {
    return(as.POSIXct(rep(NA_real_, length(dates)), origin = "1970-01-01", tz = "UTC"))
  }
  first_boundary <- as.POSIXct(paste(min(dates), "00:00:00"), tz = timezone)
  as.POSIXct(
    rep(as.numeric(first_boundary - 1), length(dates)),
    origin = "1970-01-01",
    tz = "UTC"
  )
}

ledgr_sim_pit_knowledge_column <- function(x, mode) {
  if (identical(mode, "assume_effective")) {
    return(as.POSIXct(rep(NA_real_, length(x)), origin = "1970-01-01", tz = "UTC"))
  }
  as.POSIXct(x, origin = "1970-01-01", tz = "UTC")
}

ledgr_sim_pit_time_for_date <- function(date, session_close_utc, sessions) {
  session_close_utc[match(date, sessions$session_date)]
}

ledgr_sim_pit_bars <- function(instrument_ids, closes, seed) {
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old_seed <- if (had_seed) {
    get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  } else {
    NULL
  }
  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  set.seed(seed)

  n_session <- length(closes)
  n_instrument <- length(instrument_ids)
  common <- stats::rnorm(n_session, 0.0003, 0.006)
  innovations <- matrix(
    stats::rnorm(n_session * n_instrument, 0, 0.009),
    nrow = n_session,
    ncol = n_instrument
  )
  drift <- rep(seq(-0.00005, 0.00005, length.out = n_instrument),
    each = n_session
  )
  returns <- matrix(rep(common, n_instrument), nrow = n_session) * 0.5 +
    innovations + matrix(drift, nrow = n_session)
  base <- 40 + 7 * seq_len(n_instrument)
  close <- exp(apply(returns, 2L, cumsum)) *
    matrix(rep(base, each = n_session), nrow = n_session)
  prior <- rbind(base, close[-n_session, , drop = FALSE])
  open <- prior * exp(matrix(
    stats::rnorm(n_session * n_instrument, 0, 0.002),
    nrow = n_session
  ))
  spread <- abs(matrix(
    stats::rnorm(n_session * n_instrument, 0.003, 0.001),
    nrow = n_session
  ))
  high <- pmax(open, close) * (1 + spread)
  low <- pmax(0.01, pmin(open, close) * (1 - spread))
  volume <- pmax(1, round(matrix(
    stats::rnorm(n_session * n_instrument, 250000, 40000),
    nrow = n_session
  )))

  data.frame(
    ts_utc = rep(closes, n_instrument),
    instrument_id = rep(instrument_ids, each = n_session),
    open = as.vector(open),
    high = as.vector(high),
    low = as.vector(low),
    close = as.vector(close),
    volume = as.vector(volume),
    stringsAsFactors = FALSE
  )
}

ledgr_sim_pit_lifetime <- function(instrument_ids,
                                   first_close,
                                   prior_knowledge,
                                   weekdays,
                                   session_close_utc,
                                   sessions,
                                   cases,
                                   mode) {
  effective_to <- as.POSIXct(
    rep(NA_real_, length(instrument_ids)),
    origin = "1970-01-01",
    tz = "UTC"
  )
  if ("delisting" %in% cases) {
    effective_to[[1L]] <- ledgr_sim_pit_time_for_date(
      weekdays[[10L]], session_close_utc, sessions
    )
  }
  rows <- data.frame(
    instrument_id = instrument_ids,
    effective_from = rep(first_close, length(instrument_ids)),
    effective_to = effective_to,
    knowledge_time = ledgr_sim_pit_knowledge_column(
      rep(prior_knowledge, length(instrument_ids)), mode
    ),
    assertion = "known_active",
    terminal_event = NA_character_,
    source = "ledgr_sim_pit",
    stringsAsFactors = FALSE
  )
  if ("delisting" %in% cases) {
    inactive_at <- effective_to[[1L]]
    inactive <- data.frame(
      instrument_id = instrument_ids[[1L]],
      effective_from = inactive_at,
      effective_to = as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"),
      knowledge_time = ledgr_sim_pit_knowledge_column(inactive_at, mode),
      assertion = "known_inactive",
      terminal_event = "delisted",
      source = "ledgr_sim_pit",
      stringsAsFactors = FALSE
    )
    rows <- rbind(rows, inactive)
  }
  rows
}

ledgr_sim_pit_status <- function(instrument_ids,
                                 first_close,
                                 prior_knowledge,
                                 weekdays,
                                 session_close_utc,
                                 sessions,
                                 cases,
                                 mode) {
  rows <- data.frame(
    instrument_id = instrument_ids,
    effective_from = rep(first_close, length(instrument_ids)),
    effective_to = as.POSIXct(
      rep(NA_real_, length(instrument_ids)),
      origin = "1970-01-01",
      tz = "UTC"
    ),
    knowledge_time = ledgr_sim_pit_knowledge_column(
      rep(prior_knowledge, length(instrument_ids)), mode
    ),
    status = "active",
    source = "ledgr_sim_pit",
    stringsAsFactors = FALSE
  )
  if (!("halt" %in% cases)) return(rows)

  halt_from <- ledgr_sim_pit_time_for_date(
    weekdays[[3L]], session_close_utc, sessions
  )
  halt_to <- ledgr_sim_pit_time_for_date(
    weekdays[[6L]], session_close_utc, sessions
  )
  known_at <- ledgr_sim_pit_time_for_date(
    weekdays[[5L]], session_close_utc, sessions
  )
  rows$effective_to[rows$instrument_id == instrument_ids[[2L]]] <- halt_from
  extra <- data.frame(
    instrument_id = rep(instrument_ids[[2L]], 2L),
    effective_from = c(halt_from, halt_to),
    effective_to = as.POSIXct(
      c(as.numeric(halt_to), NA_real_),
      origin = "1970-01-01",
      tz = "UTC"
    ),
    knowledge_time = ledgr_sim_pit_knowledge_column(
      c(known_at, halt_to), mode
    ),
    status = c("halted", "active"),
    source = "ledgr_sim_pit",
    stringsAsFactors = FALSE
  )
  rbind(rows, extra)
}

ledgr_sim_pit_corporate_actions <- function(instrument_ids,
                                             weekdays,
                                             session_close_utc,
                                             sessions,
                                             cases) {
  if (!("cash_dividend" %in% cases)) {
    return(data.frame(
      subtype = character(),
      parent_instrument_id = character(),
      entitlement_time = as.POSIXct(character(), tz = "UTC"),
      effective_time = as.POSIXct(character(), tz = "UTC"),
      knowledge_time = as.POSIXct(character(), tz = "UTC"),
      payment_time = as.POSIXct(character(), tz = "UTC"),
      complete = logical(),
      provenance_tier = character(),
      gross_cash_per_parent_unit = numeric(),
      gross_cash_validated = logical(),
      source = character(),
      stringsAsFactors = FALSE
    ))
  }
  entitlement <- ledgr_sim_pit_time_for_date(
    weekdays[[8L]], session_close_utc, sessions
  )
  payment <- ledgr_sim_pit_time_for_date(
    weekdays[[9L]], session_close_utc, sessions
  )
  data.frame(
    subtype = "cash_dividend",
    parent_instrument_id = instrument_ids[[3L]],
    entitlement_time = entitlement,
    effective_time = entitlement,
    knowledge_time = entitlement - 86400,
    payment_time = payment,
    complete = TRUE,
    provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = 0.75,
    gross_cash_validated = TRUE,
    source = "ledgr_sim_pit",
    stringsAsFactors = FALSE
  )
}

ledgr_sim_pit_case_manifest <- function(instrument_ids, weekdays, cases) {
  definitions <- data.frame(
    type = c(
      "venue_closure", "missing_observation", "delisting", "halt",
      "cash_dividend"
    ),
    instrument_id = c(
      NA_character_, instrument_ids[pmin(4L, length(instrument_ids))],
      instrument_ids[[1L]], instrument_ids[pmin(2L, length(instrument_ids))],
      instrument_ids[pmin(3L, length(instrument_ids))]
    ),
    date = weekdays[c(4L, 7L, 10L, 3L, 8L)],
    stringsAsFactors = FALSE
  )
  out <- definitions[definitions$type %in% cases, , drop = FALSE]
  rownames(out) <- NULL
  out
}
