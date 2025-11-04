#!/bin/bash
set -e

echo "=== Starting VNC Environment ==="

# Start D-Bus session bus and export to environment file
eval $(dbus-launch --sh-syntax)
echo "export DBUS_SESSION_BUS_ADDRESS=\"$DBUS_SESSION_BUS_ADDRESS\"" > /tmp/dbus-env
echo "export DBUS_SESSION_BUS_PID=\"$DBUS_SESSION_BUS_PID\"" >> /tmp/dbus-env
echo "D-Bus session started: $DBUS_SESSION_BUS_ADDRESS"

# Export DISPLAY
export DISPLAY=:99
echo "export DISPLAY=:99" >> /tmp/dbus-env

# Start Xvfb with proper options
Xvfb :99 -screen 0 1280x720x24 -ac +extension GLX +render -noreset &
XVFB_PID=$!
echo "Xvfb started with PID: $XVFB_PID"

# Wait for X server to be ready
for i in {1..10}; do
  if xdpyinfo -display :99 >/dev/null 2>&1; then
    echo "X server is ready"
    break
  fi
  echo "Waiting for X server... ($i/10)"
  sleep 1
done

# Verify X server is running
if ! xdpyinfo -display :99 >/dev/null 2>&1; then
  echo "ERROR: X server failed to start"
  exit 1
fi

# Start window manager
openbox &
echo "Window manager started"
sleep 1

# Start x11vnc
x11vnc -display $DISPLAY -nopw -listen 127.0.0.1 -xkb -forever -shared -rfbport 5900 -ncache 10 &
VNC_PID=$!
echo "x11vnc started with PID: $VNC_PID"
sleep 1

# Initialize clipboard (helps with copy/paste)
echo "Initializing clipboard support"
xclip -selection clipboard -i /dev/null 2>/dev/null || true

# Source environment and start Chromium
echo "Starting Chromium with environment: DISPLAY=$DISPLAY"
source /tmp/dbus-env && /usr/local/bin/chrome-launch.sh "$@" &
CHROME_PID=$!
echo "Chromium started with PID: $CHROME_PID"
sleep 2

# Start websockify for browser access (foreground process)
echo "Starting noVNC on port 6901"
echo "Access via: http://localhost:6901"
exec /usr/bin/websockify --web=/opt/noVNC 6901 127.0.0.1:5900
