#!/bin/bash
# 停止并移除 LaunchAgent 和已安装的二进制（保留日志）
set -uo pipefail
LABEL=com.jifang.screenshot-path
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Library/Application Support/screenshot-path"
echo "uninstalled"
