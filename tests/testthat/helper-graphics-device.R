ledgr_test_local_graphics_device <- function() {
  path <- tempfile("ledgr-test-plot-", fileext = ".pdf")
  grDevices::pdf(path)
  device <- grDevices::dev.cur()
  withr::defer({
    devices <- grDevices::dev.list()
    if (!is.null(devices) && device %in% devices) {
      grDevices::dev.off(device)
    }
    unlink(path)
  }, envir = parent.frame())
  invisible(path)
}
