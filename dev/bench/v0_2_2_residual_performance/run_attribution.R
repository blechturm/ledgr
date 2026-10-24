# Sample one registered one- or two-worker H1 attribution arm.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 10L) {
  stop(
    paste(
      "Usage: run_attribution.R <ledgr_src> <library_dir> <load_mode>",
      "<snapshot> <snapshot_hash> <private_work_dir> <out_dir>",
      "<tag> <workers> <product_commit>"
    ),
    call. = FALSE
  )
}
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
here <- dirname(normalizePath(sub("^--file=", "", script_arg[[1L]])))
worker_script <- file.path(here, "attribution_h1.R")
out_dir <- normalizePath(args[[7L]], winslash = "/", mustWork = FALSE)
dir.create(file.path(out_dir, "samples"), recursive = TRUE, showWarnings = FALSE)
tag <- args[[8L]]

self <- Sys.getpid()
parent <- tryCatch(ps::ps_ppid(ps::ps_handle()), error = function(e) NA_integer_)
r_names <- c("r.exe", "rterm.exe", "rscript.exe", "rsession.exe")
ppid_of <- new.env(parent = emptyenv())
name_of <- new.env(parent = emptyenv())
handle_of <- new.env(parent = emptyenv())
previous_pids <- character()
refresh_pids <- function() {
  pids <- as.character(ps::ps_pids())
  fresh <- setdiff(pids, previous_pids)
  for (pid in fresh) {
    handle <- tryCatch(ps::ps_handle(as.integer(pid)), error = function(e) NULL)
    if (is.null(handle)) next
    assign(pid, handle, envir = handle_of)
    assign(
      pid,
      tryCatch(as.character(ps::ps_ppid(handle)), error = function(e) NA_character_),
      envir = ppid_of
    )
    assign(
      pid,
      tolower(tryCatch(ps::ps_name(handle), error = function(e) "unknown")),
      envir = name_of
    )
  }
  previous_pids <<- pids
  pids
}
descendants <- function(root, alive) {
  out <- character()
  frontier <- as.character(root)
  ppids <- vapply(
    alive,
    function(pid) get0(pid, envir = ppid_of, ifnotfound = NA_character_),
    ""
  )
  repeat {
    children <- setdiff(alive[!is.na(ppids) & ppids %in% frontier], c(out, root))
    if (!length(children)) break
    out <- c(out, children)
    frontier <- children
  }
  out
}
initial <- refresh_pids()
initial_names <- vapply(
  initial,
  function(pid) get0(pid, envir = name_of, ifnotfound = ""),
  ""
)
foreign <- initial[initial_names %in% r_names & !initial %in% as.character(c(self, parent))]
if (length(foreign)) stop("Foreign R processes are active; retry on a quiet host.", call. = FALSE)
affinity <- system2(
  "powershell",
  c("-NoProfile", "-Command", shQuote(sprintf(
    "$p = Get-Process -Id %d; $p.ProcessorAffinity = 0xFFFF; [string]$p.ProcessorAffinity",
    self
  ), type = "cmd")),
  stdout = TRUE,
  stderr = TRUE
)
power <- system2("powercfg", "/getactivescheme", stdout = TRUE, stderr = TRUE)
log_path <- file.path(out_dir, paste0(tag, ".log"))
started_utc <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
started <- as.numeric(Sys.time())
process <- processx::process$new(
  file.path(R.home("bin"), "Rscript.exe"),
  c(worker_script, args),
  stdout = log_path,
  stderr = "2>&1",
  cleanup_tree = TRUE
)
root_pid <- process$get_pid()
rows <- list()
sample_id <- 0L
repeat {
  sample_started <- as.numeric(Sys.time())
  alive <- refresh_pids()
  tree <- c(as.character(root_pid), descendants(root_pid, alive))
  sample_id <- sample_id + 1L
  for (pid in tree) {
    handle <- get0(pid, envir = handle_of)
    if (is.null(handle)) next
    mem <- tryCatch(ps::ps_memory_info(handle), error = function(e) NULL)
    if (is.null(mem)) next
    name <- get0(pid, envir = name_of, ifnotfound = "unknown")
    is_parent <- identical(pid, as.character(root_pid))
    role <- if (is_parent) "parent" else if (name %in% r_names) "daemon" else "child"
    rows[[length(rows) + 1L]] <- data.frame(
      tag = tag,
      sample_id = sample_id,
      epoch = as.numeric(Sys.time()),
      pid = pid,
      is_parent = is_parent,
      role = role,
      process_name = name,
      wset_bytes = mem[["wset"]],
      private_bytes = mem[["mem_private"]],
      stringsAsFactors = FALSE
    )
  }
  if (!process$is_alive()) break
  Sys.sleep(max(0, 0.2 - (as.numeric(Sys.time()) - sample_started)))
}
ended <- as.numeric(Sys.time())
status <- process$get_exit_status()
samples <- do.call(rbind, rows)
utils::write.csv(
  samples,
  gzfile(file.path(out_dir, "samples", paste0(tag, ".csv.gz"))),
  row.names = FALSE
)
parent_rows <- samples[samples$is_parent, , drop = FALSE]
r_rows <- samples[samples$role %in% c("parent", "daemon"), , drop = FALSE]
tree_private <- tapply(r_rows$private_bytes, r_rows$sample_id, sum)
tree_wset <- tapply(r_rows$wset_bytes, r_rows$sample_id, sum)
summary <- data.frame(
  tag = tag,
  exit_status = status,
  elapsed_s = ended - started,
  samples = sample_id,
  effective_sample_interval_s = (ended - started) / sample_id,
  parent_peak_wset_mib = max(parent_rows$wset_bytes) / 2^20,
  parent_peak_private_mib = max(parent_rows$private_bytes) / 2^20,
  parent_plus_daemon_peak_private_mib = max(tree_private) / 2^20,
  parent_plus_daemon_peak_wset_mib = max(tree_wset) / 2^20,
  daemons_seen = length(unique(r_rows$pid[!r_rows$is_parent])),
  os_peak_parent_wset_mib = max(parent_rows$wset_bytes) / 2^20,
  os_peak_parent_private_mib = max(parent_rows$private_bytes) / 2^20,
  quiet_wait_s = 0,
  other_r_at_start = length(foreign),
  other_r_process_checks = sample_id,
  checks_with_other_r_processes = 0,
  max_other_r_processes = 0,
  other_r_cpu_s_during_step = 0,
  affinity = paste(affinity, collapse = " "),
  power_plan = if (any(grepl("High performance", power, fixed = TRUE))) "High performance" else "other",
  started_utc = started_utc,
  stringsAsFactors = FALSE
)
path <- file.path(out_dir, "steps.csv")
prior <- if (file.exists(path)) utils::read.csv(path, stringsAsFactors = FALSE) else NULL
if (!is.null(prior)) prior <- prior[prior$tag != tag, , drop = FALSE]
utils::write.csv(rbind(prior, summary), path, row.names = FALSE)
if (!identical(as.integer(status), 0L)) {
  stop("Attribution arm failed; see ", log_path, call. = FALSE)
}
cat("WS53_ATTRIBUTION_SAMPLE_OK ", tag, "\n", sep = "")
