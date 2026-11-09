import Foundation
import Security

enum SecureStore {
    static func read(_ key: String) -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "io.github.lswlc33.zeeho", kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }
    static func write(_ data: Data, key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "io.github.lswlc33.zeeho", kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
        var item = query; item[kSecValueData as String] = data
        SecItemAdd(item as CFDictionary, nil)
    }
    static func delete(_ key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "io.github.lswlc33.zeeho", kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
    }
}
