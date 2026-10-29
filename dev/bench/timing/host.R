# Shared timing harness (LDG-3155): host checks.
#
# The registered timing host is the maintainer's i9-12900K: the High
# performance power plan, every timed process pinned to the performance cores
# (affinity 0xFFFF), and no R process other than the harness's own. One
# PowerShell call (host.ps1) returns the power plan, the CPU load and the
# process table; the functions below read it. The runner probes before the
# window, before every slot and after the window; each measured process
# probes itself once before its timed section.
#
# Processes are identified by PID plus creation time, written "pid@created"
# (creation time in Unix milliseconds), so a reused PID is never mistaken for
# the process it replaced.

timing_plan_guid <- "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" # High performance
timing_affinity <- 65535 # 0xFFFF: performance cores, logical processors 0-15

# Executable names counted as R sessions. ark.exe is Positron's R kernel.
timing_r_names <- c("r.exe", "rscript.exe", "rterm.exe", "rgui.exe", "rsession.exe",
  "rsession-utf8.exe", "ark.exe")

# One host snapshot: plan GUID, CPU load (a noise observation, never a
# rejection rule), CPU name and the process table.
timing_host_probe <- function(harness_dir) {
  out <- suppressWarnings(system2("powershell",
    c("-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File",
      shQuote(file.path(harness_dir, "host.ps1"))), stdout = TRUE, stderr = FALSE))
  host <- strsplit(grep("^host,", out, value = TRUE)[1L], ",", fixed = TRUE)[[1L]]
  proc_lines <- sub("^proc,", "", grep("^proc,", out, value = TRUE))
  procs <- utils::read.csv(text = proc_lines, header = FALSE, stringsAsFactors = FALSE,
    col.names = c("pid", "ppid", "created", "affinity", "name"),
    colClasses = c("numeric", "numeric", "numeric", "numeric", "character"))
  list(
    at = as.double(Sys.time()),
    plan_guid = if (length(host) >= 2L && nzchar(host[[2L]])) host[[2L]] else NA_character_,
    cpu_percent = if (length(host) >= 3L) suppressWarnings(as.numeric(host[[3L]])) else NA_real_,
    cpu_name = if (length(host) >= 4L) host[[4L]] else NA_character_,
    procs = procs
  )
}

# The ancestor chain of `pid`, nearest first, as "pid@created=affinity"
# entries joined by ";". A parent belongs to the chain only if it was created
# no later than its child; otherwise its PID was reused and the walk stops.
timing_chain <- function(procs, pid) {
  entries <- character()
  child_created <- Inf
  while (!is.na(pid) && pid > 0) {
    row <- procs[procs$pid == pid, , drop = FALSE]
    if (nrow(row) != 1L || row$created > child_created) break
    entry <- sprintf("%.0f@%.0f=%.0f", row$pid, row$created, row$affinity)
    if (entry %in% entries) break
    entries <- c(entries, entry)
    child_created <- row$created
    pid <- row$ppid
  }
  paste(entries, collapse = ";")
}

# Splits a chain into a data frame of id ("pid@created") and affinity.
timing_parse_chain <- function(chain) {
  if (is.na(chain) || !nzchar(chain)) return(data.frame(id = character(), affinity = numeric()))
  parts <- strsplit(strsplit(chain, ";", fixed = TRUE)[[1L]], "=", fixed = TRUE)
  data.frame(id = vapply(parts, `[`, "", 1L),
    affinity = suppressWarnings(as.numeric(vapply(parts, `[`, "", 2L))), stringsAsFactors = FALSE)
}

# R processes outside the probing process's own ancestor chain, as
# "name:pid@created" joined by ";" (empty when there are none).
timing_foreign_r <- function(procs, chain) {
  own <- timing_parse_chain(chain)$id
  r <- procs[tolower(procs$name) %in% timing_r_names, , drop = FALSE]
  ids <- sprintf("%.0f@%.0f", r$pid, r$created)
  foreign <- !(ids %in% own)
  paste(sprintf("%s:%s", r$name[foreign], ids[foreign]), collapse = ";")
}

# Checks one chain from the measured process up to and including the root
# ("pid@created"): the root must be on the chain, and every process from the
# measured one to the root must carry the registered affinity. Returns a
# problem string, or "" when the chain is fine.
timing_chain_problem <- function(chain, root_id) {
  entries <- timing_parse_chain(chain)
  at <- match(root_id, entries$id)
  if (is.na(at)) return(sprintf("chain %s does not reach the root %s", chain, root_id))
  bad <- entries[seq_len(at), , drop = FALSE]
  bad <- bad[is.na(bad$affinity) | bad$affinity != timing_affinity, , drop = FALSE]
  if (nrow(bad)) return(sprintf("affinity %s on %s", paste(bad$affinity, collapse = ","), paste(bad$id, collapse = ",")))
  ""
}

# The host problems seen by one probe of the root (the runner): power plan,
# the root's own affinity, and foreign R processes. Returns a named character
# vector (empty when the host is fine).
timing_root_problems <- function(probe, root_pid) {
  chain <- timing_chain(probe$procs, root_pid)
  root <- timing_parse_chain(chain)[1L, , drop = FALSE]
  problems <- character()
  if (!identical(probe$plan_guid, timing_plan_guid)) problems[["power plan"]] <- probe$plan_guid
  if (!isTRUE(root$affinity == timing_affinity)) problems[["affinity"]] <- sprintf("root %s", chain)
  foreign <- timing_foreign_r(probe$procs, chain)
  if (nzchar(foreign)) problems[["foreign R"]] <- foreign
  problems
}
