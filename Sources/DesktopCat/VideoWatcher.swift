import AppKit
import IOKit.pwr_mgt

/// Notices when a video is playing, without any permission: apps that play video ask macOS
/// to keep the display awake (a power assertion anyone can read), and window positions are public.
enum VideoWatcher {
    /// Keep-awake utilities hold the same kind of assertion without playing anything.
    private static let notVideo = ["caffeinate", "amphetamine", "keepingyouawake", "lungo", "theine", "caffeine", "owly"]

    /// Processes currently keeping the display awake, as video players do.
    static func displayAwakePIDs() -> Set<Int> {
        var unmanaged: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&unmanaged) == kIOReturnSuccess,
              let byPID = unmanaged?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else { return [] }
        let me = Int(ProcessInfo.processInfo.processIdentifier)
        var pids = Set<Int>()
        for (pid, assertions) in byPID where pid.intValue != me {
            let keepsDisplayOn = assertions.contains {
                let type = $0[kIOPMAssertionTypeKey as String] as? String
                return type == (kIOPMAssertionTypePreventUserIdleDisplaySleep as String) || type == "NoDisplaySleepAssertion"
            }
            guard keepsDisplayOn else { continue }
            let name = (NSRunningApplication(processIdentifier: pid_t(pid.intValue))?.localizedName ?? "").lowercased()
            let names = assertions.compactMap { ($0[kIOPMAssertionNameKey as String] as? String)?.lowercased() }
            if notVideo.contains(where: { tool in name.contains(tool) || names.contains { $0.contains(tool) } }) { continue }
            pids.insert(pid.intValue)
        }
        return pids
    }

    /// The front-most decent-sized window of an app that's keeping the display awake.
    /// Browsers do this from a helper process, so the app owning the helper counts too.
    static func videoWindow(in windows: [WindowRect]) -> WindowRect? {
        let pids = displayAwakePIDs()
        guard !pids.isEmpty else { return nil }
        let owners = Set(pids.map(appPID))
        return windows.first { (owners.contains($0.pid) || pids.contains($0.pid)) && $0.frame.width >= 320 && $0.frame.height >= 180 }
    }

    /// A helper process (e.g. "Google Chrome Helper") belongs to the app it's bundled inside.
    private static func appPID(_ pid: Int) -> Int {
        guard let url = NSRunningApplication(processIdentifier: pid_t(pid))?.bundleURL?.path else { return pid }
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            if let p = app.bundleURL?.path, url.hasPrefix(p + "/") { return Int(app.processIdentifier) }
        }
        return pid
    }
}
