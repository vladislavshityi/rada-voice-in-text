import Foundation

// `Rada --export-iconset <dir>` renders the app icon during packaging.
if let index = CommandLine.arguments.firstIndex(of: "--export-iconset"), index + 1 < CommandLine.arguments.count {
    MainActor.assumeIsolated {
        IconExporter.exportIconset(to: URL(filePath: CommandLine.arguments[index + 1]))
    }
    exit(0)
}

RadaApp.main()
