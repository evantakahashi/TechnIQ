//
//  SettingsView.swift
//  TechnIQ
//
//  Created by Evan Takahashi on 1/11/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"

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
