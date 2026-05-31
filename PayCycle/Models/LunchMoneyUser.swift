import Foundation

struct LunchMoneyUser: Decodable {
    let id: Int
    let name: String
    let email: String
    let accountID: Int?
    let budgetName: String?
    let primaryCurrency: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case accountID = "account_id"
        case budgetName = "budget_name"
        case primaryCurrency = "primary_currency"
    }
}
