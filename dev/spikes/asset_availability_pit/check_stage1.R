args <- commandArgs(trailingOnly = TRUE)
mode_arg <- grep("^--mode=", args, value = TRUE)
mode <- if (length(mode_arg) == 0L) {
  "setup"
} else {
  sub("^--mode=", "", mode_arg[[1L]])
}

fail <- function(message) {
  cat("STAGE1 CHECK FAILED: ", message, "\n", sep = "")
  quit(save = "no", status = 1L)
}

if (!mode %in% c("setup", "gate")) {
  fail("`--mode` must be `setup` or `gate`.")
}

if (!file.exists("DESCRIPTION")) {
  fail("Run from the ledgr repository root.")
}

spike_dir <- file.path("dev", "spikes", "asset_availability_pit")
registry_path <- file.path(spike_dir, "witness_registry.csv")
policy_path <- file.path(spike_dir, "initial_policy_config.md")
spec_path <- file.path(spike_dir, "witness_spec.md")
manifest_path <- file.path(spike_dir, "evidence", "manifest.md")
charter_path <- file.path(
  "inst",
  "design",
  "rfc",
  "rfc_asset_availability_point_in_time_universes_v0_1_9_8_spike_charter.md"
)

required_files <- c(
  registry_path,
  policy_path,
  spec_path,
  manifest_path,
  charter_path
)
missing_required <- required_files[!file.exists(required_files)]
if (length(missing_required) > 0L) {
  fail(paste("Missing setup files:", paste(missing_required, collapse = ", ")))
}

registry <- utils::read.csv(
  registry_path,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

required_columns <- c(
  "witness_id",
  "witness_class",
  "title",
  "fixture_manifest",
  "expected_table",
  "status",
  "maintainer_approved",
  "independent_reviewed"
)
if (!identical(names(registry), required_columns)) {
  fail("Witness registry columns do not match the Stage 1 contract.")
}

expected_ids <- sprintf("W%02d", seq_len(31L))
if (!identical(registry$witness_id, expected_ids)) {
  fail("Witness registry must contain W01-W31 exactly once in order.")
}

charter <- readLines(charter_path, warn = FALSE)
charter_headings <- grep("^### W[0-9]+\\.", charter, value = TRUE)
charter_numbers <- as.integer(sub(
  "^### W([0-9]+)\\..*$",
  "\\1",
  charter_headings
))
charter_ids <- sprintf("W%02d", charter_numbers)
if (!identical(charter_ids, expected_ids)) {
  fail("Authoritative charter must contain W1-W31 exactly once in order.")
}

discriminating_ids <- c("W17", "W18", "W20", "W21", "W25")
expected_classes <- ifelse(
  expected_ids %in% discriminating_ids,
  "representation_discriminating",
  "semantic_oracle"
)
if (!identical(registry$witness_class, expected_classes)) {
  fail("Witness classes do not match the charter.")
}

if (anyNA(registry$title) || any(!nzchar(registry$title))) {
  fail("Every witness must have a non-empty title.")
}

allowed_status <- c("pending", "drafted", "approved")
if (any(!registry$status %in% allowed_status)) {
  fail("Witness status must be pending, drafted, or approved.")
}

old_home <- Sys.getenv("HOME")
user_profile <- Sys.getenv("USERPROFILE")
if (nzchar(user_profile)) {
  Sys.setenv(HOME = user_profile)
}
branch <- trimws(system2(
  "git",
  c("branch", "--show-current"),
  stdout = TRUE
))
if (!identical(branch, "spike/asset-availability-pit-universes")) {
  fail(paste("Unexpected branch:", branch))
}

base_commit <- "1f42cf7"
base_status <- system2(
  "git",
  c("merge-base", "--is-ancestor", base_commit, "HEAD"),
  stdout = FALSE,
  stderr = FALSE
)
if (!identical(base_status, 0L)) {
  fail(paste("HEAD does not descend from package base", base_commit))
}

runtime_paths <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION")
runtime_changes <- system2(
  "git",
  c("status", "--porcelain", "--", runtime_paths),
  stdout = TRUE,
  stderr = FALSE
)
Sys.setenv(HOME = old_home)
if (length(runtime_changes) > 0L) {
  change_text <- paste(runtime_changes, collapse = "; ")
  fail(paste("Package runtime paths changed:", change_text))
}

if (identical(mode, "setup")) {
  cat("Stage 1 workspace setup is structurally valid.\n")
  approved <- sum(registry$status == "approved")
  cat("Witnesses: 31; approved: ", approved, ".\n", sep = "")
  cat("Prototype implementation remains blocked until --mode=gate passes.\n")
  quit(save = "no", status = 0L)
}

policy <- paste(readLines(policy_path, warn = FALSE), collapse = "\n")
spec <- paste(readLines(spec_path, warn = FALSE), collapse = "\n")
manifest <- paste(readLines(manifest_path, warn = FALSE), collapse = "\n")
if (!grepl("**Status:** Maintainer approved.", policy, fixed = TRUE)) {
  fail("Initial policy is not maintainer approved.")
}
if (!grepl("**Status:** Frozen and maintainer approved.", spec, fixed = TRUE)) {
  fail("Witness evidence contract is not frozen and maintainer approved.")
}
if (!grepl("**Status:** Stage 1 frozen.", manifest, fixed = TRUE)) {
  fail("Evidence manifest has not frozen the Stage 1 inputs.")
}

if (!all(registry$status == "approved")) {
  fail("Every witness must have approved status.")
}
if (!all(registry$maintainer_approved)) {
  fail("Every witness requires maintainer approval.")
}
if (!all(registry$independent_reviewed)) {
  fail("Every witness requires independent review.")
}

artifact_paths <- c(registry$fixture_manifest, registry$expected_table)
artifact_paths <- file.path(spike_dir, artifact_paths)
missing_artifacts <- artifact_paths[!file.exists(artifact_paths)]
if (length(missing_artifacts) > 0L) {
  artifact_text <- paste(missing_artifacts, collapse = ", ")
  fail(paste("Missing witness artifacts:", artifact_text))
}

cat("Stage 1 gate passed. Fold-fork implementation may begin.\n")
