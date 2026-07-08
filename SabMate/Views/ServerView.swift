import SwiftUI

struct ServerView: View {
    @EnvironmentObject private var sabService: SABnzbdService

    var body: some View {
        Form {
            Section("Server") {
                LabeledContent("Version", value: sabService.version ?? "-")
                LabeledContent("State", value: sabService.queue?.status ?? "Unknown")
            }

            Section("Downloaded") {
                LabeledContent("Today", value: sabService.stats?.day ?? "-")
                LabeledContent("This week", value: sabService.stats?.week ?? "-")
                LabeledContent("This month", value: sabService.stats?.month ?? "-")
                LabeledContent("Total", value: sabService.stats?.total ?? "-")
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Server")
    }
}
