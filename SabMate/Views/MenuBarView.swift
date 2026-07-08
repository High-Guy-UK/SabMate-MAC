import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var sabService: SABnzbdService
    let openMainWindow: () -> Void

    var body: some View {
        VStack {
            Button {
                openMainWindow()
            } label: {
                Label("Open SabMate", systemImage: "macwindow")
            }

            Divider()

            if let queue = sabService.queue {
                Text(queue.status ?? "Connected")
                Text("Speed: \(queue.speed ?? "-")")
                Text("Left: \(queue.sizeLeft ?? "-")")
            } else {
                Text("Not connected")
            }

            Divider()

            Button {
                Task { await sabService.refreshAll() }
            } label: {
                Label("Refresh Now", systemImage: "arrow.clockwise")
            }
            .disabled(sabService.isLoading)

            if sabService.queue?.paused == true {
                Button {
                    Task { await sabService.resumeQueue() }
                } label: {
                    Label("Resume Queue", systemImage: "play.fill")
                }
            } else {
                Button {
                    Task { await sabService.pauseQueue() }
                } label: {
                    Label("Pause Queue", systemImage: "pause.fill")
                }
            }

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }

            Divider()

            Button("Quit SabMate") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .task {
            await sabService.refreshAll(showAlerts: false)
        }
    }
}
