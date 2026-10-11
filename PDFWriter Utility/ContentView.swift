//
//  ContentView.swift
//  PrintPDF Utility
//
//  Based on RWTS PDFwriter by Rodney I. Yager.
//  Portable destination-folder support added in 2026.
//

import AppKit
import Darwin
import SwiftUI

struct ContentView: View {
    @State private var destinationPath = DestinationConfiguration.savedPath ?? "Not configured"
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var offeredInitialSetup = false

    var body: some View {
        VStack(spacing: 14) {
            Image("Printer")

            Text("PrintPDF")
                .font(.title2)
                .fontWeight(.semibold)

            Text("PDF destination")
                .font(.headline)

            Text(destinationPath)
                .font(.caption)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .lineLimit(3)
                .padding(.horizontal)

            HStack {
                Button(DestinationConfiguration.savedPath == nil ? "Choose Destination…" : "Change Destination…") {
                    chooseDestination()
                }

                Button("Open Folder") {
                    openDestination()
                }
                .disabled(DestinationConfiguration.savedPath == nil)
            }

            Button("Reveal Uninstall Script") {
                NSWorkspace.shared.open(
                    URL(fileURLWithPath: "/Library/Printers/PrintPDF/", isDirectory: true)
                )
            }
        }
        .padding(24)
        .frame(width: 460, height: 340)
        .alert("PrintPDF", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            DestinationConfiguration.ensureMoverAgent()
            guard DestinationConfiguration.savedPath == nil, !offeredInitialSetup else { return }
            offeredInitialSetup = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                chooseDestination()
            }
        }
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.title = "Choose where PrintPDF should save PDFs"
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try DestinationConfiguration.save(path: url.path)
            try DestinationConfiguration.installMoverAgent()
            DestinationConfiguration.runMoverNow()
            destinationPath = url.path
        } catch {
            alertMessage = "The destination could not be saved: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func openDestination() {
        guard let path = DestinationConfiguration.savedPath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path, isDirectory: true))
    }
}

private enum DestinationConfiguration {
    static let label = "com.printpdf.mover"
    static let moverPath = "/Library/Printers/PrintPDF/pdfwriter-mover.sh"

    static var supportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/PrintPDF", isDirectory: true)
    }

    static var configurationFile: URL {
        supportDirectory.appendingPathComponent("destination.txt")
    }

    static var launchAgentFile: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var spoolDirectoryPath: String {
        "/private/var/spool/printpdf/\(NSUserName())"
    }

    static var savedPath: String? {
        guard let value = try? String(contentsOf: configurationFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }

    static func save(path: String) throws {
        try FileManager.default.createDirectory(
            at: supportDirectory,
            withIntermediateDirectories: true
        )
        try (path + "\n").write(to: configurationFile, atomically: true, encoding: .utf8)
    }

    static func installMoverAgent() throws {
        try FileManager.default.createDirectory(
            at: launchAgentFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(moverPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>WatchPaths</key>
            <array>
                <string>\(spoolDirectoryPath)</string>
            </array>
            <key>StartInterval</key>
            <integer>60</integer>
            <key>ProcessType</key>
            <string>Background</string>
        </dict>
        </plist>
        """

        try plist.write(to: launchAgentFile, atomically: true, encoding: .utf8)

        // Loading the agent is what makes delivery work at all. Verify that
        // launchd really registered it instead of trusting the exit status of
        // the bootstrap call, because a mover that is not registered can never
        // deliver a PDF or report its own failure.
        let domain = "gui/\(getuid())"
        var lastStatus: Int32 = -1

        for attempt in 0..<2 {
            if attempt > 0 {
                // launchd can refuse the first attempt while the login session
                // is still starting up, so retry once before giving up.
                Thread.sleep(forTimeInterval: 1)
            }
            _ = launchctl(["bootout", domain, launchAgentFile.path])
            lastStatus = launchctl(["bootstrap", domain, launchAgentFile.path])
            if moverAgentIsLoaded(domain: domain) {
                return
            }
        }

        throw NSError(
            domain: "PrintPDF",
            code: Int(lastStatus),
            userInfo: [NSLocalizedDescriptionKey:
                "The background mover could not be started (launchctl status \(lastStatus)), so PDFs will not be delivered. Try choosing the folder again, or reinstall PrintPDF."]
        )
    }

    static func moverAgentIsLoaded(domain: String) -> Bool {
        launchctl(["print", "\(domain)/\(label)"]) == 0
    }

    /// Repairs a mover agent that is not running. The Utility calls this while
    /// opening, so a mover that was unloaded is restored on the spot.
    static func ensureMoverAgent() {
        guard savedPath != nil,
              FileManager.default.fileExists(atPath: moverPath) else { return }

        let domain = "gui/\(getuid())"
        if moverAgentIsLoaded(domain: domain) {
            runMoverNow()
            return
        }

        if FileManager.default.fileExists(atPath: launchAgentFile.path) {
            _ = launchctl(["bootstrap", domain, launchAgentFile.path])
        } else {
            try? installMoverAgent()
        }

        if moverAgentIsLoaded(domain: domain) {
            runMoverNow()
        }
    }

    static func runMoverNow() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: moverPath)
        try? process.run()
    }

    @discardableResult
    private static func launchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
