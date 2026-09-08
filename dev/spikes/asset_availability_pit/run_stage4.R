args <- commandArgs(trailingOnly = TRUE)
no_write <- "--no-write" %in% args
output_arg <- grep("^--output-dir=", args, value = TRUE)
output_dir <- if (length(output_arg) == 0L) NULL else
  sub("^--output-dir=", "", output_arg[[1L]])
if (no_write && is.null(output_dir)) {
  stop("--no-write requires --output-dir so recorded evidence is untouched.", call. = FALSE)
}

.libPaths(c(normalizePath("lib", winslash = "/", mustWork = FALSE), .libPaths()))
pkgload::load_all(".", quiet = TRUE)

root <- normalizePath(
  file.path("dev", "spikes", "asset_availability_pit"),
  winslash = "/", mustWork = TRUE
)
for (file in c(
  "common.R", "reference_provider.R", "shared_fold.R",
  "package_dense_control.R", "w21_evidence.R", "mutations.R"
)) source(file.path(root, "stage3", file), local = .GlobalEnv)
for (file in c(
  "common.R", "providers.R", "policy_engine.R", "fixtures.R", "fork.R",
  "conformance.R"
)) source(file.path(root, "stage4", file), local = .GlobalEnv)

registry <- utils::read.csv(
  file.path(root, "witness_registry.csv"), stringsAsFactors = FALSE
)
stage4_assert(
  identical(names(registry), c(
    "witness_id", "witness_class", "title", "fixture_manifest",
    "expected_table", "status", "maintainer_approved", "independent_reviewed"
  )),
  "Frozen witness registry has an unexpected schema."
)
stage4_assert(nrow(registry) == 31L, "Stage 4 requires all 31 witness records.")

observed <- list()
conformance <- list()
memory <- list()
baselines <- list()
input_identities <- list()
at <- 0L
ct <- 0L
mt <- 0L

for (kind in stage4_provider_kinds()) {
  for (witness_id in registry$witness_id) {
    spec <- stage4_case_spec(witness_id)
    provider <- stage4_build_provider(kind, spec$fixture)
    input_identities[[paste(kind, witness_id, sep = ":")]] <-
      stage4_recovered_fact_identity(provider)

    if (witness_id == "W20") {
      direct_spec <- spec
      direct_spec$path <- "direct"
      direct <- stage4_run_case(provider, direct_spec)

      restored_provider <- stage4_restore(stage4_serialize(provider))
      restore_spec <- spec
      restore_spec$path <- "restore"
      restored <- stage4_run_case(restored_provider, restore_spec)

      parallel_spec <- spec
      parallel_spec$path <- "par"
      parallel <- stage4_psock_case(provider, parallel_spec)
      value <- rbind(direct, restored, parallel)

      mt <- mt + 1L
      memory[[mt]] <- stage4_memory_row(provider, "direct")
      mt <- mt + 1L
      memory[[mt]] <- stage4_memory_row(restored_provider, "restore")
    } else {
      value <- stage4_run_case(provider, spec)
    }

    at <- at + 1L
    observed[[at]] <- value
    if (spec$role == "executable") {
      checked <- stage4_check_conformance(value)
      stage4_assert(
        all(checked$pass),
        paste(kind, witness_id, "failed conformance on",
          paste(unique(checked$field[!checked$pass]), collapse = ", "))
      )
      ct <- ct + 1L
      conformance[[ct]] <- checked
      if (kind == "dense_state_planes") baselines[[witness_id]] <- value
    }
  }
}

for (witness_id in registry$witness_id) {
  ids <- unlist(input_identities[
    paste(stage4_provider_kinds(), witness_id, sep = ":")
  ], use.names = FALSE)
  stage4_assert(
    length(unique(ids)) == 1L,
    paste(witness_id, "providers did not recover identical fixture rows.")
  )
}

observed <- do.call(rbind, observed)
conformance <- do.call(rbind, conformance)
memory <- do.call(rbind, memory)
mutations <- stage4_checker_mutations(baselines)
stage4_assert_w20_path_identity(observed[observed$witness_id == "W20", , drop = FALSE])
policy_examples <- observed[
  observed$evidence_role == "fixture_input" &
    observed$provider == "dense_state_planes",
  , drop = FALSE
]

order_rows <- function(x, columns) {
  x[do.call(order, c(x[columns], list(method = "radix"))), , drop = FALSE]
}
conformance_groups <- split(
  conformance, paste(conformance$provider, conformance$witness_id, sep = "\034")
)
conformance <- do.call(rbind, lapply(conformance_groups, function(x) {
  expected <- stage3_read_expected(x$witness_id[[1L]])
  checked_keys <- unique(stage4_evidence_key(x))
  expected_keys <- stage4_evidence_key(expected)
  data.frame(
    provider = x$provider[[1L]],
    witness_id = x$witness_id[[1L]],
    checked_fields = length(checked_keys),
    expected_fields = length(expected_keys),
    unchecked_fields = sum(!expected_keys %in% checked_keys),
    checked_roles = paste(sort(unique(x$evidence_role), method = "radix"),
      collapse = "|"),
    evidence_hash = stage3_hash(lapply(seq_len(nrow(x)), function(i) {
      as.list(x[i, c(
        "case_id", "step", "event_time", "asset_id", "field",
        "observed_type", "observed_value", "reason_code"
      ), drop = FALSE])
    })),
    evidence_role = if (x$witness_id[[1L]] == "W21")
      "package_control" else "fork_derived",
    pass = all(x$pass),
    stringsAsFactors = FALSE
  )
}))
conformance <- order_rows(conformance, c("provider", "witness_id"))
policy_examples <- order_rows(policy_examples, c("witness_id", "case_id", "field"))
memory <- order_rows(memory, c("provider", "path"))
mutations <- order_rows(mutations, "mutation_id")
rownames(conformance) <- rownames(policy_examples) <- NULL
rownames(memory) <- rownames(mutations) <- NULL

output <- output_dir %||% file.path(root, "evidence", "stage4_results")
dir.create(output, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(conformance, file.path(output, "conformance.csv"), row.names = FALSE, na = "")
utils::write.csv(policy_examples, file.path(output, "policy_examples.csv"), row.names = FALSE, na = "")
utils::write.csv(mutations, file.path(output, "checker_mutations.csv"), row.names = FALSE, na = "")
utils::write.csv(memory, file.path(output, "provider_memory.csv"), row.names = FALSE, na = "")

cat("Stage 4 providers:", length(stage4_provider_kinds()), "\n")
cat("Stage 4 executable witnesses:", length(stage4_executable_witnesses()), "\n")
cat("Stage 4 policy examples:", nrow(registry) - length(stage4_executable_witnesses()), "\n")
cat("Conformance rows:", nrow(conformance), "all PASS\n")
cat("Checker mutations:", nrow(mutations), "all rejected\n")
cat("Evidence output:", normalizePath(output, winslash = "/", mustWork = TRUE), "\n")
