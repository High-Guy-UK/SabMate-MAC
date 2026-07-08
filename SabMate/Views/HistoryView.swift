import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var sabService: SABnzbdService

    var body: some View {
        Group {
            if sabService.history.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Completed SABnzbd items will appear here.")
                )
            } else {
                Table(sabService.history) {
                    TableColumn("Name") { item in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .lineLimit(1)
                            Text(item.category ?? "No category")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    TableColumn("Status") { item in
                        Text(item.status ?? "-")
                    }
                    .width(100)
                    TableColumn("Size") { item in
                        Text(item.size ?? "-")
                    }
                    .width(100)
                    TableColumn("Completed") { item in
                        if let date = item.completedDate {
                            Text(date, style: .date)
                        } else {
                            Text("-")
                        }
                    }
                    .width(130)
                }
            }
        }
        .navigationTitle("History")
    }
}
