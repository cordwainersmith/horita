import SwiftUI

struct AboutTab: View {
    private static let repositoryURL = URL(string: "https://github.com/cordwainersmith/horita")!
    private static let licenseURL = URL(string: "https://github.com/cordwainersmith/horita/blob/main/LICENSE")!
    private static let websiteURL = URL(string: "https://horita.app")!
    private static let authorURL = URL(string: "https://liranbaba.dev")!

    let checkForUpdates: () -> Void

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image("Logo")
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
            Text("horita").font(.title2.bold())
            Text("Version \(version) (\(build))").foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text("Made by").foregroundStyle(.secondary)
                Link("Liran Baba", destination: Self.authorURL)
            }

            Button("Check for Updates\u{2026}", action: checkForUpdates)

            HStack(spacing: 16) {
                Link("horita.app", destination: Self.websiteURL)
                Link("GitHub", destination: Self.repositoryURL)
                Link("License (MIT)", destination: Self.licenseURL)
                if let acknowledgementsURL = Bundle.main.url(forResource: "Acknowledgements", withExtension: "txt") {
                    Button("Acknowledgements") { NSWorkspace.shared.open(acknowledgementsURL) }
                        .buttonStyle(.link)
                }
            }
            .padding(.top, 4)

            Text("Your calendar data never leaves your Mac. horita has no analytics or telemetry. The only network traffic is the update check.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
