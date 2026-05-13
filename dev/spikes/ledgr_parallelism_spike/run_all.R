# LDG-2007 parallelism and scale-shape spike runner.
#
# This is exploratory spike code, not package code. Run from the repository root:
# Rscript dev/spikes/ledgr_parallelism_spike/run_all.R

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

required <- c("mirai", "mori", "DBI", "duckdb", "ledgr")
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

section <- function(name) {
  cat("\n##", name, "\n")
}

record <- function(...) {
  cat(sprintf(...), "\n")
}

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

shutdown_daemons <- function() {
  try(mirai::daemons(0), silent = TRUE)
}

start_daemons <- function(n, dispatcher = TRUE) {
  shutdown_daemons()
  mirai::daemons(n, dispatcher = dispatcher)
  invisible(TRUE)
}

mirai_value <- function(x) {
  x[]
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

payload_metrics <- function(obj) {
  list(
    object_mb = bytes_mb(object.size(obj)),
    serialized_mb = bytes_mb(length(serialize(obj, NULL)))
  )
}

send_once <- function(obj) {
  start_daemons(1, dispatcher = FALSE)
  on.exit(shutdown_daemons(), add = TRUE)
  elapsed(mirai::mirai({
    list(
      representation = x$representation,
      n_features = length(x$features),
      n_instruments = length(x$instruments),
      n_bars = x$n_bars
    )
  }, x = obj)[])$seconds
}

send_everywhere <- function(obj, n = 4L) {
  start_daemons(n, dispatcher = FALSE)
  on.exit(shutdown_daemons(), add = TRUE)
  elapsed(mirai::everywhere({ shared_features <- x; TRUE }, x = obj)[])$seconds
}

lookup_probe <- function(obj) {
  start_daemons(1, dispatcher = FALSE)
  on.exit(shutdown_daemons(), add = TRUE)
  mirai::mirai({
    t1 <- system.time({
      one_inst <- vapply(x$values, function(m) m[1, 1], numeric(1))
    })[["elapsed"]]
    t2 <- system.time({
      one_feature_all_inst <- x$values[[1]][1, ]
    })[["elapsed"]]
    list(
      one_instrument_all_features = unname(t1),
      one_feature_all_instruments = unname(t2),
      check = c(length(one_inst), length(one_feature_all_inst))
    )
  }, x = obj)[]
}

spike_1 <- function() {
  section("SPIKE-1")
  out <- list(platform = platform, cycles = list(), dispatcher_false = NULL)
  for (i in 1:3) {
    res <- safe({
      start_daemons(4)
      trivial <- mirai::mirai(1 + 1)[]
      loaded <- mirai::everywhere({
        library(ledgr)
        as.character(utils::packageVersion("ledgr"))
      })[]
      shutdown_daemons()
      list(trivial = trivial, ledgr_versions = loaded)
    })
    out$cycles[[i]] <- res
    record("cycle %d ok=%s", i, res$ok)
  }
  out$dispatcher_false <- safe({
    start_daemons(4, dispatcher = FALSE)
    trivial <- mirai::mirai(1 + 1)[]
    shutdown_daemons()
    trivial
  })
  shutdown_daemons()
  out
}

spike_2 <- function() {
  section("SPIKE-2")
  shapes <- list(
    small = list(n_instruments = 20L, n_bars = 504L, n_features = 3L),
    medium = list(n_instruments = 100L, n_bars = 2520L, n_features = 5L),
    bar_matrix = list(n_instruments = 100L, n_bars = 2520L, n_features = 5L)
  )
  lapply(names(shapes), function(nm) {
    shape <- shapes[[nm]]
    obj <- make_feature_payload(shape$n_instruments, shape$n_bars, shape$n_features)
    met <- payload_metrics(obj)
    one <- safe(send_once(obj))
    every <- safe(send_everywhere(obj))
    record("%s object_mb=%s serialized_mb=%s", nm, met$object_mb, met$serialized_mb)
    list(shape = shape, metrics = met, per_task = one, everywhere = every)
  }) |>
    stats::setNames(names(shapes))
}

spike_3 <- function() {
  section("SPIKE-3")
  mat <- matrix(runif(10000), nrow = 100)
  shared <- mori::share(mat)
  list(
    class = class(shared),
    is_shared = mori::is_shared(shared),
    shared_name = safe(mori::shared_name(shared)),
    send = safe({
      start_daemons(1, dispatcher = FALSE)
      on.exit(shutdown_daemons(), add = TRUE)
      mirai::mirai({
        list(class = class(x), first = x[1, 1], dim = dim(x))
      }, x = shared)[]
    })
  )
}

spike_4 <- function() {
  section("SPIKE-4")
  path <- tempfile("ldg2007-duckdb-", fileext = ".duckdb")
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = path)
  on.exit(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE), add = TRUE)
  bars <- data.frame(
    instrument_id = rep(sprintf("ID%03d", 1:10), each = 1000),
    ts_utc = rep(seq_len(1000), 10),
    open = runif(10000),
    volume = sample(1000:10000, 10000, replace = TRUE)
  )
  DBI::dbWriteTable(con, "bars", bars)
  DBI::dbExecute(con, "CHECKPOINT")
  DBI::dbDisconnect(con, shutdown = TRUE)
  start_daemons(4, dispatcher = FALSE)
  on.exit(shutdown_daemons(), add = TRUE)
  tasks <- lapply(seq_len(8), function(i) {
    mirai::mirai({
      con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = TRUE)
      on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
      DBI::dbGetQuery(con, "select count(*) as n, sum(volume) as volume from bars")
    }, db_path = path)
  })
  lapply(tasks, mirai_value)
}

spike_5 <- function() {
  section("SPIKE-5")
  start_daemons(1, dispatcher = FALSE)
  on.exit(shutdown_daemons(), add = TRUE)
  first <- mirai::mirai({
    .ldg2007_env <- new.env(parent = emptyenv())
    .ldg2007_env$x <- 42
    assign(".ldg2007_env", .ldg2007_env, envir = .GlobalEnv)
    TRUE
  })[]
  second <- mirai::mirai({
    if (exists(".ldg2007_env", envir = .GlobalEnv, inherits = FALSE)) {
      get(".ldg2007_env", envir = .GlobalEnv)$x
    } else {
      NULL
    }
  })[]
  cache_write <- mirai::mirai({
    library(ledgr)
    registry <- get(".ledgr_feature_cache_registry", envir = asNamespace("ledgr"))
    assign("ldg2007_sentinel", 42, envir = registry)
    exists("ldg2007_sentinel", envir = registry, inherits = FALSE)
  })[]
  cache_read <- mirai::mirai({
    library(ledgr)
    registry <- get(".ledgr_feature_cache_registry", envir = asNamespace("ledgr"))
    if (exists("ldg2007_sentinel", envir = registry, inherits = FALSE)) {
      get("ldg2007_sentinel", envir = registry)
    } else {
      NULL
    }
  })[]
  list(
    first = first,
    second = second,
    ledgr_cache_registry_write = cache_write,
    ledgr_cache_registry_read = cache_read
  )
}

spike_6 <- function() {
  section("SPIKE-6")
  shapes <- list(
    eod_many_instruments_few_features = list(n_instruments = 1000L, n_bars = 2520L, n_features = 5L),
    eod_moderate_instruments_many_features = list(n_instruments = 250L, n_bars = 2520L, n_features = 50L),
    intraday_moderate_realistic = list(n_instruments = 100L, n_bars = 100L * 390L, n_features = 10L),
    intraday_feature_width_stress = list(n_instruments = 100L, n_bars = 20L * 390L, n_features = 50L)
  )
  lapply(names(shapes), function(nm) {
    shape <- shapes[[nm]]
    obj <- make_feature_payload(shape$n_instruments, shape$n_bars, shape$n_features)
    met <- payload_metrics(obj)
    one <- safe(send_once(obj))
    every <- safe(send_everywhere(obj))
    lookup <- safe(lookup_probe(obj))
    record("%s object_mb=%s serialized_mb=%s", nm, met$object_mb, met$serialized_mb)
    list(shape = shape, metrics = met, per_task = one, everywhere = every, lookup = lookup)
  }) |>
    stats::setNames(names(shapes))
}

results <- list(
  metadata = list(platform = platform, timestamp = timestamp, r_version = R.version.string),
  packages = setNames(lapply(required, function(p) as.character(utils::packageVersion(p))), required),
  spike_1 = spike_1(),
  spike_2 = spike_2(),
  spike_3 = spike_3(),
  spike_4 = spike_4(),
  spike_5 = spike_5(),
  spike_6 = spike_6()
)

shutdown_daemons()
out_file <- file.path(results_dir, paste0(platform_slug, "-", format(Sys.time(), "%Y%m%d-%H%M%S"), ".rds"))
saveRDS(results, out_file)
cat("\nSaved results:", out_file, "\n")
