root <- normalizePath(".", winslash = "/")
dir <- file.path(root, "dev", "bench", "v0_2_3_ws5")
read <- function(name) utils::read.csv(file.path(dir, name), stringsAsFactors = FALSE, check.names = FALSE)
surface <- read("surface_inventory.csv")
owners <- read("ownership_matrix.csv")
state <- read("maintained_state_census.csv")
differences <- read("expected_differences.csv")
base <- read("base_semantic_record.csv")

expected_surface <- c(
  "context:vec", "context:feature", "context:features", "context:open(id)",
  "context:high(id)", "context:low(id)", "context:close(id)",
  "context:volume(id)", "context:position(id)", "context:idx(id)",
  "context:tradable()", "context:bars", "context:feature_table",
  "context:features_wide", "context:bar(id)",
  "column:open/high/low/close/volume",
  "column:position/held/member/buyable/holding_value",
  "column:declared_feature_alias_or_id",
  "column:entry_price/entry_at/exit_at/bars_since_entry/bars_since_exit"
)
surface_key <- paste(surface$kind, surface$name, sep = ":")
stopifnot(identical(surface_key, expected_surface))
stopifnot(!anyDuplicated(surface_key), all(nzchar(surface$owner)), all(nzchar(surface$detector)))

expected_families <- c(
  "D1_values_names_axis", "D1_lazy_once", "D1_frozen_view",
  "D1_alias_resolution", "D1_retired_surface", "D1_unpriced_holding",
  "D2_event_order", "D2_nonfill", "D2_prefix_rebuild", "D2_resume_carry",
  "D2_shared_axis", "D2_pulse_unknown", "D3_target_verbs",
  "D4_selection_weights", "D5_state_declaration", "D5_state_checkpoint",
  "D6_D7_schedule_inputs", "D8_rounding_evidence", "D9_pattern_teaching",
  "S4_item_5_reader_cut", "S4_item_6_timing", "consumer_strategy_authoring",
  "consumer_strategy_development", "consumer_peer_dense",
  "consumer_long_window_run", "consumer_long_window_sweepwf"
)
stopifnot(identical(owners$family, expected_families), !anyDuplicated(owners$family))
stopifnot(all(grepl("^LDG-31(79|8[0-9]|90)$", owners$owner)))
stopifnot(all(nzchar(owners$mutation)), all(startsWith(owners$mutation_command, "Rscript")))
implemented_mutations <- grepl("^D[1-4]_", owners$family) |
  owners$family == "D6_D7_schedule_inputs"
stopifnot(all(grepl("v0_2_3_ws5/mutations[.]R", owners$mutation_command[implemented_mutations])))
stopifnot(all(vapply(
  owners$family[implemented_mutations],
  function(family) grepl(family, owners$mutation_command[owners$family == family], fixed = TRUE),
  logical(1)
)))

expected_consumers <- c(
  "vignettes/strategy-authoring-tools.qmd", "vignettes/strategy-development.qmd",
  "dev/bench/peer_benchmark/dense/recipes.R", "dev/bench/long_window/lw_run.R",
  "dev/bench/long_window/lw_sweepwf.R"
)
stopifnot(identical(state$consumer, expected_consumers))
stopifnot(all(grepl("scalar|descriptive", state$state_shape)), all(nzchar(state$disposition)))

stopifnot(identical(differences$item, c(
  "public_context_surface", "position_facts", "uncarried_window_config_hash",
  "carried_window_config_hash",
  "current_only_store_read", "pulse_supplied_position_basis", "plain_run_config_hash"
)))
stopifnot(identical(base$record, c(
  "typed_round_trip_whole_double", "typed_round_trip_integer",
  "typed_round_trip_empty_atomic", "unchanged_tail_resume",
  "five_pulse_context_builds", "five_pulse_state_encodes", "five_pulse_state_writes"
)))

timing <- utils::read.csv(file.path(root, "dev", "bench", "timing", "protocols", "ws5-timing-1", "matrix.csv"), stringsAsFactors = FALSE)
thresholds <- utils::read.csv(file.path(root, "dev", "bench", "timing", "protocols", "ws5-timing-1", "thresholds.csv"), stringsAsFactors = FALSE)
expected_cells <- c(
  "fixed_nofill_run", "declared_nofill_run", "fixed_sparse_run",
  "declared_sparse_run", "fixed_wide_run", "declared_wide_run",
  "fixed_wide_state_change", "fixed_wide_state_unchanged", "experiment_construction"
)
stopifnot(identical(timing$cell, expected_cells), identical(thresholds$cell, expected_cells))
stopifnot(all(timing$pairs == 8L), all(thresholds$bound == 1.10))
protocol <- paste(readLines(file.path(root, "dev", "bench", "timing", "protocols", "ws5-timing-1", "protocol.md"), warn = FALSE), collapse = "\n")
workloads <- paste(readLines(file.path(root, "dev", "bench", "timing", "protocols", "ws5-timing-1", "workloads.R"), warn = FALSE), collapse = "\n")
stopifnot(grepl("14252ffb", protocol, fixed = TRUE), grepl("b5622f09", protocol, fixed = TRUE))
stopifnot(grepl("ws5_declared_strategy", workloads, fixed = TRUE), grepl("portfolio_state", workloads, fixed = TRUE))

source_text <- paste(unlist(lapply(list.files(file.path(root, "R"), "[.]R$", full.names = TRUE), readLines, warn = FALSE)), collapse = "\n")
stopifnot(!grepl("ledgr_scalar_accessor_loop", source_text, fixed = TRUE))
position_source <- paste(readLines(file.path(root, "R", "position-facts.R"), warn = FALSE), collapse = "\n")
fold_source <- paste(readLines(file.path(root, "R", "fold-engine.R"), warn = FALSE), collapse = "\n")
find_interval_matches <- gregexpr("findInterval", position_source, fixed = TRUE)[[1L]]
stopifnot(sum(find_interval_matches > 0L) == 1L)
stopifnot(grepl("ledgr_position_fact_replay_axis_map", position_source, fixed = TRUE))
stopifnot(!grepl("position_facts_view", fold_source, fixed = TRUE))
stopifnot(!grepl("for (", position_source, fixed = TRUE))

consumer_text <- paste(unlist(lapply(file.path(root, expected_consumers[3:5]), readLines, warn = FALSE)), collapse = "\n")
stopifnot(!grepl("ctx$vec", consumer_text, fixed = TRUE))
claims <- paste(readLines(file.path(root, "tests", "claims.yml"), warn = FALSE), collapse = "\n")
stopifnot(grepl("LCL-0066", claims, fixed = TRUE), grepl("LCL-0103", claims, fixed = TRUE))
stopifnot(!grepl("LCL-0071", claims, fixed = TRUE), !grepl("LCL-0102", claims, fixed = TRUE))
cat("WS5_INVENTORY_OK\n")
