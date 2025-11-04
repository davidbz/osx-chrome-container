#!/bin/bash

# Auto-load extensions from /home/chrome/extensions directory
EXTENSION_ARGS=""
if [ -d "/home/chrome/extensions" ]; then
    for ext_dir in /home/chrome/extensions/*; do
        if [ -d "$ext_dir" ] && [ -f "$ext_dir/manifest.json" ]; then
            EXTENSION_ARGS="$EXTENSION_ARGS --load-extension=$ext_dir"
            echo "Loading extension: $(basename "$ext_dir")"
        fi
    done
fi

chromium --no-first-run --disable-gpu --disable-software-rasterizer --disable-dev-shm-usage --window-size=1024,768 $EXTENSION_ARGS "$@"
