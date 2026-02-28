# ai-agent-sandbox-devcontainer

Цель: изолированная песочница для ИИ-агента на Docker Desktop/WSL2 **без маунтов хостовых дисков**. Код и состояние живут в Docker volume, источник истины — git.

## Быстрый старт (volume workspace)

1. Установить https://marketplace.cursorapi.com/items/?itemName=anysphere.remote-containers или его аналог (anysphere.remote-containers, dev-containers)

2. Убедись, что Docker Desktop запущен и есть volume для песочницы (по умолчанию `agent-work-sandbox-lite`, см. `.devcontainer/docker-compose.yml`):

- `docker volume ls`
- если нет: `docker volume create agent-work-sandbox-lite`

3. Открой этот репозиторий через Dev Containers так, чтобы workspace жил в volume.

Ключевые файлы:

- `.devcontainer/devcontainer.json` — **lite** профиль (sudo, **без** docker.sock)
- `.devcontainer/devcontainer.docker.json` — lite + **docker.sock** (опасно, но иногда нужно)
- `.devcontainer/devcontainer.network-none.json` — restricted + **network none**
- `.devcontainer/devcontainer.onec.json` — профиль **с платформой 1С + активацией** (тяжёлый)



## Новый контейнер под новый проект (1 проект = 1 volume)

Схема: для каждого проекта создаёшь отдельную папку с этим шаблоном (только конфиги), а код потом клонируешь внутрь volume уже из контейнера.

В новой папке запусти:

- `powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-project.ps1 -CreateVolume`

Скрипт:

- берёт имя текущей папки → делает slug
- правит `.devcontainer/docker-compose*.yml` (уникальные `container_name` и volume)
- создаёт Docker volume `agent-work-<slug>` (если включён `-CreateVolume`)

## Один контейнер — много проектов (лайтовый режим)

Это нормальная схема, если тебе не нужна жёсткая изоляция по зависимостям/кэшу.

Правило использования (если хочешь **один** контейнер на все проекты):

- Поднимай devcontainer **только один раз** из этой песочницы (`SandBox`).
- Все проекты держи **внутри контейнера** в `/workspaces/work` (это внешний volume `agent-work-sandbox-lite`, он сохраняется между пересборками).
- Открывай/переключай проекты **внутри уже запущенного контейнера** (не создавая новый devcontainer):
  - либо через **Attach to Running Container** к `ai-agent-sandbox`
  - либо через **File → Open Folder…** на нужную подпапку внутри `/workspaces/work`

### Как хранить репозитории, чтобы не было свалки

Держи каждый репозиторий в отдельной подпапке внутри volume:

- `/workspaces/work/repoA`
- `/workspaces/work/repoB`

### Как переключать “проект” в Cursor / VSC

После подключения к контейнеру:

- **File → Open Folder…** → выбираешь нужную папку репо (например `/workspaces/work/repoB`)

Cursor будет работать **только** с открытой папкой, даже если в контейнере лежат другие репозитории.

### Практические правила

- Не клонируй репы в корень `/workspaces/work` без подпапок — потом будет боль.
- `gh auth` и `~/.gitconfig` общие на контейнер: это удобно, но помни, что identity/токены одни на всё окружение.

## Автосоздание репозитория + ветка agent + инвайт бота

Скрипт: `scripts/provision-repo.ps1`

Важно:

- Запускай его там, где `gh` залогинен **под твоим основным аккаунтом** (обычно хост), потому что репо создаётся от имени текущего пользователя `gh`.
- Бот `steel-code-agent` должен **принять инвайт** после выполнения скрипта.

Пример:

- **Просто создать репо**:
  - `powershell -ExecutionPolicy Bypass -File .\scripts\provision-repo.ps1 -RepoName my-private-repo -AddReadme`
- **Создать репо и сразу залить “скелет проекта”** (например `.cursor/skills`, `docs/`, конфиги):
  - подготовь папку-шаблон (пример: `templates/repo-seed` в этом репозитории)
  - `powershell -ExecutionPolicy Bypass -File .\scripts\provision-repo.ps1 -RepoName my-private-repo -SeedPath .\templates\repo-seed`

## Публичить репо + включить защиту main (после публикации)

Отдельный скрипт: `scripts/publish-and-protect.ps1`

Зачем отдельный:
- на GitHub Free защита ветки для **private** репо часто упирается в 403, поэтому мы не пытаемся ставить protection на этапе provisioning
- когда/если репо станет public (или ты апгрейдишь план) — включаешь protection одной командой

Пример:
- `powershell -ExecutionPolicy Bypass -File .\scripts\publish-and-protect.ps1 -RepoName my-private-repo -RequiredApprovals 1`

## Предохранитель от пуша в main/master (локальный git hook)

Так как в некоторых планах GitHub для приватных репо защита ветки может быть **Not enforced**, в devcontainer ставится **локальный** `pre-push` hook:

- блокирует прямой `git push` в `main`/`master`
- ставится в **образ** (root-owned, read/exec only), чтобы агент не мог “случайно” стереть/переписать

Важно:

- это **не** серверная защита, а “ремень безопасности” внутри контейнера
- если пуш делают с другой машины/окружения — этот хук не сработает
- намеренно обойти хук тоже можно (например, подменить `core.hooksPath`), без server-side enforcement это неизбежно

## Операционные команды для агента

Внутри репозитория (в контейнере):

Рекомендованный workflow:

- на каждую задачу создать сабветку **от `agent**`:
  - `agent-task-branch fix-auth`
- после тестов слить сабветку в `agent` и запушить `agent`:
  - `agent-merge-to-agent`
- PR `agent → main` — **только по явной команде пользователя**:
  - `agent-open-pr`

Примечание:

- `agent-new-branch` оставлен как вспомогательная команда, но основной процесс — через `agent-task-branch`/`agent-merge-to-agent`.

## Claude Code и Codex в devcontainer

Позволяет переключить Claude CLI и Codex CLI на "свои" сервера llm-моделей. Также добавляет аллиасы для ENG & RU раскладок. Bootstrap настраивается автоматически при старте контейнера:

- запускается из `.devcontainer/postCreateCommand.sh`
- использует не-секретные параметры из `.devcontainer/.env`
- использует секрет `cc_api_key` из Docker secrets (`/run/secrets/cc_api_key`)

Что настраивается:

- **Codex**: `.devcontainer/codex-bootstrap.sh` генерирует `~/.codex/config.toml` и `~/.codex/.env`, а также wrapper `~/bin/codex-safe.sh`
- **Claude Code**: helper и status line настраиваются в `.devcontainer/postCreateCommand.sh`

Алиасы:

- `cx` / `сч` → `~/bin/codex-safe.sh`
- `cc` / `сс` → `~/bin/claude-safe.sh`

Алиасы для Claude (`cc` и `сс`) выглядят почти одинаково, но это разные символы:

- `cc` — обе буквы **латиница** (`c` + `c`)
- `сс` — обе буквы **кириллица** (`с` + `с`)

Визуально их легко перепутать. Если не срабатывает один вариант, попробуйте второй.

Для удобства:

- на английской раскладке обычно набирают `cc`
- на русской раскладке обычно набирают `сс`
- оба алиаса запускают один и тот же wrapper `~/bin/claude-safe.sh`

То же правило для Codex:

- `cx` — латиница
- `сч` — кириллица
- оба алиаса запускают `~/bin/codex-safe.sh`

Разница `cx` и `codex`:

- `cx` гарантированно подгружает ключ из `~/.codex/.env` через wrapper
- `codex` читает `~/.codex/config.toml`, но без ключа в окружении может уйти в auth flow/401

Если bootstrap не сгенерировал конфиг:

- при пустом `CC_HELPER_BASE_URL` или `CODEX_MODEL` Codex-конфиг пропускается
- в этом случае `codex` работает с дефолтными настройками CLI
- `cx` остается wrapper-алиасом, но без сгенерированных файлов поведение почти как у `codex` (если нет старых файлов в `~/.codex`)

Практический чек после rebuild:

1. `source ~/.bashrc`
2. `ls -la ~/.codex`
3. `cx --version`
4. `cx exec --skip-git-repo-check "Reply with: ok"`

## Документация

- `docs/devcontainer-limits.md` — ограничения (Electron, pids_limit), базовый набор
- `docs/github-bot-setup.md` — бот + PAT (минимальные права)
- `docs/branch-protection.md` — защита `main/master` (PR-only)
- `docs/auth-inside-container.md` — логин `gh`/git identity внутри контейнера + тестовый push в `agent/*`
- `docs/agent-git-reglament.md` — ветки/PR/восстановление
- `docs/security-hardening.md` — усиление безопасности (опционально)




## Sudo и доступ к Docker (опциональные профили)

По умолчанию песочница “широкая” (под концепт *“агент может ставить что угодно внутри песочницы”*):

- `sudo` доступен (без `no-new-privileges`).
- docker socket **не** проброшен по умолчанию.

Если нужно сузить права:

- **Ограниченный + без сети**: `.devcontainer/devcontainer.network-none.json`

Если нужен доступ к Docker Desktop из песочницы:

- **Профиль с docker.sock**: `.devcontainer/devcontainer.docker.json`

Важно:

- доступ к `/var/run/docker.sock` = фактически root-доступ к Docker host (можно снести контейнеры/volumes).
- “запинить” контейнеры от удаления на уровне Docker CLI надёжно нельзя; это только дисциплина/процедуры.

