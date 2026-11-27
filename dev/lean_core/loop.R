# Compact-state lean loop, slices 1-3 (macro WS16 "Compact-state loop";
# interface Sections 19, 19.9 and 19.11; LDG-3219, LDG-3226, LDG-3227,
# LDG-3237 to LDG-3239).
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
# Coverage (Section 19.2): anything outside slices 1-3 and the slice-4 parts
# landed so far (Section 19.13: opening positions and carried openings,
# LDG-3243; corporate actions, LDG-3244; facts, the per-pulse views and the
# context axis, LDG-3246; dispositions and terminal stops, LDG-3247) is
# refused before the first pulse with `ledgr_lean_not_covered`; the harness
# then runs the pin.

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

# --- the harness seam --------------------------------------------------------
# The fold reaches a harness only through `lean_hooks`, a list of functions.
# lean_hooks_inert() is the default: nothing is recorded, watched or forced,
# as in production after the switch. loop_harness.R installs its own set.
#   entry_refusal()        a refusal known at the run's entry (a checkpoint_every
#                          control key), or NULL
#   refused(feature)       a fold was refused before its first pulse
#   fold_start(live)       a lean fold begins; returns the function that ends it
#   handler(h, live)       the output handler the fold uses
#   uncovered()            features a stub reached during this fold
#   mark(feature)          the attempt must rerun on the pin
#   committed(reader)      the committed-prefix reader of the running fold, NULL at its end
#   capacity(default)      the run's fill-event limit
#   batch_rows()           the terminal batch bound
#   hold_expansion(in_pulses, rows)  a hold expansion ran
#   publish(fn)            runs the terminal transfer
#   fold_end(stats)        loop and transfer statistics
lean_hooks_inert <- function() list(
  entry_refusal = function() NULL, refused = function(feature) NULL,
  fold_start = function(live) function() NULL, handler = function(h, live) h,
  uncovered = function() character(), mark = function(feature) NULL,
  committed = function(reader) NULL, capacity = function(default) default,
  batch_rows = function() 65536L, hold_expansion = function(in_pulses, rows) NULL,
  publish = function(fn) fn(), fold_end = function(stats) NULL)
lean_hooks <- lean_hooks_inert()

# A coverage condition raised mid-run: the whole attempt reruns on the pin.
lean_abort_attempt <- function(feature) {
  lean_hooks$mark(feature)
  lean_not_covered(feature)
}

# --- coverage ---------------------------------------------------------------
# Slice 3 (Section 19.11): declared session calendars and history reads in
# the strategy are covered; no strategy body is scanned any more.

lean_loop_coverage <- function(execution, entry = NULL) {
  if (!is.null(entry)) lean_not_covered(entry)
  substrate <- execution$history_substrate
  pulses <- execution$pulses_posix
  # Cut 26: the compiled selector is covered (the E stage runs its admission
  # checks, then the lean R FIFO), and so is restart: every fold invocation
  # starts at pulse one since pulse-level resume was retired
  # (ledgr_run_restart_nonterminal() returns start_idx = 1L).
  if (!identical(execution$event_mode, "buffered")) lean_not_covered("db_live")
  # D3 Section 2: only the pin's default (a control key is an entry refusal); a sweep candidate
  # carries the sweep's own 0L.
  if (!(as.integer(execution$checkpoint_every) %in% c(10000L, 0L))) {
    lean_not_covered("a checkpoint_every control")
  }
  # Corporate actions are covered (LDG-3244, facts.R), with their scheduled
  # dispositions (LDG-3247).
  # Opening positions and carried openings are covered (slice 4, LDG-3243):
  # positions, lots, position facts and the opening event_seq come in
  # through execution; the frozen set and the unknown-basis mask below.
  # Membership, status and lifetime facts and execution restrictions are
  # covered (LDG-3246): such a run takes the marked path, with the
  # provider's views each pulse; without them the constant views hold
  # (checked per pulse in debug).
  cols <- unname(substrate$pulse_index[ledgr_projection_pulse_names(as.POSIXct(pulses, tz = "UTC"))])
  if (anyNA(cols)) lean_not_covered("pulses outside the prepared axis")
  # Missing bars and closes are covered (slice 3): the run takes its marks
  # from the pin's valuation state (marks.R).
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
# While the lean loop is installed, `$` on the pulse context takes this
# method: a stored field, a cached lazy field or a feature column is read
# directly; everything else (retired and unknown names, NULL fields, dot
# fields, asset fields) goes to the pin's method, so its values, caching,
# counts and refusals are the pin's. The strategy-state view keeps the pin's
# method (LDG-3220: a lean one saved no time).

lean_pin_ctx_dollar <- get("$.ledgr_pulse_context", envir = asNamespace("ledgr"))
lean_pin_envelope <- get("ledgr_fold_envelope", envir = asNamespace("ledgr"))
# Committed-prefix reads build their scratch handler from the pin's constructor
# as loaded, so a harness that wraps the constructor never sees it.
lean_pin_output_handler <- get("ledgr_output_handler", envir = asNamespace("ledgr"))
lean_name_set <- function(x) list2env(stats::setNames(as.list(rep(TRUE, length(x))), x), parent = emptyenv())
lean_ctx_retired <- lean_name_set(setdiff(ledgr_pulse_context_retired_fields(), "position"))
lean_ctx_asset <- lean_name_set(ledgr_pulse_context_asset_fields())

lean_ctx_dollar <- function(x, name) {
  if (!is.character(name) || length(name) != 1L || is.na(name) || !nzchar(name)) return(lean_pin_ctx_dollar(x, name))
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

# Fast path for the pin's ledgr_strategy_state_view(), which copies every
# field (x[]) under a class: a list whose only attribute is its names (the
# fold's declared state, empty or not) is shared instead. Values are never
# written in place, so R's copy-on-modify keeps a retained view frozen; any
# other input goes to the pin.
lean_strategy_view <- function(values) {
  if (is.list(values) && identical(names(attributes(values)), "names")) {
    view <- values
    class(view) <- c("ledgr_strategy_state_view", "list")
    if (.lean_debug && !identical(view, ledgr_strategy_state_view(values))) {
      rlang::abort("Lean state view differs from the pin's.", class = "ledgr_internal_error")
    }
    return(view)
  }
  ledgr_strategy_state_view(values)
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

# The envelope's body. lean_fold_envelope (at the end of this file) runs it
# in a hashed frame, or calls this function as it stands with debug on.
lean_fold_envelope_plain <- function(execution, output_handler) {
  execution <- ledgr_validate_execution_spec(execution)
  # A refusal before the first pulse runs the fold on the pin (19.2).
  hooks <- lean_hooks
  pulse_cols <- tryCatch(lean_loop_coverage(execution, hooks$entry_refusal()),
                         ledgr_lean_not_covered = function(c) c)
  if (inherits(pulse_cols, "condition")) {
    hooks$refused(pulse_cols$feature)
    return(lean_pin_envelope(execution, output_handler))
  }
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
  cost_steps <- lean_cost_steps(cost_resolver)  # checks.R: NULL keeps the pin's resolver
  # The pin's compiled risk plan, validated once in E as the pin does
  # (slice 2, Section 19.9).
  risk_plan <- ledgr_risk_validate_compiled_plan(execution$risk_plan)
  has_risk <- length(risk_plan$steps) > 0L
  risk_steps <- lean_risk_steps(risk_plan)  # checks.R: NULL keeps the pin's path
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
  # Slice 3 (marks.R, Section 19.11): a run whose prepared planes hold a
  # missing bar or a non-finite close takes its marks from the pin's
  # valuation state; the schedule, the frozen set and the slice-3 rows. One
  # binding: each binding in this frame slows every lookup (marks.R).
  s3 <- lean_marks_run_state(bars, ids, substrate, provider, history_reader, execution$decision_due,
    as.character(execution$opening_frozen %||% character()), marked = !is.null(execution$corporate_action_plan) ||
      length(setdiff(provider$identity()$declared_families, "sessions")) > 0L)
  epochs <- as.numeric(execution$execution_opportunities_posix %||% pulses_posix[-1L])
  epoch_valid <- ledgr_plan_epoch_valid(epochs)
  # The compiled selector selects nothing (Cut 26 decision 3; D3-A R9 as
  # amended): its admission checks run where the pin runs them
  # (R/fold-engine.R:1741-1748 at d5b3a151); every fold uses the lean R FIFO.
  if (identical(ledgr_normalize_compiled_accounting_model(execution$compiled_accounting_model), "spot_fifo")) {
    ledgr_require_compiled_spot_fifo_dispatch(execution, output_handler)
    if (!is.null(execution$corporate_action_plan)) {
      ledgr_require_compiled_spot_fifo_event_kinds(execution$corporate_action_plan$event_kinds())
    }
  }
  max_events <- max(1L, n_pulse * n)
  output_handler$init_buffers(max_events)
  # Slice 4 (facts.R, Section 19.13): the corporate-action plan, its capture
  # and the accepted rows, and on a marked run each pulse's context; one
  # binding, as s3. Built from the fold's own handler after init_buffers()
  # (its room), before any harness wrapper.
  s4 <- lean_facts_run_state(execution, output_handler, ids, !is.null(s3$state), max_events)
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
  live$ranges <- 0L
  live$max_range_pulses <- 0L
  end_fold <- hooks$fold_start(live)
  on.exit(end_fold(), add = TRUE)
  output_handler <- hooks$handler(output_handler, live)
  pos <- state0$positions
  cash <- state0$cash
  book <- state0$lot_state
  position_facts <- execution$position_facts %||% ledgr_position_fact_state(n)
  strategy_state <- execution$strategy_state$values
  state_axis <- execution$strategy_state$axis
  if (n_pulse > 0L && !identical(ids, state_axis)) {
    # The pin aligns at the first pulse's P1 (with no pulse, never); the
    # fixed axis never changes.
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
             net_after = numeric(fcap), evseq = integer(fcap))   # evseq: numbered around corporate-action rows
  nf <- 0L
  # explicit decision residuals: (pulse, k, strategy target, target, position)
  # Sizing evidence rows (slice 2, Section 19.9), pulse-ordered.
  scap <- 64L
  szr <- list(pulse = integer(scap), id = character(scap), reason = character(scap), reasons = character(scap),
             target = numeric(scap), quantity = numeric(scap), price = numeric(scap), requested = numeric(scap),
             before = numeric(scap))
  nsz <- 0L
  dcap <- 1024L
  dr <- list(pulse = integer(dcap), k = integer(dcap), target = numeric(dcap), target_after = numeric(dcap),
             position = numeric(dcap), mark = numeric(dcap), source = character(dcap), age = integer(dcap),
             reason = character(dcap), reasons = character(dcap))
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
  n_committed <- 0L                   # fill events of completed P5s
  # The run's fill-event limit, as the pin hands it to init_buffers()
  # (D3-B; a harness may lower it through the hooks).
  capacity <- as.integer(hooks$capacity(max_events))
  # Reads during the run see the committed prefix (D3 Section 1;
  # maintainer 2026-11-10: the lean records answer them, the pin's
  # handler stays the terminal sink). The prefix starts with the events a
  # retaining handler already holds at entry (a sweep's opening rows,
  # R/sweep.R:1678; slice 4, decision 4(b)); a draining handler's opening
  # rows are in the store and are not part of its pending count. Accepted
  # corporate-action rows join it at once (P1, before that pulse's strategy
  # call); a draining handler appends them to the store, outside its count.
  pre_events <- s4$pre                # its entry events, read once (facts.R)
  retains <- s4$retains
  hooks$committed(list(
    count = function() NROW(pre_events) + retains * s4$nrows + n_committed,
    events = function() {
      h <- lean_pin_output_handler(ledgr_output_sink_memory(run_id))
      h$init_buffers(max(1L, NROW(pre_events) + s4$nrows + n_committed))
      h$append_event_rows(pre_events)
      ca <- lean_facts_rows(s4)
      all <- max(1L, s4$nrows + n_committed)
      cur <- lean_facts_emit(h, fl, ids, seq_len(n_committed), ca, 1L, all, function() NULL)
      lean_facts_emit_ca(h, ca, cur, .Machine$integer.max, all, function() NULL)
      h$events()
    }))
  on.exit(hooks$committed(NULL), add = TRUE)

  grow <- function(x, cap) lapply(x, function(v) { length(v) <- cap; v })

  # P2 constants of a fixed basket: the availability view is built once;
  # each pulse copies it and sets `held` and `risk_mark`.
  ctx_pos <- seq_len(n)
  ids_attr <- list(names = ids)
  member_all <- rep(TRUE, n)                  # a fixed basket's membership, for the planner
  ids_ok <- lean_targets_axis_ok(ids)          # checks.R: the target check's universe predicate, once
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
  no_basis <- ids %in% execution$position_fact_unknown_basis   # the pin's mask (R/fold-engine.R:1879)
  counts <- list(build = context_build_counts, prep = context_preparation_counts)
  schedule_fn <- function(i) { force(i); function(schedule) schedule_query(schedule, i) }
  # The pin's projection accessor composed with its context filter, bound to
  # the pulse's context positions (a retained context reads its own).
  feature_fn <- function(pidx, cp) {
    force(pidx)
    force(cp)
    function(feature_name, default = NA_real_) {
      feature_name <- ledgr_resolve_feature_name(feature_name, name_lookup)
      mat <- feature_values[[feature_name]]
      if (is.null(mat)) return(rep(as.numeric(default), n_proj)[cp])
      as.numeric(mat[, pidx])[cp]
    }
  }

  # The pulse context: the pin's class, raw-field order and lookup service,
  # filled directly from the prepared planes; on a marked run (`marks`) its
  # universe is the pulse's context, rows ctx_pos (slice 4, decision 7).
  lean_context <- function(i, col, close, pv, positions_snapshot, view, counts, marks = NULL) {
    fv <- feature_fn(projection_idx[[i]], ctx_pos)
    r <- if (is.null(marks)) TRUE else ctx_pos
    u <- if (is.null(marks)) ids else marks$cids
    lookup <- list2env(list(
      feature_lookup = feature_lookup_state, feature_vector = fv, projection_idx = projection_idx[[i]],
      cutoff_num = ts_num[[i]], readable_feature_names = feature_lookup_state$readable_names,
      bars = list(open = as.numeric(bars$open[r, col]), high = as.numeric(bars$high[r, col]),
                  low = as.numeric(bars$low[r, col]), close = as.numeric(close[r]),
                  volume = as.numeric(bars$volume[r, col])),
      positions = positions_snapshot, universe = u, bar_index = integer(),
      id_to_idx = if (is.null(marks)) id_to_idx else ledgr_pulse_context_id_to_idx(u),
      availability = view, bars_aligned = TRUE, positions_aligned = TRUE, availability_aligned = TRUE,
      position_facts = list(entry_bar = position_facts$entry_bar, exit_bar = position_facts$exit_bar,
        cost_basis = book$cost_basis_by_inst, position = pos, current_bar = projection_idx[[i]],
        bar_axis = bar_axis, context_pos = ctx_pos, unknown_basis = no_basis),
      cache = new.env(parent = emptyenv())), parent = emptyenv())
    lookup$build_counts <- counts$build
    lookup$preparation_counts <- counts$prep
    helpers <- lean_ctx_helpers(lookup)
    ctx <- list(
      run_id = run_id, ts_utc = pulses_iso[[i]], universe = u, .positions = positions_snapshot,
      cash = cash, equity = cash + pv, seed = seed,
      pulse_seed = if (is.null(pulse_seeds)) NULL else pulse_seeds[[i]],
      state = lean_strategy_view(strategy_state), .safety_state = "GREEN", .schedule_query = schedule_fn(i),
      members = if (is.null(marks)) members0 else marks$p2$members, .history = history_reader$view(i),
      .pulse_lookup = lookup, flat = helpers$flat, hold = helpers$hold, .feature_vector = fv,
      .notes = pulse_notes)
    class(ctx) <- "ledgr_pulse_context"
    ctx
  }

  # Debug only: the pin's context builder for the same pulse, on its context
  # (R/fold-engine.R:745-810).
  lean_loop_pin_ctx <- function(i, col, close, pv, positions_snapshot, p2) {
    cids <- ids[ctx_pos]
    pf_source <- ledgr_position_fact_source(position_facts, book, pos, current_bar = projection_idx[[i]],
      bar_axis = bar_axis, context_pos = ctx_pos, unknown_basis = no_basis)
    ctx <- list(
      run_id = run_id, ts_utc = pulses_iso[[i]], universe = cids, .positions = positions_snapshot,
      cash = cash, equity = cash + pv, seed = seed,
      pulse_seed = if (is.null(pulse_seeds)) NULL else pulse_seeds[[i]],
      state = ledgr_strategy_state_view(strategy_state), .safety_state = "GREEN",
      .schedule_query = schedule_fn(i))
    ctx$members <- p2$members
    ctx$.history <- history_reader$view(i)
    class(ctx) <- "ledgr_pulse_context"
    ctx <- ledgr_update_pulse_context_helpers(ctx,
      bars = list(open = bars$open[ctx_pos, col], high = bars$high[ctx_pos, col], low = bars$low[ctx_pos, col],
                  close = close[ctx_pos], volume = bars$volume[ctx_pos, col]),
      features = data.frame(), positions = positions_snapshot, universe = cids, projection = projection,
      pulse_idx = projection_idx[[i]], cutoff_num = ts_num[[i]], feature_ids = def_ids,
      active_alias_map = active_alias_map, feature_name_state = feature_name_state,
      feature_lookup_state = feature_lookup_state, id_to_idx = NULL, availability = p2$view,
      position_facts = pf_source, build_counts = NULL, preparation_counts = NULL,
      bars_aligned = TRUE, positions_aligned = TRUE, availability_aligned = TRUE)
    ctx <- ledgr_filter_pulse_context_features(ctx, cids, ids, context_pos = ctx_pos)
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
    for (nm in c(lapply(setdiff(c(names(a), feature_lookup_state$readable_names), c("flat", "hold")), identity),
                 list("bars", "lean_no_such_field", ".notes", "", NULL, character(), NA_character_, c("a", "b"), 1L))) {
      for (rep in 1:2) {
        if (!identical(caught(lean_ctx_dollar(a, nm)), caught(lean_pin_ctx_dollar(b, nm)))) {
          fail(paste0("field `", paste(format(nm), collapse = ","), "`"))
        }
      }
    }
    if (!identical(ra$flat(), rb$flat()) || !identical(ra$hold(), rb$hold())) fail("flat()/hold()")
    # the readable names, then names the resolver refuses
    for (nm in c(lapply(feature_lookup_state$readable_names, identity),
                 list("lean_no_such_feature", "", NA_character_, c("a", "b"), 1L, NULL))) {
      if (!identical(caught(ra$.feature_vector(nm)), caught(rb$.feature_vector(nm)))) {
        fail(paste0(".feature_vector(", paste(format(nm), collapse = ","), ")"))
      }
    }
    invisible(TRUE)
  }

  # Declared-state patch (checks.R, lean_state_apply): the field records
  # looked up once, the state's own names checked once (they change only by
  # reset or replacement, which the patch path re-checks each pulse).
  if (is.null(state_defaults)) state_defaults <- ledgr_strategy_state_default_scalars(state_declaration)
  state_fields <- state_declaration$fields %||% list()
  names(state_fields) <- vapply(state_fields, function(f) f$name, character(1L))
  state_names <- names(strategy_state)
  state_names_ok <- length(state_names) > 0L && !anyNA(state_names) && all(nzchar(state_names)) &&
    !anyDuplicated(state_names) && all(state_names %in% names(state_fields))

  # A stub reached during the callback outranks how the callback ended.
  check_uncovered <- function() {
    u <- hooks$uncovered()
    if (length(u)) lean_not_covered(u[[1L]])
  }

  # --- the pulse stages (macro WS16 compact-state point 1) -----------------
  # Each stage takes the pulse index and what the earlier stages of the same
  # pulse returned, and writes by index into the run-long state above. The
  # loop body only calls them in order.

  # A settlement's returned state installed by the pin's own installer
  # (cash, positions, lot book; position facts of changed positions), its
  # position changes recorded for the implicit records (decision 4(c)) and
  # the event_seq advanced; returns the installed state (facts.R).
  lean_settle <- function(value, i, next_seq = event_seq) {
    fs <- list2env(list(positions = pos, position_facts = position_facts), parent = emptyenv())
    ledgr_carrier_settlement_install(fs, value, projection_idx[[i]])
    lean_facts_moved(s4, i, pos, fs$positions)
    cash <<- fs$cash
    pos <<- fs$positions
    book <<- fs$lot_state
    position_facts <<- fs$position_facts
    event_seq <<- next_seq
    list(cash = cash, positions = pos, lot_state = book, seq = event_seq)
  }

  # P1: corporate actions (slice 4), then valuation at the marks (the close,
  # or on a marked run the pin's marks: the valuation stop, the frozen set's
  # rows) and the equity row.
  lean_p1_value <- function(i) {
    ts <- ts_num[[i]]
    live$cur_ts <- ts
    live$cur_stage <- "valuation"
    col <- pulse_cols[[i]]
    close <- bars$close[, col]
    refused <- NULL
    if (!is.null(s4$plan)) {
      # The plan's clocks, cash posting into the capture and quantity
      # checks, in the pin's order (R/fold-engine.R:363-382; facts.R).
      posted <- lean_facts_post(s4, i, run_id, event_seq, cash, pos, book, ids, close)
      lean_settle(posted$state, i)
      event_seq <<- posted$next_event_seq
      refused <- posted$stopped %||% s4$plan$check_quantity_effects(i)
    }
    if (.lean_debug && !is.null(s4$plan)) lean_facts_debug_settled(s4, i, cash, pos, book)
    mk <- close
    m <- NULL
    if (!is.null(s3$state)) {
      m <- lean_marks_pulse(provider, s3$state, i, pulses_posix[[i]], pos, ids)
      # The dispositions, then the one P1 stop path (facts.R; decision 6).
      d <- lean_facts_dispose(s3, s4, m, i, refused, list(cash = cash, positions = pos, lot_state = book, seq = event_seq),
        function(v, s) lean_settle(v, i, s))
      m <- d$m
      st <- d$stop
      if (!is.null(st)) {
        # before the equity row; the pulse is not counted
        n_done <<- i
        lean_marks_stop(s3, i, st)
        hd_all_explicit[[i]] <<- TRUE
        status <<- "INCOMPLETE"
        stop_reason <<- st$reason
        return(list(stop = TRUE))
      }
      fz <- lean_marks_frozen(m, s3$frozen)
      s3$frozen <- fz$set
      for (g in fz$groups) lean_marks_add_rows(s3, i, 1L, g)
      mk <- m$columns$mark
      # The pulse's context (decision 7): P2-P5 and the records use it, and
      # the strategy state follows it (R/fold-engine.R:546-556).
      ctx_pos <<- m$columns$context_pos
      lean_facts_context(s4, i, ctx_pos)
      if (!identical(m$cids, s4$axis)) strategy_state <<- lean_facts_align(s4, strategy_state, state_declaration,
        m$cids, execution$strategy_state_default_scalars)
    }
    # Marks scattered onto the run axis, summed in run order (R/fold-engine.R:566-577).
    mr <- if (is.null(m)) mk else replace(rep(NA_real_, n), ctx_pos, mk)
    active <- pos != 0
    pv <- if (any(active)) sum(pos[active] * mr[active]) else 0
    last_fully_valued <<- ts
    n_eq <<- n_eq + 1L
    eq$ts[[n_eq]] <<- ts_num[[i]]
    eq$cash[[n_eq]] <<- cash
    eq$positions_value[[n_eq]] <<- pv
    eq$realized_pnl[[n_eq]] <<- book$realized_pnl
    eq$cost_basis[[n_eq]] <<- book$total_cost_basis
    n_done <<- i
    list(col = col, close = close, pv = pv, mk = mk, m = m, stop = FALSE)
  }

  # P2: a fresh context (Section 19.4), the strategy call, the checks on its
  # output, the pin's risk plan (slice 2) and the short-exposure refusal.
  lean_p2_decide <- function(i, v1) {
    marks <- v1$m
    # P2 runs on the pulse's decision axis: the run axis, or on a marked run
    # its context, bound here (decision 7); targets and records stay on it.
    if (!is.null(marks)) {
      ids <- marks$cids; ids_attr <- list(names = ids); ids_ok <- s4$ok; n <- length(ids)
      pos <- pos[ctx_pos]
    }
    if (!is.null(s3$due) && !isTRUE(s3$due[[i]])) {
      # A pulse the schedule does not decide (Section 19.11): no strategy
      # call; the skip row and the evidence rows (marks.R), targets equal
      # positions, no decision cells and no holds.
      for (g in lean_marks_skip_rows(v1$m, ids, pos)) lean_marks_add_rows(s3, i, 1L, g)
      hd_all_explicit[[i]] <<- TRUE
      return(list(result = list(state_update = NULL), sq = pos, tq = pos, pos_start = pos, fields = NULL,
                  risk_ids = character(), stop = FALSE, skip = TRUE))
    }
    col <- v1$col
    close <- v1$close
    pv <- v1$pv
    mk <- v1$mk
    pos_start <- pos
    positions_snapshot <- pos
    names(positions_snapshot) <- ids
    if (is.null(marks)) {
      view <- view0
      view$held[] <- pos != 0
      view$risk_mark[] <- close
    } else {
      view <- marks$p2$view
      if (.lean_debug) lean_loop_debug_ctx(lean_context(i, col, close, pv, positions_snapshot, view, NULL, marks),
        lean_loop_pin_ctx(i, col, close, pv, positions_snapshot, marks$p2), i)
    }
    if (.lean_debug && is.null(marks)) {
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
    ctx <- lean_context(i, col, close, pv, positions_snapshot, view, counts, marks)
    pulse_notes$sizing_skipped <- character()
    result <- tryCatch({
      live$cur_stage <- "strategy"
      if (strategy_functional) {
        ledgr_call_strategy_fn(strategy_fn, ctx, strategy_params, strategy_signature)
      } else {
        strategy_fn(ctx)
      }
    }, error = function(e) {
      # a stub reached in this callback outranks whatever error followed it
      if (inherits(e, "ledgr_lean_coverage")) rlang::cnd_signal(e)
      check_uncovered()
      ledgr_abort_strategy_error(e, ctx)
    })
    check_uncovered()
    if (is.object(result) && ledgr_is_strategy_intermediate(result)) ledgr_abort_intermediate_strategy_result(result)
    if (is.numeric(result)) result <- list(targets = result, state_update = NULL)
    if (!is.list(result) || is.null(result$targets)) {
      rlang::abort(sprintf("Strategy must return %s or a list with `targets`.", ledgr_strategy_targets_contract()),
                   class = "ledgr_invalid_strategy_result")
    }
    intent_reason <- ledgr_validate_strategy_intent_reason(result$intent_reason)
    sizing_evidence <- attr(result$targets, "sizing_evidence", exact = TRUE)
    raw_targets <- result$targets
    # Targets (checks.R, lean_targets): the plain and helper accept paths,
    # or the pin's validator.
    targets <- if (.lean_debug) {
      lean_debug_same(function() lean_targets(raw_targets, ids, ids_attr, ids_ok),
        function() ledgr_validate_strategy_targets(raw_targets, ids, allow_empty = TRUE), "target validation", i)
    } else lean_targets(raw_targets, ids, ids_attr, ids_ok)
    sq <- as.numeric(targets)
    pre <- 0L
    if (!is.null(intent_reason)) { hd_intent[[i]] <<- intent_reason; pre <- pre + 1L }
    # Sizing evidence (Section 19.9; checks.R, lean_sizing_evidence): the
    # validated evidence, or NULL (none, or stale) for the raw path; zero
    # rows write nothing.
    sizing_evidence <- if (.lean_debug) {
      lean_debug_same(function() lean_sizing_evidence(sizing_evidence, targets, ids, pos, mk),
        function() ledgr_validate_sizing_evidence(sizing_evidence, targets = targets, context_ids = ids, position = pos,
          mark = mk), "sizing evidence", i)
    } else lean_sizing_evidence(sizing_evidence, targets, ids, pos, mk)
    # On complete planes no sizing helper can skip an instrument (Section
    # 19.9); on a marked run a skip is the pin's sizing_unavailable path.
    if (.lean_debug && is.null(marks) && length(pulse_notes$sizing_skipped) > 0L) {
      rlang::abort(sprintf("Lean sizing skipped an instrument at pulse %d, unreachable in slice 2.", i),
                   class = "ledgr_internal_error")
    }
    m <- length(sizing_evidence$instrument_id)
    if (m > 0L) {
      lean_loop_add_sizing(sizing_evidence, intent_reason, i, m)
      pre <- pre + m
    } else if (is.null(sizing_evidence) && !isTRUE(pulse_notes$raw_sizing_notice_written)) {
      hd_sizing[[i]] <<- TRUE
      pre <- pre + 1L
      pulse_notes$raw_sizing_notice_written <- TRUE
    }
    hd_pre[[i]] <<- pre
    tq <- sq
    if (n > 0L) {
      # A fixed basket has no restricted or nonmember instrument. The risk
      # plan (lean steps in checks.R, or the pin's for a plan they do not
      # take) transforms the targets; its post-risk quantity recheck runs in
      # debug only (LR-16), its admissibility and the short-exposure refusal
      # in production. Without a risk step the post-risk targets are the
      # strategy targets.
      # A frozen holding is restricted to hold or exit: on a marked run the
      # pin's availability check runs in production (Cut 19 decision 4).
      if (.lean_debug || !is.null(marks)) ledgr_availability_validate_strategy_targets(targets, positions_snapshot, view)
      if (!is.null(marks)) {
        rs <- lean_marks_risk_stop(marks, ids, sq, pos, pulses_posix[[i]])
        if (!is.null(rs)) {
          # the whole decision segment, no post-risk target, then the stop rows
          lean_loop_add_decisions(seq_len(n), i, sq, rep(NA_real_, n), pos,
            lean_marks_decision_fields(marks, ids, pulse_notes$sizing_skipped))
          processed <<- processed + 1L
          lean_marks_stop(s3, i, rs)
          hd_all_explicit[[i]] <<- TRUE
          status <<- "INCOMPLETE"
          stop_reason <<- "risk_mark_unavailable"
          return(list(stop = TRUE))
        }
      }
      live$cur_stage <- "risk"
      if (has_risk) {
        tq <- if (.lean_debug) {
          lean_debug_same(function() lean_risk_targets(sq, targets, pos, positions_snapshot, risk_steps, cash + pv, mk, ids,
            risk_plan, ctx), function() lean_risk_pin(targets, positions_snapshot, risk_plan, ctx), "risk plan", i)
        } else lean_risk_targets(sq, targets, pos, positions_snapshot, risk_steps, cash + pv, mk, ids, risk_plan, ctx)
        if (.lean_debug) ledgr_validate_post_risk_quantities(stats::setNames(tq, ids), n)
      } else if (any(sq < 0 & sq < pos)) ledgr_availability_validate_short_exposure(targets, positions_snapshot)
    }
    fields <- NULL
    risk_ids <- character()
    if (!is.null(marks)) {
      fields <- lean_marks_decision_fields(marks, ids, pulse_notes$sizing_skipped)
      sr <- lean_marks_stale_rows(marks, ids, sq, tq, pos)
      if (!is.null(sr)) {
        lean_marks_add_rows(s3, i, 2L, sr)
        risk_ids <- sr$instrument_id
      }
    }
    # An empty decision axis: the pin's one decision row (R/fold-engine.R:928-935).
    if (n == 0L) lean_marks_add_rows(s3, i, 2L, lean_marks_group("", "decision", "recorded", "empty_public_domain"))
    list(result = result, sq = sq, tq = tq, pos_start = pos_start, fields = fields, risk_ids = risk_ids, stop = FALSE)
  }

  # P3: the order plan, or the affordability reconciliation stop (cut review
  # R1: the whole decision segment is staged, then the stop row; no P4 or
  # P5). Returns the plan's batch and whether the run stops here.
  lean_p3_plan <- function(i, v1, v2) {
    col <- v1$col
    sq <- v2$sq
    tq <- v2$tq
    marks <- v1$m
    if (!is.null(marks)) pos <- pos[ctx_pos]   # the decision axis (P2)
    live$cur_stage <- "execution"
    actionable <- which(abs(tq - pos) > act_tol)
    exec_ts <- if (i <= length(epochs)) epochs[[i]] else NA_real_
    batch <- NULL
    if (length(actionable) > 0L) {
      next_col <- if (i < n_pulse) pulse_cols[[i + 1L]] else col + 1L
      has_next <- next_col <= length(bar_axis)
      # The planner in the context frame with the pin's arguments
      # (R/fold-engine.R:1117-1138): on a marked run the provider's execution
      # view of the actionable instruments and the context's membership.
      view <- if (is.na(exec_ts)) NULL else if (is.null(marks)) lean_exec_view(length(actionable)) else
        lean_plan_execution_view(provider, exec_ts, ids[ctx_pos[actionable]])
      if (.lean_debug && !is.na(exec_ts)) {
        pv_view <- ledgr_carrier_execution_view(provider, exec_ts, ids[ctx_pos[actionable]])
        if (!identical(lapply(unclass(pv_view)[names(view)], unname), lapply(view, unname))) {
          rlang::abort(sprintf("Lean execution view differs from the provider's at pulse %d.", i), class = "ledgr_internal_error")
        }
      }
      batch <- lean_plan_pulse(context_pos = ctx_pos, target_qty = tq, position = pos,
        actionable_k = actionable, member = if (is.null(marks)) member_all else marks$columns$member, exec_ts = exec_ts,
        next_open = if (has_next) bars$open[, next_col] else rep(NA_real_, n),
        execution_view = view, epoch_valid = i > length(epochs) || epoch_valid[[i]],
        cost_resolver = cost_resolver, cash = cash, instrument_ids = ids, cost_steps = cost_steps)
      fill <- batch$fill
      recorded <- cash + sum(fill$cash_delta)
      if (!isTRUE(recorded == batch$expected_final_cash) &&
          !isTRUE(all.equal(as.numeric(recorded), as.numeric(batch$expected_final_cash),
                            tolerance = ledgr_availability_cash_tolerance))) {
        hd_all_explicit[[i]] <<- TRUE
        lean_loop_add_decisions(seq_along(sq), i, sq, tq, pos, v2$fields)
        hd_stop_detail[[i]] <<- canonical_json(list(cash_before = cash,
          virtual_final_cash = batch$expected_final_cash, recorded_final_cash = recorded))
        status <<- "INCOMPLETE"
        stop_reason <<- "affordability_reconciliation_failed"
        processed <<- processed + 1L
        return(list(batch = batch, stop = TRUE))
      }
    }
    list(batch = batch, stop = FALSE)
  }

  # P4: the plan's fills applied to the book and the fill records, its
  # rejections, and the explicit decision rows (every target that differs
  # from the position, clean fills taken out). Returns the fill count.
  lean_p4_apply <- function(i, v1, v2, batch) {
    close <- v1$close
    sq <- v2$sq
    tq <- v2$tq
    # LR-23 on marks (Cut 19, marks.R), on the decision axis (P2): decision
    # cells and fills are keyed by context ordinal.
    d <- v2$fields
    pc <- if (is.null(v1$m)) pos else pos[ctx_pos]
    cleanc <- lean_marks_clean(d, close, v1$m$cids %||% ids, v2$risk_ids)
    differs <- if (isTRUE(v2$skip)) integer() else which(!(is.finite(sq) & sq == pc & tq == sq & cleanc))
    # The next pulse's entitled holder of record, before fills (slice 4,
    # R/fold-engine.R:1401-1409).
    if (!is.null(s4$plan) && i < n_pulse) s4$plan$bind_boundary(i + 1L, ledgr_fold_positions_snapshot(pos, ids))
    n_fill <- if (is.null(batch)) 0L else length(batch$fill$k)
    n_rej <- if (is.null(batch)) 0L else length(batch$rejection$k)
    clean_k <- integer()
    if (n_fill > 0L) {
      fill <- batch$fill
      fr <- ledgr_carrier_segment_text(fill$info_offset, fill$info_count, fill$info_code, .ledgr_plan_reason_levels)
      k <- fill$k
      clean <- if (can_encode) {
        is.finite(sq[k]) & cleanc[k] & is.finite(fill$position_before) &
          pc[k] == fill$position_before & is.finite(fill$planned_position_after) &
          sq[k] == fill$planned_position_after & tq[k] == sq[k] & !nzchar(fr$reason) & !nzchar(fr$reasons)
      } else rep(FALSE, n_fill)
      clean[is.na(clean)] <- FALSE
      clean_k <- k[clean]
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
      fl$evseq[rows] <<- event_seq + seq_len(n_fill) - 1L
      nf <<- nf + n_fill
      event_seq <<- event_seq + n_fill
      if (s4$captures) lean_facts_fills_accepted(s4, event_seq - 1L, fill$exec_ts[[n_fill]])
      pos[fill$pos] <<- book$net_by_inst[fill$pos]
      fl$net_after[rows] <<- book$net_by_inst[fill$pos]
      cash <<- ledgr_cash_scan(cash, fill$cash_delta)[[n_fill]]
      last_executed <<- max(last_executed, fill$exec_ts, na.rm = TRUE)
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
      lean_loop_add_decisions(explicit_k, i, sq, tq, v2$pos_start, d)
    }
    n_fill
  }

  # P5: the capacity refusal, commitment, the reconciliation record and the
  # declared-state update.
  lean_p5_commit <- function(i, v1, v2, batch, n_fill) {
    close <- v1$mk   # gross exposures at the decision marks
    sq <- v2$sq
    tq <- v2$tq
    # Gross and the state update on the decision axis (P2; R/fold-engine.R:1569-1627).
    if (!is.null(v1$m)) { pos <- pos[ctx_pos]; ids <- v1$m$cids; ids_attr <- list(names = ids) }
    live$cur_stage <- "accounting"
    if (nf > capacity) {
      rlang::abort("Ledger event buffer exceeded the run's maximum event capacity.",
                   class = "ledgr_event_buffer_capacity_exceeded")
    }
    if (s4$captures) s4$nfc <- lean_facts_capacity(s4, nf)   # a retaining handler also holds captured rows
    n_committed <<- nf                # the pin flushes the pulse's fills here, before reconciliation
    if (!is.null(batch) && !isTRUE(cash == batch$expected_final_cash) && !isTRUE(all.equal(as.numeric(cash), as.numeric(batch$expected_final_cash),
                                             tolerance = ledgr_availability_cash_tolerance))) {
      rlang::abort("Recorded cash does not reconcile with the availability affordability ledger.",
        class = c("ledgr_affordability_reconciliation_failed", "ledgr_invalid_fold_execution"))
    }
    expected <- if (is.null(batch)) cash else batch$expected_final_cash
    fill_cash <- if (n_fill > 0L) batch$fill$cash_delta else numeric()
    gross_sq <- lean_gross(sq, close)
    recon <- c(
      lean_gross(pos, close),
      cash - sum(fill_cash),
      gross_sq,
      if (has_risk) lean_gross(tq, close) else gross_sq,   # Cut 18 F3: no second gross without a risk step
      cash,
      expected)
    ledgr_fold_reconciliation_check(recon[[2L]], recon[[6L]], recon[[5L]], recon[[3L]], recon[[4L]], recon[[1L]])
    # (as.numeric: on an empty axis the pin's gross is the integer 0, stored
    # in its double staging column.)
    if (.lean_debug && !identical(recon[c(1L, 3L, 4L)], as.numeric(c(ledgr_availability_marked_gross(pos, close),
        ledgr_availability_marked_gross(sq, close), ledgr_availability_marked_gross(tq, close))))) {
      rlang::abort(sprintf("Lean gross exposure differs from the pin's at pulse %d.", i), class = "ledgr_internal_error")
    }
    hd_recon[i, ] <<- recon
    hd_has_recon[[i]] <<- TRUE
    state_update <- v2$result$state_update
    if (inherits(state_update, "ledgr_strategy_state_reset")) {
      strategy_state <<- ledgr_strategy_state_defaults(state_declaration, ids, default_scalars = state_defaults)
    } else if (inherits(state_update, "ledgr_strategy_state_patch")) {
      update <- unclass(state_update)
      strategy_state <<- if (.lean_debug) {
        lean_debug_same(function() lean_state_apply(update, strategy_state, state_fields, state_defaults, state_declaration,
          ids, ids_attr, state_names, state_names_ok), function() ledgr_strategy_state_apply_values(strategy_state, update,
          state_declaration, ids, patch = TRUE, default_scalars = state_defaults), "state patch", i)
      } else {
        lean_state_apply(update, strategy_state, state_fields, state_defaults, state_declaration, ids, ids_attr,
          state_names, state_names_ok)
      }
    } else if (!is.null(state_update)) {
      strategy_state <<- ledgr_strategy_state_apply_values(strategy_state, state_update,
        state_declaration, ids, patch = FALSE, default_scalars = state_defaults)
    }
    invisible(NULL)
  }

  # E: counts the pulse; FALSE once max_pulses is reached.
  lean_e_advance <- function() {
    processed <<- processed + 1L
    if (processed >= max_pulses) {
      full_run <<- FALSE
      return(FALSE)
    }
    TRUE
  }

  # E: the pulse loop inside the run transaction, then the terminal transfer.
  run_loop <- function() {
    live$t_start <- ledgr_time_now()
    live$in_pulses <- TRUE
    on.exit(live$in_pulses <- FALSE)   # also when an error unwinds the loop, before rollback
    # The first pulse's entitled holder of record (R/fold-engine.R:1921-1926).
    if (!is.null(s4$plan) && n_pulse > 0L) s4$plan$bind_boundary(1L, ledgr_fold_positions_snapshot(pos, ids))
    for (i in seq_len(n_pulse)) {
      v1 <- lean_p1_value(i)
      if (v1$stop) break
      v2 <- lean_p2_decide(i, v1)
      if (v2$stop) break
      v3 <- lean_p3_plan(i, v1, v2)
      if (v3$stop) break
      n_fill <- lean_p4_apply(i, v1, v2, v3$batch)
      lean_p5_commit(i, v1, v2, v3$batch, n_fill)
      if (!lean_e_advance()) break
    }
    live$in_pulses <- FALSE
    live$t_pulses <- ledgr_time_elapsed(live$t_start, ledgr_time_now())
    t_pub <- ledgr_time_now()
    hooks$publish(lean_loop_publish)
    live$t_publish <- ledgr_time_elapsed(t_pub, ledgr_time_now())
    invisible(NULL)
  }

  lean_loop_add_sizing <- function(e, intent, i, m) {
    rows <- nsz + seq_len(m)
    if (nsz + m > scap) {
      while (nsz + m > scap) scap <<- scap * 2L
      szr <<- grow(szr, scap)
    }
    szr$pulse[rows] <<- i
    szr$id[rows] <<- e$instrument_id
    szr$reason[rows] <<- e$reason_code
    szr$reasons[rows] <<- if (is.null(intent)) "" else intent
    szr$target[rows] <<- e$pre_floor_quantity
    szr$quantity[rows] <<- e$rounded_quantity
    szr$price[rows] <<- e$price
    szr$requested[rows] <<- e$requested_quantity
    szr$before[rows] <<- e$position_before
    nsz <<- nsz + m
  }

  # Explicit decision rows; `fields` (marks.R) carries a marked pulse's
  # per-cell mark, source, age and reasons, NULL the current close's.
  lean_loop_add_decisions <- function(k, i, sq, tq, position, fields = NULL) {
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
    # Mark fields only on a marked run; on complete planes they are the
    # current close's, filled at publish (lean_loop_expand).
    if (!is.null(s3$state)) {
      dr$mark[rows] <<- if (is.null(fields)) bars$close[k, pulse_cols[[i]]] else fields$mark[k]
      for (f in c("source", "age", "reason", "reasons")) {
        dr[[f]][rows] <<- if (is.null(fields)) rep_len(lean_marks_current[[f]], m) else fields[[f]][k]
      }
    }
    nd <<- nd + m
  }

  # --- after the loop (Section 19.5; D3 Sections 1-3) ---------------------
  # The committed records go to the pin's handler and writer in bounded
  # terminal batches: pulse ranges whose rows fit the batch bound are
  # expanded one range at a time, and each range's writes are split into
  # batches of at most that many rows (a single pulse wider than the bound
  # is expanded alone and written in several batches). Durable events drain
  # after every batch, so each batch is one real store append.
  lean_loop_publish <- function() {
    if (n_pulse == 0L) {
      # As the pin: drain the empty writer, no completion evidence.
      writer <- ledgr_fold_diagnostic_writer(run_id, output_handler)
      output_handler$write_run_diagnostics(writer$drain())
      writer$release()
      return(invisible(NULL))
    }
    lay <- lean_loop_layout()
    bound <- as.integer(hooks$batch_rows())
    writer <- ledgr_fold_diagnostic_writer(run_id, output_handler, chunk_rows = bound)
    pieces <- function(m) if (m > 0L) lapply(seq.int(1L, m, by = bound), function(s) seq.int(s, min(m, s + bound - 1L))) else list()
    tick <- function() {
      live$batches <- live$batches + 1L
    }
    ca <- lean_facts_rows(s4)   # accepted corporate-action rows (slice 4)
    cur <- 1L
    carry <- state0$positions
    cs <- cumsum(lay$rows)
    a <- 1L
    while (a <= lay$np) {
      b <- max(a, findInterval(cs[[a]] - lay$rows[[a]] + bound, cs))
      ex <- lean_loop_expand(a, b, lay, carry)
      carry <- ex$carry
      cur <- lean_facts_emit(output_handler, fl, ids, ex$fill_rows, ca, cur, bound, tick)
      for (r in pieces(length(ex$explicit$diagnostic_seq))) {
        tick()
        writer$append_block(lapply(ex$explicit, `[`, r))
      }
      imp <- ex$implicit
      for (r in pieces(if (is.null(imp)) 0L else imp$n)) {
        tick()
        writer$append_implicit(c(list(n = length(r)), lapply(imp[names(imp) != "n"], `[`, r)))
      }
      a <- b + 1L
    }
    if (nf == 0L) output_handler$flush_pulse_events()
    lean_facts_emit_ca(output_handler, ca, cur, .Machine$integer.max, bound, tick)   # rows after the last fill
    writer$record_coverage(as.integer(sum(lay$logical_per)))
    if (output_handler$pending_event_count() > 0L) output_handler$flush_pending()
    diagnostics <- writer$drain()
    if (full_run) {
      completion <- ledgr_availability_completion_row(run_id = run_id, pulses_posix = pulses_posix,
        status = status, stop_reason = stop_reason,
        affected = s3$affected,
        last_fully_valued_ts_utc = .POSIXct(last_fully_valued, tz = "UTC"), last_executed_ts_utc = .POSIXct(last_executed, tz = "UTC"))
      output_handler$write_run_evidence(completion, diagnostics)
    } else {
      output_handler$write_run_diagnostics(diagnostics)
    }
    writer$release()
  }

  # Per pulse: logical rows and sequence offsets, and the rows a pulse can
  # expand to (an upper bound: every decision cell may be a hold).
  lean_loop_layout <- function() {
    np <- n_done
    p <- seq_len(np)
    nrec <- as.integer(hd_has_recon[p])
    # Slice 3 (Section 19.11): a pulse's logical rows are its opening rows
    # (valuation, skip and evidence), intent and sizing, its decision cells,
    # risk rows, rejections, fills, reconciliation and stop rows.
    pc <- lean_marks_part_counts(s3, np)
    nopen <- pc$open
    nrisk <- pc$risk
    nstop <- as.integer(!is.na(hd_stop_detail[p])) + pc$stop
    nctx <- if (is.null(s4$cxi)) rep.int(n, np) else s4$cxi[2L, p]   # decision cells: the context's (slice 4)
    ndec <- nctx * !pc$no_decision                # none on a scheduled skip or a valuation stop
    logical_per <- nopen + hd_pre[p] + ndec + nrisk + hd_nrej[p] + hd_nfill[p] + nrec + nstop
    base <- c(0L, cumsum(logical_per))[p]
    pre0 <- base + nopen
    dec0 <- pre0 + hd_pre[p]                       # seq of decision k is dec0 + k
    rej0 <- dec0 + ndec + nrisk
    fill0 <- rej0 + hd_nrej[p]
    nd_p <- tabulate(dr$pulse[seq_len(nd)], np)
    xf_p <- tabulate(fl$pulse[seq_len(nf)][!fl$clean[seq_len(nf)]], np)
    rows <- nopen + hd_pre[p] + nd_p + nrisk + hd_nrej[p] + xf_p + nrec + nstop + hd_nfill[p] +
      if (can_encode) nctx * !hd_all_explicit[p] else 0L
    list(np = np, logical_per = logical_per, base = base, pre0 = pre0, dec0 = dec0, risk0 = dec0 + ndec,
         rej0 = rej0, fill0 = fill0, stop0 = fill0 + hd_nfill[p] + nrec, rows = rows, nctx = nctx)
  }

  # Rows of a pulse-ordered record whose pulse lies in [a, b].
  lean_rows_in <- function(pulse, a, b) {
    lo <- findInterval(a - 1L, pulse) + 1L
    hi <- findInterval(b, pulse)
    if (hi >= lo) seq.int(lo, hi) else integer()
  }

  # Expands pulses a..b of the committed records into the writer's explicit
  # block (diagnostic sequence order) and implicit block (pulse-major, fills
  # then holds). `carry` holds each instrument's position entering pulse a;
  # the returned carry enters pulse b + 1.
  lean_loop_expand <- function(a, b, lay, carry) {
    live$ranges <- live$ranges + 1L
    live$max_range_pulses <- max(live$max_range_pulses, b - a + 1L)
    p <- seq.int(a, b)
    parts <- list()
    add <- function(seq, pulse, fields) parts[[length(parts) + 1L]] <<- c(list(seq = seq, pulse = pulse), fields)
    it <- p[!is.na(hd_intent[p])]
    if (length(it)) add(lay$pre0[it] + 1L, it, list(stage = "decision", outcome = "recorded",
      reason_code = "strategy_intent", reasons = hd_intent[it]))
    sz <- p[hd_sizing[p]]
    if (length(sz)) add(lay$pre0[sz] + as.integer(!is.na(hd_intent[sz])) + 1L, sz, list(stage = "sizing",
      outcome = "unavailable", reason_code = "sizing_intent_unavailable", reasons = "raw_quantity_targets"))
    sr <- lean_rows_in(szr$pulse[seq_len(nsz)], a, b)
    if (length(sr)) {
      sp <- szr$pulse[sr]
      within <- seq_along(sr) - match(sp, sp) + 1L
      add(lay$pre0[sp] + as.integer(!is.na(hd_intent[sp])) + within, sp, list(instrument_id = szr$id[sr],
        stage = "sizing", outcome = "recorded", reason_code = szr$reason[sr], reasons = szr$reasons[sr],
        target = szr$target[sr], quantity = szr$quantity[sr], price = szr$price[sr],
        target_before_risk = szr$requested[sr], position_before = szr$before[sr]))
    }
    r <- lean_rows_in(dr$pulse[seq_len(nd)], a, b)
    if (length(r)) {
      dp <- dr$pulse[r]; dk <- dr$k[r]
      mf <- if (is.null(s3$state)) c(list(mark = bars$close[cbind(dk, pulse_cols[dp])]), lean_marks_current) else
        list(mark = dr$mark[r], source = dr$source[r], age = dr$age[r], reason = dr$reason[r], reasons = dr$reasons[r])
      add(lay$dec0[dp] + dk, dp, list(instrument_id = ids[lean_facts_rpos(s4, dk, dp)], stage = "decision", outcome = "recorded",
        reason_code = mf$reason, reasons = mf$reasons, target = dr$target[r],
        quantity = dr$position[r], price = mf$mark, mark_source = mf$source,
        mark_age = mf$age, target_before_risk = dr$target[r], target_after_risk = dr$target_after[r],
        position_before = dr$position[r], position_after = dr$position[r]))
    }
    xr <- s3$xr
    xx <- lean_rows_in(xr$pulse[seq_len(s3$nx)], a, b)
    if (length(xx)) add(lean_marks_part_seq(xr$pulse[xx], xr$part[xx], lay), xr$pulse[xx], lapply(xr[-(1:2)], `[`, xx))
    rr <- lean_rows_in(rj$pulse, a, b)
    if (length(rr)) {
      rp <- rj$pulse[rr]
      within <- stats::ave(rp, rp, FUN = seq_along)
      add(lay$rej0[rp] + within, rp, list(instrument_id = ids[rj$pos[rr]], stage = "execution", outcome = "no_fill",
        reason_code = rj$primary[rr], reasons = rj$reasons[rr], target = rj$target[rr], quantity = rj$position[rr],
        price = rj$resolved_price[rr], execution_ts_utc = rj$exec_ts[rr], target_before_risk = rj$strategy_target[rr],
        target_after_risk = rj$target[rr], position_before = rj$position[rr], position_after = rj$position[rr]))
    }
    fr <- lean_rows_in(fl$pulse[seq_len(nf)], a, b)
    xf <- fr[!fl$clean[fr]]
    if (length(xf)) {
      fp <- fl$pulse[xf]
      add(lay$fill0[fp] + xf - hd_fill_start[fp], fp, list(instrument_id = ids[fl$pos[xf]],
        stage = "execution", outcome = "filled", reason_code = fl$info[xf], reasons = fl$infos[xf],
        target = fl$target[xf], quantity = fl$qty[xf], price = fl$price[xf], execution_ts_utc = fl$exec_ts[xf],
        event_seq = fl$evseq[xf], target_before_risk = fl$strategy_target[xf],
        target_after_risk = fl$target[xf], position_before = fl$position_before[xf],
        position_after = fl$planned_position_after[xf]))
    }
    rc <- p[hd_has_recon[p]]
    if (length(rc)) {
      detail <- vapply(rc, function(j) ledgr_fold_reconciliation_detail(
        cash_before = hd_recon[j, 2L], virtual_final_cash = hd_recon[j, 6L], recorded_final_cash = hd_recon[j, 5L],
        intended_gross_exposure = hd_recon[j, 3L], post_risk_gross_exposure = hd_recon[j, 4L],
        actual_gross_exposure = hd_recon[j, 1L]), character(1L))
      add(lay$fill0[rc] + hd_nfill[rc] + 1L, rc, list(stage = "reconciliation", outcome = "reconciled",
        reason_code = "affordability_reconciled", reasons = "affordability_reconciled", detail_json = detail))
    }
    st <- p[!is.na(hd_stop_detail[p])]
    if (length(st)) add(lay$fill0[st] + hd_nfill[st] + 1L, st, list(stage = "affordability", outcome = "stopped",
      reason_code = "affordability_reconciliation_failed", reasons = "affordability_reconciliation_failed",
      detail_json = hd_stop_detail[st]))
    explicit <- lean_loop_explicit_block(parts)
    # The sink's keep rule, as the pin applies it at every pulse flush. A
    # memory sink (no codec) never keeps a current-close decision row or a
    # fill row in slice 1, so holds and clean fills are not built for it.
    if (!is.null(keep_fn)) explicit <- lean_loop_keep(explicit)

    # holds: every decision cell of a..b that is neither explicit nor a clean
    # fill; a cell is (context ordinal, pulse), its run position lean_facts_rpos()
    # The position changes of a..b: P1 settlements and fills (decision 4(c)).
    ev <- lean_facts_moves(s4, fl, fr, a, b)
    implicit <- NULL
    if (can_encode) {
      hold <- outer(seq_len(n), lay$nctx[p], "<=")
      hold[, hd_all_explicit[p]] <- FALSE
      if (length(r)) hold[cbind(dr$k[r], dr$pulse[r] - a + 1L)] <- FALSE
      cf <- fr[fl$clean[fr]]
      if (length(cf)) hold[cbind(fl$k[cf], fl$pulse[cf] - a + 1L)] <- FALSE
      if (length(rr)) hold[cbind(rj$k[rr], rj$pulse[rr] - a + 1L)] <- FALSE
      hc <- which(hold)
      hooks$hold_expansion(isTRUE(live$in_pulses), length(hc))
      hk <- (hc - 1L) %% n + 1L
      hp <- (hc - 1L) %/% n + a
      rk <- lean_facts_rpos(s4, hk, hp)
      hpos <- lean_facts_positions_at(ev, rk, hp, a, b, carry)
      fk <- fl$k[cf]; fpl <- fl$pulse[cf]
      ord <- order(c(fpl, hp), c(rep(0L, length(cf)), rep(1L, length(hc))), method = "radix")
      kk <- c(fk, hk)[ord]
      rq <- c(fl$pos[cf], rk)[ord]
      pp <- c(fpl, hp)[ord]
      m <- length(ord)
      implicit <- list(
        n = m,
        run_id = rep_len(as.character(run_id), m),
        decision_seq = as.integer(lay$dec0[pp] + kk),
        execution_seq = as.integer(c(lay$fill0[fpl] + cf - hd_fill_start[fpl], rep(NA_integer_, length(hc)))[ord]),
        decision_order = as.numeric((kk - 1) * n + rq),   # (ordinal - 1) x axis size + run position (R/fold-engine.R:1330)
        ts_utc = ts_num[pp],
        instrument_id = ids[rq],
        target = c(fl$target[cf], hpos)[ord],
        position_before = c(fl$position_before[cf], hpos)[ord],
        decision_price = bars$close[cbind(rq, pulse_cols[pp])],
        decision_mark_source = rep_len("current_close", m),
        decision_mark_age = rep_len(0L, m),
        fill_quantity = c(fl$qty[cf], rep(NA_real_, length(hc)))[ord],
        fill_price = c(fl$price[cf], rep(NA_real_, length(hc)))[ord],
        execution_ts_utc = c(fl$exec_ts[cf], rep(NA_real_, length(hc)))[ord],
        event_seq = c(fl$evseq[cf], rep(NA_integer_, length(hc)))[ord],
        position_after = c(fl$planned_position_after[cf], hpos)[ord]
      )
    }
    # Positions entering b + 1: the book net after each instrument's last change in a..b.
    carry[ev$k] <- ev$v
    list(explicit = explicit, implicit = implicit, fill_rows = fr, carry = carry)
  }

  lean_loop_keep <- function(block) {
    if (length(block$diagnostic_seq) == 0L) return(block)
    k <- keep_fn(block, length(block$diagnostic_seq))
    lapply(block, function(v) v[k])
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
  hooks$fold_end(list(pulses = live$t_pulses, publish = live$t_publish,
    capacity = c(fills_used = nf, fills_allocated = fcap, decisions_used = nd, decisions_allocated = dcap,
      sizing_used = nsz, sizing_allocated = scap, slice3_rows_used = s3$nx, slice3_rows_allocated = s3$xcap,
      capture_blocks_used = s4$nb, capture_blocks_allocated = s4$cap, context_used = s4$ncx %||% 0L, context_allocated = length(s4$cx),
      moves_used = s4$nmv, moves_allocated = length(s4$mv$pulse),
      rejections = length(rj$k), pulse_headers = n_pulse, batches = live$batches, ranges = live$ranges,
      max_range_pulses = live$max_range_pulses)))
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

# --- the hashed frame (Cut 20; interface Section 19.12) ---------------------
#
# Why. R searches an ordinary function frame name by name. The envelope's
# frame holds about 140 names, and every lookup that passes them (base and
# package functions, the lean helpers, state the stage closures read) costs
# about 1 us per name per pulse. A hashed environment finds a name directly.
# Evaluating the envelope's compiled body in one saved 40-47 us per pulse on
# the comparison shapes with identical results (dev/spikes/hashed_frame).
#
# Form. lean_fold_envelope keeps the seat's name, so lean_loop_install(), the
# installed check and the pin seat are unchanged. With debug off it evaluates
# lean_envelope_code, the plain function's body compiled once below, in a
# hashed child of its own call frame (so `execution` and `output_handler`
# resolve as arguments). With debug on it calls lean_fold_envelope_plain
# itself: every debug-on parity run checks the plain form, every debug-off run
# the hashed one, and parity/hashed_frame_witness.R runs the hashed body with
# the debug assertions on.
#
# Inside the evaluated body, on.exit() is registered on the eval context and
# runs when that context exits, normally or during unwinding; return() exits
# that eval context, and the wrapper returns its value. Do not use missing(),
# sys.call(), sys.function(), match.call(), nargs() or parent.frame() directly
# at the body's top level. Ordinary calls and lexical <<- updates from nested
# stage closures retain their intended state semantics. A nested function
# still has its own function frame, but code inspecting its caller, including
# a helper called from the body's top level, can observe the hashed
# environment and eval frames. Top-level stop() and rlang::abort() can
# consequently record a different condition call; rlang backtraces and caller
# environments are not identical. Audit any value that retains a call or
# environment before treating it as a compared or persisted result. The
# witness's static scan of the six calls does not prove those indirect cases.
#
# Debugging. Load with debug on (lean_core_load(lib, debug = TRUE)), then
# debug() or debugonce() on lean_fold_envelope_plain. With debug off,
# traceback() shows two eval() lines between lean_fold_envelope and the
# stage, and recover() can still open the hashed frame and read its state.
#
# Compiling. sys.source() (lean_core_load, the timing protocols) sets the
# topLevelEnvironment option to the lean environment, and the compiler then
# refuses the namespace above it; the option is cleared for the compile.
# A text edit to the plain function (a parity variant) is compiled with it.
#
# Switch obligation: when the loop moves into R/, the body is compiled when
# the package is installed, this workaround goes, and the package's debug
# mechanism keeps the plain function as the path that can be stepped through.
# Pattern and caveats: inst/design/manual/optimization_coding_style.qmd, "The
# hashed-frame pattern".
lean_envelope_code <- local({
  op <- options(topLevelEnvironment = NULL)
  on.exit(options(op))
  compiler::compile(body(lean_fold_envelope_plain), env = environment(lean_fold_envelope_plain))
})

lean_fold_envelope <- function(execution, output_handler) {
  if (.lean_debug) return(lean_fold_envelope_plain(execution, output_handler))
  eval(lean_envelope_code, new.env(hash = TRUE, parent = environment()))
}
