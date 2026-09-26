\name{ledgr_run_completion}
\alias{ledgr_run_completion}
\alias{print.ledgr_run_completion}
\title{Read one run's completion evidence}
\usage{
ledgr_run_completion(bt)

\method{print}{ledgr_run_completion}(x, ...)
}
\arguments{
\item{bt}{A \code{ledgr_backtest} object.}

\item{x}{A \code{ledgr_run_completion} object.}

\item{...}{Unused.}
}
\value{
A \code{ledgr_run_completion} list. When the run has no completion row,
\code{completion_evidence_available} is \code{FALSE} and every evidence field
carries a typed missing value. The print method returns \code{x} invisibly.
}
\description{
Returns the persisted answer to whether a run covered its requested window,
including the achieved window, stop reason, and affected exposure recorded at
an incomplete boundary. It performs no new completion judgement.
}
