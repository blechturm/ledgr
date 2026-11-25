# LDG-3261: the final-code proofs of workstream 43, run in order, each step
# one fresh Rscript whose output is kept in this folder.
#
#   Rscript dev/feature_parity/evidence/ldg3261/run_proofs.R --final=<commit>
local({
  argv <- commandArgs(TRUE)
  final <- sub("^--final=", "", grep("^--final=", argv, value = TRUE)[[1L]])
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  repo <- normalizePath(file.path(here, "..", "..", "..", ".."), winslash = "/")
  fp <- file.path(repo, "dev", "feature_parity")
  S <- "C:/Users/maxth/ledgr-wt/cut24-scratch"
  pin <- "C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151"
  lib <- file.path(S, "libs", paste0("final-", final))
  rscript <- file.path(R.home("bin"), "Rscript.exe")
  step <- function(name, script, ...) {
    out <- file.path(here, paste0(name, ".txt"))
    cat(format(Sys.time(), "%H:%M:%S"), name, "\n")
    status <- system2(rscript, c(script, ...), stdout = out, stderr = out)
    cat("   exit", status, ":", tail(readLines(out, warn = FALSE), 1L), "\n")
    invisible(status)
  }
  if (!dir.exists(lib)) step("install_final", file.path(fp, "install_arm.R"), paste0("--repo=", repo),
                             paste0("--commit=", final), paste0("--lib=", lib))
  step("oracle_pin", file.path(fp, "runner.R"), "--arm=pin", paste0("--lib=", pin), paste0("--out=", S, "/oracle/pin"))
  step("oracle_pin_repeat", file.path(fp, "runner.R"), "--arm=pin_repeat", paste0("--lib=", pin),
       paste0("--out=", S, "/oracle/pin_repeat"))
  step("oracle_final", file.path(fp, "runner.R"), paste0("--arm=final_", final), paste0("--lib=", lib),
       paste0("--out=", S, "/oracle/final"))
  step("check_pin_repeat", file.path(fp, "check.R"), paste0("--pin=", S, "/oracle/pin"),
       paste0("--candidate=", S, "/oracle/pin_repeat"))
  step("check_final", file.path(fp, "check.R"), paste0("--pin=", S, "/oracle/pin"), paste0("--candidate=", S, "/oracle/final"))
  step("faults", file.path(fp, "faults.R"), paste0("--lib=", lib), paste0("--pin=", S, "/oracle/pin"),
       paste0("--scratch=", S, "/oracle/final_faults"), paste0("--evidence=", file.path(here, "faults")))
  step("identity_final", file.path(fp, "identity.R"), paste0("--lib=", lib), paste0("--out=", S, "/identity_final"),
       paste0("--old=", S, "/identity_base"))
  step("identity_check", file.path(fp, "identity_check.R"), paste0("--base=", S, "/identity_base"),
       paste0("--candidate=", S, "/identity_final"))
  step("emitted_pin_final", file.path(fp, "emitted_pin.R"), paste0("--record=", S, "/identity_final"))
  step("counts_final", file.path(fp, "counts.R"), paste0("--lib=", lib), paste0("--out=", S, "/counts_final"))
  step("census_check", file.path(fp, "census.R"), paste0("--source=", repo), paste0("--out=", file.path(here, "census")),
       paste0("--census=", file.path(fp, "census.csv")))
  step("lines", file.path(fp, "lines.R"), paste0("--repo=", repo), "--base=ea580bc6", paste0("--final=", final),
       paste0("--out=", file.path(here, "lines.csv")))
  file.copy(file.path(S, "identity_final", "identities.csv"), file.path(here, "identity_final.csv"), overwrite = TRUE)
  cat("done\n")
})
