# Cut 23 decision 4: witness (a) must fail when the rebuild drops the stored
# declaration overlay or the stored fingerprint. Each fault rewrites the
# rebuild's add_def() inside ledgr_feature_defs_from_config() in the loaded
# namespace, then runs the (a) witness; a fault that still passes is a hole.
#   Rscript overlay_faults.R --tree=<package source>
argv <- commandArgs(TRUE)
tree <- sub("^--tree=", "", grep("^--tree=", argv, value = TRUE)[[1L]])
pkgload::load_all(tree, quiet = TRUE)
ns <- asNamespace("ledgr")
original <- get("ledgr_feature_defs_from_config", ns)
src <- paste(deparse(original, control = "useSource"), collapse = "\n")
faults <- list(
  drop_declaration_overlay = c(
    from = 'if (!is.null(stored[[field]])) def[[field]] <- stored[[field]]',
    to = 'invisible(NULL)'),
  drop_stored_fingerprint = c(
    from = 'def$fingerprint <- stored$fingerprint %||% ledgr_feature_def_fingerprint(def)',
    to = 'def$fingerprint <- ledgr_feature_def_fingerprint(def)'))
run_a <- function() {
  res <- as.data.frame(testthat::test_file(file.path(tree, "tests/testthat/test-indicator-dispatch.R"),
                                            reporter = "silent", desc = "[Cut 23 (a)] a stored built-in id rebuilds as the built-in with the stored overlay"))
  sprintf("%d expectations, %d failed, error %s", res$nb, res$failed, res$error)
}
unlockBinding("ledgr_feature_defs_from_config", ns)
cat("no fault:", run_a(), "\n")
for (k in names(faults)) {
  f <- faults[[k]]
  if (!grepl(f[["from"]], src, fixed = TRUE)) stop("fault anchor not found: ", k)
  patched <- eval(parse(text = sub(f[["from"]], f[["to"]], src, fixed = TRUE)))
  environment(patched) <- ns
  assign("ledgr_feature_defs_from_config", patched, ns)
  cat(k, ":", run_a(), "\n")
  assign("ledgr_feature_defs_from_config", original, ns)
}
cat("restored:", run_a(), "\n")
