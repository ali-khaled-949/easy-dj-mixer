import SwiftUI

/// Account menu: who you're signed in as, sign out, and delete account.
struct AccountSheet: View {
    @ObservedObject var auth: AuthStore
    @ObservedObject var library: LibraryStore

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Theme.panelHigh)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Theme.dim)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.session?.label ?? "Not signed in")
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                            if let provider = auth.session?.provider {
                                Text("Signed in with \(provider.displayName)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.dim)
                            }
                        }
                    }
                    .padding(.vertical, 4)
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

                Section {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                    }
                } footer: {
                    Text("Deletes your account and removes every track you've imported from this device. This can't be undone.")
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
                Button("Delete Account and Data", role: .destructive) {
                    auth.deleteAccount(library: library)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This signs you out and permanently deletes the tracks you've imported. It cannot be undone.")
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
