---
name: Don't suggest Google Custom Search API for new projects
description: Google Custom Search JSON API is sunset for new GCP projects — every call returns 403 "project does not have the access" regardless of billing/keys/restrictions. Don't waste a session debugging this.
type: feedback
originSessionId: 30d66ec5-8a16-4d7c-85d9-f079bec9d02e
---
When considering search backends for an AI agent or MCP integration, **do not propose Google Custom Search JSON API for new Google Cloud projects.**

**Why:** As of January 2026 Google announced restrictions on Custom Search JSON API. Confirmed on 2026-04-28: new GCP projects (post-March 2026) get `403 PERMISSION_DENIED` with the message "This project does not have the access to Custom Search JSON API" on every call, regardless of:
- API enabled in the project (UI shows green checkmark, dashboard shows traffic counted)
- Billing account linked and verified
- API key created fresh, unbound, with proper API restrictions
- Any amount of propagation wait time

The dashboard at `console.cloud.google.com/apis/api/customsearch.googleapis.com/metrics` will show 100% error rate even with all conditions met. Google is silently sunsetting the API for new accounts.

**Cost incurred when Steve and I attempted this on 2026-04-28:** ~30+ minutes of debugging, $10 temporary card hold (released by bank), forced upgrade from free trial to paid GCP account that he didn't want. Net dollars: $0. Net frustration: significant.

**How to apply:**
- For oMLX/MCP web search: prefer Brave (already working in Steve's setup), Tavily (AI-agent-optimized, what we ended up on 2026-04-28), or self-hosted SearXNG.
- If a user proposes Google CSE on a new project, surface this finding immediately. Don't even start the enable-API/create-key dance.
- If a user has a *legacy* GCP project (pre-March 2026) where CSE already works, it can keep working — the restriction only blocks new projects.

**Sources:**
- https://discuss.google.dev/t/custom-search-json-api-returns-403-permission-denied-on-new-org-new-account-restriction/347093
- https://support.google.com/programmable-search/thread/421229041/
