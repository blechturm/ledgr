# Ragged Universes Without Research Leakage

## External prior-art review for ledgr

Audience: ledgr maintainers and reviewers
Research date: 4 September 2026
Scope: external prior art for ragged equity universes, unavailable observations, valuation, execution, point-in-time data, deterministic replay, and ML imputation
Evidence policy: official documentation and versioned source first; peer-reviewed and working papers for methodology; issue reports are explicitly labeled and never treated as guarantees

### Direct answer

ledgr should not replace its strict dense-panel invariant with permissive NA handling. The defensible direction is a layered model: keep the existing complete dense mode unchanged; represent lifetime, expected observation, observed fact, valuation eligibility, feature validity, and execution eligibility independently; and materialize dense arrays with masks only at strategy or fold boundaries. This direction is strongly supported by Zipline’s date-by-asset lifetime mask, Qlib’s dated instrument spans and point-in-time revision traversal, event-driven systems’ separation of arrival from global grids, and statistical models that consume rectangular arrays together with masks. None of those systems, however, provides a complete solution for ledgr.

The most consequential finding is negative. Frameworks that “support missing data” routinely encode economically different states with the same value: LEAN fill-forwards by default and permits stale market-order fills; vectorbt can backward-fill leading prices for post-simulation valuation; NautilusTrader can emit unflagged flat internal bars during a complete feed gap; Qlib treats all-NaN quotes as suspended but leaves stale-position valuation unclear; and quantstrat’s cross-symbol aggregation can omit an absent symbol’s value at a timestamp. These behaviors show why simple permissiveness is not a safe target. [LEAN fill concepts](https://www.quantconnect.com/docs/v2/writing-algorithms/reality-modeling/trade-fills/key-concepts) [vectorbt Portfolio](https://vectorbt.dev/api/portfolio/base/) [Nautilus issue 4594](https://github.com/nautechsystems/nautilus_trader/issues/4594) [Qlib Exchange](https://github.com/microsoft/qlib/blob/main/qlib/backtest/exchange.py) [blotter updatePortf](https://github.com/braverock/blotter/blob/master/R/updatePortf.R)

The initial engineering priority should be semantic preservation and execution safety, not sophisticated imputation. Raw observations and their absence must survive unchanged; stale marks must never silently become fills; terminal outcomes must not disappear with the row; and every fitted transform must be train-fold-local. Advanced imputation can then be added as an explicit model artifact rather than a repair performed while sealing source data. [Freyberger et al.](https://academic.oup.com/rfs/article-abstract/38/3/760/7590858) [scikit-learn leakage guidance](https://scikit-learn.org/stable/common_pitfalls.html)

---

# 1. Executive assessment specific to ledgr

## 1.1 What the current invariant gets right

The current fail-fast design protects three properties that permissive systems often weaken: it prevents accidental use of non-finite OHLC, produces a simple and stable strategy interface, and makes run/sweep equivalence easier to test. The review found no evidence that replacing this invariant with generic NA tolerance would be safer. In several systems, “helpful” filling or dropping changes economic meaning without an error. LEAN marks fill-forward data but enables it by default; vectorbt’s reporting layer may forward- and backward-fill close; and Qlib’s standard processors include both row deletion and zero fill. [LEAN requesting data](https://www.quantconnect.com/docs/v2/writing-algorithms/securities/requesting-data) [vectorbt Portfolio](https://vectorbt.dev/api/portfolio/base/) [Qlib processors](https://github.com/microsoft/qlib/blob/main/qlib/data/dataset/processor.py)

Fail-fast is therefore valuable as a mode and migration oracle. It is not sufficient as the only research universe. If a user obtains a valid run by keeping only complete instruments, the error has moved from software validation into sample selection. In a large U.S. equity characteristic panel, complete cases were only about 10% of observations, and larger firms were still often incomplete. Complete-case filtering can discard useful firms and, under non-random missingness, change the population being studied. [Freyberger et al.](https://bfi.uchicago.edu/wp-content/uploads/2023/01/BFI_WP_2022-168.pdf)

## 1.2 The design conclusion

No reviewed architecture dominates:

- Event-driven engines represent ragged arrivals naturally and offer clean causal sequencing, but they give matrix-oriented strategies less ergonomic data and may never construct an expected-observation grid.
- Dense matrix systems are fast and convenient, but a NaN cell usually fails to distinguish pre-listing, holiday, halt, source outage, invalid value, feature warm-up, and terminal state.
- Dynamic universes prevent some future-membership leakage, but they introduce order/state retention rules and can complicate reproducible interfaces.
- Dense arrays with masks are statistically legitimate, but masks alone do not define execution, terminal payoff, or revision visibility.
- Sparse storage with fold-local dense materialization separates physical representation from model input and is the most credible long-run hybrid, but it requires more indexing and cache machinery.

The best-supported ledgr direction is therefore evolutionary:

1. Preserve strict complete-panel behavior exactly for existing snapshots.
2. Add a semantically ragged snapshot capability whose facts, states, and explanations are distinct.
3. Gate execution on fresh eligible market evidence or an explicit terminal-event rule, never on a carried or imputed value.
4. Permit policy-governed stale valuation with age, source, and confidence visible.
5. Materialize dense values plus masks per run or fold; do not infer observation truth from rectangular shape.
6. Treat publication and revision history as part of reproducible data identity, not merely timestamps inside features.
7. Require a real-data spike before selecting storage layout, mask granularity, and strategy API.

## 1.3 Evidence-strength classification

| Classification | Meaning in this report |
|---|---|
| Supported strongly by prior art | Multiple independent primary sources or direct system behavior support the principle. |
| Plausible, ledgr-dependent | Prior art supports the mechanism, but ledgr ergonomics or performance determine the choice. |
| Requires empirical validation | Correctness is plausible, but real data or benchmarks must determine feasibility and policy. |
| Unresolved | Primary evidence is absent, contradictory, or the choice is inherently product-specific. |

# 2. Vendor-neutral terminology and taxonomy

The central modeling error to avoid is collapsing multiple questions into one field such as `gap_type`. Nasdaq publishes trading and resumption state separately from market observations; CRSP maintains distinct price-type, missing-return, delisting, distribution, and identity information; and Zipline separates asset lifetime, current raw OHLC, a forward-held `price`, staleness, and trading permission. [Nasdaq halt codes](https://www.nasdaqtrader.com/Trader.aspx?id=TradeHaltCodes) [CRSP guide](https://indexes.morningstar.com/docs/guide/crsp-us-stock-databases-guide-for-flat-file-format-2-0?isRdp=true) [Zipline API](https://zipline.ml4trading.io/api-reference.html)

| Term | Precise meaning | What it must not imply |
|---|---|---|
| Instrument identity | Stable key for the economic security or contract being modeled. | A current ticker is not a durable identity. |
| Symbology interval | Time-bounded association between an instrument and ticker, venue symbol, or vendor identifier. | A ticker string must not imply continuity across reuse. |
| Listing episode | Interval during which an instrument is admitted to a venue under a particular listing. | Corporate existence and trading eligibility are not the same. |
| Universe membership | Eligibility under the strategy’s selection rule at a decision time. | Existence in the snapshot superset is not membership. |
| Session eligibility | Whether the relevant venue/calendar defines the instant or date as a trading session for the instrument. | An open venue does not prove the instrument traded. |
| Expected observation | A data-contract assertion that a record should exist for an instrument and interval. | Absence outside the contract is not an error. |
| Observed fact | A value directly present in the pinned source record after validation. | Synthetic, imputed, or carried values are not observed. |
| Observation absence | No accepted source fact is present for the cell. | The cause may remain unknown. |
| Missing expected observation | An expected observation is absent. | It does not by itself identify outage, halt, or illiquidity. |
| Quality state | Validity and provenance status such as observed, duplicate-resolved, corrected, late, synthetic, invalid, or quarantined. | Quality is independent of lifetime and tradability. |
| Valuation mark | Price used to estimate current position value under an explicit policy. | A valuation mark is not evidence of executable liquidity. |
| Stale mark | A valuation mark whose source observation precedes the valuation instant. | “Stale” requires an age; it is not a single timeless Boolean. |
| Execution evidence | Market datum or explicit terminal-event rule admissible for filling an order. | A forward-filled or imputed value is not admissible by default. |
| Trading state | Known venue/instrument status such as trading, quoting-only, halted, paused, closed, deleted, or unknown. | A missing bar cannot safely infer the state. |
| Feature validity | Whether a feature exists under its source, warm-up, and transformation rules at decision time. | Feature NA must not be conflated with missing source OHLC. |
| Label observability | Whether the target outcome is observed for the defined horizon. | A delisting payoff and ordinary right-censoring are different. |
| Terminal economic event | Delisting, bankruptcy recovery, cash acquisition, conversion, or other event resolving the asset’s future value. | Disappearance from the price table is not a zero return. |
| Valid/effective time | Time for which a fact describes the modeled world. | It is not necessarily when anyone knew the fact. |
| Publication/availability time | Earliest defensible time the fact was public or supplied to the strategy. | Fiscal period end is not publication time. |
| Ingestion/transaction time | Time the fact entered the controlled data system. | It does not prove public availability. |
| Revision interval | Interval during which one version was the latest available version. | Current restated data must not overwrite historical knowability. |
| Decision time | Time at which the strategy’s information set is evaluated. | Later corrections cannot enter the information set. |

Temporal-database terminology supports the separation: valid time describes when a fact is true in modeled reality; transaction time describes when it is stored; a bitemporal relation carries both. ALFRED operationalizes a similar idea by tabulating observation dates against vintage dates and by storing real-time validity intervals for revisions. [Temporal database glossary](https://sigmodrecord.org/publications/sigmodRecord/9209/pdfs/140979.140996.pdf) [ALFRED vintage documentation](https://alfred.stlouisfed.org/help/downloaddata)

For ledgr, these terms imply a state vector, not a single categorical gap reason. At minimum, the engine must be able to answer independently: does the instrument exist; is it in the point-in-time universe; was an observation expected; was one actually observed; is a mark available and how old is it; is execution allowed; is a feature valid; and which revision was knowable? The exact field layout remains an RFC question.

# 3. System comparison matrix

Evidence labels: D = explicit official documentation; S = behavior inferred from versioned source/tests; OI = official issue report, not a guarantee; U = not found or unresolved.

| System / baseline | Runtime and universe model | Unavailable observation | Valuation | Execution | PIT / replay | Primary ledgr lesson |
|---|---|---|---|---|---|---|
| QuantConnect LEAN; current v2 docs, accessed 2026-09-04 | Event-driven synchronized timeslices; per-security exchange schedules; dynamic universe add/remove; stable `Symbol` through ticker changes. D | Fill-forward is default and marked `IsFillForward`; disabled subscriptions may simply yield fewer records. D | Latest security price remains usable; stale age threshold is configurable, but reviewed docs do not expose a complete stale-mark policy. D/U | Built-in market orders may fill on stale data; limit/stop families wait for post-order, non-stale data. D | Users must timestamp custom data by actual availability; no generic bitemporal revision reconstruction or immutable input hash found. D/U | Synthetic provenance is useful, but stale valuation must be barred from execution by construction. |
| zipline-reloaded 3.1.1, tag commit 09885a2 | Event simulation plus dense Pipeline workspace; stable SID; dated lifetimes mask; exchange calendars. D | Raw current OHLC are NaN without a trade, volume is 0, `price` is last known close, and `is_stale` is explicit. D | Held positions keep prior last sale. S | Zero-volume/NaN-close bar does not fill; default GTC order persists. Auto-close may force a stale-price liquidation. S | Atomic bundle ingestion and dated symbol lookup exist; no generic fundamental revision store/live parity guarantee. D/U | Strong precedent for dense superset + lifetime mask and stale mark + no normal fill; terminal close policy remains hazardous. |
| NautilusTrader stable 1.231.0; current v2 docs / 2.0.0rc4 | Multi-venue event streams; same core components in backtest/live; stable sort by `ts_init`. D | External missing bars are absent events. Internal time bars default to no-update construction; issue evidence shows flat unflagged bars during outages. D/OI | Portfolio carries last valid mark and reports stale/unpriced instruments. D | External bars drive matching; synthetic internal bars do not. Halt events exist, but automatic execution gating is not documented. D/U | `ts_event` and `ts_init`, replay ordering, seeds, and run manifests are explicit; market-data completeness remains outside the event log. D | Event sourcing and provenance are exemplary; event absence still needs an expected-data contract. |
| vectorbt 1.1.0, commit 259d2d8 | Vectorized pandas/NumPy arrays aligned to a common axis; symbol-keyed, no dated security master found. D/U | Union alignment yields NaN; default missing index policy is permissive. D | Latest valuation can be carried; post-simulation close can be forward- and backward-filled. D | NaN order inputs are skipped/ignored/rejected by code path; no built-in pending retry contract. D/S | Saving omits global defaults unless explicitly passed; no automatic dataset/environment hash. D/U | Dense convenience is not enough: backward-filled reporting and symbol-only identity can leak or misstate history. |
| Microsoft Qlib 0.9.7; current docs 0.9.8.dev11 and main commit 79633dd | MultiIndex `(datetime,instrument)`; dated instrument spans and dynamic filters; shared calendar. D | Suspended OHLCV/factor fields are NaN; all-NaN current quote is nontradable. D | Previous-close fallback for held suspended positions was not established. U | Nontradable order gets zero dealt amount and NaN price; canonical strategy skips it. D/S | Local PIT provider selects records as of current time and traverses revisions; processors require explicit fit windows. D | Strong prior art for dated lifetimes and PIT revisions; fold safety is configured, not guaranteed. |
| quantstrat 0.25 + blotter 0.17.0 + FinancialInstrument 1.4.1 | Symbol-local irregular `xts`; strategy loops portfolio symbol list; no dated dynamic membership engine. D/S | No symbol row means no indicator/rule processing; NA signals do not fire. S | `updatePosPL` can use prior price and LOCF. D | GTC limit/stop orders remain open and can fill on a later observed row. S | Walk-forward audit environments exist; no automatic snapshot hash, package lock, or revision cutoff. D/U | R-native ragged series are feasible, but cross-calendar portfolio aggregation and mutable global state need explicit safeguards. |

Sources: [LEAN timeslices](https://www.quantconnect.com/docs/v2/writing-algorithms/key-concepts/time-modeling/timeslices), [LEAN fills](https://www.quantconnect.com/docs/v2/writing-algorithms/reality-modeling/trade-fills/key-concepts), [Zipline API](https://zipline.ml4trading.io/api-reference.html), [Zipline slippage 3.1.1](https://github.com/stefan-jansen/zipline-reloaded/blob/3.1.1/src/zipline/finance/slippage.py), [Nautilus data](https://nautilustrader.io/docs/latest/concepts/data/), [Nautilus portfolio](https://nautilustrader.io/docs/latest/concepts/portfolio/), [vectorbt data](https://vectorbt.dev/api/data/base/), [vectorbt portfolio](https://vectorbt.dev/api/portfolio/base/), [Qlib data](https://qlib.readthedocs.io/en/latest/component/data.html), [Qlib source](https://github.com/microsoft/qlib/blob/main/qlib/data/data.py), [quantstrat README](https://github.com/braverock/quantstrat), [blotter source](https://github.com/braverock/blotter/blob/master/R/updatePortf.R).

# 4. Scenario-behavior matrix

## Scenarios 1–6

| # / scenario | LEAN | zipline-reloaded | NautilusTrader | vectorbt | Qlib | quantstrat stack |
|---|---|---|---|---|---|---|
| 1. IPO halfway through run | Dynamic universe can add the security; Security Master covers IPO/listing events, but invisibility of all future IDs is not guaranteed by reviewed docs. D/U | Lifetime mask is false before `start_date`; normal Pipeline output excludes it. D | Instrument definitions may arrive dynamically; no generic equity IPO lifetime guard found. U | Leading NaNs after alignment; no native dated membership. Post-simulation backward fill can populate leading valuation reports. D/S | Dated instrument spans exclude pre-listing dates. D | Symbol series can start at IPO, but portfolio symbol list is not a dated membership engine. S |
| 2. Held security delists | Final-day event and automatic liquidation; data-scope caveat. D | At `auto_close_date`, orders cancel and position closes; last-sale fallback can manufacture a stale-price close. S | Contract expiry close exists; generic equity delisting/forced close unresolved. U | Trailing NaNs may leave indefinite stale valuation; no terminal event model found. U | Lifetime can end and strategy may skip nontradable sale; later held valuation unresolved. U | No future rows; LOCF mark possible; no default delisting payoff. U |
| 3. Active stock misses one daily bar | Default synthetic fill-forward, flagged; disabled mode yields omission. D | Raw OHLC NaN, volume 0, stale price retained, no ordinary fill. D/S | External bar absent. Internal time aggregation may emit unflagged flat zero-volume bar unless disabled. D/OI | NaN after alignment; latest mark may carry; array order at NaN is not a pending order. D/S | NaN quote is treated as suspended and cannot fill. D | No row means no rule pass; prior GTC remains open; valuation may LOCF. S |
| 4. Halt for several sessions | Halt-specific automatic contract not found; fill-forward can continue and market orders can stale-fill. U/D | If represented as no trades, mark goes stale and orders persist without fills; no explicit halt state found. S/U | `InstrumentStatus` can say halt/pause, but automatic matching gate/cancel is undocumented. D/U | Generic NaN unless status is carried separately. U | Suspended-field convention prevents fills; reason granularity depends input. D | No halt state found; absent/NA rows resemble generic missingness. U |
| 5. Different exchange calendars | Per-security exchange schedules and synchronized end-times. D | Main simulation calendar plus asset exchange calendar in `can_trade`. D | Timestamped multi-venue streams; no comparable native session-calendar contract found. U | Union index creates NaNs on non-shared dates. D | Shared frequency calendar; per-instrument exchange schedules not documented. U | Symbol-local rule loops tolerate ragged dates, but portfolio aggregation can omit absent-symbol value. S |
| 6. Held position lacks current price | Latest/stale price remains available; complete stale-mark provenance not located. D/U | Last sale persists and values the position. S | Carries prior valid price and flags stale; never-priced instruments are separately reported. D | Latest valuation may be carried; filled-close analysis may also backward-fill. D | Exact previous-close valuation fallback not established. U | `updatePosPL` falls back to last price and LOCF. D |

Sources: [LEAN corporate actions](https://www.quantconnect.com/docs/v2/writing-algorithms/securities/asset-classes/us-equity/corporate-actions), [LEAN fill-forward](https://www.quantconnect.com/docs/v2/writing-algorithms/securities/requesting-data), [Zipline API](https://zipline.ml4trading.io/api-reference.html), [Zipline ledger 3.1.1](https://github.com/stefan-jansen/zipline-reloaded/blob/3.1.1/src/zipline/finance/ledger.py), [Nautilus instrument status](https://nautilustrader.io/docs/latest/concepts/data/instrument_status/), [Nautilus issue 4594](https://github.com/nautechsystems/nautilus_trader/issues/4594), [vectorbt Portfolio](https://vectorbt.dev/api/portfolio/base/), [Qlib Exchange](https://github.com/microsoft/qlib/blob/main/qlib/backtest/exchange.py), [blotter updatePosPL](https://github.com/braverock/blotter/blob/master/R/updatePosPL.R).

## Scenarios 7–12

| # / scenario | LEAN | zipline-reloaded | NautilusTrader | vectorbt | Qlib | quantstrat stack |
|---|---|---|---|---|---|---|
| 7. Target precedes missing next bar | Market order may fill immediately on stale data; limit/stop waits for later fresh post-order bar. D | Default GTC order persists; missing/zero-volume bar cannot fill; later valid bar may fill. S | No external bar means no matching update; other-instrument data cannot release delayed command against stale state; timer release basis remains unresolved. D/U | Shifted instruction at NaN price is skipped/failed; retry requires another instruction or custom callback. S | Nontradable interval produces no deal; later retry is strategy logic. D/S | Delayed GTC remains open and can fill on a later priced row. S |
| 8. Ticker changes, same instrument | Stable `Symbol`, map history, symbol-change event. D | Stable SID with dated lookup; unresolved issue warns default-date lookup can use future simulation context. D/OI | Identity is normalized symbol plus venue; generic dated alias map not found. U | User must map columns/identifiers. U | No dated alias/security-master behavior found in reviewed core. U | FinancialInstrument aliases exist but are not dated; symbol-keyed books need explicit continuity logic. D/U |
| 9. Fundamental published late, later restated | Custom data should use actual availability; restatement-vintage replay is not generic. D/U | No generic bitemporal fundamentals layer found. U | Dual timestamps can encode publication/receipt; revision chains remain user-defined. D/U | User must build an as-of panel. U | Local PIT provider filters by `cur_time` and walks revision-linked records when source is encoded correctly. D/S | No native PIT/revision store found. U |
| 10. Insufficient warm-up after listing | History can return fewer samples; indicator readiness is strategy-owned. D | Lifetime prevents pre-existence, while rolling terms may be missing until window exists. D | Cache/history checks and feature eligibility are strategy-owned. U | Rolling features remain NaN; reason is not structurally distinguished. D/U | Processors can drop/fill/normalize, but policy and fit window are configured. D | Indicator NA prevents active signal/rule; no explicit warm-up reason taxonomy. S |
| 11. Missingness concentrated in distressed names | No MNAR safeguard; fill-forward can hide concentration even though flagged. D/U | NaNs/stale flags preserve evidence better, but no MNAR policy. D/U | Stale tracker helps for external absence; unflagged synthetic internal bars can erase evidence. D/OI | Generic NaN handling only; reporting fill can obscure pattern. U | Zero fill/drop can erase or select missingness; no mechanism model. D/U | LOCF valuation and signal skipping may conceal the pattern. U |
| 12. Complete dense legacy data | Existing behavior when every expected bar is present; strict ledgr parity is an acceptance test, not a framework guarantee. | Missing/stale paths are inert; ordinary behavior. | External-bar path is ordinary; internal aggregation still config-dependent. | Alignment/fill paths are inert. | Suspension/drop/fill paths are inert on complete fields. | Ragged-calendar/LOCF paths are inert on a common complete index. |

Sources: [LEAN equity fill model](https://www.quantconnect.com/docs/v2/writing-algorithms/reality-modeling/trade-fills/supported-models/equity-model), [Zipline cancel policy](https://github.com/stefan-jansen/zipline-reloaded/blob/3.1.1/src/zipline/finance/cancel_policy.py), [Nautilus bar execution](https://nautilustrader.io/docs/latest/concepts/backtesting/bar-execution/), [vectorbt order enums](https://vectorbt.dev/api/portfolio/enums/), [Qlib PIT source](https://github.com/microsoft/qlib/blob/main/qlib/data/data.py), [quantstrat rule processing](https://github.com/braverock/quantstrat/blob/master/R/ruleOrderProc.R), [Freyberger et al.](https://academic.oup.com/rfs/article-abstract/38/3/760/7590858), [Shumway](https://doi.org/10.1111/j.1540-6261.1997.tb03818.x).

# 5. Detailed system findings

## 5.1 QuantConnect LEAN

Baseline: rolling official v2 documentation accessed 2026-09-04; the documentation changelog was current through 2026-08-27. Because the reviewed pages track a rolling engine rather than an exposed pinned binary, this report does not invent a version or commit. [LEAN changelog](https://www.quantconnect.com/docs/v2/meta/change-log) [LEAN repository](https://github.com/QuantConnect/Lean)

LEAN’s strongest contribution is the separation of dynamic membership, security identity, and per-security calendars. Timeslices synchronize data by end time while respecting resolution and time zone; dynamic universes add and remove securities; and a `Symbol` persists through ticker changes described by map files. Removed securities can remain active while held or while an order is open. These are useful precedents for a stable asset axis whose point-in-time eligibility changes without destroying economic state. [LEAN timeslices](https://www.quantconnect.com/docs/v2/writing-algorithms/key-concepts/time-modeling/timeslices) [LEAN universe concepts](https://www.quantconnect.com/docs/v2/writing-algorithms/universes/key-concepts) [LEAN corporate actions](https://www.quantconnect.com/docs/v2/writing-algorithms/securities/asset-classes/us-equity/corporate-actions)

Its missing-data behavior is deliberately permissive. Fill-forward is the default subscription setting, and generated data carry `IsFillForward`. With fill-forward disabled, history may contain fewer or no samples rather than an error. This gives strategies provenance but does not create an expected-observation contract. An absent daily bar can therefore become either a synthetic current slice item or no item, depending on configuration. [LEAN requesting data](https://www.quantconnect.com/docs/v2/writing-algorithms/securities/requesting-data) [BaseData.IsFillForward](https://www.lean.io/docs/v2/lean-engine/class-reference/classQuantConnect_1_1Data_1_1BaseData.html) [LEAN history](https://www.quantconnect.com/docs/v2/writing-algorithms/historical-data/history-requests)

Execution is the key warning. LEAN documents that pre-built fill models can fill market orders on data at least an hour old and warns that the price may be unrealistic. By contrast, its equity limit, stop, stop-limit, and trailing-stop paths reject stale data and require a best-effort bar after the order time. One framework therefore exhibits two different answers to the same missing-next-bar scenario based solely on order type. [LEAN fill concepts](https://www.quantconnect.com/docs/v2/writing-algorithms/reality-modeling/trade-fills/key-concepts) [LEAN equity fill model](https://www.quantconnect.com/docs/v2/writing-algorithms/reality-modeling/trade-fills/supported-models/equity-model)

Corporate actions are explicit: splits, dividends, symbol changes, and delistings are emitted as events; a warning precedes final delisting; and holdings are automatically liquidated. This is stronger than treating terminal disappearance as NA, but the economic price used by every terminal path remains feed/model-dependent. A 2026 issue report questions midnight delisting auto-liquidation behavior; it is contradictory evidence worth a regression test, not a normative contract. [LEAN corporate actions](https://www.quantconnect.com/docs/v2/writing-algorithms/securities/asset-classes/us-equity/corporate-actions) [LEAN issue 9512](https://github.com/QuantConnect/Lean/issues/9512)

For PIT data, LEAN instructs custom data authors to use the time the information actually became available. Its live-reconciliation documentation also explains that backtest data revisions and live arrival can diverge. No generic bitemporal restatement chain, vendor-release pin, or immutable source hash was found. [LEAN custom data](https://www.quantconnect.com/docs/v2/writing-algorithms/importing-data/streaming-data/custom-securities/key-concepts) [LEAN reconciliation](https://www.quantconnect.com/docs/v2/cloud-platform/live-trading/reconciliation)

## 5.2 zipline-reloaded

Baseline: version 3.1.1, released 2025-07-19; release tag short commit `09885a2`. Official documentation still identifies Zipline 3.0, so source-level execution claims are tied to the 3.1.1 tag. [zipline-reloaded PyPI](https://pypi.org/project/zipline-reloaded/) [zipline-reloaded releases](https://github.com/stefan-jansen/zipline-reloaded/releases)

Zipline offers the clearest direct prior art for dense matrices plus masks. Asset metadata carries `start_date`, `end_date`, `first_traded`, and `auto_close_date`; `AssetFinder.lifetimes()` produces a date-by-asset Boolean existence matrix; and Pipeline loaders receive dates, SIDs, and a root mask. Dense workspaces therefore do not require every cell to be an extant asset or observed fact. [Zipline API](https://zipline.ml4trading.io/api-reference.html) [Pipeline engine source](https://zipline.ml4trading.io/_modules/zipline/pipeline/engine.html)

The data portal separates raw and carried values. Current OHLC are NaN when the asset did not trade in the current period; volume is zero; `price` is the last known close; and `is_stale()` identifies a live asset without a current trade. If an asset never traded or is delisted, price can be NaN. The reviewed 3.1.1 slippage loop declines to fill when current volume is zero or current close is NaN, while the default cancel policy leaves GTC orders open. A later valid bar can therefore execute an order while the portfolio was marked through the gap. [Zipline API](https://zipline.ml4trading.io/api-reference.html) [Zipline slippage 3.1.1](https://github.com/stefan-jansen/zipline-reloaded/blob/3.1.1/src/zipline/finance/slippage.py) [Zipline cancel policy 3.1.1](https://github.com/stefan-jansen/zipline-reloaded/blob/3.1.1/src/zipline/finance/cancel_policy.py)

That separation is not complete at termination. At `auto_close_date`, the simulator cancels orders and closes a held position; source code falls back to the position’s last sale when the current price is NaN. The bookkeeping is deterministic, but the forced stale-price transaction may be economically wrong for bankruptcy, acquisition, or an illiquid delisting. [Zipline trade simulation 3.1.1](https://github.com/stefan-jansen/zipline-reloaded/blob/3.1.1/src/zipline/gens/tradesimulation.py) [Zipline ledger 3.1.1](https://github.com/stefan-jansen/zipline-reloaded/blob/3.1.1/src/zipline/finance/ledger.py)

Identity uses stable SIDs and dated symbol lookup. A current official issue reports that lookup without an explicit date can resolve against simulation-end context, potentially exposing future ticker ownership. The issue is unresolved evidence, but it illustrates a broader rule: a fixed asset superset is safe only when every membership, alias, statistic, and feature query is anchored to decision time. [Zipline API](https://zipline.ml4trading.io/api-reference.html) [zipline-reloaded issue 265](https://github.com/stefan-jansen/zipline-reloaded/issues/265)

Bundles atomically ingest pricing, adjustments, and an asset database, and can select an ingestion date. This improves reproducibility but is not a generic bitemporal fundamental store. The fork also does not document a live execution path that would establish backtest/live parity. [Zipline data bundles](https://zipline.ml4trading.io/bundles.html)

## 5.3 NautilusTrader

Baseline: stable 1.231.0, released 2026-08-02, attested commit `27a8e54e7ac3c57d6cbf8891f0283dfbaee97317`; current v2 documentation corresponds to rapidly evolving 2.0 release candidates, with 2.0.0rc4 released 2026-09-02 at short commit `a040025`. Claims below describe current v2 architecture and should be rechecked before adoption. [Nautilus releases](https://github.com/nautechsystems/nautilus_trader/releases) [Nautilus PyPI](https://pypi.org/project/nautilus_trader/)

Nautilus demonstrates a clean sparse/event runtime. The same message bus, cache, portfolio, engines, and strategy components operate in backtest and live modes. Backtests stable-sort loaded data by `ts_init`; live processing follows arrival order. External data streams are merged chronologically, so an absent bar is normally an absent event rather than a numeric placeholder. [Nautilus backtesting](https://nautilustrader.io/docs/latest/concepts/backtesting/) [Nautilus data](https://nautilustrader.io/docs/latest/concepts/data/) [Nautilus repeated runs](https://nautilustrader.io/docs/latest/concepts/backtesting/apis-and-runs/)

Execution flow is instrument-scoped. External execution bars update the matching state; existing orders may fill along a deterministic OHLC path; orders created in `on_bar` arrive after that bar’s synthetic intrabar points; and unrelated instrument data cannot release a delayed command against stale state. This is strong evidence for ledgr’s next-observation rule, although unrestricted timers and shutdown handling leave some delayed-order cases configuration-dependent. [Nautilus bar execution](https://nautilustrader.io/docs/latest/concepts/backtesting/bar-execution/) [Nautilus execution flow](https://nautilustrader.io/docs/latest/concepts/backtesting/execution-flow/)

Valuation is explicit. Portfolio price resolution can fall through mark, side quote, trade, and cached bar close; if no current price exists, it can carry the last valid value and report `stale_instruments`; never-priced holdings are separately `unpriced_instruments`. This is the strongest reviewed stale-mark interface. [Nautilus portfolio](https://nautilustrader.io/docs/latest/concepts/portfolio/)

There is an important contradiction. Current time-bar configuration builds no-update bars by default. An official 2026 issue, closed “not planned,” reproduces complete feed gaps as closed bars whose OHLC all equal the prior close and whose volume is zero, without a provenance flag. Internal bars do not drive execution matching, limiting the damage, but they can contaminate features and may appear current to valuation consumers. This is issue/source evidence, not a documented guarantee, and should be treated as a test case. [Nautilus data](https://nautilustrader.io/docs/latest/concepts/data/) [Nautilus issue 4594](https://github.com/nautechsystems/nautilus_trader/issues/4594) [Nautilus bar execution](https://nautilustrader.io/docs/latest/concepts/backtesting/bar-execution/)

`InstrumentStatus` can encode trading, halt, pause, and close with separate event/init times. No reviewed documentation says the matching engine automatically rejects or cancels orders from this status, so halt enforcement must be considered adapter/strategy-specific until tested. Instrument identity is normalized symbol plus venue, and no generic equity ticker-alias or listing-lifetime layer was found. [Nautilus instrument status](https://nautilustrader.io/docs/latest/concepts/data/instrument_status/) [Nautilus instruments](https://nautilustrader.io/docs/latest/concepts/instruments/)

Nautilus’s event-sourcing design is useful provenance prior art. Its run manifest can record run/parent/instance IDs, binary and schema versions, feature flags, adapter versions, configuration hash, seeds, high-watermark, and status; event entries carry sequence, init/publish time, topic, payload type, and hash. The documentation also states its limits: market data stays in the catalog, marker capture can be incomplete, and structural verification does not prove catalog completeness. [Nautilus event sourcing](https://nautilustrader.io/docs/latest/concepts/event_sourcing/)

## 5.4 vectorbt

Baseline: version 1.1.0, released 2026-07-05, commit `259d2d89fe2e7638baf3ca76c394937cd32b656d`; documentation accessed 2026-09-04. [vectorbt releases](https://github.com/polakowo/vectorbt/releases)

vectorbt represents the advantages and risks of matrix-first research. Its Data abstraction aligns symbol-specific pandas objects to a common index, with policies to insert NaN, drop unmatched dates, or raise. This is operationally convenient and demonstrates that vectorization does not require complete observations. The symbol key is the identity surface; no dated listing, alias, or corporate-action security master was found. [vectorbt Data](https://vectorbt.dev/api/data/base/) [vectorbt settings](https://vectorbt.dev/api/_settings/)

Portfolio simulation distinguishes order price from valuation price. A latest valuation price can be carried forward, and the documentation warns that using a current or future valuation in certain cash-sharing arrangements can cheat. However, `fillna_close` is designed to forward- and backward-fill NaNs after simulation to avoid NaN asset values. A pre-IPO leading gap can therefore acquire the first later price in reported asset value even though it did not create a pre-IPO fill. [vectorbt Portfolio](https://vectorbt.dev/api/portfolio/base/)

NaN order size skips an element, and order result codes include size, price, valuation-price, and value NaN conditions. Array simulation does not create a durable pending target by default; later execution requires a later instruction or custom order callback. This is materially different from Zipline’s GTC blotter and should be explicit in any ledgr matrix API. [vectorbt Portfolio](https://vectorbt.dev/api/portfolio/base/) [vectorbt portfolio enums](https://vectorbt.dev/api/portfolio/enums/)

Saved Portfolio objects omit cached results and can resolve omitted parameters from the current global defaults when reloaded. The docs recommend explicit parameters/settings. No automatic source-data content hash, environment lock, or PIT revision state was found. [vectorbt Portfolio](https://vectorbt.dev/api/portfolio/base/)

## 5.5 Microsoft Qlib

Baseline: stable 0.9.7, released 2025-08-15 at commit `da920b7f954f48ab1bb64117c976710de198373e`; current documentation identifies 0.9.8.dev11 and reviewed main source commit `79633dd9506ea689e5400dea0197717b5b3d74b7` dated 2026-07-23. Source behaviors should be pinned in a ledgr comparison test. [Qlib releases](https://github.com/microsoft/qlib/releases)

Qlib’s panel model is a MultiIndex DataFrame over `(datetime, instrument)`. Instrument definitions can map IDs to one or more date spans, and data providers intersect those spans with requested dates and dynamic filters. This is strong prior art for separating lifetime/membership from value presence. Alignment uses a shared frequency calendar; per-instrument exchange calendars were not established. [Qlib data docs](https://qlib.readthedocs.io/en/latest/component/data.html) [Qlib data source](https://github.com/microsoft/qlib/blob/main/qlib/data/data.py)

Its execution semantics are conservative for suspension. Documentation says OHLCV, money, and factor fields are NaN when a stock is suspended. Exchange source treats a missing quote or all-NaN close interval as suspended, returning zero dealt amount and NaN execution price. The canonical TopkDropout strategy skips nontradable buys and sells. The reviewed sources do not establish how a held suspended position is valued if the current quote is all NaN, so no stale, zero, or NaN policy should be attributed without a version-specific experiment. [Qlib data docs](https://qlib.readthedocs.io/en/latest/component/data.html) [Qlib Exchange](https://github.com/microsoft/qlib/blob/main/qlib/backtest/exchange.py) [Qlib signal strategy](https://github.com/microsoft/qlib/blob/main/qlib/contrib/strategy/signal_strategy.py)

Qlib has the strongest framework-native PIT mechanism reviewed. `LocalPITProvider` requires a current time, rejects future period offsets, selects records whose publication dates are no later than `cur_time`, and traverses linked revisions. That mechanism guarantees nothing if ingestion dates or revision chains are wrong, and experiment recording does not automatically hash the source snapshot. [Qlib PIT source](https://github.com/microsoft/qlib/blob/main/qlib/data/data.py) [Qlib recorder](https://qlib.readthedocs.io/en/latest/component/recorder.html)

Preprocessing is explicit but not automatically fold-safe. `DataHandlerLP` can separate raw, inference, and learning processors; processors include row drop, zero fill, and normalization; fitting processors require `fit_start_time` and `fit_end_time` and warn against including test data. A dataset’s train/test segment declaration alone does not prove those windows are correct. Dynamic filters also accept arbitrary expressions, including future references, so look-ahead remains possible. [Qlib data docs](https://qlib.readthedocs.io/en/latest/component/data.html) [Qlib processors](https://github.com/microsoft/qlib/blob/main/qlib/data/dataset/processor.py)

## 5.6 quantstrat, blotter, and FinancialInstrument

Baseline: quantstrat master declares version 0.25 dated 2023-01-24; blotter master declares 0.17.0 dated 2024-12-13; FinancialInstrument 1.4.1 was published to CRAN 2026-08-04. Exact master commits were not exposed in the reviewed pages. [quantstrat DESCRIPTION](https://github.com/braverock/quantstrat/blob/master/DESCRIPTION) [blotter DESCRIPTION](https://github.com/braverock/blotter/blob/master/DESCRIPTION) [FinancialInstrument CRAN](https://cran.r-project.org/web/packages/FinancialInstrument/index.html)

The R stack is naturally ragged at storage/runtime boundaries. quantstrat applies indicators, signals, and rules over one symbol’s `xts` market-data object at a time. Indicators and signals are vectorized; rules are path-dependent and inspect portfolio/order state. A missing symbol row means no rule pass for that timestamp, and a non-NA active signal is required to fire a signal rule. [quantstrat README](https://github.com/braverock/quantstrat) [quantstrat strategy source](https://github.com/braverock/quantstrat/blob/master/R/strategy.R) [ruleSignal source](https://github.com/braverock/quantstrat/blob/master/R/ruleSignal.R)

Default order processing permits durable GTC behavior. Limit and stop orders remain open when no non-NA transaction price is available and can fill on a later observed row. The source itself calls the simulator sufficient for backtesting and recommends replacing or revising it for production/live use, so backtest/live parity is not guaranteed. [quantstrat ruleOrderProc](https://github.com/braverock/quantstrat/blob/master/R/ruleOrderProc.R)

blotter can value a position from a prior price, merges transactions and prices, and uses last-observation-carried-forward for price and position fields. Cross-symbol aggregation is more problematic: it outer-merges symbol series, retains a TODO for NA filling, and computes portfolio value with `rowSums(..., na.rm=TRUE)`. At a timestamp present for one exchange but absent for another, the missing position can therefore contribute nothing unless the user aligns or fills correctly. This is source-inferred behavior and should be tested in an exact workflow. [blotter updatePosPL](https://github.com/braverock/blotter/blob/master/R/updatePosPL.R) [blotter getBySymbol](https://github.com/braverock/blotter/blob/master/R/getBySymbol.R) [blotter updatePortf](https://github.com/braverock/blotter/blob/master/R/updatePortf.R)

FinancialInstrument supports primary and alternate identifiers, but alias validity is not dated, and order books/data remain symbol-keyed. `walk.forward` can audit parameter selection over in-sample and out-of-sample windows, but it assumes common symbol timespans in important endpoint logic and is not an ML fit/transform pipeline. Snapshot hashes, package locks, vendor vintages, and revision cutoffs remain external responsibilities. [FinancialInstrument manual](https://cran.r-project.org/web/packages/FinancialInstrument/refman/FinancialInstrument.html) [quantstrat walk.forward](https://github.com/braverock/quantstrat/blob/master/R/walk.forward.R)

# 6. Methodology: imputation, leakage, MNAR, and labels

## 6.1 Complete cases are a policy, not a neutral validation outcome

Freyberger, Höppner, Neuhierl, and Weber document that missing predictors are widespread across firms, characteristics, and time. In their 82-characteristic panel, complete cases are roughly 10% of observations. They show that complete-case estimation can be inefficient or biased, while unconditional cross-sectional mean imputation is generally inconsistent except under restrictive independence or predictor-irrelevance conditions and can understate uncertainty. Their proposed conditional-mean/GMM method uses all observations with observed returns and downweights imputed rows, but it assumes a conditional missing-at-random structure; it does not solve genuine MNAR. [Freyberger et al.](https://academic.oup.com/rfs/article-abstract/38/3/760/7590858)

Rubin’s framework makes the same logical boundary explicit: ignoring the missingness mechanism requires appropriate missing-at-random and parameter-distinctness conditions. If data availability depends on the unseen value or outcome, imputation alone cannot identify the missing part. In ledgr’s domain, distress, illiquidity, reporting failures, and delisting can make absence informative. [Rubin 1976](https://doi.org/10.1093/biomet/63.3.581)

Decision implication: strict dense validation is a defensible data-quality mode. Complete-case universe construction is a research assumption that must be named, measured, and compared with missingness-aware alternatives.

## 6.2 Rectangular arrays can preserve partial observation

Statistical and ML prior art contradicts the claim that a rectangular tensor requires every cell to be real. GRU-D carries a value tensor, a binary observation mask, and elapsed time since last observation; partially observed factor models estimate structure with general missing patterns; and scikit-learn’s `MissingIndicator` retains which values were absent alongside an imputed matrix. [GRU-D](https://www.nature.com/articles/s41598-018-24271-9) [Xiong and Pelger](https://doi.org/10.1016/j.jeconom.2022.04.005) [Bai and Ng](https://arxiv.org/abs/1910.06677) [scikit-learn imputation](https://scikit-learn.org/stable/modules/impute.html)

This supports dense-plus-mask as a model-facing representation. It does not prove dense-plus-mask should be the canonical storage form, and it does not turn a masked market price into execution permission.

## 6.3 Fold-safe preprocessing is non-negotiable

scikit-learn’s guidance is explicit: split before preprocessing; never fit transformations, including imputers, on test data; and use a pipeline so each training fold fits its own state. TimeSeriesSplit prevents training on the future and evaluating on the past, but it assumes equally spaced samples, which a ragged equity panel may not satisfy row-by-row. ledgr should define folds by decision time and then construct the eligible cross-section inside each fold. [scikit-learn common pitfalls](https://scikit-learn.org/stable/common_pitfalls.html) [TimeSeriesSplit](https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.TimeSeriesSplit.html)

Fold-local state includes more than an imputation mean: universe/vocabulary, normalization, rank transforms, winsorization, feature selection, missing-indicator column selection, embeddings, and any learned decay. A fixed physical instrument axis is not automatically leakage. It becomes leakage when future membership changes fitting, feature construction, cross-sectional statistics, or the information visible to the model.

## 6.4 Model-native missing values help, but do not define semantics

XGBoost learns a default branch direction for missing values in tree splits, and scikit-learn documents estimators with native NaN handling. LightGBM has its own missing and sparse-zero configuration. These capabilities can remove a separate imputation step, but they cannot identify whether NA means pre-listing, halt, invalid record, warm-up, or missing fundamental; nor can they decide whether an order may execute. Representation and configuration must be pinned because sparse absence, dense zero, and NaN can be interpreted differently. [XGBoost paper](https://arxiv.org/abs/1603.02754) [XGBoost FAQ](https://xgboost.readthedocs.io/en/stable/faq.html) [LightGBM missing values](https://lightgbm.readthedocs.io/en/latest/Advanced-Topics.html#missing-value-handle) [scikit-learn imputation](https://scikit-learn.org/stable/modules/impute.html)

GRU-D shows why the surrounding pipeline matters: masks and time since observation can themselves be predictive. BRITS, by contrast, uses bidirectional recurrence; using it to reconstruct decision-time inputs can incorporate later observations. That leakage warning is an inference from the architecture, not a criticism of retrospective imputation. [GRU-D](https://www.nature.com/articles/s41598-018-24271-9) [BRITS](https://proceedings.neurips.cc/paper/2018/hash/734e6bfcd358e25ac1db0a4241b95651-Abstract.html)

## 6.5 Labels, terminal returns, and censoring

The most dangerous missing label is a failed firm that disappears. Shumway documents large negative omitted returns for performance-related delistings in historical CRSP data. Beaver, McNichols, and Price show that including delisting firm-years can move accounting-anomaly results in either direction because delisting observations concentrate in extreme characteristic portfolios. [Shumway](https://doi.org/10.1111/j.1540-6261.1997.tb03818.x) [Beaver et al.](https://doi.org/10.1016/j.jacceco.2006.12.002)

ledgr should distinguish:

- Observed horizon return.
- Explicit terminal payoff or conversion event.
- Vendor-provided delisting return.
- Vendor-missing terminal return with a documented reason.
- Ordinary right-censoring because the horizon extends beyond available data.
- Label invalidity caused by a data-quality failure.

None should be filled by a generic feature-imputation rule. Historical constants such as a single assumed negative delisting return are sensitivity scenarios, not universal truth. When the estimand is time to distress or failure, survival/hazard methods are more appropriate than treating non-observed future outcomes as ordinary regression NA. [Shumway hazard model](https://doi.org/10.1086/209665)

## 6.6 Publication and revision semantics

SEC submissions distinguish reporting periods from acceptance and dissemination. The EDGAR APIs update as filings are disseminated, and filing rules can defer the official filing date and public dissemination for submissions made after cutoffs. ALFRED’s observation-date/vintage-date matrix shows a robust vendor-neutral pattern for historical knowability. [SEC EDGAR APIs](https://www.sec.gov/search-filings/edgar-application-programming-interfaces) [SEC filing status](https://www.sec.gov/submit-filings/filer-support-resources/how-do-i-guides/determine-status-my-filing) [ALFRED](https://alfred.stlouisfed.org/help/downloaddata)

A fiscal-period timestamp alone is therefore insufficient. A backtest should select the latest accepted revision whose public-availability cutoff is no later than decision time, from the exact dataset vintage pinned to the snapshot. Dataset revisions matter even for market data: CRSP release notes document retroactive changes to historical names, distributions, halt data, and delisting dates. [CRSP June 2026 release notes](https://assets.contentstack.io/v3/assets/bltabf2a7413d5a8f05/blt121f448f0772191c/6a6d14d7b591025fe5ee8b3f/CRSP_US_Stock_Database_Release_Notes_June_2026_Monthly.pdf)

# 7. Architectural alternatives

| Alternative | Correctness model | Execution safety | Performance / complexity | Reproducibility | Strategy / ML ergonomics | Assessment |
|---|---|---|---|---|---|---|
| Fully sparse event storage and execution | Natural for actual arrivals, state changes, and causal ordering; expected absence needs a separate contract. | Strong if fills require applicable post-order events; timers and terminal policies still need rules. | Memory-efficient for sparse data; complex multi-asset joins, rolling features, and cross-sectional operations. | Strong with stable event order, pinned data, config, and seeds; hashes do not prove completeness. | Excellent for event strategies; costly for dense cross-sectional ML. | Plausible core runtime, but a disruptive change for ledgr. |
| Fully dense instrument-by-pulse panel | Simple invariants and vectorization; conflates nonexistence with required observation unless every cell is genuine. | Strong only under current fail-fast completeness; permissive fill is hazardous. | Fast, predictable, and easy to cache; potentially wasteful for broad/young universes. | Strong for sealed complete panels. | Excellent for current strategies and models. | Retain as strict legacy mode, not the sole universe model. |
| Dense panel with explicit masks | Can separate lifetime, observation, feature validity, valuation, and execution if masks are independent. | Strong if execution ignores carried/imputed arrays and consults a separate eligibility plane. | Bit masks are compact; branching and many masks add CPU/cache pressure. | Strong if masks, policies, and source versions are sealed/hashed. | Excellent for matrix code and missing-aware ML; interfaces must prevent accidental mask omission. | Leading candidate for run-facing representation; canonical storage still open. |
| Dynamic active-universe matrices | Prevents inactive rows from reaching strategy by default; requires explicit admission/removal and retained holdings. | Strong if held/order state survives removal and re-entry is deterministic. | Lower active memory; resizing/remapping/caching can be expensive. | Membership events and ordering must be recorded; interface changes across time. | Natural for portfolio selection; awkward for fixed-shape models and batched sweeps. | Credible alternative where active set is small; benchmark against fixed superset masks. |
| Sparse snapshot storage + fold-local dense materialization | Stores only facts/events and builds decision-time eligible arrays with explicit masks. | Strong if materializer keeps observed/executable data separate. | More indexing and materialization cost; potentially best storage efficiency and ML locality. | Strong when materialization query, fold, universe, and source hashes are part of identity. | Dense ergonomics for models without paying global density; extra cache lifecycle. | Most credible long-run hybrid; requires an empirical spike. |
| Hybrid event and panel model | Events own lifetime, status, actions, and revisions; panels own derived numerical views. | Potentially strongest separation; risk of divergent semantics between layers. | Highest implementation and testing complexity; can optimize each workload. | Requires one canonical ordering/query semantics and cross-layer hashes. | Supports event strategies and dense ML; hardest API to make coherent. | Strategic option if ledgr expands beyond bar research; premature as an initial change. |

Sources and analogues: [Zipline Pipeline mask](https://zipline.ml4trading.io/_modules/zipline/pipeline/engine.html), [Nautilus event sourcing](https://nautilustrader.io/docs/latest/concepts/event_sourcing/), [Qlib dated instruments](https://github.com/microsoft/qlib/blob/main/qlib/data/data.py), [GRU-D masks](https://www.nature.com/articles/s41598-018-24271-9), [vectorbt broadcasting](https://vectorbt.dev/api/portfolio/base/), [quantstrat symbol-local runtime](https://github.com/braverock/quantstrat/blob/master/R/strategy.R).

# 8. Patterns ledgr should consider adopting

## Supported strongly by prior art

1. Stable instrument identity with time-bounded symbology. LEAN’s `Symbol`, Zipline’s SID, and CRSP’s PERMNO all separate continuity from mutable ticker strings. ledgr should expose point-in-time ticker/venue mapping without using ticker as the asset key. [LEAN corporate actions](https://www.quantconnect.com/docs/v2/writing-algorithms/securities/asset-classes/us-equity/corporate-actions) [Zipline API](https://zipline.ml4trading.io/api-reference.html) [CRSP US stock databases](https://indexes.morningstar.com/research-data-products/crsp-us-stock-databases)
2. Orthogonal state planes. Lifetime, membership, expected observation, actual observation, quality, valuation, tradability, feature validity, and label state should be independently representable. Nasdaq and CRSP source schemas show these are not one dimension. [Nasdaq halts](https://www.nasdaqtrader.com/Trader.aspx?id=TradeHaltCodes) [CRSP guide](https://indexes.morningstar.com/docs/guide/crsp-us-stock-databases-guide-for-flat-file-format-2-0?isRdp=true)
3. Stale valuation separated from execution. A carried last close may value a holding under a named policy, with age and provenance, but must not become an executable OHLC. Zipline and Nautilus provide direct precedents; LEAN’s stale market fills show the failure mode. [Zipline API](https://zipline.ml4trading.io/api-reference.html) [Nautilus portfolio](https://nautilustrader.io/docs/latest/concepts/portfolio/) [LEAN fill concepts](https://www.quantconnect.com/docs/v2/writing-algorithms/reality-modeling/trade-fills/key-concepts)
4. Raw observations remain immutable. Synthetic, imputed, or carried values belong in derived layers with provenance. No automatic OHLC forward fill should occur while sealing source facts.
5. Point-in-time lifetimes and membership. A fixed superset is acceptable only if pre-eligibility identifiers, statistics, and features are inaccessible. Zipline lifetimes and Qlib instrument spans are the closest direct precedents. [Zipline API](https://zipline.ml4trading.io/api-reference.html) [Qlib data source](https://github.com/microsoft/qlib/blob/main/qlib/data/data.py)
6. Fold-local fitted transformations. Imputation, normalization, ranks, selected columns, embeddings, and any learned missingness model must be fitted per training fold and stored with the promoted model. [scikit-learn common pitfalls](https://scikit-learn.org/stable/common_pitfalls.html)
7. Explicit terminal-event and label policy. Delisting, acquisition, recovery, and censoring must not be represented by disappearing rows or generic NA. [Shumway](https://doi.org/10.1111/j.1540-6261.1997.tb03818.x)
8. Pinned data vintage and revision semantics. Event time alone cannot reproduce a run against a revised vendor database. [ALFRED](https://alfred.stlouisfed.org/help/downloaddata) [CRSP release notes](https://assets.contentstack.io/v3/assets/bltabf2a7413d5a8f05/blt121f448f0772191c/6a6d14d7b591025fe5ee8b3f/CRSP_US_Stock_Database_Release_Notes_June_2026_Monthly.pdf)

## Plausible but dependent on ledgr trade-offs

1. Dense values plus independent masks as the strategy-facing ABI. Prior art supports correctness, but ledgr must decide whether all strategies receive masks, whether unsafe value-only access is permitted, and how mask branches affect sweeps.
2. Sparse physical storage with fold/run-local dense materialization. This may best preserve both storage efficiency and ML ergonomics, but cache keys and query planning are substantial work.
3. An expected-observation service derived from venue calendar, instrument listing episode, subscription/data contract, and known status events. Most reviewed systems lack this composition, so ledgr can improve on them, but “expected” must remain a contract assertion rather than an inferred fact.
4. Order carry policy as a named execution configuration. Zipline and quantstrat retain GTC orders; vectorbt does not. ledgr can support reject, cancel, expire, or carry, provided each is deterministic and never fills on synthetic evidence.
5. Staleness budgets by use. Reporting NAV, leverage checks, signal construction, and execution can have different maximum ages. The policy should be visible to strategies and provenance.

## Requires empirical validation

1. Number and representation of masks needed for broad equities without unacceptable memory/cache cost.
2. Whether a fixed snapshot superset leaks through realistic strategy and model APIs despite membership masks.
3. Relative cost of dynamic active matrices versus fixed superset masks in run and sweep workloads.
4. Impact of complete-case, native-missing, simple imputation-plus-indicator, and conditional methods on retention, turnover, and performance for distressed/illiquid names.
5. Stale-mark risk propagation into leverage, volatility, drawdown, margin, and ranking.

# 9. Patterns ledgr should avoid

1. Automatic OHLC forward fill. It turns absence into a fictitious market path and may become executable.
2. Backward filling leading prices. vectorbt’s reporting behavior is useful for avoiding NaN metrics but is inappropriate for a PIT engine because it can attach a post-listing price to a pre-listing instant. [vectorbt Portfolio](https://vectorbt.dev/api/portfolio/base/)
3. Treating zero volume as a universal halt or absence marker. Legitimate zero-trade intervals, synthesized bars, outages, and venue halts are different.
4. Inferring lifecycle from first and last price row. IPO, re-entry, suspended quotation, merger, and dataset truncation require reference/event data.
5. Treating a missing bar as a trading-status event. Nasdaq publishes explicit halt and resumption codes, including quoting-only states; absence alone cannot reconstruct them. [Nasdaq halts](https://www.nasdaqtrader.com/Trader.aspx?id=TradeHaltCodes)
6. Allowing a valuation fallback to satisfy an execution query. LEAN’s stale market-order behavior and Zipline’s auto-close fallback illustrate the risk. [LEAN fill concepts](https://www.quantconnect.com/docs/v2/writing-algorithms/reality-modeling/trade-fills/key-concepts) [Zipline ledger](https://github.com/stefan-jansen/zipline-reloaded/blob/3.1.1/src/zipline/finance/ledger.py)
7. Dropping any row with any missing feature. It can reduce a large equity panel to a small selected sample. [Freyberger et al.](https://academic.oup.com/rfs/article-abstract/38/3/760/7590858)
8. Fitting imputation or cross-sectional ranks before folds are defined. This leaks future distributions and possibly future universe membership. [scikit-learn common pitfalls](https://scikit-learn.org/stable/common_pitfalls.html)
9. Using current/restated fundamentals under only a fiscal-period date. Availability and revision cutoff must be explicit. [SEC EDGAR APIs](https://www.sec.gov/search-filings/edgar-application-programming-interfaces) [ALFRED](https://alfred.stlouisfed.org/help/downloaddata)
10. Claiming deterministic replay from code and seed alone. Input snapshot/vintage, calendar, adjustment rules, preprocessing state, and platform-relevant numeric settings are also required.
11. Assuming same-code live/backtest architecture proves economic parity. LEAN and Nautilus both document timing/arrival differences. [LEAN reconciliation](https://www.quantconnect.com/docs/v2/cloud-platform/live-trading/reconciliation) [Nautilus live](https://nautilustrader.io/docs/latest/concepts/live/)
12. Treating issue reports as contracts. They are valuable adversarial cases, not guaranteed semantics.

# 10. Unresolved questions requiring empirical evidence

| Question | Why prior art cannot settle it | Required evidence |
|---|---|---|
| Which expected observations should daily U.S. equities have? | Venue calendar, primary listing, feed contract, halt status, and vendor coverage can disagree. | Reconcile a broad sample against exchange status and vendor records; measure false positive/negative gap classifications. |
| How long may a stale mark be used? | Valuation standards establish policy discipline, not a backtest-specific age. | Simulate risk metrics and leverage under 1, 3, 5, and longer session gaps by liquidity/distress group. |
| What should a pending target do through a gap or halt? | Systems differ among immediate stale fill, GTC carry, skip, and strategy retry. | Strategy-level outcome comparison with explicit cancel/expire/carry policies. |
| What resolves a delisted holding? | Feed-provided terminal return, cash/stock consideration, recovery, and stale mark differ economically. | Vendor coverage audit and manually reconciled terminal-event sample. |
| Is a fixed superset axis safe in practice? | Allocation alone is not leakage; APIs may expose future IDs or fit embeddings/statistics on them. | Adversarial tests that perturb future listings and require identical pre-listing features/orders/results. |
| Which masks are actually independent? | Domain logic says several are orthogonal; implementation may derive some without loss. | State-cooccurrence analysis and mutation tests over real gaps/halts/actions. |
| Can run/sweep semantics remain identical? | Caches, shared materialization, and dynamic admission can change evaluation order. | Property tests across single run, sweep, chunking, parallelism, and cache warm/cold paths. |
| Which imputation baseline is worth supporting first? | Predictive results are data/feature/model dependent and MNAR cannot be wished away. | Walk-forward comparison of native missing, simple fold-local median + indicator, carry-with-age for selected slow features, and no-imputation models. |
| How should revisions affect snapshot identity? | Full history, cutoff view, and vendor release pin offer different storage/performance trade-offs. | Prototype lookup and hash behavior under simulated corrections/restatements. |
| What is the acceptable cost of ragged support? | No reviewed source benchmarks a ledgr-like R matrix engine. | Memory/runtime profiles on representative asset counts, horizons, features, and sweep sizes. |

# 11. Implications for a future ragged-universe RFC seed

This review should seed questions and invariants, not a final schema.

## 11.1 Candidate invariants

1. Legacy complete snapshots produce identical values, orders, fills, and run/sweep results.
2. A value used for execution is either an eligible observed market fact after order time or the output of a separately named terminal-event rule.
3. Valuation fallback never changes observation truth or execution eligibility.
4. Unknown cause remains unknown; the engine does not infer halt, closure, or error from absence alone.
5. Pre-membership instruments cannot affect features, cross-sectional statistics, fitting, ranking, or order logic.
6. Every feature cell can distinguish source absence, structural nonexistence, and insufficient warm-up.
7. Terminal events and censored labels are explicit and auditable.
8. A replay against the same sealed inputs, configuration, model artifact, seed, and supported runtime yields the same result.
9. A corrected vendor dataset creates a different snapshot identity even if event-time keys are unchanged.
10. Single-run and sweep paths call the same semantic kernel.

## 11.2 Candidate interfaces to prototype

- A point-in-time asset view returning stable IDs, current symbology, lifetime, membership, session state, and known trading status.
- An observation view returning raw values plus observation/quality metadata without imputation.
- A valuation view returning mark, source observation time, age, policy, and stale/unpriced state.
- An execution query that does not accept the valuation array and returns a reasoned eligibility result.
- A feature materializer returning values, validity/missingness masks, and preprocessing artifact identity for a specified fold.
- A terminal-event resolver returning explicit payoff/conversion/censoring status.

These are conceptual boundaries. Whether they are separate objects, columns, bit planes, or compact enums is an empirical and ergonomic decision.

## 11.3 Empirical spike

Build a fixture set containing all twelve mandatory scenarios, plus manually verified reference outcomes. Run four prototypes: current strict dense baseline; dense values with orthogonal masks; sparse event runtime; and sparse snapshot with fold-local dense materialization.

## 11.4 Acceptance evidence

- Exact legacy parity for scenario 12.
- Zero fills on carried, imputed, synthetic, or pre-order prices unless an explicit terminal rule applies.
- Identical pre-event results when future listings, ticker mappings, or restatements are perturbed.
- Explicit stale/unpriced risk reports through scenarios 2, 4, and 6.
- Identical semantic results across run, sweep, cache state, and chunking.
- Sample-retention and missingness diagnostics by size, liquidity, distress, venue, and lifecycle state.
- Runtime and memory profiles for both cross-sectional ML and event-oriented strategies.
- Snapshot and model hashes that change for every semantically relevant revision.

# 12. Snapshot and provenance implications

The review supports provenance layers rather than one oversized run hash.

## 12.1 Snapshot identity should be able to bind

- Source provider, dataset/product, release or extraction identifier, and licensing-safe fingerprint.
- Content hashes or immutable object versions for raw facts and reference/event data.
- Calendar source and version.
- Stable instrument master plus time-bounded symbology and listing episodes.
- Corporate-action and terminal-event records with their own effective/availability times.
- Observation schema, validation rules, duplicate/correction policy, and normalization code version.
- Publication/availability, ingestion, and revision semantics used to build the PIT view.
- Expected-observation contract and its inputs, if expectedness is sealed rather than computed at run time.
- Deterministic ordering/canonicalization rules and any numeric precision choices.

## 12.2 Run configuration should be able to bind

- Universe selection rule and decision-time cutoff.
- Valuation policy, stale-age budgets, and unpriced-position handling.
- Execution policy for missing bars, halts, nontradable state, terminal events, and GTC/cancel/expire behavior.
- Corporate-action treatment and cash/stock conversion rules.
- Feature definitions, warm-up rules, and label horizon/censoring policy.
- Random seeds, fill/slippage/fee models, and scheduling semantics.
- Code/package lock and runtime factors needed for supported determinism.

## 12.3 Fitted model artifacts should be able to bind

- Training, validation, and test decision-time boundaries.
- Point-in-time membership set or reproducible membership query for each fold.
- Feature schema, column order, missing marker, masks/indicators, and categorical vocabulary.
- Fitted imputation, scaling, ranking, selection, embedding, and calibration state.
- Model library/version, hyperparameters, seed, and serialization format.
- Training-data snapshot identity and materialization query/hash.
- Native-missing configuration such as sparse-zero interpretation and learned default routing.

Nautilus’s manifest/event fields are useful precedent for run identity, Qlib’s PIT provider for revision lookup, and ALFRED for vintage semantics. Their limitations reinforce that a manifest must bind the market-data catalog and preprocessing artifacts rather than merely strategy events. [Nautilus event sourcing](https://nautilustrader.io/docs/latest/concepts/event_sourcing/) [Qlib PIT source](https://github.com/microsoft/qlib/blob/main/qlib/data/data.py) [ALFRED](https://alfred.stlouisfed.org/help/downloaddata)

# 13. Linked bibliography

## Backtesting and research systems

### QuantConnect LEAN

- QuantConnect. “Documentation change log.” Current through 2026-08-27; accessed 2026-09-04. https://www.quantconnect.com/docs/v2/meta/change-log
- QuantConnect. “Timeslices.” Accessed 2026-09-04. https://www.quantconnect.com/docs/v2/writing-algorithms/key-concepts/time-modeling/timeslices
- QuantConnect. “Requesting Data.” Accessed 2026-09-04. https://www.quantconnect.com/docs/v2/writing-algorithms/securities/requesting-data
- QuantConnect. “History Requests.” Accessed 2026-09-04. https://www.quantconnect.com/docs/v2/writing-algorithms/historical-data/history-requests
- QuantConnect. “Trade Fill Key Concepts.” Accessed 2026-09-04. https://www.quantconnect.com/docs/v2/writing-algorithms/reality-modeling/trade-fills/key-concepts
- QuantConnect. “Equity Fill Model.” Accessed 2026-09-04. https://www.quantconnect.com/docs/v2/writing-algorithms/reality-modeling/trade-fills/supported-models/equity-model
- QuantConnect. “Universe Key Concepts.” Accessed 2026-09-04. https://www.quantconnect.com/docs/v2/writing-algorithms/universes/key-concepts
- QuantConnect. “US Equity Corporate Actions.” Accessed 2026-09-04. https://www.quantconnect.com/docs/v2/writing-algorithms/securities/asset-classes/us-equity/corporate-actions
- QuantConnect. “US Equity Security Master.” Accessed 2026-09-04. https://www.quantconnect.com/docs/v2/writing-algorithms/datasets/quantconnect/us-equity-security-master
- QuantConnect. “Custom Securities: Key Concepts.” Accessed 2026-09-04. https://www.quantconnect.com/docs/v2/writing-algorithms/importing-data/streaming-data/custom-securities/key-concepts
- QuantConnect. “Live Reconciliation.” Accessed 2026-09-04. https://www.quantconnect.com/docs/v2/cloud-platform/live-trading/reconciliation
- QuantConnect. `BaseData.IsFillForward` class reference. Accessed 2026-09-04. https://www.lean.io/docs/v2/lean-engine/class-reference/classQuantConnect_1_1Data_1_1BaseData.html

### zipline-reloaded

- zipline-reloaded. “API Reference.” Documentation branded 3.0; accessed 2026-09-04. https://zipline.ml4trading.io/api-reference.html
- zipline-reloaded. “Data Bundles.” Accessed 2026-09-04. https://zipline.ml4trading.io/bundles.html
- zipline-reloaded. “Trading Calendars.” Accessed 2026-09-04. https://zipline.ml4trading.io/trading-calendars.html
- zipline-reloaded 3.1.1 source: `slippage.py`. https://github.com/stefan-jansen/zipline-reloaded/blob/3.1.1/src/zipline/finance/slippage.py
- zipline-reloaded 3.1.1 source: `cancel_policy.py`. https://github.com/stefan-jansen/zipline-reloaded/blob/3.1.1/src/zipline/finance/cancel_policy.py
- zipline-reloaded 3.1.1 source: `tradesimulation.py`. https://github.com/stefan-jansen/zipline-reloaded/blob/3.1.1/src/zipline/gens/tradesimulation.py
- zipline-reloaded 3.1.1 source: `ledger.py`. https://github.com/stefan-jansen/zipline-reloaded/blob/3.1.1/src/zipline/finance/ledger.py
- zipline-reloaded. “Pipeline engine” source. https://zipline.ml4trading.io/_modules/zipline/pipeline/engine.html
- zipline-reloaded. Release 3.1.1 / PyPI. 2025-07-19. https://pypi.org/project/zipline-reloaded/

### NautilusTrader

- NautilusTrader. “Data.” Current v2 docs; accessed 2026-09-04. https://nautilustrader.io/docs/latest/concepts/data/
- NautilusTrader. “Backtesting.” Accessed 2026-09-04. https://nautilustrader.io/docs/latest/concepts/backtesting/
- NautilusTrader. “Bar-Based Execution.” Accessed 2026-09-04. https://nautilustrader.io/docs/latest/concepts/backtesting/bar-execution/
- NautilusTrader. “Portfolio.” Accessed 2026-09-04. https://nautilustrader.io/docs/latest/concepts/portfolio/
- NautilusTrader. “Cache.” Accessed 2026-09-04. https://nautilustrader.io/docs/latest/concepts/cache/
- NautilusTrader. “InstrumentStatus.” Accessed 2026-09-04. https://nautilustrader.io/docs/latest/concepts/data/instrument_status/
- NautilusTrader. “Instruments.” Accessed 2026-09-04. https://nautilustrader.io/docs/latest/concepts/instruments/
- NautilusTrader. “Event Sourcing.” Accessed 2026-09-04. https://nautilustrader.io/docs/latest/concepts/event_sourcing/
- NautilusTrader. “APIs and Repeated Runs.” Accessed 2026-09-04. https://nautilustrader.io/docs/latest/concepts/backtesting/apis-and-runs/
- NautilusTrader issue 4594. “TimeBarAggregator emits flatlined closed bars during feed/connection gaps.” 2026-07-28; closed not planned. https://github.com/nautechsystems/nautilus_trader/issues/4594
- NautilusTrader releases. Accessed 2026-09-04. https://github.com/nautechsystems/nautilus_trader/releases

### vectorbt and Microsoft Qlib

- vectorbt. “Data base API.” Accessed 2026-09-04. https://vectorbt.dev/api/data/base/
- vectorbt. “Portfolio base API.” Accessed 2026-09-04. https://vectorbt.dev/api/portfolio/base/
- vectorbt. “Settings.” Accessed 2026-09-04. https://vectorbt.dev/api/_settings/
- vectorbt. “Portfolio enums.” Accessed 2026-09-04. https://vectorbt.dev/api/portfolio/enums/
- vectorbt. Release 1.1.0. 2026-07-05. https://github.com/polakowo/vectorbt/releases
- Microsoft Qlib. “Data Component.” Current docs 0.9.8.dev11; accessed 2026-09-04. https://qlib.readthedocs.io/en/latest/component/data.html
- Microsoft Qlib. `qlib/data/data.py`, main commit `79633dd9506ea689e5400dea0197717b5b3d74b7`. https://github.com/microsoft/qlib/blob/main/qlib/data/data.py
- Microsoft Qlib. `backtest/exchange.py`. https://github.com/microsoft/qlib/blob/main/qlib/backtest/exchange.py
- Microsoft Qlib. `dataset/processor.py`. https://github.com/microsoft/qlib/blob/main/qlib/data/dataset/processor.py
- Microsoft Qlib. `contrib/strategy/signal_strategy.py`. https://github.com/microsoft/qlib/blob/main/qlib/contrib/strategy/signal_strategy.py
- Microsoft Qlib. “Recorder.” Accessed 2026-09-04. https://qlib.readthedocs.io/en/latest/component/recorder.html
- Microsoft Qlib. Releases. Accessed 2026-09-04. https://github.com/microsoft/qlib/releases

### R systems

- quantstrat. README and source. Accessed 2026-09-04. https://github.com/braverock/quantstrat
- quantstrat. `R/strategy.R`. https://github.com/braverock/quantstrat/blob/master/R/strategy.R
- quantstrat. `R/ruleSignal.R`. https://github.com/braverock/quantstrat/blob/master/R/ruleSignal.R
- quantstrat. `R/ruleOrderProc.R`. https://github.com/braverock/quantstrat/blob/master/R/ruleOrderProc.R
- quantstrat. `R/walk.forward.R`. https://github.com/braverock/quantstrat/blob/master/R/walk.forward.R
- blotter. `R/updatePosPL.R`. https://github.com/braverock/blotter/blob/master/R/updatePosPL.R
- blotter. `R/getBySymbol.R`. https://github.com/braverock/blotter/blob/master/R/getBySymbol.R
- blotter. `R/updatePortf.R`. https://github.com/braverock/blotter/blob/master/R/updatePortf.R
- FinancialInstrument. Reference manual, version 1.4.1. 2026-08-04. https://cran.r-project.org/web/packages/FinancialInstrument/refman/FinancialInstrument.html

## Methodology, standards, and data architecture

### Missingness, selection, and asset-pricing evidence

- Freyberger, J.; Höppner, B.; Neuhierl, A.; Weber, M. “Missing Data in Asset Pricing Panels.” Review of Financial Studies 38(3), 760–802. https://doi.org/10.1093/rfs/hhae003
- Rubin, D. B. “Inference and Missing Data.” Biometrika 63(3), 581–592, 1976. https://doi.org/10.1093/biomet/63.3.581
- Brown, S. J.; Goetzmann, W.; Ibbotson, R. G.; Ross, S. A. “Survivorship Bias in Performance Studies.” Review of Financial Studies 5(4), 553–580, 1992. https://doi.org/10.1093/rfs/5.4.553
- Shumway, T. “The Delisting Bias in CRSP Data.” Journal of Finance 52, 327–340, 1997. https://doi.org/10.1111/j.1540-6261.1997.tb03818.x
- Shumway, T.; Warther, V. A. “The Delisting Bias in CRSP’s Nasdaq Data and Its Implications for the Size Effect.” Journal of Finance 54(6), 2361–2379, 1999. https://doi.org/10.1111/0022-1082.00192
- Beaver, W. H.; McNichols, M. F.; Price, R. “Delisting Returns and Their Effect on Accounting-Based Market Anomalies.” Journal of Accounting and Economics 43, 341–368, 2007. https://doi.org/10.1016/j.jacceco.2006.12.002
- Shumway, T. “Forecasting Bankruptcy More Accurately: A Simple Hazard Model.” Journal of Business 74(1), 101–124, 2001. https://doi.org/10.1086/209665
- Gu, S.; Kelly, B.; Xiu, D. “Empirical Asset Pricing via Machine Learning.” Review of Financial Studies 33(5), 2223–2273, 2020. https://academic.oup.com/rfs/article/33/5/2223/5758276
- Xiong, R.; Pelger, M. “Large Dimensional Latent Factor Modeling with Missing Observations and Applications to Causal Inference.” Journal of Econometrics, 2023. https://doi.org/10.1016/j.jeconom.2022.04.005

### Models and fold-safe preprocessing

- Bai, J.; Ng, S. “Matrix Completion, Counterfactuals, and Factor Analysis of Missing Data.” 2021. https://arxiv.org/abs/1910.06677
- Che, Z.; Purushotham, S.; Cho, K.; Sontag, D.; Liu, Y. “Recurrent Neural Networks for Multivariate Time Series with Missing Values.” Scientific Reports 8, 6085, 2018. https://doi.org/10.1038/s41598-018-24271-9
- Cao, W. et al. “BRITS: Bidirectional Recurrent Imputation for Time Series.” NeurIPS 2018. https://proceedings.neurips.cc/paper/2018/hash/734e6bfcd358e25ac1db0a4241b95651-Abstract.html
- Chen, T.; Guestrin, C. “XGBoost: A Scalable Tree Boosting System.” KDD 2016. https://doi.org/10.1145/2939672.2939785
- scikit-learn 1.9. “Common pitfalls and recommended practices.” Accessed 2026-09-04. https://scikit-learn.org/stable/common_pitfalls.html
- scikit-learn 1.9. “Imputation of missing values.” Accessed 2026-09-04. https://scikit-learn.org/stable/modules/impute.html
- scikit-learn 1.9. “TimeSeriesSplit.” Accessed 2026-09-04. https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.TimeSeriesSplit.html
- XGBoost 3.4.1. “Frequently Asked Questions.” Accessed 2026-09-04. https://xgboost.readthedocs.io/en/stable/faq.html
- LightGBM 4.7. “Advanced Topics: Missing Value Handle.” Accessed 2026-09-04. https://lightgbm.readthedocs.io/en/latest/Advanced-Topics.html#missing-value-handle

### Temporal, PIT, and market-data standards

- Jensen, C. S.; Clifford, J.; Gadia, S. K.; Segev, A.; Snodgrass, R. T. “A Glossary of Temporal Database Concepts.” SIGMOD Record 21(3), 1992. https://sigmodrecord.org/publications/sigmodRecord/9209/pdfs/140979.140996.pdf
- Federal Reserve Bank of St. Louis. “ALFRED Download Data Help.” Accessed 2026-09-04. https://alfred.stlouisfed.org/help/downloaddata
- U.S. Securities and Exchange Commission. “EDGAR Application Programming Interfaces.” Updated 2025-04-08; accessed 2026-09-04. https://www.sec.gov/search-filings/edgar-application-programming-interfaces
- U.S. Securities and Exchange Commission. “Determine the Status of My Filing.” 2024-06-04; accessed 2026-09-04. https://www.sec.gov/submit-filings/filer-support-resources/how-do-i-guides/determine-status-my-filing
- CRSP / Morningstar. “CRSP US Stock Databases.” Accessed 2026-09-04. https://indexes.morningstar.com/research-data-products/crsp-us-stock-databases
- CRSP / Morningstar. “CRSP US Stock Databases Guide for Flat File Format 2.0.” Effective 2026-07-31. https://indexes.morningstar.com/docs/guide/crsp-us-stock-databases-guide-for-flat-file-format-2-0?isRdp=true
- CRSP / Morningstar. “US Stock Database Release Notes, June 2026.” https://assets.contentstack.io/v3/assets/bltabf2a7413d5a8f05/blt121f448f0772191c/6a6d14d7b591025fe5ee8b3f/CRSP_US_Stock_Database_Release_Notes_June_2026_Monthly.pdf
- Nasdaq Trader. “Trading Halt Codes.” Accessed 2026-09-04. https://www.nasdaqtrader.com/Trader.aspx?id=TradeHaltCodes
- Nasdaq. “TotalView-ITCH Specification.” Accessed 2026-09-04. https://www.nasdaqtrader.com/content/technicalsupport/specifications/dataproducts/NQTVITCHSpecification.pdf
- Databento. “Common Fields, Enums, and Types.” Accessed 2026-09-04. https://databento.com/docs/standards-and-conventions/common-fields-enums-types
- Databento. “Status schema.” Accessed 2026-09-04. https://databento.com/docs/schemas-and-data-formats/status

## Limitations of this review

This is a source-based prior-art review, not an executable conformance suite. Versioned source was inspected for several consequential behaviors, but no framework was installed and run against the twelve scenarios. Rolling documentation may move after the access date. Official issues identify adversarial cases but are not contractual behavior. Provider-specific corporate-action and fundamental-data semantics were not exhaustively compared. Finally, methodological evidence can establish bias mechanisms and valid classes of representation; it cannot choose ledgr’s storage layout, API ergonomics, or performance thresholds without the proposed empirical spike.
