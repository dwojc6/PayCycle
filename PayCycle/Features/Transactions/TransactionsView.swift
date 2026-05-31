import SwiftUI

struct TransactionsView: View {
    let store: AccountsStore
    var headerHeight: CGFloat = 0
    var isScrollDisabled: Bool = false
    var onScrollOffsetChange: (CGFloat) -> Void = { _ in }
    var onScrollBottomDistanceChange: (CGFloat) -> Void = { _ in }
    var bottomSpacerHeight: CGFloat = 0
    var isActive: Bool = true

    @State private var searchText = ""
    @State private var selectedCategoryId: Int? = nil
    @State private var showCategoryPicker = false
    @State private var searchBarHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @FocusState private var searchFocused: Bool

    private var searchFadeOpacity: Double {
        scrollOffset > 1 ? 1 : 0
    }

    // All unique categories that appear in transactions
    private var availableCategories: [LunchMoneyCategory] {
        let ids = Set(
            (store.transactions + store.pendingTransactions)
                .compactMap { $0.categoryId }
        )
        return store.categories
            .filter { ids.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    private var isFiltering: Bool {
        !searchText.isEmpty || selectedCategoryId != nil
    }

    // Flat filtered list used only when search/filter is active
    private var filteredTransactions: [LunchMoneyTransaction] {
        store.transactions.filter { matches($0) }
    }

    // Filtered transactions grouped by date for sectioned display
    private var filteredTransactionsByDate: [(label: String, transactions: [LunchMoneyTransaction])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        // Separate pending from dated
        let pending = filteredTransactions.filter { $0.isPending }
        let dated = filteredTransactions.filter { !$0.isPending }

        let grouped = Dictionary(grouping: dated) { $0.date }
        var sections: [(label: String, transactions: [LunchMoneyTransaction])] = grouped.keys
            .sorted(by: >)
            .compactMap { dateStr -> (String, [LunchMoneyTransaction])? in
                guard let txns = grouped[dateStr], let date = df.date(from: dateStr) else { return nil }
                let label: String
                if calendar.isDate(date, inSameDayAs: today) {
                    label = "TODAY"
                } else if calendar.isDate(date, inSameDayAs: yesterday) {
                    label = "YESTERDAY"
                } else {
                    let display = DateFormatter()
                    display.dateFormat = "EEEE, MMM d"
                    label = display.string(from: date).uppercased()
                }
                return (label, txns.sorted { ($0.parsedDate ?? .distantPast) > ($1.parsedDate ?? .distantPast) })
            }

        if !pending.isEmpty {
            sections.insert(("PENDING", pending), at: 0)
        }

        return sections
    }

    private func matches(_ txn: LunchMoneyTransaction) -> Bool {
        let nameMatch = searchText.isEmpty ||
            txn.displayName.localizedCaseInsensitiveContains(searchText)
        let categoryMatch = selectedCategoryId == nil ||
            txn.categoryId == selectedCategoryId
        return nameMatch && categoryMatch
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.payCycleDeepNavy
                .ignoresSafeArea()

            GeometryReader { scrollGeo in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        scrollOffsetReader
                        Color.clear.frame(height: headerHeight + searchBarHeight)

                        transactionContent
                        Color.clear.frame(height: bottomSpacerHeight)
                    }
                    .background(alignment: .bottom) {
                        scrollBottomReader(viewportHeight: scrollGeo.size.height)
                    }
                }
                .coordinateSpace(name: "transactionsScroll")
                .scrollDisabled(isScrollDisabled)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        searchFocused = false
                    }
                )
                .refreshable {
                    await store.reloadTransactions()
                }
            }

            VStack(spacing: 0) {
                Color.clear.frame(height: headerHeight)
                searchAndFilterBar
                    .background(
                        GeometryReader { geo in
                            Color.payCycleDeepNavy
                                .onAppear { searchBarHeight = geo.size.height }
                                .onChange(of: geo.size.height) { _, new in searchBarHeight = new }
                        }
                    )

                LinearGradient(
                    stops: [
                        .init(color: Color.payCycleDeepNavy, location: 0),
                        .init(color: Color.payCycleDeepNavy.opacity(0), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 28)
                .opacity(searchFadeOpacity)
                .allowsHitTesting(false)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isActive && searchFocused {
                    Spacer()

                    Button("Done") {
                        searchFocused = false
                    }
                }
            }
        }
        .onChange(of: isActive) { _, active in
            if !active {
                searchFocused = false
            }
        }
    }

    @ViewBuilder
    private var transactionContent: some View {
        if store.isLoadingTransactions && store.transactions.isEmpty {
            VStack(spacing: 16) {
                ProgressView()
                    .tint(Color.payCycleSky)
                Text("Loading transactions…")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else if store.paycheckPeriods.isEmpty && store.pendingTransactions.isEmpty {
            emptyState
        } else if isFiltering {
            filteredResultsList
        } else {
            PendingTransactionsSection(transactions: store.pendingTransactions, store: store)

            ForEach(store.paycheckPeriods) { period in
                PaycheckPeriodSection(period: period, store: store)
            }
        }
    }

    private var scrollOffsetReader: some View {
        Color.clear
            .frame(height: 1)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onChange(of: geo.frame(in: .named("transactionsScroll")).minY) { _, y in
                            updateScrollOffset(max(0, -y))
                        }
                        .onAppear {
                            updateScrollOffset(max(0, -geo.frame(in: .named("transactionsScroll")).minY))
                        }
                }
            )
    }

    private func updateScrollOffset(_ offset: CGFloat) {
        scrollOffset = offset
        onScrollOffsetChange(offset)
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
                        .onChange(of: geo.frame(in: .named("transactionsScroll")).maxY) { _, y in
                            updateScrollBottomDistance(y - viewportHeight)
                        }
                        .onAppear {
                            updateScrollBottomDistance(
                                geo.frame(in: .named("transactionsScroll")).maxY - viewportHeight
                            )
                        }
                }
            )
    }

    // MARK: - Search & Filter Bar

    private var selectedCategoryName: String {
        guard let id = selectedCategoryId,
              let cat = availableCategories.first(where: { $0.id == id }) else {
            return "All"
        }
        return cat.name
    }

    private var searchAndFilterBar: some View {
        HStack(spacing: 8) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(.white)

                TextField(
                    "",
                    text: $searchText,
                    prompt: Text("Search transactions…")
                        .foregroundStyle(.white.opacity(0.3))
                )
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white)
                    .tint(Color.payCycleSky)
                    .focused($searchFocused)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .accentColor(.white)
                    .onSubmit {
                        searchFocused = false
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(.subheadline))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background {
                if #available(iOS 26, *) {
                    Capsule(style: .continuous)
                        .fill(Color.payCycleCardNavy)
                        .glassEffect(.regular.interactive(), in: Capsule())
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.payCyclePillBorder, lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.payCycleCardNavy)
                }
            }

            // Filter button
            Button {
                searchFocused = false
                showCategoryPicker = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 13, weight: .semibold))
                    if selectedCategoryId != nil {
                        Text(selectedCategoryName)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background {
                    if #available(iOS 26, *) {
                        Capsule(style: .continuous)
                            .fill(Color.payCycleCardNavy)
                            .glassEffect(.regular.interactive(), in: Capsule())
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.payCyclePillBorder, lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.payCycleCardNavy)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background(Color.payCycleDeepNavy)
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet(
                categories: availableCategories,
                selectedCategoryId: $selectedCategoryId
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.payCycleDeepNavy)
        }
    }

    // MARK: - Filtered Results

    private var filteredResultsList: some View {
        Group {
            if filteredTransactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No transactions found")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(filteredTransactions.count) result\(filteredTransactions.count == 1 ? "" : "s")")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                        .tracking(0.8)
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 4)

                    ForEach(filteredTransactionsByDate, id: \.label) { group in
                        Text(group.label)
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(group.label == "PENDING"
                                             ? Color.payCycleSky.opacity(0.7)
                                             : Color.payCycleBlue.opacity(0.72))
                            .tracking(0.8)
                            .padding(.horizontal, 20)
                            .padding(.top, 14)
                            .padding(.bottom, 4)

                        ForEach(group.transactions) { txn in
                            TransactionRowView(transaction: txn, store: store)
                        }
                    }
                }
                .background(Color.payCycleDeepNavy)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.white.opacity(0.4))

            Text("No transactions yet")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)

            Text("Pull down to refresh once your Lunch Money data is connected.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 60)
    }
}

// MARK: - Category Picker Sheet

private struct CategoryPickerSheet: View {
    let categories: [LunchMoneyCategory]
    @Binding var selectedCategoryId: Int?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Filter by Category")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 0) {
                    row(label: "All Categories", isSelected: selectedCategoryId == nil) {
                        selectedCategoryId = nil
                        dismiss()
                    }

                    Divider().background(Color.white.opacity(0.08))

                    ForEach(categories) { category in
                        row(label: category.name, isSelected: selectedCategoryId == category.id) {
                            selectedCategoryId = category.id
                            dismiss()
                        }

                        if category.id != categories.last?.id {
                            Divider().background(Color.white.opacity(0.08))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private func row(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(.body, design: .rounded, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(.white)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(Color.payCycleBlue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Paycheck Period Section

private struct PaycheckPeriodSection: View {
    let period: PaycheckPeriod
    let store: AccountsStore

    private var groupedByDate: [(label: String, transactions: [LunchMoneyTransaction])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let grouped = Dictionary(grouping: period.transactions.filter { !$0.isPending }) { $0.date }
        return grouped.keys.sorted(by: >).compactMap { dateStr -> (String, [LunchMoneyTransaction])? in
            guard let txns = grouped[dateStr], let date = df.date(from: dateStr) else { return nil }
            let label: String
            if calendar.isDate(date, inSameDayAs: today) {
                label = "TODAY"
            } else if calendar.isDate(date, inSameDayAs: yesterday) {
                label = "YESTERDAY"
            } else {
                let display = DateFormatter()
                display.dateFormat = "EEEE, MMM d"
                label = display.string(from: date).uppercased()
            }
            return (label, txns.sorted { ($0.parsedDate ?? .distantPast) > ($1.parsedDate ?? .distantPast) })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(groupedByDate, id: \.label) { group in
                Text(group.label)
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.payCycleBlue.opacity(0.72))
                    .tracking(0.8)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 4)

                ForEach(group.transactions) { txn in
                    TransactionRowView(transaction: txn, store: store)
                }
            }
        }
    }
}

// MARK: - Pending Transactions

private struct PendingTransactionsSection: View {
    let transactions: [LunchMoneyTransaction]
    let store: AccountsStore

    var body: some View {
        if !transactions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("PENDING")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.payCycleSky.opacity(0.7))
                    .tracking(0.8)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 4)

                ForEach(transactions) { transaction in
                    TransactionRowView(transaction: transaction, store: store)
                }
            }
            .background(Color.payCycleDeepNavy)
        }
    }
}

// MARK: - Transaction Row

struct TransactionRowView: View {
    let transaction: LunchMoneyTransaction
    let store: AccountsStore

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.displayName)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let cat = store.categoryName(for: transaction.categoryId) {
                    Text(cat)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(amountText)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(transaction.isIncome ? Color.payCycleSuccess : Color.white)

                if transaction.isPending {
                    Text("Pending")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.payCycleSky.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.payCycleDeepNavy)
        .opacity(transaction.isPending ? 0.62 : 1)
    }

    private var amountText: String {
        let amt = abs(transaction.displayAmount)
        let formatted = DisplayFormatter.currency(amt, code: transaction.currency)
        return transaction.isIncome ? "+\(formatted)" : formatted
    }

    private var iconName: String {
        guard let catId = transaction.categoryId,
              let cat = store.categories.first(where: { $0.id == catId }) else {
            return "creditcard"
        }
        switch cat.name.lowercased() {
        case let n where n.contains("grocer") || n.contains("food"):       return "cart"
        case let n where n.contains("restaurant") || n.contains("dining"): return "fork.knife"
        case let n where n.contains("gas") || n.contains("fuel"):          return "fuelpump"
        case let n where n.contains("income") || n.contains("paycheck"):   return "dollarsign.circle"
        case let n where n.contains("cc") || n.contains("payment"):        return "creditcard.trianglebadge.exclamationmark"
        case let n where n.contains("subscri"):                            return "repeat"
        case let n where n.contains("car") || n.contains("auto"):          return "car"
        case let n where n.contains("daycare") || n.contains("mia"):       return "figure.2.and.child.holdinghands"
        case let n where n.contains("household"):                          return "house"
        case let n where n.contains("shop") || n.contains("entertain"):    return "bag"
        case let n where n.contains("saving"):                             return "banknote"
        default:                                                            return "creditcard"
        }
    }

    private var iconColor: Color {
        guard let catId = transaction.categoryId,
              let cat = store.categories.first(where: { $0.id == catId }) else {
            return Color.payCycleSoft
        }
        if cat.isIncome { return Color.payCycleSuccess }
        switch cat.name.lowercased() {
        case let n where n.contains("grocer") || n.contains("food"):       return Color.payCycleSky
        case let n where n.contains("restaurant") || n.contains("dining"): return Color(red: 0.98, green: 0.60, blue: 0.25)
        case let n where n.contains("gas"):                                 return Color(red: 0.55, green: 0.85, blue: 0.55)
        case let n where n.contains("cc") || n.contains("payment"):         return Color.payCycleDanger
        case let n where n.contains("saving"):                              return Color.payCycleSuccess
        case let n where n.contains("car"):                                 return Color(red: 0.65, green: 0.55, blue: 0.95)
        case let n where n.contains("daycare") || n.contains("mia"):        return Color(red: 0.98, green: 0.78, blue: 0.35)
        case let n where n.contains("household"):                           return Color.payCycleSoft
        default:                                                             return Color.payCycleSoft
        }
    }
}
