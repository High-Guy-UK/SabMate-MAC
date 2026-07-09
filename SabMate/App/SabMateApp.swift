import SwiftUI
import AppKit

@main
struct SabMateApp: App {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var settings = AppSettings()
    @StateObject private var sabService = SABnzbdService()

    init() {
        let appSettings = AppSettings()
        let appService = SABnzbdService()
        appService.configure(with: appSettings.connection)
        _settings = StateObject(wrappedValue: appSettings)
        _sabService = StateObject(wrappedValue: appService)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .environmentObject(settings)
            .environmentObject(sabService)
        } label: {
            Label("SabMate", systemImage: "arrow.down.circle.fill")
        }
        .menuBarExtraStyle(.menu)

        WindowGroup("SabMate", id: "main") {
            ContentView()
                .environmentObject(settings)
                .environmentObject(sabService)
                .task {
                    sabService.configure(with: settings.connection)
                }
                .onChange(of: settings.connection) { _, connection in
                    sabService.configure(with: connection)
                }
        }
        .windowStyle(.titleBar)
        .commands {
            SidebarCommands()
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(sabService)
                .frame(width: 520)
        }
    }
}
