\name{ledgr_strategy_context}
\alias{ledgr_strategy_context}
\alias{ctx}
\title{Strategy pulse context columns}
\description{
The strategy pulse context passed to each \code{function(ctx, params)} call is
a flat named, lazy view of information known at one decision pulse.
}
\details{
Read current market, portfolio, eligibility, position-fact, and declared
feature columns by name, for example \code{ctx$close}, \code{ctx$buyable},
\code{ctx$entry_price}, or \code{ctx[["return_5"]]}. Every column is named by
instrument ID and aligned to \code{ctx$universe}. A column is built at most
once for that pulse. Returned values are pulse-frozen: editing one does not
alter the fold or a later read. \code{names(ctx)} and \code{str(ctx)} describe
the surface without forcing columns.

Active feature-map aliases are the primary declared-feature names. Registered
engine IDs are also dynamically readable. An unknown or retired field fails
with \code{ledgr_unknown_context_field}. The former \code{ctx$vec}, scalar
market and position readers, \code{ctx$feature()}, \code{ctx$features()},
\code{ctx$idx()}, and \code{ctx$tradable()} surfaces are retired. Use a flat
column read, ordinary named-vector indexing or \code{match()}, and explicit
vector logic.

\code{ctx$member} marks the current allocation population,
\code{ctx$held} marks nonzero pulse-start positions, and \code{ctx$buyable}
is membership with target restrictions applied. \code{ctx$holding_value} is
zero when unheld and the signed marked value when held; a held position without
a permissible mark is \code{NA_real_}. These columns have the same meaning in
dense and availability-aware runs.

Position facts come from the canonical accounting transition in the same
fold. \code{entry_price} is remaining FIFO basis divided by held quantity.
\code{entry_at} is the bar on which the current position opened and
\code{exit_at} is the bar of the last closing fill. Additions and partial exits
retain the opening anchor. A non-fill close clears entry facts without
inventing an exit, while a non-fill opening has unknown entry facts. The age
columns use the shared bar axis. Unknown anchors remain missing; no known prior
exit is represented by infinite \code{bars_since_exit}.

\code{ctx$flat()} returns a full named zero target and \code{ctx$hold()} returns
the pulse-start position target. The existing frame helpers \code{bar()},
\code{features_wide}, \code{feature_table}, and \code{bars} remain available.
Use \code{ctx$buyable & is.finite(ctx$close) & ctx$close > 0} for an explicit
current-close sizing predicate; it does not promise execution at the next open.

A strategy that returns \code{list(targets = ..., state_update = ...)} receives
that \code{state_update} as \code{ctx$state_prev} on the next pulse. Returning a
bare target keeps the previous state. State must be JSON-serializable plain
data. In every run \code{ctx$state_prev} is a list from the first pulse and its
\code{asset_state} is keyed by IDs on \code{ctx$universe}.

Strategies should return full named numeric target vectors. In an
availability-aware run \code{ctx$universe} is the decision axis and
\code{ctx$members} is the current allocation population; held nonmembers can
remain on the former without entering the latter.
}
\section{Complete Public Surface}{
The table is authoritative for callback-visible non-private members.
\code{Daxis} means \code{ctx$universe}. Every plane is a named vector aligned
to that axis. \code{declared_feature} represents each active alias and each
unmapped registered engine ID. Dot-prefixed engine state is private.

\preformatted{
scope | member | applies | shape | axis | units | missingness | counterpart
top | run_id | all | character_scalar | none | identifier | never | none
top | ts_utc | all | character_scalar | none | UTC_time | never | none
top | universe | all | character_vector | Daxis | instrument_id | empty_allowed | plane_names
top | bars | all | data_frame | current_Daxis_rows | market_data | rows_may_be_absent | bar
top | feature_table | all | data_frame | current_Daxis_rows | feature_value | warmup_NA_or_schema_only | declared_feature
top | cash | all | numeric_scalar | portfolio | currency | never | none
top | equity | all | numeric_scalar | portfolio | currency | never | none
top | seed | all | nullable_scalar | none | integer_seed | NULL_allowed | none
top | pulse_seed | all | nullable_scalar | none | integer_seed | NULL_allowed | none
top | state_prev | all | list | portfolio_and_Daxis | strategy_state | asset_state_from_first_pulse | none
top | members | all | character_vector | Daxis_subset | instrument_id | empty_allowed | member
top | bar | all | function | instrument_id | OHLCV_row | absent_row_errors | bars
top | flat | all | function | Daxis | target_quantity | never | none
top | hold | all | function | Daxis | target_quantity | never | position
top | features_wide | all | data_frame | current_Daxis_rows | feature_value | warmup_NA | declared_feature
plane | open | all | numeric_vector | Daxis | price | NA_allowed | bars
plane | high | all | numeric_vector | Daxis | price | NA_allowed | bars
plane | low | all | numeric_vector | Daxis | price | NA_allowed | bars
plane | close | all | numeric_vector | Daxis | price | NA_allowed | bars
plane | volume | all | numeric_vector | Daxis | source_units | NA_allowed | bars
plane | position | all | numeric_vector | Daxis | quantity | never | hold
plane | held | all | logical_vector | Daxis | flag | never | position
plane | member | all | logical_vector | Daxis | flag | never | members
plane | buyable | all | logical_vector | Daxis | flag | never | member
plane | holding_value | all | numeric_vector | Daxis | currency | NA_when_held_unpriced | position
plane | entry_price | all | numeric_vector | Daxis | price | NA_when_unheld_or_unknown | position
plane | entry_at | all | double_vector | Daxis | UTC_time | NA_when_unheld_or_unknown | position
plane | exit_at | all | double_vector | Daxis | UTC_time | NA_when_no_known_exit | position
plane | bars_since_entry | all | numeric_vector | Daxis | bars | NA_when_unheld_or_unknown | entry_at
plane | bars_since_exit | all | numeric_vector | Daxis | bars | Inf_when_no_known_exit | exit_at
plane | declared_feature | all | numeric_vector | Daxis | feature_value | warmup_NA | feature_table
}
}
\section{Feature Object Compatibility}{
\code{ledgr_experiment(features = ...)} accepts static indicators, lists of
indicators, named lists, and feature maps. Parameterized feature sweeps should
use active aliases with \code{ledgr_feature_map()}. Read each declared feature
once as its flat named context column.
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
  ready <- ledgr_passed_warmup(ctx, ctx$ret_5)
  buy <- ready & ctx$buyable & ctx$ret_5 > params$min_return
  targets[buy] <- params$qty
  targets
}
}
