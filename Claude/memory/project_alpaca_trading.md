---
name: Alpaca Paper Trading Setup
description: Paper trading account setup with Alpaca MCP server for Claude Code — waiting on API keys
type: project
originSessionId: dd1df4ec-d309-46f3-9674-c806724a82b3
---
Setting up Alpaca MCP server for paper trading practice before using real money.

**Why:** Practice trading with fake money using real market data; plan to use real money after a few weeks of paper trading.

**Status:** Waiting on Alpaca API keys. Account not yet created.

**What's done:**
- Claude Desktop config updated: `~/Library/Application Support/Claude/claude_desktop_config.json` has `mcpServers.alpaca` with placeholder keys
- Claude Code: will use `claude mcp add alpaca --scope user --transport stdio /opt/homebrew/bin/uvx alpaca-mcp-server --env ALPACA_API_KEY=X --env ALPACA_SECRET_KEY=X` once keys are in hand

**Decision:** Use Claude Code (not Desktop) as primary interface — Desktop doesn't share MCPs or CLAUDE.md.

**How to apply:** Next session, prompt user for Alpaca keys before proceeding. Once keys provided, run the `claude mcp add` command, then verify with `/mcp`.
