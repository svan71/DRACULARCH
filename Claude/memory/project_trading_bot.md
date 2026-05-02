---
name: Trading Bot Project
description: Full macro-aware trading bot built on Alpaca paper accounts — architecture, files, strategy logic, daily workflow
type: project
originSessionId: 38b1dd88-d184-499f-af78-4d062c7e752b
---
Built 2026-05-02 (overnight session). Paper trading only until proven profitable.

**Why:** Learn to trade profitably before using real money. $15k paper budget. Goal is consistent profit, not getting rich.

**Workflow commitment (confirmed 2026-05-02):** Steve and Claude work on this together daily. Paper money for an extended teaching period — every session reviews what the bot did, why it did it, what was right/wrong, and updates the strategy code based on lessons learned. No real money until the bot has a consistent track record. This is collaborative teaching, not autopilot.

## Alpaca Accounts
- **Main account** — MCP server `alpaca` — keys in `~/.config/mg-alpaca/key.env`
- **Copy Trading account** — MCP server `alpaca-copytrading` — keys in `~/.config/mg-alpaca/key-copytrading.env`
- Both configured as paper trading (ALPACA_PAPER_TRADE defaults true)
- Both added to Claude Code via `claude mcp add` — visible in `/mcp`

## All Files — Synology
`/Volumes/External/WEB Scripts/Trading/`
- `bot.py` — main trading script, runs 9:45am ET Mon-Fri (+ catch-up fires) via launchd
- `watchdog.py` — global market monitor, runs 5x daily at 4:30pm/9pm/1am/5am/8am ET
- `strategy.py` — decision engine: translates macro data into specific trade recommendations
- `tracker.py` — logs predictions vs actual outcomes, calculates accuracy stats
- `macro.py` — fetches VIX, oil, gold; reads watchdog cache if fresh (<2hrs)
- `capitol.py` — scrapes capitoltrades.com for recent politician buy trades
- `resilience.py` — network probe, cache staleness, last-run marker, noon cutoff, heartbeat
- `config.py` — all settings: budget rules, risk thresholds, politician list
- `.env` — Alpaca copy trading keys + Tavily API key
- `macro_cache.json` — written by watchdog, read by bot (avoids cold fetches at trade time)
- `predictions.json` — daily prediction log with accuracy tracking
- `state/` — last_run markers (one per component) so catch-up fires don't double-trade
- `logs/` — daily log files from both bot and watchdog

## LaunchAgents (Mac)
- `~/Library/LaunchAgents/com.steve.tradingbot.plist` — bot, Mon-Fri 9:45am ET + catch-up fires at 10:15, 10:45, 11:30 (last_run marker prevents double-trading; noon cutoff in resilience.py blocks late trades)
- `~/Library/LaunchAgents/com.steve.tradingbot.watchdog.plist` — watchdog, 5x daily every day

## Resilience Layer (added 2026-05-02)
`resilience.py` provides `pre_trade_checks_ok()` — single gate called by bot.py before any trading. Checks:
1. **last_run marker** — `state/last_run_bot.json`; refuses to run twice in same ET date
2. **noon cutoff** — refuses trades after 12:00 ET (signals too aged)
3. **network probe** — TCP check to api.alpaca.markets + query1.finance.yahoo.com, retries once after 60s
4. **heartbeat** — aborts if `macro_cache.json` is > 12h old (watchdog feed dead)
5. **cache freshness** — aborts if cache > 4h old

Watchdog also calls `network_ok()` at start — bails early without writing a stale cache when the net is down.

`mark_ran("bot", details={...})` is called after a successful run to write the marker.

**NOT YET BUILT (Tier 3):** position reconciliation script that compares expected vs actual Alpaca positions after each run. Add after a few weeks of clean runs reveal what reconciliation actually needs to catch.

## Budget Rules ($15k)
- $3,000 cash reserve — never touched
- $12,000 working capital
- Max $2,000 per position (scales down with risk)
- Min $500 per trade
- Max 6 open positions
- Position size × conviction score (0-1) from strategy engine

## Risk Levels & What Bot Does
- **LOW** — follow Capitol Trades signals + sector plays, full position size
- **MEDIUM** — selective Capitol Trades (max 2) + 1 defensive, 75% size
- **HIGH** — defensive rotation only: XLP, XLV, ITA, GLD, 50% size
- **EXTREME** — bear mode: SH (inverse S&P), PSQ (inverse Nasdaq), GLD. No longs.

## Risk Scoring (macro.py + watchdog.py)
- VIX ≥ 30 → +4 (extreme panic)
- VIX ≥ 25 → +2 (elevated)
- Oil ≥ $110 → +4 (Hormuz/war level)
- Oil ≥ $90 → +2 (elevated)
- Gold ≥ $4000 → +3 (major fear)
- Gold ≥ $3000 → +1 (elevated)
- Gold +1.5% daily → +1 (surging)
- S&P futures ≤ -2% overnight → +4
- S&P futures ≤ -1% overnight → +2
- Nikkei or Hang Seng ≤ -2% → +2 each
- Yen strengthening ≤ -1% USD/JPY → +1
- Score 0-1=low, 2-3=medium, 4-6=high, 7+=extreme

## Sector Triggers (strategy.py)
Watchdog headlines + commodity prices trigger sector-specific plays:
- `oil_high` ($90+) → XLE, XOM
- `oil_extreme` ($110+) → XLE, CVX
- `oil_falling` (<$75 or -3% day) → XLY, UAL, DAL
- `iran_ceasefire` → XLY, AAL
- `china_trade_positive` → AAPL, NVDA, KWEB
- `defense_elevated` (Iran war headlines) → LMT, RTX, NOC
- `rate_cuts_signaled` (dovish Fed language) → XRE, XHB, XLU
- `ai_selloff` (DeepSeek etc.) → SOXS, NVDQ
- `ai_recovery` → SMH, MSFT

## Prediction Tracking
- bot.py records prediction at 9:45am: risk level, direction, reasons, tickers
- watchdog.py records outcome at 4:30pm: actual S&P change, correct/incorrect
- tracker.py calculates accuracy stats, flags when accuracy <60% after 10+ days
- Run `python3 tracker.py` for accuracy report

## Data Sources
- **Capitol Trades** (capitoltrades.com) — politician buy/sell filings
- **yfinance** — VIX (^VIX), oil (CL=F), gold (GC=F), futures (ES=F, NQ=F, YM=F), Asian/European markets
- **Tavily** — news headlines for macro event detection
- Key: `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` (in Jan backup + Trading/.env)

## Key Macro Events to Watch (as of May 2026)
- **Iran war** — Strait of Hormuz, oil supply, ceasefire talks
- **Fed chair Warsh** — takes over May 15; "regime change" tone, rate cuts dead for 2026
- **Trump-China** — Beijing visit May 14, trade deal June 11 (30% tariffs, 60-day pause)
- **DeepSeek V4** — built on Huawei chips, challenges Nvidia moat
- **Memory/GPU prices** — DRAM up 50-55% Q1 2026, consumer PC market squeezed
- **Rate cuts** (2027 target) — homebuilders, REITs, small caps will front-run

## Historical Triggers Bot Knows
- Wars: S&P drops 5-6%, recovers in 28 days (19/20 cases)
- Oil shocks: inflation, recession risk, 1973 playbook
- Fed pivots: new chair → avg 5% S&P drop month 1, 12% month 3
- Trade deals: S&P gaps up 1.5-3% same day
- Ceasefires: energy -5-8% in 48hrs, airlines/consumer up
- VIX >30: go to cash immediately
- Gold >$3000: fear elevated; gold >$4000: major fear signal
- Midterm elections Nov 2026: modest drag before, bull rally after

## Current Market Readings (May 2, 2026 1am)
- Oil: $101.94 (elevated, Iran)
- Gold: $4,629.90 (extreme fear level)
- S&P futures: +0.20%
- Nasdaq futures: +0.87%
- Yen: -1.97% (safe haven demand)
- Risk level: HIGH

## Daily Workflow with Steve
Steve connects daily to discuss:
- What happened in the market that day
- Whether bot's predictions were correct
- What signals fired and why
- Adjustments to strategy based on learnings

## Position Management (positions.py) — BUILT
Called by watchdog at 4:30pm. Requires 2+ warning signals before selling.
Never sells on a single dip — protects against over-reacting to profit-taking.

Warning signals:
1. Price below 50-day MA — uptrend weakening
2. Price below 200-day MA — long-term trend broken
3. RSI < 35 — deeply oversold / heavy selling
4. High volume (>1.5x avg) on a down day — institutions exiting
5. Drop >15% from 52-week high
6. HARD STOP: down 20%+ on cost basis — overrides everything, sells immediately

Decision logic:
- 0 warnings → HOLD
- 1 warning → WATCH (log it, do nothing)
- 2+ warnings → SELL
- Hard stop (-20% cost basis) → SELL regardless

Key insight: normal profit-taking dips are LOW volume. Real reversals are HIGH volume.
The 50-day MA is the line in the sand — above it, the uptrend is still intact.

## Politicians Tracked (config.py — updated 2026-05-02)
9 names: nancy-pelosi, tommy-tuberville, daniel-crenshaw, josh-gottheimer, ro-khanna, kevin-hern, pat-fallon, mark-green, michael-mccaul. Slugs are best-guess — bad ones will 404 in Monday's log; fix Tuesday.

## Per-Politician Cap (added 2026-05-02)
`MAX_TRADES_PER_POLITICIAN = 1` in config.py. Applied in capitol.py — caps how many trades each politician contributes per run. Stops one hyperactive name (Fallon, Gottheimer) from eating the whole budget.

## First Live Run — Monday 2026-05-04
First real paper trades. Pre-run preview against 2026-05-02 cache (HIGH risk, 5 sector triggers): bot would buy XLP, XLV, ITA, GLD, XLE, XOM (~$4,300 deployed of $12k). Steve chose Path A — trust the bot, no manual pre-queueing. Review session that evening.

## Still To Build
- Test Capitol Trades scraper when market is open (verify HTML structure may differ from scraped)
- Wheel strategy (options) — separate from copy trading bot
- Consider adding "buy the dip" logic — if WATCH status + RSI <40 + above 50MA = add to position
- Reconcile contradictory trigger sets (e.g. iran_ceasefire + defense_elevated firing together) — currently defensives win priority order, which works as a hedge but logic could be cleaner
