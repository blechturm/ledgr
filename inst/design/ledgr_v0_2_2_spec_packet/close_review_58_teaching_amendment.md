# Adversarial documentation review: Workstream 58 teaching amendment

**Review point:** uncommitted teaching amendment over `6c9b4a21`  
**Reviewer:** clean-context Codex agent  
**Final verdict:** PASS

## Question

Does the rewritten minimum-variance article meet the vignette style guide,
teach its one research method at publication quality, and avoid API smells in
the code readers are asked to use?

## Initial findings

The first pass returned `CHANGES_REQUIRED`. The method and primary flow were
sound, but the review required:

1. a fixture where the long-only constraint genuinely binds, backed by an
   oracle that distinguishes the constrained solution from clipping an
   unconstrained one;
2. removal of the undeclared `mirai` requirement from the sweep;
3. a compact candidate-to-outcome table and a runnable exercise;
4. a proper synthetic-data callout and a link to the canonical risk-and-cost
   article;
5. a one-column-safe diagonal construction and exact cash-buffer wording;
6. clear labels on historical governance evidence; and
7. plain `cov()` plus hidden cleanup where those were the simpler forms.

After those corrections, a second pass found three publication-contract
issues: `LCL-0427` claimed stronger parameter visibility than `LTB-0437`
detected, two passages promised future API surfaces, and next-open execution
was introduced without linking its canonical article. A focused confirmation
then found that the parameter detector searched the whole article rather than
the exact displayed parameter chunk.

## Corrections and confirmation

The article now shows a deliberately redundant asset whose constrained weight
is zero; the independent active-set oracle proves that simple clipping is a
different answer. The sweep is sequential, its output is compact, and the
exercise can be run as written. The article uses the standard callout, links
the risk-and-cost and execution-semantics articles, uses a dimension-safe
diagonal, describes execution headroom precisely, and makes no promise about a
future scheduler or portfolio-construction API.

`LTB-0437` extracts the exact `strategy-params` chunk and requires precisely
`lookback`, `min_instruments`, `covariance_shrinkage` and `equity_fraction`, in
order. It separately proves that the evaluated strategy consumes every choice
through `params$<choice>`. The final focused review returned `PASS`: the
detector is failure-sensitive, every earlier finding is closed, and no new
teaching, style-guide or API-smell finding remains.

No reviewer edited the repository.
