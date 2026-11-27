  observed <- new.env(parent = emptyenv())
  original <- ledgr:::ledgr_context_preparation_increment
  testthat::local_mocked_bindings(
    ledgr_context_preparation_increment = function(counts, name) {
      observed[[name]] <- as.integer(observed[[name]] %||% 0L) + 1L
      original(counts, name)
    },
    .package = "ledgr"
  )
