---
name: Trading vocabulary auto-routes to the bot
description: Steve's casual trading words ("trades", "market", "stocks", "how'd we do") always refer to the Synology trading bot project — never ask for clarification
type: feedback
originSessionId: 8db1cc92-1db6-4e94-ac3f-cbe59bf921ec
---
When Steve says any of the following, he means the Alpaca paper-trading bot at `/Volumes/External/WEB Scripts/Trading/`:

- "trades" / "the trades" / "our trades"
- "the market" / "how's the market"
- "the bot" / "the trading bot"
- "our stocks" / "what we own" / "our portfolio"
- "how did we do today" / "how'd our stocks do" / "what happened today"
- "did the bot run" / "did it trade"
- "the daily review" / "let's review"

**Why:** Steve confirmed (2026-05-02) this is now a daily-collaboration project. He hates typing and won't keep re-establishing context. The trading bot is the active, recurring topic — assume that's what he means unless he explicitly names something else (DRACULARCH, fine-tune, AI server, etc.).

**How to apply:** When any of those phrases appear, immediately:
1. Read `project_trading_bot.md` from memory for context
2. Check the latest log in `/Volumes/External/WEB Scripts/Trading/logs/` — date-stamped per day
3. Check `predictions.json` for the day's prediction + outcome (after 4:30pm ET)
4. Check actual Alpaca positions via the `alpaca-copytrading` MCP tool
5. Lead the response with what you found — don't ask "which project do you mean?"

This is one of Steve's primary ongoing projects. Treat trading-related phrasing as a routing signal, not ambiguity.
