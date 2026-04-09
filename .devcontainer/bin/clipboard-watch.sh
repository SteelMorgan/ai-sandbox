#!/usr/bin/env bash
# Watches /tmp/cb-x11-sync/img.png for changes and loads it into X11 clipboard.
# Runs inside the container as a background daemon (started by entrypoint).
# Requires: xclip, inotifywait (inotify-tools) or polling fallback.

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
