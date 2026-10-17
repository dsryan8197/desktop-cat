import AppKit

/// Reads where other apps' windows are (positions and stacking order only).
/// Needs no permission; if macOS ever returns nothing, the cat just stays on the floor.
enum WindowScanner {
    static func scan() -> [WindowRect] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]],
              let mainHeight = NSScreen.screens.first?.frame.height else { return [] }
        let me = Int(ProcessInfo.processInfo.processIdentifier)
        var result: [WindowRect] = []
        for info in list {
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowOwnerPID as String] as? Int) != me,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0.1,
                  let id = info[kCGWindowNumber as String] as? Int,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let cg = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  cg.width >= 120, cg.height >= 80 else { continue }
            result.append(WindowRect(id: id, frame: WindowGeometry.cocoaRect(fromCG: cg, mainScreenHeight: mainHeight)))
        }
        return result
    }
}
