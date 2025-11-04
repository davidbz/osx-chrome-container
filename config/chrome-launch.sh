#!/bin/bash
chromium --no-first-run --disable-gpu --disable-software-rasterizer --disable-dev-shm-usage --window-size=1024,768 "$@"
