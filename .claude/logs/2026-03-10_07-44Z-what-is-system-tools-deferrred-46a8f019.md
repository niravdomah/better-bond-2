# What is "System tools (deferrred)" (2026-03-10 07:44Z)

**Project:** better-bond-2
**Session ID:** 46a8f019-ace6-4944-a41e-3f725eea7d10
**Started:** 2026-03-10 07:39Z
**Permission Mode:** 

---


_**User: Nirav Domah (2026-03-10 07:44Z)**_

What is "System tools (deferrred)"? Does it contribute to the context window? When I add all the tokens, I get 218.594k instead of 200k.


_**Agent (model claude-opus-4-6)**_

**System tools (deferred)** are tool definitions that exist but aren't fully loaded into context yet. They're listed by name only (you can see them in the `<available-deferred-tools>` tag) and their full schemas are fetched on-demand via the `ToolSearch` tool when needed. The 18.6k figure is an *estimate* of what they'd cost if fully loaded â€” they don't actually consume that much right now since only their names are present.

**Why the numbers exceed 200k:** The table shows estimated/potential token costs, not actual current usage. The deferred tools count is an estimate of their full schemas, but since they're deferred, they aren't actually in the context window. The "Free space" (159.6k) + "Autocompact buffer" (33k) + actual used tokens should add up closer to 200k. The deferred tools number is informational â€” showing what *would* be used if they were all loaded.

So in practice, deferred tools contribute minimally to the context window (just their names), and the 18.6k is the potential cost if they were all fetched.

[Logs saved]

---


---

## Session Summary (Recovered from /clear)

**Recovered:** 2026-03-10 07:46Z
**Total Prompts:** 3
**Tools Used:** 
**Files Modified:** 0

### Token Usage

_Token usage data not available. Run `/context` during session to capture token usage._

