import AppKit

/// Which desktop (Space) is showing, as a position in the row Mission Control shows, so we
/// know which way you swiped. macOS has no public call for this; the one used here is the
/// same long-standing one desktop utilities rely on, looked up at run time. If it's ever
/// missing, `index()` returns nil and the cat just runs in from the nearer side.
enum SpaceTracker {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias CopySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private static let handle = dlopen(nil, RTLD_NOW)
    private static let mainConnection: MainConnection? = dlsym(handle, "CGSMainConnectionID").map { unsafeBitCast($0, to: MainConnection.self) }
    private static let copySpaces: CopySpaces? = dlsym(handle, "CGSCopyManagedDisplaySpaces").map { unsafeBitCast($0, to: CopySpaces.self) }

    /// Position of the current desktop on the display that has the cat (0 = leftmost).
    static func index(onDisplay screen: NSScreen) -> Int? {
        guard let cid = mainConnection?(), let list = copySpaces?(cid)?.takeRetainedValue() as? [[String: Any]] else { return nil }
        let uuid = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
            .flatMap { CGDisplayCreateUUIDFromDisplayID($0.uint32Value)?.takeRetainedValue() }
            .map { CFUUIDCreateString(nil, $0) as String }
        // With "Displays have separate Spaces" off there's a single entry for all displays.
        let display = list.first { ($0["Display Identifier"] as? String) == uuid } ?? list.first
        guard let spaces = display?["Spaces"] as? [[String: Any]],
              let current = (display?["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int else { return nil }
        return spaces.firstIndex { ($0["ManagedSpaceID"] as? Int) == current }
    }
}
