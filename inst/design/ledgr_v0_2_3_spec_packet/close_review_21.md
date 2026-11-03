# Workstream 21 close review

**Mode:** Type 1 close review, independent clean context.

**Reviewed range:** `61984c0a..de35535e`.

**Verdict:** CHANGES_REQUIRED.

The migration is directionally complete and the review found no runtime
product defect or design question. Five bounded documentation, contract,
detector and evidence corrections are required before acceptance.

## Findings

### F1 — Missing-bar teaching is ambiguous

The public context help and the feature and execution manuals must say that
`is.na(ctx$close)` means no bar was observed for that instrument at the pulse.
It does not classify why the observation is absent. Expected-session and
carried-input evidence comes from the causal history readers.

### F2 — Two inspection boundaries are not binding

`contract-context-inspection` must bind synthesis boundaries B5 and B10:
pulse-snapshot contexts carry none of the retired feature-parameter or alias
metadata, and the inspection helpers consume the supplied context without
sealing, hashing, authorization, store queries or provenance construction.

### F3 — The exact-name census can pass without evidence

The source-checkout branch must require each intended root and a nonzero file
population. Whole-file allowlists must become exact hit counts or line-level
allowances, so adding a supported retired use to a refusal-test file fails.
The detector needs controls for a zero-file scan and an added use in a formerly
allowlisted file. The built-package branch must retain the established
independent checkout-context check.

### F4 — WS21 records lack durable provenance

The profile paths and commands, explicit UTF-8 locale, initial default-locale
environmental failure and response-probe source/environment/command must be
recorded durably. The small-list timing label is a hand-copied primitive list
bind, not a P2 implementation. A metadata sidecar should carry this provenance
without changing the profile runner's CSV schema.

### F5 — Two governance statements remain stale

The typed-fold-carrier pipeline row must stop carrying the discharged WS6
context-frame obligation. The private context-field contract list must include
`.schedule_query`. Concurrent manual-source changes from `1464a835`,
`b7389f88` and `d30f31d0` also require their rendered Markdown counterparts;
that reconciliation is governance maintenance, not WS21 product scope.

## Areas found clean

- Maintained runtime consumers use the flat pulse surface.
- The peer fixture remains an output comparison rather than a re-recorded
  oracle.
- The prepared numeric timestamp correction at `5e21ba51` removes the
  review-introduced hot-path parse without changing behavior.
- Fast and supported-locale review profile records, the fixture lane, source
  build and package check are passing on the recorded candidate.
- The review raised no compatibility path, new helper, identity work, query,
  sealing or provenance mechanism.

The bounded corrections need focused confirmation; the long profiles and
package check need not be rerun unless packaged source changes.
