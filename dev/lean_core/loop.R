# Compact-state lean loop, slice 1 (macro WS16 "Compact-state loop";
# interface Section 19; LDG-3219).
#
# lean_fold_envelope(execution, output_handler) takes the seat of the pinned
# ledgr_fold_envelope (R/fold-engine.R:1670, pin d5b3a151) through
# lean_loop_install(), which only harnesses call. It returns the pin's list and
# leaves the pin's handler effects, inside output_handler$run_transaction().
#
# During the pulse loop it keeps its own position-indexed state and records
# only exceptions, fills and one compact header per pulse; it writes no store
# and builds no hold row. After the loop it expands the committed records and
# hands them to the pin's handler and diagnostic writer in bounded batches
# (diagnostic-records D3 synthesis, accepted 2026-11-10).
#
# Coverage (Section 19.2): anything outside slice 1 is refused before the
# first pulse with `ledgr_lean_not_covered`; the harness then runs the pin.

# The pin's marked gross exposure (ledgr_availability_marked_gross) without
# ifelse(): a zero quantity contributes exactly 0.
lean_gross <- function(q, m) {
  v <- abs(q * m)
  v[which(q == 0)] <- 0
  if (anyNA(v) || !all(is.finite(v))) NA_real_ else sum(v)
}

lean_not_covered <- function(feature) {
  rlang::abort(sprintf("The lean loop does not cover %s (slice 1).", feature),
               class = c("ledgr_lean_not_covered", "ledgr_lean_coverage"), feature = feature)
}

# --- coverage ---------------------------------------------------------------

lean_loop_scan_names <- c(
  "ledgr_history_matrix", "ledgr_history_frame", "ledgr_history_info",
  "ledgr_target_rebalance", "ledgr_target_adjust"
)

lean_loop_coverage <- function(execution) {
  provider <- execution$availability_provider
  substrate <- execution$history_substrate
  n <- length(execution$instrument_ids)
  pulses <- execution$pulses_posix
  if (!is.null(execution$compiled_accounting_model)) lean_not_covered("compiled FIFO")
  if (!identical(execution$event_mode, "buffered")) lean_not_covered("db_live")
  # D3 Section 2: only the pin's default and no control key; a sweep candidate
  # carries the sweep's own 0L.
  if (!(as.integer(execution$checkpoint_every) %in% c(10000L, 0L)) || isTRUE(lean_entry$control_checkpoint)) {
    lean_not_covered("a checkpoint_every control")
  }
  if (!identical(as.integer(execution$start_idx), 1L)) lean_not_covered("restart")
  if (!is.null(execution$decision_due)) lean_not_covered("schedules")
  if (!identical(substrate$clock_kind, "bar_native")) lean_not_covered("declared sessions")
  steps <- environment(execution$cost_resolver)$steps
  if (!all(vapply(steps, function(s) identical(s$type_id, "zero"), logical(1L)))) lean_not_covered("costs")
  if (length(execution$risk_plan$steps) > 0L) lean_not_covered("the risk chain")
  if (!is.null(execution$corporate_action_plan)) lean_not_covered("corporate actions")
  if (length(execution$opening_frozen) > 0L || length(execution$position_fact_unknown_basis) > 0L ||
      any(ledgr_fold_positions_to_vec(execution$state$positions, execution$instrument_ids) != 0) ||
      length(execution$state$lot_state$lot_qty %||% numeric()) > 0L ||
      !identical(as.integer(execution$event_seq_start), 1L)) lean_not_covered("opening positions and imports")
  if (length(provider$identity()$declared_families) > 0L) {
    lean_not_covered("membership, status or lifetime facts")
  }
  opp <- execution$execution_opportunities_posix
  if (length(pulses) > 0L && !identical(as.numeric(opp), as.numeric(pulses[-1L]))) lean_not_covered("declared execution opportunities")
  if (length(opp) > 0L && n > 0L) {
    # The loop's constant execution view (checked per pulse in debug).
    view <- lean_plan_execution_view(provider, as.numeric(opp[[1L]]), execution$instrument_ids)
    if (!isTRUE(all(view$member)) || !isTRUE(!any(view$restricted))) lean_not_covered("execution restrictions")
  }
  cols <- unname(substrate$pulse_index[ledgr_projection_pulse_names(as.POSIXct(pulses, tz = "UTC"))])
  if (anyNA(cols)) lean_not_covered("pulses outside the prepared axis")
  used <- unique(c(cols, cols[length(cols)] + 1L))
  used <- used[used <= length(substrate$axis)]
  if (!all(substrate$bars$observed[, used])) lean_not_covered("missing bars")
  if (!all(is.finite(substrate$bars$close[, used]))) lean_not_covered("missing closes")
  called <- all.names(body(execution$strategy_fn))
  hit <- intersect(called, lean_loop_scan_names)
  if (length(hit) > 0L) lean_not_covered(sprintf("`%s()` in the strategy", hit[[1L]]))
  invisible(cols)
}

# Debug only: the constant fixed-basket packet equals the pin's provider and
# valuation view of the same pulse (an internal hand-off, AGENTS.md).
lean_loop_debug_packet <- function(packet, provider, ts, pos, ids, i, substrate, history_reader) {
  full <- stats::setNames(pos, ids)
  view <- provider$decision_view(ts, full)
  vs <- ledgr_availability_valuation_state(substrate$bars, ids, substrate$axis, .Machine$integer.max,
    ledgr_availability_exhausted_choice(provider$valuation_policy), pulse_columns = history_reader$pulse_columns)
  valuation <- vs$advance(i, as.character(view$axis), held = as.logical(view$held[as.character(view$axis)]))
  columns <- ledgr_carrier_provider_view(ledgr_availability_restrict_frozen(view, valuation), valuation)
  for (name in names(columns)) {
    if (!identical(unname(columns[[name]]), unname(packet[[name]]))) {
      rlang::abort(sprintf("Lean packet field `%s` differs from the pin's provider view at pulse %d.", name, i),
                   class = "ledgr_internal_error")
    }
  }
  invisible(TRUE)
}

# --- context reads (maintainer, 2026-11-10) ---------------------------------
# While the lean loop is installed, `$` on the pulse context and on the
# strategy-state view take these methods: a stored field, a cached lazy
# field or a feature column is read directly; everything else (retired and
# unknown names, NULL fields, dot fields, asset fields) goes to the pin's
# method, so its values, caching, counts and refusals are the pin's.

lean_pin_ctx_dollar <- get("$.ledgr_pulse_context", envir = asNamespace("ledgr"))
lean_pin_state_dollar <- get("$.ledgr_strategy_state_view", envir = asNamespace("ledgr"))
lean_pin_envelope <- get("ledgr_fold_envelope", envir = asNamespace("ledgr"))
lean_name_set <- function(x) list2env(stats::setNames(as.list(rep(TRUE, length(x))), x), parent = emptyenv())
lean_ctx_retired <- lean_name_set(setdiff(ledgr_pulse_context_retired_fields(), "position"))
lean_ctx_asset <- lean_name_set(ledgr_pulse_context_asset_fields())

lean_ctx_dollar <- function(x, name) {
  if (!is.null(lean_ctx_retired[[name]])) return(lean_pin_ctx_dollar(x, name))
  v <- .subset2(x, name)
  if (!is.null(v) && !startsWith(name, ".")) return(v)
  lookup <- .subset2(x, ".pulse_lookup")
  if (is.environment(lookup) && is.environment(cache <- lookup$cache)) {
    hit <- get0(name, envir = cache, inherits = FALSE)
    if (!is.null(hit)) return(hit)
    prepared <- lookup$feature_lookup
    if (is.null(lean_ctx_asset[[name]]) && is.list(prepared) && is.environment(prepared$readable_env) &&
        exists(name, envir = prepared$readable_env, inherits = FALSE)) {
      value <- stats::setNames(as.numeric(lookup$feature_vector(name)), as.character(lookup$universe %||% character()))
      return(ledgr_pulse_context_cache_set(lookup, name, value))
    }
  }
  lean_pin_ctx_dollar(x, name)
}

lean_state_dollar <- function(x, name) {
  v <- .subset2(x, name)
  if (is.null(v)) lean_pin_state_dollar(x, name) else v
}

# flat() is the pin's; hold() returns the aligned finite positions directly.
lean_ctx_helpers <- function(lookup) {
  force(lookup)
  list(
    flat = function(default = 0) ledgr_pulse_context_targets(lookup, default = default),
    hold = function() {
      p <- lookup$positions
      if (is.double(p) && identical(attributes(p), list(names = lookup$universe)) && all(is.finite(p))) p
      else ledgr_pulse_context_current_targets(lookup)
    })
}

# --- the loop ---------------------------------------------------------------

lean_fold_envelope <- function(execution, output_handler) {
  execution <- ledgr_validate_execution_spec(execution)
  # A refusal before the first pulse runs the fold on the pin (19.2).
  pulse_cols <- tryCatch(lean_loop_coverage(execution), ledgr_lean_not_covered = function(c) c)
  if (inherits(pulse_cols, "condition")) {
    lean_entry$refused <- c(lean_entry$refused, pulse_cols$feature)
    return(lean_pin_envelope(execution, output_handler))
  }
  lean_entry$lean_folds <- lean_entry$lean_folds + 1L
  on.exit(lean_stubs_bind(), add = TRUE)
  lean_stubs_bind(lean_stubs)
  run_id <- execution$run_id
  ids <- execution$instrument_ids
  n <- length(ids)
  pulses_posix <- execution$pulses_posix
  pulses_iso <- execution$pulses_iso
  n_pulse <- length(pulses_posix)
  ts_num <- as.numeric(pulses_posix)
  max_pulses <- execution$max_pulses
  state0 <- ledgr_carrier_import_state(execution$state, ids)
  substrate <- execution$history_substrate
  projection <- substrate$feature_projection
  bars <- substrate$bars
  feature_defs <- execution$feature_defs
  def_ids <- if (length(feature_defs) > 0L) vapply(feature_defs, function(def) def$id, character(1)) else character()
  active_alias_map <- ledgr_normalize_alias_map(execution$active_alias_map)
  cost_resolver <- execution$cost_resolver
  provider <- execution$availability_provider
  telemetry <- execution$telemetry
  seed <- execution$seed
  pulse_seeds <- NULL
  if (!is.null(seed)) {
    rng_state <- ledgr_rng_caller_state()
    on.exit(ledgr_rng_restore(rng_state), add = TRUE)
    ledgr_rng_seed_pinned(as.integer(seed))
    pulse_seeds <- ledgr_pulse_seeds(seed, seq_len(n_pulse))
  }
  history_reader <- ledgr_history_substrate_fold_reader(substrate, pulses_posix,
    feature_defs = feature_defs, active_alias_map = active_alias_map)
  epochs <- as.numeric(execution$execution_opportunities_posix %||% pulses_posix[-1L])
  epoch_valid <- ledgr_plan_epoch_valid(epochs)
  max_events <- max(1L, n_pulse * n)
  output_handler$init_buffers(max_events)
  projection_idx <- as.integer(unname(projection$pulse_index[ledgr_projection_pulse_names(pulses_posix)]))
  if (anyNA(projection_idx)) {
    rlang::abort("Runtime projection must cover every fold pulse.", class = "ledgr_invalid_fold_execution")
  }
  feature_name_state <- ledgr_projection_feature_name_state(projection, feature_ids = def_ids,
    active_alias_map = active_alias_map)
  feature_lookup_state <- ledgr_projection_feature_lookup_state(projection, feature_ids = def_ids,
    universe = ids, active_alias_map = active_alias_map, feature_name_state = feature_name_state)
  fill_axis <- ledgr_position_fact_fill_axis(substrate$axis, pulses_posix, execution$execution_opportunities_posix)
  context_build_counts <- new.env(parent = emptyenv())
  context_preparation_counts <- new.env(parent = emptyenv())
  pulse_notes <- new.env(parent = emptyenv())
  pulse_notes$raw_sizing_notice_written <- isTRUE(execution$raw_sizing_notice_written)
  schedule_query <- ledgr_strategy_schedule_query(execution$schedule_sessions, pulses_posix, execution$schedule_params)
  state_declaration <- execution$strategy_state_declaration
  state_defaults <- execution$strategy_state_default_scalars
  strategy_fn <- execution$strategy_fn
  strategy_params <- execution$strategy_params
  strategy_signature <- execution$strategy_call_signature
  strategy_functional <- isTRUE(execution$strategy_is_functional)
  bar_axis <- substrate$axis
  writer_probe <- ledgr_fold_diagnostic_writer(run_id, output_handler)
  can_encode <- isTRUE(writer_probe$can_encode)
  keep_fn <- writer_probe$keep
  writer_probe$release()

  # Run-long state (Section 19.3).
  live <- new.env(parent = emptyenv())
  live$cur_ts <- NA_real_                 # epoch seconds
  live$cur_stage <- "fold"
  live$in_pulses <- FALSE
  live$batches <- 0L
  output_handler <- lean_watch_handler(output_handler, live)
  pos <- state0$positions
  cash <- state0$cash
  book <- state0$lot_state
  position_facts <- execution$position_facts %||% ledgr_position_fact_state(n)
  strategy_state <- execution$strategy_state$values
  state_axis <- execution$strategy_state$axis
  if (!identical(ids, state_axis)) {
    # The pin aligns at the first pulse's P1; the fixed axis never changes.
    strategy_state <- ledgr_strategy_state_align(execution$strategy_state$values,
      execution$strategy_state_declaration, state_axis %||% character(), ids,
      default_scalars = execution$strategy_state_default_scalars)
  }
  status <- "DONE"
  stop_reason <- NA_character_
  processed <- 0L
  full_run <- TRUE
  event_seq <- as.integer(execution$event_seq_start)
  last_fully_valued <- NA_real_          # epoch seconds
  last_executed <- NA_real_             # epoch seconds
  eq <- list(ts = numeric(n_pulse), cash = numeric(n_pulse), positions_value = numeric(n_pulse),
             realized_pnl = numeric(n_pulse), cost_basis = numeric(n_pulse))
  n_eq <- 0L
  # fills: typed columns, doubling capacity
  fcap <- 1024L
  fl <- list(pulse = integer(fcap), k = integer(fcap), pos = integer(fcap), side = integer(fcap),
             qty = numeric(fcap), price = numeric(fcap), fee = numeric(fcap), cash_delta = numeric(fcap),
             position_delta = numeric(fcap), exec_ts = numeric(fcap), position_before = numeric(fcap),
             planned_position_after = numeric(fcap), clean = logical(fcap), info = character(fcap),
             infos = character(fcap), target = numeric(fcap), strategy_target = numeric(fcap),
             close_qty = numeric(fcap), open_qty = numeric(fcap), realized_close = numeric(fcap),
             net_after = numeric(fcap))
  nf <- 0L
  # explicit decision residuals: (pulse, k, strategy target, target, position)
  dcap <- 1024L
  dr <- list(pulse = integer(dcap), k = integer(dcap), target = numeric(dcap), target_after = numeric(dcap),
             position = numeric(dcap))
  nd <- 0L
  # rejections
  rj <- list(pulse = integer(), k = integer(), pos = integer(), primary = character(), reasons = character(),
             target = numeric(), strategy_target = numeric(), position = numeric(), resolved_price = numeric(),
             exec_ts = numeric())
  # per pulse headers
  hd_pre <- integer(n_pulse)          # intent + sizing rows before the decision segment
  hd_intent <- rep(NA_character_, n_pulse)
  hd_sizing <- logical(n_pulse)
  hd_nrej <- integer(n_pulse)
  hd_nfill <- integer(n_pulse)
  hd_fill_start <- integer(n_pulse)   # fills of pulse i are rows hd_fill_start+1 .. +hd_nfill
  hd_all_explicit <- logical(n_pulse) # a stopped pulse stages its whole decision segment
  hd_recon <- matrix(NA_real_, n_pulse, 6L)
  hd_has_recon <- logical(n_pulse)
  hd_stop_detail <- rep(NA_character_, n_pulse)
  n_done <- 0L                        # pulses with a header

  grow <- function(x, cap) lapply(x, function(v) { length(v) <- cap; v })

  # P2 constants of a fixed basket: the availability view is built once;
  # each pulse copies it and sets `held` and `risk_mark`.
  ctx_pos <- seq_len(n)
  ids_attr <- list(names = ids)
  act_tol <- sqrt(.Machine$double.eps)
  lean_exec_view <- function(m) list(member = rep(TRUE, m), restricted = rep(FALSE, m),
    reason_offset = integer(m), reason_count = integer(m), reason_code = integer())
  p2_0 <- ledgr_carrier_p2_input(list(member = rep(TRUE, n), held = rep(FALSE, n),
    target_restricted = rep(FALSE, n), restriction_offset = integer(n), restriction_count = integer(n),
    restriction_code = integer(), priced = rep(TRUE, n), mark_age = integer(n), mark = rep(NA_real_, n),
    mark_source = rep(3L, n)), ids)
  view0 <- p2_0$view
  members0 <- p2_0$members
  id_to_idx <- ledgr_pulse_context_id_to_idx(ids)
  feature_values <- projection$feature_values
  name_lookup <- feature_lookup_state$name_lookup
  n_proj <- length(projection$instrument_index)
  no_basis <- rep(FALSE, n)
  counts <- list(build = context_build_counts, prep = context_preparation_counts)
  schedule_fn <- function(i) { force(i); function(schedule) schedule_query(schedule, i) }
  # The pin's projection accessor composed with its context filter.
  feature_fn <- function(pidx) {
    force(pidx)
    function(feature_name, default = NA_real_) {
      feature_name <- ledgr_resolve_feature_name(feature_name, name_lookup)
      mat <- feature_values[[feature_name]]
      if (is.null(mat)) return(rep(as.numeric(default), n_proj)[ctx_pos])
      as.numeric(mat[, pidx])[ctx_pos]
    }
  }

  # The pulse context: the pin's class, raw-field order and lookup service,
  # filled directly from the prepared planes.
  lean_context <- function(i, col, close, pv, positions_snapshot, view, counts) {
    fv <- feature_fn(projection_idx[[i]])
    lookup <- list2env(list(
      feature_lookup = feature_lookup_state, feature_vector = fv, projection_idx = projection_idx[[i]],
      cutoff_num = ts_num[[i]], readable_feature_names = feature_lookup_state$readable_names,
      bars = list(open = as.numeric(bars$open[, col]), high = as.numeric(bars$high[, col]),
                  low = as.numeric(bars$low[, col]), close = as.numeric(close),
                  volume = as.numeric(bars$volume[, col])),
      positions = positions_snapshot, universe = ids, id_to_idx = id_to_idx, bar_index = integer(),
      availability = view, bars_aligned = TRUE, positions_aligned = TRUE, availability_aligned = TRUE,
      position_facts = list(entry_bar = position_facts$entry_bar, exit_bar = position_facts$exit_bar,
        cost_basis = book$cost_basis_by_inst, position = pos, current_bar = projection_idx[[i]],
        bar_axis = bar_axis, context_pos = ctx_pos, unknown_basis = no_basis),
      cache = new.env(parent = emptyenv())), parent = emptyenv())
    lookup$build_counts <- counts$build
    lookup$preparation_counts <- counts$prep
    helpers <- lean_ctx_helpers(lookup)
    structure(list(
      run_id = run_id, ts_utc = pulses_iso[[i]], universe = ids, .positions = positions_snapshot,
      cash = cash, equity = cash + pv, seed = seed,
      pulse_seed = if (is.null(pulse_seeds)) NULL else pulse_seeds[[i]],
      state = ledgr_strategy_state_view(strategy_state), .safety_state = "GREEN",
      .schedule_query = schedule_fn(i), members = members0, .history = history_reader$view(i),
      .pulse_lookup = lookup, flat = helpers$flat, hold = helpers$hold, .feature_vector = fv,
      .notes = pulse_notes), class = "ledgr_pulse_context")
  }

  # Debug only: the pin's context builder for the same pulse.
  lean_loop_pin_ctx <- function(i, col, close, pv, positions_snapshot, p2) {
    pf_source <- ledgr_position_fact_source(position_facts, book, pos, current_bar = projection_idx[[i]],
      bar_axis = bar_axis, context_pos = ctx_pos, unknown_basis = no_basis)
    ctx <- list(
      run_id = run_id, ts_utc = pulses_iso[[i]], universe = ids, .positions = positions_snapshot,
      cash = cash, equity = cash + pv, seed = seed,
      pulse_seed = if (is.null(pulse_seeds)) NULL else pulse_seeds[[i]],
      state = ledgr_strategy_state_view(strategy_state), .safety_state = "GREEN",
      .schedule_query = schedule_fn(i))
    ctx$members <- p2$members
    ctx$.history <- history_reader$view(i)
    class(ctx) <- "ledgr_pulse_context"
    ctx <- ledgr_update_pulse_context_helpers(ctx,
      bars = list(open = bars$open[, col], high = bars$high[, col], low = bars$low[, col],
                  close = close, volume = bars$volume[, col]),
      features = data.frame(), positions = positions_snapshot, universe = ids, projection = projection,
      pulse_idx = projection_idx[[i]], cutoff_num = ts_num[[i]], feature_ids = def_ids,
      active_alias_map = active_alias_map, feature_name_state = feature_name_state,
      feature_lookup_state = feature_lookup_state, id_to_idx = NULL, availability = p2$view,
      position_facts = pf_source, build_counts = NULL, preparation_counts = NULL,
      bars_aligned = TRUE, positions_aligned = TRUE, availability_aligned = TRUE)
    ctx <- ledgr_filter_pulse_context_features(ctx, ids, ids, context_pos = ctx_pos)
    ctx$.notes <- pulse_notes
    ctx
  }

  # Debug only: the two contexts agree on raw fields, lookup entries and
  # every public read (asset fields, feature columns, flat(), hold()).
  lean_loop_debug_ctx <- function(a, b, i) {
    fail <- function(what) rlang::abort(sprintf("Lean context %s differs from the pin's at pulse %d.", what, i),
                                        class = "ledgr_internal_error")
    ra <- unclass(a); rb <- unclass(b)
    if (!identical(names(ra), names(rb))) fail("raw field order")
    for (nm in names(ra)) {
      if (!is.function(ra[[nm]]) && !is.environment(ra[[nm]]) && !identical(ra[[nm]], rb[[nm]])) fail(nm)
    }
    la <- ra$.pulse_lookup; lb <- rb$.pulse_lookup
    if (!identical(sort(ls(la, all.names = TRUE)), sort(ls(lb, all.names = TRUE)))) fail("lookup names")
    for (nm in setdiff(ls(la, all.names = TRUE), c("cache", "feature_vector", "build_counts", "preparation_counts"))) {
      if (!identical(la[[nm]], lb[[nm]])) fail(paste0("lookup `", nm, "`"))
    }
    # every public read, twice (the second is the cache path), and two refusals
    caught <- function(expr) tryCatch(expr, error = function(e) list(class(e), conditionMessage(e)))
    for (nm in c(setdiff(c(names(a), feature_lookup_state$readable_names), c("flat", "hold")),
                 "bars", "lean_no_such_field", ".notes")) {
      for (rep in 1:2) {
        if (!identical(caught(lean_ctx_dollar(a, nm)), caught(lean_pin_ctx_dollar(b, nm)))) {
          fail(paste0("field `", nm, "`"))
        }
      }
    }
    sa <- lean_pin_ctx_dollar(a, "state"); sb <- lean_pin_ctx_dollar(b, "state")
    for (nm in c(names(unclass(sa)), "lean_no_such_state")) {
      if (!identical(caught(lean_state_dollar(sa, nm)), caught(lean_pin_state_dollar(sb, nm)))) {
        fail(paste0("state `", nm, "`"))
      }
    }
    if (!identical(ra$flat(), rb$flat()) || !identical(ra$hold(), rb$hold())) fail("flat()/hold()")
    for (nm in feature_lookup_state$readable_names) {
      if (!identical(ra$.feature_vector(nm), rb$.feature_vector(nm))) fail(paste0(".feature_vector(", nm, ")"))
    }
    invisible(TRUE)
  }

  # Declared-state patch: the pin's apply_values with the field records
  # looked up once; anything unusual goes to the pin.
  if (is.null(state_defaults)) state_defaults <- ledgr_strategy_state_default_scalars(state_declaration)
  state_fields <- state_declaration$fields %||% list()
  names(state_fields) <- vapply(state_fields, function(f) f$name, character(1L))
  lean_state_patch <- function(update) {
    nm <- names(update)
    if (length(update) == 0L || is.null(nm) || anyNA(nm) || !all(nzchar(nm)) || anyDuplicated(nm) ||
        !all(nm %in% names(strategy_state)) || !all(nm %in% names(state_fields))) {
      return(ledgr_strategy_state_apply_values(strategy_state, update, state_declaration, ids,
        patch = TRUE, default_scalars = state_defaults))
    }
    out <- strategy_state
    for (name in nm) {
      value <- ledgr_strategy_state_validate_value(update[[name]], state_fields[[name]], ids)
      reset <- is.na(value)
      if (any(reset)) value[reset] <- state_defaults[[name]]
      out[[name]] <- value
    }
    out
  }

  run_loop <- function() {
    live$t_start <- ledgr_time_now()
    live$in_pulses <- TRUE
    for (i in seq_len(n_pulse)) {
      ts <- ts_num[[i]]
      live$cur_ts <- ts
      live$cur_stage <- "valuation"
      col <- pulse_cols[[i]]
      close <- bars$close[, col]
      # P1 valuation and equity
      active <- pos != 0
      pv <- if (any(active)) sum(pos[active] * close[active]) else 0
      last_fully_valued <<- ts
      n_eq <<- n_eq + 1L
      eq$ts[[n_eq]] <<- ts_num[[i]]
      eq$cash[[n_eq]] <<- cash
      eq$positions_value[[n_eq]] <<- pv
      eq$realized_pnl[[n_eq]] <<- book$realized_pnl
      eq$cost_basis[[n_eq]] <<- book$total_cost_basis
      n_done <<- i

      # P2 context and strategy: a fresh context per pulse (Section 19.4)
      pos_start <- pos
      positions_snapshot <- stats::setNames(pos, ids)
      view <- view0
      view$held[] <- pos != 0
      view$risk_mark[] <- close
      if (.lean_debug) {
        packet <- list(
          pulse_idx = i, ts = ts_num[[i]], context_pos = ctx_pos, cash = cash, positions_value = pv,
          position = pos, member = rep(TRUE, n), held = pos != 0, buyable = rep(TRUE, n),
          target_restricted = rep(FALSE, n), restriction_offset = integer(n), restriction_count = integer(n),
          restriction_code = integer(), status = rep(3L, n), lifetime = rep(1L, n),
          terminal_event = rep("", n), lifetime_fact_id = rep("", n), mark = close, reference = close,
          source_ts = rep(ts_num[[i]], n), mark_age = integer(n), mark_source = rep(3L, n),
          priced = rep(TRUE, n), permissible = rep(TRUE, n), frozen = rep(FALSE, n))
        lean_loop_debug_packet(packet, provider, pulses_posix[[i]], pos, ids, i, substrate, history_reader)
        p2 <- ledgr_carrier_p2_input(packet, ids)
        if (!identical(p2$view, view) || !identical(p2$members, members0)) {
          rlang::abort(sprintf("Lean availability view differs from the pin's at pulse %d.", i), class = "ledgr_internal_error")
        }
        lean_loop_debug_ctx(lean_context(i, col, close, pv, positions_snapshot, view, NULL),
          lean_loop_pin_ctx(i, col, close, pv, positions_snapshot, p2), i)
      }
      ctx <- lean_context(i, col, close, pv, positions_snapshot, view, counts)
      pulse_notes$sizing_skipped <- character()
      result <- tryCatch({
        live$cur_stage <- "strategy"
        if (strategy_functional) {
          ledgr_call_strategy_fn(strategy_fn, ctx, strategy_params, strategy_signature)
        } else {
          strategy_fn(ctx)
        }
      }, error = function(e) if (inherits(e, "ledgr_lean_coverage")) rlang::cnd_signal(e) else ledgr_abort_strategy_error(e, ctx))
      if (is.object(result) && ledgr_is_strategy_intermediate(result)) ledgr_abort_intermediate_strategy_result(result)
      if (is.numeric(result)) result <- list(targets = result, state_update = NULL)
      if (!is.list(result) || is.null(result$targets)) {
        rlang::abort(sprintf("Strategy must return %s or a list with `targets`.", ledgr_strategy_targets_contract()),
                     class = "ledgr_invalid_strategy_result")
      }
      intent_reason <- ledgr_validate_strategy_intent_reason(result$intent_reason)
      sizing_evidence <- attr(result$targets, "sizing_evidence", exact = TRUE)
      if (!is.null(sizing_evidence)) lean_not_covered("sizing helpers")
      raw_targets <- result$targets
      # Fast path: a full, finite, named numeric vector in context order is
      # returned by the pin's validator unchanged.
      targets <- if (is.numeric(raw_targets) && identical(attributes(raw_targets), ids_attr) &&
                     all(is.finite(raw_targets))) {
        raw_targets
      } else {
        ledgr_validate_strategy_targets(raw_targets, ids, allow_empty = TRUE)
      }
      if (.lean_debug && !identical(targets, ledgr_validate_strategy_targets(raw_targets, ids, allow_empty = TRUE))) {
        rlang::abort(sprintf("Lean target validation differs from the pin's at pulse %d.", i), class = "ledgr_internal_error")
      }
      sq <- as.numeric(targets)
      pre <- 0L
      if (!is.null(intent_reason)) { hd_intent[[i]] <<- intent_reason; pre <- pre + 1L }
      if (!isTRUE(pulse_notes$raw_sizing_notice_written)) {
        hd_sizing[[i]] <<- TRUE
        pre <- pre + 1L
        pulse_notes$raw_sizing_notice_written <- TRUE
      }
      hd_pre[[i]] <<- pre
      tq <- sq
      if (n > 0L) {
        # A fixed basket has no restricted or nonmember instrument, and slice 1
        # has no risk step: the post-risk targets are the strategy targets.
        # Only the short-exposure refusal can fire.
        if (.lean_debug) ledgr_availability_validate_strategy_targets(targets, positions_snapshot, view)
        live$cur_stage <- "risk"
        if (any(sq < pmin(pos, 0))) ledgr_availability_validate_short_exposure(targets, positions_snapshot)
      }

      # P3 plan
      live$cur_stage <- "execution"
      actionable <- which(abs(tq - pos) > act_tol)
      exec_ts <- if (i <= length(epochs)) epochs[[i]] else NA_real_
      batch <- NULL
      if (length(actionable) > 0L) {
        next_col <- if (i < n_pulse) pulse_cols[[i + 1L]] else col + 1L
        has_next <- next_col <= length(bar_axis)
        execution_packet <- list(exec_ts = exec_ts, has_next = has_next,
          open = if (has_next) bars$open[, next_col] else rep(NA_real_, n))
        view <- if (!is.na(exec_ts)) lean_exec_view(length(actionable))
        if (.lean_debug && !is.na(exec_ts)) {
          pv_view <- lean_plan_execution_view(provider, exec_ts, ids[actionable])
          if (!identical(lapply(unclass(pv_view)[names(view)], unname), view)) {
            rlang::abort(sprintf("Lean execution view differs from the provider's at pulse %d.", i), class = "ledgr_internal_error")
          }
        }
        batch <- lean_plan_pulse(context_pos = seq_len(n), target_qty = tq, position = pos,
          actionable_k = actionable, member = rep(TRUE, n), execution = execution_packet,
          execution_view = view, epoch_valid = i > length(epochs) || epoch_valid[[i]],
          cost_resolver = cost_resolver, cash = cash, instrument_ids = ids)
        fill <- batch$fill
        recorded <- cash + sum(fill$cash_delta)
        if (!isTRUE(recorded == batch$expected_final_cash) &&
            !isTRUE(all.equal(as.numeric(recorded), as.numeric(batch$expected_final_cash),
                              tolerance = ledgr_availability_cash_tolerance))) {
          # The affordability reconciliation stop (cut review R1): the whole
          # decision segment is staged, then the stop row; no P4 or P5.
          hd_all_explicit[[i]] <<- TRUE
          lean_loop_add_decisions(seq_len(n), i, sq, tq, pos)
          hd_stop_detail[[i]] <<- canonical_json(list(cash_before = cash,
            virtual_final_cash = batch$expected_final_cash, recorded_final_cash = recorded))
          status <<- "INCOMPLETE"
          stop_reason <<- "affordability_reconciliation_failed"
          processed <<- processed + 1L
          break
        }
      }
      # explicit decision rows: every target that differs from the position
      # (clean fills are taken out below)
      differs <- which(!(is.finite(sq) & sq == pos & is.finite(close)))
      n_fill <- if (is.null(batch)) 0L else length(batch$fill$k)
      n_rej <- if (is.null(batch)) 0L else length(batch$rejection$k)
      clean_k <- integer()
      if (n_fill > 0L) {
        fill <- batch$fill
        fr <- ledgr_carrier_segment_text(fill$info_offset, fill$info_count, fill$info_code, .ledgr_plan_reason_levels)
        k <- fill$k
        clean <- if (can_encode) {
          is.finite(sq[k]) & is.finite(close[k]) & is.finite(fill$position_before) &
            pos[k] == fill$position_before & is.finite(fill$planned_position_after) &
            sq[k] == fill$planned_position_after & !nzchar(fr$reason) & !nzchar(fr$reasons)
        } else rep(FALSE, n_fill)
        clean[is.na(clean)] <- FALSE
        clean_k <- k[clean]
        # P4 apply
        live$cur_stage <- "accounting"
        applied <- lean_lot_fill(book, fill$pos, fill$side, fill$qty, fill$price, fill$fee)
        book <<- applied$book
        fill_bar <- if (i <= length(fill_axis$bar) && !anyNA(fill$exec_ts) &&
                        all(fill$exec_ts == fill_axis$opportunity[[i]])) fill_axis$bar[[i]] else
          ledgr_position_fact_fill_bar(fill_axis, i, fill$exec_ts)
        position_facts <<- ledgr_position_facts_apply(position_facts, fill$pos, fill$position_before,
          fill$planned_position_after, fill_bar, TRUE)
        rows <- nf + seq_len(n_fill)
        if (nf + n_fill > fcap) {
          while (nf + n_fill > fcap) fcap <<- fcap * 2L
          fl <<- grow(fl, fcap)
        }
        hd_fill_start[[i]] <<- nf
        hd_nfill[[i]] <<- n_fill
        a <- applied$applied
        fl$pulse[rows] <<- i
        fl$k[rows] <<- k
        fl$pos[rows] <<- fill$pos
        fl$side[rows] <<- fill$side
        fl$qty[rows] <<- fill$qty
        fl$price[rows] <<- fill$price
        fl$fee[rows] <<- fill$fee
        fl$cash_delta[rows] <<- fill$cash_delta
        fl$position_delta[rows] <<- fill$position_delta
        fl$exec_ts[rows] <<- fill$exec_ts
        fl$position_before[rows] <<- fill$position_before
        fl$planned_position_after[rows] <<- fill$planned_position_after
        fl$clean[rows] <<- clean
        fl$info[rows] <<- fr$reason
        fl$infos[rows] <<- fr$reasons
        fl$target[rows] <<- tq[k]
        fl$strategy_target[rows] <<- sq[k]
        fl$close_qty[rows] <<- a$close_qty
        fl$open_qty[rows] <<- a$open_qty
        fl$realized_close[rows] <<- a$realized_close
        nf <<- nf + n_fill
        event_seq <<- event_seq + n_fill
        pos[fill$pos] <<- book$net_by_inst[fill$pos]
        fl$net_after[rows] <<- book$net_by_inst[fill$pos]
        cash <<- ledgr_cash_scan(cash, fill$cash_delta)[[n_fill]]
        last_executed <<- max(last_executed, fill$exec_ts, na.rm = TRUE)
        if (identical(lean_entry$mutation, "write_in_loop") && nf == n_fill) {
          # Witness only: one real misplaced store write inside the loop.
          output_handler$write_fill_events(fill = fill, i = seq_len(n_fill), instrument_id = ids[fill$pos],
            event_seq = event_seq - n_fill, use_transaction = FALSE)
        }
      }
      if (n_rej > 0L) {
        rejection <- batch$rejection
        rr <- ledgr_carrier_segment_text(rejection$reason_offset, rejection$reason_count,
          rejection$reason_code, .ledgr_plan_reason_levels)
        rj$pulse <<- c(rj$pulse, rep(i, n_rej))
        rj$k <<- c(rj$k, rejection$k)
        rj$pos <<- c(rj$pos, rejection$pos)
        rj$primary <<- c(rj$primary, .ledgr_plan_reason_levels[rejection$primary])
        rj$reasons <<- c(rj$reasons, rr$reasons)
        rj$target <<- c(rj$target, tq[rejection$k])
        rj$strategy_target <<- c(rj$strategy_target, sq[rejection$k])
        rj$position <<- c(rj$position, rejection$position)
        rj$resolved_price <<- c(rj$resolved_price, rejection$resolved_price)
        rj$exec_ts <<- c(rj$exec_ts, rejection$exec_ts)
        hd_nrej[[i]] <<- n_rej
      }
      explicit_k <- if (length(clean_k)) differs[match(differs, clean_k, 0L) == 0L] else differs
      if (length(explicit_k) > 0L) {
        lean_loop_add_decisions(explicit_k, i, sq, tq, pos_start)
      }

      # P5 reconciliation record and state
      live$cur_stage <- "accounting"
      if (!is.null(batch) && !isTRUE(cash == batch$expected_final_cash) && !isTRUE(all.equal(as.numeric(cash), as.numeric(batch$expected_final_cash),
                                               tolerance = ledgr_availability_cash_tolerance))) {
        rlang::abort("Recorded cash does not reconcile with the availability affordability ledger.",
          class = c("ledgr_affordability_reconciliation_failed", "ledgr_invalid_fold_execution"))
      }
      expected <- if (is.null(batch)) cash else batch$expected_final_cash
      fill_cash <- if (n_fill > 0L) batch$fill$cash_delta else numeric()
      intended <- lean_gross(sq, close)
      recon <- c(
        lean_gross(pos, close),
        cash - sum(fill_cash),
        intended,
        intended,                       # no risk step: post-risk == strategy targets
        cash,
        expected)
      ledgr_fold_reconciliation_check(recon[[2L]], recon[[6L]], recon[[5L]], recon[[3L]], recon[[4L]], recon[[1L]])
      if (.lean_debug && !identical(recon[c(1L, 3L, 4L)], c(ledgr_availability_marked_gross(pos, close),
          ledgr_availability_marked_gross(sq, close), ledgr_availability_marked_gross(tq, close)))) {
        rlang::abort(sprintf("Lean gross exposure differs from the pin's at pulse %d.", i), class = "ledgr_internal_error")
      }
      hd_recon[i, ] <<- recon
      hd_has_recon[[i]] <<- TRUE
      state_update <- result$state_update
      if (inherits(state_update, "ledgr_strategy_state_reset")) {
        strategy_state <<- ledgr_strategy_state_defaults(state_declaration, ids, default_scalars = state_defaults)
      } else if (inherits(state_update, "ledgr_strategy_state_patch")) {
        patched <- lean_state_patch(unclass(state_update))
        if (.lean_debug && !identical(patched, ledgr_strategy_state_apply_values(strategy_state,
            unclass(state_update), state_declaration, ids, patch = TRUE, default_scalars = state_defaults))) {
          rlang::abort(sprintf("Lean state patch differs from the pin's at pulse %d.", i), class = "ledgr_internal_error")
        }
        strategy_state <<- patched
      } else if (!is.null(state_update)) {
        strategy_state <<- ledgr_strategy_state_apply_values(strategy_state, state_update,
          state_declaration, ids, patch = FALSE, default_scalars = state_defaults)
      }
      if (identical(lean_entry$mutation, "hold_in_loop") && i == 1L) lean_loop_expand()  # witness only
      processed <<- processed + 1L
      if (processed >= max_pulses) {
        full_run <<- FALSE
        break
      }
    }
    live$in_pulses <- FALSE
    live$t_pulses <- ledgr_time_elapsed(live$t_start, ledgr_time_now())
    t_pub <- ledgr_time_now()
    if (isTRUE(lean_entry$measure)) invisible(gc(reset = TRUE))
    lean_loop_publish()
    if (isTRUE(lean_entry$measure)) lean_loop_last_times$publish_peak_mb <- sum(gc()[, 6L])
    live$t_publish <- ledgr_time_elapsed(t_pub, ledgr_time_now())
    invisible(NULL)
  }

  lean_loop_add_decisions <- function(k, i, sq, tq, position) {
    m <- length(k)
    rows <- nd + seq_len(m)
    if (nd + m > dcap) {
      while (nd + m > dcap) dcap <<- dcap * 2L
      dr <<- grow(dr, dcap)
    }
    dr$pulse[rows] <<- i
    dr$k[rows] <<- k
    dr$target[rows] <<- sq[k]
    dr$target_after[rows] <<- tq[k]
    dr$position[rows] <<- position[k]
    nd <<- nd + m
  }

  # --- after the loop (Section 19.5) --------------------------------------
  lean_loop_publish <- function() {
    ex <- lean_loop_expand()
    writer <- ledgr_fold_diagnostic_writer(run_id, output_handler)
    batches <- function(m) if (m > 0L) split(seq_len(m), ceiling(seq_len(m) / lean_entry$batch_rows)) else list()
    tick <- function() {
      live$batches <- live$batches + 1L
      if (identical(lean_entry$mutation, "batch_fault") && live$batches == 2L) stop("lean witness: batch fault")
    }
    fill <- lapply(fl, function(v) v[seq_len(nf)])
    if (identical(lean_entry$mutation, "fill_price_ulp") && nf > 0L) fill$price[[1L]] <- fill$price[[1L]] * (1 + .Machine$double.eps)
    for (r in batches(nf)) {
      tick()
      block <- output_handler$write_fill_events(fill = fill, i = r, instrument_id = ids[fill$pos[r]],
        event_seq = as.integer(execution$event_seq_start) + r[[1L]] - 1L, use_transaction = FALSE)
      if (is.function(output_handler$record_accounting_fact)) {
        output_handler$record_accounting_fact(block = block, applied = list(close_qty = fill$close_qty[r],
          open_qty = fill$open_qty[r], realized_close = fill$realized_close[r]))
      }
      output_handler$flush_pulse_events()
    }
    if (nf == 0L) output_handler$flush_pulse_events()
    for (r in batches(length(ex$explicit$diagnostic_seq))) {
      tick()
      writer$append_block(lapply(ex$explicit, `[`, r))
    }
    imp <- ex$implicit
    for (r in batches(if (is.null(imp)) 0L else imp$n)) {
      tick()
      writer$append_implicit(c(list(n = length(r)), lapply(imp[names(imp) != "n"], `[`, r)))
    }
    writer$record_coverage(ex$logical_n)
    if (output_handler$pending_event_count() > 0L) output_handler$flush_pending()
    diagnostics <- writer$drain()
    if (full_run) {
      completion <- ledgr_availability_completion_row(run_id = run_id, pulses_posix = pulses_posix,
        status = status, stop_reason = stop_reason,
        affected = list(value = NA_real_, details = list(), ts_utc = as.POSIXct(NA, tz = "UTC"), specified = FALSE),
        last_fully_valued_ts_utc = .POSIXct(last_fully_valued, tz = "UTC"), last_executed_ts_utc = .POSIXct(last_executed, tz = "UTC"))
      output_handler$write_run_evidence(completion, diagnostics)
    } else {
      output_handler$write_run_diagnostics(diagnostics)
    }
    writer$release()
    live$diagnostic_seq <- ex$logical_n
  }

  # Expands the committed records into the writer's explicit block (in
  # diagnostic sequence order) and implicit block (pulse-major, fills then
  # holds), vectorized over rows.
  lean_loop_expand <- function() {
    np <- n_done
    p <- seq_len(np)
    nrec <- as.integer(hd_has_recon[p])
    nstop <- as.integer(!is.na(hd_stop_detail[p]))
    logical_per <- hd_pre[p] + n + hd_nrej[p] + hd_nfill[p] + nrec + nstop
    base <- c(0L, cumsum(logical_per))[p]
    dec0 <- base + hd_pre[p]                       # seq of decision k is dec0 + k
    rej0 <- dec0 + n
    fill0 <- rej0 + hd_nrej[p]
    recon_seq <- fill0 + hd_nfill[p] + 1L
    keep_all <- is.null(keep_fn)
    parts <- list()
    add <- function(seq, pulse, fields) parts[[length(parts) + 1L]] <<- c(list(seq = seq, pulse = pulse), fields)
    # intent and sizing rows
    it <- which(!is.na(hd_intent[p]))
    if (length(it)) add(base[it] + 1L, it, list(stage = "decision", outcome = "recorded", reason_code = "strategy_intent",
      reasons = hd_intent[it]))
    sz <- which(hd_sizing[p])
    if (length(sz)) add(base[sz] + as.integer(!is.na(hd_intent[sz])) + 1L, sz, list(stage = "sizing",
      outcome = "unavailable", reason_code = "sizing_intent_unavailable", reasons = "raw_quantity_targets"))
    # explicit decision rows
    if (nd > 0L) {
      r <- seq_len(nd)
      dp <- dr$pulse[r]; dk <- dr$k[r]
      add(dec0[dp] + dk, dp, list(instrument_id = ids[dk], stage = "decision", outcome = "recorded",
        reason_code = "decision_recorded", reasons = "decision_recorded", target = dr$target[r],
        quantity = dr$position[r], price = bars$close[cbind(dk, pulse_cols[dp])], mark_source = "current_close",
        mark_age = 0L, target_before_risk = dr$target[r], target_after_risk = dr$target_after[r],
        position_before = dr$position[r], position_after = dr$position[r]))
    }
    # rejections
    if (length(rj$k) > 0L) {
      rp <- rj$pulse
      within <- ave(rp, rp, FUN = seq_along)
      add(rej0[rp] + within, rp, list(instrument_id = ids[rj$pos], stage = "execution", outcome = "no_fill",
        reason_code = rj$primary, reasons = rj$reasons, target = rj$target, quantity = rj$position,
        price = rj$resolved_price, execution_ts_utc = rj$exec_ts, target_before_risk = rj$strategy_target,
        target_after_risk = rj$target, position_before = rj$position, position_after = rj$position))
    }
    # non-clean fills
    if (nf > 0L) {
      r <- seq_len(nf)
      fp <- fl$pulse[r]
      within <- r - hd_fill_start[fp]
      xf <- which(!fl$clean[r])
      if (length(xf)) add(fill0[fp[xf]] + within[xf], fp[xf], list(instrument_id = ids[fl$pos[xf]],
        stage = "execution", outcome = "filled", reason_code = fl$info[xf], reasons = fl$infos[xf],
        target = fl$target[xf], quantity = fl$qty[xf], price = fl$price[xf], execution_ts_utc = fl$exec_ts[xf],
        event_seq = as.integer(execution$event_seq_start) + xf - 1L, target_before_risk = fl$strategy_target[xf],
        target_after_risk = fl$target[xf], position_before = fl$position_before[xf],
        position_after = fl$planned_position_after[xf]))
    }
    # reconciliation rows
    rc <- which(hd_has_recon[p])
    if (length(rc)) {
      detail <- vapply(rc, function(j) ledgr_fold_reconciliation_detail(
        cash_before = hd_recon[j, 2L], virtual_final_cash = hd_recon[j, 6L], recorded_final_cash = hd_recon[j, 5L],
        intended_gross_exposure = hd_recon[j, 3L], post_risk_gross_exposure = hd_recon[j, 4L],
        actual_gross_exposure = hd_recon[j, 1L]), character(1L))
      add(recon_seq[rc], rc, list(stage = "reconciliation", outcome = "reconciled",
        reason_code = "affordability_reconciled", reasons = "affordability_reconciled", detail_json = detail))
    }
    st <- which(!is.na(hd_stop_detail[p]))
    if (length(st)) add(fill0[st] + hd_nfill[st] + 1L, st, list(stage = "affordability", outcome = "stopped",
      reason_code = "affordability_reconciliation_failed", reasons = "affordability_reconciliation_failed",
      detail_json = hd_stop_detail[st]))
    explicit <- lean_loop_explicit_block(parts)

    # holds: every decision cell that is neither explicit nor a clean fill
    implicit <- NULL
    if (can_encode && np > 0L) {
      hold <- matrix(TRUE, n, np)
      hold[, hd_all_explicit[p]] <- FALSE
      if (nd > 0L) hold[cbind(dr$k[seq_len(nd)], dr$pulse[seq_len(nd)])] <- FALSE
      cf <- if (nf > 0L) which(fl$clean[seq_len(nf)]) else integer()
      if (length(cf)) hold[cbind(fl$k[cf], fl$pulse[cf])] <- FALSE
      if (length(rj$k)) hold[cbind(rj$k, rj$pulse)] <- FALSE
      if (identical(lean_entry$mutation, "drop_hold")) hold[which(hold)[[1L]]] <- FALSE
      hc <- which(hold)
      lean_entry$hold_calls <- lean_entry$hold_calls + live$in_pulses
      lean_entry$hold_rows <- lean_entry$hold_rows + live$in_pulses * length(hc)
      hk <- (hc - 1L) %% n + 1L
      hp <- (hc - 1L) %/% n + 1L
      hpos <- lean_loop_positions_at(hk, hp)
      if (identical(lean_entry$mutation, "hold_position")) hpos[[1L]] <- hpos[[1L]] + 1
      # clean fills first, then holds, per pulse: order by (pulse, kind, row)
      fk <- fl$k[cf]; fpl <- fl$pulse[cf]
      ord <- order(c(fpl, hp), c(rep(0L, length(cf)), rep(1L, length(hc))), method = "radix")
      kk <- c(fk, hk)[ord]
      pp <- c(fpl, hp)[ord]
      within_fill <- cf - hd_fill_start[fpl]
      m <- length(ord)
      exec_seq <- c(fill0[fpl] + within_fill, rep(NA_integer_, length(hc)))[ord]
      implicit <- list(
        n = m,
        run_id = rep_len(as.character(run_id), m),
        decision_seq = as.integer(dec0[pp] + kk),
        execution_seq = as.integer(exec_seq),
        decision_order = as.numeric((kk - 1) * n + kk),
        ts_utc = ts_num[pp],
        instrument_id = ids[kk],
        target = c(fl$target[cf], hpos)[ord],
        position_before = c(fl$position_before[cf], hpos)[ord],
        decision_price = bars$close[cbind(kk, pulse_cols[pp])],
        decision_mark_source = rep_len("current_close", m),
        decision_mark_age = rep_len(0L, m),
        fill_quantity = c(fl$qty[cf], rep(NA_real_, length(hc)))[ord],
        fill_price = c(fl$price[cf], rep(NA_real_, length(hc)))[ord],
        execution_ts_utc = c(fl$exec_ts[cf], rep(NA_real_, length(hc)))[ord],
        event_seq = c(as.integer(execution$event_seq_start) + cf - 1L, rep(NA_integer_, length(hc)))[ord],
        position_after = c(fl$planned_position_after[cf], hpos)[ord]
      )
    }
    # The sink's keep rule, as the pin applies it at every pulse flush. A
    # memory sink (no codec) never keeps a current-close decision row or a
    # fill row in slice 1, so holds and clean fills are not built for it.
    if (!keep_all) explicit <- lean_loop_keep(explicit)
    list(explicit = explicit, implicit = implicit, logical_n = as.integer(sum(logical_per)))
  }

  lean_loop_keep <- function(block) {
    if (length(block$diagnostic_seq) == 0L) return(block)
    k <- keep_fn(block, length(block$diagnostic_seq))
    lapply(block, function(v) v[k])
  }

  # Position of instrument hk entering pulse hp: the book net after the
  # instrument's latest fill on an earlier pulse (the fill's recorded
  # position after), else the opening position; never a sum of deltas.
  lean_loop_positions_at <- function(hk, hp) {
    out <- state0$positions[hk]
    if (nf == 0L || length(hk) == 0L) return(out)
    r <- seq_len(nf)
    stride <- n_done + 1L
    # P[pulse + 1, k] = position after the fill on `pulse`
    key_fill <- (fl$pos[r] - 1L) * stride + fl$pulse[r] + 1L
    val <- numeric(n * stride)
    has <- logical(n * stride)
    val[key_fill] <- fl$net_after[r]
    has[key_fill] <- TRUE
    idx <- seq_len(n * stride)
    last <- cummax(ifelse(has, idx, (idx - 1L) %/% stride * stride))
    at <- (hk - 1L) * stride + hp
    src <- last[at]
    found <- src %% stride != 0L
    out[found] <- val[src[found]]
    out
  }

  lean_loop_explicit_block <- function(parts) {
    names_out <- names(ledgr_availability_diagnostic_columns(0L))
    if (length(parts) == 0L) {
      out <- ledgr_availability_diagnostic_columns(0L)
      return(out)
    }
    m <- vapply(parts, function(x) length(x$seq), integer(1))
    total <- sum(m)
    seq <- unlist(lapply(parts, `[[`, "seq"), use.names = FALSE)
    pulse <- unlist(lapply(parts, `[[`, "pulse"), use.names = FALSE)
    defaults <- .ledgr_diagnostic_defaults
    field <- function(name) {
      pieces <- lapply(seq_along(parts), function(j) {
        v <- parts[[j]][[name]]
        if (is.null(v)) v <- if (identical(name, "decision_ts_utc")) ts_num[parts[[j]]$pulse] else defaults[[name]]
        rep_len(v, m[[j]])
      })
      unlist(pieces, use.names = FALSE)
    }
    ord <- order(seq, method = "radix")
    col <- function(name, type) {
      v <- field(name)[ord]
      switch(type, character = as.character(v), integer = as.integer(v), double = as.numeric(v))
    }
    st <- .ledgr_diagnostic_storage
    out <- list(
      run_id = rep_len(as.character(run_id), total),
      diagnostic_seq = as.integer(seq[ord]),
      ts_utc = .POSIXct(ts_num[pulse[ord]], tz = "UTC"))
    for (name in setdiff(names_out, c("run_id", "diagnostic_seq", "ts_utc"))) {
      v <- col(name, st[[name]])
      if (name %in% .ledgr_diagnostic_epoch_fields) v <- .POSIXct(v, tz = "UTC")
      out[[name]] <- v
    }
    out[names_out]
  }

  loop_start <- ledgr_time_now()
  fold_error <- tryCatch({
    output_handler$run_transaction(run_loop)
    NULL
  }, error = function(e) e)
  if (!is.null(fold_error)) {
    # A coverage condition mid-run aborts the whole lean attempt: no
    # exception row; the harness reruns the workload on the pin (19.2).
    live$in_pulses <- FALSE
    if (inherits(fold_error, "ledgr_lean_not_covered")) {
      lean_entry$backstop <- c(lean_entry$backstop, fold_error$feature)
      rlang::cnd_signal(fold_error)
    }
    if (is.function(output_handler$write_exception_diagnostic)) {
      reason <- as.character(fold_error$reason %||% "")
      if (!nzchar(reason)) reason <- "fold_exception"
      diagnostic <- ledgr_availability_diagnostic_row(run_id = run_id, diagnostic_seq = 1L, ts_utc = .POSIXct(live$cur_ts, tz = "UTC"),
        stage = live$cur_stage, outcome = "error", reason_code = reason,
        detail_json = canonical_json(list(condition_class = class(fold_error), message = conditionMessage(fold_error))))
      try(output_handler$write_exception_diagnostic(diagnostic), silent = TRUE)
    }
    rlang::cnd_signal(fold_error)
  }
  telemetry$t_loop <- ledgr_time_elapsed(loop_start, ledgr_time_now())
  lean_loop_last_times$pulses <- live$t_pulses
  lean_loop_last_times$publish <- live$t_publish
  lean_loop_last_times$capacity <- c(fills_used = nf, fills_allocated = fcap, decisions_used = nd,
    decisions_allocated = dcap, rejections = length(rj$k), pulse_headers = n_pulse, batches = live$batches)
  telemetry$telemetry_samples <- as.integer(telemetry$telemetry_samples %||% 0L)
  equity <- ledgr_carrier_new(list(ts = eq$ts[seq_len(n_eq)], cash = eq$cash[seq_len(n_eq)],
    positions_value = eq$positions_value[seq_len(n_eq)], realized_pnl = eq$realized_pnl[seq_len(n_eq)],
    cost_basis = eq$cost_basis[seq_len(n_eq)], n = n_eq), "equity", NA_integer_)
  list(
    status = status,
    processed = processed,
    full_run = full_run,
    telemetry = telemetry,
    state = list(cash = cash, positions = stats::setNames(pos, ids), lot_state = book),
    strategy_state = ledgr_strategy_state_view(strategy_state),
    next_event_seq = event_seq,
    equity_facts = equity
  )
}
