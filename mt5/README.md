# TrendPulse: MT5 EA + Indicator

This folder has one strategy in two forms:

| File | What it is |
|---|---|
| `MQL5/Experts/TrendPulse_EA.mq5` | **Bot (Expert Advisor).** Opens and manages trades automatically. |
| `MQL5/Indicators/TrendPulse_Indicator.mq5` | **Indicator.** Draws the same signals as BUY/SELL arrows and can send alerts. It does not trade. |
| `MQL5/Include/TrendPulse/TrendPulseCore.mqh` | **Shared signal engine.** The EA and the indicator both use it. |

The signal rule lives in one place, `TP_Evaluate()` in the core file, and both programs use the same inputs. So with the same settings, **the EA trades on the bar after each arrow the indicator draws.**

## Strategy

Signals are checked only on **closed bars**, so they don't repaint.

- **BUY:** Fast MA (9) crosses above Slow MA (21)
  - and the close is above the Trend MA (200), if the trend filter is on
  - and RSI(14) is above 50, if the RSI filter is on
- **SELL:** the mirror image of BUY.
- **Stop loss:** `ATR(14) × 1.5` from entry. **Take profit:** `ATR(14) × 3.0` from entry. That is a 1:2 risk/reward.

The EA adds these extras:

- **Lot sizing:** a fixed lot size, or **risk % of balance** (default 1%) worked out from the SL distance.
- **Breakeven:** moves the SL to breakeven once the trade is 1 × ATR in profit.
- **Trailing stop:** an ATR trailing stop that starts at 1.5 × ATR in profit.
- **Opposite signals:** closes the open trade when the opposite signal appears.
- **One trade at a time:** holds at most one position per symbol for each magic number.
- **Filters:** a max-spread filter and an optional trading-hours filter (server time).

## Install

1. In MT5 go to **File → Open Data Folder**.
2. Copy the contents of this repo's `mt5/MQL5/` folder into that data folder's `MQL5/` folder, keeping the subfolders:
   - `Experts/TrendPulse_EA.mq5`
   - `Indicators/TrendPulse_Indicator.mq5`
   - `Include/TrendPulse/TrendPulseCore.mqh`
3. Open **MetaEditor** (F4). Compile `TrendPulse_EA.mq5` and `TrendPulse_Indicator.mq5` with F7.
4. In MT5, right-click **Navigator** and choose **Refresh**.

### Run the indicator

Drag **Indicators → TrendPulse_Indicator** onto a chart. Turn on popup, sound, push or email alerts in the inputs. Push alerts need your MetaQuotes ID under Tools → Options → Notifications.

### Run the bot

1. Turn on **Algo Trading** in the toolbar.
2. Drag **Expert Advisors → TrendPulse_EA** onto a chart. The EA trades that chart's symbol and timeframe.
3. In the **Common** tab, tick *Allow Algo Trading*.
4. Use a **different Magic number** on each chart when you run it on several charts.

## Backtest before going live

1. Open **View → Strategy Tester** (Ctrl+R) and choose `TrendPulse_EA`.
2. Pick a symbol and timeframe, for example EURUSD H1 or XAUUSD M15.
3. Set Modelling to **"Every tick based on real ticks"**.
4. Run it. Then use **Optimization** on the MA periods and the ATR multipliers.
5. To check the chart, run the tester in **visual mode** and add `TrendPulse_Indicator` to it with the same inputs. Trades should open on the bar after each arrow.

> ⚠️ Trading is risky. This code is a starting framework, not a promise of profit. Backtest it and run it on a **demo account** first.

---

# VwapScalper: EMA + VWAP scalping EA + Indicator

| File | What it is |
|---|---|
| `MQL5/Experts/VwapScalper_EA.mq5` | **Bot.** Opens and manages scalp trades. |
| `MQL5/Indicators/VwapScalper_Indicator.mq5` | **Indicator.** Draws session VWAP with ±1/±2 standard-deviation bands, the two EMAs, BUY/SELL arrows, and sends alerts with entry, SL and TP. |
| `MQL5/Include/VwapScalper/VwapScalperCore.mqh` | **Shared engine.** Holds the VWAP maths, the signal rule and the SL/TP rule. Both files above use it. |

Install it the same way as TrendPulse (see above).

## What the research says

- **VWAP is a good trend filter.** Zarattini & Aziz (2023) tested a simple rule on QQQ from 2018 to 2023: long above VWAP, short below. The best results came from **trading in the direction of VWAP**, not from fading it. An independent re-test over 8 years found the edge was **not steady**: it worked well in some years and was flat in others.
- **EMA crossovers alone are weak for scalping.** They react late and give many false signals in sideways markets. Most rule sets that hold up use EMAs to spot **pullbacks** in a trend that VWAP already confirms.
- **Treat the win rates on blogs with caution.** Pages quoting "55–65% win rate" are mostly marketing and can't be checked.
- **Costs decide whether scalping makes money.** With a 1.5R target you need about 40% winners to break even before costs. A spread plus commission of 0.1R per trade pushes that to about 44%. Low-spread symbols and a strict spread filter are required.
- **Forex has no real volume in MT5, only tick volume.** VWAP then acts as a price average weighted by activity. It still works, but real-volume symbols (futures, stocks) give a truer VWAP.
- **Timing matters.** The best conditions are M1–M5 during the London and New York sessions. VWAP is unreliable in the first bars after it resets, and when it is flat the market is usually moving sideways.

## The rules chosen: "VWAP trend + EMA pullback"

A **BUY** needs every one of these on a closed bar (SELL is the mirror image):

1. **Bias:** the close is above session VWAP **and** VWAP is rising. The rise over 5 bars must be more than 0.05 × ATR. This removes sideways days where VWAP is flat.
2. **Trend:** EMA 9 is above EMA 21.
3. **Trigger:** the candle dipped into EMA 9 and then **closed back above it as a green candle**. Only the first such candle in a pullback counts.
4. **Not chasing:** the close is no more than 2 × ATR above VWAP.
5. **Timing:** the bar is inside the session hours and at least 6 bars after the VWAP reset.

**Exits (the EA):**

- **Stop loss:** just beyond the signal candle (plus a 0.2 × ATR buffer), limited to between 0.5 and 2 × ATR from entry.
- **Take profit:** 1.5 × the risk (1.5R).
- **Breakeven:** the SL moves to breakeven at +1R.
- **Time stop:** the trade closes after 12 bars.
- **Wrong side of VWAP:** the trade closes if a bar closes on the other side of VWAP.
- **End of session:** all trades close when the session ends or VWAP resets.

**Daily safety limits:** at most 6 trades a day, 0.5% risk per trade, and trading stops for the day after a 2% loss.

## Recommended settings (starting point)

| Setting | Forex majors (EURUSD, GBPUSD) | Gold (XAUUSD) | Index CFDs (US100, US30) |
|---|---|---|---|
| Timeframe | M5 | M5 (or M3) | M1–M5 |
| Session hours (server time) | London + NY, e.g. 10–19 on a GMT+3 server | 10–20 | NY cash session, e.g. 16:30–23 on a GMT+3 server |
| Max spread (points) | 10–15 | 25–35 | Check with your broker |
| Volume type | Tick | Tick | Real, if your broker provides it |

> ⚠️ **The session hours use your broker's server time.** Check the clock in Market Watch and change `InpSessionStart`, `InpSessionEnd` and `InpResetHour` to match.

## How to find the best settings for your broker

1. Use the Strategy Tester with **"Every tick based on real ticks"** and your broker's real spread and commission.
2. Optimise a few settings only, so the results don't overfit:
   - `InpRewardRisk`: 1.0 – 2.5
   - `InpMinSlopeAtr`: 0 – 0.2
   - `InpMaxExtAtr`: 1 – 3
   - `InpSessionStart` and `InpSessionEnd`
   - `InpMaxBarsInTrade`: 6 – 24
3. Optimise on one period, for example 2022–2024. Then **run the chosen settings unchanged on a later period** (forward test). Keep them only if the profit factor stays above about 1.2 on data they were not tuned on.
4. Then run a demo account for 2–4 weeks and compare its slippage and spread with the backtest.

Sources: [Zarattini & Aziz, VWAP: The Holy Grail for Day Trading Systems (SSRN)](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4631351) · [8-year replication (Medium)](https://medium.com/@techacademies/i-tested-the-holy-grail-vwap-strategy-on-8-years-of-data-it-worked-for-three-of-them-601d1d61b535) · [ICFM: Scalping with VWAP and EMA](https://www.icfmindia.com/blog/scalping-with-vwap-and-ema-a-simple-traders-guide) · [TradeTaurex: VWAP for Forex](https://www.tradetaurex.com/forex-insights/vwap-trading-strategies/)
