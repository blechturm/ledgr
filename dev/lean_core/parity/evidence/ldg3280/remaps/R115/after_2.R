  testthat::expect_true(any(grepl("szr$reasons[rows] <<- if (is.null(intent)) \"\" else intent", fold_source, fixed = TRUE)))
