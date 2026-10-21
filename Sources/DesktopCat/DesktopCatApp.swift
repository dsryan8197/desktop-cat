import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pet: PetController?
    private var menuBar: MenuBarController?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // Menu-bar app: no Dock icon.
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        quitOtherCopies()

        let manifest: Manifest
        do {
            manifest = try Manifest.loadBundled()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Desktop Cat can't find its action list"
            alert.informativeText = "cats-and-actions.json is missing from the app bundle (\(error.localizedDescription))."
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        let pet = PetController(settings: Settings(), manifest: manifest)
        pet.start()
        self.pet = pet
        menuBar = MenuBarController(pet: pet)

        // Testing aid: `open DesktopCat.app --args -demo feed|water|yarn` runs a care action
        // a moment after launch. Launch arguments aren't saved, so normal launches ignore it.
        // Extras can be chained: `-demo jump,hang` (turn the extra on too, e.g. `-jumpOnWindows YES`).
        if let demo = UserDefaults.standard.string(forKey: "demo") {
            var queue = demo.split(separator: ",").map(String.init)
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                guard let next = queue.first else { timer.invalidate(); return }
                switch next {
                case "feed": pet.feed()
                case "water": pet.fillWater()
                case "yarn": pet.tossYarn()
                default:
                    guard !pet.extras.isActive, pet.fallVelocity == nil else { return }
                    if !pet.extras.start(plan: next) { NSLog("DesktopCat demo: %@ not possible here", next) }
                }
                queue.removeFirst()
            }
        }
    }

    /// Only one cat at a time: a freshly built copy replaces an older running one.
    private func quitOtherCopies() {
        guard let id = Bundle.main.bundleIdentifier else { return }
        let me = ProcessInfo.processInfo.processIdentifier
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: id) where app.processIdentifier != me {
            app.terminate()
        }
    }
}
