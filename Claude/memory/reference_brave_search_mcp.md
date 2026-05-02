---
name: oMLX search backend history (Brave → Tavily)
description: oMLX MCP search backend swapped from Brave to Tavily on 2026-04-28 after Google Custom Search rejected new GCP projects. Old configs preserved here for rollback.
type: reference
originSessionId: 30d66ec5-8a16-4d7c-85d9-f079bec9d02e
---
oMLX MCP web-search backend history. Current config lives in `~/.config/omlx/mcp.json`.

## Active (as of 2026-04-28): Tavily

**Package:** `tavily-mcp@latest` (npx, stdio)
**API key:** `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` (env `TAVILY_API_KEY`)
**Free tier:** 1000 queries/month
**Why chosen:** Returns extracted content snippets (vs Brave's titles+URLs only) — better for AI-agent use. Verified working 2026-04-28. **Steve confirmed same-day that the model "interacts better" on Tavily than Brave** — fewer repeat-search loops, model has real content to reason over. For future MCP search backend decisions, default to Tavily over Brave for AI-agent use cases.

```json
{
  "servers": {
    "tavily-search": {
      "transport": "stdio",
      "command": "npx",
      "args": ["-y", "tavily-mcp@latest"],
      "env": { "TAVILY_API_KEY": "tvly-dev-3QDIIc-..." },
      "enabled": true,
      "timeout": 60
    }
  }
}
```

Tool name oMLX exposes: `tavily-search__tavily-search` (or similar — verify in oMLX logs after restart). v1/v3 fine-tuned models trained on Brave's tool name `brave-search__brave_web_search` may need a system-prompt nudge to use the new tool name.

## Previous (2026-04-26 → 2026-04-28): Brave Search

**Package:** `@modelcontextprotocol/server-brave-search` (npx, stdio)
**API key:** `BSAdRQUZ9flD_6pgdMPziFEaAc7F1vg` (env `BRAVE_API_KEY`)
**Tool name:** `brave-search__brave_web_search`

```json
{
  "servers": {
    "brave-search": {
      "transport": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-brave-search"],
      "env": { "BRAVE_API_KEY": "BSAdRQUZ9flD_6pgdMPziFEaAc7F1vg" },
      "enabled": true,
      "timeout": 60
    }
  }
}
```

Brave's first-party server `@brave/brave-search-mcp-server` (v2.0.80, Apr 2026) is also available if the older `@modelcontextprotocol/server-brave-search` becomes unmaintained.

## Attempted but rejected: Google Custom Search

See `feedback_google_custom_search_dead.md`. Don't try this on new GCP projects.
