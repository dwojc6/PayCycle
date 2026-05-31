import Foundation

struct AppleFinanceTransactionSnapshot: Codable, Identifiable, Hashable {
    let id: UUID
    let accountID: UUID
    let transactionDate: Date
    let postedDate: Date?
    let amount: Decimal
    let currencyCode: String
    let merchantName: String?
    let transactionDescription: String
    let originalTransactionDescription: String
    let status: String
    let transactionType: String
    let creditDebitIndicator: String
    let merchantCategoryCode: String?

    var displayName: String {
        merchantName?.isEmpty == false ? merchantName! : transactionDescription
    }
}

#if canImport(FinanceKit)
import FinanceKit

extension AppleFinanceTransactionSnapshot {
    init(transaction: FinanceKit.Transaction) {
        self.id = transaction.id
        self.accountID = transaction.accountID
        self.transactionDate = transaction.transactionDate
        self.postedDate = transaction.postedDate
        self.amount = transaction.transactionAmount.amount
        self.currencyCode = transaction.transactionAmount.currencyCode
        self.merchantName = transaction.merchantName
        self.transactionDescription = transaction.transactionDescription
        self.originalTransactionDescription = transaction.originalTransactionDescription
        self.status = String(describing: transaction.status)
        self.transactionType = String(describing: transaction.transactionType)
        self.creditDebitIndicator = String(describing: transaction.creditDebitIndicator)
        self.merchantCategoryCode = transaction.merchantCategoryCode.map { String(describing: $0) }
    }
}
#endif
