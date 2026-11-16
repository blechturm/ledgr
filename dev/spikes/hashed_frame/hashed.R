# Hashed-frame fork (dev/spikes/hashed_frame): sourced after loop.R into the
# lean environment. The envelope's body is compiled once (stage functions
# defined in it compile with it) and evaluated in a hashed environment whose
# parent is the call frame, so the ~140 names it binds are found by hash
# instead of by a linear scan of an unhashed function frame. `on.exit()` in
# the body attaches to eval()'s context, which ends when the body ends.
# sys.source() sets the topLevelEnvironment option to the lean environment,
# which makes the compiler refuse the namespace above it; the compile call
# clears the option for its duration.
lean_fold_envelope_plain <- lean_fold_envelope
lean_envelope_code <- local({
  op <- options(topLevelEnvironment = NULL)
  on.exit(options(op))
  compiler::compile(body(lean_fold_envelope_plain), env = environment(lean_fold_envelope_plain))
})
lean_fold_envelope <- function(execution, output_handler) {
  eval(lean_envelope_code, new.env(hash = TRUE, parent = environment()))
}
