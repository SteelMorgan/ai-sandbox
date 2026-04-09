# Clipboard Sync — вставка скриншотов в CLI-агентов

CLI-агенты (Claude Code, Codex CLI) работают в терминале контейнера и не имеют прямого доступа к буферу обмена Windows. Для вставки скриншотов используется двухкомпонентная схема:

```
Windows clipboard ──► tray app (хост) ──► PNG файл
                                             │
                                        bind mount :ro
                                             │
                        clipboard-watch ◄────┘
                             │
                          xclip ──► X11 clipboard (Xvfb) ──► CLI агент (Ctrl+V)
```

- **Хост:** тресй-приложение следит за буфером обмена Windows. При появлении нового изображения сохраняет его как PNG в `%TEMP%\cb-x11-sync\img.png`.
- **Контейнер:** директория примонтирована как read-only. Фоновый скрипт `clipboard-watch` обнаруживает изменение файла и загружает его в X11 clipboard через `xclip`. Виртуальный X-сервер Xvfb работает внутри контейнера — никакого ПО на хосте (VcXsrv и т.п.) не нужно.
- **Защита:** bind mount read-only — агент внутри контейнера не может писать на хост через этот mount.

## Настройка хоста (одноразово, общая для всех проектов)

Тресй-приложение **одно на все контейнеры**. Mutex не даёт запустить второй экземпляр.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-clipboard-sync.ps1
```

Скрипт:
1. Создаёт `%TEMP%\cb-x11-sync\`
2. Добавляет ярлык на рабочий стол
3. Добавляет в автозагрузку Windows

После этого приложение запускается автоматически при входе в систему.

## Настройка контейнера (для каждого проекта)

### 1. Dockerfile — добавить пакеты

В блок `apt-get install` добавить:

```dockerfile
xclip \
xsel \
xvfb \
```

### 2. Dockerfile — скопировать watcher в образ

Скопировать файл `clipboard-watch.sh` в проект (например в `.devcontainer/bin/`) и добавить в Dockerfile:

```dockerfile
COPY bin/clipboard-watch.sh /usr/local/bin/clipboard-watch

# В блоке с sed/chmod:
RUN sed -i 's/\r$//' /usr/local/bin/clipboard-watch \
 && chmod 0555 /usr/local/bin/clipboard-watch
```

Содержимое `clipboard-watch.sh`:

```bash
#!/usr/bin/env bash
# Watches /tmp/cb-x11-sync/img.png for changes and loads it into X11 clipboard.
WATCH_FILE="/tmp/cb-x11-sync/img.png"
LAST_HASH=""

while true; do
    if [ -f "$WATCH_FILE" ]; then
        HASH=$(md5sum "$WATCH_FILE" 2>/dev/null | cut -d' ' -f1)
        if [ -n "$HASH" ] && [ "$HASH" != "$LAST_HASH" ]; then
            xclip -selection clipboard -t image/png -i "$WATCH_FILE" 2>/dev/null && \
                LAST_HASH="$HASH"
        fi
    fi
    sleep 0.3
done
```

### 3. docker-compose.yml — переменные и bind mount

```yaml
services:
  your-service:
    environment:
      - DISPLAY=:99
    volumes:
      # Clipboard image sync: host writes PNG, container reads (read-only)
      - ${TEMP:-/tmp}/cb-x11-sync:/tmp/cb-x11-sync:ro
```

### 4. entrypoint.sh — запуск Xvfb и watcher

Добавить перед `exec "$@"`:

```bash
# Xvfb + clipboard watcher
if command -v Xvfb >/dev/null 2>&1; then
  Xvfb :99 -screen 0 1x1x24 -nolisten tcp &
  sleep 0.5
  if [ -x /usr/local/bin/clipboard-watch ]; then
    DISPLAY=:99 su -s /bin/bash -c '/usr/local/bin/clipboard-watch &' vscode
  fi
fi
```

> Замените `vscode` на имя пользователя контейнера, если оно отличается.

## Проверка

1. Сделайте скриншот (Win+Shift+S)
2. Тресй-иконка должна мигнуть зелёным
3. В терминале контейнера:

```bash
# Должен показать :99
echo $DISPLAY

# Должен вернуть image/png в списке
xclip -selection clipboard -t TARGETS -o

# Должен сохранить PNG
xclip -selection clipboard -t image/png -o > /tmp/test.png
file /tmp/test.png
```

4. Ctrl+V в Claude CLI / Codex CLI — изображение должно вставиться

## Troubleshooting

| Симптом | Причина | Решение |
|---|---|---|
| Тресй-иконка не появляется | Приложение не запущено | Запустить ярлык с рабочего стола |
| "Already running" при запуске | Экземпляр уже работает | Проверить скрытые иконки в трее (^) |
| `xclip: Cannot open display` | Xvfb не запущен | Проверить `ps aux | grep Xvfb` в контейнере |
| `No such file: /tmp/cb-x11-sync/img.png` | Bind mount не подключён | Перезапустить контейнер (Reopen in Container) |
| Изображение не обновляется | Watcher не запущен | Проверить `ps aux | grep clipboard-watch` |
