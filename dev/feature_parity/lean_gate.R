# Runs the lean parity gate (dev/lean_core/parity/loop_parity.R) with this
# cut's feature-path code (Cut 22, LDG-3255). The lean core loads only the
# pinned build d5b3a151 and refuses any other, so the gate's two arms (the
# package run and the lean loop) normally read features through the pin's
# code. This wrapper registers a load hook that, as soon as ledgr is loaded,
# replaces the namespace's definitions from the R/ files that differ between
# --base and --tree (evaluated with the namespace as their environment), and
# then runs loop_parity.R unchanged with the remaining arguments. Both arms
# then prepare features with the candidate's code; nothing under dev/lean_core
# is edited. The replaced names are written to --overlay-log.
#
#   Rscript lean_gate.R --tree=<worktree> --base=<commit> --overlay-log=<file> <loop_parity.R arguments>
local({
  argv <- commandArgs(TRUE)
  take <- function(name) {
    hit <- grep(paste0("^--", name, "="), argv, value = TRUE)
    if (!length(hit)) stop("--", name, "= is required", call. = FALSE)
    sub(paste0("^--", name, "="), "", hit[[1L]])
  }
  tree <- normalizePath(take("tree"), winslash = "/")
  base <- take("base")
  overlay_log <- take("overlay-log")
  rest <- argv[!grepl("^--(tree|base|overlay-log)=", argv)]
  files <- system2("git", c("-C", shQuote(tree), "diff", "--name-only", base, "HEAD", "--", "R"), stdout = TRUE)
  status <- system2("git", c("-C", shQuote(tree), "status", "--porcelain", "--", "R"), stdout = TRUE)
  status <- status[!grepl("cpp11[.]R$", status)]
  if (length(status)) stop("lean_gate.R: uncommitted R/ changes in ", tree, ": ", paste(status, collapse = "; "))
  files <- file.path(tree, files[grepl("[.]R$", files)])
  head <- system2("git", c("-C", shQuote(tree), "rev-parse", "HEAD"), stdout = TRUE)
  overlay <- function(...) {
    ns <- asNamespace("ledgr")
    replaced <- character()
    for (f in files) {
      exprs <- parse(f, keep.source = FALSE)
      tmp <- new.env(parent = ns)
      for (e in exprs) eval(e, tmp)
      for (name in ls(tmp, all.names = TRUE)) {
        value <- get(name, envir = tmp)
        if (is.function(value)) environment(value) <- ns
        if (exists(name, envir = ns, inherits = FALSE)) {
          unlockBinding(name, ns)
          assign(name, value, envir = ns)
          lockBinding(name, ns)
          replaced <- c(replaced, paste0(basename(f), ":", name))
        } else {
          # A sealed namespace takes no new names; a namespace function's
          # lookup reaches the global environment after base, so a name new
          # in the candidate is defined there.
          assign(name, value, envir = globalenv())
          replaced <- c(replaced, paste0(basename(f), ":", name, " (new, global)"))
        }
      }
    }
    # The overlaid engine version must equal the candidate's installed one.
    writeLines(c(paste("tree", tree, "HEAD", head, "base", base),
                 paste("engine version after overlay", get("ledgr_feature_engine_version", envir = ns)()),
                 replaced), overlay_log)
  }
  setHook(packageEvent("ledgr", "onLoad"), overlay)
  parity <- normalizePath(file.path(tree, "dev", "lean_core", "parity", "loop_parity.R"), winslash = "/")
  assign("commandArgs", function(trailingOnly = FALSE) {
    if (trailingOnly) rest else c(base::commandArgs(FALSE)[1L], paste0("--file=", parity), "--args", rest)
  }, envir = globalenv())
  sys.source(parity, envir = globalenv(), keep.source = FALSE)
})
