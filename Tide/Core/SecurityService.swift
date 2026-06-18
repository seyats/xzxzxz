import Foundation
import LocalAuthentication
import Observation
import Security

enum SecureStoreError: LocalizedError {
    case unhandled(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandled(let status): "Keychain error \(status)"
        }
    }
}

enum SecureStore {
    static func set(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.tide.app",
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(insert as CFDictionary, nil)
        guard status == errSecSuccess else { throw SecureStoreError.unhandled(status) }
    }

    static func value(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.tide.app",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

@MainActor
@Observable
final class AdminAccessStore {
    private(set) var isUnlocked = false
    private(set) var failedAttempts = 0
    private(set) var lockedUntil: Date?
    private(set) var errorMessage: String?
    var hasPIN: Bool { SecureStore.value(account: "admin-pin") != nil }

    func setPIN(_ pin: String) -> Bool {
        guard pin.count == 4, pin.allSatisfy(\.isNumber) else {
            errorMessage = "PIN must contain four digits"
            return false
        }
        do {
            try SecureStore.set(pin, account: "admin-pin")
            isUnlocked = true
            failedAttempts = 0
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func verify(pin: String) -> Bool {
        if let lockedUntil, lockedUntil > .now {
            errorMessage = "Try again after \(lockedUntil.formatted(date: .omitted, time: .shortened))"
            return false
        }
        guard SecureStore.value(account: "admin-pin") == pin else {
            failedAttempts += 1
            if failedAttempts >= 5 {
                lockedUntil = .now.addingTimeInterval(300)
                failedAttempts = 0
            }
            errorMessage = "Incorrect PIN"
            return false
        }
        isUnlocked = true
        failedAttempts = 0
        lockedUntil = nil
        errorMessage = nil
        return true
    }

    func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            errorMessage = error?.localizedDescription ?? "Biometrics are unavailable"
            return false
        }
        do {
            let result = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Open Tide administration")
            isUnlocked = result
            return result
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func lock() {
        isUnlocked = false
    }
}
