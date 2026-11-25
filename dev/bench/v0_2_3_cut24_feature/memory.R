# Cut 24 decision 3 (cut review 24, R1): peak R heap of the feature
# preparation, extending dev/feature_parity/memory.R's method (fresh
# children, gc maxima, an 8 MiB sensitivity check) to the cut's cells. Not
# the timing harness and not process memory.
#
# Cells: 500 x 1,260 and 1,166 x 252 (the bar-native Cut 22 fixture), run and
# sweep preparation sequences, Cut 22's SMA definition sets
# (protocols/cut24-feature-1/workloads.R supplies fixture, definitions and
# the preparation, so the phase is the timed preparation). In each fresh
# child: fixture and substrate built outside the phase; debug set
# explicitly; gc(reset = TRUE) immediately before the phase; one production
# preparation with its integrated projection, retained at the end; then
# max-used Ncells (x 56 bytes) and Vcells (x 8 bytes). `heap_extra` holds an
# extra live 8 MiB raw vector inside the phase.
# Per arm and cell: 8 heap children in alternating order (base first in odd
# pairs) and 2 heap_extra children.
#
# Statistic: median(candidate heap) - median(base heap) per cell.
# --aa (both arms one library): all 256 within-pair label exchanges of the
#   statistic; memory noise is the larger absolute endpoint of their central
#   95% interval (quantile type 7); written to memory_noise.csv.
# Every record: sensitivity holds when on each arm and cell the extra 8 MiB
#   raises the median peak by more than the noise (the record's own noise in
#   --aa, else --noise); otherwise the memory evidence is inconclusive.
# --noise=<memory_noise.csv>: the retention verdict per cell: the statistic is
#   no greater than the noise; memory_verdict.csv holds the cell verdicts and
#   the overall verdict (retain_ok, exceeds or inconclusive).
#
#   Rscript memory.R --base=<lib> --candidate=<lib> --work=<dir> --out=<dir> --debug=0 (--aa | --noise=<csv>)
#   Rscript memory.R --child --lib=<lib> --shape=<n x m> --path=<run|sweep> --measure=<heap|heap_extra> --debug=0 --work=<dir>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) {
    hit <- grep(paste0("^--", name, "(=|$)"), argv, value = TRUE)
    if (!length(hit)) return(NULL)
    if (!grepl("=", hit[[1L]], fixed = TRUE)) return(TRUE)
    sub(paste0("^--", name, "="), "", hit[[1L]])
  }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  workloads <- normalizePath(file.path(here, "..", "timing", "protocols", "cut24-feature-1", "workloads.R"),
                             winslash = "/")
  if (!arg("debug") %in% c("0", "1")) stop("memory.R: --debug=0 or --debug=1 is required")
  if (isTRUE(arg("child"))) {
    lib <- normalizePath(arg("lib"), winslash = "/")
    suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
    ns <- asNamespace("ledgr")
    wl <- new.env()
    sys.source(workloads, envir = wl)
    work <- arg("work")
    dir.create(work, recursive = TRUE, showWarnings = FALSE)
    phase <- function() {
      debug <- wl$cut24_debug(ns, list(debug = arg("debug")), environment())
      fx <- wl$cut24_bar_native(arg("shape"), work, ns)
      prepare <- wl$cut24_prepare(ns, arg("path"), fx$substrate, wl$cut24_sma_defs(ns, arg("path")))
      invisible(gc(reset = TRUE))
      extra <- if (identical(arg("measure"), "heap_extra")) raw(8L * 1024L * 1024L) else raw(0L)
      projection <- prepare()
      heap <- gc()
      stopifnot(inherits(projection, "ledgr_runtime_projection"), length(extra) >= 0L)
      ledgr::ledgr_snapshot_close(fx$snapshot)
      c(ncells = heap["Ncells", "max used"] * 56, vcells = heap["Vcells", "max used"] * 8,
        commit = 0, debug = as.numeric(debug))
    }
    v <- phase()
    marker <- file.path(lib, c("ledgr_arm_commit.txt", "timing_arm.txt"))
    commit <- readLines(marker[file.exists(marker)][[1L]], warn = FALSE)[[1L]]
    cat(sprintf("RESULT ncells=%.0f vcells=%.0f heap=%.0f debug=%s commit=%s\n", v[["ncells"]], v[["vcells"]],
                v[["ncells"]] + v[["vcells"]], arg("debug"), commit))
    return(invisible())
  }

  libs <- c(base = arg("base"), candidate = arg("candidate"))
  out <- arg("out")
  work <- arg("work")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  rscript <- file.path(R.home("bin"), "Rscript.exe")
  host <- tryCatch(paste(system2("powercfg", "/getactivescheme", stdout = TRUE), collapse = " "), error = function(e) NA)
  rows <- list()
  child <- function(arm, shape, path, measure, k) {
    wd <- file.path(work, paste(arm, shape, path, measure, k, sep = "_"))
    unlink(wd, recursive = TRUE)
    res <- system2(rscript, c(file.path(here, "memory.R"), "--child", paste0("--lib=", libs[[arm]]),
                              paste0("--shape=", shape), paste0("--path=", path), paste0("--measure=", measure),
                              paste0("--debug=", arg("debug")), paste0("--work=", wd)),
                   stdout = TRUE, stderr = FALSE)
    hit <- grep("^RESULT ", res, value = TRUE)
    if (!length(hit)) stop("memory.R child failed: ", arm, " ", shape, " ", path, " ", measure)
    kv <- strsplit(strsplit(sub("^RESULT ", "", hit), " ", fixed = TRUE)[[1L]], "=", fixed = TRUE)
    v <- stats::setNames(vapply(kv, `[[`, "", 2L), vapply(kv, `[[`, "", 1L))
    rows[[length(rows) + 1L]] <<- data.frame(arm = arm, lib = libs[[arm]], commit = v[["commit"]],
      shape = shape, path = path, measure = measure, pair = k, debug = v[["debug"]],
      ncells_bytes = as.numeric(v[["ncells"]]), vcells_bytes = as.numeric(v[["vcells"]]),
      heap_bytes = as.numeric(v[["heap"]]), host_plan = host, stringsAsFactors = FALSE)
    cat(arm, shape, path, measure, k, v[["heap"]], "\n")
  }
  cells <- expand.grid(path = c("run", "sweep"), shape = c("500x1260", "1166x252"), stringsAsFactors = FALSE)
  for (j in seq_len(nrow(cells))) {
    for (k in 1:8) {
      order <- if (k %% 2L == 1L) c("base", "candidate") else c("candidate", "base")
      for (arm in order) child(arm, cells$shape[[j]], cells$path[[j]], "heap", k)
    }
    for (k in 1:2) for (arm in c("base", "candidate")) child(arm, cells$shape[[j]], cells$path[[j]], "heap_extra", k)
  }
  raw <- do.call(rbind, rows)
  utils::write.csv(raw, file.path(out, "memory_raw.csv"), row.names = FALSE)

  stat <- function(base, cand) stats::median(cand) - stats::median(base)
  summary <- list(); ex <- list()
  for (j in seq_len(nrow(cells))) {
    sel <- raw$shape == cells$shape[[j]] & raw$path == cells$path[[j]]
    h <- raw[sel & raw$measure == "heap", ]
    b <- h[h$arm == "base", ][order(h$pair[h$arm == "base"]), ]
    k <- h[h$arm == "candidate", ][order(h$pair[h$arm == "candidate"]), ]
    cell <- paste(cells$shape[[j]], cells$path[[j]], sep = "_")
    swaps <- as.matrix(expand.grid(rep(list(c(FALSE, TRUE)), 8L)))
    values <- apply(swaps, 1L, function(s) stat(ifelse(s, k$heap_bytes, b$heap_bytes), ifelse(s, b$heap_bytes, k$heap_bytes)))
    q <- stats::quantile(values, c(0.025, 0.975), type = 7, names = FALSE)
    e <- raw[sel & raw$measure == "heap_extra", ]
    summary[[cell]] <- data.frame(cell = cell, median_base = stats::median(b$heap_bytes),
      median_candidate = stats::median(k$heap_bytes), statistic = stat(b$heap_bytes, k$heap_bytes),
      exchange_L = q[[1L]], exchange_U = q[[2L]], own_noise = max(abs(q)),
      extra_lift_base = stats::median(e$heap_bytes[e$arm == "base"]) - stats::median(b$heap_bytes),
      extra_lift_candidate = stats::median(e$heap_bytes[e$arm == "candidate"]) - stats::median(k$heap_bytes),
      stringsAsFactors = FALSE)
    ex[[cell]] <- data.frame(cell = cell, exchange = seq_along(values), statistic = values)
  }
  s <- do.call(rbind, summary)
  utils::write.csv(do.call(rbind, ex), file.path(out, "memory_exchanges.csv"), row.names = FALSE)
  if (isTRUE(arg("aa"))) {
    s$noise <- s$own_noise
    utils::write.csv(data.frame(cell = s$cell, noise_bytes = s$noise), file.path(out, "memory_noise.csv"), row.names = FALSE)
  } else {
    noise <- utils::read.csv(arg("noise"), stringsAsFactors = FALSE)
    s$noise <- noise$noise_bytes[match(s$cell, noise$cell)]
  }
  s$sensitive <- s$extra_lift_base > s$noise & s$extra_lift_candidate > s$noise
  s$verdict <- ifelse(!s$sensitive, "inconclusive", ifelse(s$statistic <= s$noise, "retain_ok", "exceeds"))
  overall <- if (any(s$verdict == "inconclusive")) "inconclusive" else if (all(s$verdict == "retain_ok")) "retain_ok" else "exceeds"
  s$overall <- overall
  utils::write.csv(s, file.path(out, "memory_verdict.csv"), row.names = FALSE)
  print(s, row.names = FALSE, digits = 6)
  cat("MEMORY", toupper(overall), "\n")
})
