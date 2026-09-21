availability_validator_capture <- function(fn, rows) {
  tryCatch(
    {
      fn(rows)
      list(ok = TRUE, classes = character(), message = "")
    },
    error = function(error) {
      list(
        ok = FALSE,
        classes = class(error),
        message = conditionMessage(error)
      )
    }
  )
}

availability_validator_intervals <- function(n) {
  if (n == 0L) {
    empty <- as.POSIXct(character(), tz = "UTC")
    return(list(from = empty, to = empty))
  }
  from <- availability_v201_at(sample.int(13L, n, replace = TRUE) - 1L)
  to <- from + sample.int(8L, n, replace = TRUE) * 86400
  if (n > 0L) {
    to[stats::runif(n) < 0.25] <- availability_v201_na_time()
  }
  list(from = from, to = to)
}

availability_validator_membership_rows <- function(n) {
  interval <- availability_validator_intervals(n)
  rows <- data.frame(
    fact_id = sprintf("membership-%03d", seq_len(n)),
    instrument_id = sample(c("AAA", "BBB", "CCC"), n, replace = TRUE),
    universe_id = sample(c("U1", "U2"), n, replace = TRUE),
    member = sample(c(TRUE, FALSE), n, replace = TRUE),
    effective_from = interval$from,
    effective_to = interval$to,
    stringsAsFactors = FALSE
  )
  if (n > 1L) rows <- rows[sample.int(n), , drop = FALSE]
  rows
}

availability_validator_lifetime_rows <- function(n) {
  interval <- availability_validator_intervals(n)
  rows <- data.frame(
    fact_id = sprintf("lifetime-%03d", seq_len(n)),
    instrument_id = sample(c("AAA", "BBB", "CCC"), n, replace = TRUE),
    assertion = sample(
      c("known_active", "known_inactive", "unknown"),
      n,
      replace = TRUE
    ),
    effective_from = interval$from,
    effective_to = interval$to,
    stringsAsFactors = FALSE
  )
  if (n > 1L) rows <- rows[sample.int(n), , drop = FALSE]
  rows
}

availability_validator_status_rows <- function(n) {
  interval <- availability_validator_intervals(n)
  fact_id <- sprintf("status-%03d", seq_len(n))
  supersedes <- rep(NA_character_, n)
  if (n > 1L) {
    involved <- which(seq_len(n) > 1L & stats::runif(n) < 0.3)
    for (i in involved) {
      supersedes[[i]] <- fact_id[[sample.int(i - 1L, 1L)]]
    }
  }
  rows <- data.frame(
    fact_id = fact_id,
    instrument_id = sample(c("AAA", "BBB", "CCC"), n, replace = TRUE),
    source = sample(c("venue", "vendor"), n, replace = TRUE),
    precedence = sample(0:2, n, replace = TRUE),
    status = sample(
      c("active", "halted", "quotation_only"),
      n,
      replace = TRUE
    ),
    effective_from = interval$from,
    effective_to = interval$to,
    supersedes_fact_id = supersedes,
    stringsAsFactors = FALSE
  )
  if (n > 1L) rows <- rows[sample.int(n), , drop = FALSE]
  rows
}

availability_validator_compare <- function(reference, production, rows) {
  identical(
    availability_validator_capture(reference, rows),
    availability_validator_capture(production, rows)
  )
}

testthat::test_that("grouped validators equal pairwise references on 2000 randomized sets", {
  withr::local_seed(20260917)
  mismatches <- character()
  for (i in seq_len(2000L)) {
    n <- sample.int(11L, 1L) - 1L
    cases <- list(
      membership = list(
        rows = availability_validator_membership_rows(n),
        reference = availability_reference_validate_membership_conflicts,
        production = ledgr:::ledgr_fact_validate_membership_conflicts
      ),
      lifetime = list(
        rows = availability_validator_lifetime_rows(n),
        reference = availability_reference_validate_lifetime_conflicts,
        production = ledgr:::ledgr_fact_validate_lifetime_conflicts
      ),
      status = list(
        rows = availability_validator_status_rows(n),
        reference = availability_reference_validate_status_conflicts,
        production = ledgr:::ledgr_fact_validate_source_conflicts
      )
    )
    for (family in names(cases)) {
      case <- cases[[family]]
      if (!availability_validator_compare(
        case$reference,
        case$production,
        case$rows
      )) {
        mismatches <- c(mismatches, sprintf("set %d: %s", i, family))
      }
    }
  }
  testthat::expect_identical(mismatches, character())
})

testthat::test_that("validator adversaries preserve interval and scope semantics", {
  at <- availability_v201_at
  na_time <- availability_v201_na_time
  membership <- list(
    empty = data.frame(
      fact_id = character(), instrument_id = character(),
      universe_id = character(), member = logical(),
      effective_from = as.POSIXct(character(), tz = "UTC"),
      effective_to = as.POSIXct(character(), tz = "UTC")
    ),
    one = data.frame(
      fact_id = "one", instrument_id = "AAA", universe_id = "U",
      member = TRUE, effective_from = at(0L), effective_to = na_time()
    ),
    same_state = data.frame(
      fact_id = c("a", "b"), instrument_id = "AAA", universe_id = "U",
      member = TRUE, effective_from = at(c(0L, 2L)),
      effective_to = c(at(10L), na_time())
    ),
    opposing = data.frame(
      fact_id = c("a", "b"), instrument_id = "AAA", universe_id = "U",
      member = c(TRUE, FALSE), effective_from = at(c(0L, 2L)),
      effective_to = c(at(10L), na_time())
    ),
    touching = data.frame(
      fact_id = c("a", "b"), instrument_id = "AAA", universe_id = "U",
      member = c(TRUE, FALSE), effective_from = at(c(0L, 10L)),
      effective_to = c(at(10L), na_time())
    ),
    nested = data.frame(
      fact_id = c("a", "b"), instrument_id = "AAA", universe_id = "U",
      member = c(TRUE, FALSE), effective_from = at(c(0L, 2L)),
      effective_to = at(c(10L, 8L))
    ),
    equal = data.frame(
      fact_id = c("a", "b"), instrument_id = "AAA", universe_id = "U",
      member = c(TRUE, FALSE), effective_from = at(c(0L, 0L)),
      effective_to = at(c(10L, 10L))
    ),
    separated_scope = data.frame(
      fact_id = c("a", "b", "c"),
      instrument_id = c("AAA", "AAA", "BBB"),
      universe_id = c("U1", "U2", "U1"),
      member = c(TRUE, FALSE, FALSE), effective_from = at(c(0L, 0L, 0L)),
      effective_to = na_time(3L)
    )
  )
  for (rows in membership) {
    testthat::expect_true(availability_validator_compare(
      availability_reference_validate_membership_conflicts,
      ledgr:::ledgr_fact_validate_membership_conflicts,
      rows[sample.int(max(1L, nrow(rows))), , drop = FALSE][seq_len(nrow(rows)), , drop = FALSE]
    ))
  }

  lifetime <- data.frame(
    fact_id = c("a", "b", "c"), instrument_id = "AAA",
    assertion = c("known_active", "known_inactive", "unknown"),
    effective_from = at(c(0L, 10L, 20L)),
    effective_to = c(at(10L), at(20L), na_time())
  )
  testthat::expect_true(availability_validator_compare(
    availability_reference_validate_lifetime_conflicts,
    ledgr:::ledgr_fact_validate_lifetime_conflicts,
    lifetime[c(3L, 1L, 2L), , drop = FALSE]
  ))
  lifetime$effective_from[[3L]] <- at(5L)
  testthat::expect_true(availability_validator_compare(
    availability_reference_validate_lifetime_conflicts,
    ledgr:::ledgr_fact_validate_lifetime_conflicts,
    lifetime[c(2L, 3L, 1L), , drop = FALSE]
  ))
})

testthat::test_that("validator scope grouping preserves exact field boundaries", {
  at <- availability_v201_at
  na_time <- availability_v201_na_time
  membership <- data.frame(
    fact_id = c("a", "b"),
    instrument_id = c("A\rB", "A"),
    universe_id = c("C", "B\rC"),
    member = c(TRUE, FALSE),
    effective_from = at(c(0L, 0L)),
    effective_to = na_time(2L),
    stringsAsFactors = FALSE
  )
  testthat::expect_true(availability_validator_compare(
    availability_reference_validate_membership_conflicts,
    ledgr:::ledgr_fact_validate_membership_conflicts,
    membership
  ))

  status <- data.frame(
    fact_id = c("a", "b"),
    instrument_id = c("A\rB", "A"),
    source = c("C", "B\rC"),
    precedence = 5L,
    status = c("active", "halted"),
    effective_from = at(c(0L, 0L)),
    effective_to = na_time(2L),
    supersedes_fact_id = NA_character_,
    stringsAsFactors = FALSE
  )
  testthat::expect_true(availability_validator_compare(
    availability_reference_validate_status_conflicts,
    ledgr:::ledgr_fact_validate_source_conflicts,
    status
  ))
})

testthat::test_that("persisted missing states raise the domain condition", {
  membership <- availability_validator_membership_rows(1L)
  membership$member[[1L]] <- NA
  lifetime <- availability_validator_lifetime_rows(1L)
  lifetime$assertion[[1L]] <- NA_character_
  status <- availability_validator_status_rows(1L)
  status$status[[1L]] <- NA_character_
  status$supersedes_fact_id[[1L]] <- "prior-fact"

  cases <- list(
    membership = list(
      fn = ledgr:::ledgr_fact_validate_membership_conflicts,
      rows = membership
    ),
    lifetime = list(
      fn = ledgr:::ledgr_fact_validate_lifetime_conflicts,
      rows = lifetime
    ),
    status = list(
      fn = ledgr:::ledgr_fact_validate_source_conflicts,
      rows = status
    )
  )
  for (name in names(cases)) {
    case <- cases[[name]]
    testthat::expect_error(
      case$fn(case$rows),
      regexp = "requires non-missing",
      class = "ledgr_fact_structural_conflict",
      info = name
    )
  }
})

availability_validator_status_shape <- function(
    ids,
    statuses,
    starts,
    ends,
    supersedes = rep(NA_character_, length(ids)),
    sources = rep("venue", length(ids)),
    precedence = rep(5L, length(ids))) {
  data.frame(
    fact_id = ids,
    instrument_id = "AAA",
    source = sources,
    precedence = precedence,
    status = statuses,
    effective_from = availability_v201_at(starts),
    effective_to = ends,
    supersedes_fact_id = supersedes,
    stringsAsFactors = FALSE
  )
}

testthat::test_that("status hybrid is exact on supersession and separation shapes", {
  at <- availability_v201_at
  na_time <- availability_v201_na_time
  shapes <- list(
    direct = availability_validator_status_shape(
      c("Y", "J"), c("active", "halted"), c(0L, 5L),
      c(at(20L), na_time()), c(NA_character_, "Y")
    ),
    source_separated = availability_validator_status_shape(
      c("Y", "Z"), c("active", "halted"), c(0L, 5L),
      c(at(20L), na_time()), sources = c("venue", "vendor")
    ),
    precedence_separated = availability_validator_status_shape(
      c("Y", "Z"), c("active", "halted"), c(0L, 5L),
      c(at(20L), na_time()), precedence = c(5L, 6L)
    ),
    xyj = availability_validator_status_shape(
      c("X", "Y", "J"), c("active", "active", "halted"),
      c(0L, 0L, 15L), c(at(10L), at(20L), na_time()),
      c(NA_character_, NA_character_, "Y")
    ),
    yz = availability_validator_status_shape(
      c("Y", "J", "Z"), c("active", "halted", "halted"),
      c(0L, 20L, 5L), c(at(20L), na_time(), at(10L)),
      c(NA_character_, "Y", NA_character_)
    )
  )
  for (name in names(shapes)) {
    rows <- shapes[[name]][sample.int(nrow(shapes[[name]])), , drop = FALSE]
    testthat::expect_true(availability_validator_compare(
      availability_reference_validate_status_conflicts,
      ledgr:::ledgr_fact_validate_source_conflicts,
      rows
    ), info = name)
  }
  testthat::expect_true(availability_validator_capture(
    ledgr:::ledgr_fact_validate_source_conflicts,
    shapes$xyj
  )$ok)
  testthat::expect_false(availability_validator_capture(
    ledgr:::ledgr_fact_validate_source_conflicts,
    shapes$yz
  )$ok)
})

availability_validator_set_fixture <- function() {
  header <- data.frame(
    universe_id = "U",
    set_id = "S1",
    effective_from = availability_v201_at(1L),
    knowledge_time = availability_v201_at(0L),
    complete = TRUE,
    provenance_json = '{"source":"vendor"}',
    stringsAsFactors = FALSE
  )
  rows <- data.frame(
    fact_id = c("set-a", "set-b"),
    instrument_id = c("AAA", "BBB"),
    universe_id = "U",
    set_id = "S1",
    effective_from = availability_v201_at(c(1L, 1L)),
    effective_to = availability_v201_na_time(2L),
    knowledge_time = availability_v201_at(c(0L, 0L)),
    member = TRUE,
    provenance_json = '{"source":"vendor"}',
    stringsAsFactors = FALSE
  )
  list(rows = rows, headers = header)
}

testthat::test_that("setwise membership bypass validates every persisted invariant", {
  fixture <- availability_validator_set_fixture()
  testthat::expect_equal(
    nrow(ledgr:::ledgr_snapshot_membership_sweep_rows(
      fixture$rows,
      fixture$headers
    )),
    0L
  )

  mutations <- list(
    member = function(x) { x$rows$member[[1L]] <- FALSE; x },
    missing_header = function(x) { x$headers <- x$headers[0, ]; x },
    header_complete = function(x) { x$headers$complete[[1L]] <- NA; x },
    duplicate_header = function(x) {
      x$headers <- rbind(x$headers, x$headers); x
    },
    scope = function(x) { x$rows$universe_id[[1L]] <- "OTHER"; x },
    set_identity = function(x) { x$rows$set_id[[1L]] <- ""; x },
    effective_from = function(x) {
      x$rows$effective_from[[1L]] <- availability_v201_at(2L); x
    },
    effective_to = function(x) {
      x$rows$effective_to[[1L]] <- availability_v201_at(3L); x
    },
    knowledge_time = function(x) {
      x$rows$knowledge_time[[1L]] <- availability_v201_at(2L); x
    },
    provenance = function(x) {
      x$rows$provenance_json[[1L]] <- '{"source":"other"}'; x
    },
    duplicate = function(x) {
      x$rows$instrument_id[[2L]] <- x$rows$instrument_id[[1L]]; x
    },
    combined = function(x) {
      x$rows$member[[1L]] <- FALSE
      x$rows$effective_to[[1L]] <- availability_v201_at(3L)
      x
    }
  )
  for (name in names(mutations)) {
    changed <- mutations[[name]](availability_validator_set_fixture())
    testthat::expect_error(
      ledgr:::ledgr_snapshot_membership_sweep_rows(
        changed$rows,
        changed$headers
      ),
      class = "ledgr_invalid_state",
      info = name
    )
  }
})

testthat::test_that("setwise membership matching uses exact field boundaries", {
  fixture <- availability_validator_set_fixture()
  fixture$headers$universe_id <- "U\rS"
  fixture$headers$set_id <- "T"
  fixture$rows <- fixture$rows[1L, , drop = FALSE]
  fixture$rows$universe_id <- "U"
  fixture$rows$set_id <- "S\rT"

  testthat::expect_error(
    ledgr:::ledgr_snapshot_membership_sweep_rows(
      fixture$rows,
      fixture$headers
    ),
    class = "ledgr_snapshot_membership_set_missing"
  )
})

testthat::test_that("mixed interval assertions enter the membership sweep", {
  fixture <- availability_validator_set_fixture()
  interval <- fixture$rows[1L, , drop = FALSE]
  interval$fact_id <- "interval-a"
  interval$set_id <- NA_character_
  interval$member <- FALSE
  interval$effective_from <- availability_v201_at(2L)
  rows <- rbind(fixture$rows, interval)
  swept <- ledgr:::ledgr_snapshot_membership_sweep_rows(rows, fixture$headers)
  testthat::expect_setequal(swept$fact_id, c("set-a", "interval-a"))
  testthat::expect_error(
    ledgr:::ledgr_fact_validate_membership_conflicts(swept),
    class = "ledgr_fact_structural_conflict"
  )

  interval$instrument_id <- "CCC"
  unrelated <- rbind(fixture$rows, interval)
  swept <- ledgr:::ledgr_snapshot_membership_sweep_rows(
    unrelated,
    fixture$headers
  )
  testthat::expect_identical(swept$fact_id, "interval-a")
})

testthat::test_that("seal validates complete sets before bypassing their rows", {
  dates <- as.Date("2024-01-02") + 0:1
  ids <- c("AAA", "BBB")
  bars <- expand.grid(
    instrument_id = ids,
    ts_utc = dates,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  bars$open <- bars$high <- bars$low <- bars$close <- 100
  bars$volume <- 1000
  membership <- ledgr_facts_membership_snapshots(
    data.frame(
      instrument_id = ids,
      effective_from = as.POSIXct("2024-01-01", tz = "UTC"),
      knowledge_time = as.POSIXct("2023-12-31", tz = "UTC"),
      source = "vendor"
    ),
    universe_id = "U",
    complete = TRUE
  )
  session_dates <- as.Date("2024-01-01") + 0:3
  weekday <- as.POSIXlt(session_dates)$wday %in% 1:5
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = session_dates,
      status = ifelse(weekday, "open", "closed"),
      session_open = ifelse(weekday, "09:30:00", NA_character_),
      session_close = ifelse(weekday, "16:00:00", NA_character_),
      knowledge_time = as.POSIXct("2023-12-01", tz = "UTC")
    ),
    "XNYS",
    timezone = "America/New_York"
  )
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = ids),
    facts = ledgr_facts(sessions, membership)
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  con <- ledgr:::get_connection(snapshot)
  id <- snapshot$snapshot_id
  testthat::expect_true(ledgr:::ledgr_snapshot_validate_availability_for_seal(
    con,
    id
  ))
  DBI::dbExecute(
    con,
    paste(
      "UPDATE snapshot_membership SET member = FALSE",
      "WHERE snapshot_id = ? AND instrument_id = 'AAA'"
    ),
    params = list(id)
  )
  testthat::expect_error(
    ledgr:::ledgr_snapshot_validate_availability_for_seal(con, id),
    class = "ledgr_snapshot_membership_set_invalid"
  )
})

testthat::test_that("seal activates the grouped membership sweep", {
  membership <- ledgr_facts_membership_snapshots(
    data.frame(
      effective_from = as.POSIXct("2020-01-01", tz = "UTC"),
      knowledge_time = as.POSIXct("2019-12-31", tz = "UTC"),
      set_id = "seal-sweep",
      members = I(list("AAA")),
      source = "test",
      stringsAsFactors = FALSE
    ),
    universe_id = "U",
    complete = TRUE
  )
  calls <- 0L
  original <- ledgr:::ledgr_snapshot_membership_sweep_rows
  testthat::local_mocked_bindings(
    ledgr_snapshot_membership_sweep_rows = function(...) {
      calls <<- calls + 1L
      original(...)
    },
    .package = "ledgr"
  )
  snapshot <- availability_runtime_fixture(membership = membership)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  testthat::expect_identical(calls, 1L)
})
