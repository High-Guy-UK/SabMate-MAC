import Foundation

struct SABConnection: Codable, Equatable {
    var host: String
    var port: Int
    var useHTTPS: Bool
    var apiKey: String

    static let empty = SABConnection(host: "192.168.1.10", port: 8080, useHTTPS: false, apiKey: "")

    var baseURL: URL? {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedHost.contains("://"), var components = URLComponents(string: trimmedHost) {
            if components.port == nil {
                components.port = port
            }
            if components.scheme == nil {
                components.scheme = useHTTPS ? "https" : "http"
            }
            return components.url
        }

        var components = URLComponents()
        components.scheme = useHTTPS ? "https" : "http"
        components.host = trimmedHost
        components.port = port
        return components.url
    }

    var isReady: Bool {
        baseURL != nil && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var connection: SABConnection {
        didSet { save() }
    }

    private let defaultsKey = "sabmate.connection"

    init() {
        if
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode(SABConnection.self, from: data)
        {
            connection = decoded
        } else {
            connection = .empty
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(connection) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
