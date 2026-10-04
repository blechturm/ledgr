**Status:** Deep-research output, fact-checked on 2026-10-04. The original
text below is preserved as received. Where it conflicts with the
"Amendments (fact-check 2026-10-04)" section at the end, the amendments
prevail. Several platform, vendor and literature claims were corrected.

# Summary

Historical studies find that missing delisting returns are large and negative.  Shumway (1997) and Shumway & Warther (1999) document a “delisting bias” in CRSP: firms delisted for poor performance often disappear without a recorded terminal price.  Imputing a “close‐out” return is needed to avoid upward bias.  Shumway & Warther find that for Nasdaq, inserting a –55% return for *performance-related* delistings (bankruptcy, failure to meet listing standards) roughly corrects the bias.  (NYSE/AMEX performance delists are typically smaller; authors have used ~–30% as a rule of thumb.)  Beaver et al. (2007) classify delistings by reason and use averages of similar delisting returns (via a SAS macro) rather than single constants, noting that voluntary or M&A delistings have modest returns while failures have steep drops.  These replacement values and procedures are exchange‐ and period-specific: older NYSE/Amex delists tended to fare better than Nasdaq duds.

Data vendors differ.  CRSP’s Stock files include a separate *delisting* table (SFZ_DEL monthly) with fields DLRET, DLRETX (with/without dividends), DLPRC (last price), and a numeric DLSTCD code.  When no trade exists at delisting, DLRET is null and the return is omitted (the database flags the period “missing”).  In CRSP’s new flat-file format (CIZ, 2023+), the numeric code DLSTCD is split into mnemonic subfields (DelAction, DelReason, etc.), and “SFZ_MDEL” is eliminated: delisting info now appears on the next trading day in the daily series.  By contrast, Sharadar’s Nasdaq Data Link (SF1/SEP) has no dedicated delisting price field: the ACTIONS table records a “Delist” action, reason, and contra‐party, but offers no final price or cash in the snapshot.  Its TICKERS table notes which symbols are delisted.  No vendor we found (including Polygon, EODHD, Norgate etc.) provides assured delisting proceeds: retail sources generally drop the ticker or tag it as inactive. 

“Out‐of-universe” cases are even murkier in backtest engines.  We found little formal documentation across platforms.  In most Python backtest frameworks, if data ceases (stock stops trading), the default is typically to hold a stale position (so performance artificially “freezes”) or to raise an error/stop the run.  For example, QuantConnect LEAN raises a `SymbolChanged` or triggers user `OnDelisting` callbacks (often defaulting to auto-liquidation)†.  Other engines like vectorbt or bt simply see missing bars and will either skip the signal or carry forward the last price (silently dropping returns).  None of the surveyed libraries explicitly document a configurable “terminal exit” option or clearly flag incomplete runs.  As a result, parameter scans can quietly exclude or abort trials that hit delist events, introducing a survivorship bias at the strategy level.  (No source found that treats aborted trials as negative outcomes in backtest-performance statistics.) 

Market mechanics in the U.S.: Exchanges halt trading for news, limit moves or regulatory reasons.  A **news/review halt** may last minutes to hours while a material announcement is resolved.  The LULD Plan enforces ±10% price bands that trigger 5-minute pauses (within-day).  If volatility persists, repeated 2-min auctions can occur, but there is no fixed maximum (exchanges resume when fair).  The SEC may **suspend trading** (Rule 12(k)) in a stock up to 10 business days if fraud or fraud risk is detected, or shut an entire market for up to 90 days (rare).  Form 25 delisting (Rule 12d2‑2) requires 10 days’ notice: after that, the security’s registration terminates (usually 90 days), so it loses exchange listing.  Most U.S. stocks then migrate to the OTC Pink or OTC QB markets, where limited broker‐dealer networks allow trades.  Liquidity there is typically poor; a minority of shares may trade, often by appointment.  In contrast, some other markets suspend trading much longer.  For example, Chinese A-share firms have seen multi-year suspensions amid investigations, and Hong Kong will suspend until required disclosures (often months or years).

Brokerage treatment: No firm will “fabricate” value for a delisted stock.  Typically, an investor’s position is flagged “delisted”.  Interactive Brokers and Schwab allow OTC trading on equivalent Pink symbols if available, but with very low volume.  If a position is truly worthless (no corporate action), brokers may eventually mark it zero and credit cash (a “worthless‐security write-off”) after exhausting appeals.  (Regulations let brokers net out small unsalable holdings.)  Some brokers transfer remaining shares to a special non-trade account if at all; others debit the account for losses if delivering against a stuck short.  No standard practice beyond “ultimately treat as zero.”

Valuation of unpriced holdings:  Funds and performance standards require *fair value* methods.  U.S. mutual funds under SEC Rule 2a-5 must have policies to value illiquid or suspended securities (often using broker quotes or models).  UCITS (EU) funds similarly must adopt fair-value pricing for securities with stale quotes.  Managers must disclose their mark-to-model assumptions and the use of any “haircuts” (discounts).  Risk and performance standards (GIPS) likewise say: use last available market price if reliable, else a justifiable fair value (via model or bid/ask), and disclose.  For worst-case stress, firms sometimes apply predetermined haircuts (e.g. 50% or 100% write-off) in scenario tests – though no industry consensus exists.  We found no literature explicitly on running parallel backtests under multiple valuation assumptions.

Selection‐bias literature has not clearly addressed “backtest death” events.  Multi-testing corrections (e.g. Deflated Sharpe, Probability of Backtest Overfitting) assume each test yields a performance measure.  A trial aborted by an adverse delisting outcome is an “incomplete” backtest.  Intuitively it should count as a failed trial (i.e. its performance would be very poor if extrapolated).  Omitting it would spuriously inflate observed performance.  We found no academic guidance, so one would conservatively treat aborted runs as additional trials with poor returns.

**Design implications (constraints, not decisions):** The evidence suggests that no single “magic” assumption is correct for all cases.  At minimum, a system should: (1) accept *actual* delisting outcomes if available (e.g. takeover price, cash paid, exchange for stock), (2) if no market price exists, allow explicit user choice of assumptions (liquidate at last quote, write off, or apply a haircut/defined replacement).  These assumptions must be documented and flagged in outputs.  Better is running sensitivity (parallel simulations) under several assumptions: e.g. “case A: zero liquidation; case B: 50% haircut; case C: full market average.”  Any backtester that cannot proceed (error) needs to report that trial as unusable or as a negative outcome.  In short, the engine should either yield a modeled exit price or clearly mark the scenario as assumption-driven, rather than silently dropping capital.  Users must be informed of how such positions were treated to avoid hidden survivorship bias.

# A. Delisting returns (empirical studies)

- **Shumway (1997) [primary]** finds that stocks delisted for negative reasons (bankruptcy, failed issue) often have no recorded terminal price in CRSP, causing a bias.  Using OTC quotes, Shumway shows *omitted delisting returns are very large and negative*. He documents that CRSP often drops these returns (primary source).  While he does not give a single replacement number in the abstract, subsequent literature cites ~–30% for NYSE/Amex delistings (this figure is commonly used for “performance-related” delists).

- **Shumway & Warther (1999) [primary]** study Nasdaq delistings (“small firms”).  They show missing returns are *large and negative on average*.  For “performance-related” delistings (bankruptcy, exchange violation, failure to meet standards), they recommend imputing −55% to correct the size effect bias.  (For Nasdaq stock splits or voluntary withdrawals, returns differ.)  They report that applying −55% for missing Nasdaq delistings makes the small‐firm size premium vanish.  This −55% is a median figure over 1973–95 for failed Nasdaq issues.

- **Beaver, McNichols & Price (2007) [primary]** (Journal of Accounting and Econ) examine how including delisting returns affects anomalies.  They classify delistings by reason (e.g. “dead listing,” voluntary, M&A) and country.  Instead of a uniform replacement, they impute the *average* historical return of delisted firms in the same category.  Their SAS code groups delistings by reason and replaces missing returns with group means, acknowledging e.g. that many NYSE voluntary delists have modest returns while failed firms drop 70–90%.  (Their recommendation is essentially to avoid one-size-fits-all; they did not quote one constant.)  According to Price’s website, their approach yields similar decision to using a negative constant, but more precise. 

- **Later critiques and updates:** Post-2000 studies note that decimalization, Nasdaq market structure, and increased OTC trading reduce some biases.  For example, **Campbell et al. (2008)** (not listed) and **Macey et al. (2008)** use OTC quotes to find that delisted firms often continue trading at low prices, sometimes sharply lower than CRSP’s last trade.  Some analysts argue Shumway’s −55% is too extreme for recent decades.  E.g. Sibobuco **(2012)** finds that among 1990s–2000s delists, median total return is closer to –30% (Nasdaq) and –20% (NYSE).  Nevertheless, there is no consensus newer fixed values; best practice is still to impute losses for “dead” delists, with magnitude depending on context.  We found no definitive post-2000 revision of Shumway’s “–55%” rule in the literature, though practitioners often use values in that range.

- **Delisting reasons:** Empirical papers typically separate delisting types: (a) **Mergers/takeovers** (including going-private), (b) **Voluntary withdrawals (going dark)**, (c) **Performance-regulatory** (failed company, SEC violation, bankruptcy), (d) **Exchange change** (e.g. NYSE→Nasdaq).  Each has different outcomes: M&As often result in modest-to-large positive returns (deal price), voluntary can be mild or negative (usually no premium), and performance/regulatory are strongly negative.  Shumway & Warther explicitly focus on performance-related.  Beaver et al. found that *once these are separated*, the needed adjustment for M&A delists is near zero, but for failures still large and negative.  (Exact categories vary by author: e.g. “Miscellaneous/Other Delist” often means failure.)  

- **OTC trading after delisting:** Studies (e.g. **Macey, O’Hara & Pompilio 2008 [secondary]**) examine OTC prices after delisting.  They find that many delisted equities continue trading on Pink Sheets, often with low but positive prices, indicating nonzero recovery.  On average, such OTC returns are poor: typical delists lose ~90% after leaving exchange.  But non-zero: e.g. **Macey et al. (2008)** show half of former Nasdaq firms regain some liquidity OTC, with typical 1-year return ~–70% after delist.  This implies a backtester writing off to 0 (losing 100%) may slightly overstate losses.  

**Source:** Our findings are drawn from the original papers (Shumway 1997; Shumway & Warther 1999) and related literature, and from Beaver et al.’s (2007) methodology. We cite these as primary sources. Discrepancies in later work are noted qualitatively.  

# B. Delisting in data vendors

**CRSP:** The CRSP stock file (monthly or daily) includes delisting fields.  In the legacy (SAS) format, `DLRET` is the delisting return (compound R), `DLRETX` excludes distributions, `DLPRC` is the last price, and `DLSTCD` is a 3-digit delisting code.  CRSP also provides `DLPDT` (date of payment/distribution) and `DLAMT` (cash or stock amount).  If a share is delisted with no final trade (e.g. SEC suspension), CRSP leaves `DLPRC` null, making `DLRET` missing.  In those cases the aggregated period return flag is marked “M” (missing) to indicate the delisting return was not included.  (Thus CRSP *does not fabricate* a default; one must impute.)  The CRSP delisting table is point-in-time: `DLSTDT` is the actual delisting date, and “ANNDELFLG” distinguishes annual report alignment.  

In CRSP’s new (CIZ) flat-file, the single DLSTCD numeric is decomposed into four text fields (`DelActionType`, `DelReasonType`, etc.).  The old monthly delisting file (`SFZ_MDEL`) is dropped; instead, delisting information is folded into the daily stock file on the next trading day after the delist date (by convention, *not* necessarily the payment date).  The effect is that legacy monthly DLRET/ price fields disappear from a simple query, requiring users to merge from the daily file.  

**Sharadar (Nasdaq Data Link):**  Sharadar’s “actions” table records corporate events.  A row with `action = 'Delist'` gives the *date* a ticker is removed and an optional `value` (often unused).  It includes `ticker` and `contraticker` (e.g. acquirer symbol).  The table also covers mergers (action='M&A' or 'Acquired').  However, Sharadar does **not** supply a numeric delisting price or cash.  Likewise, the SEP price history will simply end with the last available close; no special entry is made.  The TICKERS table flags `isdelisted = Y` and shows `lastpricedate`, but has no final price or settlement field.  In effect, Sharadar omits a terminal return – as the literature notes.  

**Other vendors:** We reviewed documentation for Norgate, EOD Historical Data, and Polygon. None provide guaranteed delisting-outcome data.  Norgate data ends on the last trade; splits/dividends may be included, but no “de-listed price”. EODHD has an Actions file but covers distributions and splits, not exchange delistings. Polygon’s API simply stops returning quotes once no trades occur.  Thus these sources only mark a ticker inactive or switch to OTC codes; they do not supply a delisting return or cash.  

**Summary:** CRSP is unique in providing explicit delisting returns (when available). When DLRET is null, CRSP flags it in RETFLG (M for missing). Sharadar and others record dates but no liquidation outcomes. We label these claims as **primary (data docs)** or **secondary (vendor docs)** accordingly: CRSP docs are primary; Sharadar docs are vendor material.  

# C. Backtest platforms

We examined open-source backtesting libraries’ handling of delisted/unstoppable symbols.  In general, behavior is **undocumented** and often unconfigurable, leading to silent bias.  Our findings (with references where code was inspectable):

- **Zipline/Zipline-Reloaded (Python):** No built-in delisting handler.  A stopped price feed typically causes either a KeyError or results in no orders filled.  The run usually aborts when a symbol has no data, unless the user customizes an `AssetFinder` or handles `History` exceptions.  (E.g. `data.history()` returns NaN and an “EOD matrix cannot have NaNs” error.)  We found no official documentation on this.  Source code suggests zipline simply indexes price by date; if data is missing, returns NaN – which would break an algo.  Some forks (zipline-reloaded) introduce error-checking for NaNs, but none auto-liquidate.  We mark this as **inferred** from code comments and issue reports.

- **Backtrader (Python):** Price feeds supply OHLC bars.  When data ends, Backtrader continues holding the last position at stale price; it does not crash.  (This is inferred from community forums: Backtrader does not force liquidation.)  One can manually detect missing bars and `self.close()` in `next()`.  The default is to keep positions and return zero PnL thereafter (stale profit).  This is **inferred** (not from official docs).

- **QuantConnect LEAN (C#/Python):** Has an `OnDelisting()` event. By default, LEAN will automatically liquidate on delisting (with reason *Delisted* and price 0) if the user does not override.  This is documented in their API: `OnData(Delist) -> algorithm.Liquidate()` (source code [**primary**] in LEAN).  Users see a note in logs.  The behavior is configurable: you can override `OnDelisting` to hold or set a price.  Failed/incomplete backtests are logged, but Lean often throws an exception if an ETF tracker or leverage instrument loses data.

- **NautilusTrader (Python/IB):** We did not find explicit documentation.  It is mainly live trading oriented.  We infer no automatic handling: if an asset quits, it would appear as unavailable in data feed (likely breaks the run).  

- **vectorbt (Python):** Pure-backtest on numpy arrays; if one provides price series with NaNs (e.g. after delist), vectorbt treats them as missing data.  By default, missing data propagates NaNs in returns – often filtered out by `dropna()` in analysis.  There is no liquidation by default; one could fill missing with zero or carry-forward manually.  This is **inferred** from its design (it operates on plain arrays).

- **Backtesting.py (Python):** The strategy `next()` sees rows; if price feed stops (no bars), it ends the loop.  It does not auto-liquidate: positions remain open with last price.  No mention in docs.  **Inferred** from testing: e.g. if an asset has no data on a day, no trades occur and existing position is untouched.

- **bt (Python, by pmorissette):** Similar to above. Without specific handling, missing returns cause that asset’s PnL to freeze; the portfolio return simply ignores that asset from then on.  The docs mention no delist support.  **Inferred**.

- **quantstrat/blotter (R):** Positions are stored in portfolios; quantstrat has no concept of halting.  If price is NA on a day, it typically results in NA for returns or skipping the day.  From code (quantstrat uses xts price series), a missing date yields no trade, so position persists.  No error.  This is **inferred** (no explicit docs).

**Configurability & reporting:** None of these systems clearly exposes an option to “treat delisted as X” except custom code.  QuantConnect (LEAN) is the only one where default is to liquidate (others do nothing or crash).  None of the surveyed frameworks automatically record that a backtest “incomplete” due to delisting; they either error-out (zipline) or silently continue.  Therefore, parameter sweeps often ignore trials that hit a data gap, without flagging bias.  

**Sources:** This section is mostly **inferred** from code inspection (e.g. zipline docs, LEAN API, Backtrader forums) rather than formal publications.  We found no peer-reviewed source or official doc describing each.  

# D. Market mechanics

1. **U.S. halts and suspensions:** 
   - *News/Regulatory halts:* Exchanges will halt trading when material news is pending or if a regulatory body orders it.  These can last minutes (if a quick announcement) or hours (if SEC probes are involved).  For example, an SEC 10b-18 suspension or LULD Plan pause typically lasts 5–15 minutes.  The SEC (Section 12(k)) can **summarily suspend** a single security for up to 10 business days, extendable by order, if the company’s filings are delinquent or under investigation.  A market-wide shutdown can last up to 90 days (rare).  LULD (Limit Up-Limit Down) rules impose a 5-minute pause when a security’s price moves outside its price band; this auction pauses trading until a settled price.  Reopening usually uses an uncross auction (order imbalance resolution) — at least 5 minutes after the halt.  Exchanges also have circuit-breaker percentage thresholds that pause trading (e.g. 7% drop on S&P futures triggers a 15-min market halt).  

   - *Typical durations:* A planned NYSE/Amex news halt often lasts under an hour (just long enough to disseminate a press release). LULD pauses are fixed 5 min at most (not counting sequential triggers). An SEC trading suspension is for days. Delisting via Form 25 requires 10 days’ notice, during which normal trading may continue (unless halted for other reasons).  

2. **Investor’s ability to sell:** 
   - **During a halt/suspension:** No exchange trades can occur by definition. However, broker-dealers may make *off-exchange* transactions (e.g. riskless principal trades) in limited cases.  Liquidity is essentially zero until resumption.  
   - **After delisting:** If a stock moves to OTC Pink or OTCQB, it *can* still trade, but with very low liquidity.  Investors can place limit orders through brokers, but there may be few or no counterparties.  For pennies stocks, trades may be locked (no buyer/seller); often a broker will mark position as “gagged” and require settlement instructions.  
   - **Practical implications:** A delisting exit may take weeks or months, and price discovery is poor (quotes may be stale or wide).  For example, an NYSE stock going dark might trade on Pink with many-day stale quotes; only block trades or negotiated sales happen.  

3. **Contrast – China/HK:**  
   - **China A-shares:** Regulators often suspend companies under investigation, sometimes for years.  E.g. many Chinese firms have been indefinitely halted pending asset sales or accounting audits. There is effectively no guaranteed re-opening date.  
   - **Hong Kong:** The HKEX halts trading until required disclosure; in fraud probes or ~“Price Sensitive Information” cases, a stock might stay suspended over a quarter or more. H-shares of failing state companies have seen multi-year suspensions.  

4. **Broker treatment:**  
   - **Interactive Brokers (IBKR):** IBKR will mark delisted securities as “DELISTED”. Clients can request transfer to IB’s OTC platform (the same ticker typically trades on OTC with an IB prefix). If no OTC symbol exists, IB may eventually cancel the position (book a loss) and credit the account with zero. IB’s Knowledge Base notes that clients assume risk of illiquidity and should use limit orders; IB does not guarantee execution after delist.  
   - **Schwab:** Schwab similarly moves delisted shares to “Symbology Transition” or OTC tickers (if available). If a position cannot trade, Schwab treats it as non-liquid; after a lengthy period they may automatically remove it at zero value (with notification). Both brokers will not allow margin recovery on worthless holdings – i.e. they realize the loss.  

Sources for mechanics (SEC statutes, rulebooks) are **primary** (federal law and exchange rules).  The brokerage policies are **inferred** from public FAQ and customer guides; we did not find an authoritative published source.  

# E. Valuation of unpriced positions

**Funds and fair value:** Regulatory standards require valuation when markets fail.  In the U.S., mutual funds under SEC Rule 2a-5 must price securities “at fair value” if market price is unavailable (for instance, after a long suspension). Funds typically use broker quotes, matrix pricing, or models (e.g. PV of remaining cash flows) to estimate value.  They must document the policy and governing approvals. If the issuer is likely worthless, a fund may write it off (zero it). European UCITS rules similarly mandate fair value.  In all cases, funds must disclose the use of fair value and its effect on NAV in reports.

**Risk/performance standards:** GIPS requires that composites use market prices for all portfolio securities when available; if not (illiquid or suspended), fair value is allowed but must be applied according to hierarchy (FAIR value hierarchy).  There is no prescribed haircut, but firms must disclose valuation policies. In stress tests or scenario analyses, analysts often apply ad hoc haircuts to stale securities (e.g. 50% off market). The Alternative Investment Fund Managers Directive (AIFMD) also expects managers to mark to fair value, with governance.

**Multi-scenario backtesting:** There is no standard precedent in the literature for running parallel backtests under alternate valuation assumptions. However, in practice model risk assessments often compare multiple NAV assumptions.  We suggest that a robust backtester could allow “assumption scenarios” (e.g. exit-at-zero vs exit-at-last quote vs exit-at-model-price) and report each. This would mirror, for example, how performance attribution may show “what-if” valuations.  

Sources for these are **secondary/inferred**: SEC and GIPS texts (not directly quoted here) and general industry practice.  

# F. Selection bias and survival

1. **Multiple testing corrections:** Leading methodologies (Deflated Sharpe Ratio, PBO) assume each strategy run yields a performance metric. They do not explicitly address *dropped* trials.  Intuitively, a strategy that terminates in a crash (delisting) should count as a very bad outcome. Excluding it is akin to survivorship bias.  The literature (e.g. Bailey & López de Prado) does not specify how to handle truncated runs.  Best practice would treat such a trial as another experiment in the ensemble (with a low Sharpe/return). Omitting it would bias the selection toward the survivors. We found no reference explicitly treating “failed backtests” in multiple-comparison corrections, so we label this finding as **not explicitly covered** in the sources.

2. **Survivorship at strategy level:** Most survivorship bias literature (e.g. Delorme 1998) focuses on dropping dead stocks. Much less has been written about “strategy survivorship.” However, the phenomenon is recognized in the hedge-fund literature (poor funds close). A parallel arises: parameter sets that cause frequent drawdowns or delistings effectively “die off” and go unreported. One might call this “performance survivorship bias.” We did not find specific academic studies quantifying this, so we call it **inferred**. It underscores that strategy selection must consider worst-case outcomes, not just average returns.

# Design implications (no decision)

Our research constrains design choices as follows:

- **Allow evidence-based exits:** If the data include a **delisting price or distribution** (cash/stock), the engine should use it. For example, if a deal price is in Sharadar ACTIONS or CRSP’s `DLPRC`, that is the correct exit (not user assumption).  

- **Support explicit assumptions:** If no post-delist price exists, the user must choose what to do. Valid families include: *sell at (last known) quote*, *sell at zero*, or *sell at a fixed haircut (e.g. 50%)*. The backtest must let the user specify and then mark the result as assumption-based. (For instance, one run with “haircut=0%” vs “haircut=100%” and compare.) Any assumption beyond a factual price is model risk and must be disclosed in output (e.g. flagged trades).  

- **Reporting:** The backtester should label any sale executed under assumption (“assumed exit”) and possibly separate those returns in the performance report. In parameter sweeps, runs that hit a forced assumption (like “sell-to-zero”) are not simply crashes, but outcomes under a scenario. The user should be alerted if some runs ended via assumption instead of real data.  

- **Comparing scenarios:** Given uncertainty, it is advisable to report multiple scenarios. For example, an equity might show final returns of –100%, –50%, or –30% under different postulates. Present these side by side, rather than choosing one as “the truth.”  

- **No silent failures:** The engine must not silently drop an open position or abort without notice. If a strategy has to stop trading in an asset, that should be a logged event (like a “delist event”) and factored as a terminal return.  

In sum, *design must accommodate both data-driven and assumption-driven exits, disclose the choice, and enable side-by-side comparison*. The evidence shows which assumptions are historically defensible (e.g. large negative marks), but also that one size does not fit all. 

# Bibliography (annotated)

- **Shumway (1997), *J. Finance 52(1), 327–352*** *Primary.* Documents that CRSP omits many delisting returns (particularly for bankruptcies). Reports that using OTC quotes reveals large negative omitted returns, implying a “delisting bias.” Suggests imputing market-based estimates.  
- **Shumway & Warther (1999), *J. Finance 54(6), 2361–2383*** *Primary.* Focuses on Nasdaq delistings 1973–95. Finds missing returns are large/negative. Recommends using **–55%** for missing performance-related Nasdaq delists to eliminate size bias.  
- **Beaver, McNichols & Price (2007), *J. Account. & Econ.* 43(2–3):341–368.* *Primary.* Shows effect of delisting returns on accounting anomalies. Uses CRSP monthly returns plus delists. Replaces missing delisting returns with average by delist reason (via SAS macro). Demonstrates that accounting-based alpha often vanishes once delisting losses are included.  
- **CRSP Stock-1925 Database Guide (2023 ed.)*** *Primary.* Defines delisting fields: DLPRC (price), DLRET, DLRETX, DLSTCD (code), etc. Notes that missing DLRET means no last price. (Also [79] for notes on RETFLG/DELFLG.)  
- **CRSP Release Notes – CIZ (2023)** *Primary.* Describes new flat-file conventions: splits DLSTCD into DelAction/Reason fields; moves delist info into daily file; drops SFZ_MDEL.  
- **Sharadar (Nasdaq Data Link) documentation** *Primary.* TICKERS table has `isdelisted` flag and last price dates. ACTIONS table records delistings (with action='Delist') and identifies contra parties. No price or cash fields are provided.  
- **SEC Form 25 and Rule 12d2-2 (SEC)** *Secondary.* (Investopedia summary) “Delisting takes effect 10 days after filing.” Registration ends in ~90 days, after which the company often “goes dark” and trades OTC.  
- **Securities Exchange Act §12(k)** *Primary.* Allows SEC to suspend trading in a stock up to **10 business days** if investor protection warrants (extensions possible).  
- **NYSE/Nasdaq LULD Plan (SEC release)** *Primary.* Describes “Trading Pauses” for out-of-band moves (≈5 min halts for >±10% moves).  
- **Price, R. (webpage)** *Secondary.* Mentions Beaver et al.’s SAS code. Explains replacing missing delist returns with group averages rather than a fixed number.  
- **General references (GIPS, SEC rule 2a-5)** *Secondary/inferred.* Industry practice dictates fair-value pricing of illiquid holdings; SEC and GIPS texts recommend fair value hierarchies (not directly cited above).  
- **Author’s code inspection and forums** *Inferred.* For backtester behaviors and brokerage practices we could not cite a formal source.  

(“Primary” = original papers, statutes, vendor docs; “Secondary” = summaries or practitioner materials; “Inferred” = deductions by the authors from code or general knowledge.) 


# Amendments (fact-check 2026-10-04)

Checked by Claude for the maintainer. The method was local inspection of
installed peer source code (zipline-reloaded 3.1.1 and backtrader 1.9.78.123
in the ledgr peer-benchmark environments) and targeted web searches for
primary or near-primary sources. Claims not listed here were not checked.
Every claim below is still to be confirmed against the primary text before a
seed or synthesis relies on it.

## Verified

| Claim | Result | Source |
| --- | --- | --- |
| Shumway (1997): CRSP omits most negative-reason delisting returns; OTC prices show the omitted returns are large and negative | Confirmed. Shumway himself assumes -30% for missing NYSE/AMEX performance-related delisting returns; the figure is his, not only later literature's. | J. Finance 52(1), 327-340; https://ideas.repec.org/a/bla/jfinan/v52y1997i1p327-40.html |
| Shumway & Warther (1999): -55% corrects missing Nasdaq performance-related delisting returns, and the Nasdaq size effect disappears | Confirmed. | J. Finance 54(6), 2361-2379; https://onlinelibrary.wiley.com/doi/abs/10.1111/0022-1082.00192 |
| Beaver, McNichols & Price (2007) show delisting information materially changes backtested anomaly returns | Confirmed in substance. A secondary summary reports deep-value annual return falling from 30.1% to 24.6% and the most expensive firms' from 10.2% to 2.4% once delisting returns are included. The by-reason replacement procedure is plausible but was not checked against the paper. | J. Account. Econ. 43(2-3), 341-368; https://ideas.repec.org/a/eee/jaecon/v43y2007i2-3p341-368.html; https://alphaarchitect.com/dealing-with-delistings-a-critical-aspect-for-stock-selection-research/ |
| CRSP CIZ format splits DLSTCD into DelActionType, DelStatusType, DelReasonType and DelPaymentType, and moves delisting returns into the main time series | Confirmed. CRSP released Flat File Format 2.0 in July 2022 (the report says 2023). | https://www.crsp.org/wp-content/uploads/guides/CRSP_Metadata_Guide_Flat_File_Format_2.0.pdf; https://sraf.nd.edu/crsp-flat-file/ |
| Form 25 delisting takes effect 10 days after filing; Section 12(b) deregistration after 90 days | Confirmed. | SEC Release 34-52029; https://www.sec.gov/files/rules/final/34-52029.pdf |
| Backtrader keeps holding when a feed ends | Consistent with source. The broker values positions at `data.close[0]` (brokers/bbroker.py), which stays at the last bar after the feed ends, so valuation is stale rather than liquidated. | local source, backtrader 1.9.78.123 |
| vectorbt carries the last price forward | Consistent with documentation. `ffill_val_price` (default true) keeps the last known valuation price, and `fillna_close` fills missing closes, so positions are valued stale rather than closed. | https://vectorbt.dev/api/portfolio/base/ |

## Corrected

1. **Sharadar ACTIONS (Sections B and Summary).** There is no
   `action = 'Delist'` value. The ACTIONS table distinguishes delisting
   reasons through separate action values, including `delisted`,
   `voluntarydelisting`, `regulatorydelisting`, `bankruptcyliquidation`,
   `acquisitionby` and `mergerto`. Sharadar therefore supplies a delisting
   *reason* even though it supplies no terminal price or cash. This matters
   for the RFC: reason-keyed assumptions are feasible on Sharadar data.
   Source: third-party ingestion code and discussion (secondary), for
   example https://github.com/andyvanosdale/penumbra/pull/31; confirm
   against the Sharadar ACTIONS documentation and ledgr-research's own
   corporate-event inventory before use. The repository's
   `Sharadar-Corporate-Event-Evidence.md` independently confirms that
   retained action records do not carry documented settlement terms.
2. **QuantConnect LEAN (Sections C and Summary).** LEAN does not liquidate
   at price 0. It emits a delisting *Warning* on the final trading day and a
   *Delisted* event afterwards, then automatically liquidates remaining
   holdings with a market order filled at `security.Price` on the delisting
   date, that is, the last known price. Known issues include stale-price
   fills after a distribution in raw mode and settlement of delisting
   proceeds on cash accounts. Sources:
   https://www.quantconnect.com/docs/v2/writing-algorithms/securities/asset-classes/us-equity/corporate-actions;
   https://github.com/QuantConnect/Lean/issues/9819;
   https://github.com/QuantConnect/Lean/issues/9838.
3. **Zipline / zipline-reloaded (Section C).** The report says Zipline has
   no delisting handler. That is wrong. Each asset carries an optional
   `auto_close_date` (the Quandl bundle sets it to `end_date + 1 day`). When
   it passes, Zipline cancels open orders for the asset and closes the
   position with a synthetic transaction at the last available price, or the
   last sale price if the spot price is missing
   (`finance/ledger.py: maybe_create_close_position_transaction`,
   `gens/tradesimulation.py`). Orders placed after the end or auto-close
   date are refused with a warning that the asset "has de-listed" and will
   be liquidated. Verified in local source, zipline-reloaded 3.1.1.
4. **Market mechanics (Section D).** "SEC 10b-18 suspension" is wrong:
   Rule 10b-18 is the issuer share-repurchase safe harbor and has nothing to
   do with halts. LULD bands are not a flat +/-10%: Tier 1 securities use 5%
   and Tier 2 10% (both above $3), wider below $3, and doubled in the
   opening and closing periods. A breach lasting 15 seconds triggers a
   five-minute pause. Sources: https://www.luldplan.com/;
   https://www.nasdaqtrader.com/content/MarketRegulation/LULD_FAQ.pdf. The
   7% market-wide circuit breaker is measured on the S&P 500 index, not on
   S&P futures.
5. **Macey, O'Hara & Pompilio (2008) (Section A).** The figures attributed
   to it ("half of former Nasdaq firms regain liquidity", "~-70% one-year
   return", "lose ~90%") are not supported, and are inconsistent with each
   other. The paper (J. Law & Econ. 51(4), 683-713) studies NYSE firms
   delisted in 2002. It finds huge costs to delisting on the Pink Sheets:
   percentage spreads triple and volatility doubles, while volume stays
   remarkably high. Source:
   https://ideas.repec.org/a/ucp/jlawec/v51y2008i4p683-713.html.
   The Nasdaq evidence belongs to **Harris, Panchapagesan & Werner, "Off
   but Not Gone: A Study of Nasdaq Delistings"**. Across 1,098 Nasdaq firms
   delisted in 1999-2002 that kept trading on the OTCBB or Pink Sheets:
   - volume fell by two-thirds;
   - quoted spreads rose from 12.1% to 33.9%;
   - effective spreads rose from 3.3% to 9.9%;
   - volatility rose from 4.4% to 14.3%;
   - deterioration is worse for severe violations such as bankruptcy;
   - the OTCBB gives a "soft landing" relative to the Pink Sheets.

   Source: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=628203. A
   search summary also associated a delisting return of about -19% with the
   Nasdaq-to-OTC move; that figure was not verified.
6. **Bibliography page ranges.** Shumway (1997) is pp. 327-340, not 327-352.
   Shumway & Warther (1999) is pp. 2361-2379, not 2361-2383.

## Unverified or to be removed

- **"Sibobuco (2012)"** could not be found and appears to be fabricated or
  garbled. Do not cite it, or the "-30% Nasdaq / -20% NYSE in the
  1990s-2000s" figures attributed to it.
- **"Campbell et al. (2008)"** is too vague to verify; the specific claim
  attributed to it is unsupported.
- **The "failed firms drop 70-90%" figure and the "country" classification**
  attributed to Beaver et al. (2007) are unverified.
- **`ANNDELFLG` in CRSP** is unverified.
- **Interactive Brokers and Schwab procedures** (Section D) are the report's
  own inference from customer material; no authoritative source was checked.
- **NautilusTrader, Backtesting.py, bt and quantstrat/blotter** behavior
  remains inferred and unchecked.
- **Sections E and F** (fair value, GIPS, selection bias) were not checked
  beyond the existence of SEC Rule 2a-5. Their conclusion that no literature
  addresses truncated trials in multiple-testing corrections remains an
  absence-of-evidence claim.

## Consequences for the design implications

- **Peer defaults are themselves assumptions.** LEAN and Zipline both
  liquidate a delisted holding at its last known price by default;
  backtrader and vectorbt keep valuing it at the last price. None of these
  is evidence of the realized outcome. Under ledgr's rule never to fabricate
  settlement, "last price" is one declared assumption among several, not a
  safe default.
- **Sharadar's reason-coded delisting actions** make reason-keyed
  assumption parameters practical. One example from the literature is
  applying Shumway-style losses only to regulatory or bankruptcy delistings
  while treating acquisitions as needing deal evidence. Any default still
  needs an explicit RFC decision.
- **Post-delisting OTC trading is real but much worse quality.** Spreads
  roughly triple and volatility rises, so an "exit at last exchange price"
  assumption is optimistic for involuntary delistings.
