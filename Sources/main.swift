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
RunLoop.main.run()
