# The feature bridge (Cut 26 decision 5, cut review 26 R10; LDG-3273): a
# bounded proof that the final feature build hands the lean consumer what
# the accepted feature oracle expects. It is not the parity gate: the gate
# (loop_parity.R) runs the lean loop on the pin d5b3a151 only, so gate runs
# never exercise the new package feature path. The bridge does not run the
# lean loop either; it reads, at every fold-envelope entry, exactly what the
# lean fold reads from the execution (dev/lean_core/loop.R, the projection
# set-up and feature_fn): each strategy-visible feature name resolved through
# the pin's lookup state, its values over the fold's pulses (rows by
# instrument), their NA mask, the indexed planes, the axes and the mapping.
# The full integrated proof (the lean loop on the new feature path) is a
# switch obligation (lean_core_interface.md Section 19.14).
#
# One arm per fresh process, per library (the pin, then the final build):
# the oracle's own e2e fixtures and features (dev/feature_parity/corpus.R:
# the bar-native and declared-session clocks), plus two parameterised
# aliases, two candidates, four routes each: implicit preparation, implicit
# with two workers (the staged history reconstructed in each worker), an
# explicit precompute reused, and that reuse with two workers. Every process
# names its build (namespace path and commit marker). --fault breaks one
# worker's transferred input in that arm: `value` (one projected cell) or
# `mapping` (a candidate's alias map).
#
#   Rscript feature_bridge.R --lib=<library> --label=<arm> --out=<dir> [--fault=value|mapping]
#   Rscript feature_bridge.R --check --pin=<dir> --final=<dir>
#
# The check passes (exit 0) when, in each arm, every route gives every
# candidate the same record, every worker and parent named the arm's own
# build, and the final build's records equal the pin's (no declared
# difference applies: the oracle's e2e cases are equal on both, check.R).
# Otherwise it prints one SIGNAL line per differing component and exits 1.
local({
argv <- commandArgs(TRUE)
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), argv, value = TRUE)
  if (!length(hit)) return(default %||% stop("--", name, "= is required", call. = FALSE))
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
`%||%` <- function(a, b) if (is.null(a)) b else a
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))

if ("--check" %in% argv) {
  read <- function(dir) utils::read.csv(file.path(dir, "bridge.csv"), stringsAsFactors = FALSE)
  pin <- read(normalizePath(arg("pin"), winslash = "/"))
  final <- read(normalizePath(arg("final"), winslash = "/"))
  signals <- character()
  sig <- function(...) signals <<- c(signals, sprintf(...))
  for (a in list(pin = pin, final = final)) {
    label <- a$arm[[1L]]
    builds <- unique(a$build[a$component == "build"])
    if (length(builds) != 1L) sig("SIGNAL build %s: %d builds named: %s", label, length(builds), paste(builds, collapse = " | "))
    if (!all(c("parent", "worker") %in% a$role)) sig("SIGNAL roles %s: parent and worker records required", label)
    v <- a[a$component != "build", ]
    key <- paste(v$fixture, v$candidate, v$component)
    for (k in unique(key)) {
      d <- unique(v$value[key == k])
      if (length(d) != 1L) sig("SIGNAL route %s %s: %d distinct values across routes %s", label, k, length(d),
                               paste(unique(v$route[key == k]), collapse = ","))
    }
    want <- expand.grid(route = c("implicit", "implicit_w2", "reuse", "reuse_w2"), fixture = unique(v$fixture),
                        stringsAsFactors = FALSE)
    have <- unique(paste(v$fixture, v$route))
    if (length(m <- setdiff(paste(want$fixture, want$route), have))) sig("SIGNAL missing %s: %s", label, paste(m, collapse = ", "))
  }
  vp <- unique(pin[pin$component != "build" & pin$route == "implicit", c("fixture", "candidate", "component", "value")])
  vf <- unique(final[final$component != "build", c("fixture", "candidate", "component", "value", "route")])
  for (i in seq_len(nrow(vf))) {
    p <- vp$value[vp$fixture == vf$fixture[[i]] & vp$candidate == vf$candidate[[i]] & vp$component == vf$component[[i]]]
    if (length(p) != 1L || !identical(p, vf$value[[i]])) {
      sig("SIGNAL %s %s %s %s: final differs from the pin", vf$component[[i]], vf$fixture[[i]], vf$route[[i]], vf$candidate[[i]])
    }
  }
  cat(sprintf("pin build: %s\nfinal build: %s\n", paste(unique(pin$build[pin$component == "build"]), collapse = " | "),
              paste(unique(final$build[final$component == "build"]), collapse = " | ")))
  cat(sprintf("records: pin %d, final %d\n", nrow(pin), nrow(final)))
  if (length(signals)) {
    cat(unique(signals), sep = "\n")
    cat("BRIDGE CHECK FAIL\n")
    quit(status = 1L)
  }
  cat("BRIDGE CHECK PASS\n")
  quit(status = 0L)
}

lib <- normalizePath(arg("lib"), winslash = "/", mustWork = TRUE)
out <- normalizePath(arg("out"), winslash = "/", mustWork = FALSE)
label <- arg("label")
fault <- arg("fault", "")
stopifnot(fault %in% c("", "value", "mapping"))
dir.create(out, recursive = TRUE, showWarnings = FALSE)
source(file.path(here, "..", "..", "bench", "v0_2_3_ws16_entry", "common.R"))
ws16_load_installed(lib)
if (!identical(normalizePath(getNamespaceInfo("ledgr", "path"), winslash = "/"), file.path(lib, "ledgr"))) {
  stop("feature_bridge: ledgr was not loaded from ", lib, call. = FALSE)
}
ns <- asNamespace("ledgr")
assign("ns", ns, envir = globalenv())
source(file.path(here, "..", "..", "feature_parity", "corpus.R"))
# Workers load the parent's library, never a source tree (LDG-3271).
wd <- tempfile("bridge_wd_")
dir.create(wd)
setwd(wd)
channel <- file.path(out, "records")
unlink(channel, recursive = TRUE)
dir.create(channel)

# Installs, in the calling process, the record at every fold-envelope entry
# and (in a worker, with --fault) the fault. Self-contained: workers receive
# it serialized.
bridge_install <- function(channel, role, fault) {
  ns <- asNamespace("ledgr")
  rebind <- function(name, make) {
    f <- get(name, envir = ns)
    unlockBinding(name, ns); assign(name, make(f), envir = ns); lockBinding(name, ns)
  }
  dig <- function(x) digest::digest(x, algo = "sha256")
  origin <- normalizePath(getNamespaceInfo("ledgr", "path"), winslash = "/")
  marker <- c(file.path(dirname(origin), "LEDGR_INSTALLED_FROM_COMMIT"), file.path(dirname(origin), "ledgr_arm_commit.txt"))
  marker <- marker[file.exists(marker)]
  build <- paste0(origin, " @ ", if (length(marker)) substr(readLines(marker[[1L]], warn = FALSE)[[1L]], 1L, 8L) else "<no marker>")
  seq <- 0L
  # What the lean fold reads (dev/lean_core/loop.R): the validated execution,
  # its projection indexed at the fold's pulses, and the lookup state the
  # pin builds for the feature IDs and the active aliases.
  consume <- function(execution) {
    execution <- ns$ledgr_validate_execution_spec(execution)
    projection <- execution$history_substrate$feature_projection
    pulses <- execution$pulses_posix
    ids <- execution$instrument_ids
    def_ids <- vapply(execution$feature_defs, function(def) def$id, character(1))
    alias <- ns$ledgr_normalize_alias_map(execution$active_alias_map)
    pidx <- as.integer(unname(projection$pulse_index[ns$ledgr_projection_pulse_names(pulses)]))
    name_state <- ns$ledgr_projection_feature_name_state(projection, feature_ids = def_ids, active_alias_map = alias)
    lookup <- ns$ledgr_projection_feature_lookup_state(projection, feature_ids = def_ids, universe = ids,
      active_alias_map = alias, feature_name_state = name_state)
    visible <- sort(unique(c(def_ids, names(alias))), method = "radix")
    resolved <- vapply(visible, function(nm) ns$ledgr_resolve_feature_name(nm, lookup$name_lookup), "")
    values <- lapply(stats::setNames(resolved, visible), function(f) {
      m <- projection$feature_values[[f]]
      if (is.null(m)) NULL else m[, pidx, drop = FALSE]
    })
    list(values = dig(values),
         na = dig(lapply(values, is.na)),
         planes = dig(list(names = names(projection$feature_values),
                           dims = lapply(projection$feature_values, dim),
                           dimnames = lapply(projection$feature_values, dimnames),
                           instrument_index = projection$instrument_index)),
         axes = dig(list(pulses = format(pulses, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), pidx = pidx,
                         pulse_index = projection$pulse_index, ids = ids)),
         mapping = dig(list(def_ids = def_ids, alias = alias, resolved = resolved)))
  }
  rebind("ledgr_fold_envelope", function(f) function(execution, output_handler) {
    rec <- tryCatch(consume(execution), error = function(e) list(error = conditionMessage(e)))
    seq <<- seq + 1L
    saveRDS(list(role = role, pid = Sys.getpid(), build = build, run_id = as.character(execution$run_id), rec = rec),
            file.path(channel, sprintf("%s_%d_%d.rds", role, Sys.getpid(), seq)))
    f(execution, output_handler)
  })
  if (identical(role, "worker") && identical(fault, "value")) {
    rebind("ledgr_history_worker_take", function(f) function(identity) {
      inv <- f(identity)
      fv <- inv$history_substrate$feature_projection$feature_values
      k <- which(vapply(fv, function(m) any(is.finite(m)), logical(1)))[[1L]]
      cell <- which(is.finite(fv[[k]]))[[1L]]
      fv[[k]][cell] <- fv[[k]][cell] + 1
      inv$history_substrate$feature_projection$feature_values <- fv
      inv
    })
  }
  if (identical(role, "worker") && identical(fault, "mapping")) {
    rebind("ledgr_sweep_worker_eval_candidate_task", function(f) function(task) {
      a <- task$candidate$alias_map
      if (length(a) > 1L) task$candidate$alias_map <- stats::setNames(rev(unname(a)), names(a))
      f(task)
    })
  }
  invisible(build)
}
# Self-contained: serialized without this script's frame.
environment(bridge_install) <- globalenv()
parent_build <- bridge_install(channel, "parent", "")
# Every worker the pin starts installs the record (and the fault) after the
# pin's own setup.
setup <- get("ledgr_parallel_worker_setup", envir = ns)
unlockBinding("ledgr_parallel_worker_setup", ns)
assign("ledgr_parallel_worker_setup", function(workers = 1L, preflight, worker_packages = NULL, backend = "mirai",
                                               backend_available = NULL, dry_run = TRUE) {
  plan <- setup(workers = workers, preflight = preflight, worker_packages = worker_packages, backend = backend,
                backend_available = backend_available, dry_run = dry_run)
  n <- ns$ledgr_parallel_workers_normalize(workers)
  if (!isTRUE(dry_run) && n > 1L) {
    ns$ledgr_parallel_mirai_everywhere_expr(substitute(INSTALL(CHANNEL, "worker", FAULT),
      list(INSTALL = bridge_install, CHANNEL = channel, FAULT = fault)), workers = n)
  }
  plan
}, envir = ns)
lockBinding("ledgr_parallel_worker_setup", ns)

# The oracle's e2e indicators under aliases (a feature map names every
# indicator entry), and two parameterised aliases.
e2e <- fx_e2e_features()
names(e2e) <- paste0("x_", gsub("[^A-Za-z0-9_]", "_", vapply(e2e, function(f) f$id, "")))
features <- c(e2e, list(
  signal = ledgr::ledgr_ind_ttr("RSI", input = "close", n = ledgr::ledgr_param("rsi_n")),
  ledgr::ledgr_ind_ttr_outputs("BBands", input = "close", outputs = c("dn", "up"), n = ledgr::ledgr_param("bb_n"))))
features <- do.call(ledgr::ledgr_feature_map, features)
grid <- ledgr::ledgr_grid_cross(features = ledgr::ledgr_feature_grid(rsi_n = c(3L, 5L), bb_n = 4L),
                                strategy = ledgr::ledgr_strategy_grid(k = 1))
hold <- function(ctx, params) ctx$hold()
rows <- list()
db_dir <- file.path(out, "db")
unlink(db_dir, recursive = TRUE)
dir.create(db_dir)
for (fixture in c("bar_native", "declared_sessions")) {
  build_fx <- if (fixture == "bar_native") fx_bar_native else fx_declared
  fx <- build_fx(file.path(db_dir, paste0(fixture, ".duckdb")), hold, features)
  pre <- ledgr::ledgr_precompute_features(fx$exp, grid)
  routes <- list(
    implicit = function() ledgr::ledgr_sweep(fx$exp, grid),
    implicit_w2 = function() ledgr::ledgr_sweep(fx$exp, grid, workers = 2L),
    reuse = function() ledgr::ledgr_sweep(fx$exp, grid, precomputed_features = pre),
    reuse_w2 = function() ledgr::ledgr_sweep(fx$exp, grid, precomputed_features = pre, workers = 2L))
  for (route in names(routes)) {
    file.remove(list.files(channel, full.names = TRUE))
    res <- routes[[route]]()
    if (!all(res$status == "DONE")) stop("feature_bridge: ", fixture, " ", route, " candidates did not complete", call. = FALSE)
    for (f in list.files(channel, full.names = TRUE)) {
      r <- readRDS(f)
      if (!is.null(r$rec$error)) stop("feature_bridge: ", fixture, " ", route, " record failed: ", r$rec$error, call. = FALSE)
      base <- data.frame(arm = label, fixture = fixture, route = route, candidate = r$run_id, role = r$role, pid = r$pid,
                         build = r$build, stringsAsFactors = FALSE)
      rows[[length(rows) + 1L]] <- cbind(base, component = c("build", names(r$rec)),
                                          value = c(r$build, unlist(r$rec)), stringsAsFactors = FALSE)
    }
    roles <- unique(vapply(list.files(channel, full.names = TRUE), function(f) readRDS(f)$role, ""))
    want <- if (endsWith(route, "_w2")) "worker" else "parent"
    if (!identical(roles, want)) stop("feature_bridge: ", fixture, " ", route, " records came from ", paste(roles, collapse = ","),
                                      ", not ", want, call. = FALSE)
  }
  ledgr::ledgr_snapshot_close(fx$snapshot)
}
res <- do.call(rbind, rows)
utils::write.csv(res, file.path(out, "bridge.csv"), row.names = FALSE)
cat(sprintf("%s: %s; %d records (%d processes), fault %s\n", label, parent_build, nrow(res), length(unique(res$pid)),
            if (nzchar(fault)) fault else "none"))
})
