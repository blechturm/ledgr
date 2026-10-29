# Shared timing harness (LDG-3155): host checks.
#
# One PowerShell call (host.ps1) returns the power plan, CPU load and process
# table; the functions below read it. Processes are identified by PID plus
# creation time, "pid@created" (Unix ms), so a reused PID is never mistaken
# for its predecessor. The host rules are in the benchmark manual.

timing_plan_guid <- "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" # High performance
timing_affinity <- 65535 # 0xFFFF: performance cores, logical processors 0-15

# Executable names counted as R sessions; an annotation only, never a
# rejection reason. ark.exe is Positron's R kernel.
timing_r_names <- c("r.exe", "rscript.exe", "rterm.exe", "rgui.exe", "rsession.exe",
  "rsession-utf8.exe", "ark.exe")

# One host snapshot: plan GUID, CPU load (a noise observation, never a
# rejection rule), CPU name and the process table.
timing_host_probe <- function(harness_dir) {
  out <- suppressWarnings(system2("powershell",
    c("-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File",
      shQuote(file.path(harness_dir, "host.ps1"))), stdout = TRUE, stderr = FALSE))
  timing_parse_probe(out, at = as.double(Sys.time()))
}

# Reads host.ps1 output. A process's affinity and CPU time are kept only
# when the Get-Process object that reported them has the CIM creation time
# listed under that PID; otherwise (a reused PID, or a process that could not
# be opened) they are NA. An NA affinity fails every affinity check.
timing_parse_probe <- function(out, at) {
  host <- strsplit(grep("^host,", out, value = TRUE)[1L], ",", fixed = TRUE)[[1L]]
  proc_lines <- sub("^proc,", "", grep("^proc,", out, value = TRUE))
  procs <- utils::read.csv(text = proc_lines, header = FALSE, stringsAsFactors = FALSE,
    col.names = c("pid", "ppid", "created", "affinity", "affinity_created", "cpu_ms", "name"),
    colClasses = c("numeric", "numeric", "numeric", "numeric", "numeric", "numeric", "character"))
  same_process <- procs$affinity >= 0 & procs$affinity_created == procs$created
  procs$affinity[!same_process] <- NA_real_
  procs$cpu_ms[!same_process | procs$cpu_ms < 0] <- NA_real_
  list(
    at = at,
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
# "name:pid@created" joined by ";" (an annotation of who was present).
timing_foreign_r <- function(procs, chain) {
  own <- timing_parse_chain(chain)$id
  r <- procs[tolower(procs$name) %in% timing_r_names, , drop = FALSE]
  ids <- sprintf("%.0f@%.0f", r$pid, r$created)
  foreign <- !(ids %in% own)
  paste(sprintf("%s:%s", r$name[foreign], ids[foreign]), collapse = ";")
}

# CPU time used between two snapshots by every process present in both
# (matched by PID plus creation time), except the probing chain `own` and
# the System Idle Process. Processes whose CPU time is unreadable are counted,
# not judged; processes that start and exit between the snapshots are not
# seen. Returns the largest increase (ms), the top five as
# "name:pid@created=+ms" and the unreadable count.
timing_cpu_interval <- function(prev, cur, own) {
  id <- function(p) sprintf("%.0f@%.0f", p$pid, p$created)
  both <- merge(data.frame(id = id(prev), before = prev$cpu_ms),
    data.frame(id = id(cur), pid = cur$pid, name = cur$name, after = cur$cpu_ms), by = "id")
  both <- both[!both$id %in% own & both$pid != 0, , drop = FALSE]
  both$used <- both$after - both$before
  seen <- both[!is.na(both$used), , drop = FALSE]
  seen <- utils::head(seen[order(-seen$used), , drop = FALSE], 5L)
  list(max_ms = if (nrow(seen)) max(seen$used[[1L]], 0) else 0, unreadable = sum(is.na(both$used)),
    top = paste(sprintf("%s:%s=+%.0f", seen$name, seen$id, seen$used), collapse = ";"))
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

# The host problems seen by one probe of the root (the runner): the power
# plan and the root's own affinity. Returns a named character vector (empty
# when the host is fine). Background activity is recorded, never judged.
timing_root_problems <- function(probe, root_pid) {
  root <- timing_parse_chain(timing_chain(probe$procs, root_pid))[1L, , drop = FALSE]
  problems <- character()
  if (!identical(probe$plan_guid, timing_plan_guid)) problems[["power plan"]] <- probe$plan_guid
  if (!isTRUE(root$affinity == timing_affinity)) problems[["affinity"]] <- sprintf("root %s", root$id)
  problems
}
