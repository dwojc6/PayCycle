import SwiftUI

struct ContentView: View {
    let store: AccountsStore
    @State private var selectedTab: AppTab = .accounts
    @State private var budgetStore = BudgetStore()

    var body: some View {
        Group {
            if store.hasSavedToken {
                AccountsView(store: store, selectedTab: $selectedTab, budgetStore: budgetStore)
            } else {
                TokenSetupView(store: store)
            }
        }
        .task {
            await store.loadIfNeeded()
        }
    }
}

enum AppTab: String, CaseIterable {
    case accounts
    case transactions
    case budget
    case forecasting

    var title: String {
        switch self {
        case .accounts: return "Accounts"
        case .transactions: return "Transactions"
        case .budget: return "Budget"
        case .forecasting: return "Forecast"
        }
    }

    var tabTitle: String {
        title
    }

    var index: Int {
        AppTab.allCases.firstIndex(of: self) ?? 0
    }

    var previous: AppTab? {
        let previousIndex = index - 1
        guard AppTab.allCases.indices.contains(previousIndex) else { return nil }
        return AppTab.allCases[previousIndex]
    }

    var next: AppTab? {
        let nextIndex = index + 1
        guard AppTab.allCases.indices.contains(nextIndex) else { return nil }
        return AppTab.allCases[nextIndex]
    }
}

#Preview {
    ContentView(store: AccountsStore.preview)
}
