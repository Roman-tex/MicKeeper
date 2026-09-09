import SwiftUI
import MicKeeperCore

struct KeeperPanel: View {
    let model: AppModel
    let showAbout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("MicKeeper").font(.system(size: 14, weight: .semibold))
                Spacer()
                Toggle(L10n.text("panel.holding.toggle"), isOn: Binding(
                    get: { model.keeper.isEnabled }, set: { model.keeper.setEnabled($0) }
                ))
                .labelsHidden().toggleStyle(.switch).controlSize(.small)
                .accessibilityLabel(L10n.text("panel.holding.toggle"))
                .help(L10n.text("panel.holding.help"))
            }
            HStack(spacing: 8) {
                Text(L10n.text(model.keeper.isEnabled ? "panel.selected" : "panel.selected.disabled")).foregroundStyle(.secondary)
                Picker(L10n.text("panel.microphone"), selection: Binding(
                    get: { model.keeper.selectedUID ?? "" },
                    set: { uid in
                        if let device = model.keeper.devices.first(where: { $0.id == uid }) {
                            model.keeper.select(device)
                        }
                    }
                )) {
                    if !model.keeper.devices.contains(where: { $0.id == model.keeper.selectedUID }) {
                        Text(model.keeper.selectedName ?? L10n.text("panel.none"))
                            .tag(model.keeper.selectedUID ?? "")
                    }
                    ForEach(Array(model.keeper.devices.enumerated()), id: \.element.id) { index, device in
                        Text(deviceLabel(device, index: index)).tag(device.id)
                    }
                }
                .labelsHidden().pickerStyle(.menu)
                .help(model.keeper.selectedName ?? L10n.text("error.chooseDevice"))
                .accessibilityLabel(L10n.text("panel.microphone"))
            }
            .disabled(!model.keeper.isEnabled)
            .foregroundStyle(model.keeper.isEnabled ? .primary : .secondary)
            .opacity(model.keeper.isEnabled ? 1 : 0.55)

            if let message = model.issueMessage {
                VStack(alignment: .leading, spacing: 6) {
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L10n.text("panel.retry")) { model.retry() }.font(.caption)
                }
            }
            Divider()
            Toggle(L10n.text("panel.login"), isOn: Binding(
                get: { model.login.isEnabled },
                set: { value in Task { await model.login.setEnabled(value) } }
            ))
            .toggleStyle(.checkbox)
            .disabled(model.login.isBusy)
            if model.login.requiresApproval {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("panel.login.approval"))
                        .font(.caption).foregroundStyle(.secondary)
                    Button(L10n.text("panel.login.openSettings")) { model.login.openSettings() }.font(.caption)
                    Button(L10n.text("panel.login.cancel")) { Task { await model.login.setEnabled(false) } }
                        .font(.caption).disabled(model.login.isBusy)
                }
            }
            if let message = model.login.errorMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(L10n.text("panel.about"), action: showAbout).buttonStyle(.plain)
            Divider()
            Button(L10n.text("panel.quit")) { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain).keyboardShortcut("q")
        }
        .font(.system(size: 12))
        .padding(16)
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .id(model.language.selectedIdentifier)
    }
    private func deviceLabel(_ device: AudioDevice, index: Int) -> String {
        let duplicates = model.keeper.devices.filter { $0.name == device.name }.count > 1
        return duplicates ? "\(device.name) · \(index + 1)" : device.name
    }
}
