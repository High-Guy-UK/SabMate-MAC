import Foundation

enum SABError: LocalizedError {
    case missingConnection
    case invalidResponse
    case decoding(mode: String, preview: String)
    case invalidNZB(String)
    case network(String)
    case apiFailure(String)

    var errorDescription: String? {
        switch self {
        case .missingConnection:
            return "Add your SABnzbd host and API key in Settings first."
        case .invalidResponse:
            return "SABnzbd returned a response this app could not read."
        case .decoding(let mode, let preview):
            return "SABnzbd returned an unexpected \(mode) response: \(preview)"
        case .invalidNZB(let message):
            return message
        case .network(let message):
            return message
        case .apiFailure(let message):
            return message
        }
    }
}

@MainActor
final class SABnzbdService: ObservableObject {
    @Published private(set) var queue: SABQueue?
    @Published private(set) var history: [SABHistorySlot] = []
    @Published private(set) var stats: SABServerStatsResponse?
    @Published private(set) var version: String?
    @Published private(set) var isLoading = false
    @Published var alertMessage: String?

    private var connection: SABConnection = .empty
    private let session: URLSession
    private var isRefreshing = false

    init(session: URLSession = .shared) {
        self.session = session
    }

    func configure(with connection: SABConnection) {
        self.connection = connection
    }

    func hasActiveConnection() async -> Bool {
        guard connection.isReady else { return false }

        do {
            queue = try await fetchQueue()
            return true
        } catch {
            return false
        }
    }

    func refreshAll(showAlerts: Bool = true) async {
        guard connection.isReady else {
            if showAlerts {
                alertMessage = SABError.missingConnection.localizedDescription
            }
            return
        }
        guard !isRefreshing else { return }

        isRefreshing = true
        isLoading = true
        defer {
            isLoading = false
            isRefreshing = false
        }

        var firstRequiredError: Error?

        do { queue = try await fetchQueue() } catch { firstRequiredError = firstRequiredError ?? error }
        do { history = try await fetchHistory() } catch { firstRequiredError = firstRequiredError ?? error }
        try? await updateOptionalServerDetails()

        if showAlerts, let error = firstRequiredError {
            alertMessage = friendlyMessage(for: error)
        }
    }

    func testConnection() async {
        guard connection.isReady else {
            alertMessage = SABError.missingConnection.localizedDescription
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            queue = try await fetchQueue()
            version = try await fetchVersion()
            alertMessage = "Connected to SABnzbd\(version.map { " \($0)" } ?? "")."
        } catch {
            alertMessage = friendlyMessage(for: error)
        }
    }

    func addNZBURL(_ urlString: String, name: String, category: String, priority: SABPriority) async {
        do {
            let response = try await request(mode: "addurl", queryItems: [
                URLQueryItem(name: "name", value: urlString),
                URLQueryItem(name: "nzbname", value: name),
                URLQueryItem(name: "cat", value: category),
                URLQueryItem(name: "priority", value: priority.apiValue)
            ])
            try validateSimpleResponse(response)
            await refreshAll(showAlerts: false)
        } catch {
            alertMessage = friendlyMessage(for: error)
        }
    }

    func uploadNZBFile(at fileURL: URL, category: String, priority: SABPriority) async {
        do {
            let didAccess = fileURL.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }

            let nzbData = try validatedNZBData(from: fileURL)

            let boundary = "Boundary-\(UUID().uuidString)"
            var request = try baseRequest(mode: "addfile", queryItems: [
                URLQueryItem(name: "cat", value: category),
                URLQueryItem(name: "priority", value: priority.apiValue)
            ])
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = multipartBody(
                fileData: nzbData,
                filename: fileURL.lastPathComponent,
                boundary: boundary
            )

            let (data, response) = try await session.data(for: request)
            try validateHTTP(response)
            try validateSimpleResponse(data)
            await refreshAll(showAlerts: false)
        } catch {
            alertMessage = friendlyMessage(for: error)
        }
    }

    func pauseQueue() async {
        await performQueueAction("pause")
    }

    func resumeQueue() async {
        await performQueueAction("resume")
    }

    func deleteQueueItem(_ item: SABQueueSlot) async {
        await performQueueAction("queue", extraItems: [
            URLQueryItem(name: "name", value: "delete"),
            URLQueryItem(name: "value", value: item.id),
            URLQueryItem(name: "del_files", value: "1")
        ])
    }

    private func performQueueAction(_ mode: String, extraItems: [URLQueryItem] = []) async {
        do {
            let data = try await request(mode: mode, queryItems: extraItems)
            try validateSimpleResponse(data, allowEmpty: true)
            await refreshAll(showAlerts: false)
        } catch {
            alertMessage = friendlyMessage(for: error)
        }
    }

    private func fetchQueue() async throws -> SABQueue {
        let data = try await request(mode: "queue")
        do {
            return try JSONDecoder().decode(SABQueueResponse.self, from: data).queue
        } catch {
            throw decodeError(mode: "queue", data: data)
        }
    }

    private func fetchHistory() async throws -> [SABHistorySlot] {
        let data = try await request(mode: "history", queryItems: [URLQueryItem(name: "limit", value: "30")])
        do {
            return try JSONDecoder().decode(SABHistoryResponse.self, from: data).history.slots
        } catch {
            throw decodeError(mode: "history", data: data)
        }
    }

    private func fetchStats() async throws -> SABServerStatsResponse {
        let data = try await request(mode: "server_stats")
        do {
            return try JSONDecoder().decode(SABServerStatsResponse.self, from: data)
        } catch {
            throw decodeError(mode: "server stats", data: data)
        }
    }

    private func fetchVersion() async throws -> String {
        let data = try await request(mode: "version")
        if let text = String(data: data, encoding: .utf8) {
            return text.trimmingCharacters(in: CharacterSet(charactersIn: "\"\n "))
        }
        throw SABError.invalidResponse
    }

    private func updateOptionalServerDetails() async throws {
        if let stats = try? await fetchStats() {
            self.stats = stats
        }
        if let version = try? await fetchVersion() {
            self.version = version
        }
    }

    private func request(mode: String, queryItems: [URLQueryItem] = []) async throws -> Data {
        let request = try baseRequest(mode: mode, queryItems: queryItems)
        do {
            let (data, response) = try await session.data(for: request)
            try validateHTTP(response)
            return data
        } catch let error as URLError {
            throw networkError(for: error, request: request)
        }
    }

    private func baseRequest(mode: String, queryItems: [URLQueryItem]) throws -> URLRequest {
        guard let baseURL = connection.baseURL else { throw SABError.missingConnection }

        var components = URLComponents(url: baseURL.appending(path: "api"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "output", value: "json"),
            URLQueryItem(name: "apikey", value: connection.apiKey),
            URLQueryItem(name: "mode", value: mode)
        ] + queryItems.filter { item in
            guard let value = item.value else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        guard let url = components?.url else { throw SABError.missingConnection }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        return request
    }

    private func validateHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw SABError.invalidResponse }
        guard 200..<300 ~= http.statusCode else {
            throw SABError.apiFailure("SABnzbd returned HTTP \(http.statusCode).")
        }
    }

    private func validateSimpleResponse(_ data: Data, allowEmpty: Bool = false) throws {
        guard !data.isEmpty || allowEmpty else { throw SABError.invalidResponse }
        guard let text = String(data: data, encoding: .utf8), !text.localizedCaseInsensitiveContains("error") else {
            throw SABError.apiFailure(String(data: data, encoding: .utf8) ?? "SABnzbd reported an error.")
        }
    }

    private func multipartBody(fileData: Data, filename: String, boundary: String) -> Data {
        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"name\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: application/x-nzb\r\n\r\n")
        body.append(fileData)
        body.appendString("\r\n--\(boundary)--\r\n")
        return body
    }

    private func validatedNZBData(from fileURL: URL) throws -> Data {
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            throw SABError.invalidNZB("That NZB file is empty.")
        }

        if isValidNZBXML(data) {
            return data
        }

        if let cleanedData = cleanedNZBData(from: data), isValidNZBXML(cleanedData) {
            return cleanedData
        }

        let parser = XMLParser(data: data)
        parser.parse()
        let line = parser.lineNumber
        let column = parser.columnNumber
        let parserError = parser.parserError?.localizedDescription ?? "It does not look like a valid NZB XML file."
        throw SABError.invalidNZB("That NZB file could not be read at line \(line), column \(column): \(parserError)")
    }

    private func isValidNZBXML(_ data: Data) -> Bool {
        let parser = XMLParser(data: data)
        let validator = NZBXMLValidator()
        parser.delegate = validator
        return parser.parse() && validator.rootElementName?.lowercased() == "nzb"
    }

    private func cleanedNZBData(from data: Data) -> Data? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let nsText = text as NSString
        let closingTagRange = nsText.range(
            of: "</nzb>",
            options: [.caseInsensitive, .backwards]
        )
        guard closingTagRange.location != NSNotFound else { return nil }

        let endIndex = closingTagRange.location + closingTagRange.length
        let cleanedText = nsText.substring(to: endIndex)
        return cleanedText.data(using: .utf8)
    }

    private func networkError(for error: URLError, request: URLRequest) -> SABError {
        let urlText = request.url?.absoluteString ?? "your SABnzbd address"
        switch error.code {
        case .networkConnectionLost, .cannotConnectToHost, .cannotFindHost:
            return .network("Could not keep a connection to SABnzbd at \(urlText). Check the host, port, and whether HTTPS is switched on correctly.")
        case .timedOut:
            return .network("The connection to SABnzbd timed out. Check that your Mac can reach the server on this network.")
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot:
            return .network("The HTTPS connection failed. If your SABnzbd server is using plain HTTP, turn off Use HTTPS. If it uses a self-signed certificate, macOS may need to trust it first.")
        default:
            return .network(error.localizedDescription)
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    private func decodeError(mode: String, data: Data) -> SABError {
        let preview = String(data: data, encoding: .utf8)?
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(180) ?? "No readable response body."
        return .decoding(mode: mode, preview: String(preview))
    }
}

enum SABPriority: String, CaseIterable, Identifiable {
    case defaultPriority = "Default"
    case low = "Low"
    case normal = "Normal"
    case high = "High"
    case force = "Force"

    var id: String { rawValue }

    var apiValue: String {
        switch self {
        case .defaultPriority: return "-100"
        case .low: return "-1"
        case .normal: return "0"
        case .high: return "1"
        case .force: return "2"
        }
    }
}

private extension Data {
    mutating func appendString(_ value: String) {
        append(Data(value.utf8))
    }
}

private final class NZBXMLValidator: NSObject, XMLParserDelegate {
    private(set) var rootElementName: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if rootElementName == nil {
            rootElementName = elementName
        }
    }
}
