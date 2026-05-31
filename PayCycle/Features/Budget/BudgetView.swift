import SwiftUI

struct BudgetView: View {
    let store: AccountsStore
    let budgetStore: BudgetStore
    var headerHeight: CGFloat = 0
    var isScrollDisabled: Bool = false
    @Binding var showPeriodPicker: Bool
    var onScrollOffsetChange: (CGFloat) -> Void = { _ in }
    var onScrollBottomDistanceChange: (CGFloat) -> Void = { _ in }

    @State private var selectedPeriodIndex: Int = 0
    @State private var editingCategory: LunchMoneyCategory? = nil

    private var periods: [PaycheckPeriod] { store.paycheckPeriods }

    private var selectedPeriod: PaycheckPeriod? {
        guard !periods.isEmpty, periods.indices.contains(selectedPeriodIndex) else { return nil }
        return periods[selectedPeriodIndex]
    }

    @State private var categorySpending: [Int: Decimal] = [:]
    @State private var categoryIncome: [Int: Decimal] = [:]
    @State private var displayCategories: [LunchMoneyCategory] = []
    @State private var displayIncomeCategories: [LunchMoneyCategory] = []
    @State private var hiddenCategories: [LunchMoneyCategory] = []

    private func recomputeSpending() {
        guard let period = selectedPeriod else {
            categorySpending = [:]
            categoryIncome = [:]
            displayCategories = []
            displayIncomeCategories = []
            return
        }

        var spending: [Int: Decimal] = [:]
        var income: [Int: Decimal] = [:]

        for txn in period.transactions where !txn.isIncome {
            guard let cid = txn.categoryId else { continue }
            spending[cid, default: .zero] += txn.displayAmount
        }

        for txn in period.transactions where txn.isIncome {
            guard let cid = txn.categoryId,
                  !store.isPaycheckCategory(cid) else {
                continue
            }

            income[cid, default: .zero] += abs(txn.displayAmount)
        }

        categorySpending = spending
        categoryIncome = income

        let hiddenIds = budgetStore.hiddenCategoryIds

        displayCategories = store.categories
            .filter { !$0.isIncome }
            .filter { !hiddenIds.contains($0.id) }
            .filter { category in
                let defaultBudget = store.defaultBudget(for: category.id, in: period)

                return spending[category.id] != nil ||
                budgetStore.budget(
                    for: category.id,
                    periodId: period.id,
                    periodStartDate: period.startDate,
                    defaultBudget: defaultBudget
                ) != nil
            }
            .sorted { left, right in
                let leftSpent = spending[left.id] ?? .zero
                let rightSpent = spending[right.id] ?? .zero

                if leftSpent != rightSpent {
                    return leftSpent > rightSpent
                }

                let leftBudget = budgetAmount(for: left, period: period) ?? .zero
                let rightBudget = budgetAmount(for: right, period: period) ?? .zero

                return leftBudget > rightBudget
            }

        displayIncomeCategories = store.categories
            .filter { $0.isIncome && !store.isPaycheckCategory($0.id) }
            .filter { !hiddenIds.contains($0.id) }
            .sorted { left, right in
                let leftReceived = income[left.id] ?? .zero
                let rightReceived = income[right.id] ?? .zero

                if leftReceived != rightReceived {
                    return leftReceived > rightReceived
                }

                let leftBudget = budgetAmount(for: left, period: period) ?? .zero
                let rightBudget = budgetAmount(for: right, period: period) ?? .zero

                return leftBudget > rightBudget
            }

        hiddenCategories = store.categories
            .filter { budgetStore.hiddenCategoryIds.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        ZStack {
            Color.payCycleDeepNavy.ignoresSafeArea()
            
            if periods.isEmpty {
                emptyState
            } else {
                GeometryReader { scrollGeo in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            scrollOffsetReader
                            Color.clear.frame(height: headerHeight)
                        
                            // Period summary header
                            if let period = selectedPeriod {
                                PeriodSummaryHeader(
                                    period: period,
                                    totalBudgeted: totalBudgeted,
                                    totalSpent: totalSpent
                                )
                            }
                        
                            // Category rows
                            if displayCategories.isEmpty && displayIncomeCategories.isEmpty {
                                Text("No spending this period")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 40)
                            } else if let period = selectedPeriod {
                                if !displayIncomeCategories.isEmpty {
                                    Text("INCOME")
                                        .font(.system(.caption2, design: .rounded, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.35))
                                        .tracking(0.8)
                                        .padding(.horizontal, 20)
                                        .padding(.top, 12)
                                        .padding(.bottom, 2)

                                    ForEach(displayIncomeCategories) { category in
                                        CategoryBudgetRow(
                                            category: category,
                                            spent: categoryIncome[category.id] ?? .zero,
                                            budget: budgetAmount(for: category, period: period)
                                        )
                                        .onTapGesture { editingCategory = category }
                                    }
                                }

                                if !displayCategories.isEmpty {
                                    Text("SPENDING")
                                        .font(.system(.caption2, design: .rounded, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.35))
                                        .tracking(0.8)
                                        .padding(.horizontal, 20)
                                        .padding(.top, 12)
                                        .padding(.bottom, 2)
                                }

                                ForEach(displayCategories) { category in
                                    CategoryBudgetRow(
                                        category: category,
                                        spent: categorySpending[category.id] ?? .zero,
                                        budget: budgetAmount(for: category, period: period)
                                    )
                                    .onTapGesture { editingCategory = category }
                                }

                                if !hiddenCategories.isEmpty {
                                    Text("HIDDEN")
                                        .font(.system(.caption2, design: .rounded, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.2))
                                        .tracking(0.8)
                                        .padding(.horizontal, 20)
                                        .padding(.top, 12)
                                        .padding(.bottom, 2)

                                    ForEach(hiddenCategories) { category in
                                        HStack {
                                            Text(category.name)
                                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                                .foregroundStyle(.white.opacity(0.25))
                                            Spacer()
                                            Image(systemName: "eye.slash")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.white.opacity(0.2))
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(Color.payCycleDeepNavy)
                                        .contentShape(Rectangle())
                                        .onTapGesture { editingCategory = category }
                                    }
                                }
                            }
                            
                            Spacer().frame(height: 100)
                        }
                        .background(alignment: .bottom) {
                            scrollBottomReader(viewportHeight: scrollGeo.size.height)
                        }
                    }
                    .coordinateSpace(name: "budgetScroll")
                    .refreshable {
                        await store.reloadTransactions()

                        if let period = selectedPeriod {
                            await store.loadBudgetSummary(
                                startDate: period.startDate,
                                endDate: period.endDate
                            )
                        }

                        recomputeSpending()
                    }
                    .scrollDisabled(isScrollDisabled)
                }
            }
            
        }
        .task(id: selectedPeriodIndex) {
            if let period = selectedPeriod {
                await store.loadBudgetSummary(
                    startDate: period.startDate,
                    endDate: period.endDate
                )
            }

            recomputeSpending()
        }
        .onChange(of: store.transactionFingerprint) { _, _ in
            Task {
                if let period = selectedPeriod {
                    await store.loadBudgetSummary(
                        startDate: period.startDate,
                        endDate: period.endDate
                    )
                }
                recomputeSpending()
            }
        }
        .sheet(item: $editingCategory) { category in
            SetBudgetSheet(
                category: category,
                currentBudget: selectedPeriod.map {
                    budgetAmount(for: category, period: $0)
                } ?? budgetStore.budget(for: category.id),
                actual: category.isIncome
                    ? categoryIncome[category.id] ?? .zero
                    : categorySpending[category.id] ?? .zero,
                isHidden: budgetStore.isHidden(category.id)
            ) { newAmount, applyToFuture in
                if let amount = newAmount {
                    budgetStore.setBudget(
                        amount,
                        for: category.id,
                        periodId: selectedPeriod?.id,
                        effectiveDate: selectedPeriod?.startDate,
                        applyToFuture: applyToFuture
                    )
                } else {
                    budgetStore.removeBudget(
                        for: category.id,
                        periodId: selectedPeriod?.id,
                        effectiveDate: selectedPeriod?.startDate,
                        applyToFuture: applyToFuture
                    )
                }
                recomputeSpending()
            } onHide: { shouldHide in
                budgetStore.setHidden(shouldHide, for: category.id)
                recomputeSpending()
            }
        }
        .sheet(isPresented: $showPeriodPicker) {
            PeriodPickerSheet(
                periods: periods,
                selectedIndex: $selectedPeriodIndex
            )
        }
    }

    private var scrollOffsetReader: some View {
        Color.clear
            .frame(height: 1)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onChange(of: geo.frame(in: .named("budgetScroll")).minY) { _, y in
                            onScrollOffsetChange(max(0, -y))
                        }
                        .onAppear {
                            onScrollOffsetChange(max(0, -geo.frame(in: .named("budgetScroll")).minY))
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
                        .onChange(of: geo.frame(in: .named("budgetScroll")).maxY) { _, y in
                            updateScrollBottomDistance(y - viewportHeight)
                        }
                        .onAppear {
                            updateScrollBottomDistance(
                                geo.frame(in: .named("budgetScroll")).maxY - viewportHeight
                            )
                        }
                }
            )
    }

    private var totalBudgeted: Decimal {
        guard let selectedPeriod else { return .zero }
        return displayCategories.reduce(.zero) { $0 + (budgetAmount(for: $1, period: selectedPeriod) ?? .zero) }
    }

    private var totalSpent: Decimal {
        displayCategories.reduce(.zero) { $0 + (categorySpending[$1.id] ?? .zero) }
    }

    private func budgetAmount(for category: LunchMoneyCategory, period: PaycheckPeriod) -> Decimal? {
        let defaultBudget = store.defaultBudget(for: category.id, in: period)

        return budgetStore.budget(
            for: category.id,
            periodId: period.id,
            periodStartDate: period.startDate,
            defaultBudget: defaultBudget
        )
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.white.opacity(0.4))

            Text("No budget data yet")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)

            Text("Transactions need to load before budgets can be shown.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, headerHeight + 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Period Summary Header

private struct PeriodSummaryHeader: View {
    let period: PaycheckPeriod
    let totalBudgeted: Decimal
    let totalSpent: Decimal

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text(period.label)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(alignment: .top, spacing: 0) {
                HeaderMetric(title: "Budgeted", value: DisplayFormatter.currency(totalBudgeted), color: Color.payCycleSuccess)
                HeaderMetric(title: "Spent", value: DisplayFormatter.currency(totalSpent), color: .white)
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
        .padding(.bottom, 12)
        .background(Color.payCycleDeepNavy)
    }

}

private struct HeaderMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Category Budget Row

private struct CategoryBudgetRow: View {
    let category: LunchMoneyCategory
    let spent: Decimal
    let budget: Decimal?

    private static let currencyRoundingBehavior = NSDecimalNumberHandler(
        roundingMode: .plain,
        scale: 2,
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false
    )

    private var roundedSpent: Decimal {
        roundedToCents(spent)
    }

    private var roundedBudget: Decimal? {
        budget.map(roundedToCents)
    }

    private var progress: Double {
        guard let roundedBudget, roundedBudget > 0 else { return 0 }
        return min(Double(truncating: (roundedSpent / roundedBudget) as NSDecimalNumber), 1.0)
    }

    private var isOverBudget: Bool {
        guard let roundedBudget else { return false }
        return roundedSpent > roundedBudget
    }

    private var progressColor: Color {
        guard let roundedBudget else { return Color.payCycleBlue }

        if roundedSpent < roundedBudget {
            return Color.payCycleSuccess
        }

        if roundedSpent == roundedBudget {
            return Color.payCycleBlue
        }

        return Color.payCycleDanger
    }

    private func roundedToCents(_ value: Decimal) -> Decimal {
        NSDecimalNumber(decimal: value)
            .rounding(accordingToBehavior: Self.currencyRoundingBehavior)
            .decimalValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(category.name)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                if budget == nil {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.payCycleSky.opacity(0.6))
                }
            }

            if let budget {
                HStack(spacing: 10) {
                    Text(DisplayFormatter.currency(spent))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(isOverBudget ? Color.payCycleDanger : .white)
                        .frame(width: 74, alignment: .leading)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(progressColor)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 7)

                    Text(DisplayFormatter.currency(budget))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 74, alignment: .trailing)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            } else {
                Text("No budget set")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.payCycleDeepNavy)
        .contentShape(Rectangle())
    }
}

// MARK: - Set Budget Sheet

private struct SetBudgetSheet: View {
    let category: LunchMoneyCategory
    let currentBudget: Decimal?
    let actual: Decimal
    let isHidden: Bool
    let onSave: (Decimal?, Bool) -> Void
    let onHide: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String = ""
    @State private var applyToFuture = false
    @FocusState private var focused: Bool

    init(category: LunchMoneyCategory, currentBudget: Decimal?, actual: Decimal, isHidden: Bool, onSave: @escaping (Decimal?, Bool) -> Void, onHide: @escaping (Bool) -> Void) {
        self.category = category
        self.currentBudget = currentBudget
        self.actual = actual
        self.isHidden = isHidden
        self.onSave = onSave
        self.onHide = onHide
        if let b = currentBudget {
            _amountText = State(initialValue: "\(b)")
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.payCycleDeepNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                Text(category.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                Text("\(actualLabel): \(DisplayFormatter.currency(actual))")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    .padding(.bottom, 32)

                // Amount input
                VStack(alignment: .leading, spacing: 8) {
                    Text(amountLabel)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.horizontal, 4)

                    HStack {
                        Text("$")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))

                        TextField("0.00", text: $amountText)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .tint(Color.payCycleSky)
                            .keyboardType(.decimalPad)
                            .focused($focused)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.payCycleCardNavy)
                    )
                }
                .padding(.horizontal, 20)

                Toggle(isOn: $applyToFuture) {
                    Text("Apply to future periods")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .toggleStyle(.switch)
                .tint(Color.payCycleBlue)
                .padding(.horizontal, 20)
                .padding(.top, 18)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        if let amount = Decimal(string: amountText), amount >= 0 {
                            onSave(amount, applyToFuture)
                        }
                        dismiss()
                    } label: {
                        Text(saveButtonTitle)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.payCycleBlue)
                            )
                    }

                    if currentBudget != nil {
                        Button {
                            onSave(nil, applyToFuture)
                            dismiss()
                        } label: {
                            Text(removeButtonTitle)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(Color.payCycleDanger)
                        }
                    }

                    Button {
                        onHide(!isHidden)
                        dismiss()
                    } label: {
                        Text(isHidden ? "Unhide category" : "Hide category")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .onAppear { focused = true }
    }

    private var actualLabel: String {
        category.isIncome ? "Received this period" : "Spent this period"
    }

    private var amountLabel: String {
        category.isIncome ? "Expected income per pay period" : "Budget per pay period"
    }

    private var saveButtonTitle: String {
        category.isIncome ? "Save Income" : "Save Budget"
    }

    private var removeButtonTitle: String {
        category.isIncome ? "Remove Income" : "Remove Budget"
    }
}

// MARK: - Period Picker Sheet

private struct PeriodPickerSheet: View {
    let periods: [PaycheckPeriod]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color.payCycleDeepNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                Text("Select Pay Period")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(periods.enumerated()), id: \.element.id) { index, period in
                            Button {
                                selectedIndex = index
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(period.label)
                                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Text(dateRange(for: period))
                                            .font(.system(.caption, design: .rounded, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.45))
                                    }
                                    Spacer()
                                    if index == selectedIndex {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.payCycleBlue)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(Color.payCycleDeepNavy)
                            }
                            .buttonStyle(.plain)

                            if index < periods.count - 1 {
                                Divider().background(Color.white.opacity(0.06)).padding(.leading, 20)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.payCycleCardNavy)
                    )
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func dateRange(for period: PaycheckPeriod) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        return "\(df.string(from: period.startDate)) – \(df.string(from: period.endDate))"
    }
}
