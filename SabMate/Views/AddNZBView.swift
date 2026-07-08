import SwiftUI
import UniformTypeIdentifiers

struct AddNZBView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sabService: SABnzbdService

    @State private var addMode: AddMode = .url
    @State private var urlString = ""
    @State private var displayName = ""
    @State private var category = ""
    @State private var priority: SABPriority = .defaultPriority
    @State private var selectedFile: URL?
    @State private var isImporting = false
    @State private var isSubmitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("Type", selection: $addMode) {
                Label("URL", systemImage: "link").tag(AddMode.url)
                Label("File", systemImage: "doc.badge.plus").tag(AddMode.file)
            }
            .pickerStyle(.segmented)

            Form {
                if addMode == .url {
                    TextField("NZB URL", text: $urlString)
                    TextField("Display name", text: $displayName)
                } else {
                    HStack {
                        Text(selectedFile?.lastPathComponent ?? "No file selected")
                            .foregroundStyle(selectedFile == nil ? .secondary : .primary)
                        Spacer()
                        Button {
                            isImporting = true
                        } label: {
                            Label("Choose File", systemImage: "folder")
                        }
                    }
                }

                TextField("Category", text: $category)

                Picker("Priority", selection: $priority) {
                    ForEach(SABPriority.allCases) { priority in
                        Text(priority.rawValue).tag(priority)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button {
                    submit()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Add", systemImage: "plus")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit || isSubmitting)
            }
        }
        .padding(24)
        .frame(width: 520)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.init(filenameExtension: "nzb") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result {
                selectedFile = urls.first
            }
        }
    }

    private var canSubmit: Bool {
        switch addMode {
        case .url:
            return URL(string: urlString) != nil
        case .file:
            return selectedFile != nil
        }
    }

    private func submit() {
        isSubmitting = true
        Task {
            switch addMode {
            case .url:
                await sabService.addNZBURL(urlString, name: displayName, category: category, priority: priority)
            case .file:
                if let selectedFile {
                    await sabService.uploadNZBFile(at: selectedFile, category: category, priority: priority)
                }
            }
            isSubmitting = false
            dismiss()
        }
    }
}

private enum AddMode {
    case url
    case file
}
