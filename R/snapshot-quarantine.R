#' Read quarantined snapshot observations
#'
#' Returns observations excluded while building a snapshot with
#' `invalid_observations = "quarantine"`, and, under reason
#' `off_session_bar`, valid bars that were sealed on no declared open-session
#' close and therefore never become a pulse of an availability-aware run. The
#' rows and reasons are read
#' from sealed snapshot evidence without adding a new interpretation.
#' Off-session records are derived from the hashed bars and sessions and are
#' not themselves part of the snapshot hash.
#'
#' @param snapshot A sealed `ledgr_snapshot` object.
#' @return A tibble with quarantine identifiers, supplied identifiers and
#'   timestamps, reasons, original row JSON, provenance JSON, and
#'   `disposition` (`"excluded"` for a quarantined row, `"sealed_not_a_pulse"`
#'   for an off-session bar). A snapshot
#'   with no quarantined observations returns a zero-row tibble with the same
#'   columns.
#' @export
ledgr_snapshot_quarantine <- function(snapshot) {
  if (!inherits(snapshot, "ledgr_snapshot")) {
    rlang::abort(
      "`snapshot` must be a ledgr_snapshot object.",
      class = "ledgr_invalid_snapshot"
    )
  }
  opened <- ledgr_snapshot_connection(snapshot)
  if (isTRUE(opened$opened_new)) {
    on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  }
  ledgr_snapshot_ensure_verified(
    opened$con,
    snapshot$snapshot_id,
    snapshot_db_path = snapshot$db_path
  )
  info <- ledgr_snapshot_info(opened$con, snapshot$snapshot_id)
  if (!identical(info$status[[1L]], "SEALED")) {
    rlang::abort(
      "Quarantined observations can be read only from a sealed snapshot.",
      class = "LEDGR_SNAPSHOT_NOT_SEALED"
    )
  }

  rows <- DBI::dbGetQuery(
    opened$con,
    paste(
      "SELECT quarantine_id, supplied_instrument_id, supplied_ts_utc,",
      "reason, original_row_json, provenance_json",
      "FROM snapshot_observation_quarantine",
      "WHERE snapshot_id = ? ORDER BY quarantine_id"
    ),
    params = list(snapshot$snapshot_id)
  )
  rows$disposition <- c("excluded", "sealed_not_a_pulse")[1L + (rows$reason == ledgr_off_session_reason)]
  tibble::as_tibble(rows)
}
