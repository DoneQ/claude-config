---
name: prefer-existing-pattern-over-abstraction
description: "Gdy wzorzec istnieje w kodzie (nawet \"nie-DRY\"), powiel go 1:1 — NIE wprowadzaj abstrakcji/agregatorów bez prośby"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 00cb7b8f-dc27-40a1-91a7-da874a645b6d
---

User dwukrotnie skorygował over-engineering: gdy linki/ścieżki routingu były wpisane inline "z palca", moją reakcją było stworzenie centralnego `*_PATH`/`*_LINK` agregatora w warstwie models. User tego nie chciał — "jakbym chciał stworzyć agregator dla linków to bym to zrobił, proszę trzymaj standard projektu" oraz "jak były wpisane z palca wcześniej to po prostu zrób tak samo".

**Why:** preferuje spójność z istniejącym kodem nad teoretyczną czystością (DRY/centralizacja). Abstrakcja wprowadzona bez prośby = niechciany scope + niespójność ze standardem projektu.

**How to apply:** domyślnie powielaj istniejący wzorzec 1:1, nawet jeśli wygląda powtarzalnie/un-DRY. Refaktor lub abstrakcję proponuj JAKO PYTANIE, nie rób z automatu — zwłaszcza gdy zadanie brzmi "zrób tak samo jak X". Konkretną regułę dla mopsa (linki/ścieżki inline, bez agregatora) zapisano w mops `CLAUDE.md`. Powiązane: [[record-discovered-project-conventions]], [[scope-stay-in-current-mrka]].
