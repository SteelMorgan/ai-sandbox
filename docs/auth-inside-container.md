# Аутентификация GitHub внутри контейнера (PAT внутри volume)

Цель: токен и креды живут **внутри Docker volume**, а не на хосте.

## Вариант A (рекомендуется): `gh auth login` внутри контейнера

1) Открой devcontainer.
2) Внутри контейнера:

- `gh auth login`
  - GitHub.com
  - HTTPS
  - Paste an authentication token

После логина:
- `gh auth status`

Где хранится:
- в этой песочнице `gh` настроен хранить конфиг в volume: `GH_CONFIG_DIR=/workspaces/work/.config/gh` (переживает rebuild контейнера).

## Вариант B: git credential helper (если не хочешь `gh`)

Можно использовать `git credential-manager`, но в Linux-контейнере это часто лишний гемор.
Если тебе нужен только git over HTTPS — `gh` проще и надёжнее.

## Git identity (обязательно)

Внутри контейнера задай identity бота:

- `git config --global user.name "myname-ai-bot"`
- `git config --global user.email "myname-ai-bot@users.noreply.github.com"`

Примечание:
- в песочнице глобальный gitconfig хранится в volume: `GIT_CONFIG_GLOBAL=/workspaces/work/.gitconfig`.

## Smoke test: clone + push только в agent/*

Пример:

- `git clone https://github.com/<org>/<repo>.git`
- `cd <repo>`
- `agent-task-branch smoke-test` (или вручную `git checkout -b agent/smoke-20260128 agent`)
- создать файл, commit
- `git push -u origin HEAD`

Если push в `main` проходит — branch protection настроен плохо (см. `docs/branch-protection.md`).

## Важно про тип токена (частая ловушка)

Если бот работает с приватными репозиториями, где он добавлен как collaborator (репозитории принадлежат **другому** владельцу), fine-grained PAT может не давать доступ.
В таком случае используй **classic PAT** для бота со scope:
- `repo`
- `read:org`

