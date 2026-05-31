import Foundation

struct AccountSection: Identifiable {
    let type: NormalizedAccountType
    let accounts: [AnyAccount]
    let total: Decimal

    var id: String { type.rawValue }
}

struct AccountsSnapshot {
    let assets: Decimal
    let debt: Decimal
    let netWorth: Decimal
    let sections: [AccountSection]
}
