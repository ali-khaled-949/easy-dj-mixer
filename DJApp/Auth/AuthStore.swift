import AuthenticationServices
import Foundation
import Security

enum AuthProvider: String, Codable {
    case apple, google

    var displayName: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        }
    }
}

struct UserSession: Codable, Equatable {
    var provider: AuthProvider
    /// Stable identifier from the provider. For Apple this is the opaque user ID,
    /// for Google the OpenID `sub`.
    var userID: String
    var email: String?
    var displayName: String?

    var label: String {
        displayName?.isEmpty == false ? displayName! : (email ?? "Signed in with \(provider.displayName)")
    }
}

/// Holds the signed-in session and persists it in the keychain.
///
/// There is no backend: the app authenticates the user with Apple or Google purely to
/// establish an identity, and everything else stays on the device. That means "delete
/// account" is a local operation — there is no server-side record to remove.
@MainActor
final class AuthStore: ObservableObject {

    @Published private(set) var session: UserSession?
    @Published var errorMessage: String?
    @Published private(set) var isBusy = false

    private let keychainService = "com.simpledjmixer.nie.session"
    private let keychainAccount = "current"

    var isSignedIn: Bool { session != nil }

    init() {
        session = loadSession()
    }

    // MARK: - Apple

    func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Unexpected credential from Apple."
                return
            }

            // Apple only sends the name and email on the very first authorization, so
            // anything we get now has to be persisted — it will not come back.
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            var resolved = UserSession(provider: .apple,
                                       userID: credential.user,
                                       email: credential.email,
                                       displayName: name.isEmpty ? nil : name)

            // Preserve details from a previous sign-in of the same account.
            if let existing = loadSession(), existing.userID == resolved.userID {
                resolved.email = resolved.email ?? existing.email
                resolved.displayName = resolved.displayName ?? existing.displayName
            }

            store(resolved)

        case .failure(let error):
            // The user simply backing out is not an error worth showing.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Google

    func signInWithGoogle(presentationAnchor: ASPresentationAnchor?) {
        guard GoogleAuthService.isConfigured else {
            errorMessage = GoogleAuthService.configurationHint
            return
        }

        isBusy = true
        Task {
            do {
                let profile = try await GoogleAuthService.signIn(presentationAnchor: presentationAnchor)
                store(UserSession(provider: .google,
                                  userID: profile.subject,
                                  email: profile.email,
                                  displayName: profile.name))
            } catch GoogleAuthError.cancelled {
                // Nothing to report.
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    // MARK: - Session lifecycle

    func signOut() {
        session = nil
        deleteFromKeychain()
    }

    /// Required by App Store guideline 5.1.1(v): an app that lets people create an
    /// account has to let them delete it. With no server, that means dropping the
    /// session and every track the app has stored.
    func deleteAccount(library: LibraryStore) {
        library.deleteAllLocalData()
        UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
        signOut()
    }

    #if DEBUG
    /// Lets the console be opened without a real provider round-trip while developing.
    /// Compiled out of Release builds, so it can never reach the App Store.
    func signInForDebugging() {
        store(UserSession(provider: .apple,
                          userID: "debug-user",
                          email: "debug@example.com",
                          displayName: "Debug User"))
    }
    #endif

    private func store(_ newSession: UserSession) {
        session = newSession
        errorMessage = nil
        saveToKeychain(newSession)
    }

    // MARK: - Keychain

    private func saveToKeychain(_ session: UserSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        deleteFromKeychain()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadSession() -> UserSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(UserSession.self, from: data)
    }

    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
