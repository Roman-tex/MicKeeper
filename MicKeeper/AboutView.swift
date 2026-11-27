import SwiftUI
import MicKeeperCore

struct AboutView: View {
    let updates: UpdateChecker
    let language: LanguageController
    @State private var showingLicense = false
    private let projectURL = URL(string: "https://github.com/Roman-tex/MicKeeper")!
    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—" }
    private var build: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—" }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().scaledToFit().frame(width: 72, height: 72)
                .accessibilityHidden(true)
            VStack(spacing: 5) {
                Text("MicKeeper").font(.system(size: 23, weight: .semibold))
                Text(L10n.format("about.version", version, build)).font(.callout).foregroundStyle(.secondary)
                Text(L10n.text("about.tagline")).font(.callout).padding(.top, 3)
            }
            HStack {
                Text(L10n.text("about.language"))
                Spacer()
                Picker(L10n.text("about.language"), selection: Binding(
                    get: { language.selectedIdentifier },
                    set: { language.setSelection($0) }
                )) {
                    Text(L10n.text("language.system")).tag(LanguageController.systemIdentifier)
                    ForEach(AppLanguage.allCases, id: \.rawValue) { language in
                        Text(language.nativeName).tag(language.rawValue)
                    }
                }
                .labelsHidden().pickerStyle(.menu)
            }
            Toggle(L10n.text("about.automaticUpdates"), isOn: Binding(
                get: { updates.automatic.isEnabled },
                set: { updates.setAutomaticEnabled($0) }
            ))
            .toggleStyle(.checkbox)
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(L10n.text("about.automaticUpdates.help"))
            HStack(spacing: 16) {
                Link("GitHub", destination: projectURL)
                Link(L10n.text("about.developer"), destination: URL(string: "https://github.com/Roman-tex")!)
                Button(L10n.text("about.license")) { showingLicense = true }.buttonStyle(.link)
            }
            .font(.callout)
            Divider()
            VStack(spacing: 10) {
                Button {
                    Task { await updates.check() }
                } label: {
                    HStack(spacing: 8) {
                        if isChecking { ProgressView().controlSize(.small) }
                        Text(L10n.text(isChecking ? "about.checking" : "about.checkUpdates"))
                    }
                }.disabled(isChecking)
                updateStatus
            }
        }
        .id(language.selectedIdentifier)
        .padding(24)
        .frame(width: 370)
        .fixedSize(horizontal: false, vertical: true)
        .sheet(isPresented: $showingLicense) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("about.licenses")).font(.headline)
                ScrollView {
                    Text(licenseText).font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack { Spacer(); Button(L10n.text("about.done")) { showingLicense = false }.keyboardShortcut(.defaultAction) }
            }.padding(20).frame(width: 520, height: 440)
        }
    }
    private var isChecking: Bool { updates.isChecking }
    @ViewBuilder private var updateStatus: some View {
        switch updates.state {
        case .idle, .checking: EmptyView()
        case .current: Text(L10n.text("about.current")).font(.caption).foregroundStyle(.secondary)
        case .noRelease: Text(L10n.text("about.noRelease")).font(.caption).foregroundStyle(.secondary)
        case .available(let url): Link(L10n.text("about.available"), destination: url).font(.callout)
        case .failure(let message): Text(message).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    private var licenseText: String {
        guard let url = Bundle.main.url(forResource: "LICENSE", withExtension: "txt") else { return "" }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
}
