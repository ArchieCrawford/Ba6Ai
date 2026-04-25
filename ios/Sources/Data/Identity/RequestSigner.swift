import Foundation
import CryptoKit

/// Signs outbound Cloud Boost requests with the device identity so the
/// backend can verify the caller without accounts, passwords, or tokens.
///
/// Canonical form:
///
///     <method> \n <path> \n <timestamp> \n <sha256(body)>
///
/// The server re-computes the string, looks up the sender's public key by
/// `X-BA6-PubKey`, and verifies the ECDSA signature.
struct RequestSigner: Sendable {
    let identity: DeviceIdentity

    func sign(
        method: String,
        path: String,
        body: Data,
        now: Date = .init()
    ) throws -> SignedHeaders {
        let timestamp = Int(now.timeIntervalSince1970)
        let bodyDigest = SHA256.hash(data: body)
            .map { String(format: "%02x", $0) }
            .joined()
        let canonical = "\(method.uppercased())\n\(path)\n\(timestamp)\n\(bodyDigest)"
        let signature = try identity.sign(Data(canonical.utf8))

        return SignedHeaders(
            publicKey: identity.publicKeyBase64,
            timestamp: String(timestamp),
            signature: signature.base64EncodedString()
        )
    }

    struct SignedHeaders: Sendable {
        let publicKey: String
        let timestamp: String
        let signature: String

        func apply(to request: inout URLRequest) {
            request.setValue(publicKey, forHTTPHeaderField: "X-BA6-PubKey")
            request.setValue(timestamp, forHTTPHeaderField: "X-BA6-Timestamp")
            request.setValue(signature, forHTTPHeaderField: "X-BA6-Signature")
        }
    }
}
