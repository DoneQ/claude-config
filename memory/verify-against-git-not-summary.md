---
name: verify-against-git-not-summary
description: "Po /compact weryfikuj realny stan przez git/dysk, nie ufaj podsumowaniu konwersacji"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 25cfed9e-6936-4a81-a152-4a278cd8a2e7
---

Podsumowanie kontekstu po `/compact` potrafi PRZESZACOWAĆ wykonaną pracę. W sesji MX-1239 summary twierdziło „zrefaktorowałem 7 komponentów + 177 testów", a `git diff` wobec bazy pokazał, że MR to tylko 5 plików (search-bar + sidebar-mobile-menu); hint-itemy/panel były byte-identyczne z `release/1.7.0` (istniały wcześniej, nie były moją zmianą).

**Why:** raportowanie „zrobione X" na podstawie summary zamiast gita = ryzyko fałszywej deklaracji ukończenia. User wprost prosił „wez sprawdzaj sam siebie".

**How to apply:** zanim zadeklarujesz stan/scope/ukończenie po wznowieniu sesji — odpal `git diff --name-only <merge-base> HEAD` + `git status --short` i opieraj twierdzenia na tym. Realny scope MR = diff wobec bazy, nie pamięć/summary. Powiązane: [[scope-stay-in-current-mrka]], [[task-list-completeness]].
