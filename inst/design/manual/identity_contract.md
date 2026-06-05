# Identity Contract

**Status:** Maintainer reference for v0.1.9.1 identity surfaces.

**Audience:** maintainers and coding agents.

**Authority:** Synthesis of `../contracts.md`, the v0.1.9.1 spec packet,
and implementation traces. Binding decisions remain in those artifacts.

ledgr uses several identity fields because no single hash can answer every
question. Some fields identify concrete execution inputs. Some identify
authoring declarations. Some are JSON payloads used for replay or audit. Keep
those layers separate.

## Field Map

| Field | Purpose | Canonical source |
| --- | --- | --- |
| `config_hash` | Execution-config identity after removing store-local and run-local fields. | `config_hash_payload()` then `canonical_json()` and SHA-256. |
| `feature_set_hash` | Resolved concrete feature-set identity. | Sorted unique feature fingerprints through `ledgr_feature_set_hash()`. |
| `feature_params_hash` | User-supplied feature-parameter input identity. | Canonical JSON over the feature parameter list. |
| `alias_map_json` | Reopen/runtime alias lookup plus declaration identity evidence. | `ledgr_alias_map_storage()`. |
| `alias_map_hash` | Declaration-level alias identity. | Alias identity mappings, not concrete feature parameter values. |
| `alias_map_order` | Declaration-order diagnostic. | Original alias declaration order; not part of `config_hash`. |
| `cost_plan_json` | Canonical cost-model plan. | `ledgr_cost_plan_json()`. |
| `cost_model_hash` | Cost-model identity. | SHA-256 over `cost_plan_json`. |

## Config Hash

`config_hash` answers: "Is this the same logical execution config?"

It excludes:

- `db_path`;
- `data$snapshot_db_path`;
- `run_id`;
- `alias_map_order`.

It remains sensitive to true execution identity, including snapshot ID,
universe, strategy identity, strategy params, feature params, resolved
features, timing model, cost identity, opening state, execution seed, and
execution mode.

Feature definitions are sorted by feature ID before hashing so declaration
order alone does not change the hash. If a malformed feature definition lacks
an ID, the implementation preserves original order rather than guessing.

## Feature Identity

`feature_params_hash` and `feature_set_hash` answer different questions.

`feature_params_hash` records the parameter list supplied by the user.
`feature_set_hash` records the concrete feature definitions that resulted
after parameterized feature declarations were resolved. Two runs can share a
feature-parameter hash and still differ in feature definitions if the feature
map changes. Two runs can share an alias-map hash and differ in
`feature_set_hash` if the same parameterized declaration is resolved with
different concrete values.

For committed runs, `feature_set_hash` is stored in
`config$features$feature_set_hash` and is exposed through `ledgr_run_info()`
and `ledgr_run_list()`. For sweep candidates, it is stored in candidate
provenance and reproduction keys.

Stored runs created before v0.1.9.1 Batch 4 show `NA_character_` for
`feature_set_hash` because the field was not written. New runs always have a
deterministic value, including for empty feature sets.

## Alias Identity

The active alias map has two layers:

- runtime lookup: alias name -> concrete feature ID;
- declaration identity: alias name -> declaration-level identity.

`alias_map_json` stores enough to recover the runtime lookup map. When
declaration identity is available, it also includes identity mappings for
audit. `alias_map_hash` hashes the declaration identity layer. It is sensitive
to alias names and feature-declaration semantics, but not to concrete feature
parameter values. Concrete parameter values belong to `feature_set_hash`.

`alias_map_order` is kept for diagnostics and display. It is deliberately
excluded from `config_hash`.

## Cost Identity

The public cost API stores cost identity as:

- `cost_plan_json`: canonical serialized cost plan;
- `cost_model_hash`: SHA-256 over that plan.

These fields are execution identity for runs and sweep candidates. They are
also forward dependencies for walk-forward candidate identity. They do not
implement walk-forward or cost-grid selection by themselves.

## Implementation Trace

- `R/config-hash.R`: `config_hash()` and `config_hash_payload()`.
- `R/backtest.R`: config construction and `features$feature_set_hash`.
- `R/feature-alias-map.R`: alias lookup and declaration identity storage.
- `R/precompute-features.R`: feature-set hash helper and sweep candidate
  feature identity.
- `R/run-store.R`: run list/info projection from stored `config_json`.
- `R/cost-model.R`: cost plan JSON and cost-model hash.
