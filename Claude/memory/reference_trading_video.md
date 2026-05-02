---
name: Trading Video Notes
description: Key info from YouTube trading tutorials — Alpaca setup, copy trading, trailing stops, wheel strategy, HOT signals, macro 4-wave repricing thesis
type: reference
originSessionId: bc4e2c55-28e0-485b-9a17-1bfae8b1f444
---
## Video 1 (original setup tutorial)
https://www.youtube.com/watch?v=lH5wrfNwL3k (by someone who worked at JP Morgan)

### Three levels covered

**Level 1 — Setup**
- Use Alpaca (alpaca.markets) — free, paper trading built in, API access
- Create paper trading account, name it (e.g. "Trading Claude"), set fake balance (e.g. $50,000)
- Get API keys: Endpoint + Key + Secret (secret shown only once — copy immediately)
- Paper trading is DEFAULT in Alpaca — no extra flag needed
- Connect Claude via MCP (alpaca-mcp-server)
- Create a `trading` folder in Documents to keep everything organized

**Level 2 — Copy Trading Bot**
- Track what Wall Street whales and US politicians are buying
- Site to use: **Capitol Trades** (capitoltrades.com) — updated daily, tracks politician trades
- Strategy: copy trades from top performers (example: "McCaul" — 34.8% return vs S&P 500's 15% over same period)
- Claude accesses Capitol Trades data via MCP, copies trades automatically into paper account
- Second paper account used for this strategy to keep it separate

**Level 3 — Wheel Strategy (options)**
- One of the most consistent income strategies in trading
- How it works: sell cash-secured puts → if assigned, sell covered calls → repeat ("the wheel")
- Claude automates this via Alpaca options API
- Good for generating regular income rather than just capital gains

**Key warnings:** Not financial advice — paper trading only. Claude Pro/Max recommended for MCP features.

---

## Video 2 (deeper Claude Code + Alpaca tutorial)
https://www.youtube.com/watch?v=Rqmdw4xyIMM

### Three strategies demonstrated with full Claude Code implementation

#### Strategy 1: Trailing Stop Monitor (TSLA demo)
- Claude Code project folder: ~/Tranding (their typo)
- Model used: Opus 4.6 (1M context) + Sonnet 4.6
- Bypass permissions mode enabled
- Cron: every 5 min, 9:00 AM–4:59 PM, Mon-Fri
- Files: `tsla_strategy_log.json`, `.env` (credentials)

**Trailing stop rules (from their prompt):**
- Buy stock at market price
- Initial stop: if price drops to [FLOOR], sell everything
- Trailing trigger: once stock is UP 10% from entry, activate trailing
- Trail logic: move stop to 5% below current price; every additional 5% gain, raise floor again
- Floor ONLY goes up, never down
- Ladder-in: if price drops to [PRICE], buy [X] more shares

**TSLA live example (at recording):**
- Entry: $360.27
- Current: $359.85 (−0.12%)
- Stop floor: $324.24
- Trailing activates at: $396.30 (+10%)
- Status: holding, no action needed

#### Strategy 2: Congress Copy Trading
- Data source: Capitol Trades via Quiver Quantitative (MCP-connected)
- Scoring formula: `number_of_buys × log10(total_dollar_volume)`
- **Top-ranked politician: Michael McCaul (R-TX)**
  - 53 buys, ~$5.9M total volume, Score: 358.82
  - Stocks: NFLX, META, ORCL, SAP, ADSK, INTU, WDAY (large-cap tech + defense)
  - Why: House Foreign Affairs Committee → defense/tech inside info
- Ranking table in video:
  1. McCaul (R-TX): 53 buys, $5.9M, 358.82
  2. Blumenthal (D-CT): 49 buys, $4.3M, 325.21
  3. Cisneros (D-CA): 21 buys, $555K, 120.63
  4. Letlow (R-LA): 15 buys, $225K, 80.28
- **CRITICAL CAVEAT: Capitol Trades data lags 30–45 days** (everyone has the same delay)
- HOT signal: if 5+ politicians buy same stock → strong signal, consider auto-trade

**Full running system (from their Claude Code sessions view):**
- `tsla-trailing-stop-monitor` — Running, every 5 min, market hours Mon-Fri
- `congressional-trades-alert` — Running, every morning 10 AM Mon-Fri
- `capitol_trades_analyzer.py` — Ready, run with: `python3 capitol_trades_analyzer.py TSLA 5`
- `capitol_trades_snapshot.json` — Saved, updated on every run
- **Auto-trade trigger:** HOT signal (5+ politicians) → auto-place paper trade

#### Strategy 3: Wheel Strategy (TSLA demo)
**4-stage cycle:**
- Stage 1: Sell cash-secured put ~10% OTM, 2-4 weeks expiry, collect premium
  - TSLA at $250 → sell $230 put → collect $5/share
  - If stays above $230 → keep $5, sell again
  - If drops to $230 → get assigned (buy stock at "discount")
- Stage 2: Now own shares → sell covered call above your cost basis
- Stage 3: Sell call → collect more premium
- Stage 4: Shares called away → back to cash → spin wheel again

**TSLA example total return:**
- Put premium: +$5/share
- Call premium: +$5/share
- Share gain (bought $230, sold $260): +$35/share
- **Total: +$45/share**

**Account requirements:** $50K cash, Options Level 3 approved

**Bot rules:**
- Check positions every 15 min during market hours
- If contract hits 50% profit before expiration → close early, sell new one
- Daily summary at market close: stage, premium collected, positions, total return
- Do nothing outside market hours

#### Data sources architecture (from their diagram)
- **Quiver Quantitative** → Congress trades (via MCP skill)
- **Unusual Whales** → Options flow (via MCP skill)
- **Finviz / SEC** → Insider filings (via MCP skill)
- All flow through "The Wall" → MCP → Claude sees what big players see
- "Data flows 24/7, MCP is the plug that connects Claude to it"

#### What's applicable to our bot (compared to our current setup)
- Our capitol.py already uses Capitol Trades — McCaul is in our politician list ✅
- We have per-politician caps already ✅
- **We DON'T have trailing stops** — could add to our position management
- **We DON'T have wheel strategy yet** — on our "Still To Build" list
- McCaul's specific tickers (NFLX, META, ORCL, SAP, ADSK, INTU, WDAY) worth tracking
- HOT signal (5+ politicians) could be added to our risk scoring / signal strength
- Quiver Quantitative and Unusual Whales = additional data sources we haven't integrated

---

## Video 3 — Mark Moss Show: "This Has Only Happened 4 Times in 50 Years"
https://www.youtube.com/watch?v=Qwqn12D20iw  (20 min, iHeart Radio / Mark Moss)

### The Macro Thesis (2026 context — Iran war, Strait of Hormuz closed)
A rare pattern has fired: gold dropped 25%+ during a global crisis. Historically only 4 times in 50 years (1973, 1978, 2008, 2026). Every time it triggers a full repricing of all asset classes in a specific sequence.

**Gold crash stats:**
- Feb 2026: gold at ATH ~$5,600
- Iran war closes Strait of Hormuz → gold drops to $4,100 (March 23rd) = −25%
- Biggest weekly loss since 1983; sentiment index went from 80s → 15
- Already bouncing back above $4,700 as of video date
- Historical precedent: 1973 (−29% → +117% in 15mo), 1978 (−22% → +300% in 12mo), 2008 (−34% → +180% over 3yr to $1,900)

**Oil situation:**
- Strait of Hormuz: 20M bbl/day (20% of world supply) was flowing through it
- Replacement supply patches: Saudi pipeline, UAE pipelines, IAEA reserves, Russia floating storage → gets to ~12.5M bbl/day (4M is temporary)
- Bloomberg estimates real shortfall: >11M bbl/day
- World is short 7–10% of oil supply
- Historical: 1980 drop of 4.3% → recession; COVID 9.2% drop → $6T printing
- SPR at lowest level in decades — "cheat code is gone"
- Recession trigger: US oil consumption crossing 3% of GDP = recession → threshold ~$120/barrel

**Fiscal math:**
- "True interest expense" = Social Security + Medicare + debt interest payments
- As of February 2026, this hit **104% of federal tax revenue**
- Every non-mandatory dollar spent by the US government is now borrowed
- This is before a recession — if recession hits, tax revenue falls but obligations rise

### The Four Waves of Asset Repricing (sequence is always the same)

**Wave 1 — Gold & Commodities (HAPPENING NOW)**
- Gold is the "smoke detector" for monetary debasement — moves before the Fed announces anything
- Smart money (central banks, sovereign wealth funds) can see the math, buys early
- China has been buying gold for 15 consecutive straight months (Reuters, Feb 7, 2026)
- Central banks bought 700+ tons of gold last year
- Also: energy, industrial metals, agriculture — anything priced in dollars with real scarcity

**Wave 2 — Dollar Weakens**
- Currently dollar is STRONG (DXY above 108) — driven by oil-dollar demand (countries need dollars to buy oil)
- But this strength is "driven by desperation, not confidence"
- When Fed starts printing/easing, dollar rolls over
- Amplifies Wave 1: weaker dollar → commodity prices rise even faster

**Wave 3 — Hard Assets Reprice**
- Real estate, land, commodity-producing equities (mining stocks, energy producers, infrastructure)
- Post-2008: real estate bottomed, ran for a decade — not because economy was great, but because dollars got weaker
- 1970s: real estate was one of best asset classes of the decade — because of inflation, not despite it
- Mining/energy stocks: own real stuff, sell at rising prices, fixed debt in weakening currency = built-in advantage

**Wave 4 — Liquidity Wave Hits Risk Assets (especially Bitcoin)**
- Fed actively printing → liquidity floods system → lifts equities broadly, but not equally
- Assets that benefit most: hardest to produce, can't be printed more of
- Bitcoin: 21M fixed supply, born from 2008 crisis (Satoshi launched Jan 2009)
- After 2020 printing: BTC went $6K → $60K → $100K — "not a coincidence, that's the sequence"

### Historical Timeline (2008 example)
- Oct 2008: gold bottomed
- Mar 2009 (5 months later): S&P bottomed
- 2011: Real estate bottomed
- 2012: Each wave lagged the one before — money moved through the system in order

### What to AVOID (wrong-environment portfolio)
- **60/40 stock/bond** — built for slow growth, low inflation, stable dollar (the old environment)
- **Long-duration bonds** — get destroyed when inflation runs
- **Cash** — loses as dollar weakens
- **Growth stocks with no real assets** — repriced down when cost of capital rises
- "The biggest risk isn't a market crash — it's being positioned for the wrong environment"

### Portfolio checklist from the video
- Do you own anything that benefits from Wave 1? (Gold, commodities)
- Do you own anything that benefits from a weakening dollar?
- Do you have hard assets? (Real estate, commodity producers)
- Do you have anything that generates income when currency loses purchasing power?
- Do you have a position in truly scarce assets (Bitcoin) for the Wave 4 liquidity flood?

### Relevance to our bot
- Wave 1 commodities/gold signal = macro backdrop for our trading decisions
- Dollar weakness signal (Wave 2) = context for position sizing on commodity-linked stocks
- Energy producers and mining stocks could be worth adding to our watchlist as Wave 3 plays
- Bitcoin position sizing could scale up as Wave 4 approaches
- This is a longer-term macro frame (months-to-years), not day-trading signals
