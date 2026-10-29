# Probe findings

The smallest executed package probe confirms that ledgr already has a typed
accounting seam in memory:

- `ledgr_output_sink_memory()` retains `cash_delta`, `position_delta`,
  `event_realized`, `event_cost_basis` and `meta` as typed values;
- that sink reports `serialize_meta_json = FALSE`;
- the durable accounting surface still exposes the eleven-column
  `ledger_events` shape whose only type-specific carrier is `meta_json`.

Source inspection after the probe found four closed event sources: fills,
opening positions, corporate-action cash and dispositions. Fill JSON is fully
redundant with typed columns and exact arithmetic. Opening-position JSON is a
source discriminator plus values duplicated by `qty` and `price`.
Corporate-action cash and dispositions carry genuine evidence: source-fact and
policy identities, entitlement inputs, valuation provenance, late-arrival and
terminal-policy decisions. Those fields cannot be dropped merely because JSON
is removed.

The current readers confirm the distinction. Accounting replay and lot replay
need typed economic effects. Corporate-action settlement needs source-fact IDs
to prevent duplicate posting. Corporate-action and terminal result surfaces
need policy and valuation evidence. Therefore the useful change is a typed
durable boundary, not deletion of the event evidence model.
