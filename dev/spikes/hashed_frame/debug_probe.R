# Debug probe (closeout, 'Debugging'): what the call stack and recover() see when
# a stage errors, plain frame against the hashed pattern, on a toy envelope.
#   Rscript dev/spikes/hashed_frame/debug_probe.R > dev/spikes/hashed_frame/evidence/debug_probe.txt
env_plain <- function(execution) {
  state <- 1L
  stage <- function(i) { state <<- state + i; if (i == 3L) stop("boom in stage"); state }
  for (i in 1:5) stage(i)
  state
}
code <- compiler::compile(body(env_plain), env = environment(env_plain))
env_hashed <- compiler::cmpfun(function(execution) eval(code, new.env(hash = TRUE, parent = environment())))
show <- function(f) {
  calls <- NULL; frames <- NULL
  tryCatch(withCallingHandlers(f(0), error = function(e) { calls <<- sys.calls(); frames <<- sys.frames() }),
           error = function(e) NULL)
  k <- seq_len(length(calls) - 1L)
  k <- k[-seq_len(2L)]   # drop tryCatch/withCallingHandlers scaffolding
  cat(sprintf("  call: %s\n", vapply(calls[k], function(x) deparse(x, width.cutoff = 70)[1], "")), sep = "")
  hit <- which(vapply(frames[k], function(e) exists("state", envir = e, inherits = FALSE), NA))
  cat("  stack frames holding the envelope's 'state':", length(hit), " value there:", if (length(hit)) get("state", frames[k][[hit[1]]]) else NA, "\n")
}
cat("plain:\n"); show(env_plain)
cat("hashed:\n"); show(env_hashed)
