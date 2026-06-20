# claude-config

Backup mojej konfiguracji Claude Code (`~/.claude`) — reguły, globalne instrukcje,
memory i backupy `CLAUDE.md` projektów. Trzymane na gicie, żeby zsynchronizować
między komputerami.

## Struktura

| Ścieżka w repo | Odpowiada w `~/.claude` |
|---|---|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` (globalne instrukcje) |
| `rules/**` | `~/.claude/rules/**` (TS / Angular / Spectator) |
| `hooks/preflight-check.ps1` | `~/.claude/hooks/preflight-check.ps1` |
| `memory/**` | `~/.claude/projects/C--Users-ukryt/memory/**` |
| `projects-backup/**` | backupy `CLAUDE.md` + `PROJECT_MAP.md` projektów (monopolex / mops) |

## Odtworzenie na drugim komputerze

```bash
git clone git@github.com:DoneQ/claude-config.git
cd claude-config

# globalna konfiguracja
cp CLAUDE.md            ~/.claude/CLAUDE.md
cp -r rules             ~/.claude/
cp hooks/preflight-check.ps1 ~/.claude/hooks/

# memory (dostosuj nazwę katalogu projektu jeśli inna na tym kompie)
cp memory/*.md          ~/.claude/projects/C--Users-ukryt/memory/

# CLAUDE.md projektów — wgraj ręcznie do odpowiednich repozytoriów
#   projects-backup/monopolex-frontend/CLAUDE.md  -> <repo>/CLAUDE.md
#   projects-backup/monopolex-online-platform-suite/CLAUDE.md -> <repo>/CLAUDE.md
```

> Katalog memory (`C--Users-ukryt`) zależy od ścieżki home — na innym koncie
> Windows nazwa będzie inna. Skopiuj zawartość do właściwego `.../memory/`.
