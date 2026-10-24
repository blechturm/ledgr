# Sample one 4- or 8-worker H1 sweep process and all R descendants.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 7L) {
  stop(
    paste(
      "Usage: run_worker_scaling.R <ledgr_src> <snapshot> <snapshot_hash>",
      "<private_work_dir> <out_dir> <tag> <workers>"
    ),
    call. = FALSE
  )
}
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
here <- dirname(normalizePath(sub("^--file=", "", script_arg[[1L]])))
worker_script <- file.path(here, "worker_scaling_h1.R")
out_dir <- normalizePath(args[[5L]], winslash = "/", mustWork = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
tag <- args[[6L]]
workers <- as.integer(args[[7L]])
if (!workers %in% c(2L, 4L, 8L)) stop("workers must be 2, 4 or 8.", call. = FALSE)

self <- Sys.getpid()
parent <- tryCatch(ps::ps_ppid(ps::ps_handle()), error = function(e) NA_integer_)
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
    assign(pid, tryCatch(as.character(ps::ps_ppid(handle)), error = function(e) NA_character_), envir = ppid_of)
    assign(pid, tolower(tryCatch(ps::ps_name(handle), error = function(e) "unknown")), envir = name_of)
  }
  previous_pids <<- pids
  pids
}
descendants <- function(root, alive) {
  out <- character()
  frontier <- root
  ppids <- vapply(alive, function(pid) get0(pid, envir = ppid_of, ifnotfound = NA_character_), "")
  repeat {
    children <- setdiff(alive[!is.na(ppids) & ppids %in% frontier], c(out, root))
    if (!length(children)) break
    out <- c(out, children)
    frontier <- children
  }
  out
}
r_names <- c("r.exe", "rterm.exe", "rscript.exe", "rsession.exe")
foreign_r <- function(exclude, alive = refresh_pids()) {
  names <- vapply(alive, function(pid) get0(pid, envir = name_of, ifnotfound = ""), "")
  alive[names %in% r_names & !alive %in% as.character(exclude)]
}
other_at_start <- foreign_r(c(self, parent))
if (length(other_at_start)) {
  stop("Foreign R processes are active; retry on a quiet host.", call. = FALSE)
}
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
process <- processx::process$new(
  file.path(R.home("bin"), "Rscript.exe"),
  c(worker_script, args),
  stdout = log_path,
  stderr = "2>&1",
  cleanup_tree = TRUE
)
root_pid <- as.character(process$get_pid())
started <- as.numeric(Sys.time())
rows <- vector("list", 2000L)
n <- 0L
sample_id <- 0L
repeat {
  sample_started <- as.numeric(Sys.time())
  alive <- refresh_pids()
  tree <- c(root_pid, descendants(root_pid, alive))
  sample_id <- sample_id + 1L
  for (pid in tree) {
    handle <- get0(pid, envir = handle_of)
    if (is.null(handle)) next
    mem <- tryCatch(ps::ps_memory_info(handle), error = function(e) NULL)
    if (is.null(mem)) next
    n <- n + 1L
    if (n > length(rows)) length(rows) <- length(rows) * 2L
    rows[[n]] <- data.frame(
      tag = tag,
      sample_id = sample_id,
      epoch = as.numeric(Sys.time()),
      pid = pid,
      is_parent = identical(pid, root_pid),
      process_name = get0(pid, envir = name_of, ifnotfound = "unknown"),
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
samples <- if (n) do.call(rbind, rows[seq_len(n)]) else data.frame()
if (!nrow(samples)) stop("No process samples were captured.", call. = FALSE)
utils::write.csv(
  samples,
  gzfile(file.path(out_dir, paste0(tag, "_samples.csv.gz"))),
  row.names = FALSE
)
parent_rows <- samples[samples$is_parent, , drop = FALSE]
r_tree <- samples[samples$is_parent | samples$process_name %in% r_names, , drop = FALSE]
tree_private <- tapply(r_tree$private_bytes, r_tree$sample_id, sum)
tree_wset <- tapply(r_tree$wset_bytes, r_tree$sample_id, sum)
daemon_ids <- unique(samples$pid[!samples$is_parent & samples$process_name %in%
  c("r.exe", "rterm.exe", "rscript.exe")])
summary <- data.frame(
  tag = tag,
  workers = workers,
  exit_status = status,
  elapsed_s = ended - started,
  samples = sample_id,
  effective_interval_s = (ended - started) / sample_id,
  parent_peak_wset_mib = max(parent_rows$wset_bytes) / 2^20,
  parent_peak_private_mib = max(parent_rows$private_bytes) / 2^20,
  parent_plus_daemon_peak_wset_mib = max(tree_wset) / 2^20,
  parent_plus_daemon_peak_private_mib = max(tree_private) / 2^20,
  daemons_seen = length(daemon_ids),
  other_r_at_start = length(other_at_start),
  affinity = paste(affinity, collapse = " "),
  power_plan = if (any(grepl("High performance", power, fixed = TRUE))) {
    "High performance"
  } else {
    "other"
  },
  stringsAsFactors = FALSE
)
path <- file.path(out_dir, "worker_scaling.csv")
prior <- if (file.exists(path)) utils::read.csv(path, stringsAsFactors = FALSE) else NULL
if (!is.null(prior)) prior <- prior[prior$tag != tag, , drop = FALSE]
utils::write.csv(rbind(prior, summary), path, row.names = FALSE)
if (!identical(as.integer(status), 0L)) {
  stop("Worker arm failed; see ", log_path, call. = FALSE)
}
cat("WS53_WORKER_SCALE_OK ", tag, "\n", sep = "")
