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
reasons, original row JSON, and provenance JSON. A snapshot with no
quarantined observations returns a zero-row tibble with the same columns.
}
\description{
Returns observations excluded while building a snapshot with
\code{invalid_observations = "quarantine"}. The rows and reasons are read from
sealed snapshot evidence without adding a new interpretation.
}
