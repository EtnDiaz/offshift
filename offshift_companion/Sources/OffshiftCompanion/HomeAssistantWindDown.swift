import Foundation
import OffshiftCompanionCore
import Security

private enum HomeAssistantTokenKeychain {
    static let service = "com.offshift.companion"
    static let account = "home-assistant-wind-down-token"

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    static func save(_ token: String) -> Bool {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(token.utf8),
        ]
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

struct HomeAssistantActivationCredentials {
    let configuration: HomeAssistantWindDownConfiguration
    let token: String
}

@MainActor
final class HomeAssistantSettings: ObservableObject {
    private static let endpointDefaultsKey = "homeAssistantWindDownEndpoint"

    @Published var endpointText: String
    @Published var tokenDraft = ""
    @Published private(set) var hasStoredToken: Bool
    @Published private(set) var settingsMessage: String?
    var onSettingsChanged: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        endpointText = defaults.string(forKey: Self.endpointDefaultsKey) ?? ""
        hasStoredToken = HomeAssistantTokenKeychain.read() != nil
    }

    var isConfigured: Bool { credentials() != nil }

    func save() {
        guard let endpoint = URL(string: endpointText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            settingsMessage = "Enter a Home Assistant base URL first."
            return
        }
        do {
            _ = try HomeAssistantWindDownConfiguration(baseURL: endpoint)
            if !tokenDraft.isEmpty {
                guard HomeAssistantTokenKeychain.save(tokenDraft) else {
                    settingsMessage = "The token could not be saved in this Mac's Keychain."
                    return
                }
                tokenDraft = ""
            }
            UserDefaults.standard.set(endpoint.absoluteString, forKey: Self.endpointDefaultsKey)
            hasStoredToken = HomeAssistantTokenKeychain.read() != nil
            settingsMessage = hasStoredToken
                ? "Local Home Assistant configuration saved. The only scene Offshift can run is wind-down."
                : "Endpoint saved. Add a long-lived token in this local Settings screen before running the scene."
            onSettingsChanged?()
        } catch {
            settingsMessage = "Use an http(s) base URL without credentials, query parameters, or fragments."
        }
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: Self.endpointDefaultsKey)
        HomeAssistantTokenKeychain.delete()
        endpointText = ""
        tokenDraft = ""
        hasStoredToken = false
        settingsMessage = "Home Assistant configuration and local Keychain token were removed."
        onSettingsChanged?()
    }

    func credentials() -> HomeAssistantActivationCredentials? {
        guard let endpoint = URL(string: UserDefaults.standard.string(forKey: Self.endpointDefaultsKey) ?? ""),
              let configuration = try? HomeAssistantWindDownConfiguration(baseURL: endpoint),
              let token = HomeAssistantTokenKeychain.read(),
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return HomeAssistantActivationCredentials(configuration: configuration, token: token)
    }
}
