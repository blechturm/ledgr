# The adapter with its deliberate fault (Cut 20, cut review R1), sourced by
# loop_parity.R --witness= instead of hashed_frame_adapter.R. It loads the
# adapter, then recompiles lean_envelope_code from loop.R with one change:
# the hashed code alone builds the lean context with .safety_state "RED"
# instead of "GREEN" (the plain function is untouched and refused by the
# adapter). With debug assertions on, the existing context comparison must
# fail on it; the adapter without this file passes (hashed_frame_witness.R).
sys.source(file.path(.lean_home, "parity", "hashed_frame_adapter.R"), envir = environment(), keep.source = FALSE)
local({
  lean <- parent.env(environment())
  from <- "state = lean_strategy_view(strategy_state), .safety_state = \"GREEN\""
  to <- "state = lean_strategy_view(strategy_state), .safety_state = \"RED\""
  x <- readLines(file.path(lean$.lean_home, "loop.R"))
  if (sum(grepl(from, x, fixed = TRUE)) != 1L) stop("adapter fault: anchor not found once", call. = FALSE)
  ex <- parse(text = sub(from, to, x, fixed = TRUE), keep.source = FALSE)
  hit <- Filter(function(e) is.call(e) && identical(e[[1L]], as.name("<-")) &&
                  identical(e[[2L]], as.name("lean_fold_envelope_plain")), as.list(ex))
  if (length(hit) != 1L) stop("adapter fault: lean_fold_envelope_plain not found once", call. = FALSE)
  op <- options(topLevelEnvironment = NULL)
  on.exit(options(op))
  # The function expression's body, compiled against the lean environment as loop.R does.
  lean$lean_envelope_code <- compiler::compile(hit[[1L]][[3L]][[3L]], env = lean)
  lean$lean_entry$adapter_fault <- TRUE
})
