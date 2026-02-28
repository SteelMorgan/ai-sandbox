# Branch protection для `main`/`master` (PR-only)

Цель: агент **никогда** не пушит в `main/master`. Только через PR из `agent/*`.

## Рекомендуемые настройки (GitHub)

В репозитории: Settings → Branches → Branch protection rules

Включить для `main` (и/или `master`):
- **Require a pull request before merging**
  - (опционально) Require approvals (1+)
  - (желательно) Dismiss stale approvals on new commits
- **Require status checks to pass before merging**
  - выбрать нужные checks (CI)
- **Restrict who can push to matching branches**
  - запретить прямые push всем (или только maintainers, но агенту — точно нет)
- (опционально) **Require linear history**
- (опционально) **Include administrators** (если хочешь жёстко)

## Проверка

- Попробуй локально сделать push в `main` (должно быть запрещено).
- Убедись, что PR из `agent/*` можно создать и смержить только через checks/approval.

## Важная оговорка про private репозитории

GitHub может показывать `Not enforced` для branch protection rules в некоторых типах приватных репозиториев/планов.
В этом случае технического server-side запрета пуша в `main` **не будет**, даже если правило создано.

Что делать:
- либо переносить репо в org/план, где enforcement работает,
- либо использовать локальный предохранитель в контейнере (pre-push hook) как anti-footgun и ревьюить PR руками.

