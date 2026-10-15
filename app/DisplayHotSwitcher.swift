import AppKit

struct Layout {
    let command: String
    let title: String
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let appName = "Display Hot Switcher"
    /// Apple Silicon Homebrew first, then Intel Homebrew. Matches setdisplay.sh.
    private let displayplacerCandidates = [
        "/opt/homebrew/bin/displayplacer",
        "/usr/local/bin/displayplacer",
    ]
    private var displayplacer: String? {
        displayplacerCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    private let layouts = [
        Layout(command: "switch-to-27", title: "Mirror — Optimize for 27-inch"),
        Layout(command: "switch-to-22", title: "Mirror — Optimize for 22-inch"),
        Layout(command: "mirror-to-22", title: "Mirror 22-inch onto 27-inch"),
        Layout(command: "extend-to-27", title: "Extend — 27-inch Primary"),
    ]

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var layoutItems: [String: NSMenuItem] = [:]
    private var statusLine: NSMenuItem!
    private var scriptPath: String?
    private var monitor27 = ""
    private var monitor22 = ""
    private var isBusy = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        scriptPath = Bundle.main.path(forResource: "setdisplay", ofType: "sh")
        loadMonitorIDs()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "display.2", accessibilityDescription: appName)
            button.toolTip = appName
        }

        menu.autoenablesItems = false
        menu.delegate = self
        buildMenu()
        statusItem.menu = menu
        refreshActiveLayout()
    }

    // MARK: - Menu

    private func buildMenu() {
        for layout in layouts {
            let item = NSMenuItem(title: layout.title, action: #selector(applyLayout(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = layout.command
            item.toolTip = "setdisplay.sh \(layout.command) --yes"
            menu.addItem(item)
            layoutItems[layout.command] = item
        }
        menu.addItem(.separator())

        statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)

        let quit = NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        updateEnabledState()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshActiveLayout()
    }

    private func updateEnabledState() {
        let problem = preflightProblem()
        for item in layoutItems.values {
            item.isEnabled = problem == nil && !isBusy
        }
        if let problem {
            statusLine.title = problem
            statusLine.isHidden = false
        } else if isBusy {
            statusLine.title = "Applying…"
            statusLine.isHidden = false
        } else {
            statusLine.isHidden = true
        }
    }

    private func preflightProblem() -> String? {
        if scriptPath == nil {
            return "setdisplay.sh is missing from the app bundle"
        }
        if displayplacer == nil {
            return "displayplacer not found — brew install displayplacer"
        }
        return nil
    }

    // MARK: - Active layout detection

    /// Reads the current arrangement from `displayplacer list` and check-marks
    /// whichever layout(s) produce it.
    private func refreshActiveLayout() {
        guard preflightProblem() == nil, let displayplacer else {
            updateEnabledState()
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let result = run(displayplacer, ["list"])
            let active = activeCommands(fromListOutput: result.output)
            DispatchQueue.main.async {
                for (command, item) in self.layoutItems {
                    item.state = active.contains(command) ? .on : .off
                }
            }
        }
    }

    private func activeCommands(fromListOutput output: String) -> Set<String> {
        guard !monitor27.isEmpty, !monitor22.isEmpty,
              let arrangement = output.split(separator: "\n").last(where: { $0.hasPrefix("displayplacer ") })
        else { return [] }

        if arrangement.contains("id:\(monitor22)+\(monitor27) ") {
            return ["switch-to-22", "mirror-to-22"]
        }
        if arrangement.contains("id:\(monitor27)+\(monitor22) ") {
            return ["switch-to-27"]
        }
        if arrangement.contains("id:\(monitor27) res:2560x1440"),
           arrangement.contains("origin:(0,0)"),
           arrangement.contains("id:\(monitor22) res:1920x1080") {
            return ["extend-to-27"]
        }
        return []
    }

    // MARK: - Applying a layout

    @objc private func applyLayout(_ sender: NSMenuItem) {
        guard let command = sender.representedObject as? String, let script = scriptPath, !isBusy else { return }
        isBusy = true
        updateEnabledState()

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let result = run("/bin/bash", [script, command, "--yes"])
            DispatchQueue.main.async {
                self.isBusy = false
                self.updateEnabledState()
                self.refreshActiveLayout()
                if result.status != 0 {
                    self.showError(command: command, output: result.output)
                }
            }
        }
    }

    private func showError(command: String, output: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could not apply \(command)"
        alert.informativeText = output.trimmingCharacters(in: .whitespacesAndNewlines)
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: - Helpers

    /// The monitor IDs live in setdisplay.sh; read them from there so the app
    /// never drifts from the script it wraps.
    private func loadMonitorIDs() {
        guard let path = scriptPath, let text = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        monitor27 = shellValue(of: "MONITOR_27", in: text)
        monitor22 = shellValue(of: "MONITOR_22", in: text)
    }

    private func shellValue(of variable: String, in text: String) -> String {
        let prefix = "\(variable)="
        guard let line = text.split(separator: "\n").first(where: { $0.hasPrefix(prefix) }) else { return "" }
        return line.dropFirst(prefix.count).trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
    }

    private func run(_ executable: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return (-1, error.localizedDescription)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
