RUN_SPECIFIC_FIELDS <- character()

fail <- function(message) {
  message("Stage 4 check failed: ", message)
  quit(save = "no", status = 1L)
}

root <- normalizePath(
  file.path("dev", "spikes", "asset_availability_pit"),
  winslash = "/", mustWork = TRUE
)
recorded <- file.path(root, "evidence", "stage4_results")
fresh <- file.path(root, "scratch", "stage4_check_fresh")
if (dir.exists(fresh)) unlink(fresh, recursive = TRUE, force = TRUE)
dir.create(fresh, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(fresh, recursive = TRUE, force = TRUE), add = TRUE)

rscript <- file.path(R.home("bin"), "Rscript.exe")
if (!file.exists(rscript)) rscript <- file.path(R.home("bin"), "Rscript")
status <- system2(
  rscript,
  c(
    file.path(root, "run_stage4.R"),
    "--no-write",
    paste0("--output-dir=", fresh)
  )
)
if (status != 0L) fail("the fresh Stage 4 run failed")

files <- c(
  "conformance.csv", "policy_examples.csv", "checker_mutations.csv",
  "provider_memory.csv"
)
read_evidence <- function(path) {
  value <- utils::read.csv(
    path, stringsAsFactors = FALSE, check.names = FALSE,
    colClasses = "character", na.strings = character()
  )
  keep <- setdiff(names(value), RUN_SPECIFIC_FIELDS)
  value[, keep, drop = FALSE]
}
for (file in files) {
  old <- file.path(recorded, file)
  new <- file.path(fresh, file)
  if (!file.exists(old) || !file.exists(new)) fail(paste("missing evidence file", file))
  if (!identical(read_evidence(old), read_evidence(new))) {
    fail(paste("fresh evidence differs from", file))
  }
}

allowed_roles <- c("fork_derived", "package_control", "fixture_input")
tables <- lapply(files, function(file) read_evidence(file.path(fresh, file)))
for (i in seq_along(tables)) {
  if (!"evidence_role" %in% names(tables[[i]])) {
    fail(paste(files[[i]], "has no evidence_role column"))
  }
  if (any(!tables[[i]]$evidence_role %in% allowed_roles)) {
    fail(paste(files[[i]], "has an invalid evidence_role"))
  }
}
conformance <- tables[[match("conformance.csv", files)]]
policy_examples <- tables[[match("policy_examples.csv", files)]]
coverage_fields <- c("checked_fields", "expected_fields", "unchecked_fields")
if (!all(coverage_fields %in% names(conformance))) {
  fail("conformance evidence does not disclose frozen-table coverage")
}
unchecked <- conformance[as.integer(conformance$unchecked_fields) > 0L, , drop = FALSE]
if (nrow(unchecked) > 0L && any(unchecked$witness_id != "W20")) {
  fail("an executable witness other than W20 leaves frozen rows unchecked")
}
if (nrow(unchecked) > 0L && any(as.integer(unchecked$unchecked_fields) != 87L)) {
  fail("W20 unchecked-row disclosure no longer matches the retired paths")
}
w02_roles <- unique(conformance$checked_roles[conformance$witness_id == "W02"])
if (!identical(w02_roles, "fork_derived|package_control")) {
  fail("W02 does not disclose both fork and package-control evidence")
}

for (file in c(
  "common.R", "reference_provider.R", "shared_fold.R",
  "package_dense_control.R", "w21_evidence.R", "mutations.R"
)) source(file.path(root, "stage3", file), local = .GlobalEnv)
for (file in c(
  "common.R", "providers.R", "policy_engine.R", "fixtures.R", "fork.R"
)) source(file.path(root, "stage4", file), local = .GlobalEnv)

fixture_rows <- policy_examples[
  policy_examples$evidence_role == "fixture_input", , drop = FALSE
]
for (i in seq_len(nrow(fixture_rows))) {
  spec <- stage4_case_spec(fixture_rows$witness_id[[i]])
  if (!fixture_rows$field[[i]] %in% spec$fixture$rows$field) {
    fail(paste(
      fixture_rows$witness_id[[i]], "labels a non-fixture field as fixture_input"
    ))
  }
}

forbidden <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
git_status <- suppressWarnings(system2(
  "git", c("status", "--porcelain", "--untracked-files=all", "--", forbidden),
  stdout = TRUE, stderr = FALSE
))
if (length(git_status) > 0L) fail("package/runtime/design paths differ from HEAD")
git_diff <- suppressWarnings(system2(
  "git", c("diff", "--name-only", "1f42cf7", "--", forbidden),
  stdout = TRUE, stderr = FALSE
))
if (length(git_diff) > 0L) {
  fail("package/runtime/design paths differ from the spike base commit")
}

cat("Stage 4 check PASS\n")
cat("Fresh evidence matches", length(files), "recorded CSV files.\n")
cat("Evidence roles and fixture-input provenance PASS.\n")
cat("Frozen-table coverage disclosure PASS.\n")
cat("Package/runtime/design scope guard PASS.\n")
