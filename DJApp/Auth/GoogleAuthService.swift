import AuthenticationServices
import CryptoKit
import Foundation

/// The app's Google OAuth identity.
///
/// This is the iOS OAuth client listed in Google Cloud Console as **"Simple DJ Mixer
/// iOS"** (created before the app was renamed — the client's name is cosmetic) in the
/// `ksa-homes` project, bound to bundle ID `com.simpledjmixer.nie`. Google validates
/// that bundle ID on every sign-in, so a client from another app will not work here.
///
/// No client secret is involved: native apps use PKCE instead, which is why it is safe
/// for this value to sit in the app bundle.
enum GoogleAuthConfig {
    static let clientID = "265144728367-loekm3fmf3nrbl5ijr48d8aumiu0ecvr.apps.googleusercontent.com"
}

struct GoogleProfile {
    let subject: String
    let email: String?
    let name: String?
}

enum GoogleAuthError: LocalizedError {
    case notConfigured
    case cancelled
    case noAuthorizationCode
    case tokenExchangeFailed(String)
    case profileFetchFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured: return GoogleAuthService.configurationHint
        case .cancelled: return "Sign-in cancelled."
        case .noAuthorizationCode: return "Google didn't return an authorization code."
        case .tokenExchangeFailed(let detail): return "Couldn't complete Google sign-in. \(detail)"
        case .profileFetchFailed: return "Signed in, but couldn't read your Google profile."
        }
    }
}

/// Google sign-in over the OAuth 2.0 authorization-code flow with PKCE, using only
/// Apple's own frameworks — no Google SDK, so nothing to resolve and nothing to update.
enum GoogleAuthService {

    static var isConfigured: Bool { !GoogleAuthConfig.clientID.isEmpty }

    static let configurationHint = """
        Google sign-in isn't set up yet. Add your iOS OAuth client ID to \
        GoogleAuthConfig.clientID in GoogleAuthService.swift.
        """

    /// iOS OAuth clients use the reversed client ID as their redirect scheme.
    private static var redirectScheme: String {
        let suffix = GoogleAuthConfig.clientID
            .replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        return "com.googleusercontent.apps.\(suffix)"
    }

    private static var redirectURI: String { "\(redirectScheme):/oauth2redirect" }

    @MainActor
    static func signIn(presentationAnchor: ASPresentationAnchor?) async throws -> GoogleProfile {
        guard isConfigured else { throw GoogleAuthError.notConfigured }

        let verifier = makeCodeVerifier()
        let challenge = codeChallenge(for: verifier)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: GoogleAuthConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        let callbackURL = try await presentSession(url: components.url!,
                                                  scheme: redirectScheme,
                                                  anchor: presentationAnchor)

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            throw GoogleAuthError.noAuthorizationCode
        }

        let accessToken = try await exchange(code: code, verifier: verifier)
        return try await fetchProfile(accessToken: accessToken)
    }

    // MARK: - Web session

    @MainActor
    private static func presentSession(url: URL,
                                       scheme: String,
                                       anchor: ASPresentationAnchor?) async throws -> URL {
        let presenter = AuthPresenter(anchor: anchor)
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callback, error in
                // `presentationContextProvider` is held weakly, so the closure is what
                // keeps the presenter alive until the sheet is done.
                withExtendedLifetime(presenter) {}
                if let error {
                    let code = (error as? ASWebAuthenticationSessionError)?.code
                    continuation.resume(throwing: code == .canceledLogin ? GoogleAuthError.cancelled : error)
                    return
                }
                guard let callback else {
                    continuation.resume(throwing: GoogleAuthError.noAuthorizationCode)
                    return
                }
                continuation.resume(returning: callback)
            }
            session.presentationContextProvider = presenter
            session.prefersEphemeralWebBrowserSession = false
            // Keep the presenter alive for the duration of the session.
            presenter.retain(session)
            if !session.start() {
                continuation.resume(throwing: GoogleAuthError.tokenExchangeFailed("Couldn't open the sign-in page."))
            }
        }
    }

    // MARK: - Token exchange

    private static func exchange(code: String, verifier: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let form = [
            "client_id": GoogleAuthConfig.clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]
        request.httpBody = form
            .map { "\($0.key)=\(percentEncode($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let detail = String(data: data, encoding: .utf8) ?? "No response body."
            throw GoogleAuthError.tokenExchangeFailed(detail)
        }

        struct TokenResponse: Decodable { let access_token: String }
        guard let token = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw GoogleAuthError.tokenExchangeFailed("Unreadable token response.")
        }
        return token.access_token
    }

    private static func fetchProfile(accessToken: String) async throws -> GoogleProfile {
        var request = URLRequest(url: URL(string: "https://openidconnect.googleapis.com/v1/userinfo")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GoogleAuthError.profileFetchFailed
        }

        struct UserInfo: Decodable {
            let sub: String
            let email: String?
            let name: String?
        }
        guard let info = try? JSONDecoder().decode(UserInfo.self, from: data) else {
            throw GoogleAuthError.profileFetchFailed
        }
        return GoogleProfile(subject: info.sub, email: info.email, name: info.name)
    }

    // MARK: - PKCE

    private static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URL(Data(digest))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

/// Supplies the window the web sheet is presented from, and keeps itself alive
/// until the session finishes.
private final class AuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let anchor: ASPresentationAnchor?
    private var session: ASWebAuthenticationSession?

    init(anchor: ASPresentationAnchor?) {
        self.anchor = anchor
    }

    func retain(_ session: ASWebAuthenticationSession) {
        self.session = session
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor ?? ASPresentationAnchor()
    }
}
