# LDG-3265 diagnostic probes (close review round 1, F2): reruns the three
# probes and writes their outputs beside this script. Libraries are installed
# from their commits (cut24-scratch/libs): final-8f7c6977 has R/ equal to the
# cut base 2dee0f98; ldg3265-ffe19415 the simplified candidate;
# ldg3265-b56eaee9 the exception candidate. pieces.R alternates base and
# candidate libraries twice per case.
#
#   Rscript dev/bench/v0_2_3_cut24_feature/probes_ldg3265/run_probes.R
local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  repo <- normalizePath(file.path(here, "..", "..", "..", ".."), winslash = "/")
  libs <- "C:/Users/maxth/ledgr-wt/cut24-scratch/libs"
  rscript <- file.path(R.home("bin"), "Rscript.exe")
  run <- function(out, script, ...) {
    lines <- system2(rscript, c(file.path(here, script), ...), stdout = TRUE, stderr = TRUE)
    cat(lines, sep = "\n", file = file.path(here, out), append = TRUE)
    cat(lines, sep = "\n")
  }
  for (f in c("pieces.txt", "zero_components.txt", "swap.txt")) unlink(file.path(here, f))
  host <- c(paste("date", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
            paste("R", R.version.string), paste("platform", R.version$platform),
            paste("power plan", paste(system2("powercfg", "/getactivescheme", stdout = TRUE), collapse = " ")))
  cat(host, sep = "\n", file = file.path(here, "host.txt"))
  for (case in c("zero", "custom")) for (k in 1:2) for (l in c("final-8f7c6977", "ldg3265-ffe19415", "ldg3265-b56eaee9")) {
    run("pieces.txt", "pieces.R", paste0("--lib=", libs, "/", l), paste0("--case=", case), paste0("--repo=", repo))
  }
  run("zero_components.txt", "zero_components.R", paste0("--lib=", libs, "/ldg3265-ffe19415"), paste0("--repo=", repo))
  run("swap.txt", "swap.R", paste0("--lib=", libs, "/ldg3265-ffe19415"), paste0("--repo=", repo))
})
