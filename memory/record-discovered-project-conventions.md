---
name: record-discovered-project-conventions
description: "Gdy analizuję/ustalam konwencję projektu, OD RAZU zapisz ją do danych projektowych (CLAUDE.md / rules)"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 25cfed9e-6936-4a81-a152-4a278cd8a2e7
---

Kiedy badam projekt i ustalam „jak ten projekt rozwiązuje X" (konwencja pozycjonowania paneli, wzorzec komunikacji komponentów, gdzie żyją helpery itd.) — **OD RAZU utrwalam to w danych projektowych**, nie tylko w odpowiedzi czatu. Konwencje kodu → `<projekt>/CLAUDE.md` (lub `~/.claude/rules/`), NIGDY do memory (memory = współpraca/sesja/user).

**Why:** user chce, żeby raz ustalona prawda o projekcie była dostępna w przyszłych sesjach zamiast badać to od nowa. „od razu przy analizie rozwiązań projektowych dodaję je do swoich zapisanych danych projektowych żeby wiedzieć jak rozwiązywać takie problemy w tym projekcie w przyszłości".

**How to apply:** po każdym przeglądzie typu „sprawdź projekt i ustal standard" → dopisz ustaloną konwencję do `<projekt>/CLAUDE.md` (z konkretami: pliki/przykłady), zrób backup. Jeśli stara reguła opisuje rozwiązanie, które właśnie zastąpiłem — zaktualizuj/usuń ją, nie zostawiaj nieaktualnej. Powiązane: [[verify-against-git-not-summary]].
