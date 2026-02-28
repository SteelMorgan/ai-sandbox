## Secrets (локально, не коммитим)

Эта папка содержит файлы-секреты, которые монтируются в контейнер как `/run/secrets/*`.

### Какие файлы используются

- `cc_api_key` — токен для `cc-custom-helper` (настройка Claude Code на кастомный endpoint).
- `github_token` — GitHub PAT для `gh` внутри контейнера (опционально, на будущее).

### Как подготовить

1. Скопируй `secrets/.env.example` в `secrets/.env`.
2. Запусти генератор:
   - Bash: `./scripts/prepare-secrets.sh`
   - PowerShell: `pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\prepare-secrets.ps1`

После этого появятся файлы `secrets/cc_api_key` и `secrets/github_token`.
