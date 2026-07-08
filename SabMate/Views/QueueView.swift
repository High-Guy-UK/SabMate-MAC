import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var sabService: SABnzbdService

    var body: some View {
        VStack(spacing: 0) {
            QueueSummaryView(queue: sabService.queue)
                .padding()

            Divider()

            if let slots = sabService.queue?.slots, !slots.isEmpty {
                Table(slots) {
                    TableColumn("Name") { item in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.filename)
                                .lineLimit(1)
                            Text(item.category ?? "No category")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    TableColumn("Status") { item in
                        Text(item.status ?? "Queued")
                    }
                    .width(90)
                    TableColumn("Progress") { item in
                        ProgressView(value: Double(item.percentage ?? "0") ?? 0, total: 100)
                            .frame(width: 140)
                    }
                    .width(170)
                    TableColumn("Remaining") { item in
                        Text(item.timeLeft ?? "-")
                    }
                    .width(100)
                    TableColumn("Actions") { item in
                        Button(role: .destructive) {
                            Task { await sabService.deleteQueueItem(item) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .labelStyle(.iconOnly)
                    }
                    .width(70)
                }
            } else {
                ContentUnavailableView(
                    "Queue Empty",
                    systemImage: "tray",
                    description: Text("New downloads added to SABnzbd will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Queue")
    }
}

private struct QueueSummaryView: View {
    @EnvironmentObject private var sabService: SABnzbdService
    let queue: SABQueue?

    var body: some View {
        HStack(spacing: 16) {
            MetricView(title: "Status", value: queue?.status ?? "Unknown")
            MetricView(title: "Speed", value: queue?.speed ?? "-")
            MetricView(title: "Left", value: queue?.sizeLeft ?? "-")
            MetricView(title: "Time", value: queue?.timeLeft ?? "-")

            Spacer()

            Button {
                Task { await sabService.pauseQueue() }
            } label: {
                Label("Pause", systemImage: "pause.fill")
            }
            .disabled(queue?.paused == true)

            Button {
                Task { await sabService.resumeQueue() }
            } label: {
                Label("Resume", systemImage: "play.fill")
            }
            .disabled(queue?.paused == false)
        }
    }
}

struct MetricView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
        }
        .frame(minWidth: 82, alignment: .leading)
    }
}
