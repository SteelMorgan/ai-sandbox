# GitHub бот + PAT (fine-grained или classic)

## Что делаем

- Заводим отдельный GitHub аккаунт-бот (например `myname-ai-bot`).
- Даём ему доступ **только** к нужным репозиториям.
- Делаем PAT с минимальными правами и сроком жизни 30–90 дней.

## 1) Аккаунт-бот

- Создай отдельный аккаунт (не свой основной).
- Включи 2FA.
- Добавь в нужные private repo как collaborator **или** добавь в org/team с минимальными правами.

## 2) PAT (минимум прав)

### Вариант A: fine-grained PAT

Рекомендуется, если бот работает в репозиториях, принадлежащих выбранному resource owner (например org).

Минимум:
- **Repository access**: только нужные репозитории.
- **Permissions**:
  - **Contents**: Read and write
  - **Pull requests**: Read and write (если бот будет создавать PR)
- **Expiration**: 30–90 дней.

Ограничение:
- для приватных репозиториев **другого владельца** (где бот просто collaborator) fine-grained токен может не сработать.

### Вариант B: classic PAT (часто проще)

Если бот работает как collaborator в приватных репозиториях чужого owner — обычно проще classic PAT:
- scopes: `repo`, `read:org`
- expiration: 30–90 дней.

Важно:
- PAT **не хранить** в репозитории.
- PAT хранится **только внутри Docker volume** (см. `docs/auth-inside-container.md`).

