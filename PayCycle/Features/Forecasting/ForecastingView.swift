import SwiftUI

struct ForecastingView: View {
    let store: AccountsStore
    let budgetStore: BudgetStore
    var headerHeight: CGFloat = 0
    var isScrollDisabled: Bool = false
    var onScrollOffsetChange: (CGFloat) -> Void = { _ in }
    var onScrollBottomDistanceChange: (CGFloat) -> Void = { _ in }
    var isActive: Bool = true

    @State private var paycheckText = ""
    @State private var selectedForecastRow: ForecastPeriodRow?
    @FocusState private var paycheckFocused: Bool

    private var currentPeriod: PaycheckPeriod? {
        store.paycheckPeriods.first
    }
    
    private var currentBudgetDate: Date {
        let today = Date()

        guard let period = currentPeriod else {
            return today
        }

        if today >= period.startDate && today <= period.endDate {
            return today
        }

        return period.endDate
    }

    private var trackedAccount: AnyAccount? {
        store.bankOfAmericaAccount
    }

    private var currentBalance: Decimal {
        store.pendingAdjustedBankOfAmericaBalance
    }

    private var currentSpending: ForecastCategoryTotals {
        guard let currentPeriod else { return .empty }
        return categoryTotals(for: currentBudgetDate, period: currentPeriod)
    }

    private var currentRemainingIncome: Decimal {
        guard let currentPeriod else { return .zero }
        return incomeBudgetTotal(on: currentBudgetDate, period: currentPeriod)
    }

    private var nextStartingBalance: Decimal {
        currentBalance - currentSpending.remaining + currentRemainingIncome
    }

    private var forecastRows: [ForecastPeriodRow] {
        guard let currentPeriod else { return [] }
        var rows: [ForecastPeriodRow] = []
        var rollingBalance = nextStartingBalance

        for period in futurePeriods(after: currentPeriod.startDate) {
            let spending = categoryTotals(for: period.startDate, period: nil).budgeted
            let additionalIncome = incomeBudgetTotal(on: period.startDate, period: nil)
            let income = budgetStore.expectedPaycheck + additionalIncome
            let ending = rollingBalance - spending + income

            rows.append(ForecastPeriodRow(
                id: period.id,
                startDate: period.startDate,
                endDate: period.endDate,
                beginningBalance: rollingBalance,
                forecastedSpending: spending,
                forecastedIncome: income,
                endingBalance: ending
            ))

            rollingBalance = ending
        }

        return rows
    }

    var body: some View {
        ZStack {
            Color.payCycleDeepNavy.ignoresSafeArea()

            GeometryReader { scrollGeo in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Color.clear
                            .frame(height: headerHeight)

                        if store.isLoadingTransactions && store.transactions.isEmpty {
                            loadingState
                        } else if trackedAccount == nil {
                            missingAccountState
                        } else if currentPeriod == nil {
                            missingPeriodState
                        } else {
                            balanceHeader
                            currentPeriodCard
                            forecastList
                        }

                        Spacer().frame(height: 32)
                    }
                    .background(alignment: .bottom) {
                        scrollBottomReader(viewportHeight: scrollGeo.size.height)
                    }
                    .overlay(alignment: .top) {
                        scrollOffsetReader
                    }
                }
                .coordinateSpace(name: "forecastingScroll")
                .refreshable {
                    await store.reload(triggerSync: true)
                    await store.reloadTransactions()
                    await loadForecastBudgetSummaries()
                }
                .scrollDisabled(isScrollDisabled)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        paycheckFocused = false
                    }
                )
            }
        }
        .task(id: currentPeriod?.id) {
            paycheckText = decimalText(budgetStore.expectedPaycheck)
            await loadForecastBudgetSummaries()
        }
        .onChange(of: paycheckFocused) { _, focused in
            if !focused {
                commitPaycheckAmount()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isActive && paycheckFocused {
                    Spacer()

                    Button("Done") {
                        paycheckFocused = false
                    }
                }
            }
        }
        .onChange(of: isActive) { _, active in
            if !active {
                paycheckFocused = false
            }
        }
        .sheet(item: $selectedForecastRow) { row in
            ForecastPeriodBudgetSheet(
                store: store,
                budgetStore: budgetStore,
                row: row
            )
        }
    }

    private var scrollOffsetReader: some View {
        Color.clear
            .frame(height: 1)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onChange(of: geo.frame(in: .named("forecastingScroll")).minY) { _, y in
                            onScrollOffsetChange(max(0, -y))
                        }
                        .onAppear {
                            onScrollOffsetChange(max(0, -geo.frame(in: .named("forecastingScroll")).minY))
                        }
                }
            )
    }

    private func updateScrollBottomDistance(_ distance: CGFloat) {
        onScrollBottomDistanceChange(max(0, distance))
    }

    private func scrollBottomReader(viewportHeight: CGFloat) -> some View {
        Color.clear
            .frame(height: 1)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onChange(of: geo.frame(in: .named("forecastingScroll")).maxY) { _, y in
                            updateScrollBottomDistance(y - viewportHeight)
                        }
                        .onAppear {
                            updateScrollBottomDistance(
                                geo.frame(in: .named("forecastingScroll")).maxY - viewportHeight
                            )
                        }
                }
            )
    }

    private var balanceHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bank of America")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(DisplayFormatter.currency(currentBalance, code: trackedAccount?.currency ?? "USD"))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("Expected paycheck")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))

                    HStack(spacing: 4) {
                        Text("$")
                            .foregroundStyle(.white.opacity(0.55))
                        TextField("4600", text: $paycheckText)
                            .focused($paycheckFocused)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 92)
                            .onSubmit { commitPaycheckAmount() }
                    }
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }
            }

            HStack(alignment: .top, spacing: 0) {
                ForecastMetric(title: "Remaining", value: DisplayFormatter.currency(currentSpending.remaining), color: Color.payCycleDanger)
                ForecastMetric(title: "Income Left", value: DisplayFormatter.currency(currentRemainingIncome), color: Color.payCycleSuccess)
                ForecastMetric(title: "Next Start", value: DisplayFormatter.currency(nextStartingBalance), color: nextStartingBalance >= 0 ? Color.payCycleSuccess : Color.payCycleDanger)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.payCycleCardNavy)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.payCyclePillBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 14)
    }

    private var currentPeriodCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let currentPeriod {
                HStack {
                    Text("CURRENT PERIOD")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                        .tracking(0.8)
                    Spacer()
                    Text(dateRange(start: currentPeriod.startDate, end: currentPeriod.endDate))
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 4)
            }

            ForEach(currentSpending.categories) { category in
                ForecastCategoryRow(category: category)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.payCycleDeepNavy)
            }
        }
    }

    private var forecastList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Forecast")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)

            ForEach(forecastRows) { row in
                ForecastPeriodCell(row: row)
                    .onTapGesture {
                        selectedForecastRow = row
                    }
            }
        }
        .padding(.top, 14)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color.payCycleSky)
            Text("Loading forecast data...")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var missingAccountState: some View {
        ForecastEmptyState(
            symbolName: "building.columns",
            title: "No Bank of America account",
            message: "The forecast uses the Bank of America account balance and still shows the rest of your accounts below."
        )
    }

    private var missingPeriodState: some View {
        ForecastEmptyState(
            symbolName: "calendar.badge.exclamationmark",
            title: "No paycheck periods yet",
            message: "Transactions need to load before paycheck-based forecasting can start."
        )
    }

    private func categoryTotals(for date: Date, period: PaycheckPeriod?) -> ForecastCategoryTotals {
        var spendingByCategory: [Int: Decimal] = [:]

        if let period {
            for transaction in period.transactions where !transaction.isIncome {
                guard let categoryId = transaction.categoryId else { continue }
                spendingByCategory[categoryId, default: .zero] += transaction.displayAmount
            }
        }

        let categories = store.categories
            .filter { !$0.isIncome }
            .filter { !budgetStore.isHidden($0.id) }
            .compactMap { category -> ForecastCategoryAmount? in
                let defaultBudget = store.defaultBudget(for: category.id, on: date)

                guard let budget = budgetStore.budget(
                    for: category.id,
                    periodId: period?.id,
                    periodStartDate: date,
                    defaultBudget: defaultBudget
                ) else {
                    return nil
                }

                let spent = spendingByCategory[category.id] ?? .zero

                return ForecastCategoryAmount(
                    category: category,
                    budgeted: budget,
                    spent: spent
                )
            }
            .sorted { $0.remaining > $1.remaining }

        return ForecastCategoryTotals(categories: categories)
    }

    private func incomeBudgetTotal(on date: Date, period: PaycheckPeriod?) -> Decimal {
        var incomeByCategory: [Int: Decimal] = [:]

        if let period {
            for transaction in period.transactions where transaction.isIncome {
                guard let categoryId = transaction.categoryId,
                      !store.isPaycheckCategory(categoryId) else {
                    continue
                }

                incomeByCategory[categoryId, default: .zero] += abs(transaction.displayAmount)
            }
        }

        return store.categories
            .filter { $0.isIncome && !store.isPaycheckCategory($0.id) }
            .filter { !budgetStore.isHidden($0.id) }
            .reduce(.zero) { total, category in
                let defaultBudget = store.budgetedAmount(for: category.id, on: date)
                guard let budget = budgetStore.budget(
                    for: category.id,
                    periodId: period?.id,
                    periodStartDate: date,
                    defaultBudget: defaultBudget
                ) else {
                    return total
                }

                let received = incomeByCategory[category.id] ?? .zero
                return total + max(budget - received, .zero)
            }
    }
    
    private func loadForecastBudgetSummaries() async {
        guard let currentPeriod else { return }

        await store.loadBudgetSummaryForMonth(containing: currentBudgetDate)

        for period in futurePeriods(after: currentPeriod.startDate) {
            await store.loadBudgetSummaryForMonth(containing: period.startDate)
        }
    }

    private func futurePeriods(after currentStartDate: Date) -> [ForecastPeriodDateRange] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: currentStartDate)
        let currentMonth = calendar.component(.month, from: currentStartDate)
        var starts: [Date] = []

        guard currentMonth < 12 else { return [] }

        for month in (currentMonth + 1)...12 {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 25
            if let date = calendar.date(from: components) {
                starts.append(date)
            }
        }

        return starts.enumerated().compactMap { index, start in
            let end: Date
            if index + 1 < starts.count {
                end = calendar.date(byAdding: .day, value: -1, to: starts[index + 1]) ?? start
            } else {
                var components = DateComponents()
                components.year = year
                components.month = 12
                components.day = 31
                end = calendar.date(from: components) ?? start
            }

            return ForecastPeriodDateRange(startDate: start, endDate: end)
        }
    }

    private func commitPaycheckAmount() {
        guard let amount = Decimal(string: paycheckText), amount >= 0 else {
            paycheckText = decimalText(budgetStore.expectedPaycheck)
            return
        }
        budgetStore.expectedPaycheck = amount
    }

    private func decimalText(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private func dateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

private struct ForecastCategoryTotals {
    let categories: [ForecastCategoryAmount]

    static let empty = ForecastCategoryTotals(categories: [])

    var budgeted: Decimal {
        categories.reduce(.zero) { $0 + $1.budgeted }
    }

    var spent: Decimal {
        categories.reduce(.zero) { $0 + $1.spent }
    }

    var remaining: Decimal {
        categories.reduce(.zero) { $0 + $1.remaining }
    }
}

private struct ForecastCategoryAmount: Identifiable {
    let category: LunchMoneyCategory
    let budgeted: Decimal
    let spent: Decimal

    var id: Int { category.id }
    var remaining: Decimal { max(budgeted - spent, .zero) }
}

private struct ForecastPeriodDateRange: Identifiable {
    let startDate: Date
    let endDate: Date

    var id: String {
        let formatter = LunchMoneyTransaction.dateFormatter
        return formatter.string(from: startDate)
    }
}

private struct ForecastPeriodRow: Identifiable {
    let id: String
    let startDate: Date
    let endDate: Date
    let beginningBalance: Decimal
    let forecastedSpending: Decimal
    let forecastedIncome: Decimal
    let endingBalance: Decimal
}

private struct ForecastMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ForecastCategoryRow: View {
    let category: ForecastCategoryAmount

    private var progress: Double {
        guard category.budgeted > 0 else { return 0 }
        return min(Double(truncating: (category.spent / category.budgeted) as NSDecimalNumber), 1)
    }

    private var progressColor: Color {
        if category.spent < category.budgeted {
            return Color.payCycleSuccess
        }

        if category.spent == category.budgeted {
            return Color.payCycleBlue
        }

        return Color.payCycleDanger
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(category.category.name)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Text(DisplayFormatter.currency(category.remaining))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(category.remaining > 0 ? Color.payCycleSuccess : Color.payCycleDanger)
            }

            HStack(spacing: 8) {
                Text(DisplayFormatter.currency(category.spent))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 74, alignment: .leading)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(progressColor)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 7)

                Text(DisplayFormatter.currency(category.budgeted))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 74, alignment: .trailing)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
    }
}

private struct ForecastPeriodCell: View {
    let row: ForecastPeriodRow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(periodTitle)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text(periodRange)
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                }

                Spacer()

                Text(DisplayFormatter.currency(row.endingBalance))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(row.endingBalance >= 0 ? Color.payCycleSuccess : Color.payCycleDanger)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.28))
            }

            HStack(spacing: 0) {
                ForecastMetric(title: "Begin", value: DisplayFormatter.currency(row.beginningBalance), color: .white.opacity(0.78))
                ForecastMetric(title: "Spending", value: DisplayFormatter.currency(row.forecastedSpending), color: Color.payCycleDanger)
                ForecastMetric(title: "Income", value: DisplayFormatter.currency(row.forecastedIncome), color: Color.payCycleSuccess)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.payCycleCardNavy)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.payCyclePillBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private var periodTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Pay Period - \(formatter.string(from: row.startDate))"
    }

    private var periodRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: row.startDate)) - \(formatter.string(from: row.endDate))"
    }
}

// MARK: - Apply Scope

private enum BudgetApplyScope {
    case thisPeriodOnly
    case thisAndFuture
}

// MARK: - ForecastPeriodBudgetSheet

private struct ForecastPeriodBudgetSheet: View {
    let store: AccountsStore
    let budgetStore: BudgetStore
    let row: ForecastPeriodRow

    @Environment(\.dismiss) private var dismiss
    @State private var amountTexts: [Int: String] = [:]
    @State private var applyToFuture = false

    private var budgetRows: [ForecastEditableBudgetRow] {
        store.categories
            .filter { !$0.isIncome }
            .filter { !budgetStore.isHidden($0.id) }
            .compactMap { category in
                let defaultBudget = store.defaultBudget(for: category.id, on: row.startDate)
                guard let budget = budgetStore.budget(
                    for: category.id,
                    periodId: nil,
                    periodStartDate: row.startDate,
                    defaultBudget: defaultBudget
                ) else {
                    return nil
                }

                return ForecastEditableBudgetRow(category: category, budget: budget)
            }
            .sorted {
                if $0.budget != $1.budget {
                    return $0.budget > $1.budget
                }

                return $0.category.name < $1.category.name
            }
    }

    private var incomeRows: [ForecastEditableBudgetRow] {
        store.categories
            .filter { $0.isIncome && !store.isPaycheckCategory($0.id) }
            .filter { !budgetStore.isHidden($0.id) }
            .map { category in
                let defaultBudget = store.budgetedAmount(for: category.id, on: row.startDate)
                let budget = budgetStore.budget(
                    for: category.id,
                    periodId: nil,
                    periodStartDate: row.startDate,
                    defaultBudget: defaultBudget
                ) ?? .zero

                return ForecastEditableBudgetRow(category: category, budget: budget)
            }
            .sorted {
                if $0.budget != $1.budget {
                    return $0.budget > $1.budget
                }

                return $0.category.name < $1.category.name
            }
    }

    private var editedTotal: Decimal {
        budgetRows.reduce(.zero) { total, row in
            guard let amount = Decimal(string: amountTexts[row.id] ?? "") else {
                return total + row.budget
            }

            return total + amount
        }
    }

    private var editedIncomeTotal: Decimal {
        incomeRows.reduce(.zero) { total, row in
            guard let amount = Decimal(string: amountTexts[row.id] ?? "") else {
                return total + row.budget
            }

            return total + amount
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.payCycleDeepNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Forecast Budgets")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(periodRange)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(.white.opacity(0.48))
                    }

                    Spacer()

                    Button("Save") {
                        saveBudgets(applyToFuture: applyToFuture)
                        dismiss()
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.payCycleBlue)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)

                HStack {
                    ForecastEditSummaryMetric(
                        title: "Forecast spending",
                        value: DisplayFormatter.currency(editedTotal),
                        color: Color.payCycleDanger
                    )
                    ForecastEditSummaryMetric(
                        title: "Forecast income",
                        value: DisplayFormatter.currency(editedIncomeTotal),
                        color: Color.payCycleSuccess
                    )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.payCycleCardNavy)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                Toggle(isOn: $applyToFuture) {
                    Text("Apply to future periods")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .toggleStyle(.switch)
                .tint(Color.payCycleBlue)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if !incomeRows.isEmpty {
                            ForecastEditableSectionHeader(title: "INCOME")

                            ForEach(incomeRows) { row in
                                ForecastEditableBudgetRowView(
                                    row: row,
                                    amountText: binding(for: row)
                                )
                            }
                        }

                        if !budgetRows.isEmpty {
                            ForecastEditableSectionHeader(title: "SPENDING")
                        }

                        ForEach(budgetRows) { row in
                            ForecastEditableBudgetRowView(
                                row: row,
                                amountText: binding(for: row)
                            )
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear(perform: populateAmountTexts)
    }

    private var periodRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return "\(formatter.string(from: row.startDate)) - \(formatter.string(from: row.endDate))"
    }

    private func binding(for row: ForecastEditableBudgetRow) -> Binding<String> {
        Binding(
            get: { amountTexts[row.id] ?? decimalText(row.budget) },
            set: { amountTexts[row.id] = $0 }
        )
    }

    private func populateAmountTexts() {
        amountTexts = Dictionary(
            uniqueKeysWithValues: (incomeRows + budgetRows).map { row in
                (row.id, decimalText(row.budget))
            }
        )
    }

    private func saveBudgets(applyToFuture: Bool) {
        for row in incomeRows + budgetRows {
            let text = amountTexts[row.id] ?? decimalText(row.budget)
            guard let amount = Decimal(string: text), amount >= 0 else { continue }

            budgetStore.setBudget(
                amount,
                for: row.id,
                periodId: nil,
                effectiveDate: self.row.startDate,
                applyToFuture: applyToFuture
            )
        }
    }

    private func decimalText(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}

private struct ForecastEditSummaryMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ForecastEditableSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundStyle(.white.opacity(0.35))
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }
}

private struct ForecastEditableBudgetRow: Identifiable {
    let category: LunchMoneyCategory
    let budget: Decimal

    var id: Int { category.id }
}

private struct ForecastEditableBudgetRowView: View {
    let row: ForecastEditableBudgetRow
    @Binding var amountText: String

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.category.name)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("Current: \(DisplayFormatter.currency(row.budget))")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            HStack(spacing: 4) {
                Text("$")
                    .foregroundStyle(.white.opacity(0.45))
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 92)
                    .foregroundStyle(.white)
                    .tint(Color.payCycleSky)
            }
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

private struct ForecastEmptyState: View {
    let symbolName: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbolName)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.white.opacity(0.4))

            Text(title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 60)
    }
}

#Preview {
    ForecastingView(store: AccountsStore.preview, budgetStore: BudgetStore())
}
