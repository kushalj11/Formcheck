import CommonCrypto
import CryptoKit
import Foundation

@MainActor
final class AuthManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var displayName: String?
    @Published var isGuest = false
    @Published var lastError: String?

    private let loggedInEmailKey = "loggedInEmail"
    nonisolated private static let hashPrefix = "pbkdf2-sha256$"
    nonisolated private static let iterations: UInt32 = 120_000

    init() {
        if let email = KeychainStore.get(loggedInEmailKey) {
            displayName = email
            isSignedIn = true
        }
    }

    func signUp(email: String, password: String) {
        lastError = nil
        let normalized = Self.normalize(email)
        guard Self.looksLikeEmail(normalized) else {
            lastError = "Enter a valid email address."
            return
        }
        guard password.count >= 8 else {
            lastError = "Password must be at least 8 characters."
            return
        }
        guard KeychainStore.get(Self.saltKey(normalized)) == nil else {
            lastError = "An account with that email already exists. Log in instead."
            return
        }
        let salt = Self.randomSalt()
        guard let hash = Self.hash(password: password, salt: salt),
              KeychainStore.set(salt, forKey: Self.saltKey(normalized)),
              KeychainStore.set(hash, forKey: Self.hashKey(normalized)) else {
            KeychainStore.remove(Self.saltKey(normalized))
            KeychainStore.remove(Self.hashKey(normalized))
            lastError = "Couldn't save your account on this device. Please try again."
            return
        }
        completeSignIn(email: normalized)
    }

    func logIn(email: String, password: String) {
        lastError = nil
        let normalized = Self.normalize(email)
        guard let salt = KeychainStore.get(Self.saltKey(normalized)),
              let storedHash = KeychainStore.get(Self.hashKey(normalized)) else {
            lastError = "No account found for that email."
            return
        }
        guard Self.verify(password: password, salt: salt, against: storedHash) else {
            lastError = "Incorrect password."
            return
        }
        if !storedHash.hasPrefix(Self.hashPrefix), let upgraded = Self.hash(password: password, salt: salt) {
            KeychainStore.set(upgraded, forKey: Self.hashKey(normalized))
        }
        completeSignIn(email: normalized)
    }

    func continueAsGuest() {
        isGuest = true
        isSignedIn = true
    }

    func signOut() {
        KeychainStore.remove(loggedInEmailKey)
        displayName = nil
        isGuest = false
        isSignedIn = false
    }

    private func completeSignIn(email: String) {
        KeychainStore.set(email, forKey: loggedInEmailKey)
        displayName = email
        isGuest = false
        isSignedIn = true
        lastError = nil
    }

    private static func saltKey(_ email: String) -> String { "salt:\(email)" }
    private static func hashKey(_ email: String) -> String { "hash:\(email)" }

    private static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func looksLikeEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@")
        return parts.count == 2 && parts[1].contains(".") && !email.hasPrefix("@")
    }

    private static func randomSalt(length: Int = 16) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            fatalError("Unable to generate a secure salt. SecRandomCopyBytes failed with status \(status).")
        }
        return Data(bytes).base64EncodedString()
    }

    private static func hash(password: String, salt: String, iterations: UInt32 = iterations) -> String? {
        let passwordBytes = Array(password.utf8)
        let saltBytes = Array(salt.utf8)
        var derived = [UInt8](repeating: 0, count: 32)
        let status = passwordBytes.withUnsafeBufferPointer { pw in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                UnsafeRawPointer(pw.baseAddress)?.assumingMemoryBound(to: CChar.self), pw.count,
                saltBytes, saltBytes.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), iterations,
                &derived, derived.count
            )
        }
        guard status == kCCSuccess else { return nil }
        return "\(hashPrefix)\(iterations)$" + derived.map { String(format: "%02x", $0) }.joined()
    }

    private static func legacyHash(password: String, salt: String) -> String {
        SHA256.hash(data: Data((salt + password).utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func verify(password: String, salt: String, against stored: String) -> Bool {
        let candidate: String?
        if stored.hasPrefix(hashPrefix) {
            let parts = stored.dropFirst(hashPrefix.count).split(separator: "$")
            guard parts.count == 2, let rounds = UInt32(parts[0]) else { return false }
            candidate = hash(password: password, salt: salt, iterations: rounds)
        } else {
            candidate = legacyHash(password: password, salt: salt)
        }
        guard let candidate else { return false }
        return constantTimeEquals(candidate, stored)
    }

    private static func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        let x = Array(a.utf8), y = Array(b.utf8)
        guard x.count == y.count else { return false }
        return zip(x, y).reduce(0) { $0 | ($1.0 ^ $1.1) } == 0
    }
}
