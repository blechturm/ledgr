# Cut 13 Ticket-Cut Review

**Date:** 2026-09-26
**Reviewer:** ChatGPT
**Mode:** Type 1, then Type 2.
**Target:** `cd49ecf605af1392a104a0255c84d4ecab25eaf9`, Workstream 20,
LDG-2850 through LDG-2857 and the packet README's Cut 13 section.
**Authority:** synthesis `d9daa4d1bbfffe81180297a52c7baf4bc8e03d3f` on the
design branch; original final review `4e653780b76b84fe57ee5724426cf53ad97b5883`.
The original review covers the original synthesis, not its later amendment.
This review takes the maintainer's acceptance in the brief as its authority.
Code and contract line references below refer to the target commit; synthesis
references refer to `d9daa4d`.

**Verdict: CHANGES_REQUIRED.** The decomposition is sound enough to keep.
Three bounded corrections below make the cut executable and close its coverage
holes. No new architecture, RFC round, spike or per-ticket review is needed.

## 1. Type 1: Completeness and executability

The YAML parses, all eight IDs are unique and contiguous, and the declared
dependency graph is acyclic. Workstream 20 depends on the release workstream;
branch convergence is explicitly required before opening. No implementation
should begin merely because the cut's planning status is `open`.

### F1 - Medium: LDG-2851 overpromises compatibility and erases historical scope

`tickets.yml:1474` requires both that no source or documentation string reference
a removed name and that no configuration or strategy hash change. These are
broader promises than the synthesis authorizes.

Synthesis section 8, lines 349-353, explicitly preserves historical documents
and recorded evidence and allows normal provenance changes when strategy source
is rewritten. The historical probe deliberately reads `ctx$positions` and calls
the tombstones (`dev/spikes/strategy-context-surface/probe.R:58-71` on the design
branch). It must continue to describe that historical surface. The production
source hash hashes the deparsed strategy, not its economic equivalence
(`R/strategy-provenance.R:59-78`). Replacing a read spelling in strategy source
therefore need not preserve its source hash.

**Correction:** restrict retirement to the supported public surface, active
documentation and live read sites. Explicitly preserve historical evidence and
negative regression fixtures. Preserve hashing algorithms, stored identities
and the renamed rule's payload/hash; allow normal new identities for rewritten
strategy source. Do not introduce normalization or compatibility shims to make
the present blanket assertion pass. This is the cut's one substantive widening
of the accepted promises, and it should be removed.

### F2 - Medium: LDG-2850 cannot update the reference and keep its old test unchanged

`tickets.yml:1463-1464` binds the singular `vec$position` reference while requiring
the existing documentation-contract tests to pass unchanged. The existing test
literally requires `\code{ctx$vec$positions}` in that reference
(`tests/testthat/test-documentation-contracts.R:661`). Leaving that assertion
unchanged either fails the ticket or rewards retaining the retired spelling.

**Correction:** authorize the matching literal-expectation update with the
contract/reference edit. Keep unrelated assertions unchanged. LDG-2855 still
owns the new runtime surface comparison; this small expectation correction is
not a second surface gate. Text first remains a sensible implementation order.

### F3 - Medium: Some accepted teaching and semantic checks have no explicit owner

The cut reproduces most of synthesis sections 3-7, but not all. These omissions
matter because the surface-table test verifies disclosure and shape, not all
economic meanings. Assign them to existing tickets as follows; do not add a
registry or another test framework.

| Accepted requirement | Owning ticket and smallest detecting completion |
| --- | --- |
| Section 5 and section 6 Context row: exact `tradable()` predicate and limits | LDG-2850 corrects the reference and contract. LDG-2854's positive-weight failure case uses `priced=TRUE` with no current close, so a stale permissible mark cannot be mistaken for sizing evidence. |
| Section 3: `signal_return()` masks inadmissible scores, while the raw feature-plane entrance does not | LDG-2850 documents the difference; LDG-2852 owns a restricted-member example comparing both routes. Neither default may silently acquire the other's policy. |
| Section 7 Composition row: numerical outcomes through the new entrances | LDG-2852 asserts the synthesis's dense 15/7 target, availability AAA=6/OLD=2, weight-0.6 AAA=3/OLD=2, and explicit-none AAA=0/OLD=2. The existing reservation mutant remains owned by LDG-2854 and is referenced at close. |
| Section 7 Missingness row: all-NA scores mean zero member targets, not hold | LDG-2852 asserts the unguarded all-NA pipeline and guarded hold on the same nonzero holdings. LDG-2856 teaches that tested distinction. Printing one guarded example alone cannot detect a changed default. |
| Section 4: empty membership entails no member feature lookup | LDG-2853 uses an accessor that fails if called, checks an empty result, and still rejects an invalid lookback. Merely checking that nothing was registered misses an unnecessary lookup. |
| Section 7 Read/naming parity and Runtime/teaching rows | LDG-2851 retains the existing feature alias/warmup detectors. LDG-2856 owns run/sweep parity for the new helper paths using existing execution tests. The close review explicitly checks that changed reads and entrances add no per-pulse frames or history queries. |

The first omission already has a concrete misleading sentence to repair:
`man/ledgr_strategy_context.Rd:39-41` says `tradable()` returns instruments that
may be sized now. Its availability implementation only checks `admissible &
priced` (`R/pulse-context.R:589-599`), while sizing requires a positive current
close (`R/strategy-helpers.R:272-282`). The accepted synthesis explicitly rejects
that sizing guarantee. Listing the field in a correct surface table would not
by itself remove the false claim.

The other policy distinction is also visible in production: the return helper
replaces inadmissible member scores with NA at `R/strategy-helpers.R:85-90`.
Contracts already distinguish missing scores from missing final targets
(`contracts.md:600-623`). These are existing semantics to disclose and protect,
not permission to choose new allocation policy.

### Ownership disposition

| Synthesis decision | Primary implementation owner | Assessment |
| --- | --- | --- |
| Six contract amendments and reference semantics, section 6 | LDG-2850 | Correct owner; F2 and F3 complete it. |
| Position plane, duplicate removal, tombstones, private safety state and rule names, sections 1 and 5 | LDG-2851 | Correct owner; narrow its compatibility claim per F1. |
| Constructor dispatch, membership projection, alignment and error families, section 3 | LDG-2852 | Strong negative cases; add F3's numerical and missingness checks. |
| Empty values and three distinct empty domains, section 4 | LDG-2853 | Correct owner; strengthen the no-lookup detector. |
| Explicit zero member weights and retained positive-weight rules, section 3 | LDG-2854 | Concrete detecting cases and mutation; keep it separate from representation-only work. |
| Dense/availability documented-surface comparison, section 7 | LDG-2855 | Faithful, bidirectional and failure-sensitive. |
| Authoring examples and budget/hold semantics, sections 3 and 7 | LDG-2856 | Correct owner; bind the run/sweep check rather than only article execution. |
| Closeout and deferred inspection boundary, section 8 | LDG-2857 | Add the required horizon entry with section 5's trigger and evidence requirement; merely naming declined inspection work is insufficient. |

The horizon omission is a low-severity documentation completion, not a new
research prerequisite. Scheduler, rebalance-band and causal-frame design stay
with their separate work. The cut does not otherwise settle anything that the
synthesis deliberately left open.

## 2. Type 2: Decomposition and order

Keep one workstream and its one close review. Constructors and empty domains
share validators, but separating their acceptance responsibilities is useful;
there is no reason to create another review boundary between them. Keep the
zero-weight correction distinct from the name cleanup because it intentionally
changes behavior.

Make the practical sequence explicit: contract/reference and obsolete test
expectations; surface retirement; constructor and empty-domain work together;
zero-weight correction; final surface gate and executed examples; brief closeout.
LDG-2853 currently depends only on LDG-2850 while its acceptance requires both
new context-first pipelines (`tickets.yml:1492-1494`). Add LDG-2852 as a
dependency for that end-to-end acceptance, or explicitly describe 2852/2853 as
one joint implementation step. Do not pretend the current graph serializes all
eight tickets. This is an ordering clarification within one workstream, not a
cross-review dependency deadlock.

Trim LDG-2857's requested inventories (`tickets.yml:1533`). Link the relevant
diffs, tests and executed examples instead of copying every old/new sentence,
read-site migration and validation matrix into another document. Record shipped
claims, unresolved work, rejected approaches and the required review counters,
as `rfc_cycle.md:236-241` already prescribes. Review-ratio arithmetic is a process
limit, not a reason to manufacture independent units of work.

The historical probe may be rerun and its expected divergences reported, but its
checker requires byte-for-byte old observations (`check.py:15-29` on the design
branch). Do not rewrite that evidence or make its unchanged PASS a closure gate.
The new API's tests must own current semantic acceptance. The documented-surface
test remains the sole mechanical surface gate; no timing or member-count gate
is added.

README lines 704-713 should also distinguish a correction to the proposed
predicate design from the correction to existing zero-weight behavior. Both
are not changes to already-shipped context-first constructors. The surrounding
breaking renames are intentional; avoid a package-wide compatibility inference
from the narrower zero-weight widening.

## 3. Verification and limits

Read the target tickets, README, authoritative contracts, affected production
functions and existing tests against the exact target. Read the synthesis and
original review from the separate design history. Parsed YAML and checked the
eight IDs and dependency graph. This was a ticket-cut/source review: no R suite,
private data or implementation experiment was run, and no code was changed.

After these edits, proceed through the already-bound branch convergence and
release gate to implementation. The findings require a bounded cut correction,
not another design cycle.
