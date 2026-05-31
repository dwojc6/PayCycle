import Foundation

struct BudgetSummaryResponse: Decodable {
    let aligned: Bool
    let categories: [BudgetSummaryCategory]
}

struct BudgetSummaryCategory: Decodable, Identifiable {
    let categoryId: Int
    let totals: BudgetSummaryTotals
    let occurrences: [BudgetSummaryOccurrence]?

    var id: Int { categoryId }

    private enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case totals
        case occurrences
    }
}

struct BudgetSummaryTotals: Decodable {
    let budgeted: Decimal?
    let available: Decimal?

    private enum CodingKeys: String, CodingKey {
        case budgeted
        case available
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        budgeted = try container.decodeDecimalIfPresent(forKey: .budgeted)
        available = try container.decodeDecimalIfPresent(forKey: .available)
    }
}

struct BudgetSummaryOccurrence: Decodable, Identifiable {
    let inRange: Bool
    let startDateString: String
    let endDateString: String
    let budgeted: Decimal?
    let budgetedAmount: Decimal?
    let budgetedCurrency: String?

    var id: String { "\(startDateString)-\(endDateString)" }

    var startDate: Date? {
        LunchMoneyTransaction.dateFormatter.date(from: startDateString)
    }

    var endDate: Date? {
        LunchMoneyTransaction.dateFormatter.date(from: endDateString)
    }

    private enum CodingKeys: String, CodingKey {
        case inRange = "in_range"
        case startDateString = "start_date"
        case endDateString = "end_date"
        case budgeted
        case budgetedAmount = "budgeted_amount"
        case budgetedCurrency = "budgeted_currency"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inRange = try container.decode(Bool.self, forKey: .inRange)
        startDateString = try container.decode(String.self, forKey: .startDateString)
        endDateString = try container.decode(String.self, forKey: .endDateString)
        budgeted = try container.decodeDecimalIfPresent(forKey: .budgeted)
        budgetedAmount = try container.decodeDecimalIfPresent(forKey: .budgetedAmount)
        budgetedCurrency = try container.decodeIfPresent(String.self, forKey: .budgetedCurrency)
    }
}
