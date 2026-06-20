---
name: task-list-completeness
description: "When the user sends a list of items/fixes, track them durably and verify 100% completion before reporting"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 25cfed9e-6936-4a81-a152-4a278cd8a2e7
---

When the user sends a **list** of tasks/errors/fixes (multiple items in one message), I MUST:

1. **Write the list down durably immediately** — TaskCreate (session tracking) and/or an explicit checklist in my reply. Do NOT hold it only in working memory.
2. **Execute every item** — not a subset. Partial completion is a failure even if each done item is correct.
3. **Verify 100% before reporting** — re-check each item is actually done (e.g., re-grep, re-read), not assumed. For renames: re-grep that ZERO old occurrences remain.
4. **If something is NOT done, address WHY explicitly** — never silently drop an item or defer it without saying so. "I left X because Y" is mandatory.

**Why:** the user caught me twice fixing only part of a sent list (`onWindowResize` was explicitly listed and I deferred it to a hook). That forces the user to police my completeness — exactly what they should not have to do. Their words: "nie odpierdalaj takich rzeczy ze wysylam ci liste bledow a ty poprawiasz tylko czesc... wez sprawdzaj sam siebie."

**How to apply:** at the start of any multi-item request, enumerate the items as a tracked list; at the end, walk the list item-by-item and state done/not-done + reason. Lean on tooling (grep/tsc) to PROVE completeness rather than claiming it. Relates to [[critical-mode-self-check]].
