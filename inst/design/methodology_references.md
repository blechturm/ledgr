# External Methodology References

**Purpose:** Index of externally-authored methodology documents that ledgr
RFCs cite as design priors.

**Status:** Reference index. Entries are non-binding methodology priors, not
ledgr policy. RFC syntheses are the binding artifacts; this file records the
upstream methodology lineage that shaped them.

**What this is NOT:**

- Not deep-research LLM outputs. Those live in `inst/design/research/` and
  follow a different convention (one file per RFC cycle, ChatGPT
  Deep Research outputs only).
- Not contract definitions. Those live in `inst/design/contracts.md`.
- Not internal ledgr methodology. ledgr-specific syntheses live in
  `inst/design/manual/` as maintainer manual articles.

When an RFC seed wants to cite external methodology as a prior, the seed
names the reference here. The reference entry summarizes the framework,
maps it to ledgr surfaces, and lists the specific sections that future RFC
cycles are most likely to cite.

---

## Peterson (2017) -- Developing & Backtesting Systematic Trading Strategies

**Author:** Brian G. Peterson.

**Title:** *Developing & Backtesting Systematic Trading Strategies*.

**Date:** 2017-06-14 (updated).

**Author affiliation at time of writing:** DV Trading, DV Asset Management.

**Maintenance lineage:** Peterson maintains the load-bearing R quantitative-
finance ecosystem -- `quantstrat`, `blotter`, `PerformanceAnalytics`,
`PortfolioAnalytics`. The paper is his methodological synthesis distilled
from running quantitative teams and from years of teaching at R/Finance
workshops. It is the closest thing to a canonical "how to do this work"
doctrine in the R quant community.

**Where to find it:** Publicly distributed by the author. The maintainer
keeps a local archived copy. The original shortened URL at the end of the
paper (`goo.gl/na4u5d`) is dead; cite by title and authorship rather than
by URL.

### Why ledgr cites Peterson

Peterson's framework is built around a series of bias-prevention
disciplines: look-ahead bias, data snooping bias, data mining bias, ad-hoc
hypothesis ("HARKing"), rule burden, and overfitting. He writes about what
the analyst should do; he assumes the analyst will hand-implement identity,
snapshot management, deterministic execution, and bias prevention.

ledgr's invariants enforce structurally what Peterson asks the analyst to
enforce manually:

- Look-ahead bias -> snapshot sealing + no-lookahead pulse execution.
- Data snooping -> identity hashing + fingerprint pins + deterministic
  seeds.
- Data mining -> RFC cycle discipline + scope-discipline gates.
- Ad-hoc hypothesis -> RFC cycle's "post-synthesis amendments must either
  bind substantive defaults or name ticket-cut gates" closure rule
  (recorded 2026-06-04 in `rfc_cycle.md`).

Peterson is the methodological prior; ledgr is the substrate that makes the
discipline tractable.

### Framework outline mapped to ledgr surfaces

| Peterson section | ledgr surface |
| --- | --- |
| Constraints, Benchmarks, and Objectives | v0.2.x benchmark context (planned); no first-class business-objective surface today |
| Hypothesis Driven Development | RFC cycle discipline at the framework layer; no first-class strategy-hypothesis artifact (gap) |
| Defining the strategy (filters / indicators / signals / rules) | Feature engine + `signal_*()` -> `select_*()` -> `weight_*()` -> `target_*()` helper pipeline; ledgr collapses Peterson's "rule" into the strategy function |
| Strategy specification document | Spec packets at the framework layer; no equivalent at the user-strategy layer |
| Evaluating Each Component | Helper-pipeline functions are individually testable; no dedicated diagnostics API (gap) |
| Evaluating Indicators / Signals | No `ledgr_signal_diagnostics()` today; substrate fits the v0.2.x signal-decay obligation (sweep persistence synthesis F2) |
| Evaluating Rules (entry / exit / risk / sizing) | Collapsed into the strategy function; v0.1.9.3 chainable risk layer adds a pre-strategy risk hook |
| Parameter Optimization | Sweep + dplyr today; no built-in stable-region detector |
| Walk Forward Analysis | v0.1.9.4 (synthesis accepted with Amendments 1+2 and Section 17 gates) |
| Regime Analysis | Not on roadmap |
| Evaluating Trades (FIFO / flat-to-reduced / increased-to-reduced) | Spot-FIFO bound in v0.1.8.10 (LDG-2522); multi-asset accounting deferred |
| MAE / MFE per-trade excursions | Substrate present (lots + fills retained on promoted runs); no helper yet (small future addition) |
| Post Trade Analysis | Not addressed; no production execution path until v0.3.0 paper trading |
| Microstructure / L2 | Permanent non-goal per whole-second timestamp contract |
| Evaluating Returns | Net portfolio returns retained per v0.1.9.2; denominator convention follows fixed-starting-capital implicit in `opening` configuration |
| Rebalancing and asset allocation | See the 2026-06-07 horizon entry "Portfolio optimization scaffolding" |
| Probability of Overfitting (CSCV / DSR / White's RC) | v0.1.9.x selection-integrity diagnostics packet (planned) |

### Strong alignments

- Look-ahead and data-snooping bias prevention: structural in ledgr; no
  analyst discipline required.
- Cost identity and reproducibility: v0.1.9.1 `cost_model_hash` +
  `cost_plan_json` substrate.
- Three-tier evidence framing (scalar / return-series / promoted run): the
  v0.1.9.2 sweep persistence synthesis converges on the same decomposition
  Peterson describes.
- Pre-specification before coding: spec packets at the release-cycle layer;
  RFC cycle stages match the "specification changes must be conscious and
  recorded" doctrine.

### Partial alignments

- Component-level testability: helper pipeline supports this
  architecturally, but no dedicated signal / indicator diagnostics surface
  ships today.
- Hypothesis recording: free-text `note` on saved sweeps; no structured
  hypothesis identity artifact.
- Walk-forward, selection-integrity diagnostics, benchmark context: all on
  the roadmap; not yet shipped.
- Trade accounting: spot-FIFO is reasonable for spot; multi-asset would
  need flat-to-reduced or increased-to-reduced per Peterson's preferred
  methodologies.

### Deliberate non-alignments

- Sub-second / HFT: explicit permanent non-goal per whole-second timestamp
  contract.
- Multi-strategy portfolio optimization in the fold core: Peterson treats
  this as a meta-layer; ledgr's "no second execution engine" invariant
  pushes it outside the fold core. See the 2026-06-07 portfolio
  optimization scaffolding horizon entry.

### Citations from this paper future RFCs should anchor to

- **Selection-integrity diagnostics RFC seed (v0.1.9.x slot):**
  "Probability of Overfitting" section (out-of-sample deterioration,
  resampled trades, White's Reality Check, k-fold cross validation, CSCV)
  plus the cited Bailey/Lopez de Prado, Bailey/Borwein/Lopez de Prado/Zhu,
  Sullivan/Timmermann/White, Hansen, and Harvey/Liu papers.
- **Benchmark context RFC seed (v0.2.x):** "Choosing a benchmark" section
  four-category framing (archetypal strategies, alternative indices,
  custom tracking portfolios, market observables) and the
  "measuring performance against your benchmark" section on
  multiple-benchmark guards against targeting.
- **Portfolio optimization scaffolding (deferred):** "Rebalancing and
  asset allocation" section -- Kelly, optimal-f, LSPM (Vince 2009),
  layered objectives and optimization, rebalance frequency choices. Also
  the implicit `constrained_objective()` FIXME footnote on page 4.
- **Walk-forward Amendment 3 (if it opens) or successor RFC:**
  "Walk Forward Analysis" section -- anchored vs rolling,
  reparameterization frequency, windowing effects, and the cross-validation
  distinction documented via Hyndman's references.
- **Trade accounting RFC (multi-asset, deferred):** "Evaluating Trades"
  section on FIFO / tax lots / flat-to-flat / flat-to-reduced /
  increased-to-reduced trade definitions and brokerage reconciliation.
- **Hypothesis recording RFC (deferred):** "Hypothesis Driven Development"
  section -- declarative conjecture, predictive content, expected outcome,
  verification test; the "good hypothesis includes" checklist.
- **MAE / MFE helper (deferred):** "Per-Trade statistics" subsection on
  Maximum Adverse Excursion and Maximum Favorable Excursion as
  empirical-risk-stop and profit-taking calibrators.
- **Post-trade calibration (deferred, behind v0.3.0 paper trading):**
  "Post Trade Analysis" section -- haircuts on the research model from
  production results, asymmetric calibration (lower backtest expectations
  from production losses; never upward-adjust the model from production
  wins).

### One specific lesson worth surfacing now

Peterson's strongest single warning is against the *ad hoc hypothesis*:
refining the hypothesis after seeing results to "explain" observation,
producing the appearance of in-sample explanatory power while
out-of-sample power deteriorates. He calls this HARKing (Kerr 1998). The
`rfc_cycle.md` 2026-06-04 closure rule -- "a post-synthesis amendment that
routes only procedural constraints is insufficient closure; either
substantive defaults or named ticket-cut gates or both must land" -- is
structurally the same anti-HARKing pattern applied to framework evolution.
The fact that ledgr independently arrived at this safeguard is a sign the
cycle discipline is working. The rule should remain visible.

---

## Bailey, Borwein, Lopez de Prado, and Zhu (2014-) -- backtest overfitting and selection-bias correction

**Authors:** David H. Bailey (LBNL / UC Davis), Jonathan M. Borwein
(Newcastle), Marcos Lopez de Prado (then-Hess Energy / Cornell, now AQR),
and Qiji Jim Zhu (Western Michigan).

**Key papers:**

- Bailey and Lopez de Prado (2014). "The Deflated Sharpe Ratio: Correcting
  for Selection Bias, Backtest Overfitting and Non-Normality." *Journal of
  Portfolio Management*.
- Bailey, Borwein, Lopez de Prado, and Zhu (2014). "Pseudo-Mathematics and
  Financial Charlatanism: The Effects of Backtest Over Fitting on
  Out-of-Sample Performance." *Notices of the AMS* 61 (5): 458-71.
- Bailey, Borwein, Lopez de Prado, and Zhu (2014). "The Probability of
  Backtest Overfitting." SSRN.
- Bailey and Lopez de Prado (forthcoming/2014). "Drawdown-Based Stop-Outs
  and the 'Triple Penance' Rule." *Journal of Risk*.
- Lopez de Prado (2018). *Advances in Financial Machine Learning*. Wiley.
  Broader synthesis extending the selection-integrity work to
  ML-specific concerns (purged k-fold cross validation, embargo,
  meta-labeling, hierarchical risk parity).

**Where to find them:** SSRN, journal archives, and the authors' public
pages. Cite by paper title and authorship.

### Why ledgr cites this body of work

This is the central modern literature on *selection bias in backtest
evaluation*. The contribution that ledgr's v0.1.9.x selection-integrity
diagnostics packet will build on directly is the recognition that
**backtest overfitting is mathematically inevitable given enough trials,
and the observed performance of the best candidate must be discounted
accordingly.**

Four specific surfaces:

- **DSR (Deflated Sharpe Ratio)** adjusts the observed Sharpe of a
  selected strategy for the number of trials performed and the
  non-normality of returns. If a sweep evaluated 1,000 candidates and you
  promote the best, that candidate's Sharpe is inflated by selection
  bias; DSR is the correction.
- **PBO (Probability of Backtest Overfitting)** is a probability that the
  candidate with the best in-sample performance will perform below median
  out-of-sample. Computed empirically.
- **CSCV (Combinatorially Symmetric Cross Validation)** is the
  computational mechanism behind PBO. Split the data into S slices,
  enumerate all combinations of S/2 slices as in-sample with the
  complement as out-of-sample, rank candidates per combination, average
  the rank-degradation. Yields PBO without requiring stationarity
  assumptions stronger than other cross-validation methods.
- **Triple Penance rule** is a drawdown-based stop-out: the asymmetric
  difficulty of recovering from drawdowns (50 percent loss requires 100
  percent gain) combined with an autoregressive model for expected
  time-to-recover. Informs Level 4 (per-strategy position sizing) in the
  portfolio optimization scaffolding.

### Framework mapped to ledgr surfaces

| Bailey / Lopez de Prado contribution | ledgr surface |
| --- | --- |
| DSR -- selection-bias-corrected Sharpe | v0.1.9.x selection-integrity diagnostics (substrate: v0.1.9.2 retained net returns) |
| PBO + CSCV -- overfit probability | v0.1.9.x selection-integrity diagnostics; coordinates with v0.1.9.4 walk-forward folds |
| Triple Penance -- drawdown-based stop-outs | v0.1.9.3 chainable risk layer (Level 4 per the 2026-06-07 portfolio optimization horizon entry); future stats-driven sizing rules |
| Advances in FML -- purged k-fold, embargo, meta-labeling | v0.1.9.4 walk-forward Amendment 3 candidate; v0.2.x signal-decay substrate (sweep persistence synthesis F2) |
| Hierarchical Risk Parity (Lopez de Prado 2016) | Portfolio optimization scaffolding Level 2 / Level 3 (joint return distribution modeling substrate) |

### Strong alignments

- Retained net returns at the candidate level (v0.1.9.2) are exactly the
  input format DSR and PBO computation expect.
- The candidate-level identity surface (`candidate_id`, `candidate_row`,
  `feature_set_hash`, `cost_model_hash`) provides the trial-identity
  substrate CSCV's rank-degradation analysis requires.
- ledgr's "deterministic seeds, fingerprint pins, reproducible sweep
  identity" invariants make trial-count auditable in a way most
  competitor frameworks cannot.

### Citation anchors future RFCs should use

- **Selection-integrity diagnostics RFC seed (v0.1.9.x):** the four
  foundational papers. Treat DSR as the headline metric, PBO + CSCV as
  the headline procedure, and the Triple Penance work as the position
  sizing connection.
- **Walk-forward Amendment 3 (if opened):** Advances in FML chapter 7
  (cross-validation in finance) for the purged k-fold and embargo
  semantics that strengthen walk-forward fold integrity.
- **Portfolio optimization scaffolding Level 4 (deferred):** the Triple
  Penance autoregressive model as a citation anchor for stats-driven
  position sizing rules.
- **Portfolio optimization scaffolding Level 3 (deferred):** HRP from
  Lopez de Prado (2016) "Building Diversified Portfolios that Outperform
  Out-of-Sample" as an adapter target alongside PortfolioAnalytics.

### One specific lesson worth surfacing now

The Bailey / Borwein / Lopez de Prado / Zhu group's *Notices of the AMS*
paper carries a stronger normative claim than the technical papers around
it: large-scale backtest evaluation without selection-bias correction is
*pseudo-mathematics*. The framing -- that publishing a backtested Sharpe
without DSR-adjustment or PBO disclosure is closer to academic misconduct
than to legitimate analysis -- is intentionally provocative. ledgr's
disposition is consistent with this view: identity-bound trial counts and
the v0.1.9.x selection-integrity gate are not optional ergonomic
features; they are the framework's way of preventing the maintainer from
inadvertently publishing pseudo-mathematics.

---

## Pardo (2008) -- The Evaluation and Optimization of Trading Strategies

**Author:** Robert Pardo (Pardo Capital Limited).

**Title:** *The Evaluation and Optimization of Trading Strategies*, Second
Edition.

**Publisher:** John Wiley & Sons, 2008.

**Maintenance lineage:** Pardo's first edition (1992) effectively
introduced walk-forward analysis as a formal evaluation methodology for
trading systems. The second edition refines that work and adds robustness
criteria, stable-region parameter analysis, and trade-evaluation
methodology. Peterson cites Pardo repeatedly; the v0.1.9.4 walk-forward
synthesis's anchored / rolling distinction traces back here.

**Where to find it:** Wiley publication. The book is the citation; no
shortened URL.

### Why ledgr cites Pardo

Three load-bearing contributions:

1. **Walk-forward analysis as the central evaluation methodology.**
   Pardo's framing of rolling and anchored walk-forward windows is the
   foundation ledgr's v0.1.9.4 synthesis sits on. The Walk-Forward.md
   research file already absorbs material from Pardo via Peterson.
2. **Stable-region parameter analysis.** Pardo argues that robust
   parameter sets exhibit small-change-in-parameter -> small-change-in-
   P&L behavior, and that contiguous regions of profitable parameter
   choices in the optimization plot are stronger evidence of skill than
   isolated peaks. This is the substrate prior for any future
   stable-region detection helper in ledgr's sweep tooling.
3. **The "robust trading strategy" checklist (Chapter 11, pp. 202-209).**
   Pardo lists nine characteristics of a robust strategy:

   - relatively even distribution of trades over time,
   - relatively even distribution of trading profit,
   - relative balance between long and short profit,
   - a large group of contiguous, profitable strategy parameters,
   - acceptable trading performance across a wide range of markets,
   - acceptable risk,
   - relatively stable winning and losing runs,
   - a large and statistically valid number of trades,
   - a positive performance trajectory.

   This checklist is the cleanest existing specification of what a
   `ledgr_business_objective()` constructor should be able to express.
   When the structured-business-objective RFC opens (deferred per the
   2026-06-07 portfolio optimization scaffolding horizon entry), Pardo's
   nine characteristics are the obvious starting list of named
   constraints.

### Framework mapped to ledgr surfaces

| Pardo contribution | ledgr surface |
| --- | --- |
| Walk-forward anchored vs rolling | v0.1.9.4 walk-forward synthesis Section 3 |
| Stable-region parameter analysis | Future sweep helper (not on roadmap); v0.1.9.x selection-integrity diagnostics adjacent |
| Robust-strategy nine-characteristic checklist | Future business-objective constructor (portfolio optimization scaffolding prerequisite) |
| K-Ratio (Kestner via Pardo) | Future metric extension or PA adapter |
| "Net profit as a sole evaluation method ignores many of the characteristics important to this decision" | v0.1.9.2 sweep persistence synthesis Section 4 three-tier framing -- the lineage of the scalar-vs-series-vs-promoted hierarchy |

### Strong alignments

- The walk-forward synthesis's Amendment 2 substantive defaults
  (`carry_test_state`, fail-closed selection-rule behavior, no-default
  extraction with rationale) are a stricter version of the parameter-
  stability discipline Pardo advocates.
- The v0.1.9.2 retained net returns + planned selection-integrity
  diagnostics surface Pardo's "large group of contiguous, profitable
  parameters" criterion as a computable check.

### Citation anchors future RFCs should use

- **Business-objective constructor (deferred to v0.2.x):** Pardo's nine
  characteristics list as the citation anchor for the named-constraint
  taxonomy.
- **Stable-region parameter analysis helper (not yet roadmapped):**
  Pardo Chapter 12 on parameter stability and Chapter 13 on Multi-Market
  Robustness.
- **Walk-forward Amendment 3 (if opened):** Pardo's anchored vs rolling
  framing remains foundational; supplement rather than replace.
- **K-Ratio in the metric kernel:** Pardo cites Kestner (2003); the
  t-statistic on the linear fit of the equity curve is a candidate
  metric extension. Could land as a small parallel release.

### One specific lesson worth surfacing now

Pardo's stable-region argument is the single most actionable parameter-
optimization prior in the literature. The argument runs: a profitable
parameter combination that is *isolated* in optimization space (small
parameter perturbations crater the P&L) is almost certainly overfit; a
profitable combination that sits inside a large contiguous region of
similarly-profitable neighbors is more likely to reflect a real signal.

ledgr's current sweep tooling (dplyr over scalar results) lets a user
look for stable regions manually. A future `ledgr_sweep_stability()` or
`ledgr_sweep_region_plot()` helper would surface this as a first-class
diagnostic. Worth horizon-noting if it doesn't already have a slot;
otherwise the v0.1.9.x selection-integrity diagnostics RFC seed should
treat it as a candidate addition alongside DSR / PBO / CSCV.
