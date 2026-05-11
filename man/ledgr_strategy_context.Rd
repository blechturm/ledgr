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
\item \code{ctx$open(id)}, \code{ctx$high(id)}, \code{ctx$low(id)},
\code{ctx$close(id)}, \code{ctx$volume(id)}: current bar values for one
instrument.
\item \code{ctx$bar(id)}: the current OHLCV row for one instrument.
\item \code{ctx$feature(id, feature_id)}: one registered feature value for one
instrument, addressed by ledgr's exact engine feature ID such as
\code{"return_5"}.
\item \code{ctx$features(id, feature_map)}: mapped feature values for one
instrument, returned as a named numeric vector keyed by feature-map aliases.
\item \code{ctx$position(id)}: current simulated position for one instrument.
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

Strategies should return full named numeric target vectors. The helpers
\code{ctx$flat()} and \code{ctx$hold()} are the safest starting points because
they already have one entry for every instrument in \code{ctx$universe}.
}
\section{Feature Object Compatibility}{
\code{ledgr_experiment(features = ...)} accepts static indicators, lists of
indicators, named lists, feature maps, and feature factories of the form
\code{function(params)}. Pulse inspection helpers accept static feature shapes.
Inside the strategy context, \code{ctx$feature()} reads one engine feature ID and
\code{ctx$features()} requires a \code{ledgr_feature_map}. Lower-level or legacy
helpers may be narrower; the experiment-first workflow is the canonical public
path for feature maps.
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
    if (passed_warmup(x) && x[["ret_5"]] > params$min_return) {
      targets[id] <- params$qty
    }
  }
  targets
}
}
