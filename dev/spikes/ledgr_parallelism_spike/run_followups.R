# LDG-2007 follow-up spike runner for SPIKE-7 and SPIKE-8.
#
# This is exploratory spike code, not package code. Run from the repository root:
# Rscript dev/spikes/ledgr_parallelism_spike/run_followups.R

repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
local_lib <- if (.Platform$OS.type == "unix") {
  file.path(repo_root, "lib-wsl")
} else {
  file.path(repo_root, "lib")
}
if (dir.exists(local_lib)) {
  old_libs <- Sys.getenv("R_LIBS", unset = "")
  old_user <- Sys.getenv("R_LIBS_USER", unset = "")
  joined <- paste(c(local_lib, old_libs), collapse = .Platform$path.sep)
  joined <- paste(Filter(nzchar, strsplit(joined, .Platform$path.sep, fixed = TRUE)[[1]]), collapse = .Platform$path.sep)
  Sys.setenv(R_LIBS = joined, R_LIBS_USER = paste(c(local_lib, old_user), collapse = .Platform$path.sep))
  .libPaths(c(local_lib, .libPaths()))
}

required <- c("mirai", "mori", "DBI", "duckdb", "ledgr", "jsonlite", "TTR", "dplyr", "tibble")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0L) {
  stop("Missing required packages: ", paste(missing, collapse = ", "), call. = FALSE)
}

library(mirai)

episode_dir <- file.path(repo_root, "dev", "spikes", "ledgr_parallelism_spike")
results_dir <- file.path(episode_dir, "results")
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)

platform <- paste(Sys.info()[["sysname"]], Sys.info()[["release"]])
platform_slug <- tolower(gsub("[^A-Za-z0-9]+", "-", platform))
timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")

section <- function(name) cat("\n##", name, "\n")
record <- function(...) cat(sprintf(...), "\n")
bytes_mb <- function(x) round(as.numeric(x) / 1024^2, 3)
elapsed <- function(expr) {
  t <- system.time(value <- force(expr))
  list(value = value, seconds = unname(t[["elapsed"]]))
}
safe <- function(expr) {
  tryCatch(
    list(ok = TRUE, value = force(expr), error = NA_character_),
    error = function(e) list(ok = FALSE, value = NULL, error = conditionMessage(e))
  )
}
shutdown_daemons <- function() try(mirai::daemons(0), silent = TRUE)
start_daemons <- function(n, dispatcher = FALSE) {
  shutdown_daemons()
  mirai::daemons(n, dispatcher = dispatcher)
  invisible(TRUE)
}

make_feature_payload <- function(n_instruments, n_bars, n_features, seed = 1L) {
  set.seed(seed)
  instruments <- sprintf("ID%05d", seq_len(n_instruments))
  features <- sprintf("feat_%03d", seq_len(n_features))
  values <- vector("list", n_features)
  for (j in seq_len(n_features)) {
    mat <- matrix(runif(n_instruments * n_bars), nrow = n_bars, ncol = n_instruments)
    dimnames(mat) <- list(NULL, instruments)
    values[[j]] <- mat
  }
  names(values) <- features
  list(
    representation = "list_of_feature_matrices",
    instruments = instruments,
    features = features,
    n_bars = n_bars,
    values = values
  )
}

share_payload <- function(payload) {
  payload$representation <- "list_of_mori_shared_feature_matrices"
  payload$values <- lapply(payload$values, mori::share)
  payload
}

measure_transport <- function(payload, iterations = 1000L) {
  start_daemons(1)
  on.exit(shutdown_daemons(), add = TRUE)
  setup <- elapsed(mirai::everywhere({
    library(ledgr)
    registry <- get(".ledgr_feature_cache_registry", envir = asNamespace("ledgr"))
    assign("ldg2007_followup_payload", x, envir = registry)
    TRUE
  }, x = payload)[])
  lookup <- mirai::mirai(
    {
      library(ledgr)
      registry <- get(".ledgr_feature_cache_registry", envir = asNamespace("ledgr"))
      x <- get("ldg2007_followup_payload", envir = registry)
      mem_before <- sum(gc()[, "used"])
      timings <- system.time({
        checksum <- 0
        for (i in seq_len(iterations)) {
          row <- ((i - 1L) %% x$n_bars) + 1L
          col <- ((i - 1L) %% length(x$instruments)) + 1L
          feature <- ((i - 1L) %% length(x$values)) + 1L
          one_inst <- vapply(x$values, function(m) m[row, col], numeric(1))
          one_feature <- x$values[[feature]][row, ]
          end_row <- min(x$n_bars, row + 4L)
          window <- vapply(x$values, function(m) sum(m[row:end_row, col]), numeric(1))
          checksum <- checksum + sum(one_inst) + sum(one_feature) + sum(window)
        }
      })
      mem_after <- sum(gc()[, "used"])
      list(
        elapsed = unname(timings[["elapsed"]]),
        checksum = checksum,
        mem_used_delta = mem_after - mem_before
      )
    },
    iterations = iterations
  )[]
  list(setup_seconds = setup$seconds, lookup = lookup)
}

spike_7 <- function() {
  section("SPIKE-7")
  shapes <- list(
    eod_moderate_instruments_many_features = list(n_instruments = 250L, n_bars = 2520L, n_features = 50L, iterations = 1000L),
    intraday_feature_width_stress = list(n_instruments = 100L, n_bars = 20L * 390L, n_features = 50L, iterations = 1000L)
  )
  lapply(names(shapes), function(nm) {
    shape <- shapes[[nm]]
    plain <- make_feature_payload(shape$n_instruments, shape$n_bars, shape$n_features)
    plain_metrics <- list(
      object_mb = bytes_mb(object.size(plain)),
      serialized_mb = bytes_mb(length(serialize(plain, NULL)))
    )
    plain_res <- safe(measure_transport(plain, iterations = shape$iterations))

    share_time <- elapsed(shared <- share_payload(plain))
    shared_metrics <- list(
      object_mb = bytes_mb(object.size(shared)),
      serialized_mb = bytes_mb(length(serialize(shared, NULL))),
      share_seconds = share_time$seconds,
      all_shared = all(vapply(shared$values, mori::is_shared, logical(1)))
    )
    shared_res <- safe(measure_transport(shared, iterations = shape$iterations))

    record("%s plain_setup=%s shared_setup=%s", nm, plain_res$value$setup_seconds, shared_res$value$setup_seconds)
    rm(plain, shared)
    gc()
    list(
      shape = shape,
      plain_metrics = plain_metrics,
      plain = plain_res,
      shared_metrics = shared_metrics,
      shared = shared_res
    )
  }) |>
    stats::setNames(names(shapes))
}

spike_8 <- function() {
  section("SPIKE-8")
  start_daemons(1)
  on.exit(shutdown_daemons(), add = TRUE)

  no_setup <- list(
    jsonlite_qualified = safe(mirai::mirai({
      jsonlite::toJSON(list(a = 1), auto_unbox = TRUE)
    })[]),
    dplyr_qualified = safe(mirai::mirai({
      out <- dplyr::mutate(data.frame(x = 1), y = x + 1)
      out$y[[1]]
    })[]),
    dplyr_unqualified = safe(mirai::mirai({
      out <- mutate(data.frame(x = 1), y = x + 1)
      out$y[[1]]
    })[]),
    ttr_unqualified = safe(mirai::mirai({
      tail(SMA(1:10, n = 3), 1)
    })[])
  )

  library_setup <- safe(mirai::everywhere({
    library(dplyr)
    library(TTR)
    TRUE
  })[])
  after_library <- list(
    dplyr_unqualified = safe(mirai::mirai({
      out <- mutate(data.frame(x = 1), y = x + 1)
      out$y[[1]]
    })[]),
    ttr_unqualified = safe(mirai::mirai({
      tail(SMA(1:10, n = 3), 1)
    })[]),
    s3_tibble_print = safe(mirai::mirai({
      x <- tibble::tibble(a = 1)
      paste(class(x), collapse = "/")
    })[])
  )

  strict_setup <- safe(mirai::everywhere({
    library(ledgr)
    library(jsonlite)
    library(TTR)
    library(dplyr)
    options(ldg2007_worker_option = "set")
    ldg2007_helper <- function(x) x + 1
    TRUE
  })[])
  after_strict <- list(
    option = safe(mirai::mirai({
      getOption("ldg2007_worker_option", NULL)
    })[]),
    helper = safe(mirai::mirai({
      ldg2007_helper(41)
    })[]),
    search_path = safe(mirai::mirai({
      c(
        dplyr = "package:dplyr" %in% search(),
        TTR = "package:TTR" %in% search(),
        jsonlite = "package:jsonlite" %in% search()
      )
    })[])
  )

  list(
    no_setup = no_setup,
    library_setup = library_setup,
    after_library = after_library,
    strict_setup = strict_setup,
    after_strict = after_strict
  )
}

results <- list(
  metadata = list(platform = platform, timestamp = timestamp, r_version = R.version.string),
  packages = setNames(lapply(required, function(p) as.character(utils::packageVersion(p))), required),
  spike_7 = spike_7(),
  spike_8 = spike_8()
)

shutdown_daemons()
out_file <- file.path(results_dir, paste0(platform_slug, "-followups-", format(Sys.time(), "%Y%m%d-%H%M%S"), ".rds"))
saveRDS(results, out_file)
cat("\nSaved results:", out_file, "\n")
