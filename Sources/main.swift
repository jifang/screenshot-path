// screenshot-path: 监听系统截屏，把新截图的路径写入剪贴板。
import Cocoa

func log(_ msg: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    FileHandle.standardError.write("\(ts) \(msg)\n".data(using: .utf8)!)
}

func copyToPasteboard(_ path: String) {
    let pb = NSPasteboard.general
    pb.clearContents()
    // 文件 URL：粘到 Finder / 聊天软件得到文件；纯文本：粘到终端 / 编辑器得到路径
    pb.writeObjects([URL(fileURLWithPath: path) as NSURL])
    pb.setString(path, forType: .string)
    log("copied \(path)")
}

// 主动读一次截图目录：触发 TCC 授权弹窗（默认在桌面），否则 Spotlight 会静默过滤掉该目录的结果
let shotDir = ((UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
    ?? "~/Desktop") as NSString).expandingTildeInPath
do {
    _ = try FileManager.default.contentsOfDirectory(atPath: shotDir)
    log("access ok: \(shotDir)")
} catch {
    log("no access to \(shotDir): \(error.localizedDescription) — grant it in System Settings > Privacy & Security > Files and Folders")
}

// 不依赖 Spotlight（索引可能静默失效）：监听截图目录的文件系统事件，按文件名识别新截图
let nameRe = try! NSRegularExpression(pattern: "^(Screenshot|Screen Shot|屏幕截图|截屏).*\\.(png|jpg|jpeg|heic|tiff|pdf)$", options: [.caseInsensitive])

func listShots() -> [String: Date] {
    let fm = FileManager.default
    guard let names = try? fm.contentsOfDirectory(atPath: shotDir) else { return [:] }
    var out: [String: Date] = [:]
    for n in names where !n.hasPrefix(".") {
        guard nameRe.firstMatch(in: n, range: NSRange(n.startIndex..., in: n)) != nil else { continue }
        let path = (shotDir as NSString).appendingPathComponent(n)
        if let d = (try? fm.attributesOfItem(atPath: path))?[.creationDate] as? Date { out[path] = d }
    }
    return out
}

var seen = Set(listShots().keys)
log("started, \(seen.count) existing screenshots in \(shotDir)")

func scan() {
    let fresh = listShots().filter { !seen.contains($0.key) }
    guard !fresh.isEmpty else { return }
    seen.formUnion(fresh.keys)
    // 只取最新的一张，避免连续截图时剪贴板来回跳
    if let latest = fresh.max(by: { $0.value < $1.value })?.key { copyToPasteboard(latest) }
}

// 内核级目录事件（kqueue），空闲时零开销；截图落盘时目录内容变化即触发
let fd = open(shotDir, O_EVTONLY)
guard fd >= 0 else { log("cannot open \(shotDir) for watching"); exit(1) }
let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
src.setEventHandler { scan() }
src.resume()

// 首次运行时询问一次是否关闭截图缩略图（缩略图存在时，系统约 5 秒后才把文件写入磁盘）
func askAboutThumbnailOnce() {
    let own = UserDefaults(suiteName: "com.jifang.screenshot-path")!
    let key = "askedAboutThumbnail"
    if own.bool(forKey: key) { return }
    // 已经关闭了缩略图，无需再问
    if let on = CFPreferencesCopyAppValue("show-thumbnail" as CFString, "com.apple.screencapture" as CFString) as? Bool, on == false {
        return
    }
    own.set(true, forKey: key)  // 无论选择什么，都只问这一次

    NSApplication.shared.setActivationPolicy(.accessory)
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = "Disable the screenshot thumbnail?"
    alert.informativeText = "macOS only saves a screenshot to disk after its floating thumbnail disappears (about 5 seconds), so the path can't be copied until then. Turning the thumbnail off makes screenshots save instantly.\n\nYou can undo this in Cmd+Shift+5 → Options → Show Floating Thumbnail."
    alert.addButton(withTitle: "Disable Thumbnail")
    alert.addButton(withTitle: "Keep It")
    guard alert.runModal() == .alertFirstButtonReturn else { log("thumbnail: user kept it"); return }

    CFPreferencesSetAppValue("show-thumbnail" as CFString, kCFBooleanFalse, "com.apple.screencapture" as CFString)
    CFPreferencesAppSynchronize("com.apple.screencapture" as CFString)
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
    p.arguments = ["SystemUIServer"]
    try? p.run()
    log("thumbnail: disabled")
}
DispatchQueue.main.async { askAboutThumbnailOnce() }

RunLoop.main.run()
