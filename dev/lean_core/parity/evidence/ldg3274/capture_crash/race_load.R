.libPaths(unique(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths())))
suppressMessages(pkgload::load_all(commandArgs(TRUE)[[1L]], quiet = TRUE, export_all = TRUE))
cat("loaded", Sys.getpid(), format(Sys.time(), "%H:%M:%OS3"), "\n")
