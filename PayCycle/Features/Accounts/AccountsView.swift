import SwiftUI

struct AccountsView: View {
    let store: AccountsStore
    @Binding var selectedTab: AppTab
    let budgetStore: BudgetStore
    @State private var headerHeight: CGFloat = 0
    @State private var scrollOffsets: [AppTab: CGFloat] = [:]
    @State private var scrollBottomDistances: [AppTab: CGFloat] = [:]
    @State private var pagerWidth: CGFloat = 1
    @State private var pageProgress: CGFloat = 0
    @State private var dragStartIndex: CGFloat? = nil
    @State private var isHorizontalSwiping = false
    @State private var showBudgetPeriodPicker = false

    private var headerFadeOpacity: Double {
        guard selectedTab != .transactions else { return 0 }
        return scrollOffset(for: selectedTab) > 1 ? 1 : 0
    }

    private var pagerBottomFadeOpacity: Double {
        scrollBottomDistance(for: selectedTab) > 8 ? 1 : 0
    }

    private var controlledSelectedTab: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { selectTab($0) }
        )
    }
    
    private var liveTabProgress: CGFloat {
        pageProgress
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.payCycleDeepNavy
                .ignoresSafeArea()

            GeometryReader { geo in
                let pageHeight = geo.size.height + geo.safeAreaInsets.bottom

                HStack(alignment: .top, spacing: 0) {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        tabContent(for: tab)
                            .frame(width: geo.size.width, height: pageHeight, alignment: .top)
                    }
                }
                .frame(width: geo.size.width * CGFloat(AppTab.allCases.count), height: pageHeight, alignment: .topLeading)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        stops: [
                            .init(color: Color.payCycleDeepNavy.opacity(0), location: 0),
                            .init(color: Color.payCycleDeepNavy.opacity(0.28 * pagerBottomFadeOpacity), location: 0.58),
                            .init(color: Color.payCycleDeepNavy.opacity(pagerBottomFadeOpacity), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 104)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.18), value: pagerBottomFadeOpacity)
                }
                .contentShape(Rectangle())
                .offset(x: pagerOffset(width: geo.size.width))
                .simultaneousGesture(
                    tabSwipeGesture(width: geo.size.width),
                    including: .all
                )
                .onAppear {
                    if geo.size.width > 0 { pagerWidth = geo.size.width }
                    pageProgress = CGFloat(selectedTab.index)
                }
                .onChange(of: geo.size.width) { _, newWidth in
                    if newWidth > 0 { pagerWidth = newWidth }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Floating header — always on top
            VStack(spacing: 0) {
                AccountsHeaderView(
                    store: store,
                    selectedTab: controlledSelectedTab,
                    tabProgress: liveTabProgress
                )
                    .background(
                        GeometryReader { geo in
                            Color.payCycleDeepNavy
                                .ignoresSafeArea(edges: .top)
                                .onAppear { headerHeight = geo.size.height }
                                .onChange(of: geo.size.height) { _, new in headerHeight = new }
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
                .opacity(headerFadeOpacity)
                .allowsHitTesting(false)
            }

            // Budget period picker FAB — rendered above the bottom fade overlay
            if selectedTab == .budget {
                Button {
                    showBudgetPeriodPicker = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background {
                            if #available(iOS 26, *) {
                                Circle()
                                    .fill(Color.payCycleBlue.opacity(0.18))
                                    .glassEffect(.regular.interactive(), in: Circle())
                            } else {
                                Circle()
                                    .fill(Color.payCycleBlue)
                                    .shadow(color: Color.payCycleBlue.opacity(0.5), radius: 12, x: 0, y: 6)
                            }
                        }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .task {
            await store.loadIfNeeded()
            await store.loadTransactionsIfNeeded()
        }
        .onChange(of: selectedTab) { _, tab in
            if (tab == .transactions || tab == .budget || tab == .forecasting) && store.transactions.isEmpty {
                Task { await store.reloadTransactions() }
            }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .accounts:
            accountsTab
        case .transactions:
            transactionsTab
        case .budget:
            BudgetView(
                store: store,
                budgetStore: budgetStore,
                headerHeight: headerHeight,
                isScrollDisabled: isHorizontalSwiping,
                showPeriodPicker: $showBudgetPeriodPicker,
                onScrollOffsetChange: { updateScrollOffset($0, for: .budget) },
                onScrollBottomDistanceChange: { updateScrollBottomDistance($0, for: .budget) }
            )
        case .forecasting:
            ForecastingView(
                store: store,
                budgetStore: budgetStore,
                headerHeight: headerHeight,
                isScrollDisabled: isHorizontalSwiping,
                onScrollOffsetChange: { updateScrollOffset($0, for: .forecasting) },
                onScrollBottomDistanceChange: { updateScrollBottomDistance($0, for: .forecasting) },
                isActive: selectedTab == .forecasting
            )
        }
    }

    private var accountsTab: some View {
        GeometryReader { scrollGeo in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Color.clear
                        .frame(height: 1)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onChange(of: geo.frame(in: .named("scroll")).minY) { _, y in
                                        updateScrollOffset(max(0, -y), for: .accounts)
                                    }
                                    .onAppear {
                                        updateScrollOffset(max(0, -geo.frame(in: .named("scroll")).minY), for: .accounts)
                                    }
                            }
                        )

                    Color.clear.frame(height: max(0, headerHeight - 1))

                    accountsContent

                    bottomScrollSpacer
                }
                .background(alignment: .bottom) {
                    scrollBottomReader(
                        for: .accounts,
                        coordinateSpace: "scroll",
                        viewportHeight: scrollGeo.size.height
                    )
                }
            }
            .coordinateSpace(name: "scroll")
            .scrollDisabled(isHorizontalSwiping)
            .refreshable {
                await store.reload(triggerSync: true)
                await store.reloadTransactions()
            }
        }
    }

    private var transactionsTab: some View {
        TransactionsView(
            store: store,
            headerHeight: headerHeight,
            isScrollDisabled: isHorizontalSwiping,
            onScrollOffsetChange: { updateScrollOffset($0, for: .transactions) },
            onScrollBottomDistanceChange: { updateScrollBottomDistance($0, for: .transactions) },
            bottomSpacerHeight: 32,
            isActive: selectedTab == .transactions
        )
    }

    private func scrollOffset(for tab: AppTab) -> CGFloat {
        scrollOffsets[tab] ?? 0
    }

    private func scrollBottomDistance(for tab: AppTab) -> CGFloat {
        scrollBottomDistances[tab] ?? 1
    }

    private func updateScrollOffset(_ offset: CGFloat, for tab: AppTab) {
        let rounded = (offset * 2).rounded() / 2
        guard scrollOffsets[tab] != rounded else { return }
        scrollOffsets[tab] = rounded
    }

    private func updateScrollBottomDistance(_ distance: CGFloat, for tab: AppTab) {
        let rounded = (max(0, distance) * 2).rounded() / 2
        guard scrollBottomDistances[tab] != rounded else { return }
        scrollBottomDistances[tab] = rounded
    }

    private func scrollBottomReader(
        for tab: AppTab,
        coordinateSpace: String,
        viewportHeight: CGFloat
    ) -> some View {
        Color.clear
            .frame(height: 1)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onChange(of: geo.frame(in: .named(coordinateSpace)).maxY) { _, y in
                            updateScrollBottomDistance(y - viewportHeight, for: tab)
                        }
                        .onAppear {
                            updateScrollBottomDistance(
                                geo.frame(in: .named(coordinateSpace)).maxY - viewportHeight,
                                for: tab
                            )
                        }
                }
            )
    }

    private var bottomScrollSpacer: some View {
        Color.clear.frame(height: 32)
    }

    private func pagerOffset(width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        return -pageProgress * width
    }
    
    private func snapToSelectedTab() {
        dragStartIndex = nil

        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            pageProgress = CGFloat(selectedTab.index)
        }
    }

    private func tabSwipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                guard abs(horizontal) > abs(vertical) else { return }

                if dragStartIndex == nil {
                    dragStartIndex = CGFloat(selectedTab.index)
                    isHorizontalSwiping = true
                }

                let startIndex = dragStartIndex ?? CGFloat(selectedTab.index)
                let maxIndex = CGFloat(AppTab.allCases.count - 1)

                var progress = startIndex - (horizontal / max(width, 1))
                // Soft resistance at the edges.
                if progress < 0 {
                    progress = progress * 0.18
                } else if progress > maxIndex {
                    progress = maxIndex + ((progress - maxIndex) * 0.18)
                }

                pageProgress = progress
            }
            .onEnded { value in
                let horizontal = value.translation.width
                let predictedHorizontal = value.predictedEndTranslation.width
                let vertical = value.translation.height
                let threshold = min(width * 0.24, 110)

                isHorizontalSwiping = false

                guard abs(horizontal) > abs(vertical) * 1.25 else {
                    snapToSelectedTab()
                    return
                }

                let targetTab: AppTab

                if predictedHorizontal < -threshold, let next = selectedTab.next {
                    targetTab = next
                } else if predictedHorizontal > threshold, let previous = selectedTab.previous {
                    targetTab = previous
                } else {
                    targetTab = selectedTab
                }

                dragStartIndex = nil

                withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                    selectedTab = targetTab
                    pageProgress = CGFloat(targetTab.index)
                }
            }
    }

    private func selectTab(_ tab: AppTab) {
            guard tab != selectedTab else { return }

            dragStartIndex = nil

            withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                selectedTab = tab
                pageProgress = CGFloat(tab.index)
            }
        }

    @ViewBuilder
    private var accountsContent: some View {
        if let errorMessage = store.errorMessage {
            Text(errorMessage)
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundStyle(.white)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.payCycleCardNavy)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }

        AccountsSummaryCard(snapshot: store.snapshot, store: store)

        if store.sections.isEmpty && !store.isLoading {
            EmptyAccountsStateView()
        } else {
            ForEach(Array(store.sections.enumerated()), id: \.element.id) { index, section in
                AccountSectionView(section: section, store: store, isFirst: index == 0)
            }
        }
    }
}

#Preview {
    AccountsView(store: AccountsStore.preview, selectedTab: .constant(.accounts), budgetStore: BudgetStore())
}

private struct EmptyAccountsStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No accounts loaded yet")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text("Pull down to refresh, or open Settings to update your Lunch Money API token.")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.payCycleCardNavy)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}
