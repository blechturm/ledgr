# Candidate strategy target checks. Each must return what the pinned
# ledgr_validate_strategy_targets() (R/strategy-contracts.R:34) returns, or
# raise the same condition class and message, on every case in run.R.
#
#   same_rules       the pinned rules in the pinned order. When the target
#                    names are identical to the universe (the order ledgr's
#                    helpers return) the name, missing and extra tests are
#                    proved by that one comparison; otherwise one match()
#                    replaces two setdiff() calls and the name subset.
#   trusted_universe same_rules without re-checking `universe`, which the
#                    fold builds itself (response review D1).

sc_contract <- function() ledgr:::ledgr_strategy_targets_contract()
sc_abort <- function(msg) rlang::abort(msg, class = "ledgr_invalid_strategy_result")

sc_check <- function(targets, universe, allow_empty = FALSE, trust_universe = FALSE, gut = FALSE) {
  if (!trust_universe) {
    if (!is.character(universe) || (!isTRUE(allow_empty) && length(universe) < 1L) ||
        anyNA(universe) || any(!nzchar(universe))) {
      sc_abort("`universe` must be a character vector.")
    }
    if (anyDuplicated(universe)) sc_abort("`universe` must not contain duplicates.")
  }
  targets <- ledgr:::ledgr_unwrap_strategy_target(targets)
  if (!is.numeric(targets) || (!isTRUE(allow_empty) && length(targets) < 1L)) {
    sc_abort(sprintf("`targets` must be %s; got %s.", sc_contract(), paste(class(targets), collapse = "/")))
  }
  target_names <- names(targets)
  if (isTRUE(allow_empty) && length(universe) == 0L && length(targets) == 0L &&
      is.character(target_names) && length(target_names) == 0L) {
    return(targets)
  }
  in_order <- identical(target_names, universe)
  if (!in_order && (is.null(target_names) || length(target_names) != length(targets) ||
                    anyNA(target_names) || any(!nzchar(target_names)) || anyDuplicated(target_names))) {
    sc_abort(sprintf("`targets` must be %s. Names must be unique, non-empty instrument IDs.", sc_contract()))
  }
  if (!gut && any(!is.finite(targets))) {
    sc_abort(sprintf("`targets` must be %s. Target quantities must be finite numeric values.", sc_contract()))
  }
  if (in_order) {
    out <- as.vector(targets)
    names(out) <- universe
    return(out)
  }
  pos <- match(universe, target_names)
  if (anyNA(pos) || length(targets) != length(universe)) {
    missing <- setdiff(universe, target_names)
    extra <- setdiff(target_names, universe)
    details <- c(
      if (length(missing) > 0) sprintf("missing instruments: %s", paste(missing, collapse = ", ")),
      if (length(extra) > 0) sprintf("extra instruments: %s", paste(extra, collapse = ", "))
    )
    sc_abort(sprintf("`targets` must be %s; %s.", sc_contract(), paste(details, collapse = "; ")))
  }
  targets[pos]
}
