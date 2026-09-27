import CryptoKit
import Foundation
import Security

public enum AppsScriptSigner {
    public static func canonicalString(action: String, ts: String, nonce: String, from: String, to: String, cal: String) -> String {
        ["v1", action, ts, nonce, from, to, cal].joined(separator: "\n")
    }

    /// Lowercase hex HMAC-SHA256. The secret's UTF-8 text is the key, not its decoded bytes.
    public static func signature(canonical: String, secret: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(canonical.utf8), using: key)
        return hex(mac)
    }

    public static func signedQueryItems(action: String, from: String, to: String, cal: String,
                                        secret: String, now: Date, nonce: String) -> [URLQueryItem] {
        let ts = String(Int(now.timeIntervalSince1970))
        let canonical = canonicalString(action: action, ts: ts, nonce: nonce, from: from, to: to, cal: cal)
        let sig = signature(canonical: canonical, secret: secret)
        return [
            URLQueryItem(name: "action", value: action),
            URLQueryItem(name: "ts", value: ts),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to),
            URLQueryItem(name: "cal", value: cal),
            URLQueryItem(name: "sig", value: sig),
        ]
    }

    /// 32 hex chars from 16 random bytes.
    public static func generateSecret() -> String { randomHex(byteCount: 16) }

    /// 32 hex chars from 16 random bytes.
    public static func generateNonce() -> String { randomHex(byteCount: 16) }

    private static func randomHex(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(nil, byteCount, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed with status \(status)")
        return hex(bytes)
    }

    private static func hex<S: Sequence>(_ bytes: S) -> String where S.Element == UInt8 {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}
