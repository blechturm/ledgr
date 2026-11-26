# LDG-3270: Cut 25's final-code proofs, each step one fresh Rscript whose
# output is kept in this folder. The candidate library is installed from
# 4abdb348, whose R/ equals the final commit's (checked first, step r_tree).
# The oracle's candidate run is that library's (C:/Users/maxth/ledgr-wt/
# cut25-scratch/oracle/cand); the pin and its repeat are LDG-3264's runs.
# faults.R (faults.txt) and the full suite (full_tests_summary.txt) run on
# their own and are recorded beside these steps; R CMD check is buildcheck.
#
#   Rscript dev/feature_parity/evidence/ldg3270/run_proofs.R --final=<commit>
local({
  argv <- commandArgs(TRUE)
  final <- sub("^--final=", "", grep("^--final=", argv, value = TRUE)[[1L]])
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  repo <- normalizePath(file.path(here, "..", "..", "..", ".."), winslash = "/")
  fp <- file.path(repo, "dev", "feature_parity")
  S <- "C:/Users/maxth/ledgr-wt/cut25-scratch"
  pin <- "C:/Users/maxth/ledgr-wt/cut24-scratch/ldg3264/pin"
  pin_repeat <- "C:/Users/maxth/ledgr-wt/cut24-scratch/ldg3264/pin_repeat"
  base_identity <- "C:/Users/maxth/ledgr-wt/cut24-scratch/ldg3266/identity_ws43"
  lib <- file.path(S, "libs", "cand-4abdb348")
  cand <- file.path(S, "oracle", "cand")
  rscript <- file.path(R.home("bin"), "Rscript.exe")
  step <- function(name, script, ...) {
    log <- file.path(here, paste0(name, ".txt"))
    cat(format(Sys.time(), "%H:%M:%S"), name, "\n")
    status <- system2(rscript, c(script, ...), stdout = log, stderr = log)
    cat("   exit", status, ":", tail(readLines(log, warn = FALSE), 1L), "\n")
    invisible(status)
  }
  tree <- function(commit) system2("git", c("-C", repo, "rev-parse", paste0(commit, ":R")), stdout = TRUE)
  writeLines(c(sprintf("R/ tree at 4abdb348: %s", tree("4abdb348")), sprintf("R/ tree at %s: %s", final, tree(final)),
               sprintf("equal: %s", identical(tree("4abdb348"), tree(final)))), file.path(here, "r_tree.txt"))
  stopifnot(identical(tree("4abdb348"), tree(final)))
  step("check_final", file.path(fp, "check.R"), paste0("--pin=", pin), paste0("--candidate=", cand))
  step("check_final_declared_none", file.path(fp, "check.R"), paste0("--pin=", pin), paste0("--candidate=", cand),
       "--declared=none")
  step("check_pin_repeat", file.path(fp, "check.R"), paste0("--pin=", pin), paste0("--candidate=", pin_repeat),
       "--declared=none")
  step("check_pin_as_candidate", file.path(fp, "check.R"), paste0("--pin=", pin), paste0("--candidate=", pin))
  step("oracle_flips_final", file.path(repo, "dev", "bench", "v0_2_3_cut25_chores", "oracle_flips.R"),
       paste0("--pin=", pin), paste0("--candidate=", cand), paste0("--out=", file.path(here, "oracle_flips_final.csv")))
  step("semantics_pin", file.path(fp, "declared_semantics.R"), "--arm=pin_fn_twin",
       "--lib=C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151", paste0("--out=", S, "/semantics_final"))
  step("semantics_candidate", file.path(fp, "declared_semantics.R"), "--arm=candidate", paste0("--lib=", lib),
       paste0("--out=", S, "/semantics_final"))
  step("semantics_compare", file.path(fp, "declared_semantics.R"), "--compare", paste0("--out=", S, "/semantics_final"))
  step("declared_controls", file.path(fp, "declared_controls.R"), paste0("--pin=", pin), paste0("--candidate=", cand),
       paste0("--scratch=", S, "/declared_controls_final"), paste0("--evidence=", file.path(here, "declared_controls")))
  step("identity_final", file.path(fp, "identity.R"), paste0("--lib=", lib), paste0("--out=", S, "/identity_final"),
       paste0("--old=", base_identity), "--debug=0")
  step("identity_check", file.path(fp, "identity_check.R"), paste0("--base=", base_identity),
       paste0("--candidate=", S, "/identity_final"), "--mode=changed-engine")
  step("emitted_pin_final", file.path(fp, "emitted_pin.R"), paste0("--record=", S, "/identity_final"))
  step("counts_final", file.path(fp, "counts.R"), paste0("--lib=", lib), paste0("--out=", S, "/counts_final"))
  step("census_check", file.path(fp, "census.R"), paste0("--source=", repo), paste0("--out=", file.path(here, "census")),
       paste0("--census=", file.path(fp, "census.csv")))
  step("lines", file.path(fp, "lines.R"), paste0("--repo=", repo), "--base=ca635540", paste0("--final=", final),
       paste0("--out=", file.path(here, "lines.csv")))
  cat("done\n")
})
