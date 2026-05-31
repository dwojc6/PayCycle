import Foundation

#if canImport(FinanceKit)
import FinanceKit

extension AccountsStore {
    func refreshAppleFinanceData() async {
        isSyncingAppleFinance = true
        appleFinanceErrorMessage = nil

        defer { isSyncingAppleFinance = false }

        do {
            let store = FinanceStore.shared
            let status = try await store.requestAuthorization()
            appleFinanceAuthorizationStatus = String(describing: status)

            guard status == .authorized else {
                appleFinanceErrorMessage = "FinanceKit access was not authorized."
                return
            }

            let accounts = try await store.accounts(
                query: AccountQuery(sortDescriptors: [], predicate: nil, limit: nil, offset: nil)
            )
            let balances = try await store.accountBalances(
                query: AccountBalanceQuery(sortDescriptors: [], predicate: nil, limit: nil, offset: nil)
            )
            let transactions = try await store.transactions(
                query: TransactionQuery(
                    sortDescriptors: [SortDescriptor(\.transactionDate, order: .reverse)],
                    predicate: nil,
                    limit: 500,
                    offset: nil
                )
            )

            let balancesByAccountID = Dictionary(uniqueKeysWithValues: balances.map { ($0.accountID, $0) })

            appleFinanceAccounts = accounts
                .map { account in
                    AppleFinanceAccountSnapshot(account: account, balance: balancesByAccountID[account.id])
                }
                .sorted { $0.displayName < $1.displayName }

            appleFinanceTransactions = transactions
                .map(AppleFinanceTransactionSnapshot.init(transaction:))
                .sorted { $0.transactionDate > $1.transactionDate }

            appleFinanceLastSyncedAt = .now
            saveAppleFinanceSnapshots()
        } catch {
            appleFinanceErrorMessage = error.localizedDescription
        }
    }
}
#endif
