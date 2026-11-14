# Cut 18 (amendment lean_owned, items (b), A1 and A2): direct differential
# witnesses for each lean-owned replacement in dev/lean_core/checks.R
# against the named pinned callable, on the required cases of
# cut18_witness_cases.csv, with debug off and on.
#
#   Rscript dev/lean_core/parity/cut18_witness.R --lib=<pinned library> --out=<csv> [--mutation=<name>]
#
# Each case evaluates the lean call and the pin call on the same inputs. A
# value must be identical (types, names, attributes; doubles bit for bit,
# no tolerance); a refusal must match on the class vector, message, call
# and every payload field (reason, instrument_ids and the rest), and its
# parent condition the same way, recursively; the backtrace is excluded.
# A case of the manifest the grid does not produce, or a grid case the
# manifest lacks, fails the run (exit 1). --mutation loads checks.R with
# one registered fault (cut18_witness_mutations) and requires that some
# case fails (the fault is caught), else exit 1.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
source(file.path(here, "..", "load.R"))
source(file.path(here, "loop_edits.R"))
lean <- lean_core_load(opt("lib"))
ns <- asNamespace("ledgr")

# Registered faults: each must make some case differ.
cut18_witness_mutations <- list(
  state_broadcast_accepted = lean_edit("checks.R", "lean_state_value",
    "  plain <- if (identical(field$scope, \"asset\")) identical(attributes(value), axis_attr) else",
    "  plain <- if (identical(field$scope, \"asset\")) (identical(attributes(value), axis_attr) || length(value) == 1L) else"),
  state_nan_accepted = lean_edit("checks.R", "lean_state_value",
    "  if (plain && typed && !(is.double(value) && any(is.nan(value) | is.infinite(value)))) return(value)",
    "  if (plain && typed) return(value)"),
  state_reset_skipped = lean_edit("checks.R", "lean_state_apply", "    if (any(reset)) value[reset] <- defaults[[name]]", "    NULL"))
mutation <- opt("mutation", "")
if (nzchar(mutation)) lean_load_edited(lean, lean$.lean_home, list(cut18_witness_mutations[[mutation]]))

norm_cond <- function(e) {
  if (!inherits(e, "condition")) return(NULL)
  fields <- unclass(e); fields$trace <- NULL; fields$parent <- NULL
  fields$call <- if (is.null(conditionCall(e))) NULL else paste(deparse(conditionCall(e)), collapse = " ")
  list(class = class(e), fields = fields[order(names(fields))], parent = norm_cond(e$parent))
}
outcome <- function(f) tryCatch(list(value = f()), error = function(e) list(error = norm_cond(e)))
cases <- list()
case <- function(replacement, id, lean_call, pin_call) cases[[length(cases) + 1L]] <<- list(replacement = replacement, id = id, lean = lean_call, pin = pin_call)

## R5: state field values and state patches ---------------------------------
ids <- c("CCC", "AAA", "BBB"); ids_attr <- list(names = ids)
decl <- ns$ledgr_strategy_state_normalize(asset_state = list(above = FALSE, w = 0.5, tag = "x"),
                                          portfolio_state = list(k = 0L, x = 1.5, on = TRUE))
fields <- decl$fields; names(fields) <- vapply(fields, function(f) f$name, "")
defaults <- ns$ledgr_strategy_state_default_scalars(decl)
state0 <- ns$ledgr_strategy_state_defaults(decl, ids, default_scalars = defaults)
nmd <- function(v, n = ids) stats::setNames(v, n)
values <- list(
  asset_logical_named = list("above", nmd(c(TRUE, FALSE, TRUE))),
  asset_logical_na = list("above", nmd(c(NA, FALSE, TRUE))),
  asset_double_named = list("w", nmd(c(0.1, 0.2, 0.3))),
  asset_double_na = list("w", nmd(c(NA, 0.2, 0.3))),
  asset_double_nan = list("w", nmd(c(NaN, 0.2, 0.3))),
  asset_double_inf = list("w", nmd(c(Inf, 0.2, 0.3))),
  asset_character = list("tag", nmd(c("a", "b", "c"))),
  asset_broadcast_scalar = list("above", TRUE),
  asset_reordered_names = list("above", nmd(c(TRUE, FALSE, TRUE), rev(ids))),
  asset_unnamed_full = list("above", c(TRUE, FALSE, TRUE)),
  asset_partial_names = list("above", nmd(c(TRUE, FALSE), ids[1:2])),
  asset_wrong_type = list("above", nmd(c(1, 0, 1))),
  asset_classed = list("above", structure(nmd(c(TRUE, FALSE, TRUE)), class = "myclass")),
  asset_extra_attribute = list("above", structure(nmd(c(TRUE, FALSE, TRUE)), note = 1)),
  asset_integer_for_double = list("w", nmd(1:3)),
  portfolio_integer = list("k", 3L),
  portfolio_integer_na = list("k", NA_integer_),
  portfolio_double = list("x", 2.5),
  portfolio_double_nan = list("x", NaN),
  portfolio_logical = list("on", FALSE),
  portfolio_named_scalar = list("k", c(a = 3L)),
  portfolio_length_two = list("k", c(1L, 2L)),
  portfolio_double_for_integer = list("k", 3),
  portfolio_attribute = list("k", structure(3L, note = 1)))
for (nm in names(values)) local({
  f <- fields[[values[[nm]][[1L]]]]; v <- values[[nm]][[2L]]
  case("R5", paste0("value_", nm), function() lean$lean_state_value(v, f, ids, ids_attr),
       function() ns$ledgr_strategy_state_validate_value(v, f, ids))
})
one_axis <- "AAA"
case("R5", "value_axis_one_named", function() lean$lean_state_value(c(AAA = TRUE), fields$above, one_axis, list(names = one_axis)),
     function() ns$ledgr_strategy_state_validate_value(c(AAA = TRUE), fields$above, one_axis))
case("R5", "value_axis_empty", function() lean$lean_state_value(stats::setNames(logical(), character()), fields$above, character(),
                                                                  list(names = character())),
     function() ns$ledgr_strategy_state_validate_value(stats::setNames(logical(), character()), fields$above, character()))
st_names <- names(state0); names_ok <- TRUE
# patches built by field name, then put in the state's own order
by_name <- function(...) { p <- list(...); p[st_names] }
full <- by_name(above = nmd(c(TRUE, TRUE, FALSE)), w = nmd(c(0.4, 0.5, 0.6)), tag = nmd(c("p", "q", "r")), k = 4L, x = 0.25, on = FALSE)
patches <- list(
  full_in_order = full,
  full_with_reset = by_name(above = nmd(c(NA, TRUE, FALSE)), w = nmd(c(0.4, NA, 0.6)), tag = nmd(c("p", NA, "r")), k = NA_integer_,
                            x = NA_real_, on = NA),
  subset = list(k = 7L),
  reordered = rev(full),
  broadcast = list(above = TRUE, w = 0.9),
  unknown_field = list(k = 1L, zzz = 2),
  duplicated_names = stats::setNames(list(1L, 2L), c("k", "k")),
  empty = list(),
  unnamed = list(1L),
  na_name = stats::setNames(list(1L), NA_character_),
  empty_name = stats::setNames(list(1L), ""),
  data_frame = data.frame(k = 1L),
  not_a_list = 5L,
  bad_value_type = list(k = "a"),
  bad_value_late = local({ p <- full; p$x <- "bad"; p }))
for (nm in names(patches)) local({
  u <- patches[[nm]]
  case("R5", paste0("patch_", nm), function() lean$lean_state_apply(u, state0, fields, defaults, decl, ids, ids_attr, st_names, names_ok),
       function() ns$ledgr_strategy_state_apply_values(state0, u, decl, ids, patch = TRUE, default_scalars = defaults))
})
renamed <- state0[rev(names(state0))]
case("R5", "patch_state_renamed", function() lean$lean_state_apply(patches$full_in_order, renamed, fields, defaults, decl, ids, ids_attr,
                                                                     st_names, names_ok),
     function() ns$ledgr_strategy_state_apply_values(renamed, patches$full_in_order, decl, ids, patch = TRUE, default_scalars = defaults))

## run ---------------------------------------------------------------------------
manifest <- utils::read.csv(file.path(here, "cut18_witness_cases.csv"), stringsAsFactors = FALSE)
ids_grid <- vapply(cases, function(k) paste(k$replacement, k$id, sep = "|"), "")
rows <- list()
for (debug in c(FALSE, TRUE)) {
  lean$.lean_debug <- debug
  for (k in cases) {
    a <- outcome(k$lean); b <- outcome(k$pin)
    rows[[length(rows) + 1L]] <- data.frame(replacement = k$replacement, case = k$id, debug = as.integer(debug),
      outcome = if (is.null(b$error)) "value" else paste0("refusal: ", b$error$class[[1L]]), identical = identical(a, b))
  }
}
res <- do.call(rbind, rows)
utils::write.csv(res, opt("out"), row.names = FALSE)
missing <- setdiff(paste(manifest$replacement, manifest$case, sep = "|"), ids_grid)
extra <- setdiff(ids_grid, paste(manifest$replacement, manifest$case, sep = "|"))
cat(sprintf("%d cases x 2 debug settings, %d differ; manifest missing %d, unlisted %d\n", length(cases), sum(!res$identical),
            length(missing), length(extra)))
if (length(missing)) cat("missing:", missing, "\n")
if (length(extra)) cat("unlisted:", extra, "\n")
if (nzchar(mutation)) {
  caught <- any(!res$identical)
  cat(sprintf("mutation %s: %s\n", mutation, if (caught) "CAUGHT" else "MISSED"))
  quit(status = if (caught && !length(missing) && !length(extra)) 0L else 1L)
}
if (any(!res$identical)) print(res[!res$identical, ], row.names = FALSE)
quit(status = if (all(res$identical) && !length(missing) && !length(extra)) 0L else 1L)
