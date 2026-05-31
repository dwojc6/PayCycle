import Foundation

struct CategoriesResponse: Decodable {
    let categories: [LunchMoneyCategory]
}

struct LunchMoneyCategory: Decodable, Identifiable {
    let id: Int
    let name: String
    let isIncome: Bool
    let excludeFromTotals: Bool

    private enum CodingKeys: String, CodingKey {
        case id, name
        case isIncome = "is_income"
        case excludeFromTotals = "exclude_from_totals"
    }
}
