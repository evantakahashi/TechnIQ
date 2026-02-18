//
//  SettingsView.swift
//  TechnIQ
//
//  Created by Evan Takahashi on 1/11/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    @State private var showingDeleteAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var isDeletingAccount = false
    @State private var deleteError: String?
    @State private var showingDeleteError = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Appearance", selection: $appColorScheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose how TechnIQ looks. System follows your device settings.")
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(DesignSystem.Colors.error)
                            Text("Delete Account")
                                .foregroundColor(DesignSystem.Colors.error)
                        }
                    }
                    .disabled(isDeletingAccount)
                } header: {
                    Text("Account")
                } footer: {
                    Text("Permanently deletes your account, training data, plans, and progress. This cannot be undone.")
                }

                Section("Legal") {
                    Button {
                        if let url = URL(string: "https://techniq-b9a27.web.app/terms-of-service.html") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                    Button {
                        if let url = URL(string: "https://techniq-b9a27.web.app/privacy-policy.html") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised")
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Account?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Continue", role: .destructive) {
                    deleteConfirmationText = ""
                    showingDeleteConfirmation = true
                }
            } message: {
                Text("This will permanently delete your account, all training data, plans, and progress. This cannot be undone.")
            }
            .alert("Type DELETE to confirm", isPresented: $showingDeleteConfirmation) {
                TextField("Type DELETE", text: $deleteConfirmationText)
                    .autocapitalization(.allCharacters)
                Button("Cancel", role: .cancel) {
                    deleteConfirmationText = ""
                }
                Button("Delete Account", role: .destructive) {
                    performAccountDeletion()
                }
                .disabled(deleteConfirmationText != "DELETE")
            } message: {
                Text("This action is permanent and cannot be reversed.")
            }
            .alert("Deletion Failed", isPresented: $showingDeleteError) {
                Button("Try Again", role: .destructive) {
                    performAccountDeletion()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(deleteError ?? "An unknown error occurred. Please try again.")
            }
            .overlay {
                if isDeletingAccount {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            Text("Deleting account...")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                }
            }
        }
    }

    private func performAccountDeletion() {
        isDeletingAccount = true
        deleteError = nil

        Task {
            do {
                try await authManager.deleteAccount()
                await MainActor.run {
                    isDeletingAccount = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeletingAccount = false
                    deleteError = error.localizedDescription
                    showingDeleteError = true
                }
            }
        }
    }
}

// MARK: - Color Scheme Helper
extension String {
    var toColorScheme: ColorScheme? {
        switch self {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

#Preview {
    SettingsView()
}
