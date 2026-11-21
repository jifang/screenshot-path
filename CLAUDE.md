# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`screenshot-path`: a tiny macOS background daemon (single file, `Sources/main.swift`, Cocoa only, no Package.swift/Xcode project). It watches for new system screenshots and puts them on the clipboard as both a file URL and a plain-text path, so one paste works in Finder/chat apps (file) and terminals/editors (path). Comments and scripts are in Chinese. Public repo `jifang/screenshot-path`; the Homebrew formula lives in a separate repo, `jifang/homebrew-tap` (needs a new `url`/`sha256` per release tag).

## Commands

- Build + ad-hoc sign: `./build.sh` → `build/screenshot-path` (plain `swiftc -O`; no tests or linter exist)
- Install and (re)start as LaunchAgent: `./install.sh` (builds, copies binary to `~/Library/Application Support/screenshot-path/`, writes `~/Library/LaunchAgents/com.jifang.screenshot-path.plist`, bootstraps it)
- Uninstall: `./uninstall.sh` (keeps the log)
- Log: `~/Library/Logs/screenshot-path.log` (stderr is the only logging channel)
- Run in foreground for debugging: `./build.sh && build/screenshot-path`. Stop the LaunchAgent first (`launchctl bootout gui/$(id -u)/com.jifang.screenshot-path`) to avoid two instances.

## Architecture / gotchas

- Detection watches the screenshot directory with a `DispatchSource` file-system (kqueue, `O_EVTONLY`) event, then rescans and matches filenames (`Screenshot*`, `Screen Shot*`, `屏幕截图*`, `截屏*`). It deliberately does NOT use Spotlight/`NSMetadataQuery`: Spotlight silently stopped indexing new Desktop files, so the old version went deaf with the process still running.
- Startup records existing screenshots in `seen` and ignores them; later new files not in `seen` are handled. If several arrive at once, only the newest is copied.
- The screenshot dir comes from `com.apple.screencapture` `location` (default `~/Desktop`). The startup directory listing also triggers the TCC Files and Folders prompt; without that grant the directory can't be read.
- On first launch `askAboutThumbnailOnce()` shows an `NSAlert` offering to disable the thumbnail (writes `show-thumbnail=false` via CFPreferences, then `killall SystemUIServer`). It asks once only (flag `askedAboutThumbnail` in the `com.jifang.screenshot-path` defaults suite, set regardless of the answer) and is skipped if the thumbnail is already off. To re-test: `defaults delete com.jifang.screenshot-path askedAboutThumbnail` and re-enable the thumbnail.
- macOS writes the file only after the floating thumbnail disappears (~5 s). `defaults write com.apple.screencapture show-thumbnail -bool false` removes that delay (already applied on the user's machine).
- The `--identifier com.jifang.screenshot-path` in `build.sh` codesign is intentional so TCC grants persist across rebuilds. Keep it identical to the LaunchAgent label. The installed copy under Application Support is what the LaunchAgent runs, not `build/`.
