\name{ledgr_snapshot_quarantine}
\alias{ledgr_snapshot_quarantine}
\title{Read quarantined snapshot observations}
\usage{
ledgr_snapshot_quarantine(snapshot)
}
\arguments{
\item{snapshot}{A sealed \code{ledgr_snapshot} object.}
}
\value{
A tibble with quarantine identifiers, supplied identifiers and timestamps,
reasons, original row JSON, provenance JSON, and \code{disposition}
(\code{"excluded"} for a quarantined row, \code{"sealed_not_a_pulse"} for an
off-session bar). A snapshot with no
quarantined observations returns a zero-row tibble with the same columns.
}
\description{
Returns observations excluded while building a snapshot with
\code{invalid_observations = "quarantine"}, and, under reason
\code{off_session_bar}, valid bars that were sealed on no declared open-session
close and therefore never become a pulse of an availability-aware run. The
rows and reasons are read
from sealed snapshot evidence without adding a new interpretation.
Off-session records are derived from the hashed bars and sessions and are
not themselves part of the snapshot hash.
}
