# LDG-3211 field probe: which `services` fields and fold-state slots each
# fold stage really reads or writes, including through helpers, at the pin.
#
#   Rscript field_probe.R --pkg=<ledgr source at d5b3a151> --out=<dir>
#
# Each stage is wrapped so that its `services` list becomes a logging list
# (S3 `$` and `[[`) and its `fold_state` a pass-through environment of active
# bindings. Every access is recorded with the stage active at that moment and
# the innermost ledgr function on the stack, so a field reached only through
# a helper is listed with that helper. The static list in
# ../v0_2_3_ws16_entry/evidence/stage_fields_static.csv misses those.

local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
  entry <- file.path(here, "..", "v0_2_3_ws16_entry")
  source(file.path(entry, "common.R"))
  source(file.path(entry, "workloads.R"))
  assign("ws16_entry_dir", entry, envir = globalenv())
})
# The JIT is off so that byte-compiling a closure does not change its hash
# in the mutability check below.
compiler::enableJIT(0L)
pkg <- normalizePath(ws16_need("pkg"), winslash = "/")
out <- ws16_out(ws16_need("out"))
commit <- ws16_load_source(pkg)
if (!identical(commit, "d5b3a151")) stop("source tree is not the d5b3a151 pin", call. = FALSE)
ns <- asNamespace("ledgr")

stages <- c(
  P1 = "ledgr_fold_stage_observe_settle", P2 = "ledgr_fold_stage_decide",
  P3 = "ledgr_fold_stage_plan", P4 = "ledgr_fold_stage_apply",
  P5 = "ledgr_fold_stage_commit", P2_skip = "ledgr_fold_scheduled_skip_decision",
  P3_skip = "ledgr_fold_scheduled_skip_plan", E_stop = "ledgr_fold_apply_stop",
  E_flush = "ledgr_fold_flush_pulse_block"
)

rec <- new.env()
rec$workload <- NA_character_
rec$stage <- "E"
rec$hits <- new.env()
log_access <- function(object, field, mode) {
  caller <- ws16_caller(skip = character())
  key <- paste(rec$workload, rec$stage, object, field, mode, caller, sep = "\t")
  rec$hits[[key]] <- (rec$hits[[key]] %||% 0) + 1
}

`$.ws16_services` <- function(x, name) {
  log_access("services", name, "read")
  .subset2(x, name)
}
`[[.ws16_services` <- function(x, i, ...) {
  log_access("services", as.character(i), "read")
  .subset2(x, i)
}
.S3method("$", "ws16_services", `$.ws16_services`)
.S3method("[[", "ws16_services", `[[.ws16_services`)

wrap_services <- function(s) {
  if (inherits(s, "ws16_services")) return(s)
  class(s) <- c("ws16_services", class(s))
  s
}
wrap_state <- function(real) {
  if (isTRUE(attr(real, "ws16_proxy"))) return(real)
  proxy <- new.env(parent = emptyenv())
  for (slot in ls(real, all.names = TRUE)) {
    local({
      s <- slot
      makeActiveBinding(s, function(v) {
        if (missing(v)) {
          log_access("fold_state", s, "read")
          get(s, envir = real, inherits = FALSE)
        } else {
          log_access("fold_state", s, "write")
          assign(s, v, envir = real)
        }
      }, proxy)
    })
  }
  attr(proxy, "ws16_proxy") <- TRUE
  lockEnvironment(proxy, bindings = FALSE)
  proxy
}

for (label in names(stages)) {
  local({
    lab <- label
    ws16_wrap(stages[[lab]], function(orig) {
      force(orig)
      function(...) {
        a <- list(...)
        if (!is.null(a$services)) {
          if (is.null(rec$fold_services)) {
            rec$fold_services <- a$services
            rec$fold_hash <- lapply(unclass(a$services), deep_hash)
          }
          a$services <- wrap_services(a$services)
        }
        state_at <- if (!is.null(a$fold_state)) "fold_state" else 1L
        if (is.environment(a[[state_at]])) a[[state_at]] <- wrap_state(a[[state_at]])
        prev <- rec$stage
        rec$stage <- lab
        on.exit(rec$stage <- prev)
        do.call(orig, a)
      }
    })
  })
}

# rlang::hash() hashes an environment by identity, so fields are hashed
# through their full serialization (environment contents included).
deep_hash <- function(v) rlang::hash(serialize(v, NULL))
# Mutability: each services field is hashed at the fold's first stage call
# and again when the fold returns; a changed hash marks a field the run
# writes (an environment, or a closure whose environment changes).
rec$mut <- list()
ws16_wrap("ledgr_fold_envelope", function(orig) {
  force(orig)
  function(execution, output_handler) {
    rec$fold_services <- NULL
    on.exit({
      s <- rec$fold_services
      if (!is.null(s)) {
        after <- lapply(unclass(s), deep_hash)
        rec$mut[[length(rec$mut) + 1L]] <- data.frame(
          workload = rec$workload, field = names(after),
          type = vapply(unclass(s), function(v) paste(class(v), collapse = "/"), character(1)),
          changed = !mapply(identical, rec$fold_hash[names(after)], after),
          stringsAsFactors = FALSE)
      }
    }, add = TRUE)
    orig(execution, output_handler)
  }
})

# A0 workloads, the portable momentum run (scheduled skips) and the
# fill-heavy run, as in the entry record.
source(file.path(ws16_entry_dir, "..", "v0_2_3_output_freeze", "lib.R"))
work <- file.path(tempdir(), "ws16_field_probe")
dir.create(work, showWarnings = FALSE)
status <- list()
for (id in names(a0_workloads)) {
  rec$workload <- id
  status[[id]] <- tryCatch({ a0_run_workload(id, work); "ok" },
                           error = function(e) paste("error:", conditionMessage(e)))
}
rec$workload <- "momentum_40x504"
snapshot <- ws16_momentum_snapshot(40L, 504L, file.path(work, "momentum.duckdb"), "ws16_momentum")
bt <- ledgr_run(ws16_momentum_experiment(snapshot, 63L), params = list(lookback = 63L, n = 10L),
                run_id = "ws16-momentum", seed = 1L)
close(bt)
ledgr_snapshot_close(snapshot)
status$momentum_40x504 <- "ok"
rec$workload <- "fill_heavy_500x1260"
snapshot <- ledgr_snapshot_from_df(ws16_fill_heavy_bars(), db_path = file.path(work, "fill.duckdb"),
                                   snapshot_id = "ws16_fill")
bt <- suppressWarnings(ledgr_run(ws16_fill_heavy_experiment(snapshot), run_id = "ws16-fill",
                                 seed = 20260530L))
close(bt)
ledgr_snapshot_close(snapshot)
status$fill_heavy_500x1260 <- "ok"

keys <- ls(rec$hits)
parts <- do.call(rbind, strsplit(keys, "\t", fixed = TRUE))
hits <- as.data.frame(parts, stringsAsFactors = FALSE)
names(hits) <- c("workload", "stage", "object", "field", "mode", "via")
hits$n <- vapply(keys, function(k) rec$hits[[k]], numeric(1), USE.NAMES = FALSE)
hits <- hits[do.call(order, hits[c("stage", "object", "field", "mode", "via", "workload")]), ]
ws16_write(hits, file.path(out, "field_reads_dynamic.csv"))
# One row per stage, object, field and mode: the union over workloads.
agg <- aggregate(n ~ stage + object + field + mode, data = hits, FUN = sum)
agg$via <- vapply(seq_len(nrow(agg)), function(i) {
  h <- hits[hits$stage == agg$stage[i] & hits$object == agg$object[i] &
              hits$field == agg$field[i] & hits$mode == agg$mode[i], "via"]
  paste(sort(unique(h)), collapse = " ")
}, character(1))
agg$workloads <- vapply(seq_len(nrow(agg)), function(i) {
  length(unique(hits$workload[hits$stage == agg$stage[i] & hits$object == agg$object[i] &
                                hits$field == agg$field[i] & hits$mode == agg$mode[i]]))
}, numeric(1))
agg <- agg[do.call(order, agg[c("stage", "object", "mode", "field")]), ]
ws16_write(agg, file.path(out, "field_reads_by_stage.csv"))
mut <- do.call(rbind, rec$mut)
mut <- do.call(rbind, lapply(split(mut, mut$field), function(d) data.frame(
  field = d$field[[1L]], type = d$type[[1L]], folds = nrow(d), changed_folds = sum(d$changed),
  workloads_changed = paste(sort(unique(d$workload[d$changed])), collapse = " "),
  stringsAsFactors = FALSE)))
ws16_write(mut[order(-mut$changed_folds, mut$field), ], file.path(out, "services_mutability.csv"))
ws16_write(data.frame(workload = names(status), status = unlist(status), row.names = NULL),
           file.path(out, "field_probe_workloads.csv"))
cat("field probe written to", out, "\n")
print(status)
