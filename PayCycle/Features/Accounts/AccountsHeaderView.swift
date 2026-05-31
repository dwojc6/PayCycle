import SwiftUI

private struct TabSizePreferenceKey: PreferenceKey {
    static var defaultValue: [AppTab: CGSize] = [:]

    static func reduce(value: inout [AppTab: CGSize], nextValue: () -> [AppTab: CGSize]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct AccountsHeaderView: View {
    let store: AccountsStore
    @Binding var selectedTab: AppTab
    let tabProgress: CGFloat
    @State private var showSettings = false
    @State private var tabTextSizes: [AppTab: CGSize] = [:]

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            ZStack {
                Text("Pay Cycle")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.payCycleBlue.opacity(0.72))
                            .frame(width: 36, height: 36)
                    }
                    .allowsHitTesting(true)

                    Spacer()
                }
            }
            .padding(.horizontal, 20)

            if #available(iOS 26, *) {
                glassTabBar
            } else {
                legacyTabBar
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
        }
    }
    
    private func lerp(_ start: CGFloat, _ end: CGFloat, _ amount: CGFloat) -> CGFloat {
        start + ((end - start) * amount)
    }

    private let glassTabTextGap: CGFloat = 34
    private let glassPillHorizontalPadding: CGFloat = 12
    private let glassPillVerticalPadding: CGFloat = 5
    private let glassTabHitHorizontalPadding: CGFloat = 18
    private let glassTabHeight: CGFloat = 44

    private func tabTextSize(for tab: AppTab) -> CGSize {
        tabTextSizes[tab] ?? CGSize(width: 80, height: 20)
    }

    private func tabTextFrame(for index: Int) -> CGRect {
        let tabs = AppTab.allCases
        guard tabs.indices.contains(index) else { return .zero }

        var x: CGFloat = 0

        for previousIndex in 0..<index {
            let previousTab = tabs[previousIndex]
            x += tabTextSize(for: previousTab).width + glassTabTextGap
        }

        let tab = tabs[index]
        let size = tabTextSize(for: tab)

        return CGRect(
            x: x,
            y: (glassTabHeight - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func tabGlassFrame(for index: Int) -> CGRect {
        tabTextFrame(for: index).insetBy(
            dx: -glassPillHorizontalPadding,
            dy: -glassPillVerticalPadding
        )
    }

    private func tabHitFrame(for index: Int) -> CGRect {
        let textFrame = tabTextFrame(for: index)
        let width = max(textFrame.width + (glassTabHitHorizontalPadding * 2), 44)

        return CGRect(
            x: textFrame.midX - (width / 2),
            y: (glassTabHeight - 44) / 2,
            width: width,
            height: 44
        )
    }

    private func selectedTextCenterX() -> CGFloat {
        let tabs = AppTab.allCases
        guard !tabs.isEmpty else { return 0 }

        let maxIndex = CGFloat(tabs.count - 1)
        let progress = min(max(tabProgress, 0), maxIndex)

        let lowerIndex = Int(floor(progress))
        let upperIndex = min(lowerIndex + 1, tabs.count - 1)

        let lowerFrame = tabTextFrame(for: lowerIndex)
        let upperFrame = tabTextFrame(for: upperIndex)

        if lowerIndex == upperIndex {
            return lowerFrame.midX
        }

        let amount = progress - CGFloat(lowerIndex)
        return lerp(lowerFrame.midX, upperFrame.midX, amount)
    }

    private func stripOffset(containerWidth: CGFloat) -> CGFloat {
        (containerWidth / 2) - selectedTextCenterX()
    }

    private func tabStripWidth() -> CGFloat {
        guard let lastIndex = AppTab.allCases.indices.last else { return 0 }
        return tabHitFrame(for: lastIndex).maxX
    }

    private func selectedPillFrame() -> CGRect? {
        let tabs = AppTab.allCases
        guard !tabs.isEmpty else { return nil }

        let maxIndex = CGFloat(tabs.count - 1)
        let progress = min(max(tabProgress, 0), maxIndex)

        let lowerIndex = Int(floor(progress))
        let upperIndex = min(lowerIndex + 1, tabs.count - 1)

        let lowerFrame = tabGlassFrame(for: lowerIndex)
        let upperFrame = tabGlassFrame(for: upperIndex)

        if lowerIndex == upperIndex {
            return lowerFrame
        }

        let amount = progress - CGFloat(lowerIndex)

        let centerX = lerp(lowerFrame.midX, upperFrame.midX, amount)
        let width = lerp(lowerFrame.width, upperFrame.width, amount)
        let height = lerp(lowerFrame.height, upperFrame.height, amount)

        return CGRect(
            x: centerX - (width / 2),
            y: lerp(lowerFrame.minY, upperFrame.minY, amount),
            width: width,
            height: height
        )
    }

    @available(iOS 26, *)
    private var glassTabBar: some View {
        GeometryReader { geo in
            let offset = stripOffset(containerWidth: geo.size.width)
            let stripWidth = tabStripWidth()

            ZStack(alignment: .topLeading) {
                glassMeasurementRow
                    .opacity(0)
                    .allowsHitTesting(false)

                ZStack(alignment: .topLeading) {
                    if let frame = selectedPillFrame() {
                        Capsule(style: .continuous)
                            .fill(.clear)
                            .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.payCyclePillBorder, lineWidth: 1)
                            )
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)
                            .allowsHitTesting(false)
                    }

                    ForEach(Array(AppTab.allCases.enumerated()), id: \.element) { index, tab in
                        let textFrame = tabTextFrame(for: index)
                        let hitFrame = tabHitFrame(for: index)

                        Button {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                selectedTab = tab
                            }
                        } label: {
                            tabLabel(for: tab)
                                .frame(width: textFrame.width, height: textFrame.height)
                        }
                        .buttonStyle(.plain)
                        .frame(width: hitFrame.width, height: hitFrame.height)
                        .contentShape(Capsule())
                        .position(x: hitFrame.midX, y: hitFrame.midY)
                    }
                }
                .frame(width: stripWidth, height: glassTabHeight, alignment: .topLeading)
                .offset(x: offset)
            }
            .frame(width: geo.size.width, height: glassTabHeight, alignment: .topLeading)
            .clipped()
            .onPreferenceChange(TabSizePreferenceKey.self) { sizes in
                tabTextSizes = sizes
            }
        }
        .frame(height: glassTabHeight)
    }

    private var glassMeasurementRow: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabLabel(for: tab)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: TabSizePreferenceKey.self,
                                value: [tab: geo.size]
                            )
                        }
                    )
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func safeOffset(_ value: CGFloat) -> CGFloat {
        value.isFinite ? value : 0
    }

    private var legacyTabBar: some View {
        tabScroller { tab in
            Button {
                selectedTab = tab
            } label: {
                tabLabel(for: tab)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .fill(selectedTab == tab ? Color.payCycleCardNavy : Color.white.opacity(0.03))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(selectedTab == tab ? 0 : 0.18), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.18), value: selectedTab)
        }
    }

    private func tabScroller<TabContent: View>(
        @ViewBuilder content: @escaping (AppTab) -> TabContent
    ) -> some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(AppTab.allCases, id: \.self) { tab in
                            content(tab)
                                .id(tab)
                        }
                    }
                    .padding(.horizontal, max(20, geo.size.width / 2 - 56))
                    .padding(.vertical, 1)
                }
                .onAppear {
                    proxy.scrollTo(selectedTab, anchor: .center)
                }
                .onChange(of: selectedTab) { _, tab in
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        proxy.scrollTo(tab, anchor: .center)
                    }
                }
            }
        }
        .frame(height: 40)
    }

    private func tabLabel(for tab: AppTab) -> some View {
        Text(tab.tabTitle)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(selectedTab == tab ? Color.payCycleBlue : Color.payCycleBlue.opacity(0.56))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}
