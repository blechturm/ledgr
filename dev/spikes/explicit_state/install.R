# Installs the explicit-state fork in a lean environment and in every sweep
# worker the harness starts. Sourced into the lean environment by
# loop_parity.R --witness= through one of the three one-line files beside
# it (install_commit.R, install_all.R, install_gut.R), which set `es_set`
# and `es_gut` first. Workers get the same fork through the harness's
# worker-edits channel (loop_workers.R: the worker sources edits_file and
# calls lean_load_edited(); worker_hook.R defines that call) and each leaves
# a marker file, so the runner can count forked workers.
es_dir <- normalizePath(file.path(.lean_home, "..", "spikes", "explicit_state"), winslash = "/")
sys.source(file.path(es_dir, "transform.R"), envir = environment(), keep.source = FALSE)
es_install(environment(), es_set, es_gut)
es_mark_dir <- Sys.getenv("ES_WORKER_MARKS", "")
lean_workers$edits <- list(list(file = "explicit_state", set = es_set, gut = es_gut, dir = es_dir, marks = es_mark_dir))
lean_workers$edits_file <- file.path(es_dir, "worker_hook.R")
cat(sprintf("explicit-state fork installed: set %s%s; %d reads, %d writes, %d envelope assignments rewritten; findings: %s\n",
            es_set, if (is.null(es_gut)) "" else paste0(" (GUT: ", es_gut$fn, " ", es_gut$name, " left as <<-)"),
            es_installed$reads, es_installed$writes, es_installed$top_assignments,
            if (length(es_installed$findings)) paste(es_installed$findings, collapse = " | ") else "none"))
