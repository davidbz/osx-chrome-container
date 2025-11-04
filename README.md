# Chromium on Docker with GUI Forwarding (macOS)

Run Chromium browser in a Docker container with GUI forwarded to your macOS desktop via **X11 (XQuartz)** or **VNC** (browser-based).


## Two GUI Forwarding Methods

### 1. X11 via XQuartz (Traditional)
- Requires XQuartz installation
- Direct window forwarding to macOS desktop
- Lower performance due to X11-over-TCP overhead

### 2. VNC (Recommended)
- Browser-based access (no client needed)
- Significantly better performance than X11
- Access via `http://localhost:6901`
- Modern VNC with optimized compression

## Quick Start

### Option A: VNC (Recommended - Better Performance)

```bash
./run.sh --vnc [chrome args]
```

Then open your browser to: **`http://localhost:6901`**
- No password needed
- Pass optional Chrome arguments like `--incognito` or `--new-window`

**Note:** You may see harmless D-Bus warnings about the system bus (`/run/dbus/system_bus_socket`). These are normal - Chrome uses these for hardware integration features that aren't needed in a container. The browser will work perfectly fine.

### Option B: X11 via XQuartz

**Prerequisites:**
1. **Docker Desktop** - running
2. **XQuartz** - X11 server for macOS
   ```bash
   brew install --cask xquartz
   ```

**Run:**
```bash
./run.sh --x11 [chrome args]
```

Pass optional Chrome arguments as needed.

## Usage

```bash
./run.sh --vnc [chrome args]    # Launch with VNC (browser-based)
./run.sh --x11 [chrome args]    # Launch with X11 (XQuartz)
./run.sh --cleanup              # Remove all Docker images/containers
```

**Examples:**
```bash
./run.sh --vnc --incognito           # Launch in incognito mode
./run.sh --x11 --new-window          # Open a new window
./run.sh --vnc https://example.com   # Open specific URL
```

## Copy/Paste Support (VNC Mode)

Copy/paste between your macOS and the containerized Chrome works seamlessly in VNC mode:

### **Copy from macOS → Paste in Chrome:**
1. Copy text on your Mac (⌘+C)
2. In the noVNC interface, click the clipboard icon (📋) in the left sidebar
3. Paste your content into the clipboard dialog (⌘+V)
4. Close the dialog
5. Now paste inside Chrome (Ctrl+V or right-click → Paste)

### **Copy from Chrome → Paste on macOS:**
1. Copy text in Chrome (Ctrl+C or ⌘+C)
2. Click the clipboard icon (📋) in the noVNC sidebar
3. Your copied text will appear in the dialog
4. Select and copy it (⌘+C)
5. Paste on your Mac normally (⌘+V)

**Pro Tip:** Some modern browsers support automatic clipboard sync - check the noVNC settings (gear icon) for "Clipboard" options.

## How It Works

### X11 Method
```
┌──────────────┐         ┌──────────────┐         ┌─────────────┐
│  run.sh      │ ──────> │   XQuartz    │ <────── │   Docker    │
│  --x11       │         │  (X Server)  │         │  Container  │
└──────────────┘         └──────────────┘         └─────────────┘
                                │                         │
                                │    X11 Protocol         │
                                │    (TCP port 6000)      │
                                └─────────────────────────┘

                         Your Mac's Desktop
                         displays Chromium
```

**Flow:**
1. Container runs Chromium
2. Chromium connects to XQuartz via TCP (`<your-ip>:6000`)
3. XQuartz renders the GUI on your desktop

### VNC Method
```
┌──────────────┐                                  ┌─────────────┐
│  run.sh      │ ──────────────────────────────> │   Docker    │
│  --vnc       │                                  │  Container  │
└──────────────┘                                  │  + VNC      │
                                                  └──────┬──────┘
                                                         │
┌──────────────┐         ┌──────────────┐              │
│   Browser    │ <────── │   HTTP       │ <────────────┘
│ (Safari/etc) │         │   Port 6901  │
└──────────────┘         └──────────────┘

                    Access via Browser
                    http://localhost:6901
```

**Flow:**
1. Container runs VNC server + Chromium
2. VNC serves GUI over WebSocket (HTTP port 6901)
3. Access via any web browser on your Mac
