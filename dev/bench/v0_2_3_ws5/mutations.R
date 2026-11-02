# Source mutations for the accepted WS15 D1/D2 families. Run through the
# existing isolated-copy mutation driver; each edit must make the named
# registered test fail.
mutations <- list(
  D1_values_names_axis = list(
    file = "R/pulse-context.R",
    old = "ledgr_pulse_context_named <- function(value, universe) {\n  stats::setNames(value, universe)\n}",
    new = "ledgr_pulse_context_named <- function(value, universe) {\n  unname(value)\n}",
    filter = "flat-lazy-context",
    blocks = "flat context columns are named, lazy, strict and frozen"
  ),
  D1_lazy_once = list(
    file = "R/pulse-context.R",
    old = "if (exists(name, envir = lookup$cache, inherits = FALSE)) {",
    new = "if (FALSE && exists(name, envir = lookup$cache, inherits = FALSE)) {",
    filter = "flat-lazy-context",
    blocks = "flat context columns are named, lazy, strict and frozen"
  ),
  D1_frozen_view = list(
    edits = list(
      list(
        file = "R/pulse-context.R",
        old = "  universe <- as.character(universe)\n  lookup$bars <-",
        new = "  universe <- as.character(universe)\n  assign(\".ledgr_ws5_mutant_bars\", bars, envir = .GlobalEnv)\n  lookup$bars <-"
      ),
      list(
        file = "R/pulse-context.R",
        old = "value <- ledgr_pulse_context_named(ledgr_pulse_context_vector_field(lookup, name), ids)",
        new = "value <- ledgr_pulse_context_named(as.numeric(get(\".ledgr_ws5_mutant_bars\", envir = .GlobalEnv)[[name]]), ids)"
      )
    ),
    filter = "flat-lazy-context",
    blocks = "saved fold views freeze lazy buffers and sweep candidates isolate them"
  ),
  D1_alias_resolution = list(
    file = "R/feature-map.R",
    old = "reserved_ids <- intersect(concrete_ids, ledgr_pulse_context_reserved_fields())",
    new = "reserved_ids <- character()",
    filter = "feature-map-read-surface|flat-lazy-context",
    blocks = "mapped concrete feature IDs cannot shadow flat context fields"
  ),
  D1_retired_surface = list(
    file = "R/pulse-context.R",
    old = "  raw <- unclass(x)\n  if (name %in% ledgr_pulse_context_retired_fields() &&",
    new = "  raw <- unclass(x)\n  if (identical(name, \"vec\")) return(function(...) numeric())\n  if (name %in% ledgr_pulse_context_retired_fields() &&",
    filter = "scalar-accessor-warning",
    blocks = "retired scalar-loop warnings and readers stay absent"
  ),
  D1_unpriced_holding = list(
    file = "R/pulse-context.R",
    old = "value[held & !is.finite(mark)] <- NA_real_",
    new = "value[held & !is.finite(mark)] <- 0",
    filter = "flat-lazy-context",
    blocks = "held positions without a permissible mark keep unknown holding value"
  ),
  D2_event_order = list(
    file = "R/position-facts.R",
    old = "exit_action <- which(fill & closed)",
    new = "exit_action <- integer()",
    filter = "position-facts-context",
    blocks = "canonical replay preserves real same-bar order and non-fill semantics"
  ),
  D2_nonfill = list(
    file = "R/position-facts.R",
    old = "  fill <- prepared$operation == .ledgr_lot_fill\n  if (is.null(axis_map)) {",
    new = "  fill <- prepared$operation != .ledgr_lot_opening\n  if (is.null(axis_map)) {",
    filter = "position-facts-context",
    blocks = "canonical replay preserves real same-bar order and non-fill semantics"
  ),
  D2_prefix_rebuild = list(
    file = "R/position-facts.R",
    old = "transition <- prepared$operation != .ledgr_lot_opening",
    new = "transition <- prepared$operation == .ledgr_lot_fill",
    filter = "position-facts-context",
    blocks = "canonical replay preserves real same-bar order and non-fill semantics"
  ),
  D2_resume_carry = list(
    file = "R/walk-forward.R",
    old = "initial_state = initial_facts",
    new = "initial_state = NULL",
    filter = "position-facts-context",
    blocks = "three contiguous walk-forward windows retain entry and exit facts"
  ),
  D2_shared_axis = list(
    file = "R/position-facts.R",
    old = "valid <- times >= bars[[1L]] & index >= 1L & index <= length(bars) &",
    new = "valid <- index >= 1L & index <= length(bars) &",
    filter = "position-facts-context",
    blocks = "position fact transitions refuse off-axis timestamps"
  ),
  D2_pulse_unknown = list(
    file = "R/pulse-snapshot.R",
    old = "inspection$position_fact_unknown_basis <- names(positions)[positions != 0]",
    new = "inspection$position_fact_unknown_basis <- character()",
    filter = "position-facts-context",
    blocks = "pulse inspection reports unknown basis and anchors for supplied positions"
  ),
  D3_target_verbs = list(
    file = "R/strategy-helpers.R",
    old = "requested_value <- weights[positive_ids[valid]] * invest_fraction * base",
    new = "requested_value <- weights[positive_ids[valid]] / sum(weights[positive_ids[valid]]) * invest_fraction * base",
    filter = "strategy-authoring-ws16",
    blocks = "ctx-first target verbs share sizing and make book policy explicit"
  ),
  D4_selection_weights = list(
    file = "R/strategy-helpers.R",
    old = "max(1L, floor(length(pool) * fraction))",
    new = "max(1L, ceiling(length(pool) * fraction))",
    filter = "strategy-authoring-ws16",
    blocks = "plain selection and weights bind rank, pool and empty rules"
  ),
  D5_state_declaration = list(
    file = "R/strategy-state.R",
    old = "name = field$name, type = field$type,",
    new = "name = field$name, type = \"numeric\",",
    filter = "strategy-state-ws17",
    blocks = "declared state preserves type, missingness and axis"
  ),
  D5_state_checkpoint = list(
    file = "R/fold-engine.R",
    old = "if (changed && isTRUE(output_handler$persists_strategy_state)) {",
    new = "if (isTRUE(output_handler$persists_strategy_state)) {",
    filter = "strategy-state-ws17",
    blocks = "unchanged cursors resume without replay or encoding"
  ),
  D6_D7_schedule_inputs = list(
    file = "R/strategy-schedule.R",
    old = "if (identical(history_substrate$clock_kind, \"declared_sessions\")) {\n    history_substrate$sessions\n  } else {\n    NULL\n  }",
    new = "history_substrate$sessions",
    filter = "strategy-authoring-ws16",
    blocks = "construction requires investor inputs and schedule queries are pure"
  )
)
