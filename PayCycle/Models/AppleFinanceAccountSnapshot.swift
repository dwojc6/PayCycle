import Foundation

struct AppleFinanceAccountSnapshot: Codable, Identifiable, Hashable {
    let id: UUID
    let displayName: String
    let institutionName: String
    let accountDescription: String?
    let currencyCode: String
    let kind: String
    let openingDate: Date?
    let bookedBalance: Decimal?
    let availableBalance: Decimal?
    let balanceAsOfDate: Date?
    let creditLimit: Decimal?
    let nextPaymentDueDate: Date?
    let minimumNextPaymentAmount: Decimal?
}

#if canImport(FinanceKit)
import FinanceKit

extension AppleFinanceAccountSnapshot {
    init(account: FinanceKit.Account, balance: FinanceKit.AccountBalance?) {
        switch account {
        case .asset(let asset):
            self.id = asset.id
            self.displayName = asset.displayName
            self.institutionName = asset.institutionName
            self.accountDescription = asset.accountDescription
            self.currencyCode = asset.currencyCode
            self.kind = "Asset"
            self.openingDate = asset.openingDate
            self.creditLimit = nil
            self.nextPaymentDueDate = nil
            self.minimumNextPaymentAmount = nil
        case .liability(let liability):
            self.id = liability.id
            self.displayName = liability.displayName
            self.institutionName = liability.institutionName
            self.accountDescription = liability.accountDescription
            self.currencyCode = liability.currencyCode
            self.kind = "Liability"
            self.openingDate = liability.openingDate
            self.creditLimit = liability.creditInformation.creditLimit?.amount
            self.nextPaymentDueDate = liability.creditInformation.nextPaymentDueDate
            self.minimumNextPaymentAmount = liability.creditInformation.minimumNextPaymentAmount?.amount
        @unknown default:
            self.id = UUID()
            self.displayName = "Unknown Account"
            self.institutionName = "Apple Wallet"
            self.accountDescription = nil
            self.currencyCode = balance?.currencyCode ?? "USD"
            self.kind = "Unknown"
            self.openingDate = nil
            self.creditLimit = nil
            self.nextPaymentDueDate = nil
            self.minimumNextPaymentAmount = nil
        }

        self.bookedBalance = balance?.booked?.amount.amount
        self.availableBalance = balance?.available?.amount.amount
        self.balanceAsOfDate = balance?.booked?.asOfDate ?? balance?.available?.asOfDate
    }
}
#endif
