import Foundation
import Observation
import ServiceManagement

@MainActor @Observable final class LoginItemController {
    private(set) var isEnabled = false
    private(set) var requiresApproval = false
    private(set) var errorMessage: String?
    private(set) var isBusy = false

    init() { refresh() }
    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        requiresApproval = status == .requiresApproval
        errorMessage = nil
        if status == .notFound {
            errorMessage = L10n.text("login.error.notFound")
        }
    }
    func setEnabled(_ value: Bool) async {
        guard !isBusy else { return }
        isBusy = true; errorMessage = nil
        var failureMessage: String?
        do {
            if value { try SMAppService.mainApp.register() }
            else { try await SMAppService.mainApp.unregister() }
        } catch {
            failureMessage = L10n.format("login.error.update", error.localizedDescription)
        }
        isBusy = false
        refresh()
        errorMessage = failureMessage ?? errorMessage
    }
    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
