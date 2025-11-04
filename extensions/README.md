# Chrome Extensions

Place unpacked Chrome extensions in this directory to automatically load them when Chrome starts.

## Usage

### Adding an Extension

1. **Place your unpacked extension here:**
   ```bash
   extensions/
   ├── my-extension/
   │   ├── manifest.json
   │   ├── popup.html
   │   └── ... (other extension files)
   └── another-extension/
       ├── manifest.json
       └── ...
   ```

2. **Run Chrome:**
   ```bash
   ./run.sh --vnc
   ```
   
   All extensions in this directory will be automatically loaded!

### Extension Requirements

Each extension directory must contain a valid `manifest.json` file:

```json
{
  "manifest_version": 3,
  "name": "My Extension",
  "version": "1.0",
  "description": "Extension description"
}
```

### Managing Extensions

**List loaded extensions:**
- Open Chrome and go to `chrome://extensions/`

**Reload an extension after changes:**
- No need to rebuild Docker image
- Just restart the container: `Ctrl+C` and `./run.sh --vnc` again

**Remove an extension:**
```bash
rm -rf extensions/my-extension/
```

## Notes

- Developer mode is already enabled in the container
- Extensions are mounted as read-only from your host machine
- Extension IDs may change between container restarts
- Changes to extension files require container restart
