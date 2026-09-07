args <- commandArgs(trailingOnly = TRUE)
write_evidence <- !"--no-write" %in% args
require_freeze_anchor <- "--require-freeze-anchor" %in% args

.libPaths(c(normalizePath("lib", winslash = "/", mustWork = FALSE), .libPaths()))
pkgload::load_all(".", quiet = TRUE)

root <- normalizePath(
  file.path("dev", "spikes", "asset_availability_pit"),
  winslash = "/",
  mustWork = TRUE
)
stage3_dir <- file.path(root, "stage3")
for (file in c(
  "common.R", "reference_provider.R", "shared_fold.R",
  "package_dense_control.R", "w21_evidence.R",
  "reference_witnesses.R", "conformance.R", "mutations.R"
)) {
  source(file.path(stage3_dir, file), local = .GlobalEnv)
}

stage3_verify_frozen_inputs(require_commit_anchor = require_freeze_anchor)

provider <- stage3_reference_provider()
fixture <- stage3_provider_w21(provider)
package_trace <- stage3_run_w21_package(fixture)
fork_trace <- stage3_run_w21_fork(fixture, package_trace$source_identity)
stage3_compare_w21_traces(fork_trace, package_trace)
w02_package_controls <- stage3_run_w02_package_controls(provider)
fractional_targets <- c(A01 = 1000)
fractional_context <- list(equity = 100000, vec = list(close = c(A01 = 82.44)))
fractional_package <- getFromNamespace("ledgr_apply_risk_plan", "ledgr")(
  fractional_targets,
  getFromNamespace("ledgr_risk_plan_compile", "ledgr")(
    ledgr::ledgr_risk_max_weight(0.5),
    params = list()
  ),
  fractional_context
)
fractional_fork <- stage3_apply_max_weight(
  fractional_targets,
  fractional_context$equity,
  fractional_context$vec$close,
  0.5
)
stage3_assert(
  isTRUE(all.equal(fractional_fork, fractional_package, tolerance = 1e-12)),
  "The Stage 3 max-weight fork rounded a fractional package target."
)

observed <- list(
  W02 = stage3_materialize_observed(
    "W02",
    stage3_reference_w02(provider, w02_package_controls),
    source = "mixed_package_control_and_checker_baseline"
  ),
  W09 = stage3_materialize_observed("W09", stage3_reference_w09(provider)),
  W21 = stage3_materialize_observed("W21", stage3_w21_evidence(fork_trace)),
  W22 = stage3_materialize_observed("W22", stage3_reference_w22(provider)),
  W24 = stage3_materialize_observed("W24", stage3_reference_w24(provider)),
  W25 = stage3_materialize_observed("W25", stage3_reference_w25(provider))
)
package_w21 <- stage3_materialize_observed(
  "W21",
  stage3_w21_evidence(package_trace),
  source = "package_fold"
)

baseline_rows <- lapply(names(observed), function(witness) {
  sources <- if (witness == "W21") list(package_fold = package_w21) else list()
  result <- stage3_check_conformance(witness, observed[[witness]], sources)
  stage3_assert(result$pass, paste(witness, paste(result$findings, collapse = "; ")))
  data.frame(
    witness_id = witness,
    evidence_role = if (witness == "W21") {
      "dense_representation_control"
    } else {
      "checker_baseline"
    },
    source = if (witness == "W21") {
      paste0(provider$provider_name, "+package_fold")
    } else if (witness == "W02") {
      "package_controls+hand_calculated_reference"
    } else {
      "hand_calculated_reference"
    },
    pass = result$pass,
    findings = paste(result$findings, collapse = ";"),
    stringsAsFactors = FALSE
  )
})
baseline <- do.call(rbind, baseline_rows)

mutation_rows <- lapply(names(stage3_mutations()), function(id) {
  mutation <- stage3_mutations()[[id]]
  changed <- mutation$apply(observed[[mutation$witness]])
  result <- stage3_check_conformance(mutation$witness, changed)
  caught <- !result$pass && mutation$expected %in% result$findings
  stage3_assert(caught, paste(id, "was not rejected with", mutation$expected))
  data.frame(
    mutation_id = id,
    witness_id = mutation$witness,
    rejected = !result$pass,
    expected_finding = mutation$expected,
    findings = paste(result$findings, collapse = ";"),
    stringsAsFactors = FALSE
  )
})
mutation_results <- do.call(rbind, mutation_rows)

if (write_evidence) {
  output_dir <- file.path(root, "evidence", "stage3_results")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  for (witness in names(observed)) {
    utils::write.csv(
      observed[[witness]],
      file.path(output_dir, paste0(witness, "_reference_observed.csv")),
      row.names = FALSE,
      na = ""
    )
  }
  utils::write.csv(package_w21, file.path(output_dir, "W21_package_observed.csv"), row.names = FALSE, na = "")
  utils::write.csv(baseline, file.path(output_dir, "baseline_conformance.csv"), row.names = FALSE, na = "")
  utils::write.csv(mutation_results, file.path(output_dir, "checker_mutations.csv"), row.names = FALSE, na = "")
  environment <- data.frame(
    field = c(
      "recorded_at_utc", "r_version", "platform", "os_name", "os_release",
      "machine", "processor", "ledgr_version", "provider_id"
    ),
    value = c(
      stage3_iso(Sys.time()),
      R.version.string,
      R.version$platform,
      Sys.info()[["sysname"]],
      Sys.info()[["release"]],
      Sys.info()[["machine"]],
      Sys.getenv("PROCESSOR_IDENTIFIER", unset = "unavailable"),
      as.character(utils::packageVersion("ledgr")),
      stage3_provider_id(provider, package_trace$source_identity$snapshot_hash)
    ),
    stringsAsFactors = FALSE
  )
  utils::write.csv(environment, file.path(output_dir, "environment.csv"), row.names = FALSE, na = "")
}

cat("Stage 3 reference provider: ", provider$provider_name, "\n", sep = "")
cat("W21 fork/package dense parity: PASS\n")
cat("Dense representation controls: 1 PASS\n")
cat("Fractional max-weight calibration: PASS\n")
cat("Checker baselines: ", nrow(baseline) - 1L, " PASS\n", sep = "")
cat("Checker mutations: ", nrow(mutation_results), " rejected as required\n", sep = "")
