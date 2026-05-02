---
name: Van's PC & Mac Repair website
description: Steve's local PC repair business site at ~/Desktop/vans-repair/ — fully rebuilt 2026-05-01 in Apple-grammar all-dark; rebrand pending, photos pending, redeploy pending
type: project
originSessionId: f8ab3e03-68fe-41c4-8de4-3b76f9c7753c
---
**Site:** Van's PC & Mac Repair (Vincentown, NJ — home users only, NOT businesses)

**Location:** `~/Desktop/vans-repair/` — `index.html`, `styles.css`, `script.js`, `images/` (logos retained but unused), `NOTES.md` (original notes)

**Deployed:** Cloudflare Pages (URL not noted in repo). No domain yet.

---

## 2026-05-01 — Full ground-up rebuild

Built using the pipeline from Jack Roberts video `tn7zXRv3Xmo` ("DeepSeekV4 + Claude Code = 100X Cheaper"). Steve provided a complete Apple design-system spec; Claude (this session) executed the design pass. DeepSeek not used — site has no backend worth offloading.

**Stack:** vanilla HTML/CSS/JS. No build step. Cloudflare-ready.

**Design language:** Apple grammar — edge-to-edge tiles, single Action Blue `#0066cc` accent, no mascots, no decorative gradients, no shadows except (eventually) on photography. `system-ui` font stack catches real SF Pro on Apple devices, Inter as fallback.

**Mood: ALL-DARK** (user explicitly chose against the L/D alternation). Tile background `#1c1c1e`, cards on `--color-card #2e2e30` with translucent white border. Cards are the differentiator now since the color-change-as-divider pattern is gone.

**9 tiles top→bottom:** hero → services → linux pitch → pricing → reviews → about → service area → contact → footer. Every tile is `tile--dark`. Every subsection uses elevated cards.

**Big content cuts:**
- Mascot retired (computer character with thumbs up). Logo files kept in `images/` but unused.
- All 8 cartoon SVG service icons gone — services are pure-typography elevated cards now.
- Cheesy copy gone: "No geeks. No squads.", "Won't make you cry", "I'll nurse it back to health", "Wild concept, I know", "Steve Van you ARE the computer man!", etc.
- 16 Nextdoor reviews → 4 best (Dina M. Leisuretowne · Pat V. Bella Bridge · Michael T. Leisuretowne re: Comcast · Anna Z. Vincentown 7-year).
- "Vincentown, NJ" eyebrow removed from hero (last edit before bedtime).

**Voice held:** warm, direct, confident, non-threatening, no jokes. Examples: "Honest service. Fair prices. Talk to one person from start to finish." / "If your twelve-year-old laptop isn't worth fixing, I'll tell you."

**Polish:**
- LocalBusiness JSON-LD schema (SEO win for local search)
- Skip link for a11y
- `prefers-reduced-motion` respected
- Mobile drawer ≤833px, single-col ≤640px
- Body bumped 17→18px page-wide; small text bumped 14/15→16/17px after Steve flagged things felt small

---

## Open decisions (resume here tomorrow)

### 1. Business name — flagged as flat, NEEDS DECISION
Steve dislikes "Van's PC & Mac Repair" — apostrophe-s reads folksy/dated, "PC & Mac" stutters.

Claude proposed (recommendation flagged):
- **Van Computer Co.** ← recommended. Keeps surname, drops folksy possessive, "Co." adds quiet authority.
- Van Tech — shorter, punchier
- Van Repair Co. — most direct, craft-shop feel
- Vincentown Computer — local pride
- Pinelands Tech — regional character
- The Computer Bench — anonymous craftsman style
- Plain Tech — straight-talk vibe

When name is decided: rebrand wordmark in nav, footer, JSON-LD `name`, `<title>`, OG title.

### 2. Photos — explicitly skipped for now
Steve sent a beautiful watercooled HYTE white-case build photo (2026-05-01 02:40 screenshot). Claude pushed back on using it as the hero (would mis-signal — gaming rig vs. home user repair). Suggested it for the Custom PC Builds tile IF it's Steve's actual work / properly licensed. Steve said "lose the photos for now" — site is type-only.

When photos return: hero needs a quiet "everyday repair" photo (open laptop / clean bench / Linux desktop). Custom builds tile can use the gaming rig if confirmed his.

### 3. Domain
Original NOTES.md suggested `vansrepair.com` or `vanspcmac.com`. Both will likely change once new business name lands. Don't buy until name is final.

### 4. Cloudflare redeploy
Site is on CF Pages but with the OLD version. Push the rebuild when Steve approves.

### 5. Optional: Codex/GPT-5.5 review pass (final step in Jack Roberts pipeline) — not yet run.

---

## Key files (do not re-read on resume — they were rewritten 2026-05-01)
- `index.html` — 9-tile structure documented above
- `styles.css` — Apple-token design system, `--color-card #2e2e30` on `#1c1c1e` tiles
- `script.js` — mobile drawer toggle only (4-line replacement of older inline-style mess)

## Unrelated but adjacent
- Groq API key now in `~/.config/api-keys.env` (sourced from `~/.bashrc`) AND `~/.config/watch/.env`. (Key redacted from memory — don't store raw API keys here.)
- `/watch` plugin (`bradautomates/claude-video`) installed and verified working with the Jack Roberts video.
