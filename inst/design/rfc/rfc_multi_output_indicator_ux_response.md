# RFC Response: Multi-Output Indicator UX And Contract

**Status:** Reviewer response.
**Date:** 2026-05-15
**RFC:** `inst/design/rfc/rfc_multi_output_indicator_ux.md`
**Reviewer:** Codex

---

## Overall Assessment

The RFC identifies a real UX and performance problem. Multi-output indicators
are currently usable, but the one-output-per-constructor pattern is verbose,
easy to make inconsistent, and computationally wasteful during precompute.

I would not extend the core `series_fn()` contract first. The correct first
move is an authoring-layer multi-output bundle that materializes to ordinary
single-output `ledgr_indicator` objects. That solves the user-facing
consistency problem without changing feature fingerprints, feature payload
shape, sweep provenance, or the fold core.

Recommended direction:

```text
v0.1.8.x / adapter-prep:
  add multi-output authoring bundle
  flatten it through feature maps / experiment features
  preserve existing single-output indicator semantics

later optimization sprint:
  add grouped precompute / multi_series_fn-style batching behind the same
  user-facing bundle shape
```

This is close to Option C, but with one important refinement: do not make
`ledgr_ind_ttr()` return different object types depending on `output` vs
`outputs`. Introduce an explicit bundle helper or bundle class instead.

---

## Corrections To The RFC

### TTR Output Errors Already Surface At Construction

The RFC says wrong output names surface only at precompute time. That is not
true for the current TTR adapter. `ledgr_ind_ttr()` calls
`ledgr_ttr_validate_output_contract()` during construction, which runs the TTR
function on synthetic bars and routes through `ledgr_ttr_select_output()`.

So for TTR, output discovery is still not ergonomic, but invalid output names
already fail early:

```text
ledgr_ind_ttr(...)
  -> ledgr_ttr_validate_output_contract()
  -> ledgr_ttr_call()
  -> ledgr_ttr_select_output()
```

The discoverability problem remains, but the failure timing should be corrected
in the RFC thread.

### `ledgr_feature_map()` Does Not Currently Accept Inline Lists

`ledgr_feature_map()` currently expects `...` to be named
`ledgr_indicator` objects. It does not flatten a named list or bundle supplied
as one argument.

Plain `features = list(...)` workflows can already accept a list of indicators,
and `ledgr_feature_id()` can inspect a list of indicators. Feature maps are
stricter because aliases are part of their contract.

That means Option A is not just a constructor convenience. If it returns a
named list, it also needs one of:

- feature-map flattening for an explicit multi-output bundle class;
- a helper that returns a `ledgr_feature_map` directly;
- or documentation that users must splice / `do.call()` the returned list.

The last option is not good enough for the UX problem this RFC is trying to
solve.

---

## Recommended Shape

### 1. Add An Authoring Bundle, Not A Polymorphic Indicator Constructor

Avoid this shape:

```r
ledgr_ind_ttr("BBands", input = "close", output = "up", n = 20)
# returns ledgr_indicator

ledgr_ind_ttr("BBands", input = "close", outputs = c(...), n = 20)
# returns list / bundle / feature_map
```

That return-type switch is a footgun. Existing users and tests reasonably expect
`ledgr_ind_ttr()` to construct one indicator.

Prefer an explicit helper, for example:

```r
ledgr_ind_ttr_outputs(
  "BBands",
  input = "close",
  outputs = c(bb_dn = "dn", bb_mavg = "mavg", bb_up = "up"),
  n = 20
)
```

The return value should be an authoring object that behaves like a named list of
ordinary `ledgr_indicator` objects, with optional class/attributes for printing
and validation:

```text
class: ledgr_indicator_bundle, list
entries: named ledgr_indicator objects
attributes: backend, function name, input shape, output map, shared params hash
```

The object should not be a runtime feature source. It is an authoring
convenience that flattens before execution.

### 2. Flatten Bundles At Feature Boundaries

The bundle should be accepted anywhere feature declarations are accepted:

```r
features <- ledgr_feature_map(
  ledgr_ind_ttr_outputs(
    "BBands",
    input = "close",
    outputs = c(bb_dn = "dn", bb_mavg = "mavg", bb_up = "up"),
    n = 20
  ),
  rsi = ledgr_ind_ttr("RSI", input = "close", n = 14)
)
```

The flattening rule should be narrow and explicit:

```text
flatten ledgr_indicator_bundle objects
accept ledgr_indicator objects
reject arbitrary nested lists
```

Do not make `ledgr_feature_map()` a general recursive list normalizer. That
would blur aliases and create ambiguous naming behavior. Bundles can carry a
clear contract: their entry names are strategy-facing aliases.

The same flattening helper should be used by:

- `ledgr_feature_map()`;
- `ledgr_experiment_validate_features()`;
- `ledgr_experiment_materialize_features()`;
- precompute feature resolution.

This keeps static feature lists, feature maps, and `features = function(params)`
consistent.

### 3. Keep External Fingerprints As N Output-Specific Fingerprints

For the first implementation, each output should remain an ordinary feature with
its own indicator ID and fingerprint.

That preserves the current contracts:

- feature IDs are scalar strings used by `ctx$feature()`;
- row-level sweep provenance stores candidate-specific feature fingerprints;
- precomputed payloads are keyed by feature fingerprint;
- feature-set hashes are hashes over output-specific fingerprints;
- existing TTR parity tests continue to apply per output.

The bundle should guarantee shared params at construction time, but it should
not introduce a new public fingerprint shape yet.

### 4. Design Future Batching Behind The Bundle

The later optimization should not force users to rewrite feature factories.
The bundle can become the stable user-facing object, while precompute later
learns to group equivalent output-specific indicators by a shared computation
key:

```text
external identity:
  output-specific feature fingerprint, unchanged

internal optimization:
  computation_fingerprint = backend + function + input + shared args
  output_key = output column / derived output
```

The precompute scheduler can then:

1. group feature defs by computation fingerprint;
2. call the backend once per instrument and group;
3. validate each named output with the existing numeric-vector normalizer;
4. populate the existing payload slots keyed by output-specific fingerprint.

This gives the performance win without changing the strategy-visible feature
contract.

---

## Answers To Open Questions

### Q1. Is This Acute Before The TA-Lib Adapter Ships?

Yes, for UX consistency. The adapter should not teach a second long-form
multi-output idiom if the package already knows the pattern is awkward.

But this does not mean `multi_series_fn` must land before the adapter. It means
the public adapter surface should either:

- ship with an explicit bundle helper; or
- clearly mark one-output-per-call as the low-level form and keep the ergonomic
  helper as the next adapter-prep ticket.

Do not reopen v0.1.8.0 for this. Put it in the next v0.1.8.x adapter/design
slice.

### Q2. Should `ledgr_feature_map()` Accept Named Lists?

Not arbitrary named lists. It should accept a specific
`ledgr_indicator_bundle` and flatten it.

Arbitrary list flattening creates alias ambiguity. A classed bundle gives the
package a place to enforce:

- every entry is a `ledgr_indicator`;
- entry names are valid aliases;
- entry feature IDs are unique;
- all entries share the intended backend/function/input/args identity.

### Q3. Is The Consistency Guarantee The Right Primitive?

Yes, as an opt-in primitive.

Users can still deliberately create separate indicators with different params.
The bundle means: "these outputs are from one shared indicator computation."
Inside that object, shared params should be enforced. Outside that object,
separate one-output constructors remain valid.

### Q4. Fingerprint Shape For `multi_series_fn`

Keep N external fingerprints. Add a shared computation fingerprint only as
internal scheduler metadata when batching is implemented.

This avoids changing existing provenance and cache semantics while still
allowing precompute deduplication later.

### Q5. Roadmap Placement

Split the work:

```text
adapter-prep / v0.1.8.x:
  multi-output bundle UX
  feature-map / experiment flattening
  TTR retrofit if accepted
  TA-Lib adapter can use the same pattern

optimization sprint:
  grouped precompute / multi_series_fn-style batching
  output discovery helpers if needed
```

The UX problem should land before TA-Lib becomes a documented public adapter
idiom. The performance work can wait until it is profiled against real adapter
payloads.

### Q6. TTR Adapter Retrofit

Yes, if the bundle helper is accepted, retrofit TTR immediately enough to keep
the public examples consistent.

Do not leave TA-Lib with a bundle helper and TTR with only repeated
one-output calls. That would make the adapter surface feel accidental. The
low-level `ledgr_ind_ttr(output = ...)` path should remain supported, but the
docs should teach the bundle for multi-output use.

---

## Minimal Acceptance Criteria For A Future Ticket

A first implementation ticket should prove:

- `ledgr_ind_ttr_outputs()` or equivalent returns a named bundle of ordinary
  `ledgr_indicator` objects.
- Bundle entries have unique feature IDs and deterministic output-specific
  fingerprints.
- Bundle construction enforces one shared backend/function/input/args set.
- `ledgr_feature_map()` accepts and flattens bundles without accepting
  arbitrary nested lists.
- `ledgr_experiment(features = bundle)` and `features = function(params)
  bundle` materialize to plain indicator lists.
- Existing one-output `ledgr_ind_ttr()` behavior and IDs remain unchanged.
- TTR BBands and MACD examples use the new bundle helper in docs while keeping
  the scalar-output constructor documented as the low-level form.

Do not include precompute batching in that first ticket. Treat batching as a
second ticket with separate parity tests and feature-engine-version handling.

---

## Verdict

Proceed with the RFC, but narrow the first decision:

```text
Accept: multi-output authoring bundle as UX and consistency layer.
Defer: multi_series_fn / grouped precompute batching.
Avoid: polymorphic ledgr_ind_ttr() return types and arbitrary nested-list
       feature-map semantics.
```

This keeps the package's core invariant intact: strategies still read scalar
feature IDs, precompute still produces aligned numeric vectors per feature, and
sweep/run provenance still works with output-specific fingerprints.
