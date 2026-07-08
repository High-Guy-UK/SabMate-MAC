import Foundation

struct SABQueueResponse: Decodable {
    let queue: SABQueue
}

struct SABQueue: Decodable {
    let status: String?
    let speed: String?
    let size: String?
    let sizeLeft: String?
    let timeLeft: String?
    let paused: Bool?
    let slots: [SABQueueSlot]

    enum CodingKeys: String, CodingKey {
        case status, speed, size, paused, slots
        case sizeLeft = "sizeleft"
        case timeLeft = "timeleft"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        speed = try container.decodeFlexibleStringIfPresent(forKey: .speed)
        size = try container.decodeFlexibleStringIfPresent(forKey: .size)
        sizeLeft = try container.decodeFlexibleStringIfPresent(forKey: .sizeLeft)
        timeLeft = try container.decodeFlexibleStringIfPresent(forKey: .timeLeft)
        paused = try container.decodeFlexibleBoolIfPresent(forKey: .paused)
        slots = try container.decodeIfPresent([SABQueueSlot].self, forKey: .slots) ?? []
    }
}

struct SABQueueSlot: Decodable, Identifiable {
    let id: String
    let filename: String
    let status: String?
    let category: String?
    let percentage: String?
    let size: String?
    let sizeLeft: String?
    let timeLeft: String?

    enum CodingKeys: String, CodingKey {
        case id = "nzo_id"
        case filename, status, category, percentage, size
        case sizeLeft = "sizeleft"
        case timeLeft = "timeleft"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleStringIfPresent(forKey: .id) ?? UUID().uuidString
        filename = try container.decodeFlexibleStringIfPresent(forKey: .filename) ?? "Unknown"
        status = try container.decodeFlexibleStringIfPresent(forKey: .status)
        category = try container.decodeFlexibleStringIfPresent(forKey: .category)
        percentage = try container.decodeFlexibleStringIfPresent(forKey: .percentage)
        size = try container.decodeFlexibleStringIfPresent(forKey: .size)
        sizeLeft = try container.decodeFlexibleStringIfPresent(forKey: .sizeLeft)
        timeLeft = try container.decodeFlexibleStringIfPresent(forKey: .timeLeft)
    }
}

struct SABHistoryResponse: Decodable {
    let history: SABHistory
}

struct SABHistory: Decodable {
    let slots: [SABHistorySlot]

    enum CodingKeys: String, CodingKey {
        case slots
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        slots = try container.decodeIfPresent([SABHistorySlot].self, forKey: .slots) ?? []
    }
}

struct SABHistorySlot: Decodable, Identifiable {
    let id: String
    let name: String
    let status: String?
    let category: String?
    let size: String?
    let completed: Int?

    enum CodingKeys: String, CodingKey {
        case id = "nzo_id"
        case name, status, category, size, completed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleStringIfPresent(forKey: .id) ?? UUID().uuidString
        name = try container.decodeFlexibleStringIfPresent(forKey: .name) ?? "Unknown"
        status = try container.decodeFlexibleStringIfPresent(forKey: .status)
        category = try container.decodeFlexibleStringIfPresent(forKey: .category)
        size = try container.decodeFlexibleStringIfPresent(forKey: .size)
        completed = try container.decodeFlexibleIntIfPresent(forKey: .completed)
    }

    var completedDate: Date? {
        guard let completed else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(completed))
    }
}

struct SABServerStatsResponse: Decodable {
    let total: String?
    let month: String?
    let week: String?
    let day: String?

    enum CodingKeys: String, CodingKey {
        case total
        case month = "month_size"
        case week = "week_size"
        case day = "day_size"
        case legacyMonth = "month"
        case legacyWeek = "week"
        case legacyDay = "day"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = try container.decodeFlexibleStringIfPresent(forKey: .total)
        month = try container.decodeFlexibleStringIfPresent(forKey: .month)
            ?? container.decodeFlexibleStringIfPresent(forKey: .legacyMonth)
        week = try container.decodeFlexibleStringIfPresent(forKey: .week)
            ?? container.decodeFlexibleStringIfPresent(forKey: .legacyWeek)
        day = try container.decodeFlexibleStringIfPresent(forKey: .day)
            ?? container.decodeFlexibleStringIfPresent(forKey: .legacyDay)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleStringIfPresent(forKey key: Key) throws -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value ? "true" : "false"
        }
        return nil
    }

    func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }
        return nil
    }

    func decodeFlexibleBoolIfPresent(forKey key: Key) throws -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value != 0
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            switch value.lowercased() {
            case "true", "1", "yes", "paused":
                return true
            case "false", "0", "no", "idle", "downloading":
                return false
            default:
                return nil
            }
        }
        return nil
    }
}
