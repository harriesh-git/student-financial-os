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
