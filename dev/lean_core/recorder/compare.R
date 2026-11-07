# The one comparison for every family (interface table Section 14):
# identical() over values, names, attributes, types and order. Dropped: the
# table's clock fields, only at their owners' paths (lc_clock_paths()), and
# function source references (srcref, srcfile, wholeSrcref). Environments and
# closures are compared by content, lock state and sharing: each environment
# pairs with exactly one environment on the other side. Returns NULL, or the
# first difference.

# Where the clock fields live: a stage's timing locals (its value, P1's
# observation, the arguments that hand them on) and the telemetry environment.
lc_clock_paths <- function(boundary) {
  if (boundary %in% lc_stages) {
    c("$value", "$value$observation", "$svc:telemetry", paste0("$arg:", c("sample_start", "pulse_start", "observation", "decision", "plan", "apply")))
  } else if (identical(boundary, "E")) c("$value$telemetry", "$arg:execution$telemetry") else character()
}

lc_special_env <- function(e) {
  identical(e, globalenv()) || identical(e, baseenv()) || identical(e, emptyenv()) ||
    isNamespace(e) || !is.null(attr(e, "name")) && startsWith(attr(e, "name"), "package:")
}

lc_compare <- function(x, y, clock, owners = character(), path = "", seen = new.env(parent = emptyenv())) {
  diff <- function(what) paste0(if (nzchar(path)) path else "<top>", ": ", what)
  drop <- if (path %in% owners) clock else character()
  if (is.environment(x) || is.environment(y)) {
    if (!is.environment(x) || !is.environment(y)) return(diff("environment vs non-environment"))
    if (lc_special_env(x) || lc_special_env(y)) return(if (!identical(x, y)) diff("different special environment"))
    # Environments must correspond one to one across the whole graph, so two
    # closures that share state on one side share it on the other (WS26 close
    # review finding 1).
    kx <- paste0("x:", rlang::obj_address(x))
    ky <- paste0("y:", rlang::obj_address(y))
    mx <- seen[[kx]]
    my <- seen[[ky]]
    if (!is.null(mx) || !is.null(my)) {
      if (identical(mx, ky) && identical(my, kx)) return(NULL)
      return(diff("environment sharing differs"))
    }
    assign(kx, ky, envir = seen)
    assign(ky, kx, envir = seen)
    if (environmentIsLocked(x) != environmentIsLocked(y)) return(diff("environment locked in one only"))
    nx <- setdiff(sort(ls(x, all.names = TRUE), method = "radix"), drop)
    ny <- setdiff(sort(ls(y, all.names = TRUE), method = "radix"), drop)
    if (!identical(nx, ny)) return(diff(paste("binding names differ:", paste(setdiff(union(nx, ny), intersect(nx, ny)), collapse = ","))))
    for (n in nx) {
      ax <- bindingIsActive(n, x)
      if (ax != bindingIsActive(n, y)) return(diff(paste0("binding ", n, " active in one only")))
      if (bindingIsLocked(n, x) != bindingIsLocked(n, y)) return(diff(paste0("binding ", n, " locked in one only")))
      vx <- if (ax) activeBindingFunction(n, x) else get(n, envir = x)
      vy <- if (ax) activeBindingFunction(n, y) else get(n, envir = y)
      d <- lc_compare(vx, vy, clock, owners, paste0(path, "$", n), seen)
      if (!is.null(d)) return(d)
    }
    d <- lc_compare_attributes(attributes(x), attributes(y), clock, owners, paste0(path, "@"), seen)
    return(d %||% lc_compare(parent.env(x), parent.env(y), clock, owners, paste0(path, "<parent>"), seen))
  }
  if (!identical(typeof(x), typeof(y))) return(diff(paste("type", typeof(x), "vs", typeof(y))))
  if (typeof(x) == "closure") {
    sx <- utils::removeSource(x)
    sy <- utils::removeSource(y)
    if (!identical(formals(sx), formals(sy)) || !identical(body(sx), body(sy))) return(diff("function formals or body differ"))
    ax <- attributes(x)
    ay <- attributes(y)
    ax$srcref <- ay$srcref <- NULL
    d <- lc_compare_attributes(ax, ay, clock, owners, paste0(path, "@"), seen)
    return(d %||% lc_compare(environment(x), environment(y), clock, owners, paste0(path, "<closure env>"), seen))
  }
  if (is.list(x)) {
    kx <- !(names(x) %in% drop)
    ky <- !(names(y) %in% drop)
    if (is.null(names(x))) kx <- rep(TRUE, length(x))
    if (is.null(names(y))) ky <- rep(TRUE, length(y))
    ax <- attributes(x)
    ay <- attributes(y)
    ax$names <- names(x)[kx]
    ay$names <- names(y)[ky]
    d <- lc_compare_attributes(ax, ay, clock, owners, paste0(path, "@"), seen)
    if (!is.null(d)) return(d)
    x <- unclass(x)[kx]
    y <- unclass(y)[ky]
    if (length(x) != length(y)) return(diff(paste("length", length(x), "vs", length(y))))
    for (i in seq_along(x)) {
      label <- if (!is.null(names(x)) && nzchar(names(x)[[i]])) paste0("$", names(x)[[i]]) else paste0("[[", i, "]]")
      d <- lc_compare(x[[i]], y[[i]], clock, owners, paste0(path, label), seen)
      if (!is.null(d)) return(d)
    }
    return(NULL)
  }
  # Attributes go through the same comparison (and environment pairing) even
  # when the objects are identical, then the payloads are compared without
  # them, so equivalent environment attributes neither fail a correct replay
  # nor skip the pairing (WS26 close review round 2).
  # The S4 flag is not an attribute and stripping attributes clears it, so
  # it is compared first (WS26 close review round 3).
  if (isS4(x) != isS4(y)) return(diff("S4 in one only"))
  ax <- attributes(x)
  ay <- attributes(y)
  if (is.null(ax) && is.null(ay)) {
    if (identical(x, y)) return(NULL)
  } else {
    d <- lc_compare_attributes(ax, ay, clock, owners, paste0(path, "@"), seen)
    if (!is.null(d)) return(d)
    bare <- function(v) tryCatch({ attributes(v) <- NULL; v }, error = function(e) v)
    if (identical(bare(x), bare(y))) return(NULL)
  }
  i <- if (is.atomic(x) && length(x) == length(y)) which(xor(is.na(x), is.na(y)) | !is.na(x) & !is.na(y) & x != y)
  diff(if (length(i)) sprintf("element [%d] differs", i[[1L]]) else sprintf("%s values differ, length %d vs %d", typeof(x), length(x), length(y)))
}

lc_compare_attributes <- function(ax, ay, clock, owners, path, seen) {
  nx <- sort(as.character(names(ax)), method = "radix")
  if (!identical(nx, sort(as.character(names(ay)), method = "radix"))) return(paste0(path, ": attribute names differ"))
  for (n in nx) {
    d <- lc_compare(ax[[n]], ay[[n]], clock, owners, paste0(path, n), seen)
    if (!is.null(d)) return(d)
  }
  NULL
}
