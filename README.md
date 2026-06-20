# claude-config

Backup konfiguracji Claude Code (`~/.claude`) + per-project `CLAUDE.md` / `PROJECT_MAP.md`.
Trzymane na gicie do synchronizacji między komputerami.

## Co gdzie należy (per typ pliku)

| Typ pliku | Plik w repo | Docelowa lokalizacja |
|---|---|---|
| globalny `CLAUDE.md` | `CLAUDE.md` | `~/.claude/CLAUDE.md` |
| reguły | `rules/**` | `~/.claude/rules/**` |
| hook | `hooks/preflight-check.ps1` | `~/.claude/hooks/preflight-check.ps1` |
| memory | `memory/**` | `~/.claude/projects/<slug-home>/memory/**` |
| **per-project `CLAUDE.md`** | `projects-backup/<projekt>/CLAUDE.md` | **`<root-projektu>/CLAUDE.md`** |
| **per-project `PROJECT_MAP.md`** | `projects-backup/<projekt>/PROJECT_MAP.md` | **`<root-projektu>/.claude/PROJECT_MAP.md`** |

> - `<slug-home>` zależy od konta Windows — na DONEQ to `C--Users-ukryt`; na innym kompie inny.
> - `<root-projektu>` różni się **per komputer** → patrz tabela „Ścieżki projektów per komputer".

## Ścieżki projektów per komputer

Gdzie wgrać per-project pliki (`CLAUDE.md`, `PROJECT_MAP.md`) na danym komputerze.
**Uzupełniaj po każdym nowym kompie**: po `git pull` + sklonowaniu projektów sprawdź realne
ścieżki, dodaj analogiczną sekcję i `git push`.

### Komputer `DONEQ` (Windows 11 + WSL Ubuntu, user `doneq`)

`~/.claude` → `C:\Users\ukryt\.claude` · slug-home memory → `C--Users-ukryt`

| Projekt | Plik | Ścieżka docelowa |
|---|---|---|
| monopolex-frontend | `CLAUDE.md` | `\\wsl.localhost\Ubuntu\home\doneq\Projects\monopolex-frontend\CLAUDE.md` |
| monopolex-frontend | `PROJECT_MAP.md` | `\\wsl.localhost\Ubuntu\home\doneq\Projects\monopolex-frontend\.claude\PROJECT_MAP.md` |
| mops (monopolex-online-platform-suite) | `CLAUDE.md` | `\\wsl.localhost\Ubuntu\home\doneq\Projects\monopolex-online-platform-suite\CLAUDE.md` |
| mops | `PROJECT_MAP.md` | `\\wsl.localhost\Ubuntu\home\doneq\Projects\monopolex-online-platform-suite\.claude\PROJECT_MAP.md` |

> Z poziomu WSL te same ścieżki to `~/Projects/monopolex-frontend/...`
> oraz `~/Projects/monopolex-online-platform-suite/...`.

### Komputer `<drugi>` — DO UZUPEŁNIENIA

> Na drugim kompie po `git pull`: znajdź realne ścieżki projektów (`~/.claude`, root każdego
> projektu, slug-home memory), wpisz tu sekcję jak wyżej i `git push`.

## Odtworzenie na nowym komputerze

```bash
git clone git@github.com:DoneQ/claude-config.git
cd claude-config

# globalna konfiguracja
cp CLAUDE.md                  ~/.claude/CLAUDE.md
cp -r rules                   ~/.claude/
cp hooks/preflight-check.ps1  ~/.claude/hooks/
cp memory/*.md                ~/.claude/projects/<slug-home>/memory/   # slug-home wg konta

# per-project — wgraj wg tabeli „Ścieżki projektów per komputer"
#   projects-backup/<projekt>/CLAUDE.md       -> <root-projektu>/CLAUDE.md
#   projects-backup/<projekt>/PROJECT_MAP.md  -> <root-projektu>/.claude/PROJECT_MAP.md
```

## Aktualizacja (szybko)

Po zmianach w `~/.claude` lub w projektach — z katalogu repo:

```bash
SRC=~/.claude
cp "$SRC/CLAUDE.md"                   CLAUDE.md
cp "$SRC/rules/lang/typescript.md"   rules/lang/typescript.md
cp "$SRC/rules/arch/angular.md"      rules/arch/angular.md
cp "$SRC/rules/testing/spectator.md" rules/testing/spectator.md
cp "$SRC"/projects/C--Users-ukryt/memory/*.md memory/
cp "$SRC/hooks/preflight-check.ps1"  hooks/preflight-check.ps1
# per-project CLAUDE.md / PROJECT_MAP.md — skopiuj z root'ów projektów wg tabeli wyżej

git add -A && git commit -m "update config" && git push
```

## GitLab (mirror) — DO DOKOŃCZENIA

Planowany drugi remote (mirror). **Pending** — wymaga:
1. autoryzacji klucza `~/.ssh/id_ed25519.pub` na docelowym GitLabie (na `gitlab.com` obecnie
   zwraca `Permission denied (publickey)`),
2. podania dokładnego URL repo (np. `git@gitlab.com:DoneQ/claude-config.git` lub self-hosted).

Po ustaleniu URL:
```bash
git remote set-url --add --push origin git@github.com:DoneQ/claude-config.git
git remote set-url --add --push origin <URL-gitlab>     # jeden `git push` na oba
```
