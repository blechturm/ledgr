# Candidate code for stage-1 candidates 2 and 3, as patched copies of the
# pinned namespace functions. Nothing under R/ is edited: use_arm() swaps
# namespace bindings in the running session only. Arms:
#   pin  the installed d5b3a151 functions (the oracle);
#   c2   narrow input treatment to the certified field union;
#   c3   TTR per-call overhead: resolve the TTR function once per definition,
#        pass the close vector directly, build a frame only on a raw miss;
#   c23  both.

ns <- asNamespace("ledgr")
pin_fns <- mget(c("ledgr_history_feature_inputs", "ledgr_history_feature_frame",
                  "ledgr_history_compute_feature_series", "ledgr_history_feature_causality",
                  "ledgr_history_feature_segment", "ledgr_ttr_raw_call", "ledgr_feature_certify"),
                envir = ns)

# ---- candidate 2 -----------------------------------------------------------

# The fields one compute call must treat: every bar field when any definition
# is custom (callbacks see the whole frame, F3); otherwise the union of the
# certified canonical definitions' required fields, which for catalogue rows
# are exactly the fields the constructor's code reads (TTR Adapter contract:
# "the mapped fields are the definition's required fields"; the built-ins
# read bars$close only).
c2_field_union <- function(certified) {
  all_fields <- c("open", "high", "low", "close", "volume")
  # Negative control (arm c2naive): narrow custom definitions to their
  # declared required fields too, the reading seed review F3 refuted.
  if (!naive && (!length(certified) ||
      any(vapply(certified, function(c) identical(c$certification, "custom"), TRUE)))) {
    return(all_fields)
  }
  used <- unique(unlist(lapply(certified, function(c) c$declarations$required_fields)))
  all_fields[all_fields %in% used]
}

c2_inputs <- function(substrate, instrument_idx, prefix_end, cutoff,
                      fields = c("open", "high", "low", "close", "volume")) {
  prefix <- seq_len(prefix_end)
  expected <- as.logical(ledgr_history_substrate_expected_at(substrate, cutoff, prefix, instrument_idx)[1L, ])
  terminal_planes <- ledgr_history_substrate_terminal_planes(substrate, cutoff, prefix, instrument_idx)
  terminal <- as.logical(terminal_planes$sticky[1L, ])
  terminal_asserted <- as.logical(terminal_planes$asserted[1L, ])
  axis <- substrate$axis[prefix]
  policy <- substrate$history_policy
  raw <- list(); treated <- list(); carried <- list()
  for (field in fields) {
    value <- as.numeric(substrate$bars[[field]][instrument_idx, prefix])
    raw_value <- value
    raw_value[!expected] <- NA_real_
    raw[[field]] <- raw_value
    if (identical(field, "volume")) {
      treated[[field]] <- raw_value
      carried[[field]] <- rep(FALSE, prefix_end)
      next
    }
    treatment <- ledgr_history_input_carry_calculation(
      value = value, expected = expected, max_sessions = policy$price_carry,
      carry_allowed = !is.null(policy$price_carry), terminal_barrier = terminal)
    treated[[field]] <- treatment$value
    carried[[field]] <- treatment$input_carried
  }
  list(instrument_id = substrate$instrument_ids[[instrument_idx]], axis = axis, expected = expected,
       terminal = terminal, terminal_asserted = terminal_asserted, raw = raw, treated = treated, carried = carried)
}

# The frame holds the treated fields only; with all five fields it is the
# pin's frame (same columns, same order).
c2_frame <- function(inputs, fields, rows) {
  cols <- c(list(instrument_id = rep(inputs$instrument_id, length(rows)), ts_utc = inputs$axis[rows]),
            lapply(fields[intersect(c("open", "high", "low", "close", "volume"), names(fields))], `[`, rows))
  structure(cols, class = "data.frame", row.names = c(NA_integer_, -length(rows)))
}

# Two edits to the compute body: the union is computed once per call and
# passed to ledgr_history_feature_inputs(); the causality probe does the same.
c2_compute <- pin_fns$ledgr_history_compute_feature_series
body(c2_compute) <- local({
  b <- deparse(body(c2_compute))
  b <- sub("certified <- lapply(definitions, ledgr_feature_certify)",
           "certified <- lapply(definitions, ledgr_feature_certify)\n    treat_fields <- c2_field_union(certified)",
           b, fixed = TRUE)
  b <- sub("substrate$axis[[range_end]])", "substrate$axis[[range_end]], fields = treat_fields)", b, fixed = TRUE)
  parse(text = paste(b, collapse = "\n"))[[1L]]
})
c2_causality <- pin_fns$ledgr_history_feature_causality
body(c2_causality) <- local({
  b <- deparse(body(c2_causality))
  b <- sub("probes <- list()", "probes <- list()\n    treat_fields <- c2_field_union(certified)", b, fixed = TRUE)
  b <- sub("substrate$axis[[range_end]])", "substrate$axis[[range_end]], fields = treat_fields)", b, fixed = TRUE)
  parse(text = paste(b, collapse = "\n"))[[1L]]
})

# ---- candidate 3 -----------------------------------------------------------

# The registered seam stays: segments still call ledgr_ttr_raw_call() once
# per raw-cache miss (LTB-0276 counts these calls), now with the resolved
# function and, for input "close", the close vector.
c3_raw_call <- function(bars, params, ttr_fun = NULL, x = NULL) {
  if (is.null(ttr_fun)) {
    if (!requireNamespace("TTR", quietly = TRUE)) {
      rlang::abort("Package 'TTR' is required to compute this TTR indicator.", class = "ledgr_missing_optional_dependency")
    }
    ttr_fun <- getExportedValue("TTR", params$ttr_fn)
  }
  if (is.null(x)) x <- ledgr_ttr_build_input(bars, params$input)
  if (identical(params$input, "hlcv") && params$ttr_fn %in% c("MFI", "CMF")) {
    do.call(ttr_fun, c(list(x[, c("High", "Low", "Close"), drop = FALSE], x[, "Volume"]), params$args))
  } else {
    do.call(ttr_fun, c(list(x), params$args))
  }
}

# Resolved once per definition, at certification.
c3_certify <- function(def) {
  out <- c3_pin_certify(def)
  if (identical(out$kind, "ttr")) out$ttr_fun <- getExportedValue("TTR", out$def$params$ttr_fn)
  out
}

c3_segment <- function(cert, inputs, fields, rows, cache = NULL) {
  def <- cert$def
  stable_after <- as.integer(def$stable_after)
  width <- as.integer(def$requires_bars)
  params <- def$params %||% list()
  m <- length(rows)
  if (identical(cert$kind, "sma")) {
    return(ledgr_strict_sma_series(fields$close[rows], width))
  }
  if (identical(cert$kind, "ttr") && is.environment(cache)) {
    key <- paste(cert$ttr_call_key, rows[[1L]], rows[[m]], sep = "|")
    raw <- cache[[key]]
    if (is.null(raw)) {
      raw <- if (identical(params$input, "close")) {
        ledgr_ttr_raw_call(NULL, params, cert$ttr_fun, as.numeric(fields$close[rows]))
      } else {
        ledgr_ttr_raw_call(ledgr_history_feature_frame(inputs, fields, rows), params, cert$ttr_fun)
      }
      cache[[key]] <- raw
    }
    return(ledgr_normalize_feature_series_output(
      ledgr_ttr_select_output(raw, params$output, params$ttr_fn), m, stable_after, def$id))
  }
  frame <- ledgr_history_feature_frame(inputs, fields, rows)
  ready <- seq_len(m) >= stable_after
  if (is.function(def$series_fn)) {
    return(ledgr_normalize_feature_series_output(
      ledgr_call_feature_series_fn(def$series_fn, frame, params), m, stable_after, def$id))
  }
  value <- rep(NA_real_, m)
  for (k in which(ready)) {
    value[[k]] <- ledgr_normalize_feature_scalar_output(
      ledgr_call_feature_fn(def$fn, ledgr_history_feature_window(frame, seq.int(k - width + 1L, k)), params),
      def$id)
  }
  value
}

for (nm in c("c2_inputs", "c2_frame", "c2_compute", "c2_causality",
             "c3_raw_call", "c3_certify", "c3_segment")) {
  f <- get(nm)
  environment(f) <- ns
  assign(nm, f)
}
# Helpers the patched bodies call by name live in a child of the namespace.
c3_pin_certify <- pin_fns$ledgr_feature_certify
patch_env <- new.env(parent = ns)
patch_env$naive <- FALSE
environment(c2_field_union) <- patch_env
assign("c2_field_union", c2_field_union, envir = patch_env)
assign("c3_pin_certify", c3_pin_certify, envir = patch_env)
for (nm in c("c2_compute", "c2_causality", "c3_certify")) {
  f <- get(nm)
  environment(f) <- patch_env
  assign(nm, f)
}

arm_bindings <- list(
  pin = list(),
  c2 = list(ledgr_history_feature_inputs = c2_inputs, ledgr_history_feature_frame = c2_frame,
            ledgr_history_compute_feature_series = c2_compute, ledgr_history_feature_causality = c2_causality),
  c3 = list(ledgr_ttr_raw_call = c3_raw_call, ledgr_feature_certify = c3_certify,
            ledgr_history_feature_segment = c3_segment))
arm_bindings$c23 <- c(arm_bindings$c2, arm_bindings$c3)
arm_bindings$c2naive <- arm_bindings$c2

set_binding <- function(name, value) {
  unlockBinding(name, ns)
  assign(name, value, envir = ns)
  lockBinding(name, ns)
}

use_arm <- function(arm) {
  patch_env$naive <- identical(arm, "c2naive")
  for (nm in names(pin_fns)) set_binding(nm, pin_fns[[nm]])
  for (nm in names(arm_bindings[[arm]])) set_binding(nm, arm_bindings[[arm]][[nm]])
  invisible(arm)
}
