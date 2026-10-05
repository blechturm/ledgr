terminal_policy_hash <- function(policy) {
  ledgr:::config_hash(list(
    corporate_actions = ledgr:::ledgr_corporate_action_policy_identity(policy)
  ))
}

# Pre-ticket schema-1 policy blocks, read from the reviewed v0.2.0.1 run
# fixture rather than written by hand.
terminal_policy_schema1_blocks <- function() {
  identity <- utils::read.csv(
    testthat::test_path("fixtures", "availability-v0-2-0-1", "identity.csv"),
    colClasses = "character",
    stringsAsFactors = FALSE
  )
  config <- ledgr:::ledgr_json_read_config(identity$config_json[[1L]])
  list(
    corporate_actions = config$corporate_actions,
    valuation_policy = config$availability$valuation_policy
  )
}

terminal_policy_store_contents <- function(path, run_id) {
  opened <- ledgr_test_open_duckdb(path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  tables <- DBI::dbGetQuery(
    opened$con,
    paste(
      "SELECT DISTINCT table_name FROM information_schema.columns",
      "WHERE table_schema = 'main' AND column_name = 'run_id'",
      "ORDER BY table_name"
    )
  )$table_name
  stats::setNames(lapply(tables, function(table) {
    DBI::dbGetQuery(
      opened$con,
      sprintf("SELECT * FROM %s WHERE run_id = ?", table),
      params = list(run_id)
    )
  }), tables)
}

# ledgr-test-profile: fast
testthat::test_that("[LTB-0158] terminal policy schema 2 is closed and identity-complete", {
  map <- c(
    bankruptcy = "write_off",
    acquired = "haircut",
    default = "last_permissible"
  )
  policy <- ledgr_corporate_actions(held_terminal_position = map, haircut = 0.25)
  testthat::expect_identical(policy$policy_schema_version, 2L)
  testthat::expect_identical(
    policy,
    ledgr_corporate_actions(held_terminal_position = map, haircut = 0.25)
  )
  testthat::expect_identical(policy$held_terminal_position, map)
  testthat::expect_identical(policy$haircut, 0.25)
  testthat::expect_identical(
    ledgr:::ledgr_corporate_action_policy_identity(policy)$held_terminal_position,
    list(
      labels = c("bankruptcy", "acquired", "default"),
      policy_ids = c(
        "ledgr.corporate_action.held_terminal_position.write_off.v002",
        "ledgr.corporate_action.held_terminal_position.haircut.v002",
        "ledgr.corporate_action.held_terminal_position.last_permissible.v002"
      )
    )
  )
  testthat::expect_identical(
    ledgr:::ledgr_corporate_action_policy_identity(policy)$haircut_fraction,
    0.25
  )

  # One fallback choice is the map with only its default entry.
  testthat::expect_identical(
    ledgr_corporate_actions(held_terminal_position = "write_off"),
    ledgr_corporate_actions(held_terminal_position = c(default = "write_off"))
  )

  # Exact sealed labels resolve byte for byte; anything else takes default.
  testthat::expect_identical(
    unname(ledgr:::ledgr_corporate_action_resolve_terminal(
      policy$held_terminal_position,
      c("bankruptcy", "Bankruptcy", " bankruptcy", "acquired", "merger", NA, "")
    )),
    c(
      "write_off", "last_permissible", "last_permissible", "haircut",
      "last_permissible", "last_permissible", "last_permissible"
    )
  )

  # Label text, label order, choice, haircut and frozen fallback all move
  # identity. Haircut identity is numeric, so integer and double agree.
  base_hash <- terminal_policy_hash(policy)
  variants <- list(
    label_text = ledgr_corporate_actions(
      held_terminal_position = c(Bankruptcy = "write_off", acquired = "haircut", default = "last_permissible"),
      haircut = 0.25
    ),
    label_order = ledgr_corporate_actions(
      held_terminal_position = map[c(2L, 1L, 3L)],
      haircut = 0.25
    ),
    default_position = ledgr_corporate_actions(
      held_terminal_position = map[c(3L, 1L, 2L)],
      haircut = 0.25
    ),
    choice = ledgr_corporate_actions(
      held_terminal_position = c(bankruptcy = "last_mark", acquired = "haircut", default = "last_permissible"),
      haircut = 0.25
    ),
    haircut = ledgr_corporate_actions(held_terminal_position = map, haircut = 0.5),
    frozen = ledgr_corporate_actions(
      held_terminal_position = map,
      haircut = 0.25,
      frozen_terminal_position = "last_mark"
    )
  )
  variant_hashes <- vapply(variants, terminal_policy_hash, character(1))
  testthat::expect_true(all(variant_hashes != base_hash))
  testthat::expect_false(anyDuplicated(variant_hashes) > 0L)
  testthat::expect_identical(
    terminal_policy_hash(ledgr_corporate_actions(held_terminal_position = "haircut", haircut = 1L)),
    terminal_policy_hash(ledgr_corporate_actions(held_terminal_position = "haircut", haircut = 1))
  )

  # Stored identity round-trips through canonical JSON as schema 2.
  identity <- ledgr:::ledgr_corporate_action_policy_identity(policy)
  stored <- ledgr:::ledgr_json_read_config(canonical_json(identity))
  testthat::expect_identical(ledgr:::ledgr_corporate_action_identity_schema(stored), 2L)
  testthat::expect_identical(
    ledgr:::ledgr_corporate_action_policy_from_identity(stored),
    policy
  )

  # Malformed shapes fail with the existing policy vocabulary.
  invalid <- list(
    duplicate_label = list(held_terminal_position = c(a = "write_off", a = "last_mark", default = "refuse")),
    missing_default = list(held_terminal_position = c(bankruptcy = "write_off")),
    synonym_default = list(held_terminal_position = c(bankruptcy = "write_off", Default = "last_mark")),
    unknown_choice = list(held_terminal_position = c(default = "zero")),
    synonym_choice = list(held_terminal_position = "writeoff"),
    hyphen_choice = list(held_terminal_position = c(default = "write-off")),
    case_choice = list(held_terminal_position = "Write_off"),
    unnamed_map = list(held_terminal_position = c("write_off", "last_mark")),
    partly_named = list(held_terminal_position = c("write_off", default = "last_mark")),
    na_label = list(held_terminal_position = stats::setNames(c("write_off", "last_mark"), c(NA, "default"))),
    list_map = list(held_terminal_position = list(default = "write_off")),
    empty_map = list(held_terminal_position = character()),
    na_choice = list(held_terminal_position = NA_character_),
    haircut_missing = list(held_terminal_position = "haircut"),
    haircut_na = list(held_terminal_position = "haircut", haircut = NA_real_),
    haircut_inf = list(held_terminal_position = "haircut", haircut = Inf),
    haircut_negative = list(held_terminal_position = "haircut", haircut = -0.01),
    haircut_above_one = list(held_terminal_position = "haircut", haircut = 1.01),
    haircut_vector = list(held_terminal_position = "haircut", haircut = c(0.1, 0.2)),
    haircut_text = list(held_terminal_position = "haircut", haircut = "0.1"),
    haircut_unused = list(held_terminal_position = "write_off", haircut = 0.1),
    frozen_haircut = list(frozen_terminal_position = "haircut"),
    frozen_last_permissible = list(frozen_terminal_position = "last_permissible"),
    frozen_named = list(frozen_terminal_position = c(default = "write_off"))
  )
  for (case in names(invalid)) {
    testthat::expect_error(
      do.call(ledgr_corporate_actions, invalid[[case]]),
      class = "ledgr_invalid_corporate_action_policy",
      info = case
    )
  }
  testthat::expect_identical(
    ledgr_corporate_actions(held_terminal_position = "haircut", haircut = 0)$haircut,
    0
  )
  testthat::expect_identical(
    ledgr_corporate_actions(held_terminal_position = "haircut", haircut = 1)$haircut,
    1
  )

  tampered <- policy
  tampered$haircut <- 0.3
  testthat::expect_error(
    ledgr:::ledgr_validate_corporate_action_policy(tampered),
    class = "ledgr_invalid_corporate_action_policy"
  )
  tampered <- policy
  tampered$identity$held_terminal_position$labels <- c("acquired", "bankruptcy", "default")
  testthat::expect_error(
    ledgr:::ledgr_validate_corporate_action_policy(tampered),
    class = "ledgr_invalid_corporate_action_policy"
  )

  # Presets resolve the accepted ordinary and frozen defaults.
  research <- ledgr_corporate_actions_research()
  strict <- ledgr_corporate_actions_strict()
  omitted <- eval(
    formals(ledgr_experiment)$corporate_action_policy,
    envir = asNamespace("ledgr")
  )
  testthat::expect_identical(omitted, research)
  testthat::expect_identical(research$held_terminal_position, c(default = "last_permissible"))
  testthat::expect_identical(research$frozen_terminal_position, "write_off")
  testthat::expect_identical(strict$held_terminal_position, c(default = "refuse"))
  testthat::expect_identical(strict$frozen_terminal_position, "refuse")
  testthat::expect_null(research$haircut)

  # Every widened held-terminal meaning carries a v002 identity.
  ids <- ledgr:::ledgr_corporate_action_policy_ids()
  testthat::expect_identical(
    names(ids$held_terminal_position),
    c("last_permissible", "last_mark", "haircut", "write_off", "refuse")
  )
  testthat::expect_true(all(grepl("[.]v002$", ids$held_terminal_position)))
  testthat::expect_identical(
    unname(ids$held_terminal_position),
    sprintf(
      "ledgr.corporate_action.held_terminal_position.%s.v002",
      names(ids$held_terminal_position)
    )
  )
  testthat::expect_false(any(
    ids$held_terminal_position %in%
      ledgr:::ledgr_corporate_action_policy_ids_v1()$held_terminal_position
  ))

  # A schema-1 identity is readable as schema 1 and never accepted as schema 2.
  schema1 <- terminal_policy_schema1_blocks()$corporate_actions
  testthat::expect_identical(schema1$policy_schema_version, 1L)
  testthat::expect_identical(ledgr:::ledgr_corporate_action_identity_schema(schema1), 1L)
  testthat::expect_error(
    ledgr:::ledgr_policy_schema_require_current(list(corporate_actions = schema1)),
    class = "ledgr_policy_schema_mismatch"
  )
  relabeled <- schema1
  relabeled$policy_schema_version <- 2L
  testthat::expect_error(
    ledgr:::ledgr_corporate_action_identity_schema(relabeled),
    class = "ledgr_invalid_config"
  )
  mixed <- identity
  mixed$held_terminal_position$policy_ids[[3L]] <-
    "ledgr.corporate_action.held_terminal_position.last_permissible.v001"
  testthat::expect_error(
    ledgr:::ledgr_corporate_action_identity_schema(mixed),
    class = "ledgr_invalid_config"
  )
  extra <- identity
  extra$unused <- "x"
  testthat::expect_error(
    ledgr:::ledgr_corporate_action_identity_schema(extra),
    class = "ledgr_invalid_config"
  )
  stray_haircut <- ledgr:::ledgr_corporate_action_policy_identity(research)
  stray_haircut$haircut_fraction <- 0.1
  testthat::expect_error(
    ledgr:::ledgr_corporate_action_identity_schema(stray_haircut),
    class = "ledgr_invalid_config"
  )
  old_object <- structure(
    c(list(policy_schema_version = 1L), research[c(
      "cash_amount", "cash_posting", "unsupported_quantity"
    )]),
    class = c("ledgr_corporate_action_policy", "list")
  )
  testthat::expect_error(
    ledgr:::ledgr_validate_corporate_action_policy(old_object),
    class = "ledgr_invalid_corporate_action_policy"
  )
  testthat::expect_identical(
    ledgr:::ledgr_policy_schema_require_current(list(
      corporate_actions = ledgr:::ledgr_corporate_action_policy_identity(research)
    )),
    TRUE
  )
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0159] valuation exhaustion is versioned and identity-complete", {
  freeze <- ledgr_valuation_stale(2)
  testthat::expect_identical(freeze$schema_version, 2L)
  testthat::expect_identical(freeze$exhausted, "freeze")
  testthat::expect_identical(formals(ledgr_valuation_stale)$exhausted, "freeze")
  testthat::expect_identical(freeze, ledgr_valuation_stale(2, exhausted = "freeze"))
  refuse <- ledgr_valuation_stale(2, exhausted = "refuse")
  testthat::expect_identical(refuse$exhausted, "refuse")
  testthat::expect_false(identical(freeze, refuse))
  testthat::expect_identical(
    names(unclass(freeze)),
    c("schema_version", "type_id", "max_sessions", "exhausted")
  )
  testthat::expect_output(print(refuse), "Exhausted marks: refuse", fixed = TRUE)

  # max_sessions keeps its validation and there is still no default horizon.
  testthat::expect_identical(ledgr_valuation_stale(0)$max_sessions, 0L)
  testthat::expect_error(ledgr_valuation_stale(), "max_sessions")
  testthat::expect_error(ledgr_valuation_stale(exhausted = "freeze"), "max_sessions")
  for (bad in list(-1, 1.5, NA_real_, Inf, "2", c(1, 2), NULL)) {
    testthat::expect_error(
      ledgr_valuation_stale(bad),
      class = "ledgr_invalid_valuation_policy"
    )
  }
  for (bad in list("Freeze", "f", "frozen", "stop", NA_character_, NULL,
                   c("freeze", "refuse"), 1, TRUE, c(x = "freeze"))) {
    testthat::expect_error(
      ledgr_valuation_stale(2, exhausted = bad),
      class = "ledgr_invalid_valuation_policy"
    )
  }

  # Run and experiment identity both carry the exhaustion choice.
  snapshot <- availability_runtime_fixture(days = 3L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$hold()
  meta <- ledgr:::ledgr_precompute_snapshot_meta(snapshot)
  configs <- lapply(list(freeze = freeze, refuse = refuse), function(policy) {
    exp <- ledgr_experiment(
      snapshot,
      strategy,
      valuation_policy = policy,
      cost_model = ledgr_cost_zero()
    )
    ledgr:::ledgr_walk_forward_base_config(exp, meta)
  })
  testthat::expect_identical(
    configs$freeze$availability$valuation_policy,
    unclass(freeze)
  )
  testthat::expect_identical(
    configs$refuse$availability$valuation_policy$exhausted,
    "refuse"
  )
  testthat::expect_false(identical(
    ledgr:::config_hash(configs$freeze),
    ledgr:::config_hash(configs$refuse)
  ))
  testthat::expect_false(identical(
    ledgr:::ledgr_walk_forward_experiment_hash(configs$freeze),
    ledgr:::ledgr_walk_forward_experiment_hash(configs$refuse)
  ))

  # Schema 1 is readable but never receives an implicit exhausted value.
  schema1 <- terminal_policy_schema1_blocks()$valuation_policy
  testthat::expect_identical(schema1$schema_version, 1L)
  testthat::expect_identical(ledgr:::ledgr_valuation_policy_record_version(schema1), 1L)
  old_object <- structure(schema1, class = c("ledgr_valuation_policy", "list"))
  testthat::expect_error(
    ledgr:::ledgr_validate_valuation_policy(old_object),
    class = "ledgr_invalid_valuation_policy"
  )
  testthat::expect_error(
    ledgr_experiment(
      snapshot,
      strategy,
      valuation_policy = old_object,
      cost_model = ledgr_cost_zero()
    ),
    class = "ledgr_invalid_valuation_policy"
  )
  testthat::expect_error(
    ledgr:::ledgr_policy_schema_require_current(list(
      availability = list(valuation_policy = schema1)
    )),
    class = "ledgr_policy_schema_mismatch"
  )
  with_new_field <- c(schema1, list(exhausted = "freeze"))
  testthat::expect_true(is.na(ledgr:::ledgr_valuation_policy_record_version(with_new_field)))
  without_field <- unclass(freeze)
  without_field$exhausted <- NULL
  testthat::expect_true(is.na(ledgr:::ledgr_valuation_policy_record_version(without_field)))
  unknown <- unclass(freeze)
  unknown$exhausted <- "carry"
  testthat::expect_true(is.na(ledgr:::ledgr_valuation_policy_record_version(unknown)))
  testthat::expect_identical(
    ledgr:::ledgr_policy_schema_require_current(list(
      availability = list(valuation_policy = unclass(freeze))
    )),
    TRUE
  )
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0160] schema-1 runs stay readable and refuse execution", {
  snapshot <- availability_runtime_fixture(days = 4L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  strategy <- function(ctx, params) {
    calls$n <- calls$n + 1L
    targets <- ctx$hold()
    targets[["AAA"]] <- params$qty
    targets
  }
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    valuation_policy = ledgr_valuation_stale(2),
    cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 10000)
  )
  bt <- ledgr_run(exp, params = list(qty = 1), run_id = "schema1-policy")
  close(bt)

  # A fresh run records both policies at schema 2.
  current <- availability_run_config(bt)
  testthat::expect_identical(current$corporate_actions$policy_schema_version, 2L)
  testthat::expect_identical(current$availability$valuation_policy$schema_version, 2L)
  testthat::expect_identical(current$availability$valuation_policy$exhausted, "freeze")

  # Rewrite it to the exact pre-ticket identity the same experiment recorded.
  legacy <- terminal_policy_schema1_blocks()
  config <- current
  config$corporate_actions <- legacy$corporate_actions
  config$availability$valuation_policy <- legacy$valuation_policy
  legacy_json <- canonical_json(config)
  opened <- ledgr_test_open_duckdb(snapshot$db_path)
  DBI::dbExecute(
    opened$con,
    "UPDATE runs SET config_json = ?, config_hash = ? WHERE run_id = ?",
    params = list(legacy_json, ledgr:::config_hash(config), "schema1-policy")
  )
  ledgr_test_close_duckdb(opened$con, opened$drv)

  # Reopen and every reader report the recorded schema-1 identity unchanged.
  reopened <- ledgr_run_open(snapshot, "schema1-policy")
  on.exit(close(reopened), add = TRUE, after = FALSE)
  testthat::expect_identical(reopened$config$corporate_actions, legacy$corporate_actions)
  testthat::expect_identical(
    reopened$config$availability$valuation_policy,
    legacy$valuation_policy
  )
  info <- ledgr_run_info(snapshot, "schema1-policy")
  testthat::expect_identical(as.character(info$config_json), as.character(legacy_json))
  ca_summary <- ledgr_corporate_action_summary(reopened)
  testthat::expect_identical(
    ca_summary$selected_identities,
    unlist(legacy$corporate_actions[c(
      "cash_amount", "cash_posting", "held_terminal_position",
      "unsupported_quantity"
    )])
  )
  testthat::expect_identical(
    unname(ca_summary$selected_settings),
    c("gross", "effective_close", "last_permissible", "report_only")
  )
  testthat::expect_identical(nrow(ledgr_run_fills(reopened)), 1L)
  testthat::expect_output(
    ledgr:::ledgr_print_corporate_action_summary(ca_summary),
    "Identity held_terminal_position:   ledgr.corporate_action.held_terminal_position.last_permissible.v001",
    fixed = TRUE
  )
  testthat::expect_output(summary(reopened), "Corporate actions: NOT SUPPLIED", fixed = TRUE)

  before <- terminal_policy_store_contents(snapshot$db_path, "schema1-policy")

  # Rerun of the DONE run under its id refuses by name, without work.
  calls_before <- calls$n
  testthat::expect_error(
    ledgr_run(exp, params = list(qty = 1), run_id = "schema1-policy"),
    class = "ledgr_policy_schema_mismatch"
  )
  testthat::expect_identical(calls$n, calls_before)
  # Promotion into it refuses the same way and writes no promotion context.
  results <- ledgr_sweep(exp, ledgr_param_grid(one = list(qty = 1)), seed = 1L)
  candidate <- ledgr_candidate(results, 1L)
  calls_before <- calls$n
  testthat::expect_error(
    ledgr_promote(exp, candidate, run_id = "schema1-policy"),
    class = "ledgr_policy_schema_mismatch"
  )
  testthat::expect_identical(calls$n, calls_before)
  testthat::expect_identical(
    terminal_policy_store_contents(snapshot$db_path, "schema1-policy"),
    before
  )

  # An interrupted schema-1 run cannot resume either.
  opened <- ledgr_test_open_duckdb(snapshot$db_path)
  DBI::dbExecute(
    opened$con,
    "UPDATE runs SET status = 'RUNNING' WHERE run_id = ?",
    params = list("schema1-policy")
  )
  ledgr_test_close_duckdb(opened$con, opened$drv)
  interrupted <- terminal_policy_store_contents(snapshot$db_path, "schema1-policy")
  testthat::expect_error(
    ledgr_run(exp, params = list(qty = 1), run_id = "schema1-policy"),
    class = "ledgr_policy_schema_mismatch"
  )
  testthat::expect_identical(calls$n, calls_before)
  testthat::expect_identical(
    terminal_policy_store_contents(snapshot$db_path, "schema1-policy"),
    interrupted
  )

  # A submitted schema-1 config is refused before execution as well.
  testthat::expect_error(
    ledgr:::ledgr_run_prepare_config(reopened$config),
    class = "ledgr_policy_schema_mismatch"
  )
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0161] policy help separates evidence from modeled choices", {
  root <- testthat::test_path("..", "..")
  ca_path <- file.path(root, "man", "ledgr_corporate_action_policy.Rd")
  valuation_path <- file.path(root, "man", "ledgr_availability_policy.Rd")
  testthat::skip_if_not(
    file.exists(ca_path) && file.exists(valuation_path),
    "source help pages not available during installed-package tests"
  )
  flat <- function(path) {
    gsub("[[:space:]]+", " ", paste(readLines(path, warn = FALSE), collapse = " "))
  }
  ca_help <- flat(ca_path)
  valuation_help <- flat(valuation_path)
  ca_required <- c(
    "Sealed facts are evidence; every choice below is a declared model",
    "always outranks a modeled terminal outcome",
    "\\code{\"last_permissible\"} disposes at the mark that is permissible",
    "\\code{\"last_mark\"} disposes at the last observed mark",
    "\\code{\"haircut\"} disposes at",
    "\\code{\"write_off\"} disposes for zero proceeds. It is a conservative assumption, not evidence",
    "\\code{\"refuse\"} models nothing",
    "ledgr does not trim, case-fold or interpret vendor synonyms, so exact label normalization belongs upstream",
    "\\code{policy_schema_version} 2",
    "frozen_terminal_position"
  )
  for (text in ca_required) {
    testthat::expect_true(grepl(text, ca_help, fixed = TRUE), info = text)
  }
  valuation_required <- c(
    "\\code{max_sessions} separates ordinarily stale valuation",
    "\\code{\"freeze\"} keeps the holding at its last reference",
    "\\code{\"refuse\"} stops the run \\code{INCOMPLETE}",
    "Neither choice establishes an economic terminal",
    "There is no default horizon.",
    "\\code{schema_version} 2"
  )
  for (text in valuation_required) {
    testthat::expect_true(grepl(text, valuation_help, fixed = TRUE), info = text)
  }
})
