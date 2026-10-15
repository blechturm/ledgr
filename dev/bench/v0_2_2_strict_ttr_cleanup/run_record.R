# Records made before the correction that introduced verify_input() treated
# --source-commit as a caller-supplied label. Current records resolve that
# label to HEAD, require a clean Git input, and retain the HEAD tree hash.
args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
required_arg <- function(flag) {
  value <- arg_value(flag)
  if (is.null(value)) stop("Missing ", flag, call. = FALSE)
  value
}

script <- sub("^--file=", "", grep(
  "^--file=",
  commandArgs(FALSE),
  value = TRUE
)[[1L]])
script <- normalizePath(script, winslash = "/")

if ("--child" %in% args) {
  repo <- normalizePath(required_arg("--repo"), winslash = "/")
  arm <- required_arg("--arm")
  length <- as.integer(required_arg("--length"))
  pair <- as.integer(required_arg("--pair"))
  attempt <- as.integer(required_arg("--attempt"))
  order <- as.integer(required_arg("--order"))
  source_commit <- required_arg("--source-commit")
  source_tree <- required_arg("--source-tree")
  output <- required_arg("--output")
  stopifnot(arm %in% c("baseline", "candidate"), length >= 50L)

  suppressPackageStartupMessages(pkgload::load_all(
    repo,
    quiet = TRUE,
    compile = FALSE
  ))
  set.seed(3051L + length)
  close <- 100 * exp(cumsum(stats::rnorm(length, 0, 0.01)))
  dates <- as.Date("2020-01-01") + seq_len(length) - 1L
  bars <- data.frame(
    ts_utc = as.POSIXct(paste(dates, "21:00:00"), tz = "UTC"),
    instrument_id = "AAA",
    open = close * 0.999,
    high = close * 1.005,
    low = close * 0.995,
    close = close,
    volume = 1e5,
    stringsAsFactors = FALSE
  )
  gap_rows <- unique(pmin(length, c(1L, length %/% 2L, length)))
  strict_bars <- bars
  strict_bars[gap_rows, c("open", "high", "low", "close")] <- NA_real_

  indicator <- ledgr_ind_ttr("SMA", input = "close", n = 20L)
  definition <- ledgr:::ledgr_precompute_feature_def_from_indicator(indicator)
  kind <- ledgr:::ledgr_strict_builtin_kind(definition)
  invisible(ledgr:::ledgr_compute_feature_series_strict(
    strict_bars,
    definition,
    kind = kind
  ))
  prep_times <- numeric(5L)
  prep_iterations <- if (length <= 500L) 5L else 2L
  strict_value <- NULL
  for (i in seq_along(prep_times)) {
    started <- proc.time()[["elapsed"]]
    for (iteration in seq_len(prep_iterations)) {
      kind <- ledgr:::ledgr_strict_builtin_kind(definition)
      strict_value <- ledgr:::ledgr_compute_feature_series_strict(
        strict_bars,
        definition,
        kind = kind
      )
    }
    prep_times[[i]] <- (
      proc.time()[["elapsed"]] - started
    ) / prep_iterations
  }

  knowledge <- as.POSIXct(min(dates) - 2L, tz = "UTC")
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "14:30:00",
      session_close = "21:00:00",
      knowledge_time = knowledge,
      stringsAsFactors = FALSE
    ),
    venue_id = "WS37",
    timezone = "UTC"
  )
  membership <- ledgr_facts_membership_snapshots(
    data.frame(
      instrument_id = "AAA",
      effective_from = as.POSIXct(min(dates), tz = "UTC"),
      knowledge_time = knowledge,
      stringsAsFactors = FALSE
    ),
    universe_id = "ws37_members",
    complete = TRUE
  )
  snapshot_path <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(
    bars[-gap_rows, , drop = FALSE],
    facts = ledgr_facts(sessions, membership),
    db_path = snapshot_path,
    snapshot_id = paste0("ws37-", length)
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  feature_id <- ledgr_feature_id(indicator)
  strategy <- local({
    feature_id <- feature_id
    function(ctx, params) {
      value <- ctx$vec$feature(feature_id)
      targets <- ctx$flat()
      targets[is.finite(value)] <- 1
      targets
    }
  })
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    features = list(indicator),
    universe = ledgr_universe_members("ws37_members"),
    opening = ledgr_opening(cash = 1e6),
    valuation_policy = ledgr_valuation_stale(1L),
    cost_model = ledgr_cost_zero()
  )
  started <- proc.time()[["elapsed"]]
  result <- ledgr_run(experiment, params = list())
  end_to_end_s <- proc.time()[["elapsed"]] - started
  drop_run_id <- function(x) {
    if (is.data.frame(x)) x[setdiff(names(x), "run_id")] else x
  }
  semantics <- list(
    equity = drop_run_id(ledgr_results(result, what = "equity")),
    fills = drop_run_id(ledgr_results(result, what = "fills")),
    trades = drop_run_id(ledgr_results(result, what = "trades"))
  )
  close(result)

  row <- data.frame(
    attempt = attempt,
    length = length,
    pair = pair,
    order = order,
    arm = arm,
    source_commit = source_commit,
    source_tree = source_tree,
    r_version = paste(R.version$major, R.version$minor, sep = "."),
    ttr_version = as.character(utils::packageVersion("TTR")),
    strict_prep_s = stats::median(prep_times),
    end_to_end_s = end_to_end_s,
    strict_hash = digest::digest(strict_value, algo = "sha256"),
    semantic_hash = digest::digest(semantics, algo = "sha256"),
    stringsAsFactors = FALSE
  )
  utils::write.csv(row, output, row.names = FALSE, na = "")
  quit(save = "no", status = 0L)
}

baseline <- normalizePath(required_arg("--baseline"), winslash = "/")
candidate <- normalizePath(required_arg("--candidate"), winslash = "/")
baseline_commit <- required_arg("--baseline-commit")
candidate_commit <- required_arg("--candidate-commit")
out <- required_arg("--out")
lengths <- as.integer(strsplit(
  arg_value("--lengths", "250,1000"),
  ",",
  fixed = TRUE
)[[1L]])
pairs <- as.integer(arg_value("--pairs", "5"))
stopifnot(length(lengths) >= 2L, all(lengths >= 50L), pairs >= 5L)

git_read <- function(repo, args, label) {
  value <- suppressWarnings(system2(
    "git",
    c("-C", shQuote(repo), args),
    stdout = TRUE,
    stderr = FALSE
  ))
  status <- attr(value, "status")
  if (!is.null(status) && status != 0L) {
    stop(
      label,
      " input verification failed: ",
      paste(value, collapse = "\n"),
      call. = FALSE
    )
  }
  value
}

verify_input <- function(repo, claimed_commit, label) {
  head <- git_read(repo, c("rev-parse", "--verify", "HEAD^{commit}"), label)
  claimed <- git_read(
    repo,
    c("rev-parse", "--verify", paste0(claimed_commit, "^{commit}")),
    label
  )
  if (length(head) != 1L || length(claimed) != 1L || !identical(head, claimed)) {
    stop(
      label,
      " HEAD does not match --",
      label,
      "-commit.",
      call. = FALSE
    )
  }
  dirty <- git_read(
    repo,
    c("status", "--porcelain=v1", "--untracked-files=all"),
    label
  )
  if (length(dirty) > 0L) {
    stop(
      label,
      " input tree is not clean:\n",
      paste(dirty, collapse = "\n"),
      call. = FALSE
    )
  }
  tree <- git_read(repo, c("rev-parse", "--verify", "HEAD^{tree}"), label)
  if (length(tree) != 1L) stop(label, " tree hash is unavailable.", call. = FALSE)
  list(commit = head[[1L]], tree = tree[[1L]])
}

git_config <- tempfile("ws37-git-config-")
old_git_config <- Sys.getenv("GIT_CONFIG_GLOBAL", unset = NA_character_)
writeLines(
  c(
    "[safe]",
    paste("\tdirectory =", encodeString(baseline, quote = "\"")),
    paste("\tdirectory =", encodeString(candidate, quote = "\""))
  ),
  git_config
)
Sys.setenv(GIT_CONFIG_GLOBAL = git_config)
baseline_input <- verify_input(baseline, baseline_commit, "baseline")
candidate_input <- verify_input(candidate, candidate_commit, "candidate")
unlink(git_config)
if (is.na(old_git_config)) {
  Sys.unsetenv("GIT_CONFIG_GLOBAL")
} else {
  Sys.setenv(GIT_CONFIG_GLOBAL = old_git_config)
}
baseline_commit <- baseline_input$commit
candidate_commit <- candidate_input$commit
dir.create(out, recursive = TRUE, showWarnings = FALSE)
raw_dir <- file.path(out, "raw")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
rscript <- file.path(R.home("bin"), "Rscript.exe")

run_attempt <- function(attempt) {
  rows <- list()
  row_i <- 1L
  for (length_i in seq_along(lengths)) {
    for (pair in seq_len(pairs)) {
      arms <- if ((pair + length_i) %% 2L == 0L) {
        c("baseline", "candidate")
      } else {
        c("candidate", "baseline")
      }
      for (order in seq_along(arms)) {
        arm <- arms[[order]]
        repo <- if (identical(arm, "baseline")) baseline else candidate
        source_commit <- if (identical(arm, "baseline")) {
          baseline_commit
        } else {
          candidate_commit
        }
        source_tree <- if (identical(arm, "baseline")) {
          baseline_input$tree
        } else {
          candidate_input$tree
        }
        output <- file.path(raw_dir, sprintf(
          "attempt-%d-length-%d-pair-%02d-%s.csv",
          attempt,
          lengths[[length_i]],
          pair,
          arm
        ))
        status <- system2(
          rscript,
          c(
            shQuote(script),
            "--child",
            "--repo", shQuote(repo),
            "--arm", arm,
            "--length", lengths[[length_i]],
            "--pair", pair,
            "--attempt", attempt,
            "--order", order,
            "--source-commit", source_commit,
            "--source-tree", source_tree,
            "--output", shQuote(output)
          )
        )
        if (!identical(status, 0L) || !file.exists(output)) {
          stop("Child measurement failed: ", output, call. = FALSE)
        }
        rows[[row_i]] <- utils::read.csv(
          output,
          stringsAsFactors = FALSE,
          check.names = FALSE
        )
        row_i <- row_i + 1L
      }
    }
  }
  do.call(rbind, rows)
}

summarize_attempt <- function(measurements, attempt) {
  current <- measurements[measurements$attempt == attempt, , drop = FALSE]
  pair_rows <- list()
  row_i <- 1L
  for (length in lengths) {
    for (pair in seq_len(pairs)) {
      x <- current[current$length == length & current$pair == pair, , drop = FALSE]
      baseline_row <- x[x$arm == "baseline", , drop = FALSE]
      candidate_row <- x[x$arm == "candidate", , drop = FALSE]
      stopifnot(nrow(baseline_row) == 1L, nrow(candidate_row) == 1L)
      pair_rows[[row_i]] <- data.frame(
        attempt = attempt,
        length = length,
        pair = pair,
        strict_ratio = candidate_row$strict_prep_s / baseline_row$strict_prep_s,
        end_to_end_ratio = candidate_row$end_to_end_s / baseline_row$end_to_end_s,
        strict_exact = identical(
          candidate_row$strict_hash,
          baseline_row$strict_hash
        ),
        semantics_exact = identical(
          candidate_row$semantic_hash,
          baseline_row$semantic_hash
        )
      )
      row_i <- row_i + 1L
    }
  }
  pair_ratios <- do.call(rbind, pair_rows)
  summaries <- lapply(lengths, function(length) {
    x <- pair_ratios[pair_ratios$length == length, , drop = FALSE]
    data.frame(
      attempt = attempt,
      length = length,
      pairs = nrow(x),
      strict_median_ratio = stats::median(x$strict_ratio),
      end_to_end_median_ratio = stats::median(x$end_to_end_ratio),
      strict_gate = stats::median(x$strict_ratio) <= 0.95,
      end_to_end_gate = stats::median(x$end_to_end_ratio) <= 1.05,
      exact = all(x$strict_exact) && all(x$semantics_exact)
    )
  })
  list(pair_ratios = pair_ratios, summary = do.call(rbind, summaries))
}

measurements <- run_attempt(1L)
record <- summarize_attempt(measurements, 1L)
retry_required <- !all(
  record$summary$strict_gate & record$summary$end_to_end_gate &
    record$summary$exact
)
if (retry_required) {
  retry_measurements <- run_attempt(2L)
  measurements <- rbind(measurements, retry_measurements)
  retry_record <- summarize_attempt(measurements, 2L)
  record$pair_ratios <- rbind(record$pair_ratios, retry_record$pair_ratios)
  record$summary <- rbind(record$summary, retry_record$summary)
}
standing_attempt <- if (retry_required) 2L else 1L
standing <- record$summary[
  record$summary$attempt == standing_attempt,
  ,
  drop = FALSE
]
passed <- all(
  standing$strict_gate & standing$end_to_end_gate & standing$exact
)

utils::write.csv(
  measurements,
  file.path(out, "measurements.csv"),
  row.names = FALSE,
  na = ""
)
utils::write.csv(
  record$pair_ratios,
  file.path(out, "pair_ratios.csv"),
  row.names = FALSE,
  na = ""
)
utils::write.csv(
  record$summary,
  file.path(out, "summary.csv"),
  row.names = FALSE,
  na = ""
)
environment <- data.frame(
  recorded_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  os = paste(Sys.info()[c("sysname", "release", "machine")], collapse = " "),
  r_version = paste(R.version$major, R.version$minor, sep = "."),
  baseline = baseline,
  candidate = candidate,
  baseline_commit = baseline_commit,
  candidate_commit = candidate_commit,
  baseline_tree = baseline_input$tree,
  candidate_tree = candidate_input$tree,
  input_verification = paste(
    "Each arm's supplied commit resolved to HEAD and git status",
    "--porcelain=v1 --untracked-files=all was empty before measurement."
  ),
  lengths = paste(lengths, collapse = ","),
  pairs = pairs,
  retry_rule = paste(
    "Repeat all five alternating fresh-process pairs once if any strict <=0.95,",
    "end-to-end <=1.05, or exactness gate misses; retry stands."
  ),
  retry_ran = retry_required,
  standing_attempt = standing_attempt,
  passed = passed,
  stringsAsFactors = FALSE
)
utils::write.csv(
  environment,
  file.path(out, "environment.csv"),
  row.names = FALSE,
  na = ""
)

if (!passed) {
  stop("LDG-3051 performance gate failed; reject the production candidate.", call. = FALSE)
}
cat("LEDGR_WS37_RECORD_OK\n")
