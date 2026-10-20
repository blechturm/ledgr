# ledgr-test-file-profile: review

# Row counts of every table in a store, by table name.
ws44_store_counts <- function(snapshot) {
  con <- ledgr:::get_connection(snapshot)
  tables <- sort(DBI::dbListTables(con), method = "radix")
  stats::setNames(vapply(tables, function(table) {
    as.numeric(DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM \"%s\"", table))$n)
  }, numeric(1)), tables)
}

testthat::test_that("[LTB-0371] strategy preflight refuses private context internals before any side effect", {
  refused <- list(
    carrier = function(ctx, params) {
      bars <- ctx$.history$service$substrate$bars
      ctx$hold()
    },
    alias = function(ctx, params) {
      x <- ctx
      view <- x$.history
      ctx$hold()
    },
    brackets = function(ctx, params) {
      view <- ctx[[".history"]]
      ctx$hold()
    },
    single_bracket = function(ctx, params) {
      view <- ctx[".pulse_lookup"]
      ctx$hold()
    },
    get_element = function(ctx, params) {
      view <- getElement(ctx, ".history")
      ctx$hold()
    },
    subset2 = function(ctx, params) {
      lookup <- .subset2(ctx, ".pulse_lookup")
      ctx$hold()
    },
    name_in_string = function(ctx, params) {
      field <- ".feature_vector"
      accessor <- ctx[[field]]
      ctx$hold()
    },
    closure = function(ctx, params) {
      inner <- environment(ctx$feature)$ctx
      ctx$hold()
    },
    projection = function(ctx, params) {
      values <- environment(environment(ctx$feature)$feature_vector)$feature_values
      ctx$hold()
    },
    qualified = function(ctx, params) {
      env <- base::environment(ctx$hold)
      ctx$hold()
    },
    rlang = function(ctx, params) {
      env <- rlang::fn_env(ctx$feature)
      ctx$hold()
    },
    by_name = function(ctx, params) {
      envs <- lapply(list(ctx$feature), environment)
      ctx$hold()
    },
    do_call = function(ctx, params) {
      env <- do.call("environment", list(ctx$feature))
      ctx$hold()
    },
    frame = function(ctx, params) {
      caller <- parent.frame()
      ctx$hold()
    },
    sys = function(ctx, params) {
      self <- sys.function()
      ctx$hold()
    },
    write = function(ctx, params) {
      ctx$.notes <- NULL
      ctx$hold()
    },
    # Correction 1 (close review 44a F1): ledgr's internal namespace and
    # environment-reaching functions named as strings or member extractions.
    triple_colon = function(ctx, params) {
      view <- ledgr:::ledgr_history_context_view(ctx)
      ctx$hold()
    },
    get_from_namespace = function(ctx, params) {
      view <- utils::getFromNamespace("ledgr_history_context_view", "ledgr")(ctx)
      ctx$hold()
    },
    as_namespace = function(ctx, params) {
      view <- asNamespace("ledgr")$ledgr_history_context_view(ctx)
      ctx$hold()
    },
    get_anywhere = function(ctx, params) {
      found <- utils::getAnywhere("ledgr_history_context_view")
      ctx$hold()
    },
    mget_call = function(ctx, params) {
      found <- mget("x", envir = baseenv())
      ctx$hold()
    },
    get0_call = function(ctx, params) {
      found <- base::get0("x", envir = baseenv())
      ctx$hold()
    },
    lapply_string = function(ctx, params) {
      envs <- lapply(list(ctx$feature), "environment")
      ctx$hold()
    },
    sapply_string = function(ctx, params) {
      envs <- sapply(list(ctx$feature), "environment")
      ctx$hold()
    },
    map_string = function(ctx, params) {
      envs <- Map("environment", list(ctx$feature))
      ctx$hold()
    },
    match_fun = function(ctx, params) {
      env <- match.fun("environment")(ctx$feature)
      ctx$hold()
    },
    baseenv_member = function(ctx, params) {
      env <- baseenv()$environment(ctx$feature)
      ctx$hold()
    },
    namespace_member = function(ctx, params) {
      env <- getNamespace("base")[["environment"]](ctx$feature)
      ctx$hold()
    }
  )
  expected_access <- c(
    carrier = "$.history", alias = "$.history", brackets = "[[\".history\"]]",
    single_bracket = "[\".pulse_lookup\"]", get_element = "\".history\"",
    subset2 = "\".pulse_lookup\"", name_in_string = "\".feature_vector\"",
    closure = "environment()", projection = "environment()",
    qualified = "base::environment()", rlang = "rlang::fn_env()",
    by_name = "environment()", do_call = "\"environment\"",
    frame = "parent.frame()", sys = "sys.function()", write = "$.notes",
    triple_colon = "ledgr:::ledgr_history_context_view (not exported)",
    get_from_namespace = "utils::getFromNamespace()", as_namespace = "asNamespace()",
    get_anywhere = "utils::getAnywhere()", mget_call = "mget()", get0_call = "base::get0()",
    lapply_string = "\"environment\"", sapply_string = "\"environment\"",
    map_string = "\"environment\"", match_fun = "\"environment\"",
    baseenv_member = "$environment", namespace_member = "[[\"environment\"]]"
  )
  for (name in names(refused)) {
    preflight <- ledgr_strategy_preflight(refused[[name]])
    testthat::expect_identical(preflight$tier, "tier_3", info = name)
    testthat::expect_false(preflight$allowed, info = name)
    testthat::expect_true(
      startsWith(preflight$reason, "Strategy reaches private context internals:"),
      info = name
    )
    testthat::expect_true(grepl(expected_access[[name]], preflight$reason, fixed = TRUE), info = name)
  }

  # Valid strategies keep their tier: public context reads, the history API
  # and exported helpers stay Tier 1, a package-qualified call stays Tier 2,
  # and a strategy's own list members are not context internals.
  history_strategy <- function(ctx, params) {
    returns <- ledgr_history_frame(ctx, feature = "fast", lookback = 2L, na_action = "drop_instruments")
    if (!ledgr_history_sufficient(returns, min_instruments = 2L)) return(ctx$hold())
    x <- ledgr_history_matrix(returns)
    info <- ledgr_history_info(returns)
    w <- rep(1 / ncol(x), ncol(x))
    ledgr_target_rebalance(ledgr_history_weights(returns, w), ctx, equity_fraction = 0.5, keep = NULL)
  }
  plain_strategy <- function(ctx, params) {
    state <- list(last = ctx$ts_utc, count = 1L)
    targets <- ctx$flat()
    targets[ctx$universe[ctx$vec$admissible]] <- ctx$vec$position[ctx$vec$admissible]
    if (is.null(state$last)) return(ctx$hold())
    targets
  }
  qualified_strategy <- function(ctx, params) {
    smooth <- TTR::SMA(c(1, 2, 3), n = 2L)
    ctx$hold()
  }
  testthat::expect_identical(ledgr_strategy_preflight(history_strategy)$tier, "tier_1")
  testthat::expect_identical(ledgr_strategy_preflight(plain_strategy)$tier, "tier_1")
  testthat::expect_identical(ledgr_strategy_preflight(qualified_strategy)$tier, "tier_2")
  # A strategy's own dot-prefixed data and strings naming pulse-local private
  # fields stay Tier 1, as at BASE 6f019c6b (close review 44a F2); an
  # exported ledgr helper stays Tier 1 when qualified.
  own_data <- list(
    own_list = function(ctx, params) {
      fit <- list(.fitted = 1)
      v <- fit$.fitted
      ctx$hold()
    },
    own_frame = function(ctx, params) {
      d <- data.frame(.pred = 1)
      v <- d$.pred + d[[".pred"]]
      ctx$hold()
    },
    model = function(ctx, params) {
      m <- stats::lm(y ~ x, data.frame(x = 1:3, y = c(1, 3, 2)))
      v <- m$.fitted
      ctx$hold()
    },
    labels = function(ctx, params) {
      msg <- ".notes"
      lbl <- c(".positions", "x")
      ctx$hold()
    },
    exported = function(ctx, params) {
      close <- ledgr::ledgr_history_frame(ctx, bar = "close", lookback = 2L)
      ctx$hold()
    }
  )
  for (name in names(own_data)) {
    testthat::expect_identical(ledgr_strategy_preflight(own_data[[name]])$tier, "tier_1", info = name)
  }

  # The refusal precedes every run, sweep and walk-forward side effect.
  fixture <- ws42_history_fixture(strategy = refused$carrier)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  before <- ws44_store_counts(fixture$snapshot)
  testthat::expect_error(
    ledgr_run(fixture$exp, run_id = "private-run"),
    class = "ledgr_strategy_tier3"
  )
  testthat::expect_error(
    ledgr_sweep(fixture$exp, ledgr_param_grid(list(tag = "private"))),
    class = "ledgr_strategy_tier3"
  )
  folds <- ledgr:::ledgr_fold_list(
    list(ledgr_fold(fixture$days[[1L]], fixture$days[[3L]], fixture$days[[4L]], fixture$days[[6L]], fold_seq = 1L)),
    constructor = list(type_id = "explicit")
  )
  testthat::expect_error(
    ledgr_walk_forward(
      fixture$exp, ledgr_param_grid(list(tag = "private")), folds,
      selection_rule = ledgr_rule_argmax("annualized_return"), seed = 1L
    ),
    class = "ledgr_strategy_tier3"
  )
  # Every refused body is refused by ledgr_run() before it reads anything:
  # no run row or other store row appears.
  for (name in names(refused)) {
    testthat::expect_error(
      ledgr_run(
        ledgr_experiment(
          fixture$snapshot, refused[[name]], universe = ledgr_universe_members("u"),
          features = ledgr_feature_map(fast = ledgr_ind_sma(2)),
          valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
          opening = ledgr_opening(cash = 1000)
        ),
        run_id = paste0("private-", gsub("_", "-", name))
      ),
      class = "ledgr_strategy_tier3",
      info = name
    )
  }
  testthat::expect_identical(ws44_store_counts(fixture$snapshot), before)

  # The same experiment with a public history read runs, and its result is
  # the one the hold strategy produces.
  allowed <- ws42_history_fixture(strategy = function(ctx, params) {
    close <- ledgr_history_frame(ctx, bar = "close", lookback = 2L)
    ctx$hold()
  })
  on.exit(ledgr_snapshot_close(allowed$snapshot), add = TRUE)
  bt <- ledgr_run(allowed$exp, run_id = "public-read")
  on.exit(close(bt), add = TRUE)
  testthat::expect_identical(ledgr_compute_metrics(bt)$total_return, 0)

  # Every dot-prefixed field the package places on a pulse context is in the
  # private field list the preflight reads.
  root <- ledgr_test_source_root()
  if (ledgr_test_checkout_context(root)) {
    sources <- unlist(lapply(
      list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE),
      readLines, warn = FALSE
    ))
    used <- regmatches(sources, gregexpr("ctx(\\$|\\[\\[\")\\.[A-Za-z_]+", sources))
    fields <- unique(sub("^ctx(\\$|\\[\\[\")", "", unlist(used)))
    testthat::expect_true(length(fields) > 0L)
    testthat::expect_identical(
      setdiff(fields, ledgr:::ledgr_pulse_context_private_fields()),
      character()
    )
  }
})
