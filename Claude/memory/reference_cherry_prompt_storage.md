---
name: Cherry Studio prompt storage locations
description: Cherry has two separate prompt stores — chat Assistants vs Agents — and only one is editable from disk
type: reference
originSessionId: d5f113d3-33f9-4d75-86c4-2c24018ebd7d
---
Cherry Studio (macOS) has two distinct prompt systems:

1. **Chat Assistants** (sidebar "Assistants" tab in Home view) — stored in IndexedDB at `~/Library/Application Support/CherryStudio/IndexedDB/file__0.indexeddb.leveldb/`, **Snappy-compressed by Chromium**, not plaintext-greppable. Cannot be safely edited from outside; must be edited via the GUI (click ⋮ on the assistant → Edit Assistant). Steve's main chat assistant is named "Prompt" and uses DeepSeek.

2. **Agents** (separate "Agents" tab in top nav) — stored in SQLite at `~/Library/Application Support/CherryStudio/Data/agents.db`, table `agents`, column `instructions`. Plaintext, editable via `sqlite3` directly. Steve has an agent named "Deepseek" (id `agent_1777550506094_1ubfz6iol`) which is a separate thing from the chat "Prompt" assistant — easy to confuse them.

When Steve says "the prompt that loads when a model is run", he means the chat Assistant (#1), not the Agent (#2).
