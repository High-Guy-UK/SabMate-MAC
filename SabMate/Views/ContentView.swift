import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var sabService: SABnzbdService
    @State private var selection: SidebarItem? = .queue
    @State private var showingAddSheet = false
    @State private var showingSettings = false
    @State private var didRunStartupCheck = false
    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Queue", systemImage: "arrow.down.circle")
                    .tag(SidebarItem.queue)
                Label("History", systemImage: "clock")
                    .tag(SidebarItem.history)
                Label("Server", systemImage: "server.rack")
                    .tag(SidebarItem.server)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            Group {
                switch selection {
                case .queue:
                    QueueView()
                case .history:
                    HistoryView()
                case .server:
                    ServerView()
                case .none:
                    QueueView()
                }
            }
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add NZB", systemImage: "plus")
                    }

                    Button {
                        Task { await sabService.refreshAll() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(sabService.isLoading)

                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
        }
        .task {
            await runStartupCheck()
        }
        .onReceive(refreshTimer) { _ in
            Task {
                await sabService.refreshAll(showAlerts: false)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddNZBView()
                .environmentObject(sabService)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(sabService)
                .frame(width: 520)
        }
        .alert("SABnzbd", isPresented: Binding(
            get: { sabService.alertMessage != nil },
            set: { if !$0 { sabService.alertMessage = nil } }
        )) {
            Button("OK") { sabService.alertMessage = nil }
        } message: {
            Text(sabService.alertMessage ?? "")
        }
    }

    private func runStartupCheck() async {
        guard !didRunStartupCheck else { return }
        didRunStartupCheck = true

        sabService.configure(with: settings.connection)

        guard await sabService.hasActiveConnection() else {
            showingSettings = true
            return
        }

        await sabService.refreshAll(showAlerts: false)
    }
}

enum SidebarItem: Hashable {
    case queue
    case history
    case server
}
