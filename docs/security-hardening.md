# Усиление безопасности (опционально)

## Профили сети

- Обычные задачи: `.devcontainer/devcontainer.json` (compose-профиль, сеть включена).
- Подозрительные/файлоопасные: `.devcontainer/devcontainer.network-none.json` (compose + `network_mode: none`).

## Docker Desktop / контекст

Идея: держать отдельный Docker context/набор настроек под агента, чтобы случайно не работать “в боевом”.
Если у тебя несколько окружений — это реально снижает шанс накосячить.

## Ресурсные лимиты

В `.devcontainer/docker-compose.yml` уже выставлены:
- `cpus: "4.0"`
- `mem_limit: 8g`
- `pids_limit: 512`

Если агент начинает троттлиться — это ожидаемо. Это цена за изоляцию.

## Capabilities и привилегии

В `.devcontainer/docker-compose.yml` уже выставлено:
- `cap_drop: [ALL]`
- `security_opt: [no-new-privileges:true]`

Это базовая санитария. Если кто-то предлагает “давай добавим privileged” — это прямой путь к дыре.

