# Spike lean_fifo_cpp: compile kernel.cpp (cpp11::cpp_source) and install
# it at one seam, lean_lot_apply() in a lean environment: the compiled
# kernel first, the R kernel when it declines (returns NULL) or in debug.

spike_compile <- function(dir) {
  env <- new.env()
  cpp11::cpp_source(file.path(dir, "kernel.cpp"), env = env, quiet = TRUE)
  env$spike_lot_fill
}

spike_install <- function(lean, kernel) {
  r_apply <- lean$lean_lot_apply
  stats <- new.env(); stats$compiled <- 0L; stats$declined <- 0L
  lean$lean_lot_apply <- function(book, input) {
    if (!.lean_debug) {
      r <- kernel(book, input)
      if (!is.null(r)) { stats$compiled <- stats$compiled + 1L; return(r) }
    }
    stats$declined <- stats$declined + 1L
    r_apply(book, input)
  }
  environment(lean$lean_lot_apply) <- list2env(list(kernel = kernel, r_apply = r_apply, stats = stats), parent = lean)
  list(r_apply = r_apply, stats = stats)
}
