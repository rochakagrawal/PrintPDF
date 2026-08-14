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
            <key>StartInterval</key>
            <integer>5</integer>
            <key>ProcessType</key>
            <string>Background</string>
        </dict>
        </plist>
        """

        try plist.write(to: launchAgentFile, atomically: true, encoding: .utf8)

        let domain = "gui/\(getuid())"
        try? runLaunchctl(["bootout", domain, launchAgentFile.path], requireSuccess: false)
        try runLaunchctl(["bootstrap", domain, launchAgentFile.path], requireSuccess: true)
    }

    static func runMoverNow() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: moverPath)
        try? process.run()
    }

    private static func runLaunchctl(_ arguments: [String], requireSuccess: Bool) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        if requireSuccess && process.terminationStatus != 0 {
            throw NSError(
                domain: "PrintPDF",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "The background mover could not be started."]
            )
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
