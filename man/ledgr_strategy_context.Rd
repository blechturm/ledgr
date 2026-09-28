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
\item \code{ctx$universe}: character vector on the current decision axis. In
availability-aware runs this can include held nonmembers that remain necessary
for valuation and disposition.
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
\item \code{ctx$vec$position}: current simulated positions for the full
universe, aligned to \code{ctx$universe}.
\item \code{ctx$cash} and \code{ctx$equity}: current simulated portfolio state.
\item \code{ctx$state_prev}: the \code{state_update} the strategy returned at
the previous pulse.
\item \code{ctx$flat()}: full named target vector initialized to zero.
\item \code{ctx$hold()}: full named target vector initialized to current
positions.
\item \code{ctx$tradable()}: convenience subset of current members that are
admissible and priced in an availability-aware run; in a dense run it returns
instruments with a finite positive close. A permissible stale mark can satisfy
the predicate without supplying a current sizing close, and the result does not
promise execution at the next open.
}

Feature IDs and feature-map aliases are different namespaces.
\code{ctx$feature()} uses engine IDs from \code{ledgr_feature_id()}.
\code{ctx$features()} uses a \code{ledgr_feature_map} object and returns values
named by alias. Unknown engine feature IDs fail loudly; warmup for a known
feature is represented by \code{NA_real_}.

For universes of at least 100 instruments, reading one exact feature ID through
\code{ctx$feature()} once per instrument emits one
\code{ledgr_scalar_accessor_loop} warning per run and names
\code{ctx$vec$feature(feature_id)} as the whole-universe alternative. Mapped
\code{ctx$features(id)} reads are not recorded because an active-alias map has
no whole-universe accessor yet; warning without a replacement would not be
actionable.

\code{ctx$idx(id)} fails loudly for unknown instruments by default. Use
\code{ctx$idx(id, missing = "na")} only when an explicit \code{NA_integer_}
sentinel is part of the strategy logic.

\code{ctx$position(id)} is the scalar pulse-start state read and
\code{ctx$vec$position} is its unnamed decision-axis-aligned plane. Use
\code{ctx$idx(id)} to cross between them. \code{ctx$hold()} constructs named
portfolio intent from that state; editing its result does not mutate either
state read.

A strategy that returns \code{list(targets = ..., state_update = ...)} receives
that \code{state_update} as \code{ctx$state_prev} at the next pulse; returning a
bare target keeps the previous state. State must be JSON-serializable plain
data. In a dense run \code{ctx$state_prev} is \code{NULL} on the first pulse. In
an availability-aware run it is a list from the first pulse and carries
\code{asset_state}, a list keyed by the instrument IDs in \code{ctx$universe}:
entries for instruments that leave the axis are dropped, returning instruments
start from \code{list()}, and a returned entry for an ID outside the axis fails
with \code{ledgr_invalid_strategy_state}.

Strategies should return full named numeric target vectors. The helpers
\code{ctx$flat()} and \code{ctx$hold()} are the safest starting points because
they already have one entry for every instrument in \code{ctx$universe}.
In availability-aware runs, \code{ctx$universe} is the decision axis and
\code{ctx$members} is the current allocation population; held nonmembers may
remain on the former without entering the latter. Use \code{ctx$tradable()} as
the explicit convenience predicate for admissible and priced members. A stale
permissible mark can satisfy that predicate while still failing current-close
sizing, so it guarantees neither a sizing close nor execution at the next open.
}
\section{Complete Public Surface}{
The table below is authoritative for callback-visible, non-private members.
\code{Daxis} means \code{ctx$universe}; every plane is positional and unnamed.
Cross a plane with IDs through \code{ctx$idx()}. Dot-prefixed engine state is
private and deliberately absent.

\preformatted{
scope | member | applies | shape | axis | units | missingness | counterpart
top | run_id | all | character_scalar | none | identifier | never | none
top | ts_utc | all | character_scalar | none | UTC_time | never | none
top | universe | all | character_vector | Daxis | instrument_id | empty_allowed | vec.id
top | bars | all | data_frame | current_Daxis_rows | market_data | rows_may_be_absent | bar
top | feature_table | all | data_frame | current_Daxis_rows | feature_value | warmup_NA_or_schema_only | feature
top | cash | all | numeric_scalar | portfolio | currency | never | none
top | equity | all | numeric_scalar | portfolio | currency | never | none
top | seed | all | nullable_scalar | none | integer_seed | NULL_allowed | none
top | pulse_seed | all | nullable_scalar | none | integer_seed | NULL_allowed | none
top | state_prev | all | nullable_list | portfolio_and_Daxis | strategy_state | NULL_on_first_dense_pulse | none
top | availability_active | availability | logical_scalar | none | flag | never | none
top | members | availability | character_vector | Daxis_subset | instrument_id | empty_allowed | vec.member
top | bar | all | function | instrument_id | OHLCV_row | absent_row_errors | bars
top | open | all | function | instrument_id | price | NA_allowed | vec.open
top | high | all | function | instrument_id | price | NA_allowed | vec.high
top | low | all | function | instrument_id | price | NA_allowed | vec.low
top | close | all | function | instrument_id | price | NA_allowed | vec.close
top | volume | all | function | instrument_id | source_units | NA_allowed | vec.volume
top | position | all | function | instrument_id | quantity | never | vec.position
top | idx | all | function | instrument_id | Daxis_index | optional_NA | vec.id
top | flat | all | function | Daxis | target_quantity | never | none
top | hold | all | function | Daxis | target_quantity | never | vec.position
top | tradable | all | function | Daxis_subset | instrument_id | empty_allowed | mode_specific_planes
top | features_wide | all | data_frame | current_Daxis_rows | feature_value | warmup_NA | features
top | feature | all | function | instrument_id | feature_value | warmup_NA | vec.feature
top | features | all | function | instrument_id | feature_value | warmup_NA | vec.feature
top | vec | all | list | Daxis | mixed | plane_specific | scalar_counterparts
plane | id | all | character_vector | Daxis | instrument_id | never | universe
plane | open | all | numeric_vector | Daxis | price | NA_allowed | open
plane | high | all | numeric_vector | Daxis | price | NA_allowed | high
plane | low | all | numeric_vector | Daxis | price | NA_allowed | low
plane | close | all | numeric_vector | Daxis | price | NA_allowed | close
plane | volume | all | numeric_vector | Daxis | source_units | NA_allowed | volume
plane | position | all | numeric_vector | Daxis | quantity | never | position
plane | feature | all | function | Daxis | feature_value | warmup_NA | feature
plane | member | availability | logical_vector | Daxis | flag | never | members
plane | held | availability | logical_vector | Daxis | flag | never | none
plane | target_restricted | availability | logical_vector | Daxis | flag | never | none
plane | target_restriction_reason | availability | character_vector | Daxis | reason_token | empty_string_allowed | none
plane | admissible | availability | logical_vector | Daxis | flag | never | tradable
plane | priced | availability | logical_vector | Daxis | flag | never | tradable
plane | mark_age | availability | integer_vector | Daxis | sessions | NA_when_unpriced | none
plane | risk_mark | availability | numeric_vector | Daxis | price | NA_when_unpriced | none
plane | mark_source | availability | character_vector | Daxis | source_token | empty_when_unpriced | none
}
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
