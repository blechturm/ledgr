args <- commandArgs(trailingOnly = TRUE)
mode_arg <- grep("^--mode=", args, value = TRUE)
mode <- if (length(mode_arg) == 0L) {
  "setup"
} else {
  sub("^--mode=", "", mode_arg[[1L]])
}

fail <- function(message) {
  cat("STAGE2 CHECK FAILED: ", message, "\n", sep = "")
  quit(save = "no", status = 1L)
}

repo_path <- function(path) {
  gsub("\\\\", "/", path)
}

hash_lf_normalized <- function(path) {
  size <- file.info(path)$size
  bytes <- readBin(path, what = "raw", n = size)
  if (any(bytes == as.raw(0L))) {
    fail(paste("Frozen input is not a text file:", path))
  }
  text <- rawToChar(bytes)
  if (!validUTF8(text)) {
    fail(paste("Frozen input is not valid UTF-8:", path))
  }
  text <- gsub("\r\n", "\n", text, fixed = TRUE)
  text <- gsub("\r", "\n", text, fixed = TRUE)
  digest::digest(charToRaw(text), algo = "sha256", serialize = FALSE)
}

read_contract_csv <- function(path) {
  utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = "character",
    na.strings = character()
  )
}

git_status <- function(args) {
  suppressWarnings(system2(
    "git",
    args,
    stdout = FALSE,
    stderr = FALSE
  ))
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
hashes_path <- file.path(spike_dir, "evidence", "frozen_hashes.csv")
code_registry_path <- file.path(
  spike_dir,
  "evidence",
  "preprototype_code.csv"
)
checker_path <- file.path(spike_dir, "check_stage2.R")
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
  hashes_path,
  code_registry_path,
  checker_path,
  charter_path
)
missing_required <- required_files[!file.exists(required_files)]
if (length(missing_required) > 0L) {
  fail(paste("Missing setup files:", paste(missing_required, collapse = ", ")))
}

registry <- read_contract_csv(registry_path)
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
  fail("Witness registry columns do not match the Stage 2 contract.")
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

if (any(!nzchar(registry$title))) {
  fail("Every witness must have a non-empty title.")
}

allowed_status <- c("pending", "drafted", "approved")
if (any(!registry$status %in% allowed_status)) {
  fail("Witness status must be pending, drafted, or approved.")
}

code_registry <- read_contract_csv(code_registry_path)
if (!identical(names(code_registry), c("path", "role"))) {
  fail("Pre-prototype code registry must contain `path` and `role`.")
}
code_registry$path <- repo_path(code_registry$path)
if (any(!nzchar(code_registry$path)) || anyDuplicated(code_registry$path)) {
  fail("Pre-prototype code paths must be non-empty and unique.")
}
allowed_code_roles <- c(
  "stage_gate",
  "reference_calculation",
  "checker_mutation"
)
if (any(!code_registry$role %in% allowed_code_roles)) {
  fail("Pre-prototype code registry contains an unsupported role.")
}
checker_repo_path <- repo_path(checker_path)
checker_rows <- code_registry$path == checker_repo_path &
  code_registry$role == "stage_gate"
if (sum(checker_rows) != 1L) {
  fail("The Stage 2 checker must be registered exactly once as `stage_gate`.")
}

reference_prefix <- paste0(repo_path(file.path(spike_dir, "references")), "/")
mutation_prefix <- paste0(
  repo_path(file.path(spike_dir, "evidence", "checker_mutations")),
  "/"
)
reference_rows <- code_registry$role == "reference_calculation"
mutation_rows <- code_registry$role == "checker_mutation"
if (any(reference_rows & !startsWith(code_registry$path, reference_prefix))) {
  fail("Reference calculations must live under the spike `references/` path.")
}
if (any(mutation_rows & !startsWith(code_registry$path, mutation_prefix))) {
  fail("Checker mutations must live under `evidence/checker_mutations/`.")
}

missing_code <- code_registry$path[!file.exists(code_registry$path)]
if (length(missing_code) > 0L) {
  fail(paste("Missing registered pre-prototype code:", paste(missing_code,
    collapse = ", ")))
}

code_extensions <- c(
  "r", "rmd", "qmd", "py", "js", "ts", "c", "cc", "cpp", "h", "hpp",
  "sh", "ps1", "sql", "bat", "cmd", "rprofile", "renviron", "txt"
)
spike_files <- list.files(
  spike_dir,
  recursive = TRUE,
  full.names = TRUE,
  all.files = TRUE,
  no.. = TRUE
)
spike_files <- repo_path(spike_files[!dir.exists(spike_files)])
code_files <- spike_files[
  tolower(tools::file_ext(spike_files)) %in% code_extensions
]
make_files <- spike_files[
  tolower(basename(spike_files)) %in% c("makefile", "gnumakefile")
]
code_files <- unique(c(code_files, make_files))
undeclared_code <- setdiff(code_files, code_registry$path)
if (length(undeclared_code) > 0L) {
  fail(paste(
    "Prototype or undeclared code exists before the Stage 2 gate:",
    paste(undeclared_code, collapse = ", ")
  ))
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
base_status <- git_status(c(
  "merge-base",
  "--is-ancestor",
  base_commit,
  "HEAD"
))
if (!identical(base_status, 0L)) {
  fail(paste("HEAD does not descend from package base", base_commit))
}

charter_commit_status <- git_status(c(
  "diff",
  "--quiet",
  base_commit,
  "HEAD",
  "--",
  repo_path(charter_path)
))
if (!identical(charter_commit_status, 0L)) {
  fail(paste("The spike charter differs from frozen commit", base_commit))
}
charter_changes <- system2(
  "git",
  c("status", "--porcelain", "--", repo_path(charter_path)),
  stdout = TRUE,
  stderr = FALSE
)
if (length(charter_changes) > 0L) {
  fail("The frozen spike charter has uncommitted changes.")
}

runtime_paths <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man")
runtime_commit_status <- git_status(c(
  "diff",
  "--quiet",
  base_commit,
  "HEAD",
  "--",
  runtime_paths
))
if (!identical(runtime_commit_status, 0L)) {
  fail(paste("Committed package runtime paths differ from base", base_commit))
}
runtime_changes <- system2(
  "git",
  c("status", "--porcelain", "--", runtime_paths),
  stdout = TRUE,
  stderr = FALSE
)
Sys.setenv(HOME = old_home)
if (length(runtime_changes) > 0L) {
  change_text <- paste(runtime_changes, collapse = "; ")
  fail(paste("Uncommitted package runtime paths changed:", change_text))
}

if (identical(mode, "setup")) {
  cat("Stage 2 workspace setup is structurally valid.\n")
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
if (!grepl("**Status:** Stage 2 frozen.", manifest, fixed = TRUE)) {
  fail("Evidence manifest has not frozen the Stage 2 inputs.")
}

if (!all(registry$status == "approved")) {
  fail("Every witness must have approved status.")
}
if (!all(tolower(registry$maintainer_approved) == "true")) {
  fail("Every witness requires maintainer approval.")
}
if (!all(tolower(registry$independent_reviewed) == "true")) {
  fail("Every witness requires independent review.")
}

artifact_paths <- c(registry$fixture_manifest, registry$expected_table)
artifact_paths <- repo_path(file.path(spike_dir, artifact_paths))
missing_artifacts <- artifact_paths[!file.exists(artifact_paths)]
if (length(missing_artifacts) > 0L) {
  artifact_text <- paste(missing_artifacts, collapse = ", ")
  fail(paste("Missing witness artifacts:", artifact_text))
}

expected_columns <- c(
  "witness_id", "case_id", "step", "event_time", "asset_id", "field",
  "expected_type", "expected_value", "reason_code", "identity_expectation",
  "comparison", "tolerance", "derivation"
)
for (i in seq_len(nrow(registry))) {
  expected_path <- repo_path(file.path(spike_dir, registry$expected_table[[i]]))
  expected_table <- read_contract_csv(expected_path)
  if (!identical(names(expected_table), expected_columns)) {
    fail(paste(
      "Expected-table columns are invalid for",
      registry$witness_id[[i]]
    ))
  }
  if (nrow(expected_table) == 0L ||
      any(expected_table$witness_id != registry$witness_id[[i]])) {
    fail(paste(
      "Expected-table witness IDs are invalid for",
      registry$witness_id[[i]]
    ))
  }
  allowed_types <- c(
    "logical", "integer", "double", "character", "timestamp", "absent"
  )
  if (any(!expected_table$expected_type %in% allowed_types)) {
    fail(paste("Expected-table type is invalid for", registry$witness_id[[i]]))
  }
  double_rows <- expected_table$expected_type == "double"
  if (any(expected_table$comparison[double_rows] != "abs_tol")) {
    fail(paste("Double rows must use `abs_tol` for", registry$witness_id[[i]]))
  }
  numeric_tolerance <- suppressWarnings(as.numeric(
    expected_table$tolerance[double_rows]
  ))
  if (any(!is.finite(numeric_tolerance)) || any(numeric_tolerance < 0)) {
    fail(paste("Double tolerance is invalid for", registry$witness_id[[i]]))
  }
  exact_rows <- !double_rows
  if (any(expected_table$comparison[exact_rows] != "exact") ||
      any(nzchar(expected_table$tolerance[exact_rows]))) {
    fail(paste("Non-double rows must use exact comparison for",
      registry$witness_id[[i]]))
  }
  allowed_identity <- c("equal", "changed", "absent", "not_applicable")
  if (any(!expected_table$identity_expectation %in% allowed_identity)) {
    fail(paste("Identity expectation is invalid for", registry$witness_id[[i]]))
  }
  absent_rows <- expected_table$expected_type == "absent"
  if (any(nzchar(expected_table$expected_value[absent_rows]))) {
    fail(paste("Absent values must be empty for", registry$witness_id[[i]]))
  }
  logical_rows <- expected_table$expected_type == "logical"
  invalid_logical <- !expected_table$expected_value[logical_rows] %in%
    c("true", "false")
  if (any(invalid_logical)) {
    fail(paste("Logical values are invalid for", registry$witness_id[[i]]))
  }
}

freeze_match <- regexec(
  "- Stage 2 evidence commit: `([0-9a-f]{40})`\\.",
  manifest
)
freeze_capture <- regmatches(manifest, freeze_match)[[1L]]
if (length(freeze_capture) != 2L) {
  fail("Manifest must record the full Stage 2 evidence commit.")
}
freeze_commit <- freeze_capture[[2L]]
freeze_ancestor <- git_status(c(
  "merge-base",
  "--is-ancestor",
  freeze_commit,
  "HEAD"
))
if (!identical(freeze_ancestor, 0L)) {
  fail("Recorded Stage 2 evidence commit is not an ancestor of HEAD.")
}
freeze_after_base <- git_status(c(
  "merge-base",
  "--is-ancestor",
  base_commit,
  freeze_commit
))
if (!identical(freeze_after_base, 0L)) {
  fail(paste(
    "Recorded Stage 2 evidence commit does not descend from",
    "the package base."
  ))
}

fixed_targets <- data.frame(
  path = repo_path(c(
    charter_path,
    policy_path,
    spec_path,
    registry_path,
    code_registry_path
  )),
  role = c(
    "charter",
    "policy",
    "witness_spec",
    "witness_registry",
    "code_registry"
  ),
  stringsAsFactors = FALSE
)
fixture_targets <- data.frame(
  path = repo_path(file.path(spike_dir, registry$fixture_manifest)),
  role = "fixture_manifest",
  stringsAsFactors = FALSE
)
expected_targets <- data.frame(
  path = repo_path(file.path(spike_dir, registry$expected_table)),
  role = "expected_table",
  stringsAsFactors = FALSE
)
code_targets <- data.frame(
  path = code_registry$path,
  role = code_registry$role,
  stringsAsFactors = FALSE
)
freeze_targets <- rbind(
  fixed_targets,
  fixture_targets,
  expected_targets,
  code_targets
)
if (anyDuplicated(freeze_targets$path)) {
  fail("A frozen path has more than one role.")
}
freeze_targets <- freeze_targets[
  order(freeze_targets$path, method = "radix"),
  ,
  drop = FALSE
]
row.names(freeze_targets) <- NULL

frozen_hashes <- read_contract_csv(hashes_path)
if (!identical(names(frozen_hashes), c("path", "role", "sha256"))) {
  fail("Frozen hash registry must contain `path`, `role`, and `sha256`.")
}
frozen_hashes$path <- repo_path(frozen_hashes$path)
if (anyDuplicated(frozen_hashes$path) ||
    !identical(
      frozen_hashes$path,
      sort(frozen_hashes$path, method = "radix")
    )) {
  fail("Frozen hash paths must be unique and sorted.")
}
if (!identical(frozen_hashes[c("path", "role")], freeze_targets)) {
  fail("Frozen hash registry does not exactly match the Stage 2 freeze set.")
}
if (any(!grepl("^[0-9a-f]{64}$", frozen_hashes$sha256))) {
  fail("Every frozen hash must be a lowercase SHA-256 value.")
}
if (!requireNamespace("digest", quietly = TRUE)) {
  fail("Package `digest` is required to verify frozen evidence.")
}
actual_hashes <- vapply(
  frozen_hashes$path,
  hash_lf_normalized,
  character(1L)
)
hash_mismatch <- frozen_hashes$path[actual_hashes != frozen_hashes$sha256]
if (length(hash_mismatch) > 0L) {
  fail(paste("Frozen evidence hash mismatch:", paste(hash_mismatch,
    collapse = ", ")))
}

old_home <- Sys.getenv("HOME")
if (nzchar(user_profile)) {
  Sys.setenv(HOME = user_profile)
}
freeze_diff <- git_status(c(
  "diff",
  "--quiet",
  freeze_commit,
  "HEAD",
  "--",
  freeze_targets$path
))
gate_changes <- system2(
  "git",
  c("status", "--porcelain", "--", repo_path(spike_dir)),
  stdout = TRUE,
  stderr = FALSE
)
Sys.setenv(HOME = old_home)
if (!identical(freeze_diff, 0L)) {
  fail("Stage 2 evidence changed after its recorded freeze commit.")
}
if (length(gate_changes) > 0L) {
  fail("Stage 2 gate requires a clean, committed spike workspace.")
}

cat("Stage 2 gate passed. Fold-fork implementation may begin.\n")
