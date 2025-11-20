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

# Global variable to store Chrome PID
CHROME_PID=""

# Graceful shutdown function
graceful_shutdown() {
    echo "Received shutdown signal, gracefully stopping Chrome..."
    if [ -n "$CHROME_PID" ] && kill -0 "$CHROME_PID" 2>/dev/null; then
        # Send SIGTERM to Chrome for graceful shutdown
        echo "Sending SIGTERM to Chrome (PID: $CHROME_PID)..."
        kill -TERM "$CHROME_PID"
        
        # Wait up to 10 seconds for Chrome to exit gracefully
        for i in {1..10}; do
            if ! kill -0 "$CHROME_PID" 2>/dev/null; then
                echo "Chrome exited gracefully"
                exit 0
            fi
            sleep 1
        done
        
        # If still running after 10 seconds, force kill
        echo "Chrome didn't exit gracefully, forcing shutdown..."
        kill -KILL "$CHROME_PID" 2>/dev/null || true
    fi
    exit 0
}

# Set up signal handlers for graceful shutdown
trap graceful_shutdown SIGTERM SIGINT

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

# Start Chrome in background and store PID
echo "Starting Chromium..."
chromium --no-first-run --disable-gpu --disable-software-rasterizer --disable-dev-shm-usage --window-size=1024,768 $EXTENSION_ARGS "$@" &
CHROME_PID=$!

echo "Chrome started with PID: $CHROME_PID"

# Wait for Chrome to exit
wait "$CHROME_PID"
CHROME_EXIT_CODE=$?

echo "Chrome exited with code: $CHROME_EXIT_CODE"
exit $CHROME_EXIT_CODE
