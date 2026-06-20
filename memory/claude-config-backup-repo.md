---
name: claude-config-backup-repo
description: "Backup ~/.claude (reguły, CLAUDE.md, memory, project backups) jest wersjonowany w prywatnym repo git DoneQ"
metadata: 
  node_type: memory
  type: project
  originSessionId: 00cb7b8f-dc27-40a1-91a7-da874a645b6d
---

Konfiguracja Claude Code (`~/.claude`) ma backup w prywatnym repo git: **`git@github.com:DoneQ/claude-config.git`** (GitHub, konto DoneQ). Lokalny working copy: `C:\Users\ukryt\claude-config`.

Repo zawiera: globalny `CLAUDE.md`, `rules/**`, `hooks/preflight-check.ps1`, `memory/**`, `projects-backup/<projekt>/{CLAUDE.md,PROJECT_MAP.md}`. NIE zawiera dokumentacji pluginów ani sekretów. README ma: mapę „co gdzie należy", **ścieżki projektów per komputer** (na razie tylko `DONEQ`; drugi komp do uzupełnienia po `git pull`), i instrukcję szybkiej aktualizacji.

**Auth:** klucz SSH `~/.ssh/id_ed25519` działa dla GitHub DoneQ. `gh` CLI NIE jest zainstalowany, git nie ma globalnej tożsamości (repo-local: `DoneQ` / `DoneQ@users.noreply.github.com`). Jeden remote (GitHub) — user mówi „gitlab" na github.com/DoneQ, NIE ma osobnego GitLaba/mirrora.

**How to apply:** gdy user mówi „backupuj klaudy" / „zaktualizuj backupy" — po odświeżeniu `~/.claude/projects-backup/` skopiuj aktualne md do `~/claude-config` (wg sekcji „Aktualizacja" w README) i `git push`. Powiązane: [[verify-against-git-not-summary]].
