import SwiftUI

/// Account menu. Signed-in users can sign out or delete their account; guests are told
/// nothing is stored for them and can sign in if they want to.
struct AccountSheet: View {
    @ObservedObject var auth: AuthStore
    @ObservedObject var library: LibraryStore

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            List {
                identity

                if auth.isSignedIn {
                    signedInActions
                } else {
                    guestActions
                }

                Section {
                    Text("Easy DJ Mixer \(appVersion)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.dim)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete your account?",
                                isPresented: $confirmingDelete,
                                titleVisibility: .visible) {
                Button("Delete Account", role: .destructive) {
                    auth.deleteAccount(library: library)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your account and every track you've imported will be permanently deleted from this device. This cannot be undone.")
            }
        }
    }

    private var identity: some View {
        Section {
            HStack(spacing: 12) {
                Circle()
                    .fill(Theme.panelHigh)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: auth.isSignedIn ? "person.fill" : "person.fill.questionmark")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.dim)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(auth.session?.label ?? "Not signed in")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Text(auth.session.map { "Signed in with \($0.provider.displayName)" }
                         ?? "Using the app without an account")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.dim)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // Delete comes first and is spelled out, so it cannot be overlooked.
    @ViewBuilder
    private var signedInActions: some View {
        Section {
            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Label("Delete Account", systemImage: "trash")
                    .font(.system(size: 16, weight: .semibold))
            }
        } header: {
            Text("Delete account")
        } footer: {
            Text("Permanently deletes your account and every track you've imported. You'll be asked to confirm.")
        }

        Section {
            Button {
                auth.signOut()
                dismiss()
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } footer: {
            Text("Signing out keeps your imported tracks on this device.")
        }
    }

    private var guestActions: some View {
        Section {
            Button {
                auth.leaveGuestMode()
                dismiss()
            } label: {
                Label("Sign In", systemImage: "person.crop.circle.badge.plus")
            }
        } footer: {
            Text("You haven't created an account, so no personal information is stored. Signing in is optional.")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
