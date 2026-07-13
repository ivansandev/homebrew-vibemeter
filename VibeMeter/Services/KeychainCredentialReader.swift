import Foundation
import Security

struct KeychainCredentialReader: Sendable {
    func claudeAccessToken() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw UsageError.credentialsMissing("Sign in to Claude Code, then refresh VibeMeter.")
        }

        struct Credential: Decodable {
            struct OAuth: Decodable { let accessToken: String }
            let claudeAiOauth: OAuth?
            let oauthAccount: OAuth?
        }

        let credential = try JSONDecoder().decode(Credential.self, from: data)
        guard let token = credential.claudeAiOauth?.accessToken ?? credential.oauthAccount?.accessToken,
              !token.isEmpty else {
            throw UsageError.credentialsMissing("Claude Code is installed but its login could not be read.")
        }
        return token
    }
}
