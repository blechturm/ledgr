# The feature adapters (feature-engine stages 2-3 synthesis, rules 1-2;
# Cut 24, LDG-3259). One fixed, ordered list of package-owned descriptions:
# the ledgr built-ins first, then TTR. Certification, the calculator
# dispatch, source validation and inspection, the parameter constructors,
# dependency provenance and the feature-engine version read this list
# instead of naming an adapter. No discovery, registration, mutable hook or
# public schema: the list is code. Describing the adapters constructs no
# indicator and loads no backend.
#
# Each description is a plain list:
#   name, package     the adapter and its backend package;
#   catalogue_rows    function(row): its catalogue rows, built with the
#                     catalogue's row builder, in catalogue order;
#   constructors      the public constructors the parameter registry exposes;
#   candidates        function(def): its canonical candidates for a
#                     definition, in certification order, each list(adapter,
#                     certification, kind, indicator); the constructors carry
#                     the input mapping, forwarded arguments, width, readiness
#                     and history-class rules, variants and output discovery;
#   certified         function(canonical, declarations): what a matched
#                     certification adds for the adapter's calculator (TTR:
#                     the resolved function and the raw-call key);
#   segment           function(cert, inputs, fields, rows, cache): the
#                     adapter's calculation of one segment (TTR: raw call,
#                     output selection and derivation, normalisation, raw
#                     sharing within the preparation-local cache);
#   bind              the helpers whose code the feature-engine version binds
#                     for this adapter.
ledgr_feature_adapters <- function() {
  list(
    ledgr = ledgr_feature_adapter_ledgr(),
    TTR = ledgr_feature_adapter_ttr()
  )
}

# The indicator `source` values: one per adapter, then custom.
ledgr_indicator_sources <- function() {
  c(names(ledgr_feature_adapters()), "custom")
}
