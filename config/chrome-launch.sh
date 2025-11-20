#!/bin/bash

# Clean up Chrome lock files from previous runs (happens when container is forcefully stopped)
PROFILE_DIR="/home/chrome/.config/chromium"
if [ -d "$PROFILE_DIR" ]; then
    echo "Cleaning up Chrome lock files..."
    rm -f "$PROFILE_DIR/SingletonLock" \
          "$PROFILE_DIR/SingletonSocket" \
          "$PROFILE_DIR/SingletonCookie" \
          "$PROFILE_DIR/Default/SingletonLock" \
          "$PROFILE_DIR/Default/SingletonSocket" \
          "$PROFILE_DIR/Default/SingletonCookie" 2>/dev/null || true
fi

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

chromium --no-first-run --disable-gpu --disable-software-rasterizer --disable-dev-shm-usage --window-size=1280,1024 $EXTENSION_ARGS "$@"
