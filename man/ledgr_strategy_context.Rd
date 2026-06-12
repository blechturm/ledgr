\name{ledgr_strategy_context}
\alias{ledgr_strategy_context}
\alias{ctx}
\title{Strategy pulse context accessors}
\description{
The strategy pulse context is the object passed to every
\code{function(ctx, params)} strategy at one decision time. It exposes only
data that is known at that pulse: current bars, registered current feature
values, current simulated positions, cash, equity, and helpers for building
target vectors.
}
\details{
Common accessors:
\itemize{
\item \code{ctx$ts_utc}: current decision timestamp.
\item \code{ctx$universe}: character vector of instruments in the run.
\item \code{ctx$idx(id)}: 1-based universe position for one instrument.
\item \code{ctx$open(id)}, \code{ctx$high(id)}, \code{ctx$low(id)},
\code{ctx$close(id)}, \code{ctx$volume(id)}: current bar values for one
instrument.
\item \code{ctx$vec$open}, \code{ctx$vec$high}, \code{ctx$vec$low},
\code{ctx$vec$close}, \code{ctx$vec$volume}: current bar values for the full
universe, aligned to \code{ctx$universe}.
\item \code{ctx$bar(id)}: the current OHLCV row for one instrument.
\item \code{ctx$feature(id, feature_id)}: one registered feature value for one
instrument, addressed by ledgr's exact engine feature ID such as
\code{"return_5"}.
\item \code{ctx$vec$feature(feature_id)}: one registered feature value vector
for the full universe, aligned to \code{ctx$universe}.
\item \code{ctx$features(id, feature_map)}: mapped feature values for one
instrument, returned as a named numeric vector keyed by feature-map aliases.
\item \code{ctx$position(id)}: current simulated position for one instrument.
\item \code{ctx$vec$positions}: current simulated positions for the full
universe, aligned to \code{ctx$universe}.
\item \code{ctx$cash} and \code{ctx$equity}: current simulated portfolio state.
\item \code{ctx$flat()}: full named target vector initialized to zero.
\item \code{ctx$hold()}: full named target vector initialized to current
positions.
}

Feature IDs and feature-map aliases are different namespaces.
\code{ctx$feature()} uses engine IDs from \code{ledgr_feature_id()}.
\code{ctx$features()} uses a \code{ledgr_feature_map} object and returns values
named by alias. Unknown engine feature IDs fail loudly; warmup for a known
feature is represented by \code{NA_real_}.

\code{ctx$idx(id)} fails loudly for unknown instruments by default. Use
\code{ctx$idx(id, missing = "na")} only when an explicit \code{NA_integer_}
sentinel is part of the strategy logic.

\code{ctx$positions} is a public pulse-start snapshot. \code{ctx$vec$positions}
is the aligned vector view of the same pulse-known state. Strategy code should
treat all context fields and vector views as read-only.

Strategies should return full named numeric target vectors. The helpers
\code{ctx$flat()} and \code{ctx$hold()} are the safest starting points because
they already have one entry for every instrument in \code{ctx$universe}.
}
\section{Feature Object Compatibility}{
\code{ledgr_experiment(features = ...)} accepts static indicators, lists of
indicators, named lists, and feature maps as the canonical public feature
shapes. Compatibility feature factories of the form \code{function(params)}
remain available for old flat-grid and advanced exact-ID workflows, but new
parameterized feature sweeps should use active aliases with
\code{ledgr_feature_map()}. Pulse inspection helpers accept static feature
shapes. Inside the strategy context, \code{ctx$feature()} reads one engine
feature ID and \code{ctx$features()} requires a \code{ledgr_feature_map}.
Lower-level or legacy helpers may be narrower; the experiment-first workflow is
the canonical public path for feature maps.
}
\section{Articles}{

Strategy authoring:
\code{vignette("strategy-development", package = "ledgr")}
\code{system.file("doc", "strategy-development.html", package = "ledgr")}

Indicator IDs and feature maps:
\code{vignette("indicators", package = "ledgr")}
\code{system.file("doc", "indicators.html", package = "ledgr")}
}
\examples{
features <- ledgr_feature_map(
  ret_5 = ledgr_ind_returns(5),
  sma_10 = ledgr_ind_sma(10)
)

strategy <- function(ctx, params) {
  targets <- ctx$flat()
  for (id in ctx$universe) {
    x <- ctx$features(id, features)
    if (ledgr_passed_warmup(x) && x[["ret_5"]] > params$min_return) {
      targets[id] <- params$qty
    }
  }
  targets
}
}
