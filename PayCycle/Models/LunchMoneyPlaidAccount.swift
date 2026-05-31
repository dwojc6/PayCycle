import Foundation

struct PlaidAccountsResponse: Decodable {
    let plaidAccounts: [LunchMoneyPlaidAccount]

    private enum CodingKeys: String, CodingKey {
        case plaidAccounts = "plaid_accounts"
    }
}

struct LunchMoneyPlaidAccount: Decodable, Identifiable, Hashable {
    let id: Int
    let plaidItemID: String?
    let dateLinked: String?
    let linkedByName: String?
    let name: String
    let displayName: String?
    let rawType: String
    let subtype: String?
    let mask: String?
    let institutionName: String?
    let status: String
    let allowTransactionModifications: Bool?
    let limit: Decimal?
    let balance: Decimal
    let currency: String
    let toBase: Decimal?
    let balanceLastUpdate: Date?
    let importStartDate: String?
    let lastImport: Date?
    let lastFetch: Date?
    let plaidLastSuccessfulUpdate: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case plaidItemID = "plaid_item_id"
        case dateLinked = "date_linked"
        case linkedByName = "linked_by_name"
        case name
        case displayName = "display_name"
        case rawType = "type"
        case subtype
        case mask
        case institutionName = "institution_name"
        case status
        case allowTransactionModifications = "allow_transaction_modifications"
        case limit
        case balance
        case currency
        case toBase = "to_base"
        case balanceLastUpdate = "balance_last_update"
        case importStartDate = "import_start_date"
        case lastImport = "last_import"
        case lastFetch = "last_fetch"
        case plaidLastSuccessfulUpdate = "plaid_last_successful_update"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        plaidItemID = try container.decodeIfPresent(String.self, forKey: .plaidItemID)
        dateLinked = try container.decodeIfPresent(String.self, forKey: .dateLinked)
        linkedByName = try container.decodeIfPresent(String.self, forKey: .linkedByName)
        name = try container.decode(String.self, forKey: .name)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        rawType = try container.decode(String.self, forKey: .rawType)
        subtype = try container.decodeIfPresent(String.self, forKey: .subtype)
        mask = try container.decodeIfPresent(String.self, forKey: .mask)
        institutionName = try container.decodeIfPresent(String.self, forKey: .institutionName)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "active"
        allowTransactionModifications = try container.decodeIfPresent(Bool.self, forKey: .allowTransactionModifications)
        limit = try container.decodeDecimalIfPresent(forKey: .limit)
        balance = try container.decodeDecimal(forKey: .balance)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "usd"
        toBase = try container.decodeDecimalIfPresent(forKey: .toBase)
        balanceLastUpdate = try container.decodeFlexibleDateIfPresent(forKey: .balanceLastUpdate)
        importStartDate = try container.decodeIfPresent(String.self, forKey: .importStartDate)
        lastImport = try container.decodeFlexibleDateIfPresent(forKey: .lastImport)
        lastFetch = try container.decodeFlexibleDateIfPresent(forKey: .lastFetch)
        plaidLastSuccessfulUpdate = try container.decodeFlexibleDateIfPresent(forKey: .plaidLastSuccessfulUpdate)
    }
}

extension LunchMoneyPlaidAccount {
    var accountType: NormalizedAccountType {
        NormalizedAccountType(rawType: rawType)
    }

    var amount: Decimal {
        toBase ?? balance
    }

    var nickname: String {
        if let displayName,
           let institutionName,
           displayName.hasPrefix("\(institutionName) ") {
            return String(displayName.dropFirst(institutionName.count + 1))
        }

        if let displayName, !displayName.isEmpty {
            return displayName
        }

        return name
    }

    var shortInstitutionName: String {
        guard let institutionName, !institutionName.isEmpty else {
            return "Linked"
        }

        return institutionName
            .replacingOccurrences(of: "Federal Credit Union", with: "FCU")
            .replacingOccurrences(of: "Credit Union", with: "CU")
            .replacingOccurrences(of: "Online", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var maskedNumber: String {
        mask.map { "•\($0)" } ?? "Linked"
    }

    var badgeLabel: String {
        let candidate = nickname
            .replacingOccurrences(of: "Credit Card", with: "")
            .replacingOccurrences(of: "Checking", with: "Checking")
            .replacingOccurrences(of: "Savings", with: "Savings")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let lowered = candidate.lowercased()

        if candidate.isEmpty ||
            lowered == "credit" ||
            lowered == "card" ||
            lowered == "credit account 2880" ||
            lowered == "depository account 1519" ||
            lowered == "depository account 1794" ||
            lowered == "checking" ||
            lowered == "savings" {
            return shortInstitutionName
        }

        return candidate
    }

    var utilization: Decimal? {
        guard accountType == .credit, let limit, limit > 0 else {
            return nil
        }

        return balance / limit
    }

    var updateDate: Date? {
        balanceLastUpdate ?? lastFetch ?? plaidLastSuccessfulUpdate ?? lastImport
    }
}

enum NormalizedAccountType: String, CaseIterable, Identifiable {
    case cash
    case credit
    case loan
    case investment
    case realEstate
    case other

    init(rawType: String) {
        switch rawType.lowercased() {
        case "cash", "depository":
            self = .cash
        case "credit":
            self = .credit
        case "loan":
            self = .loan
        case "investment":
            self = .investment
        case "real estate", "real_estate", "realestate":
            self = .realEstate
        default:
            self = .other
        }
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash: return "Depository"
        case .credit: return "Credit Cards"
        case .loan: return "Loans"
        case .investment: return "Investments"
        case .realEstate: return "Real Estate"
        case .other: return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .cash: return "banknote"
        case .credit: return "creditcard"
        case .loan: return "car.side"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .realEstate: return "house"
        case .other: return "tray.2"
        }
    }
}

extension KeyedDecodingContainer {
    func decodeDecimal(forKey key: Key) throws -> Decimal {
        if let stringValue = try? decode(String.self, forKey: key),
           let decimal = Decimal(string: stringValue) {
            return decimal
        }

        if let doubleValue = try? decode(Double.self, forKey: key) {
            return Decimal(doubleValue)
        }

        if let intValue = try? decode(Int.self, forKey: key) {
            return Decimal(intValue)
        }

        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Unable to decode decimal value.")
    }

    func decodeDecimalIfPresent(forKey key: Key) throws -> Decimal? {
        if let stringValue = try? decode(String.self, forKey: key),
           let decimal = Decimal(string: stringValue) {
            return decimal
        }

        if let doubleValue = try? decode(Double.self, forKey: key) {
            return Decimal(doubleValue)
        }

        if let intValue = try? decode(Int.self, forKey: key) {
            return Decimal(intValue)
        }

        return nil
    }

    func decodeFlexibleDateIfPresent(forKey key: Key) throws -> Date? {
        guard let value = try? decode(String.self, forKey: key) else {
            return nil
        }

        return LunchMoneyDateParser.parse(value)
    }
}

enum LunchMoneyDateParser {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        fractional.date(from: value) ?? plain.date(from: value)
    }
}

