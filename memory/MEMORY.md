<!--
Memory zaczyna od zera (2026-05-05). Reguły kodu zarchiwizowane do
~/.claude/projects-backup/_archived_memory/ — od teraz reguły żyją WYŁĄCZNIE
w plikach: ~/.claude/CLAUDE.md, ~/.claude/rules/, ~/.claude/hooks/, oraz
<projekt>/CLAUDE.md i <projekt>/.claude/PROJECT_MAP.md.

Memory jest dla rzeczy o user / współpracy / sesji / kontekście których
w regułach nie ma sensu trzymać. Wypełnia się organicznie.
-->

## Setup / kontekst

- [Backup repo claude-config](claude-config-backup-repo.md) — ~/.claude wersjonowany w prywatnym `git@github.com:DoneQ/claude-config.git`; „backupuj klaudy" → odśwież i `git push`

## Współpraca

- [Task list completeness](task-list-completeness.md) — gdy user daje listę zadań: zapisz ją durably, wykonaj WSZYSTKO, zweryfikuj 100%, wyjaśnij każdy brak
- [Scope: zostań w aktualnej mrce](scope-stay-in-current-mrka.md) — NIGDY nie wychodź poza branch/MR; out-of-scope → zapytaj, nie ruszaj
- [Weryfikuj przez git, nie summary](verify-against-git-not-summary.md) — po /compact realny stan/scope sprawdzaj `git diff`/`status`, summary potrafi przeszacować
- [Zapisuj odkryte konwencje projektu](record-discovered-project-conventions.md) — po „sprawdź projekt i ustal standard" od razu utrwal konwencję w projekt CLAUDE.md/rules
- [Powiel wzorzec, nie abstrahuj](prefer-existing-pattern-over-abstraction.md) — gdy coś jest inline „z palca", zrób tak samo; agregator/abstrakcję proponuj jako PYTANIE, nie z automatu
