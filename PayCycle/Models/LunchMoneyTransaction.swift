import Foundation

// MARK: - API Response

struct TransactionsResponse: Decodable {
    let transactions: [LunchMoneyTransaction]
    let hasMore: Bool

    private enum CodingKeys: String, CodingKey {
        case transactions
        case hasMore = "has_more"
    }
}

// MARK: - Transaction Model

struct LunchMoneyTransaction: Decodable, Identifiable, Hashable {
    let id: Int
    let date: String          // "2026-01-02" — kept as string for grouping
    let amount: Decimal
    let currency: String
    let toBase: Decimal?
    let payee: String
    let originalName: String?
    let categoryId: Int?
    let notes: String?
    let status: String?
    let isPending: Bool
    let plaidAccountId: Int?
    let manualAccountId: Int?
    let plaidMetadata: PlaidMetadata?
    let createdAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, date, amount, currency, payee, notes, status
        case toBase = "to_base"
        case originalName = "original_name"
        case categoryId = "category_id"
        case isPending = "is_pending"
        case plaidAccountId = "plaid_account_id"
        case manualAccountId = "manual_account_id"
        case plaidMetadata = "plaid_metadata"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(Int.self, forKey: .id)
        date          = try c.decode(String.self, forKey: .date)
        payee         = try c.decode(String.self, forKey: .payee)
        originalName  = try c.decodeIfPresent(String.self, forKey: .originalName)
        categoryId    = try c.decodeIfPresent(Int.self, forKey: .categoryId)
        notes         = try c.decodeIfPresent(String.self, forKey: .notes)
        status        = try c.decodeIfPresent(String.self, forKey: .status)
        isPending     = try c.decodeIfPresent(Bool.self, forKey: .isPending) ?? false
        plaidAccountId  = try c.decodeIfPresent(Int.self, forKey: .plaidAccountId)
        manualAccountId = try c.decodeIfPresent(Int.self, forKey: .manualAccountId)
        plaidMetadata   = try c.decodeIfPresent(PlaidMetadata.self, forKey: .plaidMetadata)
        currency      = try c.decodeIfPresent(String.self, forKey: .currency) ?? "usd"

        // Decode amount flexibly
        if let s = try? c.decode(String.self, forKey: .amount), let d = Decimal(string: s) {
            amount = d
        } else if let d = try? c.decode(Double.self, forKey: .amount) {
            amount = Decimal(d)
        } else {
            amount = .zero
        }

        if let s = try? c.decode(String.self, forKey: .toBase), let d = Decimal(string: s) {
            toBase = d
        } else if let d = try? c.decode(Double.self, forKey: .toBase) {
            toBase = Decimal(d)
        } else {
            toBase = nil
        }

        if let s = try? c.decode(String.self, forKey: .createdAt) {
            createdAt = LunchMoneyDateParser.parse(s)
        } else {
            createdAt = nil
        }
    }

    // MARK: - Display helpers

    /// Best human-readable name using Plaid metadata, falling back to payee
    var displayName: String {
        let name: String
        if let pm = plaidMetadata {
            if let merchant = pm.merchantName, !merchant.isEmpty {
                name = merchant
            } else if let cp = pm.counterparties?.first(where: { $0.type == "merchant" }) {
                name = cp.name
            } else if let cp = pm.counterparties?.first {
                name = cp.name
            } else {
                name = payee
            }
        } else {
            name = payee
        }

        if name.localizedCaseInsensitiveContains("Illinois Department of Revenue") {
            return "Florida Department of Revenue"
        }

        return name
    }

    /// Positive = expense (money out), negative = income (money in)
    var displayAmount: Decimal { toBase ?? amount }

    var isIncome: Bool { displayAmount < 0 }

    var parsedDate: Date? {
        LunchMoneyTransaction.dateFormatter.date(from: date)
    }

    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = .current
        return df
    }()
}

// MARK: - Plaid Metadata

struct PlaidMetadata: Decodable, Hashable {
    let merchantName: String?
    let counterparties: [Counterparty]?
    let logoUrl: String?

    private enum CodingKeys: String, CodingKey {
        case merchantName = "merchant_name"
        case counterparties
        case logoUrl = "logo_url"
    }
}

struct Counterparty: Decodable, Hashable {
    let name: String
    let type: String?
    let logoUrl: String?
    let website: String?

    private enum CodingKeys: String, CodingKey {
        case name, type
        case logoUrl = "logo_url"
        case website
    }
}

// MARK: - Paycheck Period

struct PaycheckPeriod: Identifiable {
    let id: String           // "2026-01-23"
    let startDate: Date
    let endDate: Date        // day before next paycheck (or today if current)
    let paycheckAmount: Decimal
    let transactions: [LunchMoneyTransaction]

    var label: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return "Pay Period · \(df.string(from: startDate))"
    }

    var totalSpent: Decimal {
        transactions.filter { !$0.isIncome }.reduce(.zero) { $0 + $1.displayAmount }
    }

    var totalIncome: Decimal {
        transactions.filter { $0.isIncome }.reduce(.zero) { $0 + abs($1.displayAmount) }
    }
}
