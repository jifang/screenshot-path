# screenshot-path

A tiny macOS background daemon. Every time you take a screenshot, it puts the new file on the clipboard **both** as a file and as a plain-text path, so one paste works everywhere:

- paste into Finder / chat apps → the image file
- paste into a terminal / editor → the file path (handy for CLI tools and coding agents)

## Install

### Homebrew (recommended)

```sh
brew install jifang/tap/screenshot-path
brew services start screenshot-path
```

It builds from source, so you need the Xcode Command Line Tools (`xcode-select --install`).

### From source

```sh
git clone https://github.com/jifang/screenshot-path.git
cd screenshot-path
./install.sh     # build, install, register a LaunchAgent
./uninstall.sh   # remove it
```

Use one install method or the other, not both, or two copies will run.

## First run

On first start macOS asks whether `screenshot-path` may access your Desktop (or whichever folder screenshots are saved to). Click **Allow**. If you missed it: System Settings → Privacy & Security → Files & Folders.

## Tips

- macOS only writes the screenshot file after the floating thumbnail disappears (about 5 s). On first launch the app asks once whether to turn the thumbnail off. To do it manually:
  `defaults write com.apple.screencapture show-thumbnail -bool false && killall SystemUIServer`
- Custom screenshot folder (`defaults write com.apple.screencapture location ...`) is honored.
- Files are recognised by name (`Screenshot*`, `Screen Shot*`, `屏幕截图*`, `截屏*`).
- If several screenshots land at once, only the newest is copied.

## How it works

It watches the screenshot folder with a kernel file-system event (no polling, no Spotlight), so it uses no CPU while idle.

## Logs

- Homebrew: `$(brew --prefix)/var/log/screenshot-path.log`
- `install.sh`: `~/Library/Logs/screenshot-path.log`

## License

MIT
