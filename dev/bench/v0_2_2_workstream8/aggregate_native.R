args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(args[[1L]], winslash = "/")

timing <- list()
parity <- list()
for (feature in c("sma", "returns")) {
  for (workflow in c("run", "sweep")) {
    reference <- NULL
    for (rep in seq_len(3L)) {
      order <- if (rep %% 2L) c("baseline", "candidate") else {
        c("candidate", "baseline")
      }
      for (position in seq_along(order)) {
        arm <- order[[position]]
        directory <- file.path(
          root,
          sprintf("%s-%s-rep%d-%s", feature, workflow, rep, arm)
        )
        row <- utils::read.csv(file.path(directory, "native.csv"))
        row$rep <- rep
        row$position <- position
        row$arm <- arm
        timing[[length(timing) + 1L]] <- row[
          c(
            "feature", "workflow", "rep", "position", "arm", "elapsed_s",
            "gc_s", "other_r_processes"
          )
        ]
        value <- readRDS(file.path(directory, "semantic.rds"))
        if (identical(arm, "baseline") && is.null(reference)) reference <- value
        parity[[length(parity) + 1L]] <- data.frame(
          feature = feature,
          workflow = workflow,
          rep = rep,
          arm = arm,
          identical = if (identical(arm, "baseline")) {
            identical(value, reference)
          } else {
            identical(value, reference)
          }
        )
      }
    }
  }
}
timing <- do.call(rbind, timing)
parity <- do.call(rbind, parity)
groups <- interaction(timing$feature, timing$workflow, drop = TRUE)
summary <- do.call(rbind, lapply(split(timing, groups), function(x) {
  baseline <- stats::median(x$elapsed_s[x$arm == "baseline"])
  candidate <- stats::median(x$elapsed_s[x$arm == "candidate"])
  data.frame(
    feature = x$feature[[1L]],
    workflow = x$workflow[[1L]],
    baseline_median_s = baseline,
    candidate_median_s = candidate,
    gain_fraction = (baseline - candidate) / baseline
  )
}))

micro <- merge(
  utils::read.csv(file.path(root, "micro-baseline.csv")),
  utils::read.csv(file.path(root, "micro-candidate.csv")),
  by = "feature",
  suffixes = c("_baseline", "_candidate")
)
micro$speedup <- micro$median_s_baseline / micro$median_s_candidate
micro$identical <- vapply(micro$feature, function(feature) {
  identical(
    readRDS(file.path(root, paste0(feature, "-baseline.rds"))),
    readRDS(file.path(root, paste0(feature, "-candidate.rds")))
  )
}, logical(1))

gates <- do.call(rbind, lapply(c("sma", "returns"), function(feature) {
  run <- summary[summary$feature == feature & summary$workflow == "run", ]
  direct <- micro[micro$feature == feature, ]
  data.frame(
    feature = feature,
    internal_gate = direct$speedup > 10,
    public_run_gate = run$gain_fraction > 0.05,
    outcome = if (direct$speedup > 10 && run$gain_fraction > 0.05) {
      "eligible"
    } else {
      "rejected"
    }
  )
}))

utils::write.csv(timing, file.path(root, "timing.csv"), row.names = FALSE)
utils::write.csv(summary, file.path(root, "timing_summary.csv"), row.names = FALSE)
utils::write.csv(parity, file.path(root, "parity.csv"), row.names = FALSE)
utils::write.csv(micro, file.path(root, "internal.csv"), row.names = FALSE)
utils::write.csv(gates, file.path(root, "gates.csv"), row.names = FALSE)
utils::write.csv(data.frame(
  key = c(
    "r_version", "collapse", "duckdb", "baseline_commit", "candidate_tree",
    "instruments", "pulses", "internal_gate", "public_run_gate"
  ),
  value = c(
    R.version.string,
    as.character(utils::packageVersion("collapse")),
    as.character(utils::packageVersion("duckdb")),
    "dcb31309c8b95dfd33d3ede5712105d2421bb5fb",
    "detached source fork of dcb3130; exact LDG-2941 candidate",
    "50", "500", "10x", "5%"
  )
), file.path(root, "environment.csv"), row.names = FALSE)
stopifnot(
  nrow(timing) == 24L,
  all(timing$other_r_processes == 0L),
  all(parity$identical),
  all(micro$identical)
)
print(summary, row.names = FALSE)
print(micro, row.names = FALSE)
print(gates, row.names = FALSE)
