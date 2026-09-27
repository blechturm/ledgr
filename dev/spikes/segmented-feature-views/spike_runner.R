# Runnable fork for the late-known barrier revision seam, scenario driven.
#
# Spike protocol section 3. Step one built one fork and ran it; this is step two,
# pushing it at edges so its behaviour generates the cases. Expected answers are
# frozen only in the committed evidence CSV, never pre-authored here.
#
# Charter: dev/spikes/segmented-feature-views/charter.md
# Question: does a late-known carry barrier revise an earlier finite-window
# feature value and its evidence, while a previously returned result stays
# unchanged?
#
# The fixture and the candidate live in spike_core.R, shared with the ablation.
#
#   Rscript dev/spikes/segmented-feature-views/spike_runner.R

suppressMessages(pkgload::load_all(".", quiet = TRUE, export_all = TRUE))

OUT <- "dev/spikes/segmented-feature-views"
source(file.path(OUT, "spike_core.R"))

rows <- list()
record <- function(case, key, value, unit, how) {
  rows[[length(rows) + 1L]] <<- data.frame(
    case = case, key = key, value = as.character(value), unit = unit,
    derived_from = how, stringsAsFactors = FALSE
  )
}

# ------------------------------------------------------------------- cases
run_case <- function(name, subject_i = 4L, from_i = 6L, to_i = 8L, known_i = 18L,
                     age = 5L, width = 3L, drop_bars = integer(), seed = 11L) {
  inputs <- base_inputs(seed)
  subject <- inputs$instruments$instrument_id[[subject_i]]
  sealed <- seal_with_barrier(inputs, subject, from_i, to_i, known_i, drop_bars)
  on.exit({ ledgr_snapshot_close(sealed$snapshot); unlink(sealed$db) }, add = TRUE)
  v <- views(sealed, subject, age, width)
  before <- v$feature(v$prepare(sealed$known_at - 1))
  after <- v$feature(v$prepare(sealed$known_at))
  d <- revised(before, after)
  record(name, "revised_cells", length(d), "count", "difference between views")
  record(name, "carried_before", sum(!is.na(v$prepare(sealed$known_at - 1)$carried)),
         "count", "candidate carry at the earlier cutoff")
  record(name, "carried_after", sum(!is.na(v$prepare(sealed$known_at)$carried)),
         "count", "candidate carry at the later cutoff")
  record(name, "stable_on_recompute",
         identical(v$feature(v$prepare(sealed$known_at - 1)), before), "logical",
         "two preparations at the same cutoff")
  # Section 4.4: an observation inside an accepted inactive interval stays
  # admissible. Check the prepared close at an observed in-barrier session.
  pa <- v$prepare(sealed$known_at)
  inside <- which(pa$barrier & v$observed)
  if (length(inside) > 0L) {
    record(name, "observed_inside_barrier_retained",
           !is.na(pa$close[[inside[[1L]]]]), "logical",
           "prepared close at an observed session inside the barrier")
  }
  if (length(d) > 0L) {
    record(name, "first_revised_index", d[[1L]], "index", "first differing cell")
    record(name, "last_revised_index", d[[length(d)]], "index", "last differing cell")
    # Locality: section 6.1 bounds the affected range at [a, b + age + width - 1].
    lo <- from_i
    hi <- to_i + age + width - 1L
    record(name, "revisions_inside_bound",
           all(d >= lo & d <= hi), "logical",
           sprintf("all revised indices within [%d, %d]", lo, hi))
  }
  invisible(NULL)
}

run_case("A_gap_inside_barrier")                                    # the seam
run_case("B_no_gap_inside_barrier", drop_bars = integer(), from_i = 12L, to_i = 14L)
run_case("C_gap_before_barrier", drop_bars = 3L, from_i = 12L, to_i = 14L)
run_case("D_strict_policy_no_carry", age = 0L)
run_case("E_age_refuses_before_barrier", drop_bars = c(10L, 11L), from_i = 14L,
         to_i = 16L, known_i = 20L, age = 1L)
run_case("F_width_five", width = 5L)
run_case("G_barrier_late_in_axis", from_i = 15L, to_i = 17L, known_i = 20L)
run_case("H_wide_barrier", from_i = 5L, to_i = 12L)

evidence <- do.call(rbind, rows)
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(evidence, file.path(OUT, "spike_evidence.csv"), row.names = FALSE)
print(evidence, right = FALSE, max = 400)
