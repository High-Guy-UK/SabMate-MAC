import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var sabService: SABnzbdService
    @State private var testing = false

    var body: some View {
        Form {
            Section("SABnzbd Server") {
                TextField("Host or URL", text: $settings.connection.host)
                    .textFieldStyle(.roundedBorder)

                Stepper(value: $settings.connection.port, in: 1...65535) {
                    TextField("Port", value: $settings.connection.port, format: .number)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Use HTTPS", isOn: $settings.connection.useHTTPS)

                SecureField("API key", text: $settings.connection.apiKey)
                    .textFieldStyle(.roundedBorder)
            }

            Section {
                HStack {
                    Button {
                        testing = true
                        Task {
                            sabService.configure(with: settings.connection)
                            await sabService.testConnection()
                            testing = false
                        }
                    } label: {
                        Label("Test Connection", systemImage: "network")
                    }
                    .disabled(testing)

                    if testing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }

            Section {
                HStack {
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("SABnzbd", isPresented: Binding(
            get: { sabService.alertMessage != nil },
            set: { if !$0 { sabService.alertMessage = nil } }
        )) {
            Button("OK") { sabService.alertMessage = nil }
        } message: {
            Text(sabService.alertMessage ?? "")
        }
    }
}
