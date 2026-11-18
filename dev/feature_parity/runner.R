# The feature-path oracle's runner (Cut 22 decision 2, LDG-3249). One arm per
# fresh process: it loads one ledgr (an installed library, or a source tree
# through pkgload), runs every corpus case and writes the observations in
# long form, one row per case and component:
#
#   observations.csv  family, case, component, value (a sha256 digest of the
#                     observed R object, or plain text for counts, routes,
#                     certifications and field unions)
#   provenance.csv    what was loaded: arm, library or source path, the
#                     loaded namespace path, the installed commit marker, the
#                     source tree's commit and status, R/ source hashes, R
#                     and TTR versions, the fault (if any)
#
#   Rscript runner.R --arm=<label> (--lib=<library> | --source=<tree>) --out=<dir> [--fault=<name>]
#
# Faults (decision 2) are deliberate changes applied to the loaded namespace
# in this process only, for check.R's fault controls (faults.R).
local({
  argv <- commandArgs(TRUE)
  arg <- function(name, default = NULL) {
    hit <- grep(paste0("^--", name, "="), argv, value = TRUE)
    if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
  }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  out <- arg("out")
  lib <- arg("lib")
  src <- arg("source")
  fault <- arg("fault", "none")
  if (is.null(out) || is.null(arg("arm")) || (is.null(lib) == is.null(src))) {
    stop("usage: runner.R --arm=<label> (--lib=<dir> | --source=<dir>) --out=<dir> [--fault=<name>]")
  }
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  if (!is.null(lib)) {
    lib <- normalizePath(lib, winslash = "/", mustWork = TRUE)
    .libPaths(c(lib, .libPaths()))
    suppressPackageStartupMessages(library(ledgr))
  } else {
    src <- normalizePath(src, winslash = "/", mustWork = TRUE)
    pkgload::load_all(src, quiet = TRUE, export_all = FALSE)
  }
  ns <- asNamespace("ledgr")
  stopifnot(requireNamespace("TTR", quietly = TRUE), requireNamespace("digest", quietly = TRUE))

  # ---- provenance ---------------------------------------------------------
  marker <- function(dir) {
    files <- file.path(dir, c("LEDGR_INSTALLED_FROM_COMMIT", "ledgr_arm_commit.txt"))
    files <- files[file.exists(files)]
    if (length(files)) paste(readLines(files[[1L]], warn = FALSE), collapse = " ") else ""
  }
  git <- function(...) tryCatch(system2("git", c("-C", shQuote(src), ...), stdout = TRUE, stderr = FALSE),
                                error = function(e) "", warning = function(w) "")
  r_hashes <- if (!is.null(src)) {
    files <- sort(list.files(file.path(src, "R"), pattern = "[.]R$"), method = "radix")
    paste(files, vapply(file.path(src, "R", files), function(f) digest::digest(file = f, algo = "sha256"), ""),
          sep = "=", collapse = ";")
  } else if (file.exists(file.path(lib, "ledgr_arm_r_sources.txt"))) {
    paste(readLines(file.path(lib, "ledgr_arm_r_sources.txt")), collapse = ";")
  } else {
    "installed library without source hashes"
  }
  prov <- data.frame(
    field = c("arm", "library", "source", "namespace_path", "installed_marker", "source_commit",
              "source_status_R", "r_source_hashes", "r_version", "ttr_version", "fault", "field_selector"),
    value = c(arg("arm"), lib %||% "", src %||% "", getNamespaceInfo(ns, "path"),
              if (is.null(lib)) "" else marker(lib),
              if (is.null(src)) "" else paste(git("rev-parse", "HEAD"), collapse = ""),
              if (is.null(src)) "" else paste(git("status", "--porcelain", "--", "R"), collapse = ";"),
              r_hashes, R.version.string, as.character(utils::packageVersion("TTR")), fault,
              exists("ledgr_history_feature_fields", envir = ns, inherits = FALSE)),
    stringsAsFactors = FALSE)
  utils::write.csv(prov, file.path(out, "provenance.csv"), row.names = FALSE)

  set_binding <- function(name, value) {
    unlockBinding(name, ns)
    assign(name, value, envir = ns)
    lockBinding(name, ns)
  }
  wrap <- function(name, make) {
    orig <- get(name, envir = ns)
    set_binding(name, make(orig))
  }

  # ---- faults (applied before the recorders, so the recorders see them) ----
  first_finite <- function(res, f) {
    for (d in seq_along(res)) {
      hit <- which(is.finite(res[[d]]))
      if (length(hit)) { res[[d]][[hit[[1L]]]] <- f(res[[d]][[hit[[1L]]]]); return(res) }
    }
    res
  }
  switch(fault,
    none = NULL,
    changed_value = wrap("ledgr_history_compute_feature_series", function(orig) function(...) {
      first_finite(orig(...), function(x) x + 1) }),
    moved_na = wrap("ledgr_history_compute_feature_series", function(orig) function(...) {
      first_finite(orig(...), function(x) NA_real_) }),
    plane_reason = wrap("ledgr_feature_plane_exceptions", function(orig) function(...) {
      res <- orig(...)
      if (length(res$reason_code)) res$reason_code[[1L]] <- res$reason_code[[1L]] %% 3L + 1L
      res }),
    refusal_class = wrap("ledgr_history_feature_refuse_lookahead", function(orig) function(...) {
      tryCatch(orig(...), ledgr_feature_lookahead_detected = function(e) {
        class(e) <- c("ledgr_feature_prefix_changed", setdiff(class(e), "ledgr_feature_lookahead_detected"))
        stop(e) }) }),
    narrowed_callback = wrap("ledgr_history_feature_frame", function(orig) function(...) {
      frame <- orig(...)
      frame[intersect(names(frame), c("instrument_id", "ts_utc", "close"))] }),
    reordered_causality = wrap("ledgr_history_feature_causality_positions", function(orig) function(...) {
      rev(orig(...)) }),
    wrong_route = wrap("ledgr_feature_certify", function(orig) function(...) {
      cert <- orig(...)
      if (identical(cert$kind, "ttr")) { cert$certification <- "custom"; cert$kind <- NULL }
      cert }),
    # Close review round 1, F3: the candidate treats every field again, values
    # unchanged; only the observed treated fields can show it.
    all_fields = {
      if (!exists("ledgr_history_feature_fields", envir = ns, inherits = FALSE)) {
        stop("fault all_fields needs a candidate with the field selector")
      }
      wrap("ledgr_history_feature_fields", function(orig) function(...) {
        c("open", "high", "low", "close", "volume") })
    },
    stop("unknown fault: ", fault))

  # ---- recorders ----------------------------------------------------------
  # Route counts (the registered raw-call seam, the emitted closure's call,
  # the built-in SMA and the two callback entries), the frames handed to
  # custom callbacks, and the causality probe's definitions, instruments and
  # sampled positions in order.
  rec <- new.env()
  reset <- function() {
    rec$count <- c(strict_sma = 0L, ttr_raw_call = 0L, ttr_call = 0L, series_fn = 0L, fn = 0L)
    rec$custom <- FALSE
    rec$frames <- character()
    rec$causality <- character()
    rec$treated <- character()
    rec$in_causality <- FALSE
    rec$in_read <- FALSE
    rec$handoff <- c(prep_reached = 0L, prep_seen = 0L, causality_checks = 0L,
                     causality_reached = 0L, causality_seen = 0L)
  }
  reset()
  phase <- function() if (isTRUE(rec$in_causality)) "causality" else "prep"
  # The fields actually treated at each hand-off (close review round 1, F3):
  # every ledgr_history_feature_inputs() call, marked as the preparation's or
  # the causality probe's, records the fields its result treats.
  wrap("ledgr_history_feature_inputs", function(orig) function(...) {
    res <- orig(...)
    rec$treated <- c(rec$treated, paste0(phase(), ":", paste(names(res$treated), collapse = ",")))
    key <- paste0(phase(), "_seen")
    rec$handoff[[key]] <- rec$handoff[[key]] + 1L
    res
  })
  # Which hand-offs each case reaches (close review re-review 1, G1), from
  # seams other than the one observed above: every range the calculation or
  # the causality probe gets from ledgr_history_feature_ranges() is handed
  # to ledgr_history_feature_inputs() once, and the read entry hands one
  # instrument's prefix once its bounds are set. The causality probe checks
  # a definition exactly when that definition calculated cells. The pin and
  # the candidate must agree on all of it (the handoffs component).
  wrap("ledgr_history_feature_ranges", function(orig) function(...) {
    res <- orig(...)
    key <- paste0(phase(), "_reached")
    rec$handoff[[key]] <- rec$handoff[[key]] + length(res$start)
    res
  })
  wrap("ledgr_history_feature_planes", function(orig) function(...) {
    old <- rec$in_read
    rec$in_read <- TRUE
    on.exit(rec$in_read <- old)
    orig(...)
  })
  wrap("ledgr_history_feature_bounds", function(orig) function(...) {
    res <- orig(...)
    if (isTRUE(rec$in_read)) rec$handoff[["prep_reached"]] <- rec$handoff[["prep_reached"]] + 1L
    res
  })
  wrap("ledgr_history_feature_causality", function(orig) function(...) {
    old <- rec$in_causality
    rec$in_causality <- TRUE
    on.exit(rec$in_causality <- old)
    orig(...)
  })
  counted <- function(name, key) wrap(name, function(orig) function(...) {
    rec$count[[key]] <- rec$count[[key]] + 1L
    orig(...)
  })
  counted("ledgr_strict_sma_series", "strict_sma")
  counted("ledgr_ttr_raw_call", "ttr_raw_call")
  counted("ledgr_ttr_call", "ttr_call")
  callback <- function(name, key) wrap(name, function(orig) function(f, bars_df, params) {
    rec$count[[key]] <- rec$count[[key]] + 1L
    if (isTRUE(rec$custom)) {
      rec$frames <- c(rec$frames, paste0(paste(names(bars_df), collapse = ","), "#", nrow(bars_df)))
    }
    orig(f, bars_df, params)
  })
  callback("ledgr_call_feature_series_fn", "series_fn")
  callback("ledgr_call_feature_fn", "fn")
  custom_scope <- function(name) wrap(name, function(orig) function(cert, ...) {
    old <- rec$custom
    rec$custom <- identical(cert$certification, "custom")
    on.exit(rec$custom <- old)
    orig(cert, ...)
  })
  custom_scope("ledgr_history_feature_segment")
  wrap("ledgr_history_feature_check_definition", function(orig) function(cert, probe, ...) {
    rec$causality <- c(rec$causality, paste0("def=", cert$def$id, " inst=", probe[[1L]]$inputs$instrument_id))
    rec$handoff[["causality_checks"]] <- rec$handoff[["causality_checks"]] + 1L
    old <- rec$custom
    rec$custom <- identical(cert$certification, "custom")
    on.exit(rec$custom <- old)
    orig(cert, probe, ...)
  })
  wrap("ledgr_history_feature_inputs_prefix", function(orig) function(inputs, k) {
    rec$causality <- c(rec$causality, paste0("k=", k))
    orig(inputs, k)
  })

  # ---- observation --------------------------------------------------------
  dig <- function(x) digest::digest(x, algo = "sha256")
  refusal <- function(e) {
    fields <- unclass(e)[setdiff(names(unclass(e)), c("call", "trace", "parent", "rlang"))]
    c(list(class = class(e)), fields[order(names(fields), method = "radix")])
  }
  rows <- list()
  emit <- function(family, case, component, value) {
    rows[[length(rows) + 1L]] <<- data.frame(family = family, case = case, component = component,
                                             value = as.character(value), stringsAsFactors = FALSE)
  }
  # Runs `expr` with the recorders reset and a fixed seed; emits its route,
  # callback frames, causality, refusal and RNG components and returns the
  # value (NULL on refusal).
  observe <- function(family, case, expr) {
    reset()
    set.seed(20261117L)
    seed <- .Random.seed
    value <- tryCatch(expr, error = function(e) structure(list(refusal(e)), class = "oracle_refusal"))
    emit(family, case, "rng", identical(seed, .Random.seed))
    emit(family, case, "route", paste(names(rec$count), rec$count, sep = "=", collapse = ";"))
    emit(family, case, "callback", dig(rec$frames))
    emit(family, case, "causality", dig(rec$causality))
    emit(family, case, "treated_fields", paste(sort(unique(rec$treated), method = "radix"), collapse = ";"))
    emit(family, case, "handoffs", paste(names(rec$handoff), rec$handoff, sep = "=", collapse = ";"))
    if (inherits(value, "oracle_refusal")) {
      emit(family, case, "refusal", dig(value[[1L]]))
      emit(family, case, "refusal_class", value[[1L]]$class[[1L]])
      return(NULL)
    }
    emit(family, case, "refusal", "none")
    emit(family, case, "refusal_class", "none")
    value
  }

  source(file.path(here, "corpus.R"), local = TRUE)
  all_fields <- c("open", "high", "low", "close", "volume")
  certify <- function(defs) lapply(defs, ns$ledgr_feature_certify)
  cert_text <- function(certs) paste(vapply(certs, function(c) {
    paste0(c$def$id, ":", c$certification, "/", c$kind %||% "custom")
  }, ""), collapse = ";")
  # The field union candidate 2 treats: every field when any definition is
  # custom, otherwise the certified canonical definitions' required fields.
  field_union <- function(certs) {
    if (!length(certs) || any(vapply(certs, function(c) identical(c$certification, "custom"), TRUE))) {
      return(paste(all_fields, collapse = ","))
    }
    used <- unique(unlist(lapply(certs, function(c) c$declarations$required_fields)))
    paste(all_fields[all_fields %in% used], collapse = ",")
  }

  substrates <- fx_substrates()
  sets <- fx_defs()

  # ---- compute: substrate x calculation start x definition set ------------
  for (s in names(substrates)) {
    sub <- substrates[[s]]
    n_axis <- length(sub$axis)
    starts <- list(data_start = NULL, late_start = sub$axis[[max(1L, floor(n_axis / 3))]],
                   past_end = sub$axis[[n_axis]] + 86400)
    for (st in names(starts)) {
      for (set in names(sets)) {
        case <- paste(s, st, set, sep = "|")
        certs <- certify(sets[[set]])
        emit("compute", case, "certification", cert_text(certs))
        emit("compute", case, "field_union", field_union(certs))
        res <- observe("compute", case,
          ns$ledgr_history_compute_feature_series(sub, sets[[set]], calculation_start = starts[[st]]))
        if (is.null(res)) next
        values <- res
        attr(values, "ledgr_feature_planes") <- NULL
        emit("compute", case, "values", dig(values))
        emit("compute", case, "na", dig(lapply(values, is.na)))
        emit("compute", case, "planes", dig(attr(res, "ledgr_feature_planes")))
        proj <- ns$ledgr_projection_from_feature_matrix(res, universe = sub$instrument_ids,
          pulses_posix = sub$axis, feature_engine_version = "fixed", alias_index = NULL)
        emit("compute", case, "proj", dig(proj))
        bound <- ns$ledgr_history_substrate_bind_features(sub, proj)
        emit("compute", case, "reads", dig(lapply(names(res), function(id) tryCatch(
          ns$ledgr_history_feature_evidence(bound, id, seq_along(sub$instrument_ids), seq_len(n_axis), n_axis),
          error = refusal))))
      }
    }
  }

  # ---- single-definition read entry ---------------------------------------
  for (rc in fx_read_entry_cases(sets)) {
    case <- paste(rc$substrate, rc$name, sep = "|")
    sub <- substrates[[rc$substrate]]
    emit("read_entry", case, "certification", cert_text(certify(list(rc$def))))
    res <- observe("read_entry", case, lapply(sub$instrument_ids, function(id) tryCatch(
      ns$ledgr_history_feature_planes(sub, id, rc$def), error = refusal)))
    if (!is.null(res)) emit("read_entry", case, "values", dig(res))
  }

  # ---- the two TTR routes: cached raw call and emitted closure ------------
  # On substrates with one knowledge range the compute path (cached raw call)
  # and the read entry (the emitted series_fn, ledgr_ttr_call) must agree.
  for (s in c("panel_carry5", "panel_strict_outcarry", "empty")) {
    sub <- substrates[[s]]
    # Chosen by the definition (a TTR catalogue row), not by its certification,
    # so a wrong route shows as a difference, not as a missing case.
    route_defs <- c(sets$catalogue_rows, sets$parameterized_single, sets$parameterized_bundle)
    route_tags <- rep(c("", "param:"), c(length(sets$catalogue_rows), length(route_defs) - length(sets$catalogue_rows)))
    for (r in seq_along(route_defs)) {
      def <- route_defs[[r]]
      if (!is.character(def$params$ttr_fn)) next
      case <- paste(s, paste0(route_tags[[r]], def$id), sep = "|")
      res <- observe("ttr_route", case, {
        cached <- ns$ledgr_history_compute_feature_series(sub, list(def))[[1L]]
        closure <- do.call(rbind, lapply(sub$instrument_ids, function(id) {
          ns$ledgr_history_feature_planes(sub, id, def)$value
        }))
        list(cached = unname(cached), closure = unname(closure))
      })
      if (is.null(res)) next
      emit("ttr_route", case, "values", dig(res$cached))
      emit("ttr_route", case, "routes_equal", identical(res$cached, res$closure))
    }
  }

  # ---- the formatted axis at every consumer (cut review 22, R6) -----------
  for (a in names(fx_axes())) {
    axis <- fx_axes()[[a]]
    n <- length(axis)
    m <- list(f1 = matrix(as.numeric(seq_len(2L * n)), nrow = 2L, ncol = n))
    res <- observe("axis", a, {
      proj <- ns$ledgr_projection_from_feature_matrix(m, universe = c("A", "B"), pulses_posix = axis,
                                                      feature_engine_version = "fixed")
      list(proj = proj, slice = ns$ledgr_projection_slice(proj, axis),
           history_axis = ns$ledgr_precompute_history_axis(
             list(axis = axis, data_start_utc = "2021-01-01T00:00:00Z"),
             "2021-01-01T00:00:00Z", "2021-02-01T00:00:00Z"))
    })
    if (is.null(res)) next
    emit("axis", a, "dimnames", dig(dimnames(res$proj$feature_values$f1)))
    emit("axis", a, "pulse_index", dig(res$proj$pulse_index))
    emit("axis", a, "pulses_posix", dig(res$proj$pulses_posix))
    emit("axis", a, "pulses_iso", dig(res$proj$pulses_iso))
    emit("axis", a, "projection", dig(res$proj))
    emit("axis", a, "slice", dig(res$slice))
    emit("axis", a, "axis_hash", res$history_axis$axis_hash)
    emit("axis", a, "history_axis", dig(res$history_axis))
  }

  # ---- public entry points on both clocks ---------------------------------
  # The precompute object's logical content: the declared engine marker is
  # left out (decision 1) and the payload is compared by feature, as matrices
  # with their planes and fingerprint-to-ID mapping, whatever its physical
  # shape. The snapshot ID is generated afresh with every fixture snapshot,
  # so only its agreement with the fixture's is compared.
  precompute_logical <- function(pre, snapshot) {
    pre <- unclass(pre)
    pre$snapshot_id <- identical(pre$snapshot_id, snapshot$snapshot_id)
    pre$feature_engine_version <- NULL
    pre$projection$feature_engine_version <- NULL
    pre$payload <- ns_payload_logical(pre$payload, pre$universe)
    pre
  }
  ns_payload_logical <- function(payload, universe) {
    lapply(payload, function(entry) {
      values <- if (is.list(entry$values)) do.call(rbind, unname(entry$values[universe])) else entry$values
      list(feature_id = entry$feature_id, fingerprint = entry$fingerprint, values = unname(values),
           planes = entry$planes)
    })
  }
  db_dir <- file.path(out, "db")
  unlink(db_dir, recursive = TRUE)
  dir.create(db_dir)
  history <- function(seen) dig(mget(sort(ls(seen), method = "radix"), envir = seen))
  e2e <- function(clock, build) {
    features <- fx_e2e_features()
    ids <- vapply(features, function(f) f$id, "")
    grid <- function(prefix) ledgr::ledgr_grid_named(
      a = list(strategy = list(tag = paste0(prefix, "_a"), features = ids)),
      b = list(strategy = list(tag = paste0(prefix, "_b"), features = ids)))
    seen <- new.env()
    fx <- build(file.path(db_dir, paste0(clock, ".duckdb")), fx_spy(seen), features)
    on.exit(ledgr::ledgr_snapshot_close(fx$snapshot), add = TRUE)
    case <- function(name) paste(clock, name, sep = "|")
    sweep_core <- function(x) {
      x <- as.data.frame(x)
      x[, intersect(c("candidate_id", "status", "stop_reason", "final_equity", "n_trades"), names(x))]
    }
    if (!is.null(observe("e2e", case("run"),
        close(ledgr::ledgr_run(fx$exp, params = list(tag = "run", features = ids), run_id = "run"))))) {
      emit("e2e", case("run"), "history", history(seen))
    }
    rm(list = ls(seen), envir = seen)
    res <- observe("e2e", case("sweep"), ledgr::ledgr_sweep(fx$exp, grid("sweep")))
    if (!is.null(res)) {
      emit("e2e", case("sweep"), "history", history(seen))
      emit("e2e", case("sweep"), "sweep_table", dig(sweep_core(res)))
    }
    rm(list = ls(seen), envir = seen)
    pre <- observe("e2e", case("precompute"), ledgr::ledgr_precompute_features(fx$exp, grid("pre")))
    if (!is.null(pre)) emit("e2e", case("precompute"), "precompute", dig(precompute_logical(pre, fx$snapshot)))
    # Recorded even when the precompute refused, so a case is never dropped.
    res <- observe("e2e", case("precompute_reuse"), if (is.null(pre)) {
      stop("oracle: no precompute object to reuse")
    } else {
      ledgr::ledgr_sweep(fx$exp, grid("pre"), precomputed_features = pre)
    })
    if (!is.null(res)) {
      emit("e2e", case("precompute_reuse"), "history", history(seen))
      emit("e2e", case("precompute_reuse"), "sweep_table", dig(sweep_core(res)))
    }
    rm(list = ls(seen), envir = seen)
    ctx <- observe("e2e", case("inspect"),
                   ledgr::ledgr_pulse_snapshot(fx$exp, ts_utc = fx$axis[[20L]], params = list(tag = "inspect")))
    if (!is.null(ctx)) {
      emit("e2e", case("inspect"), "history", dig(lapply(ids, function(f) ledgr::ledgr_history_frame(
        ctx, feature = f, lookback = Inf, instruments = "decision_axis", min_observations = 0L, layout = "long"))))
    }
    # A scoring start after the data start.
    dated <- build(file.path(db_dir, paste0(clock, "_dated.duckdb")), fx_spy(seen), features,
                   opening_date = as.Date(fx$axis[[10L]]))
    on.exit(ledgr::ledgr_snapshot_close(dated$snapshot), add = TRUE)
    if (!is.null(observe("e2e", case("dated_run"),
        close(ledgr::ledgr_run(dated$exp, params = list(tag = "dated", features = ids), run_id = "dated"))))) {
      emit("e2e", case("dated_run"), "history", history(seen))
    }
    rm(list = ls(seen), envir = seen)
    # A preparation refusal: before any candidate or fold, a FAILED durable
    # run with no strategy call, events or equity.
    bad <- build(file.path(db_dir, paste0(clock, "_refuse.duckdb")), fx_spy(seen),
                 c(features, list(fx_lookahead_feature())))
    on.exit(ledgr::ledgr_snapshot_close(bad$snapshot), add = TRUE)
    observe("e2e", case("refuse_run"),
            ledgr::ledgr_run(bad$exp, params = list(tag = "refuse", features = ids), run_id = "refuse"))
    con <- ns$get_connection(bad$snapshot)
    count <- function(table) if (DBI::dbExistsTable(con, table)) {
      DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s WHERE run_id = 'refuse'", table))$n
    } else NA
    emit("e2e", case("refuse_run"), "store", paste0(
      "status=", ledgr::ledgr_run_info(bad$snapshot, "refuse")$status,
      ";events=", count("ledger_events"), ";equity=", count("equity_curve"), ";strategy_calls=", length(ls(seen))))
    observe("e2e", case("refuse_sweep"), ledgr::ledgr_sweep(bad$exp, grid("bad"), stop_on_error = TRUE))
    observe("e2e", case("refuse_precompute"), ledgr::ledgr_precompute_features(bad$exp, grid("bad")))
    emit("e2e", case("refuse_sweep"), "store", paste0("strategy_calls=", length(ls(seen))))
  }
  e2e("bar_native", fx_bar_native)
  e2e("declared_sessions", fx_declared)

  obs <- do.call(rbind, rows)
  utils::write.csv(obs, file.path(out, "observations.csv"), row.names = FALSE)
  cat("runner:", arg("arm"), "fault", fault, "-", length(unique(paste(obs$family, obs$case))), "cases,",
      nrow(obs), "observations\n")
})
