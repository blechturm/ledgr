# Cut 16 Workstream 40 closeout: causal facts and history identity

Implementation commit: `80c86012`

Status: ready for independent Type 1 close review, with the first hosted
rule-4 Ubuntu golden-root result still to be observed after push.

## Necessity and scope

The accepted historical-projection synthesis requires one causal factual and
identity boundary before any shared history representation is built. The old
tree collapsed effective and knowledge time in prepared facts, normalized
civil dates through UTC midnight, had no trading-status correction graph, and
did not bind the accepted history treatment policy into experiment identity.
Those are correctness and identity gaps; a representation ticket could not
safely paper over them.

This workstream implements only that foundation. It does not add a history
frame, history matrix, shared substrate, indicator treatment or worker
transport. Dense execution remains outside the new availability-only policy.

## LDG-3057: factual prerequisite

### Separate clocks

Fact construction and prepared availability retain effective and knowledge
instants separately. LCL-0286/LTB-0288 writes different values, inspects the
normalized row literally, and checks the provider immediately before and at
knowledge arrival. The two-clock fixture therefore fails a collapsed
`pmax(effective_from, knowledge_time)` representation.

### Civil dates

Date-backed fact fields retain the supplied civil date, the resolved instant,
venue time zone and calendar identity in `civil_time_json`. A Date boundary in
a run, sweep, experiment window or fold resolves through exactly one declared
venue session and refuses zero or multiple matches. LCL-0282/LTB-0284 covers
Sydney, Honolulu and New York and pins their session-derived instants rather
than UTC midnight.

### Trading-status correction chains

One graph validator owns correction semantics before ordinary precedence is
applied. LCL-0283/LTB-0285 covers monotone and non-monotone knowledge order,
successors that start earlier, early-ending refusal, sibling and unrelated
tied conflicts, transitive supersession before precedence, revival,
same-assertion component exemption, cycles, dangling links and agreement
between classification and runtime resolution.

### Corporate-action clocks

LCL-0284/LTB-0286 distinguishes the three accepted cases. An event clock with
no knowledge clock is known when effective; a row with no event or knowledge
clock remains audit-only; and knowledge without an event clock raises
`ledgr_corporate_action_clock_missing` only once that knowledge is available.
The condition carries the fact and instrument IDs and all three clock fields.

### Current sealed format

Snapshot hash rule 4 covers the civil-time fact bytes and store format 121 is
the sole current store. The rule-4 conformance corpus replaces the rule-3
fixture and is pinned locally on Windows. Rule-3 snapshots and schema-120
stores refuse through current-format conditions. Searches and current-only
census check mode find no migration, fallback or legacy reader. The dedicated
Ubuntu workflow step is present, but its first committed run remains a hosted
post-push evidence item.

## LDG-3058: history policy and identity

`ledgr_history_policy()` is the canonical experiment-level policy. Its default
is a five-expected-session price-input carry, output carry off and no segment
override. `NULL` disables input carry; output carry requires an explicitly
finite positive age. LCL-0285/LTB-0287 checks default equivalence, independent
input/output controls, invalid ages and config-identity sensitivity.

Identity advances to rule 4. The history payload binds axis and cutoff rules,
policy, treatment implementation and declared-versus-assumed price basis. It
does not bind worker or resource controls. New run, saved-sweep and
walk-forward records carry rule 4; earlier identities refuse without a parser,
inference or missing-marker fallback.

Explicit precompute carries the same history identity. LTB-0290 mocks the
candidate-execution boundary and proves that a changed policy, axis or cutoff
refuses before any candidate executes. Strict and treated requests therefore
cannot silently share an artifact.

## Detecting evidence

The registered blocks and claims are:

| Claim | Block | Boundary |
|---|---|---|
| LCL-0282 | LTB-0284 | civil dates and public Date boundaries |
| LCL-0283 | LTB-0285 | correction-chain graph semantics |
| LCL-0284 | LTB-0286 | corporate-action clock cases |
| LCL-0285 | LTB-0287, LTB-0290 | policy/config and precompute identity |
| LCL-0286 | LTB-0288 | distinct prepared clocks |
| LCL-0287 | LTB-0289 | bounded field-wise civil metadata encoding |

The new history-foundation file passes 88 expectations. Its expected values
come from literal civil/session instants, literal graph rows, direct normalized
fact inspection, provider cutoffs and a candidate-execution counter rather
than agreement among public entry points alone.

## Seven-shape walk

The implementation was checked against the seven shapes in
`optimization_coding_style.qmd`.

1. No one-row data-frame growth was added. Civil metadata is assembled by a
   fixed field vocabulary and written once per field, not once per fact row.
2. No full fact table is subset repeatedly by instrument on a production
   pulse path. Correction adjacency is prepared once at construction.
3. Civil values and clocks are normalized by field; no per-row timestamp or
   JSON formatter was introduced.
4. LTB-0289 counts the canonical NDJSON boundary on 120 rows and bounds calls
   by the fixed clock vocabulary, catching a row-wise JSON regression.
5. Boundary resolution performs one bounded session query. History identity
   is normalized once at experiment/config or precompute construction rather
   than recomputed per candidate.
6. No new per-pulse operation walks the whole decision axis. The factual
   changes occur at construction, sealing or existing provider preparation.
7. No second bars, features or history materialization was added. The shared
   substrate remains owned by Workstream 41.

The codebase checker now treats the history-policy version family as
current-only and includes a self-test for its current binding. Check mode
reports zero current-only or run-config violations.

## Verification record

- Focused fact, calendar, seal, hash, availability, config, precompute,
  sweep, walk-forward, persistence, documentation and control-plane suites:
  pass.
- Ordinary fast profile: 565/565 blocks in each of three runs, median 110.50
  seconds against 112 seconds, pass.
- Ordinary review profile: 353/353 blocks, zero failures and one pre-existing
  optional-package skip.
- Package build and check: code, tests, examples, Rd and vignette execution
  pass; two expected no-build-vignettes warnings only.
- YAML and `git diff --check`: pass.
- Product tree: `80c86012`; durable profile files are under
  `dev/bench/v0_2_2_history_foundation/evidence/`.

## Remaining review item

The independent close review must inspect the accepted fact and identity
semantics, failure sensitivity and the dense boundary. Once the branch is
pushed, it must also confirm the dedicated Ubuntu rule-4 golden-root step.
