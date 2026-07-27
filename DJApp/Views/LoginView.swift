import AuthenticationServices
import SwiftUI

/// Sign-in gate. Sign in with Apple sits first because App Store guideline 4.8
/// requires it to be offered wherever a third-party login is.
struct LoginView: View {
    @ObservedObject var auth: AuthStore

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            HStack(spacing: 46) {
                branding
                Divider().frame(height: 190).overlay(Theme.stroke)
                buttons
            }
            .padding(28)
        }
        .preferredColorScheme(.dark)
        .alert("Sign-in problem",
               isPresented: Binding(get: { auth.errorMessage != nil },
                                    set: { if !$0 { auth.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(auth.errorMessage ?? "")
        }
    }

    private var branding: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: -14) {
                Circle().fill(Theme.deckA).frame(width: 46, height: 46)
                Circle().fill(Theme.deckB).frame(width: 46, height: 46)
                    .blendMode(.plusLighter)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Easy DJ Mixer")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text("Two decks, real scratching, your music.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dim)
            }

            Text("Sign in to continue.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.dim.opacity(0.8))
                .padding(.top, 2)
        }
        .frame(maxWidth: 260, alignment: .leading)
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                auth.handleAppleAuthorization(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(width: 268, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            Button {
                auth.signInWithGoogle(presentationAnchor: currentWindow())
            } label: {
                HStack(spacing: 9) {
                    GoogleGlyph()
                        .frame(width: 17, height: 17)
                    Text("Sign in with Google")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(width: 268, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.white)
                )
            }
            .buttonStyle(.plain)

            if auth.isBusy {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 2)
            }

            Text("We use your account only to identify you.\nYour music never leaves your device.")
                .font(.system(size: 9))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.dim.opacity(0.75))
                .padding(.top, 4)

            #if DEBUG
            Button("Skip sign-in (debug build only)") {
                auth.signInForDebugging()
            }
            .font(.system(size: 9))
            .foregroundStyle(Theme.accent.opacity(0.7))
            #endif
        }
        .disabled(auth.isBusy)
    }

    private func currentWindow() -> ASPresentationAnchor? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}

/// Google's four-colour mark, drawn rather than bundled so there's no asset to license.
private struct GoogleGlyph: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let lineWidth = side * 0.27
            ZStack {
                Circle()
                    .trim(from: 0.0, to: 0.25)
                    .stroke(Color(red: 0.92, green: 0.26, blue: 0.21),
                            style: StrokeStyle(lineWidth: lineWidth))
                    .rotationEffect(.degrees(-90))
                Circle()
                    .trim(from: 0.25, to: 0.5)
                    .stroke(Color(red: 0.98, green: 0.74, blue: 0.02),
                            style: StrokeStyle(lineWidth: lineWidth))
                    .rotationEffect(.degrees(-90))
                Circle()
                    .trim(from: 0.5, to: 0.75)
                    .stroke(Color(red: 0.20, green: 0.66, blue: 0.33),
                            style: StrokeStyle(lineWidth: lineWidth))
                    .rotationEffect(.degrees(-90))
                Circle()
                    .trim(from: 0.75, to: 1.0)
                    .stroke(Color(red: 0.26, green: 0.52, blue: 0.96),
                            style: StrokeStyle(lineWidth: lineWidth))
                    .rotationEffect(.degrees(-90))
            }
            .padding(lineWidth / 2)
            .frame(width: side, height: side)
        }
    }
}
