import SwiftUI

struct AccountSectionView: View {
    let section: AccountSection
    let store: AccountsStore
    var isFirst: Bool = false
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
    isExpanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.payCycleBlue.opacity(0.72))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)

Text(section.type.title)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)

                    Text(DisplayFormatter.currency(section.total))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.payCycleBlue.opacity(0.72))

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, isFirst ? 20 : 16)
                .padding(.bottom, 10)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(section.accounts) { account in
                    AccountRowView(account: account, store: store)
                }

            }
        }
    }
}
