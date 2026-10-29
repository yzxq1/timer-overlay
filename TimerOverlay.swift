// TimerOverlay：监听 macOS「时钟」App 的计时器，运行时在屏幕上显示悬浮倒计时窗。
// 数据源：~/Library/Group Containers/group.com.apple.mobiletimerd/local.sqlite（只读）
import AppKit
import SQLite3

let dbPath = NSHomeDirectory() + "/Library/Group Containers/group.com.apple.mobiletimerd/local.sqlite"
let refEpoch: TimeInterval = 978_307_200 // CoreData 时间戳基准 2001-01-01

struct TimerInfo {
    var state: Int          // 1 停止 / 2 暂停 / 3 运行
    var title: String
    var duration: Double
    var fireDate: Date?     // 运行中：响铃时刻
    var remaining: Double?  // 暂停中：剩余秒数
}

// 解析 ZFIRETIME（NSKeyedArchiver）：含 NS.time 的是绝对时刻，MTTimerTimeInterval 是剩余秒数
func parseFireTime(_ data: Data) -> (Date?, Double?) {
    guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
          let objects = plist["$objects"] as? [Any] else { return (nil, nil) }
    var date: Date?, interval: Double?
    for case let obj as [String: Any] in objects {
        if let t = obj["NS.time"] as? Double { date = Date(timeIntervalSinceReferenceDate: t) }
        if let i = obj["MTTimerTimeInterval"] as? Double { interval = i }
    }
    return (date, interval)
}

func readTimers() -> [TimerInfo] {
    var db: OpaquePointer?
    guard sqlite3_open_v2("file:\(dbPath)?mode=ro", &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else { return [] }
    defer { sqlite3_close(db) }
    let sql = "SELECT ZSTATE, IFNULL(ZTITLE,''), ZDURATION, ZFIRETIME, ZLASTMODIFIEDDATE FROM ZMTCDTIMER WHERE ZSTATE IN (2,3)"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
    defer { sqlite3_finalize(stmt) }
    var result: [TimerInfo] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
        let state = Int(sqlite3_column_int(stmt, 0))
        let title = String(cString: sqlite3_column_text(stmt, 1))
        let duration = sqlite3_column_double(stmt, 2)
        let modified = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4) + refEpoch)
        var info = TimerInfo(state: state, title: title, duration: duration)
        if let blob = sqlite3_column_blob(stmt, 3) {
            let (date, interval) = parseFireTime(Data(bytes: blob, count: Int(sqlite3_column_bytes(stmt, 3))))
            if state == 3 {
                // 运行中优先用绝对时刻；只有间隔时按「最后修改时间 + 剩余」推算
                info.fireDate = date ?? interval.map { modified.addingTimeInterval($0) }
            } else {
                info.remaining = interval ?? date.map { $0.timeIntervalSince(modified) }
            }
        }
        result.append(info)
    }
    return result
}

func format(_ s: Double) -> String {
    let t = max(0, Int(s.rounded(.up)))
    return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60)
                     : String(format: "%02d:%02d", t / 60, t % 60)
}

final class Overlay: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    var label: NSTextField!
    var sub: NSTextField!
    var timers: [TimerInfo] = []

    func applicationDidFinishLaunching(_ n: Notification) {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 220, height: 84),
                        styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        let blur = NSVisualEffectView(frame: panel.contentView!.bounds)
        blur.material = .hudWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 16
        blur.autoresizingMask = [.width, .height]
        panel.contentView = blur

        label = NSTextField(labelWithString: "00:00")
        label.font = .monospacedDigitSystemFont(ofSize: 40, weight: .semibold)
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 26, width: 220, height: 50)
        sub = NSTextField(labelWithString: "")
        sub.font = .systemFont(ofSize: 12)
        sub.textColor = .secondaryLabelColor
        sub.alignment = .center
        sub.frame = NSRect(x: 0, y: 8, width: 220, height: 18)
        blur.addSubview(label)
        blur.addSubview(sub)

        // 默认放在主屏右上角，可拖动
        if let f = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: f.maxX - 240, y: f.maxY - 104))
        }

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.poll() }
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.render() }
        poll()
    }

    func poll() { timers = readTimers() }

    func render() {
        // 多个计时器时显示最快结束的那个
        let running = timers.filter { $0.state == 3 && $0.fireDate != nil }
            .sorted { $0.fireDate! < $1.fireDate! }
        let paused = timers.filter { $0.state == 2 }
        if let t = running.first {
            let left = t.fireDate!.timeIntervalSinceNow
            label.stringValue = format(left)
            label.textColor = left <= 10 ? .systemRed : .labelColor
            sub.stringValue = (t.title.isEmpty ? "计时器" : t.title) + (running.count > 1 ? "  +\(running.count - 1)" : "")
            panel.orderFrontRegardless()
        } else if let t = paused.first, let r = t.remaining {
            label.stringValue = format(r)
            label.textColor = .secondaryLabelColor
            sub.stringValue = "已暂停"
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // 不占 Dock
let delegate = Overlay()
app.delegate = delegate
app.run()
