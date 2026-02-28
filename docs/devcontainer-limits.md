# Ограничения devcontainer и базовый набор

## Electron / Chromium в devcontainer

При запуске Electron (или приложений на Chromium: Playwright, Puppeteer, VS Code extensions и т.п.) возможна ошибка:

```
pthread_create: Resource temporarily unavailable
fork: retry: Resource temporarily unavailable
```

**Причина:** лимит процессов (`pids_limit`) в Docker. Chromium создаёт много процессов (main, renderer, GPU, utility и т.д.), и при `pids_limit: 512` лимит быстро исчерпывается.

**Решение:** в `docker-compose.yml` установлен `pids_limit: 4096`. Если ошибка сохраняется:

- Убедись, что используешь актуальный compose (пересобери контейнер).
- На хосте проверь `ulimit -u` и `/proc/sys/kernel/threads-max` — они могут ограничивать процессы глобально.

## Базовый набор (в образе)

Агент не должен устанавливать внутри контейнера то, что уже есть в образе:

| Компонент | Назначение |
|-----------|------------|
| **git** | Репозитории, ветки |
| **openssh-client** | SSH для git |
| **gh** (GitHub CLI) | PR, ветки, auth |
| **docker-ce-cli** | Docker (при монтировании docker.sock) |
| **python3** | auto-skill-bootstrap, скрипты |
| **python3-venv** | Виртуальные окружения Python |
| **nodejs**, **npm** | `npx skills find`, frontend-задачи |
| **curl**, **gnupg**, **ca-certificates** | Загрузки, ключи, HTTPS |
| **sudo** | Установка пакетов (apt, pip, npm) |

## Что агент ставит по задаче

Агент может устанавливать внутри контейнера:

- `apt` — системные пакеты (build-essential, libpq-dev и т.п.)
- `pip` / `pipx` — Python-пакеты
- `npm` / `pnpm` / `yarn` — Node-зависимости

Если какой-то пакет нужен часто — добавь его в `.devcontainer/Dockerfile` и пересобери образ.
