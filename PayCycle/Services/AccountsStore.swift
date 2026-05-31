import Foundation
import Observation

@MainActor
@Observable
final class AccountsStore {
    enum DataSource {
        case live

        var title: String {
            "Live Lunch Money"
        }
    }

    var accounts: [AnyAccount] = []
    var currentUser: LunchMoneyUser?
    var isLoading = false
    var errorMessage: String?
    var lastRefreshedAt: Date?
    var dataSource: DataSource = .live
    var hasSavedSimpleFINSetupURL = false
    var simpleFINErrorMessage: String?
    var transactions: [LunchMoneyTransaction] = []
    var categories: [LunchMoneyCategory] = []
    var isLoadingTransactions = false
    private(set) var paycheckPeriods: [PaycheckPeriod] = []
    private(set) var budgetSummaryByCategory: [Int: Decimal] = [:]
    private(set) var monthlyBudgetSummaries: [String: [Int: Decimal]] = [:]
    var budgetSummary: BudgetSummaryResponse?
    var budgetSummaryErrorMessage: String?
    var appleFinanceAccounts: [AppleFinanceAccountSnapshot] = []
    var appleFinanceTransactions: [AppleFinanceTransactionSnapshot] = []
    var appleFinanceLastSyncedAt: Date?
    var appleFinanceErrorMessage: String?
    var appleFinanceAuthorizationStatus = "Not determined"
    var isSyncingAppleFinance = false
    private(set) var transactionFingerprint: Int = 0

    private func updateTransactionFingerprint() {
        transactionFingerprint = transactions.reduce(0) { hash, txn in
            var h = hash
            h ^= txn.id.hashValue
            h ^= txn.isPending.hashValue
            h ^= txn.categoryId?.hashValue ?? 0
            h ^= txn.amount.hashValue
            return h
        }
    }

    // Dominion Energy paycheck category ID
    private let paycheckCategoryId = 2335420

    private func rebuildPaycheckPeriods() {
        let calendar = Calendar.current
        let today = Date()

        let paychecks = transactions
            .filter { $0.categoryId == paycheckCategoryId && $0.displayName.localizedCaseInsensitiveContains("Dominion") }
            .compactMap { t -> (date: Date, amount: Decimal)? in
                guard let d = t.parsedDate else { return nil }
                return (d, abs(t.displayAmount))
            }
            .sorted { $0.date < $1.date }

        guard !paychecks.isEmpty else {
            paycheckPeriods = []
            return
        }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        // Pre-parse all transaction dates once
        let txnsWithDates: [(txn: LunchMoneyTransaction, date: Date)] = transactions.compactMap { t in
            guard let d = t.parsedDate else { return nil }
            return (t, d)
        }

        var periods: [PaycheckPeriod] = []
        for (i, paycheck) in paychecks.enumerated() {
            let start = paycheck.date
            let end: Date = i + 1 < paychecks.count
                ? (calendar.date(byAdding: .day, value: -1, to: paychecks[i + 1].date) ?? today)
                : today

            let periodTxns = txnsWithDates
                .filter { $0.date >= start && $0.date <= end }
                .sorted { $0.date > $1.date }
                .map { $0.txn }

            periods.append(PaycheckPeriod(
                id: df.string(from: start),
                startDate: start,
                endDate: end,
                paycheckAmount: paycheck.amount,
                transactions: periodTxns
            ))
        }

        paycheckPeriods = periods.reversed()
    }

    func categoryName(for id: Int?) -> String? {
        guard let id else { return nil }
        return categories.first(where: { $0.id == id })?.name
    }

    func isPaycheckCategory(_ id: Int?) -> Bool {
        id == paycheckCategoryId
    }

    /// Returns the Lunch Money budgeted amount for a category within a pay period.
    ///
    /// Pay periods frequently span two calendar months (e.g. Apr 25 – May 24). Lunch Money
    /// budgets are configured per calendar month, so we check every month touched by the
    /// period and return the first month (preferring later months, which are more likely to
    /// have budgets set) that has a non-nil budget for this category.
    func defaultBudget(for categoryId: Int, in period: PaycheckPeriod) -> Decimal? {
        return defaultBudget(for: categoryId, from: period.startDate, to: period.endDate)
    }

    func defaultBudget(for categoryId: Int, from startDate: Date, to endDate: Date) -> Decimal? {
        let calendar = Calendar.current

        // Collect all calendar-month keys spanned by this period, newest first so that
        // a May budget is preferred over an April budget for an Apr 25 – May 24 period.
        var months: [String] = []
        var cursor = calendar.date(from: calendar.dateComponents([.year, .month], from: startDate)) ?? startDate
        while cursor <= endDate {
            months.append(monthKey(for: cursor))
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }

        // Return the first budget found, checking newest month first.
        for key in months.reversed() {
            if let budget = monthlyBudgetSummaries[key]?[categoryId] {
                return budget
            }
        }

        return nil
    }

    /// Legacy single-date overload — kept for any call sites that only have a point-in-time date.
    func defaultBudget(for categoryId: Int, on date: Date) -> Decimal? {
        return defaultBudget(for: categoryId, from: date, to: date)
    }
    
    func loadBudgetSummary(startDate: Date, endDate: Date) async {
        guard hasSavedToken else { return }
        guard let token = try? keychain.loadToken(), !token.isEmpty else { return }

        // Re-fetch each calendar month spanned by the given date range and update
        // monthlyBudgetSummaries so that defaultBudget(for:on:) always uses correct
        // per-month figures rather than a year-wide aggregated response.
        let calendar = Calendar.current
        var cursor = calendar.date(
            from: calendar.dateComponents([.year, .month], from: startDate)
        ) ?? startDate
        let formatter = LunchMoneyTransaction.dateFormatter

        while cursor <= endDate {
            let range = monthDateRange(containing: cursor)
            let key = monthKey(for: cursor)

            do {
                let summary = try await apiClient.fetchBudgetSummary(
                    apiKey: token,
                    startDate: formatter.string(from: range.start),
                    endDate: formatter.string(from: range.end)
                )
                let budgetedByCategory = Dictionary(
                    uniqueKeysWithValues: summary.categories.compactMap { category -> (Int, Decimal)? in
                        guard let budgeted = category.totals.budgeted else { return nil }
                        return (category.categoryId, budgeted)
                    }
                )
                monthlyBudgetSummaries[key] = budgetedByCategory
                budgetSummary = summary
                budgetSummaryByCategory = budgetedByCategory
                budgetSummaryErrorMessage = nil
            } catch {
                budgetSummaryErrorMessage = error.localizedDescription
            }

            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
    }

    var bankOfAmericaAccount: AnyAccount? {
        accounts.first { account in
            let haystack = [
                account.nickname,
                account.displayName ?? "",
                account.sourceLabel
            ].joined(separator: " ").lowercased()

            return haystack.contains("bank of america") || haystack.contains("bofa")
        }
    }

    var pendingTransactions: [LunchMoneyTransaction] {
        transactions
            .filter(\.isPending)
            .sorted { lhs, rhs in
                let leftDate = lhs.createdAt ?? lhs.parsedDate ?? .distantPast
                let rightDate = rhs.createdAt ?? rhs.parsedDate ?? .distantPast
                return leftDate > rightDate
            }
    }

    var bankOfAmericaPendingTransactions: [LunchMoneyTransaction] {
        guard let accountId = bankOfAmericaAccount?.plaidAccountId else { return [] }

        return pendingTransactions.filter { $0.plaidAccountId == accountId }
    }

    var bankOfAmericaPendingAdjustment: Decimal {
        guard let account = bankOfAmericaAccount else { return .zero }
        return pendingAdjustment(for: account)
    }

    var pendingAdjustedBankOfAmericaBalance: Decimal {
        guard let account = bankOfAmericaAccount else { return .zero }
        return displayedAmount(for: account)
    }

    func displayedAmount(for account: AnyAccount) -> Decimal {
        guard account.id == bankOfAmericaAccount?.id else {
            return account.amount
        }

        return account.amount + bankOfAmericaPendingAdjustment
    }

    private func pendingAdjustment(for account: AnyAccount) -> Decimal {
        let pendingTotal = bankOfAmericaPendingTransactions.reduce(.zero) { $0 + $1.displayAmount }

        switch account.accountType {
        case .credit, .loan:
            return pendingTotal
        default:
            return -pendingTotal
        }
    }
    
    func budgetedAmount(for categoryId: Int, on date: Date) -> Decimal? {
        let key = monthKey(for: date)
        return monthlyBudgetSummaries[key]?[categoryId]
    }

    func loadBudgetSummaryForMonth(containing date: Date) async {
        guard hasSavedToken else { return }
        guard let token = try? keychain.loadToken(), !token.isEmpty else { return }

        let key = monthKey(for: date)

        // Do not refetch if we already have this month.
        if monthlyBudgetSummaries[key] != nil {
            return
        }

        let range = monthDateRange(containing: date)
        let formatter = LunchMoneyTransaction.dateFormatter

        do {
            let summary = try await apiClient.fetchBudgetSummary(
                apiKey: token,
                startDate: formatter.string(from: range.start),
                endDate: formatter.string(from: range.end)
            )

            let budgetedByCategory = Dictionary(
                uniqueKeysWithValues: summary.categories.compactMap { category -> (Int, Decimal)? in
                    guard let budgeted = category.totals.budgeted else {
                        return nil
                    }

                    return (category.categoryId, budgeted)
                }
            )

            monthlyBudgetSummaries[key] = budgetedByCategory

            // Optional: keep these populated for older BudgetView code paths.
            budgetSummary = summary
            budgetSummaryByCategory = budgetedByCategory
            budgetSummaryErrorMessage = nil
        } catch {
            budgetSummaryErrorMessage = error.localizedDescription
        }
    }

    private func monthKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return String(format: "%04d-%02d", year, month)
    }

    private func monthDateRange(containing date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: components) ?? date

        let nextMonth = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        let end = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? start

        return (start, end)
    }

    func loadTransactionsIfNeeded() async {
        guard !isLoadingTransactions, transactions.isEmpty else { return }
        await reloadTransactions()
    }

    func reloadTransactions() async {
        guard hasSavedToken else {
            print("[Transactions] Skipping — no saved token")
            return
        }
        guard let token = try? keychain.loadToken(), !token.isEmpty else {
            print("[Transactions] Skipping — token load failed")
            return
        }
        isLoadingTransactions = true
        defer { isLoadingTransactions = false }

        let calendar = Calendar.current
        let today = Date()
        let year = calendar.component(.year, from: today)
        let currentMonth = calendar.component(.month, from: today)
        let startDate = "\(year)-01-01"
        let endDate = LunchMoneyTransaction.dateFormatter.string(from: today)

        print("[Transactions] Fetching \(startDate) to \(endDate)")

        do {
            async let txnFetch = apiClient.fetchTransactions(apiKey: token, startDate: startDate, endDate: endDate)
            async let catFetch = apiClient.fetchCategories(apiKey: token)
            let (txns, cats) = try await (txnFetch, catFetch)
            print("[Transactions] Fetched \(txns.count) transactions, \(cats.count) categories")
            transactions = txns.sorted { ($0.parsedDate ?? .distantPast) > ($1.parsedDate ?? .distantPast) }
            categories = cats
            updateTransactionFingerprint()
            rebuildPaycheckPeriods()
            print("[Transactions] Paycheck periods: \(paycheckPeriods.count)")

            // Fetch a budget summary for each calendar month from Jan through current month.
            // The Lunch Money /summary endpoint scopes budgeted amounts to the requested date
            // range, so we must request each month individually to get correct per-month figures.
            var newMonthlySummaries: [String: [Int: Decimal]] = [:]
            var latestSummary: BudgetSummaryResponse? = nil

            for month in 1...currentMonth {
                let monthComponents = DateComponents(year: year, month: month)
                guard let monthStart = calendar.date(from: monthComponents) else { continue }
                let range = monthDateRange(containing: monthStart)
                let formatter = LunchMoneyTransaction.dateFormatter
                let msStart = formatter.string(from: range.start)
                let msEnd = formatter.string(from: range.end)

                do {
                    let summary = try await apiClient.fetchBudgetSummary(
                        apiKey: token,
                        startDate: msStart,
                        endDate: msEnd
                    )
                    let key = monthKey(for: monthStart)
                    let budgetedByCategory = Dictionary(
                        uniqueKeysWithValues: summary.categories.compactMap { cat -> (Int, Decimal)? in
                            guard let b = cat.totals.budgeted else { return nil }
                            return (cat.categoryId, b)
                        }
                    )
                    newMonthlySummaries[key] = budgetedByCategory
                    latestSummary = summary
                    print("[Budget] Loaded summary for \(key): \(budgetedByCategory.count) categories with budgets")
                } catch {
                    print("[Budget] Failed to load summary for month \(month): \(error)")
                }
            }

            monthlyBudgetSummaries = newMonthlySummaries
            if let latest = latestSummary {
                budgetSummary = latest
            }
            budgetSummaryErrorMessage = nil
        } catch {
            print("[Transactions] Error: \(error)")
            budgetSummaryErrorMessage = error.localizedDescription
        }
    }
    var hasLoaded = false
    var hasSavedToken = false

    private let apiClient: LunchMoneyAPIClient
    private let simpleFINClient: SimpleFINAPIClient
    private let keychain: APIKeychain
    private let sampleLoader: SampleDataLoader
    private let appleFinanceAccountsKey = "appleFinanceAccounts"
    private let appleFinanceTransactionsKey = "appleFinanceTransactions"
    private let appleFinanceLastSyncedAtKey = "appleFinanceLastSyncedAt"

    init() {
        self.apiClient = LunchMoneyAPIClient()
        self.simpleFINClient = SimpleFINAPIClient()
        self.keychain = APIKeychain()
        self.sampleLoader = SampleDataLoader()
        self.hasSavedToken = (try? keychain.loadToken()) != nil
        self.hasSavedSimpleFINSetupURL = (try? keychain.loadSimpleFINSetupURL()) != nil
        loadAppleFinanceSnapshots()
    }

    init(
        apiClient: LunchMoneyAPIClient,
        simpleFINClient: SimpleFINAPIClient? = nil,
        keychain: APIKeychain,
        sampleLoader: SampleDataLoader
    ) {
        self.apiClient = apiClient
        self.simpleFINClient = simpleFINClient ?? SimpleFINAPIClient()
        self.keychain = keychain
        self.sampleLoader = sampleLoader
        self.hasSavedToken = (try? keychain.loadToken()) != nil
        self.hasSavedSimpleFINSetupURL = (try? keychain.loadSimpleFINSetupURL()) != nil
        loadAppleFinanceSnapshots()
    }

    var sections: [AccountSection] {
        let grouped = Dictionary(grouping: accounts) { $0.accountType }
        let order: [NormalizedAccountType] = [.credit, .cash, .investment, .loan, .realEstate, .other]

        return order.compactMap { type in
            guard let accounts = grouped[type], !accounts.isEmpty else { return nil }
            let sortedAccounts = accounts.sorted { lhs, rhs in
                let lhsAmount = displayedAmount(for: lhs)
                let rhsAmount = displayedAmount(for: rhs)

                if lhsAmount == rhsAmount { return lhs.nickname < rhs.nickname }
                return lhsAmount > rhsAmount
            }

            return AccountSection(
                type: type,
                accounts: sortedAccounts,
                total: sortedAccounts.reduce(into: Decimal.zero) { $0 += displayedAmount(for: $1) }
            )
        }
    }

    var snapshot: AccountsSnapshot {
        let assetTypes: Set<NormalizedAccountType> = [.cash, .investment, .realEstate, .other]
        let debtTypes: Set<NormalizedAccountType> = [.credit, .loan]

        let assets = accounts
            .filter { assetTypes.contains($0.accountType) }
            .reduce(into: Decimal.zero) { $0 += displayedAmount(for: $1) }

        let debt = accounts
            .filter { debtTypes.contains($0.accountType) }
            .reduce(into: Decimal.zero) { $0 += displayedAmount(for: $1) }

        return AccountsSnapshot(
            assets: assets,
            debt: debt,
            netWorth: assets - debt,
            sections: sections
        )
    }

    var activeAccountCount: Int {
        accounts.filter { $0.isActive }.count
    }

    func loadIfNeeded() async {
        guard !hasLoaded, hasSavedToken else { return }
        hasLoaded = true
        await reload()
    }

    func reload(triggerSync: Bool = false) async {
        guard hasSavedToken else {
            errorMessage = "Save a Lunch Money API token before refreshing."
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            guard let token = try keychain.loadToken()?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !token.isEmpty else {
                hasSavedToken = false
                errorMessage = "The saved Lunch Money API token could not be found."
                return
            }

            hasSavedToken = true

            async let userFetch = apiClient.fetchUser(apiKey: token)
            async let manualFetch = apiClient.fetchManualAccounts(apiKey: token)

            let plaidAccounts: [LunchMoneyPlaidAccount]
            if triggerSync, let synced = try await apiClient.syncPlaidAccounts(apiKey: token) {
                plaidAccounts = synced
            } else {
                plaidAccounts = try await apiClient.fetchPlaidAccounts(apiKey: token)
            }

            let (user, manualAccounts) = try await (userFetch, manualFetch)

            let simpleFINAccounts = await fetchSimpleFINAccountsIfConfigured()
            let merged = mergeAccounts(
                plaidAccounts: plaidAccounts,
                manualAccounts: manualAccounts,
                simpleFINAccounts: simpleFINAccounts
            )

            apply(accounts: merged, user: user, source: .live)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveToken(_ token: String) async {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            errorMessage = "Paste a Lunch Money API token before saving."
            return
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            async let userFetch = apiClient.fetchUser(apiKey: trimmedToken)
            async let plaidFetch = apiClient.fetchPlaidAccounts(apiKey: trimmedToken)
            async let manualFetch = apiClient.fetchManualAccounts(apiKey: trimmedToken)
            let (user, plaidAccounts, manualAccounts) = try await (userFetch, plaidFetch, manualFetch)
            let simpleFINAccounts = await fetchSimpleFINAccountsIfConfigured()
            let merged = mergeAccounts(
                plaidAccounts: plaidAccounts,
                manualAccounts: manualAccounts,
                simpleFINAccounts: simpleFINAccounts
            )
            try keychain.saveToken(trimmedToken)
            hasSavedToken = true
            hasLoaded = true
            apply(accounts: merged, user: user, source: .live)
        } catch {
            hasSavedToken = ((try? keychain.loadToken())?.isEmpty == false)
            errorMessage = error.localizedDescription
        }
    }

    func removeSavedToken() async {
        do {
            try keychain.deleteToken()
            accounts = []
            currentUser = nil
            lastRefreshedAt = nil
            errorMessage = nil
            simpleFINErrorMessage = nil
            hasLoaded = false
            hasSavedToken = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveSimpleFINSetupURL(_ setupURL: String) async {
        let trimmedURL = setupURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            simpleFINErrorMessage = "Paste a SimpleFIN setup URL before saving."
            return
        }

        do {
            _ = try await simpleFINClient.fetchAccounts(setupURL: trimmedURL)
            try keychain.saveSimpleFINSetupURL(trimmedURL)
            hasSavedSimpleFINSetupURL = true
            simpleFINErrorMessage = nil
            await reload()
        } catch {
            hasSavedSimpleFINSetupURL = ((try? keychain.loadSimpleFINSetupURL())?.isEmpty == false)
            simpleFINErrorMessage = error.localizedDescription
        }
    }

    func removeSimpleFINSetupURL() async {
        do {
            try keychain.deleteSimpleFINSetupURL()
            hasSavedSimpleFINSetupURL = false
            simpleFINErrorMessage = nil
            await reload()
        } catch {
            simpleFINErrorMessage = error.localizedDescription
        }
    }

    func clearAppleFinanceTransactions() {
        appleFinanceAccounts = []
        appleFinanceTransactions = []
        appleFinanceLastSyncedAt = nil
        appleFinanceErrorMessage = nil
        UserDefaults.standard.removeObject(forKey: appleFinanceAccountsKey)
        UserDefaults.standard.removeObject(forKey: appleFinanceTransactionsKey)
        UserDefaults.standard.removeObject(forKey: appleFinanceLastSyncedAtKey)
    }

    private func apply(accounts: [AnyAccount], user: LunchMoneyUser, source: DataSource) {
        self.accounts = accounts
        currentUser = user
        dataSource = source
        lastRefreshedAt = accounts.compactMap(\.updateDate).max() ?? .now
    }

    private func fetchSimpleFINAccountsIfConfigured() async -> [SimpleFINAccount] {
        guard let setupURL = try? keychain.loadSimpleFINSetupURL(),
              !setupURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            simpleFINErrorMessage = nil
            return []
        }

        do {
            let accounts = try await simpleFINClient.fetchAccounts(setupURL: setupURL)
            simpleFINErrorMessage = nil
            return accounts
        } catch {
            simpleFINErrorMessage = error.localizedDescription
            return []
        }
    }

    private func mergeAccounts(
        plaidAccounts: [LunchMoneyPlaidAccount],
        manualAccounts: [LunchMoneyManualAccount],
        simpleFINAccounts: [SimpleFINAccount]
    ) -> [AnyAccount] {
        let simpleFINWrapped = simpleFINAccounts.map { AnyAccount.simpleFIN($0) }
        let replacesDominionManual = simpleFINWrapped.contains { $0.replacesDominionManualAccount }
        let manualWrapped = manualAccounts
            .map { AnyAccount.manual($0) }
            .filter { account in
                !(replacesDominionManual && account.replacesDominionManualAccount)
            }

        return plaidAccounts.map { .plaid($0) } + manualWrapped + simpleFINWrapped
    }

    func saveAppleFinanceSnapshots() {
        do {
            let encoder = JSONEncoder()
            let encodedAccounts = try encoder.encode(appleFinanceAccounts)
            let encodedTransactions = try encoder.encode(appleFinanceTransactions)
            UserDefaults.standard.set(encodedAccounts, forKey: appleFinanceAccountsKey)
            UserDefaults.standard.set(encodedTransactions, forKey: appleFinanceTransactionsKey)
            UserDefaults.standard.set(appleFinanceLastSyncedAt, forKey: appleFinanceLastSyncedAtKey)
            appleFinanceErrorMessage = nil
        } catch {
            appleFinanceErrorMessage = error.localizedDescription
        }
    }

    private func loadAppleFinanceSnapshots() {
        if let data = UserDefaults.standard.data(forKey: appleFinanceAccountsKey),
           let decoded = try? JSONDecoder().decode([AppleFinanceAccountSnapshot].self, from: data) {
            appleFinanceAccounts = decoded
        }

        if let data = UserDefaults.standard.data(forKey: appleFinanceTransactionsKey),
           let decoded = try? JSONDecoder().decode([AppleFinanceTransactionSnapshot].self, from: data) {
            appleFinanceTransactions = decoded
        }

        appleFinanceLastSyncedAt = UserDefaults.standard.object(forKey: appleFinanceLastSyncedAtKey) as? Date
    }
}

extension AccountsStore {
    static var preview: AccountsStore {
        let store = AccountsStore()
        let plaid = (try? store.sampleLoader.loadAccounts()) ?? []
        store.accounts = plaid.map { .plaid($0) }
        store.currentUser = try? store.sampleLoader.loadUser()
        store.lastRefreshedAt = store.accounts.compactMap(\.updateDate).max() ?? .now
        store.dataSource = .live
        store.hasSavedToken = true
        store.hasLoaded = true
        return store
    }
}
