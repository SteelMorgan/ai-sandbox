# AI Agent Sandbox

Шаблон devcontainer для запуска AI-агентов (Claude Code, Codex CLI) в изолированной Docker-среде. Код живёт в Docker volume, не на хосте — агент может ставить зависимости, ломать окружение и пересоздавать его без последствий для машины.

## Архитектура

```
Cursor / VSCode
      │
      ▼
Dev Container (Docker volume workspace)
      │
      ├── Claude Code (cc)  ──┐
      └── Codex CLI (cx)    ──┴──► 9Router (LLM proxy) ──► любой LLM API
```

**Ключевые принципы:**
- Workspace в Docker volume — выживает при rebuild контейнера
- Git как источник истины — репозитории клонируются внутрь volume
- Секреты через Docker secrets — не в образе, не в env хоста

## Требования

- Docker Desktop (Windows/Mac) или Docker Engine (Linux)
- VS Code или Cursor с расширением [Dev Containers](https://marketplace.cursorapi.com/items/?itemName=anysphere.remote-containers)
- `gh` CLI, авторизованный под твоим аккаунтом (на хосте)

## Быстрый старт

**1. Заполни секреты**

```
secrets/.env          ← скопируй из secrets/.env.example и заполни
secrets/cc_api_key    ← API-ключ для Claude Code / 9Router
secrets/github_token  ← GitHub PAT (scope: repo, read:org)
```

Сгенерируй Docker secrets из файлов:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\prepare-secrets.ps1
```

**2. Создай volume для workspace**

```bash
docker volume create agent-work-sandbox-lite
```

> Volume объявлен как `external: true` в docker-compose.yml — Docker не создаёт его автоматически и упадёт с ошибкой если volume отсутствует. Данные в volume сохраняются при rebuild контейнера.

**3. Открой в Dev Containers**

Открой папку репозитория через **Dev Containers: Reopen in Container**. Workspace смонтируется из volume в `/workspaces/work`.

**4. Проверь агентов**

```bash
cx --version                                    # Codex CLI
cx exec --skip-git-repo-check "Reply with: ok" # тест вызова модели
cc --version                                    # Claude Code
```

## AI-инструменты

### Claude Code — `cc` / `сс`

Запускается через wrapper `~/bin/claude-safe.sh`. Настройки берутся из `.devcontainer/.env` и секрета `cc_api_key`.

**Настройка 9Router для Claude Code**

Claude Code обращается к моделям по фиксированным именам: `opus`, `sonnet`, `haiku`. В 9Router нужно создать **Combo** с точно таким именем, и прописать в него один или несколько реальных бэкендов:

| Combo name | Что подставить |
|---|---|
| `opus` | Любая мощная модель (Claude Opus, GPT-5, Gemini Pro и др.) |
| `sonnet` | Сбалансированная модель |
| `haiku` | Быстрая / дешёвая модель |

В Combo можно указать любой провайдер, однако наиболее стабильное поведение достигается с оригинальными моделями Anthropic — Claude изначально обучен управлять инструментами и форматировать вывод в своём нативном формате.

### Codex CLI — `cx` / `сч`

Запускается через wrapper `~/bin/codex-safe.sh`. При старте контейнера скрипт `codex-bootstrap.sh` генерирует `~/.codex/config.toml` с профилями моделей.

> Алиасы `cc`/`сс` и `cx`/`сч` — латиница и кириллица соответственно, оба варианта работают.

**Настройка 9Router для Codex**

Codex использует кастомный список моделей, который bootstrap собирает из двух источников:

**1. `codex-model-map.json` — маппинг на официальные модели Codex**

Сопоставляет имена в 9Router (`cx/*`) с оригинальными slug-ами из [официального репозитория Codex](https://github.com/openai/codex/blob/main/codex-rs/core/models.json). Благодаря этому bootstrap заполняет метаданные модели (контекстное окно, описание, возможности) так же, как в оригинале.

```json
{
  "cx/gpt-5.3-codex": "codex-1",
  "cx/gpt-5.1-codex-mini": "codex-mini-latest"
}
```

**2. `codex-model-overrides.json` — ручные описания для моделей без upstream**

Для моделей, которых нет в официальном списке (например `ag/gemini-3.1-pro-high`), поля задаются вручную. Описание всех полей: [`docs/codex-model-catalog-fields.md`](docs/codex-model-catalog-fields.md)

**Системный промт для Gemini**

Для моделей, в имени которых содержится `gemini`, bootstrap при старте контейнера скачивает системный промт напрямую из официального репозитория Codex:

[`codex-rs/core/prompt_with_apply_patch_instructions.md`](https://github.com/openai/codex/blob/main/codex-rs/core/prompt_with_apply_patch_instructions.md)

### Переменные окружения `.devcontainer/.env`

| Переменная | Назначение |
|---|---|
| `OPENAI_BASE_URL` | URL 9Router (или другого прокси) |
| `CODEX_MODEL` | Модель по умолчанию для Codex |
| `CODEX_MODELS` | Список моделей → генерирует профили в `config.toml` |
| `CODEX_MODEL_PROVIDER_ID/NAME` | Имя провайдера в Codex UI |
| `CODEX_MODEL_MAP_FILE` | JSON с маппингом `cx/*` → upstream slug |
| `CODEX_MODEL_OVERRIDES_FILE` | JSON с ручными описаниями моделей (`ag/*` и др.) |
| `CODEX_GEMINI_PROMPT_FILE` | Системный промт для моделей Gemini |

## Профили контейнера

| Файл | Когда использовать |
|---|---|
| `devcontainer.json` | Стандартный (sudo, без docker.sock) |
| `devcontainer.docker.json` | + доступ к Docker Desktop (⚠️ фактически root на хосте) |
| `devcontainer.network-none.json` | Без доступа к сети (максимальная изоляция) |

## Сценарии использования

### Один контейнер — много проектов

Поднимаешь `SandBox` один раз. Все репозитории клонируешь внутрь `/workspaces/work/` как подпапки. Переключаешься через **File → Open Folder…** внутри уже запущенного контейнера или **Attach to Running Container**.

```
/workspaces/work/
  ├── project-a/
  └── project-b/
```

### Отдельный контейнер на проект

Копируешь шаблон в новую папку, запускаешь:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-project.ps1 -CreateVolume
```

Скрипт создаёт уникальный volume и правит `docker-compose*.yml`.

## Управление репозиториями

**Создать репо + пригласить бота:**
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\provision-repo.ps1 -RepoName my-repo -AddReadme
```

**Создать репо с seed-шаблоном** (`.cursor/skills`, `docs/` и т.п.):
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\provision-repo.ps1 -RepoName my-repo -SeedPath .\templates\repo-seed
```

**Сделать репо публичным + защита main:**
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\publish-and-protect.ps1 -RepoName my-repo
```

## Git workflow для агента

Внутри контейнера доступны команды:

| Команда | Действие |
|---|---|
| `agent-task-branch fix-auth` | Создать ветку от `agent` |
| `agent-merge-to-agent` | Слить текущую ветку в `agent` |
| `agent-open-pr` | Открыть PR `agent → main` (только по явной команде) |

## Безопасность

- **pre-push hook** в образе блокирует прямой push в `main`/`master` изнутри контейнера
- **docker.sock** не пробрасывается по умолчанию
- **sudo** доступен — sandbox по умолчанию «широкая» (агент может ставить пакеты)

Детали: [`docs/security-hardening.md`](docs/security-hardening.md)

## Документация

| Файл | Содержимое |
|---|---|
| [`docs/auth-inside-container.md`](docs/auth-inside-container.md) | `gh` auth и git identity внутри контейнера |
| [`docs/agent-git-reglament.md`](docs/agent-git-reglament.md) | Ветки, PR, восстановление |
| [`docs/branch-protection.md`](docs/branch-protection.md) | Защита main/master |
| [`docs/github-bot-setup.md`](docs/github-bot-setup.md) | Бот + PAT |
| [`docs/devcontainer-limits.md`](docs/devcontainer-limits.md) | Ограничения (Electron, pids_limit) |
| [`docs/security-hardening.md`](docs/security-hardening.md) | Усиление безопасности |
| [`docs/codex-model-catalog-fields.md`](docs/codex-model-catalog-fields.md) | Поля модели для Codex |
