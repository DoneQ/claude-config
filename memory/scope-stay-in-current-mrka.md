---
name: scope-stay-in-current-mrka
description: "Scope check applies ONLY to global/sweep requests — for direct commands just act, don't check scope"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 25cfed9e-6936-4a81-a152-4a278cd8a2e7
---

The "stay in the current branch/MR (mrka)" rule applies **ONLY to global/sweep requests** — NOT to direct commands. Classify the request first, then:

**Direct / specific command** — user points at a concrete target (this file, this component, this template, this method): "change X here", "pass Z to W", "rename this", "fix this `*ngIf`".
- **Just DO it.** Do NOT check branch scope, do NOT do git/merge-base archaeology, do NOT gate on blast-radius investigation.
- If fulfilling it directly needs a file the branch hasn't touched yet, edit that file — the user pointed at the task, that's authorization.

**Global / sweep request** — "fix all X", "do Y everywhere", "popraw całą mrkę", "przeskanuj i popraw":
- "mrka" / "cała mrka" = **this branch/MR**, NOT the whole monopolex app.
- Apply the change **only within the files the branch already touches**.
- If it might be worth going beyond the branch, **ASK** whether to change outside the mrka too — don't silently sweep the whole codebase, don't auto-expand.

**Don't check scope on every action** — only when the request is global/sweep-shaped. Over-checking on direct commands is wasted overhead (I once ran full git merge-base analysis for a one-template change the user pointed at directly).

**Touching shared services/files OUTSIDE the MR diff to IMPLEMENT a requested feature is allowed — it's NOT a "global change".** When the clean implementation of a direct request needs a change in a service/helper/file the branch hasn't touched (e.g. adding a `searchCommitted` signal to a singleton service so the feature works), just do it — those files get pulled into the MR scope. User: "możesz dotykać serwisów poza mr od implementacji rzeczy przecież to nie globalna zmiana". The "ask first / branch-only" gate is for **broadening beyond the feature** (unrelated files, codebase-wide migrations, sweeps), NOT for the files a single feature legitimately spans.

**Why:** I (a) swept 16 unrelated legacy files codebase-wide when "całą mrkę" meant the branch → user rolled it back; then (b) over-corrected by gating a *direct* request behind scope/blast-radius checks. User: "w przypadku bezposrednich polecen nie musisz wgl sprawdzac SCOPE MRKI tylko jak prosze o globalne zmiany"; "[dla globalnych] zmieniasz tylko w mrce albo pytasz czy zmienic poza mrka rowniez, nie sprawdzaj tego za kazdym razem".

**How to apply:** is the request aimed at a named target → act immediately. Is it "all / everywhere / whole" → branch-only, or ask before going wider. Relates to [[task-list-completeness]].
