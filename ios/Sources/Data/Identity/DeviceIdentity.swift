import Foundation
import CryptoKit
import Security
import LocalAuthentication

/// Device-bound identity built on the Secure Enclave.
///
/// - The private key never leaves the Secure Enclave — it can't be read,
///   exported, or backed up. All signing happens on-chip.
/// - The public key *is* the user's stable identifier ("device pubkey").
///   Derive a short fingerprint with `DeviceIdentity.fingerprint`.
/// - A key-hash tag is persisted in the keychain so we can reload the same
///   key on next launch.
///
/// If a device doesn't support the Secure Enclave (simulator on Intel,
/// some older iPads), we fall back to a software P256 key stored in the
/// keychain. That fallback is flagged on `DeviceIdentity.isHardwareBacked`.
struct DeviceIdentity: Sendable {
    /// Stable keychain tag — one key per app install.
    static let keychainTag = "ai.ba6.identity.p256"

    let publicKey: P256.Signing.PublicKey
    let isHardwareBacked: Bool
    private let signer: Signer

    func sign(_ data: Data) throws -> Data {
        try signer.sign(data)
    }

    /// Short, copy-friendly identifier derived from the public key.
    var fingerprint: String {
        let hash = SHA256.hash(data: publicKey.rawRepresentation)
        return hash.prefix(8)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    var publicKeyBase64: String {
        publicKey.rawRepresentation.base64EncodedString()
    }

    // MARK: - Loading

    static func loadOrCreate() throws -> DeviceIdentity {
        if let existing = try load() { return existing }
        return try create()
    }

    private static func load() throws -> DeviceIdentity? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keychainTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
            kSecUseAuthenticationContext as String: LAContext()
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound { return nil }
            throw IdentityError.keychain(status)
        }
        guard let keyRef = item else { return nil }
        let secKey = keyRef as! SecKey
        return try materialize(from: secKey)
    }

    private static func create() throws -> DeviceIdentity {
        if SecureEnclave.isAvailable {
            let key = try SecureEnclave.P256.Signing.PrivateKey(
                accessControl: try accessControl()
            )
            try persist(secureEnclaveKey: key)
            return DeviceIdentity(
                publicKey: key.publicKey,
                isHardwareBacked: true,
                signer: .secureEnclave(key)
            )
        } else {
            let key = P256.Signing.PrivateKey()
            try persist(softwareKey: key)
            return DeviceIdentity(
                publicKey: key.publicKey,
                isHardwareBacked: false,
                signer: .software(key)
            )
        }
    }

    private static func accessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        guard let ac = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage],
            &error
        ) else {
            throw IdentityError.accessControl(error?.takeRetainedValue())
        }
        return ac
    }

    private static func persist(secureEnclaveKey key: SecureEnclave.P256.Signing.PrivateKey) throws {
        let add: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keychainTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecValueData as String: key.dataRepresentation
        ]
        SecItemDelete(add as CFDictionary)
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw IdentityError.keychain(status) }
    }

    private static func persist(softwareKey key: P256.Signing.PrivateKey) throws {
        let add: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keychainTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: key.rawRepresentation
        ]
        SecItemDelete(add as CFDictionary)
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw IdentityError.keychain(status) }
    }

    private static func materialize(from secKey: SecKey) throws -> DeviceIdentity {
        // Attempt to export data; Secure Enclave keys return their opaque
        // `dataRepresentation` (not the raw private scalar).
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(secKey, &error) as Data? else {
            throw IdentityError.exportFailed(error?.takeRetainedValue())
        }
        if let seKey = try? SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: data) {
            return DeviceIdentity(
                publicKey: seKey.publicKey,
                isHardwareBacked: true,
                signer: .secureEnclave(seKey)
            )
        }
        let swKey = try P256.Signing.PrivateKey(rawRepresentation: data)
        return DeviceIdentity(
            publicKey: swKey.publicKey,
            isHardwareBacked: false,
            signer: .software(swKey)
        )
    }

    // MARK: - Signer

    private enum Signer: Sendable {
        case secureEnclave(SecureEnclave.P256.Signing.PrivateKey)
        case software(P256.Signing.PrivateKey)

        func sign(_ data: Data) throws -> Data {
            switch self {
            case .secureEnclave(let key):
                return try key.signature(for: data).rawRepresentation
            case .software(let key):
                return try key.signature(for: data).rawRepresentation
            }
        }
    }

    enum IdentityError: LocalizedError {
        case keychain(OSStatus)
        case accessControl(CFError?)
        case exportFailed(CFError?)

        var errorDescription: String? {
            switch self {
            case .keychain(let status): "Keychain error (\(status))."
            case .accessControl: "Failed to create Secure Enclave access control."
            case .exportFailed: "Failed to export stored identity key."
            }
        }
    }
}
