# Test-only adapter (Cut 20, cut review R1), sourced into the lean
# environment by loop_parity.R --witness= after lean_core_load(lib, debug =
# TRUE). It evaluates the production-loaded lean_envelope_code (compiled by
# loop.R at load; not recompiled here) in the same hashed child of its
# argument frame as the production wrapper, but with .lean_debug TRUE, so the
# internal debug comparisons run on the hashed form. Production debug
# dispatch (debug on -> the plain function) is unchanged; nothing in
# dev/lean_core calls this file.
#
# The plain function is replaced by a refusal, so a run that reached it
# instead of the compiled body would fail; the compiled body does not call it.
stopifnot(isTRUE(.lean_debug), identical(typeof(lean_envelope_code), "bytecode"))
lean_fold_envelope_plain <- function(execution, output_handler) {
  stop("hashed-frame adapter: the plain envelope was called", call. = FALSE)
}
lean_fold_envelope <- function(execution, output_handler) {
  lean_entry$adapter_folds <- (lean_entry$adapter_folds %||% 0L) + 1L
  eval(lean_envelope_code, new.env(hash = TRUE, parent = environment()))
}
