# RNG isolation helpers (LDG-3158; ws2_rng_design.md Sections 4, 5.3-5.5).
#
# Three parts:
# - parsed-source checks: the store/seeding/kind/daemon inventory of Section 4
#   and the wrapper-shape source check of Section 5.4, both as functions over
#   parsed expressions so their tests can feed them injected source;
# - caller-state witnesses: the caller's next runif(1) and sample(10) after a
#   call equal those of an untouched session, and the kind is unchanged;
# - a runtime tracer for the outermost ledgr frame at RNG-relevant sites.

# ---------------------------------------------------------------------------
# Parsed source
# ---------------------------------------------------------------------------

ledgr_rng_src_parse_dir <- function(root = ledgr_test_source_root()) {
  files <- sort(list.files(file.path(root, "R"), pattern = "[.][Rr]$", full.names = TRUE))
  stats::setNames(
    lapply(files, function(path) parse(path, keep.source = FALSE, encoding = "UTF-8")),
    basename(files)
  )
}

ledgr_rng_src_parse_text <- function(text, file = "injected.R") {
  stats::setNames(list(parse(text = text, keep.source = FALSE)), file)
}

# Head of a call as list(name, pkg); NULL when the head is not a plain or
# namespaced symbol.
ledgr_rng_src_call_head <- function(call) {
  head <- call[[1L]]
  if (is.symbol(head)) {
    return(list(name = as.character(head), pkg = NA_character_))
  }
  if (is.call(head) && length(head) == 3L &&
      (identical(head[[1L]], as.name("::")) || identical(head[[1L]], as.name(":::")))) {
    return(list(name = as.character(head[[3L]]), pkg = as.character(head[[2L]])))
  }
  NULL
}

ledgr_rng_src_top_name <- function(expr) {
  if (is.call(expr) && length(expr) == 3L &&
      (identical(expr[[1L]], as.name("<-")) || identical(expr[[1L]], as.name("="))) &&
      is.symbol(expr[[2L]]) && is.call(expr[[3L]]) &&
      identical(expr[[3L]][[1L]], as.name("function"))) {
    return(as.character(expr[[2L]]))
  }
  "<top>"
}

# Calls in `expr` whose head is one of `names`, as rows of (head name,
# number of arguments). Recurses through all subexpressions, including quoted
# ones.
ledgr_rng_src_calls <- function(expr, names = c("dbAppendTable", "dbWriteTable", "set.seed", "RNGkind", "daemons")) {
  hit_name <- character()
  hit_args <- integer()
  walk <- function(e) {
    if (is.call(e)) {
      head <- ledgr_rng_src_call_head(e)
      if (!is.null(head) && head$name %in% names) {
        k <- length(hit_name) + 1L
        hit_name[k] <<- head$name
        hit_args[k] <<- length(e) - 1L
      }
      for (i in seq_along(e)) {
        if (!identical(e[[i]], quote(expr = ))) walk(e[[i]])
      }
    } else if (is.pairlist(e)) {
      for (i in seq_along(e)) {
        if (!identical(e[[i]], quote(expr = ))) walk(e[[i]])
      }
    }
  }
  walk(expr)
  data.frame(name = hit_name, n_args = hit_args, stringsAsFactors = FALSE)
}

# Section 4 source inventory. `parsed` is a named list of expression vectors
# (one per file). Returns one row per finding; zero rows is a pass.
ledgr_rng_source_inventory <- function(parsed) {
  findings <- list()
  add <- function(file, fn, rule, call) {
    findings[[length(findings) + 1L]] <<- data.frame(
      file = file, function_name = fn, rule = rule, call = call,
      stringsAsFactors = FALSE
    )
  }
  for (file in names(parsed)) {
    for (expr in as.list(parsed[[file]])) {
      fn <- ledgr_rng_src_top_name(expr)
      calls <- ledgr_rng_src_calls(expr)
      for (i in seq_len(nrow(calls))) {
        name <- calls$name[[i]]
        n_args <- calls$n_args[[i]]
        if (name %in% c("dbAppendTable", "dbWriteTable") && !identical(fn, "ledgr_store_append")) {
          add(file, fn, "unguarded_store_write", name)
        } else if (identical(name, "set.seed") && !identical(fn, "ledgr_rng_seed_pinned")) {
          add(file, fn, "unowned_set_seed", name)
        } else if (identical(name, "RNGkind") && n_args == 0L &&
                   !identical(fn, "ledgr_rng_caller_state")) {
          add(file, fn, "unowned_rngkind_query", name)
        } else if (identical(name, "RNGkind") && n_args > 0L &&
                   !fn %in% c("ledgr_rng_restore", "ledgr_parallel_worker_rng_pin")) {
          add(file, fn, "unowned_rngkind_mutation", name)
        } else if (identical(name, "daemons") &&
                   !fn %in% c("ledgr_parallel_mirai_start", "ledgr_parallel_mirai_stop")) {
          add(file, fn, "unowned_daemons", name)
        }
      }
    }
  }
  if (length(findings) == 0L) {
    return(data.frame(file = character(), function_name = character(), rule = character(),
      call = character(), stringsAsFactors = FALSE))
  }
  do.call(rbind, findings)
}

# Wrapper-shape bodies of Section 5.4 (decision (15)).
ledgr_rng_wrapper_expected <- function() {
  c(
    # 14 W exports other than the dispatch-only generic ledgr_candidate.
    "ledgr_backtest", "ledgr_candidate_reproduction_key", "ledgr_feature_grid",
    "ledgr_pbo", "ledgr_precompute_features", "ledgr_promote", "ledgr_pulse_snapshot",
    "ledgr_run", "ledgr_sim_bars", "ledgr_sim_pit_inputs", "ledgr_strategy_grid",
    "ledgr_sweep", "ledgr_sweep_review", "ledgr_walk_forward",
    # The two W S3 methods.
    "ledgr_candidate.default", "ledgr_candidate.ledgr_walk_forward_results",
    # The two R helper closures returned by ledgr_indicator_dev().
    "ledgr_indicator_dev$e$test", "ledgr_indicator_dev$e$test_dates"
  )
}

ledgr_rng_wrapper_lazy <- function() {
  list(ledgr_sweep_review = "rank_by", ledgr_feature_grid = ".filter", ledgr_strategy_grid = ".filter")
}

# Every function literal in the parsed source with a resolvable name: a
# top-level `name <- function` or a nested `obj$field <- function` (named
# `<top>$obj$field`).
ledgr_rng_src_functions <- function(parsed) {
  out <- list()
  visit <- function(e, top) {
    if (!is.call(e)) return(invisible())
    if (length(e) == 3L && (identical(e[[1L]], as.name("<-")) || identical(e[[1L]], as.name("="))) &&
        is.call(e[[3L]]) && identical(e[[3L]][[1L]], as.name("function"))) {
      lhs <- e[[2L]]
      name <- if (is.symbol(lhs) && is.null(top)) {
        as.character(lhs)
      } else if (is.call(lhs) && identical(lhs[[1L]], as.name("$")) && !is.null(top)) {
        paste0(top, "$", paste(deparse(lhs[[2L]]), collapse = ""), "$", as.character(lhs[[3L]]))
      } else {
        NULL
      }
      if (!is.null(name)) {
        out[[length(out) + 1L]] <<- list(name = name, fun = e[[3L]])
        top <- if (is.null(top)) name else top
      }
      visit(e[[3L]][[3L]], top)
      return(invisible())
    }
    for (i in seq_along(e)) {
      if (!identical(e[[i]], quote(expr = ))) visit(e[[i]], top)
    }
  }
  for (file in names(parsed)) {
    for (expr in as.list(parsed[[file]])) visit(expr, NULL)
  }
  out
}

# Calls in a function body, not descending into nested function literals.
ledgr_rng_src_own_calls <- function(body) {
  out <- list()
  walk <- function(e) {
    if (!is.call(e)) return(invisible())
    if (identical(e[[1L]], as.name("function"))) return(invisible())
    out[[length(out) + 1L]] <<- e
    for (i in seq_along(e)) {
      if (!identical(e[[i]], quote(expr = ))) walk(e[[i]])
    }
  }
  walk(body)
  out
}

ledgr_rng_src_is_call_to <- function(e, name) {
  is.call(e) && is.symbol(e[[1L]]) && identical(as.character(e[[1L]]), name)
}

# Section 5.4 source check. Returns one row per violation; zero rows is a pass.
ledgr_rng_source_check <- function(parsed) {
  problems <- character()
  bad <- function(...) problems <<- c(problems, sprintf(...))
  fns <- ledgr_rng_src_functions(parsed)
  by_name <- stats::setNames(lapply(fns, `[[`, "fun"), vapply(fns, `[[`, character(1), "name"))
  steps <- c("ledgr_rng_force_args", "ledgr_rng_preserve_caller")
  wrapper <- names(by_name)[vapply(by_name, function(f) {
    if (!any(steps %in% all.names(f[[3L]]))) return(FALSE)
    calls <- ledgr_rng_src_own_calls(f[[3L]])
    any(vapply(calls, function(cl) any(vapply(steps, ledgr_rng_src_is_call_to, logical(1), e = cl)), logical(1)))
  }, logical(1))]
  expected <- ledgr_rng_wrapper_expected()
  for (x in setdiff(expected, wrapper)) bad("missing wrapper-shape body: %s", x)
  for (x in setdiff(wrapper, expected)) bad("unexpected wrapper-shape body: %s", x)
  lazy_frozen <- ledgr_rng_wrapper_lazy()
  impls <- character()
  for (name in intersect(wrapper, names(by_name))) {
    f <- by_name[[name]]
    formal_names <- names(f[[2L]])
    body <- f[[3L]]
    stmts <- if (ledgr_rng_src_is_call_to(body, "{")) as.list(body)[-1L] else list(body)
    if (length(stmts) < 2L) {
      bad("%s: body has fewer than two statements", name)
      next
    }
    first <- stmts[[1L]]
    last <- stmts[[length(stmts)]]
    if (!ledgr_rng_src_is_call_to(first, "ledgr_rng_force_args")) {
      bad("%s: first statement is not ledgr_rng_force_args()", name)
    } else {
      args <- as.list(first)[-1L]
      lazy <- if (length(args) == 0L) {
        character()
      } else if (length(args) == 1L && identical(names(args), "lazy") && is.character(args[[1L]])) {
        args[[1L]]
      } else {
        bad("%s: ledgr_rng_force_args() takes only a literal `lazy`", name)
        NA_character_
      }
      want <- lazy_frozen[[name]] %||% character()
      if (!identical(sort(lazy), sort(want))) {
        bad("%s: lazy set is {%s}, frozen set is {%s}", name, paste(lazy, collapse = ","), paste(want, collapse = ","))
      }
    }
    all_calls <- ledgr_rng_src_own_calls(body)
    n_preserve <- sum(vapply(all_calls, ledgr_rng_src_is_call_to, logical(1), name = "ledgr_rng_preserve_caller"))
    if (n_preserve != 1L) bad("%s: %d ledgr_rng_preserve_caller() calls, expected 1", name, n_preserve)
    if (!ledgr_rng_src_is_call_to(last, "ledgr_rng_preserve_caller") || length(last) != 2L) {
      bad("%s: last statement is not ledgr_rng_preserve_caller(<implementation call>)", name)
    } else if (is.call(last[[2L]]) && is.symbol(last[[2L]][[1L]])) {
      impls[[name]] <- as.character(last[[2L]][[1L]])
    } else {
      bad("%s: the preserve call does not evaluate a named implementation call", name)
    }
    if (any(vapply(all_calls, ledgr_rng_src_is_call_to, logical(1), name = "on.exit"))) {
      bad("%s: on.exit() in a wrapper-shape body", name)
    }
    capture_ok <- c(lazy_frozen[[name]] %||% character(), if (identical(name, "ledgr_pbo")) "metric")
    for (stmt in stmts[-c(1L, length(stmts))]) {
      ok <- is.call(stmt) && identical(stmt[[1L]], as.name("<-")) && is.symbol(stmt[[2L]]) && is.call(stmt[[3L]])
      if (ok) {
        rhs <- stmt[[3L]]
        arg_formal <- length(rhs) == 2L && is.symbol(rhs[[2L]]) && as.character(rhs[[2L]]) %in% formal_names
        ok <- (ledgr_rng_src_is_call_to(rhs, "missing") && arg_formal) ||
          (ledgr_rng_src_is_call_to(rhs, "match.arg") && arg_formal) ||
          (ledgr_rng_src_is_call_to(rhs, "substitute") && arg_formal && as.character(rhs[[2L]]) %in% capture_ok) ||
          (ledgr_rng_src_is_call_to(rhs, "parent.frame") && length(rhs) == 1L)
      }
      if (!ok) bad("%s: statement outside the permitted prologue: %s", name, paste(deparse(stmt), collapse = " "))
    }
  }
  generic <- by_name[["ledgr_candidate"]]
  if (is.null(generic)) {
    bad("generic ledgr_candidate not found")
  } else {
    gbody <- generic[[3L]]
    gstmts <- if (ledgr_rng_src_is_call_to(gbody, "{")) as.list(gbody)[-1L] else list(gbody)
    if (!(length(gstmts) == 1L && identical(gstmts[[1L]], quote(UseMethod("ledgr_candidate"))))) {
      bad("generic ledgr_candidate: body is not exactly UseMethod(\"ledgr_candidate\")")
    }
  }
  recapture <- c("substitute", "missing")
  for (impl in unique(impls)) {
    f <- by_name[[impl]]
    if (is.null(f)) {
      bad("implementation %s not found", impl)
      next
    }
    formal_names <- names(f[[2L]])
    for (cl in ledgr_rng_src_own_calls(f[[3L]])) {
      if (any(vapply(c("match.call", "sys.call", "parent.frame", "sys.function"), ledgr_rng_src_is_call_to, logical(1), e = cl))) {
        bad("implementation %s: %s", impl, paste(deparse(cl), collapse = " "))
      }
      if (any(vapply(recapture, ledgr_rng_src_is_call_to, logical(1), e = cl)) &&
          length(cl) >= 2L && is.symbol(cl[[2L]]) && as.character(cl[[2L]]) %in% formal_names) {
        bad("implementation %s recaptures forwarded formal: %s", impl, paste(deparse(cl), collapse = " "))
      }
    }
  }
  problems
}

# ---------------------------------------------------------------------------
# Caller-state witnesses
# ---------------------------------------------------------------------------

ledgr_rng_test_seed <- function() {
  get0(".Random.seed", envir = globalenv(), inherits = FALSE)
}

# Sets a caller state by label. "absent_lecuyer" leaves .Random.seed absent
# under a non-default active kind.
ledgr_rng_test_set_state <- function(state) {
  switch(state,
    mt = set.seed(123L, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection"),
    lecuyer = set.seed(123L, kind = "L'Ecuyer-CMRG", normal.kind = "Inversion", sample.kind = "Rejection"),
    rounding = suppressWarnings(set.seed(123L, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rounding")),
    absent_lecuyer = {
      suppressWarnings(RNGkind("L'Ecuyer-CMRG", "Box-Muller", "Rounding"))
      rm(".Random.seed", envir = globalenv())
    },
    stop("unknown caller state ", state)
  )
  invisible(state)
}

ledgr_rng_test_states <- function() c("mt", "lecuyer", "rounding", "absent_lecuyer")

# Restores the session's own RNG after a witness block.
ledgr_rng_test_local_restore <- function(envir = parent.frame()) {
  had <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  old <- ledgr_rng_test_seed()
  kind <- RNGkind()
  withr::defer({
    suppressWarnings(RNGkind(kind[[1L]], kind[[2L]], kind[[3L]]))
    if (had) {
      assign(".Random.seed", old, envir = globalenv())
    } else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    }
  }, envir = envir)
}

# Runs `code` under each caller state; after it, the caller's kind and next
# draws must equal those of an untouched session in the same state. For the
# absent state the seed must still be absent and the kind unchanged. `code`
# may fail or be interrupted; the condition is caught and returned.
ledgr_rng_expect_caller_unchanged <- function(code_fn, label, states = ledgr_rng_test_states(),
                                              expect_condition = NULL) {
  for (state in states) {
    ledgr_rng_test_set_state(state)
    kind_before <- RNGkind()
    seed_before <- ledgr_rng_test_seed()
    if (!is.null(seed_before)) {
      expected_u <- stats::runif(1)
      expected_s <- suppressWarnings(sample(10))
      assign(".Random.seed", seed_before, envir = globalenv())
    }
    result <- tryCatch(code_fn(), error = function(e) e, interrupt = function(e) e)
    if (!is.null(expect_condition)) {
      testthat::expect_true(inherits(result, expect_condition),
        info = sprintf("%s [%s]: expected condition %s", label, state, expect_condition))
    } else if (inherits(result, c("error", "interrupt"))) {
      testthat::fail(sprintf("%s [%s]: unexpected condition: %s", label, state, conditionMessage(result)))
    }
    testthat::expect_identical(RNGkind(), kind_before, info = sprintf("%s [%s]: kind", label, state))
    if (is.null(seed_before)) {
      testthat::expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE),
        info = sprintf("%s [%s]: seed stays absent", label, state))
    } else {
      testthat::expect_identical(ledgr_rng_test_seed(), seed_before, info = sprintf("%s [%s]: .Random.seed", label, state))
      testthat::expect_identical(stats::runif(1), expected_u, info = sprintf("%s [%s]: next runif", label, state))
      testthat::expect_identical(suppressWarnings(sample(10)), expected_s, info = sprintf("%s [%s]: next sample", label, state))
    }
  }
  invisible(TRUE)
}

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

# One instrument, `n` daily bars, deterministic prices (no RNG).
ledgr_rng_test_bars <- function(ids = "AAA", n = 30L) {
  ts <- as.POSIXct("2021-01-01", tz = "UTC") + 86400 * (seq_len(n) - 1L)
  do.call(rbind, lapply(seq_along(ids), function(j) {
    close <- 50 + j + 0.5 * sin(seq_len(n) / (j + 1))
    data.frame(instrument_id = ids[[j]], ts_utc = ts, open = close, high = close + 1, low = close - 1,
      close = close, volume = 1e5, stringsAsFactors = FALSE)
  }))
}

ledgr_rng_test_experiment <- function(strategy, ids = "AAA", n = 30L, db_path = tempfile(fileext = ".duckdb"),
                                      snapshot_id = "rng_iso") {
  snapshot <- ledgr_snapshot_from_df(ledgr_rng_test_bars(ids, n), db_path = db_path, snapshot_id = snapshot_id)
  exp <- ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 1e5), cost_model = ledgr_cost_zero())
  list(snapshot = snapshot, exp = exp, db_path = db_path)
}

ledgr_rng_test_flat_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  targets[[1L]] <- params$qty %||% 1
  targets
}

# The contract's recipe: draw through withr::with_seed(ctx$pulse_seed, ...).
ledgr_rng_test_recipe_strategy <- function(ctx, params) {
  if (is.null(ctx$pulse_seed)) stop("this strategy needs `seed =`")
  targets <- ctx$flat()
  idx <- withr::with_seed(ctx$pulse_seed, sample.int(length(ctx$universe), params$k))
  targets[ctx$universe[idx]] <- params$qty
  targets
}

# Ambient RNG: draws from whatever stream the fold runs on.
ledgr_rng_test_ambient_strategy <- function(ctx, params) {
  targets <- ctx$flat()
  targets[ctx$universe[stats::runif(length(ctx$universe)) < 0.5]] <- params$qty
  targets
}

ledgr_rng_test_fills <- function(bt) {
  f <- as.data.frame(ledgr_results(bt, "fills"))
  f[c("event_seq", "ts_utc", "instrument_id", "side", "qty", "price")]
}

# A small walk-forward fixture: two folds on ten daily sessions.
ledgr_rng_test_walk_forward <- function(strategy = ledgr_rng_test_flat_strategy,
                                        db_path = tempfile(fileext = ".duckdb")) {
  fx <- ledgr_rng_test_experiment(strategy, ids = c("AAA", "BBB"), n = 10L, db_path = db_path,
    snapshot_id = "rng_iso_wf")
  fold_ts <- function(i) format(as.POSIXct("2021-01-01", tz = "UTC") + 86400 * (i - 1L), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  fx$folds <- ledgr:::ledgr_fold_list(list(
    ledgr_fold(fold_ts(1), fold_ts(3), fold_ts(4), fold_ts(6), fold_seq = 1L),
    ledgr_fold(fold_ts(4), fold_ts(6), fold_ts(7), fold_ts(10), fold_seq = 2L)
  ), constructor = list(type_id = "explicit"))
  fx$grid <- ledgr_grid_named(small = list(strategy = list(qty = 2)), large = list(strategy = list(qty = 4)))
  fx
}

# ---------------------------------------------------------------------------
# Runtime tracer (Section 5.3): at each traced site, the outermost ledgr frame
# on the stack must be a W export or W method, or an R helper closure.
# ---------------------------------------------------------------------------

ledgr_rng_tracer_sites <- function() {
  c("ledgr_fold_envelope", "ledgr_rng_seed_pinned", "ledgr_parallel_mirai_start",
    "ledgr_call_feature_fn", "ledgr_call_feature_series_fn",
    "ledgr_sweep_review_rank", "ledgr_pbo_eval_metric", "ledgr_eval_grid_filter")
}

ledgr_rng_tracer_allowed <- function() {
  c(setdiff(ledgr_rng_wrapper_expected(), c("ledgr_indicator_dev$e$test", "ledgr_indicator_dev$e$test_dates")),
    "ledgr_candidate")
}

ledgr_rng_tracer_log <- new.env(parent = emptyenv())

ledgr_rng_tracer_check <- function(site) {
  ns <- asNamespace("ledgr")
  n <- sys.nframe()
  outer <- NA_character_
  for (i in seq_len(n)) {
    f <- sys.function(i)
    env <- environment(f)
    if (is.null(env)) next
    is_r_helper <- !identical(env, ns) && identical(parent.env(env), ns) &&
      inherits(get0("e", envir = env, inherits = FALSE), "ledgr_indicator_dev")
    if (identical(env, ns) || is_r_helper) {
      if (is_r_helper) {
        outer <- "<indicator_dev helper>"
      } else {
        hits <- ledgr_rng_tracer_allowed()[vapply(ledgr_rng_tracer_allowed(), function(name) {
          identical(f, get0(name, envir = ns, inherits = FALSE))
        }, logical(1))]
        outer <- if (length(hits)) hits[[1L]] else paste(deparse(sys.call(i)[[1L]]), collapse = "")
      }
      break
    }
  }
  ok <- outer %in% c(ledgr_rng_tracer_allowed(), "<indicator_dev helper>")
  ledgr_rng_tracer_log$rows[[length(ledgr_rng_tracer_log$rows) + 1L]] <-
    data.frame(site = site, outer = outer, ok = ok, stringsAsFactors = FALSE)
  invisible(NULL)
}

# Traces every site, runs `code`, untraces, and returns the observations.
ledgr_rng_with_tracer <- function(code) {
  ns <- asNamespace("ledgr")
  ledgr_rng_tracer_log$rows <- list()
  sites <- intersect(ledgr_rng_tracer_sites(), ls(ns, all.names = TRUE))
  for (site in sites) {
    suppressMessages(trace(site, tracer = substitute(CHECK(SITE), list(CHECK = ledgr_rng_tracer_check, SITE = site)),
      where = ns, print = FALSE))
  }
  on.exit(for (site in sites) suppressMessages(untrace(site, where = ns)), add = TRUE)
  force(code)
  rows <- ledgr_rng_tracer_log$rows
  if (length(rows) == 0L) {
    return(data.frame(site = character(), outer = character(), ok = logical()))
  }
  do.call(rbind, rows)
}

ledgr_rng_test_panel <- function() {
  m <- matrix(
    c(
      0.02, 0.01, -0.01, 0.00, 0.03, 0.01, -0.02, 0.00, 0.01, 0.02, -0.01, 0.00,
      0.00, 0.01, 0.02, 0.01, -0.01, 0.00, 0.03, 0.02, -0.02, -0.01, 0.00, 0.01,
      -0.01, 0.00, 0.01, 0.02, 0.00, -0.01, 0.01, 0.03, 0.02, 0.00, -0.02, -0.01,
      0.01, -0.02, 0.00, 0.01, 0.02, 0.03, 0.00, -0.01, 0.00, 0.01, 0.02, 0.03
    ),
    nrow = 12,
    ncol = 4,
    dimnames = list(NULL, paste0("c", 1:4))
  )
  ledgr_return_panel(m, ts = as.POSIXct("2020-01-02", tz = "UTC") + 86400 * seq_len(12L))
}

ledgr_rng_test_review_sweep <- function() {
  tibble::tibble(
    candidate_id = c("low", "high", "mid", "failed"),
    candidate_row = 1:4,
    status = c("DONE", "DONE", "DONE", "FAILED"),
    final_equity = c(100, 120, 110, NA_real_),
    total_return = c(0, 0.2, 0.1, NA_real_),
    sharpe_ratio = c(0.1, 0.4, 0.2, NA_real_),
    max_drawdown = c(0.01, 0.02, 0.015, NA_real_),
    n_trades = c(1L, 2L, 2L, NA_integer_),
    execution_seed = c(11L, 12L, 13L, NA_integer_),
    error_class = c(NA_character_, NA_character_, NA_character_, "ledgr_test_failure"),
    error_msg = c(NA_character_, NA_character_, NA_character_, "failed"),
    params = list(list(qty = 1), list(qty = 2), list(qty = 3), list(qty = 4)),
    feature_params = list(list(), list(), list(), list()),
    warnings = list(list(), list(), list(), list())
  )
}
