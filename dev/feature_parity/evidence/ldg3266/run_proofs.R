# LDG-3266: the final-code proofs of workstream 44 on the dropped branch
# (stage 3 dropped by LDG-3265), run in order, each step one fresh Rscript
# whose output is kept in this folder. R/ at the final commit equals the
# workstream-43 close (2dee0f98), so the engine version is unchanged: the
# identity check runs in unchanged-engine mode against a record of the
# workstream-43 close library (final-8f7c6977, engine 88b4237e), taken here
# with its store (--save-store=1) so the old precompute's reuse is checked. The oracle pin and its
# repeat are LDG-3264's runs over the 694-case corpus. The library has no
# debug flag, so every run is --debug=0.
#
#   Rscript dev/feature_parity/evidence/ldg3266/run_proofs.R --final=<commit>
local({
  argv <- commandArgs(TRUE)
  final <- sub("^--final=", "", grep("^--final=", argv, value = TRUE)[[1L]])
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  repo <- normalizePath(file.path(here, "..", "..", "..", ".."), winslash = "/")
  fp <- file.path(repo, "dev", "feature_parity")
  S <- "C:/Users/maxth/ledgr-wt/cut24-scratch"
  pin <- file.path(S, "ldg3264", "pin")
  lib <- file.path(S, "libs", paste0("final-", final))
  out <- file.path(S, "ldg3266")
  dir.create(out, showWarnings = FALSE)
  rscript <- file.path(R.home("bin"), "Rscript.exe")
  step <- function(name, script, ...) {
    log <- file.path(here, paste0(name, ".txt"))
    cat(format(Sys.time(), "%H:%M:%S"), name, "\n")
    status <- system2(rscript, c(script, ...), stdout = log, stderr = log)
    cat("   exit", status, ":", tail(readLines(log, warn = FALSE), 1L), "\n")
    invisible(status)
  }
  if (!dir.exists(lib)) step("install_final", file.path(fp, "install_arm.R"), paste0("--repo=", repo),
                             paste0("--commit=", final), paste0("--lib=", lib))
  step("oracle_final", file.path(fp, "runner.R"), paste0("--arm=final_", final), paste0("--lib=", lib),
       paste0("--out=", out, "/final"), "--debug=0")
  step("check_pin_repeat", file.path(fp, "check.R"), paste0("--pin=", pin),
       paste0("--candidate=", S, "/ldg3264/pin_repeat"))
  step("check_final", file.path(fp, "check.R"), paste0("--pin=", pin), paste0("--candidate=", out, "/final"))
  step("faults", file.path(fp, "faults.R"), paste0("--lib=", lib), paste0("--pin=", pin),
       paste0("--scratch=", out, "/faults"), paste0("--evidence=", file.path(here, "faults")))
  step("identity_ws43", file.path(fp, "identity.R"), paste0("--lib=", S, "/libs/final-8f7c6977"),
       paste0("--out=", out, "/identity_ws43"), "--save-store=1", "--debug=0")
  step("identity_final", file.path(fp, "identity.R"), paste0("--lib=", lib), paste0("--out=", out, "/identity"),
       paste0("--old=", out, "/identity_ws43"), "--debug=0")
  step("identity_check", file.path(fp, "identity_check.R"), paste0("--base=", out, "/identity_ws43"),
       paste0("--candidate=", out, "/identity"), "--mode=unchanged-engine", "--engine-prefix=88b4237e")
  step("emitted_pin_final", file.path(fp, "emitted_pin.R"), paste0("--record=", out, "/identity"))
  step("counts_final", file.path(fp, "counts.R"), paste0("--lib=", lib), paste0("--out=", out, "/counts"))
  step("census_check", file.path(fp, "census.R"), paste0("--source=", repo), paste0("--out=", file.path(here, "census")),
       paste0("--census=", file.path(fp, "census.csv")))
  step("lines", file.path(fp, "lines.R"), paste0("--repo=", repo), "--base=2dee0f98", paste0("--final=", final),
       paste0("--out=", file.path(here, "lines.csv")))
  cat("done\n")
})
