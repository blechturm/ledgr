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
    },
    # Correction 2 (re-review 1 R1 and R3): code rebuilt in an enclosure,
    # quoted carriers and internals, evaluation in the context, @ extraction,
    # rlang namespace getters and rlang names handed to a functional.
    body_rebind_export = function(ctx, params) {
      f <- ledgr::ledgr_history_frame
      body(f) <- quote(ledgr_history_context_view(ctx))
      v <- f(ctx)
      ctx$hold()
    },
    body_rebind_closure = function(ctx, params) {
      f <- ctx$feature
      body(f) <- quote(feature_vector)
      v <- f()
      ctx$hold()
    },
    s3method_rebind = function(ctx, params) {
      m <- utils::getS3method("print", "ledgr_history")
      body(m) <- quote(ledgr_history_context_view)
      v <- m()(ctx)
      ctx$hold()
    },
    unserialize_copy = function(ctx, params) {
      g <- unserialize(serialize(ctx$feature, NULL))
      ctx$hold()
    },
    as_function = function(ctx, params) {
      g <- as.function(alist(x = , x))
      ctx$hold()
    },
    substitute_ctx = function(ctx, params) {
      v <- substitute(.history, ctx)
      ctx$hold()
    },
    substitute_list = function(ctx, params) {
      v <- substitute(x, list(x = 1))
      ctx$hold()
    },
    bquote_where = function(ctx, params) {
      v <- bquote(.(.history), where = ctx)
      ctx$hold()
    },
    docall_with = function(ctx, params) {
      v <- do.call(with, list(ctx, quote(.history)))
      ctx$hold()
    },
    docall_evalq = function(ctx, params) {
      v <- do.call(evalq, list(quote(.history), ctx))
      ctx$hold()
    },
    quoted_internal = function(ctx, params) {
      call <- quote(ledgr_history_context_view(ctx))
      ctx$hold()
    },
    at_extraction = function(ctx, params) {
      v <- ctx@.notes
      ctx$hold()
    },
    rlang_namespace = function(ctx, params) {
      ns <- rlang::ns_env("ledgr")
      ctx$hold()
    },
    rlang_name_string = function(ctx, params) {
      envs <- lapply(list(ctx$feature), "fn_env")
      ctx$hold()
    },
    # Correction 3 (re-review 2 S1 and S4): qualified replacement functions,
    # attached rlang getters, formals<- alone, positional bquote() where, and
    # a quoted carrier other than .history.
    base_body_assign = function(ctx, params) {
      f <- ctx$feature
      base::body(f) <- quote(feature_vector)
      v <- f()
      ctx$hold()
    },
    rlang_fn_body_assign = function(ctx, params) {
      f <- ctx$feature
      rlang::fn_body(f) <- quote(feature_vector)
      ctx$hold()
    },
    attached_rlang = function(ctx, params) {
      e <- env_get(fn_env(ctx$feature), "feature_vector", inherit = TRUE)
      ctx$hold()
    },
    base_formals_assign = function(ctx, params) {
      f <- ctx$feature
      base::formals(f) <- alist(x = 1)
      ctx$hold()
    },
    formals_only = function(ctx, params) {
      f <- ctx$feature
      formals(f) <- alist(x = 1)
      ctx$hold()
    },
    bquote_positional = function(ctx, params) {
      v <- bquote(.(a), ctx)
      ctx$hold()
    },
    quoted_feature_vector = function(ctx, params) {
      v <- do.call(with, list(ctx, quote(.feature_vector)))
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
    baseenv_member = "$environment", namespace_member = "[[\"environment\"]]",
    body_rebind_export = "body<-()", body_rebind_closure = "body<-()",
    s3method_rebind = "ledgr_history_context_view (not exported)",
    unserialize_copy = "unserialize()", as_function = "as.function()",
    substitute_ctx = "substitute(<expr>, <env>)", substitute_list = "substitute(<expr>, <env>)",
    bquote_where = "bquote(<expr>, where = <env>)", docall_with = ".history",
    docall_evalq = ".history", quoted_internal = "ledgr_history_context_view (not exported)",
    at_extraction = "@.notes", rlang_namespace = "rlang::ns_env()",
    rlang_name_string = "lapply(\"fn_env\")",
    base_body_assign = "base::body<-()", rlang_fn_body_assign = "rlang::fn_body<-()",
    attached_rlang = "fn_env()", base_formals_assign = "base::formals<-()",
    formals_only = "formals<-()", bquote_positional = "bquote(<expr>, where = <env>)",
    quoted_feature_vector = ".feature_vector"
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
    returns <- ledgr_history_frame(ctx,
      feature = "fast", lookback = 2L,
      min_instruments = 2L
    )
    if (!ledgr_passed_warmup(returns)) {
      return(ctx$hold())
    }
    x <- ledgr_history_matrix(returns)
    info <- ledgr_history_info(returns)
    w <- rep(1 / ncol(x), ncol(x))
    ledgr_target_rebalance(ledgr_align_weights(w, returns), ctx, equity_fraction = 0.5, keep = NULL)
  }
  plain_strategy <- function(ctx, params) {
    state <- list(last = ctx$ts_utc, count = 1L)
    targets <- ctx$flat()
    targets[ctx$universe[ctx$vec$admissible]] <- ctx$vec$position[ctx$vec$admissible]
    if (is.null(state$last)) {
      return(ctx$hold())
    }
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
    },
    # An ordinary field, column or label called "environment" is data
    # (re-review 1 R2), as at BASE.
    environment_field = function(ctx, params) {
      scores <- list(environment = 0.3, social = 0.2)
      live <- identical(params$environment, "live") || scores$environment > 0
      ctx$hold()
    },
    environment_label = function(ctx, params) {
      d <- data.frame(environment = 1)
      lbl <- c("environment", "momentum")
      v <- d[["environment"]]
      ctx$hold()
    },
    # Correction 3 (re-review 2 S2, S3 and N1): environment data handed to a
    # functional outside its function slot, the strategy's own names that
    # equal ledgr internals, and bquote() splicing without an environment.
    functional_data = function(ctx, params) {
      d <- data.frame(environment = c(1, 2), sector = c("a", "b"))
      s <- list(list(environment = 1), list(environment = 2))
      by_sector <- tapply(d$environment, d$sector, mean)
      pillar <- sapply(s, "[[", "environment")
      roots <- lapply(d[["environment"]], sqrt)
      pairs <- mapply(function(a, b) a, 1:2, params$environment)
      ctx$hold()
    },
    own_names = function(ctx, params) {
      config_hash <- "abc"
      res <- list(config_hash = 1)
      v <- res$config_hash
      compute_sharpe_ratio <- function(r) mean(r) / stats::sd(r)
      snapshot_state <- 1
      ctx$hold()
    },
    # A member named like a ledgr internal that the strategy does not bind
    # itself: only the `$`/`@` member skip keeps this at Tier 1.
    member_only = function(ctx, params) {
      res <- list(config_hash = 1, compute_sharpe_ratio = 2)
      v <- res$config_hash + res$compute_sharpe_ratio
      ctx$hold()
    },
    bquote_splice = function(ctx, params) {
      v <- bquote(f(..(list(1, 2))), splice = TRUE)
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
    ledgr_sweep(fixture$exp, ledgr_grid_named(candidate_1 = list(strategy = list(tag = "private")))),
    class = "ledgr_strategy_tier3"
  )
  folds <- ledgr:::ledgr_fold_list(
    list(ledgr_fold(fixture$days[[1L]], fixture$days[[3L]], fixture$days[[4L]], fixture$days[[6L]], fold_seq = 1L)),
    constructor = list(type_id = "explicit")
  )
  testthat::expect_error(
    ledgr_walk_forward(
      fixture$exp, ledgr_grid_named(candidate_1 = list(strategy = list(tag = "private"))), folds,
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
          fixture$snapshot, refused[[name]],
          universe = ledgr_universe_members("u"),
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
      readLines,
      warn = FALSE
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
