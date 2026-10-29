# Revert runner for the v0.2.3 cut 4 (workstream 11) witnesses.
#
# Undoes one shipped fix in memory, runs the registered test files against the
# loaded namespace, and reports every test block with its outcome, so a
# witness can be shown to pass on the product and fail when its fix is
# reverted. Nothing here is a gate; it is evidence tooling for LDG-3159 and
# the replacement guts of LDG-3161 (ws2_rng_design.md Section 8.3).
#
# Usage:
#   Rscript dev/bench/v0_2_3_ws2_reverts/runner.R --root=<package root> \
#     --mutation=<name|none> --out=<csv> [--tests=pulse-seed-v2,rng-isolation]
#
# Mutations patch the loaded namespace only. mirai workers load the source
# tree afresh, so a two-worker witness compares a reverted sequential path
# with an unreverted worker path; a mutation that must reach workers needs a
# patched source copy passed as --root. A crash or skip is reported as such
# and is not counted as a predicate failure.

args <- commandArgs(trailingOnly = TRUE)
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit) == 0L) return(default)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
root <- arg("root")
mutation <- arg("mutation", "none")
out <- arg("out")
tests <- strsplit(arg("tests", "pulse-seed-v2"), ",", fixed = TRUE)[[1L]]
if (is.null(root) || is.null(out)) stop("--root and --out are required")

pkgload::load_all(root, quiet = TRUE)
ns <- asNamespace("ledgr")
patch <- function(name, value) utils::assignInNamespace(name, value, ns = ns)

mutations <- list(
  none = function() invisible(NULL),
  # R5: the rule reads one pulse late.
  pulse_shift = function() {
    orig <- ns$ledgr_pulse_seeds
    patch("ledgr_pulse_seeds", function(execution_seed, pulse_idx) {
      if (is.null(execution_seed)) return(NULL)
      orig(execution_seed, pulse_idx + 1)
    })
  },
  # R6: the rule ignores the execution seed.
  seed_ignoring = function() {
    orig <- ns$ledgr_pulse_seeds
    patch("ledgr_pulse_seeds", function(execution_seed, pulse_idx) {
      if (is.null(execution_seed)) return(NULL)
      orig(7L, pulse_idx)
    })
  },
  # R7: the marker stays at the old rule.
  marker_stale = function() patch("ledgr_seed_contract_current", function() "ledgr_seed_v1"),
  # R8: the seeded configuration omits the rule.
  config_rule_dropped = function() {
    orig <- ns$ledgr_config
    patch("ledgr_config", function(...) {
      cfg <- orig(...)
      cfg$engine$pulse_seed_rule <- NULL
      cfg
    })
  },
  # R10: the walk-forward candidate derives its marker from the constant.
  wf_marker_from_constant = function() {
    orig <- ns$ledgr_walk_forward_candidate_from_snapshot
    patch("ledgr_walk_forward_candidate_from_snapshot", function(..., pulse_seed_contract = NULL) {
      orig(..., pulse_seed_contract = ns$ledgr_seed_contract_current())
    })
  },
  # Promotion validation removed.
  validation_noop = function() patch("ledgr_candidate_validate_seed_rule", function(candidate) invisible(TRUE)),
  # The pre-LDG-3159 path: a per-pulse canonical-JSON SHA-256 (rule v1).
  per_pulse_hash = function() {
    patch("ledgr_pulse_seed_at", function(services, pulse_idx) {
      if (is.null(services$pulse_seeds)) return(NULL)
      ns$ledgr_derive_seed(services$execution_seed, list(scope = "pulse", pulse_idx = as.integer(pulse_idx)))
    })
  }
)
if (!mutation %in% names(mutations)) stop("unknown mutation: ", mutation)
mutations[[mutation]]()

rows <- list()
for (test in tests) {
  path <- file.path(root, "tests", "testthat", paste0("test-", test, ".R"))
  result <- as.data.frame(testthat::test_file(path, reporter = "silent", package = "ledgr", load_package = "none",
    stop_on_failure = FALSE))
  rows[[length(rows) + 1L]] <- data.frame(
    mutation = mutation, file = basename(path), test = result$test,
    expectations = result$nb, failed = result$failed, error = result$error, skipped = result$skipped,
    stringsAsFactors = FALSE
  )
}
report <- do.call(rbind, rows)
utils::write.csv(report, out, row.names = FALSE)
bad <- report$failed > 0L | report$error
cat(sprintf("mutation %s: %d blocks, %d failing or erroring, %d skipped\n",
  mutation, nrow(report), sum(bad), sum(report$skipped)))
for (i in which(bad)) cat(sprintf("  FAIL %s: %s%s\n", report$file[[i]], report$test[[i]],
  if (isTRUE(report$error[[i]])) " (error)" else ""))
